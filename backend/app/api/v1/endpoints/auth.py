import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Request, Header, Query, status, HTTPException
from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.auth import get_auth_service, get_current_user, require_permission
from app.services.auth import AuthService
from app.models.user import User
from app.models.role import Role
from app.schemas.auth import (
    LoginRequest, TokenResponse, PasswordChangeRequest, PasswordResetRequest, PasswordResetConfirm,
    UserResponse, RoleCreate, RoleUpdate, RoleResponse, PermissionResponse,
    BootstrapRequest, BootstrapResponse
)
from app.schemas.response import APIResponse
from pydantic import BaseModel, Field

router = APIRouter()

class RefreshRequest(BaseModel):
    refresh_token: str

# --- AUTHENTICATION ENDPOINTS ---

@router.post(
    "/auth/login",
    response_model=APIResponse[TokenResponse],
    status_code=status.HTTP_200_OK,
    summary="User Login",
    description="Authenticates user credentials under the active tenant, tracking lockouts."
)
async def login(
    request: Request,
    login_in: LoginRequest,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: AuthService = Depends(get_auth_service)
) -> APIResponse[TokenResponse]:
    client_ip = request.client.host if request.client else None
    user = await service.authenticate(tenant_id, login_in)
    token_data = await service.create_tokens(user, client_ip=client_ip)
    return APIResponse[TokenResponse](
        success=True,
        message="Login successful.",
        data=token_data
    )

@router.post(
    "/auth/refresh",
    response_model=APIResponse[TokenResponse],
    status_code=status.HTTP_200_OK,
    summary="Token Refresh Rotation",
    description="Rotates refresh tokens and access tokens, securing sessions against replay attacks."
)
async def refresh(
    request: Request,
    refresh_in: RefreshRequest,
    service: AuthService = Depends(get_auth_service)
) -> APIResponse[TokenResponse]:
    client_ip = request.client.host if request.client else None
    token_data = await service.refresh_token_rotation(refresh_in.refresh_token, client_ip=client_ip)
    return APIResponse[TokenResponse](
        success=True,
        message="Session refreshed successfully.",
        data=token_data
    )

@router.post(
    "/auth/logout",
    response_model=APIResponse[None],
    status_code=status.HTTP_200_OK,
    summary="User Logout",
    description="Revokes the active refresh token session."
)
async def logout(
    refresh_in: RefreshRequest,
    service: AuthService = Depends(get_auth_service)
) -> APIResponse[None]:
    await service.logout(refresh_in.refresh_token)
    return APIResponse[None](
        success=True,
        message="Logout successful.",
        data=None
    )

@router.get(
    "/auth/me",
    response_model=APIResponse[UserResponse],
    status_code=status.HTTP_200_OK,
    summary="Get Current User Details",
    description="Retrieves profile, assigned roles, permissions, and school memberships."
)
async def get_me(
    current_user: User = Depends(get_current_user)
) -> APIResponse[UserResponse]:
    return APIResponse[UserResponse](
        success=True,
        message="Current user profile retrieved.",
        data=UserResponse.model_validate(current_user)
    )

@router.post(
    "/auth/change-password",
    response_model=APIResponse[None],
    status_code=status.HTTP_200_OK,
    summary="Change Password",
    description="Updates user password after verifying current credentials."
)
async def change_password(
    change_in: PasswordChangeRequest,
    current_user: User = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service)
) -> APIResponse[None]:
    await service.change_password(current_user.tenant_id, current_user.id, change_in)
    return APIResponse[None](
        success=True,
        message="Password updated successfully.",
        data=None
    )

@router.post(
    "/auth/reset-password-request",
    response_model=APIResponse[None],
    status_code=status.HTTP_200_OK,
    summary="Request Password Reset",
    description="Generates a secure password reset token stored as a hash to avoid enumeration."
)
async def request_password_reset(
    reset_in: PasswordResetRequest,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: AuthService = Depends(get_auth_service)
) -> APIResponse[None]:
    await service.request_password_reset(tenant_id, reset_in.email)
    return APIResponse[None](
        success=True,
        message="If the email exists, a password reset link has been dispatched.",
        data=None
    )

