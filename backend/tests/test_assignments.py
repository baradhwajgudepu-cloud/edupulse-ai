import uuid
import pytest
from datetime import date, datetime, timezone, timedelta
from httpx import AsyncClient
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tenant import Tenant
from app.models.school import School
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.class_entity import Class, ClassCategory, ClassStatus
from app.models.section import Section
from app.models.teacher import Teacher, TeacherStatus, EmploymentType
from app.models.subject import Subject, SubjectStatus, SubjectCategory, SubjectType
from app.models.student import StudentGender
from app.models.teacher_subject_assignment import TeacherSubjectAssignment, AssignmentStatus, AssignmentType
from app.models.role import Role
from app.models.permission import Permission
from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.section import SectionRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.subject import SubjectRepository
from app.repositories.teacher_subject_assignment import TeacherSubjectAssignmentRepository
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
from app.services.auth import AuthService
from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate
from app.schemas.academic_year import AcademicYearCreate
from app.schemas.class_entity import ClassCreate
from app.schemas.section import SectionCreate
from app.schemas.teacher import TeacherCreate
from app.schemas.subject import SubjectCreate
from app.schemas.teacher_subject_assignment import TeacherSubjectAssignmentCreate
from app.schemas.auth import UserCreate

@pytest.fixture
async def setup_assignment_test_data(db_session):
    """
    Sets up testing context:
    - Tenant A, School A, Academic Year A (ACTIVE)
    - Active Class A, Active Section A
    - Active Teacher A, Active Subject A (THEORY_PRACTICAL)
    - Tenant B, School B, Academic Year B
    - Super Admin user mapped to School A
    """
    suffix = uuid.uuid4().hex[:6].upper()
    repo_t = TenantRepository(db_session)
    tenant_a = await repo_t.create(TenantCreate(name="Tenant A", code=f"tenant-a-{suffix.lower()}", subdomain=f"t-a-{suffix.lower()}", email=f"a-{suffix.lower()}@t.com"))
    tenant_b = await repo_t.create(TenantCreate(name="Tenant B", code=f"tenant-b-{suffix.lower()}", subdomain=f"t-b-{suffix.lower()}", email=f"b-{suffix.lower()}@t.com"))

    repo_s = SchoolRepository(db_session)
    school_a = await repo_s.create(tenant_a.id, SchoolCreate(name="School A", code=f"SCH_A_{suffix}", board="CBSE", email=f"s-a-{suffix.lower()}@a.com"))
    school_b = await repo_s.create(tenant_b.id, SchoolCreate(name="School B", code=f"SCH_B_{suffix}", board="CBSE", email=f"s-b-{suffix.lower()}@b.com"))
    await db_session.commit()

    # Pre-create Academic Years
    repo_ay = AcademicYearRepository(db_session)
    ay_a = await repo_ay.create(
        tenant_a.id, school_a.id,
        AcademicYearCreate(name="2026", code="AY2026", start_date="2026-01-01", end_date="2026-12-31")
    )
    ay_a.status = AcademicYearStatus.ACTIVE

    ay_b = await repo_ay.create(
        tenant_b.id, school_b.id,
        AcademicYearCreate(name="2026", code="AY2026", start_date="2026-01-01", end_date="2026-12-31")
    )
    ay_b.status = AcademicYearStatus.ACTIVE
    await db_session.commit()

    # Pre-create Classes & Sections
    repo_c = ClassRepository(db_session)
    class_a = await repo_c.create(
        tenant_a.id,
        ClassCreate(school_id=school_a.id, academic_year_id=ay_a.id, name="Class 10", code="C10", level=10, category=ClassCategory.HIGH, capacity=30)
    )
    class_b = await repo_c.create(
        tenant_b.id,
        ClassCreate(school_id=school_b.id, academic_year_id=ay_b.id, name="Class 10", code="C10", level=10, category=ClassCategory.HIGH, capacity=30)
    )
    await db_session.commit()

    repo_sec = SectionRepository(db_session)
    sec_a = await repo_sec.create(
        tenant_a.id, SectionCreate(school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_a.id, name="Sec A", code="SA", capacity=30)
    )
    sec_b = await repo_sec.create(
        tenant_b.id, SectionCreate(school_id=school_b.id, academic_year_id=ay_b.id, class_id=class_b.id, name="Sec B", code="SB", capacity=30)
    )
    await db_session.commit()

    # Pre-create Teachers
    repo_t = TeacherRepository(db_session)
    teacher_a = await repo_t.create(
        tenant_id=tenant_a.id,
        obj_in=TeacherCreate(
            school_id=school_a.id, employee_code="EMP-1", staff_code="STF-1", first_name="George", last_name="Washington",
            gender=StudentGender.MALE, date_of_birth=date(1980, 1, 1), mobile="+919900112233", official_email="gwash@school.edu",
            joining_date=date(2020, 1, 1), employment_type=EmploymentType.FULL_TIME
        )
    )
    teacher_b = await repo_t.create(
        tenant_id=tenant_b.id,
        obj_in=TeacherCreate(
            school_id=school_b.id, employee_code="EMP-2", staff_code="STF-2", first_name="John", last_name="Adams",
            gender=StudentGender.MALE, date_of_birth=date(1980, 1, 1), mobile="+919900112244", official_email="jadams@school.edu",
            joining_date=date(2020, 1, 1), employment_type=EmploymentType.FULL_TIME
        )
    )
    await db_session.commit()

    # Pre-create Subjects
    repo_sub = SubjectRepository(db_session)
    subject_a = await repo_sub.create(
        tenant_id=tenant_a.id,
        obj_in=SubjectCreate(
            school_id=school_a.id, academic_year_id=ay_a.id, subject_code="PHY-101", subject_name="Physics",
            category="CORE", subject_type="THEORY_PRACTICAL", theory_marks=70, practical_marks=30, pass_marks=40
        )
    )
    subject_b = await repo_sub.create(
        tenant_id=tenant_b.id,
        obj_in=SubjectCreate(
            school_id=school_b.id, academic_year_id=ay_b.id, subject_code="PHY-101", subject_name="Physics",
            category="CORE", subject_type="THEORY_PRACTICAL", theory_marks=70, practical_marks=30, pass_marks=40
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
        "teacher_a": teacher_a,
        "teacher_b": teacher_b,
        "subject_a": subject_a,
        "subject_b": subject_b,
        "user_a": user_a,
        "auth_headers": {
            "Authorization": f"Bearer {tokens.access_token}",
            "X-Tenant-ID": str(tenant_a.id)
        }
    }

@pytest.mark.anyio
async def test_assignment_crud_flow(client: AsyncClient, setup_assignment_test_data, db_session) -> None:
    """
    Verifies CRUD flows:
    - POST create assignment
    - GET list assignments
    - GET fetch assignment details
    - PUT update assignment parameters
    - DELETE soft delete assignment
    """
    data = setup_assignment_test_data
    school_id = data["school_a"].id
    headers = data["auth_headers"]

    # 1. Create Assignment
    payload = {
        "school_id": str(school_id),
        "academic_year_id": str(data["ay_a"].id),
        "teacher_id": str(data["teacher_a"].id),
        "subject_id": str(data["subject_a"].id),
        "class_id": str(data["class_a"].id),
        "section_id": str(data["sec_a"].id),
        "assignment_type": "PRIMARY",
        "priority": 1,
        "weekly_periods": 6,
        "workload_percentage": 15.00,
        "effective_from": "2026-01-01",
        "effective_to": "2026-12-31",
        "is_class_teacher": True,
        "maximum_students": 30,
        "remarks": "Class Headwashington"
    }
    resp = await client.post("/api/v1/teacher-subject-assignments", json=payload, headers=headers)
    assert resp.status_code == 201
    assignment_id = resp.json()["data"]["id"]
    assert resp.json()["data"]["weekly_periods"] == 6
    assert resp.json()["data"]["is_class_teacher"] is True

    # 2. Get list of assignments
    resp_list = await client.get(f"/api/v1/teacher-subject-assignments?school_id={school_id}", headers=headers)
    assert resp_list.status_code == 200
    assert len(resp_list.json()["data"]) >= 1

    # 3. Get assignment details
    resp_get = await client.get(f"/api/v1/teacher-subject-assignments/{assignment_id}?school_id={school_id}", headers=headers)
    assert resp_get.status_code == 200
    assert resp_get.json()["data"]["remarks"] == "Class Headwashington"

    # 4. Update assignment parameters
    update_payload = {
        "weekly_periods": 8,
        "status": "INACTIVE"
    }
    resp_put = await client.put(f"/api/v1/teacher-subject-assignments/{assignment_id}?school_id={school_id}", json=update_payload, headers=headers)
    assert resp_put.status_code == 200
    assert resp_put.json()["data"]["weekly_periods"] == 8
    assert resp_put.json()["data"]["status"] == "INACTIVE"
    assert resp_put.json()["data"]["is_active"] is False

    # 5. Delete assignment profile (soft-delete)
    resp_del = await client.delete(f"/api/v1/teacher-subject-assignments/{assignment_id}?school_id={school_id}", headers=headers)
    assert resp_del.status_code == 200
    assert resp_del.json()["data"]["deleted_at"] is not None

    # Verify soft-deleted assignment is omitted from fetch
    resp_del_get = await client.get(f"/api/v1/teacher-subject-assignments/{assignment_id}?school_id={school_id}", headers=headers)
    assert resp_del_get.status_code == 404

@pytest.mark.anyio
async def test_assignment_business_validations(client: AsyncClient, setup_assignment_test_data, db_session) -> None:
    """
    Verifies business logic validations:
    - Duplicate assignments fail
    - Overlapping date range fails
    - Single class teacher per section constraint
    - Max workload threshold fails (weekly periods sum > 40)
    - Active status checks (Teacher/Subject/Class/Section must be ACTIVE)
    """
    data = setup_assignment_test_data
    school_id = data["school_a"].id
    headers = data["auth_headers"]

    payload = {
        "school_id": str(school_id),
        "academic_year_id": str(data["ay_a"].id),
        "teacher_id": str(data["teacher_a"].id),
        "subject_id": str(data["subject_a"].id),
        "class_id": str(data["class_a"].id),
        "section_id": str(data["sec_a"].id),
        "assignment_type": "PRIMARY",
        "weekly_periods": 10,
        "effective_from": "2026-01-01",
        "effective_to": "2026-06-30",
        "is_class_teacher": True
    }
    resp = await client.post("/api/v1/teacher-subject-assignments", json=payload, headers=headers)
    assert resp.status_code == 201

    # 1. Overlapping date ranges check -> fails
    payload_overlap = {**payload, "effective_from": "2026-03-01", "effective_to": "2026-09-30", "is_class_teacher": False}
    resp = await client.post("/api/v1/teacher-subject-assignments", json=payload_overlap, headers=headers)
    assert resp.status_code == 422

    # 2. Single class teacher check -> fails
    # Let's create a different teacher but assign to same class/section with is_class_teacher=True
    suffix = uuid.uuid4().hex[:6].upper()
    repo_t = TeacherRepository(db_session)
    teacher_new = await repo_t.create(
        tenant_id=data["tenant_a"].id,
        obj_in=TeacherCreate(
            school_id=school_id, employee_code=f"EMP-N-{suffix}", staff_code=f"STF-N-{suffix}", first_name="Benjamin", last_name="Franklin",
            gender=StudentGender.MALE, date_of_birth=date(1980, 1, 1), mobile=f"+919900112{suffix[:4]}", official_email=f"ben@{suffix}.edu",
            joining_date=date(2020, 1, 1), employment_type=EmploymentType.FULL_TIME
        )
    )
    await db_session.commit()

    payload_dup_ct = {**payload, "teacher_id": str(teacher_new.id), "effective_from": "2026-07-01", "effective_to": "2026-12-31", "is_class_teacher": True}
    resp = await client.post("/api/v1/teacher-subject-assignments", json=payload_dup_ct, headers=headers)
    assert resp.status_code == 422

    # 3. Workload validation (40 period weekly max limit check)
    # Teacher washington already has 10 periods. Trying to assign 35 more -> fails
    payload_heavy = {**payload, "effective_from": "2026-07-01", "effective_to": "2026-12-31", "weekly_periods": 35, "is_class_teacher": False}
    resp = await client.post("/api/v1/teacher-subject-assignments", json=payload_heavy, headers=headers)
    assert resp.status_code == 422

    # 4. Status ACTIVE checks: Inactive teacher -> fails
    # Update teacher to INACTIVE
    teacher_new.status = TeacherStatus.INACTIVE
    teacher_new.is_active = False
    await db_session.commit()

    payload_inactive_t = {**payload, "teacher_id": str(teacher_new.id), "effective_from": "2026-07-01", "effective_to": "2026-12-31", "is_class_teacher": False}
    resp = await client.post("/api/v1/teacher-subject-assignments", json=payload_inactive_t, headers=headers)
    assert resp.status_code == 422

@pytest.mark.anyio
async def test_assignment_fuzzy_searches(client: AsyncClient, setup_assignment_test_data, db_session) -> None:
    """
    Verifies joined fuzzy searches match correctly on teacher names, codes, subjects.
    """
    data = setup_assignment_test_data
    school_id = data["school_a"].id
    headers = data["auth_headers"]

    # Pre-create assignment
    payload = {
        "school_id": str(school_id),
        "academic_year_id": str(data["ay_a"].id),
        "teacher_id": str(data["teacher_a"].id),
        "subject_id": str(data["subject_a"].id),
        "class_id": str(data["class_a"].id),
        "section_id": str(data["sec_a"].id),
        "assignment_type": "PRIMARY",
        "weekly_periods": 5,
        "effective_from": "2026-01-01",
        "effective_to": "2026-12-31"
    }
    resp = await client.post("/api/v1/teacher-subject-assignments", json=payload, headers=headers)
    assert resp.status_code == 201

    # Search name George -> matches
    resp_name = await client.get(f"/api/v1/teacher-subject-assignments?school_id={school_id}&search=George", headers=headers)
    assert resp_name.status_code == 200
    assert len(resp_name.json()["data"]) == 1

    # Search subject code PHY -> matches
    resp_sub = await client.get(f"/api/v1/teacher-subject-assignments?school_id={school_id}&search=PHY", headers=headers)
    assert resp_sub.status_code == 200
    assert len(resp_sub.json()["data"]) == 1

@pytest.mark.anyio
async def test_assignment_tenant_isolation(client: AsyncClient, setup_assignment_test_data, db_session) -> None:
    """
    Verifies multi-tenant isolation boundaries.
    """
    data = setup_assignment_test_data
    school_b = data["school_b"].id
    headers_a = data["auth_headers"]

    # Pre-create assignment under Tenant B
    repo_tsa = TeacherSubjectAssignmentRepository(db_session)
    tsa_b = await repo_tsa.create(
        tenant_id=data["tenant_b"].id,
        obj_in=TeacherSubjectAssignmentCreate(
            school_id=school_b,
            academic_year_id=data["ay_b"].id,
            teacher_id=data["teacher_b"].id,
            subject_id=data["subject_b"].id,
            class_id=data["class_b"].id,
            section_id=data["sec_b"].id,
            assignment_type=AssignmentType.PRIMARY,
            weekly_periods=5,
            effective_from=date(2026, 1, 1)
        )
    )
    await db_session.commit()

    # Tenant A attempts to fetch Tenant B's assignment -> fails with 401/404
    resp = await client.get(f"/api/v1/teacher-subject-assignments/{tsa_b.id}?school_id={school_b}", headers=headers_a)
    assert resp.status_code in [401, 404]

    # Tenant A attempts to list assignments under School B -> returns empty list 200 OK
    resp_list = await client.get(f"/api/v1/teacher-subject-assignments?school_id={school_b}", headers=headers_a)
    assert resp_list.status_code == 200
    assert len(resp_list.json()["data"]) == 0

@pytest.mark.anyio
async def test_assignment_concurrency_control_occ(setup_assignment_test_data, db_session) -> None:
    """
    Verifies optimistic concurrency locking on assignments.
    """
    from sqlalchemy.ext.asyncio import async_sessionmaker
    from sqlalchemy.orm.exc import StaleDataError

    data = setup_assignment_test_data
    school_id = data["school_a"].id
    tenant_id = data["tenant_a"].id
    ay_id = data["ay_a"].id

    # 1. Create assignment in Session A
    repo_a = TeacherSubjectAssignmentRepository(db_session)
    tsa_obj = await repo_a.create(
        tenant_id=tenant_id,
        obj_in=TeacherSubjectAssignmentCreate(
            school_id=school_id,
            academic_year_id=ay_id,
            teacher_id=data["teacher_a"].id,
            subject_id=data["subject_a"].id,
            class_id=data["class_a"].id,
            section_id=data["sec_a"].id,
            assignment_type=AssignmentType.PRIMARY,
            weekly_periods=4,
            effective_from=date(2026, 1, 1)
        )
    )
    await repo_a.db.commit()
    await repo_a.db.refresh(tsa_obj)
    assert tsa_obj.version == 1

    # 2. Load assignment in Session B
    async_session_b = async_sessionmaker(
        bind=db_session.bind,
        class_=AsyncSession,
        expire_on_commit=False
    )
    async with async_session_b() as session_b:
        repo_b = TeacherSubjectAssignmentRepository(session_b)
        tsa_obj_b = await repo_b.get_by_id(tsa_obj.id, school_id, tenant_id)
        assert tsa_obj_b.version == 1

        # 3. Modify and commit in Session A
        tsa_obj.weekly_periods = 6
        await repo_a.db.commit()
        await repo_a.db.refresh(tsa_obj)
        assert tsa_obj.version == 2

        # 4. Attempt update in Session B -> should raise StaleDataError
        tsa_obj_b.weekly_periods = 8
        with pytest.raises(StaleDataError):
            await repo_b.db.commit()

        await repo_b.db.close()
