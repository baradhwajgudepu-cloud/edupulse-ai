import os
import uuid
import pytest
from datetime import date, datetime, timezone
from httpx import AsyncClient
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.tenant import Tenant
from app.models.school import School
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.class_entity import Class, ClassCategory
from app.models.section import Section
from app.models.student import Student, StudentStatus, StudentGender
from app.models.guardian import Guardian, GuardianStatus, GuardianType, StudentGuardian, StudentGuardianRelationship
from app.models.role import Role
from app.models.permission import Permission
from app.models.user import User, UserStatus
from app.models.homework import Homework, HomeworkStatus, HomeworkPriority
from app.models.examination import Examination, ExamSchedule, ExamStatus, ExamType
from app.models.marks import Marks, MarksStatus, ExamResult
from app.models.report_card import ReportCardPublication, ReportCardStatus
from app.models.attendance import AttendanceSession, Attendance, AttendanceStatus, AttendanceSource
from app.models.teacher import Teacher, EmploymentType
from app.models.subject import Subject, SubjectCategory, SubjectType, SubjectStatus
from app.models.teacher_subject_assignment import TeacherSubjectAssignment, AssignmentStatus
from app.models.notification import Notification, NotificationPreference, NotificationStatus, NotificationType, NotificationPriority, NotificationTargetRole
from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.section import SectionRepository
from app.repositories.student import StudentRepository
from app.repositories.guardian import GuardianRepository, StudentGuardianRepository
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
from app.repositories.notification import NotificationRepository
from app.repositories.timetable import TimetableRepository
from app.repositories.attendance import AttendanceRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.subject import SubjectRepository
from app.repositories.teacher_subject_assignment import TeacherSubjectAssignmentRepository
from app.services.auth import AuthService
from app.services.notification import NotificationService
from app.services.attendance import AttendanceService
from app.services.homework import HomeworkService
from app.services.marks import MarksService
from app.services.report_card import ReportCardService
from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate, SchoolStatus
from app.schemas.academic_year import AcademicYearCreate
from app.schemas.class_entity import ClassCreate
from app.schemas.section import SectionCreate
from app.schemas.student import StudentCreate
from app.schemas.guardian import GuardianCreate, StudentGuardianCreate
from app.schemas.auth import UserCreate
from app.schemas.timetable import TimetableCreate
from app.schemas.teacher import TeacherCreate
from app.schemas.subject import SubjectCreate
from app.schemas.teacher_subject_assignment import TeacherSubjectAssignmentCreate
from app.schemas.attendance import BulkAttendanceMark, StudentAttendanceRecord
from app.schemas.homework import HomeworkCreate
from app.schemas.notification import NotificationCreate, NotificationPreferenceUpdate

