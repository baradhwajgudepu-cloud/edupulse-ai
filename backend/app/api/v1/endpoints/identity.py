import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.api.dependencies.auth import require_permission
from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.identity import get_identity_service
from app.db.session import get_db
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.user import User, UserStatus
from app.models.role import Role
from app.models.school import School
from app.services.identity_provisioning import IdentityProvisioningService
from app.schemas.response import APIResponse
from app.schemas.auth import UserResponse
from app.schemas.identity import IdentityProvisionStatusResponse, IdentityResetPasswordResponse

router = APIRouter()

@router.post(
    "/provision/teacher/{teacher_id}",
    response_model=APIResponse[UserResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Provision a user account for a Teacher"
)
async def provision_teacher(
    teacher_id: uuid.UUID,
    school_id: uuid.UUID,
    current_user: User = Depends(require_permission("identity.provision")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: IdentityProvisioningService = Depends(get_identity_service)
) -> APIResponse[UserResponse]:
    """
    Manually provisions an authenticated system User account for the specified Teacher.
    """
    user = await service.provision_teacher(tenant_id, school_id, teacher_id, current_user.id)
    return APIResponse(
        success=True,
        message="Teacher user account provisioned successfully.",
        data=UserResponse.model_validate(user)
    )

@router.post(
    "/provision/guardian/{guardian_id}",
    response_model=APIResponse[UserResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Provision a user account for a Guardian"
)
async def provision_guardian(
    guardian_id: uuid.UUID,
    school_id: uuid.UUID,
    current_user: User = Depends(require_permission("identity.provision")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: IdentityProvisioningService = Depends(get_identity_service)
) -> APIResponse[UserResponse]:
    """
    Manually provisions an authenticated system User account for the specified Guardian.
    """
    user = await service.provision_guardian(tenant_id, school_id, guardian_id, current_user.id)
    return APIResponse(
        success=True,
        message="Guardian user account provisioned successfully.",
        data=UserResponse.model_validate(user)
    )

@router.post(
    "/provision/principal/{principal_id}",
    response_model=APIResponse[UserResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Provision a user account for a Principal"
)
async def provision_principal(
    principal_id: uuid.UUID,
    school_id: uuid.UUID,
    current_user: User = Depends(require_permission("identity.provision")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: IdentityProvisioningService = Depends(get_identity_service)
) -> APIResponse[UserResponse]:
    """
    Manually provisions an authenticated system User account for the Principal.
    """
    user = await service.provision_principal(tenant_id, school_id, principal_id, current_user.id)
    return APIResponse(
        success=True,
        message="Principal user account provisioned successfully.",
        data=UserResponse.model_validate(user)
    )

@router.post(
    "/provision/staff/{staff_id}",
    response_model=APIResponse[UserResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Provision a user account for a Staff member"
)
async def provision_staff(
    staff_id: uuid.UUID,
    school_id: uuid.UUID,
    current_user: User = Depends(require_permission("identity.provision")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: IdentityProvisioningService = Depends(get_identity_service)
) -> APIResponse[UserResponse]:
    """
    Manually provisions an authenticated system User account for the Staff member.
    """
    user = await service.provision_staff(tenant_id, school_id, staff_id, current_user.id)
    return APIResponse(
        success=True,
        message="Staff user account provisioned successfully.",
        data=UserResponse.model_validate(user)
    )

@router.get(
    "/users",
    response_model=APIResponse[List[UserResponse]],
    status_code=status.HTTP_200_OK,
    summary="List all users"
)
async def list_users(
    skip: int = 0,
    limit: int = 100,
    current_user: User = Depends(require_permission("identity.read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[List[UserResponse]]:
    """
    Lists users belonging to the active tenant.
    """
    stmt = select(User).where(
        User.tenant_id == tenant_id,
        User.deleted_at.is_(None)
    ).offset(skip).limit(limit).options(
        selectinload(User.roles).selectinload(Role.permissions),
        selectinload(User.schools)
    )
    res = await db.execute(stmt)
    users = list(res.scalars().all())
    return APIResponse(
        success=True,
        message="Users list retrieved successfully.",
        data=[UserResponse.model_validate(u) for u in users]
    )

@router.get(
    "/users/{id}",
    response_model=APIResponse[UserResponse],
    status_code=status.HTTP_200_OK,
    summary="Retrieve user details"
)
async def get_user_details(
    id: uuid.UUID,
    current_user: User = Depends(require_permission("identity.read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[UserResponse]:
    """
    Retrieves user profile details by ID.
    """
    stmt = select(User).where(
        User.id == id,
        User.tenant_id == tenant_id,
        User.deleted_at.is_(None)
    ).options(
        selectinload(User.roles).selectinload(Role.permissions),
        selectinload(User.schools)
    )
    res = await db.execute(stmt)
    user = res.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")
    return APIResponse(
        success=True,
        message="User details retrieved successfully.",
        data=UserResponse.model_validate(user)
    )

@router.put(
    "/users/{id}/activate",
    response_model=APIResponse[UserResponse],
    status_code=status.HTTP_200_OK,
    summary="Activate user account"
)
async def activate_user(
    id: uuid.UUID,
    current_user: User = Depends(require_permission("identity.update")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: IdentityProvisioningService = Depends(get_identity_service)
) -> APIResponse[UserResponse]:
    """
    Activates a provisioned User account.
    """
    user = await service.activate_user(tenant_id, id, current_user.id)
    return APIResponse(
        success=True,
        message="User account activated successfully.",
        data=UserResponse.model_validate(user)
    )

@router.put(
    "/users/{id}/deactivate",
    response_model=APIResponse[UserResponse],
    status_code=status.HTTP_200_OK,
    summary="Deactivate user account"
)
async def deactivate_user(
    id: uuid.UUID,
    current_user: User = Depends(require_permission("identity.update")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: IdentityProvisioningService = Depends(get_identity_service)
) -> APIResponse[UserResponse]:
    """
    Deactivates a provisioned User account.
    """
    user = await service.deactivate_user(tenant_id, id, current_user.id)
    return APIResponse(
        success=True,
        message="User account deactivated successfully.",
        data=UserResponse.model_validate(user)
    )

@router.post(
    "/users/{id}/reset-password",
    response_model=APIResponse[IdentityResetPasswordResponse],
    status_code=status.HTTP_200_OK,
    summary="Reset user password"
)
async def reset_password(
    id: uuid.UUID,
    current_user: User = Depends(require_permission("identity.reset_password")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: IdentityProvisioningService = Depends(get_identity_service),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[IdentityResetPasswordResponse]:
    """
    Resets the User's credentials to a temporary hashed password.
    """
    # Fetch email first
    stmt = select(User.email).where(User.id == id, User.tenant_id == tenant_id)
    res = await db.execute(stmt)
    email = res.scalar_one_or_none()
    if not email:
        raise HTTPException(status_code=404, detail="User not found.")

    temp_pwd = await service.reset_password(tenant_id, id, current_user.id)
    return APIResponse(
        success=True,
        message="User password reset successfully.",
        data=IdentityResetPasswordResponse(email=email, temporary_password=temp_pwd)
    )

@router.post(
    "/users/{id}/unlock",
    response_model=APIResponse[UserResponse],
    status_code=status.HTTP_200_OK,
    summary="Unlock user account"
)
async def unlock_user(
    id: uuid.UUID,
    current_user: User = Depends(require_permission("identity.update")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: IdentityProvisioningService = Depends(get_identity_service)
) -> APIResponse[UserResponse]:
    """
    Unlocks a blocked or locked user account.
    """
    user = await service.unlock_user(tenant_id, id, current_user.id)
    return APIResponse(
        success=True,
        message="User account unlocked successfully.",
        data=UserResponse.model_validate(user)
    )

@router.get(
    "/provision/status/{entity_id}",
    response_model=APIResponse[IdentityProvisionStatusResponse],
    status_code=status.HTTP_200_OK,
    summary="Get provision status"
)
async def get_provision_status(
    entity_id: uuid.UUID,
    current_user: User = Depends(require_permission("identity.read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: IdentityProvisioningService = Depends(get_identity_service)
) -> APIResponse[IdentityProvisionStatusResponse]:
    """
    Checks the status details of user provisioning on a teacher or guardian profile.
    """
    status_data = await service.get_provision_status(tenant_id, entity_id)
    return APIResponse(
        success=True,
        message="Provision status retrieved successfully.",
        data=status_data
    )


from app.api.dependencies.auth import get_current_user
from app.schemas.identity import IdentityMeResponse
from app.repositories.teacher import TeacherRepository
from app.schemas.teacher import TeacherResponse

@router.get(
    "/me",
    response_model=APIResponse[IdentityMeResponse],
    status_code=status.HTTP_200_OK,
    summary="Get current user identity details"
)
async def get_identity_me(
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[IdentityMeResponse]:
    """
    Retrieves the identity details for the authenticated user session (including Teacher details if applicable).
    """
    teacher_repo = TeacherRepository(db)
    teacher = await teacher_repo.get_by_user_id(current_user.id, tenant_id)
    
    teacher_data = None
    if teacher:
        teacher_data = TeacherResponse.model_validate(teacher)
        
    return APIResponse(
        success=True,
        message="Identity profile retrieved successfully.",
        data=IdentityMeResponse(
            user=UserResponse.model_validate(current_user),
            teacher=teacher_data
        )
    )
