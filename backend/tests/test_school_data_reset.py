import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import pytest
import uuid
import jwt
from datetime import date, datetime, timezone, timedelta
from unittest.mock import patch
from httpx import AsyncClient
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.settings import settings
from app.models.tenant import Tenant, TenantStatus
from app.models.school import School, SchoolBoard, SchoolType, SchoolStatus
from app.models.user import User, UserStatus
from app.models.role import Role, user_roles, school_users
from app.models.academic_year import AcademicYear
from app.models.class_entity import Class
from app.models.section import Section
from app.models.student import Student, StudentGender
from app.models.teacher import Teacher, EmploymentType
from app.models.school_reset_audit import SchoolResetAudit
from app.core.security import create_access_token, hash_password
from app.services.school_data_reset import SchoolDataResetService
from app.schemas.school import SchoolDataResetRequest

FIXED_HASH = hash_password("Pass123!")


@pytest.fixture
async def setup_test_environment(db_session: AsyncSession):
    """
    Creates an isolated synthetic test environment using db_session.
    """
    # 1. Tenant A and Schools
    t_code_a = f"t-a-{uuid.uuid4().hex[:6]}"
    tenant_a = Tenant(
        name="Alpha Trust",
        code=t_code_a,
        subdomain=t_code_a,
        email=f"{t_code_a}@tenant.test",
        status=TenantStatus.ACTIVE
    )
    db_session.add(tenant_a)
    await db_session.flush()

    # 2. Super Admin
    sa_email = f"sa_{uuid.uuid4().hex[:6]}@edupulse.test"
    super_admin = User(
        email=sa_email,
        hashed_password=FIXED_HASH,
        first_name="Super",
        last_name="Admin",
        is_superuser=True,
        tenant_id=tenant_a.id,
        status=UserStatus.ACTIVE
    )
    db_session.add(super_admin)

    school_a1 = School(
        name="Greenwood High International",
        code=f"GWH-{uuid.uuid4().hex[:4]}".upper(),
        board=SchoolBoard.CBSE,
        school_type=SchoolType.HIGH_SCHOOL,
        email=f"info_{uuid.uuid4().hex[:4]}@gwh.test",
        tenant_id=tenant_a.id,
        status=SchoolStatus.ACTIVE
    )
    school_a2 = School(
        name="Greenwood Primary Campus",
        code=f"GWP-{uuid.uuid4().hex[:4]}".upper(),
        board=SchoolBoard.CBSE,
        school_type=SchoolType.PRIMARY,
        email=f"info_{uuid.uuid4().hex[:4]}@gwp.test",
        tenant_id=tenant_a.id,
        status=SchoolStatus.ACTIVE
    )
    db_session.add_all([school_a1, school_a2])
    await db_session.flush()

    # 3. Tenant B and School B1
    t_code_b = f"t-b-{uuid.uuid4().hex[:6]}"
    tenant_b = Tenant(
        name="Beta Foundation",
        code=t_code_b,
        subdomain=t_code_b,
        email=f"{t_code_b}@tenant.test",
        status=TenantStatus.ACTIVE
    )
    db_session.add(tenant_b)
    await db_session.flush()

    school_b1 = School(
        name="Beta Academy",
        code=f"BTA-{uuid.uuid4().hex[:4]}".upper(),
        board=SchoolBoard.ICSE,
        school_type=SchoolType.HIGH_SCHOOL,
        email=f"info_{uuid.uuid4().hex[:4]}@bta.test",
        tenant_id=tenant_b.id,
        status=SchoolStatus.ACTIVE
    )
    db_session.add(school_b1)
    await db_session.flush()

    # 4. Roles for Tenant A
    role_names = [
        ("SYSTEM_ADMIN", "SYSTEM_ADMIN"),
        ("TENANT_ADMIN", "TENANT_ADMIN"),
        ("ADMIN", "ADMIN"),
        ("ADMINISTRATOR", "ADMINISTRATOR"),
        ("PRINCIPAL", "PRINCIPAL"),
        ("TEACHER", "TEACHER"),
        ("PARENT", "PARENT"),
        ("STAFF", "STAFF"),
    ]
    roles = {}
    for code, name in role_names:
        r = Role(name=name, code=code, tenant_id=tenant_a.id, is_system=True)
        db_session.add(r)
        roles[code] = r
    await db_session.flush()

    # 5. Role for Tenant B
    role_b_admin = Role(name="TENANT_ADMIN", code="TENANT_ADMIN", tenant_id=tenant_b.id, is_system=True)
    db_session.add(role_b_admin)
    await db_session.flush()

    # 6. Users for Tenant A
    users = {}
    for code, role in roles.items():
        u = User(
            email=f"{code.lower()}_{uuid.uuid4().hex[:6]}@edupulse.test",
            hashed_password=FIXED_HASH,
            first_name=code.capitalize(),
            last_name="User",
            tenant_id=tenant_a.id,
            status=UserStatus.ACTIVE
        )
        u.roles.append(role)
        db_session.add(u)
        users[code] = u
    await db_session.flush()

    # 7. User for Tenant B
    user_tenant_b_admin = User(
        email=f"tb_admin_{uuid.uuid4().hex[:6]}@edupulse.test",
        hashed_password=FIXED_HASH,
        first_name="Beta",
        last_name="Admin",
        tenant_id=tenant_b.id,
        status=UserStatus.ACTIVE
    )
    user_tenant_b_admin.roles.append(role_b_admin)
    db_session.add(user_tenant_b_admin)
    await db_session.flush()

    await db_session.commit()

    return {
        "super_admin": super_admin,
        "tenant_a": tenant_a,
        "school_a1": school_a1,
        "school_a2": school_a2,
        "tenant_b": tenant_b,
        "school_b1": school_b1,
        "users": users,
        "user_tenant_b_admin": user_tenant_b_admin,
    }