@pytest.fixture
async def setup_notification_test_data(db_session: AsyncSession):
    suffix = uuid.uuid4().hex[:6].lower()

    # 1. Tenants
    repo_t = TenantRepository(db_session)
    tenant_a = await repo_t.create(TenantCreate(name="Notification Tenant A", code=f"notif-a-{suffix}", subdomain=f"notif-a-{suffix}", email=f"a-{suffix}@t.com"))
    tenant_b = await repo_t.create(TenantCreate(name="Notification Tenant B", code=f"notif-b-{suffix}", subdomain=f"notif-b-{suffix}", email=f"b-{suffix}@t.com"))
    await db_session.commit()

    # 2. Schools
    repo_s = SchoolRepository(db_session)
    school_a = await repo_s.create(tenant_a.id, SchoolCreate(name="Notif School A", code=f"NA_{suffix.upper()}", board="CBSE", email=f"s-a-{suffix}@a.com", status=SchoolStatus.ACTIVE))
    school_b = await repo_s.create(tenant_b.id, SchoolCreate(name="Notif School B", code=f"NB_{suffix.upper()}", board="CBSE", email=f"s-b-{suffix}@b.com", status=SchoolStatus.ACTIVE))
    
    # Configure settings
    school_a.settings = {
        "grade_policy": [{"grade": "A+", "min_percentage": 90, "max_percentage": 100}],
        "promotion_policy": {"min_attendance_pct": 75.0, "min_overall_pct": 35.0, "max_failed_subjects": 0}
    }
    db_session.add(school_a)
    await db_session.commit()

    # 3. Academic Year
    repo_ay = AcademicYearRepository(db_session)
    ay_a = await repo_ay.create(tenant_a.id, school_a.id, AcademicYearCreate(school_id=school_a.id, name="Year 2026", code="AY2026", start_date=date(2026, 1, 1), end_date=date(2026, 12, 31), status=AcademicYearStatus.ACTIVE, is_current=True))
    ay_a.status = AcademicYearStatus.ACTIVE
    
    ay_b = await repo_ay.create(tenant_b.id, school_b.id, AcademicYearCreate(school_id=school_b.id, name="Year 2026", code="AY2026", start_date=date(2026, 1, 1), end_date=date(2026, 12, 31), status=AcademicYearStatus.ACTIVE, is_current=True))
    ay_b.status = AcademicYearStatus.ACTIVE
    await db_session.commit()

    # 4. Classes & Sections
    repo_c = ClassRepository(db_session)
    class_a = await repo_c.create(tenant_a.id, ClassCreate(school_id=school_a.id, academic_year_id=ay_a.id, name="Class 8", code="C8", level=8, category=ClassCategory.PRIMARY, capacity=30))
    class_b = await repo_c.create(tenant_b.id, ClassCreate(school_id=school_b.id, academic_year_id=ay_b.id, name="Class 8", code="C8", level=8, category=ClassCategory.PRIMARY, capacity=30))
    await db_session.commit()

    repo_sec = SectionRepository(db_session)
    sec_a = await repo_sec.create(tenant_a.id, SectionCreate(school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_a.id, name="Sec A", code="SA", capacity=30))
    sec_b = await repo_sec.create(tenant_b.id, SectionCreate(school_id=school_b.id, academic_year_id=ay_b.id, class_id=class_b.id, name="Sec B", code="SB", capacity=30))
    await db_session.commit()

    # 5. Students
    repo_std = StudentRepository(db_session)
    student_a = await repo_std.create(tenant_a.id, StudentCreate(
        school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_a.id, section_id=sec_a.id,
        admission_number="ADM-001", roll_number="R-01", first_name="Rahul", last_name="Kumar",
        gender=StudentGender.MALE, date_of_birth=date(2012, 5, 10), admission_date=date(2026, 6, 1)
    ))
    
    student_b = await repo_std.create(tenant_b.id, StudentCreate(
        school_id=school_b.id, academic_year_id=ay_b.id, class_id=class_b.id, section_id=sec_b.id,
        admission_number="ADM-002", roll_number="R-02", first_name="Priya", last_name="Sharma",
        gender=StudentGender.FEMALE, date_of_birth=date(2013, 8, 15), admission_date=date(2026, 6, 1)
    ))
    await db_session.commit()

    # 6. User Setup (Auth & Roles & Permissions)
    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    auth_service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, repo_s)

    stmt_p = select(Permission)
    res_p = await db_session.execute(stmt_p)
    all_perms = list(res_p.scalars().all())

    # Fetch existing Roles (created automatically by initialize_tenant_rbac)
    from sqlalchemy.orm import selectinload
    stmt_role_parent = select(Role).where(Role.tenant_id == tenant_a.id, Role.code == "PARENT").options(selectinload(Role.permissions))
    role_parent = (await db_session.execute(stmt_role_parent)).scalar_one()
    role_parent.permissions = [p for p in all_perms if p.code in ["notification.read", "notification.mark_read", "notification.delete"]]
    db_session.add(role_parent)

    stmt_role_teacher = select(Role).where(Role.tenant_id == tenant_a.id, Role.code == "TEACHER").options(selectinload(Role.permissions))
    role_teacher = (await db_session.execute(stmt_role_teacher)).scalar_one()
    role_teacher.permissions = [p for p in all_perms if p.code in ["notification.read", "notification.mark_read"]]
    db_session.add(role_teacher)

    stmt_role_principal = select(Role).where(Role.tenant_id == tenant_a.id, Role.code == "PRINCIPAL").options(selectinload(Role.permissions))
    role_principal = (await db_session.execute(stmt_role_principal)).scalar_one()
    role_principal.permissions = all_perms
    db_session.add(role_principal)

    stmt_role_parent_b = select(Role).where(Role.tenant_id == tenant_b.id, Role.code == "PARENT").options(selectinload(Role.permissions))
    role_parent_b = (await db_session.execute(stmt_role_parent_b)).scalar_one()
    role_parent_b.permissions = [p for p in all_perms if p.code in ["notification.read", "notification.mark_read"]]
    db_session.add(role_parent_b)

    # Guardian Records & Linkage
    guardian_email_a = f"parent-a-{suffix}@gmail.com"
    guardian_repo_a = GuardianRepository(db_session)
    guardian_a = await guardian_repo_a.create(tenant_a.id, GuardianCreate(
        school_id=school_a.id, first_name="John", last_name="Doe", gender=StudentGender.MALE,
        date_of_birth=date(1985, 1, 1), mobile="9876543210", email=guardian_email_a,
        guardian_type=GuardianType.FATHER, status=GuardianStatus.ACTIVE
    ))
    await db_session.commit()

    student_guardian_repo = StudentGuardianRepository(db_session)
    await student_guardian_repo.create(tenant_a.id, StudentGuardianCreate(
        school_id=school_a.id, student_id=student_a.id, guardian_id=guardian_a.id,
        relationship=StudentGuardianRelationship.FATHER, is_primary=True, receives_notifications=True
    ))
    await db_session.commit()

    guardian_email_b = f"parent-b-{suffix}@gmail.com"
    guardian_repo_b = GuardianRepository(db_session)
    guardian_b = await guardian_repo_b.create(tenant_b.id, GuardianCreate(
        school_id=school_b.id, first_name="Mary", last_name="Smith", gender=StudentGender.FEMALE,
        date_of_birth=date(1987, 2, 2), mobile="9876543211", email=guardian_email_b,
        guardian_type=GuardianType.MOTHER, status=GuardianStatus.ACTIVE
    ))
    await db_session.commit()

    await student_guardian_repo.create(tenant_b.id, StudentGuardianCreate(
        school_id=school_b.id, student_id=student_b.id, guardian_id=guardian_b.id,
        relationship=StudentGuardianRelationship.MOTHER, is_primary=True, receives_notifications=True
    ))
    await db_session.commit()

    # User Accounts
    user_p_a = await auth_service.create_user(tenant_a.id, UserCreate(email=guardian_email_a, password="Password123!", first_name="John", last_name="Doe"))
    user_p_a.roles.append(role_parent)

    user_t_a = await auth_service.create_user(tenant_a.id, UserCreate(email=f"teacher-{suffix}@school.edu", password="Password123!", first_name="T", last_name="One"))
    user_t_a.roles.append(role_teacher)

    user_pr_a = await auth_service.create_user(tenant_a.id, UserCreate(email=f"principal-{suffix}@school.edu", password="Password123!", first_name="Pr", last_name="One"))
    user_pr_a.roles.append(role_principal)

    user_p_b = await auth_service.create_user(tenant_b.id, UserCreate(email=guardian_email_b, password="Password123!", first_name="Mary", last_name="Smith"))
    user_p_b.roles.append(role_parent_b)

    await db_session.commit()

    # Map Principal, Parent & Teacher to School A
    await db_session.execute(text("INSERT INTO school_users (user_id, school_id) VALUES (:u, :s)"), {"u": str(user_pr_a.id), "s": str(school_a.id)})
    await db_session.execute(text("INSERT INTO school_users (user_id, school_id) VALUES (:u, :s)"), {"u": str(user_t_a.id), "s": str(school_a.id)})
    await db_session.execute(text("INSERT INTO school_users (user_id, school_id) VALUES (:u, :s)"), {"u": str(user_p_a.id), "s": str(school_a.id)})
    await db_session.commit()

    # Generate Auth Tokens
    tokens_parent = await auth_service.create_tokens(user_p_a)
    tokens_teacher = await auth_service.create_tokens(user_t_a)
    tokens_principal = await auth_service.create_tokens(user_pr_a)
    tokens_parent_b = await auth_service.create_tokens(user_p_b)

    return {
        "tenant_a": tenant_a,
        "tenant_b": tenant_b,
        "school_a": school_a,
        "school_b": school_b,
        "student_a": student_a,
        "student_b": student_b,
        "ay_a": ay_a,
        "class_a": class_a,
        "sec_a": sec_a,
        "user_parent": user_p_a,
        "user_teacher": user_t_a,
        "user_principal": user_pr_a,
        "user_parent_b": user_p_b,
        "headers_parent": {"Authorization": f"Bearer {tokens_parent.access_token}", "X-Tenant-ID": str(tenant_a.id)},
        "headers_teacher": {"Authorization": f"Bearer {tokens_teacher.access_token}", "X-Tenant-ID": str(tenant_a.id)},
        "headers_principal": {"Authorization": f"Bearer {tokens_principal.access_token}", "X-Tenant-ID": str(tenant_a.id)},
        "headers_parent_b": {"Authorization": f"Bearer {tokens_parent_b.access_token}", "X-Tenant-ID": str(tenant_b.id)}
    }


