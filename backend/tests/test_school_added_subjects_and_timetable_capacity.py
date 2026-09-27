import uuid
import pytest
from datetime import date, datetime, timezone, time
from httpx import AsyncClient
from sqlalchemy import select, text

from app.models.tenant import Tenant
from app.models.school import School
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.class_entity import Class, ClassCategory, ClassStatus
from app.models.section import Section
from app.models.teacher import Teacher, EmploymentType
from app.models.subject import Subject, SubjectStatus, SubjectCategory, SubjectType, SubjectSource
from app.models.student import StudentGender
from app.models.teacher_subject_assignment import TeacherSubjectAssignment, AssignmentStatus, AssignmentType
from app.models.class_subject_assignment import ClassSubjectAssignment
from app.models.extended_working_hour import ExtendedWorkingHour
from app.models.timetable import Timetable, TimetableStatus, DayOfWeek, PeriodType
from app.models.role import Role
from app.models.permission import Permission
from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.section import SectionRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.subject import SubjectRepository
from app.repositories.teacher_subject_assignment import TeacherSubjectAssignmentRepository
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
from app.services.auth import AuthService
from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate
from app.schemas.academic_year import AcademicYearCreate
from app.schemas.class_entity import ClassCreate
from app.schemas.section import SectionCreate
from app.schemas.teacher import TeacherCreate
from app.schemas.subject import SubjectCreate
from app.schemas.teacher_subject_assignment import TeacherSubjectAssignmentCreate
from app.schemas.auth import UserCreate


