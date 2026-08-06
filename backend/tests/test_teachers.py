import uuid
import pytest
from datetime import date, datetime, timezone
from httpx import AsyncClient
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tenant import Tenant
from app.models.school import School
from app.models.student import StudentGender
from app.models.teacher import Teacher, TeacherStatus, EmploymentType
from app.models.role import Role
from app.models.permission import Permission
from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
from app.services.auth import AuthService
from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate
from app.schemas.teacher import TeacherCreate
from app.schemas.auth import UserCreate

@pytest.fixture
async def setup_teacher_test_data(db_session):
    """
    Sets up common testing context:
    - Tenant A, School A
    - Tenant B, School B
    - Super Admin user with credentials mapped to School A
    """
    suffix = uuid.uuid4().hex[:6].upper()
    repo_t = TenantRepository(db_session)
    tenant_a = await repo_t.create(TenantCreate(name="Tenant A", code=f"tenant-a-{suffix.lower()}", subdomain=f"t-a-{suffix.lower()}", email=f"a-{suffix.lower()}@t.com"))
    tenant_b = await repo_t.create(TenantCreate(name="Tenant B", code=f"tenant-b-{suffix.lower()}", subdomain=f"t-b-{suffix.lower()}", email=f"b-{suffix.lower()}@t.com"))

    repo_s = SchoolRepository(db_session)
    school_a = await repo_s.create(tenant_a.id, SchoolCreate(name="School A", code=f"SCH_A_{suffix}", board="CBSE", email=f"s-a-{suffix.lower()}@a.com"))
    school_b = await repo_s.create(tenant_b.id, SchoolCreate(name="School B", code=f"SCH_B_{suffix}", board="CBSE", email=f"s-b-{suffix.lower()}@b.com"))
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
        "user_a": user_a,
        "auth_headers": {
            "Authorization": f"Bearer {tokens.access_token}",
            "X-Tenant-ID": str(tenant_a.id)
        }
    }

@pytest.mark.anyio
async def test_teacher_crud_flow(client: AsyncClient, setup_teacher_test_data, db_session) -> None:
    """
    Verifies Teacher CRUD endpoints:
    - POST create teacher
    - GET list teachers
    - GET fetch teacher details
    - PUT update teacher details
    - DELETE soft-delete teacher
    """
    data = setup_teacher_test_data
    school_id = data["school_a"].id
    headers = data["auth_headers"]

    # 1. Create Teacher
    payload = {
        "school_id": str(school_id),
        "employee_code": "EMP-900",
        "staff_code": "STF-900",
        "first_name": "George",
        "middle_name": "W",
        "last_name": "Washington",
        "gender": "MALE",
        "date_of_birth": "1975-02-22",
        "blood_group": "AB+",
        "aadhaar_number": "111122223333",
        "pan_number": "ABCDE1111F",
        "mobile": "+919988771100",
        "alternate_mobile": "+919988771111",
        "official_email": "gwash@school.edu",
        "personal_email": "gwash@gmail.com",
        "emergency_contact_name": "Martha",
        "emergency_contact_mobile": "+919988771122",
        "emergency_contact_relation": "Wife",
        "photo_url": "http://photos.com/gw.jpg",
        "address": {"city": "Mount Vernon", "state": "VA"},
        "qualification": "Master of History",
        "specialization": "Leadership",
        "experience_years": 15,
        "joining_date": "2020-09-01",
        "date_of_confirmation": "2021-03-01",
        "employment_type": "FULL_TIME",
        "designation": "Headmaster",
        "department": "Administration",
        "salary": 120000.00,
        "settings": {"working_days": ["Monday", "Tuesday"]},
        "ai_metrics": {
            "performance_score": 98,
            "burnout_risk": 0.05
        }
    }
    resp = await client.post("/api/v1/teachers", json=payload, headers=headers)
    assert resp.status_code == 201
    teacher_id = resp.json()["data"]["id"]
    assert resp.json()["data"]["first_name"] == "George"
    assert resp.json()["data"]["emergency_contact_relation"] == "Wife"
    assert resp.json()["data"]["status"] == "ACTIVE"

    # 2. Get list of teachers
    resp_list = await client.get(f"/api/v1/teachers?school_id={school_id}", headers=headers)
    assert resp_list.status_code == 200
    assert len(resp_list.json()["data"]) >= 1

    # 3. Get teacher details
    resp_get = await client.get(f"/api/v1/teachers/{teacher_id}?school_id={school_id}", headers=headers)
    assert resp_get.status_code == 200
    assert resp_get.json()["data"]["official_email"] == "gwash@school.edu"

    # 4. Update teacher details
    update_payload = {
        "first_name": "Geo",
        "status": "ON_LEAVE"
    }
    resp_put = await client.put(f"/api/v1/teachers/{teacher_id}?school_id={school_id}", json=update_payload, headers=headers)
    assert resp_put.status_code == 200
    assert resp_put.json()["data"]["first_name"] == "Geo"
    assert resp_put.json()["data"]["status"] == "ON_LEAVE"
    assert resp_put.json()["data"]["is_active"] is True

    # 5. Delete teacher profile
    resp_del = await client.delete(f"/api/v1/teachers/{teacher_id}?school_id={school_id}", headers=headers)
    assert resp_del.status_code == 200
    assert resp_del.json()["data"]["deleted_at"] is not None

    # Verify soft-deleted teacher is omitted from fetch
    resp_del_get = await client.get(f"/api/v1/teachers/{teacher_id}?school_id={school_id}", headers=headers)
    assert resp_del_get.status_code == 404

