import io
import uuid
import pytest
from datetime import date, time, datetime, timezone
from httpx import AsyncClient, ASGITransport
from sqlalchemy import select

from app.main import app
from app.models.tenant import Tenant
from app.models.school import School
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.class_entity import Class, ClassCategory
from app.models.section import Section
from app.models.student import Student, StudentGender
from app.models.teacher import Teacher, EmploymentType
from app.models.subject import Subject, SubjectCategory, SubjectType, SubjectStatus
from app.models.teacher_subject_assignment import TeacherSubjectAssignment
from app.models.examination import Examination, ExamSchedule, ExamStatus, ExamType
from app.models.syllabus import Syllabus
from app.models.marks import Marks, MarksStatus, ExamResult
from app.models.question_paper import QuestionPaper, StudentQuestionMarks
from app.models.exam_question import ExamQuestion, QuestionDifficulty, QuestionType
from app.models.role import Role
from app.models.permission import Permission
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
from app.repositories.school import SchoolRepository
from app.schemas.auth import UserCreate
from app.services.auth import AuthService
from app.services.question_paper_intelligence import QuestionPaperIntelligenceService
from app.services.examination import ExaminationService
from app.schemas.question_paper import (
    QuestionWiseStudentRow, QuestionPaperVerifyRequest, ExtractedQuestionItem
)


