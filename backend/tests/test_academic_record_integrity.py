import uuid
import pytest
from datetime import date, time, datetime, timezone
from httpx import AsyncClient
from sqlalchemy import select
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
from app.models.role import Role
from app.models.permission import Permission
from app.models.examination import Examination, ExamSchedule, ExamStatus, ExamType
from app.models.marks import Marks, MarksStatus, ExamResult
from app.models.attendance import Attendance, AttendanceSession, AttendanceStatus

from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.section import SectionRepository
from app.repositories.student import StudentRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.subject import SubjectRepository
from app.repositories.teacher_subject_assignment import TeacherSubjectAssignmentRepository
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
from app.schemas.auth import UserCreate

@pytest.fixture
async def setup_academic_integrity_data(db_session: AsyncSession):
    suffix = uuid.uuid4().hex[:6].lower()

    # 1. Tenant & School
    repo_t = TenantRepository(db_session)
    tenant = await repo_t.create(TenantCreate(name="Integrity Tenant", code=f"int-{suffix}", subdomain=f"int-{suffix}", email=f"int-{suffix}@t.com"))
    await db_session.commit()

    repo_s = SchoolRepository(db_session)
    school = await repo_s.create(tenant.id, SchoolCreate(
        name="Integrity Model School", code=f"IMS_{suffix.upper()}", address="123 Street", city="Hyderabad",
        state="Telangana", country="India", pin_code="500001", board="CBSE", email=f"ims-{suffix}@edu.com",
        status=SchoolStatus.ACTIVE
    ))
    school.settings = {
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
    db_session.add(school)
    await db_session.commit()

    # 2. Academic Year 2026-2027
    repo_ay = AcademicYearRepository(db_session)
    ay = await repo_ay.create(tenant.id, school.id, AcademicYearCreate(
        school_id=school.id, name="2026-2027", code="AY2026-2027",
        start_date=date(2026, 6, 1), end_date=date(2027, 4, 30),
        status=AcademicYearStatus.ACTIVE, is_current=True
    ))
    ay.status = AcademicYearStatus.ACTIVE
    await db_session.commit()

    # 3. Class & Section
    repo_c = ClassRepository(db_session)
    class_10 = await repo_c.create(tenant.id, ClassCreate(school_id=school.id, academic_year_id=ay.id, name="Class 10", code="CLS10", level=10, category=ClassCategory.HIGH, capacity=40))
    await db_session.commit()

    repo_sec = SectionRepository(db_session)
    sec_a = await repo_sec.create(tenant.id, SectionCreate(school_id=school.id, academic_year_id=ay.id, class_id=class_10.id, name="Section A", code="SEC_A", capacity=40))
    await db_session.commit()

    # 4. Student (Sucharitha)
    repo_stud = StudentRepository(db_session)
    student = await repo_stud.create(tenant.id, StudentCreate(
        school_id=school.id, academic_year_id=ay.id, class_id=class_10.id, section_id=sec_a.id,
        admission_number=f"ADM-{suffix.upper()}", first_name="Sucharitha", last_name="Reddy",
        gender=StudentGender.FEMALE, date_of_birth=date(2010, 5, 12), roll_number="1",
        admission_date=date(2026, 6, 1)
    ))
    await db_session.commit()

    # 5. Teacher & Subject (Mathematics)
    repo_tchr = TeacherRepository(db_session)
    teacher = await repo_tchr.create(tenant.id, TeacherCreate(
        school_id=school.id, employee_code=f"EMP-{suffix}", staff_code=f"STF-{suffix}",
        first_name="Srinivas", last_name="Rao", gender=StudentGender.MALE, date_of_birth=date(1982, 4, 15),
        mobile=f"+9198765{suffix[:5]}", official_email=f"tchr-{suffix}@edu.com", joining_date=date(2025, 1, 1),
        employment_type=EmploymentType.FULL_TIME
    ))
    await db_session.commit()

    repo_sub = SubjectRepository(db_session)
    subject = await repo_sub.create(tenant.id, SubjectCreate(
        school_id=school.id, academic_year_id=ay.id, subject_code=f"MATH-{suffix.upper()}",
        subject_name="Mathematics", category=SubjectCategory.CORE, subject_type=SubjectType.THEORY
    ))
    subject.status = SubjectStatus.ACTIVE
    await db_session.commit()

    repo_tsa = TeacherSubjectAssignmentRepository(db_session)
    tsa = await repo_tsa.create(tenant.id, TeacherSubjectAssignmentCreate(
        school_id=school.id, academic_year_id=ay.id, teacher_id=teacher.id, subject_id=subject.id,
        class_id=class_10.id, section_id=sec_a.id, assignment_type="PRIMARY", weekly_periods=5,
        effective_from=date(2026, 6, 1)
    ))
    tsa.status = AssignmentStatus.ACTIVE
    tsa.is_active = True
    await db_session.commit()

    # 6. Admin user for auth headers
    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    auth_service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, repo_s)

    stmt_p = select(Permission)
    res_p = await db_session.execute(stmt_p)
    all_perms = list(res_p.scalars().all())

    admin_role = Role(name="Super Admin", code="SUPER_ADMIN", is_system=True, tenant_id=tenant.id)
    admin_role.permissions = all_perms
    db_session.add(admin_role)

    user_admin = await auth_service.create_user(
        tenant.id,
        UserCreate(email=f"admin-{suffix}@edu.com", password="Password123!", first_name="School", last_name="Admin")
    )
    user_admin.roles.append(admin_role)
    await db_session.commit()

    tokens = await auth_service.create_tokens(user_admin)

    # 7. Setup 5 Examinations:
    # Exam 1: Unit Test 1 (2026-06-01, COMPLETED, Max 25, Obt 17.5 = 70%) -> ELIGIBLE
    exam_ut1 = Examination(
        tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id,
        exam_name="Unit Test 1 (2026)", exam_type=ExamType.UNIT_TEST,
        start_date=date(2026, 6, 1), end_date=date(2026, 6, 5),
        status=ExamStatus.COMPLETED, created_by=user_admin.id, updated_by=user_admin.id
    )
    db_session.add(exam_ut1)
    await db_session.flush()

    sched_ut1 = ExamSchedule(
        tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id, exam_id=exam_ut1.id,
        class_id=class_10.id, section_id=sec_a.id, subject_id=subject.id,
        teacher_subject_assignment_id=tsa.id, exam_date=date(2026, 6, 2),
        start_time=time(9, 0), end_time=time(10, 0), max_marks=25, pass_marks=9,
        room_number="Room 101", created_by=user_admin.id, updated_by=user_admin.id
    )
    db_session.add(sched_ut1)
    await db_session.flush()

    mark_ut1 = Marks(
        tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id,
        examination_id=exam_ut1.id, exam_schedule_id=sched_ut1.id, student_id=student.id,
        teacher_subject_assignment_id=tsa.id, teacher_id=teacher.id, subject_id=subject.id,
        class_id=class_10.id, section_id=sec_a.id, maximum_marks=25, marks_obtained=17.5,
        result_status=ExamResult.PRESENT, status=MarksStatus.PUBLISHED,
        created_by=user_admin.id, updated_by=user_admin.id
    )
    db_session.add(mark_ut1)

    # Exam 2: Quarterly Examination 2026 (2026-09-15, COMPLETED, Max 100, Obt 70 = 70%) -> ELIGIBLE
    exam_quarterly = Examination(
        tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id,
        exam_name="Quarterly Examination 2026", exam_type=ExamType.QUARTERLY,
        start_date=date(2026, 9, 15), end_date=date(2026, 9, 22),
        status=ExamStatus.COMPLETED, created_by=user_admin.id, updated_by=user_admin.id
    )
    db_session.add(exam_quarterly)
    await db_session.flush()

    sched_quarterly = ExamSchedule(
        tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id, exam_id=exam_quarterly.id,
        class_id=class_10.id, section_id=sec_a.id, subject_id=subject.id,
        teacher_subject_assignment_id=tsa.id, exam_date=date(2026, 9, 16),
        start_time=time(9, 0), end_time=time(12, 0), max_marks=100, pass_marks=35,
        room_number="Room 101", created_by=user_admin.id, updated_by=user_admin.id
    )
    db_session.add(sched_quarterly)
    await db_session.flush()

    mark_quarterly = Marks(
        tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id,
        examination_id=exam_quarterly.id, exam_schedule_id=sched_quarterly.id, student_id=student.id,
        teacher_subject_assignment_id=tsa.id, teacher_id=teacher.id, subject_id=subject.id,
        class_id=class_10.id, section_id=sec_a.id, maximum_marks=100, marks_obtained=70.0,
        result_status=ExamResult.PRESENT, status=MarksStatus.PUBLISHED,
        created_by=user_admin.id, updated_by=user_admin.id
    )
    db_session.add(mark_quarterly)

    # Exam 3: Unit Test (2026-09-24, DRAFT) -> EXCLUDED (Draft)
    exam_draft = Examination(
        tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id,
        exam_name="Unit Test", exam_type=ExamType.UNIT_TEST,
        start_date=date(2026, 9, 24), end_date=date(2026, 9, 28),
        status=ExamStatus.DRAFT, created_by=user_admin.id, updated_by=user_admin.id
    )
    db_session.add(exam_draft)
    await db_session.flush()

    # Exam 4: Half-Yearly Examination 2026 (2026-09-29, COMPLETED, Max 100, Obt 90) -> EXCLUDED (Future Date: 29 Sep > 25 Sep)
    exam_half_yearly = Examination(
        tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id,
        exam_name="Half-Yearly Examination 2026", exam_type=ExamType.HALF_YEARLY,
        start_date=date(2026, 9, 29), end_date=date(2026, 10, 5),
        status=ExamStatus.COMPLETED, created_by=user_admin.id, updated_by=user_admin.id
    )
    db_session.add(exam_half_yearly)
    await db_session.flush()

    sched_hy = ExamSchedule(
        tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id, exam_id=exam_half_yearly.id,
        class_id=class_10.id, section_id=sec_a.id, subject_id=subject.id,
        teacher_subject_assignment_id=tsa.id, exam_date=date(2026, 9, 30),
        start_time=time(9, 0), end_time=time(12, 0), max_marks=100, pass_marks=35,
        room_number="Room 101", created_by=user_admin.id, updated_by=user_admin.id
    )
    db_session.add(sched_hy)
    await db_session.flush()

    mark_hy = Marks(
        tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id,
        examination_id=exam_half_yearly.id, exam_schedule_id=sched_hy.id, student_id=student.id,
        teacher_subject_assignment_id=tsa.id, teacher_id=teacher.id, subject_id=subject.id,
        class_id=class_10.id, section_id=sec_a.id, maximum_marks=100, marks_obtained=90.0,
        result_status=ExamResult.PRESENT, status=MarksStatus.PUBLISHED,
        created_by=user_admin.id, updated_by=user_admin.id
    )
    db_session.add(mark_hy)

    # Exam 5: Annual Examination 2027 (2026-11-28, COMPLETED, Max 100, Obt 95) -> EXCLUDED (Future Date: 28 Nov > 25 Sep)
    exam_annual = Examination(
        tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id,
        exam_name="Annual Examination 2027", exam_type=ExamType.ANNUAL,
        start_date=date(2026, 11, 28), end_date=date(2026, 12, 5),
        status=ExamStatus.COMPLETED, created_by=user_admin.id, updated_by=user_admin.id
    )
    db_session.add(exam_annual)
    await db_session.flush()

    sched_annual = ExamSchedule(
        tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id, exam_id=exam_annual.id,
        class_id=class_10.id, section_id=sec_a.id, subject_id=subject.id,
        teacher_subject_assignment_id=tsa.id, exam_date=date(2026, 11, 29),
        start_time=time(9, 0), end_time=time(12, 0), max_marks=100, pass_marks=35,
        room_number="Room 101", created_by=user_admin.id, updated_by=user_admin.id
    )
    db_session.add(sched_annual)
    await db_session.flush()

    mark_annual = Marks(
        tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id,
        examination_id=exam_annual.id, exam_schedule_id=sched_annual.id, student_id=student.id,
        teacher_subject_assignment_id=tsa.id, teacher_id=teacher.id, subject_id=subject.id,
        class_id=class_10.id, section_id=sec_a.id, maximum_marks=100, marks_obtained=95.0,
        result_status=ExamResult.PRESENT, status=MarksStatus.PUBLISHED,
        created_by=user_admin.id, updated_by=user_admin.id
    )
    db_session.add(mark_annual)

    # 8. Attendance (2 sessions, both PRESENT -> 100%)
    sess1 = AttendanceSession(
        tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id,
        class_id=class_10.id, section_id=sec_a.id, attendance_date=date(2026, 6, 2),
        teacher_id=teacher.id, subject_id=subject.id
    )
    sess2 = AttendanceSession(
        tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id,
        class_id=class_10.id, section_id=sec_a.id, attendance_date=date(2026, 9, 16),
        teacher_id=teacher.id, subject_id=subject.id
    )
    db_session.add_all([sess1, sess2])
    await db_session.flush()

    att1 = Attendance(
        tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id,
        class_id=class_10.id, section_id=sec_a.id, attendance_session_id=sess1.id,
        student_id=student.id, attendance_date=date(2026, 6, 2),
        attendance_status=AttendanceStatus.PRESENT, teacher_id=teacher.id, subject_id=subject.id,
        created_by=user_admin.id, updated_by=user_admin.id
    )
    att2 = Attendance(
        tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id,
        class_id=class_10.id, section_id=sec_a.id, attendance_session_id=sess2.id,
        student_id=student.id, attendance_date=date(2026, 9, 16),
        attendance_status=AttendanceStatus.PRESENT, teacher_id=teacher.id, subject_id=subject.id,
        created_by=user_admin.id, updated_by=user_admin.id
    )
    db_session.add_all([att1, att2])
    await db_session.commit()

    return {
        "tenant": tenant,
        "school": school,
        "ay": ay,
        "class": class_10,
        "section": sec_a,
        "student": student,
        "user_admin": user_admin,
        "auth_headers": {
            "Authorization": f"Bearer {tokens.access_token}",
            "X-Tenant-ID": str(tenant.id)
        }
    }