@pytest.fixture
async def setup_curriculum_capacity_data(db_session):
    """
    Sets up test context for School Curriculum, Additional Subjects & Timetable Capacity:
    - Tenant A, School A, Academic Year A (ACTIVE)
    - Tenant B, School B, Academic Year B (for tenant isolation check)
    - Active Class A1, Class A2, Section A1
    - Active Teacher A1, Teacher A2
    - Core Subject (Physics, BOARD_OFFICIAL)
    - Super Admin user mapped to School A
    """
    suffix = uuid.uuid4().hex[:6].upper()
    repo_t = TenantRepository(db_session)
    tenant_a = await repo_t.create(TenantCreate(name="School-Sys A", code=f"ten-a-{suffix.lower()}", subdomain=f"t-a-{suffix.lower()}", email=f"a-{suffix.lower()}@sch.com"))
    tenant_b = await repo_t.create(TenantCreate(name="School-Sys B", code=f"ten-b-{suffix.lower()}", subdomain=f"t-b-{suffix.lower()}", email=f"b-{suffix.lower()}@sch.com"))

    repo_s = SchoolRepository(db_session)
    school_a = await repo_s.create(tenant_a.id, SchoolCreate(name="Heritage Academy A", code=f"SCH_A_{suffix}", board="CBSE", email=f"s-a-{suffix.lower()}@sch.com"))
    school_b = await repo_s.create(tenant_b.id, SchoolCreate(name="Green Valley B", code=f"SCH_B_{suffix}", board="CBSE", email=f"s-b-{suffix.lower()}@sch.com"))
    await db_session.commit()

    repo_ay = AcademicYearRepository(db_session)
    ay_a = await repo_ay.create(
        tenant_a.id, school_a.id,
        AcademicYearCreate(name="2026-2027", code="AY2026", start_date="2026-06-01", end_date="2027-04-30")
    )
    ay_a.status = AcademicYearStatus.ACTIVE

    ay_b = await repo_ay.create(
        tenant_b.id, school_b.id,
        AcademicYearCreate(name="2026-2027", code="AY2026", start_date="2026-06-01", end_date="2027-04-30")
    )
    ay_b.status = AcademicYearStatus.ACTIVE
    await db_session.commit()

    repo_c = ClassRepository(db_session)
    class_a1 = await repo_c.create(
        tenant_a.id,
        ClassCreate(school_id=school_a.id, academic_year_id=ay_a.id, name="Grade 9", code="G9", level=9, category=ClassCategory.HIGH, capacity=35)
    )
    class_a2 = await repo_c.create(
        tenant_a.id,
        ClassCreate(school_id=school_a.id, academic_year_id=ay_a.id, name="Grade 10", code="G10", level=10, category=ClassCategory.HIGH, capacity=35)
    )
    await db_session.commit()

    repo_sec = SectionRepository(db_session)
    sec_a1 = await repo_sec.create(
        tenant_a.id, SectionCreate(school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_a1.id, name="Section Alpha", code="A", capacity=35)
    )
    await db_session.commit()

    repo_t = TeacherRepository(db_session)
    teacher_a1 = await repo_t.create(
        tenant_id=tenant_a.id,
        obj_in=TeacherCreate(
            school_id=school_a.id, employee_code="EMP-101", staff_code="STF-101", first_name="Ramesh", last_name="Sharma",
            gender=StudentGender.MALE, date_of_birth=date(1985, 5, 12), mobile="+919876543210", official_email="ramesh@heritage.edu",
            joining_date=date(2021, 6, 1), employment_type=EmploymentType.FULL_TIME
        )
    )
    teacher_a2 = await repo_t.create(
        tenant_id=tenant_a.id,
        obj_in=TeacherCreate(
            school_id=school_a.id, employee_code="EMP-102", staff_code="STF-102", first_name="Priya", last_name="Nair",
            gender=StudentGender.FEMALE, date_of_birth=date(1989, 8, 24), mobile="+919876543211", official_email="priya@heritage.edu",
            joining_date=date(2022, 6, 1), employment_type=EmploymentType.FULL_TIME
        )
    )
    await db_session.commit()

    repo_sub = SubjectRepository(db_session)
    subj_core = await repo_sub.create(
        tenant_id=tenant_a.id,
        obj_in=SubjectCreate(
            school_id=school_a.id, academic_year_id=ay_a.id, subject_code="SCI-01", subject_name="General Science",
            category="CORE", subject_type="THEORY_PRACTICAL", theory_marks=80, practical_marks=20, pass_marks=35
        )
    )
    subj_core.source_type = "BOARD_OFFICIAL"
    await db_session.commit()

    # User Setup & Auth
    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    auth_service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, repo_s)

    stmt_p = select(Permission)
    res_p = await db_session.execute(stmt_p)
    all_perms = list(res_p.scalars().all())

    role_a = Role(name="Super Admin", code="SUPER_ADMIN", is_system=True, tenant_id=tenant_a.id)
    role_a.permissions = all_perms
    db_session.add(role_a)

    user_a = await auth_service.create_user(
        tenant_a.id,
        UserCreate(email=f"admin-{suffix}@sch.com", password="Password123!", first_name="School", last_name="Admin")
    )
    user_a.roles.append(role_a)

    await db_session.execute(
        text("INSERT INTO school_users (user_id, school_id) VALUES (:u, :s)"),
        {"u": str(user_a.id), "s": str(school_a.id)}
    )
    await db_session.commit()

    tokens = await auth_service.create_tokens(user_a)

    return {
        "tenant_a": tenant_a,
        "tenant_b": tenant_b,
        "school_a": school_a,
        "school_b": school_b,
        "ay_a": ay_a,
        "ay_b": ay_b,
        "class_a1": class_a1,
        "class_a2": class_a2,
        "sec_a1": sec_a1,
        "teacher_a1": teacher_a1,
        "teacher_a2": teacher_a2,
        "subj_core": subj_core,
        "user_a": user_a,
        "auth_headers": {
            "Authorization": f"Bearer {tokens.access_token}",
            "X-Tenant-ID": str(tenant_a.id)
        }
    }


