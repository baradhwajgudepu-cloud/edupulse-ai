import pytest
import uuid
from datetime import datetime, timezone
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.tenant import Tenant
from app.models.school import School, SchoolBoard, SchoolType, SchoolStatus
from app.models.user import User, UserStatus
from app.models.role import Role
from app.core.security import hash_password, create_access_token
from app.services.rbac_provisioning import ensure_tenant_rbac

@pytest.mark.anyio
async def test_principal_login_and_assigned_school_context(client: AsyncClient, db_session: AsyncSession):
    """
    Verifies that:
    1. A Principal account receives their assigned school(s) in /auth/me.
    2. Calling GET /schools returns strictly their assigned school.
    3. Accessing another school campus results in HTTP 403.
    """
    now = datetime.now(timezone.utc)
    # 1. Setup Tenant
    tenant_id = uuid.uuid4()
    uid = uuid.uuid4().hex[:6]
    tenant = Tenant(
        id=tenant_id,
        name="Telangana Education Society",
        code=f"TS_{uid}",
        subdomain=f"ts_{uid}",
        email=f"ts_{uid}@tes.edu"
    )
    db_session.add(tenant)
    await db_session.flush()
    await ensure_tenant_rbac(db_session, tenant_id)

    # 2. Setup Schools (TS001 and TS002)
    school_1 = School(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        name="Telangana Model School & Junior College",
        code=f"TS001_{uuid.uuid4().hex[:4].upper()}",
        board=SchoolBoard.STATE,
        school_type=SchoolType.HIGH_SCHOOL,
        email="ts001@telanganaschool.edu",
        is_active=True,
        status=SchoolStatus.ACTIVE
    )
    school_2 = School(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        name="Hyderabad Central High School",
        code=f"TS002_{uuid.uuid4().hex[:4].upper()}",
        board=SchoolBoard.CBSE,
        school_type=SchoolType.HIGH_SCHOOL,
        email="ts002@telanganaschool.edu",
        is_active=True,
        status=SchoolStatus.ACTIVE
    )
    db_session.add_all([school_1, school_2])
    await db_session.flush()

    # 3. Setup Principal for school_1 only
    role_res = await db_session.execute(
        Role.__table__.select().where(Role.tenant_id == tenant_id, Role.code == "PRINCIPAL")
    )
    role_row = role_res.first()
    principal_role = await db_session.get(Role, role_row.id)

    principal = User(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        email=f"principal_{uuid.uuid4().hex[:6]}@telanganaschool.edu",
        hashed_password=hash_password("ValidPass123!"),
        first_name="Ramesh",
        last_name="Chandra",
        status=UserStatus.ACTIVE,
        is_superuser=False,
        must_change_password=False,
        version=1,
        created_at=now,
        updated_at=now
    )
    principal.roles.append(principal_role)
    principal.schools.append(school_1)
    db_session.add(principal)
    await db_session.commit()

    # 4. Generate token and headers
    token = create_access_token(subject=principal.id, tenant_id=tenant_id)
    headers = {
        "Authorization": f"Bearer {token}",
        "X-Tenant-ID": str(tenant_id)
    }

    # Verify /auth/me returns school_1 in schools array
    r_me = await client.get("/api/v1/auth/me", headers=headers)
    assert r_me.status_code == 200
    me_data = r_me.json()["data"]
    assigned_school_ids = [s["id"] for s in me_data["schools"]]
    assert str(school_1.id) in assigned_school_ids
    assert str(school_2.id) not in assigned_school_ids

    # Verify GET /schools returns ONLY school_1
    r_schools = await client.get("/api/v1/schools", headers=headers)
    assert r_schools.status_code == 200
    schools_list = r_schools.json()["data"]
    assert len(schools_list) == 1
    assert schools_list[0]["id"] == str(school_1.id)
    assert schools_list[0]["name"] == school_1.name

    # Verify GET /schools/{id} for school_1 succeeds
    r_detail_1 = await client.get(f"/api/v1/schools/{school_1.id}", headers=headers)
    assert r_detail_1.status_code == 200

    # Verify GET /schools/{id} for school_2 is DENIED with 403
    r_detail_2 = await client.get(f"/api/v1/schools/{school_2.id}", headers=headers)
    assert r_detail_2.status_code == 403
    assert "not authorized" in r_detail_2.json()["detail"].lower()


