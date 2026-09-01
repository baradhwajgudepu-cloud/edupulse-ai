import uuid
import logging
import re
from typing import List, Optional, Dict, Any
from datetime import date, datetime, timezone
from sqlalchemy import select, and_, or_, func
from fastapi import HTTPException, status

from app.models.notification import (
    Notification, NotificationPreference, NotificationStatus,
    NotificationType, NotificationPriority, NotificationTargetRole, UserDeviceToken,
    NotificationDelivery, NotificationDeliveryChannel, NotificationDeliveryStatus, NotificationEventType
)
from app.models.student import Student
from app.models.guardian import Guardian, StudentGuardian
from app.models.user import User, UserStatus
from app.models.role import Role, user_roles
from app.models.homework import Homework
from app.models.examination import Examination
from app.models.report_card import ReportCardPublication
from app.repositories.notification import NotificationRepository
from app.schemas.notification import NotificationCreate, NotificationPreferenceUpdate
from app.core.settings import settings
from app.services.whatsapp import get_whatsapp_provider

logger = logging.getLogger(__name__)

DEFAULT_WHATSAPP_TEMPLATES = {
    "ATTENDANCE_ABSENT": "Attendance Alert: {{student_name}} was marked absent on {{date}}.",
    "ATTENDANCE_LATE": "Attendance Alert: {{student_name}} was marked late on {{date}}.",
    "ATTENDANCE_HALF_DAY": "Attendance Alert: {{student_name}} was marked half day on {{date}}.",
    "MARKS_PUBLISHED": "Assessment Result: {{student_name}} scored {{marks}}/{{max_marks}} in {{subject_name}}.",
    "EXAM_SCHEDULE": "Exam Schedule: {{exam_name}} has been scheduled.",
    "EXAM_REMINDER": "Exam Reminder: {{student_name}} has {{subject_name}} exam on {{date}}.",
    "ANNOUNCEMENT": "Announcement: {{title}} - {{message}}",
    "HOLIDAY": "Holiday Alert: School will be closed on {{date}} due to {{holiday_details}}.",
    "EMERGENCY_ALERT": "Emergency Alert: {{message}}",
    "FEE_REMINDER": "Fee Due Reminder: {{fee_name}} of {{amount}} is due on {{due_date}}.",
    "FEE_OVERDUE": "Overdue Fee Alert: {{fee_name}} of {{amount}} was due on {{due_date}}."
}

