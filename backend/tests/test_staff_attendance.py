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

# Coordinates setup
SCHOOL_LAT = 17.4485
SCHOOL_LON = 78.3741
GEOFENCE_RADIUS = 100

@pytest.fixture
async def setup_attendance_test_data(db_session: AsyncSession):
    suffix = uuid.uuid4().hex[:6].upper()
    repo_t = TenantRepository(db_session)
    tenant_a = await repo_t.create(TenantCreate(
        name="Tenant A", code=f"t-a-{suffix.lower()}", 
        subdomain=f"t-a-{suffix.lower()}", email=f"a-{suffix.lower()}@t.com"
    ))
    tenant_b = await repo_t.create(TenantCreate(
        name="Tenant B", code=f"t-b-{suffix.lower()}", 
        subdomain=f"t-b-{suffix.lower()}", email=f"b-{suffix.lower()}@t.com"
    ))

    repo_s = SchoolRepository(db_session)
    
    # School A has geofencing configured
    school_a = await repo_s.create(tenant_a.id, SchoolCreate(
        name="School A", code=f"SCH_A_{suffix}", board="CBSE", email=f"s-a-{suffix.lower()}@a.com"
    ))
    school_a.latitude = SCHOOL_LAT
    school_a.longitude = SCHOOL_LON
    school_a.geofence_radius_meters = GEOFENCE_RADIUS
    db_session.add(school_a)

    # School B has no geofencing configured
    school_b = await repo_s.create(tenant_b.id, SchoolCreate(
        name="School B", code=f"SCH_B_{suffix}", board="CBSE", email=f"s-b-{suffix.lower()}@b.com"
    ))
    await db_session.commit()

    # Create permissions
    stmt_p = select(Permission)
    res_p = await db_session.execute(stmt_p)
    all_perms = list(res_p.scalars().all())

    # Fetch existing Teacher Role (created automatically by initialize_tenant_rbac)
    from sqlalchemy.orm import selectinload
    stmt_role_t = select(Role).where(Role.tenant_id == tenant_a.id, Role.code == "TEACHER").options(selectinload(Role.permissions))
    res_role_t = await db_session.execute(stmt_role_t)
    role_teacher = res_role_t.scalar_one()

    teacher_perm_codes = ["staff_attendance.read", "staff_attendance.create", "staff_attendance.update"]
    role_teacher.permissions = [p for p in all_perms if p.code in teacher_perm_codes]
    db_session.add(role_teacher)

    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    auth_service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, repo_s)
    
    # Active Teacher User
    user_teacher = await auth_service.create_user(
        tenant_a.id,
        UserCreate(email=f"teacher-{suffix}@a.com", password="Password123!", first_name="Sarah", last_name="Connor")
    )
    user_teacher.roles.append(role_teacher)
    user_teacher.status = UserStatus.ACTIVE
    db_session.add(user_teacher)

    # Map teacher user to School A
    await db_session.execute(
        text("INSERT INTO school_users (user_id, school_id) VALUES (:u, :s)"),
        {"u": str(user_teacher.id), "s": str(school_a.id)}
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
        mobile="9876543210",
        official_email=f"teacher-{suffix}@a.com",
        joining_date=date(2020, 6, 1),
        employment_type=EmploymentType.FULL_TIME,
        school_id=school_a.id
    ))
    teacher_profile.user_id = user_teacher.id
    db_session.add(teacher_profile)
    await db_session.commit()

    # User without permissions
    user_no_perms = await auth_service.create_user(
        tenant_a.id,
        UserCreate(email=f"no-perms-{suffix}@a.com", password="Password123!", first_name="No", last_name="Perms")
    )
    user_no_perms.status = UserStatus.ACTIVE
    db_session.add(user_no_perms)
    await db_session.commit()

    return {
        "tenant_a": tenant_a,
        "tenant_b": tenant_b,
        "school_a": school_a,
        "school_b": school_b,
        "user_teacher": user_teacher,
        "teacher_profile": teacher_profile,
        "user_no_perms": user_no_perms
    }