@pytest.mark.anyio
async def test_principal_school_context_anti_spoofing(client: AsyncClient, db_session: AsyncSession):
    """
    Verifies that a Principal cannot spoof X-School-ID to access another school campus,
    and omitting X-School-ID safely auto-resolves for single-school users.
    """
    now = datetime.now(timezone.utc)
    tenant_id = uuid.uuid4()
    uid = uuid.uuid4().hex[:6]
    tenant = Tenant(
        id=tenant_id,
        name="Anti Spoof Tenant",
        code=f"AS_{uid}",
        subdomain=f"as_{uid}",
        email=f"as_{uid}@antispoof.edu"
    )
    db_session.add(tenant)
    await db_session.flush()
    await ensure_tenant_rbac(db_session, tenant_id)

    school_a = School(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        name="Campus Alpha",
        code=f"CA_{uuid.uuid4().hex[:4].upper()}",
        board=SchoolBoard.CBSE,
        school_type=SchoolType.HIGH_SCHOOL,
        email="alpha@campus.edu",
        is_active=True,
        status=SchoolStatus.ACTIVE
    )
    school_b = School(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        name="Campus Beta",
        code=f"CB_{uuid.uuid4().hex[:4].upper()}",
        board=SchoolBoard.ICSE,
        school_type=SchoolType.HIGH_SCHOOL,
        email="beta@campus.edu",
        is_active=True,
        status=SchoolStatus.ACTIVE
    )
    db_session.add_all([school_a, school_b])
    await db_session.flush()

    role_res = await db_session.execute(
        Role.__table__.select().where(Role.tenant_id == tenant_id, Role.code == "PRINCIPAL")
    )
    principal_role = await db_session.get(Role, role_res.first().id)

    principal = User(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        email=f"principal_spoof_{uuid.uuid4().hex[:6]}@campus.edu",
        hashed_password=hash_password("ValidPass123!"),
        first_name="Alpha",
        last_name="Principal",
        status=UserStatus.ACTIVE,
        is_superuser=False,
        must_change_password=False,
        version=1,
        created_at=now,
        updated_at=now
    )
    principal.roles.append(principal_role)
    principal.schools.append(school_a)
    db_session.add(principal)
    await db_session.commit()

    token = create_access_token(subject=principal.id, tenant_id=tenant_id)

    # 1. Attempt to use unauthorized school_b in X-School-ID header
    spoofed_headers = {
        "Authorization": f"Bearer {token}",
        "X-Tenant-ID": str(tenant_id),
        "X-School-ID": str(school_b.id)
    }

    r_spoofed = await client.get("/api/v1/fees/structures", headers=spoofed_headers)
    assert r_spoofed.status_code == 403
    assert "not authorized" in r_spoofed.json()["detail"].lower()

    # 2. Omit X-School-ID: auto-resolves to single assigned school_a
    auto_headers = {
        "Authorization": f"Bearer {token}",
        "X-Tenant-ID": str(tenant_id)
    }
    r_auto = await client.get("/api/v1/fees/structures", headers=auto_headers)
    assert r_auto.status_code == 200


