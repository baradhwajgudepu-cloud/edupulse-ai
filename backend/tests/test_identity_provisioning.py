import os
import uuid
import pytest
from datetime import date, datetime, timezone
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tenant import Tenant
from app.models.school import School
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.class_entity import Class
from app.models.section import Section
from app.models.student import Student, StudentGender
from app.models.guardian import Guardian, GuardianStatus, GuardianType
from app.models.teacher import Teacher, TeacherStatus, EmploymentType
from app.models.user import User, UserStatus
from app.models.role import Role, user_roles
from app.models.permission import Permission
from app.core.security import create_access_token, hash_password
from app.services.identity_provisioning import IdentityProvisioningService
from app.services.teacher import TeacherService
from app.services.guardian import GuardianService
from app.schemas.teacher import TeacherCreate
from app.schemas.guardian import GuardianCreate
from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate, SchoolStatus
from app.schemas.academic_year import AcademicYearCreate
from app.repositories.teacher import TeacherRepository
from app.repositories.guardian import GuardianRepository, StudentGuardianRepository
from app.repositories.student import StudentRepository
from app.repositories.school import SchoolRepository
from app.repositories.tenant import TenantRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
from app.services.auth import AuthService


@pytest.fixture
async def setup_identity_test_data(db_session: AsyncSession):
    suffix = uuid.uuid4().hex[:6].lower()

    # 1. Tenants
    repo_t = TenantRepository(db_session)
    tenant_a = await repo_t.create(TenantCreate(name="Identity Tenant A", code=f"id-a-{suffix}", subdomain=f"id-a-{suffix}", email=f"a-{suffix}@t.com"))
    await db_session.commit()

    # 2. Schools
    repo_s = SchoolRepository(db_session)
    school_a = await repo_s.create(tenant_a.id, SchoolCreate(name="Identity School A", code=f"IA_{suffix.upper()}", board="CBSE", email=f"s-a-{suffix}@a.com", status=SchoolStatus.ACTIVE))
    await db_session.commit()

    # 3. Academic Year
    repo_ay = AcademicYearRepository(db_session)
    ay_a = await repo_ay.create(tenant_a.id, school_a.id, AcademicYearCreate(school_id=school_a.id, name="Year 2026", code="AY2026", start_date=date(2026, 1, 1), end_date=date(2026, 12, 31), status=AcademicYearStatus.ACTIVE, is_current=True))
    ay_a.status = AcademicYearStatus.ACTIVE
    await db_session.commit()

    # 4. Roles & Seed User
    stmt_p = select(Permission)
    res_p = await db_session.execute(stmt_p)
    all_perms = list(res_p.scalars().all())

    role_admin = Role(name="Super Admin", code="SUPER_ADMIN", is_system=True, tenant_id=tenant_a.id, version=1)
    role_admin.permissions = all_perms
    db_session.add(role_admin)

    # Fetch existing Roles (created automatically by initialize_tenant_rbac)
    from sqlalchemy.orm import selectinload
    stmt_role_parent = select(Role).where(Role.tenant_id == tenant_a.id, Role.code == "PARENT").options(selectinload(Role.permissions))
    role_parent = (await db_session.execute(stmt_role_parent)).scalar_one()
    role_parent.permissions = [p for p in all_perms if p.code in ["notification.read", "notification.mark_read"]]
    db_session.add(role_parent)

    stmt_role_teacher = select(Role).where(Role.tenant_id == tenant_a.id, Role.code == "TEACHER").options(selectinload(Role.permissions))
    role_teacher = (await db_session.execute(stmt_role_teacher)).scalar_one()
    role_teacher.permissions = [p for p in all_perms if p.code in ["notification.read", "notification.mark_read"]]
    db_session.add(role_teacher)

    stmt_role_principal = select(Role).where(Role.tenant_id == tenant_a.id, Role.code == "PRINCIPAL").options(selectinload(Role.permissions))
    role_principal = (await db_session.execute(stmt_role_principal)).scalar_one()
    role_principal.permissions = all_perms
    db_session.add(role_principal)

    stmt_role_staff = select(Role).where(Role.tenant_id == tenant_a.id, Role.code == "STAFF").options(selectinload(Role.permissions))
    role_staff = (await db_session.execute(stmt_role_staff)).scalar_one()
    role_staff.permissions = all_perms
    db_session.add(role_staff)

    await db_session.flush()

    # Admin User for provision trigger requests
    admin_user = User(
        email="identity_admin@alpha.edu",
        hashed_password=hash_password("Admin@123"),
        first_name="Identity",
        last_name="Admin",
        status=UserStatus.ACTIVE,
        is_superuser=True,
        tenant_id=tenant_a.id,
        version=1
    )
    admin_user.roles.append(role_admin)
    admin_user.schools.append(school_a)
    db_session.add(admin_user)
    await db_session.commit()

    token = create_access_token(subject=admin_user.id, tenant_id=tenant_a.id)
    headers = {"Authorization": f"Bearer {token}", "X-Tenant-ID": str(tenant_a.id)}

    return {
        "tenant_a": tenant_a,
        "school_a": school_a,
        "ay_a": ay_a,
        "admin_user": admin_user,
        "headers": headers,
        "role_parent": role_parent,
        "role_teacher": role_teacher
    }


