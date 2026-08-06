import uuid
import logging
from typing import List, Optional, Dict, Any
from datetime import date, datetime, timezone
from sqlalchemy import select, and_, or_, func
from fastapi import HTTPException, status

from app.models.notification import (
    Notification, NotificationPreference, NotificationStatus,
    NotificationType, NotificationPriority, NotificationTargetRole
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

logger = logging.getLogger(__name__)

class NotificationService:
    def __init__(self, notification_repo: NotificationRepository) -> None:
        self.notification_repo = notification_repo

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
            User.status == UserStatus.ACTIVE
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
        if field and not getattr(prefs, field):
            logger.info(f"Notification creation bypassed due to preferences: type={obj_in.notification_type.value} user={obj_in.target_user_id}")
            return None

        return await self.notification_repo.create(tenant_id, school_id, obj_in, created_by)

    # --- AUTO SERVICE HOOKS ---

    async def notify_attendance(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, student_id: uuid.UUID, attendance_date: date, status_val: str
    ) -> List[Notification]:
        # Fetch student details
        stmt = select(Student).where(Student.id == student_id, Student.deleted_at.is_(None))
        res = await self.notification_repo.db.execute(stmt)
        student = res.scalar_one_or_none()
        if not student:
            return []

        parents = await self._resolve_parent_users(tenant_id, student_id)
        created = []
        for p in parents:
            obj_in = NotificationCreate(
                notification_type=NotificationType.ATTENDANCE,
                priority=NotificationPriority.NORMAL,
                title="Attendance Marked",
                message=f"{student.first_name} {student.last_name} was marked {status_val} on {attendance_date.isoformat()}.",
                target_role=NotificationTargetRole.PARENT,
                target_user_id=p.id,
                related_module="attendance",
                related_record_id=student_id
            )
            n = await self._create_user_notification(tenant_id, school_id, obj_in)
            if n:
                created.append(n)
        return created

    async def notify_homework(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, homework_id: uuid.UUID
    ) -> List[Notification]:
        # Fetch homework details
        stmt = select(Homework).where(Homework.id == homework_id, Homework.deleted_at.is_(None))
        res = await self.notification_repo.db.execute(stmt)
        homework = res.scalar_one_or_none()
        if not homework:
            return []

        # Find all students in class/section
        stmt_st = select(Student).where(
            Student.class_id == homework.class_id,
            Student.section_id == homework.section_id,
            Student.is_active == True,
            Student.deleted_at.is_(None)
        )
        res_st = await self.notification_repo.db.execute(stmt_st)
        students = list(res_st.scalars().all())

        created = []
        for st in students:
            parents = await self._resolve_parent_users(tenant_id, st.id)
            for p in parents:
                obj_in = NotificationCreate(
                    notification_type=NotificationType.HOMEWORK,
                    priority=NotificationPriority.NORMAL,
                    title="New Homework Assigned",
                    message=f"New homework '{homework.title}' assigned. Due date: {homework.due_date.isoformat()}.",
                    target_role=NotificationTargetRole.PARENT,
                    target_user_id=p.id,
                    related_module="homework",
                    related_record_id=homework_id
                )
                n = await self._create_user_notification(tenant_id, school_id, obj_in)
                if n:
                    created.append(n)
        return created

    async def notify_marks(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, exam_id: uuid.UUID, class_id: uuid.UUID, section_id: uuid.UUID
    ) -> List[Notification]:
        # Fetch exam details
        stmt = select(Examination).where(Examination.id == exam_id, Examination.deleted_at.is_(None))
        res = await self.notification_repo.db.execute(stmt)
        exam = res.scalar_one_or_none()
        if not exam:
            return []

        # Find all students in class/section
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
            parents = await self._resolve_parent_users(tenant_id, st.id)
            for p in parents:
                obj_in = NotificationCreate(
                    notification_type=NotificationType.MARKS,
                    priority=NotificationPriority.NORMAL,
                    title="Exam Marks Published",
                    message=f"Academic marks for {st.first_name} {st.last_name} in examination '{exam.exam_name}' have been published.",
                    target_role=NotificationTargetRole.PARENT,
                    target_user_id=p.id,
                    related_module="marks",
                    related_record_id=exam_id
                )
                n = await self._create_user_notification(tenant_id, school_id, obj_in)
                if n:
                    created.append(n)
        return created

    async def notify_report_card(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, report_card_id: uuid.UUID
    ) -> List[Notification]:
        # Fetch report card details
        stmt = select(ReportCardPublication).where(ReportCardPublication.id == report_card_id, ReportCardPublication.deleted_at.is_(None))
        res = await self.notification_repo.db.execute(stmt)
        pub = res.scalar_one_or_none()
        if not pub:
            return []

        # Fetch student
        stmt_st = select(Student).where(Student.id == pub.student_id, Student.deleted_at.is_(None))
        res_st = await self.notification_repo.db.execute(stmt_st)
        student = res_st.scalar_one_or_none()
        if not student:
            return []

        parents = await self._resolve_parent_users(tenant_id, pub.student_id)
        created = []
        for p in parents:
            obj_in = NotificationCreate(
                notification_type=NotificationType.REPORT_CARD,
                priority=NotificationPriority.HIGH,
                title="Report Card Published",
                message=f"The report card for {student.first_name} {student.last_name} has been compiled and published.",
                target_role=NotificationTargetRole.PARENT,
                target_user_id=p.id,
                related_module="report_card",
                related_record_id=report_card_id
            )
            n = await self._create_user_notification(tenant_id, school_id, obj_in)
            if n:
                created.append(n)
        return created

    async def notify_announcement(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, title: str, message: str, target_role: NotificationTargetRole
    ) -> List[Notification]:
        logger.info(f"notify_announcement called: tenant_id={tenant_id}, school_id={school_id}, title={title}, target_role={target_role}")
        users = await self._resolve_role_users(tenant_id, target_role)
        created = []
        for u in users:
            obj_in = NotificationCreate(
                notification_type=NotificationType.ANNOUNCEMENT,
                priority=NotificationPriority.NORMAL,
                title=title,
                message=message,
                target_role=target_role,
                target_user_id=u.id,
                related_module="announcement"
            )
            n = await self._create_user_notification(tenant_id, school_id, obj_in)
            if n:
                created.append(n)
        return created

    async def notify_holiday(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, holiday_details: str
    ) -> List[Notification]:
        created = []
        for role in [NotificationTargetRole.PARENT, NotificationTargetRole.TEACHER, NotificationTargetRole.STAFF]:
            users = await self._resolve_role_users(tenant_id, role)
            for u in users:
                obj_in = NotificationCreate(
                    notification_type=NotificationType.HOLIDAY,
                    priority=NotificationPriority.NORMAL,
                    title="School Holiday Announced",
                    message=f"A holiday has been announced: {holiday_details}.",
                    target_role=role,
                    target_user_id=u.id,
                    related_module="holiday"
                )
                n = await self._create_user_notification(tenant_id, school_id, obj_in)
                if n:
                    created.append(n)
        return created

    async def notify_event(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, event_details: str
    ) -> List[Notification]:
        created = []
        for role in [NotificationTargetRole.PARENT, NotificationTargetRole.TEACHER, NotificationTargetRole.STAFF]:
            users = await self._resolve_role_users(tenant_id, role)
            for u in users:
                obj_in = NotificationCreate(
                    notification_type=NotificationType.EVENT,
                    priority=NotificationPriority.NORMAL,
                    title="Upcoming School Event",
                    message=f"Upcoming school event: {event_details}.",
                    target_role=role,
                    target_user_id=u.id,
                    related_module="event"
                )
                n = await self._create_user_notification(tenant_id, school_id, obj_in)
                if n:
                    created.append(n)
        return created

    async def notify_fee_due(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, student_id: uuid.UUID, fee_name: str, amount: float, due_date: date
    ) -> List[Notification]:
        stmt = select(Student).where(Student.id == student_id, Student.deleted_at.is_(None))
        res = await self.notification_repo.db.execute(stmt)
        student = res.scalar_one_or_none()
        if not student:
            return []

        parents = await self._resolve_parent_users(tenant_id, student_id)
        created = []
        for p in parents:
            obj_in = NotificationCreate(
                notification_type=NotificationType.FEE,
                priority=NotificationPriority.HIGH,
                title="Fee Due Reminder",
                message=f"Fee '{fee_name}' of amount {amount:.2f} is assigned to {student.first_name} {student.last_name} and is due on {due_date.isoformat()}.",
                target_role=NotificationTargetRole.PARENT,
                target_user_id=p.id,
                related_module="fee",
                related_record_id=student_id
            )
            n = await self._create_user_notification(tenant_id, school_id, obj_in)
            if n:
                created.append(n)
        return created

    async def notify_fee_paid(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, student_id: uuid.UUID, amount_paid: float, receipt_number: str
    ) -> List[Notification]:
        stmt = select(Student).where(Student.id == student_id, Student.deleted_at.is_(None))
        res = await self.notification_repo.db.execute(stmt)
        student = res.scalar_one_or_none()
        if not student:
            return []

        parents = await self._resolve_parent_users(tenant_id, student_id)
        created = []
        for p in parents:
            obj_in = NotificationCreate(
                notification_type=NotificationType.FEE,
                priority=NotificationPriority.NORMAL,
                title="Fee Payment Successful",
                message=f"Payment of {amount_paid:.2f} for {student.first_name} {student.last_name} was successful. Receipt: {receipt_number}.",
                target_role=NotificationTargetRole.PARENT,
                target_user_id=p.id,
                related_module="fee",
                related_record_id=student_id
            )
            n = await self._create_user_notification(tenant_id, school_id, obj_in)
            if n:
                created.append(n)
        return created

    async def notify_fee_cancelled(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, student_id: uuid.UUID, amount_reversed: float, receipt_number: str
    ) -> List[Notification]:
        stmt = select(Student).where(Student.id == student_id, Student.deleted_at.is_(None))
        res = await self.notification_repo.db.execute(stmt)
        student = res.scalar_one_or_none()
        if not student:
            return []

        parents = await self._resolve_parent_users(tenant_id, student_id)
        created = []
        for p in parents:
            obj_in = NotificationCreate(
                notification_type=NotificationType.FEE,
                priority=NotificationPriority.HIGH,
                title="Fee Payment Cancelled",
                message=f"Payment of {amount_reversed:.2f} for {student.first_name} {student.last_name} (Receipt: {receipt_number}) has been cancelled/reversed.",
                target_role=NotificationTargetRole.PARENT,
                target_user_id=p.id,
                related_module="fee",
                related_record_id=student_id
            )
            n = await self._create_user_notification(tenant_id, school_id, obj_in)
            if n:
                created.append(n)
        return created
