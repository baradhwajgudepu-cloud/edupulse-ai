import pytest
import uuid
from datetime import date, time, datetime, timezone
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tenant import Tenant
from app.models.school import School, SchoolStatus
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.class_entity import Class, ClassCategory
from app.models.section import Section
from app.models.teacher import Teacher, EmploymentType
from app.models.subject import Subject, SubjectCategory, SubjectType
from app.models.teacher_subject_assignment import TeacherSubjectAssignment
from app.models.user import User
from app.models.role import Role
from app.models.permission import Permission
from app.models.examination import Examination, ExamStatus, ExamType
from app.models.school_event import SchoolEvent, EventStatus, EventAudience
from app.models.announcement import Announcement, AnnouncementStatus, AnnouncementAudienceType

from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.section import SectionRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.subject import SubjectRepository
from app.repositories.teacher_subject_assignment import TeacherSubjectAssignmentRepository
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository

from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate
from app.schemas.academic_year import AcademicYearCreate
from app.schemas.class_entity import ClassCreate
from app.schemas.section import SectionCreate
from app.schemas.teacher import TeacherCreate
from app.schemas.subject import SubjectCreate
from app.schemas.teacher_subject_assignment import TeacherSubjectAssignmentCreate
from app.schemas.auth import UserCreate
from app.services.auth import AuthService


@pytest.fixture
async def setup_planner_test_data(db_session: AsyncSession):
    suffix = uuid.uuid4().hex[:6].lower()

    # 1. Create Tenant A & B
    repo_t = TenantRepository(db_session)
    tenant_a = await repo_t.create(TenantCreate(name="Planner Tenant A", code=f"plan-a-{suffix}", subdomain=f"plan-a-{suffix}", email=f"plan-a-{suffix}@t.com"))
    tenant_b = await repo_t.create(TenantCreate(name="Planner Tenant B", code=f"plan-b-{suffix}", subdomain=f"plan-b-{suffix}", email=f"plan-b-{suffix}@t.com"))
    await db_session.commit()

    # 2. Create School A under Tenant A, and School B under Tenant B
    repo_s = SchoolRepository(db_session)
    school_a = await repo_s.create(tenant_a.id, SchoolCreate(name="Planner School A", code=f"SC_A_{suffix.upper()}", address="123 St", city="Hyd", state="TS", country="IN", pin_code="500081", board="CBSE", email=f"sch-a-{suffix}@a.com", status=SchoolStatus.ACTIVE))
    school_b = await repo_s.create(tenant_b.id, SchoolCreate(name="Planner School B", code=f"SC_B_{suffix.upper()}", address="456 St", city="Hyd", state="TS", country="IN", pin_code="500081", board="CBSE", email=f"sch-b-{suffix}@b.com", status=SchoolStatus.ACTIVE))
    await db_session.commit()

    # 3. Academic Year for School A and School B
    repo_ay = AcademicYearRepository(db_session)
    ay_a = await repo_ay.create(tenant_a.id, school_a.id, AcademicYearCreate(school_id=school_a.id, name="Year 2026", code="AY2026", start_date=date(2026, 1, 1), end_date=date(2026, 12, 31), status=AcademicYearStatus.ACTIVE, is_current=True))
    ay_b = await repo_ay.create(tenant_b.id, school_b.id, AcademicYearCreate(school_id=school_b.id, name="Year 2026", code="AY2026", start_date=date(2026, 1, 1), end_date=date(2026, 12, 31), status=AcademicYearStatus.ACTIVE, is_current=True))
    await db_session.commit()

    # 4. Class & Section
    repo_c = ClassRepository(db_session)
    class_a = await repo_c.create(tenant_a.id, ClassCreate(school_id=school_a.id, academic_year_id=ay_a.id, name="Grade 10", code="G10", level=10, category=ClassCategory.HIGH, capacity=40))
    await db_session.commit()

    repo_sec = SectionRepository(db_session)
    sec_a = await repo_sec.create(tenant_a.id, SectionCreate(school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_a.id, name="Section A", code="SEC_A", capacity=40))
    await db_session.commit()

    # 5. Teacher, Subject, TSA for wizard scheduling validation
    repo_tchr = TeacherRepository(db_session)
    teacher_a = await repo_tchr.create(tenant_a.id, TeacherCreate(school_id=school_a.id, employee_code=f"EMP-{suffix}", staff_code=f"STF-{suffix}", first_name="Planner", last_name="Teacher", gender="MALE", date_of_birth=date(1990, 1, 1), mobile=f"+919999{suffix[:4]}", official_email=f"teach-{suffix}@t.com", joining_date=date(2026, 1, 1), employment_type=EmploymentType.FULL_TIME))
    await db_session.commit()

    repo_sub = SubjectRepository(db_session)
    subject_a = await repo_sub.create(tenant_a.id, SubjectCreate(school_id=school_a.id, academic_year_id=ay_a.id, subject_code=f"SCI-{suffix.upper()}", subject_name="Science", category=SubjectCategory.CORE, subject_type=SubjectType.THEORY))
    await db_session.commit()

    repo_tsa = TeacherSubjectAssignmentRepository(db_session)
    tsa_a = await repo_tsa.create(tenant_a.id, TeacherSubjectAssignmentCreate(school_id=school_a.id, academic_year_id=ay_a.id, teacher_id=teacher_a.id, subject_id=subject_a.id, class_id=class_a.id, section_id=sec_a.id, assignment_type="PRIMARY", weekly_periods=4, effective_from=date(2026, 1, 1)))
    await db_session.commit()

    # 6. Roles & Permissions mapping
    stmt_p = select(Permission)
    res_p = await db_session.execute(stmt_p)
    all_perms = list(res_p.scalars().all())

    # Fetch existing ADMIN role under tenant_a (created automatically by TenantRepository)
    from sqlalchemy.orm import selectinload
    stmt_role = select(Role).where(Role.tenant_id == tenant_a.id, Role.code == "ADMIN").options(selectinload(Role.permissions))
    res_role = await db_session.execute(stmt_role)
    admin_role = res_role.scalar_one()
    admin_role.permissions = all_perms
    db_session.add(admin_role)
    await db_session.commit()

    # 7. Create Super Admin User (tenant A) and standard user (tenant A)
    from app.repositories.auth import RefreshTokenRepository
    repo_u = UserRepository(db_session)
    repo_r = RoleRepository(db_session)
    repo_perm = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    
    auth_service = AuthService(repo_u, repo_r, repo_perm, refresh_repo, repo_s)
    
    super_admin = await auth_service.create_user(
        tenant_a.id,
        UserCreate(email=f"su-a-{suffix}@a.com", password="SecurePassword123!", first_name="Super", last_name="Admin")
    )
    super_admin.is_superuser = True
    super_admin.roles = [admin_role]

    std_user = await auth_service.create_user(
        tenant_a.id,
        UserCreate(email=f"std-a-{suffix}@a.com", password="SecurePassword123!", first_name="Standard", last_name="User")
    )
    std_user.roles = [admin_role]

    await db_session.commit()

    return {
        "tenant_a": tenant_a,
        "tenant_b": tenant_b,
        "school_a": school_a,
        "school_b": school_b,
        "ay_a": ay_a,
        "class_a": class_a,
        "sec_a": sec_a,
        "tsa_a": tsa_a,
        "super_admin": super_admin,
        "std_user": std_user,
        "auth_service": auth_service,
    }