@pytest.mark.anyio
async def test_future_and_draft_examination_strict_exclusion(client: AsyncClient, setup_academic_integrity_data, db_session: AsyncSession) -> None:
    """
    Section 29: Future Examination Protection Regression Test
    Verifies that examinations occurring after the as_of_date (2026-09-25)
    or in DRAFT status are strictly excluded from the consolidated report card.
    """
    data = setup_academic_integrity_data
    headers = data["auth_headers"]
    school_id = data["school"].id
    student_id = data["student"].id

    resp = await client.get(
        f"/api/v1/report-cards/preview/{student_id}?school_id={school_id}&report_card_type=CONSOLIDATED&teacher_remarks=Consistent+performance.",
        headers=headers
    )
    assert resp.status_code == 200
    preview = resp.json()["data"]

    # 1. Subject marks should reflect ONLY Unit Test 1 (17.5/25) and Quarterly (70/100)
    # Total obtained: 17.5 + 70.0 = 87.5
    # Total max: 25 + 100 = 125
    # Overall percentage: 87.5 / 125 = 70.0%
    assert preview["overall_percentage"] == 70.0
    assert preview["overall_grade"] == "B" # 70-79.99 is B
    assert preview["promotion_status"] == "PROMOTED"

    # 2. Consolidated examinations breakdown must NOT include Half-Yearly, Annual, or Draft
    cons_marks = preview["consolidated_subject_marks"]
    assert len(cons_marks) == 1 # Single subject Mathematics
    math_exams = cons_marks[0]["exams"]
    exam_names = [e["exam_name"] for e in math_exams.values()]

    assert "Unit Test 1 (2026)" in exam_names
    assert "Quarterly Examination 2026" in exam_names
    assert "Half-Yearly Examination 2026" not in exam_names
    assert "Annual Examination 2027" not in exam_names
    assert "Unit Test" not in exam_names

