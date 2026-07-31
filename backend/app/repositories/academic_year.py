import uuid
from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.schemas.academic_year import AcademicYearCreate, AcademicYearUpdate

class AcademicYearRepository:
    """
    Repository for AcademicYear database queries and transactions.
    Filters out soft-deleted records and scopes queries by tenant_id and school_id.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(
        self, ay_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[AcademicYear]:
        """
        Retrieves a single academic year by UUID within school and tenant scopes.
        """
        stmt = select(AcademicYear).where(
            AcademicYear.id == ay_id,
            AcademicYear.school_id == school_id,
            AcademicYear.tenant_id == tenant_id,
            AcademicYear.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_code(
        self, code: str, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[AcademicYear]:
        """
        Retrieves a single academic year by code within school and tenant scopes.
        """
        stmt = select(AcademicYear).where(
            AcademicYear.code == code,
            AcademicYear.school_id == school_id,
            AcademicYear.tenant_id == tenant_id,
            AcademicYear.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_name(
        self, name: str, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[AcademicYear]:
        """
        Retrieves a single academic year by name within school and tenant scopes.
        """
        stmt = select(AcademicYear).where(
            AcademicYear.name == name,
            AcademicYear.school_id == school_id,
            AcademicYear.tenant_id == tenant_id,
            AcademicYear.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_current_year(
        self, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[AcademicYear]:
        """
        Retrieves the marked current year for a school campus.
        """
        stmt = select(AcademicYear).where(
            AcademicYear.is_current == True,  # noqa: E712
            AcademicYear.school_id == school_id,
            AcademicYear.tenant_id == tenant_id,
            AcademicYear.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_active_year(
        self, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[AcademicYear]:
        """
        Retrieves the active status year for a school campus.
        """
        stmt = select(AcademicYear).where(
            AcademicYear.status == AcademicYearStatus.ACTIVE,
            AcademicYear.school_id == school_id,
            AcademicYear.tenant_id == tenant_id,
            AcademicYear.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_multi(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        skip: int = 0,
        limit: int = 100,
        status: Optional[AcademicYearStatus] = None
    ) -> List[AcademicYear]:
        """
        Retrieves list of academic years under school with status filters.
        """
        stmt = select(AcademicYear).where(
            AcademicYear.school_id == school_id,
            AcademicYear.tenant_id == tenant_id,
            AcademicYear.deleted_at.is_(None)
        )
        if status is not None:
            stmt = stmt.where(AcademicYear.status == status)
            
        stmt = stmt.offset(skip).limit(limit)
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def get_all_active_ranges(
        self, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> List[AcademicYear]:
        """
        Fetches all active non-deleted academic years to support date overlap checks.
        """
        stmt = select(AcademicYear).where(
            AcademicYear.school_id == school_id,
            AcademicYear.tenant_id == tenant_id,
            AcademicYear.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def create(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        obj_in: AcademicYearCreate,
        created_by: Optional[uuid.UUID] = None
    ) -> AcademicYear:
        """
        Inserts a new academic year under tenant and school scopes.
        """
        db_obj = AcademicYear(
            **obj_in.model_dump(),
            tenant_id=tenant_id,
            school_id=school_id,
            created_by=created_by
        )
        self.db.add(db_obj)
        await self.db.commit()
        await self.db.refresh(db_obj)
        return db_obj

    async def update(
        self,
        db_obj: AcademicYear,
        obj_in: AcademicYearUpdate,
        updated_by: Optional[uuid.UUID] = None
    ) -> AcademicYear:
        """
        Saves updates and increments OCC version automatically.
        """
        update_data = obj_in.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(db_obj, field, value)
        db_obj.updated_by = updated_by
        self.db.add(db_obj)
        await self.db.commit()
        await self.db.refresh(db_obj)
        return db_obj

    async def soft_delete(
        self,
        db_obj: AcademicYear,
        deleted_by: Optional[uuid.UUID] = None
    ) -> AcademicYear:
        """
        Soft-deletes an academic year by setting deleted_at.
        """
        db_obj.deleted_at = datetime.now(timezone.utc)
        db_obj.updated_by = deleted_by
        self.db.add(db_obj)
        await self.db.commit()
        await self.db.refresh(db_obj)
        return db_obj