@pytest.fixture
async def setup_qp_test_data(db_session):
    u = uuid.uuid4().hex[:6]
    tenant = Tenant(name=f"QP Tenant {u}", code=f"qpt_{u}", subdomain=f"qpt{u}", email=f"qpt{u}@edu.local")
    db_session.add(tenant)
    await db_session.flush()

    school = School(name=f"QP School {u}", code=f"QPS_{u}", board="CBSE", email=f"qps_{u}@edu.local", tenant_id=tenant.id)
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
        name="Class 10",
        code=f"C10_{u}",
        category=ClassCategory.HIGH,
        level=10,
        capacity=40,
        academic_year_id=ay.id,
        tenant_id=tenant.id,
        school_id=school.id
    )
    db_session.add(cls)
    await db_session.flush()

    sec = Section(
        name="Section A",
        code=f"SEC_{u}",
        class_id=cls.id,
        capacity=40,
        academic_year_id=ay.id,
        tenant_id=tenant.id,
        school_id=school.id
    )
    db_session.add(sec)
    await db_session.flush()

    stud1 = Student(
        admission_number=f"ADM-1-{u}",
        roll_number="1",
        first_name="Rohan",
        last_name="Verma",
        gender=StudentGender.MALE,
        date_of_birth=date(2010, 5, 12),
        admission_date=date(2022, 6, 1),
        class_id=cls.id,
        section_id=sec.id,
        academic_year_id=ay.id,
        tenant_id=tenant.id,
        school_id=school.id,
        is_active=True
    )
    stud2 = Student(
        admission_number=f"ADM-2-{u}",
        roll_number="2",
        first_name="Ananya",
        last_name="Sen",
        gender=StudentGender.FEMALE,
        date_of_birth=date(2010, 8, 24),
        admission_date=date(2022, 6, 1),
        class_id=cls.id,
        section_id=sec.id,
        academic_year_id=ay.id,
        tenant_id=tenant.id,
        school_id=school.id,
        is_active=True
    )
    db_session.add_all([stud1, stud2])
    await db_session.flush()

    tchr = Teacher(
        employee_code=f"EMP_{u}",
        staff_code=f"STF_{u}",
        first_name="Vikram",
        last_name="Mathur",
        gender=StudentGender.MALE,
        date_of_birth=date(1982, 3, 10),
        mobile=f"+91987654{u[:4]}",
        official_email=f"v.mathur_{u}@edu.local",
        joining_date=date(2020, 1, 1),
        employment_type=EmploymentType.FULL_TIME,
        tenant_id=tenant.id,
        school_id=school.id
    )
    db_session.add(tchr)
    await db_session.flush()

    subj = Subject(
        subject_name="Mathematics",
        subject_code=f"MTH_{u}",
        category=SubjectCategory.CORE,
        subject_type=SubjectType.THEORY,
        status=SubjectStatus.ACTIVE,
        academic_year_id=ay.id,
        tenant_id=tenant.id,
        school_id=school.id
    )
    db_session.add(subj)
    await db_session.flush()

    tsa = TeacherSubjectAssignment(
        teacher_id=tchr.id,
        subject_id=subj.id,
        class_id=cls.id,
        section_id=sec.id,
        academic_year_id=ay.id,
        assignment_type="PRIMARY",
        weekly_periods=5,
        effective_from=date(2025, 6, 1),
        assigned_at=datetime.now(timezone.utc),
        tenant_id=tenant.id,
        school_id=school.id
    )
    db_session.add(tsa)
    await db_session.flush()

    # Configured syllabus hierarchy
    s1 = Syllabus(
        syllabus_code=f"SYLL_1_{u}",
        academic_year_id=ay.id,
        class_id=cls.id,
        subject_id=subj.id,
        unit_name="Unit 1: Number Systems",
        chapter_name="Real Numbers",
        topic_name="Fundamental Theorem of Arithmetic",
        sequence_order=1,
        tenant_id=tenant.id,
        school_id=school.id
    )
    s2 = Syllabus(
        syllabus_code=f"SYLL_2_{u}",
        academic_year_id=ay.id,
        class_id=cls.id,
        subject_id=subj.id,
        unit_name="Unit 2: Algebra",
        chapter_name="Quadratic Equations",
        topic_name="Roots by Quadratic Formula",
        sequence_order=2,
        tenant_id=tenant.id,
        school_id=school.id
    )
    db_session.add_all([s1, s2])
    await db_session.flush()

    exam = Examination(
        school_id=school.id,
        academic_year_id=ay.id,
        exam_name=f"Mid-Term Examination 2026 {u}",
        exam_type=ExamType.QUARTERLY,
        status=ExamStatus.DRAFT,
        start_date=date(2026, 9, 1),
        end_date=date(2026, 9, 15),
        tenant_id=tenant.id
    )
    db_session.add(exam)
    await db_session.flush()

    sched = ExamSchedule(
        exam_id=exam.id,
        class_id=cls.id,
        section_id=sec.id,
        subject_id=subj.id,
        teacher_subject_assignment_id=tsa.id,
        academic_year_id=ay.id,
        exam_date=date(2026, 9, 5),
        start_time=time(9, 0),
        end_time=time(12, 0),
        max_marks=100,
        pass_marks=35,
        tenant_id=tenant.id,
        school_id=school.id
    )
    db_session.add(sched)
    await db_session.flush()

    # User with permissions
    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    ref_repo = RefreshTokenRepository(db_session)
    sch_repo = SchoolRepository(db_session)

    stmt_p = select(Permission)
    res_p = await db_session.execute(stmt_p)
    all_perms = list(res_p.scalars().all())

    role = Role(name=f"Admin_{u}", code="SUPER_ADMIN", is_system=True, tenant_id=tenant.id, permissions=all_perms)
    db_session.add(role)
    await db_session.flush()

    auth_svc = AuthService(user_repo, role_repo, perm_repo, ref_repo, sch_repo)
    user = await auth_svc.create_user(
        tenant.id,
        UserCreate(
            email=f"admin_{u}@edu.local",
            password="Password123!",
            first_name="Admin",
            last_name="User"
        )
    )
    user.roles.append(role)
    tokens = await auth_svc.create_tokens(user)
    token = tokens.access_token
    await db_session.commit()

    return {
        "tenant": tenant,
        "school": school,
        "ay": ay,
        "class": cls,
        "section": sec,
        "student1": stud1,
        "student2": stud2,
        "teacher": tchr,
        "subject": subj,
        "tsa": tsa,
        "syllabus1": s1,
        "syllabus2": s2,
        "exam": exam,
        "schedule": sched,
        "user": user,
        "token": token
    }


