import os
import uuid
import pytest
from datetime import date, time, datetime, timezone, timedelta
from httpx import AsyncClient
from sqlalchemy import select, update
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
from app.models.attendance import Attendance, AttendanceSession, AttendanceStatus
from app.models.report_card import ReportCardPublication, ReportCardStatus

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

@pytest.fixture
async def setup_report_test_data(db_session: AsyncSession):
    suffix = uuid.uuid4().hex[:6].lower()

    # 1. Create Tenant
    repo_t = TenantRepository(db_session)
    tenant_a = await repo_t.create(TenantCreate(name="Report Tenant A", code=f"report-a-{suffix}", subdomain=f"report-a-{suffix}", email=f"a-{suffix}@t.com"))
    await db_session.commit()

    # 2. Create School
    repo_s = SchoolRepository(db_session)
    school_a = await repo_s.create(tenant_a.id, SchoolCreate(
        name="Report School A", code=f"RC_A_{suffix.upper()}", address="123 Street", city="Bangalore",
        state="Karnataka", country="India", pin_code="560001", board="CBSE", email=f"s-a-{suffix}@a.com",
        status=SchoolStatus.ACTIVE
    ))
    
    school_a.settings = {
        "grade_policy": [
            {"grade": "A+", "min_percentage": 90, "max_percentage": 100},
            {"grade": "A", "min_percentage": 80, "max_percentage": 89.99},
            {"grade": "B", "min_percentage": 70, "max_percentage": 79.99},
            {"grade": "C", "min_percentage": 60, "max_percentage": 69.99},
            {"grade": "D", "min_percentage": 50, "max_percentage": 59.99},
            {"grade": "E", "min_percentage": 35, "max_percentage": 49.99},
            {"grade": "F", "min_percentage": 0, "max_percentage": 34.99}
        ],
        "promotion_policy": {
            "min_attendance_pct": 75.0,
            "min_overall_pct": 35.0,
            "max_failed_subjects": 0
        }
    }
    db_session.add(school_a)
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

    # 8. Examination & Schedule
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

    # 9. Timetable & Attendance Session & Logs
    from app.repositories.timetable import TimetableRepository
    from app.schemas.timetable import TimetableCreate
    repo_tt = TimetableRepository(db_session)
    tt_a = await repo_tt.create(tenant_a.id, TimetableCreate(
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        teacher_subject_assignment_id=tsa_a.id,
        class_id=class_a.id,
        section_id=sec_a1.id,
        day_of_week="MONDAY",
        period_number=1,
        start_time="08:30:00",
        end_time="09:15:00",
        period_type="REGULAR"
    ))
    tt_a.teacher_id = teacher_a.id
    tt_a.subject_id = subject_a.id
    await db_session.commit()

    sess1 = AttendanceSession(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        class_id=class_a.id,
        section_id=sec_a1.id,
        timetable_id=tt_a.id,
        attendance_date=date(2026, 3, 2),
        teacher_id=teacher_a.id,
        subject_id=subject_a.id
    )
    db_session.add(sess1)
    await db_session.flush()

    att1 = Attendance(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        class_id=class_a.id,
        section_id=sec_a1.id,
        attendance_session_id=sess1.id,
        student_id=stud1.id,
        timetable_id=tt_a.id,
        attendance_date=date(2026, 3, 2),
        attendance_status=AttendanceStatus.PRESENT,
        teacher_id=teacher_a.id,
        subject_id=subject_a.id,
        remarks="Early",
        created_by=uuid.uuid4(),
        updated_by=uuid.uuid4()
    )
    db_session.add(att1)
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
    await db_session.commit()

    tokens_a = await auth_service.create_tokens(user_admin)

    return {
        "tenant_a": tenant_a,
        "school_a": school_a,
        "ay_a": ay_a,
        "class_a": class_a,
        "sec_a1": sec_a1,
        "teacher_a": teacher_a,
        "subject_a": subject_a,
        "tsa_a": tsa_a,
        "stud1": stud1,
        "exam": exam,
        "sched": sched,
        "sess1": sess1,
        "att1": att1,
        "user_admin": user_admin,
        "auth_headers": {
            "Authorization": f"Bearer {tokens_a.access_token}",
            "X-Tenant-ID": str(tenant_a.id)
        }
    }

