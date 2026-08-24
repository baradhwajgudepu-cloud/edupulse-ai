import uuid
from typing import List, Optional, Dict, Any
from datetime import datetime, date, timezone
from sqlalchemy import select, and_, or_, func, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.notification import (
    Notification, NotificationPreference, NotificationStatus,
    NotificationType, NotificationPriority, NotificationTargetRole, UserDeviceToken
)
from app.schemas.notification import NotificationCreate, NotificationPreferenceUpdate

import logging
logger = logging.getLogger(__name__)

class NotificationRepository:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def create(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, obj_in: NotificationCreate, created_by: Optional[uuid.UUID] = None
    ) -> Notification:
        logger.info(
            f"NotificationRepository.create called: tenant_id={tenant_id}, school_id={school_id}, "
            f"notification_type={obj_in.notification_type}, priority={obj_in.priority}, target_role={obj_in.target_role}, "
            f"target_user_id={obj_in.target_user_id}, created_by={created_by}"
        )
        db_obj = Notification(
            tenant_id=tenant_id,
            school_id=school_id,
            notification_type=obj_in.notification_type,
            priority=obj_in.priority,
            title=obj_in.title,
            message=obj_in.message,
            target_role=obj_in.target_role,
            target_user_id=obj_in.target_user_id,
            related_module=obj_in.related_module,
            related_record_id=obj_in.related_record_id,
            student_id=obj_in.student_id,
            event_key=obj_in.event_key,
            settings=obj_in.settings or {},
            ai_metrics=obj_in.ai_metrics or {},
            push_status="NOT_CONFIGURED",
            email_status="NOT_CONFIGURED",
            sms_status="NOT_CONFIGURED",
            status=NotificationStatus.UNREAD,
            created_by=created_by,
            updated_by=created_by,
            scheduled_at=obj_in.scheduled_at,
            published_at=obj_in.published_at,
            sender_id=obj_in.sender_id,
            event_type=obj_in.event_type,
            idempotency_key=obj_in.idempotency_key
        )
        self.db.add(db_obj)
        return db_obj

    async def bulk_create(self, notifications: List[Notification]) -> List[Notification]:
        self.db.add_all(notifications)
        return notifications

    async def get_by_id(
        self, id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[Notification]:
        stmt = select(Notification).where(
            Notification.id == id,
            Notification.tenant_id == tenant_id,
            Notification.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

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
        # Formulate query matching targeted user OR broadcast matching user's roles
        role_enum_values = []
        for r in user_roles:
            try:
                role_enum_values.append(NotificationTargetRole[r])
            except KeyError:
                pass

        conditions = [
            Notification.tenant_id == tenant_id,
            Notification.deleted_at.is_(None),
            Notification.is_active.is_(True),
            or_(
                Notification.scheduled_at.is_(None),
                Notification.published_at.is_not(None)
            ),
            or_(
                Notification.target_user_id == user_id,
                and_(
                    Notification.target_user_id.is_(None),
                    Notification.target_role.in_(role_enum_values)
                )
            )
        ]

        if notification_type:
            conditions.append(Notification.notification_type == notification_type)
        if priority:
            conditions.append(Notification.priority == priority)
        if status:
            conditions.append(Notification.status == status)
        if filter_date:
            conditions.append(func.date(Notification.created_at) == filter_date)

        stmt = select(Notification).where(and_(*conditions)).order_by(
            Notification.created_at.desc()
        ).offset(skip).limit(limit)

        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def get_unread(
        self, tenant_id: uuid.UUID, user_id: uuid.UUID, user_roles: List[str]
    ) -> List[Notification]:
        return await self.get_multi(
            tenant_id=tenant_id,
            user_id=user_id,
            user_roles=user_roles,
            status=NotificationStatus.UNREAD
        )

    async def count_unread(
        self, tenant_id: uuid.UUID, user_id: uuid.UUID, user_roles: List[str]
    ) -> int:
        role_enum_values = []
        for r in user_roles:
            try:
                role_enum_values.append(NotificationTargetRole[r])
            except KeyError:
                pass

        stmt = select(func.count(Notification.id)).where(
            Notification.tenant_id == tenant_id,
            Notification.deleted_at.is_(None),
            Notification.is_active.is_(True),
            Notification.status == NotificationStatus.UNREAD,
            or_(
                Notification.scheduled_at.is_(None),
                Notification.published_at.is_not(None)
            ),
            or_(
                Notification.target_user_id == user_id,
                and_(
                    Notification.target_user_id.is_(None),
                    Notification.target_role.in_(role_enum_values)
                )
            )
        )
        result = await self.db.execute(stmt)
        return result.scalar() or 0

    async def mark_read(
        self, id: uuid.UUID, tenant_id: uuid.UUID, updated_by: uuid.UUID
    ) -> Optional[Notification]:
        db_obj = await self.get_by_id(id, tenant_id)
        if db_obj:
            db_obj.status = NotificationStatus.READ
            db_obj.updated_by = updated_by
            self.db.add(db_obj)
        return db_obj

    async def mark_all_read(
        self, tenant_id: uuid.UUID, user_id: uuid.UUID, user_roles: List[str], updated_by: uuid.UUID
    ) -> int:
        role_enum_values = []
        for r in user_roles:
            try:
                role_enum_values.append(NotificationTargetRole[r])
            except KeyError:
                pass

        # Load all unread notifications matching target conditions
        stmt = select(Notification).where(
            Notification.tenant_id == tenant_id,
            Notification.deleted_at.is_(None),
            Notification.is_active.is_(True),
            Notification.status == NotificationStatus.UNREAD,
            or_(
                Notification.target_user_id == user_id,
                and_(
                    Notification.target_user_id.is_(None),
                    Notification.target_role.in_(role_enum_values)
                )
            )
        )
        res = await self.db.execute(stmt)
        unread_notifications = list(res.scalars().all())

        now = datetime.now(timezone.utc)
        for n in unread_notifications:
            n.status = NotificationStatus.READ
            n.updated_by = updated_by
            n.updated_at = now
            self.db.add(n)

        return len(unread_notifications)

    async def archive(
        self, id: uuid.UUID, tenant_id: uuid.UUID, updated_by: uuid.UUID
    ) -> Optional[Notification]:
        db_obj = await self.get_by_id(id, tenant_id)
        if db_obj:
            db_obj.status = NotificationStatus.ARCHIVED
            db_obj.updated_by = updated_by
            self.db.add(db_obj)
        return db_obj

    async def soft_delete(
        self, id: uuid.UUID, tenant_id: uuid.UUID, deleted_by: uuid.UUID
    ) -> Optional[Notification]:
        db_obj = await self.get_by_id(id, tenant_id)
        if db_obj:
            db_obj.deleted_at = datetime.now(timezone.utc)
            db_obj.updated_by = deleted_by
            self.db.add(db_obj)
        return db_obj

    # --- PREFERENCES METHODS ---

    async def get_preferences(
        self, user_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[NotificationPreference]:
        stmt = select(NotificationPreference).where(
            NotificationPreference.user_id == user_id,
            NotificationPreference.tenant_id == tenant_id,
            NotificationPreference.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def create_default_preferences(
        self, user_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> NotificationPreference:
        pref = NotificationPreference(
            tenant_id=tenant_id,
            user_id=user_id,
            enable_homework=True,
            enable_attendance=True,
            enable_marks=True,
            enable_report_card=True,
            enable_announcements=True,
            enable_events=True,
            enable_fee=True,
            enable_push=True,
            enable_email=True,
            enable_sms=True,
            enable_whatsapp=True,
            enable_in_app=True
        )
        self.db.add(pref)
        return pref

    async def update_preferences(
        self,
        user_id: uuid.UUID,
        tenant_id: uuid.UUID,
        obj_in: NotificationPreferenceUpdate,
        updated_by: uuid.UUID
    ) -> NotificationPreference:
        pref = await self.get_preferences(user_id, tenant_id)
        if not pref:
            pref = await self.create_default_preferences(user_id, tenant_id)
            await self.db.flush()

        update_dict = obj_in.model_dump(exclude_unset=True)
        for k, v in update_dict.items():
            setattr(pref, k, v)
        pref.updated_by = updated_by
        pref.updated_at = datetime.now(timezone.utc)

        self.db.add(pref)
        return pref

    async def register_device_token(
        self,
        tenant_id: uuid.UUID,
        user_id: uuid.UUID,
        device_token: str,
        platform: str,
        app_type: str
    ) -> UserDeviceToken:
        stmt = select(UserDeviceToken).where(
            UserDeviceToken.tenant_id == tenant_id,
            UserDeviceToken.user_id == user_id,
            UserDeviceToken.device_token == device_token,
            UserDeviceToken.deleted_at.is_(None)
        )
        res = await self.db.execute(stmt)
        token_obj = res.scalar_one_or_none()
        
        now = datetime.now(timezone.utc)
        if token_obj:
            token_obj.platform = platform
            token_obj.app_type = app_type
            token_obj.last_seen_at = now
            token_obj.is_active = True
            token_obj.updated_at = now
        else:
            token_obj = UserDeviceToken(
                tenant_id=tenant_id,
                user_id=user_id,
                device_token=device_token,
                platform=platform,
                app_type=app_type,
                last_seen_at=now,
                is_active=True,
                created_by=user_id,
                updated_by=user_id
            )
        self.db.add(token_obj)
        return token_obj

    async def deactivate_device_token(
        self,
        tenant_id: uuid.UUID,
        user_id: uuid.UUID,
        device_token: str
    ) -> Optional[UserDeviceToken]:
        stmt = select(UserDeviceToken).where(
            UserDeviceToken.tenant_id == tenant_id,
            UserDeviceToken.user_id == user_id,
            UserDeviceToken.device_token == device_token,
            UserDeviceToken.deleted_at.is_(None)
        )
        res = await self.db.execute(stmt)
        token_obj = res.scalar_one_or_none()
        
        if token_obj:
            token_obj.is_active = False
            token_obj.updated_at = datetime.now(timezone.utc)
            token_obj.updated_by = user_id
            self.db.add(token_obj)
        return token_obj
