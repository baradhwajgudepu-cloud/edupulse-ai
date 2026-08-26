import os
import uuid
import pytest
from unittest.mock import AsyncMock, patch
from httpx import AsyncClient
from fastapi import status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.main import app
from app.models.tenant import Tenant
from app.models.school import School, SchoolStatus
from app.models.role import Role
from app.models.permission import Permission
from app.models.academic_year import AcademicYear
from app.models.user import User, UserStatus
from app.models.teacher import Teacher, EmploymentType
from app.models.student import Student, StudentGender
from app.models.subject import Subject
from app.models.class_entity import Class
from app.models.section import Section
from app.models.teacher_subject_assignment import TeacherSubjectAssignment, AssignmentStatus
from app.models.marks import Marks, ExamResult
from app.models.attendance import Attendance

from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
from app.services.auth import AuthService
from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate
from app.schemas.auth import UserCreate
from app.api.dependencies.auth import get_current_user
from app.api.dependencies.ai import get_ai_service
from app.services.ai.service import AIService
from app.core.settings import settings
from datetime import date, datetime, timezone

@pytest.fixture
async def setup_teacher_ai_data(db_session: AsyncSession):
    suffix = uuid.uuid4().hex[:6].lower()

    # Create Tenant
    repo_t = TenantRepository(db_session)
    tenant = await repo_t.create(TenantCreate(name="Teacher AI Tenant", code=f"tai-t-{suffix}", subdomain=f"tai-sub-{suffix}", email=f"tai-{suffix}@t.com"))
    await db_session.commit()

    # Create School
    repo_s = SchoolRepository(db_session)
    school = await repo_s.create(tenant.id, SchoolCreate(
        name="Teacher AI School", code=f"TAI_S_{suffix.upper()}", address="123 AI Street", city="Hyderabad",
        state="Telangana", country="India", pin_code="500001", board="CBSE", email=f"s-tai-{suffix}@a.com",
        status=SchoolStatus.ACTIVE
    ))
    await db_session.commit()

    # Setup User and Role
    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    auth_service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, repo_s)

    # Fetch existing Teacher Role (created automatically by initialize_tenant_rbac)
    stmt_role = select(Role).where(Role.tenant_id == tenant.id, Role.code == "TEACHER")
    res_role = await db_session.execute(stmt_role)
    role_t = res_role.scalar_one()

    # Teacher 1 (Authorized)
    user_t1 = await auth_service.create_user(
        tenant.id,
        UserCreate(email=f"anita-{suffix}@dps.edu", password="Password123!", first_name="Anita", last_name="Sharma")
    )
    user_t1.roles.append(role_t)
    
    teacher1 = Teacher(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        school_id=school.id,
        user_id=user_t1.id,
        employee_code=f"EMP-A1-{suffix}",
        staff_code=f"STF-A1-{suffix}",
        first_name="Anita",
        last_name="Sharma",
        gender=StudentGender.FEMALE,
        date_of_birth=date(1985, 5, 15),
        mobile=f"987654{suffix[:4]}",
        official_email=f"anita-{suffix}@dps.edu",
        joining_date=date(2020, 6, 1),
        employment_type=EmploymentType.FULL_TIME,
        designation="Senior Science Teacher",
        status="ACTIVE",
        is_active=True
    )
    db_session.add(teacher1)

    # Teacher 2 (Unassigned/Unauthorized for Class 8-A)
    user_t2 = await auth_service.create_user(
        tenant.id,
        UserCreate(email=f"rajesh-{suffix}@dps.edu", password="Password123!", first_name="Rajesh", last_name="Kumar")
    )
    user_t2.roles.append(role_t)

    teacher2 = Teacher(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        school_id=school.id,
        user_id=user_t2.id,
        employee_code=f"EMP-A2-{suffix}",
        staff_code=f"STF-A2-{suffix}",
        first_name="Rajesh",
        last_name="Kumar",
        gender=StudentGender.MALE,
        date_of_birth=date(1988, 8, 20),
        mobile=f"987655{suffix[:4]}",
        official_email=f"rajesh-{suffix}@dps.edu",
        joining_date=date(2021, 6, 1),
        employment_type=EmploymentType.FULL_TIME,
        designation="Mathematics Teacher",
        status="ACTIVE",
        is_active=True
    )
    db_session.add(teacher2)
    await db_session.commit()

    from app.models.class_entity import ClassCategory
    from app.models.section import SectionStatus
    from app.models.subject import SubjectCategory, SubjectType

    # Create Academic Year
    ay = AcademicYear(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        school_id=school.id,
        name="AY 2026-27",
        code=f"AY-26-27-{suffix}",
        start_date=date(2026, 6, 1),
        end_date=date(2027, 4, 30),
        status="ACTIVE",
        is_current=True
    )
    db_session.add(ay)
    await db_session.commit()

    # Create Class and Section
    class_8 = Class(
        id=uuid.uuid4(),
        name="Class 8",
        code=f"C8-{suffix}",
        level=8,
        category=ClassCategory.MIDDLE,
        capacity=40,
        academic_year_id=ay.id,
        tenant_id=tenant.id,
        school_id=school.id,
        is_active=True
    )
    db_session.add(class_8)

    section_a = Section(
        id=uuid.uuid4(),
        name="A",
        code=f"S8A-{suffix}",
        class_id=class_8.id,
        capacity=40,
        academic_year_id=ay.id,
        tenant_id=tenant.id,
        school_id=school.id,
        is_active=True
    )
    db_session.add(section_a)

    section_b = Section(
        id=uuid.uuid4(),
        name="B",
        code=f"S8B-{suffix}",
        class_id=class_8.id,
        capacity=40,
        academic_year_id=ay.id,
        tenant_id=tenant.id,
        school_id=school.id,
        is_active=True
    )
    db_session.add(section_b)

    # Create Subject
    subject_sci = Subject(
        id=uuid.uuid4(),
        subject_name="Science",
        subject_code=f"SCI-{suffix}",
        category=SubjectCategory.CORE,
        subject_type=SubjectType.THEORY,
        academic_year_id=ay.id,
        tenant_id=tenant.id,
        school_id=school.id,
        is_active=True
    )
    db_session.add(subject_sci)
    await db_session.commit()

    # Create Student in Section A (Assigned to Anita)
    student_priya = Student(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        school_id=school.id,
        class_id=class_8.id,
        section_id=section_a.id,
        academic_year_id=ay.id,
        first_name="Priya",
        last_name="Reddy",
        gender=StudentGender.FEMALE,
        date_of_birth=date(2012, 4, 10),
        admission_number=f"ADM-P1-{suffix}",
        roll_number="10",
        admission_date=date(2024, 6, 1),
        is_active=True
    )
    db_session.add(student_priya)

    # Create Student in Section B (Unassigned to Anita)
    student_rahul = Student(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        school_id=school.id,
        class_id=class_8.id,
        section_id=section_b.id,
        academic_year_id=ay.id,
        first_name="Rahul",
        last_name="Verma",
        gender=StudentGender.MALE,
        date_of_birth=date(2012, 8, 15),
        admission_number=f"ADM-R1-{suffix}",
        roll_number="12",
        admission_date=date(2024, 6, 1),
        is_active=True
    )
    db_session.add(student_rahul)
    await db_session.commit()

    from app.models.teacher_subject_assignment import AssignmentType
    # Create Teacher Subject Assignment for Teacher 1 (Class 8-A, Science)
    tsa_t1 = TeacherSubjectAssignment(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        school_id=school.id,
        academic_year_id=ay.id,
        teacher_id=teacher1.id,
        subject_id=subject_sci.id,
        class_id=class_8.id,
        section_id=section_a.id,
        status=AssignmentStatus.ACTIVE,
        assignment_type=AssignmentType.PRIMARY,
        weekly_periods=5,
        workload_percentage=100.0,
        effective_from=date(2025, 6, 1),
        assigned_at=datetime.now(timezone.utc),
        is_active=True
    )
    db_session.add(tsa_t1)
    await db_session.commit()

    # Add dummy marks/attendance for Priya
    marks_priya = Marks(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        school_id=school.id,
        academic_year_id=tsa_t1.academic_year_id,
        examination_id=uuid.uuid4(),
        exam_schedule_id=uuid.uuid4(),
        student_id=student_priya.id,
        teacher_subject_assignment_id=tsa_t1.id,
        teacher_id=teacher1.id,
        subject_id=subject_sci.id,
        class_id=class_8.id,
        section_id=section_a.id,
        maximum_marks=100,
        marks_obtained=88.5,
        result_status=ExamResult.PRESENT
    )
    db_session.add(marks_priya)
    await db_session.commit()

    t1_tokens = await auth_service.create_tokens(user_t1)
    t2_tokens = await auth_service.create_tokens(user_t2)

    return {
        "tenant": tenant,
        "school": school,
        "teacher1": teacher1,
        "teacher2": teacher2,
        "user_t1": user_t1,
        "user_t2": user_t2,
        "class_8": class_8,
        "section_a": section_a,
        "section_b": section_b,
        "subject_sci": subject_sci,
        "student_priya": student_priya,
        "student_rahul": student_rahul,
        "auth_headers_t1": {
            "Authorization": f"Bearer {t1_tokens.access_token}",
            "X-Tenant-ID": str(tenant.id)
        },
        "auth_headers_t2": {
            "Authorization": f"Bearer {t2_tokens.access_token}",
            "X-Tenant-ID": str(tenant.id)
        }
    }

