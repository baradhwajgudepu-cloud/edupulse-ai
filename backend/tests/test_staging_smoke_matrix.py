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
from app.models.teacher import Teacher, EmploymentType
from app.models.role import Role
from app.models.permission import Permission
from app.models.user import User, UserStatus
from app.models.student import StudentGender
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

# Target Staging School: Telangana Model School & Junior College (TS001)
STAGING_SCHOOL_LAT = 18.028900
STAGING_SCHOOL_LON = 79.564800
STAGING_SCHOOL_RADIUS = 100  # 100 meters


@pytest.fixture
async def staging_fixture(db_session: AsyncSession):
    """
    Sets up isolated test data replicating Telangana Model School & Junior College (TS001).
    Does not touch or modify production database rows.
    """
    suffix = uuid.uuid4().hex[:6].upper()
    repo_t = TenantRepository(db_session)
    tenant_a = await repo_t.create(TenantCreate(
        name=f"Staging Tenant A {suffix}", code=f"t-stg-a-{suffix.lower()}", 
        subdomain=f"stg-a-{suffix.lower()}", email=f"stga-{suffix.lower()}@t.com"
    ))
    tenant_b = await repo_t.create(TenantCreate(
        name=f"Staging Tenant B {suffix}", code=f"t-stg-b-{suffix.lower()}", 
        subdomain=f"stg-b-{suffix.lower()}", email=f"stgb-{suffix.lower()}@t.com"
    ))

    repo_s = SchoolRepository(db_session)
    admin_id = uuid.uuid4()
    
    # Staging School A: Telangana Model School & Junior College (TS001)
    school_a = await repo_s.create(tenant_a.id, SchoolCreate(
        name="Telangana Model School & Junior College", code=f"TS001_{suffix}", board="STATE", email=f"ts001-{suffix.lower()}@stg.com"
    ))
    school_a.latitude = STAGING_SCHOOL_LAT
    school_a.longitude = STAGING_SCHOOL_LON
    school_a.geofence_radius_meters = STAGING_SCHOOL_RADIUS
    school_a.settings = {
        "geofence": {
            "enabled": True,
            "updated_by": str(admin_id),
            "updated_at": datetime.now(timezone.utc).isoformat()
        }
    }
    school_a.updated_by = admin_id
    db_session.add(school_a)

    # School B: Belongs to Tenant B for Cross-Tenant test
    school_b = await repo_s.create(tenant_b.id, SchoolCreate(
        name="Tenant B Campus", code=f"SCH_B_{suffix}", board="CBSE", email=f"sch-b-{suffix.lower()}@stg.com"
    ))
    school_b.latitude = STAGING_SCHOOL_LAT
    school_b.longitude = STAGING_SCHOOL_LON
    school_b.geofence_radius_meters = STAGING_SCHOOL_RADIUS
    db_session.add(school_b)
    await db_session.commit()

    stmt_p = select(Permission)
    res_p = await db_session.execute(stmt_p)
    all_perms = list(res_p.scalars().all())

    # Map Teacher Role
    role_teacher = Role(name="Staging Teacher Role", code=f"STG_TEACHER_{suffix}", is_system=True, tenant_id=tenant_a.id)
    role_teacher.permissions = [p for p in all_perms if p.code in ["staff_attendance.read", "staff_attendance.create", "staff_attendance.update"]]
    db_session.add(role_teacher)

    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    auth_service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, repo_s)
    
    # Active Teacher User in Staging School A
    teacher_user_a = await auth_service.create_user(
        tenant_a.id,
        UserCreate(email=f"teacher-stg-a-{suffix}@stg.com", password="Password123!", first_name="Ravi", last_name="Kumar")
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
            employee_code=f"EMP_TS_{suffix}",
            staff_code=f"STF_TS_{suffix}",
            first_name="Ravi",
            last_name="Kumar",
            gender=StudentGender.MALE,
            date_of_birth=date(1985, 6, 10),
            mobile="9876543219",
            official_email=f"teacher-stg-a-{suffix}@stg.com",
            joining_date=date(2021, 6, 1),
            employment_type=EmploymentType.FULL_TIME,
            school_id=school_a.id
        )
    )
    teacher_profile_a.user_id = teacher_user_a.id
    db_session.add(teacher_profile_a)
    await db_session.commit()

    return {
        "tenant_a": tenant_a,
        "tenant_b": tenant_b,
        "school_a": school_a,
        "school_b": school_b,
        "teacher_user_a": teacher_user_a,
        "teacher_profile_a": teacher_profile_a,
        "admin_id": admin_id,
    }


