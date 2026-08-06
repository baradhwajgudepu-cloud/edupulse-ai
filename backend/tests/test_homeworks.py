import uuid
import pytest
from datetime import date, datetime, timezone, timedelta
from httpx import AsyncClient
from sqlalchemy import select, text
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tenant import Tenant
from app.models.school import School
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.class_entity import Class, ClassCategory
from app.models.section import Section
from app.models.student import Student, StudentGender
from app.models.teacher import Teacher, EmploymentType, TeacherStatus
from app.models.subject import Subject, SubjectCategory, SubjectType, SubjectStatus
from app.models.teacher_subject_assignment import TeacherSubjectAssignment, AssignmentStatus
from app.models.timetable import Timetable, DayOfWeek, PeriodType, TimetableStatus
from app.models.guardian import Guardian, StudentGuardian, StudentGuardianRelationship, GuardianType, GuardianStatus
from app.models.role import Role
from app.models.permission import Permission
from app.models.homework import Homework, HomeworkStatus, HomeworkPriority

from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.section import SectionRepository
from app.repositories.student import StudentRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.subject import SubjectRepository
from app.repositories.teacher_subject_assignment import TeacherSubjectAssignmentRepository
from app.repositories.timetable import TimetableRepository
from app.repositories.guardian import GuardianRepository, StudentGuardianRepository
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
from app.services.auth import AuthService

from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate, SchoolStatus
from app.schemas.academic_year import AcademicYearCreate
from app.schemas.class_entity import ClassCreate
from app.schemas.section import SectionCreate
from app.schemas.student import StudentCreate
from app.schemas.teacher import TeacherCreate
from app.schemas.subject import SubjectCreate
from app.schemas.teacher_subject_assignment import TeacherSubjectAssignmentCreate
from app.schemas.timetable import TimetableCreate
from app.schemas.guardian import GuardianCreate
from app.schemas.auth import UserCreate

