import uuid
import pytest
from datetime import date, datetime, timedelta, timezone
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tenant import Tenant
from app.models.school import School, SchoolBoard, SchoolStatus
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.class_entity import Class, ClassCategory
from app.models.section import Section
from app.models.subject import Subject, SubjectCategory, SubjectType, SubjectStatus
from app.models.teacher import Teacher, TeacherStatus, EmploymentType
from app.models.student import StudentGender
from app.models.teacher_subject_assignment import TeacherSubjectAssignment, AssignmentType, AssignmentStatus
from app.models.syllabus import Syllabus
from app.models.examination import Examination, ExamSchedule
from app.models.timetable import Timetable, TimetableStatus, PeriodType, DayOfWeek

from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.section import SectionRepository
from app.repositories.subject import SubjectRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.teacher_subject_assignment import TeacherSubjectAssignmentRepository
from app.repositories.syllabus import SyllabusRepository
from app.repositories.curriculum import CurriculumRepository

from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate
from app.schemas.academic_year import AcademicYearCreate
from app.schemas.class_entity import ClassCreate
from app.schemas.section import SectionCreate
from app.schemas.subject import SubjectCreate
from app.schemas.teacher import TeacherCreate
from app.schemas.teacher_subject_assignment import TeacherSubjectAssignmentCreate
from app.schemas.curriculum import CurriculumPopulateRequest
from app.schemas.academic_planning import (
    TimetableAIRecommendationRequest, TimetableGridValidationRequest, TimetableSlotValidation
)

from app.services.curriculum_engine import CurriculumEngine
from app.services.syllabus_prediction_engine import SyllabusPredictionEngine
from app.services.timetable_ai_engine import TimetableAIEngine
from app.repositories.timetable import TimetableRepository
from app.repositories.timetable_recommendation import TimetableRecommendationRepository
from app.repositories.syllabus_coverage import SyllabusCoverageRepository
from app.services.syllabus import SyllabusService

