import uuid
from typing import List, Dict, Any, Optional
from datetime import date
from fastapi import APIRouter, Depends, Query, status, HTTPException
from sqlalchemy import select, and_
from sqlalchemy.orm import joinedload
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.auth import require_permission, get_current_user
from app.db.session import get_db
from app.models.user import User
from app.models.school_event import SchoolEvent, EventStatus
from app.models.academic_calendar import AcademicCalendarEvent, CalendarEventType, CalendarEventStatus
from app.models.examination import ExamSchedule, Examination, ExamStatus
from app.services.academic_calendar import AcademicCalendarService
from app.schemas.academic_calendar import (
    CalendarEventCreate, CalendarEventUpdate, CalendarEventResponse,
    PrincipalHolidayDeclareRequest, StateHolidayStatusResponse,
    WorkingDaysCalculationResponse, StateHolidayPopulateRequest
)
from app.schemas.response import APIResponse

router = APIRouter()

async def verify_school_access(user_id: uuid.UUID, school_id: uuid.UUID, db: AsyncSession) -> None:
    from sqlalchemy import select
    from app.models.user import User
    from app.models.school import School
    from app.models.role import school_users

    # 1. Fetch user to check superuser and tenant
    user_stmt = select(User).where(User.id == user_id)
    user_res = await db.execute(user_stmt)
    user = user_res.scalar_one_or_none()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found."
        )

    # 2. Fetch selected school
    school_stmt = select(School).where(School.id == school_id)
    school_res = await db.execute(school_stmt)
    school = school_res.scalar_one_or_none()
    if not school:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="School not found."
        )

    # 3. Verify selected school belongs to user's tenant
    if not user.is_superuser and school.tenant_id != user.tenant_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. School belongs to a different tenant."
        )

    # 4. Selected school must be active
    if not school.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="School is inactive."
        )

    # 5. If superuser, allow access
    if user.is_superuser:
        return

    # Check mapping in school_users
    stmt = select(1).select_from(school_users).where(
        school_users.c.user_id == user_id,
        school_users.c.school_id == school_id
    )
    res = await db.execute(stmt)
    if not res.fetchone():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. You do not have permissions for this school."
        )