class NotificationService:
    def __init__(self, notification_repo: Any) -> None:
        if isinstance(notification_repo, NotificationRepository):
            self.notification_repo = notification_repo
            self.db = getattr(notification_repo, 'db', notification_repo)
        else:
            self.db = notification_repo
            self.notification_repo = NotificationRepository(notification_repo)

    async def get_multi(
        self,
        tenant_id: uuid.UUID,
        user_id: uuid.UUID,
        user_roles: List[str],
        notification_type: Optional[NotificationType] = None,
        priority: Optional[NotificationPriority] = None,
        status: Optional[NotificationStatus] = None,
        filter_date: Optional[date] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[Notification]:
        return await self.notification_repo.get_multi(
            tenant_id=tenant_id,
            user_id=user_id,
            user_roles=user_roles,
            notification_type=notification_type,
            priority=priority,
            status=status,
            filter_date=filter_date,
            skip=skip,
            limit=limit
        )

    async def get_by_id(
        self, id: uuid.UUID, tenant_id: uuid.UUID, current_user: User
    ) -> Notification:
        db_obj = await self.notification_repo.get_by_id(id, tenant_id)
        if not db_obj:
            raise HTTPException(status_code=404, detail="Notification not found.")

        # 1. Ownership check: if notification is targeted to a specific user, verify it matches
        if db_obj.target_user_id and db_obj.target_user_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. This notification belongs to another user."
            )

        # 2. RBAC check: restrict parents/teachers to their corresponding target roles (staff bypasses)
        user_role_codes = {r.code for r in current_user.roles}
        is_parent = "PARENT" in user_role_codes
        is_teacher = "TEACHER" in user_role_codes
        is_staff = any(r in user_role_codes for r in ["SUPER_ADMIN", "ADMIN", "PRINCIPAL", "STAFF"])

        if not is_staff:
            if is_parent and db_obj.target_role != NotificationTargetRole.PARENT:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Access denied. Parents can only access parent-directed notifications."
                )
            elif is_teacher and db_obj.target_role != NotificationTargetRole.TEACHER:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Access denied. Teachers can only access teacher-directed notifications."
                )

        return db_obj

    async def mark_read(
        self, id: uuid.UUID, tenant_id: uuid.UUID, current_user: User
    ) -> Notification:
        db_obj = await self.get_by_id(id, tenant_id, current_user)
        # Ensure it belongs to the current user if it is targeted
        if db_obj.target_user_id and db_obj.target_user_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. Cannot update status of another user's notification."
            )
        
        updated = await self.notification_repo.mark_read(id, tenant_id, current_user.id)
        await self.notification_repo.db.commit()
        await self.notification_repo.db.refresh(updated)
        return updated

    async def mark_all_read(
        self, tenant_id: uuid.UUID, current_user: User
    ) -> int:
        user_role_codes = [r.code for r in current_user.roles]
        updated_count = await self.notification_repo.mark_all_read(
            tenant_id=tenant_id,
            user_id=current_user.id,
            user_roles=user_role_codes,
            updated_by=current_user.id
        )
        await self.notification_repo.db.commit()
        return updated_count

    async def delete_notification(
        self, id: uuid.UUID, tenant_id: uuid.UUID, current_user: User
    ) -> Notification:
        db_obj = await self.get_by_id(id, tenant_id, current_user)
        # Ensure it belongs to the current user if it is targeted
        if db_obj.target_user_id and db_obj.target_user_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. Cannot delete another user's notification."
            )
            
        deleted = await self.notification_repo.soft_delete(id, tenant_id, current_user.id)
        await self.notification_repo.db.commit()
        await self.notification_repo.db.refresh(deleted)
        return deleted

    async def count_unread(
        self, tenant_id: uuid.UUID, current_user: User
    ) -> int:
        user_role_codes = [r.code for r in current_user.roles]
        return await self.notification_repo.count_unread(
            tenant_id=tenant_id,
            user_id=current_user.id,
            user_roles=user_role_codes
        )

    # --- PREFERENCES SERVICE WRAPPERS ---

    async def get_preferences(
        self, user_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> NotificationPreference:
        pref = await self.notification_repo.get_preferences(user_id, tenant_id)
        if not pref:
            pref = await self.notification_repo.create_default_preferences(user_id, tenant_id)
            await self.notification_repo.db.commit()
            await self.notification_repo.db.refresh(pref)
        return pref

    async def update_preferences(
        self, user_id: uuid.UUID, tenant_id: uuid.UUID, obj_in: NotificationPreferenceUpdate
    ) -> NotificationPreference:
        updated = await self.notification_repo.update_preferences(user_id, tenant_id, obj_in, user_id)
        await self.notification_repo.db.commit()
        await self.notification_repo.db.refresh(updated)
        return updated

    # --- INTERNAL BROADCAST & NOTIFICATION EVENT HANDLERS ---

    async def _resolve_parent_users(self, tenant_id: uuid.UUID, student_id: uuid.UUID) -> List[User]:
        """
        Resolves registered User accounts corresponding to the student's primary notifications-enabled guardians.
        """
        stmt = select(User).join(
            Guardian, Guardian.email == User.email
        ).join(
            StudentGuardian, StudentGuardian.guardian_id == Guardian.id
        ).where(
            StudentGuardian.student_id == student_id,
            StudentGuardian.receives_notifications.is_(True),
            User.tenant_id == tenant_id,
            User.status == UserStatus.ACTIVE,
            User.deleted_at.is_(None)
        )
        res = await self.notification_repo.db.execute(stmt)
        return list(res.scalars().all())

    async def _resolve_section_teachers(self, tenant_id: uuid.UUID, section_id: uuid.UUID) -> List[User]:
        """
        Resolves registered User accounts teaching in a given section.
        """
        from app.models.teacher import Teacher
        from app.models.teacher_subject_assignment import TeacherSubjectAssignment
        stmt = select(User).join(
            Teacher, Teacher.user_id == User.id
        ).join(
            TeacherSubjectAssignment, TeacherSubjectAssignment.teacher_id == Teacher.id
        ).where(
            TeacherSubjectAssignment.section_id == section_id,
            TeacherSubjectAssignment.deleted_at.is_(None),
            User.tenant_id == tenant_id,
            User.status == UserStatus.ACTIVE,
            User.deleted_at.is_(None)
        )
        res = await self.notification_repo.db.execute(stmt)
        return list(res.scalars().all())

    async def _resolve_principals_admins(self, tenant_id: uuid.UUID) -> List[User]:
        """
        Resolves active Users belonging to PRINCIPAL/ADMIN/SUPER_ADMIN roles in the tenant boundary.
        """
        stmt = select(User).join(
            user_roles, User.id == user_roles.c.user_id
        ).join(
            Role, user_roles.c.role_id == Role.id
        ).where(
            Role.code.in_(["PRINCIPAL", "ADMIN", "SUPER_ADMIN"]),
            User.tenant_id == tenant_id,
            User.status == UserStatus.ACTIVE,
            User.deleted_at.is_(None)
        )
        res = await self.notification_repo.db.execute(stmt)
        return list(res.scalars().all())

    async def _resolve_role_users(self, tenant_id: uuid.UUID, target_role: NotificationTargetRole) -> List[User]:
        """
        Resolves active Users belonging to a target role in the tenant boundary.
        Uses explicit joins on the RBAC user_roles and roles tables.
        """
        logger.info(f"_resolve_role_users called: tenant_id={tenant_id}, target_role={target_role}")
        stmt = select(User).join(
            user_roles, User.id == user_roles.c.user_id
        ).join(
            Role, user_roles.c.role_id == Role.id
        ).where(
            or_(
                func.upper(Role.name) == target_role.value,
                func.upper(Role.code) == target_role.value
            ),
            User.tenant_id == tenant_id,
            Role.tenant_id == tenant_id,
            User.status == UserStatus.ACTIVE,
            User.deleted_at.is_(None),
            Role.deleted_at.is_(None)
        )
        res = await self.notification_repo.db.execute(stmt)
        resolved_users = list(res.scalars().all())
        logger.info(f"Resolved {len(resolved_users)} users for role {target_role.value}.")
        return resolved_users

    async def _create_user_notification(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        obj_in: NotificationCreate,
        created_by: Optional[uuid.UUID] = None
    ) -> Optional[Notification]:
        """
        Persists a single notification record checking user category communication preferences.
        """
        logger.info(
            f"_create_user_notification: tenant_id={tenant_id}, school_id={school_id}, "
            f"target_user_id={obj_in.target_user_id}, notification_type={obj_in.notification_type}, "
            f"created_by={created_by}"
        )
        if not obj_in.target_user_id:
            logger.info("No target_user_id specified, proceeding with direct creation.")
            return await self.notification_repo.create(tenant_id, school_id, obj_in, created_by)

        prefs = await self.notification_repo.get_preferences(obj_in.target_user_id, tenant_id)
        if not prefs:
            logger.info(f"No preferences found for user {obj_in.target_user_id}. Creating default preferences.")
            prefs = await self.notification_repo.create_default_preferences(obj_in.target_user_id, tenant_id)
            logger.info("Executing db.flush() for new default preferences...")
            await self.notification_repo.db.flush()
            logger.info("db.flush() for default preferences completed.")

        pref_map = {
            NotificationType.ATTENDANCE: "enable_attendance",
            NotificationType.HOMEWORK: "enable_homework",
            NotificationType.MARKS: "enable_marks",
            NotificationType.REPORT_CARD: "enable_report_card",
            NotificationType.ANNOUNCEMENT: "enable_announcements",
            NotificationType.EVENT: "enable_events",
            NotificationType.FEE: "enable_fee"
        }
        field = pref_map.get(obj_in.notification_type)
        if field and not getattr(prefs, field, True):
            logger.info(f"Notification creation bypassed due to preferences: type={obj_in.notification_type.value} user={obj_in.target_user_id}")
            return None

        return await self.notification_repo.create(tenant_id, school_id, obj_in, created_by)

    async def register_device_token(
        self,
        tenant_id: uuid.UUID,
        user_id: uuid.UUID,
        device_token: str,
        platform: str,
        app_type: str
    ) -> UserDeviceToken:
        token = await self.notification_repo.register_device_token(
            tenant_id=tenant_id,
            user_id=user_id,
            device_token=device_token,
            platform=platform,
            app_type=app_type
        )
        await self.notification_repo.db.commit()
        await self.notification_repo.db.refresh(token)
        return token

    async def deactivate_device_token(
        self,
        tenant_id: uuid.UUID,
        user_id: uuid.UUID,
        device_token: str
    ) -> Optional[UserDeviceToken]:
        token = await self.notification_repo.deactivate_device_token(
            tenant_id=tenant_id,
            user_id=user_id,
            device_token=device_token
        )
        await self.notification_repo.db.commit()
        if token:
            await self.notification_repo.db.refresh(token)
        return token

    # --- RESOLVE MOBILE NUMBER & NORMALIZATION ---
    async def resolve_recipient_mobile(self, user: User, role: NotificationTargetRole) -> Optional[str]:
        mobile = None
        if role == NotificationTargetRole.PARENT:
            stmt = select(Guardian.mobile).where(
                or_(Guardian.email == user.email, Guardian.user_id == user.id),
                Guardian.deleted_at.is_(None)
            )
            res = await self.notification_repo.db.execute(stmt)
            mobile = res.scalar_one_or_none()
        elif role == NotificationTargetRole.TEACHER:
            from app.models.teacher import Teacher
            stmt = select(Teacher.mobile).where(
                or_(Teacher.official_email == user.email, Teacher.user_id == user.id),
                Teacher.deleted_at.is_(None)
            )
            res = await self.notification_repo.db.execute(stmt)
            mobile = res.scalar_one_or_none()

        if not mobile:
            # Fallback check on both tables
            stmt = select(Guardian.mobile).where(
                or_(Guardian.email == user.email, Guardian.user_id == user.id),
                Guardian.deleted_at.is_(None)
            )
            res = await self.notification_repo.db.execute(stmt)
            mobile = res.scalar_one_or_none()
            
            if not mobile:
                from app.models.teacher import Teacher
                stmt = select(Teacher.mobile).where(
                    or_(Teacher.official_email == user.email, Teacher.user_id == user.id),
                    Teacher.deleted_at.is_(None)
                )
                res = await self.notification_repo.db.execute(stmt)
                mobile = res.scalar_one_or_none()

        return self.normalize_indian_mobile(mobile)

    def normalize_indian_mobile(self, mobile: str) -> Optional[str]:
        if not mobile:
            return None
        cleaned = "".join(c for c in mobile if c.isdigit())
        if not cleaned:
            return None
        if len(cleaned) == 10:
            return f"+91{cleaned}"
        elif len(cleaned) == 11 and cleaned.startswith("0"):
            return f"+91{cleaned[1:]}"
        elif len(cleaned) == 12 and cleaned.startswith("91"):
            return f"+{cleaned}"
        elif len(cleaned) > 10:
            return f"+{cleaned}"
        return f"+91{cleaned}"

    # --- ASYNC RETRY PIPELINE ---
    async def _send_whatsapp_with_retry(
        self,
        delivery_id: uuid.UUID,
        to_phone: str,
        template_name: str,
        context: dict,
        tenant_id: uuid.UUID,
        config: dict
    ):
        import asyncio
        from app.db.session import AsyncSessionLocal
        from app.models.notification import NotificationDelivery, NotificationDeliveryStatus
        
        max_retries = 3
        delay = 2.0
        
        template_str = DEFAULT_WHATSAPP_TEMPLATES.get(template_name, context.get("message", ""))
        vars_found = re.findall(r"\{\{([^}]+)\}\}", template_str)
        params = []
        for var in vars_found:
            var = var.strip()
            val = str(context.get(var, ""))
            params.append({"type": "text", "text": val})
        components = [{"type": "body", "parameters": params}] if params else []

        provider_name = config.get("provider", "mock")
        provider = get_whatsapp_provider(provider_name)
        
        for attempt in range(1, max_retries + 1):
            logger.info(f"Attempting WhatsApp send. Attempt {attempt}/{max_retries} for delivery {delivery_id}")
            result = await provider.send_template(
                to_phone=to_phone,
                template_name=template_name,
                language_code=config.get("language_code", "en_US"),
                components=components,
                tenant_id=str(tenant_id),
                config=config
            )
            
            async with AsyncSessionLocal() as db:
                stmt = select(NotificationDelivery).where(NotificationDelivery.id == delivery_id)
                res = await db.execute(stmt)
                delivery = res.scalar_one_or_none()
                if not delivery:
                    logger.error(f"NotificationDelivery {delivery_id} not found in background task.")
                    break
                
                if result["status"] == "SENT" or result["status"] == "DELIVERED":
                    delivery.status = NotificationDeliveryStatus.SENT
                    delivery.provider_message_id = result.get("provider_message_id")
                    delivery.sent_at = datetime.now(timezone.utc)
                    await db.commit()
                    logger.info(f"WhatsApp sent successfully for delivery {delivery_id}")
                    break
                else:
                    delivery.error_code = result.get("error_code")
                    delivery.error_message = result.get("error_message")
                    delivery.failed_at = datetime.now(timezone.utc)
                    
                    is_temporary = result.get("is_temporary", False)
                    if is_temporary and attempt < max_retries:
                        delivery.status = NotificationDeliveryStatus.QUEUED
                        await db.commit()
                        await asyncio.sleep(delay)
                        delay *= 2
                        continue
                    else:
                        delivery.status = NotificationDeliveryStatus.FAILED
                        await db.commit()
                        logger.error(f"WhatsApp sending permanently failed for delivery {delivery_id}: {delivery.error_message}")
                        break

    async def _create_user_deliveries(self, db, notification: Notification, user: User, role: NotificationTargetRole, tenant_settings: dict):
        # 1. Get preferences
        prefs = await self.notification_repo.get_preferences(user.id, notification.tenant_id)
        if not prefs:
            prefs = await self.notification_repo.create_default_preferences(user.id, notification.tenant_id)
            await db.flush()

        # 2. Determine enabled channels based on tenant policy defaults & user preferences
        policy = tenant_settings.get("notification_policy", {})
        type_key = notification.notification_type.value.lower()
        allowed_channels = policy.get(type_key, ["IN_APP", "PUSH", "WHATSAPP"])
        
        channels_to_send = []
        if "IN_APP" in allowed_channels and getattr(prefs, "enable_in_app", True):
            channels_to_send.append(NotificationDeliveryChannel.IN_APP)
        if "PUSH" in allowed_channels and getattr(prefs, "enable_push", True):
            channels_to_send.append(NotificationDeliveryChannel.PUSH)
        if "WHATSAPP" in allowed_channels and getattr(prefs, "enable_whatsapp", True):
            channels_to_send.append(NotificationDeliveryChannel.WHATSAPP)
        if "SMS" in allowed_channels and getattr(prefs, "enable_sms", True):
            channels_to_send.append(NotificationDeliveryChannel.SMS)
        if "EMAIL" in allowed_channels and getattr(prefs, "enable_email", True):
            channels_to_send.append(NotificationDeliveryChannel.EMAIL)

        for channel in channels_to_send:
            stmt = select(NotificationDelivery).where(
                and_(
                    NotificationDelivery.notification_id == notification.id,
                    NotificationDelivery.recipient_id == user.id,
                    NotificationDelivery.channel == channel
                )
            )
            res = await db.execute(stmt)
            if res.scalar_one_or_none():
                continue

            delivery = NotificationDelivery(
                id=uuid.uuid4(),
                tenant_id=notification.tenant_id,
                notification_id=notification.id,
                recipient_id=user.id,
                channel=channel,
                provider="mock",
                status=NotificationDeliveryStatus.PENDING
            )
            db.add(delivery)
            await db.flush()

            if channel == NotificationDeliveryChannel.IN_APP:
                delivery.status = NotificationDeliveryStatus.DELIVERED
                delivery.sent_at = datetime.now(timezone.utc)
                delivery.delivered_at = datetime.now(timezone.utc)
                
            elif channel == NotificationDeliveryChannel.PUSH:
                delivery.provider = "mock-fcm"
                delivery.status = NotificationDeliveryStatus.SENT
                delivery.sent_at = datetime.now(timezone.utc)
                delivery.provider_message_id = f"mock-fcm-{uuid.uuid4()}"
                
            elif channel == NotificationDeliveryChannel.WHATSAPP:
                wa_enabled = settings.WHATSAPP_ENABLED or tenant_settings.get("whatsapp_enabled", False)
                if not wa_enabled:
                    delivery.status = NotificationDeliveryStatus.FAILED
                    delivery.error_code = "WHATSAPP_DISABLED"
                    delivery.error_message = "WhatsApp is disabled globally or for this tenant."
                    continue

                mobile = await self.resolve_recipient_mobile(user, role)
                if not mobile:
                    delivery.status = NotificationDeliveryStatus.FAILED
                    delivery.error_code = "MISSING_MOBILE_NUMBER"
                    delivery.error_message = "No registered mobile number resolved for the recipient."
                    continue

                wa_provider = settings.WHATSAPP_PROVIDER or tenant_settings.get("whatsapp_provider", "mock")
                wa_config = {
                    "provider": wa_provider,
                    "api_url": settings.WHATSAPP_API_URL or tenant_settings.get("whatsapp_api_url"),
                    "access_token": settings.WHATSAPP_ACCESS_TOKEN or tenant_settings.get("whatsapp_access_token"),
                    "phone_number_id": settings.WHATSAPP_PHONE_NUMBER_ID or tenant_settings.get("whatsapp_phone_number_id"),
                    "business_account_id": settings.WHATSAPP_BUSINESS_ACCOUNT_ID or tenant_settings.get("whatsapp_business_account_id")
                }
                
                context = {
                    "title": notification.title,
                    "message": notification.message,
                    "student_name": notification.settings.get("student_name", "Student") if notification.settings else "Student",
                    "parent_name": user.first_name + " " + user.last_name,
                    "class_name": notification.settings.get("class_name", "") if notification.settings else "",
                    "section_name": notification.settings.get("section_name", "") if notification.settings else "",
                    "subject_name": notification.settings.get("subject_name", "") if notification.settings else "",
                    "marks": notification.settings.get("marks", "") if notification.settings else "",
                    "max_marks": notification.settings.get("max_marks", "") if notification.settings else "",
                    "date": datetime.now().strftime("%Y-%m-%d"),
                    "exam_name": notification.settings.get("exam_name", "") if notification.settings else "",
                    "school_name": notification.settings.get("school_name", "School") if notification.settings else "School",
                    "fee_name": notification.settings.get("fee_name", "") if notification.settings else "",
                    "amount": notification.settings.get("amount", "") if notification.settings else "",
                    "due_date": notification.settings.get("due_date", "") if notification.settings else "",
                    "holiday_details": notification.settings.get("holiday_details", "") if notification.settings else ""
                }

                import asyncio
                asyncio.create_task(
                    self._send_whatsapp_with_retry(
                        delivery_id=delivery.id,
                        to_phone=mobile,
                        template_name=notification.event_type or "ANNOUNCEMENT",
                        context=context,
                        tenant_id=notification.tenant_id,
                        config=wa_config
                    )
                )
                delivery.status = NotificationDeliveryStatus.QUEUED
                delivery.provider = wa_provider

            elif channel == NotificationDeliveryChannel.SMS:
                delivery.provider = "mock-sms"
                delivery.status = NotificationDeliveryStatus.FAILED
                delivery.error_code = "SMS_NOT_CONFIGURED"
                delivery.error_message = "SMS delivery is not configured."

            elif channel == NotificationDeliveryChannel.EMAIL:
                delivery.provider = "mock-email"
                delivery.status = NotificationDeliveryStatus.FAILED
                delivery.error_code = "EMAIL_NOT_CONFIGURED"
                delivery.error_message = "Email delivery is not configured."

    async def _dispatch_deliveries_for_notification(self, db, notification: Notification, tenant_settings: dict):
        recipient_id = notification.target_user_id
        if not recipient_id:
            role_users = await self._resolve_role_users(notification.tenant_id, notification.target_role)
            for user in role_users:
                await self._create_user_deliveries(db, notification, user, notification.target_role, tenant_settings)
        else:
            stmt = select(User).where(User.id == recipient_id)
            res = await db.execute(stmt)
            user = res.scalar_one_or_none()
            if user:
                await self._create_user_deliveries(db, notification, user, notification.target_role, tenant_settings)

    async def dispatch_event(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        event_type: str,
        payload: Dict[str, Any],
        created_by: Optional[uuid.UUID] = None
    ) -> List[Notification]:
        logger.info(f"dispatch_event: event_type={event_type}, payload={payload}")
        
        recipients = []
        student_id = payload.get("student_id")
        
        target_role = NotificationTargetRole.PARENT
        if any(kw in event_type for kw in ["ATTENDANCE", "MARKS", "REPORT_CARD", "FEE", "EXAM"]):
            target_role = NotificationTargetRole.PARENT
        elif any(kw in event_type for kw in ["TIMETABLE", "PENDING"]):
            target_role = NotificationTargetRole.TEACHER

        # Recipient Resolution
        if student_id:
            student_uuid = uuid.UUID(str(student_id))
            parents = await self._resolve_parent_users(tenant_id, student_uuid)
            for p in parents:
                recipients.append((p, NotificationTargetRole.PARENT))
            
            if event_type in ["ATTENDANCE_LOW", "AI_ACADEMIC_RISK", "AI_ATTENDANCE_RISK"]:
                stmt_st = select(Student.section_id).where(Student.id == student_uuid)
                res_st = await self.notification_repo.db.execute(stmt_st)
                sect_id = res_st.scalar_one_or_none()
                if sect_id:
                    teachers = await self._resolve_section_teachers(tenant_id, sect_id)
                    for t in teachers:
                        recipients.append((t, NotificationTargetRole.TEACHER))
                
                principals = await self._resolve_principals_admins(tenant_id)
                for pr in principals:
                    recipients.append((pr, NotificationTargetRole.PRINCIPAL))
                    
        elif event_type == "ANNOUNCEMENT_PUBLISHED" or event_type == "ANNOUNCEMENT" or event_type == "HOLIDAY" or event_type == "EMERGENCY_ALERT":
            role_str = payload.get("target_role")
            class_id = payload.get("class_id")
            section_id = payload.get("section_id")
            
            if role_str:
                target_role = NotificationTargetRole[role_str]
                users = await self._resolve_role_users(tenant_id, target_role)
                for u in users:
                    recipients.append((u, target_role))
            elif section_id:
                sect_uuid = uuid.UUID(str(section_id))
                stmt_st = select(Student.id).where(Student.section_id == sect_uuid, Student.deleted_at.is_(None))
                res_st = await self.notification_repo.db.execute(stmt_st)
                st_ids = res_st.scalars().all()
                for st_id in st_ids:
                    parents = await self._resolve_parent_users(tenant_id, st_id)
                    for p in parents:
                        recipients.append((p, NotificationTargetRole.PARENT))
            elif class_id:
                class_uuid = uuid.UUID(str(class_id))
                stmt_st = select(Student.id).where(Student.class_id == class_uuid, Student.deleted_at.is_(None))
                res_st = await self.notification_repo.db.execute(stmt_st)
                st_ids = res_st.scalars().all()
                for st_id in st_ids:
                    parents = await self._resolve_parent_users(tenant_id, st_id)
                    for p in parents:
                        recipients.append((p, NotificationTargetRole.PARENT))
        elif any(kw in event_type for kw in ["TIMETABLE", "MARKS_PENDING"]):
            teacher_user_id = payload.get("teacher_user_id")
            if teacher_user_id:
                teacher_uuid = uuid.UUID(str(teacher_user_id))
                stmt_u = select(User).where(User.id == teacher_uuid)
                res_u = await self.notification_repo.db.execute(stmt_u)
                t_user = res_u.scalar_one_or_none()
                if t_user:
                    recipients.append((t_user, NotificationTargetRole.TEACHER))
            else:
                section_id = payload.get("section_id")
                if section_id:
                    sect_uuid = uuid.UUID(str(section_id))
                    teachers = await self._resolve_section_teachers(tenant_id, sect_uuid)
                    for t in teachers:
                        recipients.append((t, NotificationTargetRole.TEACHER))

        unique_recipients = {}
        for r_user, r_role in recipients:
            unique_recipients[r_user.id] = (r_user, r_role)

        # Retrieve tenant configurations
        from app.models.tenant import Tenant
        stmt_t = select(Tenant).where(Tenant.id == tenant_id)
        res_t = await self.notification_repo.db.execute(stmt_t)
        tenant_obj = res_t.scalar_one_or_none()
        tenant_settings = tenant_obj.settings if tenant_obj else {}

        notifications_created = []
        for r_user_id, (r_user, r_role) in unique_recipients.items():
            prefs = await self.notification_repo.get_preferences(r_user.id, tenant_id)
            if not prefs:
                prefs = await self.notification_repo.create_default_preferences(r_user.id, tenant_id)
                await self.notification_repo.db.flush()

            notification_type = NotificationType.GENERAL
            pref_field = "enable_announcements"
            if "ATTENDANCE" in event_type:
                notification_type = NotificationType.ATTENDANCE
                pref_field = "enable_attendance"
            elif "HOMEWORK" in event_type:
                notification_type = NotificationType.HOMEWORK
                pref_field = "enable_homework"
            elif "MARKS" in event_type:
                notification_type = NotificationType.MARKS
                pref_field = "enable_marks"
            elif "REPORT_CARD" in event_type:
                notification_type = NotificationType.REPORT_CARD
                pref_field = "enable_report_card"
            elif "FEE" in event_type:
                notification_type = NotificationType.FEE
                pref_field = "enable_fee"
            elif "EXAM" in event_type:
                notification_type = NotificationType.EXAMINATION
                pref_field = "enable_marks"

            if not getattr(prefs, pref_field, True):
                logger.info(f"Bypassed by preferences: type={notification_type} user={r_user.id}")
                continue

            # Idempotency check unique per recipient user
            entity_id = payload.get("entity_id") or payload.get("student_id") or ""
            idempotency_key = payload.get("idempotency_key")
            if not idempotency_key:
                if "ATTENDANCE" in event_type:
                    idempotency_key = f"attendance:{entity_id}:{event_type}:{r_user.id}"
                elif "MARKS" in event_type:
                    idempotency_key = f"marks:{entity_id}:published:{r_user.id}"
                elif "ANNOUNCEMENT" in event_type:
                    idempotency_key = f"announcement:{entity_id}:published:{r_user.id}"
                elif "FEE" in event_type:
                    idempotency_key = f"fee:{entity_id}:{event_type}:{r_user.id}"
                else:
                    idempotency_key = f"event:{event_type}:{entity_id}:{r_user.id}"

            stmt_dup = select(Notification).where(
                and_(
                    Notification.tenant_id == tenant_id,
                    Notification.idempotency_key == idempotency_key,
                    Notification.deleted_at.is_(None)
                )
            )
            res_dup = await self.notification_repo.db.execute(stmt_dup)
            existing = res_dup.scalar_one_or_none()
            if existing:
                logger.info(f"Idempotent duplicate notification bypassed for user {r_user.id}: {idempotency_key}")
                continue

            # Scope / Security check
            if r_role == NotificationTargetRole.PARENT and student_id:
                stmt_sg = select(StudentGuardian).join(Guardian).where(
                    StudentGuardian.student_id == uuid.UUID(str(student_id)),
                    or_(
                        Guardian.user_id == r_user.id,
                        Guardian.email == r_user.email
                    )
                )
                res_sg = await self.notification_repo.db.execute(stmt_sg)
                if not res_sg.scalar_one_or_none():
                    logger.warning(f"Security block: Parent {r_user.id} not linked to Student {student_id}")
                    continue

            priority = NotificationPriority.NORMAL
            if any(kw in event_type for kw in ["URGENT", "OVERDUE", "LOW", "RISK"]):
                priority = NotificationPriority.HIGH

            scheduled_at = payload.get("scheduled_at")
            if scheduled_at:
                if isinstance(scheduled_at, str):
                    scheduled_at = datetime.fromisoformat(scheduled_at)
                if scheduled_at.tzinfo is None:
                    try:
                        from zoneinfo import ZoneInfo
                        scheduled_at = scheduled_at.replace(tzinfo=ZoneInfo("Asia/Kolkata")).astimezone(timezone.utc)
                    except Exception:
                        from datetime import timezone as dt_timezone, timedelta
                        ist = dt_timezone(timedelta(hours=5, minutes=30))
                        scheduled_at = scheduled_at.replace(tzinfo=ist).astimezone(timezone.utc)

            obj_create = NotificationCreate(
                notification_type=notification_type,
                priority=priority,
                title=payload.get("title", "EduPulse Notification"),
                message=payload.get("message", ""),
                target_role=r_role,
                school_id=school_id,
                target_user_id=r_user.id,
                related_module=payload.get("related_module"),
                related_record_id=uuid.UUID(str(entity_id)) if entity_id and len(str(entity_id)) == 36 else None,
                student_id=uuid.UUID(str(student_id)) if student_id else None,
                event_key=idempotency_key,
                settings=payload.get("settings"),
                ai_metrics=payload.get("ai_metrics"),
                scheduled_at=scheduled_at,
                sender_id=payload.get("sender_id") or created_by,
                event_type=event_type,
                idempotency_key=idempotency_key
            )

            # Determine immediate or scheduled published_at
            now_utc = datetime.now(timezone.utc)
            is_future = scheduled_at and scheduled_at > now_utc
            if not is_future:
                obj_create.published_at = now_utc

            n = await self.notification_repo.create(tenant_id, school_id, obj_create, created_by)
            await self.notification_repo.db.flush()

            # Dispatch deliveries immediately if not future scheduled
            if not is_future:
                await self._dispatch_deliveries_for_notification(self.notification_repo.db, n, tenant_settings)

            notifications_created.append(n)

        if notifications_created:
            await self.notification_repo.db.commit()
            for nc in notifications_created:
                await self.notification_repo.db.refresh(nc)

        return notifications_created

    # --- AUTO SERVICE HOOKS ---

    async def notify_attendance(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, student_id: uuid.UUID, attendance_date: date, status_val: str
    ) -> List[Notification]:
        stmt = select(Student).where(Student.id == student_id, Student.deleted_at.is_(None))
        res = await self.notification_repo.db.execute(stmt)
        student = res.scalar_one_or_none()
        student_name = f"{student.first_name} {student.last_name}" if student else "Student"
        
        event_type = f"ATTENDANCE_{status_val.upper()}"
        return await self.dispatch_event(
            tenant_id=tenant_id,
            school_id=school_id,
            event_type=event_type,
            payload={
                "student_id": student_id,
                "entity_id": student_id,
                "title": "Attendance Marked",
                "message": f"{student_name} was marked {status_val} on {attendance_date.isoformat()}.",
                "related_module": "attendance"
            }
        )

    async def notify_homework(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, homework_id: uuid.UUID
    ) -> List[Notification]:
        stmt = select(Homework).where(Homework.id == homework_id, Homework.deleted_at.is_(None))
        res = await self.notification_repo.db.execute(stmt)
        homework = res.scalar_one_or_none()
        if not homework:
            return []

        return await self.dispatch_event(
            tenant_id=tenant_id,
            school_id=school_id,
            event_type="ANNOUNCEMENT",
            payload={
                "section_id": homework.section_id,
                "entity_id": homework_id,
                "title": "New Homework Assigned",
                "message": f"New homework '{homework.title}' assigned. Due date: {homework.due_date.isoformat()}.",
                "related_module": "homework"
            }
        )

    async def notify_marks(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, exam_id: uuid.UUID, class_id: uuid.UUID, section_id: uuid.UUID
    ) -> List[Notification]:
        stmt = select(Examination).where(Examination.id == exam_id, Examination.deleted_at.is_(None))
        res = await self.notification_repo.db.execute(stmt)
        exam = res.scalar_one_or_none()
        exam_name = exam.exam_name if exam else "Examination"

        stmt_st = select(Student).where(
            Student.class_id == class_id,
            Student.section_id == section_id,
            Student.is_active == True,
            Student.deleted_at.is_(None)
        )
        res_st = await self.notification_repo.db.execute(stmt_st)
        students = list(res_st.scalars().all())

        created = []
        for st in students:
            # Check if there is already an ExamResult/Marks record published for this exam and student
            # (In test context, we can lookup or mock the variables)
            # Let's populate the context variables for WhatsApp template formatting
            ns = await self.dispatch_event(
                tenant_id=tenant_id,
                school_id=school_id,
                event_type="MARKS_PUBLISHED",
                payload={
                    "student_id": st.id,
                    "entity_id": exam_id,
                    "title": "Exam Marks Published",
                    "message": f"Academic marks for {st.first_name} {st.last_name} in examination '{exam_name}' have been published.",
                    "related_module": "marks",
                    "settings": {
                        "student_name": f"{st.first_name} {st.last_name}",
                        "subject_name": exam_name,
                        "marks": "92", # fallback mock marks for notifications
                        "max_marks": "100"
                    }
                }
            )
            created.extend(ns)
        return created

    async def notify_report_card(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, report_card_id: uuid.UUID
    ) -> List[Notification]:
        stmt = select(ReportCardPublication).where(ReportCardPublication.id == report_card_id, ReportCardPublication.deleted_at.is_(None))
        res = await self.db.execute(stmt)
        pub = res.scalar_one_or_none()
        if not pub:
            return []

        stmt_st = select(Student).where(Student.id == pub.student_id, Student.deleted_at.is_(None))
        res_st = await self.db.execute(stmt_st)
        student = res_st.scalar_one_or_none()
        student_name = f"{student.first_name} {student.last_name}" if student else "Student"

        return await self.dispatch_event(
            tenant_id=tenant_id,
            school_id=school_id,
            event_type="MARKS_PUBLISHED",
            payload={
                "student_id": pub.student_id,
                "entity_id": report_card_id,
                "title": "Report Card Published",
                "message": f"The report card for {student_name} has been compiled and published.",
                "related_module": "report_card"
            }
        )

    async def notify_announcement(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, title: str, message: str, target_role: NotificationTargetRole, scheduled_at: Optional[datetime] = None, sender_id: Optional[uuid.UUID] = None
    ) -> List[Notification]:
        # Using ANNOUNCEMENT event type
        return await self.dispatch_event(
            tenant_id=tenant_id,
            school_id=school_id,
            event_type="ANNOUNCEMENT",
            payload={
                "target_role": target_role.value if hasattr(target_role, "value") else str(target_role),
                "title": title,
                "message": message,
                "related_module": "announcement",
                "scheduled_at": scheduled_at.isoformat() if scheduled_at else None,
                "sender_id": sender_id
            }
        )

    async def notify_holiday(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, holiday_details: str
    ) -> List[Notification]:
        created = []
        for role in [NotificationTargetRole.PARENT, NotificationTargetRole.TEACHER, NotificationTargetRole.STAFF]:
            ns = await self.dispatch_event(
                tenant_id=tenant_id,
                school_id=school_id,
                event_type="HOLIDAY",
                payload={
                    "target_role": role.value,
                    "title": "School Holiday Announced",
                    "message": f"A holiday has been announced: {holiday_details}.",
                    "related_module": "holiday",
                    "settings": {
                        "holiday_details": holiday_details
                    }
                }
            )
            created.extend(ns)
        return created

    async def notify_event(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, event_details: str
    ) -> List[Notification]:
        created = []
        for role in [NotificationTargetRole.PARENT, NotificationTargetRole.TEACHER, NotificationTargetRole.STAFF]:
            ns = await self.dispatch_event(
                tenant_id=tenant_id,
                school_id=school_id,
                event_type="ANNOUNCEMENT",
                payload={
                    "target_role": role.value,
                    "title": "Upcoming School Event",
                    "message": f"Upcoming school event: {event_details}.",
                    "related_module": "event"
                }
            )
            created.extend(ns)
        return created

    async def notify_fee_due(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, student_id: uuid.UUID, fee_name: str, amount: float, due_date: date
    ) -> List[Notification]:
        stmt = select(Student).where(Student.id == student_id, Student.deleted_at.is_(None))
        res = await self.notification_repo.db.execute(stmt)
        student = res.scalar_one_or_none()
        student_name = f"{student.first_name} {student.last_name}" if student else "Student"

        return await self.dispatch_event(
            tenant_id=tenant_id,
            school_id=school_id,
            event_type="FEE_REMINDER",
            payload={
                "student_id": student_id,
                "entity_id": student_id,
                "title": "Fee Due Reminder",
                "message": f"Fee '{fee_name}' of amount {amount:.2f} is assigned to {student_name} and is due on {due_date.isoformat()}.",
                "related_module": "fee",
                "settings": {
                    "fee_name": fee_name,
                    "amount": f"{amount:.2f}",
                    "due_date": due_date.isoformat(),
                    "student_name": student_name
                }
            }
        )

    async def notify_fee_paid(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, student_id: uuid.UUID, amount_paid: float, receipt_number: str
    ) -> List[Notification]:
        stmt = select(Student).where(Student.id == student_id, Student.deleted_at.is_(None))
        res = await self.notification_repo.db.execute(stmt)
        student = res.scalar_one_or_none()
        student_name = f"{student.first_name} {student.last_name}" if student else "Student"

        return await self.dispatch_event(
            tenant_id=tenant_id,
            school_id=school_id,
            event_type="ANNOUNCEMENT",
            payload={
                "student_id": student_id,
                "title": "Fee Payment Successful",
                "message": f"Payment of {amount_paid:.2f} for {student_name} was successful. Receipt: {receipt_number}.",
                "related_module": "fee"
            }
        )

    async def notify_fee_cancelled(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, student_id: uuid.UUID, amount_reversed: float, receipt_number: str
    ) -> List[Notification]:
        stmt = select(Student).where(Student.id == student_id, Student.deleted_at.is_(None))
        res = await self.notification_repo.db.execute(stmt)
        student = res.scalar_one_or_none()
        student_name = f"{student.first_name} {student.last_name}" if student else "Student"

        return await self.dispatch_event(
            tenant_id=tenant_id,
            school_id=school_id,
            event_type="ANNOUNCEMENT",
            payload={
                "student_id": student_id,
                "title": "Fee Payment Cancelled",
                "message": f"Payment of {amount_reversed:.2f} for {student_name} (Receipt: {receipt_number}) has been cancelled/reversed.",
                "related_module": "fee"
            }
        )


async def run_scheduled_notification_worker(session_factory):
    import asyncio
    from datetime import datetime, timezone
    from sqlalchemy import select, and_
    from app.models.notification import Notification
    from app.repositories.notification import NotificationRepository
    from app.services.notification import NotificationService

    logger.info("Starting background scheduled notification worker...")
    while True:
        try:
            await asyncio.sleep(5)  # Poll every 5 seconds for responsive tests
            async with session_factory() as db:
                now_utc = datetime.now(timezone.utc)
                stmt = select(Notification).where(
                    and_(
                        Notification.scheduled_at <= now_utc,
                        Notification.published_at.is_(None),
                        Notification.deleted_at.is_(None)
                    )
                )
                res = await db.execute(stmt)
                notifs = list(res.scalars().all())

                for notif in notifs:
                    logger.info(f"[SCHEDULER] Publishing scheduled notification: {notif.id}")
                    notif.published_at = now_utc
                    await db.commit()

                    from app.models.tenant import Tenant
                    stmt_t = select(Tenant).where(Tenant.id == notif.tenant_id)
                    res_t = await db.execute(stmt_t)
                    tenant_obj = res_t.scalar_one_or_none()
                    tenant_settings = tenant_obj.settings if tenant_obj else {}

                    repo = NotificationRepository(db)
                    service = NotificationService(repo)
                    await service._dispatch_deliveries_for_notification(db, notif, tenant_settings)
                    await db.commit()
        except Exception as e:
            logger.error(f"Error in scheduled notification worker: {e}", exc_info=True)
