import uuid
import pytest
from datetime import date, datetime, timezone
from httpx import AsyncClient
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import status

from app.main import app
from app.models.tenant import Tenant
from app.models.school import School
from app.models.academic_year import AcademicYear
from app.models.class_entity import Class
from app.models.section import Section
from app.models.student import Student, StudentStatus
from app.models.subject import Subject
from app.models.teacher import Teacher
from app.models.teacher_subject_assignment import TeacherSubjectAssignment
from app.models.examination import Examination, ExamSchedule
from app.models.timetable import Timetable
from app.models.attendance import AttendanceSession
from app.models.homework import Homework, HomeworkStatus, HomeworkPriority
from app.models.user import User, UserStatus
from app.models.role import Role
from app.models.permission import Permission

from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.section import SectionRepository
from app.repositories.student import StudentRepository
from app.repositories.subject import SubjectRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.teacher_subject_assignment import TeacherSubjectAssignmentRepository
from app.repositories.examination import ExaminationRepository
from app.repositories.timetable import TimetableRepository
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository

from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate
from app.schemas.academic_year import AcademicYearCreate
from app.schemas.class_entity import ClassCreate
from app.schemas.section import SectionCreate
from app.schemas.student import StudentCreate
from app.schemas.subject import SubjectCreate
from app.schemas.teacher import TeacherCreate
from app.schemas.teacher_subject_assignment import TeacherSubjectAssignmentCreate
from app.schemas.examination import ExaminationCreate, ExamScheduleCreate
from app.schemas.timetable import TimetableCreate
from app.schemas.auth import UserCreate
from app.schemas.marks import BulkMarksEntry
from app.schemas.attendance import BulkAttendanceMark, StudentAttendanceRecord, AttendanceSessionCreate, AttendanceCorrectionUpdate
from app.schemas.homework import HomeworkCreate, HomeworkUpdate, HomeworkCopyRequest

from app.services.auth import AuthService
from app.api.dependencies.auth import get_current_user

