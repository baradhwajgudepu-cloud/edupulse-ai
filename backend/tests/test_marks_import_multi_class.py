import io
import uuid
import pytest
from datetime import date
from openpyxl import Workbook
from sqlalchemy import select
from fastapi import HTTPException

from app.models.tenant import Tenant
from app.models.school import School
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.class_entity import Class, ClassCategory
from app.models.section import Section
from app.models.student import Student, StudentGender
from app.models.subject import Subject, SubjectCategory, SubjectType, SubjectStatus
from app.models.examination import Examination, ExaminationClass, ExamSchedule, ExamPaper, ExamPaperClass, ExamStatus, ExamType
from app.models.marks import Marks
from app.services.marks import MarksService


@pytest.fixture
async def multi_class_setup(db_session):
    u = uuid.uuid4().hex[:6]
    tenant = Tenant(name=f"MultiClass Tenant {u}", code=f"MCT_{u}", subdomain=f"mct{u}", email=f"mct{u}__edupulse.local")
    db_session.add(tenant)
    await db_session.flush()

    school = School(name=f"MultiClass School {u}", code=f"MCS_{u}", board="CBSE", email=f"mcs_{u}__edupulse.local", tenant_id=tenant.id)
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

    # Classes: Class 5 and Class 6
    cls5 = Class(name="Class 5", code=f"C5_{u}", category=ClassCategory.PRIMARY, level=5, capacity=40, academic_year_id=ay.id, tenant_id=tenant.id, school_id=school.id)
    cls6 = Class(name="Class 6", code=f"C6_{u}", category=ClassCategory.MIDDLE, level=6, capacity=40, academic_year_id=ay.id, tenant_id=tenant.id, school_id=school.id)
    cls7 = Class(name="Class 7", code=f"C7_{u}", category=ClassCategory.MIDDLE, level=7, capacity=40, academic_year_id=ay.id, tenant_id=tenant.id, school_id=school.id)
    db_session.add_all([cls5, cls6, cls7])
    await db_session.flush()

    sec5a = Section(name="Section A", code=f"S5A_{u}", class_id=cls5.id, academic_year_id=ay.id, capacity=40, tenant_id=tenant.id, school_id=school.id)
    sec6a = Section(name="Section A", code=f"S6A_{u}", class_id=cls6.id, academic_year_id=ay.id, capacity=40, tenant_id=tenant.id, school_id=school.id)
    db_session.add_all([sec5a, sec6a])
    await db_session.flush()

    # Students
    st5 = Student(
        first_name="Student5", last_name="A", admission_number=f"ADM5_{u}", roll_number="501",
        gender=StudentGender.MALE, date_of_birth=date(2015, 1, 1), admission_date=date(2023, 6, 1),
        class_id=cls5.id, section_id=sec5a.id, academic_year_id=ay.id, tenant_id=tenant.id, school_id=school.id
    )
    st6 = Student(
        first_name="Student6", last_name="B", admission_number=f"ADM6_{u}", roll_number="601",
        gender=StudentGender.FEMALE, date_of_birth=date(2014, 1, 1), admission_date=date(2023, 6, 1),
        class_id=cls6.id, section_id=sec6a.id, academic_year_id=ay.id, tenant_id=tenant.id, school_id=school.id
    )
    db_session.add_all([st5, st6])
    await db_session.flush()

    # Subjects
    sub_math = Subject(
        subject_name="Mathematics", subject_code=f"MATH_{u}",
        category=SubjectCategory.CORE, subject_type=SubjectType.THEORY,
        status=SubjectStatus.ACTIVE, academic_year_id=ay.id, tenant_id=tenant.id, school_id=school.id
    )
    db_session.add(sub_math)
    await db_session.flush()

    # Cycle Exam with participating classes: Class 5 and Class 6 (Class 7 excluded)
    exam = Examination(
        exam_name="Quarterly Examination 2026",
        exam_type=ExamType.QUARTERLY,
        start_date=date(2026, 9, 1),
        end_date=date(2026, 9, 15),
        status=ExamStatus.SCHEDULED,
        academic_year_id=ay.id,
        tenant_id=tenant.id,
        school_id=school.id,
        settings={"class_ids": [str(cls5.id), str(cls6.id)]},
    )
    db_session.add(exam)
    await db_session.flush()

    ec5 = ExaminationClass(examination_id=exam.id, class_id=cls5.id, tenant_id=tenant.id, school_id=school.id)
    ec6 = ExaminationClass(examination_id=exam.id, class_id=cls6.id, tenant_id=tenant.id, school_id=school.id)
    db_session.add_all([ec5, ec6])
    await db_session.flush()

    # Master Paper: Mathematics with Class 5 max 50 and Class 6 max 100
    paper = ExamPaper(
        examination_id=exam.id,
        subject_id=sub_math.id,
        paper_name="Mathematics Paper",
        paper_code=f"MATH_P_{u}",
        default_max_marks=100,
        default_pass_marks=35,
        order_index=1,
        academic_year_id=ay.id,
        tenant_id=tenant.id,
        school_id=school.id
    )
    db_session.add(paper)
    await db_session.flush()

    # Class Paper Overrides
    epc5 = ExamPaperClass(
        paper_id=paper.id,
        examination_id=exam.id,
        class_id=cls5.id,
        maximum_marks=50,
        pass_marks=18,
        tenant_id=tenant.id,
        school_id=school.id
    )
    epc6 = ExamPaperClass(
        paper_id=paper.id,
        examination_id=exam.id,
        class_id=cls6.id,
        maximum_marks=100,
        pass_marks=35,
        tenant_id=tenant.id,
        school_id=school.id
    )
    db_session.add_all([epc5, epc6])
    await db_session.flush()

    return {
        "tenant": tenant,
        "school": school,
        "ay": ay,
        "cls5": cls5,
        "cls6": cls6,
        "cls7": cls7,
        "sec5a": sec5a,
        "sec6a": sec6a,
        "st5": st5,
        "st6": st6,
        "sub_math": sub_math,
        "exam": exam,
        "paper": paper,
    }


