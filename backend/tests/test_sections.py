import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy import select, text
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tenant import Tenant
from app.models.school import School
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.class_entity import Class, ClassStatus, ClassCategory
from app.models.section import Section, SectionStatus
from app.models.role import Role
from app.models.permission import Permission
from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.section import SectionRepository
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
from app.services.auth import AuthService
from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate
from app.schemas.academic_year import AcademicYearCreate
from app.schemas.class_entity import ClassCreate
from app.schemas.section import SectionCreate
from app.schemas.auth import UserCreate

@pytest.fixture
async def setup_section_data(db_session):
    """
    Sets up testing context:
    - Tenant A, School A, Academic Year A (ACTIVE)
    - Tenant B, School B, Academic Year B (ACTIVE)
    - Class A, Class B
    - Super Admin user with credentials
    """
    suffix = uuid.uuid4().hex[:6].upper()
    repo_t = TenantRepository(db_session)
    tenant_a = await repo_t.create(TenantCreate(name="Tenant A", code=f"tenant-a-{suffix.lower()}", subdomain=f"t-a-{suffix.lower()}", email=f"a-{suffix.lower()}@t.com"))
    tenant_b = await repo_t.create(TenantCreate(name="Tenant B", code=f"tenant-b-{suffix.lower()}", subdomain=f"t-b-{suffix.lower()}", email=f"b-{suffix.lower()}@t.com"))

    repo_s = SchoolRepository(db_session)
    school_a = await repo_s.create(tenant_a.id, SchoolCreate(name="School A", code=f"SCH_A_{suffix}", board="CBSE", email=f"s-a-{suffix.lower()}@a.com"))
    school_b = await repo_s.create(tenant_b.id, SchoolCreate(name="School B", code=f"SCH_B_{suffix}", board="CBSE", email=f"s-b-{suffix.lower()}@b.com"))

    repo_ay = AcademicYearRepository(db_session)
    ay_a = await repo_ay.create(
        tenant_a.id,
        school_a.id,
        AcademicYearCreate(name="2026-2027", code="AY2026-2027", start_date="2026-06-01", end_date="2027-04-30")
    )
    ay_a.status = AcademicYearStatus.ACTIVE

    ay_b = await repo_ay.create(
        tenant_b.id,
        school_b.id,
        AcademicYearCreate(name="2026-2027", code="AY2026-2027", start_date="2026-06-01", end_date="2027-04-30")
    )
    ay_b.status = AcademicYearStatus.ACTIVE

    repo_c = ClassRepository(db_session)
    class_a = await repo_c.create(
        tenant_a.id,
        ClassCreate(
            school_id=school_a.id,
            academic_year_id=ay_a.id,
            name="Class 10",
            code="CLASS_10A",
            level=10,
            category=ClassCategory.HIGH,
            capacity=40
        )
    )

    class_b = await repo_c.create(
        tenant_b.id,
        ClassCreate(
            school_id=school_b.id,
            academic_year_id=ay_b.id,
            name="Class 10",
            code="CLASS_10B",
            level=10,
            category=ClassCategory.HIGH,
            capacity=40
        )
    )
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

    user_a = await auth_service.create_user(
        tenant_a.id,
        UserCreate(email=f"admin-{suffix}@a.com", password="Password123!", first_name="Admin", last_name="User")
    )
    user_a.roles.append(role_a)

    # Map user to School A
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
        "class_a": class_a,
        "class_b": class_b,
        "user_a": user_a,
        "auth_headers": {
            "Authorization": f"Bearer {tokens.access_token}",
            "X-Tenant-ID": str(tenant_a.id)
        }
    }

