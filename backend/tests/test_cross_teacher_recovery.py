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
from app.models.teacher_subject_assignment import TeacherSubjectAssignment, AssignmentType, AssignmentStatus
from app.models.timetable import Timetable, TimetableStatus, PeriodType, DayOfWeek
from app.models.examination import Examination, ExamSchedule, ExamType, ExamStatus
from app.models.syllabus import Syllabus
from app.models.syllabus_coverage import SyllabusCoverageProgress
from app.models.syllabus_recovery import SyllabusRecoveryPlan, RecoveryPlanItem
from app.models.teacher_leave import TeacherLeave, LeaveType, LeaveStatus
from app.models.academic_calendar import AcademicCalendarEvent, CalendarEventType, CalendarEventStatus
from app.models.notification import Notification, NotificationType, NotificationTargetRole
from app.models.user import User, UserStatus

from app.services.syllabus_prediction_engine import SyllabusPredictionEngine
from app.services.cross_teacher_recovery_service import CrossTeacherRecoveryService
from app.schemas.syllabus_recovery import (
    CrossTeacherApprovalRequest, CrossTeacherEditRequest, RecoveryPlanItemUpdate
)

from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.section import SectionRepository
from app.repositories.subject import SubjectRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.teacher_subject_assignment import TeacherSubjectAssignmentRepository

from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate
from app.schemas.academic_year import AcademicYearCreate
from app.schemas.class_entity import ClassCreate
from app.schemas.section import SectionCreate
from app.schemas.subject import SubjectCreate
from app.schemas.teacher import TeacherCreate
from app.schemas.teacher_subject_assignment import TeacherSubjectAssignmentCreate

pytestmark = pytest.mark.anyio