@pytest.mark.anyio
async def test_student_360_analytics_data_parity(client: AsyncClient, setup_academic_integrity_data, db_session: AsyncSession) -> None:
    """
    Section 30: Student 360 Backend Analytics Integrity & Parity Test
    Verifies that GET /api/v1/students/{id}/analytics accurately reflects
    completed examinations, correct attendance, and exact parity with report card score.
    """
    data = setup_academic_integrity_data
    headers = data["auth_headers"]
    school_id = data["school"].id
    student_id = data["student"].id

    resp = await client.get(
        f"/api/v1/students/{student_id}/analytics?school_id={school_id}",
        headers=headers
    )
    assert resp.status_code == 200
    analytics = resp.json()["data"]

    # 1. Attendance Parity
    att = analytics["attendance"]
    assert att["has_data"] is True
    assert att["attendance_rate"] == 100.0
    assert att["total_days"] == 2
    assert att["present_days"] == 2
    assert att["absent_days"] == 0

    # 2. Academic Parity (Only completed non-future exams)
    acad = analytics["academics"]
    assert acad["has_data"] is True
    assert acad["academic_average"] == 70.0
    assert acad["current_score"] == 70.0
    assert acad["overall_grade"] == "B"

    completed_exam_names = [e["examination_name"] for e in acad["completed_examinations"]]
    assert "Unit Test 1 (2026)" in completed_exam_names
    assert "Quarterly Examination 2026" in completed_exam_names
    assert "Half-Yearly Examination 2026" not in completed_exam_names
    assert "Annual Examination 2027" not in completed_exam_names
    assert "Unit Test" not in completed_exam_names

    # 3. AI Insights reflect real data
    ai = analytics["ai_analysis"]
    assert ai["has_data"] is True
    assert ai["data_state"] == "SUFFICIENT_DATA"
    assert "70.0%" in ai["headline"]
    assert "100.0% attendance" in ai["headline"]
