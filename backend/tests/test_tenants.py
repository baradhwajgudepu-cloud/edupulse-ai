import pytest
from httpx import AsyncClient
from app.models.tenant import TenantStatus

@pytest.mark.anyio
async def test_tenant_crud_workflow_with_indian_specs(client: AsyncClient) -> None:
    """
    Validates the full CRUD lifecycle of a Tenant entity using Indian specifications:
    1. Creation of a Tenant with valid Indian inputs (including PIN code, phone, PAN, and GSTIN).
    2. Attempting to create duplicate code/subdomain/email (expects 400).
    3. Reading the Tenant detail by UUID (expects 200).
    4. Listing Tenants with pagination parameters (expects 200).
    5. Modifying fields of a Tenant (expects 200).
    6. Soft-deleting the Tenant (expects 200).
    7. Verifying that the soft-deleted tenant is omitted from typical lists/fetches (expects 404/empty).
    """
    # 1. Create a Tenant with valid Indian localization parameters
    tenant_data = {
        "name": "Sri Chaitanya Educational Institutions Pvt Ltd",
        "display_name": "Sri Chaitanya",
        "code": "sri-chaitanya",
        "subdomain": "srichaitanya",
        "email": "info@srichaitanya.edu.in",
        "phone": "+919876543210",  # Valid 10-digit mobile with +91 prefix
        "website": "https://srichaitanya.edu.in",
        "timezone": "Asia/Kolkata",
        "currency": "INR",
        "address": "Plot No. 12, Tech Park",
        "city": "Hyderabad",
        "state": "Telangana",
        "country": "India",
        "postal_code": "500081",  # Valid 6-digit PIN code
        "pan": "ABCDE1234F",  # Valid 10-character Indian PAN format
        "gstin": "36ABCDE1234F1Z5",  # Valid 15-character Indian GSTIN format
        "is_active": True,
        "status": "ACTIVE",
        "settings": {
            "attendance": True,
            "fees": True,
            "transport": False,
            "library": True
        },
        "plan": "enterprise",
        "subscription_start": "2026-07-29T12:00:00Z",
        "subscription_end": "2027-07-29T12:00:00Z"
    }
    
    response = await client.post("/api/v1/tenants", json=tenant_data)
    assert response.status_code == 201
    
    payload = response.json()
    assert payload["success"] is True
    assert payload["message"] == "Tenant created successfully."
    tenant_response = payload["data"]
    assert tenant_response["name"] == tenant_data["name"]
    assert tenant_response["display_name"] == tenant_data["display_name"]
    assert tenant_response["phone"] == tenant_data["phone"]
    assert tenant_response["postal_code"] == tenant_data["postal_code"]
    assert tenant_response["pan"] == tenant_data["pan"]
    assert tenant_response["gstin"] == tenant_data["gstin"]
    assert tenant_response["timezone"] == "Asia/Kolkata"
    assert tenant_response["currency"] == "INR"
    
    tenant_id = tenant_response["id"]
    assert tenant_id is not None
    
    # 2. Try to create duplicate (same code)
    dup_code_data = tenant_data.copy()
    dup_code_data["subdomain"] = "sri-chaitanya-2"
    dup_code_data["email"] = "info2@srichaitanya.edu.in"
    response = await client.post("/api/v1/tenants", json=dup_code_data)
    assert response.status_code == 409
    assert "code" in response.json()["message"].lower()

    # Try to create duplicate (same subdomain)
    dup_sub_data = tenant_data.copy()
    dup_sub_data["code"] = "sri-chaitanya-2"
    dup_sub_data["email"] = "info2@srichaitanya.edu.in"
    response = await client.post("/api/v1/tenants", json=dup_sub_data)
    assert response.status_code == 409
    assert "subdomain" in response.json()["message"].lower()

    # Try to create duplicate (same email)
    dup_email_data = tenant_data.copy()
    dup_email_data["code"] = "sri-chaitanya-2"
    dup_email_data["subdomain"] = "sri-chaitanya-2"
    response = await client.post("/api/v1/tenants", json=dup_email_data)
    assert response.status_code == 409
    assert "email" in response.json()["message"].lower()
    
    # 3. Read the Tenant by ID
    response = await client.get(f"/api/v1/tenants/{tenant_id}")
    assert response.status_code == 200
    payload = response.json()
    assert payload["success"] is True
    assert payload["data"]["id"] == tenant_id
    assert payload["data"]["display_name"] == "Sri Chaitanya"
    
    # 4. List Tenants (with status filter check, paginated search)
    found = False
    for skip_val in range(0, 1000, 100):
        response = await client.get("/api/v1/tenants", params={"status": "ACTIVE", "skip": skip_val, "limit": 100})
        assert response.status_code == 200
        payload = response.json()
        assert payload["success"] is True
        if not payload["data"]:
            break
        if any(t["id"] == tenant_id for t in payload["data"]):
            found = True
            break
    assert found is True
    
    # 5. Update the Tenant (Change status, is_active flag, and display name)
    update_data = {
        "display_name": "Sri Chaitanya Schools",
        "is_active": False,
        "status": "SUSPENDED"
    }
    response = await client.put(f"/api/v1/tenants/{tenant_id}", json=update_data)
    assert response.status_code == 200
    payload = response.json()
    assert payload["success"] is True
    assert payload["data"]["display_name"] == "Sri Chaitanya Schools"
    assert payload["data"]["is_active"] is False
    assert payload["data"]["status"] == "SUSPENDED"
    
    # 6. Delete the Tenant (Soft Delete)
    response = await client.delete(f"/api/v1/tenants/{tenant_id}")
    assert response.status_code == 200
    payload = response.json()
    assert payload["success"] is True
    assert payload["data"]["deleted_at"] is not None
    
    # 7. Verify soft-deleted Tenant is no longer accessible via list or detail
    response = await client.get(f"/api/v1/tenants/{tenant_id}")
    assert response.status_code == 404
    
    response = await client.get("/api/v1/tenants")
    assert response.status_code == 200
    payload = response.json()
    assert not any(t["id"] == tenant_id for t in payload["data"])

