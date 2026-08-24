import uuid
from typing import List, Optional
from datetime import datetime, timezone
from sqlalchemy import select, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.announcement import Announcement, AnnouncementStatus, AnnouncementAudienceType
from app.models.notification import NotificationTargetRole

class AnnouncementRepository:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(
        self, announcement_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[Announcement]:
        stmt = select(Announcement).where(
            Announcement.id == announcement_id,
            Announcement.school_id == school_id,
            Announcement.tenant_id == tenant_id,
            Announcement.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def create(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        title: str,
        message: str,
        audience_type: AnnouncementAudienceType,
        target_role: Optional[NotificationTargetRole],
        target_class_id: Optional[uuid.UUID],
        target_section_id: Optional[uuid.UUID],
        publish_at: Optional[datetime],
        expires_at: Optional[datetime],
        priority: str,
        attachment_url: Optional[str],
        status: AnnouncementStatus,
        created_by: Optional[uuid.UUID] = None
    ) -> Announcement:
        db_obj = Announcement(
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=academic_year_id,
            title=title,
            message=message,
            audience_type=audience_type,
            target_role=target_role,
            target_class_id=target_class_id,
            target_section_id=target_section_id,
            publish_at=publish_at,
            expires_at=expires_at,
            priority=priority,
            attachment_url=attachment_url,
            status=status,
            created_by=created_by,
            updated_by=created_by
        )
        self.db.add(db_obj)
        return db_obj

    async def update(
        self, db_obj: Announcement, update_data: dict, updated_by: Optional[uuid.UUID] = None
    ) -> Announcement:
        for field, value in update_data.items():
            setattr(db_obj, field, value)
        db_obj.updated_by = updated_by
        self.db.add(db_obj)
        return db_obj

    async def soft_delete(
        self, db_obj: Announcement, deleted_by: Optional[uuid.UUID] = None
    ) -> Announcement:
        db_obj.deleted_at = datetime.now(timezone.utc)
        db_obj.is_active = False
        db_obj.updated_by = deleted_by
        self.db.add(db_obj)
        return db_obj

    async def get_multi(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        academic_year_id: Optional[uuid.UUID] = None,
        status: Optional[AnnouncementStatus] = None,
        audience_type: Optional[AnnouncementAudienceType] = None,
        target_role: Optional[NotificationTargetRole] = None,
        class_id: Optional[uuid.UUID] = None,
        section_id: Optional[uuid.UUID] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[Announcement]:
        filters = [
            Announcement.school_id == school_id,
            Announcement.tenant_id == tenant_id,
            Announcement.deleted_at.is_(None)
        ]
        if academic_year_id:
            filters.append(Announcement.academic_year_id == academic_year_id)
        if status:
            filters.append(Announcement.status == status)
        if audience_type:
            filters.append(Announcement.audience_type == audience_type)
        if target_role:
            filters.append(Announcement.target_role == target_role)
        if class_id:
            filters.append(Announcement.target_class_id == class_id)
        if section_id:
            filters.append(Announcement.target_section_id == section_id)

        stmt = select(Announcement).where(
            and_(*filters)
        ).order_by(
            Announcement.created_at.desc()
        ).offset(skip).limit(limit)

        result = await self.db.execute(stmt)
        return list(result.scalars().all())