@pytest.mark.anyio
async def test_notification_preferences_crud(client: AsyncClient, setup_notification_test_data) -> None:
    headers = setup_notification_test_data["headers_parent"]

    # 1. Get default preferences
    resp = await client.get("/api/v1/notification-preferences", headers=headers)
    assert resp.status_code == 200
    pref = resp.json()["data"]
    assert pref["enable_homework"] is True
    assert pref["enable_attendance"] is True

    # 2. Update preferences
    update_payload = {"enable_homework": False, "enable_push": False}
    resp_up = await client.put("/api/v1/notification-preferences", json=update_payload, headers=headers)
    assert resp_up.status_code == 200
    updated_pref = resp_up.json()["data"]
    assert updated_pref["enable_homework"] is False
    assert updated_pref["enable_push"] is False
    assert updated_pref["enable_attendance"] is True


@pytest.mark.anyio
async def test_notification_broadcasting_and_rbac(client: AsyncClient, setup_notification_test_data) -> None:
    headers_pr = setup_notification_test_data["headers_principal"]
    headers_p = setup_notification_test_data["headers_parent"]
    headers_t = setup_notification_test_data["headers_teacher"]

    # 1. Principal sends a custom broadcast announcement to PARENT role
    payload = {
        "notification_type": "ANNOUNCEMENT",
        "priority": "HIGH",
        "title": "Welcome Back Parents",
        "message": "We look forward to a great school semester.",
        "target_role": "PARENT"
    }
    resp = await client.post("/api/v1/notifications", json=payload, headers=headers_pr)
    assert resp.status_code == 201
    
    # 2. Parent checks unread list and unread count
    resp_list = await client.get("/api/v1/notifications", headers=headers_p)
    assert resp_list.status_code == 200
    results = resp_list.json()["data"]
    assert len(results) == 1
    assert results[0]["title"] == "Welcome Back Parents"
    assert results[0]["status"] == "UNREAD"

    resp_cnt = await client.get("/api/v1/notifications/unread-count", headers=headers_p)
    assert resp_cnt.status_code == 200
    assert resp_cnt.json()["data"]["unread_count"] == 1

    # 3. Teacher checks notifications, should not see parent announcement
    resp_t_list = await client.get("/api/v1/notifications", headers=headers_t)
    assert resp_t_list.status_code == 200
    assert len(resp_t_list.json()["data"]) == 0

    # 4. Parent marks the notification as read
    notif_id = results[0]["id"]
    resp_read = await client.put(f"/api/v1/notifications/{notif_id}/read", headers=headers_p)
    assert resp_read.status_code == 200
    assert resp_read.json()["data"]["status"] == "READ"

    # 5. Parent checks unread count again
    resp_cnt_2 = await client.get("/api/v1/notifications/unread-count", headers=headers_p)
    assert resp_cnt_2.json()["data"]["unread_count"] == 0


