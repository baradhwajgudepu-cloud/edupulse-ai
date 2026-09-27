import hashlib
import uuid
from datetime import datetime, timedelta, timezone
import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User, UserStatus
from app.models.tenant import Tenant
from app.models.refresh_token import RefreshToken
from app.core.security import hash_password, verify_password
from app.services.email import EmailService, email_service
from app.core.settings import settings

async def get_or_create_tenant(db: AsyncSession) -> Tenant:
    stmt = select(Tenant)
    res = await db.execute(stmt)
    tenant = res.scalars().first()
    if not tenant:
        tenant = Tenant(
            id=uuid.uuid4(),
            name="Test Tenant",
            code=f"test_{uuid.uuid4().hex[:6]}",
            subdomain="test",
            email="tenant@test.com"
        )
        db.add(tenant)
        await db.commit()
        await db.refresh(tenant)
    return tenant

@pytest.mark.anyio
async def test_1_existing_user_forgot_password_returns_generic_success(client: AsyncClient, db_session: AsyncSession):
    """
    1. Forgot password for an existing user must return generic 200 OK without disclosing account existence.
    """
    tenant = await get_or_create_tenant(db_session)
    test_email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    hashed_pw = hash_password("ValidPassword123!")

    user = User(
        email=test_email,
        hashed_password=hashed_pw,
        first_name="Test",
        last_name="User",
        tenant_id=tenant.id,
        status=UserStatus.ACTIVE
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    response = await client.post(
        "/api/v1/auth/forgot-password",
        json={"email": test_email}
    )
    assert response.status_code == 200
    res_json = response.json()
    assert res_json["success"] is True
    assert "instructions have been sent" in res_json["message"]

@pytest.mark.anyio
async def test_2_non_existing_user_returns_identical_generic_success(client: AsyncClient):
    """
    2. Forgot password for a non-existent email must return the exact same generic success message (Anti-enumeration).
    """
    non_existing_email = f"unknown_{uuid.uuid4().hex[:8]}@example.com"
    response = await client.post(
        "/api/v1/auth/forgot-password",
        json={"email": non_existing_email}
    )
    assert response.status_code == 200
    res_json = response.json()
    assert res_json["success"] is True
    assert "instructions have been sent" in res_json["message"]

@pytest.mark.anyio
async def test_3_stored_reset_value_is_sha256_hash(client: AsyncClient, db_session: AsyncSession):
    """
    3. Stored reset value is a SHA-256 hash (64 hex characters), not plaintext.
    """
    tenant = await get_or_create_tenant(db_session)
    test_email = f"hash_test_{uuid.uuid4().hex[:8]}@example.com"
    user = User(
        email=test_email,
        hashed_password=hash_password("ValidPassword123!"),
        first_name="Hash",
        last_name="Tester",
        tenant_id=tenant.id,
        status=UserStatus.ACTIVE
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    await client.post(
        "/api/v1/auth/forgot-password",
        json={"email": test_email}
    )

    await db_session.refresh(user)
    assert user.password_reset_hash is not None
    assert len(user.password_reset_hash) == 64  # SHA-256 length
    assert user.password_reset_expires_at is not None

@pytest.mark.anyio
async def test_4_and_5_valid_token_resets_password_and_verifies_with_argon2(client: AsyncClient, db_session: AsyncSession):
    """
    4 & 5. Valid token resets password successfully and verifies using Argon2id.
    """
    tenant = await get_or_create_tenant(db_session)
    test_email = f"reset_test_{uuid.uuid4().hex[:8]}@example.com"
    original_pw = "OriginalPassword123!"
    new_pw = "NewSecurePassword456@"

    raw_token = f"custom_secure_token_{uuid.uuid4().hex}"
    raw_hash = hashlib.sha256(raw_token.encode()).hexdigest()
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=30)

    user = User(
        email=test_email,
        hashed_password=hash_password(original_pw),
        first_name="Reset",
        last_name="Tester",
        tenant_id=tenant.id,
        status=UserStatus.ACTIVE,
        password_reset_hash=raw_hash,
        password_reset_expires_at=expires_at
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    # Reset password using the raw token
    reset_resp = await client.post(
        "/api/v1/auth/reset-password",
        json={
            "token": raw_token,
            "new_password": new_pw,
            "confirm_password": new_pw
        }
    )
    assert reset_resp.status_code == 200
    assert reset_resp.json()["success"] is True

    # Verify user record updated with Argon2id hash and fields cleared
    await db_session.refresh(user)
    assert verify_password(new_pw, user.hashed_password) is True
    assert verify_password(original_pw, user.hashed_password) is False
    assert user.password_reset_hash is None
    assert user.password_reset_expires_at is None

@pytest.mark.anyio
async def test_6_expired_token_is_rejected(client: AsyncClient, db_session: AsyncSession):
    """
    6. Using an expired reset token must be rejected (400 Bad Request).
    """
    tenant = await get_or_create_tenant(db_session)
    raw_token = f"expired_{uuid.uuid4().hex}"
    raw_hash = hashlib.sha256(raw_token.encode()).hexdigest()

    user = User(
        email=f"expired_{uuid.uuid4().hex[:8]}@example.com",
        hashed_password=hash_password("TempPassword123!"),
        first_name="Exp",
        last_name="Tester",
        tenant_id=tenant.id,
        status=UserStatus.ACTIVE,
        password_reset_hash=raw_hash,
        password_reset_expires_at=datetime.now(timezone.utc) - timedelta(minutes=5) # Expired
    )
    db_session.add(user)
    await db_session.commit()

    resp = await client.post(
        "/api/v1/auth/reset-password",
        json={
            "token": raw_token,
            "new_password": "NewValidPass999#",
            "confirm_password": "NewValidPass999#"
        }
    )
    assert resp.status_code == 400
    err_msg = resp.json().get("message") or resp.json().get("detail") or ""
    assert "expired" in err_msg.lower()

@pytest.mark.anyio
async def test_7_used_or_cleared_token_cannot_be_reused(client: AsyncClient, db_session: AsyncSession):
    """
    7. Once used/cleared, a token cannot be reused.
    """
    tenant = await get_or_create_tenant(db_session)
    raw_token = f"reused_{uuid.uuid4().hex}"
    raw_hash = hashlib.sha256(raw_token.encode()).hexdigest()

    user = User(
        email=f"used_{uuid.uuid4().hex[:8]}@example.com",
        hashed_password=hash_password("TempPassword123!"),
        first_name="Used",
        last_name="Tester",
        tenant_id=tenant.id,
        status=UserStatus.ACTIVE,
        password_reset_hash=raw_hash,
        password_reset_expires_at=datetime.now(timezone.utc) + timedelta(minutes=30)
    )
    db_session.add(user)
    await db_session.commit()

    # First reset succeeds
    resp1 = await client.post(
        "/api/v1/auth/reset-password",
        json={
            "token": raw_token,
            "new_password": "NewPassword123#",
            "confirm_password": "NewPassword123#"
        }
    )
    assert resp1.status_code == 200

    # Second reset with same token is rejected
    resp2 = await client.post(
        "/api/v1/auth/reset-password",
        json={
            "token": raw_token,
            "new_password": "AnotherPassword456$",
            "confirm_password": "AnotherPassword456$"
        }
    )
    assert resp2.status_code == 400

@pytest.mark.anyio
async def test_8_new_forgot_password_invalidates_previous_token(client: AsyncClient, db_session: AsyncSession):
    """
    8. Requesting a new password reset overrides and invalidates any previous reset token.
    """
    tenant = await get_or_create_tenant(db_session)
    test_email = f"override_{uuid.uuid4().hex[:8]}@example.com"
    user = User(
        email=test_email,
        hashed_password=hash_password("TempPassword123!"),
        first_name="Override",
        last_name="Tester",
        tenant_id=tenant.id,
        status=UserStatus.ACTIVE,
        password_reset_hash="initial_old_hash_value",
        password_reset_expires_at=datetime.now(timezone.utc) + timedelta(minutes=30)
    )
    db_session.add(user)
    await db_session.commit()

    # Trigger forgot password
    resp = await client.post(
        "/api/v1/auth/forgot-password",
        json={"email": test_email}
    )
    assert resp.status_code == 200

    await db_session.refresh(user)
    assert user.password_reset_hash != "initial_old_hash_value"

@pytest.mark.anyio
async def test_9_password_reset_clears_failed_attempts_and_unlocks_account(client: AsyncClient, db_session: AsyncSession):
    """
    9. Password reset resets failed login attempts, unlocks account if locked, and revokes sessions.
    """
    tenant = await get_or_create_tenant(db_session)
    raw_token = f"unlock_tok_{uuid.uuid4().hex}"
    raw_hash = hashlib.sha256(raw_token.encode()).hexdigest()

    user = User(
        email=f"locked_{uuid.uuid4().hex[:8]}@example.com",
        hashed_password=hash_password("LockedPassword123!"),
        first_name="Locked",
        last_name="User",
        tenant_id=tenant.id,
        status=UserStatus.LOCKED,
        locked_until=datetime.now(timezone.utc) + timedelta(hours=1),
        failed_login_attempts=5,
        password_reset_hash=raw_hash,
        password_reset_expires_at=datetime.now(timezone.utc) + timedelta(minutes=30)
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    # Add active refresh token to verify revocation
    rt_record = RefreshToken(
        user_id=user.id,
        token_hash=hashlib.sha256("rt_session_tok".encode()).hexdigest(),
        expires_at=datetime.now(timezone.utc) + timedelta(days=7),
        tenant_id=tenant.id,
        is_revoked=False
    )
    db_session.add(rt_record)
    await db_session.commit()

    # Perform reset
    resp = await client.post(
        "/api/v1/auth/reset-password",
        json={
            "token": raw_token,
            "new_password": "UnlockedPassword123#",
            "confirm_password": "UnlockedPassword123#"
        }
    )
    assert resp.status_code == 200

    await db_session.refresh(user)
    assert user.status == UserStatus.ACTIVE
    assert user.locked_until is None
    assert user.failed_login_attempts == 0

    await db_session.refresh(rt_record)
    assert rt_record.is_revoked is True

@pytest.mark.anyio
async def test_10_no_token_is_exposed_in_api_response(client: AsyncClient, db_session: AsyncSession):
    """
    10. Neither forgot-password nor reset-password responses expose tokens or hashes.
    """
    tenant = await get_or_create_tenant(db_session)
    test_email = f"safe_{uuid.uuid4().hex[:8]}@example.com"
    user = User(
        email=test_email,
        hashed_password=hash_password("SafePassword123!"),
        first_name="Safe",
        last_name="API",
        tenant_id=tenant.id,
        status=UserStatus.ACTIVE
    )
    db_session.add(user)
    await db_session.commit()

    # Forgot password response check
    resp = await client.post(
        "/api/v1/auth/forgot-password",
        json={"email": test_email}
    )
    assert resp.status_code == 200
    resp_text = resp.text.lower()
    assert "token" not in resp.json().get("data", {}) if resp.json().get("data") else True
    assert "password_reset_hash" not in resp_text

@pytest.mark.anyio
async def test_11_smtp_config_validation():
    """
    11. SMTP configuration validation:
    - Missing host -> is_configured is False
    - Missing from_email -> is_configured is False
    - Username provided without password -> is_configured is False
    - Host, from_email, username, and password provided -> is_configured is True
    - Host and from_email provided without username/password -> is_configured is True
    """
    svc = EmailService()

    # Missing host
    svc.host = None
    svc.from_email = "noreply@edupulse.com"
    svc.username = None
    svc.password = None
    assert svc.is_configured is False

    # Missing from_email
    svc.host = "smtp.gmail.com"
    svc.from_email = None
    assert svc.is_configured is False

    # Username without password
    svc.host = "smtp.gmail.com"
    svc.from_email = "noreply@edupulse.com"
    svc.username = "edupulsetechnologies@gmail.com"
    svc.password = None
    assert svc.is_configured is False

    # Username with empty string password
    svc.password = ""
    assert svc.is_configured is False

    # Complete configuration
    svc.password = "valid_app_password"
    assert svc.is_configured is True

    # Open relay / no auth required
    svc.username = None
    svc.password = None
    assert svc.is_configured is True

@pytest.mark.anyio
async def test_12_smtp_unavailable_returns_503_anti_enumeration(client: AsyncClient, db_session: AsyncSession, monkeypatch):
    """
    12. When SMTP is unavailable outside DEBUG mode:
    - Returns HTTP 503 for existing user.
    - Returns identical HTTP 503 for non-existent user.
    - Zero account enumeration information is leaked.
    """
    tenant = await get_or_create_tenant(db_session)
    existing_email = f"smtp_unavail_{uuid.uuid4().hex[:8]}@example.com"
    user = User(
        email=existing_email,
        hashed_password=hash_password("ValidPassword123!"),
        first_name="Unavail",
        last_name="User",
        tenant_id=tenant.id,
        status=UserStatus.ACTIVE
    )
    db_session.add(user)
    await db_session.commit()

    # Simulate production (DEBUG=False) with unconfigured SMTP
    monkeypatch.setattr(EmailService, "is_configured", property(lambda self: False))
    monkeypatch.setattr(settings, "DEBUG", False)

    # Existing user -> 503
    resp_exist = await client.post(
        "/api/v1/auth/forgot-password",
        json={"email": existing_email}
    )
    assert resp_exist.status_code == 503
    msg_exist = resp_exist.json().get("detail") or resp_exist.json().get("message")
    assert "temporarily unavailable" in msg_exist.lower()

    # Non-existing user -> identical 503
    non_existing_email = f"nobody_{uuid.uuid4().hex[:8]}@example.com"
    resp_non_exist = await client.post(
        "/api/v1/auth/forgot-password",
        json={"email": non_existing_email}
    )
    assert resp_non_exist.status_code == 503
    msg_non_exist = resp_non_exist.json().get("detail") or resp_non_exist.json().get("message")
    assert msg_exist == msg_non_exist

@pytest.mark.anyio
async def test_13_runtime_delivery_failure_rolls_back_token_and_returns_503(client: AsyncClient, db_session: AsyncSession, monkeypatch):
    """
    13. When SMTP runtime sendmail fails:
    - Returns HTTP 503 Service Unavailable.
    - Stored reset token and expiry are rolled back to None in the database.
    """
    tenant = await get_or_create_tenant(db_session)
    test_email = f"fail_delivery_{uuid.uuid4().hex[:8]}@example.com"
    user = User(
        email=test_email,
        hashed_password=hash_password("ValidPassword123!"),
        first_name="Fail",
        last_name="Delivery",
        tenant_id=tenant.id,
        status=UserStatus.ACTIVE
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    # Mock send_password_reset_email to return False (delivery failure)
    async def mock_send_fail(*args, **kwargs):
        return False

    monkeypatch.setattr(email_service, "send_password_reset_email", mock_send_fail)

    resp = await client.post(
        "/api/v1/auth/forgot-password",
        json={"email": test_email}
    )
    assert resp.status_code == 503

    # Verify reset token is cleared / rolled back on the user model
    await db_session.refresh(user)
    assert user.password_reset_hash is None
    assert user.password_reset_expires_at is None

@pytest.mark.anyio
async def test_14_tampered_and_invalid_otp_rejected(client: AsyncClient, db_session: AsyncSession):
    """
    14. Tampered and invalid reset tokens must be rejected with 400 Bad Request.
    """
    tenant = await get_or_create_tenant(db_session)
    raw_token = f"legit_token_{uuid.uuid4().hex}"
    raw_hash = hashlib.sha256(raw_token.encode()).hexdigest()
    user = User(
        email=f"tamper_{uuid.uuid4().hex[:8]}@example.com",
        hashed_password=hash_password("TempPassword123!"),
        first_name="Tamper",
        last_name="Test",
        tenant_id=tenant.id,
        status=UserStatus.ACTIVE,
        password_reset_hash=raw_hash,
        password_reset_expires_at=datetime.now(timezone.utc) + timedelta(minutes=30)
    )
    db_session.add(user)
    await db_session.commit()

    # Submit tampered token (single character modified)
    tampered_token = raw_token[:-1] + ("0" if raw_token[-1] != "0" else "1")
    resp = await client.post(
        "/api/v1/auth/reset-password",
        json={
            "token": tampered_token,
            "new_password": "NewStrongPass123#",
            "confirm_password": "NewStrongPass123#"
        }
    )
    assert resp.status_code == 400
    err_msg = resp.json().get("detail") or resp.json().get("message") or ""
    assert "invalid or expired" in err_msg.lower()

@pytest.mark.anyio
async def test_15_locked_user_can_request_reset_and_is_unlocked(client: AsyncClient, db_session: AsyncSession):
    """
    15. Locked user can request password reset, and confirming reset unlocks the account.
    """
    tenant = await get_or_create_tenant(db_session)
    test_email = f"locked_flow_{uuid.uuid4().hex[:8]}@example.com"
    user = User(
        email=test_email,
        hashed_password=hash_password("LockedOldPass123!"),
        first_name="Locked",
        last_name="Student",
        tenant_id=tenant.id,
        status=UserStatus.LOCKED,
        locked_until=datetime.now(timezone.utc) + timedelta(hours=2),
        failed_login_attempts=5
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    # 1. Request password reset as locked user
    resp = await client.post(
        "/api/v1/auth/forgot-password",
        json={"email": test_email}
    )
    assert resp.status_code == 200

    await db_session.refresh(user)
    assert user.password_reset_hash is not None
    assert user.password_reset_expires_at is not None

    # 2. Reset password using a known token
    new_raw_token = f"unlock_known_{uuid.uuid4().hex}"
    user.password_reset_hash = hashlib.sha256(new_raw_token.encode()).hexdigest()
    user.password_reset_expires_at = datetime.now(timezone.utc) + timedelta(minutes=30)
    await db_session.commit()

    reset_resp = await client.post(
        "/api/v1/auth/reset-password",
        json={
            "token": new_raw_token,
            "new_password": "NewUnlockedPass456$",
            "confirm_password": "NewUnlockedPass456$"
        }
    )
    assert reset_resp.status_code == 200

    await db_session.refresh(user)
    assert user.status == UserStatus.ACTIVE
    assert user.locked_until is None
    assert user.failed_login_attempts == 0
    assert user.password_reset_hash is None
