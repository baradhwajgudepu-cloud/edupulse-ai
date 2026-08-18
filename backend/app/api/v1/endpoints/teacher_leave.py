import uuid
from typing import List, Optional
from datetime import date
from fastapi import APIRouter, Depends, Query, status, HTTPException
from sqlalchemy import text, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.teacher import Teacher

from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.auth import get_current_user, require_permission
from app.api.dependencies.teacher_leave import get_teacher_leave_service
from app.db.session import get_db
from app.models.user import User
from app.models.teacher_leave import LeaveStatus, LeaveType
from app.schemas.response import APIResponse
from app.schemas.teacher_leave import (
    TeacherLeaveCreateRequest,
    TeacherLeaveReviewRequest,
    TeacherLeaveCancelRequest,
    TeacherLeaveResponse
)
from app.services.teacher_leave import TeacherLeaveService

router = APIRouter()

async def verify_school_access(user_id: uuid.UUID, school_id: uuid.UUID, db: AsyncSession) -> None:
    """
    Helper to check if a user is authorized to access a given school context in the school_users mapping.
    """
    stmt = text("SELECT 1 FROM school_users WHERE user_id = :uid AND school_id = :sid")
    res = await db.execute(stmt, {"uid": str(user_id), "sid": str(school_id)})
    if not res.fetchone():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. You do not have permissions for this school."
        )

@router.post(
    "",
    response_model=APIResponse[TeacherLeaveResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Submit leave request",
    description="Teacher creates a new pending leave request. The teacher profile and school are resolved server-side."
)
async def submit_leave(
    payload: TeacherLeaveCreateRequest,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher_leave.create")),
    service: TeacherLeaveService = Depends(get_teacher_leave_service)
) -> APIResponse[TeacherLeaveResponse]:
    # Resolve teacher profile
    teacher = await service.teacher_repo.get_by_user_id(current_user.id, tenant_id)
    if not teacher:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Teacher profile not found for authenticated user."
        )
    
    # Enforce tenant match
    if teacher.tenant_id != tenant_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. Mismatched tenant boundary."
        )

    db_obj = await service.create_leave(tenant_id, current_user.id, payload)
    return APIResponse[TeacherLeaveResponse](
        success=True,
        message="Leave request submitted successfully.",
        data=TeacherLeaveResponse.model_validate(db_obj)
    )

@router.get(
    "/my",
    response_model=APIResponse[List[TeacherLeaveResponse]],
    status_code=status.HTTP_200_OK,
    summary="Get authenticated teacher leaves",
    description="Returns all leave requests submitted by the logged-in teacher."
)
async def get_my_leaves(
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher_leave.read")),
    service: TeacherLeaveService = Depends(get_teacher_leave_service)
) -> APIResponse[List[TeacherLeaveResponse]]:
    leaves = await service.get_my_leave_requests(tenant_id, current_user.id)
    responses = [TeacherLeaveResponse.model_validate(l) for l in leaves]
    return APIResponse[List[TeacherLeaveResponse]](
        success=True,
        message="My leave requests retrieved.",
        data=responses
    )

