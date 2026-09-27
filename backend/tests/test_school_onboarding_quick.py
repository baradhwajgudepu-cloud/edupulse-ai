import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.models.tenant import Tenant, TenantStatus
from app.models.school import School, SchoolBoard, SchoolType, SchoolStatus
from app.models.user import User, UserStatus
from app.models.role import Role
from app.core.security import verify_password, hash_password, create_access_token
from app.services.rbac_provisioning import ensure_tenant_rbac

FIXED_HASH = hash_password("Password123!")


async def get_or_create_platform_admin(db_session) -> tuple[User, str]:
    """
    Provisions a Platform Super Administrator with no active school context
    and generates an authoritative platform-scoped access token (tenant_id=None).
    """
    u = uuid.uuid4().hex[:6]
    platform_tenant = Tenant(
        name=f"Platform Root Tenant {u}",
        code=f"TNT_PLATFORM_{u.upper()}",
        subdomain=f"platform{u}",
        email=f"platform.{u}@edupulse.local",
        status=TenantStatus.ACTIVE
    )
    db_session.add(platform_tenant)
    await db_session.flush()

    platform_admin = User(
        email=f"platform.admin.{u}@edupulse.local",
        hashed_password=FIXED_HASH,
        first_name="Platform",
        last_name="SuperAdmin",
        is_superuser=True,
        tenant_id=platform_tenant.id,
        status=UserStatus.ACTIVE
    )
    db_session.add(platform_admin)
    await db_session.flush()

    # Platform token has tenant_id=None to represent Platform Administration Scope
    token = create_access_token(subject=str(platform_admin.id), tenant_id=None)
    return platform_admin, token


async def create_tenant_user_with_role(db_session, role_code: str) -> tuple[User, Tenant, str]:
    """
    Provisions a standard non-platform tenant user with a specific role (e.g. PRINCIPAL, TEACHER).
    """
    u = uuid.uuid4().hex[:6]
    tenant = Tenant(
        name=f"Standard Tenant {u}",
        code=f"TNT_STD_{u.upper()}",
        subdomain=f"std{u}",
        email=f"tenant.{u}@edupulse.local",
        status=TenantStatus.ACTIVE
    )
    db_session.add(tenant)
    await db_session.flush()

    await ensure_tenant_rbac(db_session, tenant.id)

    stmt_role = select(Role).where(Role.tenant_id == tenant.id, Role.code == role_code)
    res = await db_session.execute(stmt_role)
    role = res.scalar_one_or_none()

    user = User(
        email=f"{role_code.lower()}.{u}@edupulse.local",
        hashed_password=FIXED_HASH,
        first_name=role_code.capitalize(),
        last_name="User",
        is_superuser=False,
        tenant_id=tenant.id,
        status=UserStatus.ACTIVE
    )
    if role:
        user.roles.append(role)
    db_session.add(user)
    await db_session.flush()

    token = create_access_token(subject=str(user.id), tenant_id=str(tenant.id))
    return user, tenant, token


@pytest.mark.anyio
async def test_platform_admin_create_school_without_active_school_context(client: AsyncClient, db_session):
    """
    Test 1: Platform Admin with NO active school context creates a school.
    Must succeed with HTTP 201 CREATED (NOT HTTP 400 'Active school context required.').
    """
    admin, token = await get_or_create_platform_admin(db_session)

    u = uuid.uuid4().hex[:6]
    school_name = f"Telangana School {u}"
    payload = {
        "school_name": school_name,
        "principal_name": "Baradhwaj",
        "principal_email": f"baradhwaj.{u}@tms.edu",
        "principal_password": "SecurePassword@123"
    }

    # Platform Admin sends request with NO X-School-ID, NO X-Active-School-ID, and NO X-Tenant-ID
    headers = {
        "Authorization": f"Bearer {token}"
    }

    resp = await client.post("/api/v1/schools/onboard-quick", json=payload, headers=headers)
    assert resp.status_code == 201, resp.text
    data = resp.json()["data"]

    assert data["school_name"] == school_name
    assert data["principal_email"] == f"baradhwaj.{u}@tms.edu"
    assert data["status"] == "ACTIVE"
    assert data["school_code"] is not None
    assert data["school_code"].startswith("TS") or data["school_code"].startswith("SCH")
    assert data["access_token"] is not None
    assert data["token_type"] == "bearer"