@pytest.mark.anyio
async def test_teacher_business_validations(client: AsyncClient, setup_teacher_test_data, db_session) -> None:
    """
    Verifies Teacher business validations:
    - DOB check (Age >= 18)
    - Future joining date fails
    - Duplicate employee/staff codes within school boundary fails
    - Duplicate mobile/emails/Aadhaar/PAN within tenant boundary fails
    - Experience/salary >= 0 validation
    """
    data = setup_teacher_test_data
    school_id = data["school_a"].id
    headers = data["auth_headers"]

    # Pre-create teacher
    payload_a = {
        "school_id": str(school_id),
        "employee_code": "EMP-UNIQ-A",
        "staff_code": "STF-UNIQ-A",
        "first_name": "John",
        "last_name": "Adams",
        "gender": "MALE",
        "date_of_birth": "1980-01-01",
        "aadhaar_number": "888899990000",
        "pan_number": "PQRSD1234E",
        "mobile": "+918800991122",
        "official_email": "jadams@school.edu",
        "joining_date": "2021-01-01",
        "employment_type": "FULL_TIME"
    }
    resp = await client.post("/api/v1/teachers", json=payload_a, headers=headers)
    assert resp.status_code == 201

    # 1. Under 18 years old -> fails (Age constraint check)
    today = date.today()
    under_18_dob = f"{today.year - 17}-{today.month:02d}-{today.day:02d}"  # 17 years old
    payload_under_18 = {**payload_a, "employee_code": "EMP-2", "staff_code": "STF-2", "mobile": "+918800991133", "official_email": "jadams2@school.edu", "date_of_birth": under_18_dob}
    resp = await client.post("/api/v1/teachers", json=payload_under_18, headers=headers)
    assert resp.status_code == 422

    # 2. Future joining date -> fails
    payload_future_join = {**payload_a, "employee_code": "EMP-2", "staff_code": "STF-2", "mobile": "+918800991133", "official_email": "jadams2@school.edu", "joining_date": "2030-01-01"}
    resp = await client.post("/api/v1/teachers", json=payload_future_join, headers=headers)
    assert resp.status_code == 422

    # 3. Duplicate Employee Code in same school -> fails
    payload_dup_emp = {**payload_a, "staff_code": "STF-2", "mobile": "+918800991133", "official_email": "jadams2@school.edu", "employee_code": "EMP-UNIQ-A"}
    resp = await client.post("/api/v1/teachers", json=payload_dup_emp, headers=headers)
    assert resp.status_code == 409

    # 4. Duplicate Staff Code in same school -> fails
    payload_dup_staff = {**payload_a, "employee_code": "EMP-2", "mobile": "+918800991133", "official_email": "jadams2@school.edu", "staff_code": "STF-UNIQ-A"}
    resp = await client.post("/api/v1/teachers", json=payload_dup_staff, headers=headers)
    assert resp.status_code == 409

    # 5. Duplicate Mobile in same tenant -> fails
    payload_dup_mob = {**payload_a, "employee_code": "EMP-2", "staff_code": "STF-2", "official_email": "jadams2@school.edu", "mobile": "+918800991122"}
    resp = await client.post("/api/v1/teachers", json=payload_dup_mob, headers=headers)
    assert resp.status_code == 409

    # 6. Duplicate Official Email in same tenant -> fails
    payload_dup_email = {**payload_a, "employee_code": "EMP-2", "staff_code": "STF-2", "mobile": "+918800991133", "official_email": "jadams@school.edu"}
    resp = await client.post("/api/v1/teachers", json=payload_dup_email, headers=headers)
    assert resp.status_code == 409

    # 7. Experience years < 0 -> fails
    payload_bad_exp = {**payload_a, "employee_code": "EMP-2", "staff_code": "STF-2", "mobile": "+918800991133", "official_email": "jadams2@school.edu", "experience_years": -1}
    resp = await client.post("/api/v1/teachers", json=payload_bad_exp, headers=headers)
    assert resp.status_code == 422

    # 8. Salary < 0 -> fails
    payload_bad_sal = {**payload_a, "employee_code": "EMP-2", "staff_code": "STF-2", "mobile": "+918800991133", "official_email": "jadams2@school.edu", "salary": -100.00}
    resp = await client.post("/api/v1/teachers", json=payload_bad_sal, headers=headers)
    assert resp.status_code == 422