@pytest.fixture
async def setup_homework_test_data(db_session: AsyncSession):
    """
    Initializes setup objects for student homework integration tests.
    """
    suffix = uuid.uuid4().hex[:6].lower()

    # 1. Create Tenants
    repo_t = TenantRepository(db_session)
    tenant_a = await repo_t.create(TenantCreate(name="Homework Tenant A", code=f"hw-a-{suffix}", subdomain=f"hw-a-{suffix}", email=f"a-{suffix}@t.com"))
    tenant_b = await repo_t.create(TenantCreate(name="Homework Tenant B", code=f"hw-b-{suffix}", subdomain=f"hw-b-{suffix}", email=f"b-{suffix}@t.com"))
    await db_session.commit()

    # 2. Create Schools
    repo_s = SchoolRepository(db_session)
    school_a = await repo_s.create(tenant_a.id, SchoolCreate(name="HW School A", code=f"SC_A_{suffix.upper()}", address="123 Street", city="Bangalore", state="Karnataka", country="India", pin_code="560001", board="CBSE", email=f"s-a-{suffix}@a.com", status=SchoolStatus.ACTIVE))
    school_b = await repo_s.create(tenant_b.id, SchoolCreate(name="HW School B", code=f"SC_B_{suffix.upper()}", address="456 Street", city="Bangalore", state="Karnataka", country="India", pin_code="560001", board="CBSE", email=f"s-b-{suffix}@b.com", status=SchoolStatus.ACTIVE))
    await db_session.commit()

    # 3. Academic Years
    repo_ay = AcademicYearRepository(db_session)
    ay_a = await repo_ay.create(tenant_a.id, school_a.id, AcademicYearCreate(school_id=school_a.id, name="Year 2026", code="AY2026", start_date=date(2026, 1, 1), end_date=date(2026, 12, 31), status=AcademicYearStatus.ACTIVE, is_current=True))
    ay_a.status = AcademicYearStatus.ACTIVE
    ay_b = await repo_ay.create(tenant_b.id, school_b.id, AcademicYearCreate(school_id=school_b.id, name="Year 2026", code="AY2026", start_date=date(2026, 1, 1), end_date=date(2026, 12, 31), status=AcademicYearStatus.ACTIVE, is_current=True))
    ay_b.status = AcademicYearStatus.ACTIVE
    await db_session.commit()

    # 4. Classes & Sections
    repo_c = ClassRepository(db_session)
    class_a = await repo_c.create(tenant_a.id, ClassCreate(school_id=school_a.id, academic_year_id=ay_a.id, name="Grade 8", code="G8", level=8, category=ClassCategory.MIDDLE, capacity=35))
    class_b = await repo_c.create(tenant_b.id, ClassCreate(school_id=school_b.id, academic_year_id=ay_b.id, name="Grade 8", code="G8_B", level=8, category=ClassCategory.MIDDLE, capacity=35))
    await db_session.commit()

    repo_sec = SectionRepository(db_session)
    sec_a1 = await repo_sec.create(tenant_a.id, SectionCreate(school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_a.id, name="Section A1", code="SEC_A1", capacity=35))
    sec_a2 = await repo_sec.create(tenant_a.id, SectionCreate(school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_a.id, name="Section A2", code="SEC_A2", capacity=35))
    sec_b = await repo_sec.create(tenant_b.id, SectionCreate(school_id=school_b.id, academic_year_id=ay_b.id, class_id=class_b.id, name="Section B", code="SEC_B", capacity=35))
    await db_session.commit()

    # 5. Students
    repo_stud = StudentRepository(db_session)
    stud_a = await repo_stud.create(tenant_a.id, StudentCreate(school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_a.id, section_id=sec_a1.id, admission_number="ADM-A", first_name="Albert", last_name="Einstein", gender=StudentGender.MALE, date_of_birth=date(2012, 3, 14), roll_number="1", admission_date=date(2026, 1, 1)))
    stud_b = await repo_stud.create(tenant_b.id, StudentCreate(school_id=school_b.id, academic_year_id=ay_b.id, class_id=class_b.id, section_id=sec_b.id, admission_number="ADM-B", first_name="Marie", last_name="Curie", gender=StudentGender.FEMALE, date_of_birth=date(2012, 11, 7), roll_number="1", admission_date=date(2026, 1, 1)))
    await db_session.commit()

    # 6. Teachers & Subjects
    repo_tchr = TeacherRepository(db_session)
    teacher_a = await repo_tchr.create(tenant_a.id, TeacherCreate(school_id=school_a.id, employee_code=f"EMP-A-{suffix}", staff_code=f"STF-A-{suffix}", first_name="John", last_name="Doe", gender=StudentGender.MALE, date_of_birth=date(1985, 5, 20), mobile=f"+91987654{suffix[:4]}", official_email=f"teacher-a-{suffix}@edu.com", joining_date=date(2025, 1, 1), employment_type=EmploymentType.FULL_TIME))
    teacher_b = await repo_tchr.create(tenant_b.id, TeacherCreate(school_id=school_b.id, employee_code=f"EMP-B-{suffix}", staff_code=f"STF-B-{suffix}", first_name="Jane", last_name="Smith", gender=StudentGender.FEMALE, date_of_birth=date(1990, 8, 15), mobile=f"+91987655{suffix[:4]}", official_email=f"teacher-b-{suffix}@edu.com", joining_date=date(2025, 1, 1), employment_type=EmploymentType.FULL_TIME))
    await db_session.commit()

    repo_sub = SubjectRepository(db_session)
    subject_a = await repo_sub.create(tenant_a.id, SubjectCreate(school_id=school_a.id, academic_year_id=ay_a.id, subject_code=f"MATH-{suffix.upper()}", subject_name="Mathematics", category=SubjectCategory.CORE, subject_type=SubjectType.THEORY))
    subject_a.status = SubjectStatus.ACTIVE
    subject_b = await repo_sub.create(tenant_b.id, SubjectCreate(school_id=school_b.id, academic_year_id=ay_b.id, subject_code=f"MATH-{suffix.upper()}", subject_name="Mathematics", category=SubjectCategory.CORE, subject_type=SubjectType.THEORY))
    subject_b.status = SubjectStatus.ACTIVE
    await db_session.commit()

    # 7. Assignments
    repo_tsa = TeacherSubjectAssignmentRepository(db_session)
    tsa_a = await repo_tsa.create(tenant_a.id, TeacherSubjectAssignmentCreate(school_id=school_a.id, academic_year_id=ay_a.id, teacher_id=teacher_a.id, subject_id=subject_a.id, class_id=class_a.id, section_id=sec_a1.id, assignment_type="PRIMARY", weekly_periods=5, effective_from=date(2026, 1, 1)))
    tsa_a.status = AssignmentStatus.ACTIVE
    tsa_a.is_active = True
    
    # Also assign teacher to section A2 for copy test
    tsa_a2 = await repo_tsa.create(tenant_a.id, TeacherSubjectAssignmentCreate(school_id=school_a.id, academic_year_id=ay_a.id, teacher_id=teacher_a.id, subject_id=subject_a.id, class_id=class_a.id, section_id=sec_a2.id, assignment_type="PRIMARY", weekly_periods=5, effective_from=date(2026, 1, 1)))
    tsa_a2.status = AssignmentStatus.ACTIVE
    tsa_a2.is_active = True

    tsa_b = await repo_tsa.create(tenant_b.id, TeacherSubjectAssignmentCreate(school_id=school_b.id, academic_year_id=ay_b.id, teacher_id=teacher_b.id, subject_id=subject_b.id, class_id=class_b.id, section_id=sec_b.id, assignment_type="PRIMARY", weekly_periods=5, effective_from=date(2026, 1, 1)))
    tsa_b.status = AssignmentStatus.ACTIVE
    tsa_b.is_active = True
    await db_session.commit()

    # 8. Timetable
    repo_tt = TimetableRepository(db_session)
    tt_a = await repo_tt.create(tenant_a.id, TimetableCreate(school_id=school_a.id, academic_year_id=ay_a.id, teacher_subject_assignment_id=tsa_a.id, class_id=class_a.id, section_id=sec_a1.id, day_of_week="MONDAY", period_number=1, start_time="08:30:00", end_time="09:15:00", period_type="REGULAR"))
    tt_a.teacher_id = teacher_a.id
    tt_a.subject_id = subject_a.id
    
    tt_b = await repo_tt.create(tenant_b.id, TimetableCreate(school_id=school_b.id, academic_year_id=ay_b.id, teacher_subject_assignment_id=tsa_b.id, class_id=class_b.id, section_id=sec_b.id, day_of_week="MONDAY", period_number=1, start_time="08:30:00", end_time="09:15:00", period_type="REGULAR"))
    tt_b.teacher_id = teacher_b.id
    tt_b.subject_id = subject_b.id
    await db_session.commit()

    # 9. Guardians
    repo_g = GuardianRepository(db_session)
    parent_email = f"parent-{suffix}@family.com"
    guardian_a = await repo_g.create(tenant_a.id, GuardianCreate(school_id=school_a.id, guardian_type=GuardianType.FATHER, first_name="Albert", last_name="Einstein Sr", gender=StudentGender.MALE, date_of_birth=date(1980, 1, 1), mobile=f"+91888888{suffix[:4]}", email=parent_email))
    await db_session.commit()

    repo_sg = StudentGuardianRepository(db_session)
    sg = StudentGuardian(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        student_id=stud_a.id,
        guardian_id=guardian_a.id,
        relationship=StudentGuardianRelationship.FATHER,
        is_primary=True,
        receives_notifications=True
    )
    db_session.add(sg)
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

    user_teacher = await auth_service.create_user(
        tenant_a.id,
        UserCreate(email=teacher_a.official_email, password="Password123!", first_name="John", last_name="Doe")
    )
    user_teacher.roles.append(role_a)

    user_parent = await auth_service.create_user(
        tenant_a.id,
        UserCreate(email=parent_email, password="Password123!", first_name="Albert", last_name="Einstein Sr")
    )
    user_parent.roles.append(role_a)

    await db_session.commit()

    tokens_t = await auth_service.create_tokens(user_teacher)
    tokens_p = await auth_service.create_tokens(user_parent)

    return {
        "tenant_a": tenant_a, "tenant_b": tenant_b,
        "school_a": school_a, "school_b": school_b,
        "ay_a": ay_a, "ay_b": ay_b,
        "class_a": class_a, "class_b": class_b,
        "sec_a1": sec_a1, "sec_a2": sec_a2, "sec_b": sec_b,
        "stud_a": stud_a, "stud_b": stud_b,
        "teacher_a": teacher_a, "teacher_b": teacher_b,
        "subject_a": subject_a, "subject_b": subject_b,
        "tsa_a": tsa_a, "tsa_a2": tsa_a2, "tsa_b": tsa_b,
        "tt_a": tt_a, "tt_b": tt_b,
        "guardian_a": guardian_a,
        "user_teacher": user_teacher,
        "user_parent": user_parent,
        "auth_headers": {
            "Authorization": f"Bearer {tokens_t.access_token}",
            "X-Tenant-ID": str(tenant_a.id)
        },
        "parent_auth_headers": {
            "Authorization": f"Bearer {tokens_p.access_token}",
            "X-Tenant-ID": str(tenant_a.id)
        }
    }