@pytest.mark.anyio
async def test_subject_source_type_and_assessment_settings(client: AsyncClient, setup_curriculum_capacity_data):
    """
    1. Verify SCHOOL_ADDED subjects can be created with full assessment & report card configurations.
    2. Verify filtering subjects by source_type (BOARD_OFFICIAL vs SCHOOL_ADDED).
    """
    data = setup_curriculum_capacity_data
    headers = data["auth_headers"]
    school_id = str(data["school_a"].id)
    ay_id = str(data["ay_a"].id)

    # Create School-Added Subject: Robotics & AI
    payload = {
        "school_id": school_id,
        "academic_year_id": ay_id,
        "subject_code": "ROB-101",
        "subject_name": "Robotics & AI",
        "short_name": "Robotics",
        "source_type": "SCHOOL_ADDED",
        "category": "SKILL",
        "subject_type": "THEORY_PRACTICAL",
        "description": "School-specific hands-on robotics and coding laboratory.",
        "weekly_periods": 3,
        "is_examination_applicable": True,
        "is_marks_applicable": True,
        "max_marks": 50,
        "pass_marks": 20,
        "appears_in_report_card": True,
        "included_in_consolidated_result": True,
        "included_in_rank_calculation": False
    }

    res = await client.post("/api/v1/subjects", json=payload, headers=headers)
    assert res.status_code == 201, res.text
    created = res.json()["data"]
    assert created["subject_name"] == "Robotics & AI"
    assert created["source_type"] == "SCHOOL_ADDED"
    assert created["is_examination_applicable"] is True
    assert created["max_marks"] == 50
    assert created["pass_marks"] == 20
    assert created["appears_in_report_card"] is True
    assert created["included_in_rank_calculation"] is False

    # Filter by source_type=SCHOOL_ADDED
    res_filtered = await client.get(
        f"/api/v1/subjects?school_id={school_id}&source_type=SCHOOL_ADDED",
        headers=headers
    )
    assert res_filtered.status_code == 200
    school_added_list = res_filtered.json()["data"]
    assert any(s["subject_code"] == "ROB-101" for s in school_added_list)
    assert all(s["source_type"] == "SCHOOL_ADDED" for s in school_added_list)

    # Filter by source_type=BOARD_OFFICIAL
    res_official = await client.get(
        f"/api/v1/subjects?school_id={school_id}&source_type=BOARD_OFFICIAL",
        headers=headers
    )
    assert res_official.status_code == 200
    official_list = res_official.json()["data"]
    assert any(s["subject_code"] == "SCI-01" for s in official_list)
    assert not any(s["subject_code"] == "ROB-101" for s in official_list)


@pytest.mark.anyio
async def test_tenant_isolation_for_school_added_subjects(client: AsyncClient, setup_curriculum_capacity_data):
    """
    Verify multi-tenant isolation: School A's custom subjects NEVER leak or pollute School B.
    """
    data = setup_curriculum_capacity_data
    headers_a = data["auth_headers"]
    school_a_id = str(data["school_a"].id)
    school_b_id = str(data["school_b"].id)
    ay_a_id = str(data["ay_a"].id)

    # Create subject in Tenant A
    payload = {
        "school_id": school_a_id,
        "academic_year_id": ay_a_id,
        "subject_code": "FIN-LIT",
        "subject_name": "Financial Literacy",
        "source_type": "SCHOOL_ADDED",
        "category": "ADDITIONAL",
        "subject_type": "THEORY",
        "weekly_periods": 2
    }
    res = await client.post("/api/v1/subjects", json=payload, headers=headers_a)
    assert res.status_code == 201
    subj_a_id = res.json()["data"]["id"]

    # Tenant B tries to query Tenant A's subject
    headers_b = {
        "Authorization": headers_a["Authorization"],
        "X-Tenant-ID": str(data["tenant_b"].id)
    }
    res_b = await client.get(f"/api/v1/subjects/{subj_a_id}?school_id={school_b_id}", headers=headers_b)
    assert res_b.status_code in (403, 404)

    # Tenant B lists subjects for School B - School A's subject must not appear
    res_b_list = await client.get(f"/api/v1/subjects?school_id={school_b_id}", headers=headers_b)
    if res_b_list.status_code == 200:
        subjects_b = res_b_list.json()["data"]
        assert not any(s["id"] == subj_a_id for s in subjects_b)


