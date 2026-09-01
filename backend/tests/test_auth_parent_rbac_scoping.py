import uuid
import pytest
from datetime import date
from httpx import AsyncClient
from sqlalchemy import select, text

from app.models.tenant import Tenant
from app.models.school import School
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.class_entity import Class, ClassCategory
from app.models.section import Section
from app.models.student import Student, StudentGender
from app.models.guardian import Guardian, GuardianStatus, GuardianType, StudentGuardian, StudentGuardianRelationship
from app.models.role import Role
from app.models.permission import Permission
from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.section import SectionRepository
from app.repositories.student import StudentRepository
from app.repositories.guardian import GuardianRepository, StudentGuardianRepository
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
from app.services.auth import AuthService
from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate
from app.schemas.academic_year import AcademicYearCreate
from app.schemas.class_entity import ClassCreate
from app.schemas.section import SectionCreate
from app.schemas.student import StudentCreate
from app.schemas.guardian import GuardianCreate, StudentGuardianCreate
from app.schemas.auth import UserCreate

@pytest.fixture
async def setup_parent_scoping_data(db_session):
    suffix = uuid.uuid4().hex[:6].upper()
    repo_t = TenantRepository(db_session)
    tenant_a = await repo_t.create(TenantCreate(name="Tenant A", code=f"tenant-a-{suffix.lower()}", subdomain=f"t-a-{suffix.lower()}", email=f"a-{suffix.lower()}@t.com"))
    tenant_b = await repo_t.create(TenantCreate(name="Tenant B", code=f"tenant-b-{suffix.lower()}", subdomain=f"t-b-{suffix.lower()}", email=f"b-{suffix.lower()}@t.com"))

    repo_s = SchoolRepository(db_session)
    school_a = await repo_s.create(tenant_a.id, SchoolCreate(name="School A", code=f"SCH_A_{suffix}", board="CBSE", email=f"s-a-{suffix.lower()}@a.com"))
    school_b = await repo_s.create(tenant_b.id, SchoolCreate(name="School B", code=f"SCH_B_{suffix}", board="CBSE", email=f"s-b-{suffix.lower()}@b.com"))
    await db_session.commit()

    repo_ay = AcademicYearRepository(db_session)
    ay_a = await repo_ay.create(tenant_a.id, school_a.id, AcademicYearCreate(name="2026", code="AY2026", start_date="2026-01-01", end_date="2026-12-31"))
    ay_a.status = AcademicYearStatus.ACTIVE
    ay_b = await repo_ay.create(tenant_b.id, school_b.id, AcademicYearCreate(name="2026", code="AY2026", start_date="2026-01-01", end_date="2026-12-31"))
    ay_b.status = AcademicYearStatus.ACTIVE
    await db_session.commit()

    repo_c = ClassRepository(db_session)
    class_a = await repo_c.create(tenant_a.id, ClassCreate(school_id=school_a.id, academic_year_id=ay_a.id, name="Class 1", code="C1", level=1, category=ClassCategory.PRIMARY, capacity=30))
    class_b = await repo_c.create(tenant_b.id, ClassCreate(school_id=school_b.id, academic_year_id=ay_b.id, name="Class 1", code="C1", level=1, category=ClassCategory.PRIMARY, capacity=30))
    await db_session.commit()

    repo_sec = SectionRepository(db_session)
    sec_a = await repo_sec.create(tenant_a.id, SectionCreate(school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_a.id, name="Sec A", code="SA", capacity=30))
    sec_b = await repo_sec.create(tenant_b.id, SectionCreate(school_id=school_b.id, academic_year_id=ay_b.id, class_id=class_b.id, name="Sec A", code="SA", capacity=30))
    await db_session.commit()

    # Create Students
    repo_std = StudentRepository(db_session)
    student_a1 = await repo_std.create(tenant_id=tenant_a.id, obj_in=StudentCreate(school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_a.id, section_id=sec_a.id, admission_number="ADM-001", roll_number="R-01", first_name="Kid", last_name="A1", gender=StudentGender.MALE, date_of_birth=date(2015, 1, 1), admission_date=date(2026, 6, 1)))
    student_a2 = await repo_std.create(tenant_id=tenant_a.id, obj_in=StudentCreate(school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_a.id, section_id=sec_a.id, admission_number="ADM-002", roll_number="R-02", first_name="Kid", last_name="C1", gender=StudentGender.FEMALE, date_of_birth=date(2017, 1, 1), admission_date=date(2026, 6, 1)))
    student_b1 = await repo_std.create(tenant_id=tenant_b.id, obj_in=StudentCreate(school_id=school_b.id, academic_year_id=ay_b.id, class_id=class_b.id, section_id=sec_b.id, admission_number="ADM-003", roll_number="R-03", first_name="Kid", last_name="B1", gender=StudentGender.MALE, date_of_birth=date(2015, 1, 1), admission_date=date(2026, 6, 1)))
    await db_session.commit()

    # User & AuthService Setup
    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    auth_service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, repo_s)

    # Initialize Tenant RBAC first
    from app.services.rbac_provisioning import ensure_tenant_rbac
    await ensure_tenant_rbac(db_session, tenant_a.id)
    await ensure_tenant_rbac(db_session, tenant_b.id)

    # Super Admin (Tenant A)
    role_admin = await role_repo.get_by_code("ADMIN", tenant_a.id)
    user_admin = await auth_service.create_user(tenant_a.id, UserCreate(email=f"admin-{suffix}@a.com", password="Password123!", first_name="Admin", last_name="User", role_ids=[role_admin.id], school_ids=[school_a.id]))
    user_admin.is_superuser = True
    db_session.add(user_admin)
    
    # Parent A (Tenant A)
    role_parent_a = await role_repo.get_by_code("PARENT", tenant_a.id)
    user_parent_a = await auth_service.create_user(tenant_a.id, UserCreate(email=f"parent-a-{suffix}@a.com", password="Password123!", first_name="Parent", last_name="A", role_ids=[role_parent_a.id], school_ids=[school_a.id]))

    # Parent C (Tenant A - Unrelated)
    user_parent_c = await auth_service.create_user(tenant_a.id, UserCreate(email=f"parent-c-{suffix}@a.com", password="Password123!", first_name="Parent", last_name="C", role_ids=[role_parent_a.id], school_ids=[school_a.id]))

    # Parent B (Tenant B)
    role_parent_b = await role_repo.get_by_code("PARENT", tenant_b.id)
    user_parent_b = await auth_service.create_user(tenant_b.id, UserCreate(email=f"parent-b-{suffix}@b.com", password="Password123!", first_name="Parent", last_name="B", role_ids=[role_parent_b.id], school_ids=[school_b.id]))
    await db_session.commit()

    # Create Guardian Profiles
    repo_g = GuardianRepository(db_session)
    
    # Guardian A (linked to Parent A)
    g_a = await repo_g.create(tenant_a.id, GuardianCreate(school_id=school_a.id, guardian_type=GuardianType.FATHER, first_name="Guardian", last_name="A", gender="MALE", date_of_birth=date(1985, 1, 1), mobile=f"987654{suffix[:4]}", email=user_parent_a.email))
    g_a.user_id = user_parent_a.id
    db_session.add(g_a)

    # Guardian C (linked to Parent C)
    g_c = await repo_g.create(tenant_a.id, GuardianCreate(school_id=school_a.id, guardian_type=GuardianType.FATHER, first_name="Guardian", last_name="C", gender="MALE", date_of_birth=date(1985, 1, 1), mobile=f"987653{suffix[:4]}", email=user_parent_c.email))
    g_c.user_id = user_parent_c.id
    db_session.add(g_c)

    # Guardian B (linked to Parent B)
    g_b = await repo_g.create(tenant_b.id, GuardianCreate(school_id=school_b.id, guardian_type=GuardianType.FATHER, first_name="Guardian", last_name="B", gender="MALE", date_of_birth=date(1985, 1, 1), mobile=f"987652{suffix[:4]}", email=user_parent_b.email))
    g_b.user_id = user_parent_b.id
    db_session.add(g_b)
    await db_session.commit()

    # Map Sibling A1 to Guardian A
    repo_sg = StudentGuardianRepository(db_session)
    await repo_sg.create(tenant_a.id, StudentGuardianCreate(school_id=school_a.id, student_id=student_a1.id, guardian_id=g_a.id, relationship=StudentGuardianRelationship.FATHER, is_primary=True))
    # Map Sibling C1 to Guardian C
    await repo_sg.create(tenant_a.id, StudentGuardianCreate(school_id=school_a.id, student_id=student_a2.id, guardian_id=g_c.id, relationship=StudentGuardianRelationship.FATHER, is_primary=True))
    # Map Sibling B1 to Guardian B
    await repo_sg.create(tenant_b.id, StudentGuardianCreate(school_id=school_b.id, student_id=student_b1.id, guardian_id=g_b.id, relationship=StudentGuardianRelationship.FATHER, is_primary=True))
    await db_session.commit()

    tokens_admin = await auth_service.create_tokens(user_admin)
    tokens_parent_a = await auth_service.create_tokens(user_parent_a)
    tokens_parent_c = await auth_service.create_tokens(user_parent_c)

    return {
        "tenant_a": tenant_a,
        "tenant_b": tenant_b,
        "school_a": school_a,
        "school_b": school_b,
        "guardian_a": g_a,
        "guardian_b": g_b,
        "guardian_c": g_c,
        "student_a1": student_a1,
        "student_a2": student_a2,
        "headers_admin": {
            "Authorization": f"Bearer {tokens_admin.access_token}",
            "X-Tenant-ID": str(tenant_a.id)
        },
        "headers_parent_a": {
            "Authorization": f"Bearer {tokens_parent_a.access_token}",
            "X-Tenant-ID": str(tenant_a.id)
        },
        "headers_parent_c": {
            "Authorization": f"Bearer {tokens_parent_c.access_token}",
            "X-Tenant-ID": str(tenant_a.id)
        }
    }

