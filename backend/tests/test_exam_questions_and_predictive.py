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
from app.models.marks import Marks, MarksStatus, ExamResult
from app.models.exam_question import ExamQuestion, QuestionDifficulty, QuestionType
from app.models.syllabus import Syllabus
from app.models.role import Role
from app.models.permission import Permission
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository
from app.schemas.auth import UserCreate
from app.services.auth import AuthService


@pytest.fixture
async def setup_predictive_test_data(db_session):
    u = uuid.uuid4().hex[:6]
    tenant = Tenant(name=f"Predictive Tenant {u}", code=f"PT_{u}", subdomain=f"pt{u}", email=f"pt{u}@edupulse.local")
    db_session.add(tenant)
    await db_session.flush()

    school = School(name=f"Predictive School {u}", code=f"PS_{u}", board="CBSE", email=f"ps_{u}@edupulse.local", tenant_id=tenant.id)
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
        name="Grade 10",
        code=f"G10_{u}",
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
        code=f"10A_{u}",
        class_id=cls.id,
        academic_year_id=ay.id,
        capacity=40,
        tenant_id=tenant.id,
        school_id=school.id
    )
    db_session.add(sec)
    await db_session.flush()

    sub_math = Subject(
        subject_name="Mathematics",
        subject_code=f"MATH_{u}",
        category=SubjectCategory.CORE,
        subject_type=SubjectType.THEORY,
        status=SubjectStatus.ACTIVE,
        academic_year_id=ay.id,
        tenant_id=tenant.id,
        school_id=school.id
    )
    sub_sci = Subject(
        subject_name="Science",
        subject_code=f"SCI_{u}",
        category=SubjectCategory.CORE,
        subject_type=SubjectType.THEORY,
        status=SubjectStatus.ACTIVE,
        academic_year_id=ay.id,
        tenant_id=tenant.id,
        school_id=school.id
    )
    db_session.add_all([sub_math, sub_sci])
    await db_session.flush()

    st1 = Student(
        first_name="Rohan",
        last_name="Verma",
        admission_number=f"ADM_R_{u}",
        roll_number="101",
        date_of_birth=date(2010, 5, 12),
        admission_date=date(2025, 6, 1),
        gender=StudentGender.MALE,
        class_id=cls.id,
        section_id=sec.id,
        academic_year_id=ay.id,
        tenant_id=tenant.id,
        school_id=school.id,
        is_active=True
    )
    db_session.add(st1)
    await db_session.flush()

    teacher = Teacher(
        tenant_id=tenant.id,
        school_id=school.id,
        employee_code=f"EMP_P_{u}",
        staff_code=f"STF_P_{u}",
        first_name="Prof",
        last_name="Euler",
        gender=StudentGender.MALE,
        date_of_birth=date(1980, 1, 1),
        joining_date=date(2025, 1, 1),
        employment_type=EmploymentType.FULL_TIME,
        official_email=f"euler_{u}@edupulse.local",
        mobile=f"+91998877{u[:4]}",
    )
    db_session.add(teacher)
    await db_session.flush()

    now_ts = datetime.now(timezone.utc)
    tsa_math = TeacherSubjectAssignment(
        tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id,
        teacher_id=teacher.id, subject_id=sub_math.id, class_id=cls.id, section_id=sec.id,
        assignment_type="PRIMARY", weekly_periods=6, effective_from=date(2025, 6, 1),
        assigned_at=now_ts, is_active=True
    )
    tsa_sci = TeacherSubjectAssignment(
        tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id,
        teacher_id=teacher.id, subject_id=sub_sci.id, class_id=cls.id, section_id=sec.id,
        assignment_type="PRIMARY", weekly_periods=6, effective_from=date(2025, 6, 1),
        assigned_at=now_ts, is_active=True
    )
    db_session.add_all([tsa_math, tsa_sci])
    await db_session.flush()

    exam1 = Examination(
        exam_name="Term 1 Midterm",
        exam_type=ExamType.UNIT_TEST,
        academic_year_id=ay.id,
        start_date=date(2025, 8, 10),
        end_date=date(2025, 8, 20),
        status=ExamStatus.PUBLISHED,
        tenant_id=tenant.id,
        school_id=school.id
    )
    exam2 = Examination(
        exam_name="Term 1 Final",
        exam_type=ExamType.QUARTERLY,
        academic_year_id=ay.id,
        start_date=date(2025, 10, 15),
        end_date=date(2025, 10, 25),
        status=ExamStatus.PUBLISHED,
        tenant_id=tenant.id,
        school_id=school.id
    )
    db_session.add_all([exam1, exam2])
    await db_session.flush()

    sched1_math = ExamSchedule(
        exam_id=exam1.id, class_id=cls.id, section_id=sec.id, subject_id=sub_math.id,
        teacher_subject_assignment_id=tsa_math.id, exam_date=date(2025, 8, 12),
        start_time=time(9, 0), end_time=time(12, 0), max_marks=100, pass_marks=35,
        academic_year_id=ay.id, tenant_id=tenant.id, school_id=school.id
    )
    sched2_math = ExamSchedule(
        exam_id=exam2.id, class_id=cls.id, section_id=sec.id, subject_id=sub_math.id,
        teacher_subject_assignment_id=tsa_math.id, exam_date=date(2025, 10, 18),
        start_time=time(9, 0), end_time=time(12, 0), max_marks=100, pass_marks=35,
        academic_year_id=ay.id, tenant_id=tenant.id, school_id=school.id
    )
    db_session.add_all([sched1_math, sched2_math])
    await db_session.flush()

    # Permissions & Superuser Admin
    from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
    from app.repositories.school import SchoolRepository
    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    ref_repo = RefreshTokenRepository(db_session)
    sch_repo = SchoolRepository(db_session)
    auth_svc = AuthService(user_repo, role_repo, perm_repo, ref_repo, sch_repo)

    role_admin = await role_repo.get_by_code("SUPER_ADMIN", tenant.id)
    if not role_admin:
        role_admin = Role(name="Super Admin", code="SUPER_ADMIN", tenant_id=tenant.id, is_system=True)
        db_session.add(role_admin)
        await db_session.flush()

    admin_user = await auth_svc.create_user(
        tenant.id,
        UserCreate(
            email=f"admin_{u}@edupulse.local",
            password="Password123!",
            first_name="Super",
            last_name="Admin"
        )
    )
    admin_user.is_superuser = True
    admin_user.roles.append(role_admin)
    tokens = await auth_svc.create_tokens(admin_user)
    token = tokens.access_token

    await db_session.commit()

    return {
        "tenant": tenant,
        "school": school,
        "academic_year": ay,
        "class": cls,
        "section": sec,
        "student": st1,
        "teacher": teacher,
        "subject_math": sub_math,
        "subject_sci": sub_sci,
        "exam1": exam1,
        "exam2": exam2,
        "sched1_math": sched1_math,
        "sched2_math": sched2_math,
        "token": token,
        "admin_user": admin_user
    }


