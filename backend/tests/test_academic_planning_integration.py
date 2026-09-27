import uuid
import pytest
from datetime import date, time, timedelta, datetime, timezone
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tenant import Tenant
from app.models.school import School, SchoolBoard, SchoolType, SchoolStatus
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.class_entity import Class, ClassCategory
from app.models.section import Section
from app.models.subject import Subject, SubjectCategory, SubjectType, SubjectStatus
from app.models.teacher import Teacher, TeacherStatus, EmploymentType
from app.models.student import StudentGender
from app.models.teacher_subject_assignment import TeacherSubjectAssignment, AssignmentType
from app.models.timetable import Timetable, TimetableStatus, PeriodType, DayOfWeek
from app.models.examination import Examination, ExamSchedule, ExamType, ExamStatus
from app.models.syllabus import Syllabus
from app.models.academic_calendar import AcademicCalendarEvent, CalendarEventType, CalendarEventStatus
from app.models.user import User, UserStatus

from app.services.academic_calendar import AcademicCalendarService
from app.services.timetable_ai_engine import TimetableAIEngine
from app.services.syllabus_prediction_engine import SyllabusPredictionEngine
from app.repositories.timetable import TimetableRepository
from app.repositories.timetable_recommendation import TimetableRecommendationRepository
from app.repositories.syllabus_recovery import SyllabusRecoveryRepository
from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.section import SectionRepository
from app.repositories.subject import SubjectRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.teacher_subject_assignment import TeacherSubjectAssignmentRepository
from app.repositories.syllabus import SyllabusRepository

from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate
from app.schemas.academic_year import AcademicYearCreate
from app.schemas.class_entity import ClassCreate
from app.schemas.section import SectionCreate
from app.schemas.subject import SubjectCreate
from app.schemas.teacher import TeacherCreate
from app.schemas.teacher_subject_assignment import TeacherSubjectAssignmentCreate
from app.schemas.syllabus import SyllabusCreate
from app.schemas.academic_planning import TimetableAIRecommendationRequest
from app.schemas.syllabus_recovery import RecoveryValidationItem