@pytest.mark.anyio
async def test_tenant_isolation_and_rbac_guards(client: AsyncClient, setup_notification_test_data, db_session: AsyncSession) -> None:
    headers_p_a = setup_notification_test_data["headers_parent"]
    headers_p_b = setup_notification_test_data["headers_parent_b"]
    tenant_a = setup_notification_test_data["tenant_a"]
    school_a = setup_notification_test_data["school_a"]
    parent_a = setup_notification_test_data["user_parent"]
    parent_b = setup_notification_test_data["user_parent_b"]

    tenant_id = tenant_a.id
    school_id = school_a.id
    parent_id = parent_a.id

    # Seed notification directly for Parent A in Tenant A
    repo_n = NotificationRepository(db_session)
    n_obj = await repo_n.create(
        tenant_id=tenant_id,
        school_id=school_id,
        obj_in=NotificationCreate(
            notification_type=NotificationType.GENERAL,
            priority=NotificationPriority.NORMAL,
            title="Private A",
            message="Only for A",
            target_role=NotificationTargetRole.PARENT,
            target_user_id=parent_id
        )
    )
    await db_session.commit()

    n_id = n_obj.id

    # Expire to sync
    db_session.expire_all()

    # Parent B (Tenant B) tries to query Parent A's notification
    resp_b = await client.get(f"/api/v1/notifications/{n_id}", headers=headers_p_b)
    assert resp_b.status_code == 404

    # Parent A marks read all
    resp_bulk = await client.put("/api/v1/notifications/read-all", headers=headers_p_a)
    assert resp_bulk.status_code == 200
    assert resp_bulk.json()["data"] == 1

    # Soft Delete
    resp_del = await client.delete(f"/api/v1/notifications/{n_id}", headers=headers_p_a)
    assert resp_del.status_code == 200
    
    # Reload and assert deleted_at exists
    stmt = select(Notification).where(Notification.id == n_id)
    res = await db_session.execute(stmt)
    reloaded = res.scalar_one()
    assert reloaded.deleted_at is not None