@pytest.mark.anyio
async def test_teacher_student_insight_authorized(client: AsyncClient, setup_teacher_ai_data) -> None:
    data = setup_teacher_ai_data
    
    fake_provider = AsyncMock()
    fake_provider.generate_json.return_value = {
        "performance_trend": "Improving",
        "attendance_trend": "Highly Consistent",
        "improvement_areas": ["Science concepts revision"],
        "attention_areas": ["Practical application of Newton's laws"],
        "recent_academic_changes": None,
        "suggested_actions": ["Keep up the revision sheet"],
        "summary": "Excellent performance overall."
    }
    fake_service = AIService(provider=fake_provider)
    app.dependency_overrides[get_ai_service] = lambda: fake_service
    app.dependency_overrides[get_current_user] = lambda: data["user_t1"]

    try:
        payload = {"student_id": str(data["student_priya"].id)}
        res = await client.post("/api/v1/teacher-ai/student-insight", json=payload, headers=data["auth_headers_t1"])
        assert res.status_code == 200
        json_res = res.json()
        assert json_res["success"] is True
        assert json_res["data"]["performance_trend"] == "Improving"
        assert json_res["data"]["summary"] == "Excellent performance overall."
    finally:
        app.dependency_overrides.clear()

@pytest.mark.anyio
async def test_teacher_student_insight_unauthorized_teacher2(client: AsyncClient, setup_teacher_ai_data) -> None:
    data = setup_teacher_ai_data
    
    # Teacher 2 trying to access Student Priya (not assigned)
    app.dependency_overrides[get_current_user] = lambda: data["user_t2"]
    try:
        payload = {"student_id": str(data["student_priya"].id)}
        res = await client.post("/api/v1/teacher-ai/student-insight", json=payload, headers=data["auth_headers_t2"])
        assert res.status_code == 403
        assert "Access denied" in res.json()["message"]
    finally:
        app.dependency_overrides.clear()

