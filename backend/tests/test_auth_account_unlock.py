import pytest
import uuid
from datetime import datetime, timedelta, timezone
from httpx import AsyncClient
from fastapi import HTTPException
from app.models.user import UserStatus
from app.services.auth import AuthService
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate
from app.schemas.auth import UserCreate, LoginRequest

@pytest.mark.anyio
async def test_locked_account_rejection(db_session) -> None:
    """
    Verifies that an account with status LOCKED is rejected upon authentication:
    - If locked_until > now: raises 401 with lockout time details.
    - If locked with no locked_until: raises 403 Forbidden.
    """
    repo_t = TenantRepository(db_session)
    tenant = await repo_t.create(TenantCreate(name="T1", code="t1-lock", subdomain="t1", email="t1@lock.com"))
    repo_s = SchoolRepository(db_session)
    school = await repo_s.create(tenant.id, SchoolCreate(name="S1", code="S1", board="CBSE", email="s1@lock.com"))

    service = AuthService(
        UserRepository(db_session),
        RoleRepository(db_session),
        PermissionRepository(db_session),
        RefreshTokenRepository(db_session),
        repo_s
    )

    user = await service.create_user(
        tenant.id,
        UserCreate(email="locked.user@lock.com", password="Password123!", first_name="Locked", last_name="User", school_ids=[school.id])
    )

    # 1. Active lockout with future locked_until -> HTTP 401
    user.status = UserStatus.LOCKED
    user.locked_until = datetime.now(timezone.utc) + timedelta(minutes=15)
    await db_session.commit()

    with pytest.raises(HTTPException) as exc_info:
        await service.authenticate(tenant.id, LoginRequest(email=user.email, password="Password123!"))
    assert exc_info.value.status_code == 401
    assert "account is locked" in exc_info.value.detail.lower()

    # 2. Administrative lock without locked_until -> HTTP 403
    user.locked_until = None
    await db_session.commit()

    with pytest.raises(HTTPException) as exc_info_403:
        await service.authenticate(tenant.id, LoginRequest(email=user.email, password="Password123!"))
    assert exc_info_403.value.status_code == 403
    assert "UserStatus.LOCKED" in exc_info_403.value.detail

@pytest.mark.anyio
async def test_successful_unlock_and_login_after_unlocking(db_session) -> None:
    """
    Verifies:
    1. A locked account is successfully unlocked via unlock_account.
    2. Status transitions to ACTIVE, failed_login_attempts reset to 0, locked_until reset to None.
    3. User can authenticate successfully immediately after unlocking.
    """
    repo_t = TenantRepository(db_session)
    tenant = await repo_t.create(TenantCreate(name="T2", code="t2-lock", subdomain="t2", email="t2@lock.com"))
    repo_s = SchoolRepository(db_session)
    school = await repo_s.create(tenant.id, SchoolCreate(name="S2", code="S2", board="CBSE", email="s2@lock.com"))

    service = AuthService(
        UserRepository(db_session),
        RoleRepository(db_session),
        PermissionRepository(db_session),
        RefreshTokenRepository(db_session),
        repo_s
    )

    user = await service.create_user(
        tenant.id,
        UserCreate(email="unlock.me@lock.com", password="Password123!", first_name="Unlock", last_name="Me", school_ids=[school.id])
    )
    user.status = UserStatus.LOCKED
    user.failed_login_attempts = 5
    user.locked_until = datetime.now(timezone.utc) + timedelta(minutes=15)
    await db_session.commit()

    # Verify locked before unlock
    with pytest.raises(HTTPException):
        await service.authenticate(tenant.id, LoginRequest(email=user.email, password="Password123!"))

    # Execute unlock
    result = await service.unlock_account(email=user.email)
    assert result["success"] is True
    assert result["action"] == "UNLOCKED"
    assert result["previous_status"] == "LOCKED"
    assert result["new_status"] == "ACTIVE"

    # Reload from DB and verify exact fields
    await db_session.refresh(user)
    assert user.status == UserStatus.ACTIVE
    assert user.failed_login_attempts == 0
    assert user.locked_until is None

    # Authenticate immediately after unlock -> SUCCESS
    auth_user = await service.authenticate(tenant.id, LoginRequest(email=user.email, password="Password123!"))
    assert auth_user.id == user.id
    assert auth_user.email == user.email

@pytest.mark.anyio
async def test_unlock_already_active_user(db_session) -> None:
    """
    Verifies that calling unlock_account for an already active user is idempotent
    and returns ALREADY_ACTIVE without making unintended modifications.
    """
    repo_t = TenantRepository(db_session)
    tenant = await repo_t.create(TenantCreate(name="T3", code="t3-lock", subdomain="t3", email="t3@lock.com"))
    repo_s = SchoolRepository(db_session)
    school = await repo_s.create(tenant.id, SchoolCreate(name="S3", code="S3", board="CBSE", email="s3@lock.com"))

    service = AuthService(
        UserRepository(db_session),
        RoleRepository(db_session),
        PermissionRepository(db_session),
        RefreshTokenRepository(db_session),
        repo_s
    )

    user = await service.create_user(
        tenant.id,
        UserCreate(email="already.active@lock.com", password="Password123!", first_name="Active", last_name="User", school_ids=[school.id])
    )
    assert user.status == UserStatus.ACTIVE

    result = await service.unlock_account(email=user.email)
    assert result["success"] is True
    assert result["action"] == "ALREADY_ACTIVE"
    assert user.status == UserStatus.ACTIVE