@pytest.mark.anyio
async def test_principal_user_management_school_scoping(client: AsyncClient, db_session: AsyncSession):
    """
    Verifies that:
    1. Principal calling GET /identity/users retrieves only users linked to their assigned school.
    2. Super Admins and users from other schools are excluded.
    3. Cannot access platform administrators or users from other schools by ID.
    """
    now = datetime.now(timezone.utc)
    tenant_id = uuid.uuid4()
    uid = uuid.uuid4().hex[:6]
    tenant = Tenant(
        id=tenant_id,
        name="Identity Scope Tenant",
        code=f"IST_{uid}",
        subdomain=f"ist_{uid}",
        email=f"ist_{uid}@scope.edu"
    )
    db_session.add(tenant)
    await db_session.flush()
    await ensure_tenant_rbac(db_session, tenant_id)

    school_x = School(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        name="School X",
        code=f"SX_{uuid.uuid4().hex[:4].upper()}",
        board=SchoolBoard.CBSE,
        school_type=SchoolType.HIGH_SCHOOL,
        email="x@school.edu",
        is_active=True,
        status=SchoolStatus.ACTIVE
    )
    school_y = School(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        name="School Y",
        code=f"SY_{uuid.uuid4().hex[:4].upper()}",
        board=SchoolBoard.CBSE,
        school_type=SchoolType.HIGH_SCHOOL,
        email="y@school.edu",
        is_active=True,
        status=SchoolStatus.ACTIVE
    )
    db_session.add_all([school_x, school_y])
    await db_session.flush()

    # Roles
    p_role = (await db_session.execute(Role.__table__.select().where(Role.tenant_id == tenant_id, Role.code == "PRINCIPAL"))).first()
    t_role = (await db_session.execute(Role.__table__.select().where(Role.tenant_id == tenant_id, Role.code == "TEACHER"))).first()
    principal_role = await db_session.get(Role, p_role.id)
    teacher_role = await db_session.get(Role, t_role.id)

    # 1. Principal of School X
    principal_x = User(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        email=f"principal_x_{uuid.uuid4().hex[:6]}@x.edu",
        hashed_password=hash_password("Pass123!"),
        first_name="Principal",
        last_name="X",
        status=UserStatus.ACTIVE,
        is_superuser=False,
        must_change_password=False,
        version=1,
        created_at=now,
        updated_at=now
    )
    principal_x.roles.append(principal_role)
    principal_x.schools.append(school_x)

    # 2. Teacher in School X
    teacher_x = User(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        email=f"teacher_x_{uuid.uuid4().hex[:6]}@x.edu",
        hashed_password=hash_password("Pass123!"),
        first_name="Teacher",
        last_name="X",
        status=UserStatus.ACTIVE,
        is_superuser=False,
        must_change_password=False,
        version=1,
        created_at=now,
        updated_at=now
    )
    teacher_x.roles.append(teacher_role)
    teacher_x.schools.append(school_x)

    # 3. Teacher in School Y
    teacher_y = User(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        email=f"teacher_y_{uuid.uuid4().hex[:6]}@y.edu",
        hashed_password=hash_password("Pass123!"),
        first_name="Teacher",
        last_name="Y",
        status=UserStatus.ACTIVE,
        is_superuser=False,
        must_change_password=False,
        version=1,
        created_at=now,
        updated_at=now
    )
    teacher_y.roles.append(teacher_role)
    teacher_y.schools.append(school_y)

    # 4. Super Admin in Tenant
    super_admin = User(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        email=f"superadmin_{uuid.uuid4().hex[:6]}@platform.edu",
        hashed_password=hash_password("Pass123!"),
        first_name="Super",
        last_name="Admin",
        status=UserStatus.ACTIVE,
        is_superuser=True,
        must_change_password=False,
        version=1,
        created_at=now,
        updated_at=now
    )

    db_session.add_all([principal_x, teacher_x, teacher_y, super_admin])
    await db_session.commit()

    token_px = create_access_token(subject=principal_x.id, tenant_id=tenant_id)
    headers_px = {
        "Authorization": f"Bearer {token_px}",
        "X-Tenant-ID": str(tenant_id)
    }

    # Principal X calls GET /identity/users
    r_users = await client.get("/api/v1/identity/users", headers=headers_px)
    assert r_users.status_code == 200
    returned_user_ids = [u["id"] for u in r_users.json()["data"]]

    # Teacher X should be visible
    assert str(teacher_x.id) in returned_user_ids
    # Teacher Y (school Y) and Super Admin must NOT be visible
    assert str(teacher_y.id) not in returned_user_ids
    assert str(super_admin.id) not in returned_user_ids

    # Principal X trying to get details of Teacher Y -> 403
    r_ty = await client.get(f"/api/v1/identity/users/{teacher_y.id}", headers=headers_px)
    assert r_ty.status_code == 403

    # Principal X trying to get details of Super Admin -> 403
    r_sa = await client.get(f"/api/v1/identity/users/{super_admin.id}", headers=headers_px)
    assert r_sa.status_code == 403


@pytest.mark.anyio
async def test_super_admin_unrestricted_school_access(client: AsyncClient, db_session: AsyncSession):
    """
    Verifies that Platform Super Admin retains global / tenant-wide visibility across all schools.
    """
    now = datetime.now(timezone.utc)
    tenant_id = uuid.uuid4()
    uid = uuid.uuid4().hex[:6]
    tenant = Tenant(
        id=tenant_id,
        name="Global Tenant",
        code=f"GT_{uid}",
        subdomain=f"gt_{uid}",
        email=f"gt_{uid}@global.edu"
    )
    db_session.add(tenant)
    await db_session.flush()

    s1 = School(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        name="Global School 1",
        code=f"GS1_{uuid.uuid4().hex[:4].upper()}",
        board=SchoolBoard.CBSE,
        school_type=SchoolType.HIGH_SCHOOL,
        email="gs1@global.edu",
        is_active=True,
        status=SchoolStatus.ACTIVE
    )
    s2 = School(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        name="Global School 2",
        code=f"GS2_{uuid.uuid4().hex[:4].upper()}",
        board=SchoolBoard.ICSE,
        school_type=SchoolType.HIGH_SCHOOL,
        email="gs2@global.edu",
        is_active=True,
        status=SchoolStatus.ACTIVE
    )
    db_session.add_all([s1, s2])

    admin = User(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        email=f"admin_global_{uuid.uuid4().hex[:6]}@edupulse.com",
        hashed_password=hash_password("AdminPass123!"),
        first_name="Platform",
        last_name="SuperAdmin",
        status=UserStatus.ACTIVE,
        is_superuser=True,
        must_change_password=False,
        version=1,
        created_at=now,
        updated_at=now
    )
    db_session.add(admin)
    await db_session.commit()

    token = create_access_token(subject=admin.id, tenant_id=tenant_id)
    headers = {
        "Authorization": f"Bearer {token}",
        "X-Tenant-ID": str(tenant_id)
    }

    # Super Admin calls GET /schools -> returns both schools
    r = await client.get("/api/v1/schools", headers=headers)
    assert r.status_code == 200
    ids = [s["id"] for s in r.json()["data"]]
    assert str(s1.id) in ids
    assert str(s2.id) in ids