async def setup_planning_integration_context(db_session: AsyncSession):
    suffix = uuid.uuid4().hex[:6].lower()

    # Tenant
    repo_t = TenantRepository(db_session)
    tenant = await repo_t.create(TenantCreate(
        name=f"Integration Tenant {suffix}", code=f"t-{suffix}", subdomain=f"t-{suffix}", email=f"admin-{suffix}@t.com"
    ))
    await db_session.flush()

    # School
    repo_s = SchoolRepository(db_session)
    school = await repo_s.create(tenant.id, SchoolCreate(
        name=f"TMS School {suffix}", code=f"TMS_{suffix.upper()}", address="Road 10", city="Hyderabad",
        state="TELANGANA", country="India", pin_code="500001", board="STATE", email=f"tms-{suffix}@s.com",
        status=SchoolStatus.ACTIVE
    ))
    school.settings = {"saturday_policy": "SECOND_FOURTH_OFF", "daily_periods": 6}
    await db_session.flush()

    # Academic Year
    repo_ay = AcademicYearRepository(db_session)
    ay = await repo_ay.create(tenant.id, school.id, AcademicYearCreate(
        school_id=school.id, name="2026-2027", code="AY2026-2027",
        start_date=date(2026, 6, 1), end_date=date(2027, 4, 30),
        status=AcademicYearStatus.ACTIVE, is_current=True
    ))
    ay.status = AcademicYearStatus.ACTIVE
    await db_session.flush()

    # Class 10
    repo_c = ClassRepository(db_session)
    cls = await repo_c.create(tenant.id, ClassCreate(
        school_id=school.id, academic_year_id=ay.id, name="Class 10", code=f"C10_{suffix.upper()}",
        level=10, category=ClassCategory.HIGH, capacity=40
    ))
    await db_session.flush()

    # Sections A & B
    repo_sec = SectionRepository(db_session)
    sec_a = await repo_sec.create(tenant.id, SectionCreate(
        school_id=school.id, academic_year_id=ay.id, class_id=cls.id, name="Section A", code=f"S10A_{suffix.upper()}",
        room_number="Room 101", capacity=40
    ))
    sec_b = await repo_sec.create(tenant.id, SectionCreate(
        school_id=school.id, academic_year_id=ay.id, class_id=cls.id, name="Section B", code=f"S10B_{suffix.upper()}",
        room_number="Room 102", capacity=40
    ))
    await db_session.flush()

    # Subjects: Mathematics & Science
    repo_sub = SubjectRepository(db_session)
    subj_math = await repo_sub.create(tenant.id, SubjectCreate(
        school_id=school.id, academic_year_id=ay.id, subject_code=f"MTH_{suffix.upper()}",
        subject_name="Mathematics", category=SubjectCategory.CORE, subject_type=SubjectType.THEORY
    ))
    subj_math.status = SubjectStatus.ACTIVE

    subj_sci = await repo_sub.create(tenant.id, SubjectCreate(
        school_id=school.id, academic_year_id=ay.id, subject_code=f"SCI_{suffix.upper()}",
        subject_name="Science", category=SubjectCategory.CORE, subject_type=SubjectType.THEORY
    ))
    subj_sci.status = SubjectStatus.ACTIVE
    await db_session.flush()

    # Teachers
    repo_tea = TeacherRepository(db_session)
    teacher_a = await repo_tea.create(tenant.id, TeacherCreate(
        school_id=school.id, employee_code=f"EMP_A_{suffix.upper()}", staff_code=f"STF_A_{suffix.upper()}",
        first_name="Radha", last_name="Sharma", gender=StudentGender.FEMALE, date_of_birth=date(1986, 5, 10),
        mobile="+919876500001", official_email=f"radha_{suffix}@school.edu",
        joining_date=date(2025, 1, 1), employment_type=EmploymentType.FULL_TIME
    ))
    teacher_a.status = TeacherStatus.ACTIVE

    teacher_b = await repo_tea.create(tenant.id, TeacherCreate(
        school_id=school.id, employee_code=f"EMP_B_{suffix.upper()}", staff_code=f"STF_B_{suffix.upper()}",
        first_name="Ramesh", last_name="Verma", gender=StudentGender.MALE, date_of_birth=date(1984, 8, 20),
        mobile="+919876500002", official_email=f"ramesh_{suffix}@school.edu",
        joining_date=date(2025, 1, 1), employment_type=EmploymentType.FULL_TIME
    ))
    teacher_b.status = TeacherStatus.ACTIVE
    await db_session.flush()

    # Assignments
    repo_tsa = TeacherSubjectAssignmentRepository(db_session)
    tsa_math = await repo_tsa.create(tenant.id, TeacherSubjectAssignmentCreate(
        school_id=school.id, academic_year_id=ay.id, class_id=cls.id, section_id=sec_a.id,
        subject_id=subj_math.id, teacher_id=teacher_a.id, weekly_periods=5,
        assignment_type=AssignmentType.PRIMARY, effective_from=date(2026, 6, 1)
    ))
    tsa_sci = await repo_tsa.create(tenant.id, TeacherSubjectAssignmentCreate(
        school_id=school.id, academic_year_id=ay.id, class_id=cls.id, section_id=sec_a.id,
        subject_id=subj_sci.id, teacher_id=teacher_b.id, weekly_periods=5,
        assignment_type=AssignmentType.PRIMARY, effective_from=date(2026, 6, 1)
    ))
    await db_session.flush()

    # User
    user = User(
        tenant_id=tenant.id,
        email=f"admin_{suffix}@school.edu",
        first_name="Principal",
        last_name="Test",
        hashed_password="hashed_pw_test",
        is_superuser=True,
        status=UserStatus.ACTIVE
    )
    db_session.add(user)
    await db_session.flush()

    # Syllabus units for Math
    repo_syl = SyllabusRepository(db_session)
    await repo_syl.create(
        tenant.id, school.id, ay.id,
        SyllabusCreate(
            class_id=cls.id,
            subject_id=subj_math.id,
            syllabus_code=f"SYL-M1-{suffix}",
            unit_name="Unit 1",
            chapter_name="Number Systems",
            topic_name="Real Numbers",
            sequence_order=1,
            estimated_periods=6
        )
    )
    await repo_syl.create(
        tenant.id, school.id, ay.id,
        SyllabusCreate(
            class_id=cls.id,
            subject_id=subj_math.id,
            syllabus_code=f"SYL-M2-{suffix}",
            unit_name="Unit 2",
            chapter_name="Algebra",
            topic_name="Polynomials",
            sequence_order=2,
            estimated_periods=8
        )
    )
    await db_session.flush()

    # Upcoming exam
    exam = Examination(
        tenant_id=tenant.id,
        school_id=school.id,
        academic_year_id=ay.id,
        exam_name="Quarterly Examinations 2026",
        exam_type=ExamType.QUARTERLY,
        start_date=date(2026, 10, 15),
        end_date=date(2026, 10, 25),
        status=ExamStatus.SCHEDULED
    )
    db_session.add(exam)
    await db_session.flush()

    sched = ExamSchedule(
        tenant_id=tenant.id,
        school_id=school.id,
        academic_year_id=ay.id,
        exam_id=exam.id,
        class_id=cls.id,
        section_id=sec_a.id,
        subject_id=subj_math.id,
        exam_date=date(2026, 10, 18),
        start_time=time(9, 30),
        end_time=time(12, 30),
        max_marks=100,
        pass_marks=35
    )
    db_session.add(sched)
    await db_session.flush()

    return {
        "tenant": tenant,
        "school": school,
        "academic_year": ay,
        "class": cls,
        "section_a": sec_a,
        "section_b": sec_b,
        "subject_math": subj_math,
        "subject_sci": subj_sci,
        "teacher_a": teacher_a,
        "teacher_b": teacher_b,
        "user": user,
        "exam": exam,
        "exam_schedule": sched
    }


