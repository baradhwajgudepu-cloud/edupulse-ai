import pytest
import uuid
from httpx import AsyncClient
from sqlalchemy.orm.exc import StaleDataError
from app.models.school import SchoolBoard, SchoolType, SchoolStatus

@pytest.mark.anyio
async def test_school_crud_workflow(client: AsyncClient) -> None:
    """
    Tests the CRUD operations of the School entity:
    1. Create a Tenant to scope the schools.
    2. Register a School under the tenant with valid parameters.
    3. Retrieve the School by ID.
    4. List schools with filter parameters.
    5. Update school parameters.
    6. Soft-delete the school.
    """
    # 1. Create a Tenant
    tenant_data = {
        "name": "Sri Chaitanya Schools Trust",
        "display_name": "Sri Chaitanya",
        "code": "sri-chaitanya-school-test",
        "subdomain": "srichaitanyatest",
        "email": "trust@srichaitanya.edu.in",
        "phone": "+919876543210",
        "website": "https://srichaitanya.edu.in",
        "timezone": "Asia/Kolkata",
        "currency": "INR",
        "address": "Madhapur",
        "city": "Hyderabad",
        "state": "Telangana",
        "postal_code": "500081"
    }
    t_resp = await client.post("/api/v1/tenants", json=tenant_data)
    assert t_resp.status_code == 201
    tenant_id = t_resp.json()["data"]["id"]
    
    # Header containing the active tenant scope
    headers = {"X-Tenant-ID": tenant_id}
    
    # 2. Register a School
    school_data = {
        "name": "Sri Chaitanya High School - Madhapur",
        "display_name": "Sri Chaitanya Madhapur",
        "code": "HYD_MADHAPUR",  # Valid uppercase, matches regex ^[A-Z0-9_-]{2,20}$
        "board": "CBSE",
        "school_type": "HIGH_SCHOOL",
        "email": "madhapur@srichaitanya.edu.in",
        "phone": "+919876543211",
        "website": "https://srichaitanya.edu.in/madhapur",
        "principal_name": "Dr. K. R. Rao",
        "address": "Plot 45, Hitec City Road",
        "city": "Hyderabad",
        "state": "Telangana",
        "country": "India",
        "postal_code": "500081",
        "logo_url": "schools/logos/hyd_madhapur.png",
        "is_active": True,
        "status": "ACTIVE",
        "settings": {
            "attendance": True,
            "library": True,
            "transport": False,
            "hostel": False,
            "biometric": True
        },
        "udise_code": "36210512345"  # Valid 11-digit numeric
    }
    
    s_resp = await client.post("/api/v1/schools", json=school_data, headers=headers)
    assert s_resp.status_code == 201
    school_response = s_resp.json()["data"]
    assert school_response["name"] == school_data["name"]
    assert school_response["code"] == "HYD_MADHAPUR"
    assert school_response["board"] == "CBSE"
    assert school_response["school_type"] == "HIGH_SCHOOL"
    assert school_response["email"] == school_data["email"]
    assert school_response["settings"]["attendance"] is True
    assert school_response["settings"]["transport"] is False
    assert school_response["version"] == 1
    
    school_id = school_response["id"]
    
    # 3. Retrieve school by ID
    get_resp = await client.get(f"/api/v1/schools/{school_id}", headers=headers)
    assert get_resp.status_code == 200
    assert get_resp.json()["data"]["name"] == school_data["name"]
    
    # 4. List schools with filter parameters
    list_resp = await client.get(
        "/api/v1/schools",
        params={"board": "CBSE", "status": "ACTIVE", "is_active": True},
        headers=headers
    )
    assert list_resp.status_code == 200
    assert len(list_resp.json()["data"]) >= 1
    assert any(s["id"] == school_id for s in list_resp.json()["data"])
    
    # 5. Update school details
    update_data = {
        "display_name": "Sri Chaitanya Madhapur Campus",
        "status": "INACTIVE",
        "is_active": False
    }
    up_resp = await client.put(f"/api/v1/schools/{school_id}", json=update_data, headers=headers)
    assert up_resp.status_code == 200
    assert up_resp.json()["data"]["display_name"] == "Sri Chaitanya Madhapur Campus"
    assert up_resp.json()["data"]["status"] == "INACTIVE"
    assert up_resp.json()["data"]["is_active"] is False
    
    # 6. Soft-delete school
    del_resp = await client.delete(f"/api/v1/schools/{school_id}", headers=headers)
    assert del_resp.status_code == 200
    assert del_resp.json()["data"]["deleted_at"] is not None
    
    # Verify soft-deleted school is omitted
    get_del = await client.get(f"/api/v1/schools/{school_id}", headers=headers)
    assert get_del.status_code == 404

