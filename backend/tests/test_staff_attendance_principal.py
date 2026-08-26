import uuid
import pytest
from datetime import date, datetime, timezone, timedelta
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
from app.models.staff_attendance import StaffAttendance
from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate, SchoolUpdate
from app.schemas.teacher import TeacherCreate
from app.schemas.auth import UserCreate
from app.services.staff_attendance import StaffAttendanceService
from app.services.auth import AuthService
from app.api.dependencies.auth import get_current_user
from app.models.student import StudentGender

@pytest.fixture
async def setup_principal_attendance_data(db_session: AsyncSession):
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
    school_a = await repo_s.create(tenant_a.id, SchoolCreate(
        name="School A", code=f"SCH_A_{suffix}", board="CBSE", email=f"s-a-{suffix.lower()}@a.com"
    ))
    school_a.latitude = 17.4485
    school_a.longitude = 78.3741
    school_a.geofence_radius_meters = 100
    db_session.add(school_a)

    school_b = await repo_s.create(tenant_a.id, SchoolCreate(
        name="School B", code=f"SCH_B_{suffix}", board="CBSE", email=f"s-b-{suffix.lower()}@b.com"
    ))
    db_session.add(school_b)

    await db_session.commit()

    # Create permissions
    stmt_p = select(Permission)
    res_p = await db_session.execute(stmt_p)
    all_perms = list(res_p.scalars().all())

    # Fetch existing Teacher, Principal, & Admin Roles (created automatically by initialize_tenant_rbac)
    from sqlalchemy.orm import selectinload
    stmt_role_t = select(Role).where(Role.tenant_id == tenant_a.id, Role.code == "TEACHER").options(selectinload(Role.permissions))
    res_role_t = await db_session.execute(stmt_role_t)
    role_teacher = res_role_t.scalar_one()

    stmt_role_p = select(Role).where(Role.tenant_id == tenant_a.id, Role.code == "PRINCIPAL").options(selectinload(Role.permissions))
    res_role_p = await db_session.execute(stmt_role_p)
    role_principal = res_role_p.scalar_one()

    stmt_role_ad = select(Role).where(Role.tenant_id == tenant_a.id, Role.code == "ADMIN").options(selectinload(Role.permissions))
    res_role_ad = await db_session.execute(stmt_role_ad)
    role_admin = res_role_ad.scalar_one()

    role_teacher.permissions = [p for p in all_perms if p.code in ["staff_attendance.read", "staff_attendance.create", "staff_attendance.update"]]
    db_session.add(role_teacher)

    role_principal.permissions = [p for p in all_perms if p.code in ["staff_attendance.read", "staff_attendance.admin", "school.update"]]
    db_session.add(role_principal)

    role_admin.permissions = [p for p in all_perms if p.code in ["staff_attendance.read", "staff_attendance.admin", "school.update"]]
    db_session.add(role_admin)

    await db_session.commit()

    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    auth_service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, repo_s)

    # 1. Teacher User (School A)
    user_teacher = await auth_service.create_user(
        tenant_a.id, UserCreate(email=f"teacher-{suffix}@a.com", password="Password123!", first_name="Sarah", last_name="Connor")
    )
    user_teacher.roles.append(role_teacher)
    user_teacher.status = UserStatus.ACTIVE
    db_session.add(user_teacher)

    # 2. Principal User (School A)
    user_principal = await auth_service.create_user(
        tenant_a.id, UserCreate(email=f"principal-{suffix}@a.com", password="Password123!", first_name="James", last_name="Cameron")
    )
    user_principal.roles.append(role_principal)
    user_principal.status = UserStatus.ACTIVE
    db_session.add(user_principal)

    # 3. Admin User (School A)
    user_admin = await auth_service.create_user(
        tenant_a.id, UserCreate(email=f"admin-{suffix}@a.com", password="Password123!", first_name="Admin", last_name="User")
    )
    user_admin.roles.append(role_admin)
    user_admin.status = UserStatus.ACTIVE
    db_session.add(user_admin)

    # 4. Cross School User (Principal for School B only)
    user_cross_principal = await auth_service.create_user(
        tenant_a.id, UserCreate(email=f"cross-{suffix}@a.com", password="Password123!", first_name="Cross", last_name="Principal")
    )
    user_cross_principal.roles.append(role_principal)
    user_cross_principal.status = UserStatus.ACTIVE
    db_session.add(user_cross_principal)

    await db_session.commit()

    # School mappings
    await db_session.execute(text("INSERT INTO school_users (user_id, school_id) VALUES (:u, :s)"), {"u": str(user_teacher.id), "s": str(school_a.id)})
    await db_session.execute(text("INSERT INTO school_users (user_id, school_id) VALUES (:u, :s)"), {"u": str(user_principal.id), "s": str(school_a.id)})
    await db_session.execute(text("INSERT INTO school_users (user_id, school_id) VALUES (:u, :s)"), {"u": str(user_admin.id), "s": str(school_a.id)})
    await db_session.execute(text("INSERT INTO school_users (user_id, school_id) VALUES (:u, :s)"), {"u": str(user_cross_principal.id), "s": str(school_b.id)})

    # Teacher Profile (School A)
    teacher_repo = TeacherRepository(db_session)
    teacher_profile = await teacher_repo.create(tenant_a.id, TeacherCreate(
        employee_code=f"EMP_{suffix}", staff_code=f"STF_{suffix}",
        first_name="Sarah", last_name="Connor", gender=StudentGender.FEMALE,
        date_of_birth=date(1990, 5, 15), mobile="9876543210",
        official_email=f"teacher-{suffix}@a.com", joining_date=date(2020, 6, 1),
        employment_type=EmploymentType.FULL_TIME, school_id=school_a.id
    ))
    teacher_profile.user_id = user_teacher.id
    db_session.add(teacher_profile)
    await db_session.flush()
    await db_session.refresh(teacher_profile)

    # Insert historical attendance records
    att1 = StaffAttendance(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        teacher_id=teacher_profile.id,
        attendance_date=date.today() - timedelta(days=1),
        check_in_time=datetime.now(timezone.utc) - timedelta(days=1, hours=4),
        check_in_latitude=17.4486,
        check_in_longitude=78.3742,
        check_in_distance_meters=15.0,
        check_out_time=datetime.now(timezone.utc) - timedelta(days=1),
        check_out_latitude=17.4485,
        check_out_longitude=78.3741,
        check_out_distance_meters=5.0,
        is_mocked_location=False
    )
    db_session.add(att1)

    att2 = StaffAttendance(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        teacher_id=teacher_profile.id,
        attendance_date=date.today() - timedelta(days=2),
        check_in_time=datetime.now(timezone.utc) - timedelta(days=2, hours=4),
        check_in_latitude=17.4480,
        check_in_longitude=78.3740,
        check_in_distance_meters=60.0,
        is_mocked_location=True
    )
    db_session.add(att2)

    await db_session.commit()

    return {
        "tenant_a": tenant_a,
        "tenant_b": tenant_b,
        "school_a": school_a,
        "school_b": school_b,
        "user_teacher": user_teacher,
        "user_principal": user_principal,
        "user_admin": user_admin,
        "user_cross": user_cross_principal,
        "teacher_profile": teacher_profile,
        "att1": att1,
        "att2": att2
    }