@router.post(
    "/auth/reset-password-confirm",
    response_model=APIResponse[None],
    status_code=status.HTTP_200_OK,
    summary="Confirm Password Reset",
    description="Updates user password using a valid, non-expired password reset token."
)
async def confirm_password_reset(
    confirm_in: PasswordResetConfirm,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: AuthService = Depends(get_auth_service)
) -> APIResponse[None]:
    await service.confirm_password_reset(tenant_id, confirm_in.token, confirm_in.new_password)
    return APIResponse[None](
        success=True,
        message="Password reset successfully.",
        data=None
    )

# --- ROLE & PERMISSION ENDPOINTS ---

@router.post(
    "/roles",
    response_model=APIResponse[RoleResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create Custom Role",
    description="Registers a custom custom role under the tenant."
)
async def create_custom_role(
    role_in: RoleCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("role.create")),
    service: AuthService = Depends(get_auth_service)
) -> APIResponse[RoleResponse]:
    role = await service.create_role(tenant_id, role_in, created_by=current_user.id)
    return APIResponse[RoleResponse](
        success=True,
        message="Role created successfully.",
        data=RoleResponse.model_validate(role)
    )

@router.put(
    "/roles/{id}",
    response_model=APIResponse[RoleResponse],
    status_code=status.HTTP_200_OK,
    summary="Update Custom Role",
    description="Modifies names, descriptions, or permission maps for custom roles."
)
async def update_custom_role(
    id: uuid.UUID,
    role_in: RoleUpdate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("role.update")),
    service: AuthService = Depends(get_auth_service)
) -> APIResponse[RoleResponse]:
    role = await service.update_role(tenant_id, id, role_in, updated_by=current_user.id)
    return APIResponse[RoleResponse](
        success=True,
        message="Role updated successfully.",
        data=RoleResponse.model_validate(role)
    )

@router.get(
    "/roles",
    response_model=APIResponse[List[RoleResponse]],
    status_code=status.HTTP_200_OK,
    summary="List Roles",
    description="Retrieves a paginated list of all active roles registered under the tenant."
)
async def list_roles(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("role.read")),
    service: AuthService = Depends(get_auth_service)
) -> APIResponse[List[RoleResponse]]:
    roles = await service.role_repo.get_multi(tenant_id, skip=skip, limit=limit)
    responses = [RoleResponse.model_validate(r) for r in roles]
    return APIResponse[List[RoleResponse]](
        success=True,
        message="Roles fetched successfully.",
        data=responses
    )

@router.get(
    "/permissions",
    response_model=APIResponse[List[PermissionResponse]],
    status_code=status.HTTP_200_OK,
    summary="List Permissions",
    description="Retrieves a list of all global system permissions available."
)
async def list_permissions(
    skip: int = Query(0, ge=0),
    limit: int = Query(200, ge=1, le=200),
    current_user: User = Depends(require_permission("permission.read")),
    service: AuthService = Depends(get_auth_service)
) -> APIResponse[List[PermissionResponse]]:
    perms = await service.perm_repo.get_multi(skip=skip, limit=limit)
    responses = [PermissionResponse.model_validate(p) for p in perms]
    return APIResponse[List[PermissionResponse]](
        success=True,
        message="System permissions fetched successfully.",
        data=responses
    )

@router.post(
    "/auth/bootstrap",
    response_model=APIResponse[BootstrapResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Development System Bootstrap",
    description="Registers the default tenant, Super Admin role, and first administrator user if the system has no existing users. Can be disabled in config settings."
)
async def bootstrap(
    bootstrap_in: BootstrapRequest,
    service: AuthService = Depends(get_auth_service)
) -> APIResponse[BootstrapResponse]:
    from app.core.settings import settings
    if not settings.ENABLE_BOOTSTRAP:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="System bootstrapping is disabled in this environment."
        )
    
    bootstrap_res = await service.bootstrap_system(bootstrap_in)
    return APIResponse[BootstrapResponse](
        success=True,
        message="System initialized successfully.",
        data=bootstrap_res
    )
