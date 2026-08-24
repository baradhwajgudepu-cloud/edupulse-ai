import uuid
import pytest
from datetime import date, time, datetime, timezone, timedelta
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
from app.models.guardian import Guardian, StudentGuardian, StudentGuardianRelationship, GuardianType, GuardianStatus
from app.models.role import Role
from app.models.permission import Permission
from app.models.examination import ExamTemplate, Examination, ExamSchedule, ExamStatus, ExamType

from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.section import SectionRepository
from app.repositories.student import StudentRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.subject import SubjectRepository
from app.repositories.teacher_subject_assignment import TeacherSubjectAssignmentRepository
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
from app.schemas.guardian import GuardianCreate
from app.schemas.auth import UserCreate

@pytest.fixture
async def setup_exam_test_data(db_session: AsyncSession):
    suffix = uuid.uuid4().hex[:6].lower()

    # 1. Create Tenant
    repo_t = TenantRepository(db_session)
    tenant_a = await repo_t.create(TenantCreate(name="Exam Tenant A", code=f"exam-a-{suffix}", subdomain=f"exam-a-{suffix}", email=f"a-{suffix}@t.com"))
    tenant_b = await repo_t.create(TenantCreate(name="Exam Tenant B", code=f"exam-b-{suffix}", subdomain=f"exam-b-{suffix}", email=f"b-{suffix}@t.com"))
    await db_session.commit()

    # 2. Create School
    repo_s = SchoolRepository(db_session)
    school_a = await repo_s.create(tenant_a.id, SchoolCreate(name="Exam School A", code=f"SC_A_{suffix.upper()}", address="123 Street", city="Bangalore", state="Karnataka", country="India", pin_code="560001", board="CBSE", email=f"s-a-{suffix}@a.com", status=SchoolStatus.ACTIVE))
    school_b = await repo_s.create(tenant_b.id, SchoolCreate(name="Exam School B", code=f"SC_B_{suffix.upper()}", address="456 Street", city="Bangalore", state="Karnataka", country="India", pin_code="560001", board="CBSE", email=f"s-b-{suffix}@b.com", status=SchoolStatus.ACTIVE))
    await db_session.commit()

    # 3. Academic Year
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
    sec_b = await repo_sec.create(tenant_b.id, SectionCreate(school_id=school_b.id, academic_year_id=ay_b.id, class_id=class_b.id, name="Section B", code="SEC_B", capacity=35))
    await db_session.commit()

    # 5. Student
    repo_stud = StudentRepository(db_session)
    stud_a = await repo_stud.create(tenant_a.id, StudentCreate(school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_a.id, section_id=sec_a1.id, admission_number="ADM-A", first_name="Albert", last_name="Einstein", gender=StudentGender.MALE, date_of_birth=date(2012, 3, 14), roll_number="1", admission_date=date(2026, 1, 1)))
    await db_session.commit()

    # 6. Teacher & Subject
    repo_tchr = TeacherRepository(db_session)
    teacher_a = await repo_tchr.create(tenant_a.id, TeacherCreate(school_id=school_a.id, employee_code=f"EMP-A-{suffix}", staff_code=f"STF-A-{suffix}", first_name="John", last_name="Doe", gender=StudentGender.MALE, date_of_birth=date(1985, 5, 20), mobile=f"+91987654{suffix[:4]}", official_email=f"teacher-a-{suffix}@edu.com", joining_date=date(2025, 1, 1), employment_type=EmploymentType.FULL_TIME))
    await db_session.commit()

    repo_sub = SubjectRepository(db_session)
    subject_a = await repo_sub.create(tenant_a.id, SubjectCreate(school_id=school_a.id, academic_year_id=ay_a.id, subject_code=f"MATH-{suffix.upper()}", subject_name="Mathematics", category=SubjectCategory.CORE, subject_type=SubjectType.THEORY))
    subject_a.status = SubjectStatus.ACTIVE
    await db_session.commit()

    # 7. Assignment
    repo_tsa = TeacherSubjectAssignmentRepository(db_session)
    tsa_a = await repo_tsa.create(tenant_a.id, TeacherSubjectAssignmentCreate(school_id=school_a.id, academic_year_id=ay_a.id, teacher_id=teacher_a.id, subject_id=subject_a.id, class_id=class_a.id, section_id=sec_a1.id, assignment_type="PRIMARY", weekly_periods=5, effective_from=date(2026, 1, 1)))
    tsa_a.status = AssignmentStatus.ACTIVE
    tsa_a.is_active = True
    await db_session.commit()

    # 8. Guardians
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

    user_admin = await auth_service.create_user(
        tenant_a.id,
        UserCreate(email=f"admin-{suffix}@a.com", password="Password123!", first_name="School", last_name="Admin", school_ids=[school_a.id])
    )
    user_admin.roles.append(role_a)

    user_parent = await auth_service.create_user(
        tenant_a.id,
        UserCreate(email=parent_email, password="Password123!", first_name="Albert", last_name="Einstein Sr", school_ids=[school_a.id])
    )
    user_parent.roles.append(role_a)

    await db_session.commit()

    tokens_a = await auth_service.create_tokens(user_admin)
    tokens_p = await auth_service.create_tokens(user_parent)

    return {
        "tenant_a": tenant_a, "tenant_b": tenant_b,
        "school_a": school_a, "school_b": school_b,
        "ay_a": ay_a, "ay_b": ay_b,
        "class_a": class_a, "class_b": class_b,
        "sec_a1": sec_a1, "sec_b": sec_b,
        "teacher_a": teacher_a, "subject_a": subject_a,
        "tsa_a": tsa_a, "guardian_a": guardian_a,
        "user_admin": user_admin, "user_parent": user_parent,
        "auth_headers": {
            "Authorization": f"Bearer {tokens_a.access_token}",
            "X-Tenant-ID": str(tenant_a.id)
        },
        "parent_auth_headers": {
            "Authorization": f"Bearer {tokens_p.access_token}",
            "X-Tenant-ID": str(tenant_a.id)
        }
    }