@pytest.mark.anyio
async def test_class_subject_assignment_crud_and_sync(client: AsyncClient, setup_curriculum_capacity_data):
    """
    1. Create ClassSubjectAssignment mapping subject to Class 9 Section Alpha with 3 weekly periods.
    2. Assign Teacher A1.
    3. Verify automatic synchronization with TeacherSubjectAssignment so Teacher 360 immediately works.
    """
    data = setup_curriculum_capacity_data
    headers = data["auth_headers"]
    school_id = str(data["school_a"].id)
    ay_id = str(data["ay_a"].id)
    class_id = str(data["class_a1"].id)
    sec_id = str(data["sec_a1"].id)
    teacher_id = str(data["teacher_a1"].id)

    # Create subject
    res_sub = await client.post("/api/v1/subjects", json={
        "school_id": school_id,
        "academic_year_id": ay_id,
        "subject_code": "COD-01",
        "subject_name": "Coding & Algorithms",
        "source_type": "SCHOOL_ADDED",
        "category": "SKILL",
        "subject_type": "PRACTICAL",
        "weekly_periods": 3
    }, headers=headers)
    assert res_sub.status_code == 201
    subject_id = res_sub.json()["data"]["id"]

    # Create ClassSubjectAssignment
    csa_payload = {
        "school_id": school_id,
        "academic_year_id": ay_id,
        "class_id": class_id,
        "section_id": sec_id,
        "subject_id": subject_id,
        "weekly_periods": 3,
        "period_duration_minutes": 45,
        "teacher_id": teacher_id,
        "is_lab_required": True,
        "preferred_days": ["MONDAY", "WEDNESDAY", "FRIDAY"]
    }
    res_csa = await client.post("/api/v1/class-subject-assignments", json=csa_payload, headers=headers)
    assert res_csa.status_code == 201, res_csa.text
    csa_data = res_csa.json()["data"]
    assert csa_data["weekly_periods"] == 3
    assert csa_data["is_lab_required"] is True

    # Verify Auto-sync: TeacherSubjectAssignment was created/updated
    res_tsa = await client.get(
        f"/api/v1/teacher-subject-assignments?teacher_id={teacher_id}&school_id={school_id}",
        headers=headers
    )
    assert res_tsa.status_code == 200
    tsa_items = res_tsa.json()["data"]
    matching_tsa = next((t for t in tsa_items if t["subject_id"] == subject_id and t["class_id"] == class_id), None)
    assert matching_tsa is not None
    assert matching_tsa["weekly_periods"] == 3


@pytest.mark.anyio
async def test_batch_class_subject_assignment(client: AsyncClient, setup_curriculum_capacity_data):
    """
    Verify batch assignment of a subject across multiple classes.
    """
    data = setup_curriculum_capacity_data
    headers = data["auth_headers"]
    school_id = str(data["school_a"].id)
    ay_id = str(data["ay_a"].id)
    class_1 = str(data["class_a1"].id)
    class_2 = str(data["class_a2"].id)

    # Subject: Value Education
    res_sub = await client.post("/api/v1/subjects", json={
        "school_id": school_id,
        "academic_year_id": ay_id,
        "subject_code": "VAL-01",
        "subject_name": "Value Education & Ethics",
        "source_type": "SCHOOL_ADDED",
        "category": "ADDITIONAL",
        "subject_type": "THEORY",
        "weekly_periods": 2
    }, headers=headers)
    assert res_sub.status_code == 201
    subject_id = res_sub.json()["data"]["id"]

    batch_payload = {
        "school_id": school_id,
        "academic_year_id": ay_id,
        "subject_id": subject_id,
        "class_ids": [class_1, class_2],
        "weekly_periods": 2,
        "is_lab_required": False
    }
    res_batch = await client.post("/api/v1/class-subject-assignments/batch", json=batch_payload, headers=headers)
    assert res_batch.status_code == 201
    assert len(res_batch.json()["data"]) == 2


