import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.school import get_school_service
from app.services.school import SchoolService
from app.schemas.school import SchoolCreate, SchoolUpdate, SchoolResponse
from app.models.school import SchoolBoard, SchoolStatus
from app.schemas.response import APIResponse

router = APIRouter()

@router.post(
    "",
    response_model=APIResponse[SchoolResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create a new school campus",
    description="Registers a new school campus scoped under the active tenant, with composite uniqueness validation."
)
async def create_school(
    obj_in: SchoolCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: SchoolService = Depends(get_school_service)
) -> APIResponse[SchoolResponse]:
    """
    Registers a new school campus in the active tenant.
    """
    school = await service.create_school(tenant_id, obj_in)
    school_response = SchoolResponse.model_validate(school)
    return APIResponse[SchoolResponse](
        success=True,
        message="School created successfully.",
        data=school_response
    )

@router.get(
    "",
    response_model=APIResponse[List[SchoolResponse]],
    status_code=status.HTTP_200_OK,
    summary="List all schools under active tenant",
    description="Retrieves a list of school campuses scoped by tenant with pagination and optional filters."
)
async def list_schools(
    skip: int = Query(0, ge=0, description="Number of records to skip"),
    limit: int = Query(100, ge=1, le=100, description="Limit count of records returned"),
    status: Optional[SchoolStatus] = Query(None, description="Filter by status (ACTIVE/INACTIVE/SUSPENDED)"),
    board: Optional[SchoolBoard] = Query(None, description="Filter by board Affiliation"),
    is_active: Optional[bool] = Query(None, description="Filter by active switch"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: SchoolService = Depends(get_school_service)
) -> APIResponse[List[SchoolResponse]]:
    """
    Lists active schools matching page filters scoped by tenant.
    """
    schools = await service.list_schools(
        tenant_id=tenant_id,
        skip=skip,
        limit=limit,
        status_filter=status,
        board=board,
        is_active=is_active
    )
    school_responses = [SchoolResponse.model_validate(s) for s in schools]
    return APIResponse[List[SchoolResponse]](
        success=True,
        message="Schools fetched successfully.",
        data=school_responses
    )

@router.get(
    "/{id}",
    response_model=APIResponse[SchoolResponse],
    status_code=status.HTTP_200_OK,
    summary="Get school details",
    description="Retrieves details of a specific active school campus by UUID scoped by tenant."
)
async def get_school(
    id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: SchoolService = Depends(get_school_service)
) -> APIResponse[SchoolResponse]:
    """
    Fetches details of a single active school by UUID.
    """
    school = await service.get_school(id, tenant_id)
    school_response = SchoolResponse.model_validate(school)
    return APIResponse[SchoolResponse](
        success=True,
        message="School details fetched successfully.",
        data=school_response
    )

@router.put(
    "/{id}",
    response_model=APIResponse[SchoolResponse],
    status_code=status.HTTP_200_OK,
    summary="Update school details",
    description="Modifies school attributes scoped by tenant, verifying unique constraints."
)
async def update_school(
    id: uuid.UUID,
    obj_in: SchoolUpdate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: SchoolService = Depends(get_school_service)
) -> APIResponse[SchoolResponse]:
    """
    Updates properties of an existing school campus.
    """
    school = await service.update_school(tenant_id, id, obj_in)
    school_response = SchoolResponse.model_validate(school)
    return APIResponse[SchoolResponse](
        success=True,
        message="School updated successfully.",
        data=school_response
    )

@router.delete(
    "/{id}",
    response_model=APIResponse[SchoolResponse],
    status_code=status.HTTP_200_OK,
    summary="Soft-delete school",
    description="Soft-deletes the selected school scoped by tenant."
)
async def delete_school(
    id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: SchoolService = Depends(get_school_service)
) -> APIResponse[SchoolResponse]:
    """
    Performs soft-delete operations on the selected school.
    """
    school = await service.delete_school(tenant_id, id)
    school_response = SchoolResponse.model_validate(school)
    return APIResponse[SchoolResponse](
        success=True,
        message="School deleted successfully.",
        data=school_response
    )
