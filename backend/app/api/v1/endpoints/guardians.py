import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status, HTTPException

from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.guardian import get_guardian_service
from app.api.dependencies.auth import require_permission
from app.services.guardian import GuardianService
from app.schemas.guardian import GuardianCreate, GuardianUpdate, GuardianResponse
from app.models.guardian import GuardianStatus
from app.models.user import User
from app.schemas.response import APIResponse

router = APIRouter()

@router.post(
    "",
    response_model=APIResponse[GuardianResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Add a new guardian profile",
    description="Registers a new parent/guardian profile, checking tenant boundary uniqueness."
)
async def create_guardian(
    obj_in: GuardianCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("guardian.create")),
    service: GuardianService = Depends(get_guardian_service)
) -> APIResponse[GuardianResponse]:
    db_obj = await service.create_guardian(tenant_id, obj_in, created_by=current_user.id)
    return APIResponse[GuardianResponse](
        success=True,
        message="Guardian profile registered successfully.",
        data=GuardianResponse.model_validate(db_obj)
    )

@router.get(
    "",
    response_model=APIResponse[List[GuardianResponse]],
    status_code=status.HTTP_200_OK,
    summary="List guardian profiles under school",
    description="Retrieves a paginated list of guardians scoped by tenant and school."
)
async def list_guardians(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    status_filter: Optional[GuardianStatus] = Query(None, alias="status", description="Filter by status"),
    search: Optional[str] = Query(None, description="Fuzzy match search on names, mobile, email, Aadhaar, or PAN"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("guardian.read")),
    service: GuardianService = Depends(get_guardian_service)
) -> APIResponse[List[GuardianResponse]]:
    guardians = await service.guardian_repo.get_multi(
        school_id=school_id,
        tenant_id=tenant_id,
        status=status_filter,
        search=search,
        skip=skip,
        limit=limit
    )
    responses = [GuardianResponse.model_validate(g) for g in guardians]
    return APIResponse[List[GuardianResponse]](
        success=True,
        message="Guardians fetched successfully.",
        data=responses
    )

@router.get(
    "/{id}",
    response_model=APIResponse[GuardianResponse],
    status_code=status.HTTP_200_OK,
    summary="Get guardian profile details",
    description="Retrieves guardian profile attributes scoped by tenant and school."
)
async def get_guardian(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("guardian.read")),
    service: GuardianService = Depends(get_guardian_service)
) -> APIResponse[GuardianResponse]:
    db_obj = await service.guardian_repo.get_by_id(id, school_id, tenant_id)
    if not db_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Guardian profile not found."
        )
    return APIResponse[GuardianResponse](
        success=True,
        message="Guardian details fetched successfully.",
        data=GuardianResponse.model_validate(db_obj)
    )

@router.put(
    "/{id}",
    response_model=APIResponse[GuardianResponse],
    status_code=status.HTTP_200_OK,
    summary="Update guardian details",
    description="Modifies guardian parameters scoped by tenant and school."
)
async def update_guardian(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    obj_in: GuardianUpdate = ...,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("guardian.update")),
    service: GuardianService = Depends(get_guardian_service)
) -> APIResponse[GuardianResponse]:
    db_obj = await service.update_guardian(tenant_id, school_id, id, obj_in, updated_by=current_user.id)
    return APIResponse[GuardianResponse](
        success=True,
        message="Guardian updated successfully.",
        data=GuardianResponse.model_validate(db_obj)
    )

@router.delete(
    "/{id}",
    response_model=APIResponse[GuardianResponse],
    status_code=status.HTTP_200_OK,
    summary="Soft-delete guardian profile",
    description="Soft-deletes the guardian profile, updating status to INACTIVE."
)
async def delete_guardian(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("guardian.delete")),
    service: GuardianService = Depends(get_guardian_service)
) -> APIResponse[GuardianResponse]:
    db_obj = await service.delete_guardian(tenant_id, school_id, id, deleted_by=current_user.id)
    return APIResponse[GuardianResponse](
        success=True,
        message="Guardian deleted successfully.",
        data=GuardianResponse.model_validate(db_obj)
    )
