import pytest
import uuid
from datetime import date, time, datetime, timezone
from decimal import Decimal
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.models.role import Role
from app.models.permission import Permission
from app.models.student import Student
from app.models.class_entity import Class, ClassCategory
from app.models.section import Section
from app.models.teacher import Teacher, EmploymentType
from app.models.subject import Subject, SubjectCategory, SubjectType, SubjectStatus
from app.models.teacher_subject_assignment import TeacherSubjectAssignment, AssignmentStatus
from app.models.examination import Examination, ExamSchedule, ExamType, ExamStatus
from app.models.attendance import AttendanceSession, Attendance, AttendanceStatus
from app.models.report_card import ReportCardPublication, ReportCardStatus
from app.models.marks import Marks

from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.section import SectionRepository
from app.repositories.student import StudentRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.subject import SubjectRepository
from app.repositories.teacher_subject_assignment import TeacherSubjectAssignmentRepository
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
from app.services.auth import AuthService

from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate, SchoolStatus
from app.schemas.academic_year import AcademicYearCreate, AcademicYearStatus
from app.schemas.class_entity import ClassCreate
from app.schemas.section import SectionCreate
from app.schemas.student import StudentCreate, StudentGender
from app.schemas.teacher import TeacherCreate
from app.schemas.subject import SubjectCreate
from app.schemas.teacher_subject_assignment import TeacherSubjectAssignmentCreate
from app.schemas.auth import UserCreate

