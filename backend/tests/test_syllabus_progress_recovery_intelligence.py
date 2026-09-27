import uuid
import pytest
from datetime import date, time, timedelta, datetime, timezone
from sqlalchemy import select

from app.models.tenant import Tenant
from app.models.school import School, SchoolStatus
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.class_entity import Class, ClassCategory
from app.models.section import Section
from app.models.subject import Subject, SubjectCategory, SubjectType, SubjectStatus
from app.models.teacher import Teacher, TeacherStatus, EmploymentType
from app.models.student import Student, StudentGender, StudentStatus
from app.models.teacher_subject_assignment import TeacherSubjectAssignment, AssignmentType
from app.models.timetable import Timetable, TimetableStatus, PeriodType, DayOfWeek
from app.models.examination import Examination, ExamSchedule, ExamType, ExamStatus
from app.models.syllabus import Syllabus
from app.models.syllabus_coverage import SyllabusCoverageProgress
from app.models.academic_calendar import AcademicCalendarEvent, CalendarEventType, CalendarEventStatus
from app.models.syllabus_recovery import SyllabusRecoveryPlan, RecoveryPlanItem
from app.models.notification import Notification, NotificationType, NotificationTargetRole
from app.models.user import User, UserStatus
from app.services.syllabus_prediction_engine import SyllabusPredictionEngine
from app.services.academic_calendar import AcademicCalendarService
from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.section import SectionRepository
from app.repositories.subject import SubjectRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.teacher_subject_assignment import TeacherSubjectAssignmentRepository
from app.repositories.syllabus_recovery import SyllabusRecoveryRepository
from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate
from app.schemas.academic_year import AcademicYearCreate
from app.schemas.class_entity import ClassCreate
from app.schemas.section import SectionCreate
from app.schemas.subject import SubjectCreate
from app.schemas.teacher import TeacherCreate
from app.schemas.teacher_subject_assignment import TeacherSubjectAssignmentCreate
from app.schemas.syllabus_recovery import RecoveryPlanItemUpdate, RecoveryValidationItem

pytestmark = pytest.mark.anyio