@pytest.mark.anyio
async def test_question_mapping_crud_and_bulk(client: AsyncClient, setup_predictive_test_data):
    data = setup_predictive_test_data
    tenant = data["tenant"]
    school = data["school"]
    ay = data["academic_year"]
    exam1 = data["exam1"]
    sub_math = data["subject_math"]
    token = data["token"]

    headers = {
        "Authorization": f"Bearer {token}",
        "X-Tenant-ID": str(tenant.id),
        "X-School-ID": str(school.id),
    }

    # 1. Map single question
    create_payload = {
        "subject_id": str(sub_math.id),
        "question_number": "Q1",
        "question_text": "Solve quadratic equation 2x^2 + 5x - 3 = 0",
        "max_marks": 5.0,
        "chapter_name": "Quadratic Equations",
        "topic_name": "Factoring Method",
        "difficulty": "MEDIUM",
        "question_type": "SHORT"
    }
    resp = await client.post(
        f"/api/v1/examinations/{exam1.id}/questions",
        json=create_payload,
        params={"school_id": str(school.id), "academic_year_id": str(ay.id)},
        headers=headers
    )
    assert resp.status_code == 201
    q_data = resp.json()["data"]
    assert q_data["question_number"] == "Q1"
    assert q_data["chapter_name"] == "Quadratic Equations"
    q1_id = q_data["id"]

    # 2. Bulk map additional questions
    bulk_payload = {
        "subject_id": str(sub_math.id),
        "questions": [
            {
                "question_number": "Q2",
                "question_text": "Find roots using quadratic formula",
                "max_marks": 5.0,
                "chapter_name": "Quadratic Equations",
                "topic_name": "Quadratic Formula",
                "difficulty": "HARD",
                "question_type": "LONG"
            },
            {
                "question_number": "Q3",
                "question_text": "Arithmetic progression sum of first n terms",
                "max_marks": 4.0,
                "chapter_name": "Arithmetic Progressions",
                "difficulty": "EASY",
                "question_type": "SHORT"
            }
        ]
    }
    resp_bulk = await client.post(
        f"/api/v1/examinations/{exam1.id}/questions/bulk",
        json=bulk_payload,
        params={"school_id": str(school.id)},
        headers=headers
    )
    assert resp_bulk.status_code == 200
    assert len(resp_bulk.json()["data"]) == 2

    # 3. List questions for examination and subject
    resp_list = await client.get(
        f"/api/v1/examinations/{exam1.id}/questions",
        params={"school_id": str(school.id), "subject_id": str(sub_math.id)},
        headers=headers
    )
    assert resp_list.status_code == 200
    all_qs = resp_list.json()["data"]
    assert len(all_qs) == 3
    q_nums = [q["question_number"] for q in all_qs]
    assert "Q1" in q_nums and "Q2" in q_nums and "Q3" in q_nums

    # 4. Update Q1
    resp_update = await client.put(
        f"/api/v1/examinations/{exam1.id}/questions/{q1_id}",
        json={"difficulty": "HARD", "max_marks": 6.0},
        params={"school_id": str(school.id)},
        headers=headers
    )
    assert resp_update.status_code == 200
    assert resp_update.json()["data"]["difficulty"] == "HARD"
    assert resp_update.json()["data"]["max_marks"] == 6.0

    # 5. Delete Q1
    resp_del = await client.delete(
        f"/api/v1/examinations/{exam1.id}/questions/{q1_id}",
        params={"school_id": str(school.id)},
        headers=headers
    )
    assert resp_del.status_code == 200