@pytest.mark.anyio
async def test_section_crud_flow(client: AsyncClient, setup_section_data, db_session) -> None:
    """
    Verifies Section CRUD endpoints:
    - POST create section
    - GET list sections
    - GET fetch section details
    - PUT update section parameters
    - DELETE soft-delete section
    """
    data = setup_section_data
    school_id = data["school_a"].id
    ay_id = data["ay_a"].id
    class_id = data["class_a"].id
    headers = data["auth_headers"]

    # 1. Create section
    payload = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "class_id": str(class_id),
        "name": "Section A",
        "code": "SEC_A",
        "capacity": 30,
        "room_number": "R101",
        "sort_order": 1,
        "settings": {"ac": True},
        "ai_metrics": {"attendance_risk": 0.05}
    }
    resp = await client.post("/api/v1/sections", json=payload, headers=headers)
    assert resp.status_code == 201
    section_id = resp.json()["data"]["id"]
    assert resp.json()["data"]["name"] == "Section A"
    assert resp.json()["data"]["sort_order"] == 1
    assert resp.json()["data"]["ai_metrics"]["attendance_risk"] == 0.05

    # 2. Get list of sections
    resp_list = await client.get(f"/api/v1/sections?school_id={school_id}", headers=headers)
    assert resp_list.status_code == 200
    assert len(resp_list.json()["data"]) >= 1

    # 3. Get section details
    resp_get = await client.get(f"/api/v1/sections/{section_id}?school_id={school_id}", headers=headers)
    assert resp_get.status_code == 200
    assert resp_get.json()["data"]["code"] == "SEC_A"

    # 4. Update section parameters
    update_payload = {
        "name": "Section Alpha",
        "capacity": 35,
        "room_number": "R102",
        "sort_order": 5,
        "settings": {"ac": False}
    }
    resp_put = await client.put(f"/api/v1/sections/{section_id}?school_id={school_id}", json=update_payload, headers=headers)
    assert resp_put.status_code == 200
    assert resp_put.json()["data"]["name"] == "Section Alpha"
    assert resp_put.json()["data"]["capacity"] == 35
    assert resp_put.json()["data"]["room_number"] == "R102"
    assert resp_put.json()["data"]["sort_order"] == 5

    # 5. Delete section
    resp_del = await client.delete(f"/api/v1/sections/{section_id}?school_id={school_id}", headers=headers)
    assert resp_del.status_code == 200
    assert resp_del.json()["data"]["deleted_at"] is not None

    # Verify soft-deleted section is excluded from fetch
    resp_del_get = await client.get(f"/api/v1/sections/{section_id}?school_id={school_id}", headers=headers)
    assert resp_del_get.status_code == 404

@pytest.mark.anyio
async def test_section_business_validations(client: AsyncClient, setup_section_data, db_session) -> None:
    """
    Verifies Section business validations:
    - Code uniqueness inside class
    - Name uniqueness inside class
    - Capacity boundaries (capacity > 0)
    - Prohibit creation inside archived Academic Years
    - Validate Class matches year and school scoping
    """
    data = setup_section_data
    school_id = data["school_a"].id
    ay_id = data["ay_a"].id
    class_id = data["class_a"].id
    headers = data["auth_headers"]

    # Pre-create standard Section A
    payload_a = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "class_id": str(class_id),
        "name": "Section A",
        "code": "SEC_A",
        "capacity": 30
    }
    resp = await client.post("/api/v1/sections", json=payload_a, headers=headers)
    assert resp.status_code == 201

    # 1. Duplicate code in the same class -> should raise 409
    payload_dup_code = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "class_id": str(class_id),
        "name": "Section Other",
        "code": "SEC_A",
        "capacity": 30
    }
    resp = await client.post("/api/v1/sections", json=payload_dup_code, headers=headers)
    assert resp.status_code == 409

    # 2. Duplicate name in the same class -> should raise 409
    payload_dup_name = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "class_id": str(class_id),
        "name": "Section A",
        "code": "SEC_OTHER",
        "capacity": 30
    }
    resp = await client.post("/api/v1/sections", json=payload_dup_name, headers=headers)
    assert resp.status_code == 409

    # 3. Capacity validation must be positive
    payload_bad_capacity = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "class_id": str(class_id),
        "name": "Section Bad",
        "code": "SEC_BAD",
        "capacity": 0
    }
    resp = await client.post("/api/v1/sections", json=payload_bad_capacity, headers=headers)
    assert resp.status_code == 422

    # 4. Create section in archived academic year -> should fail with 400
    repo_ay = AcademicYearRepository(db_session)
    ay_archived = await repo_ay.create(
        data["tenant_a"].id,
        school_id,
        AcademicYearCreate(name="2025-2026", code="AY2025-2026", start_date="2025-06-01", end_date="2026-04-30")
    )
    ay_archived.status = AcademicYearStatus.ARCHIVED
    await db_session.commit()

    repo_c = ClassRepository(db_session)
    class_archived = await repo_c.create(
        data["tenant_a"].id,
        ClassCreate(
            school_id=school_id,
            academic_year_id=ay_archived.id,
            name="Class 11",
            code="CLASS_11A",
            level=11,
            category=ClassCategory.HIGH,
            capacity=30
        )
    )
    await db_session.commit()

    payload_archived = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_archived.id),
        "class_id": str(class_archived.id),
        "name": "Section Arch",
        "code": "SEC_ARCH",
        "capacity": 30
    }
    resp = await client.post("/api/v1/sections", json=payload_archived, headers=headers)
    assert resp.status_code == 400

    # 5. Class year scoping mismatch -> should raise 400
    payload_mismatch = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "class_id": str(class_archived.id),  # Class belongs to ay_archived, not ay_id!
        "name": "Section Mis",
        "code": "SEC_MIS",
        "capacity": 30
    }
    resp = await client.post("/api/v1/sections", json=payload_mismatch, headers=headers)
    assert resp.status_code == 400

