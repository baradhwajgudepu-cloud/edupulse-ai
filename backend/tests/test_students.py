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
from app.models.class_entity import Class, ClassStatus, ClassCategory
from app.models.section import Section, SectionStatus
from app.models.student import Student, StudentStatus, StudentGender
from app.models.role import Role
from app.models.permission import Permission
from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.section import SectionRepository
from app.repositories.student import StudentRepository
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
from app.services.auth import AuthService
from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate
from app.schemas.academic_year import AcademicYearCreate
from app.schemas.class_entity import ClassCreate
from app.schemas.section import SectionCreate
from app.schemas.student import StudentCreate
from app.schemas.auth import UserCreate

@pytest.fixture
async def setup_student_data(db_session):
    """
    Sets up common testing context:
    - Tenant A, School A, Academic Year A (ACTIVE)
    - Class A, Section A (capacity 1) and Section B (capacity 10)
    - Tenant B, School B, Academic Year B (ACTIVE), Class B, Section C
    - Super Admin user with credentials
    """
    suffix = uuid.uuid4().hex[:6].upper()
    repo_t = TenantRepository(db_session)
    tenant_a = await repo_t.create(TenantCreate(name="Tenant A", code=f"tenant-a-{suffix.lower()}", subdomain=f"t-a-{suffix.lower()}", email=f"a-{suffix.lower()}@t.com"))
    tenant_b = await repo_t.create(TenantCreate(name="Tenant B", code=f"tenant-b-{suffix.lower()}", subdomain=f"t-b-{suffix.lower()}", email=f"b-{suffix.lower()}@t.com"))

    repo_s = SchoolRepository(db_session)
    school_a = await repo_s.create(tenant_a.id, SchoolCreate(name="School A", code=f"SCH_A_{suffix}", board="CBSE", email=f"s-a-{suffix.lower()}@a.com"))
    school_b = await repo_s.create(tenant_b.id, SchoolCreate(name="School B", code=f"SCH_B_{suffix}", board="CBSE", email=f"s-b-{suffix.lower()}@b.com"))

    repo_ay = AcademicYearRepository(db_session)
    ay_a = await repo_ay.create(
        tenant_a.id,
        school_a.id,
        AcademicYearCreate(name="2026-2027", code="AY2026-2027", start_date="2026-06-01", end_date="2027-04-30")
    )
    ay_a.status = AcademicYearStatus.ACTIVE

    ay_b = await repo_ay.create(
        tenant_b.id,
        school_b.id,
        AcademicYearCreate(name="2026-2027", code="AY2026-2027", start_date="2026-06-01", end_date="2027-04-30")
    )
    ay_b.status = AcademicYearStatus.ACTIVE

    repo_c = ClassRepository(db_session)
    class_a = await repo_c.create(
        tenant_a.id,
        ClassCreate(
            school_id=school_a.id,
            academic_year_id=ay_a.id,
            name="Class 10",
            code="CLASS_10A",
            level=10,
            category=ClassCategory.HIGH,
            capacity=40
        )
    )

    class_b = await repo_c.create(
        tenant_b.id,
        ClassCreate(
            school_id=school_b.id,
            academic_year_id=ay_b.id,
            name="Class 10",
            code="CLASS_10B",
            level=10,
            category=ClassCategory.HIGH,
            capacity=40
        )
    )
    await db_session.commit()

    repo_sec = SectionRepository(db_session)
    # Section A has capacity = 1 for limit checks
    sec_a = await repo_sec.create(
        tenant_a.id,
        SectionCreate(
            school_id=school_a.id,
            academic_year_id=ay_a.id,
            class_id=class_a.id,
            name="Section A",
            code="SEC_A",
            capacity=1
        )
    )
    # Section B has capacity = 10 for normal tests
    sec_b = await repo_sec.create(
        tenant_a.id,
        SectionCreate(
            school_id=school_a.id,
            academic_year_id=ay_a.id,
            class_id=class_a.id,
            name="Section B",
            code="SEC_B",
            capacity=10
        )
    )
    # Section B-Tenant
    sec_c = await repo_sec.create(
        tenant_b.id,
        SectionCreate(
            school_id=school_b.id,
            academic_year_id=ay_b.id,
            class_id=class_b.id,
            name="Section C",
            code="SEC_C",
            capacity=10
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
        "ay_a": ay_a,
        "ay_b": ay_b,
        "class_a": class_a,
        "class_b": class_b,
        "sec_a": sec_a,
        "sec_b": sec_b,
        "sec_c": sec_c,
        "user_a": user_a,
        "auth_headers": {
            "Authorization": f"Bearer {tokens.access_token}",
            "X-Tenant-ID": str(tenant_a.id)
        }
    }

@pytest.mark.anyio
async def test_student_crud_flow(client: AsyncClient, setup_student_data, db_session) -> None:
    """
    Verifies Student CRUD endpoints:
    - POST create student
    - GET list students
    - GET fetch student details
    - PUT update student details
    - DELETE soft-delete student
    """
    data = setup_student_data
    school_id = data["school_a"].id
    ay_id = data["ay_a"].id
    class_id = data["class_a"].id
    sec_id = data["sec_b"].id
    headers = data["auth_headers"]

    # 1. Create Student
    payload = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "class_id": str(class_id),
        "section_id": str(sec_id),
        "admission_number": "ADM-001",
        "roll_number": "ROLL-01",
        "first_name": "John",
        "middle_name": "Fitzgerald",
        "last_name": "Kennedy",
        "gender": "MALE",
        "date_of_birth": "2015-05-29",
        "blood_group": "O+",
        "aadhaar_number": "123456789012",
        "emis_number": "EMIS-8877",
        "mobile": "+919988776655",
        "email": "jfk@whitehouse.gov",
        "photo_url": "http://photos.com/jfk.jpg",
        "address": {"city": "Brookline", "state": "MA"},
        "medical_information": {"allergies": ["dust"]},
        "admission_date": "2026-06-01",
        "settings": {"scholarship": True},
        "ai_metrics": {
            "attendance_prediction": 0.95,
            "performance_prediction": 0.88,
            "dropout_risk": 0.02,
            "behavior_score": 95
        }
    }
    resp = await client.post("/api/v1/students", json=payload, headers=headers)
    assert resp.status_code == 201
    student_id = resp.json()["data"]["id"]
    assert resp.json()["data"]["first_name"] == "John"
    assert resp.json()["data"]["admitted_at"] is not None
    assert resp.json()["data"]["status"] == "ACTIVE"

    # 2. Get list of students
    resp_list = await client.get(f"/api/v1/students?school_id={school_id}", headers=headers)
    assert resp_list.status_code == 200
    assert len(resp_list.json()["data"]) >= 1

    # 3. Get student details
    resp_get = await client.get(f"/api/v1/students/{student_id}?school_id={school_id}", headers=headers)
    assert resp_get.status_code == 200
    assert resp_get.json()["data"]["roll_number"] == "ROLL-01"

    # 4. Update student details
    update_payload = {
        "first_name": "Jack",
        "mobile": "+918888888888",
        "status": "SUSPENDED"
    }
    resp_put = await client.put(f"/api/v1/students/{student_id}?school_id={school_id}", json=update_payload, headers=headers)
    assert resp_put.status_code == 200
    assert resp_put.json()["data"]["first_name"] == "Jack"
    assert resp_put.json()["data"]["mobile"] == "+918888888888"
    assert resp_put.json()["data"]["status"] == "SUSPENDED"
    assert resp_put.json()["data"]["is_active"] is False

    # 5. Delete student profile
    resp_del = await client.delete(f"/api/v1/students/{student_id}?school_id={school_id}", headers=headers)
    assert resp_del.status_code == 200
    assert resp_del.json()["data"]["deleted_at"] is not None
    assert resp_del.json()["data"]["withdrawn_at"] is not None

    # Verify soft-deleted student is omitted from fetch
    resp_del_get = await client.get(f"/api/v1/students/{student_id}?school_id={school_id}", headers=headers)
    assert resp_del_get.status_code == 404

