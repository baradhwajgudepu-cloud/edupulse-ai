import uuid
from typing import Dict, Any
from fastapi import APIRouter, Depends, Query, status, HTTPException
from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.auth import require_permission
from app.db.session import get_db
from app.models.user import User
from app.models.teacher_leave import TeacherLeave, LeaveStatus
from app.models.examination import Examination, ExamStatus
from app.models.announcement import Announcement, AnnouncementStatus
from app.models.school_event import SchoolEvent, EventStatus
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

    # 6. For standard users, check mapping
    stmt = text("SELECT 1 FROM school_users WHERE user_id = :uid AND school_id = :sid")
    res = await db.execute(stmt, {"uid": str(user_id), "sid": str(school_id)})
    if not res.fetchone():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. You do not have permissions for this school."
        )


@router.get(
    "/action-items",
    response_model=APIResponse[Dict[str, Any]],
    status_code=status.HTTP_200_OK,
    summary="Get Principal action required dashboard counts"
)
async def get_action_items(
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher_leave.review")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[Dict[str, Any]]:
    await verify_school_access(current_user.id, school_id, db)

    # 1. Query pending leaves count
    stmt_leaves = select(func.count(TeacherLeave.id)).where(
        TeacherLeave.school_id == school_id,
        TeacherLeave.tenant_id == tenant_id,
        TeacherLeave.status == LeaveStatus.PENDING,
        TeacherLeave.deleted_at.is_(None)
    )
    res_leaves = await db.execute(stmt_leaves)
    pending_leaves = res_leaves.scalar() or 0

    # 2. Query draft examinations count
    stmt_exams = select(func.count(Examination.id)).where(
        Examination.school_id == school_id,
        Examination.tenant_id == tenant_id,
        Examination.status == ExamStatus.DRAFT,
        Examination.deleted_at.is_(None)
    )
    res_exams = await db.execute(stmt_exams)
    draft_exams = res_exams.scalar() or 0

    # 3. Query draft announcements count
    stmt_announcements = select(func.count(Announcement.id)).where(
        Announcement.school_id == school_id,
        Announcement.tenant_id == tenant_id,
        Announcement.status == AnnouncementStatus.DRAFT,
        Announcement.deleted_at.is_(None)
    )
    res_announcements = await db.execute(stmt_announcements)
    draft_announcements = res_announcements.scalar() or 0

    # 4. Query draft events count
    stmt_events = select(func.count(SchoolEvent.id)).where(
        SchoolEvent.school_id == school_id,
        SchoolEvent.tenant_id == tenant_id,
        SchoolEvent.status == EventStatus.DRAFT,
        SchoolEvent.deleted_at.is_(None)
    )
    res_events = await db.execute(stmt_events)
    draft_events = res_events.scalar() or 0

    action_counts = {
        "pending_leaves_count": pending_leaves,
        "draft_examinations_count": draft_exams,
        "draft_announcements_count": draft_announcements,
        "draft_events_count": draft_events,
        "total_actions_count": pending_leaves + draft_exams + draft_announcements + draft_events
    }

    return APIResponse[Dict[str, Any]](
        success=True,
        message="Principal action required counts loaded.",
        data=action_counts
    )
