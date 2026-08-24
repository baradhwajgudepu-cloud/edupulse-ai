import uuid
from typing import List, Optional
from datetime import datetime, timezone
from fastapi import HTTPException, status

from app.models.announcement import Announcement, AnnouncementStatus, AnnouncementAudienceType
from app.models.user import User
from app.models.notification import NotificationTargetRole
from app.repositories.announcement import AnnouncementRepository
from app.schemas.announcement import AnnouncementCreate, AnnouncementUpdate
from app.services.notification import NotificationService

class AnnouncementService:
    def __init__(self, announcement_repo: AnnouncementRepository) -> None:
        self.announcement_repo = announcement_repo

    async def create_announcement(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: Optional[uuid.UUID],
        obj_in: AnnouncementCreate,
        current_user: User
    ) -> Announcement:
        if not academic_year_id:
            from app.models.academic_year import AcademicYear, AcademicYearStatus
            from sqlalchemy import select
            ay_stmt = select(AcademicYear).where(
                AcademicYear.school_id == school_id,
                AcademicYear.status == AcademicYearStatus.ACTIVE,
                AcademicYear.deleted_at.is_(None)
            )
            ay_res = await self.announcement_repo.db.execute(ay_stmt)
            ay = ay_res.scalars().first()
            if not ay:
                ay_stmt_fallback = select(AcademicYear).where(
                    AcademicYear.school_id == school_id,
                    AcademicYear.deleted_at.is_(None)
                )
                ay_res_fallback = await self.announcement_repo.db.execute(ay_stmt_fallback)
                ay = ay_res_fallback.scalars().first()
                if not ay:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="No academic year found for this school."
                    )
            academic_year_id = ay.id
        db_obj = await self.announcement_repo.create(
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=academic_year_id,
            title=obj_in.title,
            message=obj_in.message,
            audience_type=obj_in.audience_type,
            target_role=obj_in.target_role,
            target_class_id=obj_in.target_class_id,
            target_section_id=obj_in.target_section_id,
            publish_at=obj_in.publish_at,
            expires_at=obj_in.expires_at,
            priority=obj_in.priority.value,
            attachment_url=obj_in.attachment_url,
            status=AnnouncementStatus.DRAFT,
            created_by=current_user.id
        )
        await self.announcement_repo.db.commit()
        await self.announcement_repo.db.refresh(db_obj)
        return db_obj

    async def update_announcement(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        announcement_id: uuid.UUID,
        obj_in: AnnouncementUpdate,
        current_user: User
    ) -> Announcement:
        db_obj = await self.announcement_repo.get_by_id(announcement_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Announcement not found."
            )

        update_data = obj_in.model_dump(exclude_unset=True)
        updated = await self.announcement_repo.update(db_obj, update_data, updated_by=current_user.id)
        await self.announcement_repo.db.commit()
        await self.announcement_repo.db.refresh(updated)
        return updated

    async def delete_announcement(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        announcement_id: uuid.UUID,
        current_user: User
    ) -> Announcement:
        db_obj = await self.announcement_repo.get_by_id(announcement_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Announcement not found."
            )

        deleted = await self.announcement_repo.soft_delete(db_obj, deleted_by=current_user.id)
        await self.announcement_repo.db.commit()
        await self.announcement_repo.db.refresh(deleted)
        return deleted

    async def publish_announcement(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        announcement_id: uuid.UUID,
        current_user: User,
        notification_service: NotificationService
    ) -> Announcement:
        db_obj = await self.announcement_repo.get_by_id(announcement_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Announcement not found."
            )

        if db_obj.status == AnnouncementStatus.PUBLISHED:
            return db_obj

        # Update status
        db_obj.status = AnnouncementStatus.PUBLISHED
        db_obj.publish_at = datetime.now(timezone.utc)
        db_obj.updated_by = current_user.id
        await self.announcement_repo.db.commit()
        await self.announcement_repo.db.refresh(db_obj)

        # Trigger notification dispatch
        payload = {
            "title": db_obj.title,
            "message": db_obj.message,
            "related_module": "announcement",
            "entity_id": str(db_obj.id)
        }

        if db_obj.audience_type == AnnouncementAudienceType.ROLE and db_obj.target_role:
            payload["target_role"] = db_obj.target_role.value
        elif db_obj.audience_type == AnnouncementAudienceType.CLASS and db_obj.target_class_id:
            payload["class_id"] = str(db_obj.target_class_id)
        elif db_obj.audience_type == AnnouncementAudienceType.SECTION and db_obj.target_section_id:
            payload["section_id"] = str(db_obj.target_section_id)

        await notification_service.dispatch_event(
            tenant_id=tenant_id,
            school_id=school_id,
            event_type="ANNOUNCEMENT_PUBLISHED",
            payload=payload,
            created_by=current_user.id
        )

        return db_obj
