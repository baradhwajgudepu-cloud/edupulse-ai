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
from app.services.teacher_leave import TeacherLeaveService
from app.api.dependencies.auth import get_current_user

@pytest.fixture
async def setup_leave_test_data(db_session: AsyncSession):
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
    school_a1 = await repo_s.create(tenant_a.id, SchoolCreate(
        name="School A1", code=f"SCH_A1_{suffix}", board="CBSE", email=f"s-a1-{suffix.lower()}@a.com"
    ))
    school_a2 = await repo_s.create(tenant_a.id, SchoolCreate(
        name="School A2", code=f"SCH_A2_{suffix}", board="CBSE", email=f"s-a2-{suffix.lower()}@a.com"
    ))
    school_b = await repo_s.create(tenant_b.id, SchoolCreate(
        name="School B", code=f"SCH_B_{suffix}", board="CBSE", email=f"s-b-{suffix.lower()}@b.com"
    ))
    await db_session.commit()

    stmt_p = select(Permission)
    res_p = await db_session.execute(stmt_p)
    all_perms = list(res_p.scalars().all())

    # Fetch existing Teacher & Principal Roles (created automatically by initialize_tenant_rbac)
    from sqlalchemy.orm import selectinload
    stmt_role_t = select(Role).where(Role.tenant_id == tenant_a.id, Role.code == "TEACHER").options(selectinload(Role.permissions))
    res_role_t = await db_session.execute(stmt_role_t)
    role_teacher = res_role_t.scalar_one()

    stmt_role_p = select(Role).where(Role.tenant_id == tenant_a.id, Role.code == "PRINCIPAL").options(selectinload(Role.permissions))
    res_role_p = await db_session.execute(stmt_role_p)
    role_principal = res_role_p.scalar_one()

    teacher_perm_codes = ["teacher_leave.read", "teacher_leave.create", "teacher_leave.cancel"]
    role_teacher.permissions = [p for p in all_perms if p.code in teacher_perm_codes]
    db_session.add(role_teacher)

    principal_perm_codes = ["teacher_leave.read", "teacher_leave.review", "teacher_leave.admin"]
    role_principal.permissions = [p for p in all_perms if p.code in principal_perm_codes]
    db_session.add(role_principal)

    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    auth_service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, repo_s)
    
    # Teacher 1 (School A1)
    user_teacher1 = await auth_service.create_user(
        tenant_a.id,
        UserCreate(email=f"t1-{suffix}@a.com", password="Password123!", first_name="T1", last_name="Connor")
    )
    user_teacher1.roles.append(role_teacher)
    user_teacher1.status = UserStatus.ACTIVE
    db_session.add(user_teacher1)

    await db_session.execute(
        text("INSERT INTO school_users (user_id, school_id) VALUES (:u, :s)"),
        {"u": str(user_teacher1.id), "s": str(school_a1.id)}
    )

    teacher_repo = TeacherRepository(db_session)
    profile_teacher1 = await teacher_repo.create(tenant_a.id, TeacherCreate(
        employee_code=f"EMP1_{suffix}", staff_code=f"STF1_{suffix}",
        first_name="T1", last_name="Connor", gender=StudentGender.FEMALE,
        date_of_birth=date(1990, 5, 15), mobile="9876543211",
        official_email=f"t1-{suffix}@a.com", joining_date=date(2020, 6, 1),
        employment_type=EmploymentType.FULL_TIME, school_id=school_a1.id
    ))
    profile_teacher1.user_id = user_teacher1.id
    db_session.add(profile_teacher1)

    # Teacher 2 (School A2)
    user_teacher2 = await auth_service.create_user(
        tenant_a.id,
        UserCreate(email=f"t2-{suffix}@a.com", password="Password123!", first_name="T2", last_name="Connor")
    )
    user_teacher2.roles.append(role_teacher)
    user_teacher2.status = UserStatus.ACTIVE
    db_session.add(user_teacher2)

    await db_session.execute(
        text("INSERT INTO school_users (user_id, school_id) VALUES (:u, :s)"),
        {"u": str(user_teacher2.id), "s": str(school_a2.id)}
    )

    profile_teacher2 = await teacher_repo.create(tenant_a.id, TeacherCreate(
        employee_code=f"EMP2_{suffix}", staff_code=f"STF2_{suffix}",
        first_name="T2", last_name="Connor", gender=StudentGender.FEMALE,
        date_of_birth=date(1990, 5, 15), mobile="9876543212",
        official_email=f"t2-{suffix}@a.com", joining_date=date(2020, 6, 1),
        employment_type=EmploymentType.FULL_TIME, school_id=school_a2.id
    ))
    profile_teacher2.user_id = user_teacher2.id
    db_session.add(profile_teacher2)

    # Principal 1 (School A1)
    user_principal1 = await auth_service.create_user(
        tenant_a.id,
        UserCreate(email=f"p1-{suffix}@a.com", password="Password123!", first_name="P1", last_name="Connor")
    )
    user_principal1.roles.append(role_principal)
    user_principal1.status = UserStatus.ACTIVE
    db_session.add(user_principal1)

    await db_session.execute(
        text("INSERT INTO school_users (user_id, school_id) VALUES (:u, :s)"),
        {"u": str(user_principal1.id), "s": str(school_a1.id)}
    )

    # User without permissions
    user_no_perms = await auth_service.create_user(
        tenant_a.id,
        UserCreate(email=f"noperm-{suffix}@a.com", password="Password123!", first_name="No", last_name="Perm")
    )
    user_no_perms.status = UserStatus.ACTIVE
    db_session.add(user_no_perms)

    await db_session.commit()

    return {
        "tenant_a": tenant_a,
        "tenant_b": tenant_b,
        "school_a1": school_a1,
        "school_a2": school_a2,
        "school_b": school_b,
        "teacher1": user_teacher1,
        "teacher1_profile": profile_teacher1,
        "teacher2": user_teacher2,
        "teacher2_profile": profile_teacher2,
        "principal1": user_principal1,
        "user_no_perms": user_no_perms
    }