async def setup_test_context(db_session, state="TELANGANA", ay_code="2026-2027"):
    suffix = uuid.uuid4().hex[:6].lower()
    repo_t = TenantRepository(db_session)
    tenant = await repo_t.create(TenantCreate(
        name=f"TMS Tenant {suffix}", code=f"t-{suffix}", subdomain=f"t-{suffix}", email=f"a-{suffix}@tms.edu"
    ))
    await db_session.flush()

    repo_s = SchoolRepository(db_session)
    school = await repo_s.create(tenant.id, SchoolCreate(
        name=f"Telangana Model School {suffix}", code=f"TMS_{suffix.upper()}", address="Main Road", city="Hyderabad",
        state=state, country="India", pin_code="500001", board="STATE", email=f"tms-{suffix}@s.edu",
        status=SchoolStatus.ACTIVE
    ))
    school.settings = {"saturday_policy": "SECOND_FOURTH_OFF"}
    await db_session.flush()

    repo_ay = AcademicYearRepository(db_session)
    ay = await repo_ay.create(tenant.id, school.id, AcademicYearCreate(
        school_id=school.id, name=f"AY {ay_code}", code=f"AY{ay_code}",
        start_date=date(2026, 6, 1), end_date=date(2027, 4, 30),
        status=AcademicYearStatus.ACTIVE, is_current=True
    ))
    ay.status = AcademicYearStatus.ACTIVE
    await db_session.flush()

    repo_c = ClassRepository(db_session)
    cls = await repo_c.create(tenant.id, ClassCreate(
        school_id=school.id, academic_year_id=ay.id, name="Class 5", code=f"C5_{suffix.upper()}",
        level=5, category=ClassCategory.PRIMARY, capacity=40
    ))
    await db_session.flush()

    repo_sec = SectionRepository(db_session)
    sec = await repo_sec.create(tenant.id, SectionCreate(
        school_id=school.id, academic_year_id=ay.id, class_id=cls.id, name="A", code=f"S_A_{suffix.upper()}",
        room_number="Room 101", capacity=40
    ))
    await db_session.flush()

    repo_sub = SubjectRepository(db_session)
    subj = await repo_sub.create(tenant.id, SubjectCreate(
        school_id=school.id, academic_year_id=ay.id, subject_code=f"MTH_{suffix.upper()}",
        subject_name="Mathematics", category=SubjectCategory.CORE, subject_type=SubjectType.THEORY
    ))
    subj.status = SubjectStatus.ACTIVE
    await db_session.flush()

    user_teacher = User(
        tenant_id=tenant.id,
        email=f"radha_{suffix}@tms.edu",
        first_name="Radha",
        last_name="Sharma",
        hashed_password="hashed_password",
        status=UserStatus.ACTIVE
    )
    db_session.add(user_teacher)
    await db_session.flush()

    repo_tea = TeacherRepository(db_session)
    teacher = await repo_tea.create(tenant.id, TeacherCreate(
        school_id=school.id, employee_code=f"EMP_{suffix.upper()}", staff_code=f"STF_{suffix.upper()}",
        first_name="Radha", last_name="Sharma", gender=StudentGender.FEMALE, date_of_birth=date(1988, 5, 10),
        mobile="+919876543210", official_email=f"radha_{suffix}@tms.edu",
        joining_date=date(2025, 6, 1), employment_type=EmploymentType.FULL_TIME
    ))
    teacher.status = TeacherStatus.ACTIVE
    teacher.user_id = user_teacher.id
    await db_session.flush()

    repo_tsa = TeacherSubjectAssignmentRepository(db_session)
    tsa = await repo_tsa.create(tenant.id, TeacherSubjectAssignmentCreate(
        school_id=school.id, academic_year_id=ay.id, class_id=cls.id, section_id=sec.id,
        subject_id=subj.id, teacher_id=teacher.id, weekly_periods=5,
        assignment_type=AssignmentType.PRIMARY, effective_from=date(2026, 6, 1)
    ))
    await db_session.flush()

    student = Student(
        tenant_id=tenant.id,
        school_id=school.id,
        admission_number=f"ADM_{suffix.upper()}",
        roll_number="15",
        first_name="Aarav",
        last_name="Kumar",
        gender=StudentGender.MALE,
        date_of_birth=date(2015, 8, 14),
        class_id=cls.id,
        section_id=sec.id,
        academic_year_id=ay.id,
        admission_date=date(2026, 6, 1),
        status=StudentStatus.ACTIVE
    )
    db_session.add(student)
    await db_session.flush()

    user_principal = User(
        tenant_id=tenant.id,
        email=f"principal_{suffix}@tms.edu",
        first_name="Principal",
        last_name="Reddy",
        hashed_password="hashed_pw_test",
        is_superuser=True,
        status=UserStatus.ACTIVE
    )
    db_session.add(user_principal)
    await db_session.flush()

    # Seed 20 syllabus topics for Class 5A Mathematics
    syll_items = []
    chapters = ["Large Numbers", "Addition & Subtraction", "Multiplication & Division", "Fractions", "Decimals"]
    for i in range(1, 21):
        ch_idx = (i - 1) // 4
        ch_name = chapters[ch_idx]
        syll = Syllabus(
            tenant_id=tenant.id,
            school_id=school.id,
            academic_year_id=ay.id,
            class_id=cls.id,
            subject_id=subj.id,
            syllabus_code=f"C5_MTH_T{i}",
            unit_name="Arithmetic",
            chapter_name=ch_name,
            topic_name=f"{ch_name} - Subtopic {((i-1)%4)+1}",
            sequence_order=i,
            estimated_periods=4,
            coverage_status="PENDING",
            lifecycle_status="PLANNED",
            is_active=True
        )
        db_session.add(syll)
        syll_items.append(syll)
    await db_session.flush()

    return {
        "tenant": tenant,
        "school": school,
        "academic_year": ay,
        "class": cls,
        "section": sec,
        "subject": subj,
        "teacher": teacher,
        "student": student,
        "principal": user_principal,
        "syll_items": syll_items,
        "tsa": tsa
    }


