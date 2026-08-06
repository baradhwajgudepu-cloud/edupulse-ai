import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status, HTTPException

from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.teacher import get_teacher_service
from app.api.dependencies.auth import require_permission
from app.services.teacher import TeacherService
from app.schemas.teacher import TeacherCreate, TeacherUpdate, TeacherResponse
from app.models.teacher import TeacherStatus
from app.models.user import User
from app.schemas.response import APIResponse

router = APIRouter()

@router.post(
    "",
    response_model=APIResponse[TeacherResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Add a new teacher profile",
    description="Registers a new teacher profile in the system, validating age, joining date, and uniqueness checks."
)
async def create_teacher(
    obj_in: TeacherCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher.create")),
    service: TeacherService = Depends(get_teacher_service)
) -> APIResponse[TeacherResponse]:
    db_obj = await service.create_teacher(tenant_id, obj_in, created_by=current_user.id)
    return APIResponse[TeacherResponse](
        success=True,
        message="Teacher profile registered successfully.",
        data=TeacherResponse.model_validate(db_obj)
    )

@router.get(
    "",
    response_model=APIResponse[List[TeacherResponse]],
    status_code=status.HTTP_200_OK,
    summary="List teacher profiles under school",
    description="Retrieves a paginated list of teachers scoped by tenant and school."
)
async def list_teachers(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    department: Optional[str] = Query(None, description="Filter by department"),
    designation: Optional[str] = Query(None, description="Filter by designation"),
    status_filter: Optional[TeacherStatus] = Query(None, alias="status", description="Filter by teacher status"),
    search: Optional[str] = Query(None, description="Fuzzy match search on names, email, mobile, Aadhaar, PAN, designation, department, and employee/staff codes"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher.read")),
    service: TeacherService = Depends(get_teacher_service)
) -> APIResponse[List[TeacherResponse]]:
    teachers = await service.teacher_repo.get_multi(
        school_id=school_id,
        tenant_id=tenant_id,
        department=department,
        designation=designation,
        status=status_filter,
        search=search,
        skip=skip,
        limit=limit
    )
    responses = [TeacherResponse.model_validate(t) for t in teachers]
    return APIResponse[List[TeacherResponse]](
        success=True,
        message="Teachers fetched successfully.",
        data=responses
    )

@router.get(
    "/{id}",
    response_model=APIResponse[TeacherResponse],
    status_code=status.HTTP_200_OK,
    summary="Get teacher profile details",
    description="Retrieves teacher profile attributes scoped by tenant and school."
)
async def get_teacher(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher.read")),
    service: TeacherService = Depends(get_teacher_service)
) -> APIResponse[TeacherResponse]:
    db_obj = await service.teacher_repo.get_by_id(id, school_id, tenant_id)
    if not db_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Teacher profile not found."
        )
    return APIResponse[TeacherResponse](
        success=True,
        message="Teacher details fetched successfully.",
        data=TeacherResponse.model_validate(db_obj)
    )

@router.put(
    "/{id}",
    response_model=APIResponse[TeacherResponse],
    status_code=status.HTTP_200_OK,
    summary="Update teacher details",
    description="Modifies teacher parameters scoped by tenant and school."
)
async def update_teacher(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    obj_in: TeacherUpdate = ...,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher.update")),
    service: TeacherService = Depends(get_teacher_service)
) -> APIResponse[TeacherResponse]:
    db_obj = await service.update_teacher(tenant_id, school_id, id, obj_in, updated_by=current_user.id)
    return APIResponse[TeacherResponse](
        success=True,
        message="Teacher updated successfully.",
        data=TeacherResponse.model_validate(db_obj)
    )

@router.delete(
    "/{id}",
    response_model=APIResponse[TeacherResponse],
    status_code=status.HTTP_200_OK,
    summary="Soft-delete teacher profile",
    description="Soft-deletes the teacher profile, updating status to INACTIVE."
)
async def delete_teacher(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher.delete")),
    service: TeacherService = Depends(get_teacher_service)
) -> APIResponse[TeacherResponse]:
    db_obj = await service.delete_teacher(tenant_id, school_id, id, deleted_by=current_user.id)
    return APIResponse[TeacherResponse](
        success=True,
        message="Teacher deleted successfully.",
        data=TeacherResponse.model_validate(db_obj)
    )
