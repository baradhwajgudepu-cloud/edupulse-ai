import uuid
from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.school import School, SchoolBoard, SchoolStatus
from app.schemas.school import SchoolCreate, SchoolUpdate

class SchoolRepository:
    """
    Repository for School database queries and transactions.
    Filters out soft-deleted records (deleted_at is not null) and scopes queries by tenant_id.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(self, school_id: uuid.UUID, tenant_id: uuid.UUID) -> Optional[School]:
        """
        Retrieves a single school by UUID within tenant scope.
        """
        stmt = select(School).where(
            School.id == school_id,
            School.tenant_id == tenant_id,
            School.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_code(self, tenant_id: uuid.UUID, code: str) -> Optional[School]:
        """
        Retrieves a single school by its unique code within tenant scope.
        """
        stmt = select(School).where(
            School.tenant_id == tenant_id,
            School.code == code,
            School.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_email(self, tenant_id: uuid.UUID, email: str) -> Optional[School]:
        """
        Retrieves a single school by its email within tenant scope.
        """
        stmt = select(School).where(
            School.tenant_id == tenant_id,
            School.email == email,
            School.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_udise(self, udise_code: str) -> Optional[School]:
        """
        Retrieves a single school globally by UDISE code.
        """
        stmt = select(School).where(
            School.udise_code == udise_code,
            School.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_multi(
        self,
        tenant_id: uuid.UUID,
        skip: int = 0,
        limit: int = 100,
        status: Optional[SchoolStatus] = None,
        board: Optional[SchoolBoard] = None,
        is_active: Optional[bool] = None
    ) -> List[School]:
        """
        Retrieves a list of schools within tenant scope with filters.
        """
        stmt = select(School).where(
            School.tenant_id == tenant_id,
            School.deleted_at.is_(None)
        )
        if status is not None:
            stmt = stmt.where(School.status == status)
        if board is not None:
            stmt = stmt.where(School.board == board)
        if is_active is not None:
            stmt = stmt.where(School.is_active == is_active)
            
        stmt = stmt.offset(skip).limit(limit)
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def create(
        self,
        tenant_id: uuid.UUID,
        obj_in: SchoolCreate,
        created_by: Optional[uuid.UUID] = None
    ) -> School:
        """
        Creates and registers a new School under tenant_id.
        """
        db_obj = School(
            **obj_in.model_dump(),
            tenant_id=tenant_id,
            created_by=created_by
        )
        self.db.add(db_obj)
        await self.db.commit()
        await self.db.refresh(db_obj)
        return db_obj

    async def update(
        self,
        db_obj: School,
        obj_in: SchoolUpdate,
        updated_by: Optional[uuid.UUID] = None
    ) -> School:
        """
        Updates fields of an existing School and increments version (OCC).
        """
        update_data = obj_in.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            if field == "settings" and value is not None:
                existing_settings = db_obj.settings or {}
                new_settings = dict(existing_settings)
                for k, v in value.items():
                    if isinstance(v, dict) and isinstance(new_settings.get(k), dict):
                        new_settings[k] = {**new_settings[k], **v}
                    else:
                        new_settings[k] = v
                db_obj.settings = new_settings
            else:
                setattr(db_obj, field, value)
        db_obj.updated_by = updated_by
        self.db.add(db_obj)
        await self.db.commit()
        await self.db.refresh(db_obj)
        return db_obj

    async def soft_delete(
        self,
        db_obj: School,
        deleted_by: Optional[uuid.UUID] = None
    ) -> School:
        """
        Soft-deletes the school by setting the deleted_at property.
        """
        db_obj.deleted_at = datetime.now(timezone.utc)
        db_obj.updated_by = deleted_by
        self.db.add(db_obj)
        await self.db.commit()
        await self.db.refresh(db_obj)
        return db_obj