@pytest.mark.anyio
async def test_homework_crud_flow(client: AsyncClient, setup_homework_test_data) -> None:
    """
    Verifies creating, retrieving, updating, listing, publishing, and soft deleting homework assignments.
    """
    data = setup_homework_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id

    # 1. Create a Draft Homework
    tomorrow = (date.today() + timedelta(days=1)).isoformat()
    payload = {
        "school_id": str(school_id),
        "academic_year_id": str(data["ay_a"].id),
        "teacher_id": str(data["teacher_a"].id),
        "teacher_subject_assignment_id": str(data["tsa_a"].id),
        "subject_id": str(data["subject_a"].id),
        "class_id": str(data["class_a"].id),
        "section_id": str(data["sec_a1"].id),
        "title": "Algebra Homework 1",
        "description": "Solve quadratic equations from page 45.",
        "due_date": tomorrow,
        "priority": "NORMAL",
        "status": "DRAFT",
        "estimated_minutes": 45
    }
    resp = await client.post("/api/v1/homeworks", json=payload, headers=headers)
    assert resp.status_code == 201
    hw_id = resp.json()["data"]["id"]
    assert resp.json()["data"]["status"] == "DRAFT"

    # 2. Retrieve granular details
    resp_get = await client.get(f"/api/v1/homeworks/{hw_id}?school_id={school_id}", headers=headers)
    assert resp_get.status_code == 200
    assert resp_get.json()["data"]["title"] == "Algebra Homework 1"

    # 3. Update details
    update_payload = {
        "title": "Algebra Homework 1 Updated",
        "estimated_minutes": 50
    }
    resp_update = await client.put(f"/api/v1/homeworks/{hw_id}?school_id={school_id}", json=update_payload, headers=headers)
    assert resp_update.status_code == 200
    assert resp_update.json()["data"]["title"] == "Algebra Homework 1 Updated"
    assert resp_update.json()["data"]["estimated_minutes"] == 50

    # 4. Search and List
    resp_list = await client.get(f"/api/v1/homeworks?school_id={school_id}&search=algebra", headers=headers)
    assert resp_list.status_code == 200
    assert len(resp_list.json()["data"]) == 1

    # 5. Publish
    resp_publish = await client.post(f"/api/v1/homeworks/{hw_id}/publish?school_id={school_id}", headers=headers)
    assert resp_publish.status_code == 200
    assert resp_publish.json()["data"]["status"] == "PUBLISHED"
    assert resp_publish.json()["data"]["settings"]["notification_status"] == "PENDING"

    # 6. Soft Delete
    resp_del = await client.delete(f"/api/v1/homeworks/{hw_id}?school_id={school_id}", headers=headers)
    assert resp_del.status_code == 200
    assert resp_del.json()["data"]["is_active"] is False