@pytest.mark.anyio
async def test_exam_template_crud(client: AsyncClient, setup_exam_test_data) -> None:
    data = setup_exam_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id

    # Create Template
    payload = {
        "template_name": "Mid-Term Template",
        "exam_type": "HALF_YEARLY",
        "subject_configs": [
            {"subject_id": str(data["subject_a"].id), "max_marks": 100, "pass_marks": 35}
        ]
    }
    resp = await client.post(
        f"/api/v1/examinations/templates?school_id={school_id}&academic_year_id={data['ay_a'].id}",
        json=payload,
        headers=headers
    )
    assert resp.status_code == 201
    assert resp.json()["data"]["template_name"] == "Mid-Term Template"

    # List Templates
    resp_list = await client.get(f"/api/v1/examinations/templates?school_id={school_id}", headers=headers)
    assert resp_list.status_code == 200
    assert len(resp_list.json()["data"]) == 1

@pytest.mark.anyio
async def test_exam_wizard_workflow(client: AsyncClient, setup_exam_test_data) -> None:
    data = setup_exam_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id

    # 1. Fetch Auto-Suggestion schedules from TSA
    resp_sugg = await client.get(
        f"/api/v1/examinations/wizard/suggest?school_id={school_id}&academic_year_id={data['ay_a'].id}&class_ids={data['class_a'].id}&start_date=2026-09-01&end_date=2026-09-10",
        headers=headers
    )
    assert resp_sugg.status_code == 200
    sugg_list = resp_sugg.json()["data"]
    assert len(sugg_list) == 1
    assert sugg_list[0]["class_id"] == str(data["class_a"].id)

    # 2. Submit Wizard request
    wizard_payload = {
        "school_id": str(school_id),
        "academic_year_id": str(data["ay_a"].id),
        "exam_name": "Quarterly Exam 2026",
        "exam_type": "QUARTERLY",
        "start_date": "2026-09-01",
        "end_date": "2026-09-10",
        "description": "Wizard exam configuration test",
        "schedules": sugg_list
    }
    resp_w = await client.post(
        f"/api/v1/examinations/wizard",
        json=wizard_payload,
        headers=headers
    )
    assert resp_w.status_code == 201
    exam_data = resp_w.json()["data"]
    assert exam_data["exam_name"] == "Quarterly Exam 2026"
    assert len(exam_data["schedules"]) == 1
    assert exam_data["schedules"][0]["max_marks"] == 100