async def setup_cross_teacher_context(db_session, ay_code="2026-2027"):
    """
    Sets up acceptance scenario:
    Telangana Model School & Junior College
    AY 2026-2027
    Class 5A: Mathematics, Teacher A (Radha Sharma)
    Class 5B: Mathematics, Teacher B (Vikram Rao)
    Class 5C: Mathematics, Teacher C (Ananya Reddy)
    """
    suffix = uuid.uuid4().hex[:6].lower()
    repo_t = TenantRepository(db_session)
    tenant = await repo_t.create(TenantCreate(
        name=f"TMS Tenant {suffix}", code=f"t-{suffix}", subdomain=f"t-{suffix}", email=f"admin-{suffix}@tms.edu"
    ))
    await db_session.flush()

    repo_s = SchoolRepository(db_session)
    school = await repo_s.create(tenant.id, SchoolCreate(
        name=f"Telangana Model School & Junior College {suffix}", code=f"TMS_{suffix.upper()}",
        address="Nalgonda Road", city="Hyderabad", state="TELANGANA", country="India",
        pin_code="500001", board="STATE", email=f"tms-{suffix}@s.edu", status=SchoolStatus.ACTIVE
    ))
    school.settings = {"saturday_policy": "SECOND_FOURTH_OFF"}
    await db_session.flush()

    repo_ay = AcademicYearRepository(db_session)
    ay = await repo_ay.create(tenant.id, school.id, AcademicYearCreate(
        school_id=school.id, name=f"Academic Year {ay_code}", code=f"AY{ay_code}",
        start_date=date(2026, 6, 1), end_date=date(2027, 4, 30),
        status=AcademicYearStatus.ACTIVE, is_current=True
    ))
    ay.status = AcademicYearStatus.ACTIVE
    await db_session.flush()

    repo_c = ClassRepository(db_session)
    cls5 = await repo_c.create(tenant.id, ClassCreate(
        school_id=school.id, academic_year_id=ay.id, name="Class 5", code=f"C5_{suffix.upper()}",
        level=5, category=ClassCategory.PRIMARY, capacity=40
    ))
    await db_session.flush()

    repo_sec = SectionRepository(db_session)
    sec_a = await repo_sec.create(tenant.id, SectionCreate(
        school_id=school.id, academic_year_id=ay.id, class_id=cls5.id, name="A", code=f"S_5A_{suffix.upper()}",
        room_number="Room 101", capacity=40
    ))
    sec_b = await repo_sec.create(tenant.id, SectionCreate(
        school_id=school.id, academic_year_id=ay.id, class_id=cls5.id, name="B", code=f"S_5B_{suffix.upper()}",
        room_number="Room 102", capacity=40
    ))
    sec_c = await repo_sec.create(tenant.id, SectionCreate(
        school_id=school.id, academic_year_id=ay.id, class_id=cls5.id, name="C", code=f"S_5C_{suffix.upper()}",
        room_number="Room 103", capacity=40
    ))
    await db_session.flush()

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

    # Create Users and Teachers
    async def create_teacher_entity(first, last, code, max_weekly=30, qual="M.Sc Mathematics"):
        u = User(
            tenant_id=tenant.id, email=f"{first.lower()}_{suffix}@tms.edu",
            first_name=first, last_name=last, hashed_password="hashed_pw", status=UserStatus.ACTIVE
        )
        db_session.add(u)
        await db_session.flush()

        repo_tea = TeacherRepository(db_session)
        t = await repo_tea.create(tenant.id, TeacherCreate(
            school_id=school.id, employee_code=f"EMP_{code}_{suffix.upper()}", staff_code=f"STF_{code}_{suffix.upper()}",
            first_name=first, last_name=last, gender=StudentGender.FEMALE, date_of_birth=date(1988, 5, 10),
            mobile=f"+9198{abs(hash(code + suffix)) % 90000000:08d}", official_email=f"{first.lower()}_{suffix}@tms.edu",
            joining_date=date(2025, 6, 1), employment_type=EmploymentType.FULL_TIME
        ))
        t.status = TeacherStatus.ACTIVE
        t.user_id = u.id
        t.qualification = qual
        t.specialization = "Mathematics" if "Math" in qual else "Science"
        t.settings = {"max_weekly_periods": max_weekly, "max_daily_periods": 6}
        await db_session.flush()
        return t, u

    teacher_a, user_a = await create_teacher_entity("Radha", "Sharma", "TEA_A", max_weekly=30, qual="M.Sc Mathematics, B.Ed")
    teacher_b, user_b = await create_teacher_entity("Vikram", "Rao", "TEA_B", max_weekly=30, qual="M.Sc Mathematics")
    teacher_c, user_c = await create_teacher_entity("Ananya", "Reddy", "TEA_C", max_weekly=24, qual="B.Sc Mathematics, B.Ed")
    teacher_d_sci, user_d = await create_teacher_entity("Suresh", "Kumar", "TEA_D", max_weekly=30, qual="M.Sc Physics")

    # Teacher Assignments
    repo_tsa = TeacherSubjectAssignmentRepository(db_session)
    tsa_a = await repo_tsa.create(tenant.id, TeacherSubjectAssignmentCreate(
        school_id=school.id, academic_year_id=ay.id, class_id=cls5.id, section_id=sec_a.id,
        subject_id=subj_math.id, teacher_id=teacher_a.id, weekly_periods=5,
        assignment_type=AssignmentType.PRIMARY, effective_from=date(2026, 6, 1)
    ))
    tsa_b = await repo_tsa.create(tenant.id, TeacherSubjectAssignmentCreate(
        school_id=school.id, academic_year_id=ay.id, class_id=cls5.id, section_id=sec_b.id,
        subject_id=subj_math.id, teacher_id=teacher_b.id, weekly_periods=5,
        assignment_type=AssignmentType.PRIMARY, effective_from=date(2026, 6, 1)
    ))
    tsa_c = await repo_tsa.create(tenant.id, TeacherSubjectAssignmentCreate(
        school_id=school.id, academic_year_id=ay.id, class_id=cls5.id, section_id=sec_c.id,
        subject_id=subj_math.id, teacher_id=teacher_c.id, weekly_periods=5,
        assignment_type=AssignmentType.PRIMARY, effective_from=date(2026, 6, 1)
    ))
    tsa_d = await repo_tsa.create(tenant.id, TeacherSubjectAssignmentCreate(
        school_id=school.id, academic_year_id=ay.id, class_id=cls5.id, section_id=sec_b.id,
        subject_id=subj_sci.id, teacher_id=teacher_d_sci.id, weekly_periods=4,
        assignment_type=AssignmentType.PRIMARY, effective_from=date(2026, 6, 1)
    ))
    await db_session.flush()

    # Principal user
    user_principal = User(
        tenant_id=tenant.id, email=f"principal_{suffix}@tms.edu",
        first_name="Principal", last_name="Reddy", hashed_password="hashed_pw_test",
        is_superuser=True, status=UserStatus.ACTIVE
    )
    db_session.add(user_principal)
    await db_session.flush()

    # Seed 20 syllabus chapters/topics for Class 5 Mathematics
    syll_math_items = []
    chapters = [
        "Large Numbers", "Addition & Subtraction", "Multiplication & Division", "Factors & Multiples", "Fractions"
    ]
    for i in range(1, 21):
        ch_idx = (i - 1) // 4
        ch_name = chapters[ch_idx]
        syll = Syllabus(
            tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id, class_id=cls5.id,
            subject_id=subj_math.id, syllabus_code=f"C5_MTH_T{i}", unit_name="Arithmetic",
            chapter_name=ch_name, topic_name=f"{ch_name} - Part {((i-1)%4)+1}",
            sequence_order=i, estimated_periods=4, coverage_status="PENDING",
            lifecycle_status="PLANNED", is_active=True
        )
        db_session.add(syll)
        syll_math_items.append(syll)
    await db_session.flush()

    # Progress:
    # Class 5A (Teacher A): 20 / 20 completed (100% COMPLETE!)
    for i in range(20):
        cov_a = SyllabusCoverageProgress(
            tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id, class_id=cls5.id,
            section_id=sec_a.id, subject_id=subj_math.id, syllabus_id=syll_math_items[i].id,
            status="COMPLETED", completion_percentage=100.0,
            completed_at=datetime.now(timezone.utc) - timedelta(days=5)
        )
        db_session.add(cov_a)

    # Class 5B (Teacher B): 13 / 20 completed (65% AT_RISK!)
    for i in range(13):
        cov_b = SyllabusCoverageProgress(
            tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id, class_id=cls5.id,
            section_id=sec_b.id, subject_id=subj_math.id, syllabus_id=syll_math_items[i].id,
            status="COMPLETED", completion_percentage=100.0,
            completed_at=datetime.now(timezone.utc) - timedelta(days=2)
        )
        db_session.add(cov_b)

    # Class 5C (Teacher C): 19 / 20 completed (95% ON_TRACK!)
    for i in range(19):
        cov_c = SyllabusCoverageProgress(
            tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id, class_id=cls5.id,
            section_id=sec_c.id, subject_id=subj_math.id, syllabus_id=syll_math_items[i].id,
            status="COMPLETED", completion_percentage=100.0,
            completed_at=datetime.now(timezone.utc) - timedelta(days=3)
        )
        db_session.add(cov_c)

    await db_session.flush()

    # Setup Timetable entries:
    # Teacher A teaches 24 periods per week (available capacity = 30 - 24 = 6 periods)
    # Teacher C teaches 24 periods per week (configured max 24, available capacity = 0 periods!)
    for p in range(1, 5):
        for day in [DayOfWeek.MONDAY, DayOfWeek.TUESDAY, DayOfWeek.WEDNESDAY, DayOfWeek.THURSDAY, DayOfWeek.FRIDAY, DayOfWeek.SATURDAY]:
            # Teacher A slot for Class 5A
            tt_a = Timetable(
                tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id,
                class_id=cls5.id, section_id=sec_a.id, subject_id=subj_math.id,
                teacher_id=teacher_a.id, day_of_week=day, period_number=p,
                start_time=time(9 + p, 0), end_time=time(9 + p, 45),
                period_type=PeriodType.REGULAR, status=TimetableStatus.ACTIVE, is_active=True
            )
            db_session.add(tt_a)

            # Teacher C slot for Class 5C
            tt_c = Timetable(
                tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id,
                class_id=cls5.id, section_id=sec_c.id, subject_id=subj_math.id,
                teacher_id=teacher_c.id, day_of_week=day, period_number=p,
                start_time=time(9 + p, 0), end_time=time(9 + p, 45),
                period_type=PeriodType.REGULAR, status=TimetableStatus.ACTIVE, is_active=True
            )
            db_session.add(tt_c)

    await db_session.flush()

    return {
        "tenant": tenant,
        "school": school,
        "academic_year": ay,
        "class": cls5,
        "section_a": sec_a,
        "section_b": sec_b,
        "section_c": sec_c,
        "subject_math": subj_math,
        "subject_sci": subj_sci,
        "teacher_a": teacher_a,
        "teacher_b": teacher_b,
        "teacher_c": teacher_c,
        "teacher_d_sci": teacher_d_sci,
        "user_principal": user_principal,
        "user_a": user_a,
        "user_b": user_b,
        "syll_math_items": syll_math_items
    }