@pytest.mark.anyio
async def test_identity_auto_provisioning_teacher(setup_identity_test_data, db_session: AsyncSession) -> None:
    tenant_a = setup_identity_test_data["tenant_a"]
    school_a = setup_identity_test_data["school_a"]
    admin_user = setup_identity_test_data["admin_user"]

    teacher_service = TeacherService(
        teacher_repo=TeacherRepository(db_session),
        school_repo=SchoolRepository(db_session)
    )

    suffix = uuid.uuid4().hex[:6].lower()
    teacher_create = TeacherCreate(
        school_id=school_a.id,
        employee_code=f"EMP-{suffix}",
        staff_code=f"STF-{suffix}",
        first_name="Jane",
        last_name="Smith",
        gender=StudentGender.FEMALE,
        date_of_birth=date(1990, 5, 15),
        mobile=f"+919999{suffix}",
        official_email=f"jane.{suffix}@school.edu",
        joining_date=date(2025, 10, 10),
        employment_type=EmploymentType.FULL_TIME
    )

    # 1. Creating teacher triggers auto-provisioning
    teacher = await teacher_service.create_teacher(tenant_a.id, teacher_create, created_by=admin_user.id)
    assert teacher.user_id is not None

    # 2. Verify User record has correct properties
    stmt_u = select(User).where(User.id == teacher.user_id).options(selectinload(User.roles))
    res_u = await db_session.execute(stmt_u)
    user = res_u.scalar_one()
    assert user.email == teacher.official_email
    assert user.must_change_password is True
    assert len(user.roles) == 1
    assert user.roles[0].code == "TEACHER"

    # 3. Deactivating/soft deleting teacher propagates status to User
    await teacher_service.delete_teacher(tenant_a.id, school_a.id, teacher.id, deleted_by=admin_user.id)
    
    # Reload user
    await db_session.refresh(user)
    assert user.status == UserStatus.INACTIVE
    assert user.deleted_at is not None

    # 4. Restoring teacher propagates restoration to User
    await teacher_service.restore_teacher(tenant_a.id, school_a.id, teacher.id, restored_by=admin_user.id)
    await db_session.refresh(user)
    assert user.status == UserStatus.ACTIVE
    assert user.deleted_at is None