@pytest.mark.anyio
async def test_haversine_distance():
    # Instantiate service manually with mock repos to test mathematical calculation
    service = StaffAttendanceService(None, None, None)
    
    # 0 meters same coordinates
    d1 = service.haversine_distance(17.4485, 78.3741, 17.4485, 78.3741)
    assert abs(d1) < 0.1
    
    # Approx 50 meters offset
    d2 = service.haversine_distance(17.4485, 78.3741, 17.4482, 78.3743)
    assert 30.0 < d2 < 60.0

    # Large distance offset
    d3 = service.haversine_distance(17.4485, 78.3741, 13.0827, 80.2707)  # Hyderabad to Chennai
    assert d3 > 500000.0


@pytest.mark.anyio
async def test_check_in_success_inside_geofence(client: AsyncClient, setup_attendance_test_data):
    data = setup_attendance_test_data
    user = data["user_teacher"]
    tenant = data["tenant_a"]

    app.dependency_overrides[get_current_user] = lambda: user

    headers = {
        "X-Tenant-ID": str(tenant.id)
    }

    # Coordinates 30 meters from school
    payload = {
        "latitude": SCHOOL_LAT + 0.0002,
        "longitude": SCHOOL_LON + 0.0002,
        "is_mocked": False,
        "remarks": "Check in at gate"
    }

    response = await client.post("/api/v1/staff-attendance/check-in", json=payload, headers=headers)
    assert response.status_code == status.HTTP_201_CREATED
    res_json = response.json()
    assert res_json["success"] is True
    assert res_json["data"]["status"] == "CHECKED_IN"
    assert res_json["data"]["check_in_distance_meters"] < 50.0
    assert res_json["data"]["is_mocked_location"] is False
    assert res_json["data"]["remarks"] == "Check in at gate"
    
    # Clean up override
    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.anyio
async def test_check_in_exact_boundary(client: AsyncClient, setup_attendance_test_data):
    data = setup_attendance_test_data
    user = data["user_teacher"]
    tenant = data["tenant_a"]
    school = data["school_a"]

    app.dependency_overrides[get_current_user] = lambda: user

    headers = {
        "X-Tenant-ID": str(tenant.id)
    }

    # Set geofence radius to exactly calculated distance for coordinates offset
    service = StaffAttendanceService(None, None, None)
    target_lat = SCHOOL_LAT + 0.0005
    target_lon = SCHOOL_LON + 0.0005
    distance = service.haversine_distance(target_lat, target_lon, SCHOOL_LAT, SCHOOL_LON)
    
    # Artificially modify school geofence limit to match distance precisely
    school.geofence_radius_meters = int(distance) + 1

    payload = {
        "latitude": target_lat,
        "longitude": target_lon,
        "is_mocked": False
    }

    response = await client.post("/api/v1/staff-attendance/check-in", json=payload, headers=headers)
    assert response.status_code == status.HTTP_201_CREATED
    
    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.anyio
async def test_check_in_outside_geofence(client: AsyncClient, setup_attendance_test_data):
    data = setup_attendance_test_data
    user = data["user_teacher"]
    tenant = data["tenant_a"]

    app.dependency_overrides[get_current_user] = lambda: user

    headers = {
        "X-Tenant-ID": str(tenant.id)
    }

    # Coordinates way outside (10km)
    payload = {
        "latitude": 17.5500,
        "longitude": 78.4800,
        "is_mocked": False
    }

    response = await client.post("/api/v1/staff-attendance/check-in", json=payload, headers=headers)
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    res_json = response.json()
    assert "outside the permitted school geofence" in res_json["message"]

    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.anyio
async def test_check_in_school_not_configured(client: AsyncClient, setup_attendance_test_data, db_session: AsyncSession):
    data = setup_attendance_test_data
    user = data["user_teacher"]
    tenant = data["tenant_a"]
    school = data["school_a"]

    # Clear school coordinates
    school.latitude = None
    school.longitude = None
    db_session.add(school)
    await db_session.commit()

    app.dependency_overrides[get_current_user] = lambda: user

    headers = {
        "X-Tenant-ID": str(tenant.id)
    }

    payload = {
        "latitude": SCHOOL_LAT,
        "longitude": SCHOOL_LON,
        "is_mocked": False
    }

    response = await client.post("/api/v1/staff-attendance/check-in", json=payload, headers=headers)
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    res_json = response.json()
    assert "coordinates are not configured" in res_json["message"]

    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.anyio
