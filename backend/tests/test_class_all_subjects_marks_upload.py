import io
import uuid
import pytest
from datetime import date, time, datetime, timezone
from httpx import AsyncClient, ASGITransport
from openpyxl import Workbook, load_workbook
from sqlalchemy import select

from unittest.mock import patch
from sqlalchemy.exc import SQLAlchemyError

from app.main import app
from app.models.tenant import Tenant
from app.models.school import School
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.class_entity import Class, ClassCategory
from app.models.section import Section
from app.models.student import Student, StudentGender
from app.models.teacher import Teacher, EmploymentType, TeacherStatus
from app.models.teacher_subject_assignment import TeacherSubjectAssignment
from app.models.subject import Subject, SubjectCategory, SubjectType, SubjectStatus
from app.models.examination import Examination, ExamSchedule, ExamStatus, ExamType
from app.models.marks import Marks, MarksStatus, ExamResult
from app.models.role import Role
from app.models.permission import Permission
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository
from app.schemas.auth import UserCreate
from app.services.auth import AuthService


@pytest.fixture
async def setup_class_upload_data(db_session):
    u = uuid.uuid4().hex[:6]
    tenant = Tenant(name=f"Upload Test Tenant {u}", code=f"UTT_{u}", subdomain=f"utt{u}", email=f"utt{u}@edupulse.local")
    db_session.add(tenant)
    await db_session.flush()

    school = School(name=f"Upload Test School {u}", code=f"UTS_{u}", board="CBSE", email=f"uts_{u}@edupulse.local", tenant_id=tenant.id)
    db_session.add(school)
    await db_session.flush()

    ay = AcademicYear(
        name="2025-2026",
        code=f"AY_{u}",
        start_date=date(2025, 6, 1),
        end_date=date(2026, 4, 30),
        status=AcademicYearStatus.ACTIVE,
        tenant_id=tenant.id,
        school_id=school.id
    )
    db_session.add(ay)
    await db_session.flush()

    cls = Class(
        name="Class 5",
        code=f"C5_{u}",
        category=ClassCategory.PRIMARY,
        level=5,
        capacity=40,
        academic_year_id=ay.id,
        tenant_id=tenant.id,
        school_id=school.id
    )
    db_session.add(cls)
    await db_session.flush()

    sec = Section(
        name="Section A",
        code=f"5A_{u}",
        class_id=cls.id,
        academic_year_id=ay.id,
        capacity=40,
        tenant_id=tenant.id,
        school_id=school.id
    )
    db_session.add(sec)
    await db_session.flush()

    # Create subjects: English, Mathematics, Science
    sub_eng = Subject(subject_name="English", subject_code=f"ENG_{u}", category=SubjectCategory.CORE, subject_type=SubjectType.THEORY, status=SubjectStatus.ACTIVE, academic_year_id=ay.id, tenant_id=tenant.id, school_id=school.id)
    sub_math = Subject(subject_name="Mathematics", subject_code=f"MAT_{u}", category=SubjectCategory.CORE, subject_type=SubjectType.THEORY, status=SubjectStatus.ACTIVE, academic_year_id=ay.id, tenant_id=tenant.id, school_id=school.id)
    sub_sci = Subject(subject_name="Science", subject_code=f"SCI_{u}", category=SubjectCategory.CORE, subject_type=SubjectType.THEORY, status=SubjectStatus.ACTIVE, academic_year_id=ay.id, tenant_id=tenant.id, school_id=school.id)
    db_session.add_all([sub_eng, sub_math, sub_sci])
    await db_session.flush()

    # Create students
    st1 = Student(
        first_name="Aarav",
        last_name="Kumar",
        admission_number=f"ADM_1_{u}",
        roll_number="1",
        date_of_birth=date(2015, 1, 1),
        admission_date=date(2025, 6, 1),
        gender=StudentGender.MALE,
        class_id=cls.id,
        section_id=sec.id,
        academic_year_id=ay.id,
        tenant_id=tenant.id,
        school_id=school.id,
        is_active=True
    )
    st2 = Student(
        first_name="Priya",
        last_name="Sharma",
        admission_number=f"ADM_2_{u}",
        roll_number="2",
        date_of_birth=date(2015, 2, 2),
        admission_date=date(2025, 6, 1),
        gender=StudentGender.FEMALE,
        class_id=cls.id,
        section_id=sec.id,
        academic_year_id=ay.id,
        tenant_id=tenant.id,
        school_id=school.id,
        is_active=True
    )
    db_session.add_all([st1, st2])
    await db_session.flush()

    # Teacher & TeacherSubjectAssignments
    teacher = Teacher(
        tenant_id=tenant.id,
        school_id=school.id,
        employee_code=f"EMP_{u}",
        staff_code=f"STF_{u}",
        first_name="Test",
        last_name="Teacher",
        gender=StudentGender.MALE,
        date_of_birth=date(1985, 5, 20),
        joining_date=date(2025, 1, 1),
        employment_type=EmploymentType.FULL_TIME,
        official_email=f"teacher_{u}@edupulse.local",
        mobile=f"+91987654{u[:4]}",
    )
    db_session.add(teacher)
    await db_session.flush()

    now_ts = datetime.now(timezone.utc)
    tsa_eng = TeacherSubjectAssignment(
        tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id,
        teacher_id=teacher.id, subject_id=sub_eng.id, class_id=cls.id, section_id=sec.id,
        assignment_type="PRIMARY", weekly_periods=5, effective_from=date(2025, 6, 1),
        assigned_at=now_ts, is_active=True
    )
    tsa_math = TeacherSubjectAssignment(
        tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id,
        teacher_id=teacher.id, subject_id=sub_math.id, class_id=cls.id, section_id=sec.id,
        assignment_type="PRIMARY", weekly_periods=5, effective_from=date(2025, 6, 1),
        assigned_at=now_ts, is_active=True
    )
    tsa_sci = TeacherSubjectAssignment(
        tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id,
        teacher_id=teacher.id, subject_id=sub_sci.id, class_id=cls.id, section_id=sec.id,
        assignment_type="PRIMARY", weekly_periods=5, effective_from=date(2025, 6, 1),
        assigned_at=now_ts, is_active=True
    )
    db_session.add_all([tsa_eng, tsa_math, tsa_sci])
    await db_session.flush()

    # Examination
    exam = Examination(
        exam_name="Quarterly Examination 2025",
        exam_type=ExamType.QUARTERLY,
        academic_year_id=ay.id,
        start_date=date(2025, 9, 1),
        end_date=date(2025, 9, 15),
        status=ExamStatus.SCHEDULED,
        tenant_id=tenant.id,
        school_id=school.id
    )
    db_session.add(exam)
    await db_session.flush()

    # Exam Schedules for English (100), Mathematics (100), Science (50)
    sched_eng = ExamSchedule(
        exam_id=exam.id,
        class_id=cls.id,
        section_id=sec.id,
        subject_id=sub_eng.id,
        teacher_subject_assignment_id=tsa_eng.id,
        academic_year_id=ay.id,
        exam_date=date(2025, 9, 2),
        start_time=time(9, 0),
        end_time=time(12, 0),
        max_marks=100,
        pass_marks=35,
        tenant_id=tenant.id,
        school_id=school.id
    )
    sched_math = ExamSchedule(
        exam_id=exam.id,
        class_id=cls.id,
        section_id=sec.id,
        subject_id=sub_math.id,
        teacher_subject_assignment_id=tsa_math.id,
        academic_year_id=ay.id,
        exam_date=date(2025, 9, 4),
        start_time=time(9, 0),
        end_time=time(12, 0),
        max_marks=100,
        pass_marks=35,
        tenant_id=tenant.id,
        school_id=school.id
    )
    sched_sci = ExamSchedule(
        exam_id=exam.id,
        class_id=cls.id,
        section_id=sec.id,
        subject_id=sub_sci.id,
        teacher_subject_assignment_id=tsa_sci.id,
        academic_year_id=ay.id,
        exam_date=date(2025, 9, 6),
        start_time=time(9, 0),
        end_time=time(11, 0),
        max_marks=50,
        pass_marks=18,
        tenant_id=tenant.id,
        school_id=school.id
    )
    db_session.add_all([sched_eng, sched_math, sched_sci])
    await db_session.flush()

    # Admin user with marks permissions
    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)

    stmt_p = select(Permission)
    res_p = await db_session.execute(stmt_p)
    all_perms = list(res_p.scalars().all())

    role = Role(name=f"Admin_{u}", code="SUPER_ADMIN", is_system=True, tenant_id=tenant.id, permissions=all_perms)
    db_session.add(role)
    await db_session.flush()

    from app.repositories.auth import RefreshTokenRepository
    from app.repositories.school import SchoolRepository
    ref_repo = RefreshTokenRepository(db_session)
    sch_repo = SchoolRepository(db_session)
    auth_svc = AuthService(user_repo, role_repo, perm_repo, ref_repo, sch_repo)
    admin_user = await auth_svc.create_user(
        tenant.id,
        UserCreate(
            email=f"admin_{u}@edupulse.local",
            password="Password123!",
            first_name="Admin",
            last_name="User"
        )
    )
    admin_user.roles.append(role)
    tokens = await auth_svc.create_tokens(admin_user)
    token = tokens.access_token

    await db_session.commit()

    return {
        "tenant": tenant,
        "school": school,
        "academic_year": ay,
        "exam": exam,
        "class": cls,
        "section": sec,
        "students": [st1, st2],
        "subjects": [sub_eng, sub_math, sub_sci],
        "schedules": [sched_eng, sched_math, sched_sci],
        "token": token,
        "teacher": teacher,
        "tsas": [tsa_eng, tsa_math, tsa_sci],
        "admin_user": admin_user,
        "auth_svc": auth_svc,
        "role": role
    }