# =============================================================================
# 1. CORE ACCEPTANCE TEST: CLASS 5A (100%) -> CLASS 5B (65%) RECOMMENDATION
# =============================================================================
async def test_cross_teacher_acceptance_scenario_and_approval(db_session):
    """
    Scenario:
    Class 5A: Mathematics, Teacher A (20/20 completed = 100%)
    Class 5B: Mathematics, Teacher B (13/20 completed = 65%, AT_RISK)
    AI recommends: Teacher A take recovery period for Class 5B.
    Principal approves -> Timetable updated -> Prediction recalculated.
    """
    ctx = await setup_cross_teacher_context(db_session)
    service = CrossTeacherRecoveryService(db_session)

    # 1. Generate Cross-Teacher Recommendation
    rec = await service.generate_recovery_recommendation(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        class_id=ctx["class"].id,
        section_id=ctx["section_b"].id,
        subject_id=ctx["subject_math"].id,
        user_id=ctx["user_principal"].id
    )

    # Acceptance Assertions:
    assert rec.class_name == "Class 5"
    assert rec.section_name == "B"
    assert rec.subject_name == "Mathematics"
    assert rec.current_completion == 65.0
    assert rec.recommended_support_teacher_id == ctx["teacher_a"].id
    assert "Radha Sharma" in rec.recommended_support_teacher_name
    assert rec.primary_teacher_id == ctx["teacher_b"].id
    assert "Radha Sharma has completed the planned Mathematics syllabus" in rec.ai_recommendation_text
    assert rec.total_recovery_periods == 2
    assert rec.projected_improvement_days > 0
    assert len(rec.candidate_evaluations) >= 2
    assert rec.status == "PROPOSED"

    # Verify Timetable was NOT modified automatically (Strict Human-in-the-Loop!)
    tt_check = await db_session.execute(
        select(Timetable).where(
            Timetable.school_id == ctx["school"].id,
            Timetable.class_id == ctx["class"].id,
            Timetable.section_id == ctx["section_b"].id,
            Timetable.teacher_id == ctx["teacher_a"].id,
            Timetable.deleted_at.is_(None)
        )
    )
    assert len(tt_check.scalars().all()) == 0, "Timetable must NOT be modified before principal approval!"

    # 2. Principal reviews and APPROVES the recommendation
    approved_plan = await service.approve_recovery_plan(
        school_id=ctx["school"].id,
        plan_id=rec.plan_id,
        user_id=ctx["user_principal"].id
    )

    assert approved_plan.status == "APPROVED"
    assert approved_plan.approved_by == ctx["user_principal"].id
    assert approved_plan.support_teacher_id == ctx["teacher_a"].id
    # PRIMARY TEACHER REMAINS OWNER!
    assert approved_plan.primary_teacher_id == ctx["teacher_b"].id

    # Verify Timetable slots created with Support Teacher A and RECOVERY CLASS badge
    tt_after = await db_session.execute(
        select(Timetable).where(
            Timetable.school_id == ctx["school"].id,
            Timetable.class_id == ctx["class"].id,
            Timetable.section_id == ctx["section_b"].id,
            Timetable.teacher_id == ctx["teacher_a"].id,
            Timetable.status == TimetableStatus.ACTIVE,
            Timetable.deleted_at.is_(None)
        )
    )
    recovery_slots = tt_after.scalars().all()
    assert len(recovery_slots) == 2, "Expected 2 recovery timetable slots created for Support Teacher A"
    for slot in recovery_slots:
        assert slot.settings.get("is_recovery") is True
        assert slot.settings.get("label") == "RECOVERY CLASS"
        assert slot.settings.get("recovery_type") == "CROSS_TEACHER_RECOVERY"
        assert slot.settings.get("support_teacher_name") == "Radha Sharma"
        assert slot.settings.get("primary_teacher_name") == "Vikram Rao"

    # Verify Notifications dispatched:
    # Support Teacher A receives notification with RECOVERY CLASS
    notif_a_stmt = select(Notification).where(
        Notification.target_user_id == ctx["user_a"].id,
        Notification.related_record_id == rec.plan_id
    )
    res_na = await db_session.execute(notif_a_stmt)
    notif_a = res_na.scalars().first()
    assert notif_a is not None
    assert "RECOVERY CLASS" in notif_a.message

    # Primary Teacher B receives notification with SUPPORT TEACHER ASSIGNED
    notif_b_stmt = select(Notification).where(
        Notification.target_user_id == ctx["user_b"].id,
        Notification.related_record_id == rec.plan_id
    )
    res_nb = await db_session.execute(notif_b_stmt)
    notif_b = res_nb.scalars().first()
    assert notif_b is not None
    assert "SUPPORT TEACHER ASSIGNED: Radha Sharma" in notif_b.message
    assert "You remain the primary teacher" in notif_b.message


