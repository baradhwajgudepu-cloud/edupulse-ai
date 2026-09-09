import pytest
import uuid
from datetime import datetime, timezone
from httpx import AsyncClient
from app.models.user import User, UserStatus
from app.models.role import Role
from app.services.auth import AuthService
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate
from app.schemas.auth import UserCreate, RoleCreate, LoginRequest
from fastapi import HTTPException
from app.core.security import decode_access_token
from app.api.dependencies.auth import LEGACY_PLAY_STORE_TENANT_ID
from app.api.dependencies.common import get_tenant_id

@pytest.mark.anyio
async def test_multi_tenant_login_scenarios(client: AsyncClient, db_session) -> None:
    """
    Tests 1 to 10 covering multi-tenant login architecture:
    Test 1: Existing user logs in with correct X-Tenant-ID -> 200 OK.
    Test 2: Existing user logs in with NO X-Tenant-ID -> 200 OK (unambiguous identity resolution).
    Test 3: Newly onboarded user logs in while client sends OLD/stale tenant ID -> 200 OK.
    Test 4: Onboarded principal login with stale tenant header -> succeeds, JWT tenant matches user's tenant.
    Test 5: Wrong password -> 401 generic invalid credentials.
    Test 6: Inactive user -> 403 Forbidden.
    Test 7: Deleted user -> 401 generic invalid credentials.
    Test 8: Cross-tenant authenticated request -> 403 Forbidden.
    Test 9: Forged X-Tenant-ID after authentication -> 401 boundary mismatch (cannot alter tenant context).
    Test 10: Duplicate email across tenants -> 400 Ambiguity handling without leaking info.
    """
    repo_t = TenantRepository(db_session)
    repo_s = SchoolRepository(db_session)
    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, repo_s)

    # 1. Setup Tenant A (e.g. Existing Demo Tenant)
    tenant_a = await repo_t.create(TenantCreate(
        name="Demo Tenant A", code=f"t-a-{uuid.uuid4().hex[:6]}",
        subdomain=f"sub-a-{uuid.uuid4().hex[:6]}", email=f"a-{uuid.uuid4().hex[:6]}@demo.com"
    ))
    school_a = await repo_s.create(tenant_a.id, SchoolCreate(
        name="Demo School A", code=f"SCHA_{uuid.uuid4().hex[:4].upper()}", board="CBSE", email=f"scha_{uuid.uuid4().hex[:6]}@demo.com"
    ))
    role_teacher_a = await service.create_role(tenant_a.id, RoleCreate(
        name="Teacher A", code=f"TEACHER_A_{uuid.uuid4().hex[:4].upper()}", description="Teacher"
    ))
    user_a = await service.create_user(tenant_a.id, UserCreate(
        email=f"teacher.a.{uuid.uuid4().hex[:6]}@demo.com",
        password="Password123!",
        first_name="Teacher",
        last_name="A",
        role_ids=[role_teacher_a.id],
        school_ids=[school_a.id]
    ))

    # 2. Setup Tenant B (e.g. Newly Onboarded School Tenant)
    tenant_b = await repo_t.create(TenantCreate(
        name="Telangana Tenant B", code=f"t-b-{uuid.uuid4().hex[:6]}",
        subdomain=f"sub-b-{uuid.uuid4().hex[:6]}", email=f"b-{uuid.uuid4().hex[:6]}@telangana.edu"
    ))
    school_b = await repo_s.create(tenant_b.id, SchoolCreate(
        name="Telangana Model School", code=f"SCHB_{uuid.uuid4().hex[:4].upper()}", board="STATE", email=f"schb_{uuid.uuid4().hex[:6]}@telangana.edu"
    ))
    role_principal_b = await service.create_role(tenant_b.id, RoleCreate(
        name="Principal B", code=f"PRINCIPAL_B_{uuid.uuid4().hex[:4].upper()}", description="Principal"
    ))
    principal_b = await service.create_user(tenant_b.id, UserCreate(
        email=f"principal.ts001.{uuid.uuid4().hex[:6]}@telanganaschool.edu",
        password="EduPulse@123",
        first_name="Principal",
        last_name="TS001",
        role_ids=[role_principal_b.id],
        school_ids=[school_b.id]
    ))

    # -------------------------------------------------------------------------
    # TEST 1: Existing user logs in with correct X-Tenant-ID -> 200 OK
    # -------------------------------------------------------------------------
    resp1 = await client.post(
        "/api/v1/auth/login",
        json={"email": user_a.email, "password": "Password123!"},
        headers={"X-Tenant-ID": str(tenant_a.id)}
    )
    assert resp1.status_code == 200, f"Test 1 failed: {resp1.text}"
    token_1 = resp1.json()["data"]["access_token"]
    payload_1 = decode_access_token(token_1)
    assert payload_1["tenant_id"] == str(tenant_a.id)

    # -------------------------------------------------------------------------
    # TEST 2: Existing user logs in with NO X-Tenant-ID -> 200 OK
    # -------------------------------------------------------------------------
    resp2 = await client.post(
        "/api/v1/auth/login",
        json={"email": user_a.email, "password": "Password123!"}
    )
    assert resp2.status_code == 200, f"Test 2 failed: {resp2.text}"
    token_2 = resp2.json()["data"]["access_token"]
    payload_2 = decode_access_token(token_2)
    assert payload_2["tenant_id"] == str(tenant_a.id)

    # -------------------------------------------------------------------------
    # TEST 3: Newly onboarded user logs in while client sends OLD tenant ID -> 200 OK
    # -------------------------------------------------------------------------
    resp3 = await client.post(
        "/api/v1/auth/login",
        json={"email": principal_b.email, "password": "EduPulse@123"},
        headers={"X-Tenant-ID": str(tenant_a.id)}  # Client sends fallback tenant A
    )
    assert resp3.status_code == 200, f"Test 3 failed: {resp3.text}"
    token_3 = resp3.json()["data"]["access_token"]
    payload_3 = decode_access_token(token_3)
    assert payload_3["tenant_id"] == str(tenant_b.id)

    # -------------------------------------------------------------------------
    # TEST 4: Verification of authentic JWT tenant_id for newly onboarded principal
    # -------------------------------------------------------------------------
    assert payload_3["sub"] == str(principal_b.id)
    assert payload_3["tenant_id"] == str(principal_b.tenant_id)

    # -------------------------------------------------------------------------
    # TEST 5: Wrong password -> 401 generic invalid credentials
    # -------------------------------------------------------------------------
    resp5 = await client.post(
        "/api/v1/auth/login",
        json={"email": principal_b.email, "password": "WrongPassword999!"},
        headers={"X-Tenant-ID": str(tenant_a.id)}
    )
    assert resp5.status_code == 401, f"Test 5 failed: {resp5.text}"
    assert resp5.json()["message"] == "Invalid email or password."

    # -------------------------------------------------------------------------
    # TEST 6: Inactive user rejection -> 403 Forbidden
    # -------------------------------------------------------------------------
    inactive_user = await service.create_user(tenant_b.id, UserCreate(
        email=f"inactive.{uuid.uuid4().hex[:6]}@telanganaschool.edu",
        password="EduPulse@123",
        first_name="Inactive",
        last_name="User"
    ))
    inactive_user.status = UserStatus.INACTIVE
    await db_session.commit()

    resp6 = await client.post(
        "/api/v1/auth/login",
        json={"email": inactive_user.email, "password": "EduPulse@123"}
    )
    assert resp6.status_code == 403, f"Test 6 failed: {resp6.text}"
    assert "Access denied" in resp6.json()["message"]

    # -------------------------------------------------------------------------
    # TEST 7: Deleted user -> 401 generic invalid credentials
    # -------------------------------------------------------------------------
    deleted_user = await service.create_user(tenant_b.id, UserCreate(
        email=f"deleted.{uuid.uuid4().hex[:6]}@telanganaschool.edu",
        password="EduPulse@123",
        first_name="Deleted",
        last_name="User"
    ))
    deleted_user.deleted_at = datetime.now(timezone.utc)
    await db_session.commit()

    resp7 = await client.post(
        "/api/v1/auth/login",
        json={"email": deleted_user.email, "password": "EduPulse@123"}
    )
    assert resp7.status_code == 401, f"Test 7 failed: {resp7.text}"
    assert resp7.json()["message"] == "Invalid email or password."

    # -------------------------------------------------------------------------
    # TEST 8: Cross-tenant authenticated request -> 403 Forbidden
    # User in Tenant A tries to access School in Tenant B
    # -------------------------------------------------------------------------
    headers_user_a = {
        "Authorization": f"Bearer {token_1}",
        "X-Tenant-ID": str(tenant_a.id),
        "X-School-ID": str(school_b.id)  # Belongs to Tenant B
    }
    resp8_detail = await client.get(f"/api/v1/schools/{school_b.id}", headers=headers_user_a)
    assert resp8_detail.status_code in (403, 404), f"Test 8 failed: {resp8_detail.text}"

    # -------------------------------------------------------------------------
    # TEST 9: Forged X-Tenant-ID after authentication -> 401 Mismatch
    # -------------------------------------------------------------------------
    headers_forged = {
        "Authorization": f"Bearer {token_1}",
        "X-Tenant-ID": str(tenant_b.id)  # Token is Tenant A, header claims Tenant B
    }
    resp9 = await client.get("/api/v1/auth/me", headers=headers_forged)
    assert resp9.status_code == 401, f"Test 9 failed: {resp9.text}"
    assert "mismatch" in resp9.json()["message"].lower()

    # -------------------------------------------------------------------------
    # TEST 10: Duplicate email across tenants -> Safe ambiguity handling (400)
    # -------------------------------------------------------------------------
    shared_email = f"shared.user.{uuid.uuid4().hex[:6]}@shared.com"
    u_tenant_a = await service.create_user(tenant_a.id, UserCreate(
        email=shared_email, password="Password123!", first_name="Dup", last_name="A"
    ))
    u_tenant_b = await service.create_user(tenant_b.id, UserCreate(
        email=shared_email, password="Password123!", first_name="Dup", last_name="B"
    ))
    assert u_tenant_a.id != u_tenant_b.id

    # 10a. Login without header or with unmatched header -> 400 Ambiguity
    resp10a = await client.post(
        "/api/v1/auth/login",
        json={"email": shared_email, "password": "Password123!"}
    )
    assert resp10a.status_code == 400, f"Test 10a failed: {resp10a.text}"
    assert "Multiple organization accounts" in resp10a.json()["message"]

    # 10b. Login with explicit Tenant A header resolves unambiguous Tenant A user
    resp10b = await client.post(
        "/api/v1/auth/login",
        json={"email": shared_email, "password": "Password123!"},
        headers={"X-Tenant-ID": str(tenant_a.id)}
    )
    assert resp10b.status_code == 200, f"Test 10b failed: {resp10b.text}"
    token_10b = resp10b.json()["data"]["access_token"]
    assert decode_access_token(token_10b)["tenant_id"] == str(tenant_a.id)

    # 10c. Login with explicit Tenant B header resolves unambiguous Tenant B user
    resp10c = await client.post(
        "/api/v1/auth/login",
        json={"email": shared_email, "password": "Password123!"},
        headers={"X-Tenant-ID": str(tenant_b.id)}
    )
    assert resp10c.status_code == 200, f"Test 10c failed: {resp10c.text}"
    token_10c = resp10c.json()["data"]["access_token"]
    assert decode_access_token(token_10c)["tenant_id"] == str(tenant_b.id)