def make_excel_bytes(rows):
    wb = Workbook()
    ws = wb.active
    ws.title = "Marks"
    for row in rows:
        ws.append(row)
    bio = io.BytesIO()
    wb.save(bio)
    return bio.getvalue()


@pytest.mark.anyio
async def test_multi_class_preview_and_paper_resolution(db_session, multi_class_setup):
    s = multi_class_setup
    svc = MarksService(db_session)

    rows = [
        ["Class", "Section", "Roll No", "Admission No", "Student Name", "Subject", "Max Marks", "Marks Obtained", "Status"],
        ["Class 5", "Section A", "501", s["st5"].admission_number, "Student5 A", "Mathematics", 50, 45.0, "PRESENT"],
        ["Class 6", "Section A", "601", s["st6"].admission_number, "Student6 B", "Mathematics", 100, 85.0, "PRESENT"],
        ["Class 7", "Section A", "701", "ADM7_FAKE", "Student7 C", "Mathematics", 100, 75.0, "PRESENT"],
    ]
    file_bytes = make_excel_bytes(rows)

    preview = await svc.preview_exam_wide_marks_file(
        examination_id=s["exam"].id,
        file_bytes=file_bytes,
        filename="multi_class_test.xlsx",
        school_id=s["school"].id,
        academic_year_id=s["ay"].id,
    )

    assert preview.total_rows == 3
    assert preview.valid_rows_count == 2
    assert preview.invalid_rows_count == 1  # Class 7 row is invalid
    assert "Class 5" in preview.classes_detected
    assert "Class 6" in preview.classes_detected

    # Verify class-specific paper override resolution
    row5 = next(r for r in preview.preview_rows if r.class_name == "Class 5")
    assert row5.is_valid is True
    assert row5.max_marks == 50
    assert row5.marks_obtained == 45.0

    row6 = next(r for r in preview.preview_rows if r.class_name == "Class 6")
    assert row6.is_valid is True
    assert row6.max_marks == 100
    assert row6.marks_obtained == 85.0

    row7 = next(r for r in preview.preview_rows if r.class_name == "Class 7")
    assert row7.is_valid is False
    assert "does not participate" in (row7.error_message or "").lower()

    # Verify classes_summary
    assert len(preview.classes_summary) >= 2
    c5_summary = next((c for c in preview.classes_summary if c["class_name"] == "Class 5"), None)
    assert c5_summary is not None
    assert len(c5_summary["sections"]) >= 1


