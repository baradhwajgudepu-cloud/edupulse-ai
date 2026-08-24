import uuid
from datetime import date
from typing import Optional, List
from fastapi import APIRouter, Depends, status, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import get_db
from sqlalchemy import text, select
from app.models.teacher import Teacher

from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.auth import get_current_user, require_permission
from app.api.dependencies.staff_attendance import get_staff_attendance_service
from app.models.user import User
from app.schemas.response import APIResponse
from app.schemas.staff_attendance import StaffCheckInRequest, StaffCheckOutRequest, StaffAttendanceResponse, StaffDailyAttendanceSummary
from app.services.staff_attendance import StaffAttendanceService

router = APIRouter()

@router.get(
    "/status",
    response_model=APIResponse[Optional[StaffAttendanceResponse]],
    status_code=status.HTTP_200_OK,
    summary="Get today's staff attendance status",
    description="Retrieves the logged-in teacher's check-in/check-out status for today."
)
async def get_today_status(
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("staff_attendance.read")),
    service: StaffAttendanceService = Depends(get_staff_attendance_service)
) -> APIResponse[Optional[StaffAttendanceResponse]]:
    db_obj = await service.get_today_status(tenant_id, current_user.id)
    response_data = StaffAttendanceResponse.model_validate(db_obj) if db_obj else None
    return APIResponse[Optional[StaffAttendanceResponse]](
        success=True,
        message="Today's staff attendance status retrieved.",
        data=response_data
    )

@router.post(
    "/check-in",
    response_model=APIResponse[StaffAttendanceResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Record staff check-in",
    description="Performs geofence validation and records the teacher's check-in timestamp."
)
async def check_in(
    payload: StaffCheckInRequest,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("staff_attendance.create")),
    service: StaffAttendanceService = Depends(get_staff_attendance_service)
) -> APIResponse[StaffAttendanceResponse]:
    db_obj = await service.check_in(tenant_id, current_user.id, payload)
    return APIResponse[StaffAttendanceResponse](
        success=True,
        message="Staff check-in recorded successfully.",
        data=StaffAttendanceResponse.model_validate(db_obj)
    )

@router.post(
    "/check-out",
    response_model=APIResponse[StaffAttendanceResponse],
    status_code=status.HTTP_200_OK,
    summary="Record staff check-out",
    description="Performs geofence validation and records the teacher's check-out timestamp."
)
async def check_out(
    payload: StaffCheckOutRequest,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("staff_attendance.update")),
    service: StaffAttendanceService = Depends(get_staff_attendance_service)
) -> APIResponse[StaffAttendanceResponse]:
    db_obj = await service.check_out(tenant_id, current_user.id, payload)
    return APIResponse[StaffAttendanceResponse](
        success=True,
        message="Staff check-out recorded successfully.",
        data=StaffAttendanceResponse.model_validate(db_obj)
    )

@router.get(
    "/daily",
    response_model=APIResponse[StaffDailyAttendanceSummary],
    status_code=status.HTTP_200_OK,
    summary="Get daily staff attendance summary",
    description="Retrieves daily staff attendance logs and statistics scoped by school."
)
async def get_daily_report(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    attendance_date: date = Query(..., description="Target date"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("staff_attendance.admin")), # Require Principal/Admin permission
    service: StaffAttendanceService = Depends(get_staff_attendance_service)
) -> APIResponse[StaffDailyAttendanceSummary]:
    report = await service.get_daily_report(tenant_id, school_id, attendance_date)
    return APIResponse[StaffDailyAttendanceSummary](
        success=True,
        message="Daily staff attendance report fetched successfully.",
        data=StaffDailyAttendanceSummary.model_validate(report)
    )

async def verify_school_access(user_id: uuid.UUID, school_id: uuid.UUID, db: AsyncSession) -> None:
    """
    Helper to check if a user is authorized to access a given school context in the school_users mapping.
    """
    from sqlalchemy import select
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
    stmt = text("SELECT 1 FROM school_users WHERE user_id = :uid AND school_id = :sid")
    res = await db.execute(stmt, {"uid": str(user_id), "sid": str(school_id)})
    if not res.fetchone():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. You do not have permissions for this school."
        )


@router.get(
    "/teacher/{teacher_id}/history",
    response_model=APIResponse[List[StaffAttendanceResponse]],
    status_code=status.HTTP_200_OK,
    summary="Get teacher attendance history",
    description="Allows Principal/Admin to retrieve staff attendance logs for a selected teacher."
)
async def get_teacher_history(
    teacher_id: uuid.UUID,
    start_date: Optional[date] = Query(None, description="Filter history from date"),
    end_date: Optional[date] = Query(None, description="Filter history to date"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("staff_attendance.admin")),
    service: StaffAttendanceService = Depends(get_staff_attendance_service),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[List[StaffAttendanceResponse]]:
    # Resolve teacher profile globally to get school_id and check tenant mapping
    stmt = select(Teacher).where(
        Teacher.id == teacher_id,
        Teacher.tenant_id == tenant_id,
        Teacher.deleted_at.is_(None)
    )
    res = await db.execute(stmt)
    teacher = res.scalar_one_or_none()
    if not teacher:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Teacher profile not found."
        )

    # Verify reviewer belongs to the target teacher's school
    await verify_school_access(current_user.id, teacher.school_id, db)

    history = await service.get_teacher_attendance_history(
        tenant_id=tenant_id,
        teacher_id=teacher_id,
        start_date=start_date,
        end_date=end_date,
        skip=skip,
        limit=limit
    )

    responses = [StaffAttendanceResponse.model_validate(h) for h in history]
    return APIResponse[List[StaffAttendanceResponse]](
        success=True,
        message="Teacher attendance history fetched successfully.",
        data=responses
    )

