import uuid
from typing import List, Optional
from datetime import date, datetime, timezone
from sqlalchemy import select, and_, or_, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.academic_calendar import AcademicCalendarEvent, CalendarEventType, CalendarEventStatus

class AcademicCalendarRepository:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(
        self, event_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[AcademicCalendarEvent]:
        stmt = select(AcademicCalendarEvent).where(
            AcademicCalendarEvent.id == event_id,
            AcademicCalendarEvent.school_id == school_id,
            AcademicCalendarEvent.tenant_id == tenant_id,
            AcademicCalendarEvent.deleted_at.is_(None)
        )
        res = await self.db.execute(stmt)
        return res.scalar_one_or_none()

    async def get_events(
        self,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        event_types: Optional[List[CalendarEventType]] = None,
        status: Optional[CalendarEventStatus] = None
    ) -> List[AcademicCalendarEvent]:
        stmt = select(AcademicCalendarEvent).where(
            AcademicCalendarEvent.school_id == school_id,
            AcademicCalendarEvent.academic_year_id == academic_year_id,
            AcademicCalendarEvent.deleted_at.is_(None)
        )
        if start_date:
            stmt = stmt.where(AcademicCalendarEvent.event_date >= start_date)
        if end_date:
            stmt = stmt.where(AcademicCalendarEvent.event_date <= end_date)
        if event_types:
            stmt = stmt.where(AcademicCalendarEvent.event_type.in_(event_types))
        if status:
            stmt = stmt.where(AcademicCalendarEvent.status == status)

        stmt = stmt.order_by(AcademicCalendarEvent.event_date.asc())
        res = await self.db.execute(stmt)
        return list(res.scalars().all())

    async def get_events_on_date(
        self,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        target_date: date
    ) -> List[AcademicCalendarEvent]:
        stmt = select(AcademicCalendarEvent).where(
            AcademicCalendarEvent.school_id == school_id,
            AcademicCalendarEvent.academic_year_id == academic_year_id,
            AcademicCalendarEvent.event_date == target_date,
            AcademicCalendarEvent.deleted_at.is_(None)
        )
        res = await self.db.execute(stmt)
        return list(res.scalars().all())

    async def create(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        event_date: date,
        event_type: CalendarEventType,
        title: str,
        description: Optional[str] = None,
        source: str = "SCHOOL_ADMIN",
        source_reference: Optional[str] = None,
        status: CalendarEventStatus = CalendarEventStatus.APPROVED,
        is_non_working_day: bool = True,
        created_by: Optional[uuid.UUID] = None,
        extra_data: Optional[dict] = None
    ) -> AcademicCalendarEvent:
        db_obj = AcademicCalendarEvent(
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=academic_year_id,
            event_date=event_date,
            event_type=event_type,
            title=title,
            description=description,
            source=source,
            source_reference=source_reference,
            status=status,
            is_non_working_day=is_non_working_day,
            created_by=created_by,
            extra_data=extra_data or {}
        )
        self.db.add(db_obj)
        return db_obj

    async def approve(
        self,
        event: AcademicCalendarEvent,
        approved_by: uuid.UUID
    ) -> AcademicCalendarEvent:
        event.status = CalendarEventStatus.APPROVED
        event.approved_by = approved_by
        event.approved_at = datetime.now(timezone.utc)
        self.db.add(event)
        return event

    async def soft_delete(
        self,
        event: AcademicCalendarEvent,
        deleted_by: Optional[uuid.UUID] = None
    ) -> AcademicCalendarEvent:
        event.deleted_at = datetime.now(timezone.utc)
        event.status = CalendarEventStatus.CANCELLED
        self.db.add(event)
        return event
