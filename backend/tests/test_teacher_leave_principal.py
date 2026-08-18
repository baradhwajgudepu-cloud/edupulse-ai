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
from app.models.student import StudentGender
from app.models.teacher_leave import TeacherLeave, LeaveStatus, LeaveType
from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
from app.services.auth import AuthService
from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate
from app.schemas.teacher import TeacherCreate
from app.schemas.auth import UserCreate
from app.api.dependencies.auth import get_current_user

@pytest.fixture
async def setup_principal_leave_data(db_session: AsyncSession):
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
    school_b = await repo_s.create(tenant_a.id, SchoolCreate(
        name="School B", code=f"SCH_B_{suffix}", board="CBSE", email=f"s-b-{suffix.lower()}@b.com"
    ))

    await db_session.commit()

    stmt_p = select(Permission)
    res_p = await db_session.execute(stmt_p)
    all_perms = list(res_p.scalars().all())

    # Roles setup
    role_teacher = Role(name="Teacher", code="TEACHER", is_system=True, tenant_id=tenant_a.id)
    role_teacher.permissions = [p for p in all_perms if p.code in ["teacher_leave.read", "teacher_leave.create", "teacher_leave.cancel"]]
    db_session.add(role_teacher)

    role_principal = Role(name="Principal", code="PRINCIPAL", is_system=True, tenant_id=tenant_a.id)
    role_principal.permissions = [p for p in all_perms if p.code in ["teacher_leave.read", "teacher_leave.review"]]
    db_session.add(role_principal)

    role_admin = Role(name="Admin", code="ADMIN", is_system=True, tenant_id=tenant_a.id)
    role_admin.permissions = [p for p in all_perms if p.code in ["teacher_leave.read", "teacher_leave.review"]]
    db_session.add(role_admin)

    await db_session.commit()

    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    auth_service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, repo_s)

    # Users
    user_teacher = await auth_service.create_user(
        tenant_a.id, UserCreate(email=f"teacher-{suffix}@a.com", password="Password123!", first_name="Sarah", last_name="Connor")
    )
    user_teacher.roles.append(role_teacher)
    user_teacher.status = UserStatus.ACTIVE
    db_session.add(user_teacher)

    user_principal = await auth_service.create_user(
        tenant_a.id, UserCreate(email=f"principal-{suffix}@a.com", password="Password123!", first_name="James", last_name="Cameron")
    )
    user_principal.roles.append(role_principal)
    user_principal.status = UserStatus.ACTIVE
    db_session.add(user_principal)

    user_admin = await auth_service.create_user(
        tenant_a.id, UserCreate(email=f"admin-{suffix}@a.com", password="Password123!", first_name="Admin", last_name="User")
    )
    user_admin.roles.append(role_admin)
    user_admin.status = UserStatus.ACTIVE
    db_session.add(user_admin)

    user_cross = await auth_service.create_user(
        tenant_a.id, UserCreate(email=f"cross-{suffix}@a.com", password="Password123!", first_name="Cross", last_name="Principal")
    )
    user_cross.roles.append(role_principal)
    user_cross.status = UserStatus.ACTIVE
    db_session.add(user_cross)

    await db_session.commit()

    # School mappings
    await db_session.execute(text("INSERT INTO school_users (user_id, school_id) VALUES (:u, :s)"), {"u": str(user_teacher.id), "s": str(school_a.id)})
    await db_session.execute(text("INSERT INTO school_users (user_id, school_id) VALUES (:u, :s)"), {"u": str(user_principal.id), "s": str(school_a.id)})
    await db_session.execute(text("INSERT INTO school_users (user_id, school_id) VALUES (:u, :s)"), {"u": str(user_admin.id), "s": str(school_a.id)})
    await db_session.execute(text("INSERT INTO school_users (user_id, school_id) VALUES (:u, :s)"), {"u": str(user_cross.id), "s": str(school_b.id)})

    # Teacher Profile
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
    await db_session.commit()
    await db_session.refresh(teacher_profile)

    # Historical Leaves
    leave1 = TeacherLeave(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        teacher_id=teacher_profile.id,
        leave_type=LeaveType.SICK,
        start_date=date.today() + timedelta(days=5),
        end_date=date.today() + timedelta(days=6),
        reason="Fever and rest",
        status=LeaveStatus.PENDING
    )
    db_session.add(leave1)

    leave2 = TeacherLeave(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        teacher_id=teacher_profile.id,
        leave_type=LeaveType.CASUAL,
        start_date=date.today() + timedelta(days=10),
        end_date=date.today() + timedelta(days=11),
        reason="Family function",
        status=LeaveStatus.APPROVED,
        reviewed_by=user_principal.id,
        reviewed_at=datetime.now(timezone.utc),
        reviewer_remarks="Approved"
    )
    db_session.add(leave2)

    await db_session.commit()

    return {
        "tenant_a": tenant_a,
        "tenant_b": tenant_b,
        "school_a": school_a,
        "school_b": school_b,
        "user_teacher": user_teacher,
        "user_principal": user_principal,
        "user_admin": user_admin,
        "user_cross": user_cross,
        "teacher_profile": teacher_profile,
        "leave1": leave1,
        "leave2": leave2
    }


