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
from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate
from app.schemas.teacher import TeacherCreate
from app.schemas.auth import UserCreate
from app.services.auth import AuthService
from app.models.student import StudentGender
from app.models.teacher_leave import LeaveStatus
from app.api.dependencies.auth import get_current_user

@pytest.fixture
async def setup_leaves_test_data(db_session: AsyncSession):
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
    school_b = await repo_s.create(tenant_b.id, SchoolCreate(
        name="School B", code=f"SCH_B_{suffix}", board="CBSE", email=f"s-b-{suffix.lower()}@b.com"
    ))
    await db_session.commit()

    # Get system permissions
    stmt_p = select(Permission)
    res_p = await db_session.execute(stmt_p)
    all_perms = list(res_p.scalars().all())

    # Roles Setup
    role_teacher = Role(name="Teacher Role", code="TEACHER", is_system=True, tenant_id=tenant_a.id)
    role_teacher.permissions = [p for p in all_perms if p.code in ["teacher_leave.create", "teacher_leave.read", "staff_attendance.read"]]
    db_session.add(role_teacher)

    role_principal = Role(name="Principal Role", code="PRINCIPAL", is_system=True, tenant_id=tenant_a.id)
    role_principal.permissions = [p for p in all_perms if p.code in ["teacher_leave.review", "teacher_leave.read", "staff_attendance.read", "staff_attendance.admin"]]
    db_session.add(role_principal)

    role_principal_b = Role(name="Principal Role B", code="PRINCIPAL", is_system=True, tenant_id=tenant_b.id)
    role_principal_b.permissions = [p for p in all_perms if p.code in ["teacher_leave.review", "teacher_leave.read", "staff_attendance.read", "staff_attendance.admin"]]
    db_session.add(role_principal_b)
    await db_session.commit()

    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    auth_service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, repo_s)
    
    # Active Teacher User (Tenant A, School A)
    user_teacher = await auth_service.create_user(
        tenant_a.id,
        UserCreate(email=f"teacher-{suffix}@a.com", password="Password123!", first_name="Sarah", last_name="Connor")
    )
    user_teacher.roles.append(role_teacher)
    user_teacher.status = UserStatus.ACTIVE
    db_session.add(user_teacher)

    # Active Principal User (Tenant A, School A)
    user_principal = await auth_service.create_user(
        tenant_a.id,
        UserCreate(email=f"principal-{suffix}@a.com", password="Password123!", first_name="John", last_name="Doe")
    )
    user_principal.roles.append(role_principal)
    user_principal.status = UserStatus.ACTIVE
    db_session.add(user_principal)

    # Active Principal User B (Tenant B, School B)
    user_principal_b = await auth_service.create_user(
        tenant_b.id,
        UserCreate(email=f"principal-{suffix}@b.com", password="Password123!", first_name="Arthur", last_name="Dent")
    )
    user_principal_b.roles.append(role_principal_b)
    user_principal_b.status = UserStatus.ACTIVE
    db_session.add(user_principal_b)

    await db_session.commit()

    # Map users to schools
    await db_session.execute(
        text("INSERT INTO school_users (user_id, school_id) VALUES (:u, :s)"),
        {"u": str(user_teacher.id), "s": str(school_a.id)}
    )
    await db_session.execute(
        text("INSERT INTO school_users (user_id, school_id) VALUES (:u, :s)"),
        {"u": str(user_principal.id), "s": str(school_a.id)}
    )
    await db_session.execute(
        text("INSERT INTO school_users (user_id, school_id) VALUES (:u, :s)"),
        {"u": str(user_principal_b.id), "s": str(school_b.id)}
    )
    await db_session.commit()

    # Create Teacher Profile
    teacher_repo = TeacherRepository(db_session)
    teacher_profile = await teacher_repo.create(tenant_a.id, TeacherCreate(
        employee_code=f"EMP_{suffix}",
        staff_code=f"STF_{suffix}",
        first_name="Sarah",
        last_name="Connor",
        gender=StudentGender.FEMALE.value,
        date_of_birth=date(1990, 5, 12),
        mobile="9876543210",
        official_email=f"teacher-{suffix}@a.com",
        joining_date=date(2020, 1, 1),
        employment_type=EmploymentType.FULL_TIME.value,
        designation="TGT Science",
        department="Science",
        school_id=school_a.id
    ))
    teacher_profile.user_id = user_teacher.id
    db_session.add(teacher_profile)
    await db_session.commit()

    return {
        "tenant_a": tenant_a,
        "tenant_b": tenant_b,
        "school_a": school_a,
        "school_b": school_b,
        "user_teacher": user_teacher,
        "user_principal": user_principal,
        "user_principal_b": user_principal_b,
        "teacher": teacher_profile
    }