@pytest.fixture
async def setup_report_test_data(db_session: AsyncSession):
    suffix = uuid.uuid4().hex[:6].lower()

    # 1. Create Tenant
    repo_t = TenantRepository(db_session)
    tenant_a = await repo_t.create(TenantCreate(name="Report Tenant A", code=f"report-a-{suffix}", subdomain=f"report-a-{suffix}", email=f"a-{suffix}@t.com"))
    await db_session.commit()

    # 2. Create School
    repo_s = SchoolRepository(db_session)
    school_a = await repo_s.create(tenant_a.id, SchoolCreate(
        name="Report School A", code=f"RC_A_{suffix.upper()}", address="123 Street", city="Bangalore",
        state="Karnataka", country="India", pin_code="560001", board="CBSE", email=f"s-a-{suffix}@a.com",
        status=SchoolStatus.ACTIVE
    ))
    
    school_a.settings = {
        "grade_policy": [
            {"grade": "A+", "min_percentage": 90, "max_percentage": 100},
            {"grade": "A", "min_percentage": 80, "max_percentage": 89.99},
            {"grade": "B", "min_percentage": 70, "max_percentage": 79.99},
            {"grade": "C", "min_percentage": 60, "max_percentage": 69.99},
            {"grade": "D", "min_percentage": 50, "max_percentage": 59.99},
            {"grade": "E", "min_percentage": 35, "max_percentage": 49.99},
            {"grade": "F", "min_percentage": 0, "max_percentage": 34.99}
        ],
        "promotion_policy": {
            "min_attendance_pct": 75.0,
            "min_overall_pct": 35.0,
            "max_failed_subjects": 0
        }
    }
    db_session.add(school_a)
    await db_session.commit()

    # 3. Academic Year
    repo_ay = AcademicYearRepository(db_session)
    ay_a = await repo_ay.create(tenant_a.id, school_a.id, AcademicYearCreate(school_id=school_a.id, name="Year 2026", code="AY2026", start_date=date(2026, 1, 1), end_date=date(2026, 12, 31), status=AcademicYearStatus.ACTIVE, is_current=True))
    ay_a.status = AcademicYearStatus.ACTIVE
    await db_session.commit()

    # 4. Classes & Sections
    repo_c = ClassRepository(db_session)
    class_a = await repo_c.create(tenant_a.id, ClassCreate(school_id=school_a.id, academic_year_id=ay_a.id, name="Grade 8", code="G8", level=8, category=ClassCategory.MIDDLE, capacity=35))
    await db_session.commit()

    repo_sec = SectionRepository(db_session)
    sec_a1 = await repo_sec.create(tenant_a.id, SectionCreate(school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_a.id, name="Section A1", code="SEC_A1", capacity=35))
    await db_session.commit()

    # 5. Students
    repo_stud = StudentRepository(db_session)
    stud1 = await repo_stud.create(tenant_a.id, StudentCreate(school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_a.id, section_id=sec_a1.id, admission_number="ADM-1", first_name="Albert", last_name="Einstein", gender=StudentGender.MALE, date_of_birth=date(2012, 3, 14), roll_number="10", admission_date=date(2026, 1, 1)))
    await db_session.commit()

    # 6. Teacher & Subject
    repo_tchr = TeacherRepository(db_session)
    teacher_a = await repo_tchr.create(tenant_a.id, TeacherCreate(school_id=school_a.id, employee_code=f"EMP-A-{suffix}", staff_code=f"STF-A-{suffix}", first_name="John", last_name="Doe", gender=StudentGender.MALE, date_of_birth=date(1985, 5, 20), mobile=f"+91987654{suffix[:4]}", official_email=f"teacher-a-{suffix}@edu.com", joining_date=date(2025, 1, 1), employment_type=EmploymentType.FULL_TIME))
    await db_session.commit()

    repo_sub = SubjectRepository(db_session)
    subject_a = await repo_sub.create(tenant_a.id, SubjectCreate(school_id=school_a.id, academic_year_id=ay_a.id, subject_code=f"MATH-{suffix.upper()}", subject_name="Mathematics", category=SubjectCategory.CORE, subject_type=SubjectType.THEORY))
    subject_a.status = SubjectStatus.ACTIVE
    await db_session.commit()

    # 7. Assignment
    repo_tsa = TeacherSubjectAssignmentRepository(db_session)
    tsa_a = await repo_tsa.create(tenant_a.id, TeacherSubjectAssignmentCreate(school_id=school_a.id, academic_year_id=ay_a.id, teacher_id=teacher_a.id, subject_id=subject_a.id, class_id=class_a.id, section_id=sec_a1.id, assignment_type="PRIMARY", weekly_periods=5, effective_from=date(2026, 1, 1)))
    tsa_a.status = AssignmentStatus.ACTIVE
    tsa_a.is_active = True
    await db_session.commit()

    # 8. Examination & Schedule
    exam = Examination(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        exam_name="Quarterly Exam 2026",
        exam_type=ExamType.QUARTERLY,
        start_date=date(2026, 9, 1),
        end_date=date(2026, 9, 10),
        status=ExamStatus.PUBLISHED,
        created_by=uuid.uuid4(),
        updated_by=uuid.uuid4()
    )
    db_session.add(exam)
    await db_session.flush()

    sched = ExamSchedule(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        exam_id=exam.id,
        class_id=class_a.id,
        section_id=sec_a1.id,
        subject_id=subject_a.id,
        teacher_subject_assignment_id=tsa_a.id,
        exam_date=date(2026, 9, 2),
        start_time=time(9, 0),
        end_time=time(12, 0),
        max_marks=100,
        pass_marks=35,
        room_number="Room 101",
        created_by=uuid.uuid4(),
        updated_by=uuid.uuid4()
    )
    db_session.add(sched)
    await db_session.commit()

    # 9. Timetable & Attendance Session & Logs
    from app.repositories.timetable import TimetableRepository
    from app.schemas.timetable import TimetableCreate
    repo_tt = TimetableRepository(db_session)
    tt_a = await repo_tt.create(tenant_a.id, TimetableCreate(
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        teacher_subject_assignment_id=tsa_a.id,
        class_id=class_a.id,
        section_id=sec_a1.id,
        day_of_week="MONDAY",
        period_number=1,
        start_time="08:30:00",
        end_time="09:15:00",
        period_type="REGULAR"
    ))
    tt_a.teacher_id = teacher_a.id
    tt_a.subject_id = subject_a.id
    await db_session.commit()

    sess1 = AttendanceSession(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        class_id=class_a.id,
        section_id=sec_a1.id,
        timetable_id=tt_a.id,
        attendance_date=date(2026, 3, 2),
        teacher_id=teacher_a.id,
        subject_id=subject_a.id
    )
    db_session.add(sess1)
    await db_session.flush()

    att1 = Attendance(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        class_id=class_a.id,
        section_id=sec_a1.id,
        attendance_session_id=sess1.id,
        student_id=stud1.id,
        timetable_id=tt_a.id,
        attendance_date=date(2026, 3, 2),
        attendance_status=AttendanceStatus.PRESENT,
        teacher_id=teacher_a.id,
        subject_id=subject_a.id,
        remarks="Early",
        created_by=uuid.uuid4(),
        updated_by=uuid.uuid4()
    )
    db_session.add(att1)
    await db_session.commit()

    # User Setup
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

    user_admin = await auth_service.create_user(
        tenant_a.id,
        UserCreate(email=f"admin-{suffix}@a.com", password="Password123!", first_name="School", last_name="Admin")
    )
    user_admin.roles.append(role_a)
    await db_session.commit()

    tokens_a = await auth_service.create_tokens(user_admin)

    return {
        "tenant_a": tenant_a,
        "school_a": school_a,
        "ay_a": ay_a,
        "class_a": class_a,
        "sec_a1": sec_a1,
        "teacher_a": teacher_a,
        "subject_a": subject_a,
        "tsa_a": tsa_a,
        "stud1": stud1,
        "exam": exam,
        "sched": sched,
        "sess1": sess1,
        "att1": att1,
        "user_admin": user_admin,
        "auth_headers": {
            "Authorization": f"Bearer {tokens_a.access_token}",
            "X-Tenant-ID": str(tenant_a.id)
        }
    }