# =============================================================================
# 1. TEXT EXTRACTION UNIT TESTS
# =============================================================================
def test_parse_raw_text_to_questions():
    sample_text = """
    SECTION A
    Q1. Find the roots of the quadratic equation using Quadratic Formula. [5 Marks]
    Q2: Explain the Fundamental Theorem of Arithmetic with prime factors. (10 marks)
    (a) State the theorem. [4]
    (b) Give an example. [6]
    SECTION B
    3. Choose the correct option: Which number is irrational? (A) 2 (B) sqrt(3) (C) 4 [2 Marks]
    4. Calculate the LCM and HCF of 12 and 18. [4 Marks]
    """
    service = QuestionPaperIntelligenceService(None)
    questions, overall_conf, low_conf_cnt = service.parse_raw_text_to_questions(sample_text)

    assert len(questions) == 4
    # Q1 checks
    assert questions[0].question_number == "Q1"
    assert questions[0].section_name == "SECTION A"
    assert questions[0].max_marks == 5.0
    assert "Fundamental" not in questions[0].question_text
    assert questions[0].difficulty in ["MEDIUM", "EASY"]

    # Q2 with sub-questions
    assert questions[1].question_number == "Q2"
    assert questions[1].max_marks == 10.0
    assert len(questions[1].sub_questions) == 2
    assert questions[1].sub_questions[0].question_number == "Q2(a)"
    assert questions[1].sub_questions[0].max_marks == 4.0
    assert questions[1].sub_questions[1].question_number == "Q2(b)"
    assert questions[1].sub_questions[1].max_marks == 6.0

    # Q3 MCQ
    assert questions[2].question_number == "Q3"
    assert questions[2].section_name == "SECTION B"
    assert questions[2].question_type == "MCQ"
    assert questions[2].max_marks == 2.0

    # Q4 Numerical
    assert questions[3].question_number == "Q4"
    assert questions[3].question_type == "NUMERICAL"
    assert questions[3].max_marks == 4.0


# =============================================================================
# 2. ZERO-HALLUCINATION SYLLABUS MAPPING TESTS
# =============================================================================
@pytest.mark.anyio
async def test_syllabus_mapping_zero_hallucination(db_session, setup_qp_test_data):
    data = setup_qp_test_data
    service = QuestionPaperIntelligenceService(db_session)

    options = await service.get_configured_syllabus_options(
        school_id=data["school"].id,
        academic_year_id=data["ay"].id,
        class_id=data["class"].id,
        subject_id=data["subject"].id
    )
    assert len(options) == 2
    assert options[0].chapter_name == "Real Numbers"
    assert options[1].chapter_name == "Quadratic Equations"

    sample_questions = [
        ExtractedQuestionItem(
            question_number="Q1",
            question_text="State the Fundamental Theorem of Arithmetic and prime factorisation.",
            max_marks=5.0
        ),
        ExtractedQuestionItem(
            question_number="Q2",
            question_text="Find the roots of 2x^2 + 5x - 3 = 0 using Quadratic Formula.",
            max_marks=5.0
        ),
        ExtractedQuestionItem(
            question_number="Q3",
            question_text="Explain Quantum Chromodynamics and String Theory.", # Unrelated topic
            max_marks=10.0
        )
    ]

    mapped = await service.map_questions_to_syllabus(sample_questions, options)

    # Q1 mapped accurately to Real Numbers
    assert mapped[0].chapter_name == "Real Numbers"
    assert mapped[0].topic_name == "Fundamental Theorem of Arithmetic"
    assert mapped[0].mapping_confidence > 0.5
    assert mapped[0].review_status == "PENDING"

    # Q2 mapped to Quadratic Equations
    assert mapped[1].chapter_name == "Quadratic Equations"
    assert mapped[1].topic_name == "Roots by Quadratic Formula"
    assert mapped[1].review_status == "PENDING"

    # Q3 flagged for review, zero hallucination (not made up)
    assert mapped[2].review_status == "FLAGGED_FOR_REVIEW"
    assert mapped[2].mapping_source == "UNMAPPED"
    assert "requires review" in mapped[2].topic_name.lower()