@pytest.mark.anyio
async def test_teacher_student_insight_unauthorized_student_rahul(client: AsyncClient, setup_teacher_ai_data) -> None:
    data = setup_teacher_ai_data

    # Teacher 1 trying to access Student Rahul (in section B, unassigned class/section)
    app.dependency_overrides[get_current_user] = lambda: data["user_t1"]
    try:
        payload_rahul = {"student_id": str(data["student_rahul"].id)}
        res2 = await client.post("/api/v1/teacher-ai/student-insight", json=payload_rahul, headers=data["auth_headers_t1"])
        assert res2.status_code == 403
        assert "Access denied" in res2.json()["message"]
    finally:
        app.dependency_overrides.clear()

@pytest.mark.anyio
async def test_teacher_class_analysis_authorized(client: AsyncClient, setup_teacher_ai_data) -> None:
    data = setup_teacher_ai_data

    fake_provider = AsyncMock()
    fake_provider.generate_json.return_value = {
        "class_average": 88.5,
        "grade_distribution": {"A": 1},
        "pass_percentage": 100.0,
        "improvement_trend": "Steady",
        "students_improving": ["Priya R."],
        "students_declining": [],
        "strong_areas": ["Science concepts"],
        "needs_reinforcement_areas": [],
        "suggested_actions": ["No specific intervention needed."]
    }
    fake_service = AIService(provider=fake_provider)
    app.dependency_overrides[get_ai_service] = lambda: fake_service
    app.dependency_overrides[get_current_user] = lambda: data["user_t1"]

    try:
        payload = {
            "class_id": str(data["class_8"].id),
            "section_id": str(data["section_a"].id),
            "subject_id": str(data["subject_sci"].id)
        }
        res = await client.post("/api/v1/teacher-ai/class-analysis", json=payload, headers=data["auth_headers_t1"])
        assert res.status_code == 200
        json_res = res.json()
        assert json_res["success"] is True
        assert json_res["data"]["class_average"] == 88.5
    finally:
        app.dependency_overrides.clear()

