import uuid
from datetime import datetime, timezone
from typing import List, Optional, Sequence
from sqlalchemy import select, update, or_, func
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.user import User, UserStatus
from app.models.role import Role, school_users, user_roles
from app.models.permission import Permission
from app.models.refresh_token import RefreshToken
from app.schemas.auth import UserCreate, UserUpdate, RoleCreate, RoleUpdate


class UserRepository:
    """
    Repository for User database operations.
    Handles loading of nested Roles, Permissions, and School memberships.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(self, user_id: uuid.UUID, tenant_id: uuid.UUID) -> Optional[User]:
        """
        Retrieves a single user by ID, loading roles, nested permissions, and schools.
        """
        stmt = select(User).where(
            User.id == user_id,
            User.tenant_id == tenant_id,
            User.deleted_at.is_(None)
        ).options(
            selectinload(User.roles).selectinload(Role.permissions),
            selectinload(User.schools)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_id_platform(self, user_id: uuid.UUID) -> Optional[User]:
        """
        Retrieves a single user by ID globally without tenant restriction, loading roles/permissions.
        """
        stmt = select(User).where(
            User.id == user_id,
            User.deleted_at.is_(None)
        ).options(
            selectinload(User.roles).selectinload(Role.permissions),
            selectinload(User.schools)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_email(self, email: str, tenant_id: uuid.UUID) -> Optional[User]:
        """
        Retrieves a single user by email within the tenant boundary, loading permissions.
        """
        stmt = select(User).where(
            User.email == email,
            User.tenant_id == tenant_id,
            User.deleted_at.is_(None)
        ).options(
            selectinload(User.roles).selectinload(Role.permissions),
            selectinload(User.schools)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_email_or_login_id(self, identifier: str, tenant_id: uuid.UUID) -> Optional[User]:
        """
        Retrieves a single user by email or login_id within the tenant boundary, loading permissions.
        """
        stmt = select(User).where(
            or_(func.lower(User.email) == identifier.lower(), func.lower(User.login_id) == identifier.lower()),
            User.tenant_id == tenant_id,
            User.deleted_at.is_(None)
        ).options(
            selectinload(User.roles).selectinload(Role.permissions),
            selectinload(User.schools)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_email_platform(self, email: str) -> Optional[User]:
        """
        Retrieves a single user by email globally without tenant restriction, loading permissions.
        """
        stmt = select(User).where(
            User.email == email,
            User.deleted_at.is_(None)
        ).options(
            selectinload(User.roles).selectinload(Role.permissions),
            selectinload(User.schools)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_password_reset_hash(self, token_hash: str) -> Optional[User]:
        """
        Retrieves a user by their active password reset hash.
        """
        stmt = select(User).where(
            User.password_reset_hash == token_hash,
            User.deleted_at.is_(None)
        ).options(
            selectinload(User.roles).selectinload(Role.permissions),
            selectinload(User.schools)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()


    async def create(
        self,
        tenant_id: uuid.UUID,
        obj_in: UserCreate,
        hashed_password: str,
        created_by: Optional[uuid.UUID] = None
    ) -> User:
        """
        Creates a new user record. Does NOT assign roles/schools (handled in service layer).
        """
        db_obj = User(
            email=obj_in.email,
            hashed_password=hashed_password,
            first_name=obj_in.first_name,
            last_name=obj_in.last_name,
            tenant_id=tenant_id,
            status=UserStatus.ACTIVE,
            created_by=created_by
        )
        self.db.add(db_obj)
        return db_obj

    async def update(
        self,
        db_obj: User,
        obj_in: UserUpdate | dict,
        updated_by: Optional[uuid.UUID] = None
    ) -> User:
        """
        Updates basic properties and increments version.
        """
        if isinstance(obj_in, dict):
            update_data = obj_in
        else:
            update_data = obj_in.model_dump(exclude_unset=True)

        for field, value in update_data.items():
            if field not in ("school_ids", "role_ids"):
                setattr(db_obj, field, value)

        db_obj.updated_by = updated_by
        self.db.add(db_obj)
        return db_obj

    async def soft_delete(self, db_obj: User, deleted_by: Optional[uuid.UUID] = None) -> User:
        """
        Soft-deletes the user.
        """
        db_obj.deleted_at = datetime.now(timezone.utc)
        db_obj.status = UserStatus.INACTIVE
        db_obj.updated_by = deleted_by
        self.db.add(db_obj)
        await self.db.commit()
        await self.db.refresh(db_obj)
        return db_obj


class RoleRepository:
    """
    Repository for Role database operations.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(self, role_id: uuid.UUID, tenant_id: uuid.UUID) -> Optional[Role]:
        stmt = select(Role).where(
            Role.id == role_id,
            Role.tenant_id == tenant_id,
            Role.deleted_at.is_(None)
        ).options(selectinload(Role.permissions))
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_code(self, code: str, tenant_id: uuid.UUID) -> Optional[Role]:
        stmt = select(Role).where(
            Role.code == code,
            Role.tenant_id == tenant_id,
            Role.deleted_at.is_(None)
        ).options(selectinload(Role.permissions))
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_multi(
        self, tenant_id: uuid.UUID, skip: int = 0, limit: int = 100
    ) -> List[Role]:
        stmt = select(Role).where(
            Role.tenant_id == tenant_id,
            Role.deleted_at.is_(None)
        ).options(selectinload(Role.permissions)).offset(skip).limit(limit)
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def create(
        self, tenant_id: uuid.UUID, obj_in: RoleCreate, is_system: bool = False, created_by: Optional[uuid.UUID] = None
    ) -> Role:
        db_obj = Role(
            name=obj_in.name,
            code=obj_in.code,
            description=obj_in.description,
            tenant_id=tenant_id,
            is_system=is_system,
            created_by=created_by
        )
        self.db.add(db_obj)
        return db_obj

    async def update(
        self, db_obj: Role, obj_in: RoleUpdate, updated_by: Optional[uuid.UUID] = None
    ) -> Role:
        update_data = obj_in.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            if field != "permission_ids":
                setattr(db_obj, field, value)
        db_obj.updated_by = updated_by
        self.db.add(db_obj)
        return db_obj