# =============================================================================
# 3. DUAL-MODE MARKS ENTRY & VALIDATION TESTS
# =============================================================================
@pytest.mark.anyio
async def test_marks_validation_and_aggregation(db_session, setup_qp_test_data):
    data = setup_qp_test_data
    service = QuestionPaperIntelligenceService(db_session)
    paper_id = data["schedule"].id

    # Add 2 questions to the paper
    q1 = ExamQuestion(
        tenant_id=data["tenant"].id,
        school_id=data["school"].id,
        academic_year_id=data["ay"].id,
        examination_id=data["exam"].id,
        subject_id=data["subject"].id,
        exam_schedule_id=paper_id,
        question_number="Q1",
        max_marks=10.0,
        question_type=QuestionType.SHORT,
        difficulty=QuestionDifficulty.MEDIUM
    )
    q2 = ExamQuestion(
        tenant_id=data["tenant"].id,
        school_id=data["school"].id,
        academic_year_id=data["ay"].id,
        examination_id=data["exam"].id,
        subject_id=data["subject"].id,
        exam_schedule_id=paper_id,
        question_number="Q2",
        max_marks=15.0,
        question_type=QuestionType.LONG,
        difficulty=QuestionDifficulty.HARD
    )
    db_session.add_all([q1, q2])
    await db_session.commit()

    # 1. Negative marks validation
    with pytest.raises(Exception) as exc_neg:
        await service.save_question_wise_marks(
            paper_id=paper_id,
            rows=[
                QuestionWiseStudentRow(
                    student_id=data["student1"].id,
                    student_name="Rohan Verma",
                    admission_number="ADM-1",
                    question_marks={str(q1.id): -2.0, str(q2.id): 10.0}
                )
            ],
            is_draft=False,
            current_user_id=data["user"].id,
            school_id=data["school"].id,
            tenant_id=data["tenant"].id
        )
    assert "cannot be negative" in str(exc_neg.value).lower()

    # 2. Exceeds max marks validation
    with pytest.raises(Exception) as exc_exceed:
        await service.save_question_wise_marks(
            paper_id=paper_id,
            rows=[
                QuestionWiseStudentRow(
                    student_id=data["student1"].id,
                    student_name="Rohan Verma",
                    admission_number="ADM-1",
                    question_marks={str(q1.id): 12.0, str(q2.id): 10.0} # 12 > 10.0 max
                )
            ],
            is_draft=False,
            current_user_id=data["user"].id,
            school_id=data["school"].id,
            tenant_id=data["tenant"].id
        )
    assert "exceeds maximum marks" in str(exc_exceed.value).lower()

    # 3. Successful valid save and auto-sum to Marks
    valid_res = await service.save_question_wise_marks(
        paper_id=paper_id,
        rows=[
            QuestionWiseStudentRow(
                student_id=data["student1"].id,
                student_name="Rohan Verma",
                admission_number="ADM-1",
                question_marks={str(q1.id): 8.0, str(q2.id): 12.0} # Sum = 20.0
            ),
            QuestionWiseStudentRow(
                student_id=data["student2"].id,
                student_name="Ananya Sen",
                admission_number="ADM-2",
                question_marks={str(q1.id): 10.0, str(q2.id): 14.0} # Sum = 24.0
            )
        ],
        is_draft=False,
        current_user_id=data["user"].id,
        school_id=data["school"].id,
        tenant_id=data["tenant"].id
    )
    assert valid_res["success"] is True
    assert valid_res["total_students"] == 2

    # Verify Marks table synchronized
    stmt = select(Marks).where(Marks.exam_schedule_id == paper_id)
    res = await db_session.execute(stmt)
    saved_marks = {m.student_id: float(m.marks_obtained) for m in res.scalars().all()}
    assert saved_marks[data["student1"].id] == 20.0
    assert saved_marks[data["student2"].id] == 24.0