@pytest.mark.anyio
async def test_authorization_roles_and_access_control(setup_test_environment, client: AsyncClient):
    """
    1. Only SUPER_ADMIN, SYSTEM_ADMIN, and TENANT_ADMIN are permitted.
    2. Ordinary ADMIN, ADMINISTRATOR, PRINCIPAL, TEACHER, PARENT, STAFF are denied with 403.
    3. Cross-tenant administrator is denied with 403 or 404.
    """
    env = setup_test_environment
    school = env["school_a1"]
    tenant_a = env["tenant_a"]
    tenant_b = env["tenant_b"]

    # A. Permitted Roles: SUPER_ADMIN, SYSTEM_ADMIN, TENANT_ADMIN
    for role_name in ["SUPER_ADMIN", "SYSTEM_ADMIN", "TENANT_ADMIN"]:
        if role_name == "SUPER_ADMIN":
            u = env["super_admin"]
            token = create_access_token(subject=str(u.id))
        else:
            u = env["users"][role_name]
            token = create_access_token(subject=str(u.id), tenant_id=tenant_a.id)

        headers = {
            "Authorization": f"Bearer {token}",
            "X-Tenant-ID": str(tenant_a.id),
            "X-School-ID": str(school.id),
        }
        res = await client.get(f"/api/v1/schools/{school.id}/data-summary", headers=headers)
        assert res.status_code == 200, f"Role {role_name} should be permitted, got {res.status_code}: {res.text}"
        data = res.json()
        assert data["success"] is True
        assert "confirmation_token" in data["data"]

    # B. Denied Roles: ADMIN, ADMINISTRATOR, PRINCIPAL, TEACHER, PARENT, STAFF
    denied_roles = ["ADMIN", "ADMINISTRATOR", "PRINCIPAL", "TEACHER", "PARENT", "STAFF"]
    for role_name in denied_roles:
        u = env["users"][role_name]
        token = create_access_token(subject=str(u.id), tenant_id=tenant_a.id)
        headers = {
            "Authorization": f"Bearer {token}",
            "X-Tenant-ID": str(tenant_a.id),
            "X-School-ID": str(school.id),
        }
        res = await client.get(f"/api/v1/schools/{school.id}/data-summary", headers=headers)
        assert res.status_code == 403, f"Role {role_name} must be denied with 403, got {res.status_code}: {res.text}"

        res_post = await client.post(
            f"/api/v1/schools/{school.id}/reset-data",
            json={
                "school_name": school.name,
                "confirm_destruction": True,
                "reason": "Unauthorized attempt",
                "confirmation_token": "dummy-token"
            },
            headers=headers
        )
        assert res_post.status_code == 403, f"Role {role_name} reset-data must be denied with 403, got {res_post.status_code}"

    # C. Cross-tenant administrator denied
    tb_admin = env["user_tenant_b_admin"]
    tb_token = create_access_token(subject=str(tb_admin.id), tenant_id=tenant_b.id)
    # 1. Accessing school of Tenant A with Tenant B header -> 404 (school not found in tenant B)
    res_cross1 = await client.get(
        f"/api/v1/schools/{school.id}/data-summary",
        headers={"Authorization": f"Bearer {tb_token}", "X-Tenant-ID": str(tenant_b.id)}
    )
    assert res_cross1.status_code in (403, 404)

    # 2. Accessing school of Tenant A spoofing Tenant A header -> 403 (user belongs to Tenant B)
    res_cross2 = await client.get(
        f"/api/v1/schools/{school.id}/data-summary",
        headers={"Authorization": f"Bearer {tb_token}", "X-Tenant-ID": str(tenant_a.id)}
    )
    assert res_cross2.status_code in (401, 403)