@pytest.mark.anyio
async def test_preference_enforcement(client: AsyncClient, setup_notification_test_data, db_session: AsyncSession) -> None:
    headers_p = setup_notification_test_data["headers_parent"]
    tenant_a = setup_notification_test_data["tenant_a"]
    school_a = setup_notification_test_data["school_a"]
    parent_a = setup_notification_test_data["user_parent"]

    tenant_id = tenant_a.id
    school_id = school_a.id
    parent_id = parent_a.id

    # 1. Turn OFF homework preferences
    update_payload = {"enable_homework": False}
    resp = await client.put("/api/v1/notification-preferences", json=update_payload, headers=headers_p)
    assert resp.status_code == 200

    # Expire to sync
    db_session.expire_all()

    # 2. Trigger notification service to broadcast homework to Parent A
    repo_n = NotificationRepository(db_session)
    service = NotificationService(repo_n)

    result_homework = await service._create_user_notification(
        tenant_id=tenant_id,
        school_id=school_id,
        obj_in=NotificationCreate(
            notification_type=NotificationType.HOMEWORK,
            priority=NotificationPriority.NORMAL,
            title="Homework Math",
            message="Ch 5",
            target_role=NotificationTargetRole.PARENT,
            target_user_id=parent_id
        )
    )
    # Should be None since preference is disabled!
    assert result_homework is None

    # 3. Trigger attendance notification (preference remains enabled)
    result_att = await service._create_user_notification(
        tenant_id=tenant_id,
        school_id=school_id,
        obj_in=NotificationCreate(
            notification_type=NotificationType.ATTENDANCE,
            priority=NotificationPriority.NORMAL,
            title="Attendance Marked",
            message="Present",
            target_role=NotificationTargetRole.PARENT,
            target_user_id=parent_id
        )
    )
    assert result_att is not None
    assert result_att.title == "Attendance Marked"


@pytest.mark.anyio
async def test_bulk_notification_performance(setup_notification_test_data, db_session: AsyncSession) -> None:
    tenant_a = setup_notification_test_data["tenant_a"]
    school_a = setup_notification_test_data["school_a"]
    parent_a = setup_notification_test_data["user_parent"]

    tenant_id = tenant_a.id
    school_id = school_a.id
    parent_id = parent_a.id

    repo_n = NotificationRepository(db_session)
    
    notifications = []
    for i in range(50):
        notifications.append(
            Notification(
                tenant_id=tenant_id,
                school_id=school_id,
                notification_type=NotificationType.GENERAL,
                priority=NotificationPriority.LOW,
                title=f"Bulk Notif {i}",
                message=f"Performance check {i}",
                target_role=NotificationTargetRole.PARENT,
                target_user_id=parent_id,
                status=NotificationStatus.UNREAD
            )
        )
    
    # Bulk create
    created = await repo_n.bulk_create(notifications)
    await db_session.commit()
    assert len(created) == 50