@pytest.mark.anyio
async def test_planner_tenant_and_superuser_bypass(client: AsyncClient, setup_planner_test_data: dict) -> None:
    data = setup_planner_test_data
    auth_service = data["auth_service"]

    # Generate token for Super Admin (Tenant A)
    tokens_su = await auth_service.create_tokens(data["super_admin"])
    su_token = tokens_su.access_token
    headers_su = {"Authorization": f"Bearer {su_token}", "X-Tenant-ID": str(data["tenant_a"].id)}

    # Generate token for Std User (Tenant A)
    tokens_std = await auth_service.create_tokens(data["std_user"])
    std_token = tokens_std.access_token
    headers_std = {"Authorization": f"Bearer {std_token}", "X-Tenant-ID": str(data["tenant_a"].id)}

    # Create Event payload
    event_payload = {
        "event_name": "Tenant A Event",
        "description": "Fun activities",
        "event_date": "2026-05-10",
        "start_time": "10:00:00",
        "end_time": "12:00:00",
        "venue": "Main Hall",
        "target_audience": "ALL",
        "is_holiday": False
    }

    # 1. Super Admin access school inside same tenant A -> ALLOW
    res1 = await client.post(
        f"/api/v1/events?school_id={data['school_a'].id}",
        json=event_payload,
        headers=headers_su
    )
    assert res1.status_code == 201
    event_id = res1.json()["data"]["id"]

    # 2. Super Admin access school in tenant B -> ALLOW (Cross-Tenant Superuser Access)
    res2 = await client.post(
        f"/api/v1/events?school_id={data['school_b'].id}",
        json=event_payload,
        headers=headers_su
    )
    assert res2.status_code == 201

    # 3. Standard User access school inside tenant A (no mapping) -> DENY (403 Forbidden)
    res3 = await client.post(
        f"/api/v1/events?school_id={data['school_a'].id}",
        json=event_payload,
        headers=headers_std
    )
    assert res3.status_code == 403

    # 3.5. Standard User access school in tenant B (cross-tenant) -> DENY (403 Forbidden)
    res3_5 = await client.post(
        f"/api/v1/events?school_id={data['school_b'].id}",
        json=event_payload,
        headers=headers_std
    )
    assert res3_5.status_code == 403

    # 4. Super Admin publishes event -> ALLOW
    res4 = await client.post(
        f"/api/v1/events/{event_id}/publish?school_id={data['school_a'].id}",
        headers=headers_su
    )
    assert res4.status_code == 200
    assert res4.json()["data"]["status"] == "PUBLISHED"