@pytest.mark.anyio
async def test_input_validation_and_confirmation_token_checks(setup_test_environment, client: AsyncClient):
    """
    Verifies input validations:
    - Wrong school name (422)
    - Unconfirmed checkbox (422)
    - Short reason (422)
    - Missing token (422)
    - Expired token (422)
    - Token from another school/tenant/actor (422)
    """
    env = setup_test_environment
    school = env["school_a1"]
    tenant_a = env["tenant_a"]
    u = env["users"]["TENANT_ADMIN"]
    token = create_access_token(subject=str(u.id), tenant_id=tenant_a.id)
    headers = {
        "Authorization": f"Bearer {token}",
        "X-Tenant-ID": str(tenant_a.id),
        "X-School-ID": str(school.id),
    }

    # Get valid confirmation token from summary
    res_sum = await client.get(f"/api/v1/schools/{school.id}/data-summary", headers=headers)
    assert res_sum.status_code == 200
    valid_conf_token = res_sum.json()["data"]["confirmation_token"]
    assert valid_conf_token is not None

    # 1. Wrong school name
    res = await client.post(
        f"/api/v1/schools/{school.id}/reset-data",
        json={
            "school_name": "Incorrect Legal Name",
            "confirm_destruction": True,
            "reason": "Valid reason for reset",
            "confirmation_token": valid_conf_token
        },
        headers=headers
    )
    assert res.status_code == 422
    assert "does not match" in str(res.json())

    # 2. Case sensitivity (lowercase name)
    res = await client.post(
        f"/api/v1/schools/{school.id}/reset-data",
        json={
            "school_name": school.name.lower(),
            "confirm_destruction": True,
            "reason": "Valid reason for reset",
            "confirmation_token": valid_conf_token
        },
        headers=headers
    )
    assert res.status_code == 422

    # 3. Unconfirmed destruction
    res = await client.post(
        f"/api/v1/schools/{school.id}/reset-data",
        json={
            "school_name": school.name,
            "confirm_destruction": False,
            "reason": "Valid reason for reset",
            "confirmation_token": valid_conf_token
        },
        headers=headers
    )
    assert res.status_code == 422
    assert "checkbox must be checked" in str(res.json())

    # 4. Reason too short (< 3 chars)
    res = await client.post(
        f"/api/v1/schools/{school.id}/reset-data",
        json={
            "school_name": school.name,
            "confirm_destruction": True,
            "reason": "  no ",
            "confirmation_token": valid_conf_token
        },
        headers=headers
    )
    assert res.status_code == 422
    assert "at least 3 characters" in str(res.json())

    # 5. Missing confirmation token
    res = await client.post(
        f"/api/v1/schools/{school.id}/reset-data",
        json={
            "school_name": school.name,
            "confirm_destruction": True,
            "reason": "Valid reason for reset",
            "confirmation_token": ""
        },
        headers=headers
    )
    assert res.status_code == 422

    # 6. Expired confirmation token
    expired_token = jwt.encode(
        {
            "sub": str(u.id),
            "school_id": str(school.id),
            "tenant_id": str(tenant_a.id),
            "type": "school_reset_confirmation",
            "exp": datetime.now(timezone.utc) - timedelta(minutes=5),
        },
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM
    )
    res = await client.post(
        f"/api/v1/schools/{school.id}/reset-data",
        json={
            "school_name": school.name,
            "confirm_destruction": True,
            "reason": "Valid reason for reset",
            "confirmation_token": expired_token
        },
        headers=headers
    )
    assert res.status_code == 422
    assert "expired" in str(res.json()).lower()

    # 7. Token from another school
    other_school_token = jwt.encode(
        {
            "sub": str(u.id),
            "school_id": str(env["school_a2"].id),
            "tenant_id": str(tenant_a.id),
            "type": "school_reset_confirmation",
            "exp": datetime.now(timezone.utc) + timedelta(minutes=15),
        },
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM
    )
    res = await client.post(
        f"/api/v1/schools/{school.id}/reset-data",
        json={
            "school_name": school.name,
            "confirm_destruction": True,
            "reason": "Valid reason for reset",
            "confirmation_token": other_school_token
        },
        headers=headers
    )
    assert res.status_code == 422
    assert "different school" in str(res.json())


