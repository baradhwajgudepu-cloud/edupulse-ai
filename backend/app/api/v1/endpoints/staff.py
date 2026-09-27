import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status, HTTPException

from app.api.dependencies.common import get_tenant_id, verify_school_access
from app.api.dependencies.teacher import get_teacher_service
from app.api.dependencies.auth import require_permission
from app.services.teacher import TeacherService
from app.schemas.teacher import TeacherCreate, TeacherUpdate, TeacherResponse
from app.models.teacher import TeacherStatus, StaffType
from app.models.user import User
from app.schemas.response import APIResponse

router = APIRouter()

@router.post(
    "",
    response_model=APIResponse[TeacherResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Add a new staff profile",
    description="Registers a new staff member (Teaching or Non-Teaching)."
)
async def create_staff(
    obj_in: TeacherCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher.create", "school.update")),
    service: TeacherService = Depends(get_teacher_service)
) -> APIResponse[TeacherResponse]:
    await verify_school_access(current_user, obj_in.school_id, service.teacher_repo.db)
    db_obj = await service.create_teacher(tenant_id, obj_in, created_by=current_user.id)
    return APIResponse[TeacherResponse](
        success=True,
        message="Staff profile registered successfully.",
        data=TeacherResponse.model_validate(db_obj)
    )

@router.get(
    "",
    response_model=APIResponse[List[TeacherResponse]],
    status_code=status.HTTP_200_OK,
    summary="List staff members",
    description="Retrieves a list of staff members with optional staff_type filter (TEACHING or NON_TEACHING)."
)
async def list_staff(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    staff_type: Optional[StaffType] = Query(None, description="Filter by TEACHING or NON_TEACHING"),
    department: Optional[str] = Query(None, description="Filter by department"),
    designation: Optional[str] = Query(None, description="Filter by designation"),
    status_filter: Optional[TeacherStatus] = Query(None, alias="status", description="Filter by status"),
    search: Optional[str] = Query(None, description="Search query"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher.read", "school.read")),
    service: TeacherService = Depends(get_teacher_service)
) -> APIResponse[List[TeacherResponse]]:
    await verify_school_access(current_user, school_id, service.teacher_repo.db)
    staff_members = await service.teacher_repo.get_multi(
        school_id=school_id,
        tenant_id=tenant_id,
        department=department,
        designation=designation,
        status=status_filter,
        staff_type=staff_type,
        search=search,
        skip=skip,
        limit=limit
    )
    responses = [TeacherResponse.model_validate(s) for s in staff_members]
    return APIResponse[List[TeacherResponse]](
        success=True,
        message="Staff members fetched successfully.",
        data=responses
    )

@router.get(
    "/{id}",
    response_model=APIResponse[TeacherResponse],
    status_code=status.HTTP_200_OK,
    summary="Get staff profile details"
)
async def get_staff(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher.read", "school.read")),
    service: TeacherService = Depends(get_teacher_service)
) -> APIResponse[TeacherResponse]:
    await verify_school_access(current_user, school_id, service.teacher_repo.db)
    db_obj = await service.teacher_repo.get_by_id(id, school_id, tenant_id)
    if not db_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Staff profile not found."
        )
    return APIResponse[TeacherResponse](
        success=True,
        message="Staff details fetched successfully.",
        data=TeacherResponse.model_validate(db_obj)
    )

@router.put(
    "/{id}",
    response_model=APIResponse[TeacherResponse],
    status_code=status.HTTP_200_OK,
    summary="Update staff profile"
)
async def update_staff(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    obj_in: TeacherUpdate = ...,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher.update", "school.update")),
    service: TeacherService = Depends(get_teacher_service)
) -> APIResponse[TeacherResponse]:
    await verify_school_access(current_user, school_id, service.teacher_repo.db)
    db_obj = await service.update_teacher(tenant_id, school_id, id, obj_in, updated_by=current_user.id)
    return APIResponse[TeacherResponse](
        success=True,
        message="Staff profile updated successfully.",
        data=TeacherResponse.model_validate(db_obj)
    )

@router.delete(
    "/{id}",
    response_model=APIResponse[TeacherResponse],
    status_code=status.HTTP_200_OK,
    summary="Delete staff profile"
)
async def delete_staff(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher.delete", "school.update")),
    service: TeacherService = Depends(get_teacher_service)
) -> APIResponse[TeacherResponse]:
    await verify_school_access(current_user, school_id, service.teacher_repo.db)
    db_obj = await service.delete_teacher(tenant_id, school_id, id, deleted_by=current_user.id)
    return APIResponse[TeacherResponse](
        success=True,
        message="Staff profile deleted successfully.",
        data=TeacherResponse.model_validate(db_obj)
    )