# =============================================================================
# TEST 1: SCHOOL PLANNING SUMMARY & DATA-SUFFICIENCY TIER
# =============================================================================
@pytest.mark.anyio
async def test_school_planning_summary_integration(db_session: AsyncSession):
    ctx = await setup_planning_integration_context(db_session)
    engine = SyllabusPredictionEngine(db_session)

    summary = await engine.get_school_planning_summary(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        tenant_id=ctx["tenant"].id
    )

    assert summary.school_id == ctx["school"].id
    assert summary.academic_year_id == ctx["academic_year"].id
    assert len(summary.class_summaries) >= 1
    assert summary.total_subjects_tracked >= 1
    assert summary.upcoming_exams_count >= 1
    assert 0.0 <= summary.school_wide_completion_pct <= 100.0


# =============================================================================
# TEST 2: ACADEMIC HEATMAP MATRIX GENERATION
# =============================================================================
@pytest.mark.anyio
async def test_academic_heatmap_matrix_integration(db_session: AsyncSession):
    ctx = await setup_planning_integration_context(db_session)
    engine = SyllabusPredictionEngine(db_session)

    heatmap = await engine.get_academic_heatmap(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id
    )

    assert heatmap.school_id == ctx["school"].id
    assert heatmap.academic_year_id == ctx["academic_year"].id
    assert len(heatmap.classes) >= 1
    assert len(heatmap.subjects) >= 2
    assert len(heatmap.cells) > 0

    valid_statuses = {"AHEAD", "ON_TRACK", "BEHIND", "CRITICAL", "NO_PROGRESS", "NO_DATA", "DELAYED", "AT_RISK"}
    for cell in heatmap.cells:
        assert cell.status in valid_statuses
        assert 0.0 <= cell.completion_percentage <= 100.0