@pytest.mark.anyio
async def test_homework_timetable_flow(client: AsyncClient, setup_homework_test_data) -> None:
    """
    Verifies creating a homework directly from a timetable slot ID.
    """
    data = setup_homework_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id
    timetable_id = data["tt_a"].id

    tomorrow = (date.today() + timedelta(days=1)).isoformat()
    payload = {
        "title": "Geometry Homework 2",
        "description": "Construct triangles.",
        "due_date": tomorrow,
        "priority": "HIGH",
        "status": "DRAFT",
        "estimated_minutes": 30
    }
    resp = await client.post(
        f"/api/v1/homeworks/timetable/{timetable_id}?school_id={school_id}",
        json=payload,
        headers=headers
    )
    assert resp.status_code == 201
    res_data = resp.json()["data"]
    assert res_data["title"] == "Geometry Homework 2"
    # Derived from timetable context
    assert res_data["class_id"] == str(data["class_a"].id)
    assert res_data["section_id"] == str(data["sec_a1"].id)
    assert res_data["teacher_id"] == str(data["teacher_a"].id)
    assert res_data["subject_id"] == str(data["subject_a"].id)

@pytest.mark.anyio
async def test_homework_templates(client: AsyncClient, setup_homework_test_data) -> None:
    """
    Verifies template lookup endpoint based on subject categories.
    """
    data = setup_homework_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id
    subject_id = data["subject_a"].id

    # Fetch templates scoped to math subject
    resp = await client.get(f"/api/v1/homeworks/templates?school_id={school_id}&subject_id={subject_id}", headers=headers)
    assert resp.status_code == 200
    assert "Solve Exercise" in resp.json()["data"]