from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate, SchoolStatus
from app.schemas.academic_year import AcademicYearCreate
from app.schemas.class_entity import ClassCreate
from app.schemas.section import SectionCreate
from app.schemas.student import StudentCreate
from app.schemas.teacher import TeacherCreate
from app.schemas.subject import SubjectCreate
from app.schemas.teacher_subject_assignment import TeacherSubjectAssignmentCreate
from app.schemas.auth import UserCreate

@pytest.mark.anyio
async def test_report_card_preview_calculation(client: AsyncClient, setup_report_test_data, db_session: AsyncSession) -> None:
    data = setup_report_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id
    student_id = data["stud1"].id

    # Seed published marks
    mark = Marks(
        tenant_id=data["tenant_a"].id,
        school_id=school_id,
        academic_year_id=data["ay_a"].id,
        examination_id=data["exam"].id,
        exam_schedule_id=data["sched"].id,
        student_id=student_id,
        teacher_subject_assignment_id=data["tsa_a"].id,
        teacher_id=data["teacher_a"].id,
        subject_id=data["subject_a"].id,
        class_id=data["class_a"].id,
        section_id=data["sec_a1"].id,
        maximum_marks=100,
        marks_obtained=85.0,
        result_status=ExamResult.PRESENT,
        status=MarksStatus.PUBLISHED,
        created_by=data["user_admin"].id,
        updated_by=data["user_admin"].id
    )
    db_session.add(mark)
    await db_session.commit()

    # Call preview endpoint
    resp = await client.get(
        f"/api/v1/report-cards/preview/{student_id}?school_id={school_id}&teacher_remarks=Excellent+progress.",
        headers=headers
    )
    assert resp.status_code == 200
    preview = resp.json()["data"]
    assert preview["student_name"] == "Albert Einstein"
    assert preview["attendance_total"] == 1
    assert preview["attendance_present"] == 1
    assert preview["attendance_percentage"] == 100.0
    assert preview["overall_percentage"] == 85.0
    assert preview["overall_grade"] == "A" # policy 80-89.99 is A
    assert preview["promotion_status"] == "PROMOTED"
    assert preview["is_valid"] is True

@pytest.mark.anyio
async def test_report_card_missing_data_warnings(client: AsyncClient, setup_report_test_data, db_session: AsyncSession) -> None:
    data = setup_report_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id
    student_id = data["stud1"].id

    # Scenario: marks not entered, remarks not provided, no attendance Sessions taken
    resp = await client.get(
        f"/api/v1/report-cards/preview/{student_id}?school_id={school_id}",
        headers=headers
    )
    assert resp.status_code == 200
    preview = resp.json()["data"]
    assert preview["is_valid"] is False
    assert len(preview["missing_reasons"]) > 0
    assert any("marks not entered" in r for r in preview["missing_reasons"])
    assert any("Teacher remark not entered" in r for r in preview["missing_reasons"])

@pytest.mark.anyio
async def test_single_and_bulk_class_generation(client: AsyncClient, setup_report_test_data, db_session: AsyncSession) -> None:
    data = setup_report_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id
    student_id = data["stud1"].id

    # Seed marks
    mark = Marks(
        tenant_id=data["tenant_a"].id,
        school_id=school_id,
        academic_year_id=data["ay_a"].id,
        examination_id=data["exam"].id,
        exam_schedule_id=data["sched"].id,
        student_id=student_id,
        teacher_subject_assignment_id=data["tsa_a"].id,
        teacher_id=data["teacher_a"].id,
        subject_id=data["subject_a"].id,
        class_id=data["class_a"].id,
        section_id=data["sec_a1"].id,
        maximum_marks=100,
        marks_obtained=92.0,
        result_status=ExamResult.PRESENT,
        status=MarksStatus.PUBLISHED,
        created_by=data["user_admin"].id,
        updated_by=data["user_admin"].id
    )
    db_session.add(mark)
    await db_session.commit()

    # Generate single report card
    payload = {
        "student_id": str(student_id),
        "school_id": str(school_id),
        "teacher_remarks": "Brilliant Student"
    }
    resp_gen = await client.post("/api/v1/report-cards/generate", json=payload, headers=headers)
    assert resp_gen.status_code == 201
    assert resp_gen.json()["data"]["status"] == "DRAFT"

    # Bulk generate class
    bulk_payload = {
        "class_id": str(data["class_a"].id),
        "section_id": str(data["sec_a1"].id),
        "school_id": str(school_id)
    }
    resp_bulk = await client.post("/api/v1/report-cards/generate/class", json=bulk_payload, headers=headers)
    assert resp_bulk.status_code == 201
    assert resp_bulk.json()["data"]["generated_count"] == 1

