import uuid
from typing import List, Dict, Any, Optional
from datetime import date, datetime, timedelta, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_

from app.models.academic_calendar import AcademicCalendarEvent, CalendarEventType, CalendarEventStatus
from app.models.state_holiday_master import StateHolidayMaster
from app.models.school import School
from app.models.academic_year import AcademicYear
from app.models.examination import Examination, ExamSchedule
from app.repositories.academic_calendar import AcademicCalendarRepository
from app.repositories.state_holiday_master import StateHolidayMasterRepository
from app.schemas.academic_calendar import (
    CalendarEventResponse, StateHolidayStatusResponse,
    WorkingDaysCalculationResponse, HolidayImpactResponse
)

class AcademicCalendarService:
    """
    Core service orchestrating:
    1. Verified State Public Holiday population
    2. School and Principal-declared Holidays
    3. Authoritative Unified Working-Day Calculation (shared across all modules)
    4. Examination Conflict Detection
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.calendar_repo = AcademicCalendarRepository(db)
        self.state_holiday_repo = StateHolidayMasterRepository(db)

    async def get_state_holiday_status(
        self, state: str, academic_year_code: str
    ) -> StateHolidayStatusResponse:
        await self.state_holiday_repo.seed_verified_defaults_if_empty()
        holidays = await self.state_holiday_repo.get_holidays(state, academic_year_code)
        if holidays:
            first_h = holidays[0]
            return StateHolidayStatusResponse(
                state=state,
                academic_year_code=academic_year_code,
                is_verified=True,
                source=first_h.source,
                source_version=first_h.source_version,
                holidays_count=len(holidays),
                message=f"Verified public holiday calendar found from {first_h.source} ({first_h.source_version}).",
                can_import=False
            )
        return StateHolidayStatusResponse(
            state=state,
            academic_year_code=academic_year_code,
            is_verified=False,
            source=None,
            source_version=None,
            holidays_count=0,
            message="Public holiday calendar could not be verified.",
            can_import=True
        )

    async def populate_state_holidays(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        state: str,
        academic_year_code: str,
        created_by: Optional[uuid.UUID] = None
    ) -> Dict[str, Any]:
        await self.state_holiday_repo.seed_verified_defaults_if_empty()
        holidays = await self.state_holiday_repo.get_holidays(state, academic_year_code)
        if not holidays:
            return {
                "success": False,
                "is_verified": False,
                "count": 0,
                "message": "Public holiday calendar could not be verified.",
                "can_import": True
            }

        # Check existing events to avoid duplicating
        existing_events = await self.calendar_repo.get_events(
            school_id=school_id,
            academic_year_id=academic_year_id,
            event_types=[CalendarEventType.PUBLIC_HOLIDAY]
        )
        existing_dates = {e.event_date for e in existing_events}

        created_count = 0
        for h in holidays:
            if h.holiday_date not in existing_dates:
                await self.calendar_repo.create(
                    tenant_id=tenant_id,
                    school_id=school_id,
                    academic_year_id=academic_year_id,
                    event_date=h.holiday_date,
                    event_type=CalendarEventType.PUBLIC_HOLIDAY,
                    title=h.holiday_name,
                    description=h.description,
                    source=h.source,
                    source_reference=h.source_version,
                    status=CalendarEventStatus.APPROVED,
                    is_non_working_day=True,
                    created_by=created_by,
                    extra_data={
                        "state": h.state,
                        "academic_year_code": h.academic_year_code,
                        "verification_status": h.verification_status,
                        "source_date": h.source_date.isoformat() if h.source_date else None
                    }
                )
                created_count += 1

        await self.db.flush()
        first_h = holidays[0]
        return {
            "success": True,
            "is_verified": True,
            "count": created_count,
            "total_holidays": len(holidays),
            "source": first_h.source,
            "source_version": first_h.source_version,
            "message": f"Successfully populated {created_count} verified state public holidays."
        }

    async def create_school_holiday(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        event_date: date,
        title: str,
        description: Optional[str] = None,
        created_by: Optional[uuid.UUID] = None
    ) -> AcademicCalendarEvent:
        event = await self.calendar_repo.create(
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=academic_year_id,
            event_date=event_date,
            event_type=CalendarEventType.SCHOOL_HOLIDAY,
            title=title,
            description=description,
            source="SCHOOL_ADMIN",
            status=CalendarEventStatus.APPROVED,
            is_non_working_day=True,
            created_by=created_by
        )
        await self.db.flush()
        return event

    async def declare_principal_holiday(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        event_date: date,
        title: str,
        reason: Optional[str] = None,
        auto_approve: bool = True,
        created_by: Optional[uuid.UUID] = None
    ) -> AcademicCalendarEvent:
        status = CalendarEventStatus.APPROVED if auto_approve else CalendarEventStatus.DRAFT
        event = await self.calendar_repo.create(
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=academic_year_id,
            event_date=event_date,
            event_type=CalendarEventType.PRINCIPAL_DECLARED_HOLIDAY,
            title=title,
            description=reason,
            source="PRINCIPAL",
            status=status,
            is_non_working_day=True,
            created_by=created_by,
            extra_data={"declared_by_principal": True, "reason": reason}
        )
        if auto_approve and created_by:
            event.approved_by = created_by
            event.approved_at = datetime.now(timezone.utc)

        await self.db.flush()
        return event

    async def approve_holiday(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        event_id: uuid.UUID,
        approved_by: uuid.UUID
    ) -> AcademicCalendarEvent:
        event = await self.calendar_repo.get_by_id(event_id, school_id, tenant_id)
        if not event:
            raise ValueError("Holiday event not found.")

        event.status = CalendarEventStatus.APPROVED
        event.approved_by = approved_by
        event.approved_at = datetime.now(timezone.utc)
        event.is_non_working_day = True
        self.db.add(event)
        await self.db.flush()
        return event

    async def calculate_working_days(
        self,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        start_date: date,
        end_date: date
    ) -> WorkingDaysCalculationResponse:
        """
        Authoritative unified calculation of working days.
        Used consistently by:
        - Timetable AI Engine
        - Syllabus Prediction Engine
        - Examination Scheduling
        - Academic Calendar views
        """
        if start_date > end_date:
            start_date, end_date = end_date, start_date

        # 1. Fetch school and academic year settings
        school = await self.db.get(School, school_id)
        school_settings = school.settings or {} if school else {}
        saturday_policy = school_settings.get("saturday_policy", "SECOND_FOURTH_OFF")

        # 2. Fetch all approved/published calendar events in date range
        events = await self.calendar_repo.get_events(
            school_id=school_id,
            academic_year_id=academic_year_id,
            start_date=start_date,
            end_date=end_date,
            status=CalendarEventStatus.APPROVED
        )

        special_working_dates = {e.event_date for e in events if e.event_type == CalendarEventType.SPECIAL_WORKING_DAY}
        holiday_events_by_date = {
            e.event_date: e for e in events
            if e.is_non_working_day and e.event_type in (
                CalendarEventType.PUBLIC_HOLIDAY,
                CalendarEventType.SCHOOL_HOLIDAY,
                CalendarEventType.PRINCIPAL_DECLARED_HOLIDAY
            )
        }

        # 3. Iterate day-by-day
        cur_dt = start_date
        working_dates: List[date] = []
        breakdown = {
            "public_holidays": 0,
            "school_holidays": 0,
            "principal_holidays": 0,
            "sundays": 0,
            "saturdays_off": 0,
            "special_working_days": 0
        }

        total_calendar_days = 0

        while cur_dt <= end_date:
            total_calendar_days += 1

            # Rule 1: Special working day explicitly overrides any weekend or normal holiday
            if cur_dt in special_working_dates:
                working_dates.append(cur_dt)
                breakdown["special_working_days"] += 1
                cur_dt += timedelta(days=1)
                continue

            # Rule 2: Explicit calendar holiday
            if cur_dt in holiday_events_by_date:
                h_type = holiday_events_by_date[cur_dt].event_type
                if h_type == CalendarEventType.PUBLIC_HOLIDAY:
                    breakdown["public_holidays"] += 1
                elif h_type == CalendarEventType.SCHOOL_HOLIDAY:
                    breakdown["school_holidays"] += 1
                elif h_type == CalendarEventType.PRINCIPAL_DECLARED_HOLIDAY:
                    breakdown["principal_holidays"] += 1
                cur_dt += timedelta(days=1)
                continue

            # Rule 3: Weekend checks
            weekday = cur_dt.weekday()  # Monday=0, Sunday=6
            if weekday == 6:  # Sunday is always non-working
                breakdown["sundays"] += 1
                cur_dt += timedelta(days=1)
                continue

            if weekday == 5:  # Saturday
                if saturday_policy == "ALL_OFF":
                    breakdown["saturdays_off"] += 1
                    cur_dt += timedelta(days=1)
                    continue
                elif saturday_policy == "ALL_WORKING":
                    working_dates.append(cur_dt)
                    cur_dt += timedelta(days=1)
                    continue
                else:  # Standard Indian 2nd and 4th Saturday off
                    # Determine which Saturday of the month (1st, 2nd, 3rd, 4th, 5th)
                    day_of_month = cur_dt.day
                    saturday_index = (day_of_month - 1) // 7 + 1
                    if saturday_index in (2, 4):
                        breakdown["saturdays_off"] += 1
                        cur_dt += timedelta(days=1)
                        continue
                    else:
                        working_dates.append(cur_dt)
                        cur_dt += timedelta(days=1)
                        continue

            # Regular Monday-Friday working day
            working_dates.append(cur_dt)
            cur_dt += timedelta(days=1)

        total_working_days = len(working_dates)
        total_non_working_days = total_calendar_days - total_working_days

        return WorkingDaysCalculationResponse(
            school_id=school_id,
            academic_year_id=academic_year_id,
            start_date=start_date,
            end_date=end_date,
            total_calendar_days=total_calendar_days,
            total_working_days=total_working_days,
            total_non_working_days=total_non_working_days,
            working_dates=working_dates,
            breakdown=breakdown
        )

    async def detect_exam_conflicts(
        self,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        target_date: date
    ) -> List[Dict[str, Any]]:
        stmt = select(ExamSchedule, Examination).join(
            Examination, ExamSchedule.exam_id == Examination.id
        ).where(
            ExamSchedule.school_id == school_id,
            ExamSchedule.academic_year_id == academic_year_id,
            ExamSchedule.exam_date == target_date,
            ExamSchedule.deleted_at.is_(None),
            Examination.deleted_at.is_(None)
        )
        res = await self.db.execute(stmt)
        rows = res.all()
        conflicts = []
        for sched, exam in rows:
            conflicts.append({
                "exam_id": str(exam.id),
                "exam_name": exam.exam_name,
                "schedule_id": str(sched.id),
                "class_id": str(sched.class_id) if sched.class_id else None,
                "section_id": str(sched.section_id) if sched.section_id else None,
                "subject_id": str(sched.subject_id) if sched.subject_id else None,
                "start_time": sched.start_time.isoformat() if sched.start_time else None,
                "end_time": sched.end_time.isoformat() if sched.end_time else None,
                "room_number": sched.room_number
            })
        return conflicts