# =============================================================================
# TEST 3: TIMETABLE AI ENGINE GENERATE, APPROVE & IDEMPOTENT UPSERT
# =============================================================================
@pytest.mark.anyio
async def test_timetable_ai_generation_and_publish_upsert(db_session: AsyncSession):
    ctx = await setup_planning_integration_context(db_session)
    tt_repo = TimetableRepository(db_session)
    rec_repo = TimetableRecommendationRepository(db_session)
    engine = TimetableAIEngine(db_session, tt_repo, rec_repo)

    # 1. Generate AI recommendation
    req = TimetableAIRecommendationRequest(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        class_id=ctx["class"].id,
        section_id=ctx["section_a"].id,
        periods_per_day=6,
        working_days=["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]
    )
    rec = await engine.generate_recommendation(
        tenant_id=ctx["tenant"].id,
        req=req,
        current_user=ctx["user"]
    )

    assert rec is not None
    assert len(rec.suggested_slots) > 0
    assert rec.status == "SUGGESTED"

    # 2. Approve and publish recommendation
    published_count = await engine.approve_and_publish_recommendation(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        recommendation_id=rec.recommendation_id,
        current_user=ctx["user"]
    )

    assert published_count > 0

    # Verify active slots in DB
    slots = await tt_repo.get_section_schedule(
        class_id=ctx["class"].id,
        section_id=ctx["section_a"].id,
        academic_year_id=ctx["academic_year"].id,
        tenant_id=ctx["tenant"].id
    )
    assert len(slots) == published_count

    # 3. Test idempotent re-publish / upsert (must NOT violate uq_timetables_class_slot)
    rec2 = await engine.generate_recommendation(
        tenant_id=ctx["tenant"].id,
        req=req,
        current_user=ctx["user"]
    )
    published_count2 = await engine.approve_and_publish_recommendation(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        recommendation_id=rec2.recommendation_id,
        current_user=ctx["user"]
    )
    assert published_count2 > 0

    slots_after = await tt_repo.get_section_schedule(
        class_id=ctx["class"].id,
        section_id=ctx["section_a"].id,
        academic_year_id=ctx["academic_year"].id,
        tenant_id=ctx["tenant"].id
    )
    assert len(slots_after) == published_count2


# =============================================================================
# TEST 4: HOLIDAY & TEACHER ABSENCE IMPACT INTELLIGENCE
# =============================================================================
@pytest.mark.anyio
async def test_holiday_and_teacher_absence_impact(db_session: AsyncSession):
    ctx = await setup_planning_integration_context(db_session)
    tt_repo = TimetableRepository(db_session)
    rec_repo = TimetableRecommendationRepository(db_session)
    ai_engine = TimetableAIEngine(db_session, tt_repo, rec_repo)
    pred_engine = SyllabusPredictionEngine(db_session)

    # First populate timetable slots so we have scheduled periods
    req = TimetableAIRecommendationRequest(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        class_id=ctx["class"].id,
        section_id=ctx["section_a"].id,
        periods_per_day=6
    )
    rec = await ai_engine.generate_recommendation(
        tenant_id=ctx["tenant"].id,
        req=req,
        current_user=ctx["user"]
    )
    await ai_engine.approve_and_publish_recommendation(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        recommendation_id=rec.recommendation_id,
        current_user=ctx["user"]
    )

    # 1. Test Holiday Impact Analysis on a Monday
    monday_date = date(2026, 9, 28)
    holiday_impact = await ai_engine.analyze_holiday_impact(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        holiday_date=monday_date
    )

    assert holiday_impact["affected_periods_count"] > 0
    assert holiday_impact["affected_classes_count"] >= 1
    assert holiday_impact["affected_teachers_count"] >= 1

    # 2. Test Teacher Absence Impact Analysis
    absence_impact = await pred_engine.analyze_teacher_absence_impact(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        teacher_id=ctx["teacher_a"].id,
        absence_date=monday_date
    )

    assert absence_impact.teacher_id == ctx["teacher_a"].id
    assert absence_impact.absence_date == monday_date
    assert absence_impact.total_missed_periods > 0
    assert len(absence_impact.affected_classes) >= 1
    assert absence_impact.recommended_action is not None


# =============================================================================
# TEST 5: 4-PHASE SYLLABUS RECOVERY PLAN GENERATION & CONFLICT VALIDATION
# =============================================================================
@pytest.mark.anyio
async def test_recovery_plan_generation_and_validation(db_session: AsyncSession):
    ctx = await setup_planning_integration_context(db_session)
    engine = SyllabusPredictionEngine(db_session)

    # Generate 4-Phase Recovery Plan
    plan = await engine.generate_syllabus_recovery_plan(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        class_id=ctx["class"].id,
        section_id=ctx["section_a"].id,
        subject_id=ctx["subject_math"].id,
        reason="Accelerated Term 1 exam syllabus coverage",
        target_completion_date=date(2026, 10, 15),
        created_by=ctx["user"].id
    )

    assert plan.id is not None
    assert plan.status in ["DRAFT", "PROPOSED", "PENDING_APPROVAL", "SUGGESTED"]
    assert len(plan.items) >= 4

    phases = {item.phase for item in plan.items}
    # Verify phases match 4-phase pedagogy
    assert any("CATCHUP" in p or "CATCH_UP" in p for p in phases)
    assert any("CORE" in p for p in phases)
    assert any("PRACTICE" in p for p in phases)
    assert any("BUFFER" in p for p in phases)

    # Validate proposed candidate slots
    candidate_items = [
        RecoveryValidationItem(
            date=item.date,
            period_number=item.period_number,
            class_id=ctx["class"].id,
            section_id=ctx["section_a"].id,
            teacher_id=item.teacher_id,
            room_id=item.room_id,
            topic_name=item.topic_name
        )
        for item in plan.items
    ]

    val_res = await engine.validate_recovery_plan(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        items=candidate_items
    )

    assert val_res.is_valid in [True, False]
    assert isinstance(val_res.total_conflicts, int)
    assert len(val_res.results) == len(candidate_items)