@pytest.mark.anyio
async def test_exam_freeze_locked(client: AsyncClient, setup_exam_test_data) -> None:
    data = setup_exam_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id

    # Create exam
    payload = {
        "school_id": str(school_id),
        "academic_year_id": str(data["ay_a"].id),
        "exam_name": "Frozen Exam Test",
        "exam_type": "UNIT_TEST",
        "start_date": "2026-05-01",
        "end_date": "2026-05-05",
        "description": "Standard exam master"
    }
    resp = await client.post("/api/v1/examinations", json=payload, headers=headers)
    assert resp.status_code == 201
    exam_id = resp.json()["data"]["id"]

    # Lock the exam status
    lock_payload = {"status": "LOCKED"}
    resp_lock = await client.put(f"/api/v1/examinations/{exam_id}?school_id={school_id}", json=lock_payload, headers=headers)
    assert resp_lock.status_code == 200
    assert resp_lock.json()["data"]["status"] == "LOCKED"

    # Try modifying details after lock -> rejected with 422
    update_payload = {"exam_name": "Updated name fails"}
    resp_fail = await client.put(f"/api/v1/examinations/{exam_id}?school_id={school_id}", json=update_payload, headers=headers)
    assert resp_fail.status_code == 422
    assert "frozen" in resp_fail.json()["message"]

@pytest.mark.anyio
async def test_exam_copy_shift_dates(client: AsyncClient, setup_exam_test_data) -> None:
    data = setup_exam_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id

    # Setup source exam with 1 schedule paper on Sep 5
    wizard_payload = {
        "school_id": str(school_id),
        "academic_year_id": str(data["ay_a"].id),
        "exam_name": "Term 1 Exam",
        "exam_type": "HALF_YEARLY",
        "start_date": "2026-09-01",
        "end_date": "2026-09-10",
        "schedules": [
            {
                "class_id": str(data["class_a"].id),
                "section_id": str(data["sec_a1"].id),
                "subject_id": str(data["subject_a"].id),
                "teacher_subject_assignment_id": str(data["tsa_a"].id),
                "exam_date": "2026-09-05",
                "start_time": "09:00:00",
                "end_time": "12:00:00",
                "max_marks": 100,
                "pass_marks": 35,
                "room_number": "Room 1"
            }
        ]
    }
    resp_src = await client.post("/api/v1/examinations/wizard", json=wizard_payload, headers=headers)
    assert resp_src.status_code == 201
    source_id = resp_src.json()["data"]["id"]

    # Copy Term 1 Exam to Oct start range (shifted 30 days ahead)
    copy_payload = {
        "source_exam_id": source_id,
        "new_exam_name": "Term 2 Exam Cloned",
        "new_start_date": "2026-10-01",
        "new_end_date": "2026-10-10"
    }
    resp_copy = await client.post(f"/api/v1/examinations/copy?school_id={school_id}", json=copy_payload, headers=headers)
    assert resp_copy.status_code == 201
    new_data = resp_copy.json()["data"]
    assert new_data["exam_name"] == "Term 2 Exam Cloned"
    # The schedule paper date shifts from Sep 5 to Oct 5 (shifted 30 days exactly)
    assert new_data["schedules"][0]["exam_date"] == "2026-10-05"