@pytest.mark.anyio
async def test_platform_admin_creates_two_schools_unique_codes(client: AsyncClient, db_session):
    """
    Test 2: Platform Admin creates two schools sequentially.
    Both must succeed with unique, collision-safe school codes (e.g. TMS001, TMS002).
    """
    admin, token = await get_or_create_platform_admin(db_session)
    headers = {"Authorization": f"Bearer {token}"}

    u1 = uuid.uuid4().hex[:6]
    resp1 = await client.post("/api/v1/schools/onboard-quick", json={
        "school_name": "Telangana Model School",
        "principal_name": "Principal One",
        "principal_email": f"p1.{u1}@tms.edu",
        "principal_password": "Password123@abc"
    }, headers=headers)
    assert resp1.status_code == 201, resp1.text
    code1 = resp1.json()["data"]["school_code"]

    u2 = uuid.uuid4().hex[:6]
    resp2 = await client.post("/api/v1/schools/onboard-quick", json={
        "school_name": "Telangana Model School",
        "principal_name": "Principal Two",
        "principal_email": f"p2.{u2}@tms.edu",
        "principal_password": "Password123@abc"
    }, headers=headers)
    assert resp2.status_code == 201, resp2.text
    code2 = resp2.json()["data"]["school_code"]

    # Verify both were created and received unique codes
    assert code1 != code2
    assert code1.startswith("TMS")
    assert code2.startswith("TMS")


@pytest.mark.anyio
async def test_platform_admin_create_school_no_board_or_type(client: AsyncClient, db_session):
    """
    Test 3: Platform Admin creates school with no board or school_type.
    Board and School Type must remain optional ('Not Configured') and not defaulted to CBSE/HIGH_SCHOOL.
    """
    admin, token = await get_or_create_platform_admin(db_session)
    headers = {"Authorization": f"Bearer {token}"}

    u = uuid.uuid4().hex[:6]
    resp = await client.post("/api/v1/schools/onboard-quick", json={
        "school_name": f"Universal Academy {u}",
        "principal_name": "Dr. Sarah Smith",
        "principal_email": f"sarah.{u}@universal.edu",
        "principal_password": "Password123@abc"
    }, headers=headers)
    assert resp.status_code == 201, resp.text
    data = resp.json()["data"]

    assert data["board"] == "Not Configured"
    assert data["school_type"] == "Not Configured"

    # Verify directly in DB settings
    school_id = uuid.UUID(data["school_id"])
    stmt_s = select(School).where(School.id == school_id)
    s_res = await db_session.execute(stmt_s)
    school = s_res.scalar_one_or_none()
    assert school is not None
    assert school.settings.get("board_configured") is False
    assert school.settings.get("school_type_configured") is False


@pytest.mark.anyio
async def test_principal_attempt_to_create_school_forbidden(client: AsyncClient, db_session):
    """
    Test 4: Non-platform user (PRINCIPAL) attempts to create a school.
    Must be rejected with HTTP 403 Forbidden.
    """
    user, tenant, token = await create_tenant_user_with_role(db_session, "PRINCIPAL")

    headers = {
        "Authorization": f"Bearer {token}",
        "X-Tenant-ID": str(tenant.id)
    }
    resp = await client.post("/api/v1/schools/onboard-quick", json={
        "school_name": "Unauthorized School",
        "principal_name": "Rogue Principal",
        "principal_email": f"rogue.{uuid.uuid4().hex[:6]}@edupulse.local",
        "principal_password": "Password123@abc"
    }, headers=headers)

    assert resp.status_code == 403, f"Expected 403 Forbidden, got {resp.status_code}"
    err_msg = resp.json().get("message") or resp.json().get("detail") or ""
    assert "Platform administrator privileges required" in err_msg


@pytest.mark.anyio
async def test_teacher_attempt_to_create_school_forbidden(client: AsyncClient, db_session):
    """
    Test 5: Non-platform user (TEACHER) attempts to create a school.
    Must be rejected with HTTP 403 Forbidden.
    """
    user, tenant, token = await create_tenant_user_with_role(db_session, "TEACHER")

    headers = {
        "Authorization": f"Bearer {token}",
        "X-Tenant-ID": str(tenant.id)
    }
    resp = await client.post("/api/v1/schools/onboard-quick", json={
        "school_name": "Unauthorized Teacher School",
        "principal_name": "Rogue Teacher",
        "principal_email": f"teacher.{uuid.uuid4().hex[:6]}@edupulse.local",
        "principal_password": "Password123@abc"
    }, headers=headers)

    assert resp.status_code == 403, f"Expected 403 Forbidden, got {resp.status_code}"
    err_msg = resp.json().get("message") or resp.json().get("detail") or ""
    assert "Platform administrator privileges required" in err_msg