@pytest.mark.anyio
async def test_duplicate_behavior_update_existing(db_session, multi_class_setup):
    s = multi_class_setup
    svc = MarksService(db_session)

    # 1. First import: Class 5 Student gets score 40
    rows1 = [
        ["Class", "Section", "Roll No", "Admission No", "Student Name", "Subject", "Max Marks", "Marks Obtained", "Status"],
        ["Class 5", "Section A", "501", s["st5"].admission_number, "Student5 A", "Mathematics", 50, 40.0, "PRESENT"],
    ]
    prev1 = await svc.preview_exam_wide_marks_file(
        examination_id=s["exam"].id,
        file_bytes=make_excel_bytes(rows1),
        filename="round1.xlsx",
        school_id=s["school"].id,
    )
    res1 = await svc.confirm_exam_wide_marks(
        examination_id=s["exam"].id,
        school_id=s["school"].id,
        rows=prev1.preview_rows,
        auto_approve=True,
        duplicate_behavior="UPDATE_EXISTING",
    )
    assert res1.saved_count == 1
    assert res1.created_count == 1
    assert res1.updated_count == 0

    # 2. Second preview: file has updated score 48 for Class 5, and new row for Class 6
    rows2 = [
        ["Class", "Section", "Roll No", "Admission No", "Student Name", "Subject", "Max Marks", "Marks Obtained", "Status"],
        ["Class 5", "Section A", "501", s["st5"].admission_number, "Student5 A", "Mathematics", 50, 48.0, "PRESENT"],
        ["Class 6", "Section A", "601", s["st6"].admission_number, "Student6 B", "Mathematics", 100, 92.0, "PRESENT"],
    ]
    prev2 = await svc.preview_exam_wide_marks_file(
        examination_id=s["exam"].id,
        file_bytes=make_excel_bytes(rows2),
        filename="round2.xlsx",
        school_id=s["school"].id,
    )
    assert prev2.existing_marks_count == 1
    row5_p2 = next(r for r in prev2.preview_rows if r.class_name == "Class 5")
    assert row5_p2.is_existing is True

    # 3. Confirm with UPDATE_EXISTING
    res2 = await svc.confirm_exam_wide_marks(
        examination_id=s["exam"].id,
        school_id=s["school"].id,
        rows=prev2.preview_rows,
        auto_approve=True,
        duplicate_behavior="UPDATE_EXISTING",
    )
    assert res2.saved_count == 2
    assert res2.created_count == 1  # Class 6 is newly created
    assert res2.updated_count == 1  # Class 5 is updated
    assert res2.skipped_count == 0

    # Check updated score in DB
    mark = (await db_session.execute(
        select(Marks).where(Marks.student_id == s["st5"].id)
    )).scalar_one()
    assert mark.marks_obtained == 48.0


@pytest.mark.anyio
async def test_duplicate_behavior_skip_existing(db_session, multi_class_setup):
    s = multi_class_setup
    svc = MarksService(db_session)

    # 1. Existing score 40
    rows1 = [
        ["Class", "Section", "Roll No", "Admission No", "Student Name", "Subject", "Max Marks", "Marks Obtained", "Status"],
        ["Class 5", "Section A", "501", s["st5"].admission_number, "Student5 A", "Mathematics", 50, 40.0, "PRESENT"],
    ]
    prev1 = await svc.preview_exam_wide_marks_file(
        examination_id=s["exam"].id,
        file_bytes=make_excel_bytes(rows1),
        filename="round1.xlsx",
        school_id=s["school"].id,
    )
    await svc.confirm_exam_wide_marks(
        examination_id=s["exam"].id,
        school_id=s["school"].id,
        rows=prev1.preview_rows,
        auto_approve=True,
    )

    # 2. Second upload with score 50, but duplicate_behavior="SKIP_EXISTING"
    rows2 = [
        ["Class", "Section", "Roll No", "Admission No", "Student Name", "Subject", "Max Marks", "Marks Obtained", "Status"],
        ["Class 5", "Section A", "501", s["st5"].admission_number, "Student5 A", "Mathematics", 50, 50.0, "PRESENT"],
    ]
    prev2 = await svc.preview_exam_wide_marks_file(
        examination_id=s["exam"].id,
        file_bytes=make_excel_bytes(rows2),
        filename="round2.xlsx",
        school_id=s["school"].id,
    )
    res2 = await svc.confirm_exam_wide_marks(
        examination_id=s["exam"].id,
        school_id=s["school"].id,
        rows=prev2.preview_rows,
        auto_approve=True,
        duplicate_behavior="SKIP_EXISTING",
    )
    assert res2.saved_count == 0
    assert res2.created_count == 0
    assert res2.updated_count == 0
    assert res2.skipped_count == 1

    # Score in DB must still be 40.0, NOT 50.0!
    mark = (await db_session.execute(
        select(Marks).where(Marks.student_id == s["st5"].id)
    )).scalar_one()
    assert mark.marks_obtained == 40.0