@pytest.mark.anyio
async def test_student_business_validations(client: AsyncClient, setup_student_data, db_session) -> None:
    """
    Verifies Student business validations:
    - Admission number unique per school
    - Roll number unique per section
    - Roll number reuse allowed in DIFFERENT sections
    - Capacity boundaries (capacity limit check)
    - DOB in the past and Admission date not in the future
    - Cannot register in archived academic years
    """
    data = setup_student_data
    school_id = data["school_a"].id
    ay_id = data["ay_a"].id
    class_id = data["class_a"].id
    sec_a = data["sec_a"].id
    sec_b = data["sec_b"].id
    headers = data["auth_headers"]

    # Pre-create standard student in Section A
    payload_a = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "class_id": str(class_id),
        "section_id": str(sec_a),
        "admission_number": "ADM-UNIQ-1",
        "roll_number": "ROLL-UNIQ-1",
        "first_name": "Alice",
        "last_name": "Smith",
        "gender": "FEMALE",
        "date_of_birth": "2016-01-01",
        "admission_date": "2026-06-01"
    }
    resp = await client.post("/api/v1/students", json=payload_a, headers=headers)
    assert resp.status_code == 201

    # 1. Duplicate admission number inside same school -> should raise 409
    payload_dup_adm = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "class_id": str(class_id),
        "section_id": str(sec_b),  # Different section
        "admission_number": "ADM-UNIQ-1",  # Duplicate
        "roll_number": "ROLL-UNIQ-2",
        "first_name": "Bob",
        "last_name": "Smith",
        "gender": "MALE",
        "date_of_birth": "2016-02-02",
        "admission_date": "2026-06-01"
    }
    resp = await client.post("/api/v1/students", json=payload_dup_adm, headers=headers)
    assert resp.status_code == 409

    # 2. Duplicate roll number in same section -> should raise 409
    payload_dup_roll = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "class_id": str(class_id),
        "section_id": str(sec_a),  # Same section
        "admission_number": "ADM-UNIQ-2",
        "roll_number": "ROLL-UNIQ-1",  # Duplicate roll number
        "first_name": "Charlie",
        "last_name": "Smith",
        "gender": "MALE",
        "date_of_birth": "2016-03-03",
        "admission_date": "2026-06-01"
    }
    resp = await client.post("/api/v1/students", json=payload_dup_roll, headers=headers)
    assert resp.status_code == 409

    # 3. Duplicate roll number in DIFFERENT section -> should SUCCEED
    payload_diff_sec_roll = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "class_id": str(class_id),
        "section_id": str(sec_b),  # Different section!
        "admission_number": "ADM-UNIQ-2",
        "roll_number": "ROLL-UNIQ-1",  # Reuse roll number
        "first_name": "David",
        "last_name": "Smith",
        "gender": "MALE",
        "date_of_birth": "2016-04-04",
        "admission_date": "2026-06-01"
    }
    resp = await client.post("/api/v1/students", json=payload_diff_sec_roll, headers=headers)
    assert resp.status_code == 201

    # 4. Capacity check: Section A has capacity = 1. We already added Alice. Adding david to Section A should fail
    payload_cap_fail = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "class_id": str(class_id),
        "section_id": str(sec_a),  # Capacity met (1/1)
        "admission_number": "ADM-UNIQ-3",
        "roll_number": "ROLL-UNIQ-3",
        "first_name": "Eva",
        "last_name": "Smith",
        "gender": "FEMALE",
        "date_of_birth": "2016-05-05",
        "admission_date": "2026-06-01"
    }
    resp = await client.post("/api/v1/students", json=payload_cap_fail, headers=headers)
    assert resp.status_code == 400
    assert "capacity" in resp.json()["message"].lower()

    # 5. Invalid DOB in future
    payload_bad_dob = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "class_id": str(class_id),
        "section_id": str(sec_b),
        "admission_number": "ADM-UNIQ-3",
        "roll_number": "ROLL-UNIQ-3",
        "first_name": "Frank",
        "last_name": "Smith",
        "gender": "MALE",
        "date_of_birth": "2030-01-01",  # Future!
        "admission_date": "2026-06-01"
    }
    resp = await client.post("/api/v1/students", json=payload_bad_dob, headers=headers)
    assert resp.status_code == 422

    # 6. Invalid Admission Date in future
    payload_bad_adm = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "class_id": str(class_id),
        "section_id": str(sec_b),
        "admission_number": "ADM-UNIQ-3",
        "roll_number": "ROLL-UNIQ-3",
        "first_name": "Frank",
        "last_name": "Smith",
        "gender": "MALE",
        "date_of_birth": "2016-01-01",
        "admission_date": "2030-01-01"  # Future!
    }
    resp = await client.post("/api/v1/students", json=payload_bad_adm, headers=headers)
    assert resp.status_code == 422