@pytest.mark.anyio
async def test_principal_can_retrieve_teacher_attendance_history(client: AsyncClient, setup_principal_attendance_data):
    data = setup_principal_attendance_data
    app.dependency_overrides[get_current_user] = lambda: data["user_principal"]

    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    t_id = data["teacher_profile"].id

    response = await client.get(f"/api/v1/staff-attendance/teacher/{t_id}/history", headers=headers)
    assert response.status_code == status.HTTP_200_OK
    res_json = response.json()
    assert res_json["success"] is True
    assert len(res_json["data"]) == 2
    
    # Assert coordinates, distances and mock flag are mapped correctly
    records = res_json["data"]
    assert records[0]["check_in_latitude"] == 17.4486
    assert records[0]["check_in_longitude"] == 78.3742
    assert records[0]["check_in_distance_meters"] == 15.0
    assert records[0]["is_mocked_location"] is False

    assert records[1]["check_in_latitude"] == 17.4480
    assert records[1]["check_in_longitude"] == 78.3740
    assert records[1]["check_in_distance_meters"] == 60.0
    assert records[1]["is_mocked_location"] is True


@pytest.mark.anyio
async def test_admin_can_retrieve_teacher_attendance_history(client: AsyncClient, setup_principal_attendance_data):
    data = setup_principal_attendance_data
    app.dependency_overrides[get_current_user] = lambda: data["user_admin"]

    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    t_id = data["teacher_profile"].id

    response = await client.get(f"/api/v1/staff-attendance/teacher/{t_id}/history", headers=headers)
    assert response.status_code == status.HTTP_200_OK
    assert response.json()["success"] is True


@pytest.mark.anyio
async def test_teacher_denied_access_to_history(client: AsyncClient, setup_principal_attendance_data):
    data = setup_principal_attendance_data
    app.dependency_overrides[get_current_user] = lambda: data["user_teacher"]

    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    t_id = data["teacher_profile"].id

    response = await client.get(f"/api/v1/staff-attendance/teacher/{t_id}/history", headers=headers)
    assert response.status_code == status.HTTP_403_FORBIDDEN


@pytest.mark.anyio
async def test_cross_school_attendance_access_denied(client: AsyncClient, setup_principal_attendance_data):
    data = setup_principal_attendance_data
    app.dependency_overrides[get_current_user] = lambda: data["user_cross"]

    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    t_id = data["teacher_profile"].id

    response = await client.get(f"/api/v1/staff-attendance/teacher/{t_id}/history", headers=headers)
    assert response.status_code == status.HTTP_403_FORBIDDEN