@pytest.mark.anyio
async def test_teacher_creates_leave_success(client: AsyncClient, setup_leave_test_data):
    data = setup_leave_test_data
    app.dependency_overrides[get_current_user] = lambda: data["teacher1"]

    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    payload = {
        "leave_type": "CASUAL",
        "start_date": date.today().isoformat(),
        "end_date": (date.today() + timedelta(days=2)).isoformat(),
        "reason": "Family function",
        "remarks": "Will be available over mail"
    }

    response = await client.post("/api/v1/teacher-leaves", json=payload, headers=headers)
    assert response.status_code == status.HTTP_201_CREATED
    res_json = response.json()
    assert res_json["success"] is True
    assert res_json["data"]["status"] == "PENDING"
    assert res_json["data"]["leave_type"] == "CASUAL"
    assert res_json["data"]["school_id"] == str(data["school_a1"].id)
    assert res_json["data"]["teacher_id"] == str(data["teacher1_profile"].id)

    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.anyio
async def test_leave_creation_invalid_date_range(client: AsyncClient, setup_leave_test_data):
    data = setup_leave_test_data
    app.dependency_overrides[get_current_user] = lambda: data["teacher1"]

    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    payload = {
        "leave_type": "SICK",
        "start_date": (date.today() + timedelta(days=5)).isoformat(),
        "end_date": date.today().isoformat(),  # start after end
        "reason": "Sick leave"
    }

    response = await client.post("/api/v1/teacher-leaves", json=payload, headers=headers)
    # Validation error from field_validator is a 422 Unprocessable Entity
    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY

    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.anyio
async def test_leave_creation_overlap_rejection(client: AsyncClient, setup_leave_test_data):
    data = setup_leave_test_data
    app.dependency_overrides[get_current_user] = lambda: data["teacher1"]

    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    
    # 1. First leave
    payload1 = {
        "leave_type": "CASUAL",
        "start_date": date.today().isoformat(),
        "end_date": (date.today() + timedelta(days=2)).isoformat(),
        "reason": "Trip"
    }
    await client.post("/api/v1/teacher-leaves", json=payload1, headers=headers)

    # 2. Overlapping leave
    payload2 = {
        "leave_type": "SICK",
        "start_date": (date.today() + timedelta(days=1)).isoformat(),
        "end_date": (date.today() + timedelta(days=3)).isoformat(),
        "reason": "Flu"
    }
    response = await client.post("/api/v1/teacher-leaves", json=payload2, headers=headers)
    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY
    assert "overlaps with an existing" in response.json()["message"]

    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.anyio