@pytest.mark.anyio
async def test_syllabus_coverage_tracking(client: AsyncClient, setup_predictive_test_data):
    data = setup_predictive_test_data
    tenant = data["tenant"]
    school = data["school"]
    ay = data["academic_year"]
    cls = data["class"]
    sub_math = data["subject_math"]
    token = data["token"]

    headers = {
        "Authorization": f"Bearer {token}",
        "X-Tenant-ID": str(tenant.id),
        "X-School-ID": str(school.id),
    }

    # 1. Create syllabus entry
    syl_payload = {
        "class_id": str(cls.id),
        "subject_id": str(sub_math.id),
        "syllabus_code": f"SYL_M1_{uuid.uuid4().hex[:4]}",
        "unit_name": "Algebra",
        "chapter_name": "Quadratic Equations",
        "topic_name": "Factoring Method",
        "coverage_status": "PENDING"
    }
    resp = await client.post(
        "/api/v1/syllabuses",
        json=syl_payload,
        params={"school_id": str(school.id), "academic_year_id": str(ay.id)},
        headers=headers
    )
    assert resp.status_code == 201
    syl_data = resp.json()["data"]
    syl_id = syl_data["id"]
    assert syl_data["coverage_status"] == "PENDING"

    # 2. Update coverage to COMPLETED
    resp_cov = await client.patch(
        f"/api/v1/syllabuses/{syl_id}/coverage",
        json={"coverage_status": "COMPLETED"},
        params={"school_id": str(school.id)},
        headers=headers
    )
    assert resp_cov.status_code == 200
    assert resp_cov.json()["data"]["coverage_status"] == "COMPLETED"
    assert resp_cov.json()["data"]["completed_at"] is not None

    # 3. Get coverage summary
    resp_sum = await client.get(
        "/api/v1/syllabuses/coverage/summary",
        params={"school_id": str(school.id), "academic_year_id": str(ay.id), "subject_id": str(sub_math.id)},
        headers=headers
    )
    assert resp_sum.status_code == 200
    summaries = resp_sum.json()["data"]
    assert len(summaries) >= 1
    assert summaries[0]["completed_topics"] >= 1
    assert summaries[0]["coverage_percentage"] == 100.0