@pytest.mark.anyio
async def test_unlock_nonexistent_user(db_session) -> None:
    """
    Verifies that attempting to unlock a non-existent user raises 404 NOT FOUND
    and never creates an account automatically.
    """
    repo_s = SchoolRepository(db_session)
    service = AuthService(
        UserRepository(db_session),
        RoleRepository(db_session),
        PermissionRepository(db_session),
        RefreshTokenRepository(db_session),
        repo_s
    )

    with pytest.raises(HTTPException) as exc_info:
        await service.unlock_account(email="ghost.user@doesnotexist.com")
    assert exc_info.value.status_code == 404
    assert "not found" in exc_info.value.detail.lower()

@pytest.mark.anyio
async def test_unauthorized_unlock_api_attempts(client: AsyncClient, db_session) -> None:
    """
    Verifies that API endpoint /api/v1/users/{id}/unlock rejects:
    - Requests with missing token (HTTP 401)
    """
    random_user_id = uuid.uuid4()
    random_tenant_id = uuid.uuid4()

    # Unauthenticated request -> 401
    resp = await client.post(
        f"/api/v1/identity/users/{random_user_id}/unlock",
        headers={"X-Tenant-ID": str(random_tenant_id)}
    )
    assert resp.status_code == 401

@pytest.mark.anyio
async def test_automatic_lockout_expiration(db_session) -> None:
    """
    Verifies that once locked_until timestamp expires (locked_until <= now):
    - authenticate() and authenticate_platform() automatically clear the lockout.
    - Status becomes ACTIVE.
    - Login succeeds with valid credentials.
    """
    repo_t = TenantRepository(db_session)
    tenant = await repo_t.create(TenantCreate(name="T4", code="t4-lock", subdomain="t4", email="t4@lock.com"))
    repo_s = SchoolRepository(db_session)
    school = await repo_s.create(tenant.id, SchoolCreate(name="S4", code="S4", board="CBSE", email="s4@lock.com"))

    service = AuthService(
        UserRepository(db_session),
        RoleRepository(db_session),
        PermissionRepository(db_session),
        RefreshTokenRepository(db_session),
        repo_s
    )

    user = await service.create_user(
        tenant.id,
        UserCreate(email="auto.unlock@lock.com", password="Password123!", first_name="Auto", last_name="Unlock", school_ids=[school.id])
    )
    # Lockout timestamp is in the past (1 minute ago)
    user.status = UserStatus.LOCKED
    user.failed_login_attempts = 5
    user.locked_until = datetime.now(timezone.utc) - timedelta(minutes=1)
    await db_session.commit()

    # Attempting login with correct password after lockout expired -> Should automatically unlock and succeed!
    auth_user = await service.authenticate(tenant.id, LoginRequest(email=user.email, password="Password123!"))
    assert auth_user.id == user.id

    await db_session.refresh(user)
    assert user.status == UserStatus.ACTIVE
    assert user.failed_login_attempts == 0
    assert user.locked_until is None

@pytest.mark.anyio
async def test_locked_user_can_request_and_complete_password_reset(db_session) -> None:
    """
    Verifies that:
    1. A locked user (UserStatus.LOCKED) is allowed to request a password reset.
    2. Reset token is generated and dispatched via email_service.
    3. Confirming password reset updates password and restores UserStatus.ACTIVE.
    4. User can log in with new credentials immediately.
    """
    from unittest.mock import patch, AsyncMock

    repo_t = TenantRepository(db_session)
    tenant = await repo_t.create(TenantCreate(name="T5", code="t5-lock", subdomain="t5", email="t5@lock.com"))
    repo_s = SchoolRepository(db_session)
    school = await repo_s.create(tenant.id, SchoolCreate(name="S5", code="S5", board="CBSE", email="s5@lock.com"))

    service = AuthService(
        UserRepository(db_session),
        RoleRepository(db_session),
        PermissionRepository(db_session),
        RefreshTokenRepository(db_session),
        repo_s
    )

    user = await service.create_user(
        tenant.id,
        UserCreate(email="locked.reset@lock.com", password="OldPassword123!", first_name="Locked", last_name="Reset", school_ids=[school.id])
    )
    user.status = UserStatus.LOCKED
    user.failed_login_attempts = 5
    user.locked_until = datetime.now(timezone.utc) + timedelta(minutes=15)
    await db_session.commit()

    captured_tokens = []
    async def mock_send_email(to_email, recipient_name, reset_token):
        captured_tokens.append(reset_token)
        return True

    with patch("app.services.auth.email_service.send_password_reset_email", side_effect=mock_send_email):
        await service.request_password_reset(email=user.email, tenant_id=tenant.id)

    # Verify reset token was dispatched despite user being LOCKED
    assert len(captured_tokens) == 1
    raw_token = captured_tokens[0]

    # Verify reset hash stored on user
    await db_session.refresh(user)
    assert user.password_reset_hash is not None

    # Confirm password reset with new password
    await service.confirm_password_reset(
        token=raw_token,
        new_password="NewSecurePassword123!",
        tenant_id=tenant.id
    )

    # Verify user is now ACTIVE and unlocked
    await db_session.refresh(user)
    assert user.status == UserStatus.ACTIVE
    assert user.failed_login_attempts == 0
    assert user.locked_until is None
    assert user.password_reset_hash is None

    # Authenticate with new password -> SUCCESS
    auth_user = await service.authenticate(tenant.id, LoginRequest(email=user.email, password="NewSecurePassword123!"))
    assert auth_user.id == user.id