@pytest.mark.anyio
async def test_homework_recent(client: AsyncClient, setup_homework_test_data) -> None:
    """
    Verifies get_recent_homework endpoint.
    """
    from app.main import app
    from app.api.dependencies.auth import get_current_user

    data = setup_homework_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id

    async def mock_teacher():
        return data["user_teacher"]

    app.dependency_overrides[get_current_user] = mock_teacher
    try:
        resp = await client.get(f"/api/v1/homeworks/recent?school_id={school_id}", headers=headers)
        assert resp.status_code == 200
        assert isinstance(resp.json()["data"], list)
    finally:
        del app.dependency_overrides[get_current_user]

@pytest.mark.anyio
async def test_homework_copy(client: AsyncClient, setup_homework_test_data) -> None:
    """
    Verifies duplicating homework across sections.
    """
    data = setup_homework_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id

    tomorrow = (date.today() + timedelta(days=1)).isoformat()
    # 1. Create source homework in section A1
    payload = {
        "school_id": str(school_id),
        "academic_year_id": str(data["ay_a"].id),
        "teacher_id": str(data["teacher_a"].id),
        "teacher_subject_assignment_id": str(data["tsa_a"].id),
        "subject_id": str(data["subject_a"].id),
        "class_id": str(data["class_a"].id),
        "section_id": str(data["sec_a1"].id),
        "title": "HW to Copy",
        "description": "Please solve.",
        "due_date": tomorrow
    }
    resp = await client.post("/api/v1/homeworks", json=payload, headers=headers)
    assert resp.status_code == 201
    source_id = resp.json()["data"]["id"]

    # 2. Copy to section A2 (Teacher John teaches subject_a in section A2)
    copy_payload = {
        "homework_id": source_id,
        "target_section_ids": [str(data["sec_a2"].id)]
    }
    resp_copy = await client.post(f"/api/v1/homeworks/copy?school_id={school_id}", json=copy_payload, headers=headers)
    assert resp_copy.status_code == 201
    copies = resp_copy.json()["data"]
    assert len(copies) == 1
    assert copies[0]["section_id"] == str(data["sec_a2"].id)
    assert copies[0]["ai_metrics"]["copied_from_previous"] is True

@pytest.mark.anyio
async def test_homework_parent_flow(client: AsyncClient, setup_homework_test_data) -> None:
    """
    Verifies that parents can fetch homework scoped to their children's classes/sections.
    """
    from app.main import app
    from app.api.dependencies.auth import get_current_user

    data = setup_homework_test_data
    headers = data["auth_headers"]
    parent_headers = data["parent_auth_headers"]
    school_id = data["school_a"].id

    tomorrow = (date.today() + timedelta(days=1)).isoformat()
    # 1. Create draft homework (parent shouldn't see draft)
    payload = {
        "school_id": str(school_id),
        "academic_year_id": str(data["ay_a"].id),
        "teacher_id": str(data["teacher_a"].id),
        "teacher_subject_assignment_id": str(data["tsa_a"].id),
        "subject_id": str(data["subject_a"].id),
        "class_id": str(data["class_a"].id),
        "section_id": str(data["sec_a1"].id),
        "title": "HW Parent Draft Test",
        "description": "Hidden.",
        "due_date": tomorrow,
        "status": "DRAFT"
    }
    
    async def mock_teacher():
        return data["user_teacher"]

    app.dependency_overrides[get_current_user] = mock_teacher
    try:
        resp_draft = await client.post("/api/v1/homeworks", json=payload, headers=headers)
        assert resp_draft.status_code == 201
        draft_id = resp_draft.json()["data"]["id"]
    finally:
        del app.dependency_overrides[get_current_user]

    # 2. Query parent endpoint -> should not return the draft
    async def mock_parent():
        return data["user_parent"]

    app.dependency_overrides[get_current_user] = mock_parent
    try:
        resp_parent_empty = await client.get(f"/api/v1/homeworks/parent?school_id={school_id}", headers=parent_headers)
        assert resp_parent_empty.status_code == 200
        assert len(resp_parent_empty.json()["data"]) == 0
    finally:
        del app.dependency_overrides[get_current_user]

    # 3. Publish the homework
    app.dependency_overrides[get_current_user] = mock_teacher
    try:
        pub_resp = await client.post(f"/api/v1/homeworks/{draft_id}/publish?school_id={school_id}", headers=headers)
        assert pub_resp.status_code == 200
    finally:
        del app.dependency_overrides[get_current_user]

    # 4. Query parent endpoint again -> should return the published homework
    app.dependency_overrides[get_current_user] = mock_parent
    try:
        resp_parent_filled = await client.get(f"/api/v1/homeworks/parent?school_id={school_id}", headers=parent_headers)
        assert resp_parent_filled.status_code == 200
        assert len(resp_parent_filled.json()["data"]) == 1
        assert resp_parent_filled.json()["data"][0]["title"] == "HW Parent Draft Test"
    finally:
        del app.dependency_overrides[get_current_user]