@pytest.mark.anyio
async def test_predictive_analytics_data_sufficiency_rules(client: AsyncClient, setup_predictive_test_data, db_session):
    data = setup_predictive_test_data
    tenant = data["tenant"]
    school = data["school"]
    ay = data["academic_year"]
    cls = data["class"]
    sec = data["section"]
    st = data["student"]
    sub_math = data["subject_math"]
    exam1 = data["exam1"]
    exam2 = data["exam2"]
    sched1 = data["sched1_math"]
    sched2 = data["sched2_math"]
    token = data["token"]

    headers = {
        "Authorization": f"Bearer {token}",
        "X-Tenant-ID": str(tenant.id),
        "X-School-ID": str(school.id),
    }

    # ==================================================
    # TEST RULE 1: 0 Exams -> INSUFFICIENT_DATA
    # ==================================================
    resp_0 = await client.get(
        "/api/v1/ai-intelligence/academic-predictive",
        params={"school_id": str(school.id), "academic_year_id": str(ay.id), "class_id": str(cls.id)},
        headers=headers
    )
    assert resp_0.status_code == 200
    body_0 = resp_0.json()["data"]
    assert body_0["data_sufficiency"]["exam_count"] == 0
    assert body_0["data_sufficiency"]["sufficiency_status"] == "INSUFFICIENT_DATA"
    assert body_0["data_sufficiency"]["status_message"] == "Insufficient assessment data"
    assert body_0["data_sufficiency"]["is_predictive"] is False
    assert len(body_0["subject_performance"]) == 0

    # ==================================================
    # TEST RULE 2: 1 Exam -> DESCRIPTIVE_ONLY (No trajectory prediction)
    # ==================================================
    mark1 = Marks(
        tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id,
        examination_id=exam1.id, exam_schedule_id=sched1.id, student_id=st.id,
        subject_id=sub_math.id, class_id=cls.id, section_id=sec.id,
        maximum_marks=100, marks_obtained=68.0, result_status=ExamResult.PRESENT,
        status=MarksStatus.PUBLISHED, teacher_id=data["teacher"].id,
        teacher_subject_assignment_id=sched1.teacher_subject_assignment_id
    )
    db_session.add(mark1)
    await db_session.commit()

    resp_1 = await client.get(
        "/api/v1/ai-intelligence/academic-predictive",
        params={"school_id": str(school.id), "academic_year_id": str(ay.id), "class_id": str(cls.id)},
        headers=headers
    )
    assert resp_1.status_code == 200
    body_1 = resp_1.json()["data"]
    assert body_1["data_sufficiency"]["exam_count"] == 1
    assert body_1["data_sufficiency"]["sufficiency_status"] == "DESCRIPTIVE_ONLY"
    assert "Trajectory prediction requires at least two examination cycles" in body_1["data_sufficiency"]["status_message"]
    assert body_1["data_sufficiency"]["is_predictive"] is False
    assert len(body_1["subject_performance"]) == 1
    assert body_1["subject_performance"][0]["average_percentage"] == 68.0

    # Verify unmapped question fallback notice
    assert body_1["chapter_performance"]["is_available"] is False
    assert "Chapter-level analysis unavailable because examination questions are not mapped" in body_1["chapter_performance"]["message"]

    # ==================================================
    # TEST RULE 3: Multiple Exams (>= 2) -> PREDICTIVE_ACTIVE
    # ==================================================
    mark2 = Marks(
        tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id,
        examination_id=exam2.id, exam_schedule_id=sched2.id, student_id=st.id,
        subject_id=sub_math.id, class_id=cls.id, section_id=sec.id,
        maximum_marks=100, marks_obtained=82.0, result_status=ExamResult.PRESENT,
        status=MarksStatus.PUBLISHED, teacher_id=data["teacher"].id,
        teacher_subject_assignment_id=sched2.teacher_subject_assignment_id
    )
    db_session.add(mark2)
    await db_session.commit()

    resp_2 = await client.get(
        "/api/v1/ai-intelligence/student/" + str(st.id) + "/predictive",
        params={"school_id": str(school.id), "academic_year_id": str(ay.id)},
        headers=headers
    )
    assert resp_2.status_code == 200
    body_2 = resp_2.json()["data"]
    assert body_2["data_sufficiency"]["exam_count"] == 2
    assert body_2["data_sufficiency"]["sufficiency_status"] == "PREDICTIVE_ACTIVE"
    assert body_2["data_sufficiency"]["is_predictive"] is True

    # Student summary trajectory
    st_sum = body_2["student_predictive_summary"]
    assert st_sum is not None
    assert st_sum["trajectory_direction"] == "IMPROVING"  # 68.0 -> 82.0
    assert st_sum["predicted_score_band"] is not None
    assert st_sum["predicted_score_band"]["min_percentage"] > 70.0