@pytest.mark.anyio
async def test_reports_endpoints_isolated(client: AsyncClient, setup_report_test_data, db_session: AsyncSession) -> None:
    data = setup_report_test_data
    tenant_id = data["tenant_a"].id
    school_id = data["school_a"].id
    headers = {**data["auth_headers"], "X-School-ID": str(school_id)}

    # 1. Test Dashboard Endpoint
    resp = await client.get("/api/v1/reports/dashboard", headers=headers)
    assert resp.status_code == 200
    res_data = resp.json()["data"]
    assert "total_students" in res_data
    assert "active_teachers" in res_data
    assert "average_academic_performance" in res_data
    assert "fee_collection_percentage" in res_data

    # 2. Test Academic Endpoint
    resp_acad = await client.get("/api/v1/reports/academic", headers=headers)
    assert resp_acad.status_code == 200
    res_acad = resp_acad.json()["data"]
    assert "average_percentage" in res_acad
    assert "grade_distribution" in res_acad

    # 3. Test Examinations Endpoint
    resp_ex = await client.get("/api/v1/reports/examinations", headers=headers)
    assert resp_ex.status_code == 200
    assert isinstance(resp_ex.json()["data"], list)

    # 4. Test Attendance Endpoint
    resp_att = await client.get("/api/v1/reports/attendance", headers=headers)
    assert resp_att.status_code == 200
    res_att = resp_att.json()["data"]
    assert "overall_attendance" in res_att
    assert "low_attendance_students" in res_att

    # 5. Test Fees Endpoint
    resp_fee = await client.get("/api/v1/reports/fees", headers=headers)
    assert resp_fee.status_code == 200
    res_fee = resp_fee.json()["data"]
    assert "total_assigned" in res_fee
    assert "total_collected" in res_fee

    # 6. Test AI Intelligence Endpoint
    resp_ai = await client.get("/api/v1/reports/ai-intelligence", headers=headers)
    assert resp_ai.status_code == 200
    res_ai = resp_ai.json()["data"]
    assert "high_risk_students" in res_ai
    assert "improving_students" in res_ai


@pytest.mark.anyio
async def test_reports_isolation_and_rbac(client: AsyncClient, setup_report_test_data, db_session: AsyncSession) -> None:
    data = setup_report_test_data
    tenant_id = data["tenant_a"].id
    school_id = data["school_a"].id

    # Create user with no reports permissions
    stmt_p = select(Permission).where(Permission.code.in_(["school.read"]))
    res_p = await db_session.execute(stmt_p)
    school_perms = list(res_p.scalars().all())

    repo_user = UserRepository(db_session)
    repo_role = RoleRepository(db_session)
    repo_perm = PermissionRepository(db_session)
    repo_refresh = RefreshTokenRepository(db_session)
    repo_school = SchoolRepository(db_session)
    auth_s = AuthService(repo_user, repo_role, repo_perm, repo_refresh, repo_school)

    low_role = Role(name="Low Permission", code="LOW_PERM", is_system=False, tenant_id=tenant_id)
    low_role.permissions = school_perms
    db_session.add(low_role)
    await db_session.commit()

    user_low = await auth_s.create_user(tenant_id, UserCreate(email="low@edu.com", password="SecurePassword123!", first_name="Low", last_name="User"))
    user_low.roles = [low_role]
    db_session.add(user_low)
    await db_session.commit()

    token_low = await auth_s.create_tokens(user_low)
    headers_low = {"Authorization": f"Bearer {token_low.access_token}", "X-Tenant-ID": str(tenant_id), "X-School-ID": str(school_id)}

    # Verify that user without reports.read permission is blocked (RBAC)
    resp = await client.get("/api/v1/reports/dashboard", headers=headers_low)
    assert resp.status_code == 403


