import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from app.api.dependencies.tenant import get_tenant_service, get_tenant_deletion_service
from app.api.dependencies.auth import require_super_admin
from app.services.tenant import TenantService
from app.services.tenant_deletion import TenantDeletionService
from app.schemas.tenant import TenantCreate, TenantUpdate, TenantResponse, TenantDeletionSummary
from app.models.tenant import TenantStatus
from app.models.user import User
from app.schemas.response import APIResponse

router = APIRouter()

@router.post(
    "",
    response_model=APIResponse[TenantResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create a new tenant",
    description="Registers a new tenant organization with unique name, code, subdomain, and email. Supports idempotent resolution if requested."
)
async def create_tenant(
    obj_in: TenantCreate,
    idempotent: bool = Query(False, description="If true and tenant code already exists, returns existing tenant"),
    service: TenantService = Depends(get_tenant_service)
) -> APIResponse[TenantResponse]:
    """
    Registers a new tenant organization in the system or resolves existing if idempotent=True.
    """
    if idempotent:
        existing = await service.repo.get_by_code(obj_in.code)
        if existing and existing.is_active:
            return APIResponse[TenantResponse](
                success=True,
                message="Existing tenant resolved successfully.",
                data=TenantResponse.model_validate(existing)
            )
    tenant = await service.create_tenant(obj_in)
    tenant_response = TenantResponse.model_validate(tenant)
    return APIResponse[TenantResponse](
        success=True,
        message="Tenant created successfully.",
        data=tenant_response
    )

@router.get(
    "/by-code/{code}",
    response_model=APIResponse[TenantResponse],
    status_code=status.HTTP_200_OK,
    summary="Get tenant by code",
    description="Retrieves active tenant details by unique code identifier."
)
async def get_tenant_by_code(
    code: str,
    service: TenantService = Depends(get_tenant_service)
) -> APIResponse[TenantResponse]:
    """
    Fetches details of a single active tenant by unique code.
    """
    from fastapi import HTTPException
    tenant = await service.repo.get_by_code(code)
    if not tenant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Tenant with code '{code}' not found."
        )
    return APIResponse[TenantResponse](
        success=True,
        message="Tenant details fetched successfully.",
        data=TenantResponse.model_validate(tenant)
    )

@router.get(
    "",
    response_model=APIResponse[List[TenantResponse]],
    status_code=status.HTTP_200_OK,
    summary="List all tenants",
    description="Retrieves a list of active tenants with pagination filters, code lookup, and text search."
)
async def list_tenants(
    skip: int = Query(0, ge=0, description="Number of records to skip"),
    limit: int = Query(100, ge=1, le=100, description="Limit count of records returned"),
    status: Optional[TenantStatus] = Query(None, description="Filter by status (ACTIVE/INACTIVE/SUSPENDED)"),
    code: Optional[str] = Query(None, description="Lookup tenant by exact code"),
    search: Optional[str] = Query(None, description="Search tenants by name, code, or email"),
    service: TenantService = Depends(get_tenant_service)
) -> APIResponse[List[TenantResponse]]:
    """
    Lists active tenants with pagination and filtering support.
    """
    tenants = await service.list_tenants(skip=skip, limit=limit, status_filter=status, code=code, search=search)
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

@router.delete(
    "/{id}/permanent",
    response_model=APIResponse[TenantDeletionSummary],
    status_code=status.HTTP_200_OK,
    summary="Permanently delete tenant",
    description="Irreversibly deletes a tenant and all tenant-scoped entities. Protected against EDUPULSE_SYSTEM. Requires Super Admin privileges. Supports dry_run mode."
)
async def delete_tenant_permanent(
    id: uuid.UUID,
    dry_run: bool = Query(False, description="Simulate deletion and return counts without committing changes"),
    current_user: User = Depends(require_super_admin),
    service: TenantDeletionService = Depends(get_tenant_deletion_service)
) -> APIResponse[TenantDeletionSummary]:
    """
    Permanently deletes a tenant and all its associated data.
    """
    summary = await service.delete_tenant_permanent(
        tenant_id=id,
        current_user=current_user,
        dry_run=dry_run
    )
    msg = "Tenant deletion simulated successfully (dry run)." if dry_run else "Tenant permanently deleted successfully."
    return APIResponse[TenantDeletionSummary](
        success=True,
        message=msg,
        data=TenantDeletionSummary.model_validate(summary)
    )