async def test_syllabus_progress_lifecycle_and_pace_update(db_session):
    ctx = await setup_test_context(db_session)
    engine = SyllabusPredictionEngine(db_session)

    # 1. Initially mark 12 of 20 topics as COMPLETED (12/20 = 60.0%)
    for i in range(12):
        item = ctx["syll_items"][i]
        cov = SyllabusCoverageProgress(
            tenant_id=ctx["tenant"].id,
            school_id=ctx["school"].id,
            academic_year_id=ctx["academic_year"].id,
            class_id=ctx["class"].id,
            section_id=ctx["section"].id,
            subject_id=ctx["subject"].id,
            syllabus_id=item.id,
            status="COMPLETED",
            completion_percentage=100.0,
            completed_at=datetime.now(timezone.utc) - timedelta(days=2)
        )
        db_session.add(cov)
    await db_session.flush()

    pred_initial = await engine.predict_subject_completion(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        class_id=ctx["class"].id,
        subject_id=ctx["subject"].id,
        section_id=ctx["section"].id
    )
    assert pred_initial.total_topics == 20
    assert pred_initial.completed_topics == 12
    assert pred_initial.completion_percentage == 60.0

    # 2. Teacher completes topic 13 (Fractions -> Comparing Fractions)
    topic_13 = ctx["syll_items"][12]
    cov_13 = SyllabusCoverageProgress(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        class_id=ctx["class"].id,
        section_id=ctx["section"].id,
        subject_id=ctx["subject"].id,
        syllabus_id=topic_13.id,
        status="COMPLETED",
        completion_percentage=100.0,
        completed_at=datetime.now(timezone.utc)
    )
    db_session.add(cov_13)
    await db_session.flush()

    pred_updated = await engine.predict_subject_completion(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        class_id=ctx["class"].id,
        subject_id=ctx["subject"].id,
        section_id=ctx["section"].id
    )
    assert pred_updated.completed_topics == 13
    assert pred_updated.completion_percentage == 65.0
    assert pred_updated.data_sufficiency == "SUFFICIENT"


async def test_teacher_absence_impact_analysis(db_session):
    ctx = await setup_test_context(db_session)
    engine = SyllabusPredictionEngine(db_session)

    # Setup timetable for Radha: Wednesday Period 3
    # Use a future Wednesday
    today = date.today()
    days_ahead = (2 - today.weekday()) % 7  # 2 is Wednesday
    if days_ahead == 0:
        days_ahead = 7
    wednesday_dt = today + timedelta(days=days_ahead)

    tt_slot = Timetable(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        class_id=ctx["class"].id,
        section_id=ctx["section"].id,
        subject_id=ctx["subject"].id,
        teacher_id=ctx["teacher"].id,
        day_of_week=DayOfWeek.WEDNESDAY,
        period_number=3,
        start_time=time(10, 30),
        end_time=time(11, 15),
        period_type=PeriodType.REGULAR,
        status=TimetableStatus.ACTIVE,
        is_active=True
    )
    db_session.add(tt_slot)
    await db_session.flush()

    # Analyze absence impact
    impact = await engine.analyze_teacher_absence_impact(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        teacher_id=ctx["teacher"].id,
        absence_date=wednesday_dt
    )

    assert impact.total_missed_periods == 1
    assert len(impact.affected_periods) == 1
    assert impact.affected_periods[0].period_number == 3
    assert impact.affected_periods[0].class_id == ctx["class"].id
    assert impact.affected_periods[0].subject_id == ctx["subject"].id
    assert "Large Numbers" in impact.affected_periods[0].topic_name
    assert len(impact.affected_classes) == 1
    assert impact.affected_classes[0].missed_periods_count == 1
    assert impact.estimated_recovery_periods_needed == 1


async def test_recovery_plan_generation_and_phase_breakdown(db_session):
    ctx = await setup_test_context(db_session)
    engine = SyllabusPredictionEngine(db_session)

    plan = await engine.generate_syllabus_recovery_plan(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        class_id=ctx["class"].id,
        section_id=ctx["section"].id,
        subject_id=ctx["subject"].id,
        reason="Teacher medical leave - missed fractions instruction",
        created_by=ctx["principal"].id
    )

    assert plan.status == "SUGGESTED"
    assert plan.class_id == ctx["class"].id
    assert plan.section_id == ctx["section"].id
    assert plan.subject_id == ctx["subject"].id
    assert len(plan.items) == 4

    phases = [it.phase for it in plan.items]
    assert "PHASE_1_CATCHUP" in phases
    assert "PHASE_2_CORE" in phases
    assert "PHASE_3_PRACTICE" in phases
    assert "PHASE_4_BUFFER" in phases

    # Verify candidate dates are in future and conflict status is checked
    for it in plan.items:
        assert it.date > date.today()
        assert it.duration_minutes == 45
        assert it.conflict_status in ("NO_CONFLICT", "CONFLICT_DETECTED")