@pytest.mark.anyio
async def test_identity_auto_provisioning_guardian(setup_identity_test_data, db_session: AsyncSession) -> None:
    tenant_a = setup_identity_test_data["tenant_a"]
    school_a = setup_identity_test_data["school_a"]
    admin_user = setup_identity_test_data["admin_user"]

    guardian_service = GuardianService(
        guardian_repo=GuardianRepository(db_session),
        student_guardian_repo=StudentGuardianRepository(db_session),
        student_repo=StudentRepository(db_session),
        school_repo=SchoolRepository(db_session)
    )

    suffix = uuid.uuid4().hex[:6].lower()
    guardian_create = GuardianCreate(
        school_id=school_a.id,
        guardian_type=GuardianType.FATHER,
        first_name="Bob",
        last_name="Smith",
        gender=StudentGender.MALE,
        date_of_birth=date(1985, 3, 22),
        mobile=f"+918888{suffix}",
        email=f"bob.{suffix}@gmail.com"
    )

    # 1. Creating guardian triggers auto-provisioning
    guardian = await guardian_service.create_guardian(tenant_a.id, guardian_create, created_by=admin_user.id)
    assert guardian.user_id is not None

    stmt_u = select(User).where(User.id == guardian.user_id).options(selectinload(User.roles))
    res_u = await db_session.execute(stmt_u)
    user = res_u.scalar_one()
    assert user.email == guardian.email
    assert len(user.roles) == 1
    assert user.roles[0].code == "PARENT"

    # 2. Deactivating guardian propagates status to User
    await guardian_service.delete_guardian(tenant_a.id, school_a.id, guardian.id, deleted_by=admin_user.id)
    await db_session.refresh(user)
    assert user.status == UserStatus.INACTIVE
    assert user.deleted_at is not None

    # 3. Restoring guardian restores User
    await guardian_service.restore_guardian(tenant_a.id, school_a.id, guardian.id, restored_by=admin_user.id)
    await db_session.refresh(user)
    assert user.status == UserStatus.ACTIVE
    assert user.deleted_at is None


@pytest.mark.anyio
async def test_identity_manual_provision_apis(client: AsyncClient, setup_identity_test_data, db_session: AsyncSession) -> None:
    tenant_a = setup_identity_test_data["tenant_a"]
    school_a = setup_identity_test_data["school_a"]
    headers = setup_identity_test_data["headers"]

    # Seed teacher directly in DB without a linked user_id to test manual provisioning API
    suffix = uuid.uuid4().hex[:6].lower()
    teacher_db = Teacher(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        employee_code=f"EMP-M-{suffix}",
        staff_code=f"STF-M-{suffix}",
        first_name="Manual",
        last_name="Teacher",
        gender=StudentGender.MALE,
        date_of_birth=date(1988, 1, 1),
        mobile=f"+917777{suffix}",
        official_email=f"manual.{suffix}@school.edu",
        joining_date=date(2025, 1, 1),
        employment_type=EmploymentType.FULL_TIME,
        status=TeacherStatus.ACTIVE,
        is_active=True,
        version=1
    )
    db_session.add(teacher_db)
    await db_session.commit()

    # 1. Trigger manual provisioning POST endpoint
    resp = await client.post(
        f"/api/v1/identity/provision/teacher/{teacher_db.id}?school_id={school_a.id}",
        headers=headers
    )
    assert resp.status_code == 201
    user_id = resp.json()["data"]["id"]

    # 2. Check provisioning status endpoint
    resp_st = await client.get(
        f"/api/v1/identity/provision/status/{teacher_db.id}",
        headers=headers
    )
    assert resp_st.status_code == 200
    assert resp_st.json()["data"]["is_provisioned"] is True
    assert resp_st.json()["data"]["user_id"] == user_id

    # 3. Test duplicate email validation error
    teacher_other = Teacher(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        employee_code=f"EMP-O-{suffix}",
        staff_code=f"STF-O-{suffix}",
        first_name="Other",
        last_name="Teacher",
        gender=StudentGender.MALE,
        date_of_birth=date(1988, 1, 1),
        mobile=f"+917779{suffix}",
        official_email=f"manual-other.{suffix}@school.edu",
        joining_date=date(2025, 1, 1),
        employment_type=EmploymentType.FULL_TIME,
        status=TeacherStatus.ACTIVE,
        is_active=True,
        version=1
    )
    db_session.add(teacher_other)
    await db_session.flush()

    user_conflict = User(
        email=f"manual-dup.{suffix}@school.edu",
        hashed_password=hash_password("Dummy@123"),
        first_name="Dummy",
        last_name="User",
        status=UserStatus.ACTIVE,
        tenant_id=tenant_a.id,
        version=1
    )
    db_session.add(user_conflict)
    await db_session.flush()
    teacher_other.user_id = user_conflict.id
    await db_session.commit()

    teacher_dup = Teacher(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        employee_code=f"EMP-D-{suffix}",
        staff_code=f"STF-D-{suffix}",
        first_name="Manual",
        last_name="Dup",
        gender=StudentGender.MALE,
        date_of_birth=date(1988, 1, 1),
        mobile=f"+917778{suffix}",
        official_email=f"manual-dup.{suffix}@school.edu", # Matches user_conflict's email
        joining_date=date(2025, 1, 1),
        employment_type=EmploymentType.FULL_TIME,
        status=TeacherStatus.ACTIVE,
        is_active=True,
        version=1
    )
    db_session.add(teacher_dup)
    await db_session.commit()

    resp_dup = await client.post(
        f"/api/v1/identity/provision/teacher/{teacher_dup.id}?school_id={school_a.id}",
        headers=headers
    )
    assert resp_dup.status_code == 409

    # 4. Test idempotency
    resp_idem = await client.post(
        f"/api/v1/identity/provision/teacher/{teacher_db.id}?school_id={school_a.id}",
        headers=headers
    )
    assert resp_idem.status_code == 201  # Returns existing user successfully