@pytest.mark.anyio
async def test_school_composite_and_global_uniqueness(client: AsyncClient) -> None:
    """
    Verifies that unique constraints are scoped correctly:
    1. Creating a duplicate code under the SAME tenant returns 409 Conflict.
    2. Creating a duplicate email under the SAME tenant returns 409 Conflict.
    3. Creating a duplicate UDISE code globally returns 409 Conflict.
    4. Creating a duplicate code under a DIFFERENT tenant successfully creates (composite validation check).
    """
    # Create Tenant A
    t_a_data = {
        "name": "Trust A", "code": "trust-a", "subdomain": "trust-a",
        "email": "trust-a@edu.in", "timezone": "Asia/Kolkata", "currency": "INR"
    }
    resp_t_a = await client.post("/api/v1/tenants", json=t_a_data)
    t_a_id = resp_t_a.json()["data"]["id"]
    headers_a = {"X-Tenant-ID": t_a_id}

    # Create Tenant B
    t_b_data = {
        "name": "Trust B", "code": "trust-b", "subdomain": "trust-b",
        "email": "trust-b@edu.in", "timezone": "Asia/Kolkata", "currency": "INR"
    }
    resp_t_b = await client.post("/api/v1/tenants", json=t_b_data)
    t_b_id = resp_t_b.json()["data"]["id"]
    headers_b = {"X-Tenant-ID": t_b_id}

    # Register School 1 in Tenant A
    school_1_data = {
        "name": "School One",
        "code": "SCH001",
        "board": "CBSE",
        "school_type": "PRIMARY",
        "email": "one@trust-a.in",
        "udise_code": "36210599999"
    }
    resp_s1 = await client.post("/api/v1/schools", json=school_1_data, headers=headers_a)
    assert resp_s1.status_code == 201

    # 1. Create duplicate code in Tenant A -> Expects 409 Conflict
    dup_code_data = school_1_data.copy()
    dup_code_data["email"] = "other@trust-a.in"
    dup_code_data["udise_code"] = "36210588888"
    resp_dup_code = await client.post("/api/v1/schools", json=dup_code_data, headers=headers_a)
    assert resp_dup_code.status_code == 409
    assert "code" in resp_dup_code.json()["message"].lower()

    # 2. Create duplicate email in Tenant A -> Expects 409 Conflict
    dup_email_data = school_1_data.copy()
    dup_email_data["code"] = "SCH002"
    dup_email_data["udise_code"] = "36210588888"
    resp_dup_email = await client.post("/api/v1/schools", json=dup_email_data, headers=headers_a)
    assert resp_dup_email.status_code == 409
    assert "email" in resp_dup_email.json()["message"].lower()

    # 3. Create duplicate UDISE code globally (even in Tenant B) -> Expects 409 Conflict
    dup_udise_data = school_1_data.copy()
    dup_udise_data["code"] = "SCH002"
    dup_udise_data["email"] = "two@trust-b.in"
    resp_dup_udise = await client.post("/api/v1/schools", json=dup_udise_data, headers=headers_b)
    assert resp_dup_udise.status_code == 409
    assert "udise" in resp_dup_udise.json()["message"].lower()

    # 4. Create duplicate code in DIFFERENT Tenant B -> Expects 201 Created (verifies composite key)
    valid_diff_tenant = school_1_data.copy()
    valid_diff_tenant["email"] = "two@trust-b.in"
    valid_diff_tenant["udise_code"] = "36210577777"
    resp_diff = await client.post("/api/v1/schools", json=valid_diff_tenant, headers=headers_b)
    assert resp_diff.status_code == 201