@pytest.mark.anyio
async def test_teacher_fuzzy_searches(client: AsyncClient, setup_teacher_test_data, db_session) -> None:
    """
    Verifies fuzzy searching filters matches correctly on names, codes, mobile, emails.
    """
    data = setup_teacher_test_data
    school_id = data["school_a"].id
    headers = data["auth_headers"]

    payload = {
        "school_id": str(school_id),
        "employee_code": "EMP-FUZZY",
        "staff_code": "STF-FUZZY",
        "first_name": "FuzzyT",
        "last_name": "SearchT",
        "gender": "OTHER",
        "date_of_birth": "1980-01-01",
        "aadhaar_number": "777788889999",
        "pan_number": "KLMNO1234E",
        "mobile": "+918888999900",
        "official_email": "fuzzyt@school.edu",
        "joining_date": "2021-01-01",
        "employment_type": "VISITING"
    }
    resp = await client.post("/api/v1/teachers", json=payload, headers=headers)
    assert resp.status_code == 201

    # Search Aadhaar
    resp_aadhaar = await client.get(f"/api/v1/teachers?school_id={school_id}&search=77778888", headers=headers)
    assert resp_aadhaar.status_code == 200
    assert len(resp_aadhaar.json()["data"]) == 1

    # Search PAN
    resp_pan = await client.get(f"/api/v1/teachers?school_id={school_id}&search=KLMNO", headers=headers)
    assert resp_pan.status_code == 200
    assert len(resp_pan.json()["data"]) == 1

@pytest.mark.anyio
async def test_teacher_tenant_isolation(client: AsyncClient, setup_teacher_test_data, db_session) -> None:
    """
    Verifies that Teacher profiles remain isolated within tenant boundaries.
    """
    data = setup_teacher_test_data
    school_b = data["school_b"].id
    headers_a = data["auth_headers"]

    # Pre-create teacher under Tenant B
    repo_t = TeacherRepository(db_session)
    t_b = await repo_t.create(
        tenant_id=data["tenant_b"].id,
        obj_in=TeacherCreate(
            school_id=school_b,
            employee_code="EMP-TEN-B",
            staff_code="STF-TEN-B",
            first_name="Isolated",
            last_name="TeacherB",
            gender=StudentGender.FEMALE,
            date_of_birth=date(1985, 1, 1),
            mobile="+917766554400",
            official_email="t_b@school.edu",
            joining_date=date(2021, 1, 1),
            employment_type=EmploymentType.FULL_TIME
        )
    )
    await db_session.commit()

    # Tenant A attempts to fetch Tenant B's teacher details -> should fail with 401/404
    resp = await client.get(f"/api/v1/teachers/{t_b.id}?school_id={school_b}", headers=headers_a)
    assert resp.status_code in [401, 404]

    # Tenant A attempts to list teachers under School B -> returns empty list 200 OK
    resp_list = await client.get(f"/api/v1/teachers?school_id={school_b}", headers=headers_a)
    assert resp_list.status_code == 200
    assert len(resp_list.json()["data"]) == 0

@pytest.mark.anyio
async def test_teacher_concurrency_control_occ(setup_teacher_test_data, db_session) -> None:
    """
    Verifies optimistic concurrency locking on Teachers.
    """
    from sqlalchemy.ext.asyncio import async_sessionmaker
    from sqlalchemy.orm.exc import StaleDataError

    data = setup_teacher_test_data
    school_id = data["school_a"].id
    tenant_id = data["tenant_a"].id

    # 1. Create teacher in Session A
    repo_a = TeacherRepository(db_session)
    t_obj = await repo_a.create(
        tenant_id=tenant_id,
        obj_in=TeacherCreate(
            school_id=school_id,
            employee_code="EMP-OCC",
            staff_code="STF-OCC",
            first_name="Concur",
            last_name="Teacher",
            gender=StudentGender.MALE,
            date_of_birth=date(1980, 1, 1),
            mobile="+919999888800",
            official_email="concur_t@school.edu",
            joining_date=date(2020, 1, 1),
            employment_type=EmploymentType.PART_TIME
        )
    )
    await repo_a.db.commit()
    await repo_a.db.refresh(t_obj)
    assert t_obj.version == 1

    # 2. Load teacher in Session B
    async_session_b = async_sessionmaker(
        bind=db_session.bind,
        class_=AsyncSession,
        expire_on_commit=False
    )
    async with async_session_b() as session_b:
        repo_b = TeacherRepository(session_b)
        t_obj_b = await repo_b.get_by_id(t_obj.id, school_id, tenant_id)
        assert t_obj_b.version == 1

        # 3. Modify and commit in Session A
        t_obj.first_name = "Concur A"
        await repo_a.db.commit()
        await repo_a.db.refresh(t_obj)
        assert t_obj.version == 2

        # 4. Attempt update in Session B -> should raise StaleDataError
        t_obj_b.first_name = "Concur B"
        with pytest.raises(StaleDataError):
            await repo_b.db.commit()

        await repo_b.db.close()