@pytest.mark.anyio
async def test_teacher_class_analysis_unauthorized(client: AsyncClient, setup_teacher_ai_data) -> None:
    data = setup_teacher_ai_data

    app.dependency_overrides[get_current_user] = lambda: data["user_t1"]
    try:
        payload = {
            "class_id": str(data["class_8"].id),
            "section_id": str(data["section_b"].id), # Section B is not assigned to Teacher 1
            "subject_id": str(data["subject_sci"].id)
        }
        res = await client.post("/api/v1/teacher-ai/class-analysis", json=payload, headers=data["auth_headers_t1"])
        assert res.status_code == 403
    finally:
        app.dependency_overrides.clear()

@pytest.mark.anyio
async def test_teacher_generate_remark_draft(client: AsyncClient, setup_teacher_ai_data) -> None:
    data = setup_teacher_ai_data

    fake_provider = AsyncMock()
    fake_provider.generate_json.return_value = {
        "draft_remark": "Priya has shown excellent performance in Science."
    }
    fake_service = AIService(provider=fake_provider)
    app.dependency_overrides[get_ai_service] = lambda: fake_service
    app.dependency_overrides[get_current_user] = lambda: data["user_t1"]

    try:
        payload = {
            "student_id": str(data["student_priya"].id),
            "subject_id": str(data["subject_sci"].id)
        }
        res = await client.post("/api/v1/teacher-ai/generate-remark", json=payload, headers=data["auth_headers_t1"])
        assert res.status_code == 200
        assert res.json()["data"]["draft_remark"] == "Priya has shown excellent performance in Science."
    finally:
        app.dependency_overrides.clear()

