import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy import select
from fastapi import HTTPException

from app.models.tenant import Tenant
from app.models.school import School
from app.models.user import User, UserStatus
from app.models.role import Role
from app.services.identity_provisioning import IdentityProvisioningService
from app.core.security import verify_password, create_access_token


@pytest.fixture
async def setup_principal_test_data(db_session):
    u = uuid.uuid4().hex[:6]
    tenant = Tenant(name=f"Principal Test Tenant {u}", code=f"PTT_{u}", subdomain=f"ptt{u}", email=f"ptt{u}@edupulse.local")
    db_session.add(tenant)
    await db_session.flush()

    school = School(name=f"Principal Test School {u}", code=f"PTS_{u}", board="CBSE", email=f"contact_{u}@edupulse.local", tenant_id=tenant.id)
    db_session.add(school)
    await db_session.flush()

    # Create admin user for token authentication
    admin = User(
        email=f"admin_{u}@edupulse.local",
        first_name="Admin",
        last_name="User",
        status=UserStatus.ACTIVE,
        is_superuser=True,
        tenant_id=tenant.id,
        hashed_password="dummy_hashed_password"
    )
    db_session.add(admin)
    await db_session.flush()
    await db_session.commit()

    token = create_access_token(subject=str(admin.id), tenant_id=str(tenant.id))
    headers = {
        "Authorization": f"Bearer {token}",
        "X-Tenant-ID": str(tenant.id)
    }

    return {
        "tenant": tenant,
        "school": school,
        "admin": admin,
        "headers": headers,
        "u": u
    }


@pytest.mark.anyio
async def test_provision_principal_service(db_session, setup_principal_test_data):
    data = setup_principal_test_data
    tenant = data["tenant"]
    school = data["school"]
    u = data["u"]

    service = IdentityProvisioningService(db_session)
    p_email = f"principal.{u}@myschool.edu"
    p_pass = "SecurePass@123"

    user = await service.provision_principal(
        tenant_id=tenant.id,
        school_id=school.id,
        email=p_email,
        first_name="Dr. Jane",
        last_name="Doe",
        password=p_pass
    )

    assert user is not None
    assert user.email == p_email.lower()
    assert user.first_name == "Dr. Jane"
    assert user.last_name == "Doe"
    assert user.status == UserStatus.ACTIVE
    assert verify_password(p_pass, user.hashed_password)

    role_codes = [r.code for r in user.roles]
    assert "PRINCIPAL" in role_codes

    school_ids = [s.id for s in user.schools]
    assert school.id in school_ids


@pytest.mark.anyio
async def test_provision_principal_idempotency(db_session, setup_principal_test_data):
    data = setup_principal_test_data
    tenant = data["tenant"]
    school = data["school"]
    u = data["u"]

    service = IdentityProvisioningService(db_session)
    p_email = f"principal.idem.{u}@myschool.edu"

    # 1. Provision first time
    user1 = await service.provision_principal(
        tenant_id=tenant.id,
        school_id=school.id,
        email=p_email,
        first_name="Jane",
        last_name="Smith",
        password="EduPulse@123"
    )

    # 2. Provision second time (retry)
    user2 = await service.provision_principal(
        tenant_id=tenant.id,
        school_id=school.id,
        email=p_email,
        first_name="Jane",
        last_name="Smith",
        password="EduPulse@123"
    )

    assert user1.id == user2.id

    # Verify no duplicate user records exist
    users_stmt = select(User).where(User.tenant_id == tenant.id, User.email == p_email.lower())
    users = (await db_session.execute(users_stmt)).scalars().all()
    assert len(users) == 1


@pytest.mark.anyio
async def test_provision_principal_cross_tenant_conflict(db_session, setup_principal_test_data):
    data = setup_principal_test_data
    tenant1 = data["tenant"]
    school1 = data["school"]
    u = data["u"]

    # Create Tenant 2 and School 2
    tenant2 = Tenant(name=f"Tenant2 {u}", code=f"T2_{u}", subdomain=f"t2{u}", email=f"t2{u}@edupulse.local")
    db_session.add(tenant2)
    await db_session.flush()

    school2 = School(name=f"School2 {u}", code=f"S2_{u}", board="CBSE", email=f"s2{u}@edupulse.local", tenant_id=tenant2.id)
    db_session.add(school2)
    await db_session.flush()
    await db_session.commit()

    service = IdentityProvisioningService(db_session)
    shared_email = f"shared.principal.{u}@myschool.edu"

    # Provision in Tenant 1
    await service.provision_principal(
        tenant_id=tenant1.id,
        school_id=school1.id,
        email=shared_email,
        first_name="Tenant1",
        last_name="Principal"
    )

    # Attempt provisioning same email in Tenant 2 -> Conflict 409
    with pytest.raises(HTTPException) as exc_info:
        await service.provision_principal(
            tenant_id=tenant2.id,
            school_id=school2.id,
            email=shared_email,
            first_name="Tenant2",
            last_name="Principal"
        )
    assert exc_info.value.status_code == 409


@pytest.mark.anyio
async def test_provision_principal_api_endpoint(client: AsyncClient, setup_principal_test_data):
    data = setup_principal_test_data
    tenant = data["tenant"]
    school = data["school"]
    headers = data["headers"]
    u = data["u"]

    p_email = f"principal.api.{u}@myschool.edu"
    payload = {
        "email": p_email,
        "first_name": "API",
        "last_name": "Principal",
        "phone": "+919876543210",
        "password": "EduPulse@123",
        "school_id": str(school.id)
    }

    resp = await client.post("/api/v1/identity/provision/principal", json=payload, headers=headers)
    assert resp.status_code == 201, f"Error: {resp.text}"
    res_json = resp.json()
    assert res_json["success"] is True
    assert res_json["data"]["email"] == p_email.lower()
    assert res_json["data"]["first_name"] == "API"
    assert res_json["data"]["last_name"] == "Principal"
    assert any(r["code"] == "PRINCIPAL" for r in res_json["data"]["roles"])
    assert any(str(s["id"]) == str(school.id) for s in res_json["data"]["schools"])
