import uuid
from typing import List, Optional
from fastapi import HTTPException, status
from app.models.tenant import Tenant
from app.repositories.tenant import TenantRepository
from app.schemas.tenant import TenantCreate, TenantUpdate

class TenantService:
    """
    Service Layer containing business validations for Tenants.
    Handles uniqueness checks for Code, Subdomain, and Email.
    """
    def __init__(self, repo: TenantRepository) -> None:
        self.repo = repo

    async def get_tenant(self, tenant_id: uuid.UUID) -> Tenant:
        """
        Retrieves a single tenant by UUID or raises a 404 error if not found.
        """
        tenant = await self.repo.get_by_id(tenant_id)
        if not tenant:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Tenant not found."
            )
        return tenant

    async def list_tenants(
        self, skip: int = 0, limit: int = 100, status_filter: Optional[str] = None
    ) -> List[Tenant]:
        """
        Lists active tenants matching page filters.
        """
        return await self.repo.get_multi(skip=skip, limit=limit, status=status_filter)

    async def create_tenant(
        self, obj_in: TenantCreate, created_by: Optional[uuid.UUID] = None
    ) -> Tenant:
        """
        Performs unique checks on code, subdomain, and email before registering a new tenant.
        """
        # Validate code uniqueness
        if await self.repo.get_by_code(obj_in.code):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Tenant code '{obj_in.code}' is already registered."
            )

        # Validate subdomain uniqueness
        if await self.repo.get_by_subdomain(obj_in.subdomain):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Subdomain '{obj_in.subdomain}' is already taken."
            )

        # Validate email uniqueness
        if await self.repo.get_by_email(obj_in.email):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Tenant contact email '{obj_in.email}' is already registered."
            )

        return await self.repo.create(obj_in, created_by=created_by)

    async def update_tenant(
        self, tenant_id: uuid.UUID, obj_in: TenantUpdate, updated_by: Optional[uuid.UUID] = None
    ) -> Tenant:
        """
        Loads the existing tenant, validates modifications for unique field violations, and performs the updates.
        """
        tenant = await self.get_tenant(tenant_id)

        # Validate code uniqueness if changing
        if obj_in.code is not None and obj_in.code != tenant.code:
            if await self.repo.get_by_code(obj_in.code):
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Tenant code '{obj_in.code}' is already registered."
                )

        # Validate subdomain uniqueness if changing
        if obj_in.subdomain is not None and obj_in.subdomain != tenant.subdomain:
            if await self.repo.get_by_subdomain(obj_in.subdomain):
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Subdomain '{obj_in.subdomain}' is already taken."
                )

        # Validate email uniqueness if changing
        if obj_in.email is not None and obj_in.email != tenant.email:
            if await self.repo.get_by_email(obj_in.email):
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Tenant contact email '{obj_in.email}' is already registered."
                )

        return await self.repo.update(tenant, obj_in, updated_by=updated_by)

    async def delete_tenant(
        self, tenant_id: uuid.UUID, deleted_by: Optional[uuid.UUID] = None
    ) -> Tenant:
        """
        Performs soft-delete operations on the selected tenant.
        """
        tenant = await self.get_tenant(tenant_id)
        return await self.repo.soft_delete(tenant, deleted_by=deleted_by)