@pytest.mark.anyio
async def test_reports_drilldowns(client: AsyncClient, setup_report_test_data, db_session: AsyncSession) -> None:
    data = setup_report_test_data
    tenant_id = data["tenant_a"].id
    school_id = data["school_a"].id
    headers = {**data["auth_headers"], "X-School-ID": str(school_id)}

    # 1. Test Students reports drill-down endpoint
    resp = await client.get("/api/v1/reports/students", headers=headers)
    assert resp.status_code == 200
    res_data = resp.json()["data"]
    assert isinstance(res_data, list)
    if len(res_data) > 0:
        student = res_data[0]
        assert "student_id" in student
        assert "student_name" in student
        assert "attendance_percentage" in student
        assert "academic_percentage" in student
        assert "grade" in student

    # 2. Test Teachers reports drill-down endpoint
    resp_t = await client.get("/api/v1/reports/teachers", headers=headers)
    assert resp_t.status_code == 200
    res_t = resp_t.json()["data"]
    assert isinstance(res_t, list)
    if len(res_t) > 0:
        teacher = res_t[0]
        assert "teacher_id" in teacher
        assert "teacher_name" in teacher
        assert "subjects" in teacher
        assert "status" in teacher

    # 3. Test Classes/Sections reports drill-down endpoint
    resp_c = await client.get("/api/v1/reports/classes", headers=headers)
    assert resp_c.status_code == 200
    res_c = resp_c.json()["data"]
    assert isinstance(res_c, list)
    if len(res_c) > 0:
        cls = res_c[0]
        assert "class_id" in cls
        assert "class_name" in cls
        assert "sections" in cls
        assert "academic_percentage" in cls
        if len(cls["sections"]) > 0:
            sec = cls["sections"][0]
            assert "section_id" in sec
            assert "section_name" in sec
            assert "academic_percentage" in sec

    # 4. Verify Academic extended data
    resp_acad = await client.get("/api/v1/reports/academic", headers=headers)
    assert resp_acad.status_code == 200
    res_acad = resp_acad.json()["data"]
    assert "subject_performance" in res_acad
    assert "student_performance" in res_acad

    # 5. Verify Fees extended data
    resp_fee = await client.get("/api/v1/reports/fees", headers=headers)
    assert resp_fee.status_code == 200
    res_fee = resp_fee.json()["data"]
    assert "student_fees" in res_fee

    # 6. Verify AI extended data
    resp_ai = await client.get("/api/v1/reports/ai-intelligence", headers=headers)
    assert resp_ai.status_code == 200
    res_ai = resp_ai.json()["data"]
    if len(res_ai["high_risk_students"]) > 0:
        student_ai = res_ai["high_risk_students"][0]
        assert "attendance_trend" in student_ai
        assert "weak_subjects" in student_ai


@pytest.mark.anyio
async def test_tenant_analytics_overview(client: AsyncClient, setup_report_test_data, db_session: AsyncSession) -> None:
    from app.models.role import Role
    from app.core.security import hash_password
    from app.models.user import User
    import uuid

    data = setup_report_test_data
    tenant_a = data["tenant_a"]
    headers = data["auth_headers"]

    resp = await client.get("/api/v1/reports/tenant/overview", headers=headers)
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["tenant_id"] == str(tenant_a.id)
    assert data["total_schools"] >= 1
    assert len(data["schools"]) >= 1
    assert "overall_attendance" in data
    assert "fee_collection_percentage" in data

    # 2. Block principal/teacher without tenant roles (RBAC check)
    # Fetch existing Principal role under tenant_a (created automatically by TenantRepository)
    stmt_role = select(Role).where(Role.tenant_id == tenant_a.id, Role.code == "PRINCIPAL")
    res_role = await db_session.execute(stmt_role)
    principal_role = res_role.scalar_one()

    principal_user = User(
        email="principal_test@example.com",
        hashed_password=hash_password("Password@123"),
        first_name="Principal",
        last_name="Test",
        tenant_id=tenant_a.id,
        status="ACTIVE"
    )
    principal_user.roles.append(principal_role)
    db_session.add(principal_user)
    await db_session.commit()

    # Log in principal user to get token
    login_resp = await client.post(
        f"/api/v1/auth/login",
        json={"email": "principal_test@example.com", "password": "Password@123"},
        headers={"X-Tenant-ID": str(tenant_a.id)}
    )
    assert login_resp.status_code == 200
    p_token = login_resp.json()["data"]["access_token"]

    headers_p = {
        "X-Tenant-ID": str(tenant_a.id),
        "Authorization": f"Bearer {p_token}"
    }

    resp_p = await client.get("/api/v1/reports/tenant/overview", headers=headers_p)
    assert resp_p.status_code == 403
    assert "Access denied" in resp_p.json()["message"]