@pytest.mark.anyio
async def test_homework_past_due_date_fails(client: AsyncClient, setup_homework_test_data) -> None:
    """
    Verifies that homework with a due date in the past is rejected.
    """
    data = setup_homework_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id

    yesterday = (date.today() - timedelta(days=1)).isoformat()
    payload = {
        "school_id": str(school_id),
        "academic_year_id": str(data["ay_a"].id),
        "teacher_id": str(data["teacher_a"].id),
        "teacher_subject_assignment_id": str(data["tsa_a"].id),
        "subject_id": str(data["subject_a"].id),
        "class_id": str(data["class_a"].id),
        "section_id": str(data["sec_a1"].id),
        "title": "Algebra Homework Past Fail",
        "description": "Due yesterday.",
        "due_date": yesterday
    }
    resp = await client.post("/api/v1/homeworks", json=payload, headers=headers)
    assert resp.status_code == 422
    assert "date cannot be in the past" in resp.json()["message"]

@pytest.mark.anyio
async def test_homework_duplicate_fails(client: AsyncClient, setup_homework_test_data) -> None:
    """
    Verifies that assigning a duplicate homework topic is rejected.
    """
    data = setup_homework_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id

    tomorrow = (date.today() + timedelta(days=1)).isoformat()
    payload = {
        "school_id": str(school_id),
        "academic_year_id": str(data["ay_a"].id),
        "teacher_id": str(data["teacher_a"].id),
        "teacher_subject_assignment_id": str(data["tsa_a"].id),
        "subject_id": str(data["subject_a"].id),
        "class_id": str(data["class_a"].id),
        "section_id": str(data["sec_a1"].id),
        "title": "Unique HW Topic",
        "description": "Due tomorrow.",
        "due_date": tomorrow
    }
    # First submit succeeds
    resp1 = await client.post("/api/v1/homeworks", json=payload, headers=headers)
    assert resp1.status_code == 201

    # Second submit of same topic is blocked
    resp2 = await client.post("/api/v1/homeworks", json=payload, headers=headers)
    assert resp2.status_code == 422
    assert "already exists for this class/section" in resp2.json()["message"]

@pytest.mark.anyio
async def test_homework_isolation_scoping(client: AsyncClient, setup_homework_test_data) -> None:
    """
    Verifies multi-tenant scoping boundaries:
    - Tenant B cannot view or copy Tenant A's homework.
    """
    data = setup_homework_test_data
    headers_a = data["auth_headers"]
    headers_b = {
        "Authorization": headers_a["Authorization"], # superuser token
        "X-Tenant-ID": str(data["tenant_b"].id)
    }
    school_id = data["school_a"].id

    tomorrow = (date.today() + timedelta(days=1)).isoformat()
    # 1. Create homework in Tenant A
    payload = {
        "school_id": str(school_id),
        "academic_year_id": str(data["ay_a"].id),
        "teacher_id": str(data["teacher_a"].id),
        "teacher_subject_assignment_id": str(data["tsa_a"].id),
        "subject_id": str(data["subject_a"].id),
        "class_id": str(data["class_a"].id),
        "section_id": str(data["sec_a1"].id),
        "title": "HW Tenant A Scoped",
        "description": "Secret.",
        "due_date": tomorrow
    }
    resp = await client.post("/api/v1/homeworks", json=payload, headers=headers_a)
    assert resp.status_code == 201
    hw_id = resp.json()["data"]["id"]

    # 2. Try fetching Tenant A homework with Tenant B scope -> fails with 404
    resp_b_get = await client.get(f"/api/v1/homeworks/{hw_id}?school_id={school_id}", headers=headers_b)
    assert resp_b_get.status_code == 404