@pytest.fixture
async def setup_boundary_data(db_session: AsyncSession):
    suffix = uuid.uuid4().hex[:6].upper()
    repo_t = TenantRepository(db_session)
    tenant_a = await repo_t.create(TenantCreate(
        name="Tenant A", code=f"t-a-{suffix.lower()}", 
        subdomain=f"t-a-{suffix.lower()}", email=f"a-{suffix.lower()}@t.com"
    ))
    tenant_b = await repo_t.create(TenantCreate(
        name="Tenant B", code=f"t-b-{suffix.lower()}", 
        subdomain=f"t-b-{suffix.lower()}", email=f"b-{suffix.lower()}@t.com"
    ))

    repo_s = SchoolRepository(db_session)
    school_a = await repo_s.create(tenant_a.id, SchoolCreate(
        name="School A", code=f"SCH_A_{suffix}", board="CBSE", email=f"s-a-{suffix.lower()}@a.com"
    ))
    # Configure School A geofence for staff attendance
    school_a.latitude = 17.4485
    school_a.longitude = 78.3741
    school_a.geofence_radius_meters = 100
    db_session.add(school_a)

    school_b = await repo_s.create(tenant_a.id, SchoolCreate(
        name="School B", code=f"SCH_B_{suffix}", board="CBSE", email=f"s-b-{suffix.lower()}@b.com"
    ))
    school_cross = await repo_s.create(tenant_b.id, SchoolCreate(
        name="School Cross", code=f"SCH_C_{suffix}", board="CBSE", email=f"s-c-{suffix.lower()}@b.com"
    ))
    await db_session.commit()

    repo_ay = AcademicYearRepository(db_session)
    ay_a = await repo_ay.create(tenant_a.id, school_a.id, AcademicYearCreate(
        name="2026-2027", code="AY2026-2027", start_date="2026-06-01", end_date="2027-04-30"
    ))
    ay_cross = await repo_ay.create(tenant_b.id, school_cross.id, AcademicYearCreate(
        name="2026-2027", code="AY2026-2027", start_date="2026-06-01", end_date="2027-04-30"
    ))

    repo_c = ClassRepository(db_session)
    from app.models.class_entity import ClassCategory
    class_a = await repo_c.create(tenant_a.id, ClassCreate(
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        name="Class 10",
        code=f"C10_{suffix}",
        level=10,
        category=ClassCategory.HIGH,
        capacity=30
    ))
    class_cross = await repo_c.create(tenant_b.id, ClassCreate(
        school_id=school_cross.id,
        academic_year_id=ay_cross.id,
        name="Class 10",
        code=f"C10C_{suffix}",
        level=10,
        category=ClassCategory.HIGH,
        capacity=30
    ))
    await db_session.flush()

    repo_sec = SectionRepository(db_session)
    sec_a = await repo_sec.create(tenant_a.id, SectionCreate(
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        class_id=class_a.id,
        name="Section A",
        code=f"SEC_A_{suffix}",
        capacity=30
    ))
    sec_b = await repo_sec.create(tenant_a.id, SectionCreate(
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        class_id=class_a.id,
        name="Section B",
        code=f"SEC_B_{suffix}",
        capacity=30
    ))
    sec_cross = await repo_sec.create(tenant_b.id, SectionCreate(
        school_id=school_cross.id,
        academic_year_id=ay_cross.id,
        class_id=class_cross.id,
        name="Section C",
        code=f"SEC_C_{suffix}",
        capacity=30
    ))

    repo_sub = SubjectRepository(db_session)
    sub_math = await repo_sub.create(tenant_a.id, SubjectCreate(
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        subject_name="Mathematics",
        subject_code=f"MATH_{suffix}",
        category="CORE",
        subject_type="THEORY"
    ))
    sub_cross = await repo_sub.create(tenant_b.id, SubjectCreate(
        school_id=school_cross.id,
        academic_year_id=ay_cross.id,
        subject_name="Mathematics",
        subject_code=f"MATHC_{suffix}",
        category="CORE",
        subject_type="THEORY"
    ))

    # Seed Permissions
    stmt_p = select(Permission)
    res_p = await db_session.execute(stmt_p)
    all_perms = list(res_p.scalars().all())

    # Roles
    role_teacher = Role(name="Teacher Role", code="TEACHER", is_system=True, tenant_id=tenant_a.id)
    teacher_perms = [
        "student.read", "teacher_subject_assignment.read", "marks.read", "marks.create", 
        "marks.update", "marks.delete", "marks.publish", "attendance.read", "attendance.create", 
        "attendance.update", "homework.read", "homework.create", "homework.update", "homework.delete",
        "staff_attendance.read", "staff_attendance.create", "staff_attendance.update"
    ]
    role_teacher.permissions = [p for p in all_perms if p.code in teacher_perms]
    db_session.add(role_teacher)
    await db_session.commit()

    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    auth_service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, repo_s)

    # Teacher A User & Profile
    user_tea_a = await auth_service.create_user(tenant_a.id, UserCreate(email=f"teacher.a.{suffix}@a.com", password="Password123!", first_name="Teacher", last_name="A"))
    user_tea_a.roles.append(role_teacher)
    user_tea_a.status = UserStatus.ACTIVE
    db_session.add(user_tea_a)
    await db_session.execute(text("INSERT INTO school_users (user_id, school_id) VALUES (:u, :s)"), {"u": str(user_tea_a.id), "s": str(school_a.id)})

    # Teacher B User & Profile
    user_tea_b = await auth_service.create_user(tenant_a.id, UserCreate(email=f"teacher.b.{suffix}@a.com", password="Password123!", first_name="Teacher", last_name="B"))
    user_tea_b.roles.append(role_teacher)
    user_tea_b.status = UserStatus.ACTIVE
    db_session.add(user_tea_b)
    await db_session.execute(text("INSERT INTO school_users (user_id, school_id) VALUES (:u, :s)"), {"u": str(user_tea_b.id), "s": str(school_a.id)})

    await db_session.commit()

    # Profiles
    teacher_repo = TeacherRepository(db_session)
    profile_tea_a = await teacher_repo.create(tenant_a.id, TeacherCreate(
        employee_code=f"EMPA_{suffix}", staff_code=f"STFA_{suffix}", first_name="Teacher", last_name="A",
        gender="MALE", date_of_birth="1980-01-01", official_email=user_tea_a.email, mobile="9876543210",
        joining_date="2020-01-01", designation="Math Teacher", school_id=school_a.id, employment_type="FULL_TIME"
    ))
    profile_tea_b = await teacher_repo.create(tenant_a.id, TeacherCreate(
        employee_code=f"EMPB_{suffix}", staff_code=f"STFB_{suffix}", first_name="Teacher", last_name="B",
        gender="MALE", date_of_birth="1980-01-01", official_email=user_tea_b.email, mobile="9876543211",
        joining_date="2020-01-01", designation="Math Teacher", school_id=school_a.id, employment_type="FULL_TIME"
    ))
    profile_tea_a.user_id = user_tea_a.id
    profile_tea_b.user_id = user_tea_b.id
    await db_session.flush()

    # TSA assignments
    tsa_repo = TeacherSubjectAssignmentRepository(db_session)
    tsa_a = await tsa_repo.create(tenant_a.id, TeacherSubjectAssignmentCreate(
        school_id=school_a.id, academic_year_id=ay_a.id, teacher_id=profile_tea_a.id,
        subject_id=sub_math.id, class_id=class_a.id, section_id=sec_a.id, is_class_teacher=True,
        assignment_type="PRIMARY", weekly_periods=5, effective_from=date(2026, 1, 1)
    ))
    tsa_b = await tsa_repo.create(tenant_a.id, TeacherSubjectAssignmentCreate(
        school_id=school_a.id, academic_year_id=ay_a.id, teacher_id=profile_tea_b.id,
        subject_id=sub_math.id, class_id=class_a.id, section_id=sec_b.id, is_class_teacher=True,
        assignment_type="PRIMARY", weekly_periods=5, effective_from=date(2026, 1, 1)
    ))
    tsa_a.status = "ACTIVE"
    tsa_a.is_active = True
    tsa_b.status = "ACTIVE"
    tsa_b.is_active = True
    await db_session.flush()

    # Students
    student_repo = StudentRepository(db_session)
    student_a = await student_repo.create(tenant_a.id, StudentCreate(
        school_id=school_a.id,
        first_name="Student", last_name="A", gender="MALE", date_of_birth="2010-01-01",
        admission_number=f"ADM_A_{suffix}", roll_number="1", email=f"stud.a.{suffix}@a.com",
        academic_year_id=ay_a.id, class_id=class_a.id, section_id=sec_a.id,
        admission_date="2026-06-01"
    ))
    student_b = await student_repo.create(tenant_a.id, StudentCreate(
        school_id=school_a.id,
        first_name="Student", last_name="B", gender="MALE", date_of_birth="2010-01-01",
        admission_number=f"ADM_B_{suffix}", roll_number="2", email=f"stud.b.{suffix}@a.com",
        academic_year_id=ay_a.id, class_id=class_a.id, section_id=sec_b.id,
        admission_date="2026-06-01"
    ))
    student_cross = await student_repo.create(tenant_b.id, StudentCreate(
        school_id=school_cross.id,
        first_name="Student", last_name="C", gender="MALE", date_of_birth="2010-01-01",
        admission_number=f"ADM_C_{suffix}", roll_number="3", email=f"stud.c.{suffix}@b.com",
        academic_year_id=ay_cross.id, class_id=class_cross.id, section_id=sec_cross.id,
        admission_date="2026-06-01"
    ))

    # Examinations & Schedules
    from app.models.examination import ExamStatus, ExamType
    from datetime import time
    exam_a = Examination(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        exam_name="Term 1",
        exam_type=ExamType.HALF_YEARLY,
        start_date=date(2026, 9, 1),
        end_date=date(2026, 9, 10),
        status=ExamStatus.PUBLISHED,
        created_by=uuid.uuid4(),
        updated_by=uuid.uuid4()
    )
    db_session.add(exam_a)
    await db_session.flush()

    exam_sched_a = ExamSchedule(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        exam_id=exam_a.id,
        class_id=class_a.id,
        section_id=sec_a.id,
        subject_id=sub_math.id,
        teacher_subject_assignment_id=tsa_a.id,
        exam_date=date(2026, 9, 1),
        start_time=time(9, 0, 0),
        end_time=time(12, 0, 0),
        max_marks=100.0,
        pass_marks=35.0,
        created_by=uuid.uuid4(),
        updated_by=uuid.uuid4()
    )
    exam_sched_b = ExamSchedule(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        exam_id=exam_a.id,
        class_id=class_a.id,
        section_id=sec_b.id,
        subject_id=sub_math.id,
        teacher_subject_assignment_id=tsa_b.id,
        exam_date=date(2026, 9, 1),
        start_time=time(9, 0, 0),
        end_time=time(12, 0, 0),
        max_marks=100.0,
        pass_marks=35.0,
        created_by=uuid.uuid4(),
        updated_by=uuid.uuid4()
    )
    db_session.add(exam_sched_a)
    db_session.add(exam_sched_b)
    await db_session.flush()

    # Timetable
    repo_tt = TimetableRepository(db_session)
    tt_a = await repo_tt.create(tenant_a.id, TimetableCreate(
        school_id=school_a.id, academic_year_id=ay_a.id, teacher_subject_assignment_id=tsa_a.id,
        class_id=class_a.id, section_id=sec_a.id, day_of_week="MONDAY", period_number=1,
        start_time="08:30:00", end_time="09:15:00", period_type="REGULAR"
    ), teacher_id=profile_tea_a.id, subject_id=sub_math.id)
    tt_b = await repo_tt.create(tenant_a.id, TimetableCreate(
        school_id=school_a.id, academic_year_id=ay_a.id, teacher_subject_assignment_id=tsa_b.id,
        class_id=class_a.id, section_id=sec_b.id, day_of_week="MONDAY", period_number=1,
        start_time="08:30:00", end_time="09:15:00", period_type="REGULAR"
    ), teacher_id=profile_tea_b.id, subject_id=sub_math.id)

    await db_session.flush()
    await db_session.commit()

    return {
        "tenant_a": tenant_a,
        "tenant_b": tenant_b,
        "school_a": school_a,
        "school_cross": school_cross,
        "user_tea_a": user_tea_a,
        "user_tea_b": user_tea_b,
        "profile_tea_a": profile_tea_a,
        "profile_tea_b": profile_tea_b,
        "student_a": student_a,
        "student_b": student_b,
        "student_cross": student_cross,
        "tsa_a": tsa_a,
        "tsa_b": tsa_b,
        "exam_sched_a": exam_sched_a,
        "exam_sched_b": exam_sched_b,
        "tt_a": tt_a,
        "tt_b": tt_b,
        "class_a": class_a,
        "sec_a": sec_a,
        "sub_math": sub_math
    }