async def test_teacher_lists_own_leaves(client: AsyncClient, setup_leave_test_data):
    data = setup_leave_test_data
    app.dependency_overrides[get_current_user] = lambda: data["teacher1"]

    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    
    # Post one leave request
    payload = {
        "leave_type": "CASUAL",
        "start_date": date.today().isoformat(),
        "end_date": date.today().isoformat(),
        "reason": "Personal work"
    }
    await client.post("/api/v1/teacher-leaves", json=payload, headers=headers)

    # Fetch own leaves
    response = await client.get("/api/v1/teacher-leaves/my", headers=headers)
    assert response.status_code == status.HTTP_200_OK
    res_json = response.json()
    assert len(res_json["data"]) >= 1
    assert res_json["data"][0]["teacher_id"] == str(data["teacher1_profile"].id)

    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.anyio
async def test_teacher_cancels_pending_leave(client: AsyncClient, setup_leave_test_data):
    data = setup_leave_test_data
    app.dependency_overrides[get_current_user] = lambda: data["teacher1"]

    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    
    # Create
    payload = {
        "leave_type": "CASUAL",
        "start_date": date.today().isoformat(),
        "end_date": date.today().isoformat(),
        "reason": "Dentist visit"
    }
    res_create = await client.post("/api/v1/teacher-leaves", json=payload, headers=headers)
    leave_id = res_create.json()["data"]["id"]

    # Cancel
    cancel_payload = {"cancellation_reason": "Rescheduled appointment"}
    response = await client.post(f"/api/v1/teacher-leaves/{leave_id}/cancel", json=cancel_payload, headers=headers)
    assert response.status_code == status.HTTP_200_OK
    assert response.json()["data"]["status"] == "CANCELLED"
    assert response.json()["data"]["cancellation_reason"] == "Rescheduled appointment"

    # Try cancelling again (fails since not PENDING anymore)
    response_dup = await client.post(f"/api/v1/teacher-leaves/{leave_id}/cancel", json=cancel_payload, headers=headers)
    assert response_dup.status_code == status.HTTP_400_BAD_REQUEST
    assert "Cannot cancel leave request" in response_dup.json()["message"]

    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.anyio