@pytest.fixture
async def academic_planning_fixture(db_session: AsyncSession):
    suffix = uuid.uuid4().hex[:6].lower()

    # 1. Tenants
    repo_t = TenantRepository(db_session)
    tenant_a = await repo_t.create(TenantCreate(name="Plan Tenant A", code=f"t-a-{suffix}", subdomain=f"t-a-{suffix}", email=f"a-{suffix}@t.com"))
    tenant_b = await repo_t.create(TenantCreate(name="Plan Tenant B", code=f"t-b-{suffix}", subdomain=f"t-b-{suffix}", email=f"b-{suffix}@t.com"))
    await db_session.commit()

    # 2. Schools
    repo_s = SchoolRepository(db_session)
    school_a = await repo_s.create(tenant_a.id, SchoolCreate(
        name="Apex Academy", code=f"APEX_{suffix.upper()}", address="1st Cross", city="Bangalore",
        state="Karnataka", country="India", pin_code="560001", board="CBSE", email=f"apex-{suffix}@a.com",
        status=SchoolStatus.ACTIVE
    ))
    school_b = await repo_s.create(tenant_b.id, SchoolCreate(
        name="Beacon High", code=f"BEAC_{suffix.upper()}", address="2nd Cross", city="Bangalore",
        state="Karnataka", country="India", pin_code="560001", board="ICSE", email=f"beac-{suffix}@b.com",
        status=SchoolStatus.ACTIVE
    ))
    await db_session.commit()

    # 3. Academic Years
    repo_ay = AcademicYearRepository(db_session)
    ay_a = await repo_ay.create(tenant_a.id, school_a.id, AcademicYearCreate(
        school_id=school_a.id, name="AY 2026-27", code="AY2026-2027", start_date=date(2026, 6, 1), end_date=date(2027, 4, 30),
        status=AcademicYearStatus.ACTIVE, is_current=True
    ))
    ay_a.status = AcademicYearStatus.ACTIVE

    ay_b = await repo_ay.create(tenant_b.id, school_b.id, AcademicYearCreate(
        school_id=school_b.id, name="AY 2026-27", code="AY2026-2027", start_date=date(2026, 6, 1), end_date=date(2027, 4, 30),
        status=AcademicYearStatus.ACTIVE, is_current=True
    ))
    ay_b.status = AcademicYearStatus.ACTIVE
    await db_session.commit()

    # 4. Classes & Sections
    repo_c = ClassRepository(db_session)
    class_10 = await repo_c.create(tenant_a.id, ClassCreate(
        school_id=school_a.id, academic_year_id=ay_a.id, name="Grade 10", code="G10", level=10, category=ClassCategory.HIGH, capacity=40
    ))
    await db_session.commit()

    repo_sec = SectionRepository(db_session)
    section_a = await repo_sec.create(tenant_a.id, SectionCreate(
        school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_10.id, name="Section A", code="SEC_A", room_number="Room 101", capacity=40
    ))
    await db_session.commit()

    # 5. Subjects
    repo_sub = SubjectRepository(db_session)
    math_sub = await repo_sub.create(tenant_a.id, SubjectCreate(
        school_id=school_a.id, academic_year_id=ay_a.id, subject_code=f"MATH10-{suffix.upper()}",
        subject_name="Mathematics", category=SubjectCategory.CORE, subject_type=SubjectType.THEORY
    ))
    math_sub.status = SubjectStatus.ACTIVE

    sci_sub = await repo_sub.create(tenant_a.id, SubjectCreate(
        school_id=school_a.id, academic_year_id=ay_a.id, subject_code=f"SCI10-{suffix.upper()}",
        subject_name="Science", category=SubjectCategory.CORE, subject_type=SubjectType.THEORY
    ))
    sci_sub.status = SubjectStatus.ACTIVE
    await db_session.commit()

    # 6. Teachers
    repo_tea = TeacherRepository(db_session)
    teacher_math = await repo_tea.create(tenant_a.id, TeacherCreate(
        school_id=school_a.id, employee_code=f"EMP-M-{suffix}", staff_code=f"STF-M-{suffix}",
        first_name="Ramanujan", last_name="Sharma", gender=StudentGender.MALE, date_of_birth=date(1985, 1, 1),
        mobile="+919876543210", official_email=f"math-{suffix}@apex.org",
        joining_date=date(2025, 1, 1), employment_type=EmploymentType.FULL_TIME
    ))
    teacher_math.status = TeacherStatus.ACTIVE

    teacher_sci = await repo_tea.create(tenant_a.id, TeacherCreate(
        school_id=school_a.id, employee_code=f"EMP-S-{suffix}", staff_code=f"STF-S-{suffix}",
        first_name="Curie", last_name="Patel", gender=StudentGender.FEMALE, date_of_birth=date(1988, 5, 15),
        mobile="+919876543211", official_email=f"sci-{suffix}@apex.org",
        joining_date=date(2025, 1, 1), employment_type=EmploymentType.FULL_TIME
    ))
    teacher_sci.status = TeacherStatus.ACTIVE
    await db_session.commit()

    # 7. Teacher Subject Assignments
    repo_tsa = TeacherSubjectAssignmentRepository(db_session)
    tsa_math = await repo_tsa.create(tenant_a.id, TeacherSubjectAssignmentCreate(
        school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_10.id, section_id=section_a.id,
        subject_id=math_sub.id, teacher_id=teacher_math.id, weekly_periods=6,
        assignment_type=AssignmentType.PRIMARY, effective_from=date(2026, 6, 1)
    ))
    tsa_sci = await repo_tsa.create(tenant_a.id, TeacherSubjectAssignmentCreate(
        school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_10.id, section_id=section_a.id,
        subject_id=sci_sub.id, teacher_id=teacher_sci.id, weekly_periods=5,
        assignment_type=AssignmentType.PRIMARY, effective_from=date(2026, 6, 1)
    ))
    await db_session.commit()

    # 8. Upcoming Examination
    from app.models.examination import ExamType, ExamStatus
    exam = Examination(
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        exam_name="Term 1 Midterm Exam",
        exam_type=ExamType.FINAL,
        start_date=date.today() + timedelta(days=20),
        end_date=date.today() + timedelta(days=30),
        status=ExamStatus.SCHEDULED,
        tenant_id=tenant_a.id
    )
    db_session.add(exam)
    await db_session.flush()

    sched = ExamSchedule(
        exam_id=exam.id,
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        class_id=class_10.id,
        section_id=section_a.id,
        subject_id=math_sub.id,
        teacher_subject_assignment_id=tsa_math.id,
        exam_date=date.today() + timedelta(days=22),
        start_time=datetime.now().time().replace(microsecond=0),
        end_time=(datetime.now() + timedelta(hours=2)).time().replace(microsecond=0),
        max_marks=100,
        pass_marks=35,
        tenant_id=tenant_a.id
    )
    db_session.add(sched)
    await db_session.commit()

    return {
        "tenant_a": tenant_a, "tenant_b": tenant_b,
        "school_a": school_a, "school_b": school_b,
        "ay_a": ay_a, "ay_b": ay_b,
        "class_10": class_10, "section_a": section_a,
        "math_sub": math_sub, "sci_sub": sci_sub,
        "teacher_math": teacher_math, "teacher_sci": teacher_sci,
        "tsa_math": tsa_math, "tsa_sci": tsa_sci,
        "exam": exam,
        "auth_headers": {
            "Authorization": "Bearer mock-token",
            "X-Tenant-ID": str(tenant_a.id)
        }
    }

