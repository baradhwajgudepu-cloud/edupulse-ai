import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from app.api.dependencies.tenant import get_tenant_service
from app.services.tenant import TenantService
from app.schemas.tenant import TenantCreate, TenantUpdate, TenantResponse
from app.models.tenant import TenantStatus
from app.schemas.response import APIResponse

router = APIRouter()

@router.post(
    "",
    response_model=APIResponse[TenantResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create a new tenant",
    description="Registers a new tenant organization with unique name, code, subdomain, and email."
)
async def create_tenant(
    obj_in: TenantCreate,
    service: TenantService = Depends(get_tenant_service)
) -> APIResponse[TenantResponse]:
    """
    Registers a new tenant organization in the system.
    """
    tenant = await service.create_tenant(obj_in)
    tenant_response = TenantResponse.model_validate(tenant)
    return APIResponse[TenantResponse](
        success=True,
        message="Tenant created successfully.",
        data=tenant_response
    )

@router.get(
    "",
    response_model=APIResponse[List[TenantResponse]],
    status_code=status.HTTP_200_OK,
    summary="List all tenants",
    description="Retrieves a list of active tenants with pagination filters."
)
async def list_tenants(
    skip: int = Query(0, ge=0, description="Number of records to skip"),
    limit: int = Query(100, ge=1, le=100, description="Limit count of records returned"),
    status: Optional[TenantStatus] = Query(None, description="Filter by status (ACTIVE/INACTIVE/SUSPENDED)"),
    service: TenantService = Depends(get_tenant_service)
) -> APIResponse[List[TenantResponse]]:
    """
    Lists active tenants with pagination support.
    """
    tenants = await service.list_tenants(skip=skip, limit=limit, status_filter=status)
    tenant_responses = [TenantResponse.model_validate(t) for t in tenants]
    return APIResponse[List[TenantResponse]](
        success=True,
        message="Tenants fetched successfully.",
        data=tenant_responses
    )

@router.get(
    "/{id}",
    response_model=APIResponse[TenantResponse],
    status_code=status.HTTP_200_OK,
    summary="Get tenant details",
    description="Retrieves parameters of a specific active tenant by UUID."
)
async def get_tenant(
    id: uuid.UUID,
    service: TenantService = Depends(get_tenant_service)
) -> APIResponse[TenantResponse]:
    """
    Fetches details of a single active tenant by UUID.
    """
    tenant = await service.get_tenant(id)
    tenant_response = TenantResponse.model_validate(tenant)
    return APIResponse[TenantResponse](
        success=True,
        message="Tenant details fetched successfully.",
        data=tenant_response
    )

@router.put(
    "/{id}",
    response_model=APIResponse[TenantResponse],
    status_code=status.HTTP_200_OK,
    summary="Update tenant details",
    description="Modifies the configuration parameters of an existing active tenant."
)
async def update_tenant(
    id: uuid.UUID,
    obj_in: TenantUpdate,
    service: TenantService = Depends(get_tenant_service)
) -> APIResponse[TenantResponse]:
    """
    Updates parameters of an active tenant.
    """
    tenant = await service.update_tenant(tenant_id=id, obj_in=obj_in)
    tenant_response = TenantResponse.model_validate(tenant)
    return APIResponse[TenantResponse](
        success=True,
        message="Tenant updated successfully.",
        data=tenant_response
    )

@router.delete(
    "/{id}",
    response_model=APIResponse[TenantResponse],
    status_code=status.HTTP_200_OK,
    summary="Soft-delete tenant",
    description="Soft-deletes a tenant by marking it as deleted while preserving histories."
)
async def delete_tenant(
    id: uuid.UUID,
    service: TenantService = Depends(get_tenant_service)
) -> APIResponse[TenantResponse]:
    """
    Soft-deletes a tenant by UUID.
    """
    tenant = await service.delete_tenant(id)
    tenant_response = TenantResponse.model_validate(tenant)
    return APIResponse[TenantResponse](
        success=True,
        message="Tenant soft-deleted successfully.",
        data=tenant_response
    )