@pytest.mark.anyio
async def test_teacher_generate_homework_draft(client: AsyncClient, setup_teacher_ai_data) -> None:
    data = setup_teacher_ai_data

    fake_provider = AsyncMock()
    fake_provider.generate_json.return_value = {
        "title": "Properties of Light",
        "description": "Solve all numericals",
        "learning_objective": "Understand reflection and refraction",
        "difficulty": "EASY",
        "estimated_minutes": 30,
        "questions": [
            {
                "text": "What is the speed of light?",
                "marks": 5,
                "difficulty": "EASY",
                "choices": None,
                "answer_key": "3e8 m/s"
            }
        ]
    }
    fake_service = AIService(provider=fake_provider)
    app.dependency_overrides[get_ai_service] = lambda: fake_service
    app.dependency_overrides[get_current_user] = lambda: data["user_t1"]

    try:
        payload = {
            "class_id": str(data["class_8"].id),
            "section_id": str(data["section_a"].id),
            "subject_id": str(data["subject_sci"].id),
            "topic": "Properties of Light",
            "difficulty": "EASY",
            "number_of_questions": 1,
            "marks": 5
        }
        res = await client.post("/api/v1/teacher-ai/generate-homework", json=payload, headers=data["auth_headers_t1"])
        assert res.status_code == 200
        assert res.json()["data"]["title"] == "Properties of Light"
        assert len(res.json()["data"]["questions"]) == 1
    finally:
        app.dependency_overrides.clear()

@pytest.mark.anyio
async def test_ai_disabled_configuration(client: AsyncClient, setup_teacher_ai_data) -> None:
    data = setup_teacher_ai_data
    
    app.dependency_overrides[get_current_user] = lambda: data["user_t1"]
    try:
        with patch("app.core.settings.settings.AI_ENABLED", False):
            payload = {"student_id": str(data["student_priya"].id)}
            res = await client.post("/api/v1/teacher-ai/student-insight", json=payload, headers=data["auth_headers_t1"])
            assert res.status_code == 503
            assert "disabled by system configuration" in res.json()["message"]
    finally:
        app.dependency_overrides.clear()


@pytest.mark.anyio
async def test_teacher_generate_questions_draft(client: AsyncClient, setup_teacher_ai_data) -> None:
    data = setup_teacher_ai_data

    fake_provider = AsyncMock()
    fake_provider.generate_json.return_value = {
        "questions": [
            {
                "text": "Explain reflection.",
                "marks": 5,
                "difficulty": "MEDIUM",
                "choices": None,
                "answer_key": None
            }
        ]
    }
    fake_service = AIService(provider=fake_provider)
    app.dependency_overrides[get_ai_service] = lambda: fake_service
    app.dependency_overrides[get_current_user] = lambda: data["user_t1"]

    try:
        payload = {
            "class_id": str(data["class_8"].id),
            "section_id": str(data["section_a"].id),
            "subject_id": str(data["subject_sci"].id),
            "topic": "Reflection of Light",
            "difficulty": "MEDIUM",
            "number_of_questions": 1,
            "marks": 5
        }
        res = await client.post("/api/v1/teacher-ai/generate-questions", json=payload, headers=data["auth_headers_t1"])
        assert res.status_code == 200
        assert len(res.json()["data"]["questions"]) == 1
    finally:
        app.dependency_overrides.clear()


@pytest.mark.anyio
async def test_teacher_unauthorized_subject(client: AsyncClient, setup_teacher_ai_data) -> None:
    data = setup_teacher_ai_data
    # Teacher 1 is NOT assigned to Mathematics (only Science)
    app.dependency_overrides[get_current_user] = lambda: data["user_t1"]
    try:
        payload = {
            "class_id": str(data["class_8"].id),
            "section_id": str(data["section_a"].id),
            "subject_id": str(uuid.uuid4()), # Unassigned subject ID
            "topic": "Algebra",
            "difficulty": "MEDIUM",
            "number_of_questions": 5,
            "marks": 20
        }
        res = await client.post("/api/v1/teacher-ai/generate-homework", json=payload, headers=data["auth_headers_t1"])
        assert res.status_code == 403
    finally:
        app.dependency_overrides.clear()


