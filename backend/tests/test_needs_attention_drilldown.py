import uuid
import pytest
from datetime import date, datetime, time, timezone
from decimal import Decimal
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.tenant import Tenant
from app.models.school import School, SchoolStatus
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.class_entity import Class, ClassCategory
from app.models.section import Section
from app.models.student import Student, StudentGender, StudentStatus
from app.models.teacher import Teacher, EmploymentType
from app.models.subject import Subject, SubjectCategory, SubjectType, SubjectStatus
from app.models.teacher_subject_assignment import TeacherSubjectAssignment, AssignmentStatus
from app.models.examination import Examination, ExamSchedule, ExamType, ExamStatus
from app.models.marks import Marks, MarksStatus, ExamResult
from app.models.attendance import Attendance, AttendanceSession, AttendanceStatus, AttendanceSessionType, AttendanceSessionStatus
from app.services.student_risk_service import evaluate_active_risk_students


@pytest.fixture
async def setup_attention_test_data(db_session: AsyncSession):
    suffix = uuid.uuid4().hex[:6].lower()

    # 1. Tenant
    tenant = Tenant(
        id=uuid.uuid4(),
        name=f"Attention Tenant {suffix}",
        code=f"att-ten-{suffix}",
        subdomain=f"att-{suffix}",
        email=f"att-{suffix}@edu.com"
    )
    db_session.add(tenant)
    await db_session.commit()

    # 2. School A & School B (for isolation)
    school_a = School(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        name=f"School A {suffix}",
        code=f"SCH_A_{suffix.upper()}",
        address="123 Alpha Road",
        city="Bangalore",
        state="Karnataka",
        country="India",
        postal_code="560001",
        board="CBSE",
        email=f"school-a-{suffix}@edu.com",
        status=SchoolStatus.ACTIVE
    )
    school_b = School(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        name=f"School B {suffix}",
        code=f"SCH_B_{suffix.upper()}",
        address="456 Beta Road",
        city="Bangalore",
        state="Karnataka",
        country="India",
        postal_code="560001",
        board="CBSE",
        email=f"school-b-{suffix}@edu.com",
        status=SchoolStatus.ACTIVE
    )
    db_session.add_all([school_a, school_b])
    await db_session.commit()

    # 3. Academic Year
    ay_a = AcademicYear(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        school_id=school_a.id,
        name="AY 2026-27",
        code=f"AY26_{suffix}",
        start_date=date(2026, 4, 1),
        end_date=date(2027, 3, 31),
        status=AcademicYearStatus.ACTIVE,
        is_current=True
    )
    ay_b = AcademicYear(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        school_id=school_b.id,
        name="AY 2026-27 B",
        code=f"AY26B_{suffix}",
        start_date=date(2026, 4, 1),
        end_date=date(2027, 3, 31),
        status=AcademicYearStatus.ACTIVE,
        is_current=True
    )
    db_session.add_all([ay_a, ay_b])
    await db_session.commit()

    # 4. Class & Section for School A & School B
    class_a = Class(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        name="Class 8",
        code="C8",
        level=8,
        category=ClassCategory.MIDDLE,
        capacity=40
    )
    class_b = Class(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        school_id=school_b.id,
        academic_year_id=ay_b.id,
        name="Class 8 B",
        code="C8B",
        level=8,
        category=ClassCategory.MIDDLE,
        capacity=40
    )
    db_session.add_all([class_a, class_b])
    await db_session.commit()

    sec_a = Section(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        class_id=class_a.id,
        name="Section A",
        code="SEC_A",
        capacity=40
    )
    sec_b = Section(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        school_id=school_b.id,
        academic_year_id=ay_b.id,
        class_id=class_b.id,
        name="Section B",
        code="SEC_B",
        capacity=40
    )
    db_session.add_all([sec_a, sec_b])
    await db_session.commit()

    # 5. Four Students in School A
    # Student 1: Rahul Kumar (Low Attendance < 75%)
    stud1 = Student(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        class_id=class_a.id,
        section_id=sec_a.id,
        admission_number=f"ADM-RK-{suffix}",
        roll_number="01",
        first_name="Rahul",
        last_name="Kumar",
        gender=StudentGender.MALE,
        date_of_birth=date(2012, 1, 10),
        admission_date=date(2026, 4, 1),
        status=StudentStatus.ACTIVE,
        is_active=True
    )
    # Student 2: Ananya Reddy (High Attendance, Consecutive Academic Drops)
    stud2 = Student(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        class_id=class_a.id,
        section_id=sec_a.id,
        admission_number=f"ADM-AR-{suffix}",
        roll_number="02",
        first_name="Ananya",
        last_name="Reddy",
        gender=StudentGender.FEMALE,
        date_of_birth=date(2012, 5, 15),
        admission_date=date(2026, 4, 1),
        status=StudentStatus.ACTIVE,
        is_active=True
    )
    # Student 3: Vikram Singh (Both: Low Attendance + Consecutive Academic Drops)
    stud3 = Student(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        class_id=class_a.id,
        section_id=sec_a.id,
        admission_number=f"ADM-VS-{suffix}",
        roll_number="03",
        first_name="Vikram",
        last_name="Singh",
        gender=StudentGender.MALE,
        date_of_birth=date(2012, 8, 20),
        admission_date=date(2026, 4, 1),
        status=StudentStatus.ACTIVE,
        is_active=True
    )
    # Student 4: Priya Sharma (Good Attendance, Improving Marks - Stable/No Attention)
    stud4 = Student(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        class_id=class_a.id,
        section_id=sec_a.id,
        admission_number=f"ADM-PS-{suffix}",
        roll_number="04",
        first_name="Priya",
        last_name="Sharma",
        gender=StudentGender.FEMALE,
        date_of_birth=date(2012, 11, 25),
        admission_date=date(2026, 4, 1),
        status=StudentStatus.ACTIVE,
        is_active=True
    )
    # Student 5: In School B (Isolation check)
    stud_b = Student(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        school_id=school_b.id,
        academic_year_id=ay_b.id,
        class_id=class_b.id,
        section_id=sec_b.id,
        admission_number=f"ADM-B-{suffix}",
        roll_number="99",
        first_name="SchoolB",
        last_name="Student",
        gender=StudentGender.MALE,
        date_of_birth=date(2012, 1, 1),
        admission_date=date(2026, 4, 1),
        status=StudentStatus.ACTIVE,
        is_active=True
    )
    db_session.add_all([stud1, stud2, stud3, stud4, stud_b])
    await db_session.commit()

    # 6. Subject, Teacher, Assignment
    subject = Subject(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        subject_name="Science",
        subject_code=f"SCI_{suffix.upper()}",
        category=SubjectCategory.CORE,
        subject_type=SubjectType.THEORY,
        status=SubjectStatus.ACTIVE
    )
    teacher = Teacher(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        school_id=school_a.id,
        first_name="Teacher",
        last_name="One",
        gender=StudentGender.FEMALE,
        date_of_birth=date(1990, 1, 1),
        employee_code=f"EMP_{suffix}",
        staff_code=f"STF_{suffix}",
        mobile=f"+91987654{suffix[:4]}",
        official_email=f"t_{suffix}@edu.com",
        joining_date=date(2024, 1, 1),
        employment_type=EmploymentType.FULL_TIME
    )
    db_session.add_all([subject, teacher])
    await db_session.commit()

    now_ts = datetime.now(timezone.utc)
    tsa = TeacherSubjectAssignment(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        teacher_id=teacher.id,
        subject_id=subject.id,
        class_id=class_a.id,
        section_id=sec_a.id,
        assignment_type="PRIMARY",
        weekly_periods=5,
        effective_from=date(2026, 4, 1),
        assigned_at=now_ts,
        status=AssignmentStatus.ACTIVE,
        is_active=True
    )
    db_session.add(tsa)
    await db_session.commit()

    # 7. Attendance Sessions & Records
    for d in range(1, 11):
        att_date = date(2026, 5, d)
        sess_a = AttendanceSession(
            id=uuid.uuid4(),
            tenant_id=tenant.id,
            school_id=school_a.id,
            academic_year_id=ay_a.id,
            class_id=class_a.id,
            section_id=sec_a.id,
            teacher_id=teacher.id,
            subject_id=subject.id,
            attendance_date=att_date,
            session_type=AttendanceSessionType.FULL_DAY,
            status=AttendanceSessionStatus.SUBMITTED,
            is_active=True
        )
        sess_b = AttendanceSession(
            id=uuid.uuid4(),
            tenant_id=tenant.id,
            school_id=school_b.id,
            academic_year_id=ay_b.id,
            class_id=class_b.id,
            section_id=sec_b.id,
            attendance_date=att_date,
            session_type=AttendanceSessionType.FULL_DAY,
            status=AttendanceSessionStatus.SUBMITTED,
            is_active=True
        )
        db_session.add_all([sess_a, sess_b])
        await db_session.flush()

        # Student 1: 6 present, 4 absent (60% < 75%)
        st1_status = AttendanceStatus.PRESENT if d <= 6 else AttendanceStatus.ABSENT
        att1 = Attendance(
            id=uuid.uuid4(),
            tenant_id=tenant.id,
            school_id=school_a.id,
            academic_year_id=ay_a.id,
            class_id=class_a.id,
            section_id=sec_a.id,
            attendance_session_id=sess_a.id,
            student_id=stud1.id,
            attendance_date=att_date,
            attendance_status=st1_status,
            is_active=True
        )

        # Student 2: 9 present, 1 absent (90% >= 75%)
        st2_status = AttendanceStatus.PRESENT if d <= 9 else AttendanceStatus.ABSENT
        att2 = Attendance(
            id=uuid.uuid4(),
            tenant_id=tenant.id,
            school_id=school_a.id,
            academic_year_id=ay_a.id,
            class_id=class_a.id,
            section_id=sec_a.id,
            attendance_session_id=sess_a.id,
            student_id=stud2.id,
            attendance_date=att_date,
            attendance_status=st2_status,
            is_active=True
        )

        # Student 3: 6 present, 4 absent (60% < 75%)
        st3_status = AttendanceStatus.PRESENT if d <= 6 else AttendanceStatus.ABSENT
        att3 = Attendance(
            id=uuid.uuid4(),
            tenant_id=tenant.id,
            school_id=school_a.id,
            academic_year_id=ay_a.id,
            class_id=class_a.id,
            section_id=sec_a.id,
            attendance_session_id=sess_a.id,
            student_id=stud3.id,
            attendance_date=att_date,
            attendance_status=st3_status,
            is_active=True
        )

        # Student 4: 9 present, 1 absent (90% >= 75%)
        st4_status = AttendanceStatus.PRESENT if d <= 9 else AttendanceStatus.ABSENT
        att4 = Attendance(
            id=uuid.uuid4(),
            tenant_id=tenant.id,
            school_id=school_a.id,
            academic_year_id=ay_a.id,
            class_id=class_a.id,
            section_id=sec_a.id,
            attendance_session_id=sess_a.id,
            student_id=stud4.id,
            attendance_date=att_date,
            attendance_status=st4_status,
            is_active=True
        )

        # Student B in School B: 10 present (100%)
        att_b = Attendance(
            id=uuid.uuid4(),
            tenant_id=tenant.id,
            school_id=school_b.id,
            academic_year_id=ay_b.id,
            class_id=class_b.id,
            section_id=sec_b.id,
            attendance_session_id=sess_b.id,
            student_id=stud_b.id,
            attendance_date=att_date,
            attendance_status=AttendanceStatus.PRESENT,
            is_active=True
        )

        db_session.add_all([att1, att2, att3, att4, att_b])

    await db_session.commit()

    # 8. Chronological Examinations & Schedules
    # Exam 1 (May 1), Exam 2 (June 1), Exam 3 (July 1)
    exam1 = Examination(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        exam_name="Assessment 1",
        exam_type=ExamType.UNIT_TEST,
        start_date=date(2026, 5, 1),
        end_date=date(2026, 5, 5),
        status=ExamStatus.PUBLISHED,
        is_active=True
    )
    exam2 = Examination(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        exam_name="Assessment 2",
        exam_type=ExamType.UNIT_TEST,
        start_date=date(2026, 6, 1),
        end_date=date(2026, 6, 5),
        status=ExamStatus.PUBLISHED,
        is_active=True
    )
    exam3 = Examination(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        exam_name="Assessment 3",
        exam_type=ExamType.UNIT_TEST,
        start_date=date(2026, 7, 1),
        end_date=date(2026, 7, 5),
        status=ExamStatus.PUBLISHED,
        is_active=True
    )
    db_session.add_all([exam1, exam2, exam3])
    await db_session.flush()

    sched1 = ExamSchedule(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        exam_id=exam1.id,
        class_id=class_a.id,
        section_id=sec_a.id,
        subject_id=subject.id,
        teacher_subject_assignment_id=tsa.id,
        exam_date=date(2026, 5, 2),
        start_time=time(9, 0),
        end_time=time(12, 0),
        max_marks=100,
        pass_marks=35,
        room_number="Room 101"
    )
    sched2 = ExamSchedule(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        exam_id=exam2.id,
        class_id=class_a.id,
        section_id=sec_a.id,
        subject_id=subject.id,
        teacher_subject_assignment_id=tsa.id,
        exam_date=date(2026, 6, 2),
        start_time=time(9, 0),
        end_time=time(12, 0),
        max_marks=100,
        pass_marks=35,
        room_number="Room 101"
    )
    sched3 = ExamSchedule(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        exam_id=exam3.id,
        class_id=class_a.id,
        section_id=sec_a.id,
        subject_id=subject.id,
        teacher_subject_assignment_id=tsa.id,
        exam_date=date(2026, 7, 2),
        start_time=time(9, 0),
        end_time=time(12, 0),
        max_marks=100,
        pass_marks=35,
        room_number="Room 101"
    )
    db_session.add_all([sched1, sched2, sched3])
    await db_session.commit()

    # Marks:
    # Student 2 (Ananya Reddy): 3 consecutive drops (90 -> 70 -> 50)
    for ex, sched, score in [(exam1, sched1, 90.0), (exam2, sched2, 70.0), (exam3, sched3, 50.0)]:
        m = Marks(
            id=uuid.uuid4(),
            tenant_id=tenant.id,
            school_id=school_a.id,
            academic_year_id=ay_a.id,
            examination_id=ex.id,
            exam_schedule_id=sched.id,
            class_id=class_a.id,
            section_id=sec_a.id,
            student_id=stud2.id,
            teacher_subject_assignment_id=tsa.id,
            teacher_id=teacher.id,
            subject_id=subject.id,
            maximum_marks=100,
            marks_obtained=score,
            status=MarksStatus.PUBLISHED,
            result_status=ExamResult.PRESENT,
            is_active=True
        )
        db_session.add(m)

    # Student 3 (Vikram Singh): 2 consecutive drops (85 -> 65 -> 45)
    for ex, sched, score in [(exam1, sched1, 85.0), (exam2, sched2, 65.0), (exam3, sched3, 45.0)]:
        m = Marks(
            id=uuid.uuid4(),
            tenant_id=tenant.id,
            school_id=school_a.id,
            academic_year_id=ay_a.id,
            examination_id=ex.id,
            exam_schedule_id=sched.id,
            class_id=class_a.id,
            section_id=sec_a.id,
            student_id=stud3.id,
            teacher_subject_assignment_id=tsa.id,
            teacher_id=teacher.id,
            subject_id=subject.id,
            maximum_marks=100,
            marks_obtained=score,
            status=MarksStatus.PUBLISHED,
            result_status=ExamResult.PRESENT,
            is_active=True
        )
        db_session.add(m)

    # Student 4 (Priya Sharma): Improving marks (60 -> 75 -> 90)
    for ex, sched, score in [(exam1, sched1, 60.0), (exam2, sched2, 75.0), (exam3, sched3, 90.0)]:
        m = Marks(
            id=uuid.uuid4(),
            tenant_id=tenant.id,
            school_id=school_a.id,
            academic_year_id=ay_a.id,
            examination_id=ex.id,
            exam_schedule_id=sched.id,
            class_id=class_a.id,
            section_id=sec_a.id,
            student_id=stud4.id,
            teacher_subject_assignment_id=tsa.id,
            teacher_id=teacher.id,
            subject_id=subject.id,
            maximum_marks=100,
            marks_obtained=score,
            status=MarksStatus.PUBLISHED,
            result_status=ExamResult.PRESENT,
            is_active=True
        )
        db_session.add(m)

    await db_session.commit()

    return {
        "tenant": tenant,
        "school_a": school_a,
        "school_b": school_b,
        "ay_a": ay_a,
        "class_a": class_a,
        "sec_a": sec_a,
        "stud1": stud1,  # Rahul Kumar: Low Attendance
        "stud2": stud2,  # Ananya Reddy: Consecutive Academic Drops
        "stud3": stud3,  # Vikram Singh: Both
        "stud4": stud4,  # Priya Sharma: Stable / Good
        "stud_b": stud_b, # School B
        "headers_a": {"X-Tenant-ID": str(tenant.id), "X-School-ID": str(school_a.id)},
        "headers_b": {"X-Tenant-ID": str(tenant.id), "X-School-ID": str(school_b.id)},
    }