@pytest.mark.anyio
async def test_identity_lifecycle_management_apis(client: AsyncClient, setup_identity_test_data, db_session: AsyncSession) -> None:
    tenant_a = setup_identity_test_data["tenant_a"]
    school_a = setup_identity_test_data["school_a"]
    headers = setup_identity_test_data["headers"]

    # Provision teacher
    suffix = uuid.uuid4().hex[:6].lower()
    teacher_db = Teacher(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        employee_code=f"EMP-L-{suffix}",
        staff_code=f"STF-L-{suffix}",
        first_name="Lifecycle",
        last_name="Teacher",
        gender=StudentGender.MALE,
        date_of_birth=date(1988, 1, 1),
        mobile=f"+916666{suffix}",
        official_email=f"life.{suffix}@school.edu",
        joining_date=date(2025, 1, 1),
        employment_type=EmploymentType.FULL_TIME,
        status=TeacherStatus.ACTIVE,
        is_active=True,
        version=1
    )
    db_session.add(teacher_db)
    await db_session.commit()

    resp = await client.post(
        f"/api/v1/identity/provision/teacher/{teacher_db.id}?school_id={school_a.id}",
        headers=headers
    )
    assert resp.status_code == 201
    user_id = resp.json()["data"]["id"]

    # 1. Deactivate User Account
    resp_deact = await client.put(f"/api/v1/identity/users/{user_id}/deactivate", headers=headers)
    assert resp_deact.status_code == 200
    assert resp_deact.json()["data"]["status"] == "INACTIVE"

    # 2. Activate User Account
    resp_act = await client.put(f"/api/v1/identity/users/{user_id}/activate", headers=headers)
    assert resp_act.status_code == 200
    assert resp_act.json()["data"]["status"] == "ACTIVE"

    # 3. Reset Password
    resp_reset = await client.post(f"/api/v1/identity/users/{user_id}/reset-password", headers=headers)
    assert resp_reset.status_code == 200
    assert resp_reset.json()["data"]["temporary_password"] == "EduPulse@123"

    # 4. Test login using JWT auth with provisioned user
    login_payload = {
        "email": f"life.{suffix}@school.edu",
        "password": "EduPulse@123"
    }
    resp_login = await client.post(
        "/api/v1/auth/login",
        json=login_payload,
        headers={"X-Tenant-ID": str(tenant_a.id)}
    )
    assert resp_login.status_code == 200
    assert "access_token" in resp_login.json()["data"]
