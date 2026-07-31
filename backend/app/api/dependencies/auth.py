import uuid
from typing import List, Callable
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import get_db
from app.core.settings import settings
from app.core.security import decode_access_token
from app.models.user import User, UserStatus
from app.repositories.auth import (
    UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
)
from app.repositories.school import SchoolRepository
from app.services.auth import AuthService
from app.api.dependencies.school import get_school_repository

oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl=f"{settings.API_PREFIX}/auth/login",
    auto_error=False
)

# --- REPOSITORY & SERVICE DEPENDENCY INJECTIONS ---

async def get_user_repository(db: AsyncSession = Depends(get_db)) -> UserRepository:
    return UserRepository(db)

async def get_role_repository(db: AsyncSession = Depends(get_db)) -> RoleRepository:
    return RoleRepository(db)

async def get_permission_repository(db: AsyncSession = Depends(get_db)) -> PermissionRepository:
    return PermissionRepository(db)

async def get_refresh_token_repository(db: AsyncSession = Depends(get_db)) -> RefreshTokenRepository:
    return RefreshTokenRepository(db)

async def get_auth_service(
    user_repo: UserRepository = Depends(get_user_repository),
    role_repo: RoleRepository = Depends(get_role_repository),
    perm_repo: PermissionRepository = Depends(get_permission_repository),
    refresh_repo: RefreshTokenRepository = Depends(get_refresh_token_repository),
    school_repo: SchoolRepository = Depends(get_school_repository)
) -> AuthService:
    return AuthService(
        user_repo=user_repo,
        role_repo=role_repo,
        perm_repo=perm_repo,
        refresh_repo=refresh_repo,
        school_repo=school_repo
    )

# --- AUTHENTICATION DEPENDENCY ---

from app.api.dependencies.common import get_tenant_id

async def get_current_user(
    token: str = Depends(oauth2_scheme),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    user_repo: UserRepository = Depends(get_user_repository)
) -> User:
    """
    Decodes the access token and returns the current authenticated user object.
    Checks that the token's tenant claim matches the requested tenant ID.
    """
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication token is missing."
        )

    # Decodes access token claims
    payload = decode_access_token(token)
    user_id_str = payload.get("sub")
    tenant_id_str = payload.get("tenant_id")

    if not user_id_str or not tenant_id_str:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token claims."
        )

    try:
        user_id = uuid.UUID(user_id_str)
        token_tenant_id = uuid.UUID(tenant_id_str)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Malformed authentication token claims."
        )

    if token_tenant_id != tenant_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token tenant claims mismatch requested boundary."
        )

    user = await user_repo.get_by_id(user_id, tenant_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or has been deleted."
        )

    if user.status != UserStatus.ACTIVE:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Access denied. User account is currently '{user.status}'."
        )

    return user

# --- REUSABLE AUTHORIZATION FILTER CLASSES ---

class require_role:
    """
    FastAPI Role Authorization dependency.
    Usage: router_path(..., user = Depends(require_role("ADMIN", "TEACHER")))
    """
    def __init__(self, *allowed_roles: str) -> None:
        self.allowed_roles = allowed_roles

    def __call__(self, current_user: User = Depends(get_current_user)) -> User:
        # Super-users bypass all checks
        if current_user.is_superuser:
            return current_user

        user_role_codes = {r.code for r in current_user.roles}
        if not any(r in user_role_codes for r in self.allowed_roles):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. Insufficient role permissions."
            )
        return current_user


class require_permission:
    """
    FastAPI Permission Authorization dependency.
    Usage: router_path(..., user = Depends(require_permission("academic_year.create")))
    """
    def __init__(self, *allowed_permissions: str) -> None:
        self.allowed_permissions = allowed_permissions

    def __call__(self, current_user: User = Depends(get_current_user)) -> User:
        # Super-users bypass all checks
        if current_user.is_superuser:
            return current_user

        # Flatten user permissions across all roles
        user_permission_codes = {
            p.code for r in current_user.roles for p in r.permissions
        }
        
        if not any(p in user_permission_codes for p in self.allowed_permissions):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. Mismatched or insufficient system permissions."
            )
        return current_user
