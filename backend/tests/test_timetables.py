import uuid
import pytest
from datetime import date, datetime, timezone, time, timedelta
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
from app.models.timetable import Timetable, TimetableStatus, DayOfWeek, PeriodType
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
from app.repositories.timetable import TimetableRepository
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
from app.schemas.timetable import TimetableCreate
from app.schemas.auth import UserCreate

@pytest.fixture
async def setup_timetable_test_data(db_session):
    """
    Sets up testing context:
    - Tenant A, School A, Academic Year A (ACTIVE)
    - Active Class A, Active Section A
    - Active Teacher A, Active Subject A (THEORY_PRACTICAL)
    - Teacher Subject Assignment A (weekly_periods=2)
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

    # Create Teacher Subject Assignment A (weekly_periods = 2)
    repo_tsa = TeacherSubjectAssignmentRepository(db_session)
    tsa_a = await repo_tsa.create(
        tenant_id=tenant_a.id,
        obj_in=TeacherSubjectAssignmentCreate(
            school_id=school_a.id, academic_year_id=ay_a.id, teacher_id=teacher_a.id, subject_id=subject_a.id,
            class_id=class_a.id, section_id=sec_a.id, assignment_type=AssignmentType.PRIMARY, weekly_periods=2,
            effective_from=date(2026, 1, 1)
        )
    )
    tsa_a.status = AssignmentStatus.ACTIVE
    tsa_a.is_active = True

    tsa_b = await repo_tsa.create(
        tenant_id=tenant_b.id,
        obj_in=TeacherSubjectAssignmentCreate(
            school_id=school_b.id, academic_year_id=ay_b.id, teacher_id=teacher_b.id, subject_id=subject_b.id,
            class_id=class_b.id, section_id=sec_b.id, assignment_type=AssignmentType.PRIMARY, weekly_periods=2,
            effective_from=date(2026, 1, 1)
        )
    )
    tsa_b.status = AssignmentStatus.ACTIVE
    tsa_b.is_active = True
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
        "tsa_a": tsa_a,
        "tsa_b": tsa_b,
        "user_a": user_a,
        "auth_headers": {
            "Authorization": f"Bearer {tokens.access_token}",
            "X-Tenant-ID": str(tenant_a.id)
        }
    }

@pytest.mark.anyio
async def test_timetable_crud_flow(client: AsyncClient, setup_timetable_test_data, db_session) -> None:
    """
    Verifies CRUD flows:
    - POST create timetable slot
    - GET list timetable slots
    - GET fetch timetable slot details
    - PUT update timetable slot parameters
    - DELETE soft delete timetable slot
    """
    data = setup_timetable_test_data
    school_id = data["school_a"].id
    headers = data["auth_headers"]

    # 1. Create Timetable Slot
    payload = {
        "school_id": str(school_id),
        "academic_year_id": str(data["ay_a"].id),
        "teacher_subject_assignment_id": str(data["tsa_a"].id),
        "class_id": str(data["class_a"].id),
        "section_id": str(data["sec_a"].id),
        "day_of_week": "MONDAY",
        "period_number": 1,
        "start_time": "08:30:00",
        "end_time": "09:15:00",
        "period_type": "REGULAR",
        "room_id": str(uuid.uuid4()),
        "settings": {"requires_projector": True}
    }
    resp = await client.post("/api/v1/timetables", json=payload, headers=headers)
    assert resp.status_code == 201
    slot_id = resp.json()["data"]["id"]
    assert resp.json()["data"]["period_number"] == 1
    assert resp.json()["data"]["teacher_id"] == str(data["teacher_a"].id)
    assert resp.json()["data"]["subject_id"] == str(data["subject_a"].id)

    # 2. Get list of slots
    resp_list = await client.get(f"/api/v1/timetables?school_id={school_id}", headers=headers)
    assert resp_list.status_code == 200
    assert len(resp_list.json()["data"]) >= 1

    # 3. Get slot details
    resp_get = await client.get(f"/api/v1/timetables/{slot_id}?school_id={school_id}", headers=headers)
    assert resp_get.status_code == 200
    assert resp_get.json()["data"]["settings"]["requires_projector"] is True

    # 4. Update slot parameters
    update_payload = {
        "period_number": 2,
        "start_time": "09:15:00",
        "end_time": "10:00:00",
        "status": "INACTIVE"
    }
    resp_put = await client.put(f"/api/v1/timetables/{slot_id}?school_id={school_id}", json=update_payload, headers=headers)
    assert resp_put.status_code == 200
    assert resp_put.json()["data"]["period_number"] == 2
    assert resp_put.json()["data"]["status"] == "INACTIVE"
    assert resp_put.json()["data"]["is_active"] is False

    # 5. Delete slot (soft-delete)
    resp_del = await client.delete(f"/api/v1/timetables/{slot_id}?school_id={school_id}", headers=headers)
    assert resp_del.status_code == 200
    assert resp_del.json()["data"]["deleted_at"] is not None

    # Verify soft-deleted slot is omitted from fetch
    resp_del_get = await client.get(f"/api/v1/timetables/{slot_id}?school_id={school_id}", headers=headers)
    assert resp_del_get.status_code == 404

@pytest.mark.anyio
async def test_timetable_schedule_lookups(client: AsyncClient, setup_timetable_test_data, db_session) -> None:
    """
    Verifies teacher, class, and section schedule lookup endpoints.
    """
    data = setup_timetable_test_data
    school_id = data["school_a"].id
    headers = data["auth_headers"]

    # Pre-create slot
    payload = {
        "school_id": str(school_id),
        "academic_year_id": str(data["ay_a"].id),
        "teacher_subject_assignment_id": str(data["tsa_a"].id),
        "class_id": str(data["class_a"].id),
        "section_id": str(data["sec_a"].id),
        "day_of_week": "MONDAY",
        "period_number": 1,
        "start_time": "08:30:00",
        "end_time": "09:15:00",
        "period_type": "REGULAR"
    }
    resp = await client.post("/api/v1/timetables", json=payload, headers=headers)
    assert resp.status_code == 201

    # Teacher schedule lookup
    resp_t = await client.get(
        f"/api/v1/timetables/teacher-schedule?teacher_id={data['teacher_a'].id}&academic_year_id={data['ay_a'].id}&school_id={school_id}",
        headers=headers
    )
    assert resp_t.status_code == 200
    assert len(resp_t.json()["data"]) == 1

    # Class schedule lookup
    resp_c = await client.get(
        f"/api/v1/timetables/class-schedule?class_id={data['class_a'].id}&academic_year_id={data['ay_a'].id}&school_id={school_id}",
        headers=headers
    )
    assert resp_c.status_code == 200
    assert len(resp_c.json()["data"]) == 1

    # Section schedule lookup
    resp_sec = await client.get(
        f"/api/v1/timetables/section-schedule?class_id={data['class_a'].id}&section_id={data['sec_a'].id}&academic_year_id={data['ay_a'].id}&school_id={school_id}",
        headers=headers
    )
    assert resp_sec.status_code == 200
    assert len(resp_sec.json()["data"]) == 1

@pytest.mark.anyio
async def test_timetable_business_validations(client: AsyncClient, setup_timetable_test_data, db_session) -> None:
    """
    Verifies business logic validations:
    - Block teacher double-booking in same period slot
    - Block class/section double-booking in same period slot
    - Block overlapping time slots on same day/section
    - Block exceeding assignment weekly period limits (weekly_periods=2)
    - Break period does not require teacher/subject/assignment
    """
    data = setup_timetable_test_data
    school_id = data["school_a"].id
    headers = data["auth_headers"]

    # 1. Create REGULAR period slot 1
    payload1 = {
        "school_id": str(school_id),
        "academic_year_id": str(data["ay_a"].id),
        "teacher_subject_assignment_id": str(data["tsa_a"].id),
        "class_id": str(data["class_a"].id),
        "section_id": str(data["sec_a"].id),
        "day_of_week": "MONDAY",
        "period_number": 1,
        "start_time": "08:30:00",
        "end_time": "09:15:00",
        "period_type": "REGULAR"
    }
    resp = await client.post("/api/v1/timetables", json=payload1, headers=headers)
    assert resp.status_code == 201

    # 2. Block teacher double-booking -> fails
    # Assign different class but same teacher/day/period slot
    suffix = uuid.uuid4().hex[:6].upper()
    repo_c = ClassRepository(db_session)
    class_new = await repo_c.create(
        data["tenant_a"].id,
        ClassCreate(school_id=school_id, academic_year_id=data["ay_a"].id, name=f"Class {suffix}", code=f"C{suffix}", level=11, category=ClassCategory.HIGH, capacity=30)
    )
    await db_session.commit()
    repo_sec = SectionRepository(db_session)
    sec_new = await repo_sec.create(
        data["tenant_a"].id, SectionCreate(school_id=school_id, academic_year_id=data["ay_a"].id, class_id=class_new.id, name="Sec N", code=f"SN{suffix}", capacity=30)
    )
    await db_session.commit()
    repo_tsa = TeacherSubjectAssignmentRepository(db_session)
    tsa_new = await repo_tsa.create(
        tenant_id=data["tenant_a"].id,
        obj_in=TeacherSubjectAssignmentCreate(
            school_id=school_id, academic_year_id=data["ay_a"].id, teacher_id=data["teacher_a"].id, subject_id=data["subject_a"].id,
            class_id=class_new.id, section_id=sec_new.id, assignment_type=AssignmentType.PRIMARY, weekly_periods=2,
            effective_from=date(2026, 1, 1)
        )
    )
    tsa_new.status = AssignmentStatus.ACTIVE
    tsa_new.is_active = True
    await db_session.commit()

    payload_t_conflict = {
        **payload1,
        "teacher_subject_assignment_id": str(tsa_new.id),
        "class_id": str(class_new.id),
        "section_id": str(sec_new.id),
    }
    resp_t_conf = await client.post("/api/v1/timetables", json=payload_t_conflict, headers=headers)
    assert resp_t_conf.status_code == 422

    # 3. Block class/section double-booking -> fails
    # Assign same class/section/day/period but try different teacher/subject mapping
    teacher_frank = await TeacherRepository(db_session).create(
        tenant_id=data["tenant_a"].id,
        obj_in=TeacherCreate(
            school_id=school_id, employee_code=f"EMP-F-{suffix}", staff_code=f"STF-F-{suffix}", first_name="Benjamin", last_name="Franklin",
            gender=StudentGender.MALE, date_of_birth=date(1980, 1, 1), mobile=f"+919900113{suffix[:4]}", official_email=f"frank@{suffix}.edu",
            joining_date=date(2020, 1, 1), employment_type=EmploymentType.FULL_TIME
        )
    )
    await db_session.commit()
    subject_math = await SubjectRepository(db_session).create(
        tenant_id=data["tenant_a"].id,
        obj_in=SubjectCreate(
            school_id=school_id, academic_year_id=data["ay_a"].id, subject_code=f"MTH-{suffix}", subject_name="Mathematics",
            category="CORE", subject_type="THEORY", theory_marks=100, practical_marks=0, pass_marks=40
        )
    )
    await db_session.commit()
    tsa_math = await repo_tsa.create(
        tenant_id=data["tenant_a"].id,
        obj_in=TeacherSubjectAssignmentCreate(
            school_id=school_id, academic_year_id=data["ay_a"].id, teacher_id=teacher_frank.id, subject_id=subject_math.id,
            class_id=data["class_a"].id, section_id=data["sec_a"].id, assignment_type=AssignmentType.PRIMARY, weekly_periods=2,
            effective_from=date(2026, 1, 1)
        )
    )
    tsa_math.status = AssignmentStatus.ACTIVE
    tsa_math.is_active = True
    await db_session.commit()

    payload_c_conflict = {
        **payload1,
        "teacher_subject_assignment_id": str(tsa_math.id),
    }
    resp_c_conf = await client.post("/api/v1/timetables", json=payload_c_conflict, headers=headers)
    assert resp_c_conf.status_code == 422

    # 4. Time overlap check -> fails
    payload_overlap = {
        **payload1,
        "teacher_subject_assignment_id": str(tsa_math.id),
        "period_number": 5, # different period index
        "start_time": "09:00:00", # overlaps with 08:30 - 09:15
        "end_time": "09:45:00"
    }
    resp_overlap = await client.post("/api/v1/timetables", json=payload_overlap, headers=headers)
    assert resp_overlap.status_code == 422

    # 5. Workload allocation cap check -> fails
    # Let's create slot 2 for tsa_a
    payload2 = {
        **payload1,
        "period_number": 2,
        "start_time": "09:15:00",
        "end_time": "10:00:00"
    }
    resp2 = await client.post("/api/v1/timetables", json=payload2, headers=headers)
    assert resp2.status_code == 201

    # Try creating slot 3 (exceeding tsa_a.weekly_periods = 2) -> fails
    payload3 = {
        **payload1,
        "period_number": 3,
        "start_time": "10:00:00",
        "end_time": "10:45:00"
    }
    resp3 = await client.post("/api/v1/timetables", json=payload3, headers=headers)
    assert resp3.status_code == 422

    # 6. Break period handling: BREAK period type does not require assignment
    payload_break = {
        "school_id": str(school_id),
        "academic_year_id": str(data["ay_a"].id),
        "class_id": str(data["class_a"].id),
        "section_id": str(data["sec_a"].id),
        "day_of_week": "MONDAY",
        "period_number": 4,
        "start_time": "11:00:00",
        "end_time": "11:30:00",
        "period_type": "BREAK",
        "room_id": None
    }
    resp_break = await client.post("/api/v1/timetables", json=payload_break, headers=headers)
    assert resp_break.status_code == 201
    assert resp_break.json()["data"]["teacher_subject_assignment_id"] is None
    assert resp_break.json()["data"]["teacher_id"] is None
    assert resp_break.json()["data"]["subject_id"] is None

@pytest.mark.anyio
async def test_timetable_tenant_isolation(client: AsyncClient, setup_timetable_test_data, db_session) -> None:
    """
    Verifies multi-tenant isolation boundaries.
    """
    data = setup_timetable_test_data
    school_b = data["school_b"].id
    headers_a = data["auth_headers"]

    # Pre-create slot under Tenant B
    repo_tt = TimetableRepository(db_session)
    slot_b = await repo_tt.create(
        tenant_id=data["tenant_b"].id,
        obj_in=TimetableCreate(
            school_id=school_b,
            academic_year_id=data["ay_b"].id,
            teacher_subject_assignment_id=data["tsa_b"].id,
            class_id=data["class_b"].id,
            section_id=data["sec_b"].id,
            day_of_week=DayOfWeek.MONDAY,
            period_number=1,
            start_time=time(8, 30),
            end_time=time(9, 15),
            period_type=PeriodType.REGULAR
        ),
        teacher_id=data["teacher_b"].id,
        subject_id=data["subject_b"].id
    )
    await db_session.commit()

    # Tenant A attempts to fetch Tenant B's slot -> fails with 401/404
    resp = await client.get(f"/api/v1/timetables/{slot_b.id}?school_id={school_b}", headers=headers_a)
    assert resp.status_code in [401, 404]

    # Tenant A attempts to list slots under School B -> returns empty list 200 OK
    resp_list = await client.get(f"/api/v1/timetables?school_id={school_b}", headers=headers_a)
    assert resp_list.status_code == 200
    assert len(resp_list.json()["data"]) == 0

@pytest.mark.anyio
async def test_timetable_concurrency_control_occ(setup_timetable_test_data, db_session) -> None:
    """
    Verifies optimistic concurrency locking on timetable slots.
    """
    from sqlalchemy.ext.asyncio import async_sessionmaker
    from sqlalchemy.orm.exc import StaleDataError

    data = setup_timetable_test_data
    school_id = data["school_a"].id
    tenant_id = data["tenant_a"].id

    # 1. Create slot in Session A
    repo_a = TimetableRepository(db_session)
    slot_obj = await repo_a.create(
        tenant_id=tenant_id,
        obj_in=TimetableCreate(
            school_id=school_id,
            academic_year_id=data["ay_a"].id,
            teacher_subject_assignment_id=data["tsa_a"].id,
            class_id=data["class_a"].id,
            section_id=data["sec_a"].id,
            day_of_week=DayOfWeek.MONDAY,
            period_number=1,
            start_time=time(8, 30),
            end_time=time(9, 15),
            period_type=PeriodType.REGULAR
        ),
        teacher_id=data["teacher_a"].id,
        subject_id=data["subject_a"].id
    )
    await repo_a.db.commit()
    await repo_a.db.refresh(slot_obj)
    assert slot_obj.version == 1

    # 2. Load slot in Session B
    async_session_b = async_sessionmaker(
        bind=db_session.bind,
        class_=AsyncSession,
        expire_on_commit=False
    )
    async with async_session_b() as session_b:
        repo_b = TimetableRepository(session_b)
        slot_obj_b = await repo_b.get_by_id(slot_obj.id, school_id, tenant_id)
        assert slot_obj_b.version == 1

        # 3. Modify and commit in Session A
        slot_obj.room_id = uuid.uuid4()
        await repo_a.db.commit()
        await repo_a.db.refresh(slot_obj)
        assert slot_obj.version == 2

        # 4. Attempt update in Session B -> should raise StaleDataError
        slot_obj_b.room_id = uuid.uuid4()
        with pytest.raises(StaleDataError):
            await repo_b.db.commit()

        await repo_b.db.close()