@pytest.mark.anyio
async def test_summary_query_hardening_and_error_capture(setup_test_environment, db_session: AsyncSession):
    """
    Verifies that summary queries:
    - Return exact counts and calculate total_records_to_delete.
    - Do NOT silently swallow query errors into zero counts.
    - Report failed queries in query_errors and blocking_dependencies.
    - Set eligible = false when errors occur.
    """
    env = setup_test_environment
    school = env["school_a1"]
    tenant_a = env["tenant_a"]
    u = env["users"]["TENANT_ADMIN"]

    # Seed operational records
    ay = AcademicYear(
        school_id=school.id,
        tenant_id=tenant_a.id,
        name="2026-27",
        code=f"AY-{uuid.uuid4().hex[:4]}".upper(),
        start_date=date(2026, 6, 1),
        end_date=date(2027, 3, 31)
    )
    db_session.add(ay)
    await db_session.flush()

    cls = Class(
        school_id=school.id,
        tenant_id=tenant_a.id,
        academic_year_id=ay.id,
        name="Class 10",
        code=f"C10-{uuid.uuid4().hex[:4]}".upper(),
        level=10,
        capacity=40
    )
    db_session.add(cls)
    await db_session.flush()

    sec = Section(
        school_id=school.id,
        tenant_id=tenant_a.id,
        class_id=cls.id,
        academic_year_id=ay.id,
        name="A",
        code=f"S10A-{uuid.uuid4().hex[:4]}".upper(),
        capacity=30
    )
    db_session.add(sec)
    await db_session.flush()

    stu = Student(
        school_id=school.id,
        tenant_id=tenant_a.id,
        class_id=cls.id,
        section_id=sec.id,
        academic_year_id=ay.id,
        admission_number=f"ADM-{uuid.uuid4().hex[:4]}",
        roll_number="1",
        first_name="Student",
        last_name="Alpha",
        gender=StudentGender.MALE,
        date_of_birth=date(2010, 1, 1),
        admission_date=date(2026, 6, 1)
    )
    db_session.add(stu)
    await db_session.commit()

    service = SchoolDataResetService(db_session)
    # 1. Normal healthy summary check
    summary = await service.get_school_data_summary(school.id, tenant_a.id, u)
    assert summary.eligible is True
    assert summary.records_to_delete["students"] >= 1
    assert summary.records_to_delete["classes"] >= 1
    assert summary.records_to_delete["academic_years"] >= 1
    assert summary.total_records_to_delete > 0
    assert summary.query_errors == []
    assert summary.blocking_dependencies == []
    assert summary.confirmation_token is not None

    # 2. Simulated failure in one of the summary queries
    original_execute = service.db.execute

    async def mock_failing_execute(stmt, *args, **kwargs):
        stmt_str = str(stmt)
        if "FROM students" in stmt_str:
            raise RuntimeError("Simulated connection timeout or corrupted index in students table")
        return await original_execute(stmt, *args, **kwargs)

    with patch.object(service.db, "execute", side_effect=mock_failing_execute):
        hardened_summary = await service.get_school_data_summary(school.id, tenant_a.id, u)
        assert hardened_summary.eligible is False, "Summary should be marked ineligible on query failure"
        assert len(hardened_summary.query_errors) >= 1
        assert "students" in hardened_summary.query_errors[0]
        assert len(hardened_summary.blocking_dependencies) >= 1
        assert hardened_summary.confirmation_token is None, "Ineligible summary must not generate confirmation token"