@pytest.mark.anyio
async def test_exam_parent_view(client: AsyncClient, setup_exam_test_data) -> None:
    from app.main import app
    from app.api.dependencies.auth import get_current_user

    data = setup_exam_test_data
    headers = data["auth_headers"]
    parent_headers = data["parent_auth_headers"]
    school_id = data["school_a"].id

    # 1. Create draft exam schedules via wizard
    wizard_payload = {
        "school_id": str(school_id),
        "academic_year_id": str(data["ay_a"].id),
        "exam_name": "Monthly Mid Test",
        "exam_type": "MONTHLY",
        "start_date": "2026-06-01",
        "end_date": "2026-06-05",
        "schedules": [
            {
                "class_id": str(data["class_a"].id),
                "section_id": str(data["sec_a1"].id),
                "subject_id": str(data["subject_a"].id),
                "teacher_subject_assignment_id": str(data["tsa_a"].id),
                "exam_date": "2026-06-02",
                "start_time": "09:00:00",
                "end_time": "12:00:00",
                "max_marks": 100,
                "pass_marks": 35,
                "room_number": "Room 5"
            }
        ]
    }
    resp_w = await client.post("/api/v1/examinations/wizard", json=wizard_payload, headers=headers)
    assert resp_w.status_code == 201
    exam_id = resp_w.json()["data"]["id"]

    # 2. Query parent endpoint -> should return 0 items because the exam is in DRAFT
    async def mock_parent():
        return data["user_parent"]

    app.dependency_overrides[get_current_user] = mock_parent
    try:
        resp_parent_empty = await client.get(f"/api/v1/examinations/parent?school_id={school_id}", headers=parent_headers)
        assert resp_parent_empty.status_code == 200
        assert len(resp_parent_empty.json()["data"]) == 0
    finally:
        del app.dependency_overrides[get_current_user]

    # 3. Publish the exam schedule
    async def mock_admin():
        return data["user_admin"]

    app.dependency_overrides[get_current_user] = mock_admin
    try:
        await client.post(f"/api/v1/examinations/{exam_id}/publish?school_id={school_id}", headers=headers)
    finally:
        del app.dependency_overrides[get_current_user]

    # 4. Parent views again -> now returns the published schedule paper details
    app.dependency_overrides[get_current_user] = mock_parent
    try:
        resp_parent_filled = await client.get(f"/api/v1/examinations/parent?school_id={school_id}", headers=parent_headers)
        assert resp_parent_filled.status_code == 200
        assert len(resp_parent_filled.json()["data"]) == 1
        assert resp_parent_filled.json()["data"][0]["room_number"] == "Room 5"
    finally:
        del app.dependency_overrides[get_current_user]

@pytest.mark.anyio
async def test_exam_conflict_detection(client: AsyncClient, setup_exam_test_data) -> None:
    data = setup_exam_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id

    # Create first exam scheduled on Sep 1 at 09:00 for Class A
    wizard_payload1 = {
        "school_id": str(school_id),
        "academic_year_id": str(data["ay_a"].id),
        "exam_name": "Wizard Clash Test Master 1",
        "exam_type": "QUARTERLY",
        "start_date": "2026-09-01",
        "end_date": "2026-09-05",
        "schedules": [
            {
                "class_id": str(data["class_a"].id),
                "section_id": str(data["sec_a1"].id),
                "subject_id": str(data["subject_a"].id),
                "teacher_subject_assignment_id": str(data["tsa_a"].id),
                "exam_date": "2026-09-01",
                "start_time": "09:00:00",
                "end_time": "12:00:00",
                "max_marks": 100,
                "pass_marks": 35,
                "room_number": "Room 10"
            }
        ]
    }
    resp1 = await client.post("/api/v1/examinations/wizard", json=wizard_payload1, headers=headers)
    assert resp1.status_code == 201

    # Try creating another exam on same Sep 1 at 09:00 for same Class A -> Class overlap clash blocks it with 422
    wizard_payload2 = {
        "school_id": str(school_id),
        "academic_year_id": str(data["ay_a"].id),
        "exam_name": "Wizard Clash Test Master 2",
        "exam_type": "QUARTERLY",
        "start_date": "2026-09-01",
        "end_date": "2026-09-05",
        "schedules": [
            {
                "class_id": str(data["class_a"].id),
                "section_id": str(data["sec_a1"].id),
                "subject_id": str(data["subject_a"].id),
                "teacher_subject_assignment_id": str(data["tsa_a"].id),
                "exam_date": "2026-09-01",
                "start_time": "09:00:00",
                "end_time": "12:00:00",
                "max_marks": 100,
                "pass_marks": 35,
                "room_number": "Room 11"
            }
        ]
    }
    resp2 = await client.post("/api/v1/examinations/wizard", json=wizard_payload2, headers=headers)
    assert resp2.status_code == 422
    assert "conflict" in resp2.json()["message"]

