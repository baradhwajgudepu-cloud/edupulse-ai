import uuid
from typing import List, Optional
from datetime import datetime, timezone
from sqlalchemy import select, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.class_entity import Class, ClassStatus
from app.schemas.class_entity import ClassCreate, ClassUpdate

class ClassRepository:
    """
    Repository layer for Class entity operations.
    Filters by tenant boundaries and excludes soft deleted rows (deleted_at IS NULL).
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(
        self, class_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[Class]:
        """
        Retrieves a single class by UUID scoped to tenant and school.
        """
        stmt = select(Class).where(
            Class.id == class_id,
            Class.school_id == school_id,
            Class.tenant_id == tenant_id,
            Class.deleted_at.is_(None)
        ).options(selectinload(Class.next_class))
        
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_code(
        self, code: str, academic_year_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[Class]:
        """
        Retrieves a class by code within a specific academic year.
        Used for collision detection.
        """
        stmt = select(Class).where(
            Class.code == code,
            Class.academic_year_id == academic_year_id,
            Class.tenant_id == tenant_id,
            Class.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_name(
        self, name: str, academic_year_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[Class]:
        """
        Retrieves a class by name within a specific academic year.
        Used for collision detection.
        """
        stmt = select(Class).where(
            Class.name == name,
            Class.academic_year_id == academic_year_id,
            Class.tenant_id == tenant_id,
            Class.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_multi(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        academic_year_id: Optional[uuid.UUID] = None,
        status: Optional[ClassStatus] = None,
        search: Optional[str] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[Class]:
        """
        Retrieves paginated classes, matching tenant, school, academic year, and status.
        Supports fuzzy name or code searching.
        """
        filters = [
            Class.school_id == school_id,
            Class.tenant_id == tenant_id,
            Class.deleted_at.is_(None)
        ]
        
        if academic_year_id:
            filters.append(Class.academic_year_id == academic_year_id)
        if status:
            filters.append(Class.status == status)
        if search:
            search_clause = or_(
                Class.name.ilike(f"%{search}%"),
                Class.code.ilike(f"%{search}%")
            )
            filters.append(search_clause)
            
        stmt = select(Class).where(and_(*filters)).offset(skip).limit(limit).options(selectinload(Class.next_class))
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def create(
        self,
        tenant_id: uuid.UUID,
        obj_in: ClassCreate,
        created_by: Optional[uuid.UUID] = None
    ) -> Class:
        """
        Creates and returns a transient Class object. Does not commit.
        """
        db_obj = Class(
            name=obj_in.name,
            display_name=obj_in.display_name,
            code=obj_in.code,
            level=obj_in.level,
            category=obj_in.category,
            stream=obj_in.stream,
            description=obj_in.description,
            capacity=obj_in.capacity,
            promotion_order=obj_in.promotion_order,
            next_class_id=obj_in.next_class_id,
            settings=obj_in.settings,
            ai_metrics=obj_in.ai_metrics,
            tenant_id=tenant_id,
            school_id=obj_in.school_id,
            academic_year_id=obj_in.academic_year_id,
            created_by=created_by
        )
        self.db.add(db_obj)
        return db_obj

    async def update(
        self,
        db_obj: Class,
        obj_in: ClassUpdate | dict,
        updated_by: Optional[uuid.UUID] = None
    ) -> Class:
        """
        Updates basic properties on the Class model instance. Does not commit.
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
        db_obj: Class,
        deleted_by: Optional[uuid.UUID] = None
    ) -> Class:
        """
        Marks Class as soft-deleted and inactive. Does not commit.
        """
        db_obj.deleted_at = datetime.now(timezone.utc)
        db_obj.status = ClassStatus.INACTIVE
        db_obj.is_active = False
        db_obj.updated_by = deleted_by
        self.db.add(db_obj)
        return db_obj