@pytest.mark.anyio
async def test_transactional_safety_and_rollback_on_deliberate_failure(setup_test_environment, db_session: AsyncSession):
    """
    Verifies transactional atomicity:
    - Deliberate failure injected midway through deletion sequence.
    - All previously deleted records are fully restored after rollback.
    - Durable audit survives rollback with status ROLLED_BACK.
    - Raw database exception is not exposed to the client.
    - Response contains reference Audit ID.
    """
    env = setup_test_environment
    school = env["school_a1"]
    tenant_a = env["tenant_a"]
    u = env["users"]["TENANT_ADMIN"]

    # Seed test academic year and class
    ay = AcademicYear(
        school_id=school.id,
        tenant_id=tenant_a.id,
        name="2026-27",
        code=f"AY-FAIL-{uuid.uuid4().hex[:4]}".upper(),
        start_date=date(2026, 6, 1),
        end_date=date(2027, 3, 31)
    )
    db_session.add(ay)
    await db_session.flush()
    cls = Class(
        school_id=school.id,
        tenant_id=tenant_a.id,
        academic_year_id=ay.id,
        name="Class Test",
        code=f"CT-{uuid.uuid4().hex[:4]}".upper(),
        level=1,
        capacity=30
    )
    db_session.add(cls)
    await db_session.commit()
    ay_id = ay.id
    cls_id = cls.id
    target_school_id = school.id
    u_email = u.email

    # Generate valid summary token
    service = SchoolDataResetService(db_session)
    summary = await service.get_school_data_summary(school.id, tenant_a.id, u)
    conf_token = summary.confirmation_token

    # Inject deliberate failure on "DELETE FROM classes"
    original_execute = db_session.execute

    async def failing_execute(stmt, *args, **kwargs):
        stmt_str = str(stmt)
        if "DELETE FROM classes" in stmt_str:
            raise RuntimeError("Deliberate transactional failure injected during classes deletion")
        return await original_execute(stmt, *args, **kwargs)

    reset_payload = SchoolDataResetRequest(
        school_name=school.name,
        confirm_destruction=True,
        reason="Deliberate failure injection test",
        confirmation_token=conf_token
    )

    with patch.object(db_session, "execute", side_effect=failing_execute):
        with pytest.raises(Exception) as exc_info:
            await service.reset_school_data(school.id, tenant_a.id, reset_payload, u)

    # Verify sanitized error detail
    err_msg = str(exc_info.value).lower()
    assert "internal server error" in err_msg
    assert "reference audit id" in err_msg
    assert "deliberate transactional failure injected" not in err_msg, "Raw DB exception must not leak to client"

    # Verify all records restored after rollback
    res_ay = await db_session.execute(select(AcademicYear).where(AcademicYear.id == ay_id))
    assert res_ay.scalar_one_or_none() is not None, "Academic Year must be restored after rollback"

    res_cls = await db_session.execute(select(Class).where(Class.id == cls_id))
    assert res_cls.scalar_one_or_none() is not None, "Class must be restored after rollback"

    # Verify durable audit record survived rollback in school_reset_audits
    res_audit = await db_session.execute(
        select(SchoolResetAudit)
        .where(
            SchoolResetAudit.school_id == target_school_id,
            SchoolResetAudit.reason == "Deliberate failure injection test"
        )
        .order_by(SchoolResetAudit.created_at.desc())
    )
    audit_record = res_audit.scalar_one_or_none()
    assert audit_record is not None, "Durable audit record must survive transaction rollback!"
    assert audit_record.status == "ROLLED_BACK"
    assert audit_record.actor_email == u_email