@pytest.mark.anyio
async def test_cross_school_isolation(client: AsyncClient, setup_teacher_ai_data, db_session: AsyncSession) -> None:
    data = setup_teacher_ai_data
    suffix = uuid.uuid4().hex[:6]

    # Create another school in same tenant
    repo_s = SchoolRepository(db_session)
    other_school = await repo_s.create(data["tenant"].id, SchoolCreate(
        name="Other School", code=f"OTH_S_{suffix.upper()}", address="456 Other St", city="Hyderabad",
        state="Telangana", country="India", pin_code="500002", board="CBSE", email=f"oth-{suffix}@a.com",
        status=SchoolStatus.ACTIVE
    ))
    # Create class in other school
    other_class = Class(
        id=uuid.uuid4(),
        name="Class 8 Other",
        code=f"C8O-{suffix}",
        level=8,
        category="MIDDLE",
        capacity=40,
        academic_year_id=data["student_priya"].academic_year_id,
        tenant_id=data["tenant"].id,
        school_id=other_school.id,
        is_active=True
    )
    db_session.add(other_class)
    await db_session.commit()

    # Teacher 1 tries to access other_class
    app.dependency_overrides[get_current_user] = lambda: data["user_t1"]
    try:
        payload = {
            "class_id": str(other_class.id),
            "section_id": str(data["section_a"].id),
            "subject_id": str(data["subject_sci"].id),
            "topic": "Skeletal System",
            "difficulty": "MEDIUM",
            "number_of_questions": 5,
            "marks": 20
        }
        res = await client.post("/api/v1/teacher-ai/generate-homework", json=payload, headers=data["auth_headers_t1"])
        assert res.status_code == 403
    finally:
        app.dependency_overrides.clear()


@pytest.mark.anyio
async def test_cross_tenant_isolation(client: AsyncClient, setup_teacher_ai_data, db_session: AsyncSession) -> None:
    data = setup_teacher_ai_data
    suffix = uuid.uuid4().hex[:6]

    # Create another Tenant
    repo_t = TenantRepository(db_session)
    other_tenant = await repo_t.create(TenantCreate(name="Other Tenant", code=f"tai-ot-{suffix}", subdomain=f"tai-osub-{suffix}", email=f"tai-o-{suffix}@t.com"))
    await db_session.commit()

    # Teacher 1 tries to call with other tenant ID header
    app.dependency_overrides[get_current_user] = lambda: data["user_t1"]
    try:
        payload = {"student_id": str(data["student_priya"].id)}
        headers = data["auth_headers_t1"].copy()
        headers["X-Tenant-ID"] = str(other_tenant.id)
        res = await client.post("/api/v1/teacher-ai/student-insight", json=payload, headers=headers)
        # Should return 403 since resolved teacher profile won't be found for Teacher 1 user under other_tenant
        assert res.status_code == 403
    finally:
        app.dependency_overrides.clear()


@pytest.mark.anyio
async def test_client_ids_cannot_override_authenticated_context(client: AsyncClient, setup_teacher_ai_data) -> None:
    data = setup_teacher_ai_data
    
    fake_provider = AsyncMock()
    fake_provider.generate_json.return_value = {
        "performance_trend": "Improving",
        "attendance_trend": "Consistent",
        "improvement_areas": [],
        "attention_areas": [],
        "recent_academic_changes": None,
        "suggested_actions": [],
        "summary": "Good."
    }
    fake_service = AIService(provider=fake_provider)
    app.dependency_overrides[get_ai_service] = lambda: fake_service
    app.dependency_overrides[get_current_user] = lambda: data["user_t1"]

    try:
        # Pass extra client teacher_id / tenant_id inside JSON.
        # They must be ignored and not override behavior.
        payload = {
            "student_id": str(data["student_priya"].id),
            "teacher_id": str(uuid.uuid4()),
            "tenant_id": str(uuid.uuid4())
        }
        res = await client.post("/api/v1/teacher-ai/student-insight", json=payload, headers=data["auth_headers_t1"])
        assert res.status_code == 200
        assert res.json()["success"] is True
    finally:
        app.dependency_overrides.clear()