async def test_conflict_validation_holiday_and_clash(db_session):
    ctx = await setup_test_context(db_session)
    engine = SyllabusPredictionEngine(db_session)

    # 1. Declare an approved holiday on next Friday
    friday = date.today() + timedelta(days=((4 - date.today().weekday()) % 7 or 7))
    holiday = AcademicCalendarEvent(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        event_date=friday,
        event_type=CalendarEventType.PUBLIC_HOLIDAY,
        title="State Festival Holiday",
        is_non_working_day=True,
        status=CalendarEventStatus.APPROVED
    )
    db_session.add(holiday)
    await db_session.flush()

    # 2. Schedule teacher in another class on Monday Period 2
    monday = date.today() + timedelta(days=((0 - date.today().weekday()) % 7 or 7))
    repo_c = ClassRepository(db_session)
    cls_other = await repo_c.create(ctx["tenant"].id, ClassCreate(
        school_id=ctx["school"].id, academic_year_id=ctx["academic_year"].id, name="Class 6", code=f"C6_{uuid.uuid4().hex[:4].upper()}",
        level=6, category=ClassCategory.MIDDLE, capacity=40
    ))
    await db_session.flush()
    repo_sec = SectionRepository(db_session)
    sec_other = await repo_sec.create(ctx["tenant"].id, SectionCreate(
        school_id=ctx["school"].id, academic_year_id=ctx["academic_year"].id, class_id=cls_other.id, name="B", code=f"S_B_{uuid.uuid4().hex[:4].upper()}",
        capacity=40
    ))
    await db_session.flush()

    tt_clash = Timetable(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        class_id=cls_other.id,
        section_id=sec_other.id,
        subject_id=ctx["subject"].id,
        teacher_id=ctx["teacher"].id,
        day_of_week=DayOfWeek.MONDAY,
        period_number=2,
        start_time=time(9, 30),
        end_time=time(10, 15),
        period_type=PeriodType.REGULAR,
        status=TimetableStatus.ACTIVE,
        is_active=True
    )
    db_session.add(tt_clash)
    await db_session.flush()

    # Propose 3 validation items:
    # Item 0: Propose on Friday holiday -> HOLIDAY_COLLISION
    # Item 1: Propose on Monday Period 2 -> TEACHER_CLASH
    # Item 2: Propose on Thursday Period 8 (clear slot) -> NO_CONFLICT
    thursday = date.today() + timedelta(days=((3 - date.today().weekday()) % 7 or 7))

    validation_items = [
        RecoveryValidationItem(
            date=friday,
            period_number=1,
            teacher_id=ctx["teacher"].id,
            class_id=ctx["class"].id,
            section_id=ctx["section"].id,
            topic_name="Fractions Holiday Test"
        ),
        RecoveryValidationItem(
            date=monday,
            period_number=2,
            teacher_id=ctx["teacher"].id,
            class_id=ctx["class"].id,
            section_id=ctx["section"].id,
            topic_name="Fractions Clash Test"
        ),
        RecoveryValidationItem(
            date=thursday,
            period_number=8,
            teacher_id=ctx["teacher"].id,
            class_id=ctx["class"].id,
            section_id=ctx["section"].id,
            topic_name="Fractions Clear Test"
        )
    ]

    val_res = await engine.validate_recovery_plan(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        items=validation_items
    )

    assert val_res.is_valid is False
    assert val_res.total_conflicts == 2

    # Item 0: Holiday
    assert val_res.results[0].has_conflict is True
    assert val_res.results[0].conflict_type == "HOLIDAY_COLLISION"

    # Item 1: Teacher Clash
    assert val_res.results[1].has_conflict is True
    assert val_res.results[1].conflict_type == "TEACHER_CLASH"

    # Item 2: Clear
    assert val_res.results[2].has_conflict is False
    assert val_res.results[2].conflict_type == "NO_CONFLICT"