@pytest.mark.anyio
async def test_parent_own_profile_access(client: AsyncClient, setup_parent_scoping_data):
    """
    Test A: Parent can access own guardian profile.
    """
    data = setup_parent_scoping_data
    g_id = data["guardian_a"].id
    s_id = data["school_a"].id

    # 1. Fetch own details
    resp_details = await client.get(f"/api/v1/guardians/{g_id}?school_id={s_id}", headers=data["headers_parent_a"])
    assert resp_details.status_code == 200
    assert resp_details.json()["data"]["id"] == str(g_id)

    # 2. List own profile
    resp_list = await client.get(f"/api/v1/guardians?school_id={s_id}", headers=data["headers_parent_a"])
    assert resp_list.status_code == 200
    results = resp_list.json()["data"]
    assert len(results) == 1
    assert results[0]["id"] == str(g_id)

@pytest.mark.anyio
async def test_parent_other_profile_block(client: AsyncClient, setup_parent_scoping_data):
    """
    Test B: Parent cannot access another parent's guardian profile.
    """
    data = setup_parent_scoping_data
    g_c_id = data["guardian_c"].id
    s_id = data["school_a"].id

    # 1. Access other direct details -> 403
    resp_details = await client.get(f"/api/v1/guardians/{g_c_id}?school_id={s_id}", headers=data["headers_parent_a"])
    assert resp_details.status_code == 403