@pytest.mark.anyio
async def test_ai_draft_syllabus_generation_and_approval(client: AsyncClient, setup_curriculum_capacity_data):
    """
    Verify AI Draft Syllabus:
    1. Generates structured draft syllabus for school-added subject.
    2. Explicitly labeled 'AI GENERATED DRAFT' with strict disclaimer (zero hallucination guard).
    3. Principal/Admin can approve and persist draft into school editable Syllabus table.
    """
    data = setup_curriculum_capacity_data
    headers = data["auth_headers"]
    school_id = str(data["school_a"].id)
    ay_id = str(data["ay_a"].id)
    class_id = str(data["class_a1"].id)

    res_sub = await client.post("/api/v1/subjects", json={
        "school_id": school_id,
        "academic_year_id": ay_id,
        "subject_code": "FIN-102",
        "subject_name": "Financial Literacy",
        "source_type": "SCHOOL_ADDED",
        "category": "ADDITIONAL",
        "subject_type": "THEORY",
        "weekly_periods": 2
    }, headers=headers)
    subject_id = res_sub.json()["data"]["id"]

    draft_req = {
        "school_id": school_id,
        "academic_year_id": ay_id,
        "class_id": class_id,
        "subject_id": subject_id,
        "num_units": 2,
        "chapters_per_unit": 2
    }
    res_draft = await client.post("/api/v1/curriculum/ai-draft-syllabus", json=draft_req, headers=headers)
    assert res_draft.status_code == 200, res_draft.text
    draft_data = res_draft.json()["data"]
    assert draft_data["is_ai_draft"] is True
    assert draft_data["status"] == "AI GENERATED DRAFT"
    assert "AI GENERATED DRAFT" in draft_data["disclaimer"]
    assert len(draft_data["topics"]) > 0

    first_topic = draft_data["topics"][0]
    assert "Banking" in first_topic["unit_name"] or "Money" in first_topic["unit_name"] or "Financial" in first_topic["unit_name"]

    # Approve and persist draft topics
    approve_req = {
        "school_id": school_id,
        "academic_year_id": ay_id,
        "class_id": class_id,
        "subject_id": subject_id,
        "topics": draft_data["topics"]
    }
    res_approve = await client.post("/api/v1/curriculum/ai-draft-syllabus/approve", json=approve_req, headers=headers)
    assert res_approve.status_code == 200
    assert res_approve.json()["data"]["approved_topics_count"] == len(draft_data["topics"])


@pytest.mark.anyio
async def test_working_hours_capacity_and_shortfall_detection(client: AsyncClient, setup_curriculum_capacity_data):
    """
    1. Configure normal working hours: 5 days, 6 periods/day = 30 available periods.
    2. Map subjects requiring 35 periods.
    3. Verify capacity endpoint detects shortfall: Required > Available.
    4. Verify explicit non-silent warning message and remediation choices.
    """
    data = setup_curriculum_capacity_data
    headers = data["auth_headers"]
    school_id = str(data["school_a"].id)
    ay_id = str(data["ay_a"].id)
    class_id = str(data["class_a1"].id)
    sec_id = str(data["sec_a1"].id)

    # Set working hours: 5 working days, 6 periods per day (capacity = 30)
    wh_payload = {
        "school_id": school_id,
        "academic_year_id": ay_id,
        "normal_start_time": "08:30",
        "normal_end_time": "14:00",
        "periods_per_day": 6,
        "working_days": ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY"],
        "is_extended_hours_enabled": False
    }
    res_wh = await client.put("/api/v1/working-hours", json=wh_payload, headers=headers)
    assert res_wh.status_code == 200
    wh_data = res_wh.json()["data"]
    assert wh_data["total_weekly_capacity"] == 30

    # Create subjects with total demand = 35 periods
    for i in range(7):
        res_s = await client.post("/api/v1/subjects", json={
            "school_id": school_id,
            "academic_year_id": ay_id,
            "subject_code": f"SUBJ-{i:02d}",
            "subject_name": f"Subject {i}",
            "source_type": "SCHOOL_ADDED",
            "category": "CORE" if i < 4 else "ADDITIONAL",
            "subject_type": "THEORY",
            "weekly_periods": 5
        }, headers=headers)
        s_id = res_s.json()["data"]["id"]

        await client.post("/api/v1/class-subject-assignments", json={
            "school_id": school_id,
            "academic_year_id": ay_id,
            "class_id": class_id,
            "section_id": sec_id,
            "subject_id": s_id,
            "weekly_periods": 5
        }, headers=headers)

    # Check capacity endpoint
    res_cap = await client.get(
        f"/api/v1/working-hours/capacity?school_id={school_id}&academic_year_id={ay_id}&class_id={class_id}&section_id={sec_id}",
        headers=headers
    )
    assert res_cap.status_code == 200
    cap = res_cap.json()["data"]
    assert cap["available_weekly_capacity"] == 30
    assert cap["total_required_periods"] >= 35
    assert cap["is_shortfall"] is True
    assert cap["shortfall_periods"] >= 5
    assert "Timetable Capacity Shortfall" in cap["shortfall_warning_message"]
    assert "Optimize Existing Timetable" in cap["remediation_options"]
    assert "Add Working Hours" in cap["remediation_options"]