@pytest.mark.anyio
async def test_legacy_play_store_tenant_header_compatibility(client: AsyncClient, db_session) -> None:
    """
    Regression test suite for Legacy Play Store Tenant Header Compatibility:
    Rule 1: JWT + no X-Tenant-ID -> 200 OK (JWT tenant authoritative)
    Rule 2: JWT + matching X-Tenant-ID -> 200 OK
    Rule 3: JWT + legacy Play Store X-Tenant-ID -> 200 OK (legacy header ignored, JWT tenant authoritative)
    Rule 4: JWT + arbitrary wrong X-Tenant-ID -> 401 Unauthorized (boundary mismatch)
    Rule 5: JWT + another legitimate X-Tenant-ID -> 401 Unauthorized (boundary mismatch)
    Rule 6: JWT tenant remains authoritative (user profile & downstream operations retain real tenant)
    Rule 7: School authorization still enforced (user cannot access schools outside assigned context)
    Rule 8: Cross-tenant data access remains blocked
    """
    repo_t = TenantRepository(db_session)
    repo_s = SchoolRepository(db_session)
    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, repo_s)

    # 1. Setup Tenant X with School X and Principal User
    tenant_x = await repo_t.create(TenantCreate(
        name="Telangana Public School",
        code=f"tx-{uuid.uuid4().hex[:6]}",
        subdomain=f"sub-x-{uuid.uuid4().hex[:6]}",
        email=f"contact-x-{uuid.uuid4().hex[:6]}@telangana.edu"
    ))
    school_x = await repo_s.create(tenant_x.id, SchoolCreate(
        name="TPS Campus 1",
        code=f"SCHX_{uuid.uuid4().hex[:4].upper()}",
        board="STATE",
        email=f"campus1-{uuid.uuid4().hex[:6]}@telangana.edu"
    ))
    role_principal = await service.create_role(tenant_x.id, RoleCreate(
        name="Principal",
        code=f"PRINCIPAL_{uuid.uuid4().hex[:4].upper()}",
        description="Principal Role"
    ))
    principal_user = await service.create_user(tenant_x.id, UserCreate(
        email=f"principal.test.{uuid.uuid4().hex[:6]}@telangana.edu",
        password="EduPulse@123",
        first_name="Principal",
        last_name="Test",
        role_ids=[role_principal.id],
        school_ids=[school_x.id]
    ))

    # 2. Setup Tenant Y with School Y (for cross-tenant boundary and authorization tests)
    tenant_y = await repo_t.create(TenantCreate(
        name="Other School Trust",
        code=f"ty-{uuid.uuid4().hex[:6]}",
        subdomain=f"sub-y-{uuid.uuid4().hex[:6]}",
        email=f"contact-y-{uuid.uuid4().hex[:6]}@other.edu"
    ))
    school_y = await repo_s.create(tenant_y.id, SchoolCreate(
        name="Other Campus",
        code=f"SCHY_{uuid.uuid4().hex[:4].upper()}",
        board="CBSE",
        email=f"campus-y-{uuid.uuid4().hex[:6]}@other.edu"
    ))

    # 3. Authenticate User -> obtain valid JWT token
    login_resp = await client.post(
        "/api/v1/auth/login",
        json={"email": principal_user.email, "password": "EduPulse@123"},
        headers={"X-Tenant-ID": str(LEGACY_PLAY_STORE_TENANT_ID)}
    )
    assert login_resp.status_code == 200, f"Login failed: {login_resp.text}"
    token = login_resp.json()["data"]["access_token"]
    payload = decode_access_token(token)
    assert payload["tenant_id"] == str(tenant_x.id)
    assert payload["tenant_id"] != str(LEGACY_PLAY_STORE_TENANT_ID)

    # -------------------------------------------------------------------------
    # Rule 1: JWT + no X-Tenant-ID -> 200 OK
    # -------------------------------------------------------------------------
    resp_no_header = await client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert resp_no_header.status_code == 200, f"Rule 1 failed: {resp_no_header.text}"
    data_no_header = resp_no_header.json()["data"]
    assert data_no_header["tenant_id"] == str(tenant_x.id)
    assert data_no_header["email"] == principal_user.email

    # -------------------------------------------------------------------------
    # Rule 2: JWT + matching X-Tenant-ID -> 200 OK
    # -------------------------------------------------------------------------
    resp_matching = await client.get(
        "/api/v1/auth/me",
        headers={
            "Authorization": f"Bearer {token}",
            "X-Tenant-ID": str(tenant_x.id)
        }
    )
    assert resp_matching.status_code == 200, f"Rule 2 failed: {resp_matching.text}"
    data_matching = resp_matching.json()["data"]
    assert data_matching["tenant_id"] == str(tenant_x.id)

    # -------------------------------------------------------------------------
    # Rule 3: JWT + legacy Play Store X-Tenant-ID -> 200 OK
    # (The legacy Play Store header 09f2d4e7... MUST be ignored and JWT tenant used)
    # -------------------------------------------------------------------------
    resp_legacy = await client.get(
        "/api/v1/auth/me",
        headers={
            "Authorization": f"Bearer {token}",
            "X-Tenant-ID": str(LEGACY_PLAY_STORE_TENANT_ID)
        }
    )
    assert resp_legacy.status_code == 200, f"Rule 3 failed: {resp_legacy.text}"
    data_legacy = resp_legacy.json()["data"]
    assert data_legacy["tenant_id"] == str(tenant_x.id)
    assert data_legacy["tenant_id"] != str(LEGACY_PLAY_STORE_TENANT_ID)

    # -------------------------------------------------------------------------
    # Rule 4: JWT + arbitrary wrong X-Tenant-ID -> 401 Unauthorized
    # -------------------------------------------------------------------------
    arbitrary_tenant_id = uuid.uuid4()
    resp_arbitrary = await client.get(
        "/api/v1/auth/me",
        headers={
            "Authorization": f"Bearer {token}",
            "X-Tenant-ID": str(arbitrary_tenant_id)
        }
    )
    assert resp_arbitrary.status_code == 401, f"Rule 4 failed: {resp_arbitrary.text}"
    assert "mismatch" in resp_arbitrary.json()["message"].lower()

    # -------------------------------------------------------------------------
    # Rule 5: JWT + another legitimate X-Tenant-ID -> 401 Unauthorized
    # (Cannot switch to Tenant Y while token is signed for Tenant X)
    # -------------------------------------------------------------------------
    resp_other_tenant = await client.get(
        "/api/v1/auth/me",
        headers={
            "Authorization": f"Bearer {token}",
            "X-Tenant-ID": str(tenant_y.id)
        }
    )
    assert resp_other_tenant.status_code == 401, f"Rule 5 failed: {resp_other_tenant.text}"
    assert "mismatch" in resp_other_tenant.json()["message"].lower()

    # -------------------------------------------------------------------------
    # Rule 6: School authorization still enforced with legacy header
    # User can access School X (their school), but NOT School Y (another school)
    # -------------------------------------------------------------------------
    resp_school_x = await client.get(
        f"/api/v1/schools/{school_x.id}",
        headers={
            "Authorization": f"Bearer {token}",
            "X-Tenant-ID": str(LEGACY_PLAY_STORE_TENANT_ID),
            "X-School-ID": str(school_x.id)
        }
    )
    assert resp_school_x.status_code == 200, f"Rule 6a failed: {resp_school_x.text}"

    resp_school_y = await client.get(
        f"/api/v1/schools/{school_y.id}",
        headers={
            "Authorization": f"Bearer {token}",
            "X-Tenant-ID": str(LEGACY_PLAY_STORE_TENANT_ID),
            "X-School-ID": str(school_y.id)
        }
    )
    assert resp_school_y.status_code in (403, 404), f"Rule 6b cross-school access must fail: {resp_school_y.text}"

    # -------------------------------------------------------------------------
    # Rule 7: get_tenant_id dependency bridges legacy header to authentic JWT tenant
    # -------------------------------------------------------------------------
    # 7a. With legacy header + JWT token -> returns JWT tenant, NOT legacy header
    res_t1 = await get_tenant_id(
        x_tenant_id=str(LEGACY_PLAY_STORE_TENANT_ID),
        authorization=f"Bearer {token}"
    )
    assert res_t1 == tenant_x.id
    assert res_t1 != LEGACY_PLAY_STORE_TENANT_ID

    # 7b. Without header + JWT token -> returns JWT tenant
    res_t2 = await get_tenant_id(
        x_tenant_id=None,
        authorization=f"Bearer {token}"
    )
    assert res_t2 == tenant_x.id

    # 7c. With matching header -> returns matching tenant
    res_t3 = await get_tenant_id(
        x_tenant_id=str(tenant_x.id),
        authorization=f"Bearer {token}"
    )
    assert res_t3 == tenant_x.id

    # 7d. Without header and without token -> raises 400
    with pytest.raises(HTTPException) as exc_info:
        await get_tenant_id(x_tenant_id=None, authorization=None)
    assert exc_info.value.status_code == 400

    # -------------------------------------------------------------------------
    # Rule 8: Cross-tenant data access remains blocked
    # Even with legacy header, accessing resources belonging to Tenant Y is forbidden
    # -------------------------------------------------------------------------
    resp_cross = await client.get(
        f"/api/v1/schools/{school_y.id}",
        headers={
            "Authorization": f"Bearer {token}",
            "X-Tenant-ID": str(LEGACY_PLAY_STORE_TENANT_ID)
        }
    )
    assert resp_cross.status_code in (403, 404), f"Rule 8 failed: {resp_cross.text}"