@pytest.mark.anyio
async def test_service_integrations_triggers(setup_notification_test_data, db_session: AsyncSession) -> None:
    tenant_a = setup_notification_test_data["tenant_a"]
    school_a = setup_notification_test_data["school_a"]
    ay_a = setup_notification_test_data["ay_a"]
    class_a = setup_notification_test_data["class_a"]
    sec_a = setup_notification_test_data["sec_a"]
    student_a = setup_notification_test_data["student_a"]
    teacher_a = setup_notification_test_data["user_teacher"]
    parent_a = setup_notification_test_data["user_parent"]

    tenant_id = tenant_a.id
    school_id = school_a.id
    ay_id = ay_a.id
    class_id = class_a.id
    sec_id = sec_a.id
    student_id = student_a.id
    teacher_id = teacher_a.id
    parent_id = parent_a.id

    # Repos and Service setup
    repo_n = NotificationRepository(db_session)
    notif_service = NotificationService(repo_n)

    # 1. Test Attendance Trigger Hook
    # Seed teacher details
    suffix = uuid.uuid4().hex[:6].lower()
    repo_teacher = TeacherRepository(db_session)
    teacher_obj = await repo_teacher.create(tenant_id, TeacherCreate(
        school_id=school_id,
        employee_code=f"EMP-A-{suffix}",
        staff_code=f"STF-A-{suffix}",
        first_name="T",
        last_name="One",
        gender=StudentGender.MALE,
        date_of_birth=date(1980, 1, 1),
        mobile=f"+91987654{suffix[:4]}",
        official_email=f"teacher-{suffix}@school.edu",
        joining_date=date(2025, 1, 1),
        employment_type=EmploymentType.FULL_TIME
    ))
    await db_session.commit()

    # Seed subject details
    repo_subject = SubjectRepository(db_session)
    subject_obj = await repo_subject.create(tenant_id, SubjectCreate(
        school_id=school_id,
        academic_year_id=ay_id,
        subject_name="Mathematics",
        subject_code=f"MATH-{suffix.upper()}",
        category=SubjectCategory.CORE,
        subject_type=SubjectType.THEORY
    ))
    await db_session.commit()

    # Seed teacher subject assignment
    repo_tsa = TeacherSubjectAssignmentRepository(db_session)
    tsa_obj = await repo_tsa.create(tenant_id, TeacherSubjectAssignmentCreate(
        school_id=school_id,
        academic_year_id=ay_id,
        teacher_id=teacher_obj.id,
        subject_id=subject_obj.id,
        class_id=class_id,
        section_id=sec_id,
        assignment_type="PRIMARY",
        weekly_periods=5,
        effective_from=date(2026, 1, 1)
    ))
    tsa_obj.status = AssignmentStatus.ACTIVE
    tsa_obj.is_active = True
    await db_session.commit()

    # Seed timetable
    repo_tt = TimetableRepository(db_session)
    tt_obj = await repo_tt.create(tenant_id, TimetableCreate(
        school_id=school_id,
        academic_year_id=ay_id,
        class_id=class_id,
        section_id=sec_id,
        teacher_subject_assignment_id=tsa_obj.id,
        day_of_week="MONDAY",
        period_number=1,
        start_time="08:00:00",
        end_time="09:00:00",
        period_type="REGULAR"
    ))
    await db_session.commit()

    # Create attendance session and mark Rahul absent
    
    att_service = AttendanceService(
        attendance_repo=AttendanceRepository(db_session),
        student_repo=StudentRepository(db_session),
        timetable_repo=TimetableRepository(db_session),
        academic_year_repo=AcademicYearRepository(db_session),
        notification_service=notif_service
    )
    
    session_obj = AttendanceSession(
        tenant_id=tenant_id, school_id=school_id, academic_year_id=ay_id,
        class_id=class_id, section_id=sec_id, timetable_id=tt_obj.id,
        attendance_date=date(2026, 3, 2), teacher_id=teacher_obj.id, subject_id=subject_obj.id
    )
    db_session.add(session_obj)
    await db_session.flush()

    session_id = session_obj.id

    # Bulk mark Rahul absent
    mark_payload = BulkAttendanceMark(
        attendance_session_status="SUBMITTED",
        records=[
            StudentAttendanceRecord(attendance_status="ABSENT", student_id=student_id)
        ]
    )
    
    # Reload teacher user to load schools relationship
    stmt_tea = select(User).where(User.id == teacher_id).options(
        selectinload(User.schools)
    )
    res_tea = await db_session.execute(stmt_tea)
    teacher_loaded = res_tea.scalar_one()

    await att_service.bulk_mark_attendance(
        tenant_id=tenant_id, school_id=school_id, session_id=session_id,
        obj_in=mark_payload, current_user=teacher_loaded
    )

    # Expire to sync
    db_session.expire_all()

    # Reload parent user eagerly
    stmt_par = select(User).where(User.id == parent_id).options(
        selectinload(User.roles)
    )
    res_par = await db_session.execute(stmt_par)
    parent_loaded = res_par.scalar_one()

    # Query parent notifications, should have one for attendance
    unread_cnt = await notif_service.count_unread(tenant_id, parent_loaded)
    assert unread_cnt == 1

    stmt = select(Notification).where(Notification.target_user_id == parent_id, Notification.notification_type == NotificationType.ATTENDANCE)
    res_notif = await db_session.execute(stmt)
    notif = res_notif.scalar_one()
    assert "ABSENT" in notif.message