# =====================================================================
# STUDENTS BOUNDARY TESTS
# =====================================================================

@pytest.mark.anyio
async def test_teacher_get_assigned_student_success(client: AsyncClient, setup_boundary_data):
    data = setup_boundary_data
    app.dependency_overrides[get_current_user] = lambda: data["user_tea_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    response = await client.get(
        f"/api/v1/students/{data['student_a'].id}?school_id={data['school_a'].id}",
        headers=headers
    )
    assert response.status_code == status.HTTP_200_OK
    assert response.json()["success"] is True

@pytest.mark.anyio
async def test_teacher_get_unassigned_student_forbidden(client: AsyncClient, setup_boundary_data):
    data = setup_boundary_data
    app.dependency_overrides[get_current_user] = lambda: data["user_tea_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    # Student B belongs to Section B (assigned to Teacher B, not Teacher A)
    response = await client.get(
        f"/api/v1/students/{data['student_b'].id}?school_id={data['school_a'].id}",
        headers=headers
    )
    assert response.status_code == status.HTTP_403_FORBIDDEN

@pytest.mark.anyio
async def test_teacher_get_cross_tenant_student_not_found_or_forbidden(client: AsyncClient, setup_boundary_data):
    data = setup_boundary_data
    app.dependency_overrides[get_current_user] = lambda: data["user_tea_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    response = await client.get(
        f"/api/v1/students/{data['student_cross'].id}?school_id={data['school_cross'].id}",
        headers=headers
    )
    # Different tenant/school should be NOT FOUND (404) or FORBIDDEN (403)
    assert response.status_code in [status.HTTP_404_NOT_FOUND, status.HTTP_403_FORBIDDEN]


# =====================================================================
# ASSIGNMENTS BOUNDARY TESTS
# =====================================================================

@pytest.mark.anyio
async def test_teacher_list_own_assignments_only(client: AsyncClient, setup_boundary_data):
    data = setup_boundary_data
    app.dependency_overrides[get_current_user] = lambda: data["user_tea_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    # Pass teacher_id of Teacher B to check if server ignores it and returns Teacher A's assignments
    response = await client.get(
        f"/api/v1/teacher-subject-assignments?school_id={data['school_a'].id}&teacher_id={data['profile_tea_b'].id}",
        headers=headers
    )
    assert response.status_code == status.HTTP_200_OK
    results = response.json()["data"]
    # Should only return Teacher A's assignment
    for a in results:
        assert a["teacher_id"] == str(data["profile_tea_a"].id)

@pytest.mark.anyio
async def test_teacher_get_other_assignment_forbidden(client: AsyncClient, setup_boundary_data):
    data = setup_boundary_data
    app.dependency_overrides[get_current_user] = lambda: data["user_tea_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    response = await client.get(
        f"/api/v1/teacher-subject-assignments/{data['tsa_b'].id}?school_id={data['school_a'].id}",
        headers=headers
    )
    assert response.status_code == status.HTTP_403_FORBIDDEN


# =====================================================================
# MARKS BOUNDARY TESTS
# =====================================================================

@pytest.mark.anyio
async def test_teacher_get_wizard_entry_assigned_success(client: AsyncClient, setup_boundary_data):
    data = setup_boundary_data
    app.dependency_overrides[get_current_user] = lambda: data["user_tea_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    response = await client.get(
        f"/api/v1/marks/wizard/entry?school_id={data['school_a'].id}&exam_schedule_id={data['exam_sched_a'].id}",
        headers=headers
    )
    assert response.status_code == status.HTTP_200_OK

@pytest.mark.anyio
async def test_teacher_get_wizard_entry_unassigned_forbidden(client: AsyncClient, setup_boundary_data):
    data = setup_boundary_data
    app.dependency_overrides[get_current_user] = lambda: data["user_tea_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    response = await client.get(
        f"/api/v1/marks/wizard/entry?school_id={data['school_a'].id}&exam_schedule_id={data['exam_sched_b'].id}",
        headers=headers
    )
    assert response.status_code == status.HTTP_403_FORBIDDEN

@pytest.mark.anyio
async def test_teacher_save_marks_unassigned_forbidden(client: AsyncClient, setup_boundary_data):
    data = setup_boundary_data
    app.dependency_overrides[get_current_user] = lambda: data["user_tea_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    # Attempt to submit marks using Teacher B's assignment (unassigned class/section)
    payload = {
        "teacher_subject_assignment_id": str(data["tsa_b"].id),
        "exam_schedule_id": str(data["exam_sched_b"].id),
        "marks": [
            {
                "student_id": str(data["student_b"].id),
                "marks_obtained": 85.0,
                "result_status": "PRESENT",
                "remarks": "Good"
            }
        ]
    }
    response = await client.post(
        f"/api/v1/marks/bulk?school_id={data['school_a'].id}",
        json=payload,
        headers=headers
    )
    assert response.status_code == status.HTTP_403_FORBIDDEN


# =====================================================================
# ATTENDANCE BOUNDARY TESTS
# =====================================================================

@pytest.mark.anyio
async def test_teacher_create_attendance_session_own_timetable_success(client: AsyncClient, setup_boundary_data):
    data = setup_boundary_data
    app.dependency_overrides[get_current_user] = lambda: data["user_tea_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    payload = {
        "school_id": str(data["school_a"].id),
        "academic_year_id": str(data["exam_sched_a"].academic_year_id),
        "timetable_id": str(data["tt_a"].id),
        "attendance_date": "2026-09-01",
        "remarks": "Regular class session"
    }
    response = await client.post(
        "/api/v1/attendances/session",
        json=payload,
        headers=headers
    )
    assert response.status_code == status.HTTP_201_CREATED

@pytest.mark.anyio
async def test_teacher_create_attendance_session_other_timetable_forbidden(client: AsyncClient, setup_boundary_data):
    data = setup_boundary_data
    app.dependency_overrides[get_current_user] = lambda: data["user_tea_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    payload = {
        "school_id": str(data["school_a"].id),
        "academic_year_id": str(data["exam_sched_a"].academic_year_id),
        "timetable_id": str(data["tt_b"].id),  # Belongs to Teacher B
        "attendance_date": "2026-09-01",
        "remarks": "Attempting other timetable"
    }
    response = await client.post(
        "/api/v1/attendances/session",
        json=payload,
        headers=headers
    )
    assert response.status_code == status.HTTP_403_FORBIDDEN


# =====================================================================
# HOMEWORK BOUNDARY TESTS
# =====================================================================

@pytest.mark.anyio
async def test_teacher_create_homework_resolves_identity(client: AsyncClient, setup_boundary_data):
    data = setup_boundary_data
    app.dependency_overrides[get_current_user] = lambda: data["user_tea_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    # Send profile_tea_b.id as client-supplied teacher_id to verify server overrides it with profile_tea_a.id
    payload = {
        "school_id": str(data["school_a"].id),
        "academic_year_id": str(data["exam_sched_a"].academic_year_id),
        "teacher_id": str(data["profile_tea_b"].id),
        "teacher_subject_assignment_id": str(data["tsa_a"].id),
        "subject_id": str(data["sub_math"].id),
        "class_id": str(data["class_a"].id),
        "section_id": str(data["sec_a"].id),
        "title": "Solve algebra worksheets",
        "description": "Solve exercise 4.2",
        "due_date": "2026-10-01",
        "priority": "NORMAL",
        "status": "DRAFT"
    }
    response = await client.post(
        "/api/v1/homeworks",
        json=payload,
        headers=headers
    )
    assert response.status_code == status.HTTP_201_CREATED
    homework_data = response.json()["data"]
    # Check that it resolved to Teacher A, not B
    assert homework_data["teacher_id"] == str(data["profile_tea_a"].id)


# =====================================================================
# STAFF ATTENDANCE BOUNDARY TESTS
# =====================================================================

@pytest.mark.anyio
async def test_teacher_get_staff_attendance_status(client: AsyncClient, setup_boundary_data):
    data = setup_boundary_data
    app.dependency_overrides[get_current_user] = lambda: data["user_tea_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    response = await client.get("/api/v1/staff-attendance/status", headers=headers)
    assert response.status_code == status.HTTP_200_OK

@pytest.mark.anyio
async def test_teacher_access_admin_daily_report_forbidden(client: AsyncClient, setup_boundary_data):
    data = setup_boundary_data
    app.dependency_overrides[get_current_user] = lambda: data["user_tea_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    response = await client.get(
        f"/api/v1/staff-attendance/daily?school_id={data['school_a'].id}&attendance_date=2026-09-01",
        headers=headers
    )
    assert response.status_code == status.HTTP_403_FORBIDDEN

@pytest.mark.anyio
async def test_teacher_access_other_history_forbidden(client: AsyncClient, setup_boundary_data):
    data = setup_boundary_data
    app.dependency_overrides[get_current_user] = lambda: data["user_tea_a"]
    headers = {"X-Tenant-ID": str(data["tenant_a"].id)}

    # Request history of Teacher B
    response = await client.get(
        f"/api/v1/staff-attendance/teacher/{data['profile_tea_b'].id}/history?start_date=2026-09-01",
        headers=headers
    )
    assert response.status_code == status.HTTP_403_FORBIDDEN
