import uuid
from typing import List, Optional
from datetime import datetime, timezone
from sqlalchemy import select, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.syllabus import Syllabus
from app.schemas.syllabus import SyllabusCreate, SyllabusUpdate

class SyllabusRepository:
    """
    Repository layer for Syllabus database operations.
    Enforces multi-tenancy boundaries, school boundaries, and soft deletions.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(
        self, syllabus_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[Syllabus]:
        """
        Retrieves a single syllabus by ID scoped to school and tenant.
        """
        stmt = select(Syllabus).where(
            Syllabus.id == syllabus_id,
            Syllabus.school_id == school_id,
            Syllabus.tenant_id == tenant_id,
            Syllabus.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_code(
        self,
        syllabus_code: str,
        academic_year_id: uuid.UUID,
        class_id: uuid.UUID,
        subject_id: uuid.UUID,
        tenant_id: uuid.UUID
    ) -> Optional[Syllabus]:
        """
        Retrieves syllabus by code scoped to academic year, class, subject, and tenant.
        """
        stmt = select(Syllabus).where(
            Syllabus.syllabus_code == syllabus_code,
            Syllabus.academic_year_id == academic_year_id,
            Syllabus.class_id == class_id,
            Syllabus.subject_id == subject_id,
            Syllabus.tenant_id == tenant_id,
            Syllabus.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_multi(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        academic_year_id: Optional[uuid.UUID] = None,
        class_id: Optional[uuid.UUID] = None,
        subject_id: Optional[uuid.UUID] = None,
        search: Optional[str] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[Syllabus]:
        """
        Retrieves paginated list of syllabus entries scoped by tenant and school.
        Supports filtering and search.
        """
        filters = [
            Syllabus.school_id == school_id,
            Syllabus.tenant_id == tenant_id,
            Syllabus.deleted_at.is_(None)
        ]

        if academic_year_id:
            filters.append(Syllabus.academic_year_id == academic_year_id)
        if class_id:
            filters.append(Syllabus.class_id == class_id)
        if subject_id:
            filters.append(Syllabus.subject_id == subject_id)

        if search:
            search_clause = or_(
                Syllabus.unit_name.ilike(f"%{search}%"),
                Syllabus.chapter_name.ilike(f"%{search}%"),
                Syllabus.topic_name.ilike(f"%{search}%"),
                Syllabus.syllabus_code.ilike(f"%{search}%")
            )
            filters.append(search_clause)

        stmt = (
            select(Syllabus)
            .where(and_(*filters))
            .order_by(Syllabus.sequence_order, Syllabus.created_at)
            .offset(skip)
            .limit(limit)
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def create(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        obj_in: SyllabusCreate,
        created_by: Optional[uuid.UUID] = None
    ) -> Syllabus:
        """
        Creates and returns transient Syllabus entity.
        """
        db_obj = Syllabus(
            syllabus_code=obj_in.syllabus_code,
            unit_name=obj_in.unit_name,
            chapter_name=obj_in.chapter_name,
            topic_name=obj_in.topic_name,
            description=obj_in.description,
            sequence_order=obj_in.sequence_order,
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=academic_year_id,
            class_id=obj_in.class_id,
            subject_id=obj_in.subject_id,
            created_by=created_by
        )
        self.db.add(db_obj)
        return db_obj

    async def update(
        self,
        db_obj: Syllabus,
        obj_in: SyllabusUpdate | dict,
        updated_by: Optional[uuid.UUID] = None
    ) -> Syllabus:
        """
        Updates syllabus details.
        """
        update_data = obj_in if isinstance(obj_in, dict) else obj_in.model_dump(exclude_unset=True)
        for field, val in update_data.items():
            setattr(db_obj, field, val)

        db_obj.updated_at = datetime.now(timezone.utc)
        if updated_by:
            db_obj.updated_by = updated_by

        self.db.add(db_obj)
        return db_obj

    async def soft_delete(
        self, db_obj: Syllabus, deleted_by: Optional[uuid.UUID] = None
    ) -> Syllabus:
        """
        Applies soft deletion timestamp to Syllabus.
        """
        now = datetime.now(timezone.utc)
        db_obj.deleted_at = now
        db_obj.is_active = False
        if deleted_by:
            db_obj.updated_by = deleted_by
        
        self.db.add(db_obj)
        return db_obj