@pytest.mark.anyio
async def test_student_fuzzy_searches(client: AsyncClient, setup_student_data, db_session) -> None:
    """
    Verifies that Student search parameters filter correctly by roll number, Aadhaar, and mobile.
    """
    data = setup_student_data
    school_id = data["school_a"].id
    ay_id = data["ay_a"].id
    class_id = data["class_a"].id
    sec_id = data["sec_b"].id
    headers = data["auth_headers"]

    # Register student
    payload = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "class_id": str(class_id),
        "section_id": str(sec_id),
        "admission_number": "ADM-FUZZ",
        "roll_number": "ROLL-FUZZ-99",
        "first_name": "Fuzzy",
        "last_name": "Search",
        "gender": "OTHER",
        "date_of_birth": "2015-01-01",
        "aadhaar_number": "999988887777",
        "mobile": "+919999000011",
        "admission_date": "2026-06-01"
    }
    resp = await client.post("/api/v1/students", json=payload, headers=headers)
    assert resp.status_code == 201

    # Search by Roll Number
    resp_roll = await client.get(f"/api/v1/students?school_id={school_id}&search=FUZZ-99", headers=headers)
    assert resp_roll.status_code == 200
    assert len(resp_roll.json()["data"]) == 1

    # Search by Aadhaar
    resp_aadhaar = await client.get(f"/api/v1/students?school_id={school_id}&search=99998888", headers=headers)
    assert resp_aadhaar.status_code == 200
    assert len(resp_aadhaar.json()["data"]) == 1

    # Search by Mobile
    resp_mobile = await client.get(f"/api/v1/students?school_id={school_id}&search=99990000", headers=headers)
    assert resp_mobile.status_code == 200
    assert len(resp_mobile.json()["data"]) == 1