@pytest.mark.anyio
async def test_dashboard_attention_count_matches_directory(client: AsyncClient, setup_attention_test_data, db_session: AsyncSession):
    data = setup_attention_test_data
    headers = data["headers_a"]
    school_id = data["school_a"].id

    # 1. Fetch dashboard KPIs
    resp_dash = await client.get(f"/api/v1/reports/dashboard?school_id={school_id}", headers=headers)
    assert resp_dash.status_code == 200
    dash_data = resp_dash.json()["data"]
    dash_attention_count = dash_data["students_requiring_attention"]

    # Exactly 3 students should require attention:
    # 1. Rahul Kumar (Attendance 60% < 75%)
    # 2. Ananya Reddy (3 consecutive exam drops)
    # 3. Vikram Singh (Attendance 60% + exam drops)
    # Priya Sharma does not qualify
    assert dash_attention_count == 3

    # 2. Fetch students directory with attention=needs_attention
    resp_students = await client.get(f"/api/v1/students?school_id={school_id}&attention=needs_attention", headers=headers)
    assert resp_students.status_code == 200
    students_res = resp_students.json()
    qualifying_students = students_res["data"]
    meta_total = students_res["meta"]["total"]

    # VERIFY 1:1 SOURCE OF TRUTH PARITY
    assert meta_total == dash_attention_count, f"Dashboard count {dash_attention_count} must match directory total {meta_total}"
    assert len(qualifying_students) == 3

    # VERIFY EXACT STUDENT IDS
    qualifying_ids = {s["id"] for s in qualifying_students}
    expected_ids = {str(data["stud1"].id), str(data["stud2"].id), str(data["stud3"].id)}
    assert qualifying_ids == expected_ids
    assert str(data["stud4"].id) not in qualifying_ids