@pytest.mark.anyio
async def test_section_tenant_and_school_isolation(client: AsyncClient, setup_section_data, db_session) -> None:
    """
    Verifies Section isolation boundaries:
    - Cross-tenant requests should fail or return empty datasets.
    """
    data = setup_section_data
    school_b = data["school_b"].id
    class_b = data["class_b"].id
    ay_b = data["ay_b"].id
    headers_a = data["auth_headers"]

    # Pre-create section under Tenant B
    repo_s = SectionRepository(db_session)
    s_b = await repo_s.create(
        tenant_id=data["tenant_b"].id,
        obj_in=SectionCreate(
            school_id=school_b,
            academic_year_id=ay_b,
            class_id=class_b,
            name="Section B-Tenant",
            code="SEC_BTEN",
            capacity=30
        )
    )
    await db_session.commit()

    # Tenant A attempts to fetch Tenant B's section -> should fail with 404
    resp = await client.get(f"/api/v1/sections/{s_b.id}?school_id={school_b}", headers=headers_a)
    assert resp.status_code in [401, 404]

    # Tenant A attempts to list sections under School B -> returns empty results
    resp_list = await client.get(f"/api/v1/sections?school_id={school_b}", headers=headers_a)
    assert resp_list.status_code == 200
    assert len(resp_list.json()["data"]) == 0

@pytest.mark.anyio
async def test_section_concurrency_control_occ(setup_section_data, db_session) -> None:
    """
    Verifies optimistic concurrency locking on Sections.
    """
    from sqlalchemy.ext.asyncio import async_sessionmaker
    from sqlalchemy.orm.exc import StaleDataError

    data = setup_section_data
    school_id = data["school_a"].id
    ay_id = data["ay_a"].id
    class_id = data["class_a"].id
    tenant_id = data["tenant_a"].id

    # 1. Create section in Session A
    repo_a = SectionRepository(db_session)
    section_obj = await repo_a.create(
        tenant_id=tenant_id,
        obj_in=SectionCreate(
            school_id=school_id,
            academic_year_id=ay_id,
            class_id=class_id,
            name="Section OCC",
            code="SEC_OCC",
            capacity=30
        )
    )
    await repo_a.db.commit()
    await repo_a.db.refresh(section_obj)
    assert section_obj.version == 1

    # 2. Load section in Session B
    async_session_b = async_sessionmaker(
        bind=db_session.bind,
        class_=AsyncSession,
        expire_on_commit=False
    )
    async with async_session_b() as session_b:
        repo_b = SectionRepository(session_b)
        section_obj_b = await repo_b.get_by_id(section_obj.id, school_id, tenant_id)
        assert section_obj_b.version == 1

        # 3. Update and commit in Session A
        section_obj.capacity = 35
        await repo_a.db.commit()
        await repo_a.db.refresh(section_obj)
        assert section_obj.version == 2

        # 4. Attempt update in Session B -> should raise StaleDataError
        section_obj_b.capacity = 40
        with pytest.raises(StaleDataError):
            await repo_b.db.commit()

        await repo_b.db.close()

@pytest.mark.anyio
async def test_class_deletion_prevented_with_sections(client: AsyncClient, setup_section_data, db_session) -> None:
    """
    Verifies that a Class cannot be deleted if sections are actively assigned.
    """
    data = setup_section_data
    school_id = data["school_a"].id
    ay_id = data["ay_a"].id
    class_id = data["class_a"].id
    headers = data["auth_headers"]

    # 1. Create a Section under Class A
    payload_sec = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "class_id": str(class_id),
        "name": "Section Delete Block",
        "code": "SEC_DEL",
        "capacity": 30
    }
    resp_sec = await client.post("/api/v1/sections", json=payload_sec, headers=headers)
    assert resp_sec.status_code == 201

    # 2. Attempt to delete Class A -> should fail with 400 Bad Request
    resp_class_del = await client.delete(f"/api/v1/classes/{class_id}?school_id={school_id}", headers=headers)
    assert resp_class_del.status_code == 400
    assert "sections are currently assigned" in resp_class_del.json()["message"]
