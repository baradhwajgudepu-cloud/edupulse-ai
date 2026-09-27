import uuid
import pytest
from datetime import date, timedelta
from httpx import AsyncClient
from sqlalchemy import select, text
from sqlalchemy.orm import selectinload

from app.models.tenant import Tenant, TenantStatus
from app.models.school import School, SchoolBoard, SchoolType, SchoolStatus
from app.models.teacher import Teacher, TeacherStatus, EmploymentType
from app.models.role import Role
from app.models.permission import Permission
from app.models.user import User, UserStatus
from app.models.student import StudentGender
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
from app.services.auth import AuthService
from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate
from app.schemas.teacher import TeacherCreate
from app.schemas.auth import UserCreate
from app.core.security import hash_password, create_access_token
from app.services.rbac_provisioning import ensure_tenant_rbac

FIXED_HASH = hash_password("Password123!")


async def setup_school_environment(db_session, with_teacher: bool = True):
    suffix = uuid.uuid4().hex[:6].upper()
    repo_t = TenantRepository(db_session)
    tenant = await repo_t.create(TenantCreate(
        name=f"Tenant {suffix}", code=f"t-{suffix.lower()}",
        subdomain=f"t-{suffix.lower()}", email=f"tenant-{suffix.lower()}@t.com"
    ))

    repo_s = SchoolRepository(db_session)
    school = await repo_s.create(tenant.id, SchoolCreate(
        name=f"Telangana Model School {suffix}",
        code=f"TMS_{suffix}",
        board="CBSE",
        email=f"school-{suffix.lower()}@tms.edu"
    ))

    ay = AcademicYear(
        tenant_id=tenant.id,
        school_id=school.id,
        name="2026-2027",
        code=f"AY_{suffix}",
        start_date=date(2026, 6, 1),
        end_date=date(2027, 4, 30),
        status=AcademicYearStatus.ACTIVE,
        is_current=True
    )
    db_session.add(ay)
    await db_session.commit()

    # Permissions
    stmt_p = select(Permission)
    res_p = await db_session.execute(stmt_p)
    all_perms = list(res_p.scalars().all())

    stmt_role_t = select(Role).where(Role.tenant_id == tenant.id, Role.code == "TEACHER").options(selectinload(Role.permissions))
    res_role_t = await db_session.execute(stmt_role_t)
    role_teacher = res_role_t.scalar_one()

    stmt_role_p = select(Role).where(Role.tenant_id == tenant.id, Role.code == "PRINCIPAL").options(selectinload(Role.permissions))
    res_role_p = await db_session.execute(stmt_role_p)
    role_principal = res_role_p.scalar_one()

    role_teacher.permissions = [p for p in all_perms if p.code in [
        "teacher_leave.read", "teacher_leave.create", "teacher_leave.cancel", "announcement.read", "exam.read"
    ]]
    db_session.add(role_teacher)

    role_principal.permissions = [p for p in all_perms if p.code in [
        "teacher_leave.read", "teacher_leave.review", "teacher_leave.admin",
        "exam.create", "exam.read", "exam.update", "exam.publish",
        "announcement.create", "announcement.read", "announcement.update", "announcement.publish",
        "event.create", "event.read", "event.update", "event.publish",
        "reports.read"
    ]]
    db_session.add(role_principal)
    await db_session.commit()

    # Users
    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    auth_service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, repo_s)

    user_principal = await auth_service.create_user(
        tenant.id, UserCreate(email=f"principal-{suffix}@tms.edu", password="Password123!", first_name="Dr", last_name="Kiran")
    )
    user_principal.roles.append(role_principal)
    user_principal.schools.append(school)
    user_principal.status = UserStatus.ACTIVE
    db_session.add(user_principal)
    await db_session.commit()
    await db_session.refresh(user_principal)

    principal_token = create_access_token(subject=str(user_principal.id), tenant_id=str(tenant.id))

    teacher_profile = None
    teacher_token = None
    user_teacher = None

    if with_teacher:
        user_teacher = await auth_service.create_user(
            tenant.id, UserCreate(email=f"teacher-{suffix}@tms.edu", password="Password123!", first_name="Radha", last_name="Sharma")
        )
        user_teacher.roles.append(role_teacher)
        user_teacher.schools.append(school)
        user_teacher.status = UserStatus.ACTIVE
        db_session.add(user_teacher)
        await db_session.commit()
        await db_session.refresh(user_teacher)

        teacher_repo = TeacherRepository(db_session)
        teacher_profile = await teacher_repo.create(tenant.id, TeacherCreate(
            employee_code=f"EMP_{suffix}", staff_code=f"STF_{suffix}",
            first_name="Radha", last_name="Sharma", gender=StudentGender.FEMALE,
            date_of_birth=date(1990, 5, 15), mobile="9876543210",
            official_email=f"teacher-{suffix}@tms.edu", joining_date=date(2020, 6, 1),
            employment_type=EmploymentType.FULL_TIME, school_id=school.id
        ))
        teacher_profile.user_id = user_teacher.id
        db_session.add(teacher_profile)
        await db_session.commit()
        await db_session.refresh(teacher_profile)

        teacher_token = create_access_token(subject=str(user_teacher.id), tenant_id=str(tenant.id))

    return {
        "tenant": tenant,
        "school": school,
        "academic_year": ay,
        "principal": user_principal,
        "principal_token": principal_token,
        "teacher_user": user_teacher,
        "teacher_profile": teacher_profile,
        "teacher_token": teacher_token,
    }