@pytest.mark.anyio
async def test_attention_reasons_and_criteria(client: AsyncClient, setup_attention_test_data, db_session: AsyncSession):
    data = setup_attention_test_data
    headers = data["headers_a"]
    school_id = data["school_a"].id

    resp = await client.get(f"/api/v1/students?school_id={school_id}&attention=needs_attention", headers=headers)
    assert resp.status_code == 200
    students_by_id = {s["id"]: s for s in resp.json()["data"]}

    # Student 1: Rahul Kumar (only attendance < 75%)
    s1 = students_by_id[str(data["stud1"].id)]
    assert s1["ai_metrics"]["needs_attention"] is True
    assert s1["ai_metrics"]["attention_reason"] == "Attendance below 75%"
    assert s1["ai_metrics"]["attendance_rate"] == 60.0

    # Student 2: Ananya Reddy (only consecutive drops)
    s2 = students_by_id[str(data["stud2"].id)]
    assert s2["ai_metrics"]["needs_attention"] is True
    assert "consecutive assessment declines" in s2["ai_metrics"]["attention_reason"]
    assert s2["ai_metrics"]["attendance_rate"] == 90.0

    # Student 3: Vikram Singh (Both attendance and academic drops - appears ONCE with combined reason)
    s3 = students_by_id[str(data["stud3"].id)]
    assert s3["ai_metrics"]["needs_attention"] is True
    assert s3["ai_metrics"]["attention_reason"] == "Attendance below 75% + Academic performance decline"


