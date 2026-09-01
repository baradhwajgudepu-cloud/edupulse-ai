import uuid
from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy import select, text, update
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
        Atomically soft-deletes the school and all dependent entities,
        cleans up school_users associations, and soft-deletes users
        who belong only to this school (excluding superusers/platform admins).
        """
        now = datetime.now(timezone.utc)
        db_obj.deleted_at = now
        db_obj.status = SchoolStatus.INACTIVE
        db_obj.is_active = False
        db_obj.updated_by = deleted_by
        self.db.add(db_obj)

        school_id = db_obj.id

        # 1. Cascade soft-delete all school-owned entities
        from app.db.base import Base
        for table_name, table in Base.metadata.tables.items():
            cols = [c.name for c in table.columns]
            if 'school_id' in cols and 'deleted_at' in cols and table_name != 'schools':
                stmt = (
                    table.update()
                    .where(table.c.school_id == school_id, table.c.deleted_at.is_(None))
                    .values(deleted_at=now, updated_by=deleted_by)
                )
                await self.db.execute(stmt)

        # 2. Identify users belonging to this school and determine if they belong only to this school
        from app.models.user import User, UserStatus
        from app.models.role import school_users
        from app.models.refresh_token import RefreshToken

        users_in_school_stmt = (
            select(school_users.c.user_id)
            .where(school_users.c.school_id == school_id)
        )
        res_school_users = await self.db.execute(users_in_school_stmt)
        user_ids_in_school = list(res_school_users.scalars().all())

        if user_ids_in_school:
            other_schools_stmt = (
                select(school_users.c.user_id)
                .join(School, School.id == school_users.c.school_id)
                .where(
                    school_users.c.user_id.in_(user_ids_in_school),
                    school_users.c.school_id != school_id,
                    School.deleted_at.is_(None)
                )
            )
            res_other = await self.db.execute(other_schools_stmt)
            users_with_other_schools = set(res_other.scalars().all())

            single_school_user_ids = [
                uid for uid in user_ids_in_school
                if uid not in users_with_other_schools
            ]

            if single_school_user_ids:
                # Soft-delete single-school users (excluding superusers)
                await self.db.execute(
                    update(User)
                    .where(User.id.in_(single_school_user_ids), User.is_superuser == False, User.deleted_at.is_(None))
                    .values(deleted_at=now, status=UserStatus.INACTIVE, updated_by=deleted_by)
                )
                # Revoke refresh tokens
                await self.db.execute(
                    update(RefreshToken)
                    .where(RefreshToken.user_id.in_(single_school_user_ids), RefreshToken.deleted_at.is_(None))
                    .values(deleted_at=now)
                )

        # 3. Clean up school_users associations for this deleted school
        await self.db.execute(
            school_users.delete().where(school_users.c.school_id == school_id)
        )

        await self.db.commit()
        await self.db.refresh(db_obj)
        return db_obj