@pytest.mark.anyio
async def test_marks_bulk_upload_preview_and_idempotent_upsert(client: AsyncClient, setup_predictive_test_data):
    data = setup_predictive_test_data
    tenant = data["tenant"]
    school = data["school"]
    cls = data["class"]
    sec = data["section"]
    st = data["student"]
    sub_math = data["subject_math"]
    exam1 = data["exam1"]
    token = data["token"]

    headers = {
        "Authorization": f"Bearer {token}",
        "X-Tenant-ID": str(tenant.id),
        "X-School-ID": str(school.id),
    }

    # Build CSV matching by Admission Number
    csv_content = (
        "Class,Section,Admission_Number,Student_Name,Subject,Max_Marks,Marks_Obtained\n"
        f"{cls.name},{sec.name},{st.admission_number},{st.first_name} {st.last_name},{sub_math.subject_name},100,77.5\n"
    )

    # 1. Preview upload
    files = {"file": ("marks_upload.csv", csv_content.encode("utf-8"), "text/csv")}
    resp_prev = await client.post(
        f"/api/v1/marks/examinations/{exam1.id}/bulk-upload-preview",
        params={"school_id": str(school.id)},
        files=files,
        headers=headers
    )
    assert resp_prev.status_code == 200
    prev_data = resp_prev.json()["data"]
    assert prev_data["valid_rows_count"] == 1
    assert prev_data["invalid_rows_count"] == 0
    row_preview = prev_data["preview_rows"][0]
    assert row_preview["student_id"] == str(st.id)
    assert row_preview["marks_obtained"] == 77.5

    # 2. Confirm import (1st run: created_count=1)
    confirm_payload = {
        "exam_id": str(exam1.id),
        "school_id": str(school.id),
        "rows": prev_data["preview_rows"],
        "auto_approve": True
    }
    resp_conf1 = await client.post(
        f"/api/v1/marks/examinations/{exam1.id}/bulk-upload-confirm",
        json=confirm_payload,
        params={"school_id": str(school.id)},
        headers=headers
    )
    assert resp_conf1.status_code == 200
    res1 = resp_conf1.json()["data"]
    assert res1["saved_count"] == 1
    assert res1["created_count"] == 1
    assert res1["updated_count"] == 0

    # 3. Re-import with updated marks (2nd run: updated_count=1, created_count=0)
    row_preview["marks_obtained"] = 85.0
    confirm_payload["rows"] = [row_preview]
    resp_conf2 = await client.post(
        f"/api/v1/marks/examinations/{exam1.id}/bulk-upload-confirm",
        json=confirm_payload,
        params={"school_id": str(school.id)},
        headers=headers
    )
    assert resp_conf2.status_code == 200
    res2 = resp_conf2.json()["data"]
    assert res2["saved_count"] == 1
    assert res2["created_count"] == 0
    assert res2["updated_count"] == 1
    assert res2["failed_count"] == 0
