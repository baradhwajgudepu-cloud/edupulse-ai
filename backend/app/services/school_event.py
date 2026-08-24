import uuid
from typing import List, Optional
from datetime import date, datetime, timezone
from fastapi import HTTPException, status

from app.models.school_event import SchoolEvent, EventStatus, EventAudience
from app.models.user import User
from app.models.notification import NotificationTargetRole
from app.repositories.school_event import SchoolEventRepository
from app.schemas.school_event import SchoolEventCreate, SchoolEventUpdate
from app.services.notification import NotificationService

class SchoolEventService:
    def __init__(self, event_repo: SchoolEventRepository) -> None:
        self.event_repo = event_repo

    async def create_event(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: Optional[uuid.UUID],
        obj_in: SchoolEventCreate,
        current_user: User
    ) -> SchoolEvent:
        if not academic_year_id:
            from app.models.academic_year import AcademicYear, AcademicYearStatus
            from sqlalchemy import select
            ay_stmt = select(AcademicYear).where(
                AcademicYear.school_id == school_id,
                AcademicYear.status == AcademicYearStatus.ACTIVE,
                AcademicYear.deleted_at.is_(None)
            )
            ay_res = await self.event_repo.db.execute(ay_stmt)
            ay = ay_res.scalars().first()
            if not ay:
                ay_stmt_fallback = select(AcademicYear).where(
                    AcademicYear.school_id == school_id,
                    AcademicYear.deleted_at.is_(None)
                )
                ay_res_fallback = await self.event_repo.db.execute(ay_stmt_fallback)
                ay = ay_res_fallback.scalars().first()
                if not ay:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="No academic year found for this school."
                    )
            academic_year_id = ay.id

        if obj_in.end_time < obj_in.start_time and obj_in.event_date == obj_in.event_date:
            # Simple validation check
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Event end time cannot be earlier than start time on the same date."
            )

        db_obj = await self.event_repo.create(
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=academic_year_id,
            event_name=obj_in.event_name,
            description=obj_in.description,
            event_date=obj_in.event_date,
            start_time=obj_in.start_time,
            end_time=obj_in.end_time,
            venue=obj_in.venue,
            target_audience=obj_in.target_audience,
            status=EventStatus.DRAFT,
            is_holiday=obj_in.is_holiday,
            created_by=current_user.id
        )
        await self.event_repo.db.commit()
        await self.event_repo.db.refresh(db_obj)
        return db_obj

    async def update_event(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        event_id: uuid.UUID,
        obj_in: SchoolEventUpdate,
        current_user: User
    ) -> SchoolEvent:
        db_obj = await self.event_repo.get_by_id(event_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="School Event not found."
            )

        update_data = obj_in.model_dump(exclude_unset=True)
        updated = await self.event_repo.update(db_obj, update_data, updated_by=current_user.id)
        await self.event_repo.db.commit()
        await self.event_repo.db.refresh(updated)
        return updated

    async def delete_event(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        event_id: uuid.UUID,
        current_user: User
    ) -> SchoolEvent:
        db_obj = await self.event_repo.get_by_id(event_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="School Event not found."
            )

        deleted = await self.event_repo.soft_delete(db_obj, deleted_by=current_user.id)
        await self.event_repo.db.commit()
        await self.event_repo.db.refresh(deleted)
        return deleted

    async def publish_event(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        event_id: uuid.UUID,
        current_user: User,
        notification_service: NotificationService
    ) -> SchoolEvent:
        db_obj = await self.event_repo.get_by_id(event_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="School Event not found."
            )

        if db_obj.status == EventStatus.PUBLISHED:
            return db_obj

        # Update status
        db_obj.status = EventStatus.PUBLISHED
        db_obj.updated_by = current_user.id
        await self.event_repo.db.commit()
        await self.event_repo.db.refresh(db_obj)

        # Trigger notification distribution
        roles = []
        if db_obj.target_audience == EventAudience.ALL:
            roles = [NotificationTargetRole.PARENT, NotificationTargetRole.TEACHER, NotificationTargetRole.STAFF]
        elif db_obj.target_audience == EventAudience.TEACHERS:
            roles = [NotificationTargetRole.TEACHER]
        elif db_obj.target_audience == EventAudience.PARENTS:
            roles = [NotificationTargetRole.PARENT]
        elif db_obj.target_audience == EventAudience.STUDENTS:
            roles = [NotificationTargetRole.PARENT]

        for role in roles:
            await notification_service.dispatch_event(
                tenant_id=tenant_id,
                school_id=school_id,
                event_type="ANNOUNCEMENT_PUBLISHED",
                payload={
                    "target_role": role.value,
                    "title": f"New Event: {db_obj.event_name}",
                    "message": f"Event scheduled at {db_obj.venue or 'School'} on {db_obj.event_date.isoformat()} from {db_obj.start_time.isoformat()} to {db_obj.end_time.isoformat()}.",
                    "related_module": "event",
                    "entity_id": str(db_obj.id)
                },
                created_by=current_user.id
            )

        return db_obj