# =============================================================================
# 2. TEACHER CAPACITY CALCULATION & WORKLOAD SAFETY
# =============================================================================
async def test_teacher_capacity_calculation_and_workload_safety(db_session):
    """
    Teacher A has max 30, scheduled 24 -> available = 6 periods (has_capacity = True).
    Teacher C has max 24, scheduled 24 -> available = 0 periods (has_capacity = False).
    System must NOT recommend Teacher C for additional recovery periods.
    """
    ctx = await setup_cross_teacher_context(db_session)
    service = CrossTeacherRecoveryService(db_session)

    # Teacher A capacity
    cap_a = await service.calculate_teacher_capacity(ctx["school"].id, ctx["academic_year"].id, ctx["teacher_a"].id)
    assert cap_a.max_weekly_periods == 30
    assert cap_a.current_weekly_periods == 24
    assert cap_a.available_capacity == 6
    assert cap_a.has_capacity is True

    # Teacher C capacity (At configured workload limit)
    cap_c = await service.calculate_teacher_capacity(ctx["school"].id, ctx["academic_year"].id, ctx["teacher_c"].id)
    assert cap_c.max_weekly_periods == 24
    assert cap_c.current_weekly_periods == 24
    assert cap_c.available_capacity == 0
    assert cap_c.has_capacity is False
    assert "has no available configured teaching capacity" in cap_c.status_note

    # Candidate evaluation surfaces Teacher C as NO_CAPACITY
    candidates = await service.find_eligible_candidates_for_recovery(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        target_class_id=ctx["class"].id,
        target_section_id=ctx["section_b"].id,
        target_subject_id=ctx["subject_math"].id
    )
    eval_c = next((c for c in candidates if c.teacher_id == ctx["teacher_c"].id), None)
    assert eval_c is not None
    assert eval_c.eligibility_status == "NO_CAPACITY"
    assert eval_c.has_capacity is False