@router.get(
    "/{leave_id}",
    response_model=APIResponse[TeacherLeaveResponse],
    status_code=status.HTTP_200_OK,
    summary="Get specific leave request",
    description="Returns details of a single leave request if the user is the owner or Principal/Admin."
)
async def get_leave(
    leave_id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher_leave.read")),
    service: TeacherLeaveService = Depends(get_teacher_leave_service),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[TeacherLeaveResponse]:
    user_roles = [r.code for r in current_user.roles]
    db_obj = await service.get_leave(leave_id, tenant_id, current_user.id, user_roles)
    
    # If the current user is not the owner (meaning they are Principal/Admin/Reviewer), verify school access scope
    teacher = await service.teacher_repo.get_by_user_id(current_user.id, tenant_id)
    is_owner = teacher and teacher.id == db_obj.teacher_id
    if not is_owner:
        await verify_school_access(current_user.id, db_obj.school_id, db)

    return APIResponse[TeacherLeaveResponse](
        success=True,
        message="Leave request details retrieved.",
        data=TeacherLeaveResponse.model_validate(db_obj)
    )

@router.post(
    "/{leave_id}/cancel",
    response_model=APIResponse[TeacherLeaveResponse],
    status_code=status.HTTP_200_OK,
    summary="Cancel pending leave request",
    description="Cancels an eligible pending leave request (accessible only to the owner)."
)
async def cancel_leave(
    leave_id: uuid.UUID,
    payload: TeacherLeaveCancelRequest,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher_leave.cancel")),
    service: TeacherLeaveService = Depends(get_teacher_leave_service)
) -> APIResponse[TeacherLeaveResponse]:
    db_obj = await service.cancel_leave(leave_id, tenant_id, current_user.id, payload)
    return APIResponse[TeacherLeaveResponse](
        success=True,
        message="Leave request cancelled successfully.",
        data=TeacherLeaveResponse.model_validate(db_obj)
    )

@router.get(
    "",
    response_model=APIResponse[List[TeacherLeaveResponse]],
    status_code=status.HTTP_200_OK,
    summary="List leave requests (Principal/Admin)",
    description="Retrieves teacher leaves scoped by school and tenant context."
)
async def list_leaves(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    status_filter: Optional[LeaveStatus] = Query(None, alias="status", description="Filter by status"),
    leave_type: Optional[LeaveType] = Query(None, alias="leave_type", description="Filter by leave type"),
    start_date: Optional[date] = Query(None, description="Start date filter"),
    end_date: Optional[date] = Query(None, description="End date filter"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher_leave.review")),
    service: TeacherLeaveService = Depends(get_teacher_leave_service),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[List[TeacherLeaveResponse]]:
    # Verify school access for the reviewer
    await verify_school_access(current_user.id, school_id, db)
    
    leaves = await service.list_leave_requests(
        school_id=school_id,
        tenant_id=tenant_id,
        status_filter=status_filter,
        leave_type=leave_type,
        start_date=start_date,
        end_date=end_date,
        skip=skip,
        limit=limit
    )
    responses = [TeacherLeaveResponse.model_validate(l) for l in leaves]
    return APIResponse[List[TeacherLeaveResponse]](
        success=True,
        message="Leave requests retrieved.",
        data=responses
    )

@router.post(
    "/{leave_id}/review",
    response_model=APIResponse[TeacherLeaveResponse],
    status_code=status.HTTP_200_OK,
    summary="Approve or reject a leave request",
    description="Principal/Admin approves or rejects a pending leave request."
)
async def review_leave(
    leave_id: uuid.UUID,
    payload: TeacherLeaveReviewRequest,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher_leave.review")),
    service: TeacherLeaveService = Depends(get_teacher_leave_service),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[TeacherLeaveResponse]:
    # Resolve the leave first to check its school context
    leave_request = await service.leave_repo.get_by_id(leave_id, tenant_id)
    if not leave_request:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Leave request not found."
        )

    # Verify reviewer belongs to the target leave's school
    await verify_school_access(current_user.id, leave_request.school_id, db)
    
    # Enforce review rules
    db_obj = await service.review_leave(
        leave_id=leave_id,
        tenant_id=tenant_id,
        reviewer_id=current_user.id,
        reviewer_school_id=leave_request.school_id,
        payload=payload
    )
    return APIResponse[TeacherLeaveResponse](
        success=True,
        message=f"Leave request reviewed successfully as {db_obj.status.value}.",
        data=TeacherLeaveResponse.model_validate(db_obj)
    )

@router.get(
    "/teacher/{teacher_id}/history",
    response_model=APIResponse[List[TeacherLeaveResponse]],
    status_code=status.HTTP_200_OK,
    summary="Get teacher leave history",
    description="Retrieves a list of leaves submitted by the selected teacher, scoped to Principal/Admin school access."
)
async def get_teacher_leave_history(
    teacher_id: uuid.UUID,
    status_filter: Optional[LeaveStatus] = Query(None, alias="status", description="Filter by status"),
    leave_type: Optional[LeaveType] = Query(None, alias="leave_type", description="Filter by leave type"),
    start_date: Optional[date] = Query(None, description="Start date filter"),
    end_date: Optional[date] = Query(None, description="End date filter"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher_leave.review")),
    service: TeacherLeaveService = Depends(get_teacher_leave_service),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[List[TeacherLeaveResponse]]:
    # Resolve teacher profile globally to check school context and tenant boundary
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

    leaves = await service.get_teacher_leave_history(
        tenant_id=tenant_id,
        teacher_id=teacher_id,
        status=status_filter,
        leave_type=leave_type,
        start_date=start_date,
        end_date=end_date,
        skip=skip,
        limit=limit
    )

    responses = [TeacherLeaveResponse.model_validate(l) for l in leaves]
    return APIResponse[List[TeacherLeaveResponse]](
        success=True,
        message="Teacher leave history retrieved.",
        data=responses
    )