# =============================================================================
# 4. QUESTION-WISE ANALYTICS & DATA SUFFICIENCY TESTS
# =============================================================================
@pytest.mark.anyio
async def test_analytics_data_sufficiency(db_session, setup_qp_test_data):
    data = setup_qp_test_data
    service = QuestionPaperIntelligenceService(db_session)
    paper_id = data["schedule"].id

    # Case A: Only Total Marks entered (no question-wise data)
    m1 = Marks(
        tenant_id=data["tenant"].id,
        school_id=data["school"].id,
        academic_year_id=data["ay"].id,
        examination_id=data["exam"].id,
        exam_schedule_id=paper_id,
        teacher_subject_assignment_id=data["tsa"].id,
        teacher_id=data["teacher"].id,
        subject_id=data["subject"].id,
        class_id=data["class"].id,
        section_id=data["section"].id,
        student_id=data["student1"].id,
        maximum_marks=100,
        marks_obtained=75,
        result_status=ExamResult.PRESENT,
        status=MarksStatus.SUBMITTED
    )
    db_session.add(m1)
    await db_session.commit()

    analytics_total_only = await service.get_question_wise_analytics(
        paper_id=paper_id,
        school_id=data["school"].id,
        tenant_id=data["tenant"].id
    )
    assert analytics_total_only.has_question_data is False
    assert analytics_total_only.data_sufficiency == "TOTAL_MARKS_ONLY"
    assert "Detailed topic analysis unavailable because question-wise marks were not entered." in analytics_total_only.message
    assert len(analytics_total_only.question_analytics) == 0

    # Case B: Question-wise data entered
    q1 = ExamQuestion(
        tenant_id=data["tenant"].id,
        school_id=data["school"].id,
        academic_year_id=data["ay"].id,
        examination_id=data["exam"].id,
        subject_id=data["subject"].id,
        exam_schedule_id=paper_id,
        question_number="Q1",
        max_marks=10.0,
        chapter_name="Real Numbers",
        topic_name="Fundamental Theorem of Arithmetic",
        question_type=QuestionType.SHORT,
        difficulty=QuestionDifficulty.MEDIUM
    )
    db_session.add(q1)
    await db_session.flush()

    sqm1 = StudentQuestionMarks(
        tenant_id=data["tenant"].id,
        school_id=data["school"].id,
        academic_year_id=data["ay"].id,
        examination_id=data["exam"].id,
        exam_schedule_id=paper_id,
        question_id=q1.id,
        student_id=data["student1"].id,
        marks_obtained=3.0, # 30% -> Should indicate HARD
        max_marks=10.0
    )
    db_session.add(sqm1)
    await db_session.commit()

    analytics_qw = await service.get_question_wise_analytics(
        paper_id=paper_id,
        school_id=data["school"].id,
        tenant_id=data["tenant"].id
    )
    assert analytics_qw.has_question_data is True
    assert analytics_qw.data_sufficiency == "QUESTION_WISE_AVAILABLE"
    assert len(analytics_qw.question_analytics) == 1
    assert analytics_qw.question_analytics[0]["difficulty_indicator"] == "HARD"
    assert analytics_qw.question_analytics[0]["students_below_50_count"] == 1
    assert len(analytics_qw.topic_analytics) == 1
    assert analytics_qw.topic_analytics[0]["topic_name"] == "Fundamental Theorem of Arithmetic"


# =============================================================================
# 5. EXAMINATION SAFE DELETE & ARCHIVE TESTS
# =============================================================================
@pytest.mark.anyio
async def test_exam_delete_and_archive_safety(db_session, setup_qp_test_data):
    data = setup_qp_test_data
    from app.repositories.examination import ExaminationRepository, ExamScheduleRepository, ExamTypeMasterRepository, ExamTemplateRepository
    from app.repositories.school import SchoolRepository
    from app.repositories.academic_year import AcademicYearRepository
    from app.repositories.teacher_subject_assignment import TeacherSubjectAssignmentRepository
    exam_repo = ExaminationRepository(db_session)
    sched_repo = ExamScheduleRepository(db_session)
    type_repo = ExamTypeMasterRepository(db_session)
    tpl_repo = ExamTemplateRepository(db_session)
    school_repo = SchoolRepository(db_session)
    ay_repo = AcademicYearRepository(db_session)
    tsa_repo = TeacherSubjectAssignmentRepository(db_session)

    exam_service = ExaminationService(
        type_repo=type_repo,
        template_repo=tpl_repo,
        exam_repo=exam_repo,
        schedule_repo=sched_repo,
        school_repo=school_repo,
        academic_year_repo=ay_repo,
        tsa_repo=tsa_repo
    )

    # 1. Draft exam with no marks can be deleted directly
    del_obj = await exam_service.delete_examination(
        tenant_id=data["tenant"].id,
        school_id=data["school"].id,
        exam_id=data["exam"].id,
        current_user=data["user"],
        mode="standard"
    )
    assert del_obj.id == data["exam"].id

    # 2. Re-create Published exam with marks
    pub_exam = Examination(
        school_id=data["school"].id,
        academic_year_id=data["ay"].id,
        exam_name="Published Mid-Term 2026",
        exam_type=ExamType.ANNUAL,
        status=ExamStatus.PUBLISHED,
        start_date=date(2026, 9, 1),
        end_date=date(2026, 9, 15),
        tenant_id=data["tenant"].id
    )
    db_session.add(pub_exam)
    await db_session.flush()

    m = Marks(
        tenant_id=data["tenant"].id,
        school_id=data["school"].id,
        academic_year_id=data["ay"].id,
        examination_id=pub_exam.id,
        exam_schedule_id=data["schedule"].id,
        teacher_subject_assignment_id=data["tsa"].id,
        teacher_id=data["teacher"].id,
        subject_id=data["subject"].id,
        class_id=data["class"].id,
        section_id=data["section"].id,
        student_id=data["student1"].id,
        maximum_marks=100,
        marks_obtained=80,
        result_status=ExamResult.PRESENT,
        status=MarksStatus.SUBMITTED
    )
    db_session.add(m)
    await db_session.commit()

    # 3. Standard delete must be rejected for PUBLISHED / has marks
    with pytest.raises(Exception) as exc_blocked:
        await exam_service.delete_examination(
            tenant_id=data["tenant"].id,
            school_id=data["school"].id,
            exam_id=pub_exam.id,
            current_user=data["user"],
            mode="standard"
        )
    assert "cannot delete examination" in str(exc_blocked.value).lower()
    assert "archive" in str(exc_blocked.value).lower()

    # 4. Check Deletion Impact API
    impact = await exam_service.get_deletion_impact(
        tenant_id=data["tenant"].id,
        school_id=data["school"].id,
        exam_id=pub_exam.id
    )
    assert impact["can_delete_direct"] is False
    assert impact["can_archive"] is True
    assert impact["results_count"] >= 1

    # 5. Archive examination works
    archived = await exam_service.archive_examination(
        tenant_id=data["tenant"].id,
        school_id=data["school"].id,
        exam_id=pub_exam.id,
        current_user=data["user"]
    )
    assert archived.status == ExamStatus.ARCHIVED

    # 6. Permanent delete requires exact confirmation name
    with pytest.raises(Exception) as exc_mismatch:
        await exam_service.delete_examination(
            tenant_id=data["tenant"].id,
            school_id=data["school"].id,
            exam_id=pub_exam.id,
            current_user=data["user"],
            mode="permanent",
            confirmation_name="Wrong Exam Name"
        )
    assert "confirmation name mismatch" in str(exc_mismatch.value).lower()

    # 7. Permanent delete with exact confirmation name
    perm_del = await exam_service.delete_examination(
        tenant_id=data["tenant"].id,
        school_id=data["school"].id,
        exam_id=pub_exam.id,
        current_user=data["user"],
        mode="permanent",
        confirmation_name="Published Mid-Term 2026"
    )
    assert perm_del.id == pub_exam.id

    # Verify Students and Teachers are NEVER deleted
    stud_check = await db_session.get(Student, data["student1"].id)
    assert stud_check is not None
    teacher_check = await db_session.get(Teacher, data["teacher"].id)
    assert teacher_check is not None


