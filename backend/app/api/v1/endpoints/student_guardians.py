import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status, HTTPException

from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.guardian import get_guardian_service
from app.api.dependencies.auth import require_permission
from app.services.guardian import GuardianService
from app.schemas.guardian import StudentGuardianCreate, StudentGuardianUpdate, StudentGuardianResponse
from app.models.user import User
from app.schemas.response import APIResponse

router = APIRouter()

@router.post(
    "",
    response_model=APIResponse[StudentGuardianResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Assign a guardian to a student",
    description="Maps a student with a guardian, validating bounds, mapping duplicates, and primary limits."
)
async def assign_student_guardian(
    obj_in: StudentGuardianCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("guardian.create")),
    service: GuardianService = Depends(get_guardian_service)
) -> APIResponse[StudentGuardianResponse]:
    db_obj = await service.assign_student_guardian(tenant_id, obj_in)
    return APIResponse[StudentGuardianResponse](
        success=True,
        message="Student assigned to guardian successfully.",
        data=StudentGuardianResponse.model_validate(db_obj)
    )

@router.get(
    "",
    response_model=APIResponse[List[StudentGuardianResponse]],
    status_code=status.HTTP_200_OK,
    summary="List student-guardian mappings",
    description="Retrieves a list of active mapping configurations filtered by Student or Guardian."
)
async def list_student_guardians(
    student_id: Optional[uuid.UUID] = Query(None, description="Filter by Student ID"),
    guardian_id: Optional[uuid.UUID] = Query(None, description="Filter by Guardian ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("guardian.read")),
    service: GuardianService = Depends(get_guardian_service)
) -> APIResponse[List[StudentGuardianResponse]]:
    if student_id:
        mappings = await service.student_guardian_repo.get_student_guardians(student_id, tenant_id)
    elif guardian_id:
        mappings = await service.student_guardian_repo.get_guardian_students(guardian_id, tenant_id)
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Either student_id or guardian_id query parameter must be provided."
        )
    
    responses = [StudentGuardianResponse.model_validate(m) for m in mappings]
    return APIResponse[List[StudentGuardianResponse]](
        success=True,
        message="Student guardian mappings fetched successfully.",
        data=responses
    )

@router.put(
    "/{id}",
    response_model=APIResponse[StudentGuardianResponse],
    status_code=status.HTTP_200_OK,
    summary="Update mapping parameters",
    description="Updates relationship status, primary flags, or pickups permissions."
)
async def update_student_guardian(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    obj_in: StudentGuardianUpdate = ...,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("guardian.update")),
    service: GuardianService = Depends(get_guardian_service)
) -> APIResponse[StudentGuardianResponse]:
    db_obj = await service.update_student_guardian(tenant_id, school_id, id, obj_in)
    return APIResponse[StudentGuardianResponse](
        success=True,
        message="Mapping updated successfully.",
        data=StudentGuardianResponse.model_validate(db_obj)
    )

@router.delete(
    "/{id}",
    response_model=APIResponse[StudentGuardianResponse],
    status_code=status.HTTP_200_OK,
    summary="Remove guardian assignment",
    description="Soft-deletes the mapping configuration between student and guardian."
)
async def remove_student_guardian(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("guardian.delete")),
    service: GuardianService = Depends(get_guardian_service)
) -> APIResponse[StudentGuardianResponse]:
    db_obj = await service.remove_student_guardian(tenant_id, school_id, id)
    return APIResponse[StudentGuardianResponse](
        success=True,
        message="Mapping removed successfully.",
        data=StudentGuardianResponse.model_validate(db_obj)
    )
