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
        self,
        skip: int = 0,
        limit: int = 100,
        status_filter: Optional[str] = None,
        code: Optional[str] = None,
        search: Optional[str] = None
    ) -> List[Tenant]:
        """
        Lists active tenants matching page filters.
        """
        return await self.repo.get_multi(
            skip=skip, limit=limit, status=status_filter, code=code, search=search
        )

    async def create_tenant(
        self, obj_in: TenantCreate, created_by: Optional[uuid.UUID] = None
    ) -> Tenant:
        """
        Performs unique checks on code, subdomain, and email before registering a new tenant.
        """
        # Validate code uniqueness
        existing_code = await self.repo.get_by_code(obj_in.code, include_deleted=True)
        if existing_code:
            if existing_code.deleted_at is not None:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Tenant code '{obj_in.code}' is reserved by an archived/soft-deleted tenant. Permanently delete the archived tenant to reuse this code."
                )
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Tenant code '{obj_in.code}' is already registered."
            )

        # Validate subdomain uniqueness
        existing_subdomain = await self.repo.get_by_subdomain(obj_in.subdomain, include_deleted=True)
        if existing_subdomain:
            if existing_subdomain.deleted_at is not None:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Subdomain '{obj_in.subdomain}' is reserved by an archived/soft-deleted tenant. Permanently delete the archived tenant to reuse this subdomain."
                )
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Subdomain '{obj_in.subdomain}' is already taken."
            )

        # Validate email uniqueness
        existing_email = await self.repo.get_by_email(obj_in.email, include_deleted=True)
        if existing_email:
            if existing_email.deleted_at is not None:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Tenant contact email '{obj_in.email}' is reserved by an archived/soft-deleted tenant. Permanently delete the archived tenant to reuse this email."
                )
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
            existing_code = await self.repo.get_by_code(obj_in.code, include_deleted=True)
            if existing_code and existing_code.id != tenant_id:
                if existing_code.deleted_at is not None:
                    raise HTTPException(
                        status_code=status.HTTP_409_CONFLICT,
                        detail=f"Tenant code '{obj_in.code}' is reserved by an archived/soft-deleted tenant. Permanently delete the archived tenant to reuse this code."
                    )
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Tenant code '{obj_in.code}' is already registered."
                )

        # Validate subdomain uniqueness if changing
        if obj_in.subdomain is not None and obj_in.subdomain != tenant.subdomain:
            existing_subdomain = await self.repo.get_by_subdomain(obj_in.subdomain, include_deleted=True)
            if existing_subdomain and existing_subdomain.id != tenant_id:
                if existing_subdomain.deleted_at is not None:
                    raise HTTPException(
                        status_code=status.HTTP_409_CONFLICT,
                        detail=f"Subdomain '{obj_in.subdomain}' is reserved by an archived/soft-deleted tenant. Permanently delete the archived tenant to reuse this subdomain."
                    )
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Subdomain '{obj_in.subdomain}' is already taken."
                )

        # Validate email uniqueness if changing
        if obj_in.email is not None and obj_in.email != tenant.email:
            existing_email = await self.repo.get_by_email(obj_in.email, include_deleted=True)
            if existing_email and existing_email.id != tenant_id:
                if existing_email.deleted_at is not None:
                    raise HTTPException(
                        status_code=status.HTTP_409_CONFLICT,
                        detail=f"Tenant contact email '{obj_in.email}' is reserved by an archived/soft-deleted tenant. Permanently delete the archived tenant to reuse this email."
                    )
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