async def test_slot_edit_and_approval_workflow(db_session):
    ctx = await setup_test_context(db_session)
    engine = SyllabusPredictionEngine(db_session)

    # 1. Generate plan
    plan = await engine.generate_syllabus_recovery_plan(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        class_id=ctx["class"].id,
        section_id=ctx["section"].id,
        subject_id=ctx["subject"].id,
        reason="Missed periods recovery",
        created_by=ctx["principal"].id
    )
    first_item = plan.items[0]

    # 2. Edit first slot to Period 8 on next working day
    thursday = date.today() + timedelta(days=((3 - date.today().weekday()) % 7 or 7))
    update_data = RecoveryPlanItemUpdate(
        date=thursday,
        period_number=8,
        topic_name="Fractions - Intensive Problem Solving"
    )
    updated_item = await engine.update_recovery_plan_item(
        school_id=ctx["school"].id,
        plan_id=plan.id,
        item_id=first_item.id,
        update_data=update_data,
        user_id=ctx["principal"].id
    )

    assert updated_item.period_number == 8
    assert updated_item.topic_name == "Fractions - Intensive Problem Solving"
    assert updated_item.status == "MODIFIED"
    assert updated_item.conflict_status == "NO_CONFLICT"

    # 3. Partial regeneration
    regenerated_plan = await engine.regenerate_recovery_plan(
        school_id=ctx["school"].id,
        plan_id=plan.id,
        user_id=ctx["principal"].id
    )
    # Modified item should be preserved
    preserved = [it for it in regenerated_plan.items if it.id == first_item.id]
    assert len(preserved) == 1
    assert preserved[0].status == "MODIFIED"

    # 4. Approve recovery plan
    approved_plan = await engine.approve_recovery_plan(
        school_id=ctx["school"].id,
        plan_id=plan.id,
        user_id=ctx["principal"].id
    )
    assert approved_plan.status == "APPROVED"
    assert approved_plan.approved_by == ctx["principal"].id
    assert all(it.is_approved is True for it in approved_plan.items)

    # 5. Verify teacher notification dispatched
    notif_stmt = select(Notification).where(
        Notification.school_id == ctx["school"].id,
        Notification.target_role == NotificationTargetRole.TEACHER,
        Notification.target_user_id == ctx["teacher"].user_id
    )
    res_notif = await db_session.execute(notif_stmt)
    notifications = list(res_notif.scalars().all())
    assert len(notifications) >= 1
    assert "Academic Schedule Updated" in notifications[0].title


async def test_sanitized_student_parent_progress_view(db_session):
    ctx = await setup_test_context(db_session)
    engine = SyllabusPredictionEngine(db_session)

    # Complete 10 topics
    for i in range(10):
        item = ctx["syll_items"][i]
        cov = SyllabusCoverageProgress(
            tenant_id=ctx["tenant"].id,
            school_id=ctx["school"].id,
            academic_year_id=ctx["academic_year"].id,
            class_id=ctx["class"].id,
            section_id=ctx["section"].id,
            subject_id=ctx["subject"].id,
            syllabus_id=item.id,
            status="COMPLETED",
            completion_percentage=100.0,
            completed_at=datetime.now(timezone.utc)
        )
        db_session.add(cov)

    # Mark topic 11 IN_PROGRESS
    cov_11 = SyllabusCoverageProgress(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        class_id=ctx["class"].id,
        section_id=ctx["section"].id,
        subject_id=ctx["subject"].id,
        syllabus_id=ctx["syll_items"][10].id,
        status="IN_PROGRESS",
        completion_percentage=40.0
    )
    db_session.add(cov_11)
    await db_session.flush()

    progress = await engine.get_student_syllabus_progress(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        student_id=ctx["student"].id
    )

    assert progress.student_name == "Aarav Kumar"
    assert progress.class_name == "Class 5"
    assert progress.section_name == "A"
    assert len(progress.subjects) >= 1

    math_sub = next(s for s in progress.subjects if s.subject_id == ctx["subject"].id)
    assert math_sub.total_topics == 20
    assert math_sub.completed_topics == 10
    assert math_sub.in_progress_topics == 1
    assert math_sub.completion_percentage == 50.0

    # Verify topic states
    completed_topics = [t for t in math_sub.topics if t.status == "COMPLETED"]
    in_progress_topics = [t for t in math_sub.topics if t.status == "IN_PROGRESS"]
    upcoming_topics = [t for t in math_sub.topics if t.status == "UPCOMING"]

    assert len(completed_topics) == 10
    assert len(in_progress_topics) == 1
    assert len(upcoming_topics) == 9

    # Strict Zero-Leakage: serialize response to dict and verify NO internal staff notes/absence mentions
    dumped = progress.model_dump()
    dumped_str = str(dumped).lower()
    assert "leave" not in dumped_str
    assert "medical" not in dumped_str
    assert "deficit" not in dumped_str
    assert "staff evaluation" not in dumped_str


async def test_academic_heatmap_matrix(db_session):
    ctx = await setup_test_context(db_session)
    engine = SyllabusPredictionEngine(db_session)

    heatmap = await engine.get_academic_heatmap(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id
    )

    assert len(heatmap.classes) >= 1
    assert len(heatmap.subjects) >= 1
    assert len(heatmap.cells) >= 1
    assert "total_cells" in heatmap.summary
    assert "on_track" in heatmap.summary

    cell = heatmap.cells[0]
    assert cell.class_id == ctx["class"].id
    assert cell.section_id == ctx["section"].id
    assert cell.subject_id == ctx["subject"].id
    assert cell.status in ("NO_PROGRESS", "ON_TRACK", "AT_RISK", "DELAYED", "AHEAD")