@pytest.mark.anyio
async def test_clearing_filter_restores_all_students(client: AsyncClient, setup_attention_test_data, db_session: AsyncSession):
    data = setup_attention_test_data
    headers = data["headers_a"]
    school_id = data["school_a"].id

    # Filtered
    resp_filtered = await client.get(f"/api/v1/students?school_id={school_id}&attention=needs_attention", headers=headers)
    assert resp_filtered.json()["meta"]["total"] == 3

    # Unfiltered (Clear Filter)
    resp_all = await client.get(f"/api/v1/students?school_id={school_id}", headers=headers)
    assert resp_all.status_code == 200
    all_students = resp_all.json()["data"]
    assert len(all_students) == 4
    assert resp_all.json()["meta"]["total"] == 4
    all_ids = {s["id"] for s in all_students}
    assert str(data["stud4"].id) in all_ids


@pytest.mark.anyio
async def test_school_isolation_attention(client: AsyncClient, setup_attention_test_data, db_session: AsyncSession):
    data = setup_attention_test_data
    school_b_id = data["school_b"].id
    headers_b = data["headers_b"]

    # School B has no at-risk students
    resp_b = await client.get(f"/api/v1/students?school_id={school_b_id}&attention=needs_attention", headers=headers_b)
    assert resp_b.status_code == 200
    assert resp_b.json()["data"] == []
    assert resp_b.json()["meta"]["total"] == 0

    # Dashboard for School B
    resp_dash_b = await client.get(f"/api/v1/reports/dashboard?school_id={school_b_id}", headers=headers_b)
    assert resp_dash_b.status_code == 200
    assert resp_dash_b.json()["data"]["students_requiring_attention"] == 0


@pytest.mark.anyio
async def test_recalculation_on_attendance_update(client: AsyncClient, setup_attention_test_data, db_session: AsyncSession):
    data = setup_attention_test_data
    headers = data["headers_a"]
    school_id = data["school_a"].id
    stud1 = data["stud1"]

    # Update Rahul's attendance to 90%
    stmt_att = select(Attendance).where(
        Attendance.student_id == stud1.id,
        Attendance.attendance_status == AttendanceStatus.ABSENT
    )
    res_att = await db_session.execute(stmt_att)
    absent_records = res_att.scalars().all()
    for rec in absent_records:
        rec.attendance_status = AttendanceStatus.PRESENT
    await db_session.commit()

    # Re-evaluate
    resp_dash = await client.get(f"/api/v1/reports/dashboard?school_id={school_id}", headers=headers)
    assert resp_dash.json()["data"]["students_requiring_attention"] == 2

    resp_students = await client.get(f"/api/v1/students?school_id={school_id}&attention=needs_attention", headers=headers)
    assert resp_students.json()["meta"]["total"] == 2
    qualifying_ids = {s["id"] for s in resp_students.json()["data"]}
    assert str(stud1.id) not in qualifying_ids