@pytest.mark.anyio
async def test_principal_can_retrieve_teacher_leave_history(client: AsyncClient, setup_principal_leave_data):
    data = setup_principal_leave_data
    app.dependency_overrides[get_current_user] = lambda: data["user_principal"]

    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    t_id = data["teacher_profile"].id

    response = await client.get(f"/api/v1/teacher-leaves/teacher/{t_id}/history", headers=headers)
    assert response.status_code == status.HTTP_200_OK
    res_json = response.json()
    assert res_json["success"] is True
    assert len(res_json["data"]) == 2


@pytest.mark.anyio
async def test_admin_can_retrieve_teacher_leave_history(client: AsyncClient, setup_principal_leave_data):
    data = setup_principal_leave_data
    app.dependency_overrides[get_current_user] = lambda: data["user_admin"]

    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    t_id = data["teacher_profile"].id

    response = await client.get(f"/api/v1/teacher-leaves/teacher/{t_id}/history", headers=headers)
    assert response.status_code == status.HTTP_200_OK
    assert response.json()["success"] is True


@pytest.mark.anyio
async def test_teacher_denied_access_to_leave_history(client: AsyncClient, setup_principal_leave_data):
    data = setup_principal_leave_data
    app.dependency_overrides[get_current_user] = lambda: data["user_teacher"]

    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    t_id = data["teacher_profile"].id

    response = await client.get(f"/api/v1/teacher-leaves/teacher/{t_id}/history", headers=headers)
    assert response.status_code == status.HTTP_403_FORBIDDEN


@pytest.mark.anyio
async def test_cross_school_leave_access_denied(client: AsyncClient, setup_principal_leave_data):
    data = setup_principal_leave_data
    app.dependency_overrides[get_current_user] = lambda: data["user_cross"]

    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    t_id = data["teacher_profile"].id

    response = await client.get(f"/api/v1/teacher-leaves/teacher/{t_id}/history", headers=headers)
    assert response.status_code == status.HTTP_403_FORBIDDEN


@pytest.mark.anyio
async def test_cross_tenant_leave_access_denied(client: AsyncClient, setup_principal_leave_data):
    data = setup_principal_leave_data
    app.dependency_overrides[get_current_user] = lambda: data["user_principal"]

    headers = {"X-Tenant-ID": str(data["tenant_b"].id)}
    t_id = data["teacher_profile"].id

    response = await client.get(f"/api/v1/teacher-leaves/teacher/{t_id}/history", headers=headers)
    assert response.status_code in [status.HTTP_404_NOT_FOUND, status.HTTP_422_UNPROCESSABLE_ENTITY]


