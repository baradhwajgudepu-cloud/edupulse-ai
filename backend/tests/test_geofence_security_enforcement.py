import uuid
import pytest
from datetime import date, datetime, timezone
from httpx import AsyncClient
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import status

from app.main import app
from app.models.tenant import Tenant
from app.models.school import School
from app.models.teacher import Teacher, TeacherStatus, EmploymentType
from app.models.role import Role
from app.models.permission import Permission
from app.models.user import User, UserStatus
from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate
from app.schemas.teacher import TeacherCreate
from app.schemas.auth import UserCreate
from app.services.staff_attendance import StaffAttendanceService
from app.services.auth import AuthService
from app.api.dependencies.auth import get_current_user
from app.models.student import StudentGender

# Test School Anchor Coordinates: Hyderabad Tech Campus
SCHOOL_LAT = 17.448500
SCHOOL_LON = 78.374100
SCHOOL_RADIUS = 100  # 100 meters

@pytest.fixture
async def sec_test_data(db_session: AsyncSession):
    suffix = uuid.uuid4().hex[:6].upper()
    repo_t = TenantRepository(db_session)
    tenant_a = await repo_t.create(TenantCreate(
        name=f"Sec Tenant A {suffix}", code=f"t-sec-a-{suffix.lower()}", 
        subdomain=f"t-sec-a-{suffix.lower()}", email=f"seca-{suffix.lower()}@t.com"
    ))
    tenant_b = await repo_t.create(TenantCreate(
        name=f"Sec Tenant B {suffix}", code=f"t-sec-b-{suffix.lower()}", 
        subdomain=f"t-sec-b-{suffix.lower()}", email=f"secb-{suffix.lower()}@t.com"
    ))

    repo_s = SchoolRepository(db_session)
    admin_id = uuid.uuid4()
    
    # School A: Properly configured geofence
    school_a = await repo_s.create(tenant_a.id, SchoolCreate(
        name="Security School A", code=f"SCH_SEC_A_{suffix}", board="CBSE", email=f"s-sec-a-{suffix.lower()}@a.com"
    ))
    school_a.latitude = SCHOOL_LAT
    school_a.longitude = SCHOOL_LON
    school_a.geofence_radius_meters = SCHOOL_RADIUS
    school_a.settings = {
        "geofence": {
            "enabled": True,
            "updated_by": str(admin_id),
            "updated_at": datetime.now(timezone.utc).isoformat()
        }
    }
    school_a.updated_by = admin_id
    db_session.add(school_a)

    # School Unconfigured: coordinates are None
    school_unconf = await repo_s.create(tenant_a.id, SchoolCreate(
        name="Security School Unconfigured", code=f"SCH_SEC_UNC_{suffix}", board="CBSE", email=f"s-sec-unc-{suffix.lower()}@a.com"
    ))
    school_unconf.latitude = None
    school_unconf.longitude = None
    school_unconf.geofence_radius_meters = 100
    school_unconf.settings = {}
    db_session.add(school_unconf)

    # School B: Belongs to Tenant B
    school_b = await repo_s.create(tenant_b.id, SchoolCreate(
        name="Security School B", code=f"SCH_SEC_B_{suffix}", board="CBSE", email=f"s-sec-b-{suffix.lower()}@b.com"
    ))
    school_b.latitude = SCHOOL_LAT
    school_b.longitude = SCHOOL_LON
    school_b.geofence_radius_meters = SCHOOL_RADIUS
    db_session.add(school_b)
    await db_session.commit()

    stmt_p = select(Permission)
    res_p = await db_session.execute(stmt_p)
    all_perms = list(res_p.scalars().all())

    # Map Teacher Role
    role_teacher = Role(name="Sec Teacher Role", code=f"SEC_TEACHER_{suffix}", is_system=True, tenant_id=tenant_a.id)
    role_teacher.permissions = [p for p in all_perms if p.code in ["staff_attendance.read", "staff_attendance.create", "staff_attendance.update"]]
    db_session.add(role_teacher)

    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    auth_service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, repo_s)
    
    # Active Teacher User in School A
    teacher_user_a = await auth_service.create_user(
        tenant_a.id,
        UserCreate(email=f"teacher-sec-a-{suffix}@a.com", password="Password123!", first_name="Elena", last_name="Rostova")
    )
    teacher_user_a.roles.append(role_teacher)
    teacher_user_a.status = UserStatus.ACTIVE
    db_session.add(teacher_user_a)

    await db_session.execute(
        text("INSERT INTO school_users (user_id, school_id) VALUES (:u, :s)"),
        {"u": str(teacher_user_a.id), "s": str(school_a.id)}
    )

    teacher_repo = TeacherRepository(db_session)
    teacher_profile_a = await teacher_repo.create(
        tenant_a.id,
        TeacherCreate(
            employee_code=f"EMP_A_{suffix}",
            staff_code=f"STF_A_{suffix}",
            first_name="Elena",
            last_name="Rostova",
            gender=StudentGender.FEMALE,
            date_of_birth=date(1990, 5, 15),
            mobile="9876543210",
            official_email=f"teacher-sec-a-{suffix}@a.com",
            joining_date=date(2023, 1, 1),
            employment_type=EmploymentType.FULL_TIME,
            school_id=school_a.id
        )
    )
    teacher_profile_a.user_id = teacher_user_a.id
    db_session.add(teacher_profile_a)

    # Active Teacher User in Unconfigured School
    teacher_user_unc = await auth_service.create_user(
        tenant_a.id,
        UserCreate(email=f"teacher-sec-unc-{suffix}@a.com", password="Password123!", first_name="Mikhail", last_name="Petrov")
    )
    teacher_user_unc.roles.append(role_teacher)
    teacher_user_unc.status = UserStatus.ACTIVE
    db_session.add(teacher_user_unc)

    await db_session.execute(
        text("INSERT INTO school_users (user_id, school_id) VALUES (:u, :s)"),
        {"u": str(teacher_user_unc.id), "s": str(school_unconf.id)}
    )

    teacher_profile_unc = await teacher_repo.create(
        tenant_a.id,
        TeacherCreate(
            employee_code=f"EMP_UNC_{suffix}",
            staff_code=f"STF_UNC_{suffix}",
            first_name="Mikhail",
            last_name="Petrov",
            gender=StudentGender.MALE,
            date_of_birth=date(1988, 3, 20),
            mobile="9876543211",
            official_email=f"teacher-sec-unc-{suffix}@a.com",
            joining_date=date(2023, 1, 1),
            employment_type=EmploymentType.FULL_TIME,
            school_id=school_unconf.id
        )
    )
    teacher_profile_unc.user_id = teacher_user_unc.id
    db_session.add(teacher_profile_unc)

    await db_session.commit()

    return {
        "tenant_a": tenant_a,
        "tenant_b": tenant_b,
        "school_a": school_a,
        "school_unconf": school_unconf,
        "school_b": school_b,
        "teacher_user_a": teacher_user_a,
        "teacher_profile_a": teacher_profile_a,
        "teacher_user_unc": teacher_user_unc,
        "teacher_profile_unc": teacher_profile_unc,
        "admin_id": admin_id,
    }


# ==============================================================================
# 1. Distance & 2 km Enforcement
# ==============================================================================

@pytest.mark.anyio
async def test_geofence_enforced_teacher_2km_away_rejected(client: AsyncClient, sec_test_data: dict):
    """
    Teacher ~2 km away from school MUST be rejected when geofencing is enabled.
    0.018 degrees latitude difference is ~2000 meters.
    """
    data = sec_test_data
    app.dependency_overrides[get_current_user] = lambda: data["teacher_user_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    payload = {
        "latitude": SCHOOL_LAT + 0.018000,
        "longitude": SCHOOL_LON,
        "accuracy": 10.0,
        "is_mocked": False
    }
    resp = await client.post("/api/v1/staff-attendance/check-in", json=payload, headers=headers)
    assert resp.status_code == status.HTTP_400_BAD_REQUEST
    msg = resp.json()["message"]
    assert "outside the permitted school geofence" in msg
    assert "Check-in failed" in msg

    app.dependency_overrides.pop(get_current_user, None)


# ==============================================================================
# 2. Deterministic GPS Accuracy Validation
# ==============================================================================

@pytest.mark.anyio
async def test_geofence_missing_accuracy_rejected(client: AsyncClient, sec_test_data: dict):
    """
    If accuracy is None / omitted, backend MUST reject with HTTP 400.
    """
    data = sec_test_data
    app.dependency_overrides[get_current_user] = lambda: data["teacher_user_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    # Accuracy omitted
    payload = {
        "latitude": SCHOOL_LAT,
        "longitude": SCHOOL_LON,
        "is_mocked": False
    }
    resp = await client.post("/api/v1/staff-attendance/check-in", json=payload, headers=headers)
    assert resp.status_code == status.HTTP_400_BAD_REQUEST
    assert "GPS accuracy reading is required" in resp.json()["message"]

    # Accuracy explicitly None
    payload_none = {
        "latitude": SCHOOL_LAT,
        "longitude": SCHOOL_LON,
        "accuracy": None,
        "is_mocked": False
    }
    resp2 = await client.post("/api/v1/staff-attendance/check-in", json=payload_none, headers=headers)
    assert resp2.status_code == status.HTTP_400_BAD_REQUEST
    assert "GPS accuracy reading is required" in resp2.json()["message"]

    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.anyio
async def test_geofence_degraded_accuracy_rejected(client: AsyncClient, sec_test_data: dict):
    """
    If GPS accuracy reading is > 100.0m, check-in must be rejected.
    """
    data = sec_test_data
    app.dependency_overrides[get_current_user] = lambda: data["teacher_user_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    payload = {
        "latitude": SCHOOL_LAT,
        "longitude": SCHOOL_LON,
        "accuracy": 100.1,
        "is_mocked": False
    }
    resp = await client.post("/api/v1/staff-attendance/check-in", json=payload, headers=headers)
    assert resp.status_code == status.HTTP_400_BAD_REQUEST
    assert "GPS accuracy is too low" in resp.json()["message"]

    app.dependency_overrides.pop(get_current_user, None)


# ==============================================================================
# 3. Dynamic Boundary & Tolerance Model
# ==============================================================================

@pytest.mark.anyio
async def test_geofence_boundary_within_tolerance_accepted(client: AsyncClient, sec_test_data: dict):
    """
    tolerance = min(accuracy, 15.0, radius * 0.1).
    For radius = 100m, radius * 0.1 = 10.0m.
    If accuracy = 10.0m, tolerance = 10.0m. Effective max distance = 110.0m.
    Distance at 105m should be accepted.
    """
    data = sec_test_data
    app.dependency_overrides[get_current_user] = lambda: data["teacher_user_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    service = StaffAttendanceService(None, None, None)
    # 0.00095 degrees lat offset ~ 105.6 meters
    offset_lat = SCHOOL_LAT + 0.000950
    dist = service.haversine_distance(offset_lat, SCHOOL_LON, SCHOOL_LAT, SCHOOL_LON)
    assert 100.0 < dist <= 110.0

    payload = {
        "latitude": offset_lat,
        "longitude": SCHOOL_LON,
        "accuracy": 10.0,
        "is_mocked": False,
        "remarks": "Check-in on boundary with good accuracy fix"
    }
    resp = await client.post("/api/v1/staff-attendance/check-in", json=payload, headers=headers)
    assert resp.status_code == status.HTTP_201_CREATED
    assert resp.json()["data"]["status"] == "CHECKED_IN"

    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.anyio
async def test_geofence_boundary_outside_tolerance_rejected(client: AsyncClient, sec_test_data: dict, db_session: AsyncSession):
    """
    Distance at 115m (> 100m + 10m tolerance) MUST be rejected.
    """
    data = sec_test_data
    school = data["school_unconf"]
    school.latitude = SCHOOL_LAT
    school.longitude = SCHOOL_LON
    school.geofence_radius_meters = 100
    db_session.add(school)
    await db_session.commit()

    app.dependency_overrides[get_current_user] = lambda: data["teacher_user_unc"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    service = StaffAttendanceService(None, None, None)
    offset_lat = SCHOOL_LAT + 0.001050
    dist = service.haversine_distance(offset_lat, SCHOOL_LON, SCHOOL_LAT, SCHOOL_LON)
    assert dist > 110.0

    payload = {
        "latitude": offset_lat,
        "longitude": SCHOOL_LON,
        "accuracy": 10.0,
        "is_mocked": False
    }
    resp = await client.post("/api/v1/staff-attendance/check-in", json=payload, headers=headers)
    assert resp.status_code == status.HTTP_400_BAD_REQUEST
    assert "outside the permitted school geofence" in resp.json()["message"]

    app.dependency_overrides.pop(get_current_user, None)


# ==============================================================================
# 4. Anti-Spoofing & Uncontrollable Decision Fields
# ==============================================================================

@pytest.mark.anyio
async def test_client_spoofed_fields_ignored(client: AsyncClient, sec_test_data: dict):
    """
    Client sends spoofable fields:
    - is_within_geofence: True
    - distance: 0.0
    - geofence_verified: True
    while GPS coordinates are 2 km away.
    Server MUST NOT be influenced and MUST reject with HTTP 400.
    """
    data = sec_test_data
    app.dependency_overrides[get_current_user] = lambda: data["teacher_user_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    spoofed_payload = {
        "latitude": SCHOOL_LAT + 0.018000,  # 2 km away
        "longitude": SCHOOL_LON,
        "accuracy": 10.0,
        "is_mocked": False,
        "is_within_geofence": True,
        "distance": 0.0,
        "geofence_verified": True
    }
    resp = await client.post("/api/v1/staff-attendance/check-in", json=spoofed_payload, headers=headers)
    assert resp.status_code == status.HTTP_400_BAD_REQUEST
    assert "outside the permitted school geofence" in resp.json()["message"]

    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.anyio
async def test_geofence_mocked_location_rejected_even_inside_radius(client: AsyncClient, sec_test_data: dict):
    """
    Simulated/mocked GPS providers (is_mocked=True) MUST be rejected with HTTP 400
    even if the spoofed coordinates are precisely at the school center (0m distance).
    """
    data = sec_test_data
    app.dependency_overrides[get_current_user] = lambda: data["teacher_user_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    mocked_payload = {
        "latitude": SCHOOL_LAT,  # Exactly at school center
        "longitude": SCHOOL_LON,
        "accuracy": 5.0,
        "is_mocked": True,
        "remarks": "Attempting check-in via mock GPS app"
    }
    resp = await client.post("/api/v1/staff-attendance/check-in", json=mocked_payload, headers=headers)
    assert resp.status_code == status.HTTP_400_BAD_REQUEST
    assert "Mocked GPS location detected" in resp.json()["message"]
    assert "cannot be verified using simulated location providers" in resp.json()["message"]

    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.anyio
async def test_checkout_mocked_location_rejected(client: AsyncClient, sec_test_data: dict):
    """
    Check-out with is_mocked=True MUST be rejected with HTTP 400
    even if coordinates are inside the school geofence.
    """
    data = sec_test_data
    app.dependency_overrides[get_current_user] = lambda: data["teacher_user_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    # Valid check-in first
    valid_ci = {
        "latitude": SCHOOL_LAT,
        "longitude": SCHOOL_LON,
        "accuracy": 10.0,
        "is_mocked": False
    }
    resp_ci = await client.post("/api/v1/staff-attendance/check-in", json=valid_ci, headers=headers)
    assert resp_ci.status_code == status.HTTP_201_CREATED

    # Attempt check-out with mock location
    mocked_co = {
        "latitude": SCHOOL_LAT,
        "longitude": SCHOOL_LON,
        "accuracy": 5.0,
        "is_mocked": True
    }
    resp_co = await client.post("/api/v1/staff-attendance/check-out", json=mocked_co, headers=headers)
    assert resp_co.status_code == status.HTTP_400_BAD_REQUEST
    assert "Mocked GPS location detected" in resp_co.json()["message"]
    assert "Check-out cannot be verified" in resp_co.json()["message"]

    app.dependency_overrides.pop(get_current_user, None)


# ==============================================================================
# 5. Fail-Safe Geofence Configuration Enforcement
# ==============================================================================

@pytest.mark.anyio
async def test_geofence_unconfigured_coordinates_fail_safe_rejected(client: AsyncClient, sec_test_data: dict, db_session: AsyncSession):
    """
    School with enabled=True but latitude/longitude=None MUST fail safely (HTTP 400).
    It must NEVER allow sign-in under the guise of 'disabled'.
    """
    data = sec_test_data
    school_unc = data["school_unconf"]
    school_unc.latitude = None
    school_unc.longitude = None
    db_session.add(school_unc)
    await db_session.commit()

    app.dependency_overrides[get_current_user] = lambda: data["teacher_user_unc"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    payload = {
        "latitude": SCHOOL_LAT,
        "longitude": SCHOOL_LON,
        "accuracy": 10.0,
        "is_mocked": False
    }
    resp = await client.post("/api/v1/staff-attendance/check-in", json=payload, headers=headers)
    assert resp.status_code == status.HTTP_400_BAD_REQUEST
    assert "School geolocation coordinates are not configured" in resp.json()["message"]

    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.anyio
async def test_geofence_unconfigured_radius_fail_safe_rejected(client: AsyncClient, sec_test_data: dict, db_session: AsyncSession):
    """
    School with coordinates but radius=0 or None MUST fail safely with HTTP 400.
    """
    data = sec_test_data
    school = data["school_a"]
    school.geofence_radius_meters = 0
    db_session.add(school)
    await db_session.commit()

    app.dependency_overrides[get_current_user] = lambda: data["teacher_user_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    payload = {
        "latitude": SCHOOL_LAT,
        "longitude": SCHOOL_LON,
        "accuracy": 10.0,
        "is_mocked": False
    }
    resp = await client.post("/api/v1/staff-attendance/check-in", json=payload, headers=headers)
    assert resp.status_code == status.HTTP_400_BAD_REQUEST
    assert "geofence radius is not configured" in resp.json()["message"]

    # Restore radius
    school.geofence_radius_meters = SCHOOL_RADIUS
    db_session.add(school)
    await db_session.commit()
    app.dependency_overrides.pop(get_current_user, None)


# ==============================================================================
# 6. Disabled Policy Authorization & Exemption Tracking
# ==============================================================================

@pytest.mark.anyio
async def test_geofence_disabled_allows_sign_in_and_records_exemption(client: AsyncClient, sec_test_data: dict, db_session: AsyncSession):
    """
    When geofence is explicitly disabled by an authorized administrator:
    1. Teacher ~2 km away can check in (HTTP 201).
    2. Exemption tag with actor ID is recorded in remarks:
       [GEOFENCE_EXEMPTION: Authorized school geofence restriction disabled | Actor: <actor_id>]
    """
    data = sec_test_data
    school = data["school_a"]
    admin_id = data["admin_id"]

    school.settings = {
        "geofence": {
            "enabled": False,
            "updated_by": str(admin_id),
            "updated_at": datetime.now(timezone.utc).isoformat()
        }
    }
    db_session.add(school)
    await db_session.commit()

    app.dependency_overrides[get_current_user] = lambda: data["teacher_user_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    payload = {
        "latitude": SCHOOL_LAT + 0.018000,  # 2 km away
        "longitude": SCHOOL_LON,
        "accuracy": 10.0,
        "is_mocked": False,
        "remarks": "Offsite administrative duty"
    }
    resp = await client.post("/api/v1/staff-attendance/check-in", json=payload, headers=headers)
    assert resp.status_code == status.HTTP_201_CREATED
    rec_data = resp.json()["data"]
    assert rec_data["status"] == "CHECKED_IN"
    assert rec_data["check_in_distance_meters"] > 1800.0
    assert "[GEOFENCE_EXEMPTION:" in rec_data["remarks"]
    assert str(admin_id) in rec_data["remarks"]
    assert "Offsite administrative duty" in rec_data["remarks"]

    # Restore enabled
    school.settings["geofence"]["enabled"] = True
    db_session.add(school)
    await db_session.commit()
    app.dependency_overrides.pop(get_current_user, None)


# ==============================================================================
# 7. Check-Out Geofence Enforcement Parity
# ==============================================================================

@pytest.mark.anyio
async def test_checkout_geofence_enforcement_outside_rejected(client: AsyncClient, sec_test_data: dict):
    """
    Check-out at 2 km distance MUST be rejected when geofencing is enabled.
    """
    data = sec_test_data
    app.dependency_overrides[get_current_user] = lambda: data["teacher_user_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    # 0. Check in first inside geofence
    ci_payload = {
        "latitude": SCHOOL_LAT,
        "longitude": SCHOOL_LON,
        "accuracy": 10.0,
        "is_mocked": False,
        "remarks": "Morning shift check-in"
    }
    resp_ci = await client.post("/api/v1/staff-attendance/check-in", json=ci_payload, headers=headers)
    assert resp_ci.status_code == status.HTTP_201_CREATED

    # 1. Check-out far away MUST be rejected
    co_payload_far = {
        "latitude": SCHOOL_LAT + 0.018000,
        "longitude": SCHOOL_LON,
        "accuracy": 10.0,
        "is_mocked": False
    }
    resp_co_far = await client.post("/api/v1/staff-attendance/check-out", json=co_payload_far, headers=headers)
    assert resp_co_far.status_code == status.HTTP_400_BAD_REQUEST
    assert "outside the permitted school geofence" in resp_co_far.json()["message"]
    assert "Check-out failed" in resp_co_far.json()["message"]

    # 2. Check-out inside boundary succeeds
    co_payload_near = {
        "latitude": SCHOOL_LAT,
        "longitude": SCHOOL_LON,
        "accuracy": 10.0,
        "is_mocked": False,
        "remarks": "Shift finished"
    }
    resp_co_near = await client.post("/api/v1/staff-attendance/check-out", json=co_payload_near, headers=headers)
    assert resp_co_near.status_code == status.HTTP_200_OK
    assert resp_co_near.json()["data"]["status"] == "CHECKED_OUT"

    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.anyio
async def test_checkout_geofence_disabled_records_exemption(client: AsyncClient, sec_test_data: dict, db_session: AsyncSession):
    """
    Teacher check-out when geofence is disabled by administrator allows remote checkout and appends exemption.
    """
    data = sec_test_data
    school = data["school_a"]
    admin_id = data["admin_id"]

    # Disable geofence
    school.settings = {
        "geofence": {
            "enabled": False,
            "updated_by": str(admin_id),
            "updated_at": datetime.now(timezone.utc).isoformat()
        }
    }
    db_session.add(school)
    await db_session.commit()

    app.dependency_overrides[get_current_user] = lambda: data["teacher_user_unc"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    # Configure school_unc coordinates
    school_unc = data["school_unconf"]
    school_unc.latitude = SCHOOL_LAT
    school_unc.longitude = SCHOOL_LON
    school_unc.settings = {
        "geofence": {
            "enabled": False,
            "updated_by": str(admin_id),
            "updated_at": datetime.now(timezone.utc).isoformat()
        }
    }
    db_session.add(school_unc)
    await db_session.commit()

    # 1. Check in
    ci_resp = await client.post("/api/v1/staff-attendance/check-in", json={
        "latitude": SCHOOL_LAT,
        "longitude": SCHOOL_LON,
        "accuracy": 10.0,
        "is_mocked": False,
        "remarks": "Regular start"
    }, headers=headers)
    assert ci_resp.status_code == status.HTTP_201_CREATED

    # 2. Check out remotely 2 km away
    co_resp = await client.post("/api/v1/staff-attendance/check-out", json={
        "latitude": SCHOOL_LAT + 0.018000,
        "longitude": SCHOOL_LON,
        "accuracy": 10.0,
        "is_mocked": False,
        "remarks": "Left for field visit"
    }, headers=headers)
    assert co_resp.status_code == status.HTTP_200_OK
    assert co_resp.json()["data"]["status"] == "CHECKED_OUT"
    assert "[GEOFENCE_EXEMPTION:" in co_resp.json()["data"]["remarks"]

    app.dependency_overrides.pop(get_current_user, None)


# ==============================================================================
# 8. GET /schools/{id}/geofence Decoupled State Matrix
# ==============================================================================

@pytest.mark.anyio
async def test_get_school_geofence_decouples_enabled_from_is_configured(client: AsyncClient, sec_test_data: dict):
    """
    Verifies that for an unconfigured school:
    enabled: True (policy is active)
    is_configured: False (coordinates missing)
    This prevents the UI from displaying 'Geofence Disabled'.
    """
    data = sec_test_data
    app.dependency_overrides[get_current_user] = lambda: data["teacher_user_unc"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    school_unc_id = str(data["school_unconf"].id)

    resp = await client.get(f"/api/v1/schools/{school_unc_id}/geofence", headers=headers)
    assert resp.status_code == status.HTTP_200_OK
    gf = resp.json()["data"]
    assert gf["enabled"] is True
    assert gf["is_configured"] is False
    assert gf["latitude"] is None
    assert gf["longitude"] is None

    app.dependency_overrides.pop(get_current_user, None)


# ==============================================================================
# 9. Cross-Tenant School Geofence Isolation
# ==============================================================================

@pytest.mark.anyio
async def test_cross_tenant_school_geofence_isolation(client: AsyncClient, sec_test_data: dict):
    """
    Access to another tenant's school geofence must be rejected with 404.
    """
    data = sec_test_data
    app.dependency_overrides[get_current_user] = lambda: data["teacher_user_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    school_b_id = str(data["school_b"].id)

    resp = await client.get(f"/api/v1/schools/{school_b_id}/geofence", headers=headers)
    assert resp.status_code == status.HTTP_404_NOT_FOUND

    app.dependency_overrides.pop(get_current_user, None)