@router.get(
    "/feed",
    response_model=APIResponse[List[Dict[str, Any]]],
    status_code=status.HTTP_200_OK,
    summary="Get consolidated calendar planner feed"
)
async def get_calendar_feed(
    school_id: uuid.UUID = Query(...),
    start_date: date = Query(...),
    end_date: date = Query(...),
    academic_year_id: Optional[uuid.UUID] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("event.read")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[List[Dict[str, Any]]]:
    """
    Returns unified list of calendar feed items (events, holidays, exams).
    """
    await verify_school_access(current_user.id, school_id, db)
    
    feed_items = []

    # 1. Fetch academic calendar events (state public holidays, school holidays, principal holidays, special working days)
    stmt_acad = select(AcademicCalendarEvent).where(
        AcademicCalendarEvent.school_id == school_id,
        AcademicCalendarEvent.tenant_id == tenant_id,
        AcademicCalendarEvent.event_date >= start_date,
        AcademicCalendarEvent.event_date <= end_date,
        AcademicCalendarEvent.deleted_at.is_(None)
    )
    if academic_year_id:
        stmt_acad = stmt_acad.where(AcademicCalendarEvent.academic_year_id == academic_year_id)

    res_acad = await db.execute(stmt_acad)
    acad_events = res_acad.scalars().all()

    for ae in acad_events:
        feed_items.append({
            "id": str(ae.id),
            "type": ae.event_type.value,
            "title": ae.title,
            "description": ae.description,
            "date": ae.event_date.isoformat(),
            "start_time": "00:00:00",
            "end_time": "23:59:59",
            "extra_data": {
                "source": ae.source,
                "source_reference": ae.source_reference,
                "status": ae.status.value,
                "is_holiday": ae.is_non_working_day,
                "is_non_working_day": ae.is_non_working_day,
                "event_type": ae.event_type.value
            }
        })

    # 2. Fetch school events
    stmt_events = select(SchoolEvent).where(
        SchoolEvent.school_id == school_id,
        SchoolEvent.tenant_id == tenant_id,
        SchoolEvent.event_date >= start_date,
        SchoolEvent.event_date <= end_date,
        SchoolEvent.deleted_at.is_(None)
    )
    res_events = await db.execute(stmt_events)
    events = res_events.scalars().all()

    for event in events:
        feed_items.append({
            "id": str(event.id),
            "type": "HOLIDAY" if event.is_holiday else "EVENT",
            "title": event.event_name,
            "description": event.description,
            "date": event.event_date.isoformat(),
            "start_time": event.start_time.isoformat(),
            "end_time": event.end_time.isoformat(),
            "extra_data": {
                "venue": event.venue,
                "target_audience": event.target_audience.value,
                "status": event.status.value,
                "is_holiday": event.is_holiday
            }
        })

    # 3. Fetch examination schedules
    stmt_schedules = select(ExamSchedule).join(
        Examination, ExamSchedule.exam_id == Examination.id
    ).where(
        ExamSchedule.school_id == school_id,
        ExamSchedule.tenant_id == tenant_id,
        ExamSchedule.exam_date >= start_date,
        ExamSchedule.exam_date <= end_date,
        ExamSchedule.deleted_at.is_(None),
        Examination.deleted_at.is_(None)
    ).options(
        joinedload(ExamSchedule.examination),
        joinedload(ExamSchedule.class_obj),
        joinedload(ExamSchedule.section),
        joinedload(ExamSchedule.subject)
    )
    res_schedules = await db.execute(stmt_schedules)
    schedules = res_schedules.scalars().all()

    for sched in schedules:
        feed_items.append({
            "id": str(sched.id),
            "type": "EXAMINATION",
            "title": f"{sched.examination.exam_name}: {sched.subject.subject_name if sched.subject else 'Paper'}",
            "description": f"Class: {sched.class_obj.name if sched.class_obj else ''} - Sec: {sched.section.name if sched.section else ''}",
            "date": sched.exam_date.isoformat(),
            "start_time": sched.start_time.isoformat(),
            "end_time": sched.end_time.isoformat(),
            "extra_data": {
                "exam_id": str(sched.exam_id),
                "exam_name": sched.examination.exam_name,
                "class_name": sched.class_obj.name if sched.class_obj else None,
                "section_name": sched.section.name if sched.section else None,
                "subject_name": sched.subject.subject_name if sched.subject else None,
                "max_marks": sched.max_marks,
                "pass_marks": sched.pass_marks,
                "room_number": sched.room_number,
                "status": sched.examination.status.value
            }
        })

    # Sort consolidated feed by date and start_time
    feed_items.sort(key=lambda x: (x["date"], x["start_time"]))

    return APIResponse[List[Dict[str, Any]]](
        success=True,
        message="Consolidated calendar planner feed loaded.",
        data=feed_items
    )

@router.get(
    "/working-days",
    response_model=APIResponse[WorkingDaysCalculationResponse],
    status_code=status.HTTP_200_OK,
    summary="Get calculated working days for academic year and range"
)
async def get_working_days(
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    start_date: date = Query(...),
    end_date: date = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("event.read")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[WorkingDaysCalculationResponse]:
    await verify_school_access(current_user.id, school_id, db)
    cal_service = AcademicCalendarService(db)
    res = await cal_service.calculate_working_days(
        school_id=school_id,
        academic_year_id=academic_year_id,
        start_date=start_date,
        end_date=end_date
    )
    return APIResponse[WorkingDaysCalculationResponse](
        success=True,
        message="Calculated authoritative working days.",
        data=res
    )

@router.get(
    "/holidays/state/status",
    response_model=APIResponse[StateHolidayStatusResponse],
    status_code=status.HTTP_200_OK,
    summary="Check official verification status of state public holiday calendar"
)
async def get_state_holiday_status(
    state: str = Query(...),
    academic_year_code: str = Query(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[StateHolidayStatusResponse]:
    cal_service = AcademicCalendarService(db)
    res = await cal_service.get_state_holiday_status(state, academic_year_code)
    return APIResponse[StateHolidayStatusResponse](
        success=True,
        message=res.message,
        data=res
    )

@router.post(
    "/holidays/state/populate",
    response_model=APIResponse[Dict[str, Any]],
    status_code=status.HTTP_200_OK,
    summary="Auto-populate verified state public holidays for school and academic year"
)
async def populate_state_holidays(
    school_id: Optional[uuid.UUID] = Query(None),
    academic_year_id: Optional[uuid.UUID] = Query(None),
    state: Optional[str] = Query(None),
    academic_year_code: Optional[str] = Query(None),
    payload: Optional[StateHolidayPopulateRequest] = None,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("event.create")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[Dict[str, Any]]:
    target_school_id = (payload.school_id if payload else None) or school_id
    target_ay_id = (payload.academic_year_id if payload else None) or academic_year_id
    target_state = (payload.state if payload else None) or state
    target_ay_code = (payload.academic_year_code if payload else None) or academic_year_code

    if not all([target_school_id, target_ay_id, target_state, target_ay_code]):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Missing required fields: school_id, academic_year_id, state, academic_year_code."
        )

    await verify_school_access(current_user.id, target_school_id, db)
    cal_service = AcademicCalendarService(db)
    res = await cal_service.populate_state_holidays(
        tenant_id=tenant_id,
        school_id=target_school_id,
        academic_year_id=target_ay_id,
        state=target_state,
        academic_year_code=target_ay_code,
        created_by=current_user.id
    )
    await db.commit()
    return APIResponse[Dict[str, Any]](
        success=res.get("success", False),
        message=res.get("message", "Populated state holidays."),
        data=res
    )

@router.post(
    "/holidays/school",
    response_model=APIResponse[CalendarEventResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create school-specific holiday"
)
async def create_school_holiday(
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    event_in: CalendarEventCreate = ...,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("event.create")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[CalendarEventResponse]:
    await verify_school_access(current_user.id, school_id, db)
    cal_service = AcademicCalendarService(db)
    event = await cal_service.create_school_holiday(
        tenant_id=tenant_id,
        school_id=school_id,
        academic_year_id=academic_year_id,
        event_date=event_in.event_date,
        title=event_in.title,
        description=event_in.description,
        created_by=current_user.id
    )
    await db.commit()
    await db.refresh(event)
    return APIResponse[CalendarEventResponse](
        success=True,
        message="School holiday created successfully.",
        data=CalendarEventResponse.model_validate(event)
    )

@router.post(
    "/holidays/principal-declare",
    response_model=APIResponse[CalendarEventResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Principal declares holiday on a normal working day"
)
async def declare_principal_holiday(
    payload: PrincipalHolidayDeclareRequest,
    school_id: Optional[uuid.UUID] = Query(None),
    academic_year_id: Optional[uuid.UUID] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("event.create")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[CalendarEventResponse]:
    target_school_id = payload.school_id or school_id
    target_ay_id = payload.academic_year_id or academic_year_id
    if not target_school_id or not target_ay_id:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Missing required fields: school_id and academic_year_id"
        )
    await verify_school_access(current_user.id, target_school_id, db)
    cal_service = AcademicCalendarService(db)
    reason_str = payload.reason or payload.description
    event = await cal_service.declare_principal_holiday(
        tenant_id=tenant_id,
        school_id=target_school_id,
        academic_year_id=target_ay_id,
        event_date=payload.event_date,
        title=payload.title,
        reason=reason_str,
        auto_approve=payload.auto_approve,
        created_by=current_user.id
    )
    await db.commit()
    await db.refresh(event)
    return APIResponse[CalendarEventResponse](
        success=True,
        message=f"Principal declared holiday for {payload.event_date.strftime('%d %B %Y')}. Date is now marked as non-working.",
        data=CalendarEventResponse.model_validate(event)
    )

@router.post(
    "/holidays/{id}/approve",
    response_model=APIResponse[CalendarEventResponse],
    status_code=status.HTTP_200_OK,
    summary="Approve holiday declaration"
)
async def approve_holiday(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("event.create")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[CalendarEventResponse]:
    await verify_school_access(current_user.id, school_id, db)
    cal_service = AcademicCalendarService(db)
    event = await cal_service.approve_holiday(
        tenant_id=tenant_id,
        school_id=school_id,
        event_id=id,
        approved_by=current_user.id
    )
    await db.commit()
    await db.refresh(event)
    return APIResponse[CalendarEventResponse](
        success=True,
        message="Holiday approved successfully. Non-working day enforced.",
        data=CalendarEventResponse.model_validate(event)
    )

@router.get(
    "/events",
    response_model=APIResponse[List[CalendarEventResponse]],
    status_code=status.HTTP_200_OK,
    summary="List academic calendar events"
)
async def list_calendar_events(
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("event.read")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[List[CalendarEventResponse]]:
    await verify_school_access(current_user.id, school_id, db)
    cal_service = AcademicCalendarService(db)
    events = await cal_service.calendar_repo.get_events(
        school_id=school_id,
        academic_year_id=academic_year_id,
        start_date=start_date,
        end_date=end_date
    )
    return APIResponse[List[CalendarEventResponse]](
        success=True,
        message="Retrieved academic calendar events.",
        data=[CalendarEventResponse.model_validate(e) for e in events]
    )