@pytest.mark.anyio
async def test_teacher_leave_workflow_e2e(client: AsyncClient, setup_leaves_test_data: dict):
    data = setup_leaves_test_data
    school_a_id = str(data["school_a"].id)
    
    # 1. Submit leave request as teacher
    app.dependency_overrides[get_current_user] = lambda: data["user_teacher"]
    response = await client.post(
        "/api/v1/teacher-leaves",
        json={
            "leave_type": "CASUAL",
            "start_date": str(date.today() + timedelta(days=2)),
            "end_date": str(date.today() + timedelta(days=3)),
            "reason": "Personal medical checkup"
        },
        headers={
            "X-Tenant-ID": str(data["tenant_a"].id)
        }
    )
    assert response.status_code == status.HTTP_201_CREATED
    leave_id = response.json()["data"]["id"]

    # 2. Get pending leaves as Principal A
    app.dependency_overrides[get_current_user] = lambda: data["user_principal"]
    response = await client.get(
        f"/api/v1/teacher-leaves?school_id={school_a_id}&status=PENDING",
        headers={
            "X-Tenant-ID": str(data["tenant_a"].id)
        }
    )
    assert response.status_code == status.HTTP_200_OK
    assert len(response.json()["data"]) == 1
    assert response.json()["data"][0]["reason"] == "Personal medical checkup"

    # 3. Prevent Tenant B Principal B from viewing Principal A's leave request
    app.dependency_overrides[get_current_user] = lambda: data["user_principal_b"]
    response = await client.get(
        f"/api/v1/teacher-leaves?school_id={school_a_id}",
        headers={
            "X-Tenant-ID": str(data["tenant_b"].id)
        }
    )
    # Principal B does not belong to school_a or tenant_a
    assert response.status_code == status.HTTP_403_FORBIDDEN

    # 4. Reject leave request as Principal A
    app.dependency_overrides[get_current_user] = lambda: data["user_principal"]
    response = await client.post(
        f"/api/v1/teacher-leaves/{leave_id}/review",
        json={
            "decision": "REJECT",
            "reviewer_remarks": "Not enough staff coverage"
        },
        headers={
            "X-Tenant-ID": str(data["tenant_a"].id)
        }
    )
    assert response.status_code == status.HTTP_200_OK
    assert response.json()["data"]["status"] == "REJECTED"
    assert response.json()["data"]["reviewer_remarks"] == "Not enough staff coverage"
    
    app.dependency_overrides.pop(get_current_user, None)

@pytest.mark.anyio
async def test_staff_attendance_daily_and_leaves(client: AsyncClient, setup_leaves_test_data: dict):
    data = setup_leaves_test_data
    school_a_id = str(data["school_a"].id)
    target_date = str(date.today() + timedelta(days=5))

    # 1. Submit and Approve a leave request for target date
    app.dependency_overrides[get_current_user] = lambda: data["user_teacher"]
    response = await client.post(
        "/api/v1/teacher-leaves",
        json={
            "leave_type": "SICK",
            "start_date": target_date,
            "end_date": target_date,
            "reason": "Recovering from wisdom teeth extraction"
        },
        headers={
            "X-Tenant-ID": str(data["tenant_a"].id)
        }
    )
    leave_id = response.json()["data"]["id"]

    app.dependency_overrides[get_current_user] = lambda: data["user_principal"]
    response = await client.post(
        f"/api/v1/teacher-leaves/{leave_id}/review",
        json={
            "decision": "APPROVE",
            "reviewer_remarks": "Approved"
        },
        headers={
            "X-Tenant-ID": str(data["tenant_a"].id)
        }
    )
    assert response.status_code == status.HTTP_200_OK

    # 2. Query daily staff report for target date
    response = await client.get(
        f"/api/v1/staff-attendance/daily?school_id={school_a_id}&attendance_date={target_date}",
        headers={
            "X-Tenant-ID": str(data["tenant_a"].id)
        }
    )
    assert response.status_code == status.HTTP_200_OK
    summary = response.json()["data"]
    assert summary["total_teachers"] == 1
    assert summary["on_leave_count"] == 1
    assert summary["records"][0]["attendance_status"] == "ON_LEAVE"
    assert summary["records"][0]["remarks"] == "Recovering from wisdom teeth extraction"
    
    app.dependency_overrides.pop(get_current_user, None)
