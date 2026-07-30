import uuid
from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.tenant import Tenant
from app.schemas.tenant import TenantCreate, TenantUpdate

class TenantRepository:
    """
    Repository for Tenant database queries and transactions.
    Filters out soft-deleted records (deleted_at is not null) by default.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(self, tenant_id: uuid.UUID) -> Optional[Tenant]:
        """
        Retrieves a single tenant by UUID.
        """
        stmt = select(Tenant).where(Tenant.id == tenant_id, Tenant.deleted_at.is_(None))
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_code(self, code: str) -> Optional[Tenant]:
        """
        Retrieves a single tenant by its unique identifier code.
        """
        stmt = select(Tenant).where(Tenant.code == code, Tenant.deleted_at.is_(None))
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_subdomain(self, subdomain: str) -> Optional[Tenant]:
        """
        Retrieves a single tenant by its unique subdomain.
        """
        stmt = select(Tenant).where(Tenant.subdomain == subdomain, Tenant.deleted_at.is_(None))
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_email(self, email: str) -> Optional[Tenant]:
        """
        Retrieves a single tenant by email address.
        """
        stmt = select(Tenant).where(Tenant.email == email, Tenant.deleted_at.is_(None))
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_multi(
        self, skip: int = 0, limit: int = 100, status: Optional[str] = None
    ) -> List[Tenant]:
        """
        Retrieves a list of tenants with optional status filtering.
        """
        stmt = select(Tenant).where(Tenant.deleted_at.is_(None))
        if status is not None:
            stmt = stmt.where(Tenant.status == status)
        stmt = stmt.offset(skip).limit(limit)
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def create(self, obj_in: TenantCreate, created_by: Optional[uuid.UUID] = None) -> Tenant:
        """
        Creates and registers a new Tenant in the database.
        """
        db_obj = Tenant(
            **obj_in.model_dump(),
            created_by=created_by
        )
        self.db.add(db_obj)
        await self.db.commit()
        await self.db.refresh(db_obj)
        return db_obj

    async def update(
        self, db_obj: Tenant, obj_in: TenantUpdate, updated_by: Optional[uuid.UUID] = None
    ) -> Tenant:
        """
        Updates fields of an existing Tenant.
        """
        update_data = obj_in.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(db_obj, field, value)
        db_obj.updated_by = updated_by
        self.db.add(db_obj)
        await self.db.commit()
        await self.db.refresh(db_obj)
        return db_obj

    async def soft_delete(self, db_obj: Tenant, deleted_by: Optional[uuid.UUID] = None) -> Tenant:
        """
        Soft-deletes the tenant by setting the deleted_at property.
        """
        db_obj.deleted_at = datetime.now(timezone.utc)
        db_obj.updated_by = deleted_by
        self.db.add(db_obj)
        await self.db.commit()
        await self.db.refresh(db_obj)
        return db_obj
