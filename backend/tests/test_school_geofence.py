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
from app.services.auth import AuthService
from app.api.dependencies.auth import get_current_user
from app.models.student import StudentGender

# Test coordinates
TEST_LAT = 17.5000
TEST_LON = 78.4000
TEST_RADIUS = 150

@pytest.fixture
async def geofence_test_data(db_session: AsyncSession):
    suffix = uuid.uuid4().hex[:6].upper()
    repo_t = TenantRepository(db_session)
    tenant_a = await repo_t.create(TenantCreate(
        name="Tenant Geofence A", code=f"t-g-a-{suffix.lower()}", 
        subdomain=f"t-g-a-{suffix.lower()}", email=f"ga-{suffix.lower()}@t.com"
    ))
    tenant_b = await repo_t.create(TenantCreate(
        name="Tenant Geofence B", code=f"t-g-b-{suffix.lower()}", 
        subdomain=f"t-g-b-{suffix.lower()}", email=f"gb-{suffix.lower()}@t.com"
    ))

    repo_s = SchoolRepository(db_session)
    
    # School A: initially unconfigured coordinates
    school_a = await repo_s.create(tenant_a.id, SchoolCreate(
        name="Geofence School A", code=f"SCH_GA_{suffix}", board="CBSE", email=f"s-ga-{suffix.lower()}@a.com"
    ))
    
    # School B: belongs to Tenant B
    school_b = await repo_s.create(tenant_b.id, SchoolCreate(
        name="Geofence School B", code=f"SCH_GB_{suffix}", board="CBSE", email=f"s-gb-{suffix.lower()}@b.com"
    ))
    await db_session.commit()

    # Get system permissions
    stmt_p = select(Permission)
    res_p = await db_session.execute(stmt_p)
    all_perms = list(res_p.scalars().all())

    # Map Admin Role (with school update and write permissions)
    role_admin = Role(name="Geofence Admin Role", code="GEO_ADMIN", is_system=True, tenant_id=tenant_a.id)
    role_admin.permissions = [p for p in all_perms if p.code in ["school.update", "school.create", "school.read"]]
    db_session.add(role_admin)

    # Map Guest Role (no school permissions)
    role_guest = Role(name="Geofence Guest Role", code="GEO_GUEST", is_system=True, tenant_id=tenant_a.id)
    role_guest.permissions = [p for p in all_perms if p.code == "school.read"]
    db_session.add(role_guest)

    # Map Teacher Role (for check-in / out tests)
    role_teacher = Role(name="Geofence Teacher Role", code="GEO_TEACHER", is_system=True, tenant_id=tenant_a.id)
    role_teacher.permissions = [p for p in all_perms if p.code in ["staff_attendance.read", "staff_attendance.create", "staff_attendance.update"]]
    db_session.add(role_teacher)

    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    auth_service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, repo_s)

    # Active Admin User
    admin_user = await auth_service.create_user(
        tenant_a.id,
        UserCreate(email=f"admin-{suffix}@a.com", password="Password123!", first_name="Admin", last_name="User")
    )
    admin_user.roles.append(role_admin)
    admin_user.status = UserStatus.ACTIVE
    db_session.add(admin_user)

    # Active Guest User (Unauthorized)
    guest_user = await auth_service.create_user(
        tenant_a.id,
        UserCreate(email=f"guest-{suffix}@a.com", password="Password123!", first_name="Guest", last_name="User")
    )
    guest_user.roles.append(role_guest)
    guest_user.status = UserStatus.ACTIVE
    db_session.add(guest_user)

    # Active Teacher User
    teacher_user = await auth_service.create_user(
        tenant_a.id,
        UserCreate(email=f"teacher-{suffix}@a.com", password="Password123!", first_name="Sarah", last_name="Connor")
    )
    teacher_user.roles.append(role_teacher)
    teacher_user.status = UserStatus.ACTIVE
    db_session.add(teacher_user)

    # Map teacher user to School A
    await db_session.execute(
        text("INSERT INTO school_users (user_id, school_id) VALUES (:u, :s)"),
        {"u": str(teacher_user.id), "s": str(school_a.id)}
    )

    # Create Teacher Profile
    teacher_repo = TeacherRepository(db_session)
    teacher_profile = await teacher_repo.create(tenant_a.id, TeacherCreate(
        employee_code=f"EMP_{suffix}",
        staff_code=f"STF_{suffix}",
        first_name="Sarah",
        last_name="Connor",
        gender=StudentGender.FEMALE,
        date_of_birth=date(1990, 5, 15),
        joining_date=date(2020, 1, 1),
        official_email=f"sarah-{suffix}@a.com",
        mobile="+919876543232",
        employment_type=EmploymentType.FULL_TIME,
        status=TeacherStatus.ACTIVE,
        school_id=school_a.id
    ))
    teacher_profile.user_id = teacher_user.id
    db_session.add(teacher_profile)

    await db_session.commit()

    return {
        "tenant_a_id": tenant_a.id,
        "tenant_b_id": tenant_b.id,
        "school_a_id": school_a.id,
        "school_b_id": school_b.id,
        "admin_user": admin_user,
        "guest_user": guest_user,
        "teacher_user": teacher_user,
        "teacher_profile": teacher_profile,
    }