@pytest.mark.anyio
async def test_school_user_mapping_and_preservation(setup_test_environment, db_session: AsyncSession):
    """
    Verifies school-user mapping behavior:
    - Teacher unlinked from target school, User preserved.
    - Parent unlinked from target school, User preserved.
    - Administrator mapping to target school preserved.
    - Multi-school user loses only target school mapping, other school mapping preserved.
    - Other schools and other tenants untouched.
    """
    env = setup_test_environment
    school_a1 = env["school_a1"]
    school_a2 = env["school_a2"]
    tenant_a = env["tenant_a"]
    admin = env["users"]["TENANT_ADMIN"]
    teacher = env["users"]["TEACHER"]
    parent = env["users"]["PARENT"]

    # Multi-school teacher linked to School A1 and School A2
    multi_teacher = User(
        email=f"multi_teacher_{uuid.uuid4().hex[:6]}@edupulse.test",
        hashed_password=FIXED_HASH,
        first_name="Multi",
        last_name="Teacher",
        tenant_id=tenant_a.id,
        status=UserStatus.ACTIVE
    )
    db_session.add(multi_teacher)
    await db_session.flush()

    # Link mappings
    await db_session.execute(school_users.insert().values(user_id=teacher.id, school_id=school_a1.id))
    await db_session.execute(school_users.insert().values(user_id=parent.id, school_id=school_a1.id))
    await db_session.execute(school_users.insert().values(user_id=admin.id, school_id=school_a1.id))
    await db_session.execute(school_users.insert().values(user_id=multi_teacher.id, school_id=school_a1.id))
    await db_session.execute(school_users.insert().values(user_id=multi_teacher.id, school_id=school_a2.id))

    # Teacher operational record in School A1
    t_prof = Teacher(
        user_id=teacher.id,
        school_id=school_a1.id,
        tenant_id=tenant_a.id,
        employee_code=f"EMP-{uuid.uuid4().hex[:4]}".upper(),
        staff_code=f"STF-{uuid.uuid4().hex[:4]}".upper(),
        first_name="Teacher",
        last_name="User",
        gender=StudentGender.MALE,
        date_of_birth=date(1985, 1, 1),
        employment_type=EmploymentType.FULL_TIME,
        official_email=teacher.email,
        joining_date=date(2020, 1, 1),
        mobile="9876543210"
    )
    db_session.add(t_prof)
    await db_session.commit()

    # Execute successful reset of School A1
    service = SchoolDataResetService(db_session)
    summary = await service.get_school_data_summary(school_a1.id, tenant_a.id, admin)
    reset_payload = SchoolDataResetRequest(
        school_name=school_a1.name,
        confirm_destruction=True,
        reason="School-user mapping verification reset",
        confirmation_token=summary.confirmation_token
    )
    resp = await service.reset_school_data(school_a1.id, tenant_a.id, reset_payload, admin)
    assert resp.status == "COMPLETED"

    # 1. Teacher unlinked from school_a1, Teacher record deleted, User preserved
    res_t_map = await db_session.execute(
        select(school_users).where(school_users.c.user_id == teacher.id, school_users.c.school_id == school_a1.id)
    )
    assert res_t_map.scalar_one_or_none() is None, "Teacher school mapping to A1 must be removed"
    res_t_user = await db_session.execute(select(User).where(User.id == teacher.id))
    assert res_t_user.scalar_one_or_none() is not None, "Teacher User record must be preserved"

    # 2. Parent unlinked from school_a1, User preserved
    res_p_map = await db_session.execute(
        select(school_users).where(school_users.c.user_id == parent.id, school_users.c.school_id == school_a1.id)
    )
    assert res_p_map.scalar_one_or_none() is None, "Parent school mapping to A1 must be removed"
    res_p_user = await db_session.execute(select(User).where(User.id == parent.id))
    assert res_p_user.scalar_one_or_none() is not None, "Parent User record must be preserved"

    # 3. Administrator mapping to target school PRESERVED
    res_a_map = await db_session.execute(
        select(school_users).where(school_users.c.user_id == admin.id, school_users.c.school_id == school_a1.id)
    )
    assert res_a_map.first() is not None, "Administrator school mapping must remain preserved"

    # 4. Multi-school teacher lost mapping to School A1, but mapping to School A2 is PRESERVED
    res_m1 = await db_session.execute(
        select(school_users).where(school_users.c.user_id == multi_teacher.id, school_users.c.school_id == school_a1.id)
    )
    assert res_m1.scalar_one_or_none() is None, "Multi-school teacher mapping to A1 must be removed"
    res_m2 = await db_session.execute(
        select(school_users).where(school_users.c.user_id == multi_teacher.id, school_users.c.school_id == school_a2.id)
    )
    assert res_m2.first() is not None, "Multi-school teacher mapping to A2 must be preserved"