# =============================================================================
# 6. FASTAPI ENDPOINT INTEGRATION TESTS
# =============================================================================
@pytest.mark.anyio
async def test_question_paper_and_marks_api_flow(client: AsyncClient, setup_qp_test_data):
    data = setup_qp_test_data
    exam_id = str(data["exam"].id)
    paper_id = str(data["schedule"].id)
    school_id = str(data["school"].id)
    headers = {
        "Authorization": f"Bearer {data['token']}",
        "X-Tenant-ID": str(data["tenant"].id),
        "X-School-ID": school_id
    }

    # 1. Delete Impact
    impact_resp = await client.get(
        f"/api/v1/examinations/{exam_id}/delete-impact",
        params={"school_id": school_id},
        headers=headers
    )
    assert impact_resp.status_code == 200
    impact_data = impact_resp.json()["data"]
    assert impact_data["exam_id"] == exam_id
    assert impact_data["can_delete_direct"] is True

    # 2. Upload Question Paper with raw text
    sample_paper = """
    SECTION A
    Q1. What is the Fundamental Theorem of Arithmetic? [5 Marks]
    Q2. Solve 3x^2 - 4x + 1 = 0 using Quadratic Formula. [5 Marks]
    """
    upload_resp = await client.post(
        f"/api/v1/examinations/{exam_id}/papers/{paper_id}/question-paper/upload",
        params={"school_id": school_id},
        data={"raw_text": sample_paper},
        headers=headers
    )
    assert upload_resp.status_code == 200
    extract_data = upload_resp.json()["data"]
    assert extract_data["detected_questions_count"] == 2
    assert extract_data["verification_status"] == "PENDING_REVIEW"

    # 3. Get Question Paper
    qp_resp = await client.get(
        f"/api/v1/examinations/{exam_id}/papers/{paper_id}/question-paper",
        params={"school_id": school_id},
        headers=headers
    )
    assert qp_resp.status_code == 200
    qp_data = qp_resp.json()["data"]
    assert len(qp_data["questions"]) == 2

    # 4. Teacher Verify & Adjust Question Paper
    verify_payload = {
        "title": "Mathematics Mid-Term Verified Paper",
        "total_marks": 50.0,
        "mark_as_verified": True,
        "questions": [
            {
                "question_number": "Q1",
                "section_name": "SECTION A",
                "sequence_order": 1,
                "question_text": "What is the Fundamental Theorem of Arithmetic?",
                "max_marks": 20.0,
                "question_type": "SHORT",
                "difficulty": "MEDIUM",
                "chapter_name": "Real Numbers",
                "topic_name": "Fundamental Theorem of Arithmetic",
                "sub_questions": []
            },
            {
                "question_number": "Q2",
                "section_name": "SECTION A",
                "sequence_order": 2,
                "question_text": "Solve 3x^2 - 4x + 1 = 0 using Quadratic Formula.",
                "max_marks": 30.0,
                "question_type": "NUMERICAL",
                "difficulty": "HARD",
                "chapter_name": "Quadratic Equations",
                "topic_name": "Roots by Quadratic Formula",
                "sub_questions": []
            }
        ]
    }
    verify_resp = await client.put(
        f"/api/v1/examinations/{exam_id}/papers/{paper_id}/question-paper/verify",
        params={"school_id": school_id},
        json=verify_payload,
        headers=headers
    )
    assert verify_resp.status_code == 200
    v_data = verify_resp.json()["data"]
    assert v_data["verification_status"] == "VERIFIED"
    assert v_data["total_marks"] == 50.0

    # 5. Get Syllabus Topics
    topics_resp = await client.get(
        f"/api/v1/examinations/{exam_id}/papers/{paper_id}/syllabus-topics",
        params={"school_id": school_id},
        headers=headers
    )
    assert topics_resp.status_code == 200
    topics_list = topics_resp.json()["data"]
    assert len(topics_list) >= 2

    # 6. Get Marks Matrix
    matrix_resp = await client.get(
        f"/api/v1/examinations/{exam_id}/papers/{paper_id}/marks/question-wise",
        params={"school_id": school_id},
        headers=headers
    )
    assert matrix_resp.status_code == 200
    m_data = matrix_resp.json()["data"]
    assert len(m_data["rows"]) == 2
    assert len(m_data["questions"]) == 2

    new_q1_id = m_data["questions"][0]["id"]
    new_q2_id = m_data["questions"][1]["id"]

    # 7. Post Question-Wise Marks
    marks_submit_payload = {
        "is_draft": False,
        "rows": [
            {
                "student_id": str(data["student1"].id),
                "student_name": "Rohan Verma",
                "admission_number": "ADM-1",
                "question_marks": {
                    new_q1_id: 18.0,
                    new_q2_id: 25.0
                },
                "total_obtained": 43.0,
                "max_marks": 50.0,
                "is_complete": True,
                "result_status": "PRESENT"
            },
            {
                "student_id": str(data["student2"].id),
                "student_name": "Ananya Sen",
                "admission_number": "ADM-2",
                "question_marks": {
                    new_q1_id: 8.0,
                    new_q2_id: 12.0
                },
                "total_obtained": 20.0,
                "max_marks": 50.0,
                "is_complete": True,
                "result_status": "PRESENT"
            }
        ]
    }
    save_marks_resp = await client.post(
        f"/api/v1/examinations/{exam_id}/papers/{paper_id}/marks/question-wise",
        params={"school_id": school_id},
        json=marks_submit_payload,
        headers=headers
    )
    assert save_marks_resp.status_code == 200
    assert save_marks_resp.json()["data"]["total_students"] == 2

    # 8. Check Question-Wise Analytics
    analytics_resp = await client.get(
        f"/api/v1/examinations/{exam_id}/papers/{paper_id}/analytics",
        params={"school_id": school_id},
        headers=headers
    )
    assert analytics_resp.status_code == 200
    ana_data = analytics_resp.json()["data"]
    assert ana_data["has_question_data"] is True
    assert ana_data["data_sufficiency"] == "QUESTION_WISE_AVAILABLE"
    assert len(ana_data["question_analytics"]) == 2
    assert len(ana_data["topic_analytics"]) == 2
    assert ana_data["syllabus_coverage"]["mapped_topics_count"] == 2