@pytest.mark.anyio
async def test_class_all_subjects_template_and_upload(client: AsyncClient, setup_class_upload_data):
    data = setup_class_upload_data
    tenant = data["tenant"]
    school = data["school"]
    exam = data["exam"]
    cls = data["class"]
    sec = data["section"]
    token = data["token"]

    headers = {
        "Authorization": f"Bearer {token}",
        "X-Tenant-ID": str(tenant.id),
        "X-School-ID": str(school.id),
        "Origin": "http://localhost:3000"
    }

    # 1. Test template download
    resp_tpl = await client.get(
        f"/api/v1/marks/examinations/{exam.id}/class-all-subjects-template",
        params={
            "class_id": str(cls.id),
            "section_id": str(sec.id),
            "school_id": str(school.id)
        },
        headers=headers
    )
    assert resp_tpl.status_code == 200
    assert "application/vnd.openxmlformats" in resp_tpl.headers["content-type"]
    assert resp_tpl.headers.get("access-control-allow-origin") == "http://localhost:3000"

    # Verify downloaded workbook has the student rows and subject columns
    wb = load_workbook(io.BytesIO(resp_tpl.content))
    ws = wb.active
    headers_row = [cell.value for cell in ws[1]]
    assert "Roll No" in headers_row
    assert "Student Name" in headers_row
    assert any("English" in str(h) for h in headers_row)
    assert any("Mathematics" in str(h) for h in headers_row)
    assert any("Science" in str(h) for h in headers_row)

    # 2. Build Excel file for uploading:
    # Roll No | Student Name | English | Mathematics | Science
    # 1       | Aarav Kumar  | 85      | 95          | 45
    # 2       | Priya Sharma | 90      | 88          | 48
    upload_wb = Workbook()
    upload_ws = upload_wb.active
    upload_ws.append(["Roll No", "Student Name", "English (Max 100)", "Mathematics (Max 100)", "Science (Max 50)"])
    upload_ws.append(["1", "Aarav Kumar", 85, 95, 45])
    upload_ws.append(["2", "Priya Sharma", 90, 88, 48])

    upload_buf = io.BytesIO()
    upload_wb.save(upload_buf)
    upload_buf.seek(0)

    # 3. Test OPTIONS preflight request from http://localhost:3000
    opt_headers = {
        "Origin": "http://localhost:3000",
        "Access-Control-Request-Method": "POST",
        "Access-Control-Request-Headers": "authorization,x-tenant-id,x-school-id,content-type"
    }
    opt_resp = await client.options(
        f"/api/v1/marks/examinations/{exam.id}/upload-class-all-subjects",
        headers=opt_headers
    )
    assert opt_resp.status_code == 200
    assert opt_resp.headers.get("access-control-allow-origin") == "http://localhost:3000"

    # 4. Upload file
    files = {
        "file": ("Class5_SectionA_All_Subjects_Quarterly_Marks.xlsx", upload_buf.getvalue(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    }
    upload_resp = await client.post(
        f"/api/v1/marks/examinations/{exam.id}/upload-class-all-subjects",
        params={
            "class_id": str(cls.id),
            "section_id": str(sec.id),
            "school_id": str(school.id)
        },
        headers=headers,
        files=files
    )
    assert upload_resp.status_code == 200
    data = upload_resp.json()["data"]
    assert data["total_students_processed"] == 2
    assert data["total_subjects_detected"] == 3
    assert data["total_marks_created"] == 6
    assert data["failed_rows"] == 0
    assert len(data["validation_errors"]) == 0

    # 5. Test validation error when score exceeds max marks (Science max is 50, upload 55)
    invalid_wb = Workbook()
    invalid_ws = invalid_wb.active
    invalid_ws.append(["Roll No", "Student Name", "English", "Mathematics", "Science"])
    invalid_ws.append(["1", "Aarav Kumar", 85, 95, 55])

    invalid_buf = io.BytesIO()
    invalid_wb.save(invalid_buf)
    invalid_buf.seek(0)

    files_invalid = {
        "file": ("invalid_marks.xlsx", invalid_buf.getvalue(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    }
    resp_invalid = await client.post(
        f"/api/v1/marks/examinations/{exam.id}/upload-class-all-subjects",
        params={
            "class_id": str(cls.id),
            "section_id": str(sec.id),
            "school_id": str(school.id)
        },
        headers=headers,
        files=files_invalid
    )
    assert resp_invalid.status_code == 200
    data_inv = resp_invalid.json()["data"]
    assert len(data_inv["validation_errors"]) == 1
    assert "exceeds maximum allowed 50" in data_inv["validation_errors"][0]


def test_normalize_subject_header():
    from app.core.normalization import normalize_subject_header
    assert normalize_subject_header("English (Max 100)") == "english"
    assert normalize_subject_header("MATHEMATICS (MAX 100)") == "mathematics"
    assert normalize_subject_header("Science - Max 50") == "science"
    assert normalize_subject_header(" mathematics ") == "mathematics"
    assert normalize_subject_header("Mathematics(Max 100)") == "mathematics"
    assert normalize_subject_header("Mathematics - Max: 100") == "mathematics"
    assert normalize_subject_header("Social Studies [100]") == "socialstudies"
    assert normalize_subject_header("Physics (100 Marks)") == "physics"
    assert normalize_subject_header("MATH_101 (Max 100)") == "math101"


@pytest.mark.anyio
async def test_generated_template_can_be_uploaded_without_header_changes(client: AsyncClient, setup_class_upload_data):
    """
    Mandatory Round-trip verification:
    1. Download the generated Class & All Subjects template
    2. Upload the exact same file without changing any headers (filling in marks)
    3. Assert all scheduled subjects are detected and marks uploaded successfully
    """
    data = setup_class_upload_data
    tenant = data["tenant"]
    school = data["school"]
    exam = data["exam"]
    cls = data["class"]
    sec = data["section"]
    token = data["token"]

    headers = {
        "Authorization": f"Bearer {token}",
        "X-Tenant-ID": str(tenant.id),
        "X-School-ID": str(school.id),
    }

    # 1. Download generated template
    resp_tpl = await client.get(
        f"/api/v1/marks/examinations/{exam.id}/class-all-subjects-template",
        params={
            "class_id": str(cls.id),
            "section_id": str(sec.id),
            "school_id": str(school.id)
        },
        headers=headers
    )
    assert resp_tpl.status_code == 200
    tpl_bytes = resp_tpl.content

    # 2. Open generated template and fill marks without modifying any headers
    wb = load_workbook(io.BytesIO(tpl_bytes))
    ws = wb.active

    # Verify exact generated headers
    row_headers = [cell.value for cell in ws[1]]
    assert "Roll No" in row_headers
    assert "Student Name" in row_headers
    assert len(row_headers) == 5  # Roll No, Student Name, 3 subjects

    # Populate marks in existing rows (row 2: Aarav, row 3: Priya)
    ws.cell(row=2, column=3, value=88)
    ws.cell(row=2, column=4, value=92)
    ws.cell(row=2, column=5, value=47)

    ws.cell(row=3, column=3, value=91)
    ws.cell(row=3, column=4, value=85)
    ws.cell(row=3, column=5, value=44)

    filled_buf = io.BytesIO()
    wb.save(filled_buf)
    filled_buf.seek(0)

    # 3. Upload the exact filled workbook back
    files = {
        "file": ("Filled_All_Subjects_Template.xlsx", filled_buf.getvalue(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    }
    upload_resp = await client.post(
        f"/api/v1/marks/examinations/{exam.id}/upload-class-all-subjects",
        params={
            "class_id": str(cls.id),
            "section_id": str(sec.id),
            "school_id": str(school.id)
        },
        headers=headers,
        files=files
    )
    assert upload_resp.status_code == 200
    res_data = upload_resp.json()["data"]
    assert res_data["total_students_processed"] == 2
    assert res_data["total_subjects_detected"] == 3
    assert res_data["total_marks_created"] + res_data["total_marks_updated"] == 6
    assert res_data["failed_rows"] == 0
    assert len(res_data["validation_errors"]) == 0


@pytest.mark.anyio
async def test_upload_long_format_per_subject_workbook(client: AsyncClient, setup_class_upload_data):
    """
    Test uploading a long-format per-subject spreadsheet with columns:
    [admission_number, roll_number, student_name, subject_code, subject_name, exam_code, marks_obtained, maximum_marks]
    Verifies that dual-format parser detects subjects and imports marks properly.
    """
    data = setup_class_upload_data
    tenant = data["tenant"]
    school = data["school"]
    exam = data["exam"]
    cls = data["class"]
    sec = data["section"]
    token = data["token"]

    headers = {
        "Authorization": f"Bearer {token}",
        "X-Tenant-ID": str(tenant.id),
        "X-School-ID": str(school.id),
        "Origin": "http://localhost:3000"
    }

    # Build long-format workbook
    wb = Workbook()
    ws = wb.active
    ws.title = "ALL_SUBJECTS"
    ws.append([
        "admission_number", "roll_number", "student_name", "subject_code", "subject_name", "exam_code", "marks_obtained", "maximum_marks"
    ])
    ws.append(["ADM001", "1", "Aarav Kumar", "ENG101", "English", "EXAM01", 85, 100])
    ws.append(["ADM001", "1", "Aarav Kumar", "MATH101", "Mathematics", "EXAM01", 95, 100])
    ws.append(["ADM001", "1", "Aarav Kumar", "SCI101", "Science", "EXAM01", 45, 50])
    ws.append(["ADM002", "2", "Priya Sharma", "ENG101", "English", "EXAM01", 90, 100])
    ws.append(["ADM002", "2", "Priya Sharma", "MATH101", "Mathematics", "EXAM01", 88, 100])
    ws.append(["ADM002", "2", "Priya Sharma", "SCI101", "Science", "EXAM01", 48, 50])

    buf = io.BytesIO()
    wb.save(buf)
    buf.seek(0)

    files = {
        "file": ("Class5_SectionA_All_Subjects_Quarterly_Marks.xlsx", buf.getvalue(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    }
    upload_resp = await client.post(
        f"/api/v1/marks/examinations/{exam.id}/upload-class-all-subjects",
        params={
            "class_id": str(cls.id),
            "section_id": str(sec.id),
            "school_id": str(school.id)
        },
        headers=headers,
        files=files
    )
    assert upload_resp.status_code == 200
    data = upload_resp.json()["data"]
    assert data["total_students_processed"] == 2
    assert data["total_subjects_detected"] == 3
    assert data["total_marks_created"] + data["total_marks_updated"] == 6
    assert data["failed_rows"] == 0
    assert len(data["validation_errors"]) == 0


@pytest.mark.anyio
async def test_missing_teacher_produces_clean_422_with_cors(client: AsyncClient, setup_class_upload_data, db_session):
    """
    Verifies that when a schedule has no valid teacher and the school has no active teachers:
    1. A clean HTTP 422 error is returned (instead of throwing a 500 FK constraint violation).
    2. CORS headers (Access-Control-Allow-Origin) are present on the error response.
    3. The response body is valid JSON with a clear error message.
    """
    data = setup_class_upload_data
    tenant = data["tenant"]
    school = data["school"]
    exam = data["exam"]
    cls = data["class"]
    sec = data["section"]
    token = data["token"]

    # Soft delete all TSAs in the school
    stmt_tsa = select(TeacherSubjectAssignment).where(TeacherSubjectAssignment.school_id == school.id)
    res_tsa = await db_session.execute(stmt_tsa)
    tsas = list(res_tsa.scalars().all())
    for tsa in tsas:
        await db_session.delete(tsa)

    # Delete all teachers in the school
    stmt_t = select(Teacher).where(Teacher.school_id == school.id)
    res_t = await db_session.execute(stmt_t)
    teachers = list(res_t.scalars().all())
    for t in teachers:
        await db_session.delete(t)
    await db_session.commit()

    # Build spreadsheet with scheduled subject 'English'
    wb = Workbook()
    ws = wb.active
    ws.title = "Marks Entry"
    ws.append(["Roll No", "Student Name", "English"])
    ws.append(["1", "Aarav Kumar", 80])
    buf = io.BytesIO()
    wb.save(buf)

    headers = {
        "Authorization": f"Bearer {token}",
        "X-Tenant-ID": str(tenant.id),
        "X-School-ID": str(school.id),
        "Origin": "http://localhost:3000"
    }

    files = {
        "file": ("english_marks.xlsx", buf.getvalue(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    }

    resp = await client.post(
        f"/api/v1/marks/examinations/{exam.id}/upload-class-all-subjects",
        params={
            "class_id": str(cls.id),
            "section_id": str(sec.id),
            "school_id": str(school.id)
        },
        headers=headers,
        files=files
    )

    assert resp.status_code == 422
    assert resp.headers.get("access-control-allow-origin") == "http://localhost:3000"
    resp_json = resp.json()
    assert resp_json["success"] is False
    assert "detail" in resp_json or "message" in resp_json


@pytest.mark.anyio
async def test_teacher_resolution_hierarchy_and_transaction_safety(
    client: AsyncClient,
    setup_class_upload_data,
    db_session
):
    """
    High-value regression test verifying all 4 audit requirements:
    Case A: TSA exists -> Marks.teacher_id equals TSA.teacher_id
    Case B: No section TSA but current user has Teacher record -> Marks.teacher_id equals Teacher.id
    Case C: No valid teacher relationship exists -> HTTP 422 with CORS headers
    Case D: A failed database operation triggers rollback and returns secure HTTP 500 without leaking DB internals
    """
    data = setup_class_upload_data
    tenant = data["tenant"]
    school = data["school"]
    ay = data["academic_year"]
    exam = data["exam"]
    cls = data["class"]
    sec = data["section"]
    token = data["token"]
    teacher = data["teacher"]
    tsa_eng = data["tsas"][0]
    sched_eng = data["schedules"][0]
    auth_svc = data["auth_svc"]
    role = data["role"]
    admin_user = data["admin_user"]

    admin_headers = {
        "Authorization": f"Bearer {token}",
        "X-Tenant-ID": str(tenant.id),
        "X-School-ID": str(school.id),
        "Origin": "http://localhost:3000"
    }

    # =========================================================================
    # CASE A: TSA exists -> Marks.teacher_id equals TSA.teacher_id
    # =========================================================================
    wb_a = Workbook()
    ws_a = wb_a.active
    ws_a.title = "Marks Entry"
    ws_a.append(["Roll No", "Student Name", "English"])
    ws_a.append(["1", "Aarav Kumar", 88])
    buf_a = io.BytesIO()
    wb_a.save(buf_a)

    resp_a = await client.post(
        f"/api/v1/marks/examinations/{exam.id}/upload-class-all-subjects",
        params={"class_id": str(cls.id), "section_id": str(sec.id), "school_id": str(school.id)},
        headers=admin_headers,
        files={"file": ("case_a.xlsx", buf_a.getvalue(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")}
    )
    assert resp_a.status_code == 200, resp_a.text
    stmt_a = select(Marks).where(
        Marks.exam_schedule_id == sched_eng.id,
        Marks.examination_id == exam.id,
        Marks.school_id == school.id
    )
    mark_a = (await db_session.execute(stmt_a)).scalars().first()
    assert mark_a is not None
    assert mark_a.teacher_id == teacher.id
    assert mark_a.teacher_id == tsa_eng.teacher_id
    assert mark_a.teacher_subject_assignment_id == tsa_eng.id

    # =========================================================================
    # CASE B: No section TSA but current user has Teacher record -> Marks.teacher_id equals Teacher.id
    # =========================================================================
    u_b = uuid.uuid4().hex[:6]
    teacher_user_b = await auth_svc.create_user(
        tenant.id,
        UserCreate(
            email=f"teacher_user_{u_b}@edupulse.local",
            password="Password123!",
            first_name="Teacher",
            last_name=f"User{u_b}"
        )
    )
    teacher_user_b.roles.append(role)
    teacher_b_record = Teacher(
        user_id=teacher_user_b.id,
        school_id=school.id,
        tenant_id=tenant.id,
        employee_code=f"EMP_{u_b}",
        staff_code=f"STF_{u_b}",
        first_name="Teacher",
        last_name=f"User{u_b}",
        gender=StudentGender.MALE,
        date_of_birth=date(1990, 1, 1),
        joining_date=date(2025, 1, 1),
        employment_type=EmploymentType.FULL_TIME,
        official_email=f"teacher_{u_b}@edupulse.local",
        mobile=f"+91987654{u_b[:4]}",
        status=TeacherStatus.ACTIVE
    )
    db_session.add(teacher_b_record)
    await db_session.flush()

    tokens_b = await auth_svc.create_tokens(teacher_user_b)
    teacher_b_headers = {
        "Authorization": f"Bearer {tokens_b.access_token}",
        "X-Tenant-ID": str(tenant.id),
        "X-School-ID": str(school.id),
        "Origin": "http://localhost:3000"
    }

    sub_hindi = Subject(
        tenant_id=tenant.id,
        school_id=school.id,
        academic_year_id=ay.id,
        subject_name=f"Hindi_{u_b}",
        subject_code=f"HIN_{u_b}",
        category=SubjectCategory.CORE,
        subject_type=SubjectType.THEORY,
        status=SubjectStatus.ACTIVE
    )
    db_session.add(sub_hindi)
    await db_session.flush()

    # Inactive TSA so Priority 1 & 2 fail to find an active section TSA
    tsa_hindi = TeacherSubjectAssignment(
        tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id,
        teacher_id=teacher.id, subject_id=sub_hindi.id, class_id=cls.id, section_id=sec.id,
        assignment_type="PRIMARY", weekly_periods=4, effective_from=date(2025, 6, 1),
        assigned_at=datetime.now(timezone.utc), is_active=False
    )
    db_session.add(tsa_hindi)
    await db_session.flush()

    sched_hindi = ExamSchedule(
        exam_id=exam.id,
        class_id=cls.id,
        section_id=sec.id,
        subject_id=sub_hindi.id,
        teacher_subject_assignment_id=tsa_hindi.id,
        academic_year_id=ay.id,
        exam_date=date(2025, 9, 8),
        start_time=time(9, 0),
        end_time=time(12, 0),
        max_marks=100,
        pass_marks=35,
        tenant_id=tenant.id,
        school_id=school.id
    )
    db_session.add(sched_hindi)
    await db_session.commit()

    wb_b = Workbook()
    ws_b = wb_b.active
    ws_b.title = "Marks Entry"
    ws_b.append(["Roll No", "Student Name", f"Hindi_{u_b}"])
    ws_b.append(["1", "Aarav Kumar", 92])
    buf_b = io.BytesIO()
    wb_b.save(buf_b)

    from app.main import app
    from app.api.dependencies.auth import get_current_user

    prev_override = app.dependency_overrides.get(get_current_user)
    app.dependency_overrides[get_current_user] = lambda: teacher_user_b
    try:
        resp_b = await client.post(
            f"/api/v1/marks/examinations/{exam.id}/upload-class-all-subjects",
            params={"class_id": str(cls.id), "section_id": str(sec.id), "school_id": str(school.id)},
            headers=teacher_b_headers,
            files={"file": ("case_b.xlsx", buf_b.getvalue(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")}
        )
    finally:
        if prev_override is not None:
            app.dependency_overrides[get_current_user] = prev_override
        else:
            app.dependency_overrides.pop(get_current_user, None)

    assert resp_b.status_code == 200, resp_b.text
    stmt_b = select(Marks).where(
        Marks.exam_schedule_id == sched_hindi.id,
        Marks.examination_id == exam.id,
        Marks.school_id == school.id
    )
    mark_b = (await db_session.execute(stmt_b)).scalars().first()
    assert mark_b is not None
    assert mark_b.teacher_id == teacher_b_record.id
    assert mark_b.teacher_id != teacher_user_b.id

    # =========================================================================
    # CASE C: No valid teacher relationship exists -> HTTP 422
    # =========================================================================
    u_c = uuid.uuid4().hex[:6]
    sub_french = Subject(
        tenant_id=tenant.id,
        school_id=school.id,
        academic_year_id=ay.id,
        subject_name=f"French_{u_c}",
        subject_code=f"FR_{u_c}",
        category=SubjectCategory.CORE,
        subject_type=SubjectType.THEORY,
        status=SubjectStatus.ACTIVE
    )
    db_session.add(sub_french)
    await db_session.flush()

    tsa_french = TeacherSubjectAssignment(
        tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id,
        teacher_id=teacher.id, subject_id=sub_french.id, class_id=cls.id, section_id=sec.id,
        assignment_type="PRIMARY", weekly_periods=4, effective_from=date(2025, 6, 1),
        assigned_at=datetime.now(timezone.utc), is_active=False
    )
    db_session.add(tsa_french)
    await db_session.flush()

    sched_french = ExamSchedule(
        exam_id=exam.id,
        class_id=cls.id,
        section_id=sec.id,
        subject_id=sub_french.id,
        teacher_subject_assignment_id=tsa_french.id,
        academic_year_id=ay.id,
        exam_date=date(2025, 9, 10),
        start_time=time(9, 0),
        end_time=time(12, 0),
        max_marks=100,
        pass_marks=35,
        tenant_id=tenant.id,
        school_id=school.id
    )
    db_session.add(sched_french)
    await db_session.commit()

    wb_c = Workbook()
    ws_c = wb_c.active
    ws_c.title = "Marks Entry"
    ws_c.append(["Roll No", "Student Name", f"French_{u_c}"])
    ws_c.append(["1", "Aarav Kumar", 75])
    buf_c = io.BytesIO()
    wb_c.save(buf_c)

    app.dependency_overrides[get_current_user] = lambda: admin_user
    try:
        resp_c = await client.post(
            f"/api/v1/marks/examinations/{exam.id}/upload-class-all-subjects",
            params={"class_id": str(cls.id), "section_id": str(sec.id), "school_id": str(school.id)},
            headers=admin_headers,
            files={"file": ("case_c.xlsx", buf_c.getvalue(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")}
        )
    finally:
        if prev_override is not None:
            app.dependency_overrides[get_current_user] = prev_override
        else:
            app.dependency_overrides.pop(get_current_user, None)

    assert resp_c.status_code == 422
    assert resp_c.headers.get("access-control-allow-origin") == "http://localhost:3000"
    resp_c_json = resp_c.json()
    error_msg = resp_c_json.get("detail") or resp_c_json.get("message")
    assert "Cannot upload marks for subject" in str(error_msg)

    # =========================================================================
    # CASE D: Failed database operation triggers rollback & returns secure HTTP 500
    # =========================================================================
    wb_d = Workbook()
    ws_d = wb_d.active
    ws_d.title = "Marks Entry"
    ws_d.append(["Roll No", "Student Name", "English"])
    ws_d.append(["2", "Priya Sharma", 95])
    buf_d = io.BytesIO()
    wb_d.save(buf_d)

    target_sched_id = sched_eng.id
    target_student_id = data["students"][1].id

    stmt_count_pre = select(Marks).where(
        Marks.exam_schedule_id == target_sched_id,
        Marks.student_id == target_student_id
    )
    assert (await db_session.execute(stmt_count_pre)).scalars().first() is None

    with patch.object(db_session, "flush", side_effect=SQLAlchemyError("Simulated disk write failure")):
        resp_d = await client.post(
            f"/api/v1/marks/examinations/{exam.id}/upload-class-all-subjects",
            params={"class_id": str(cls.id), "section_id": str(sec.id), "school_id": str(school.id)},
            headers=admin_headers,
            files={"file": ("case_d.xlsx", buf_d.getvalue(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")}
        )
        assert resp_d.status_code == 500
        assert resp_d.headers.get("access-control-allow-origin") == "http://localhost:3000"
        resp_d_json = resp_d.json()
        error_msg_d = resp_d_json.get("detail") or resp_d_json.get("message")
        assert error_msg_d == "An unexpected error occurred while processing the marks upload."
        assert "Simulated disk write failure" not in str(resp_d_json)

    stmt_count_post = select(Marks).where(
        Marks.exam_schedule_id == target_sched_id,
        Marks.student_id == target_student_id
    )
    assert (await db_session.execute(stmt_count_post)).scalars().first() is None