class PermissionRepository:
    """
    Repository for Permission database operations.
    Permissions are global system configurations.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(self, perm_id: uuid.UUID) -> Optional[Permission]:
        stmt = select(Permission).where(Permission.id == perm_id)
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_code(self, code: str) -> Optional[Permission]:
        stmt = select(Permission).where(Permission.code == code)
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_multi(self, skip: int = 0, limit: int = 200) -> List[Permission]:
        stmt = select(Permission).offset(skip).limit(limit)
        result = await self.db.execute(stmt)
        return list(result.scalars().all())


class RefreshTokenRepository:
    """
    Repository for storing and validating cryptographically secure Refresh Tokens.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_hash(self, token_hash: str) -> Optional[RefreshToken]:
        """
        Retrieves refresh token details by SHA-256 hash.
        """
        stmt = select(RefreshToken).where(RefreshToken.token_hash == token_hash)
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def create(
        self, user_id: uuid.UUID, token_hash: str, expires_at: datetime, tenant_id: Optional[uuid.UUID] = None, created_by_ip: Optional[str] = None
    ) -> RefreshToken:
        db_obj = RefreshToken(
            user_id=user_id,
            token_hash=token_hash,
            expires_at=expires_at,
            tenant_id=tenant_id,
            created_by_ip=created_by_ip
        )
        self.db.add(db_obj)
        await self.db.commit()
        await self.db.refresh(db_obj)
        return db_obj

    async def revoke(self, db_obj: RefreshToken) -> RefreshToken:
        """
        Revokes a single refresh token session.
        """
        db_obj.is_revoked = True
        self.db.add(db_obj)
        await self.db.commit()
        await self.db.refresh(db_obj)
        return db_obj

    async def revoke_all_for_user(self, user_id: uuid.UUID) -> None:
        """
        Revokes all refresh tokens for a user (used during token reuse threat detection).
        """
        stmt = update(RefreshToken).where(
            RefreshToken.user_id == user_id,
            RefreshToken.is_revoked == False  # noqa: E712
        ).values(is_revoked=True)
        await self.db.execute(stmt)
        await self.db.commit()