@pytest.mark.anyio
async def test_newly_created_school_has_zero_baseline_and_isolated_context(client: AsyncClient, db_session):
    """
    Verifies that a newly created school starts with 0 students, 0 teachers,
    0 teacher leaves, 0 exams, and 0 circulars.
    """
    ctx = await setup_school_environment(db_session, with_teacher=False)
    school_id = str(ctx["school"].id)
    principal_headers = {
        "Authorization": f"Bearer {ctx['principal_token']}",
        "X-School-ID": school_id,
        "X-Tenant-ID": str(ctx["tenant"].id),
    }

    # 1. Check reports daily / dashboard summary
    rep_resp = await client.get(
        "/api/v1/reports/dashboard",
        headers=principal_headers
    )
    assert rep_resp.status_code == 200, rep_resp.text
    rep_data = rep_resp.json()["data"]
    assert rep_data["total_students"] == 0
    assert rep_data["active_teachers"] == 0

    # 2. Check Teacher Leaves
    leaves_resp = await client.get(
        "/api/v1/teacher-leaves",
        params={"school_id": school_id},
        headers=principal_headers
    )
    assert leaves_resp.status_code == 200, leaves_resp.text
    assert len(leaves_resp.json()["data"]) == 0

    # 3. Check Examinations
    exams_resp = await client.get(
        "/api/v1/examinations",
        params={"school_id": school_id},
        headers=principal_headers
    )
    assert exams_resp.status_code == 200, exams_resp.text
    assert len(exams_resp.json()["data"]) == 0

    # 4. Check Announcements
    ann_resp = await client.get(
        "/api/v1/announcements",
        params={"school_id": school_id},
        headers=principal_headers
    )
    assert ann_resp.status_code == 200, ann_resp.text
    assert len(ann_resp.json()["data"]) == 0


@pytest.mark.anyio
async def test_teacher_leave_lifecycle_submit_and_principal_review(client: AsyncClient, db_session):
    """
    Teacher submits leave request -> Principal reviews with approval and remarks.
    """
    ctx = await setup_school_environment(db_session, with_teacher=True)
    school_id = str(ctx["school"].id)
    t_headers = {
        "Authorization": f"Bearer {ctx['teacher_token']}",
        "X-School-ID": school_id,
        "X-Tenant-ID": str(ctx["tenant"].id),
    }
    p_headers = {
        "Authorization": f"Bearer {ctx['principal_token']}",
        "X-School-ID": school_id,
        "X-Tenant-ID": str(ctx["tenant"].id),
    }

    # 1. Teacher submits leave
    leave_payload = {
        "leave_type": "CASUAL",
        "start_date": "2026-10-05",
        "end_date": "2026-10-07",
        "reason": "Attending university graduation ceremony.",
        "remarks": "Classes will be covered by Dept Head."
    }
    submit_resp = await client.post("/api/v1/teacher-leaves", json=leave_payload, headers=t_headers)
    assert submit_resp.status_code == 201, submit_resp.text
    leave_id = submit_resp.json()["data"]["id"]
    assert submit_resp.json()["data"]["status"] == "PENDING"

    # 2. Principal retrieves leave requests
    list_resp = await client.get(
        "/api/v1/teacher-leaves",
        params={"school_id": school_id},
        headers=p_headers
    )
    assert list_resp.status_code == 200, list_resp.text
    leaves = list_resp.json()["data"]
    assert len(leaves) >= 1
    match = [l for l in leaves if l["id"] == leave_id]
    assert len(match) == 1
    assert match[0]["status"] == "PENDING"

    # 3. Principal approves leave
    review_resp = await client.post(
        f"/api/v1/teacher-leaves/{leave_id}/review",
        json={
            "decision": "APPROVE",
            "reviewer_remarks": "Approved. Please ensure syllabus coverage plan is shared."
        },
        headers=p_headers
    )
    assert review_resp.status_code == 200, review_resp.text
    reviewed_data = review_resp.json()["data"]
    assert reviewed_data["status"] == "APPROVED"
    assert reviewed_data["reviewer_remarks"] == "Approved. Please ensure syllabus coverage plan is shared."