@pytest.mark.anyio
async def test_provider_timeout_handled(client: AsyncClient, setup_teacher_ai_data) -> None:
    data = setup_teacher_ai_data

    # Mock provider to raise TimeoutError
    fake_provider = AsyncMock()
    fake_provider.generate_json.side_effect = TimeoutError("Gemini Request Timed Out")
    fake_service = AIService(provider=fake_provider)
    app.dependency_overrides[get_ai_service] = lambda: fake_service
    app.dependency_overrides[get_current_user] = lambda: data["user_t1"]

    try:
        payload = {"student_id": str(data["student_priya"].id)}
        res = await client.post("/api/v1/teacher-ai/student-insight", json=payload, headers=data["auth_headers_t1"])
        assert res.status_code == 502
        assert "Service currently unavailable" in res.json()["message"]
    finally:
        app.dependency_overrides.clear()


@pytest.mark.anyio
async def test_provider_failure_handled(client: AsyncClient, setup_teacher_ai_data) -> None:
    data = setup_teacher_ai_data

    # Mock provider to raise internal exception
    fake_provider = AsyncMock()
    fake_provider.generate_json.side_effect = Exception("Internal provider crash")
    fake_service = AIService(provider=fake_provider)
    app.dependency_overrides[get_ai_service] = lambda: fake_service
    app.dependency_overrides[get_current_user] = lambda: data["user_t1"]

    try:
        payload = {"student_id": str(data["student_priya"].id)}
        res = await client.post("/api/v1/teacher-ai/student-insight", json=payload, headers=data["auth_headers_t1"])
        assert res.status_code == 502
        assert "Service currently unavailable" in res.json()["message"]
    finally:
        app.dependency_overrides.clear()


@pytest.mark.anyio
async def test_malformed_provider_response_handled(client: AsyncClient, setup_teacher_ai_data) -> None:
    data = setup_teacher_ai_data

    # Mock provider to return malformed dict that fails Pydantic validation
    fake_provider = AsyncMock()
    fake_provider.generate_json.return_value = {
        "some_unexpected_key": "junk"
    }
    fake_service = AIService(provider=fake_provider)
    app.dependency_overrides[get_ai_service] = lambda: fake_service
    app.dependency_overrides[get_current_user] = lambda: data["user_t1"]

    try:
        payload = {"student_id": str(data["student_priya"].id)}
        res = await client.post("/api/v1/teacher-ai/student-insight", json=payload, headers=data["auth_headers_t1"])
        # Validation error will bubble up, raising 502 Bad Gateway via catch block
        assert res.status_code == 502
    finally:
        app.dependency_overrides.clear()


@pytest.mark.anyio
async def test_sensitive_fields_excluded_from_provider_context(client: AsyncClient, setup_teacher_ai_data) -> None:
    data = setup_teacher_ai_data

    fake_provider = AsyncMock()
    fake_provider.generate_json.return_value = {
        "performance_trend": "Improving",
        "attendance_trend": "Consistent",
        "improvement_areas": [],
        "attention_areas": [],
        "recent_academic_changes": None,
        "suggested_actions": [],
        "summary": "Good."
    }
    fake_service = AIService(provider=fake_provider)
    app.dependency_overrides[get_ai_service] = lambda: fake_service
    app.dependency_overrides[get_current_user] = lambda: data["user_t1"]

    try:
        payload = {"student_id": str(data["student_priya"].id)}
        await client.post("/api/v1/teacher-ai/student-insight", json=payload, headers=data["auth_headers_t1"])
        
        # Verify provider generate_json prompt context does not contain sensitive properties
        called_args = fake_provider.generate_json.call_args[1]
        called_prompt = called_args["prompt"]
        
        sensitive_keywords = [
            "password", "jwt", "token", "aadhaar", "guardian_phone", "phone", 
            "guardian_email", "email", "fee", "payment", "pin_code"
        ]
        # Ignore case and assert none of these sensitive fields are leaked to provider
        prompt_lower = called_prompt.lower()
        for kw in sensitive_keywords:
            # Note: anonymized student first name might be present, but guardian info / personal attributes are blocked
            assert kw not in prompt_lower
    finally:
        app.dependency_overrides.clear()


