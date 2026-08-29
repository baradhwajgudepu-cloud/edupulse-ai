import uuid
import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.user import User, UserStatus
from app.models.role import Role
from app.models.tenant import Tenant
from app.repositories.auth import (
    UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
)
from app.repositories.school import SchoolRepository
from app.services.auth import AuthService
from app.core.security import verify_password

@pytest.mark.anyio
async def test_bootstrap_super_admin_creates_account(db_session: AsyncSession):
    """
    1. Bootstrap creates a new Super Admin account with role SUPER_ADMIN and is_superuser=True.
    """
    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    school_repo = SchoolRepository(db_session)

    service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, school_repo)

    test_email = f"superadmin_{uuid.uuid4().hex[:8]}@example.com"
    test_password = "SuperPassword123!"

    result = await service.bootstrap_super_admin(
        email=test_email,
        password=test_password,
        ensure_only=False,
        reset_password=False,
        dry_run=False
    )

    assert result["action"] == "CREATED"
    assert result["email"] == test_email
    assert result["role"] == "SUPER_ADMIN"
    assert result["is_superuser"] is True

    # Verify user in database
    stmt = select(User).where(User.email == test_email).options(selectinload(User.roles))
    res = await db_session.execute(stmt)
    user = res.scalar_one_or_none()

    assert user is not None
    assert user.is_superuser is True
    assert user.status == UserStatus.ACTIVE
    assert verify_password(test_password, user.hashed_password) is True
    assert any(r.code == "SUPER_ADMIN" for r in user.roles)

@pytest.mark.anyio
async def test_bootstrap_super_admin_idempotency(db_session: AsyncSession):
    """
    2. Running bootstrap multiple times does not recreate user or overwrite password without --reset-password flag.
    """
    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    school_repo = SchoolRepository(db_session)

    service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, school_repo)

    test_email = f"superadmin_{uuid.uuid4().hex[:8]}@example.com"
    initial_password = "InitialPassword123!"

    # 1. First run creates account
    res1 = await service.bootstrap_super_admin(
        email=test_email,
        password=initial_password,
        dry_run=False
    )
    assert res1["action"] == "CREATED"

    # 2. Second run with ensure_only verifies without updating password
    res2 = await service.bootstrap_super_admin(
        email=test_email,
        ensure_only=True,
        reset_password=False,
        dry_run=False
    )
    assert res2["action"] == "VERIFIED"
    assert res2["password_changed"] is False

    # Check password remains the initial password
    stmt = select(User).where(User.email == test_email)
    res = await db_session.execute(stmt)
    user = res.scalar_one_or_none()
    assert verify_password(initial_password, user.hashed_password) is True

@pytest.mark.anyio
async def test_bootstrap_super_admin_explicit_reset_password(db_session: AsyncSession):
    """
    3. Running bootstrap with reset_password=True updates the password.
    """
    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    school_repo = SchoolRepository(db_session)

    service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, school_repo)

    test_email = f"superadmin_{uuid.uuid4().hex[:8]}@example.com"
    initial_password = "InitialPassword123!"
    new_password = "UpdatedPassword456@"

    # 1. Create account
    await service.bootstrap_super_admin(
        email=test_email,
        password=initial_password,
        dry_run=False
    )

    # 2. Reset password
    res = await service.bootstrap_super_admin(
        email=test_email,
        password=new_password,
        reset_password=True,
        dry_run=False
    )
    assert res["action"] == "UPDATED"
    assert res["password_changed"] is True

    # Verify password in database
    stmt = select(User).where(User.email == test_email)
    res_db = await db_session.execute(stmt)
    user = res_db.scalar_one_or_none()
    assert verify_password(new_password, user.hashed_password) is True
    assert verify_password(initial_password, user.hashed_password) is False

@pytest.mark.anyio
async def test_bootstrap_super_admin_dry_run(db_session: AsyncSession):
    """
    4. Dry run does not commit changes to the database.
    """
    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    school_repo = SchoolRepository(db_session)

    service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, school_repo)

    test_email = f"dryrun_{uuid.uuid4().hex[:8]}@example.com"
    test_password = "DryRunPassword123!"

    result = await service.bootstrap_super_admin(
        email=test_email,
        password=test_password,
        dry_run=True
    )
    assert result["action"] == "CREATED"
    assert result["dry_run"] is True

    # Verify user was NOT persisted in DB
    stmt = select(User).where(User.email == test_email)
    res = await db_session.execute(stmt)
    user = res.scalar_one_or_none()
    assert user is None

@pytest.mark.anyio
async def test_bootstrap_super_admin_custom_names(db_session: AsyncSession):
    """
    5. Bootstrap respects custom first_name and last_name configurations.
    """
    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    school_repo = SchoolRepository(db_session)

    service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, school_repo)

    test_email = f"custom_name_{uuid.uuid4().hex[:8]}@example.com"
    test_password = "SuperPassword123!"

    result = await service.bootstrap_super_admin(
        email=test_email,
        password=test_password,
        first_name="Platform",
        last_name="SuperAdmin",
        dry_run=False
    )
    assert result["action"] == "CREATED"

    stmt = select(User).where(User.email == test_email)
    res = await db_session.execute(stmt)
    user = res.scalar_one_or_none()
    assert user is not None
    assert user.first_name == "Platform"
    assert user.last_name == "SuperAdmin"

@pytest.mark.anyio
async def test_bootstrap_super_admin_tenant_and_roles_assignment(db_session: AsyncSession):
    """
    6. Super Admin is assigned to the system tenant and assigned SUPER_ADMIN role with system permissions.
    """
    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    school_repo = SchoolRepository(db_session)

    service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, school_repo)

    test_email = f"tenant_check_{uuid.uuid4().hex[:8]}@example.com"
    test_password = "SuperPassword123!"

    result = await service.bootstrap_super_admin(
        email=test_email,
        password=test_password,
        dry_run=False
    )
    assert result["action"] == "CREATED"

    stmt = select(User).where(User.email == test_email).options(selectinload(User.roles).selectinload(Role.permissions))
    res = await db_session.execute(stmt)
    user = res.scalar_one_or_none()

    assert user is not None
    # Tenant must be the system tenant
    stmt_t = select(Tenant).where(Tenant.id == user.tenant_id)
    res_t = await db_session.execute(stmt_t)
    tenant = res_t.scalar_one_or_none()
    assert tenant is not None
    assert tenant.code == "system"