@pytest.mark.anyio
async def test_curriculum_engine_population_and_fallback(db_session: AsyncSession, academic_planning_fixture):
    data = academic_planning_fixture
    curriculum_repo = CurriculumRepository(db_session)
    syllabus_repo = SyllabusRepository(db_session)
    engine = CurriculumEngine(db_session, curriculum_repo, syllabus_repo)

    # 1. Verified curriculum templates lookup
    templates = await engine.get_verified_templates(board="CBSE", class_level=10)
    assert len(templates) > 0
    math_template = next(t for t in templates if "Mathematics" in t.subject_name)
    assert len(math_template.items) == 13

    # 2. Populate school syllabus from verified board curriculum
    from app.models.user import User, UserStatus
    user = User(id=uuid.uuid4(), email="admin@apex.org", is_superuser=True, status=UserStatus.ACTIVE, tenant_id=data["tenant_a"].id)

    pop_req = CurriculumPopulateRequest(
        school_id=data["school_a"].id,
        academic_year_id=data["ay_a"].id,
        board="CBSE",
        class_ids=[data["class_10"].id]
    )
    res = await engine.populate_school_syllabus(data["tenant_a"].id, pop_req, user)
    assert res.success is True
    assert res.available is True
    assert res.cloned_count > 0

    # Verify topics are now in the school's isolated Syllabus table
    school_syll = await syllabus_repo.get_multi(
        school_id=data["school_a"].id,
        tenant_id=data["tenant_a"].id,
        academic_year_id=data["ay_a"].id,
        class_id=data["class_10"].id,
        subject_id=data["math_sub"].id
    )
    assert len(school_syll) == 13
    assert school_syll[0].lifecycle_status == "PLANNED"
    assert school_syll[0].estimated_periods > 0

    # 3. Test Fallback when verified curriculum is unavailable (e.g. unknown board)
    pop_req_unavailable = CurriculumPopulateRequest(
        school_id=data["school_a"].id,
        academic_year_id=data["ay_a"].id,
        board="UNKNOWN_BOARD_XYZ",
        class_ids=[data["class_10"].id]
    )
    res_unavail = await engine.populate_school_syllabus(data["tenant_a"].id, pop_req_unavailable, user)
    assert res_unavail.success is False
    assert res_unavail.available is False
    assert "Verified curriculum unavailable" in res_unavail.message
    assert res_unavail.details["can_import"] is True

    # 4. Multi-tenant School isolation: School B syllabus remains empty
    school_b_syll = await syllabus_repo.get_multi(
        school_id=data["school_b"].id,
        tenant_id=data["tenant_b"].id
    )
    assert len(school_b_syll) == 0