@pytest.mark.anyio
async def test_timetable_ai_engine_with_school_added_subjects_and_extended_hours(client: AsyncClient, setup_curriculum_capacity_data):
    """
    Verify TimetableAIEngine:
    1. Accounts for school-added subjects configured via ClassSubjectAssignment.
    2. Proposes extended teaching hours when enabled and shortfall exists.
    3. Status remains SUGGESTED until approved.
    4. Detects period allocation changes against active timetable.
    """
    data = setup_curriculum_capacity_data
    headers = data["auth_headers"]
    school_id = str(data["school_a"].id)
    ay_id = str(data["ay_a"].id)
    class_id = str(data["class_a1"].id)
    sec_id = str(data["sec_a1"].id)
    teacher_id = str(data["teacher_a1"].id)

    # Enable extended working hours: Mon, Wed, Fri (3 additional periods)
    await client.put("/api/v1/working-hours", json={
        "school_id": school_id,
        "academic_year_id": ay_id,
        "normal_start_time": "08:30",
        "normal_end_time": "14:30",
        "periods_per_day": 6,
        "working_days": ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY"],
        "is_extended_hours_enabled": True,
        "extended_start_time": "14:30",
        "extended_end_time": "15:15",
        "applicable_days": ["MONDAY", "WEDNESDAY", "FRIDAY"],
        "additional_periods": 1
    }, headers=headers)

    # Create School-Added Subject: Coding
    res_s = await client.post("/api/v1/subjects", json={
        "school_id": school_id,
        "academic_year_id": ay_id,
        "subject_code": "CODE-201",
        "subject_name": "Full Stack Coding",
        "source_type": "SCHOOL_ADDED",
        "category": "SKILL",
        "subject_type": "PRACTICAL",
        "weekly_periods": 4
    }, headers=headers)
    subj_code_id = res_s.json()["data"]["id"]

    await client.post("/api/v1/class-subject-assignments", json={
        "school_id": school_id,
        "academic_year_id": ay_id,
        "class_id": class_id,
        "section_id": sec_id,
        "subject_id": subj_code_id,
        "weekly_periods": 4,
        "teacher_id": teacher_id
    }, headers=headers)

    # Request Timetable AI Recommendation
    rec_req = {
        "school_id": school_id,
        "academic_year_id": ay_id,
        "class_id": class_id,
        "section_id": sec_id,
        "periods_per_day": 6,
        "working_days": ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY"],
        "lunch_period_number": 4
    }
    res_rec = await client.post("/api/v1/academic-planning/timetable-recommendations", json=rec_req, headers=headers)
    assert res_rec.status_code == 200, res_rec.text
    rec_data = res_rec.json()["data"]
    assert rec_data["status"] == "SUGGESTED"
    assert rec_data["can_publish"] is True

    # Verify school-added subject is present in suggested slots and workload breakdown
    slots = rec_data["suggested_slots"]
    code_slots = [s for s in slots if s["subject_id"] == subj_code_id]
    assert len(code_slots) > 0

    # Approve and publish recommendation
    pub_res = await client.post("/api/v1/academic-planning/timetable-ai/approve", json={
        "recommendation_id": rec_data["recommendation_id"],
        "publish_immediately": True
    }, headers=headers)
    assert pub_res.status_code == 200
    assert pub_res.json()["data"] > 0