@pytest.mark.anyio
async def test_principal_workflow_and_locking(client: AsyncClient, setup_report_test_data, db_session: AsyncSession) -> None:
    data = setup_report_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id
    student_id = data["stud1"].id

    # Seed marks
    mark = Marks(
        tenant_id=data["tenant_a"].id,
        school_id=school_id,
        academic_year_id=data["ay_a"].id,
        examination_id=data["exam"].id,
        exam_schedule_id=data["sched"].id,
        student_id=student_id,
        teacher_subject_assignment_id=data["tsa_a"].id,
        teacher_id=data["teacher_a"].id,
        subject_id=data["subject_a"].id,
        class_id=data["class_a"].id,
        section_id=data["sec_a1"].id,
        maximum_marks=100,
        marks_obtained=75.0,
        result_status=ExamResult.PRESENT,
        status=MarksStatus.PUBLISHED,
        created_by=data["user_admin"].id,
        updated_by=data["user_admin"].id
    )
    db_session.add(mark)
    await db_session.commit()

    # Generate Draft
    payload = {
        "student_id": str(student_id),
        "school_id": str(school_id),
        "teacher_remarks": "Keeps learning"
    }
    resp = await client.post("/api/v1/report-cards/generate", json=payload, headers=headers)
    rep_id = resp.json()["data"]["id"]

    # Workflow lifecycle: DRAFT -> UNDER_REVIEW -> APPROVED -> PUBLISHED -> LOCKED
    # 1. Submit review
    resp_rev = await client.post(f"/api/v1/report-cards/{rep_id}/submit-review?school_id={school_id}", headers=headers)
    assert resp_rev.status_code == 200
    assert resp_rev.json()["data"]["status"] == "UNDER_REVIEW"

    # 2. Principal Approve
    resp_app = await client.post(f"/api/v1/report-cards/{rep_id}/approve?school_id={school_id}", headers=headers)
    assert resp_app.status_code == 200
    assert resp_app.json()["data"]["status"] == "APPROVED"

    # 3. Publish
    resp_pub = await client.post(
        f"/api/v1/report-cards/publish?class_id={data['class_a'].id}&section_id={data['sec_a1'].id}&school_id={school_id}",
        headers=headers
    )
    assert resp_pub.status_code == 200

    # 4. Lock
    resp_lock = await client.post(f"/api/v1/report-cards/{rep_id}/lock?school_id={school_id}", headers=headers)
    assert resp_lock.status_code == 200
    assert resp_lock.json()["data"]["status"] == "LOCKED"

    # Verify locked blocks modifications
    resp_bad = await client.post("/api/v1/report-cards/generate", json=payload, headers=headers)
    assert resp_bad.status_code == 422
    assert "locked and cannot be regenerated" in resp_bad.json()["message"]