@pytest.mark.anyio
async def test_syllabus_hierarchy_editing_reordering_and_section_progress(db_session: AsyncSession, academic_planning_fixture):
    data = academic_planning_fixture
    syll_repo = SyllabusRepository(db_session)
    cov_repo = SyllabusCoverageRepository(db_session)
    service = SyllabusService(
        syllabus_repo=syll_repo,
        school_repo=SchoolRepository(db_session),
        academic_year_repo=AcademicYearRepository(db_session),
        class_repo=ClassRepository(db_session),
        subject_repo=SubjectRepository(db_session),
        coverage_repo=cov_repo
    )

    from app.models.user import User, UserStatus
    user = User(id=uuid.uuid4(), email="admin@apex.org", is_superuser=True, status=UserStatus.ACTIVE, tenant_id=data["tenant_a"].id)

    # 1. Create syllabus items
    from app.schemas.syllabus import SyllabusCreate, SyllabusReorderItem, SyllabusCoverageProgressUpdate
    s1 = await service.create_syllabus_entry(
        tenant_id=data["tenant_a"].id,
        school_id=data["school_a"].id,
        academic_year_id=data["ay_a"].id,
        obj_in=SyllabusCreate(
            class_id=data["class_10"].id,
            subject_id=data["math_sub"].id,
            syllabus_code=f"MATH_U1_{uuid.uuid4().hex[:4]}",
            unit_name="Unit 1: Algebra",
            chapter_name="Polynomials",
            topic_name="Introduction to Polynomials",
            sequence_order=1,
            estimated_periods=4
        ),
        current_user=user
    )
    s2 = await service.create_syllabus_entry(
        tenant_id=data["tenant_a"].id,
        school_id=data["school_a"].id,
        academic_year_id=data["ay_a"].id,
        obj_in=SyllabusCreate(
            class_id=data["class_10"].id,
            subject_id=data["math_sub"].id,
            syllabus_code=f"MATH_U2_{uuid.uuid4().hex[:4]}",
            unit_name="Unit 1: Algebra",
            chapter_name="Polynomials",
            topic_name="Roots of Polynomials",
            sequence_order=2,
            estimated_periods=6
        ),
        current_user=user
    )

    # 2. Reorder sequence
    reorder_count = await service.reorder_entries(
        tenant_id=data["tenant_a"].id,
        school_id=data["school_a"].id,
        items=[
            SyllabusReorderItem(id=s1.id, sequence_order=2),
            SyllabusReorderItem(id=s2.id, sequence_order=1)
        ],
        current_user=user
    )
    assert reorder_count == 2
    r1 = await syll_repo.get_by_id(s1.id, data["school_a"].id, data["tenant_a"].id)
    assert r1.sequence_order == 2

    # 3. Lifecycle Status transitions: PLANNED -> IN_PROGRESS -> COMPLETED -> REOPENED
    up1 = await service.update_lifecycle_status(data["tenant_a"].id, data["school_a"].id, s1.id, "IN_PROGRESS", user)
    assert up1.lifecycle_status == "IN_PROGRESS"
    assert up1.coverage_status == "ONGOING"

    up2 = await service.update_lifecycle_status(data["tenant_a"].id, data["school_a"].id, s1.id, "COMPLETED", user)
    assert up2.lifecycle_status == "COMPLETED"
    assert up2.coverage_status == "COMPLETED"
    assert up2.completed_at is not None

    up3 = await service.update_lifecycle_status(data["tenant_a"].id, data["school_a"].id, s1.id, "REOPENED", user)
    assert up3.lifecycle_status == "REOPENED"
    assert up3.completed_at is None

    # 4. Section-specific and teacher-specific progress tracking
    prog = await service.record_section_progress(
        tenant_id=data["tenant_a"].id,
        school_id=data["school_a"].id,
        academic_year_id=data["ay_a"].id,
        section_id=data["section_a"].id,
        syllabus_id=s1.id,
        obj_in=SyllabusCoverageProgressUpdate(
            status="COMPLETED",
            completion_percentage=100.0,
            completed_at=datetime.now(timezone.utc),
            remarks="Completed with problem sets."
        ),
        current_user=user,
        teacher_id=data["teacher_math"].id
    )
    assert prog.status == "COMPLETED"
    assert prog.completion_percentage == 100.0
    assert prog.teacher_id == data["teacher_math"].id
    assert prog.remarks == "Completed with problem sets."