@pytest.mark.anyio
async def test_planner_announcement_and_circular_flows(client: AsyncClient, setup_planner_test_data: dict) -> None:
    data = setup_planner_test_data
    auth_service = data["auth_service"]
    tokens_su = await auth_service.create_tokens(data["super_admin"])
    su_token = tokens_su.access_token
    headers_su = {"Authorization": f"Bearer {su_token}", "X-Tenant-ID": str(data["tenant_a"].id)}

    ann_payload = {
        "title": "Welcome Announcement",
        "message": "Hello class of 2026",
        "audience_type": "ROLE",
        "target_role": "PARENT",
        "priority": "NORMAL"
    }

    # Create Announcement -> ALLOW
    res1 = await client.post(
        f"/api/v1/announcements?school_id={data['school_a'].id}",
        json=ann_payload,
        headers=headers_su
    )
    assert res1.status_code == 201
    ann_id = res1.json()["data"]["id"]

    # Publish Announcement -> ALLOW
    res2 = await client.post(
        f"/api/v1/announcements/{ann_id}/publish?school_id={data['school_a'].id}",
        headers=headers_su
    )
    assert res2.status_code == 200
    assert res2.json()["data"]["status"] == "PUBLISHED"

    # Create Circular (Announcement with attachment_url) -> ALLOW
    circ_payload = {
        "title": "Academic Circular",
        "message": "Attached is the annual plan PDF.",
        "audience_type": "ROLE",
        "target_role": "TEACHER",
        "priority": "HIGH",
        "attachment_url": "https://storage.edupulse.com/circ/annual.pdf"
    }
    res3 = await client.post(
        f"/api/v1/announcements?school_id={data['school_a'].id}",
        json=circ_payload,
        headers=headers_su
    )
    assert res3.status_code == 201
    assert res3.json()["data"]["attachment_url"] == circ_payload["attachment_url"]


@pytest.mark.anyio
async def test_planner_examinations_wizard_flow(client: AsyncClient, setup_planner_test_data: dict) -> None:
    data = setup_planner_test_data
    auth_service = data["auth_service"]
    tokens_su = await auth_service.create_tokens(data["super_admin"])
    su_token = tokens_su.access_token
    headers_su = {"Authorization": f"Bearer {su_token}", "X-Tenant-ID": str(data["tenant_a"].id)}

    # Wizard payload mapping class/section/subject to TSA
    wizard_payload = {
        "school_id": str(data["school_a"].id),
        "academic_year_id": str(data["ay_a"].id),
        "exam_name": "Science Midterm 2026",
        "exam_type": "HALF_YEARLY",
        "start_date": "2026-06-01",
        "end_date": "2026-06-15",
        "description": "Science Half Yearly Exams",
        "schedules": [
          {
            "class_id": str(data["class_a"].id),
            "section_id": str(data["sec_a"].id),
            "subject_id": str(data["tsa_a"].subject_id),
            "teacher_subject_assignment_id": str(data["tsa_a"].id),
            "exam_date": "2026-06-05",
            "start_time": "09:00:00",
            "end_time": "12:00:00",
            "max_marks": 100,
            "pass_marks": 35,
            "room_number": "Room 101"
          }
        ]
    }

    # Execute Exam Wizard creation -> ALLOW
    res1 = await client.post(
        "/api/v1/examinations/wizard",
        json=wizard_payload,
        headers=headers_su
    )
    assert res1.status_code == 201
    exam_id = res1.json()["data"]["id"]

    # Publish Examination -> ALLOW
    res2 = await client.post(
        f"/api/v1/examinations/{exam_id}/publish?school_id={data['school_a'].id}",
        headers=headers_su
    )
    assert res2.status_code == 200
    assert res2.json()["data"]["status"] == "PUBLISHED"
