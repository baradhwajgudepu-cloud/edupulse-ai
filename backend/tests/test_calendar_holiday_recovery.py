import uuid
import pytest
from datetime import date, time, timedelta, datetime, timezone
from httpx import AsyncClient
from sqlalchemy import select, and_

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
from app.models.state_holiday_master import StateHolidayMaster
from app.models.user import User, UserStatus
from app.services.academic_calendar import AcademicCalendarService
from app.services.timetable_ai_engine import TimetableAIEngine
from app.services.syllabus_prediction_engine import SyllabusPredictionEngine
from app.repositories.timetable import TimetableRepository
from app.repositories.timetable_recommendation import TimetableRecommendationRepository
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

async def setup_test_context(db_session, state="TELANGANA", ay_code="2026-2027"):
    suffix = uuid.uuid4().hex[:6].lower()
    repo_t = TenantRepository(db_session)
    tenant = await repo_t.create(TenantCreate(
        name=f"Plan Tenant {suffix}", code=f"t-{suffix}", subdomain=f"t-{suffix}", email=f"a-{suffix}@t.com"
    ))
    await db_session.flush()

    repo_s = SchoolRepository(db_session)
    school = await repo_s.create(tenant.id, SchoolCreate(
        name=f"School {suffix}", code=f"SCH_{suffix.upper()}", address="Road 1", city="Hyderabad",
        state=state, country="India", pin_code="500001", board="STATE", email=f"sch-{suffix}@s.com",
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
        level=5, category=ClassCategory.MIDDLE, capacity=40
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

    repo_tea = TeacherRepository(db_session)
    teacher = await repo_tea.create(tenant.id, TeacherCreate(
        school_id=school.id, employee_code=f"EMP_{suffix.upper()}", staff_code=f"STF_{suffix.upper()}",
        first_name="Radha", last_name="Sharma", gender=StudentGender.FEMALE, date_of_birth=date(1986, 5, 10),
        mobile="+919876500000", official_email=f"radha_{suffix}@school.edu",
        joining_date=date(2025, 1, 1), employment_type=EmploymentType.FULL_TIME
    ))
    teacher.status = TeacherStatus.ACTIVE
    await db_session.flush()

    repo_tsa = TeacherSubjectAssignmentRepository(db_session)
    tsa = await repo_tsa.create(tenant.id, TeacherSubjectAssignmentCreate(
        school_id=school.id, academic_year_id=ay.id, class_id=cls.id, section_id=sec.id,
        subject_id=subj.id, teacher_id=teacher.id, weekly_periods=5,
        assignment_type=AssignmentType.PRIMARY, effective_from=date(2026, 6, 1)
    ))
    await db_session.flush()

    user = User(
        tenant_id=tenant.id,
        email=f"principal_{suffix}@school.edu",
        first_name="Principal",
        last_name="Sharma",
        hashed_password="hashed_pw_test",
        is_superuser=True,
        status=UserStatus.ACTIVE
    )
    db_session.add(user)
    await db_session.flush()

    return {
        "tenant": tenant,
        "school": school,
        "academic_year": ay,
        "class": cls,
        "section": sec,
        "subject": subj,
        "teacher": teacher,
        "tsa": tsa,
        "user": user,
        "ay_code": ay_code
    }


# ==============================================================
# TEST 1: STATE PUBLIC HOLIDAY POPULATION (VERIFIED)
# ==============================================================
@pytest.mark.anyio
async def test_state_public_holiday_population_verified(db_session):
    ctx = await setup_test_context(db_session, state="TELANGANA", ay_code="2026-2027")
    cal_service = AcademicCalendarService(db_session)

    res = await cal_service.populate_state_holidays(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        state="TELANGANA",
        academic_year_code="2026-2027",
        created_by=ctx["user"].id
    )

    assert res["success"] is True
    assert res["is_verified"] is True
    assert res["count"] > 0
    assert "Government of Telangana" in res["source"]
    assert "G.O.Rt.No. 2026/V1" in res["source_version"]

    # Verify DB records
    events = await cal_service.calendar_repo.get_events(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        event_types=[CalendarEventType.PUBLIC_HOLIDAY]
    )
    assert len(events) == res["count"]
    for e in events:
        assert e.event_type == CalendarEventType.PUBLIC_HOLIDAY
        assert e.is_non_working_day is True
        assert e.status == CalendarEventStatus.APPROVED


# ==============================================================
# TEST 2: UNVERIFIED STATE CALENDAR DOES NOT FABRICATE DATA
# ==============================================================
@pytest.mark.anyio
async def test_state_public_holiday_source_version_and_unverified_handling(db_session):
    ctx = await setup_test_context(db_session, state="SIKKIM", ay_code="2035-2036")
    cal_service = AcademicCalendarService(db_session)

    # Check status
    status_res = await cal_service.get_state_holiday_status(state="SIKKIM", academic_year_code="2035-2036")
    assert status_res.is_verified is False
    assert status_res.message == "Public holiday calendar could not be verified."
    assert status_res.can_import is True

    # Attempt populate
    pop_res = await cal_service.populate_state_holidays(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        state="SIKKIM",
        academic_year_code="2035-2036"
    )
    assert pop_res["success"] is False
    assert pop_res["count"] == 0

    # Ensure no holidays were fabricated in DB
    events = await cal_service.calendar_repo.get_events(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id
    )
    assert len(events) == 0


# ==============================================================
# TEST 3: SCHOOL HOLIDAY CREATION & ISOLATION FROM GLOBAL MASTER
# ==============================================================
@pytest.mark.anyio
async def test_school_holiday_creation_and_isolation(db_session):
    ctx = await setup_test_context(db_session)
    cal_service = AcademicCalendarService(db_session)

    # Count global state holiday master entries before
    stmt_master = select(StateHolidayMaster)
    master_before = len((await db_session.execute(stmt_master)).scalars().all())

    # Add school holiday
    school_h = await cal_service.create_school_holiday(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        event_date=date(2026, 10, 12),
        title="School Foundation Day",
        description="Annual campus sports and foundation celebrations.",
        created_by=ctx["user"].id
    )
    assert school_h.event_type == CalendarEventType.SCHOOL_HOLIDAY
    assert school_h.is_non_working_day is True
    assert school_h.status == CalendarEventStatus.APPROVED

    # Verify global state holiday master was NOT mutated
    master_after = len((await db_session.execute(stmt_master)).scalars().all())
    assert master_before == master_after


# ==============================================================
# TEST 4: PRINCIPAL DECLARED HOLIDAY FLOW
# ==============================================================
@pytest.mark.anyio
async def test_principal_declared_holiday_flow(db_session):
    ctx = await setup_test_context(db_session)
    cal_service = AcademicCalendarService(db_session)

    p_holiday = await cal_service.declare_principal_holiday(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        event_date=date(2026, 10, 14),
        title="Emergency Rain Closure",
        reason="Heavy waterlogging reported near campus.",
        auto_approve=True,
        created_by=ctx["user"].id
    )
    assert p_holiday.event_type == CalendarEventType.PRINCIPAL_DECLARED_HOLIDAY
    assert p_holiday.status == CalendarEventStatus.APPROVED
    assert p_holiday.is_non_working_day is True
    assert p_holiday.approved_by == ctx["user"].id


# ==============================================================
# TEST 5: UNIFIED WORKING-DAY CALCULATION EXCLUDING HOLIDAYS
# ==============================================================
@pytest.mark.anyio
async def test_unified_working_day_calculation_excluding_holidays(db_session):
    ctx = await setup_test_context(db_session)
    cal_service = AcademicCalendarService(db_session)

    # Populate public holidays
    await cal_service.populate_state_holidays(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        state="TELANGANA",
        academic_year_code="2026-2027"
    )
    # Add school holiday on 2026-10-12
    await cal_service.create_school_holiday(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        event_date=date(2026, 10, 12),
        title="Local Festival Day"
    )

    # Calculate for October 2026 (2026-10-01 to 2026-10-31)
    calc = await cal_service.calculate_working_days(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        start_date=date(2026, 10, 1),
        end_date=date(2026, 10, 31)
    )

    # In Oct 2026:
    # 2026-10-02: Gandhi Jayanti (Public Holiday) -> non-working
    # 2026-10-12: Local Festival (School Holiday) -> non-working
    # 2026-10-20: Dussehra (Public Holiday) -> non-working
    assert date(2026, 10, 2) not in calc.working_dates
    assert date(2026, 10, 12) not in calc.working_dates
    assert date(2026, 10, 20) not in calc.working_dates
    assert calc.total_working_days < calc.total_calendar_days
    assert calc.breakdown["public_holidays"] >= 2
    assert calc.breakdown["school_holidays"] >= 1


# ==============================================================
# TEST 6: WEEKEND AND SPECIAL WORKING DAY HANDLING
# ==============================================================
@pytest.mark.anyio
async def test_weekend_and_custom_saturday_handling(db_session):
    ctx = await setup_test_context(db_session)
    cal_service = AcademicCalendarService(db_session)

    # Oct 10, 2026 is 2nd Saturday -> should be non-working
    # Oct 17, 2026 is 3rd Saturday -> should be working (under SECOND_FOURTH_OFF)
    # Declare Oct 11, 2026 (Sunday) as SPECIAL_WORKING_DAY
    await cal_service.calendar_repo.create(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        event_date=date(2026, 10, 11),
        event_type=CalendarEventType.SPECIAL_WORKING_DAY,
        title="Special Sports Prep Session",
        status=CalendarEventStatus.APPROVED,
        is_non_working_day=False
    )

    calc = await cal_service.calculate_working_days(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        start_date=date(2026, 10, 10),
        end_date=date(2026, 10, 18)
    )

    assert date(2026, 10, 10) not in calc.working_dates  # 2nd Saturday OFF
    assert date(2026, 10, 11) in calc.working_dates      # Sunday with SPECIAL_WORKING_DAY override
    assert date(2026, 10, 17) in calc.working_dates      # 3rd Saturday WORKING
    assert date(2026, 10, 18) not in calc.working_dates  # Regular Sunday OFF


# ==============================================================
# TEST 7: TIMETABLE HOLIDAY EXCLUSION
# ==============================================================
@pytest.mark.anyio
async def test_timetable_holiday_exclusion(db_session):
    ctx = await setup_test_context(db_session)
    cal_service = AcademicCalendarService(db_session)

    # Date 2026-10-12 is Monday. Mark as School Holiday
    await cal_service.create_school_holiday(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        event_date=date(2026, 10, 12),
        title="School Holiday"
    )

    working_calc = await cal_service.calculate_working_days(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        start_date=date(2026, 10, 12),
        end_date=date(2026, 10, 12)
    )
    assert len(working_calc.working_dates) == 0
    assert working_calc.total_working_days == 0


# ==============================================================
# TEST 8: TIMETABLE HOLIDAY IMPACT ANALYSIS
# ==============================================================
@pytest.mark.anyio
async def test_holiday_timetable_impact_analysis(db_session):
    ctx = await setup_test_context(db_session)
    ai_engine = TimetableAIEngine(db_session, TimetableRepository(db_session), TimetableRecommendationRepository(db_session))

    # Seed 3 active published Monday slots
    for p in range(1, 4):
        slot = Timetable(
            tenant_id=ctx["tenant"].id,
            school_id=ctx["school"].id,
            academic_year_id=ctx["academic_year"].id,
            class_id=ctx["class"].id,
            section_id=ctx["section"].id,
            subject_id=ctx["subject"].id,
            teacher_id=ctx["teacher"].id,
            day_of_week=DayOfWeek.MONDAY,
            period_number=p,
            start_time=time(8 + p, 0),
            end_time=time(8 + p, 45),
            period_type=PeriodType.REGULAR,
            status=TimetableStatus.ACTIVE,
            is_active=True
        )
        db_session.add(slot)
    await db_session.flush()

    # 2026-10-12 is Monday
    impact = await ai_engine.analyze_holiday_impact(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        holiday_date=date(2026, 10, 12)
    )

    assert impact["is_working_day_originally"] is True
    assert impact["affected_periods_count"] == 3
    assert impact["affected_classes_count"] == 1
    assert impact["affected_teachers_count"] == 1
    assert "Mathematics" in impact["subjects_requiring_recovery"]


# ==============================================================
# TEST 9: AI RECOVERY RECOMMENDATION GENERATION
# ==============================================================
@pytest.mark.anyio
async def test_ai_recovery_recommendation_generation(db_session):
    ctx = await setup_test_context(db_session)
    ai_engine = TimetableAIEngine(db_session, TimetableRepository(db_session), TimetableRecommendationRepository(db_session))

    # Seed 1 active Monday slot
    slot = Timetable(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        class_id=ctx["class"].id,
        section_id=ctx["section"].id,
        subject_id=ctx["subject"].id,
        teacher_id=ctx["teacher"].id,
        day_of_week=DayOfWeek.MONDAY,
        period_number=2,
        start_time=time(9, 15),
        end_time=time(10, 0),
        period_type=PeriodType.REGULAR,
        status=TimetableStatus.ACTIVE,
        is_active=True
    )
    db_session.add(slot)
    await db_session.flush()

    recovery_res = await ai_engine.generate_holiday_recovery(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        holiday_date=date(2026, 10, 12),
        current_user=ctx["user"]
    )

    assert recovery_res["status"] == "SUGGESTED"
    assert recovery_res["affected_periods"] == 1
    assert len(recovery_res["changes"]) == 1
    ch = recovery_res["changes"][0]
    assert ch["from_slot"] == "MONDAY P2"
    assert ch["to_day"] != "MONDAY"  # Must be moved to another day
    assert ch["to_period"] >= 1
    assert ch["strategy"] in ("FREE_PERIOD_REALLOCATION", "ACTIVITY_PERIOD_SUBSTITUTION")


# ==============================================================
# TEST 10: MINIMUM-DISRUPTION PRINCIPLE PRESERVES UNAFFECTED SLOTS
# ==============================================================
@pytest.mark.anyio
async def test_minimum_disruption_principle_preserves_unaffected_slots(db_session):
    ctx = await setup_test_context(db_session)
    ai_engine = TimetableAIEngine(db_session, TimetableRepository(db_session), TimetableRecommendationRepository(db_session))

    # Seed 1 Monday slot and 4 Tuesday-Friday slots
    mon_slot = Timetable(
        tenant_id=ctx["tenant"].id, school_id=ctx["school"].id, academic_year_id=ctx["academic_year"].id,
        class_id=ctx["class"].id, section_id=ctx["section"].id, subject_id=ctx["subject"].id,
        teacher_id=ctx["teacher"].id, day_of_week=DayOfWeek.MONDAY, period_number=1,
        start_time=time(8, 30), end_time=time(9, 15), period_type=PeriodType.REGULAR, status=TimetableStatus.ACTIVE
    )
    db_session.add(mon_slot)

    unaffected_ids = []
    for d, p in [(DayOfWeek.TUESDAY, 1), (DayOfWeek.WEDNESDAY, 1), (DayOfWeek.THURSDAY, 1), (DayOfWeek.FRIDAY, 1)]:
        s = Timetable(
            tenant_id=ctx["tenant"].id, school_id=ctx["school"].id, academic_year_id=ctx["academic_year"].id,
            class_id=ctx["class"].id, section_id=ctx["section"].id, subject_id=ctx["subject"].id,
            teacher_id=ctx["teacher"].id, day_of_week=d, period_number=p,
            start_time=time(8, 30), end_time=time(9, 15), period_type=PeriodType.REGULAR, status=TimetableStatus.ACTIVE
        )
        db_session.add(s)
        await db_session.flush()
        unaffected_ids.append(s.id)

    await db_session.flush()

    recovery_res = await ai_engine.generate_holiday_recovery(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        holiday_date=date(2026, 10, 12),
        current_user=ctx["user"]
    )

    assert recovery_res["preserves_unaffected_slots"] is True
    assert recovery_res["unaffected_slots_count"] == 4

    # Apply recovery
    rec_id = recovery_res["recommendation_id"]
    apply_res = await ai_engine.approve_and_apply_holiday_recovery(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        recommendation_id=rec_id,
        current_user=ctx["user"]
    )
    assert apply_res["success"] is True

    # Confirm all 4 Tuesday-Friday slots remain completely untouched
    for s_id in unaffected_ids:
        slot_obj = await db_session.get(Timetable, s_id)
        assert slot_obj.status == TimetableStatus.ACTIVE
        assert slot_obj.deleted_at is None
        assert slot_obj.day_of_week != DayOfWeek.MONDAY


# ==============================================================
# TEST 11: TEACHER CONFLICT VALIDATION IN RECOVERY
# ==============================================================
@pytest.mark.anyio
async def test_teacher_conflict_validation_in_recovery(db_session):
    ctx = await setup_test_context(db_session)
    ai_engine = TimetableAIEngine(db_session, TimetableRepository(db_session), TimetableRecommendationRepository(db_session))

    # Teacher is busy on Wednesday P2 with another class
    repo_c = ClassRepository(db_session)
    other_cls = await repo_c.create(ctx["tenant"].id, ClassCreate(
        school_id=ctx["school"].id, academic_year_id=ctx["academic_year"].id, name="Class 6", code=f"C6_{uuid.uuid4().hex[:4].upper()}",
        level=6, category=ClassCategory.MIDDLE, capacity=40
    ))
    await db_session.flush()

    repo_sec = SectionRepository(db_session)
    other_sec = await repo_sec.create(ctx["tenant"].id, SectionCreate(
        school_id=ctx["school"].id, academic_year_id=ctx["academic_year"].id, class_id=other_cls.id, name="B", code=f"S_B_{uuid.uuid4().hex[:4].upper()}",
        room_number="Room 102", capacity=40
    ))
    await db_session.flush()

    busy_slot = Timetable(
        tenant_id=ctx["tenant"].id, school_id=ctx["school"].id, academic_year_id=ctx["academic_year"].id,
        class_id=other_cls.id, section_id=other_sec.id, subject_id=ctx["subject"].id,
        teacher_id=ctx["teacher"].id, day_of_week=DayOfWeek.WEDNESDAY, period_number=2,
        start_time=time(9, 15), end_time=time(10, 0), period_type=PeriodType.REGULAR, status=TimetableStatus.ACTIVE
    )
    db_session.add(busy_slot)

    # Monday slot to recover
    mon_slot = Timetable(
        tenant_id=ctx["tenant"].id, school_id=ctx["school"].id, academic_year_id=ctx["academic_year"].id,
        class_id=ctx["class"].id, section_id=ctx["section"].id, subject_id=ctx["subject"].id,
        teacher_id=ctx["teacher"].id, day_of_week=DayOfWeek.MONDAY, period_number=1,
        start_time=time(8, 30), end_time=time(9, 15), period_type=PeriodType.REGULAR, status=TimetableStatus.ACTIVE
    )
    db_session.add(mon_slot)
    await db_session.flush()

    rec_res = await ai_engine.generate_holiday_recovery(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        holiday_date=date(2026, 10, 12),
        current_user=ctx["user"]
    )

    # Destination slot must NOT conflict with Wednesday P2
    for ch in rec_res["changes"]:
        assert not (ch["to_day"] == "WEDNESDAY" and ch["to_period"] == 2)


# ==============================================================
# TEST 12: ROOM CONFLICT VALIDATION
# ==============================================================
@pytest.mark.anyio
async def test_room_conflict_validation_in_recovery(db_session):
    ctx = await setup_test_context(db_session)
    ai_engine = TimetableAIEngine(db_session, TimetableRepository(db_session), TimetableRecommendationRepository(db_session))
    from app.schemas.academic_planning import TimetableGridValidationRequest, TimetableSlotValidation

    # Create grid with room conflict
    room_id = uuid.uuid4()
    req = TimetableGridValidationRequest(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        class_id=ctx["class"].id,
        section_id=ctx["section"].id,
        slots=[
            TimetableSlotValidation(day_of_week="MONDAY", period_number=1, start_time="08:30:00", end_time="09:15:00", period_type="REGULAR", subject_id=ctx["subject"].id, teacher_id=ctx["teacher"].id, room_id=room_id),
            TimetableSlotValidation(day_of_week="MONDAY", period_number=1, start_time="08:30:00", end_time="09:15:00", period_type="REGULAR", subject_id=ctx["subject"].id, teacher_id=uuid.uuid4(), room_id=room_id)
        ]
    )
    val = await ai_engine.validate_grid(tenant_id=ctx["tenant"].id, req=req)
    assert val.has_conflict is True
    assert any("ROOM_DOUBLE_BOOKING" in c.conflict_type or "CLASH" in c.conflict_type for c in val.conflicts)


# ==============================================================
# TEST 13: EXAMINATION CONFLICT DETECTION WITHOUT SILENT MOVE
# ==============================================================
@pytest.mark.anyio
async def test_examination_conflict_detection_without_silent_move(db_session):
    ctx = await setup_test_context(db_session)
    cal_service = AcademicCalendarService(db_session)
    ai_engine = TimetableAIEngine(db_session, TimetableRepository(db_session), TimetableRecommendationRepository(db_session))

    # Create exam on 2026-10-12
    exam = Examination(
        tenant_id=ctx["tenant"].id, school_id=ctx["school"].id, academic_year_id=ctx["academic_year"].id,
        exam_name="Mid-Term Exam 2026", exam_type=ExamType.HALF_YEARLY,
        start_date=date(2026, 10, 10), end_date=date(2026, 10, 20), status=ExamStatus.PUBLISHED
    )
    db_session.add(exam)
    await db_session.flush()

    sched = ExamSchedule(
        tenant_id=ctx["tenant"].id, school_id=ctx["school"].id, academic_year_id=ctx["academic_year"].id,
        exam_id=exam.id, class_id=ctx["class"].id, section_id=ctx["section"].id, subject_id=ctx["subject"].id,
        exam_date=date(2026, 10, 12), start_time=time(9, 0), end_time=time(12, 0), max_marks=100.0, pass_marks=35.0
    )
    db_session.add(sched)
    await db_session.flush()

    # Analyze holiday impact on that day
    impact = await ai_engine.analyze_holiday_impact(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        holiday_date=date(2026, 10, 12)
    )

    assert impact["exam_conflict_detected"] is True
    assert len(impact["exam_conflicts"]) == 1
    assert impact["exam_conflicts"][0]["exam_name"] == "Mid-Term Exam 2026"

    # Verify the examination was NOT deleted or moved
    exam_check = await db_session.get(ExamSchedule, sched.id)
    assert exam_check is not None
    assert exam_check.exam_date == date(2026, 10, 12)
    assert exam_check.deleted_at is None


# ==============================================================
# TEST 14: SYLLABUS COMPLETION RECALCULATION AFTER HOLIDAY
# ==============================================================
@pytest.mark.anyio
async def test_syllabus_completion_recalculation_after_holiday(db_session):
    ctx = await setup_test_context(db_session)
    pred_engine = SyllabusPredictionEngine(db_session)
    cal_service = AcademicCalendarService(db_session)

    # Seed syllabus chapters & topics
    for i in range(1, 11):
        syll = Syllabus(
            tenant_id=ctx["tenant"].id, school_id=ctx["school"].id, academic_year_id=ctx["academic_year"].id,
            class_id=ctx["class"].id, subject_id=ctx["subject"].id,
            syllabus_code=f"SYLL_{i}_{uuid.uuid4().hex[:4]}",
            unit_name=f"Unit {(i-1)//3 + 1}",
            chapter_name=f"Chapter {i}", topic_name=f"Topic {i}.1", sequence_order=i,
            coverage_status="COMPLETED" if i <= 3 else "PENDING"
        )
        db_session.add(syll)
    await db_session.flush()

    # 1. Prediction without holiday
    pred_before = await pred_engine.predict_subject_completion(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        class_id=ctx["class"].id,
        subject_id=ctx["subject"].id,
        reference_date=date(2026, 10, 1)
    )
    dt_before = pred_before.projected_completion_date

    # 2. Add multiple holidays in October
    for d in [5, 6, 7, 8, 9]:
        await cal_service.create_school_holiday(
            tenant_id=ctx["tenant"].id,
            school_id=ctx["school"].id,
            academic_year_id=ctx["academic_year"].id,
            event_date=date(2026, 10, d),
            title=f"Mid-Term Break Day {d}"
        )

    # 3. Prediction after holiday
    pred_after = await pred_engine.predict_subject_completion(
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        class_id=ctx["class"].id,
        subject_id=ctx["subject"].id,
        reference_date=date(2026, 10, 1)
    )
    dt_after = pred_after.projected_completion_date

    # Projected completion date must be later because working days were consumed by holidays
    assert dt_after > dt_before


# ==============================================================
# TEST 15: SCHOOL ISOLATION IN CALENDAR & RECOVERY
# ==============================================================
@pytest.mark.anyio
async def test_school_isolation_in_calendar_and_recovery(db_session):
    ctx_a = await setup_test_context(db_session)
    ctx_b = await setup_test_context(db_session)
    cal_service = AcademicCalendarService(db_session)

    # School A creates holiday
    ev_a = await cal_service.create_school_holiday(
        tenant_id=ctx_a["tenant"].id,
        school_id=ctx_a["school"].id,
        academic_year_id=ctx_a["academic_year"].id,
        event_date=date(2026, 11, 2),
        title="School A Sports Gala"
    )

    # School B events query must NOT contain School A's event
    events_b = await cal_service.calendar_repo.get_events(
        school_id=ctx_b["school"].id,
        academic_year_id=ctx_b["academic_year"].id
    )
    assert ev_a.id not in [e.id for e in events_b]

    # School B cannot fetch School A's event by ID
    isolated_ev = await cal_service.calendar_repo.get_by_id(
        event_id=ev_a.id,
        school_id=ctx_b["school"].id,
        tenant_id=ctx_b["tenant"].id
    )
    assert isolated_ev is None


# ==============================================================
# TEST 16: ACADEMIC-YEAR ISOLATION
# ==============================================================
@pytest.mark.anyio
async def test_academic_year_isolation_in_calendar_and_recovery(db_session):
    ctx = await setup_test_context(db_session)
    cal_service = AcademicCalendarService(db_session)

    # Create next academic year for same school
    ay_next = AcademicYear(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        name="AY 2027-2028",
        code=f"AY_NEXT_{uuid.uuid4().hex[:4]}",
        start_date=date(2027, 6, 1),
        end_date=date(2028, 4, 30),
        status=AcademicYearStatus.UPCOMING
    )
    db_session.add(ay_next)
    await db_session.flush()

    # Add holiday to current AY
    await cal_service.create_school_holiday(
        tenant_id=ctx["tenant"].id,
        school_id=ctx["school"].id,
        academic_year_id=ctx["academic_year"].id,
        event_date=date(2026, 10, 15),
        title="Current AY Holiday"
    )

    # Next AY calendar must be empty
    events_next = await cal_service.calendar_repo.get_events(
        school_id=ctx["school"].id,
        academic_year_id=ay_next.id
    )
    assert len(events_next) == 0