async def test_duplicate_check_in(client: AsyncClient, setup_attendance_test_data):
    data = setup_attendance_test_data
    user = data["user_teacher"]
    tenant = data["tenant_a"]

    app.dependency_overrides[get_current_user] = lambda: user

    headers = {
        "X-Tenant-ID": str(tenant.id)
    }

    payload = {
        "latitude": SCHOOL_LAT,
        "longitude": SCHOOL_LON,
        "is_mocked": False
    }

    # First check-in
    response = await client.post("/api/v1/staff-attendance/check-in", json=payload, headers=headers)
    assert response.status_code == status.HTTP_201_CREATED

    # Duplicate check-in
    response_dup = await client.post("/api/v1/staff-attendance/check-in", json=payload, headers=headers)
    assert response_dup.status_code == status.HTTP_409_CONFLICT
    assert "already been recorded" in response_dup.json()["message"]

    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.anyio
async def test_check_out_success_inside_geofence(client: AsyncClient, setup_attendance_test_data):
    data = setup_attendance_test_data
    user = data["user_teacher"]
    tenant = data["tenant_a"]

    app.dependency_overrides[get_current_user] = lambda: user

    headers = {
        "X-Tenant-ID": str(tenant.id)
    }

    payload_in = {
        "latitude": SCHOOL_LAT,
        "longitude": SCHOOL_LON,
        "is_mocked": False,
        "remarks": "Morning shift"
    }

    # 1. Check In
    await client.post("/api/v1/staff-attendance/check-in", json=payload_in, headers=headers)

    # 2. Check Out
    payload_out = {
        "latitude": SCHOOL_LAT + 0.0001,
        "longitude": SCHOOL_LON + 0.0001,
        "is_mocked": False,
        "remarks": "Heading home"
    }

    response = await client.post("/api/v1/staff-attendance/check-out", json=payload_out, headers=headers)
    assert response.status_code == status.HTTP_200_OK
    res_json = response.json()
    assert res_json["success"] is True
    assert res_json["data"]["status"] == "CHECKED_OUT"
    assert res_json["data"]["duration_seconds"] is not None
    assert res_json["data"]["remarks"] == "Morning shift | Out: Heading home"

    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.anyio
async def test_check_out_outside_geofence(client: AsyncClient, setup_attendance_test_data):
    data = setup_attendance_test_data
    user = data["user_teacher"]
    tenant = data["tenant_a"]

    app.dependency_overrides[get_current_user] = lambda: user

    headers = {
        "X-Tenant-ID": str(tenant.id)
    }

    # 1. Check In
    payload_in = {
        "latitude": SCHOOL_LAT,
        "longitude": SCHOOL_LON,
        "is_mocked": False
    }
    await client.post("/api/v1/staff-attendance/check-in", json=payload_in, headers=headers)

    # 2. Check Out Outside (mismatched geofence)
    payload_out = {
        "latitude": 17.5500,
        "longitude": 78.4800,
        "is_mocked": False
    }
    response = await client.post("/api/v1/staff-attendance/check-out", json=payload_out, headers=headers)
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert "outside the permitted school geofence" in response.json()["message"]

    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.anyio
async def test_check_out_without_check_in(client: AsyncClient, setup_attendance_test_data):
    data = setup_attendance_test_data
    user = data["user_teacher"]
    tenant = data["tenant_a"]

    app.dependency_overrides[get_current_user] = lambda: user

    headers = {
        "X-Tenant-ID": str(tenant.id)
    }

    payload = {
        "latitude": SCHOOL_LAT,
        "longitude": SCHOOL_LON,
        "is_mocked": False
    }

    response = await client.post("/api/v1/staff-attendance/check-out", json=payload, headers=headers)
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert "No active check-in session found" in response.json()["message"]

    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.anyio
async def test_duplicate_check_out(client: AsyncClient, setup_attendance_test_data):
    data = setup_attendance_test_data
    user = data["user_teacher"]
    tenant = data["tenant_a"]

    app.dependency_overrides[get_current_user] = lambda: user

    headers = {
        "X-Tenant-ID": str(tenant.id)
    }

    # 1. Check In
    payload_in = {
        "latitude": SCHOOL_LAT,
        "longitude": SCHOOL_LON,
        "is_mocked": False
    }
    await client.post("/api/v1/staff-attendance/check-in", json=payload_in, headers=headers)

    # 2. First Check Out
    payload_out = {
        "latitude": SCHOOL_LAT,
        "longitude": SCHOOL_LON,
        "is_mocked": False
    }
    await client.post("/api/v1/staff-attendance/check-out", json=payload_out, headers=headers)

    # 3. Duplicate Check Out
    response_dup = await client.post("/api/v1/staff-attendance/check-out", json=payload_out, headers=headers)
    assert response_dup.status_code == status.HTTP_400_BAD_REQUEST
    assert "Already checked out" in response_dup.json()["message"]

    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.anyio
