import uuid
import pytest
from datetime import date, time, datetime, timezone, timedelta
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tenant import Tenant
from app.models.school import School
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.class_entity import Class, ClassCategory
from app.models.section import Section
from app.models.student import Student, StudentGender
from app.models.teacher import Teacher, EmploymentType
from app.models.subject import Subject, SubjectCategory, SubjectType, SubjectStatus
from app.models.teacher_subject_assignment import TeacherSubjectAssignment, AssignmentStatus
from app.models.guardian import Guardian, StudentGuardian, StudentGuardianRelationship, GuardianType
from app.models.role import Role
from app.models.permission import Permission
from app.models.examination import Examination, ExamSchedule, ExamStatus, ExamType
from app.models.marks import Marks, MarksStatus, ExamResult

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
async def setup_marks_test_data(db_session: AsyncSession):
    suffix = uuid.uuid4().hex[:6].lower()

    # 1. Create Tenant
    repo_t = TenantRepository(db_session)
    tenant_a = await repo_t.create(TenantCreate(name="Marks Tenant A", code=f"marks-a-{suffix}", subdomain=f"marks-a-{suffix}", email=f"a-{suffix}@t.com"))
    await db_session.commit()

    # 2. Create School
    repo_s = SchoolRepository(db_session)
    school_a = await repo_s.create(tenant_a.id, SchoolCreate(name="Marks School A", code=f"SC_A_{suffix.upper()}", address="123 Street", city="Bangalore", state="Karnataka", country="India", pin_code="560001", board="CBSE", email=f"s-a-{suffix}@a.com", status=SchoolStatus.ACTIVE))
    await db_session.commit()

    # 3. Academic Year
    repo_ay = AcademicYearRepository(db_session)
    ay_a = await repo_ay.create(tenant_a.id, school_a.id, AcademicYearCreate(school_id=school_a.id, name="Year 2026", code="AY2026", start_date=date(2026, 1, 1), end_date=date(2026, 12, 31), status=AcademicYearStatus.ACTIVE, is_current=True))
    ay_a.status = AcademicYearStatus.ACTIVE
    await db_session.commit()

    # 4. Classes & Sections
    repo_c = ClassRepository(db_session)
    class_a = await repo_c.create(tenant_a.id, ClassCreate(school_id=school_a.id, academic_year_id=ay_a.id, name="Grade 8", code="G8", level=8, category=ClassCategory.MIDDLE, capacity=35))
    await db_session.commit()

    repo_sec = SectionRepository(db_session)
    sec_a1 = await repo_sec.create(tenant_a.id, SectionCreate(school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_a.id, name="Section A1", code="SEC_A1", capacity=35))
    await db_session.commit()

    # 5. Students
    repo_stud = StudentRepository(db_session)
    stud1 = await repo_stud.create(tenant_a.id, StudentCreate(school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_a.id, section_id=sec_a1.id, admission_number="ADM-1", first_name="Albert", last_name="Einstein", gender=StudentGender.MALE, date_of_birth=date(2012, 3, 14), roll_number="10", admission_date=date(2026, 1, 1)))
    stud2 = await repo_stud.create(tenant_a.id, StudentCreate(school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_a.id, section_id=sec_a1.id, admission_number="ADM-2", first_name="Marie", last_name="Curie", gender=StudentGender.FEMALE, date_of_birth=date(2012, 11, 7), roll_number="2", admission_date=date(2026, 1, 1)))
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
        student_id=stud1.id,
        guardian_id=guardian_a.id,
        relationship=StudentGuardianRelationship.FATHER,
        is_primary=True,
        receives_notifications=True
    )
    db_session.add(sg)
    await db_session.commit()

    # 9. Examination & Schedule
    exam = Examination(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        exam_name="Quarterly Exam 2026",
        exam_type=ExamType.QUARTERLY,
        start_date=date(2026, 9, 1),
        end_date=date(2026, 9, 10),
        status=ExamStatus.PUBLISHED,
        created_by=uuid.uuid4(),
        updated_by=uuid.uuid4()
    )
    db_session.add(exam)
    await db_session.flush()

    sched = ExamSchedule(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        exam_id=exam.id,
        class_id=class_a.id,
        section_id=sec_a1.id,
        subject_id=subject_a.id,
        teacher_subject_assignment_id=tsa_a.id,
        exam_date=date(2026, 9, 2),
        start_time=time(9, 0),
        end_time=time(12, 0),
        max_marks=100,
        pass_marks=35,
        room_number="Room 101",
        created_by=uuid.uuid4(),
        updated_by=uuid.uuid4()
    )
    db_session.add(sched)
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
        UserCreate(email=f"admin-{suffix}@a.com", password="Password123!", first_name="School", last_name="Admin")
    )
    user_admin.roles.append(role_a)

    user_parent = await auth_service.create_user(
        tenant_a.id,
        UserCreate(email=parent_email, password="Password123!", first_name="Albert", last_name="Einstein Sr")
    )
    user_parent.roles.append(role_a)

    await db_session.commit()

    tokens_a = await auth_service.create_tokens(user_admin)
    tokens_p = await auth_service.create_tokens(user_parent)

    return {
        "tenant_a": tenant_a,
        "school_a": school_a,
        "ay_a": ay_a,
        "class_a": class_a,
        "sec_a1": sec_a1,
        "teacher_a": teacher_a,
        "subject_a": subject_a,
        "tsa_a": tsa_a,
        "guardian_a": guardian_a,
        "stud1": stud1,
        "stud2": stud2,
        "exam": exam,
        "sched": sched,
        "user_admin": user_admin,
        "user_parent": user_parent,
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
async def test_bulk_save_marks_draft_autosave(client: AsyncClient, setup_marks_test_data, db_session: AsyncSession) -> None:
    data = setup_marks_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id

    # 1. Autosave with partial entries (autosave allows skipping missing students)
    payload = {
        "exam_schedule_id": str(data["sched"].id),
        "teacher_subject_assignment_id": str(data["tsa_a"].id),
        "marks": [
            {
                "student_id": str(data["stud1"].id),
                "marks_obtained": 45.0,
                "result_status": "PRESENT",
                "remarks": "Decent effort"
            }
        ]
    }
    resp = await client.post(
        f"/api/v1/marks/bulk?school_id={school_id}&autosave=true",
        json=payload,
        headers=headers
    )
    assert resp.status_code == 201
    assert len(resp.json()["data"]) == 1
    assert resp.json()["data"][0]["status"] == "DRAFT"

    # 2. Check that TSA settings saved the resume session details
    stmt = select(TeacherSubjectAssignment).where(TeacherSubjectAssignment.id == data["tsa_a"].id)
    res = await db_session.execute(stmt)
    tsa = res.scalar_one()
    assert tsa.settings["last_marks_session"]["last_student_id"] == str(data["stud1"].id)

@pytest.mark.anyio
async def test_wizard_entry_smart_missing(client: AsyncClient, setup_marks_test_data) -> None:
    data = setup_marks_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id

    # Save 1 mark record first
    payload = {
        "exam_schedule_id": str(data["sched"].id),
        "teacher_subject_assignment_id": str(data["tsa_a"].id),
        "marks": [
            {"student_id": str(data["stud2"].id), "marks_obtained": 90.0, "result_status": "PRESENT"}
        ]
    }
    await client.post(f"/api/v1/marks/bulk?school_id={school_id}", json=payload, headers=headers)

    # Fetch Wizard entry sheet
    resp = await client.get(
        f"/api/v1/marks/wizard/entry?school_id={school_id}&exam_schedule_id={data['sched'].id}",
        headers=headers
    )
    assert resp.status_code == 200
    summary = resp.json()["data"]
    assert summary["total_students"] == 2
    assert summary["entered_count"] == 1
    assert summary["missing_count"] == 1
    assert summary["average_score"] == 90.0
    
    # Assert roll number sorting: "2" (Marie Curie) should be before "10" (Albert Einstein)
    entries = summary["entries"]
    assert entries[0]["student"]["roll_number"] == "2"
    assert entries[1]["student"]["roll_number"] == "10"

@pytest.mark.anyio
async def test_audit_trail_history(client: AsyncClient, setup_marks_test_data) -> None:
    data = setup_marks_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id

    # Save initial mark
    payload1 = {
        "exam_schedule_id": str(data["sched"].id),
        "teacher_subject_assignment_id": str(data["tsa_a"].id),
        "marks": [
            {"student_id": str(data["stud1"].id), "marks_obtained": 45.0, "result_status": "PRESENT"}
        ]
    }
    await client.post(f"/api/v1/marks/bulk?school_id={school_id}", json=payload1, headers=headers)

    # Correct the mark to 48.0
    payload2 = {
        "exam_schedule_id": str(data["sched"].id),
        "teacher_subject_assignment_id": str(data["tsa_a"].id),
        "marks": [
            {"student_id": str(data["stud1"].id), "marks_obtained": 48.0, "result_status": "PRESENT"}
        ]
    }
    resp_corr = await client.put(f"/api/v1/marks/bulk?school_id={school_id}", json=payload2, headers=headers)
    assert resp_corr.status_code == 200
    mark_record = resp_corr.json()["data"][0]
    assert mark_record["marks_obtained"] == 48.0
    
    # Audit history check
    audit = mark_record["audit_history"]
    assert len(audit) == 1
    assert audit[0]["old_marks"] == 45.0
    assert audit[0]["new_marks"] == 48.0

@pytest.mark.anyio
async def test_rollback_on_failure(client: AsyncClient, setup_marks_test_data, db_session: AsyncSession) -> None:
    data = setup_marks_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id

    sched_id = data["sched"].id
    tsa_id = data["tsa_a"].id
    stud1_id = data["stud1"].id
    stud2_id = data["stud2"].id

    # Save marks payload where one student exceeds maximum marks limit (110 / 100)
    payload = {
        "exam_schedule_id": str(sched_id),
        "teacher_subject_assignment_id": str(tsa_id),
        "marks": [
            {"student_id": str(stud2_id), "marks_obtained": 80.0, "result_status": "PRESENT"},
            {"student_id": str(stud1_id), "marks_obtained": 110.0, "result_status": "PRESENT"} # Exceeds max
        ]
    }
    resp = await client.post(f"/api/v1/marks/bulk?school_id={school_id}", json=payload, headers=headers)
    assert resp.status_code == 422

    # Verify no marks were created in the database (rolled back successfully)
    stmt = select(Marks).where(Marks.exam_schedule_id == sched_id)
    res = await db_session.execute(stmt)
    records = res.scalars().all()
    assert len(records) == 0

@pytest.mark.anyio
async def test_absent_nullifies_marks(client: AsyncClient, setup_marks_test_data) -> None:
    data = setup_marks_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id

    payload = {
        "exam_schedule_id": str(data["sched"].id),
        "teacher_subject_assignment_id": str(data["tsa_a"].id),
        "marks": [
            {"student_id": str(data["stud1"].id), "marks_obtained": 50.0, "result_status": "ABSENT"}
        ]
    }
    resp = await client.post(f"/api/v1/marks/bulk?school_id={school_id}", json=payload, headers=headers)
    assert resp.status_code == 201
    assert resp.json()["data"][0]["marks_obtained"] is None

@pytest.mark.anyio
async def test_visibility_restrictions(client: AsyncClient, setup_marks_test_data, db_session: AsyncSession) -> None:
    from app.main import app
    from app.api.dependencies.auth import get_current_user

    data = setup_marks_test_data
    headers = data["auth_headers"]
    parent_headers = data["parent_auth_headers"]
    school_id = data["school_a"].id

    # 1. Create draft marks
    payload = {
        "exam_schedule_id": str(data["sched"].id),
        "teacher_subject_assignment_id": str(data["tsa_a"].id),
        "marks": [
            {"student_id": str(data["stud1"].id), "marks_obtained": 75.0, "result_status": "PRESENT"}
        ]
    }
    await client.post(f"/api/v1/marks/bulk?school_id={school_id}", json=payload, headers=headers)

    async def mock_parent():
        return data["user_parent"]

    # 2. Query parent endpoint -> should return 0 items because marks are in DRAFT status
    app.dependency_overrides[get_current_user] = mock_parent
    try:
        resp_p_empty = await client.get(f"/api/v1/marks/student?school_id={school_id}", headers=parent_headers)
        assert resp_p_empty.status_code == 200
        assert len(resp_p_empty.json()["data"]) == 0
    finally:
        del app.dependency_overrides[get_current_user]

    # 3. Publish the marks
    async def mock_admin():
        return data["user_admin"]

    app.dependency_overrides[get_current_user] = mock_admin
    try:
        # Check summary first
        resp_sum = await client.get(f"/api/v1/marks/publish/summary?school_id={school_id}&exam_schedule_id={data['sched'].id}", headers=headers)
        assert resp_sum.status_code == 200
        assert resp_sum.json()["data"]["entered_count"] == 1
        
        # Do publish
        resp_pub = await client.post(f"/api/v1/marks/publish?school_id={school_id}&exam_schedule_id={data['sched'].id}", headers=headers)
        assert resp_pub.status_code == 200
    finally:
        del app.dependency_overrides[get_current_user]

    # 4. Query parent view again -> now returns the published mark record
    app.dependency_overrides[get_current_user] = mock_parent
    try:
        resp_p_filled = await client.get(f"/api/v1/marks/student?school_id={school_id}", headers=parent_headers)
        assert resp_p_filled.status_code == 200
        assert len(resp_p_filled.json()["data"]) == 1
        assert resp_p_filled.json()["data"][0]["marks_obtained"] == 75.0
    finally:
        del app.dependency_overrides[get_current_user]