@pytest.mark.anyio
async def test_unknown_teacher_leaves_returns_not_found(client: AsyncClient, setup_principal_leave_data):
    data = setup_principal_leave_data
    app.dependency_overrides[get_current_user] = lambda: data["user_principal"]

    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    random_uuid = uuid.uuid4()

    response = await client.get(f"/api/v1/teacher-leaves/teacher/{random_uuid}/history", headers=headers)
    assert response.status_code == status.HTTP_404_NOT_FOUND


@pytest.mark.anyio
async def test_leave_history_status_filtering(client: AsyncClient, setup_principal_leave_data):
    data = setup_principal_leave_data
    app.dependency_overrides[get_current_user] = lambda: data["user_principal"]

    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    t_id = data["teacher_profile"].id

    response = await client.get(
        f"/api/v1/teacher-leaves/teacher/{t_id}/history",
        params={"status": "APPROVED"},
        headers=headers
    )
    assert response.status_code == status.HTTP_200_OK
    res_json = response.json()
    assert len(res_json["data"]) == 1
    assert res_json["data"][0]["status"] == "APPROVED"


@pytest.mark.anyio
async def test_leave_history_type_filtering(client: AsyncClient, setup_principal_leave_data):
    data = setup_principal_leave_data
    app.dependency_overrides[get_current_user] = lambda: data["user_principal"]

    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    t_id = data["teacher_profile"].id

    response = await client.get(
        f"/api/v1/teacher-leaves/teacher/{t_id}/history",
        params={"leave_type": "SICK"},
        headers=headers
    )
    assert response.status_code == status.HTTP_200_OK
    res_json = response.json()
    assert len(res_json["data"]) == 1
    assert res_json["data"][0]["leave_type"] == "SICK"


@pytest.mark.anyio
async def test_leave_history_date_filtering(client: AsyncClient, setup_principal_leave_data):
    data = setup_principal_leave_data
    app.dependency_overrides[get_current_user] = lambda: data["user_principal"]

    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    t_id = data["teacher_profile"].id

    start = date.today() + timedelta(days=4)
    end = date.today() + timedelta(days=7)

    response = await client.get(
        f"/api/v1/teacher-leaves/teacher/{t_id}/history",
        params={"start_date": str(start), "end_date": str(end)},
        headers=headers
    )
    assert response.status_code == status.HTTP_200_OK
    res_json = response.json()
    assert len(res_json["data"]) == 1
    assert res_json["data"][0]["leave_type"] == "SICK"


@pytest.mark.anyio
async def test_leave_history_pagination(client: AsyncClient, setup_principal_leave_data):
    data = setup_principal_leave_data
    app.dependency_overrides[get_current_user] = lambda: data["user_principal"]

    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    t_id = data["teacher_profile"].id

    response = await client.get(
        f"/api/v1/teacher-leaves/teacher/{t_id}/history",
        params={"skip": 1, "limit": 1},
        headers=headers
    )
    assert response.status_code == status.HTTP_200_OK
    res_json = response.json()
    assert len(res_json["data"]) == 1


@pytest.mark.anyio
async def test_existing_review_workflow_remains_intact(client: AsyncClient, setup_principal_leave_data):
    data = setup_principal_leave_data
    app.dependency_overrides[get_current_user] = lambda: data["user_principal"]

    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    l_id = data["leave1"].id

    review_payload = {
        "decision": "APPROVE",
        "reviewer_remarks": "Looks reasonable, approved."
    }

    response = await client.post(
        f"/api/v1/teacher-leaves/{l_id}/review",
        json=review_payload,
        headers=headers
    )
    assert response.status_code == status.HTTP_200_OK
    res_json = response.json()
    assert res_json["success"] is True
    assert res_json["data"]["status"] == "APPROVED"
    assert res_json["data"]["reviewer_remarks"] == "Looks reasonable, approved."
