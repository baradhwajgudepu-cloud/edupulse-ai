import uuid
import secrets
import hashlib
from datetime import datetime, timedelta, timezone
from typing import List, Optional
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload
from fastapi import HTTPException, status
from app.core.security import hash_password, verify_password, create_access_token
from app.models.user import User, UserStatus
from app.models.role import Role
from app.models.permission import Permission
from app.models.refresh_token import RefreshToken
from app.models.tenant import Tenant
from app.repositories.tenant import TenantRepository
from app.repositories.auth import (
    UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
)
from app.repositories.school import SchoolRepository
from app.schemas.tenant import TenantCreate
from app.schemas.auth import (
    UserCreate, UserUpdate, RoleCreate, RoleUpdate,
    LoginRequest, TokenResponse, PasswordChangeRequest,
    BootstrapRequest, BootstrapResponse, validate_password_strength
)
from app.services.email import email_service
from app.core.settings import settings

# In-memory sliding rate limiters for password reset requests (IP and Email)
_reset_rate_limit_ip: dict[str, list[datetime]] = {}
_reset_rate_limit_email: dict[str, list[datetime]] = {}

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
        user = await self.user_repo.get_by_email_or_login_id(login_in.email, tenant_id)
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

    async def authenticate_platform(self, login_in: LoginRequest) -> User:
        """
        Authenticates platform administrator.
        """
        user = await self.user_repo.get_by_email_platform(login_in.email)
        if not user:
            # Timing leak protection
            verify_password(login_in.password, "$argon2id$v=19$m=65536,t=3,p=4$c29tZXNhbHQ$P13Z840YqZ7jI7w1gS3W7Q")
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

        # 3. Verify user has platform admin role (SUPER_ADMIN or is_superuser)
        is_platform_admin = user.is_superuser or any(role.code == "SUPER_ADMIN" for role in user.roles)
        if not is_platform_admin:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. Insufficient platform permissions."
            )

        # 4. Successful authentication details
        user.failed_login_attempts = 0
        user.locked_until = None
        user.last_login = now
        await self.user_repo.db.commit()
        return user

    async def create_tokens(
        self, user: User, client_ip: Optional[str] = None, is_platform: bool = False
    ) -> TokenResponse:
        """
        Generates access token and refresh token pair, hashing and saving the refresh token.
        """
        # Minimal Access Token claims
        tenant_id = None if is_platform else user.tenant_id
        access_token = create_access_token(subject=user.id, tenant_id=tenant_id)
        
        # Cryptographically strong Refresh Token
        raw_refresh = secrets.token_hex(32)
        token_hash = hashlib.sha256(raw_refresh.encode()).hexdigest()
        
        expires_at = datetime.now(timezone.utc) + timedelta(days=7)
        await self.refresh_repo.create(
            user_id=user.id,
            token_hash=token_hash,
            expires_at=expires_at,
            tenant_id=tenant_id,
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
        is_platform = (db_token.tenant_id is None)
        return await self.create_tokens(user, client_ip=client_ip, is_platform=is_platform)

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
        user.must_change_password = False
        await self.user_repo.db.commit()

    def _check_rate_limit(self, identifier: str, limit: int, store: dict[str, list[datetime]], entity_type: str) -> None:
        """
        Enforces a sliding window rate limit.
        """
        now = datetime.now(timezone.utc)
        window = timedelta(minutes=settings.PASSWORD_RESET_RATE_LIMIT_WINDOW_MINUTES)
        timestamps = store.get(identifier, [])
        # Filter out expired timestamps
        valid_timestamps = [t for t in timestamps if now - t < window]
        if len(valid_timestamps) >= limit:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Too many password reset requests for this {entity_type}. Please wait before trying again."
            )
        valid_timestamps.append(now)
        store[identifier] = valid_timestamps

    async def request_password_reset(
        self,
        email: str,
        tenant_id: Optional[uuid.UUID] = None,
        client_ip: Optional[str] = None
    ) -> None:
        """
        Requests password reset. Safely dispatches reset instructions to avoid email enumeration.
        Applies rate limiting per IP and per Email.
        """
        norm_email = email.strip().lower()

        # 1. Rate limiting
        if client_ip:
            self._check_rate_limit(
                client_ip,
                settings.PASSWORD_RESET_RATE_LIMIT_PER_IP,
                _reset_rate_limit_ip,
                "network address"
            )
        self._check_rate_limit(
            norm_email,
            settings.PASSWORD_RESET_RATE_LIMIT_PER_EMAIL,
            _reset_rate_limit_email,
            "email address"
        )

        # 2. Look up user by email (within tenant if provided, or globally for platform/admin users)
        if tenant_id:
            user = await self.user_repo.get_by_email(norm_email, tenant_id)
        else:
            user = await self.user_repo.get_by_email_platform(norm_email)

        if not user or user.status != UserStatus.ACTIVE:
            # Silently return to prevent user enumeration
            return

        # 3. Generate cryptographically strong random token
        raw_reset_token = secrets.token_urlsafe(32)
        reset_hash = hashlib.sha256(raw_reset_token.encode()).hexdigest()
        expires_at = datetime.now(timezone.utc) + timedelta(
            minutes=settings.PASSWORD_RESET_TOKEN_EXPIRE_MINUTES
        )

        # 4. Store reset hash and expiration directly on the User model
        user.password_reset_hash = reset_hash
        user.password_reset_expires_at = expires_at
        await self.user_repo.db.commit()

        # 5. Dispatch branded email asynchronously
        recipient_name = f"{user.first_name} {user.last_name}".strip()
        await email_service.send_password_reset_email(
            to_email=user.email,
            recipient_name=recipient_name or "User",
            reset_token=raw_reset_token
        )

    async def confirm_password_reset(
        self,
        token: str,
        new_password: str,
        tenant_id: Optional[uuid.UUID] = None
    ) -> None:
        """
        Resets user password after verifying hash token.
        Enforces single-use token invalidation, password complexity, and session revocation.
        """
        validate_password_strength(new_password)
        reset_hash = hashlib.sha256(token.encode()).hexdigest()
        now = datetime.now(timezone.utc)

        # 1. Lookup user by active password reset hash
        user = await self.user_repo.get_by_password_reset_hash(reset_hash)
        if not user or (tenant_id and user.tenant_id != tenant_id):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid or expired password reset token."
            )

        expires_at = user.password_reset_expires_at
        if expires_at and expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        if not expires_at or expires_at < now:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This password reset token has expired."
            )

        # 2. Update user password using Argon2id
        user.hashed_password = hash_password(new_password)
        user.password_reset_hash = None
        user.password_reset_expires_at = None
        user.must_change_password = False
        user.failed_login_attempts = 0

        if user.status == UserStatus.LOCKED:
            user.status = UserStatus.ACTIVE
            user.locked_until = None

        # 3. Revoke all active sessions and refresh tokens
        await self.refresh_repo.revoke_all_for_user(user.id)

        # 4. Commit atomic transaction
        await self.user_repo.db.commit()


    async def bootstrap_super_admin(
        self,
        email: Optional[str] = None,
        password: Optional[str] = None,
        first_name: Optional[str] = None,
        last_name: Optional[str] = None,
        ensure_only: bool = False,
        reset_password: bool = False,
        dry_run: bool = False
    ) -> dict:
        """
        Idempotent Super Admin bootstrap/update flow.
        Reads credentials from environment variables if not provided.
        Never prints plaintext credentials.
        """
        target_email = (email or settings.SUPER_ADMIN_EMAIL or "").strip().lower()
        if not target_email:
            raise ValueError(
                "Super Admin email is required. Please set SUPER_ADMIN_EMAIL environment variable."
            )

        target_password = password or settings.SUPER_ADMIN_INITIAL_PASSWORD
        target_first_name = first_name or settings.SUPER_ADMIN_FIRST_NAME or "Super"
        target_last_name = last_name or settings.SUPER_ADMIN_LAST_NAME or "Admin"

        # 1. Find or create default System Tenant
        tenant_repo = TenantRepository(self.user_repo.db)
        stmt_t = select(Tenant).where(Tenant.code == "system", Tenant.deleted_at.is_(None))
        res_t = await self.user_repo.db.execute(stmt_t)
        system_tenant = res_t.scalars().first()

        if not system_tenant:
            if not dry_run:
                system_tenant = await tenant_repo.create(
                    TenantCreate(
                        name="System Tenant",
                        code="system",
                        subdomain="system",
                        email=target_email
                    )
                )
            else:
                system_tenant = Tenant(
                    id=uuid.uuid4(),
                    name="System Tenant",
                    code="system",
                    subdomain="system",
                    email=target_email
                )

        # 2. Find or create SUPER_ADMIN role with all permissions
        stmt_p = select(Permission).where(Permission.deleted_at.is_(None))
        res_p = await self.perm_repo.db.execute(stmt_p)
        permissions = list(res_p.scalars().all())

        stmt_r = select(Role).where(
            Role.code == "SUPER_ADMIN",
            Role.tenant_id == system_tenant.id,
            Role.deleted_at.is_(None)
        ).options(selectinload(Role.permissions))
        res_r = await self.role_repo.db.execute(stmt_r)
        role = res_r.scalar_one_or_none()

        if not role:
            role = Role(
                name="Super Admin",
                code="SUPER_ADMIN",
                description="System Super Administrator with full platform permissions",
                tenant_id=system_tenant.id,
                is_system=True
            )
            role.permissions = permissions
            if not dry_run:
                self.role_repo.db.add(role)
        else:
            role.permissions = permissions

        # 3. Look up user by normalized lowercase email
        stmt_u = select(User).where(
            func.lower(User.email) == target_email,
            User.deleted_at.is_(None)
        ).options(selectinload(User.roles))
        res_u = await self.user_repo.db.execute(stmt_u)
        user = res_u.scalar_one_or_none()

        if not user:
            if not target_password:
                raise ValueError(
                    "Super Admin initial password is required to create an account. "
                    "Please set SUPER_ADMIN_INITIAL_PASSWORD environment variable."
                )
            validate_password_strength(target_password)

            if not dry_run:
                hashed_pw = hash_password(target_password)
                user = User(
                    email=target_email,
                    hashed_password=hashed_pw,
                    first_name=target_first_name,
                    last_name=target_last_name,
                    tenant_id=system_tenant.id,
                    is_superuser=True,
                    status=UserStatus.ACTIVE
                )
                user.roles.append(role)
                self.user_repo.db.add(user)
                await self.user_repo.db.commit()

            return {
                "action": "CREATED",
                "email": target_email,
                "role": "SUPER_ADMIN",
                "is_superuser": True,
                "password_changed": True,
                "dry_run": dry_run
            }


        # User already exists
        user.is_superuser = True
        user.status = UserStatus.ACTIVE
        if role not in user.roles:
            user.roles.append(role)

        password_updated = False
        if reset_password:
            if not target_password:
                raise ValueError(
                    "Password is required for reset. Please set SUPER_ADMIN_INITIAL_PASSWORD environment variable."
                )
            validate_password_strength(target_password)
            user.hashed_password = hash_password(target_password)
            user.failed_login_attempts = 0
            user.locked_until = None
            password_updated = True

        if not dry_run:
            await self.user_repo.db.commit()

        return {
            "action": "UPDATED" if password_updated else "VERIFIED",
            "email": target_email,
            "role": "SUPER_ADMIN",
            "is_superuser": True,
            "password_changed": password_updated,
            "dry_run": dry_run
        }


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