@pytest.mark.anyio
async def test_device_tokens_endpoints(client: AsyncClient, setup_notification_test_data, db_session: AsyncSession) -> None:
    headers = setup_notification_test_data["headers_parent"]
    tenant_id = setup_notification_test_data["tenant_a"].id
    parent_id = setup_notification_test_data["user_parent"].id

    # 1. Register device token
    payload = {
        "device_token": "mock-fcm-device-token-xyz-123",
        "platform": "android",
        "app_type": "parent"
    }
    resp = await client.post("/api/v1/notifications/device-tokens", json=payload, headers=headers)
    assert resp.status_code == 201
    data = resp.json()["data"]
    assert data["device_token"] == "mock-fcm-device-token-xyz-123"
    assert data["platform"] == "android"
    assert data["app_type"] == "parent"
    assert data["is_active"] is True

    # Check DB
    from app.models.notification import UserDeviceToken
    stmt = select(UserDeviceToken).where(
        UserDeviceToken.tenant_id == tenant_id,
        UserDeviceToken.user_id == parent_id,
        UserDeviceToken.device_token == "mock-fcm-device-token-xyz-123"
    )
    res = await db_session.execute(stmt)
    token = res.scalar_one_or_none()
    assert token is not None
    assert token.is_active is True

    # 2. Deactivate device token
    deact_payload = {
        "device_token": "mock-fcm-device-token-xyz-123"
    }
    resp = await client.post("/api/v1/notifications/device-tokens/deactivate", json=deact_payload, headers=headers)
    assert resp.status_code == 200
    
    # Check DB again
    db_session.expire_all()
    res2 = await db_session.execute(stmt)
    token2 = res2.scalar_one_or_none()
    assert token2 is not None
    assert token2.is_active is False


@pytest.mark.anyio
async def test_event_idempotency_and_preferences(setup_notification_test_data, db_session: AsyncSession) -> None:
    tenant_a = setup_notification_test_data["tenant_a"]
    school_a = setup_notification_test_data["school_a"]
    student_a = setup_notification_test_data["student_a"]

    tenant_id = tenant_a.id
    school_id = school_a.id
    student_id = student_a.id

    repo_n = NotificationRepository(db_session)
    notif_service = NotificationService(repo_n)

    # Dispatch first fee payment event
    notifs = await notif_service.dispatch_event(
        tenant_id=tenant_id,
        school_id=school_id,
        event_type="FEE_PAYMENT_RECEIVED",
        payload={
            "student_id": student_id,
            "entity_id": student_id,  # using student_id as mock entity_id
            "title": "Fee Payment Successful",
            "message": "Payment of 500.00 was successful.",
            "related_module": "fee"
        }
    )
    assert len(notifs) == 1
    assert notifs[0].event_key is not None
    assert notifs[0].push_status == "NOT_CONFIGURED"

    # Dispatch identical duplicate event
    notifs_dup = await notif_service.dispatch_event(
        tenant_id=tenant_id,
        school_id=school_id,
        event_type="FEE_PAYMENT_RECEIVED",
        payload={
            "student_id": student_id,
            "entity_id": student_id,
            "title": "Fee Payment Successful",
            "message": "Payment of 500.00 was successful.",
            "related_module": "fee"
        }
    )
    # Should bypass creation completely (length 0)
    assert len(notifs_dup) == 0