# =============================================================================
# 3. SUBJECT COMPATIBILITY (DEFAULT: STRICT SAME SUBJECT)
# =============================================================================
async def test_subject_compatibility_no_automatic_cross_subject(db_session):
    """
    AI must NOT automatically assign Science teacher (Teacher D) to teach Mathematics.
    Teacher D must not be included as a Mathematics recovery teacher.
    """
    ctx = await setup_cross_teacher_context(db_session)
    service = CrossTeacherRecoveryService(db_session)

    candidates = await service.find_eligible_candidates_for_recovery(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        target_class_id=ctx["class"].id,
        target_section_id=ctx["section_b"].id,
        target_subject_id=ctx["subject_math"].id
    )
    sci_candidate = next((c for c in candidates if c.teacher_id == ctx["teacher_d_sci"].id), None)
    assert sci_candidate is None, "Science teacher must NOT be assigned to Mathematics without explicit configuration!"


# =============================================================================
# 4. HOLIDAY, EXAM & TEACHER LEAVE CONFLICT EVALUATION
# =============================================================================
async def test_leave_holiday_and_exam_conflict_evaluation(db_session):
    """
    1. Approved teacher leave blocks candidate teacher from being recommended on those dates.
    2. Approved school holiday blocks recovery periods on that date.
    3. Exam schedule blocks recovery periods on that date.
    """
    ctx = await setup_cross_teacher_context(db_session)
    service = CrossTeacherRecoveryService(db_session)

    target_date = date.today() + timedelta(days=2)

    # 1. Teacher Leave: Teacher A takes leave on target_date
    leave = TeacherLeave(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        teacher_id=ctx["teacher_a"].id,
        leave_type=LeaveType.CASUAL,
        start_date=target_date,
        end_date=target_date,
        reason="Family function",
        status=LeaveStatus.APPROVED
    )
    db_session.add(leave)

    # 2. Approved Holiday on target_date + 1
    holiday = AcademicCalendarEvent(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        title="State Festival",
        event_type=CalendarEventType.SCHOOL_HOLIDAY,
        event_date=target_date + timedelta(days=1),
        is_non_working_day=True,
        status=CalendarEventStatus.APPROVED
    )
    db_session.add(holiday)

    # 3. Scheduled Examination on target_date + 2
    exam = Examination(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        exam_name="Mid-Term Exams",
        exam_type=ExamType.UNIT_TEST,
        start_date=target_date + timedelta(days=2),
        end_date=target_date + timedelta(days=5),
        status=ExamStatus.SCHEDULED
    )
    db_session.add(exam)
    await db_session.flush()

    exam_sc = ExamSchedule(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        exam_id=exam.id,
        class_id=ctx["class"].id,
        section_id=ctx["section_b"].id,
        subject_id=ctx["subject_math"].id,
        exam_date=target_date + timedelta(days=2),
        start_time=time(9, 30),
        end_time=time(12, 30),
        max_marks=100
    )
    db_session.add(exam_sc)
    await db_session.flush()

    # Search free slots
    slots = await service._find_compatible_free_slots(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        candidate_teacher_id=ctx["teacher_a"].id,
        target_class_id=ctx["class"].id,
        target_section_id=ctx["section_b"].id
    )

    slot_dates = {s["date"] for s in slots}
    assert target_date.isoformat() not in slot_dates, "Slots must not fall on approved teacher leave date!"
    assert (target_date + timedelta(days=1)).isoformat() not in slot_dates, "Slots must not fall on approved holiday!"
    assert (target_date + timedelta(days=2)).isoformat() not in slot_dates, "Slots must not fall on examination date!"


