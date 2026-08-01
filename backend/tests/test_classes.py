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
from app.models.role import Role
from app.models.permission import Permission
from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
from app.repositories.class_entity import ClassRepository
from app.services.auth import AuthService
from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate
from app.schemas.academic_year import AcademicYearCreate
from app.schemas.auth import UserCreate

@pytest.fixture
async def setup_class_data(db_session):
    """
    Sets up common testing context:
    - Tenant A, School A, Academic Year A (ACTIVE)
    - Tenant B, School B, Academic Year B (ACTIVE)
    - Super Admin user with JWT token credentials
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
    
    # Establish role and permissions configuration
    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    auth_service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, repo_s)
    
    # Super Admin role for Tenant A
    stmt_p = select(Permission)
    res_p = await db_session.execute(stmt_p)
    all_perms = list(res_p.scalars().all())
    
    role_a = Role(
        name="Super Admin",
        code="SUPER_ADMIN",
        is_system=True,
        tenant_id=tenant_a.id
    )
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
        "auth_headers": {"Authorization": f"Bearer {tokens.access_token}", "X-Tenant-ID": str(tenant_a.id)}
    }

@pytest.mark.anyio
async def test_class_crud_flow(client: AsyncClient, setup_class_data) -> None:
    """
    Tests basic Class CRUD operations:
    - Create a Class
    - Fetch details
    - List classes (with search and status filters)
    - Update attributes
    - Soft delete
    """
    data = setup_class_data
    school_id = data["school_a"].id
    ay_id = data["ay_a"].id
    headers = data["auth_headers"]

    # 1. Create Class
    payload = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "name": "Class 10",
        "display_name": "Grade X",
        "code": "CLASS_10A",
        "level": 10,
        "category": "HIGH",
        "capacity": 45,
        "promotion_order": 10,
        "settings": {"expected_strength": 40},
        "ai_metrics": {"forecasted_strength": 42}
    }
    
    resp = await client.post("/api/v1/classes", json=payload, headers=headers)
    assert resp.status_code == 201
    res_json = resp.json()
    assert res_json["success"] is True
    class_id = res_json["data"]["id"]
    
    # 2. Get Class Details
    resp_get = await client.get(f"/api/v1/classes/{class_id}?school_id={school_id}", headers=headers)
    assert resp_get.status_code == 200
    assert resp_get.json()["data"]["name"] == "Class 10"
    assert resp_get.json()["data"]["category"] == "HIGH"
    
    # 3. List Classes
    resp_list = await client.get(f"/api/v1/classes?school_id={school_id}&academic_year_id={ay_id}", headers=headers)
    assert resp_list.status_code == 200
    assert len(resp_list.json()["data"]) == 1
    
    # Test fuzzy search and filters
    resp_search = await client.get(f"/api/v1/classes?school_id={school_id}&search=10A", headers=headers)
    assert len(resp_search.json()["data"]) == 1
    
    resp_search_empty = await client.get(f"/api/v1/classes?school_id={school_id}&search=Missing", headers=headers)
    assert len(resp_search_empty.json()["data"]) == 0

    # 4. Update Class Attributes
    update_payload = {
        "capacity": 50,
        "settings": {"expected_strength": 48, "sections_exist": False}
    }
    resp_put = await client.put(f"/api/v1/classes/{class_id}?school_id={school_id}", json=update_payload, headers=headers)
    assert resp_put.status_code == 200
    assert resp_put.json()["data"]["capacity"] == 50
    assert resp_put.json()["data"]["version"] == 2  # OCC incremented version column

    # 5. Soft Delete
    resp_delete = await client.delete(f"/api/v1/classes/{class_id}?school_id={school_id}", headers=headers)
    assert resp_delete.status_code == 200
    assert resp_delete.json()["data"]["is_active"] is False
    assert resp_delete.json()["data"]["status"] == "INACTIVE"
    
    # Verify it is no longer listed in default list
    resp_list_after = await client.get(f"/api/v1/classes?school_id={school_id}", headers=headers)
    assert len(resp_list_after.json()["data"]) == 0

@pytest.mark.anyio
async def test_class_business_validations(client: AsyncClient, setup_class_data, db_session) -> None:
    """
    Tests service business rules:
    - Block duplicate class codes/names in same academic year.
    - Accept duplicate codes/names in different academic years.
    - Capacity validation.
    - Code regex checks.
    - Cannot create class in archived Academic Year.
    - Block deletion if active sections exist.
    """
    data = setup_class_data
    school_id = data["school_a"].id
    ay_id = data["ay_a"].id
    headers = data["auth_headers"]

    # Pre-create a Class
    payload_1 = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "name": "Class 8",
        "code": "CLASS_8A",
        "level": 8,
        "category": "MIDDLE",
        "capacity": 30
    }
    await client.post("/api/v1/classes", json=payload_1, headers=headers)

    # 1. Duplicate Code Collision (Same AY)
    payload_dup_code = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "name": "Different Name",
        "code": "CLASS_8A",
        "level": 8,
        "category": "MIDDLE",
        "capacity": 30
    }
    resp = await client.post("/api/v1/classes", json=payload_dup_code, headers=headers)
    assert resp.status_code == 409
    assert "code" in resp.json()["message"].lower()

    # 2. Duplicate Name Collision (Same AY)
    payload_dup_name = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "name": "Class 8",
        "code": "CLASS_8B",
        "level": 8,
        "category": "MIDDLE",
        "capacity": 30
    }
    resp = await client.post("/api/v1/classes", json=payload_dup_name, headers=headers)
    assert resp.status_code == 409
    assert "name" in resp.json()["message"].lower()

    # 3. Create class in different Academic Year -> should succeed
    repo_ay = AcademicYearRepository(db_session)
    ay_next = await repo_ay.create(
        data["tenant_a"].id,
        school_id,
        AcademicYearCreate(name="2027-2028", code="AY2027-2028", start_date="2027-06-01", end_date="2028-04-30")
    )
    await db_session.commit()
    
    payload_next_year = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_next.id),
        "name": "Class 8",
        "code": "CLASS_8A",
        "level": 8,
        "category": "MIDDLE",
        "capacity": 30
    }
    resp = await client.post("/api/v1/classes", json=payload_next_year, headers=headers)
    assert resp.status_code == 201

    # 4. Capacity validation must be positive
    payload_bad_capacity = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "name": "Class 9",
        "code": "CLASS_9A",
        "level": 9,
        "category": "MIDDLE",
        "capacity": -10
    }
    resp = await client.post("/api/v1/classes", json=payload_bad_capacity, headers=headers)
    assert resp.status_code == 422

    # 5. Invalid Code Format validation
    payload_bad_code = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "name": "Class 9",
        "code": "class-9a!",  # Must match ^[A-Z0-9_]+$
        "level": 9,
        "category": "MIDDLE",
        "capacity": 30
    }
    resp = await client.post("/api/v1/classes", json=payload_bad_code, headers=headers)
    assert resp.status_code == 422

    # 6. Create class inside archived Academic Year
    ay_archived = await repo_ay.create(
        data["tenant_a"].id,
        school_id,
        AcademicYearCreate(name="2025-2026", code="AY2025-2026", start_date="2025-06-01", end_date="2026-04-30")
    )
    ay_archived.status = AcademicYearStatus.ARCHIVED
    await db_session.commit()
    
    payload_archived = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_archived.id),
        "name": "Class Old",
        "code": "CLASS_OLD",
        "level": 7,
        "category": "MIDDLE",
        "capacity": 30
    }
    resp = await client.post("/api/v1/classes", json=payload_archived, headers=headers)
    assert resp.status_code == 400
    assert "archived" in resp.json()["message"].lower()

    # 7. Block deletion if active sections exist (mocked using settings["sections_exist"] = True)
    payload_sec = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "name": "Class 11",
        "code": "CLASS_11A",
        "level": 11,
        "category": "HIGH",
        "capacity": 30,
        "settings": {"sections_exist": True}
    }
    resp_sec = await client.post("/api/v1/classes", json=payload_sec, headers=headers)
    sec_class_id = resp_sec.json()["data"]["id"]
    
    resp_del_blocked = await client.delete(f"/api/v1/classes/{sec_class_id}?school_id={school_id}", headers=headers)
    assert resp_del_blocked.status_code == 400
    assert "sections" in resp_del_blocked.json()["message"].lower()

@pytest.mark.anyio
async def test_class_archive_and_promote(client: AsyncClient, setup_class_data) -> None:
    """
    Tests transitioning status to ARCHIVED and promoting class sequences.
    """
    data = setup_class_data
    school_id = data["school_a"].id
    ay_id = data["ay_a"].id
    headers = data["auth_headers"]

    # Create Class
    payload = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "name": "Class 12",
        "code": "CLASS_12A",
        "level": 12,
        "category": "HIGHER_SECONDARY",
        "capacity": 50
    }
    resp = await client.post("/api/v1/classes", json=payload, headers=headers)
    class_id = resp.json()["data"]["id"]

    # Archive
    resp_archive = await client.post(f"/api/v1/classes/{class_id}/archive?school_id={school_id}", headers=headers)
    assert resp_archive.status_code == 200
    assert resp_archive.json()["data"]["status"] == "ARCHIVED"
    assert resp_archive.json()["data"]["is_active"] is False

    # Promote
    resp_promote = await client.post(f"/api/v1/classes/{class_id}/promote?school_id={school_id}", headers=headers)
    assert resp_promote.status_code == 200
    assert "last_promotion_execution" in resp_promote.json()["data"]["settings"]

@pytest.mark.anyio
async def test_class_tenant_and_school_isolation(client: AsyncClient, setup_class_data, db_session) -> None:
    """
    Tests scoping isolation:
    - Tenant A's token cannot query/modify Tenant B's class.
    - Tenant A's token cannot list Tenant B's classes.
    """
    data = setup_class_data
    school_a = data["school_a"].id
    school_b = data["school_b"].id
    ay_b = data["ay_b"].id
    headers_a = data["auth_headers"]

    # Pre-create a Class under Tenant B / School B
    repo_c = ClassRepository(db_session)
    c_b = Class(
        name="Class B",
        code="CLASS_B",
        level=10,
        category=ClassCategory.HIGH,
        capacity=40,
        tenant_id=data["tenant_b"].id,
        school_id=school_b,
        academic_year_id=ay_b
    )
    db_session.add(c_b)
    await db_session.commit()

    # Attempt to fetch Tenant B's class using Tenant A's headers -> should fail with 401 or 404
    resp = await client.get(f"/api/v1/classes/{c_b.id}?school_id={school_b}", headers=headers_a)
    assert resp.status_code in [401, 404]

    # Attempt to list classes under School B with Tenant A's headers (filters out B-tenant school data -> returns empty list 200 OK)
    resp_list = await client.get(f"/api/v1/classes?school_id={school_b}", headers=headers_a)
    assert resp_list.status_code == 200
    assert len(resp_list.json()["data"]) == 0

@pytest.mark.anyio
async def test_class_concurrency_control_occ(setup_class_data, db_session) -> None:
    """
    Tests that optimistic concurrency control prevents stale updates.
    """
    from sqlalchemy.ext.asyncio import async_sessionmaker
    from sqlalchemy.orm.exc import StaleDataError
    from app.repositories.class_entity import ClassRepository
    from app.schemas.class_entity import ClassCreate

    data = setup_class_data
    school_id = data["school_a"].id
    ay_id = data["ay_a"].id
    tenant_id = data["tenant_a"].id

    # 1. Create class in Session A
    repo_a = ClassRepository(db_session)
    class_obj = await repo_a.create(
        tenant_id=tenant_id,
        obj_in=ClassCreate(
            school_id=school_id,
            academic_year_id=ay_id,
            name="Class OCC",
            code="CLASS_OCC",
            level=9,
            category=ClassCategory.MIDDLE,
            capacity=30
        )
    )
    await repo_a.db.commit()
    await repo_a.db.refresh(class_obj)
    assert class_obj.version == 1

    # 2. Open Session B using the same connection bind and load the class
    async_session_b = async_sessionmaker(
        bind=db_session.bind,
        class_=AsyncSession,
        expire_on_commit=False
    )
    async with async_session_b() as session_b:
        repo_b = ClassRepository(session_b)
        class_obj_b = await repo_b.get_by_id(class_obj.id, school_id, tenant_id)
        assert class_obj_b.version == 1

        # 3. Modify and commit in Session A
        class_obj.capacity = 35
        await repo_a.db.commit()
        await repo_a.db.refresh(class_obj)
        assert class_obj.version == 2

        # 4. Modify and commit in Session B (raises StaleDataError because B's expected version is 1, but database is 2)
        class_obj_b.capacity = 40
        with pytest.raises(StaleDataError):
            await repo_b.db.commit()
            
        await repo_b.db.close()