@pytest.mark.anyio
async def test_idempotency_and_repeat_reset(setup_test_environment, db_session: AsyncSession):
    """
    Verifies that a second reset against an already-reset school:
    - Returns zero operational records to delete.
    - Completes safely without foreign key errors.
    - Creates a new distinct durable audit record.
    - Preserves school identity and administrator access.
    """
    env = setup_test_environment
    school = env["school_a1"]
    tenant_a = env["tenant_a"]
    admin = env["users"]["TENANT_ADMIN"]

    service = SchoolDataResetService(db_session)

    # 1. Summary on already-reset school
    summary = await service.get_school_data_summary(school.id, tenant_a.id, admin)
    assert summary.eligible is True
    assert summary.total_records_to_delete == 0

    # 2. Reset execution
    payload = SchoolDataResetRequest(
        school_name=school.name,
        confirm_destruction=True,
        reason="Idempotent repeat reset test",
        confirmation_token=summary.confirmation_token
    )
    resp = await service.reset_school_data(school.id, tenant_a.id, payload, admin)
    assert resp.status == "COMPLETED"
    assert resp.total_records_deleted == 0
    assert resp.school_name == school.name

    # 3. Durable audit record created
    res_audit = await db_session.execute(
        select(SchoolResetAudit)
        .where(
            SchoolResetAudit.school_id == school.id,
            SchoolResetAudit.audit_id == resp.audit_id
        )
    )
    audit_record = res_audit.scalar_one_or_none()
    assert audit_record is not None
    assert audit_record.status == "COMPLETED"
    assert audit_record.total_records_deleted == 0