async def test_principal_reviews_leave(client: AsyncClient, setup_leave_test_data):
    data = setup_leave_test_data
    
    # 1. Teacher submits leave
    app.dependency_overrides[get_current_user] = lambda: data["teacher1"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    payload = {
        "leave_type": "CASUAL",
        "start_date": date.today().isoformat(),
        "end_date": date.today().isoformat(),
        "reason": "Urgent travel"
    }
    res_create = await client.post("/api/v1/teacher-leaves", json=payload, headers=headers)
    leave_id = res_create.json()["data"]["id"]

    # 2. Principal reviews (APPROVE)
    app.dependency_overrides[get_current_user] = lambda: data["principal1"]
    review_payload = {
        "decision": "APPROVE",
        "reviewer_remarks": "Approved. Enjoy your travel."
    }
    response = await client.post(f"/api/v1/teacher-leaves/{leave_id}/review", json=review_payload, headers=headers)
    assert response.status_code == status.HTTP_200_OK
    assert response.json()["data"]["status"] == "APPROVED"
    assert response.json()["data"]["reviewed_by"] == str(data["principal1"].id)
    assert response.json()["data"]["reviewer_remarks"] == "Approved. Enjoy your travel."

    # 3. Cannot cancel approved leave
    app.dependency_overrides[get_current_user] = lambda: data["teacher1"]
    cancel_payload = {"cancellation_reason": "Cancel travel"}
    res_cancel = await client.post(f"/api/v1/teacher-leaves/{leave_id}/cancel", json=cancel_payload, headers=headers)
    assert res_cancel.status_code == status.HTTP_400_BAD_REQUEST

    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.anyio
async def test_reviewer_school_authorization(client: AsyncClient, setup_leave_test_data):
    data = setup_leave_test_data
    
    # 1. Teacher 2 (School A2) submits leave
    app.dependency_overrides[get_current_user] = lambda: data["teacher2"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    payload = {
        "leave_type": "CASUAL",
        "start_date": date.today().isoformat(),
        "end_date": date.today().isoformat(),
        "reason": "Personal"
    }
    res_create = await client.post("/api/v1/teacher-leaves", json=payload, headers=headers)
    leave_id = res_create.json()["data"]["id"]

    # 2. Principal 1 (School A1) reviews Teacher 2's leave (School A2) -> Should fail with 403 Forbidden!
    app.dependency_overrides[get_current_user] = lambda: data["principal1"]
    review_payload = {
        "decision": "APPROVE",
        "reviewer_remarks": "Not my school but trying to approve"
    }
    response = await client.post(f"/api/v1/teacher-leaves/{leave_id}/review", json=review_payload, headers=headers)
    assert response.status_code == status.HTTP_403_FORBIDDEN
    assert "You do not have permissions for this school" in response.json()["message"]

    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.anyio
async def test_teacher_cannot_review_own_leave(client: AsyncClient, setup_leave_test_data, db_session: AsyncSession):
    data = setup_leave_test_data
    
    # 1. Submits leave
    app.dependency_overrides[get_current_user] = lambda: data["teacher1"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    payload = {
        "leave_type": "CASUAL",
        "start_date": date.today().isoformat(),
        "end_date": date.today().isoformat(),
        "reason": "Trip"
    }
    res_create = await client.post("/api/v1/teacher-leaves", json=payload, headers=headers)
    leave_id = res_create.json()["data"]["id"]

    # Temporarily add review permission to teacher role to see if it allows self-review
    stmt_role = select(Role).where(Role.code == "TEACHER", Role.tenant_id == data["tenant_a"].id)
    res_role = await db_session.execute(stmt_role)
    role_teacher = res_role.scalar_one()
    
    stmt_p = select(Permission).where(Permission.code == "teacher_leave.review")
    res_p = await db_session.execute(stmt_p)
    perm_review = res_p.scalar_one()
    
    role_teacher.permissions.append(perm_review)
    await db_session.commit()

    # Try self review
    review_payload = {
        "decision": "APPROVE",
        "reviewer_remarks": "Self approving"
    }
    response = await client.post(f"/api/v1/teacher-leaves/{leave_id}/review", json=review_payload, headers=headers)
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert "Cannot review your own leave request" in response.json()["message"]

    # Revert role change
    role_teacher.permissions.remove(perm_review)
    await db_session.commit()

    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.anyio
async def test_tenant_isolation(client: AsyncClient, setup_leave_test_data):
    data = setup_leave_test_data
    from fastapi import HTTPException
    def mock_get_current_user_mismatch():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token tenant claims mismatch requested boundary."
        )
    app.dependency_overrides[get_current_user] = mock_get_current_user_mismatch

    # Use tenant B header for tenant A user
    headers = {"X-Tenant-ID": str(data["tenant_b"].id)}
    payload = {
        "leave_type": "CASUAL",
        "start_date": date.today().isoformat(),
        "end_date": date.today().isoformat(),
        "reason": "Personal"
    }

    response = await client.post("/api/v1/teacher-leaves", json=payload, headers=headers)
    assert response.status_code == status.HTTP_401_UNAUTHORIZED

    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.anyio
async def test_permission_enforcement(client: AsyncClient, setup_leave_test_data):
    data = setup_leave_test_data
    app.dependency_overrides[get_current_user] = lambda: data["user_no_perms"]

    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}
    payload = {
        "leave_type": "CASUAL",
        "start_date": date.today().isoformat(),
        "end_date": date.today().isoformat(),
        "reason": "Personal"
    }

    response = await client.post("/api/v1/teacher-leaves", json=payload, headers=headers)
    assert response.status_code == status.HTTP_403_FORBIDDEN
    assert "insufficient system permissions" in response.json()["message"]

    app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.anyio
async def test_is_teacher_on_approved_leave_helper(db_session: AsyncSession, setup_leave_test_data):
    data = setup_leave_test_data
    service = TeacherLeaveService(None, None, None)
    
    # Manual insertion of approved leave
    leave_date = date.today() + timedelta(days=10)
    db_obj = TeacherLeave(
        id=uuid.uuid4(),
        tenant_id=data["tenant_a"].id,
        school_id=data["school_a1"].id,
        teacher_id=data["teacher1_profile"].id,
        leave_type=LeaveType.CASUAL,
        start_date=leave_date,
        end_date=leave_date + timedelta(days=2),
        reason="Vacation",
        status=LeaveStatus.APPROVED
    )
    db_session.add(db_obj)
    await db_session.commit()

    leave_service = TeacherLeaveService(None, None, None)
    # We must mock or use the db session in a repository
    from app.repositories.teacher_leave import TeacherLeaveRepository
    repo = TeacherLeaveRepository(db_session)
    leave_service.leave_repo = repo

    # On leave
    is_on_leave = await leave_service.is_teacher_on_approved_leave(
        data["tenant_a"].id, data["teacher1_profile"].id, leave_date + timedelta(days=1)
    )
    assert is_on_leave is True

    # Not on leave
    is_on_leave_false = await leave_service.is_teacher_on_approved_leave(
        data["tenant_a"].id, data["teacher1_profile"].id, leave_date - timedelta(days=1)
    )
    assert is_on_leave_false is False
