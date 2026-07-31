import uuid
import secrets
import hashlib
from datetime import datetime, timedelta, timezone
from typing import List, Optional
from sqlalchemy import select, func
from fastapi import HTTPException, status
from app.core.security import hash_password, verify_password, create_access_token
from app.models.user import User, UserStatus
from app.models.role import Role
from app.models.permission import Permission
from app.models.refresh_token import RefreshToken
from app.models.tenant import Tenant
from app.repositories.tenant import TenantRepository
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
from app.repositories.school import SchoolRepository
from app.schemas.tenant import TenantCreate
from app.schemas.auth import (
    UserCreate, UserUpdate, RoleCreate, RoleUpdate,
    LoginRequest, TokenResponse, PasswordChangeRequest,
    BootstrapRequest, BootstrapResponse
)

class AuthService:
    """
    Service Layer implementing Authentication and RBAC workflows.
    Enforces login lockouts, Token Rotation (RTR), and cryptographic password resets.
    """
    def __init__(
        self,
        user_repo: UserRepository,
        role_repo: RoleRepository,
        perm_repo: PermissionRepository,
        refresh_repo: RefreshTokenRepository,
        school_repo: SchoolRepository
    ) -> None:
        self.user_repo = user_repo
        self.role_repo = role_repo
        self.perm_repo = perm_repo
        self.refresh_repo = refresh_repo
        self.school_repo = school_repo

    async def authenticate(self, tenant_id: uuid.UUID, login_in: LoginRequest) -> User:
        """
        Authenticates user. Throttles brute-force attempts and updates login audit fields.
        """
        user = await self.user_repo.get_by_email(login_in.email, tenant_id)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password."
            )

        # 1. Lockout verification
        now = datetime.now(timezone.utc)
        if user.status == UserStatus.LOCKED:
            locked_until = user.locked_until
            if locked_until:
                if locked_until.tzinfo is None:
                    locked_until = locked_until.replace(tzinfo=timezone.utc)
                if locked_until > now:
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail=f"This account is locked due to multiple login failures. Try again after {locked_until}."
                    )
            else:
                # Unlock automatically if duration has expired
                user.status = UserStatus.ACTIVE
                user.failed_login_attempts = 0
                user.locked_until = None

        if user.status != UserStatus.ACTIVE:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied. Account status is currently '{user.status}'."
            )

        # 2. Password verification
        if not verify_password(login_in.password, user.hashed_password):
            user.failed_login_attempts += 1
            if user.failed_login_attempts >= 5:
                user.status = UserStatus.LOCKED
                user.locked_until = now + timedelta(minutes=15)
                await self.user_repo.db.commit()
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Too many failed login attempts. Your account has been locked for 15 minutes."
                )
            await self.user_repo.db.commit()
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password."
            )

        # 3. Successful authentication details
        user.failed_login_attempts = 0
        user.locked_until = None
        user.last_login = now
        await self.user_repo.db.commit()
        return user

    async def create_tokens(
        self, user: User, client_ip: Optional[str] = None
    ) -> TokenResponse:
        """
        Generates access token and refresh token pair, hashing and saving the refresh token.
        """
        # Minimal Access Token claims
        access_token = create_access_token(subject=user.id, tenant_id=user.tenant_id)
        
        # Cryptographically strong Refresh Token
        raw_refresh = secrets.token_hex(32)
        token_hash = hashlib.sha256(raw_refresh.encode()).hexdigest()
        
        expires_at = datetime.now(timezone.utc) + timedelta(days=7)
        await self.refresh_repo.create(
            user_id=user.id,
            token_hash=token_hash,
            expires_at=expires_at,
            created_by_ip=client_ip
        )
        return TokenResponse(access_token=access_token, refresh_token=raw_refresh)

    async def refresh_token_rotation(
        self, raw_refresh_token: str, client_ip: Optional[str] = None
    ) -> TokenResponse:
        """
        Validates refresh tokens and issues rotated pairs.
        Triggers alarms and invalidates session on reuse.
        """
        token_hash = hashlib.sha256(raw_refresh_token.encode()).hexdigest()
        db_token = await self.refresh_repo.get_by_hash(token_hash)
        
        if not db_token:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired session token."
            )

        # 1. Reuse Attack Detection (Replay Protection)
        if db_token.is_revoked:
            # Revoke all sessions for the user to secure accounts
            await self.refresh_repo.revoke_all_for_user(db_token.user_id)
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Refresh token reuse detected. All active login sessions revoked."
            )

        # 2. Expiration check
        expires_at = db_token.expires_at
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        if expires_at < datetime.now(timezone.utc):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Session token has expired."
            )

        # 3. Retrieve user to ensure account is active
        # Load user with empty tenant_id query as we scope by user_id
        stmt = select(User).where(User.id == db_token.user_id, User.deleted_at.is_(None))
        user_res = await self.user_repo.db.execute(stmt)
        user = user_res.scalar_one_or_none()
        if not user or user.status != UserStatus.ACTIVE:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="User account is locked or inactive."
            )

        # 4. Invalidate old token and issue new rotated pair
        await self.refresh_repo.revoke(db_token)
        return await self.create_tokens(user, client_ip=client_ip)

    async def logout(self, raw_refresh_token: str) -> None:
        """
        Revokes the refresh token to close session.
        """
        token_hash = hashlib.sha256(raw_refresh_token.encode()).hexdigest()
        db_token = await self.refresh_repo.get_by_hash(token_hash)
        if db_token:
            await self.refresh_repo.revoke(db_token)

    async def change_password(
        self, tenant_id: uuid.UUID, user_id: uuid.UUID, change_in: PasswordChangeRequest
    ) -> None:
        """
        Modifies password after validating active credentials.
        """
        user = await self.user_repo.get_by_id(user_id, tenant_id)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found."
            )

        if not verify_password(change_in.current_password, user.hashed_password):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Incorrect current password."
            )

        user.hashed_password = hash_password(change_in.new_password)
        await self.user_repo.db.commit()

    async def request_password_reset(self, tenant_id: uuid.UUID, email: str) -> None:
        """
        Requests password reset. Safely logs reset parameters to avoid email enumeration.
        """
        user = await self.user_repo.get_by_email(email, tenant_id)
        if not user:
            # Silently return to prevent user enumeration
            return

        raw_reset_token = secrets.token_urlsafe(32)
        reset_hash = hashlib.sha256(raw_reset_token.encode()).hexdigest()
        
        user.password_reset_hash = reset_hash
        user.password_reset_expires_at = datetime.now(timezone.utc) + timedelta(hours=1)
        await self.user_repo.db.commit()

        # In a real app, send email. Here, print to security logs for verification
        print(f"[SECURITY RESET ALERT] Password reset code for {email} on Tenant {tenant_id}: {raw_reset_token}")

    async def confirm_password_reset(
        self, tenant_id: uuid.UUID, token: str, new_password: str
    ) -> None:
        """
        Resets user password after verifying hash token.
        """
        reset_hash = hashlib.sha256(token.encode()).hexdigest()
        stmt = select(User).where(
            User.password_reset_hash == reset_hash,
            User.tenant_id == tenant_id,
            User.deleted_at.is_(None)
        )
        res = await self.user_repo.db.execute(stmt)
        user = res.scalar_one_or_none()

        if not user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid or expired reset token."
            )

        expires_at = user.password_reset_expires_at
        if expires_at and expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        if not expires_at or expires_at < datetime.now(timezone.utc):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Reset token has expired."
            )

        user.hashed_password = hash_password(new_password)
        user.password_reset_hash = None
        user.password_reset_expires_at = None
        user.failed_login_attempts = 0
        if user.status == UserStatus.LOCKED:
            user.status = UserStatus.ACTIVE
            user.locked_until = None
            
        await self.user_repo.db.commit()

    # --- USER & ROLE CRUD & MAPPINGS SERVICE ---

    async def create_user(self, tenant_id: uuid.UUID, user_in: UserCreate, created_by: Optional[uuid.UUID] = None) -> User:
        """
        Creates user and assigns associated school memberships and roles.
        """
        if await self.user_repo.get_by_email(user_in.email, tenant_id):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Email address is already registered."
            )

        hashed_pw = hash_password(user_in.password)
        
        user = User(
            email=user_in.email,
            hashed_password=hashed_pw,
            first_name=user_in.first_name,
            last_name=user_in.last_name,
            tenant_id=tenant_id,
            status=UserStatus.ACTIVE,
            created_by=created_by
        )

        # Associate Schools (transient object appends)
        if user_in.school_ids:
            for s_id in user_in.school_ids:
                school = await self.school_repo.get_by_id(s_id, tenant_id)
                if school:
                    user.schools.append(school)

        # Associate Roles (transient object appends)
        if user_in.role_ids:
            for r_id in user_in.role_ids:
                role = await self.role_repo.get_by_id(r_id, tenant_id)
                if role:
                    user.roles.append(role)

        self.user_repo.db.add(user)
        await self.user_repo.db.commit()
        return await self.user_repo.get_by_id(user.id, tenant_id)

    async def update_user(
        self, tenant_id: uuid.UUID, user_id: uuid.UUID, user_in: UserUpdate, updated_by: Optional[uuid.UUID] = None
    ) -> User:
        """
        Modifies user attributes, school scopes, and roles.
        """
        user = await self.user_repo.get_by_id(user_id, tenant_id)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found."
            )

        # Update basic parameters (does not commit)
        user = await self.user_repo.update(user, user_in, updated_by=updated_by)

        # Update School associations if provided
        if user_in.school_ids is not None:
            user.schools.clear()
            for s_id in user_in.school_ids:
                school = await self.school_repo.get_by_id(s_id, tenant_id)
                if school:
                    user.schools.append(school)

        # Update Role associations if provided
        if user_in.role_ids is not None:
            user.roles.clear()
            for r_id in user_in.role_ids:
                role = await self.role_repo.get_by_id(r_id, tenant_id)
                if role:
                    user.roles.append(role)

        await self.user_repo.db.commit()
        return await self.user_repo.get_by_id(user.id, tenant_id)

    async def create_role(self, tenant_id: uuid.UUID, role_in: RoleCreate, created_by: Optional[uuid.UUID] = None) -> Role:
        """
        Creates role and assigns associated permission codes.
        """
        if await self.role_repo.get_by_code(role_in.code, tenant_id):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Role with code '{role_in.code}' already exists."
            )

        role = Role(
            name=role_in.name,
            code=role_in.code,
            description=role_in.description,
            tenant_id=tenant_id,
            is_system=False,
            created_by=created_by
        )

        if role_in.permission_ids:
            for p_id in role_in.permission_ids:
                perm = await self.perm_repo.get_by_id(p_id)
                if perm:
                    role.permissions.append(perm)

        self.role_repo.db.add(role)
        await self.role_repo.db.commit()
        return await self.role_repo.get_by_id(role.id, tenant_id)

    async def update_role(self, tenant_id: uuid.UUID, role_id: uuid.UUID, role_in: RoleUpdate, updated_by: Optional[uuid.UUID] = None) -> Role:
        role = await self.role_repo.get_by_id(role_id, tenant_id)
        if not role:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Role not found."
            )

        if role.is_system:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="System default roles cannot be edited."
            )

        role = await self.role_repo.update(role, role_in, updated_by=updated_by)

        if role_in.permission_ids is not None:
            role.permissions.clear()
            for p_id in role_in.permission_ids:
                perm = await self.perm_repo.get_by_id(p_id)
                if perm:
                    role.permissions.append(perm)

        await self.role_repo.db.commit()
        return await self.role_repo.get_by_id(role.id, tenant_id)

    async def bootstrap_system(self, bootstrap_in: BootstrapRequest) -> BootstrapResponse:
        """
        Bootstrap system: registers default tenant (if missing), SUPER_ADMIN role with all
        system permissions, and the first administrator user.
        Raises 403 if any user already exists in the database.
        """
        # 1. Check if any user exists
        stmt_count = select(func.count(User.id))
        res_count = await self.user_repo.db.execute(stmt_count)
        users_count = res_count.scalar() or 0
        
        if users_count > 0:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="System has already been initialized."
            )

        # 2. Find or create a default system tenant
        tenant_repo = TenantRepository(self.user_repo.db)
        stmt_t = select(Tenant)
        res_t = await self.user_repo.db.execute(stmt_t)
        tenant = res_t.scalars().first()
        
        if not tenant:
            tenant = await tenant_repo.create(
                TenantCreate(
                    name="System Tenant",
                    code="system",
                    subdomain="system",
                    email="system@edupulse.com"
                )
            )

        # 3. Find or create SUPER_ADMIN role
        from sqlalchemy.orm import selectinload
        stmt_r = select(Role).where(
            Role.code == "SUPER_ADMIN",
            Role.tenant_id == tenant.id,
            Role.deleted_at.is_(None)
        ).options(selectinload(Role.permissions))
        res_r = await self.role_repo.db.execute(stmt_r)
        role = res_r.scalar_one_or_none()
        
        # 4. Fetch all existing permissions and assign to the role
        stmt_p = select(Permission).where(Permission.deleted_at.is_(None))
        res_p = await self.perm_repo.db.execute(stmt_p)
        permissions = list(res_p.scalars().all())
        
        if not role:
            role = Role(
                name="Super Admin",
                code="SUPER_ADMIN",
                description="System Super Administrator with full permissions",
                tenant_id=tenant.id,
                is_system=True
            )
            role.permissions = permissions
            self.role_repo.db.add(role)
        else:
            role.permissions = permissions

        # 5. Create first user
        hashed_pw = hash_password(bootstrap_in.password)
        user = User(
            email=bootstrap_in.email,
            hashed_password=hashed_pw,
            first_name=bootstrap_in.first_name,
            last_name=bootstrap_in.last_name,
            tenant_id=tenant.id,
            is_superuser=True,
            status=UserStatus.ACTIVE
        )
        user.roles.append(role)
        self.user_repo.db.add(user)

        # 6. Commit atomic changes
        await self.user_repo.db.commit()

        return BootstrapResponse(
            message="System initialized successfully.",
            admin_email=bootstrap_in.email
        )
