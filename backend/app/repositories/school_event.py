import uuid
from typing import List, Optional
from datetime import date, datetime, timezone
from sqlalchemy import select, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.school_event import SchoolEvent, EventStatus, EventAudience

class SchoolEventRepository:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(
        self, event_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[SchoolEvent]:
        stmt = select(SchoolEvent).where(
            SchoolEvent.id == event_id,
            SchoolEvent.school_id == school_id,
            SchoolEvent.tenant_id == tenant_id,
            SchoolEvent.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def create(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        event_name: str,
        description: Optional[str],
        event_date: date,
        start_time: any,
        end_time: any,
        venue: Optional[str],
        target_audience: EventAudience,
        status: EventStatus,
        is_holiday: bool,
        created_by: Optional[uuid.UUID] = None
    ) -> SchoolEvent:
        db_obj = SchoolEvent(
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=academic_year_id,
            event_name=event_name,
            description=description,
            event_date=event_date,
            start_time=start_time,
            end_time=end_time,
            venue=venue,
            target_audience=target_audience,
            status=status,
            is_holiday=is_holiday,
            created_by=created_by,
            updated_by=created_by
        )
        self.db.add(db_obj)
        return db_obj

    async def update(
        self, db_obj: SchoolEvent, update_data: dict, updated_by: Optional[uuid.UUID] = None
    ) -> SchoolEvent:
        for field, value in update_data.items():
            setattr(db_obj, field, value)
        db_obj.updated_by = updated_by
        self.db.add(db_obj)
        return db_obj

    async def soft_delete(
        self, db_obj: SchoolEvent, deleted_by: Optional[uuid.UUID] = None
    ) -> SchoolEvent:
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
        status: Optional[EventStatus] = None,
        target_audience: Optional[EventAudience] = None,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[SchoolEvent]:
        filters = [
            SchoolEvent.school_id == school_id,
            SchoolEvent.tenant_id == tenant_id,
            SchoolEvent.deleted_at.is_(None)
        ]
        if academic_year_id:
            filters.append(SchoolEvent.academic_year_id == academic_year_id)
        if status:
            filters.append(SchoolEvent.status == status)
        if target_audience:
            filters.append(SchoolEvent.target_audience == target_audience)
        if start_date:
            filters.append(SchoolEvent.event_date >= start_date)
        if end_date:
            filters.append(SchoolEvent.event_date <= end_date)

        stmt = select(SchoolEvent).where(
            and_(*filters)
        ).order_by(
            SchoolEvent.event_date.asc(),
            SchoolEvent.start_time.asc()
        ).offset(skip).limit(limit)

        result = await self.db.execute(stmt)
        return list(result.scalars().all())