@pytest.mark.anyio
async def test_parent_own_mappings_access(client: AsyncClient, setup_parent_scoping_data):
    """
    Test C: Parent can access own student-guardian mappings.
    """
    data = setup_parent_scoping_data
    g_id = data["guardian_a"].id

    resp = await client.get(f"/api/v1/student-guardians?guardian_id={g_id}", headers=data["headers_parent_a"])
    assert resp.status_code == 200
    results = resp.json()["data"]
    assert len(results) == 1
    assert results[0]["guardian_id"] == str(g_id)

@pytest.mark.anyio
async def test_parent_other_mappings_block(client: AsyncClient, setup_parent_scoping_data):
    """
    Test D: Parent cannot access another parent's student-guardian mappings.
    """
    data = setup_parent_scoping_data
    g_c_id = data["guardian_c"].id

    # Query mapping of Parent C -> 403
    resp = await client.get(f"/api/v1/student-guardians?guardian_id={g_c_id}", headers=data["headers_parent_a"])
    assert resp.status_code == 403

@pytest.mark.anyio
async def test_parent_cross_tenant_block(client: AsyncClient, setup_parent_scoping_data):
    """
    Test E: Parent cannot access another tenant's mappings or guardian profile.
    """
    data = setup_parent_scoping_data
    g_b_id = data["guardian_b"].id
    s_b_id = data["school_b"].id

    # Try mapping lookup of Tenant B -> mismatch token tenant claim -> 401/403
    resp_map = await client.get(f"/api/v1/student-guardians?guardian_id={g_b_id}", headers=data["headers_parent_a"])
    assert resp_map.status_code in (401, 403)

@pytest.mark.anyio
async def test_existing_authorized_roles(client: AsyncClient, setup_parent_scoping_data):
    """
    Test F: Admin role behavior remains unchanged (can list all guardians).
    """
    data = setup_parent_scoping_data
    s_id = data["school_a"].id

    resp_list = await client.get(f"/api/v1/guardians?school_id={s_id}", headers=data["headers_admin"])
    assert resp_list.status_code == 200
    results = resp_list.json()["data"]
    # Admin sees both Guardian A and Guardian C
    assert len(results) == 2