@pytest.mark.anyio
async def test_quick_onboarding_duplicate_email_conflict(client: AsyncClient, db_session):
    """
    Test 6: Duplicate Email Conflict.
    Attempting to onboard with an existing user's email must return HTTP 409.
    """
    admin, token = await get_or_create_platform_admin(db_session)
    headers = {"Authorization": f"Bearer {token}"}

    u = uuid.uuid4().hex[:6]
    dup_email = f"unique.{u}@myschool.edu"
    payload1 = {
        "school_name": f"First School {u}",
        "principal_name": f"First Principal {u}",
        "principal_email": dup_email,
        "principal_password": "Password123@abc"
    }
    resp1 = await client.post("/api/v1/schools/onboard-quick", json=payload1, headers=headers)
    assert resp1.status_code == 201

    payload2 = {
        "school_name": f"Second School {u}",
        "principal_name": f"Second Principal {u}",
        "principal_email": dup_email,
        "principal_password": "Password123@abc"
    }
    resp2 = await client.post("/api/v1/schools/onboard-quick", json=payload2, headers=headers)
    assert resp2.status_code == 409


@pytest.mark.anyio
async def test_successful_onboarding_db_verification(client: AsyncClient, db_session):
    """
    Test 7: Successful onboarding full DB verification.
    Verifies Tenant, School, School Code, Principal, Role, and School Mapping in DB.
    """
    admin, token = await get_or_create_platform_admin(db_session)
    headers = {"Authorization": f"Bearer {token}"}

    u = uuid.uuid4().hex[:6]
    school_name = f"Telangana Heritage School {u}"
    principal_name = "Baradhwaj Gudepu"
    principal_email = f"baradhwaj.{u}@heritage.edu"
    principal_password = "SecurePassword@123"

    resp = await client.post("/api/v1/schools/onboard-quick", json={
        "school_name": school_name,
        "principal_name": principal_name,
        "principal_email": principal_email,
        "principal_password": principal_password
    }, headers=headers)
    assert resp.status_code == 201, resp.text
    res_data = resp.json()["data"]

    tenant_id = uuid.UUID(res_data["tenant_id"])
    school_id = uuid.UUID(res_data["school_id"])
    principal_id = uuid.UUID(res_data["principal_id"])
    school_code = res_data["school_code"]

    # 1. Verify Tenant in DB
    stmt_t = select(Tenant).where(Tenant.id == tenant_id)
    t_res = await db_session.execute(stmt_t)
    tenant = t_res.scalar_one_or_none()
    assert tenant is not None
    assert tenant.name == school_name
    assert tenant.is_active is True

    # 2. Verify School in DB
    stmt_s = select(School).where(School.id == school_id)
    s_res = await db_session.execute(stmt_s)
    school = s_res.scalar_one_or_none()
    assert school is not None
    assert school.name == school_name
    assert school.code == school_code
    assert school.tenant_id == tenant_id
    assert school.is_active is True
    assert school.principal_name == principal_name

    # 3. Verify Principal User in DB
    stmt_u = select(User).where(User.id == principal_id).options(
        selectinload(User.roles),
        selectinload(User.schools)
    )
    u_res = await db_session.execute(stmt_u)
    user = u_res.scalar_one_or_none()
    assert user is not None
    assert user.email == principal_email.lower()
    assert user.status == UserStatus.ACTIVE
    assert user.tenant_id == tenant_id
    assert verify_password(principal_password, user.hashed_password)

    # 4. Verify PRINCIPAL role and School Mapping
    role_codes = [r.code for r in user.roles]
    assert "PRINCIPAL" in role_codes

    school_ids = [s.id for s in user.schools]
    assert school_id in school_ids