@pytest.mark.anyio
async def test_new_examination_validation_rules(client: AsyncClient, setup_exam_test_data) -> None:
    data = setup_exam_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id
    ay_id = data["ay_a"].id

    # 1. Valid future date inside active academic year succeeds + Dynamic academic year resolution (ay_id omitted)
    payload_valid = {
        "school_id": str(school_id),
        "exam_name": "Wizard Valid Exam 2026",
        "exam_type": "QUARTERLY",
        "start_date": "2026-06-01",
        "end_date": "2026-06-05",
        "target_scope": "ALL_CLASSES",
        "schedules": []
    }
    resp_valid = await client.post("/api/v1/examinations/wizard", json=payload_valid, headers=headers)
    assert resp_valid.status_code == 201
    res_data = resp_valid.json()["data"]
    assert res_data["academic_year_id"] == str(ay_id)
    assert res_data["settings"]["target_scope"] == "ALL_CLASSES"

    # 2. Date outside active academic year fails (2027 is outside 2026 bounds)
    payload_outside = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "exam_name": "Wizard Outside Exam",
        "exam_type": "QUARTERLY",
        "start_date": "2027-06-01",
        "end_date": "2027-06-05",
        "target_scope": "ALL_CLASSES",
        "schedules": []
    }
    resp_outside = await client.post("/api/v1/examinations/wizard", json=payload_outside, headers=headers)
    assert resp_outside.status_code == 422

    # 3. Start date after end date fails
    payload_invalid_dates = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "exam_name": "Wizard Date Conflict Exam",
        "exam_type": "QUARTERLY",
        "start_date": "2026-06-05",
        "end_date": "2026-06-01",
        "target_scope": "ALL_CLASSES",
        "schedules": []
    }
    resp_invalid_dates = await client.post("/api/v1/examinations/wizard", json=payload_invalid_dates, headers=headers)
    assert resp_invalid_dates.status_code == 422

    # 4. SPECIFIC_CLASSES requires class_ids
    payload_spec_classes_fail = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "exam_name": "Wizard Specific Classes Fail",
        "exam_type": "QUARTERLY",
        "start_date": "2026-06-01",
        "end_date": "2026-06-05",
        "target_scope": "SPECIFIC_CLASSES",
        "class_ids": [],
        "schedules": []
    }
    resp_spec_classes_fail = await client.post("/api/v1/examinations/wizard", json=payload_spec_classes_fail, headers=headers)
    assert resp_spec_classes_fail.status_code == 422

    # 5. SPECIFIC_CLASSES succeeds with class_ids
    payload_spec_classes_ok = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "exam_name": "Wizard Specific Classes OK",
        "exam_type": "QUARTERLY",
        "start_date": "2026-06-01",
        "end_date": "2026-06-05",
        "target_scope": "SPECIFIC_CLASSES",
        "class_ids": [str(data["class_a"].id)],
        "schedules": []
    }
    resp_spec_classes_ok = await client.post("/api/v1/examinations/wizard", json=payload_spec_classes_ok, headers=headers)
    assert resp_spec_classes_ok.status_code == 201

    # 6. SPECIFIC_SECTIONS requires section_ids
    payload_spec_secs_fail = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "exam_name": "Wizard Specific Sections Fail",
        "exam_type": "QUARTERLY",
        "start_date": "2026-06-01",
        "end_date": "2026-06-05",
        "target_scope": "SPECIFIC_SECTIONS",
        "section_ids": [],
        "schedules": []
    }
    resp_spec_secs_fail = await client.post("/api/v1/examinations/wizard", json=payload_spec_secs_fail, headers=headers)
    assert resp_spec_secs_fail.status_code == 422

    # 7. SPECIFIC_SECTIONS succeeds with section_ids
    payload_spec_secs_ok = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "exam_name": "Wizard Specific Sections OK",
        "exam_type": "QUARTERLY",
        "start_date": "2026-06-01",
        "end_date": "2026-06-05",
        "target_scope": "SPECIFIC_SECTIONS",
        "section_ids": [str(data["sec_a1"].id)],
        "schedules": []
    }
    resp_spec_secs_ok = await client.post("/api/v1/examinations/wizard", json=payload_spec_secs_ok, headers=headers)
    assert resp_spec_secs_ok.status_code == 201

    # 8. Cross-school examination creation remains rejected
    payload_cross_school = {
        "school_id": str(data["school_b"].id),
        "academic_year_id": str(data["ay_b"].id),
        "exam_name": "Cross School Hack",
        "exam_type": "QUARTERLY",
        "start_date": "2026-06-01",
        "end_date": "2026-06-05",
        "target_scope": "ALL_CLASSES",
        "schedules": []
    }
    resp_cross = await client.post("/api/v1/examinations/wizard", json=payload_cross_school, headers=headers)
    assert resp_cross.status_code == 403