@pytest.mark.anyio
async def test_regeneration_guardrails(client: AsyncClient, setup_report_test_data, db_session: AsyncSession) -> None:
    data = setup_report_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id
    student_id = data["stud1"].id

    # Seed marks
    mark = Marks(
        tenant_id=data["tenant_a"].id,
        school_id=school_id,
        academic_year_id=data["ay_a"].id,
        examination_id=data["exam"].id,
        exam_schedule_id=data["sched"].id,
        student_id=student_id,
        teacher_subject_assignment_id=data["tsa_a"].id,
        teacher_id=data["teacher_a"].id,
        subject_id=data["subject_a"].id,
        class_id=data["class_a"].id,
        section_id=data["sec_a1"].id,
        maximum_marks=100,
        marks_obtained=75.0,
        result_status=ExamResult.PRESENT,
        status=MarksStatus.PUBLISHED,
        created_by=data["user_admin"].id,
        updated_by=data["user_admin"].id
    )
    db_session.add(mark)
    await db_session.commit()

    # 1. Generate Report Card
    payload = {
        "student_id": str(student_id),
        "school_id": str(school_id),
        "teacher_remarks": "Tries hard"
    }
    resp = await client.post("/api/v1/report-cards/generate", json=payload, headers=headers)
    rep_id = resp.json()["data"]["id"]

    # 2. Promote to Published
    await client.post(f"/api/v1/report-cards/{rep_id}/submit-review?school_id={school_id}", headers=headers)
    await client.post(f"/api/v1/report-cards/{rep_id}/approve?school_id={school_id}", headers=headers)
    await client.post(
        f"/api/v1/report-cards/publish?class_id={data['class_a'].id}&section_id={data['sec_a1'].id}&school_id={school_id}",
        headers=headers
    )

    # Verify that trying to regenerate is rejected (no corrections yet)
    resp_fail = await client.post("/api/v1/report-cards/generate", json=payload, headers=headers)
    assert resp_fail.status_code == 422
    assert "no marks corrections" in resp_fail.json()["message"]

    # 3. Correct Marks (shifts updated_at timestamp)
    now_future = datetime.now(timezone.utc) + timedelta(minutes=5)
    await db_session.execute(
        update(Marks).where(Marks.id == mark.id).values(marks_obtained=80.0, updated_at=now_future)
    )
    await db_session.commit()

    # 4. Regenerate -> allowed and version increments
    resp_ok = await client.post("/api/v1/report-cards/generate", json=payload, headers=headers)
    assert resp_ok.status_code == 201
    assert resp_ok.json()["data"]["version"] > 1
    assert len(resp_ok.json()["data"]["pdf_history"]) == 1

@pytest.mark.anyio
async def test_pdf_download_and_verification(client: AsyncClient, setup_report_test_data, db_session: AsyncSession) -> None:
    data = setup_report_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id
    student_id = data["stud1"].id

    # Seed marks
    mark = Marks(
        tenant_id=data["tenant_a"].id,
        school_id=school_id,
        academic_year_id=data["ay_a"].id,
        examination_id=data["exam"].id,
        exam_schedule_id=data["sched"].id,
        student_id=student_id,
        teacher_subject_assignment_id=data["tsa_a"].id,
        teacher_id=data["teacher_a"].id,
        subject_id=data["subject_a"].id,
        class_id=data["class_a"].id,
        section_id=data["sec_a1"].id,
        maximum_marks=100,
        marks_obtained=88.0,
        result_status=ExamResult.PRESENT,
        status=MarksStatus.PUBLISHED,
        created_by=data["user_admin"].id,
        updated_by=data["user_admin"].id
    )
    db_session.add(mark)
    await db_session.commit()

    # Generate Report
    payload = {
        "student_id": str(student_id),
        "school_id": str(school_id),
        "teacher_remarks": "Excellent"
    }
    resp = await client.post("/api/v1/report-cards/generate", json=payload, headers=headers)
    verify_uuid = resp.json()["data"]["verification_uuid"]

    # 1. Verification route checks (public route, no authorization headers required)
    resp_ver = await client.get(f"/api/v1/report-cards/verify/{verify_uuid}")
    assert resp_ver.status_code == 200
    assert resp_ver.json()["data"]["student_name"] == "Albert Einstein"

    # 2. PDF Download
    resp_dl = await client.get(f"/api/v1/report-cards/download/{student_id}?school_id={school_id}", headers=headers)
    assert resp_dl.status_code == 200
    assert resp_dl.headers["content-type"] == "application/pdf"
    assert b"%PDF" in resp_dl.content