@pytest.mark.anyio
async def test_school_format_validation_failures(client: AsyncClient) -> None:
    """
    Verifies regex check violations result in 422 errors:
    - Code must match ^[A-Z0-9_-]{2,20}$ (fails on lowercase, too short/long).
    - Phone number check.
    - PIN Code check.
    - UDISE check.
    """
    headers = {"X-Tenant-ID": str(uuid.uuid4())}
    base_data = {
        "name": "Springfield",
        "code": "SCH001",
        "board": "CBSE",
        "email": "springfield@edu.in"
    }

    # 1. Invalid lowercase code
    invalid_code = base_data.copy()
    invalid_code["code"] = "sch001"  # lowercase
    r = await client.post("/api/v1/schools", json=invalid_code, headers=headers)
    assert r.status_code == 422
    assert "code" in r.json()["message"].lower()

    # 2. Invalid phone number prefix
    invalid_phone = base_data.copy()
    invalid_phone["phone"] = "+12345678901"  # invalid prefix
    r = await client.post("/api/v1/schools", json=invalid_phone, headers=headers)
    assert r.status_code == 422
    assert "phone" in r.json()["message"].lower()

    # 3. Invalid PIN code length
    invalid_pin = base_data.copy()
    invalid_pin["postal_code"] = "50008"  # 5 digits
    r = await client.post("/api/v1/schools", json=invalid_pin, headers=headers)
    assert r.status_code == 422
    assert "postal_code" in r.json()["message"].lower()

    # 4. Invalid UDISE code length
    invalid_udise = base_data.copy()
    invalid_udise["udise_code"] = "12345"  # 5 digits instead of 11
    r = await client.post("/api/v1/schools", json=invalid_udise, headers=headers)
    assert r.status_code == 422
    assert "udise" in r.json()["message"].lower()

@pytest.mark.anyio
async def test_school_optimistic_concurrency_control(db_session) -> None:
    """
    Asserts that concurrent update collisions are blocked:
    1. Create school in Session A.
    2. Open Session B, load the same school.
    3. Modify and commit in Session A (version increments to 2).
    4. Attempt to modify and commit in Session B (outdated version 1).
    5. Verifies StaleDataError is raised.
    """
    from app.db.session import AsyncSessionLocal
    from app.repositories.school import SchoolRepository
    from app.schemas.school import SchoolCreate
    from sqlalchemy.ext.asyncio import async_sessionmaker, AsyncSession
    
    # Pre-requisite: Create a Tenant
    from app.repositories.tenant import TenantRepository
    from app.schemas.tenant import TenantCreate
    repo_t = TenantRepository(db_session)
    tenant = await repo_t.create(
        TenantCreate(
            name="SOCIETY", code="society", subdomain="society", email="society@edu.in"
        )
    )
    
    # 1. Create school in Session A
    repo_a = SchoolRepository(db_session)
    school = await repo_a.create(
        tenant_id=tenant.id,
        obj_in=SchoolCreate(
            name="Hills High School",
            code="HILLS_HIGH",
            board="STATE",
            email="hills@society.edu.in",
            udise_code="36210512000"
        )
    )
    assert school.version == 1

    # 2. Open Session B using the same test engine connection and load the school
    async_session_b = async_sessionmaker(
        bind=db_session.bind,
        class_=AsyncSession,
        expire_on_commit=False
    )
    async with async_session_b() as session_b:
        repo_b = SchoolRepository(session_b)
        school_b = await repo_b.get_by_id(school.id, tenant.id)
        assert school_b.version == 1

        # 3. Modify and commit in Session A
        school.name = "Hills High School A"
        await repo_a.db.commit()
        await repo_a.db.refresh(school)
        assert school.version == 2

        # 4. Modify and commit in Session B (raises StaleDataError)
        school_b.name = "Hills High School B"
        with pytest.raises(StaleDataError):
            await repo_b.db.commit()
            
        await repo_b.db.close()