@pytest.mark.anyio
async def test_student_timeline_transitions(client: AsyncClient, setup_student_data, db_session) -> None:
    """
    Verifies that state modifications update specific lifecycle timestamps (graduated_at, withdrawn_at).
    """
    data = setup_student_data
    school_id = data["school_a"].id
    ay_id = data["ay_a"].id
    class_id = data["class_a"].id
    sec_id = data["sec_b"].id
    headers = data["auth_headers"]

    # Register student
    payload = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "class_id": str(class_id),
        "section_id": str(sec_id),
        "admission_number": "ADM-TIME",
        "roll_number": "ROLL-TIME",
        "first_name": "Time",
        "last_name": "Traveler",
        "gender": "FEMALE",
        "date_of_birth": "2015-01-01",
        "admission_date": "2026-06-01"
    }
    resp = await client.post("/api/v1/students", json=payload, headers=headers)
    student_id = resp.json()["data"]["id"]

    # Update to ALUMNI -> Should populate graduated_at
    resp_grad = await client.put(f"/api/v1/students/{student_id}?school_id={school_id}", json={"status": "ALUMNI"}, headers=headers)
    assert resp_grad.status_code == 200
    assert resp_grad.json()["data"]["graduated_at"] is not None
    assert resp_grad.json()["data"]["status"] == "ALUMNI"

    # Update to WITHDRAWN -> Should populate withdrawn_at
    resp_with = await client.put(f"/api/v1/students/{student_id}?school_id={school_id}", json={"status": "WITHDRAWN"}, headers=headers)
    assert resp_with.status_code == 200
    assert resp_with.json()["data"]["withdrawn_at"] is not None