@pytest.mark.anyio
async def test_examination_and_announcement_publish_workflow(client: AsyncClient, db_session):
    """
    Verifies Exam and Announcement creation (Draft) -> Publishing workflow.
    """
    ctx = await setup_school_environment(db_session, with_teacher=True)
    school_id = str(ctx["school"].id)
    ay_id = str(ctx["academic_year"].id)
    p_headers = {
        "Authorization": f"Bearer {ctx['principal_token']}",
        "X-School-ID": school_id,
        "X-Tenant-ID": str(ctx["tenant"].id),
    }

    # 1. Create Exam Wizard
    exam_payload = {
        "school_id": school_id,
        "academic_year_id": ay_id,
        "exam_name": "Mid-Term Assessment 2026",
        "exam_type": "HALF_YEARLY",
        "start_date": "2026-10-15",
        "end_date": "2026-10-25",
        "description": "Standard term summative evaluation.",
        "schedules": []
    }
    create_exam_resp = await client.post("/api/v1/examinations/wizard", json=exam_payload, headers=p_headers)
    assert create_exam_resp.status_code == 201, create_exam_resp.text
    exam_id = create_exam_resp.json()["data"]["id"]
    assert create_exam_resp.json()["data"]["status"] == "DRAFT"

    # Publish Exam
    pub_exam_resp = await client.post(
        f"/api/v1/examinations/{exam_id}/publish",
        params={"school_id": school_id},
        headers=p_headers
    )
    assert pub_exam_resp.status_code == 200, pub_exam_resp.text
    assert pub_exam_resp.json()["data"]["status"] == "PUBLISHED"

    # 2. Create Announcement / Circular
    ann_payload = {
        "title": "Annual Science Fair Circular",
        "message": "All students from classes 6-10 are invited to present project abstracts.",
        "audience_type": "ROLE",
        "priority": "HIGH"
    }
    create_ann_resp = await client.post(
        "/api/v1/announcements",
        params={"school_id": school_id},
        json=ann_payload,
        headers=p_headers
    )
    assert create_ann_resp.status_code == 201, create_ann_resp.text
    ann_id = create_ann_resp.json()["data"]["id"]
    assert create_ann_resp.json()["data"]["status"] == "DRAFT"

    # Publish Announcement
    pub_ann_resp = await client.post(
        f"/api/v1/announcements/{ann_id}/publish",
        params={"school_id": school_id},
        headers=p_headers
    )
    assert pub_ann_resp.status_code == 200, pub_ann_resp.text
    assert pub_ann_resp.json()["data"]["status"] == "PUBLISHED"


@pytest.mark.anyio
async def test_cross_school_isolation_and_unauthorized_review_rejection(client: AsyncClient, db_session):
    """
    Verifies that Principal of School B cannot see or approve School A's leave requests.
    """
    ctx_a = await setup_school_environment(db_session, with_teacher=True)
    ctx_b = await setup_school_environment(db_session, with_teacher=True)

    school_a_id = str(ctx_a["school"].id)
    school_b_id = str(ctx_b["school"].id)

    # Teacher A submits leave in School A
    t_headers_a = {
        "Authorization": f"Bearer {ctx_a['teacher_token']}",
        "X-School-ID": school_a_id,
        "X-Tenant-ID": str(ctx_a["tenant"].id),
    }
    leave_resp = await client.post("/api/v1/teacher-leaves", json={
        "leave_type": "SICK",
        "start_date": "2026-11-01",
        "end_date": "2026-11-02",
        "reason": "Viral fever recovery."
    }, headers=t_headers_a)
    assert leave_resp.status_code == 201
    leave_id = leave_resp.json()["data"]["id"]

    # Principal B queries School B's leaves: must be empty
    p_headers_b = {
        "Authorization": f"Bearer {ctx_b['principal_token']}",
        "X-School-ID": school_b_id,
        "X-Tenant-ID": str(ctx_b["tenant"].id),
    }
    list_b = await client.get(
        "/api/v1/teacher-leaves",
        params={"school_id": school_b_id},
        headers=p_headers_b
    )
    assert list_b.status_code == 200
    assert len(list_b.json()["data"]) == 0

    # Principal B attempts to query School A leaves: rejected with 403
    cross_list = await client.get(
        "/api/v1/teacher-leaves",
        params={"school_id": school_a_id},
        headers=p_headers_b
    )
    assert cross_list.status_code == 403

    # Principal B attempts to review School A's leave: rejected with 403
    cross_review = await client.post(
        f"/api/v1/teacher-leaves/{leave_id}/review",
        json={"decision": "APPROVE", "reviewer_remarks": "Unauthorized approval attempt"},
        headers=p_headers_b
    )
    assert cross_review.status_code in (403, 404)