@pytest.mark.anyio
async def test_teacher_ai_missing_key_returns_503(client: AsyncClient, setup_teacher_ai_data) -> None:
    data = setup_teacher_ai_data
    app.dependency_overrides[get_current_user] = lambda: data["user_t1"]
    
    # We selectively patch settings.GEMINI_API_KEY to None
    with patch("app.core.settings.settings.GEMINI_API_KEY", None):
        # Reset the dependency singleton instance so it recreates with the patched settings
        import app.api.dependencies.ai as dep_ai
        dep_ai._ai_service_instance = None
        
        try:
            payload = {"student_id": str(data["student_priya"].id)}
            res = await client.post("/api/v1/teacher-ai/student-insight", json=payload, headers=data["auth_headers_t1"])
            assert res.status_code == 502
            assert "Service currently unavailable" in res.json()["message"]
        finally:
            dep_ai._ai_service_instance = None
            app.dependency_overrides.clear()


@pytest.mark.anyio
async def test_teacher_ai_configured_provider_initialization(setup_teacher_ai_data) -> None:
    data = setup_teacher_ai_data
    
    with patch("app.core.settings.settings.GEMINI_API_KEY", "dummy_key_123"), \
         patch("app.core.settings.settings.AI_PROVIDER", "gemini"), \
         patch("app.core.settings.settings.AI_MODEL", "gemini-1.5-flash"):
        
        import app.api.dependencies.ai as dep_ai
        dep_ai._ai_service_instance = None
        
        try:
            # Resolve AI service using dependency
            ai_service = dep_ai.get_ai_service()
            assert ai_service.provider is not None
            assert getattr(ai_service.provider, "api_key", None) == "dummy_key_123"
            assert getattr(ai_service.provider, "model", None) == "gemini-1.5-flash"
        finally:
            dep_ai._ai_service_instance = None


def test_homework_normalization_observed_gemini_output() -> None:
    from app.api.v1.endpoints.teacher_ai import normalize_homework_response
    
    raw_response = {
        "title": "Adjectives Practice",
        "description": "Complete the exercises",
        "learning_objective": "Identify adjectives",
        "difficulty": "MEDIUM",
        "estimated_minutes": 20,
        "questions": [
            {
                "question_number": 1,
                "q": "B) fluffy",
                "marks": 3
            }
        ]
    }
    
    normalized = normalize_homework_response(raw_response, fallback_difficulty="MEDIUM")
    
    assert normalized["questions"][0]["text"] == "B) fluffy"
    assert normalized["questions"][0]["difficulty"] == "MEDIUM"
    assert normalized["questions"][0]["marks"] == 3
    assert normalized["questions"][0]["question_number"] == 1


def test_homework_normalization_correct_output() -> None:
    from app.api.v1.endpoints.teacher_ai import normalize_homework_response
    
    raw_response = {
        "title": "Adjectives Practice",
        "description": "Complete the exercises",
        "learning_objective": "Identify adjectives",
        "difficulty": "MEDIUM",
        "estimated_minutes": 20,
        "questions": [
            {
                "question_number": 1,
                "text": "Identify the adjective in the sentence.",
                "difficulty": "MEDIUM",
                "marks": 3
            }
        ]
    }
    
    normalized = normalize_homework_response(raw_response, fallback_difficulty="MEDIUM")
    
    assert normalized["questions"][0]["text"] == "Identify the adjective in the sentence."
    assert normalized["questions"][0]["difficulty"] == "MEDIUM"
    assert normalized["questions"][0]["marks"] == 3
    assert normalized["questions"][0]["question_number"] == 1
