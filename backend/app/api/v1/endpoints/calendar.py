import uuid
from typing import List, Dict, Any
from datetime import date
from fastapi import APIRouter, Depends, Query, status, HTTPException
from sqlalchemy import select, and_
from sqlalchemy.orm import joinedload
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.auth import require_permission
from app.db.session import get_db
from app.models.user import User
from app.models.school_event import SchoolEvent, EventStatus
from app.models.examination import ExamSchedule, Examination, ExamStatus
from app.schemas.response import APIResponse

router = APIRouter()

async def verify_school_access(user_id: uuid.UUID, school_id: uuid.UUID, db: AsyncSession) -> None:
    from sqlalchemy import text, select
    from app.models.user import User
    from app.models.school import School

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

    # 5. For standard users, check mapping
    from app.models.role import school_users
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
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("event.read")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[List[Dict[str, Any]]]:
    """
    Returns unified list of calendar feed items (events, holidays, exams).
    """
    await verify_school_access(current_user.id, school_id, db)
    
    feed_items = []

    # 1. Fetch school events (including holidays)
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

    # 2. Fetch examination schedules
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
