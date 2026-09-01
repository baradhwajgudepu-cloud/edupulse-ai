import uuid
from typing import List, Optional
from fastapi import HTTPException, status
from app.models.school import School, SchoolBoard, SchoolStatus
from app.repositories.school import SchoolRepository
from app.schemas.school import SchoolCreate, SchoolUpdate

class SchoolService:
    """
    Service Layer containing business validations for Schools.
    Validates composite uniqueness (code, email) within the scope of a tenant,
    and global uniqueness for registry identifiers (UDISE).
    """
    def __init__(self, repo: SchoolRepository) -> None:
        self.repo = repo

    async def get_school(self, school_id: uuid.UUID, tenant_id: uuid.UUID) -> School:
        """
        Retrieves a single school by UUID within tenant scope, or raises a 404 error if not found.
        """
        school = await self.repo.get_by_id(school_id, tenant_id)
        if not school:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="School not found under the active tenant scope."
            )
        return school

    async def list_schools(
        self,
        tenant_id: uuid.UUID,
        skip: int = 0,
        limit: int = 100,
        status_filter: Optional[SchoolStatus] = None,
        board: Optional[SchoolBoard] = None,
        is_active: Optional[bool] = None
    ) -> List[School]:
        """
        Lists active schools scoped by tenant.
        """
        return await self.repo.get_multi(
            tenant_id=tenant_id,
            skip=skip,
            limit=limit,
            status=status_filter,
            board=board,
            is_active=is_active
        )

    async def create_school(
        self,
        tenant_id: uuid.UUID,
        obj_in: SchoolCreate,
        created_by: Optional[uuid.UUID] = None
    ) -> School:
        """
        Registers a new school campus under tenant_id, checking unique constraints.
        """
        # Validate composite (tenant_id, code) uniqueness
        if await self.repo.get_by_code(tenant_id, obj_in.code):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"School code '{obj_in.code}' is already registered under this tenant."
            )

        # Validate composite (tenant_id, email) uniqueness
        if await self.repo.get_by_email(tenant_id, obj_in.email):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"School contact email '{obj_in.email}' is already registered under this tenant."
            )

        # Validate global UDISE uniqueness if provided
        if obj_in.udise_code:
            if await self.repo.get_by_udise(obj_in.udise_code):
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"School UDISE code '{obj_in.udise_code}' is already registered globally."
                )

        return await self.repo.create(tenant_id, obj_in, created_by=created_by)

    async def update_school(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        obj_in: SchoolUpdate,
        updated_by: Optional[uuid.UUID] = None
    ) -> School:
        """
        Modifies properties of an existing School, verifying unique constraint changes.
        """
        school = await self.get_school(school_id, tenant_id)

        # Validate code uniqueness if changing
        if obj_in.code is not None and obj_in.code != school.code:
            if await self.repo.get_by_code(tenant_id, obj_in.code):
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"School code '{obj_in.code}' is already registered under this tenant."
                )

        # Validate email uniqueness if changing
        if obj_in.email is not None and obj_in.email != school.email:
            if await self.repo.get_by_email(tenant_id, obj_in.email):
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"School contact email '{obj_in.email}' is already registered under this tenant."
                )

        # Validate UDISE uniqueness if changing
        if obj_in.udise_code is not None and obj_in.udise_code != school.udise_code:
            if await self.repo.get_by_udise(obj_in.udise_code):
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"School UDISE code '{obj_in.udise_code}' is already registered globally."
                )

        return await self.repo.update(school, obj_in, updated_by=updated_by)

    async def delete_school(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        deleted_by: Optional[uuid.UUID] = None
    ) -> School:
        """
        Soft-deletes the selected school.
        """
        school = await self.get_school(school_id, tenant_id)
        return await self.repo.soft_delete(school, deleted_by=deleted_by)

    async def update_logo(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        logo_url: Optional[str]
    ) -> School:
        """
        Updates the logo_url for a school within the tenant scope.
        """
        school = await self.get_school(school_id, tenant_id)
        school.logo_url = logo_url
        await self.repo.db.commit()
        await self.repo.db.refresh(school)
        return school