@pytest.mark.anyio
async def test_timetable_ai_engine_and_constraint_validator(db_session: AsyncSession, academic_planning_fixture):
    data = academic_planning_fixture
    tt_repo = TimetableRepository(db_session)
    rec_repo = TimetableRecommendationRepository(db_session)
    engine = TimetableAIEngine(db_session, tt_repo, rec_repo)

    from app.models.user import User, UserStatus
    user = User(id=uuid.uuid4(), email="admin@apex.org", is_superuser=True, status=UserStatus.ACTIVE, tenant_id=data["tenant_a"].id)

    # 1. AI Recommendation Generation
    req = TimetableAIRecommendationRequest(
        school_id=data["school_a"].id,
        academic_year_id=data["ay_a"].id,
        class_id=data["class_10"].id,
        section_id=data["section_a"].id,
        periods_per_day=7,
        working_days=["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY"],
        lunch_period_number=4
    )
    rec_res = await engine.generate_recommendation(data["tenant_a"].id, req, user)
    assert rec_res.status == "SUGGESTED"
    assert len(rec_res.suggested_slots) > 0
    assert rec_res.can_publish is True

    # Check lunch break was properly placed
    lunch_slots = [s for s in rec_res.suggested_slots if s.period_number == 4]
    assert all(s.period_type == "BREAK" for s in lunch_slots)

    # 2. Strict Validation: Test detection of clash
    val_req = TimetableGridValidationRequest(
        school_id=data["school_a"].id,
        academic_year_id=data["ay_a"].id,
        class_id=data["class_10"].id,
        section_id=data["section_a"].id,
        slots=[
            TimetableSlotValidation(day_of_week="MONDAY", period_number=1, teacher_id=data["teacher_math"].id, subject_id=data["math_sub"].id),
            TimetableSlotValidation(day_of_week="MONDAY", period_number=1, teacher_id=data["teacher_sci"].id, subject_id=data["sci_sub"].id),  # Class clash
        ]
    )
    val_res = await engine.validate_grid(data["tenant_a"].id, val_req)
    assert val_res.has_conflict is True
    assert any(c.conflict_type == "CLASS_DOUBLE_BOOKING" for c in val_res.conflicts)

    # 3. Explicit Approval and Publication (Never silent!)
    published_count = await engine.approve_and_publish_recommendation(
        data["tenant_a"].id, data["school_a"].id, rec_res.recommendation_id, user
    )
    assert published_count > 0

    # Verify slots are now ACTIVE in timetables table
    active_slots = await tt_repo.get_section_schedule(
        class_id=data["class_10"].id,
        section_id=data["section_a"].id,
        academic_year_id=data["ay_a"].id,
        tenant_id=data["tenant_a"].id
    )
    assert len(active_slots) > 0
    assert all(s.status == TimetableStatus.ACTIVE for s in active_slots)