@pytest.mark.anyio
async def test_report_card_security_restrictions(client: AsyncClient, setup_report_test_data, db_session: AsyncSession) -> None:
    from app.schemas.auth import UserCreate
    
    data = setup_report_test_data
    school_id = data["school_a"].id
    student_id = data["stud1"].id
    tenant_id = data["tenant_a"].id
    
    # Seed marks
    mark = Marks(
        tenant_id=tenant_id,
        school_id=school_id,
        academic_year_id=data["ay_a"].id,
        examination_id=data["exam"].id,
        exam_schedule_id=data["sched"].id,
        student_id=student_id,
        teacher_subject_assignment_id=data["tsa_a"].id,
        teacher_id=data["teacher_a"].id,
        subject_id=data["subject_a"].id,
        class_id=data["class_a"].id,
        section_id=data["sec_a1"].id,
        maximum_marks=100,
        marks_obtained=90.0,
        result_status=ExamResult.PRESENT,
        status=MarksStatus.PUBLISHED,
        created_by=data["user_admin"].id,
        updated_by=data["user_admin"].id
    )
    db_session.add(mark)
    await db_session.commit()
    
    payload = {
        "student_id": str(student_id),
        "school_id": str(school_id),
        "teacher_remarks": "Excellent job"
    }
    await client.post("/api/v1/report-cards/generate", json=payload, headers=data["auth_headers"])
    
    # Check permissions
    stmt_p = select(Permission).where(Permission.code.in_(["report_card.download", "report_card.read"]))
    res_p = await db_session.execute(stmt_p)
    rc_perms = list(res_p.scalars().all())
    
    # Fetch existing PARENT role under tenant_id (created automatically by TenantRepository)
    from sqlalchemy.orm import selectinload
    stmt_role = select(Role).where(Role.tenant_id == tenant_id, Role.code == "PARENT").options(selectinload(Role.permissions))
    res_role = await db_session.execute(stmt_role)
    parent_role = res_role.scalar_one()
    parent_role.permissions = rc_perms
    db_session.add(parent_role)
    await db_session.commit()
    
    repo_user = UserRepository(db_session)
    repo_role = RoleRepository(db_session)
    repo_perm = PermissionRepository(db_session)
    repo_refresh = RefreshTokenRepository(db_session)
    repo_school = SchoolRepository(db_session)
    
    auth_s = AuthService(repo_user, repo_role, repo_perm, repo_refresh, repo_school)

    # Parent 1: Vikram Rao (linked)
    user_p1 = await auth_s.create_user(tenant_id, UserCreate(email="vikram@demo.com", password="SecurePassword123!", first_name="Vikram", last_name="Rao"))
    user_p1.roles = [parent_role]
    db_session.add(user_p1)
    await db_session.commit()
    
    guard1 = Guardian(
        tenant_id=tenant_id,
        school_id=school_id,
        guardian_type=GuardianType.FATHER,
        first_name="Vikram",
        last_name="Rao",
        gender=StudentGender.MALE,
        date_of_birth=date(1980, 1, 1),
        mobile="+919876543210",
        email="vikram@demo.com",
        address={},
        communication_preferences={},
        is_active=True,
        user_id=user_p1.id
    )
    db_session.add(guard1)
    await db_session.flush()
    
    sg1 = StudentGuardian(
        tenant_id=tenant_id,
        school_id=school_id,
        student_id=student_id,
        guardian_id=guard1.id,
        relationship=StudentGuardianRelationship.FATHER,
        is_primary=True,
        can_pickup_student=True,
        receives_notifications=True
    )
    db_session.add(sg1)
    await db_session.commit()
    
    # Parent 2: Unlinked
    user_p2 = await auth_s.create_user(tenant_id, UserCreate(email="unlinked@demo.com", password="SecurePassword123!", first_name="Unlinked", last_name="Parent"))
    user_p2.roles = [parent_role]
    db_session.add(user_p2)
    await db_session.commit()
    
    guard2 = Guardian(
        tenant_id=tenant_id,
        school_id=school_id,
        guardian_type=GuardianType.MOTHER,
        first_name="Unlinked",
        last_name="Parent",
        gender=StudentGender.FEMALE,
        date_of_birth=date(1982, 1, 1),
        mobile="+919876543211",
        email="unlinked@demo.com",
        address={},
        communication_preferences={},
        is_active=True,
        user_id=user_p2.id
    )
    db_session.add(guard2)
    await db_session.commit()
    
    from app.api.dependencies.auth import get_current_user
    from app.main import app

    active_user = None

    async def mock_get_current_user_override():
        return active_user

    app.dependency_overrides[get_current_user] = mock_get_current_user_override

    try:
        token_p1 = await auth_s.create_tokens(user_p1)
        headers_p1 = {"Authorization": f"Bearer {token_p1.access_token}", "X-Tenant-ID": str(tenant_id)}
        
        token_p2 = await auth_s.create_tokens(user_p2)
        headers_p2 = {"Authorization": f"Bearer {token_p2.access_token}", "X-Tenant-ID": str(tenant_id)}
        
        # Linked parent can download
        active_user = user_p1
        resp_p1 = await client.get(f"/api/v1/report-cards/download/{student_id}?school_id={school_id}", headers=headers_p1)
        assert resp_p1.status_code == 200
        assert resp_p1.headers["content-type"] == "application/pdf"
        
        # Unlinked parent gets 403
        active_user = user_p2
        resp_p2 = await client.get(f"/api/v1/report-cards/download/{student_id}?school_id={school_id}", headers=headers_p2)
        assert resp_p2.status_code == 403
        assert "Access denied" in resp_p2.json()["message"]
        
        # Fetch existing TEACHER role under tenant_id (created automatically by TenantRepository)
        from sqlalchemy.orm import selectinload
        stmt_role_t = select(Role).where(Role.tenant_id == tenant_id, Role.code == "TEACHER").options(selectinload(Role.permissions))
        res_role_t = await db_session.execute(stmt_role_t)
        teacher_role = res_role_t.scalar_one()
        teacher_role.permissions = rc_perms
        db_session.add(teacher_role)
        await db_session.commit()
        
        # Teacher 1: Assigned (John Doe)
        user_t1 = await auth_s.create_user(tenant_id, UserCreate(email="john.doe@edu.com", password="SecurePassword123!", first_name="John", last_name="Doe", school_ids=[school_id]))
        user_t1.roles = [teacher_role]
        db_session.add(user_t1)
        await db_session.commit()
        
        data["teacher_a"].user_id = user_t1.id
        db_session.add(data["teacher_a"])
        await db_session.commit()
        
        # Teacher 2: Unassigned
        user_t2 = await auth_s.create_user(tenant_id, UserCreate(email="unassigned.t@edu.com", password="SecurePassword123!", first_name="Unassigned", last_name="Teacher", school_ids=[school_id]))
        user_t2.roles = [teacher_role]
        db_session.add(user_t2)
        await db_session.commit()
        
        teacher2 = Teacher(
            tenant_id=tenant_id,
            school_id=school_id,
            employee_code="EMP-T2",
            staff_code="STF-T2",
            first_name="Unassigned",
            last_name="Teacher",
            gender=StudentGender.FEMALE,
            date_of_birth=date(1990, 1, 1),
            mobile="+919876543212",
            official_email="unassigned.t@edu.com",
            joining_date=date(2025, 1, 1),
            employment_type=EmploymentType.FULL_TIME,
            user_id=user_t2.id,
            is_active=True
        )
        db_session.add(teacher2)
        await db_session.commit()
        
        token_t1 = await auth_s.create_tokens(user_t1)
        headers_t1 = {"Authorization": f"Bearer {token_t1.access_token}", "X-Tenant-ID": str(tenant_id)}
        
        token_t2 = await auth_s.create_tokens(user_t2)
        headers_t2 = {"Authorization": f"Bearer {token_t2.access_token}", "X-Tenant-ID": str(tenant_id)}
        
        # Assigned teacher can download
        active_user = user_t1
        resp_t1 = await client.get(f"/api/v1/report-cards/download/{student_id}?school_id={school_id}", headers=headers_t1)
        assert resp_t1.status_code == 200
        
        # Unassigned teacher gets 403
        active_user = user_t2
        resp_t2 = await client.get(f"/api/v1/report-cards/download/{student_id}?school_id={school_id}", headers=headers_t2)
        assert resp_t2.status_code == 403
        assert "Access denied" in resp_t2.json()["message"]
        
    finally:
        if get_current_user in app.dependency_overrides:
            del app.dependency_overrides[get_current_user]