# =============================================================================
# 5. PRINCIPAL REJECTION AND EDIT WORKFLOWS
# =============================================================================
async def test_principal_rejection_and_edit_workflows(db_session):
    """
    Principal can:
    1. Reject recommendation with remarks (timetable stays 100% untouched).
    2. Edit recommendation (duration, periods/week, notes).
    """
    ctx = await setup_cross_teacher_context(db_session)
    service = CrossTeacherRecoveryService(db_session)

    rec = await service.generate_recovery_recommendation(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        class_id=ctx["class"].id,
        section_id=ctx["section_b"].id,
        subject_id=ctx["subject_math"].id,
        user_id=ctx["user_principal"].id
    )

    # 1. Edit Plan: Increase duration to 3 weeks
    edited_plan = await service.edit_recovery_plan(
        school_id=ctx["school"].id,
        plan_id=rec.plan_id,
        edit_req=CrossTeacherEditRequest(
            duration_weeks=3,
            recommended_periods_per_week=1,
            parent_notes="Mathematics syllabus acceleration"
        ),
        user_id=ctx["user_principal"].id
    )
    assert edited_plan.status == "EDITED"
    assert edited_plan.duration_weeks == 3
    assert edited_plan.parent_notes == "Mathematics syllabus acceleration"

    # 2. Reject Plan
    rejected_plan = await service.reject_recovery_plan(
        school_id=ctx["school"].id,
        plan_id=rec.plan_id,
        remarks="Will cover via homework and self-study instead.",
        user_id=ctx["user_principal"].id
    )
    assert rejected_plan.status == "REJECTED"
    assert rejected_plan.rejection_remarks == "Will cover via homework and self-study instead."

    # Timetable must have ZERO recovery slots
    tt_check = await db_session.execute(
        select(Timetable).where(
            Timetable.school_id == ctx["school"].id,
            Timetable.class_id == ctx["class"].id,
            Timetable.section_id == ctx["section_b"].id,
            Timetable.teacher_id == ctx["teacher_a"].id,
            Timetable.deleted_at.is_(None)
        )
    )
    assert len(tt_check.scalars().all()) == 0