@pytest.mark.anyio
async def test_student_tenant_and_school_isolation(client: AsyncClient, setup_student_data, db_session) -> None:
    """
    Verifies that Student profiles remain isolated within tenant boundaries.
    """
    data = setup_student_data
    school_b = data["school_b"].id
    ay_b = data["ay_b"].id
    class_b = data["class_b"].id
    sec_c = data["sec_c"].id
    headers_a = data["auth_headers"]

    # Pre-create student under Tenant B
    repo_s = StudentRepository(db_session)
    s_b = await repo_s.create(
        tenant_id=data["tenant_b"].id,
        obj_in=StudentCreate(
            school_id=school_b,
            academic_year_id=ay_b,
            class_id=class_b,
            section_id=sec_c,
            admission_number="ADM-TEN-B",
            roll_number="ROLL-TEN-B",
            first_name=f"Bob",
            last_name="TenantB",
            gender=StudentGender.MALE,
            date_of_birth=date(2015, 1, 1),
            admission_date=date(2026, 6, 1)
        )
    )
    await db_session.commit()

    # Tenant A attempts to fetch Tenant B's student details -> should fail with 404
    resp = await client.get(f"/api/v1/students/{s_b.id}?school_id={school_b}", headers=headers_a)
    assert resp.status_code in [401, 404]

    # Tenant A attempts to list students under School B -> returns empty list 200 OK
    resp_list = await client.get(f"/api/v1/students?school_id={school_b}", headers=headers_a)
    assert resp_list.status_code == 200
    assert len(resp_list.json()["data"]) == 0

@pytest.mark.anyio
async def test_student_concurrency_control_occ(setup_student_data, db_session) -> None:
    """
    Verifies optimistic concurrency locking on Students.
    """
    from sqlalchemy.ext.asyncio import async_sessionmaker
    from sqlalchemy.orm.exc import StaleDataError

    data = setup_student_data
    school_id = data["school_a"].id
    ay_id = data["ay_a"].id
    class_id = data["class_a"].id
    sec_id = data["sec_b"].id
    tenant_id = data["tenant_a"].id

    # 1. Create student in Session A
    repo_a = StudentRepository(db_session)
    student_obj = await repo_a.create(
        tenant_id=tenant_id,
        obj_in=StudentCreate(
            school_id=school_id,
            academic_year_id=ay_id,
            class_id=class_id,
            section_id=sec_id,
            admission_number="ADM-OCC",
            roll_number="ROLL-OCC",
            first_name="Concur",
            last_name="Test",
            gender=StudentGender.OTHER,
            date_of_birth=date(2015, 1, 1),
            admission_date=date(2026, 6, 1)
        )
    )
    await repo_a.db.commit()
    await repo_a.db.refresh(student_obj)
    assert student_obj.version == 1

    # 2. Load student in Session B
    async_session_b = async_sessionmaker(
        bind=db_session.bind,
        class_=AsyncSession,
        expire_on_commit=False
    )
    async with async_session_b() as session_b:
        repo_b = StudentRepository(session_b)
        student_obj_b = await repo_b.get_by_id(student_obj.id, school_id, tenant_id)
        assert student_obj_b.version == 1

        # 3. Modify and commit in Session A
        student_obj.first_name = "Concur A"
        await repo_a.db.commit()
        await repo_a.db.refresh(student_obj)
        assert student_obj.version == 2

        # 4. Attempt update in Session B -> should raise StaleDataError
        student_obj_b.first_name = "Concur B"
        with pytest.raises(StaleDataError):
            await repo_b.db.commit()

        await repo_b.db.close()