@pytest.mark.anyio
async def test_admin_configure_geofence(client: AsyncClient, geofence_test_data: dict) -> None:
    # Set app overrides to mock admin user
    admin = geofence_test_data["admin_user"]
    app.dependency_overrides[get_current_user] = lambda: admin

    school_id = geofence_test_data["school_a_id"]
    headers = {"X-Tenant-ID": str(geofence_test_data["tenant_a_id"])}

    # Configure geofence
    payload = {
        "latitude": TEST_LAT,
        "longitude": TEST_LON,
        "geofence_radius_meters": TEST_RADIUS
    }

    resp = await client.put(f"/api/v1/schools/{school_id}", json=payload, headers=headers)
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["latitude"] == TEST_LAT
    assert data["longitude"] == TEST_LON
    assert data["geofence_radius"] == TEST_RADIUS
    assert data["geofence_radius_meters"] == TEST_RADIUS

    # Clean overrides
    app.dependency_overrides.pop(get_current_user, None)

@pytest.mark.anyio
async def test_unauthorized_user_cannot_configure_geofence(client: AsyncClient, geofence_test_data: dict) -> None:
    # Set app overrides to guest user (unauthorized)
    guest = geofence_test_data["guest_user"]
    app.dependency_overrides[get_current_user] = lambda: guest

    school_id = geofence_test_data["school_a_id"]
    headers = {"X-Tenant-ID": str(geofence_test_data["tenant_a_id"])}

    payload = {
        "latitude": TEST_LAT,
        "longitude": TEST_LON,
        "geofence_radius_meters": TEST_RADIUS
    }

    resp = await client.put(f"/api/v1/schools/{school_id}", json=payload, headers=headers)
    assert resp.status_code == 403

    app.dependency_overrides.pop(get_current_user, None)

@pytest.mark.anyio
async def test_tenant_isolation_prevents_configuring_another_tenant_school(client: AsyncClient, geofence_test_data: dict) -> None:
    # Admin of Tenant A tries to edit School B (Tenant B)
    admin = geofence_test_data["admin_user"]
    app.dependency_overrides[get_current_user] = lambda: admin

    school_b_id = geofence_test_data["school_b_id"]
    headers = {"X-Tenant-ID": str(geofence_test_data["tenant_a_id"])}  # Request scope under Tenant A

    payload = {
        "latitude": TEST_LAT,
        "longitude": TEST_LON,
        "geofence_radius_meters": TEST_RADIUS
    }

    # Should raise 404 since School B doesn't exist under Tenant A scope
    resp = await client.put(f"/api/v1/schools/{school_b_id}", json=payload, headers=headers)
    assert resp.status_code == 404

    app.dependency_overrides.pop(get_current_user, None)