@pytest.mark.anyio
async def test_indian_format_validation_failures(client: AsyncClient) -> None:
    """
    Asserts that invalid formats for Indian-specific fields trigger HTTP 422 errors.
    """
    base_data = {
        "name": "Springfield Academy",
        "code": "springfield",
        "subdomain": "springfield",
        "email": "info@springfield.in"
    }

    # 1. Invalid PIN Code (5 digits instead of 6)
    invalid_pin_data = base_data.copy()
    invalid_pin_data["postal_code"] = "50008"
    response = await client.post("/api/v1/tenants", json=invalid_pin_data)
    assert response.status_code == 422
    assert "postal_code" in response.json()["message"].lower()

    # 2. Invalid Indian Mobile (starts with 1, which is invalid in India)
    invalid_phone_data = base_data.copy()
    invalid_phone_data["phone"] = "+911876543210"
    response = await client.post("/api/v1/tenants", json=invalid_phone_data)
    assert response.status_code == 422
    assert "phone" in response.json()["message"].lower()

    # 3. Invalid Indian PAN (lowercase letters are invalid)
    invalid_pan_data = base_data.copy()
    invalid_pan_data["pan"] = "abcde1234f"
    response = await client.post("/api/v1/tenants", json=invalid_pan_data)
    assert response.status_code == 422
    assert "pan" in response.json()["message"].lower()

    # 4. Invalid Indian GSTIN (missing the last check digit)
    invalid_gstin_data = base_data.copy()
    invalid_gstin_data["gstin"] = "36ABCDE1234F1Z"
    response = await client.post("/api/v1/tenants", json=invalid_gstin_data)
    assert response.status_code == 422
    assert "gstin" in response.json()["message"].lower()

@pytest.mark.anyio
async def test_optimistic_concurrency_control(db_session) -> None:
    """
    Validates optimistic concurrency control (OCC) is enforced:
    1. Register a tenant in the database (default version = 1).
    2. Open a separate database session (Session B) and load the same tenant.
    3. Modify and commit the tenant in Session A (version increments to 2).
    4. Attempt to modify and commit the tenant in Session B (outdated version 1).
    5. Asserts that SQLAlchemy raises StaleDataError during Session B commit.
    """
    from sqlalchemy.orm.exc import StaleDataError
    from app.db.session import AsyncSessionLocal
    from app.repositories.tenant import TenantRepository
    from app.schemas.tenant import TenantCreate
    
    # 1. Create tenant in db (Session A)
    repo_a = TenantRepository(db_session)
    tenant_in = TenantCreate(
        name="Sri Chaitanya Schools",
        display_name="Sri Chaitanya",
        code="sri-chaitanya-occ",
        subdomain="srichaitanyaocc",
        email="info@srichaitanyaocc.edu.in",
        phone="+919876543210",
        website="https://srichaitanya.edu.in",
        timezone="Asia/Kolkata",
        currency="INR"
    )
    tenant = await repo_a.create(tenant_in)
    assert tenant.version == 1
    
    # 2. Load the same tenant in a separate transaction (Session B) using the test engine bind
    from sqlalchemy.ext.asyncio import async_sessionmaker, AsyncSession
    async_session_b = async_sessionmaker(
        bind=db_session.bind,
        class_=AsyncSession,
        expire_on_commit=False
    )
    async with async_session_b() as session_b:
        repo_b = TenantRepository(session_b)
        tenant_b = await repo_b.get_by_id(tenant.id)
        assert tenant_b.version == 1
        
        # 3. Update the tenant in Session A (version increments to 2)
        tenant.name = "Sri Chaitanya Schools Ltd"
        await repo_a.db.commit()
        await repo_a.db.refresh(tenant)
        assert tenant.version == 2
        
        # 4. Modify the tenant in Session B and attempt to commit (outdated version 1)
        tenant_b.name = "Sri Chaitanya Schools Private Ltd"
        
        # Expect StaleDataError to be raised due to optimistic locking mismatch
        with pytest.raises(StaleDataError):
            await repo_b.db.commit()
            
        await repo_b.db.close()