@pytest.mark.anyio
async def test_principal_immediate_login_no_claims_mismatch(client: AsyncClient, db_session):
    """
    Test 8: Principal Immediate Login & Zero Boundary Mismatch.
    Verifies that the issued access token allows immediate API access
    with matching X-Tenant-ID header and does not encounter HTTP 401 boundary errors.
    Also verifies authentication via /api/v1/auth/login.
    """
    admin, token = await get_or_create_platform_admin(db_session)
    headers = {"Authorization": f"Bearer {token}"}

    u = uuid.uuid4().hex[:6]
    principal_email = f"principal.{u}@boundary.edu"
    principal_password = "BoundaryPass@123"

    resp = await client.post("/api/v1/schools/onboard-quick", json={
        "school_name": f"Boundary School {u}",
        "principal_name": f"Principal {u}",
        "principal_email": principal_email,
        "principal_password": principal_password,
    }, headers=headers)
    assert resp.status_code == 201, resp.text
    data = resp.json()["data"]

    token = data["access_token"]
    tenant_id = data["tenant_id"]
    school_id = data["school_id"]

    # 1. Call school-scoped API with matching X-Tenant-ID and issued token
    principal_headers = {
        "Authorization": f"Bearer {token}",
        "X-Tenant-ID": tenant_id
    }
    progress_resp = await client.get(f"/api/v1/schools/{school_id}/setup-progress", headers=principal_headers)
    assert progress_resp.status_code == 200, progress_resp.text
    p_data = progress_resp.json()["data"]
    assert p_data["completed_count"] == 2
    assert p_data["total_steps"] == 8

    # 2. Verify direct login via /api/v1/auth/login
    login_resp = await client.post("/api/v1/auth/login", json={
        "email": principal_email,
        "password": principal_password
    })
    assert login_resp.status_code == 200, login_resp.text
    login_data = login_resp.json()["data"]
    assert login_data["access_token"] is not None


@pytest.mark.anyio
async def test_quick_onboarding_custom_board_and_type(client: AsyncClient, db_session):
    """
    Test 9: Flexible School Types & Boards.
    Verifies custom school types and board names (e.g. Junior College, State Board)
    are saved safely in settings without breaking models.
    """
    admin, token = await get_or_create_platform_admin(db_session)
    headers = {"Authorization": f"Bearer {token}"}

    u = uuid.uuid4().hex[:6]
    resp = await client.post("/api/v1/schools/onboard-quick", json={
        "school_name": f"Narayana Junior College {u}",
        "principal_name": f"Sri Krishna {u}",
        "principal_email": f"krishna.{u}@narayana.edu",
        "principal_password": "JuniorCollege@123",
        "board": "Telangana State Board (TSBIE)",
        "school_type": "Junior College",
        "phone": "+919849012345"
    }, headers=headers)
    assert resp.status_code == 201, resp.text
    res_data = resp.json()["data"]

    assert res_data["board"] == "Telangana State Board (TSBIE)"
    assert res_data["school_type"] == "Junior College"

    school_id = uuid.UUID(res_data["school_id"])
    stmt_s = select(School).where(School.id == school_id)
    s_res = await db_session.execute(stmt_s)
    school = s_res.scalar_one_or_none()

    assert school.board == SchoolBoard.OTHER
    assert school.school_type == SchoolType.OTHER
    assert school.settings["custom_board"] == "Telangana State Board (TSBIE)"
    assert school.settings["custom_school_type"] == "Junior College"


@pytest.mark.anyio
async def test_multi_tenant_isolation_between_schools(client: AsyncClient, db_session):
    """
    Test 10: Multi-tenant Isolation.
    Principal from School A must NOT be able to access School B's setup progress.
    """
    admin, token = await get_or_create_platform_admin(db_session)
    headers = {"Authorization": f"Bearer {token}"}

    u1 = uuid.uuid4().hex[:6]
    u2 = uuid.uuid4().hex[:6]

    # School A
    resp_a = await client.post("/api/v1/schools/onboard-quick", json={
        "school_name": f"School Alpha {u1}",
        "principal_name": f"Principal Alpha {u1}",
        "principal_email": f"alpha.{u1}@alpha.edu",
        "principal_password": "PasswordAlpha@123",
    }, headers=headers)
    assert resp_a.status_code == 201
    data_a = resp_a.json()["data"]

    # School B
    resp_b = await client.post("/api/v1/schools/onboard-quick", json={
        "school_name": f"School Beta {u2}",
        "principal_name": f"Principal Beta {u2}",
        "principal_email": f"beta.{u2}@beta.edu",
        "principal_password": "PasswordBeta@123",
    }, headers=headers)
    assert resp_b.status_code == 201
    data_b = resp_b.json()["data"]

    token_a = data_a["access_token"]
    tenant_a = data_a["tenant_id"]
    school_b_id = data_b["school_id"]

    # Principal A tries to access School B with Principal A's token and tenant A
    cross_headers = {
        "Authorization": f"Bearer {token_a}",
        "X-Tenant-ID": tenant_a
    }
    cross_access_resp = await client.get(f"/api/v1/schools/{school_b_id}/setup-progress", headers=cross_headers)
    assert cross_access_resp.status_code in (403, 404)