@pytest.mark.anyio
async def test_cross_tenant_attendance_access_denied(client: AsyncClient, setup_principal_attendance_data):
    data = setup_principal_attendance_data
    app.dependency_overrides[get_current_user] = lambda: data["user_principal"]

    headers = {"X-Tenant-ID": str(data["tenant_b"].id)}
    t_id = data["teacher_profile"].id

    response = await client.get(f"/api/v1/staff-attendance/teacher/{t_id}/history", headers=headers)
    assert response.status_code in [status.HTTP_404_NOT_FOUND, status.HTTP_422_UNPROCESSABLE_ENTITY]


@pytest.mark.anyio
async def test_unknown_teacher_returns_not_found(client: AsyncClient, setup_principal_attendance_data):
    data = setup_principal_attendance_data
    app.dependency_overrides[get_current_user] = lambda: data["user_principal"]

    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    random_uuid = uuid.uuid4()

    response = await client.get(f"/api/v1/staff-attendance/teacher/{random_uuid}/history", headers=headers)
    assert response.status_code == status.HTTP_404_NOT_FOUND


@pytest.mark.anyio
async def test_attendance_history_date_filtering(client: AsyncClient, setup_principal_attendance_data):
    data = setup_principal_attendance_data
    app.dependency_overrides[get_current_user] = lambda: data["user_principal"]

    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    t_id = data["teacher_profile"].id

    yest = date.today() - timedelta(days=1)
    response = await client.get(
        f"/api/v1/staff-attendance/teacher/{t_id}/history", 
        params={"start_date": str(yest), "end_date": str(yest)},
        headers=headers
    )
    assert response.status_code == status.HTTP_200_OK
    res_json = response.json()
    assert len(res_json["data"]) == 1
    assert res_json["data"][0]["attendance_date"] == str(yest)


@pytest.mark.anyio
async def test_attendance_history_pagination(client: AsyncClient, setup_principal_attendance_data):
    data = setup_principal_attendance_data
    app.dependency_overrides[get_current_user] = lambda: data["user_principal"]

    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    t_id = data["teacher_profile"].id

    response = await client.get(
        f"/api/v1/staff-attendance/teacher/{t_id}/history", 
        params={"skip": 1, "limit": 1},
        headers=headers
    )
    assert response.status_code == status.HTTP_200_OK
    res_json = response.json()
    assert len(res_json["data"]) == 1


@pytest.mark.anyio
async def test_daily_attendance_response_extended_compatibility(client: AsyncClient, setup_principal_attendance_data):
    data = setup_principal_attendance_data
    app.dependency_overrides[get_current_user] = lambda: data["user_principal"]

    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    s_id = data["school_a"].id
    target_date = date.today() - timedelta(days=1)

    response = await client.get(
        "/api/v1/staff-attendance/daily",
        params={"school_id": str(s_id), "attendance_date": str(target_date)},
        headers=headers
    )
    assert response.status_code == status.HTTP_200_OK
    res_json = response.json()
    assert res_json["success"] is True
    
    records = res_json["data"]["records"]
    assert len(records) > 0
    t_rec = next(r for r in records if r["teacher_id"] == str(data["teacher_profile"].id))
    assert t_rec["check_in_latitude"] == 17.4486
    assert t_rec["check_in_longitude"] == 78.3742
    assert t_rec["check_in_distance_meters"] == 15.0
    assert t_rec["is_mocked_location"] is False


@pytest.mark.anyio
async def test_school_geofence_configuration_update(client: AsyncClient, setup_principal_attendance_data):
    data = setup_principal_attendance_data
    app.dependency_overrides[get_current_user] = lambda: data["user_principal"]

    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    s_id = data["school_a"].id

    update_payload = {
        "latitude": 12.3456,
        "longitude": 98.7654,
        "geofence_radius_meters": 500
    }

    response = await client.put(f"/api/v1/schools/{s_id}", json=update_payload, headers=headers)
    assert response.status_code == status.HTTP_200_OK
    res_json = response.json()
    assert res_json["success"] is True
    assert res_json["data"]["latitude"] == 12.3456
    assert res_json["data"]["longitude"] == 98.7654
    assert res_json["data"]["geofence_radius_meters"] == 500


@pytest.mark.anyio
async def test_school_geofence_configuration_validation(client: AsyncClient, setup_principal_attendance_data):
    data = setup_principal_attendance_data
    app.dependency_overrides[get_current_user] = lambda: data["user_principal"]

    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    s_id = data["school_a"].id

    # 1. Invalid coordinates: only latitude supplied
    response1 = await client.put(f"/api/v1/schools/{s_id}", json={"latitude": 12.3456}, headers=headers)
    assert response1.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY

    # 2. Out of bounds latitude
    response2 = await client.put(f"/api/v1/schools/{s_id}", json={"latitude": 95.0, "longitude": 45.0}, headers=headers)
    assert response2.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY

    # 3. Invalid radius
    response3 = await client.put(f"/api/v1/schools/{s_id}", json={"geofence_radius_meters": 20000}, headers=headers)
    assert response3.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY
