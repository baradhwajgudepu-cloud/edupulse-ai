import uuid
import pytest
from datetime import date, datetime, timezone
from httpx import AsyncClient
from sqlalchemy import select, text
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tenant import Tenant
from app.models.school import School
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.class_entity import Class, ClassCategory
from app.models.section import Section
from app.models.student import Student, StudentStatus, StudentGender
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
async def setup_guardian_test_data(db_session):
    """
    Sets up common testing context:
    - Tenant A, School A
    - Student A, Student B (siblings under School A)
    - Tenant B, School B, Student C (isolated tenant context)
    - Super Admin user with credentials
    """
    suffix = uuid.uuid4().hex[:6].upper()
    repo_t = TenantRepository(db_session)
    tenant_a = await repo_t.create(TenantCreate(name="Tenant A", code=f"tenant-a-{suffix.lower()}", subdomain=f"t-a-{suffix.lower()}", email=f"a-{suffix.lower()}@t.com"))
    tenant_b = await repo_t.create(TenantCreate(name="Tenant B", code=f"tenant-b-{suffix.lower()}", subdomain=f"t-b-{suffix.lower()}", email=f"b-{suffix.lower()}@t.com"))

    repo_s = SchoolRepository(db_session)
    school_a = await repo_s.create(tenant_a.id, SchoolCreate(name="School A", code=f"SCH_A_{suffix}", board="CBSE", email=f"s-a-{suffix.lower()}@a.com"))
    school_b = await repo_s.create(tenant_b.id, SchoolCreate(name="School B", code=f"SCH_B_{suffix}", board="CBSE", email=f"s-b-{suffix.lower()}@b.com"))
    await db_session.commit()

    # Pre-create Academic Year, Class, Section using repositories
    repo_ay = AcademicYearRepository(db_session)
    ay_a = await repo_ay.create(
        tenant_a.id,
        school_a.id,
        AcademicYearCreate(name="2026", code="AY2026", start_date="2026-01-01", end_date="2026-12-31")
    )
    ay_a.status = AcademicYearStatus.ACTIVE

    ay_b = await repo_ay.create(
        tenant_b.id,
        school_b.id,
        AcademicYearCreate(name="2026", code="AY2026", start_date="2026-01-01", end_date="2026-12-31")
    )
    ay_b.status = AcademicYearStatus.ACTIVE

    repo_c = ClassRepository(db_session)
    class_a = await repo_c.create(
        tenant_a.id,
        ClassCreate(
            school_id=school_a.id,
            academic_year_id=ay_a.id,
            name="Class 1",
            code="C1",
            level=1,
            category=ClassCategory.PRIMARY,
            capacity=30
        )
    )

    class_b = await repo_c.create(
        tenant_b.id,
        ClassCreate(
            school_id=school_b.id,
            academic_year_id=ay_b.id,
            name="Class 1",
            code="C1",
            level=1,
            category=ClassCategory.PRIMARY,
            capacity=30
        )
    )
    await db_session.commit()

    repo_sec = SectionRepository(db_session)
    sec_a = await repo_sec.create(
        tenant_a.id,
        SectionCreate(
            school_id=school_a.id,
            academic_year_id=ay_a.id,
            class_id=class_a.id,
            name="Sec A",
            code="SA",
            capacity=30
        )
    )
    sec_b = await repo_sec.create(
        tenant_b.id,
        SectionCreate(
            school_id=school_b.id,
            academic_year_id=ay_b.id,
            class_id=class_b.id,
            name="Sec A",
            code="SA",
            capacity=30
        )
    )
    await db_session.commit()

    repo_std = StudentRepository(db_session)
    student_a1 = await repo_std.create(
        tenant_id=tenant_a.id,
        obj_in=StudentCreate(
            school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_a.id, section_id=sec_a.id,
            admission_number="ADM-001", roll_number="R-01", first_name="Sibling", last_name="One",
            gender=StudentGender.MALE, date_of_birth=date(2015, 1, 1), admission_date=date(2026, 6, 1)
        )
    )
    student_a2 = await repo_std.create(
        tenant_id=tenant_a.id,
        obj_in=StudentCreate(
            school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_a.id, section_id=sec_a.id,
            admission_number="ADM-002", roll_number="R-02", first_name="Sibling", last_name="Two",
            gender=StudentGender.FEMALE, date_of_birth=date(2017, 1, 1), admission_date=date(2026, 6, 1)
        )
    )
    student_b1 = await repo_std.create(
        tenant_id=tenant_b.id,
        obj_in=StudentCreate(
            school_id=school_b.id, academic_year_id=ay_b.id, class_id=class_b.id, section_id=sec_b.id,
            admission_number="ADM-003", roll_number="R-03", first_name="TenantB", last_name="Student",
            gender=StudentGender.MALE, date_of_birth=date(2015, 1, 1), admission_date=date(2026, 6, 1)
        )
    )
    await db_session.commit()

    # User Setup
    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    auth_service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, repo_s)

    stmt_p = select(Permission)
    res_p = await db_session.execute(stmt_p)
    all_perms = list(res_p.scalars().all())

    role_a = Role(name="Super Admin", code="SUPER_ADMIN", is_system=True, tenant_id=tenant_a.id)
    role_a.permissions = all_perms
    db_session.add(role_a)

    user_a = await auth_service.create_user(
        tenant_a.id,
        UserCreate(email=f"admin-{suffix}@a.com", password="Password123!", first_name="Admin", last_name="User")
    )
    user_a.roles.append(role_a)

    # Map user to School A
    await db_session.execute(
        text("INSERT INTO school_users (user_id, school_id) VALUES (:u, :s)"),
        {"u": str(user_a.id), "s": str(school_a.id)}
    )
    await db_session.commit()

    tokens = await auth_service.create_tokens(user_a)

    return {
        "tenant_a": tenant_a,
        "tenant_b": tenant_b,
        "school_a": school_a,
        "school_b": school_b,
        "student_a1": student_a1,
        "student_a2": student_a2,
        "student_b1": student_b1,
        "user_a": user_a,
        "auth_headers": {
            "Authorization": f"Bearer {tokens.access_token}",
            "X-Tenant-ID": str(tenant_a.id)
        }
    }

@pytest.mark.anyio
async def test_guardian_crud_flow(client: AsyncClient, setup_guardian_test_data, db_session) -> None:
    """
    Verifies Guardian CRUD endpoints:
    - POST create guardian
    - GET list guardians
    - GET fetch guardian details
    - PUT update guardian details
    - DELETE soft-delete guardian
    """
    data = setup_guardian_test_data
    school_id = data["school_a"].id
    headers = data["auth_headers"]

    # 1. Create Guardian
    payload = {
        "school_id": str(school_id),
        "guardian_type": "FATHER",
        "first_name": "Abraham",
        "middle_name": "Thomas",
        "last_name": "Lincoln",
        "gender": "MALE",
        "date_of_birth": "1980-02-12",
        "aadhaar_number": "123456789012",
        "pan_number": "ABCDE1234F",
        "occupation": "Lawyer",
        "qualification": "Graduate",
        "organization": "Illinois Court",
        "annual_income": 85000.00,
        "mobile": "+919988112233",
        "alternate_mobile": "+919988112244",
        "email": "alincoln@whitehouse.gov",
        "emergency_contact_name": "Alternate Contact",
        "emergency_contact_mobile": "+919988112255",
        "photo_url": "http://photos.com/abe.jpg",
        "address": {"city": "Springfield", "state": "IL"},
        "communication_preferences": {"preferred_language": "English", "communication_mode": "SMS"},
        "settings": {"receive_alerts": True},
        "ai_metrics": {
            "engagement_score": 90,
            "fee_payment_score": 95,
            "communication_score": 88
        }
    }
    resp = await client.post("/api/v1/guardians", json=payload, headers=headers)
    assert resp.status_code == 201
    guardian_id = resp.json()["data"]["id"]
    assert resp.json()["data"]["first_name"] == "Abraham"
    assert resp.json()["data"]["emergency_contact_name"] == "Alternate Contact"
    assert resp.json()["data"]["is_mobile_verified"] is False
    assert resp.json()["data"]["status"] == "ACTIVE"

    # 2. Get list of guardians
    resp_list = await client.get(f"/api/v1/guardians?school_id={school_id}", headers=headers)
    assert resp_list.status_code == 200
    assert len(resp_list.json()["data"]) >= 1

    # 3. Get guardian details
    resp_get = await client.get(f"/api/v1/guardians/{guardian_id}?school_id={school_id}", headers=headers)
    assert resp_get.status_code == 200
    assert resp_get.json()["data"]["email"] == "alincoln@whitehouse.gov"

    # 4. Update guardian details
    update_payload = {
        "first_name": "Abe",
        "is_mobile_verified": True,
        "status": "INACTIVE"
    }
    resp_put = await client.put(f"/api/v1/guardians/{guardian_id}?school_id={school_id}", json=update_payload, headers=headers)
    assert resp_put.status_code == 200
    assert resp_put.json()["data"]["first_name"] == "Abe"
    assert resp_put.json()["data"]["is_mobile_verified"] is True
    assert resp_put.json()["data"]["status"] == "INACTIVE"
    assert resp_put.json()["data"]["is_active"] is False

    # 5. Delete guardian profile
    resp_del = await client.delete(f"/api/v1/guardians/{guardian_id}?school_id={school_id}", headers=headers)
    assert resp_del.status_code == 200
    assert resp_del.json()["data"]["deleted_at"] is not None

    # Verify soft-deleted guardian is omitted from fetch
    resp_del_get = await client.get(f"/api/v1/guardians/{guardian_id}?school_id={school_id}", headers=headers)
    assert resp_del_get.status_code == 404

@pytest.mark.anyio
async def test_guardian_business_validations(client: AsyncClient, setup_guardian_test_data, db_session) -> None:
    """
    Verifies Guardian business validations:
    - Duplicate Mobile, Email, Aadhaar, PAN boundary checks
    - DOB in future verification
    """
    data = setup_guardian_test_data
    school_id = data["school_a"].id
    headers = data["auth_headers"]

    # Pre-create guardian
    payload_a = {
        "school_id": str(school_id),
        "guardian_type": "MOTHER",
        "first_name": "Mary",
        "last_name": "Lincoln",
        "gender": "FEMALE",
        "date_of_birth": "1982-05-10",
        "aadhaar_number": "999988887777",
        "pan_number": "XYZAB1234C",
        "mobile": "+919900001111",
        "email": "mary@whitehouse.gov"
    }
    resp = await client.post("/api/v1/guardians", json=payload_a, headers=headers)
    assert resp.status_code == 201

    # 1. Duplicate Mobile
    payload_dup_mob = {**payload_a, "aadhaar_number": "111122223333", "pan_number": "DEFGH1234F", "email": "mary2@whitehouse.gov"}
    resp = await client.post("/api/v1/guardians", json=payload_dup_mob, headers=headers)
    assert resp.status_code == 409

    # 2. Duplicate Email
    payload_dup_email = {**payload_a, "mobile": "+919900002222", "aadhaar_number": "111122223333", "pan_number": "DEFGH1234F"}
    resp = await client.post("/api/v1/guardians", json=payload_dup_email, headers=headers)
    assert resp.status_code == 409

    # 3. Duplicate Aadhaar
    payload_dup_aadhaar = {**payload_a, "mobile": "+919900002222", "pan_number": "DEFGH1234F", "email": "mary2@whitehouse.gov"}
    resp = await client.post("/api/v1/guardians", json=payload_dup_aadhaar, headers=headers)
    assert resp.status_code == 409

    # 4. Duplicate PAN
    payload_dup_pan = {**payload_a, "mobile": "+919900002222", "aadhaar_number": "111122223333", "email": "mary2@whitehouse.gov"}
    resp = await client.post("/api/v1/guardians", json=payload_dup_pan, headers=headers)
    assert resp.status_code == 409

    # 5. Invalid DOB in future
    payload_future_dob = {**payload_a, "mobile": "+919900002222", "aadhaar_number": "111122223333", "pan_number": "DEFGH1234F", "email": "mary2@whitehouse.gov", "date_of_birth": "2030-01-01"}
    resp = await client.post("/api/v1/guardians", json=payload_future_dob, headers=headers)
    assert resp.status_code == 422

@pytest.mark.anyio
async def test_student_guardian_mapping_flow(client: AsyncClient, setup_guardian_test_data, db_session) -> None:
    """
    Verifies student guardian mapping logic:
    - Maps guardian to sibling students
    - Validates only one primary guardian per student
    - Prevents duplicate mappings
    - Allows listing mapping configurations
    - Deletes mapping configurations
    """
    data = setup_guardian_test_data
    school_id = data["school_a"].id
    student_a1 = data["student_a1"].id
    student_a2 = data["student_a2"].id
    headers = data["auth_headers"]

    # Register Guardian
    payload_g = {
        "school_id": str(school_id),
        "guardian_type": "FATHER",
        "first_name": "Thomas",
        "last_name": "Lincoln",
        "gender": "MALE",
        "date_of_birth": "1978-01-01",
        "mobile": "+918877112233"
    }
    resp_g = await client.post("/api/v1/guardians", json=payload_g, headers=headers)
    guardian_id = resp_g.json()["data"]["id"]

    # Register Secondary Guardian
    payload_g2 = {**payload_g, "mobile": "+918877112244", "first_name": "Sarah"}
    resp_g2 = await client.post("/api/v1/guardians", json=payload_g2, headers=headers)
    guardian_id2 = resp_g2.json()["data"]["id"]

    # 1. Map Student 1 to Guardian 1 as Primary -> SUCCEEDS
    payload_map1 = {
        "school_id": str(school_id),
        "student_id": str(student_a1),
        "guardian_id": str(guardian_id),
        "relationship": "FATHER",
        "is_primary": True
    }
    resp_map1 = await client.post("/api/v1/student-guardians", json=payload_map1, headers=headers)
    assert resp_map1.status_code == 201
    map_id = resp_map1.json()["data"]["id"]
    assert resp_map1.json()["data"]["is_primary"] is True

    # 2. Map Sibling (Student 2) to Guardian 1 as Primary -> SUCCEEDS (guardian shared by siblings)
    payload_map2 = {
        "school_id": str(school_id),
        "student_id": str(student_a2),
        "guardian_id": str(guardian_id),
        "relationship": "FATHER",
        "is_primary": True
    }
    resp_map2 = await client.post("/api/v1/student-guardians", json=payload_map2, headers=headers)
    assert resp_map2.status_code == 201

    # 3. Try mapping Student 1 to Guardian 2 as Primary -> FAILS (Primary already exists)
    payload_map_fail = {
        "school_id": str(school_id),
        "student_id": str(student_a1),
        "guardian_id": str(guardian_id2),
        "relationship": "GUARDIAN",
        "is_primary": True
    }
    resp_map_fail = await client.post("/api/v1/student-guardians", json=payload_map_fail, headers=headers)
    assert resp_map_fail.status_code == 400

    # 4. Try mapping Student 1 to Guardian 2 as Non-Primary -> SUCCEEDS
    payload_map_non_prim = {**payload_map_fail, "is_primary": False}
    resp_map_non_prim = await client.post("/api/v1/student-guardians", json=payload_map_non_prim, headers=headers)
    assert resp_map_non_prim.status_code == 201
    map_id_non = resp_map_non_prim.json()["data"]["id"]

    # 5. Try mapping Student 1 to Guardian 1 again -> FAILS (Duplicate mapping prevention)
    resp_dup = await client.post("/api/v1/student-guardians", json=payload_map1, headers=headers)
    assert resp_dup.status_code == 409

    # 6. List student guardians
    resp_list = await client.get(f"/api/v1/student-guardians?student_id={student_a1}", headers=headers)
    assert resp_list.status_code == 200
    assert len(resp_list.json()["data"]) == 2

    # 7. Remove secondary mapping
    resp_del = await client.delete(f"/api/v1/student-guardians/{map_id_non}?school_id={school_id}", headers=headers)
    assert resp_del.status_code == 200
    assert resp_del.json()["data"]["deleted_at"] is not None

@pytest.mark.anyio
async def test_guardian_fuzzy_searches(client: AsyncClient, setup_guardian_test_data, db_session) -> None:
    """
    Verifies fuzzy searching filters matches correctly on roll code, Aadhaar, PAN.
    """
    data = setup_guardian_test_data
    school_id = data["school_a"].id
    headers = data["auth_headers"]

    payload = {
        "school_id": str(school_id),
        "guardian_type": "OTHER",
        "first_name": "FuzzyG",
        "last_name": "SearchG",
        "gender": "OTHER",
        "date_of_birth": "1980-01-01",
        "aadhaar_number": "888877776666",
        "pan_number": "FGHJK1234D",
        "mobile": "+918888000022"
    }
    resp = await client.post("/api/v1/guardians", json=payload, headers=headers)
    assert resp.status_code == 201

    # Search Aadhaar
    resp_aadhaar = await client.get(f"/api/v1/guardians?school_id={school_id}&search=88887777", headers=headers)
    assert resp_aadhaar.status_code == 200
    assert len(resp_aadhaar.json()["data"]) == 1

    # Search PAN
    resp_pan = await client.get(f"/api/v1/guardians?school_id={school_id}&search=FGHJK", headers=headers)
    assert resp_pan.status_code == 200
    assert len(resp_pan.json()["data"]) == 1

@pytest.mark.anyio
async def test_guardian_tenant_isolation(client: AsyncClient, setup_guardian_test_data, db_session) -> None:
    """
    Verifies that Guardian profiles remain isolated within tenant boundaries.
    """
    data = setup_guardian_test_data
    school_b = data["school_b"].id
    headers_a = data["auth_headers"]

    # Pre-create guardian under Tenant B
    repo_g = GuardianRepository(db_session)
    g_b = await repo_g.create(
        tenant_id=data["tenant_b"].id,
        obj_in=GuardianCreate(
            school_id=school_b,
            guardian_type=GuardianType.MOTHER,
            first_name="Isolated",
            last_name="TenantB",
            gender=StudentGender.FEMALE,
            date_of_birth=date(1985, 1, 1),
            mobile="+917766554433"
        )
    )
    await db_session.commit()

    # Tenant A attempts to fetch Tenant B's guardian details -> should fail with 401/404
    resp = await client.get(f"/api/v1/guardians/{g_b.id}?school_id={school_b}", headers=headers_a)
    assert resp.status_code in [401, 404]

    # Tenant A attempts to list guardians under School B -> returns empty list 200 OK
    resp_list = await client.get(f"/api/v1/guardians?school_id={school_b}", headers=headers_a)
    assert resp_list.status_code == 200
    assert len(resp_list.json()["data"]) == 0

@pytest.mark.anyio
async def test_guardian_concurrency_control_occ(setup_guardian_test_data, db_session) -> None:
    """
    Verifies optimistic concurrency locking on Guardians.
    """
    from sqlalchemy.ext.asyncio import async_sessionmaker
    from sqlalchemy.orm.exc import StaleDataError

    data = setup_guardian_test_data
    school_id = data["school_a"].id
    tenant_id = data["tenant_a"].id

    # 1. Create guardian in Session A
    repo_a = GuardianRepository(db_session)
    g_obj = await repo_a.create(
        tenant_id=tenant_id,
        obj_in=GuardianCreate(
            school_id=school_id,
            guardian_type=GuardianType.UNCLE,
            first_name="Concur",
            last_name="Uncle",
            gender=StudentGender.MALE,
            date_of_birth=date(1980, 1, 1),
            mobile="+919999888877"
        )
    )
    await repo_a.db.commit()
    await repo_a.db.refresh(g_obj)
    assert g_obj.version == 1

    # 2. Load guardian in Session B
    async_session_b = async_sessionmaker(
        bind=db_session.bind,
        class_=AsyncSession,
        expire_on_commit=False
    )
    async with async_session_b() as session_b:
        repo_b = GuardianRepository(session_b)
        g_obj_b = await repo_b.get_by_id(g_obj.id, school_id, tenant_id)
        assert g_obj_b.version == 1

        # 3. Modify and commit in Session A
        g_obj.first_name = "Concur A"
        await repo_a.db.commit()
        await repo_a.db.refresh(g_obj)
        assert g_obj.version == 2

        # 4. Attempt update in Session B -> should raise StaleDataError
        g_obj_b.first_name = "Concur B"
        with pytest.raises(StaleDataError):
            await repo_b.db.commit()

        await repo_b.db.close()