@pytest.mark.anyio
async def test_duplicate_behavior_fail_duplicate(db_session, multi_class_setup):
    s = multi_class_setup
    svc = MarksService(db_session)

    # 1. Existing score 40
    rows1 = [
        ["Class", "Section", "Roll No", "Admission No", "Student Name", "Subject", "Max Marks", "Marks Obtained", "Status"],
        ["Class 5", "Section A", "501", s["st5"].admission_number, "Student5 A", "Mathematics", 50, 40.0, "PRESENT"],
    ]
    prev1 = await svc.preview_exam_wide_marks_file(
        examination_id=s["exam"].id,
        file_bytes=make_excel_bytes(rows1),
        filename="round1.xlsx",
        school_id=s["school"].id,
    )
    await svc.confirm_exam_wide_marks(
        examination_id=s["exam"].id,
        school_id=s["school"].id,
        rows=prev1.preview_rows,
        auto_approve=True,
    )

    # 2. Second upload with duplicate_behavior="FAIL_DUPLICATE"
    rows2 = [
        ["Class", "Section", "Roll No", "Admission No", "Student Name", "Subject", "Max Marks", "Marks Obtained", "Status"],
        ["Class 5", "Section A", "501", s["st5"].admission_number, "Student5 A", "Mathematics", 50, 45.0, "PRESENT"],
    ]
    prev2 = await svc.preview_exam_wide_marks_file(
        examination_id=s["exam"].id,
        file_bytes=make_excel_bytes(rows2),
        filename="round2.xlsx",
        school_id=s["school"].id,
    )
    with pytest.raises(HTTPException) as exc_info:
        await svc.confirm_exam_wide_marks(
            examination_id=s["exam"].id,
            school_id=s["school"].id,
            rows=prev2.preview_rows,
            auto_approve=True,
            duplicate_behavior="FAIL_DUPLICATE",
        )
    assert exc_info.value.status_code == 409
    assert "duplicate" in exc_info.value.detail.lower()


@pytest.mark.anyio
async def test_generate_exam_wide_template_multi_class(db_session, multi_class_setup):
    s = multi_class_setup
    svc = MarksService(db_session)

    # Generate template for all participating classes
    content, filename, mime = await svc.generate_exam_wide_template(
        examination_id=s["exam"].id,
        school_id=s["school"].id,
    )
    assert len(content) > 0
    assert ".xlsx" in filename
    assert "application/vnd.openxmlformats" in mime

    # Load and check workbook has headers and participating students
    from openpyxl import load_workbook
    wb = load_workbook(io.BytesIO(content))
    ws = wb.active
    rows = list(ws.iter_rows(values_only=True))
    assert len(rows) >= 3  # Header + at least Student 5 and Student 6
    header = rows[0]
    assert "Class" in header
    assert "Subject" in header
    assert "Marks Obtained" in header


@pytest.mark.anyio
async def test_confirm_exam_wide_marks_missing_class_breakdown(db_session, multi_class_setup):
    s = multi_class_setup
    svc = MarksService(db_session)

    # File only has data for Class 5, Class 6 is participating in the exam but has 0 records in upload
    rows = [
        ["Class", "Section", "Roll No", "Admission No", "Student Name", "Subject", "Max Marks", "Marks Obtained", "Status"],
        ["Class 5", "Section A", "501", s["st5"].admission_number, "Student5 A", "Mathematics", 50, 42.0, "PRESENT"],
    ]
    file_bytes = make_excel_bytes(rows)

    preview = await svc.preview_exam_wide_marks_file(
        examination_id=s["exam"].id,
        file_bytes=file_bytes,
        filename="class5_only.xlsx",
        school_id=s["school"].id,
    )
    assert preview.valid_rows_count == 1

    res = await svc.confirm_exam_wide_marks(
        examination_id=s["exam"].id,
        school_id=s["school"].id,
        rows=preview.preview_rows,
        auto_approve=True,
    )

    assert res.saved_count == 1
    assert res.classes_count == 1
    assert len(res.classes_breakdown) >= 2

    c5_b = next((b for b in res.classes_breakdown if b.get("class_name") == "Class 5"), None)
    assert c5_b is not None
    assert c5_b["total_records"] == 1
    assert c5_b["created_count"] == 1
    assert c5_b["status"] == "SUCCESS"
    assert c5_b["sections_count"] == 1
    assert c5_b["students_count"] == 1

    c6_b = next((b for b in res.classes_breakdown if b.get("class_name") == "Class 6"), None)
    assert c6_b is not None
    assert c6_b["total_records"] == 0
    assert c6_b["status"] == "NOT_FOUND"
    assert "No student marks records found" in c6_b.get("reason", "")