# ==============================================================================
# 12 STAGING SMOKE TESTS
# ==============================================================================

# ST-01: Inside permitted radius
@pytest.mark.anyio
async def test_st01_inside_permitted_radius(client: AsyncClient, staging_fixture: dict):
    data = staging_fixture
    app.dependency_overrides[get_current_user] = lambda: data["teacher_user_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    payload = {
        "latitude": STAGING_SCHOOL_LAT,
        "longitude": STAGING_SCHOOL_LON,
        "accuracy": 8.0,
        "is_mocked": False,
        "remarks": "On campus check-in"
    }
    resp = await client.post("/api/v1/staff-attendance/check-in", json=payload, headers=headers)
    assert resp.status_code == status.HTTP_201_CREATED
    rec = resp.json()["data"]
    assert rec["status"] == "CHECKED_IN"
    assert rec["check_in_distance_meters"] is not None
    assert rec["check_in_distance_meters"] < 5.0
    app.dependency_overrides.pop(get_current_user, None)


# ST-02: Approximately 2 km away
@pytest.mark.anyio
async def test_st02_approx_2km_away(client: AsyncClient, staging_fixture: dict):
    data = staging_fixture
    app.dependency_overrides[get_current_user] = lambda: data["teacher_user_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    # 0.018 degrees latitude ~ 2000 meters
    payload = {
        "latitude": STAGING_SCHOOL_LAT + 0.018000,
        "longitude": STAGING_SCHOOL_LON,
        "accuracy": 8.0,
        "is_mocked": False
    }
    resp = await client.post("/api/v1/staff-attendance/check-in", json=payload, headers=headers)
    assert resp.status_code == status.HTTP_400_BAD_REQUEST
    assert "outside the permitted school geofence" in resp.json()["message"]
    app.dependency_overrides.pop(get_current_user, None)


# ST-03: Mocked GPS inside radius
@pytest.mark.anyio
async def test_st03_mocked_gps_inside_radius(client: AsyncClient, staging_fixture: dict):
    data = staging_fixture
    app.dependency_overrides[get_current_user] = lambda: data["teacher_user_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    payload = {
        "latitude": STAGING_SCHOOL_LAT,
        "longitude": STAGING_SCHOOL_LON,
        "accuracy": 5.0,
        "is_mocked": True
    }
    resp = await client.post("/api/v1/staff-attendance/check-in", json=payload, headers=headers)
    assert resp.status_code == status.HTTP_400_BAD_REQUEST
    assert "Mocked GPS location detected" in resp.json()["message"]
    app.dependency_overrides.pop(get_current_user, None)


# ST-04: Missing school latitude
@pytest.mark.anyio
async def test_st04_missing_school_latitude(client: AsyncClient, staging_fixture: dict, db_session: AsyncSession):
    data = staging_fixture
    school = data["school_a"]
    orig_lat = school.latitude
    school.latitude = None
    db_session.add(school)
    await db_session.commit()

    app.dependency_overrides[get_current_user] = lambda: data["teacher_user_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    payload = {
        "latitude": STAGING_SCHOOL_LAT,
        "longitude": STAGING_SCHOOL_LON,
        "accuracy": 8.0,
        "is_mocked": False
    }
    resp = await client.post("/api/v1/staff-attendance/check-in", json=payload, headers=headers)
    assert resp.status_code == status.HTTP_400_BAD_REQUEST
    assert "School geolocation coordinates are not configured" in resp.json()["message"]

    # Restore latitude
    school.latitude = orig_lat
    db_session.add(school)
    await db_session.commit()
    app.dependency_overrides.pop(get_current_user, None)


# ST-05: Missing school longitude
@pytest.mark.anyio
async def test_st05_missing_school_longitude(client: AsyncClient, staging_fixture: dict, db_session: AsyncSession):
    data = staging_fixture
    school = data["school_a"]
    orig_lon = school.longitude
    school.longitude = None
    db_session.add(school)
    await db_session.commit()

    app.dependency_overrides[get_current_user] = lambda: data["teacher_user_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    payload = {
        "latitude": STAGING_SCHOOL_LAT,
        "longitude": STAGING_SCHOOL_LON,
        "accuracy": 8.0,
        "is_mocked": False
    }
    resp = await client.post("/api/v1/staff-attendance/check-in", json=payload, headers=headers)
    assert resp.status_code == status.HTTP_400_BAD_REQUEST
    assert "School geolocation coordinates are not configured" in resp.json()["message"]

    # Restore longitude
    school.longitude = orig_lon
    db_session.add(school)
    await db_session.commit()
    app.dependency_overrides.pop(get_current_user, None)


# ST-06: Invalid or zero radius
@pytest.mark.anyio
async def test_st06_invalid_or_zero_radius(client: AsyncClient, staging_fixture: dict, db_session: AsyncSession):
    data = staging_fixture
    school = data["school_a"]
    orig_rad = school.geofence_radius_meters
    school.geofence_radius_meters = 0
    db_session.add(school)
    await db_session.commit()

    app.dependency_overrides[get_current_user] = lambda: data["teacher_user_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    payload = {
        "latitude": STAGING_SCHOOL_LAT,
        "longitude": STAGING_SCHOOL_LON,
        "accuracy": 8.0,
        "is_mocked": False
    }
    resp = await client.post("/api/v1/staff-attendance/check-in", json=payload, headers=headers)
    assert resp.status_code == status.HTTP_400_BAD_REQUEST
    assert "School geofence radius is not configured" in resp.json()["message"]

    # Restore radius
    school.geofence_radius_meters = orig_rad
    db_session.add(school)
    await db_session.commit()
    app.dependency_overrides.pop(get_current_user, None)


# ST-07: Missing GPS accuracy
@pytest.mark.anyio
async def test_st07_missing_gps_accuracy(client: AsyncClient, staging_fixture: dict):
    data = staging_fixture
    app.dependency_overrides[get_current_user] = lambda: data["teacher_user_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    payload = {
        "latitude": STAGING_SCHOOL_LAT,
        "longitude": STAGING_SCHOOL_LON,
        "is_mocked": False
    }
    resp = await client.post("/api/v1/staff-attendance/check-in", json=payload, headers=headers)
    assert resp.status_code == status.HTTP_400_BAD_REQUEST
    assert "GPS accuracy reading is required" in resp.json()["message"]
    app.dependency_overrides.pop(get_current_user, None)


# ST-08: GPS accuracy above 100 meters
@pytest.mark.anyio
async def test_st08_gps_accuracy_above_100m(client: AsyncClient, staging_fixture: dict):
    data = staging_fixture
    app.dependency_overrides[get_current_user] = lambda: data["teacher_user_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    payload = {
        "latitude": STAGING_SCHOOL_LAT,
        "longitude": STAGING_SCHOOL_LON,
        "accuracy": 105.0,
        "is_mocked": False
    }
    resp = await client.post("/api/v1/staff-attendance/check-in", json=payload, headers=headers)
    assert resp.status_code == status.HTTP_400_BAD_REQUEST
    assert "GPS accuracy is too low" in resp.json()["message"]
    app.dependency_overrides.pop(get_current_user, None)


# ST-09: Boundary inside tolerance
@pytest.mark.anyio
async def test_st09_boundary_inside_tolerance(client: AsyncClient, staging_fixture: dict):
    data = staging_fixture
    app.dependency_overrides[get_current_user] = lambda: data["teacher_user_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    service = StaffAttendanceService(None, None, None)
    offset_lat = STAGING_SCHOOL_LAT + 0.000950
    dist = service.haversine_distance(offset_lat, STAGING_SCHOOL_LON, STAGING_SCHOOL_LAT, STAGING_SCHOOL_LON)
    assert 100.0 < dist <= 110.0  # 105.6m is <= 100m + 10m tolerance

    payload = {
        "latitude": offset_lat,
        "longitude": STAGING_SCHOOL_LON,
        "accuracy": 10.0,
        "is_mocked": False,
        "remarks": "Border check-in within GPS tolerance"
    }
    resp = await client.post("/api/v1/staff-attendance/check-in", json=payload, headers=headers)
    assert resp.status_code == status.HTTP_201_CREATED
    assert resp.json()["data"]["status"] == "CHECKED_IN"
    app.dependency_overrides.pop(get_current_user, None)


# ST-10: Boundary beyond tolerance
@pytest.mark.anyio
async def test_st10_boundary_beyond_tolerance(client: AsyncClient, staging_fixture: dict):
    data = staging_fixture
    app.dependency_overrides[get_current_user] = lambda: data["teacher_user_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    service = StaffAttendanceService(None, None, None)
    offset_lat = STAGING_SCHOOL_LAT + 0.001050
    dist = service.haversine_distance(offset_lat, STAGING_SCHOOL_LON, STAGING_SCHOOL_LAT, STAGING_SCHOOL_LON)
    assert dist > 110.0  # 116.7m is > 110m

    payload = {
        "latitude": offset_lat,
        "longitude": STAGING_SCHOOL_LON,
        "accuracy": 10.0,
        "is_mocked": False
    }
    resp = await client.post("/api/v1/staff-attendance/check-in", json=payload, headers=headers)
    assert resp.status_code == status.HTTP_400_BAD_REQUEST
    assert "outside the permitted school geofence" in resp.json()["message"]
    app.dependency_overrides.pop(get_current_user, None)


# ST-11: Authorized administrative exemption
@pytest.mark.anyio
async def test_st11_authorized_administrative_exemption(client: AsyncClient, staging_fixture: dict, db_session: AsyncSession):
    data = staging_fixture
    school = data["school_a"]
    admin_id = data["admin_id"]

    # Disable geofence policy by admin
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
        "latitude": STAGING_SCHOOL_LAT + 0.018000,  # 2 km away
        "longitude": STAGING_SCHOOL_LON,
        "accuracy": 8.0,
        "is_mocked": False,
        "remarks": "Authorized off-site work"
    }
    resp = await client.post("/api/v1/staff-attendance/check-in", json=payload, headers=headers)
    assert resp.status_code == status.HTTP_201_CREATED
    rec = resp.json()["data"]
    assert rec["status"] == "CHECKED_IN"
    assert rec["check_in_distance_meters"] > 1800.0
    assert "[GEOFENCE_EXEMPTION:" in rec["remarks"]
    assert str(admin_id) in rec["remarks"]

    # Restore enabled
    school.settings["geofence"]["enabled"] = True
    db_session.add(school)
    await db_session.commit()
    app.dependency_overrides.pop(get_current_user, None)


# ST-12: Cross-tenant geofence access
@pytest.mark.anyio
async def test_st12_cross_tenant_geofence_access(client: AsyncClient, staging_fixture: dict):
    data = staging_fixture
    # User belongs to Tenant A
    app.dependency_overrides[get_current_user] = lambda: data["teacher_user_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    school_b_id = str(data["school_b"].id)  # School belongs to Tenant B

    resp = await client.get(f"/api/v1/schools/{school_b_id}/geofence", headers=headers)
    assert resp.status_code == status.HTTP_404_NOT_FOUND
    app.dependency_overrides.pop(get_current_user, None)