@pytest.mark.anyio
async def test_syllabus_prediction_engine_and_data_sufficiency_tiers(db_session: AsyncSession, academic_planning_fixture):
    data = academic_planning_fixture
    prediction_engine = SyllabusPredictionEngine(db_session)
    syll_repo = SyllabusRepository(db_session)
    cov_repo = SyllabusCoverageRepository(db_session)

    # --- Tier 1: No syllabus configured ---
    pred_no_syll = await prediction_engine.predict_subject_completion(
        school_id=data["school_a"].id,
        academic_year_id=data["ay_a"].id,
        class_id=data["class_10"].id,
        subject_id=data["sci_sub"].id
    )
    assert pred_no_syll.data_sufficiency == "NO_SYLLABUS"
    assert pred_no_syll.message == "No syllabus configured."
    assert pred_no_syll.projected_completion_date is None

    # Populate syllabus for Math
    curriculum_repo = CurriculumRepository(db_session)
    curriculum_engine = CurriculumEngine(db_session, curriculum_repo, syll_repo)
    from app.models.user import User, UserStatus
    user = User(id=uuid.uuid4(), email="admin@apex.org", is_superuser=True, status=UserStatus.ACTIVE, tenant_id=data["tenant_a"].id)
    await curriculum_engine.populate_school_syllabus(
        data["tenant_a"].id,
        CurriculumPopulateRequest(school_id=data["school_a"].id, academic_year_id=data["ay_a"].id, board="CBSE", class_ids=[data["class_10"].id]),
        user
    )

    # --- Tier 2: Waiting for teaching-progress data (syllabus exists, 0 completed) ---
    pred_waiting = await prediction_engine.predict_subject_completion(
        school_id=data["school_a"].id,
        academic_year_id=data["ay_a"].id,
        class_id=data["class_10"].id,
        subject_id=data["math_sub"].id
    )
    assert pred_waiting.data_sufficiency == "WAITING_FOR_PROGRESS"
    assert pred_waiting.message == "Waiting for teaching-progress data."
    assert pred_waiting.completion_percentage == 0.0
    assert pred_waiting.projected_completion_date is None

    # Log 1 completion -> Tier 3: Insufficient progress data (< 2 data points)
    math_topics = await syll_repo.get_multi(
        school_id=data["school_a"].id,
        tenant_id=data["tenant_a"].id,
        class_id=data["class_10"].id,
        subject_id=data["math_sub"].id
    )
    assert len(math_topics) >= 2

    await cov_repo.upsert_progress(
        tenant_id=data["tenant_a"].id,
        school_id=data["school_a"].id,
        academic_year_id=data["ay_a"].id,
        class_id=data["class_10"].id,
        section_id=data["section_a"].id,
        subject_id=data["math_sub"].id,
        syllabus_id=math_topics[0].id,
        status="COMPLETED",
        completion_percentage=100.0,
        user_id=user.id
    )
    await db_session.commit()

    pred_insufficient = await prediction_engine.predict_subject_completion(
        school_id=data["school_a"].id,
        academic_year_id=data["ay_a"].id,
        class_id=data["class_10"].id,
        subject_id=data["math_sub"].id,
        section_id=data["section_a"].id
    )
    assert pred_insufficient.data_sufficiency == "INSUFFICIENT_DATA"
    assert pred_insufficient.message == "Insufficient progress data for reliable completion prediction."
    assert pred_insufficient.projected_completion_date is None

    # Log 3 completions -> Sufficient data tier, calculates pace and projected date
    for i in range(1, 4):
        await cov_repo.upsert_progress(
            tenant_id=data["tenant_a"].id,
            school_id=data["school_a"].id,
            academic_year_id=data["ay_a"].id,
            class_id=data["class_10"].id,
            section_id=data["section_a"].id,
            subject_id=data["math_sub"].id,
            syllabus_id=math_topics[i].id,
            status="COMPLETED",
            completion_percentage=100.0,
            user_id=user.id
        )
    await db_session.commit()

    pred_sufficient = await prediction_engine.predict_subject_completion(
        school_id=data["school_a"].id,
        academic_year_id=data["ay_a"].id,
        class_id=data["class_10"].id,
        subject_id=data["math_sub"].id,
        section_id=data["section_a"].id
    )
    assert pred_sufficient.data_sufficiency == "SUFFICIENT"
    assert pred_sufficient.completed_topics == 4
    assert pred_sufficient.completion_percentage > 0.0
    assert pred_sufficient.projected_completion_date is not None
    assert pred_sufficient.target_exam_name == "Term 1 Midterm Exam"

    # School-wide summary and continuous adaptive recommendations
    summary = await prediction_engine.get_school_planning_summary(
        school_id=data["school_a"].id,
        academic_year_id=data["ay_a"].id,
        tenant_id=data["tenant_a"].id
    )
    assert summary.school_wide_completion_pct > 0.0
    assert len(summary.class_summaries) > 0