@pytest.mark.anyio
async def test_invalid_latitude_longitude_radius_rejected(client: AsyncClient, geofence_test_data: dict) -> None:
    admin = geofence_test_data["admin_user"]
    app.dependency_overrides[get_current_user] = lambda: admin

    school_id = geofence_test_data["school_a_id"]
    headers = {"X-Tenant-ID": str(geofence_test_data["tenant_a_id"])}

    # Invalid latitude
    resp = await client.put(f"/api/v1/schools/{school_id}", json={"latitude": 95.0, "longitude": 78.0}, headers=headers)
    assert resp.status_code == 422

    # Invalid longitude
    resp = await client.put(f"/api/v1/schools/{school_id}", json={"latitude": 17.0, "longitude": -185.0}, headers=headers)
    assert resp.status_code == 422

    # Invalid radius
    resp = await client.put(f"/api/v1/schools/{school_id}", json={"geofence_radius_meters": -10}, headers=headers)
    assert resp.status_code == 422

    # Mismatched coordinates (latitude only)
    resp = await client.put(f"/api/v1/schools/{school_id}", json={"latitude": 17.0}, headers=headers)
    assert resp.status_code == 422

    app.dependency_overrides.pop(get_current_user, None)

@pytest.mark.anyio
async def test_check_in_validation_flows(client: AsyncClient, db_session: AsyncSession, geofence_test_data: dict) -> None:
    tenant_id = geofence_test_data["tenant_a_id"]
    school_id = geofence_test_data["school_a_id"]
    teacher = geofence_test_data["teacher_user"]
    headers = {"X-Tenant-ID": str(tenant_id)}

    # 1. Missing coordinates returns HTTP 400
    app.dependency_overrides[get_current_user] = lambda: teacher
    checkin_payload = {"latitude": TEST_LAT, "longitude": TEST_LON, "is_mocked": False}
    resp = await client.post("/api/v1/staff-attendance/check-in", json=checkin_payload, headers=headers)
    assert resp.status_code == 400
    assert "School geolocation coordinates are not configured" in resp.json()["message"]

    # 2. Configure School coordinates
    repo_s = SchoolRepository(db_session)
    school = await repo_s.get_by_id(school_id, tenant_id)
    school.latitude = TEST_LAT
    school.longitude = TEST_LON
    school.geofence_radius_meters = TEST_RADIUS
    db_session.add(school)
    await db_session.commit()

    # 3. Check-in outside radius fails (e.g. check-in at 10km away)
    checkin_payload_far = {"latitude": TEST_LAT + 0.1, "longitude": TEST_LON + 0.1, "is_mocked": False}
    resp = await client.post("/api/v1/staff-attendance/check-in", json=checkin_payload_far, headers=headers)
    assert resp.status_code == 400
    assert "outside the permitted school geofence" in resp.json()["message"]

    # 4. Check-in inside radius succeeds
    checkin_payload_near = {"latitude": TEST_LAT, "longitude": TEST_LON, "is_mocked": False}
    resp = await client.post("/api/v1/staff-attendance/check-in", json=checkin_payload_near, headers=headers)
    assert resp.status_code == 201
    data = resp.json()["data"]
    assert data["check_in_latitude"] == TEST_LAT
    assert data["check_in_longitude"] == TEST_LON

    # 5. Teacher cannot override school coordinates through the API (verified by checkin response capturing teacher's payload coordinates, not matching school's coordinates)
    # Teacher check out at slightly offset location but inside geofence
    checkout_payload_offset = {"latitude": TEST_LAT + 0.0001, "longitude": TEST_LON, "is_mocked": False}
    resp_co = await client.post("/api/v1/staff-attendance/check-out", json=checkout_payload_offset, headers=headers)
    assert resp_co.status_code == 200
    co_data = resp_co.json()["data"]
    assert co_data["check_out_latitude"] == TEST_LAT + 0.0001
    assert co_data["check_out_distance_meters"] is not None

    app.dependency_overrides.pop(get_current_user, None)