# =============================================================================
# 6. CANCELLATION WORKFLOW (TIMETABLE ROLLBACK & RECALCULATION)
# =============================================================================
async def test_recovery_cancellation_and_rollback(db_session):
    """
    If an approved plan is later cancelled:
    1. Recovery timetable slots are safely deactivated.
    2. Prediction resets back to original baseline.
    3. Status transitions to CANCELLED.
    """
    ctx = await setup_cross_teacher_context(db_session)
    service = CrossTeacherRecoveryService(db_session)

    rec = await service.generate_recovery_recommendation(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        class_id=ctx["class"].id,
        section_id=ctx["section_b"].id,
        subject_id=ctx["subject_math"].id,
        user_id=ctx["user_principal"].id
    )
    await service.approve_recovery_plan(ctx["school"].id, rec.plan_id, user_id=ctx["user_principal"].id)

    # Cancel Plan
    cancelled_plan = await service.cancel_recovery_plan(
        school_id=ctx["school"].id,
        plan_id=rec.plan_id,
        reason="Teacher B recovered missed chapters ahead of time.",
        user_id=ctx["user_principal"].id
    )
    assert cancelled_plan.status == "CANCELLED"

    # Active recovery slots should now be 0
    tt_after_cancel = await db_session.execute(
        select(Timetable).where(
            Timetable.school_id == ctx["school"].id,
            Timetable.class_id == ctx["class"].id,
            Timetable.section_id == ctx["section_b"].id,
            Timetable.teacher_id == ctx["teacher_a"].id,
            Timetable.status == TimetableStatus.ACTIVE,
            Timetable.deleted_at.is_(None)
        )
    )
    assert len(tt_after_cancel.scalars().all()) == 0


# =============================================================================
# 7. RECOVERY ANALYTICS (NORMAL VS RECOVERY VS CROSS-TEACHER VS ABSENCE)
# =============================================================================
async def test_recovery_analytics_breakdown(db_session):
    """
    Analytics must distinguish:
    1. Normal teaching periods
    2. Recovery teaching periods
    3. Cross-teacher support periods
    4. Teacher absence recovery periods
    """
    ctx = await setup_cross_teacher_context(db_session)
    service = CrossTeacherRecoveryService(db_session)

    rec = await service.generate_recovery_recommendation(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        class_id=ctx["class"].id,
        section_id=ctx["section_b"].id,
        subject_id=ctx["subject_math"].id,
        user_id=ctx["user_principal"].id
    )
    await service.approve_recovery_plan(ctx["school"].id, rec.plan_id, user_id=ctx["user_principal"].id)

    analytics = await service.get_recovery_analytics(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id
    )

    assert analytics.recovery_periods == 2
    assert analytics.cross_teacher_support_periods == 2
    assert analytics.approved_recovery_plans_count == 1
    assert analytics.normal_periods > 0
    assert len(analytics.class_breakdown) > 0
    assert len(analytics.subject_breakdown) > 0