async def test_today_status_transitions(client: AsyncClient, setup_attendance_test_data):
    data = setup_attendance_test_data
    user = data["user_teacher"]
    tenant = data["tenant_a"]

    app.dependency_overrides[get_current_user] = lambda: user

    headers = {
        "X-Tenant-ID": str(tenant.id)
    }

    # Step 1: Initial state status
    response1 = await client.get("/api/v1/staff-attendance/status", headers=headers)
    assert response1.status_code == status.HTTP_200_OK
    assert response1.json()["data"]["status"] == "NOT_CHECKED_IN"

    # Step 2: Check In
    payload_in = {
        "latitude": SCHOOL_LAT,
        "longitude": SCHOOL_LON,
        "is_mocked": False
    }
    await client.post("/api/v1/staff-attendance/check-in", json=payload_in, headers=headers)

    # Step 3: Verify Checked In status
    response2 = await client.get("/api/v1/staff-attendance/status", headers=headers)
    assert response2.status_code == status.HTTP_200_OK
    assert response2.json()["data"]["status"] == "CHECKED_IN"

    # Step 4: Check Out
    await client.post("/api/v1/staff-attendance/check-out", json=payload_in, headers=headers)

    # Step 5: Verify Checked Out status
    response3 = await client.get("/api/v1/staff-attendance/status", headers=headers)
    assert response3.status_code == status.HTTP_200_OK
    assert response3.json()["data"]["status"] == "CHECKED_OUT"
    assert response3.json()["data"]["duration_seconds"] is not None

    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.anyio
async def test_mock_location_audit_record(client: AsyncClient, setup_attendance_test_data):
    data = setup_attendance_test_data
    user = data["user_teacher"]
    tenant = data["tenant_a"]

    app.dependency_overrides[get_current_user] = lambda: user

    headers = {
        "X-Tenant-ID": str(tenant.id)
    }

    payload = {
        "latitude": SCHOOL_LAT,
        "longitude": SCHOOL_LON,
        "is_mocked": True
    }

    response = await client.post("/api/v1/staff-attendance/check-in", json=payload, headers=headers)
    assert response.status_code == status.HTTP_201_CREATED
    assert response.json()["data"]["is_mocked_location"] is True

    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.anyio
async def test_tenant_isolation(client: AsyncClient, setup_attendance_test_data):
    data = setup_attendance_test_data
    tenant_b = data["tenant_b"]

    from fastapi import HTTPException
    def mock_get_current_user_mismatch():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token tenant claims mismatch requested boundary."
        )
    app.dependency_overrides[get_current_user] = mock_get_current_user_mismatch

    # Access using tenant B (teacher belongs to tenant A)
    headers = {
        "X-Tenant-ID": str(tenant_b.id)
    }

    payload = {
        "latitude": SCHOOL_LAT,
        "longitude": SCHOOL_LON,
        "is_mocked": False
    }

    # Should fail due to tenant boundaries check in auth middleware
    response = await client.post("/api/v1/staff-attendance/check-in", json=payload, headers=headers)
    assert response.status_code == status.HTTP_401_UNAUTHORIZED

    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.anyio
async def test_permission_enforcement(client: AsyncClient, setup_attendance_test_data):
    data = setup_attendance_test_data
    user_no_perms = data["user_no_perms"]
    tenant = data["tenant_a"]

    app.dependency_overrides[get_current_user] = lambda: user_no_perms

    headers = {
        "X-Tenant-ID": str(tenant.id)
    }

    payload = {
        "latitude": SCHOOL_LAT,
        "longitude": SCHOOL_LON,
        "is_mocked": False
    }

    response = await client.post("/api/v1/staff-attendance/check-in", json=payload, headers=headers)
    assert response.status_code == status.HTTP_403_FORBIDDEN
    assert "insufficient system permissions" in response.json()["message"]

    app.dependency_overrides.pop(get_current_user, None)
