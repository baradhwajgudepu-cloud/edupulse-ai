import uuid
from typing import List, Optional
from datetime import datetime, timezone
from sqlalchemy import select, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.section import Section, SectionStatus
from app.schemas.section import SectionCreate, SectionUpdate

class SectionRepository:
    """
    Repository layer for Section database operations.
    Enforces multi-tenancy limits and soft deletion (deleted_at IS NULL).
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(
        self, section_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[Section]:
        """
        Retrieves a single section by UUID scoped to school and tenant.
        """
        stmt = select(Section).where(
            Section.id == section_id,
            Section.school_id == school_id,
            Section.tenant_id == tenant_id,
            Section.deleted_at.is_(None)
        ).options(selectinload(Section.class_obj))
        
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_code(
        self, code: str, class_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[Section]:
        """
        Retrieves a section by code within a specific class.
        Used for duplicate code check.
        """
        stmt = select(Section).where(
            Section.code == code,
            Section.class_id == class_id,
            Section.tenant_id == tenant_id,
            Section.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_name(
        self, name: str, class_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[Section]:
        """
        Retrieves a section by name within a specific class.
        Used for duplicate name check.
        """
        stmt = select(Section).where(
            Section.name == name,
            Section.class_id == class_id,
            Section.tenant_id == tenant_id,
            Section.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_multi(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        academic_year_id: Optional[uuid.UUID] = None,
        class_id: Optional[uuid.UUID] = None,
        status: Optional[SectionStatus] = None,
        search: Optional[str] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[Section]:
        """
        Retrieves paginated sections matching tenant, school, academic year, class, and status.
        Supports fuzzy name or code searching and sorts by sort_order.
        """
        filters = [
            Section.school_id == school_id,
            Section.tenant_id == tenant_id,
            Section.deleted_at.is_(None)
        ]

        if academic_year_id:
            filters.append(Section.academic_year_id == academic_year_id)
        if class_id:
            filters.append(Section.class_id == class_id)
        if status:
            filters.append(Section.status == status)
        if search:
            search_clause = or_(
                Section.name.ilike(f"%{search}%"),
                Section.code.ilike(f"%{search}%")
            )
            filters.append(search_clause)

        stmt = (
            select(Section)
            .where(and_(*filters))
            .order_by(Section.sort_order, Section.name)
            .offset(skip)
            .limit(limit)
            .options(selectinload(Section.class_obj))
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def create(
        self,
        tenant_id: uuid.UUID,
        obj_in: SectionCreate,
        created_by: Optional[uuid.UUID] = None
    ) -> Section:
        """
        Creates and returns a transient Section object. Does not commit.
        """
        db_obj = Section(
            name=obj_in.name,
            code=obj_in.code,
            capacity=obj_in.capacity,
            room_number=obj_in.room_number,
            sort_order=obj_in.sort_order,
            description=obj_in.description,
            settings=obj_in.settings,
            ai_metrics=obj_in.ai_metrics,
            tenant_id=tenant_id,
            school_id=obj_in.school_id,
            academic_year_id=obj_in.academic_year_id,
            class_id=obj_in.class_id,
            created_by=created_by
        )
        self.db.add(db_obj)
        return db_obj

    async def update(
        self,
        db_obj: Section,
        obj_in: SectionUpdate | dict,
        updated_by: Optional[uuid.UUID] = None
    ) -> Section:
        """
        Updates basic properties on Section. Does not commit.
        """
        if isinstance(obj_in, dict):
            update_data = obj_in
        else:
            update_data = obj_in.model_dump(exclude_unset=True)

        for field, value in update_data.items():
            setattr(db_obj, field, value)

        db_obj.updated_by = updated_by
        self.db.add(db_obj)
        return db_obj

    async def soft_delete(
        self,
        db_obj: Section,
        deleted_by: Optional[uuid.UUID] = None
    ) -> Section:
        """
        Marks Section as soft-deleted and inactive. Does not commit.
        """
        db_obj.deleted_at = datetime.now(timezone.utc)
        db_obj.status = SectionStatus.INACTIVE
        db_obj.is_active = False
        db_obj.updated_by = deleted_by
        self.db.add(db_obj)
        return db_obj
