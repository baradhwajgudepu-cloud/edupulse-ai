import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import pytest
import uuid
import httpx
from httpx import AsyncClient
from sqlalchemy import select, text
from app.main import app
from app.db.session import AsyncSessionLocal, engine
from app.models.tenant import Tenant, TenantStatus
from app.models.user import User, UserStatus
from app.models.school import School, SchoolBoard
from app.models.academic_year import AcademicYear, AcademicYearStatus
from datetime import datetime, timedelta, timezone
from app.core.security import create_access_token, hash_password

@pytest.mark.anyio
async def test_tenant_deletion_and_recreation_lifecycle():
    """
    Tests the complete tenant deletion and recreation lifecycle:
    1. Create/Ensure tenant with code 'ts-edu'
    2. Permanently delete tenant
    3. Verify tenant cannot be fetched
    4. Verify all tenant-scoped records are removed
    5. Create a NEW tenant using the SAME code 'ts-edu' (SUCCESS)
    """
    try:
        async with AsyncSessionLocal() as session:
            # Fetch or create platform superadmin
            res_sa = await session.execute(
                select(User).where(User.is_superuser == True).limit(1)
            )
            super_admin = res_sa.scalar_one_or_none()
            if not super_admin:
                super_admin = User(
                    email="superadmin_lifecycle_test@edupulse.local",
                    hashed_password=hash_password("SuperSecure123!"),
                    first_name="Super",
                    last_name="Admin",
                    is_superuser=True,
                    status=UserStatus.ACTIVE
                )
                session.add(super_admin)
                await session.commit()
                await session.refresh(super_admin)

            sa_token = create_access_token(subject=str(super_admin.id), tenant_id=None)
            sa_headers = {"Authorization": f"Bearer {sa_token}"}

            transport = httpx.ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as ac:
                target_code = "ts-edu"

                # Check if ts-edu already exists in DB from past demo/tests
                res_existing = await session.execute(
                    select(Tenant).where(Tenant.code == target_code)
                )
                existing_tenant = res_existing.scalar_one_or_none()

                if existing_tenant:
                    del_resp = await ac.delete(
                        f"/api/v1/tenants/{existing_tenant.id}/permanent",
                        headers=sa_headers
                    )
                    assert del_resp.status_code == 200, f"Failed pre-cleaning ts-edu: {del_resp.text}"

                # =========================================================
                # STEP 1: Create tenant with code 'ts-edu'
                # =========================================================
                create_payload = {
                    "name": "Telangana Educational Society",
                    "code": target_code,
                    "subdomain": "ts-edu-subdomain",
                    "email": "admin@telanganaedu.org",
                    "phone": "+919876543210",
                    "address": "Hyderabad Center",
                    "city": "Hyderabad",
                    "state": "Telangana",
                    "country": "India",
                    "postal_code": "500001",
                    "is_active": True,
                    "status": "ACTIVE"
                }
                resp_create_1 = await ac.post(
                    "/api/v1/tenants",
                    json=create_payload,
                    headers=sa_headers
                )
                assert resp_create_1.status_code == 201, f"Step 1 failed: {resp_create_1.text}"
                tenant_1 = resp_create_1.json()["data"]
                tenant_1_id = tenant_1["id"]
                assert tenant_1["code"] == target_code

                # Attach a school and dependent records to verify cascading permanent deletion
                test_school = School(
                    name="Telangana Model School",
                    code="TMS_001",
                    board=SchoolBoard.STATE,
                    email="tms@telanganaedu.org",
                    tenant_id=uuid.UUID(tenant_1_id),
                    is_active=True
                )
                session.add(test_school)
                await session.commit()
                await session.refresh(test_school)

                test_academic_year = AcademicYear(
                    name="2026-2027",
                    code="AY_2026_27",
                    start_date=datetime.now(timezone.utc).date(),
                    end_date=(datetime.now(timezone.utc) + timedelta(days=365)).date(),
                    school_id=test_school.id,
                    tenant_id=uuid.UUID(tenant_1_id),
                    status=AcademicYearStatus.ACTIVE
                )
                session.add(test_academic_year)
                await session.commit()

                # Attach a tenant-scoped user
                tenant_user = User(
                    email="teacher_lifecycle_test@telanganaedu.org",
                    hashed_password=hash_password("Teacher123!"),
                    first_name="Teacher",
                    last_name="One",
                    is_superuser=False,
                    tenant_id=uuid.UUID(tenant_1_id),
                    status=UserStatus.ACTIVE
                )
                session.add(tenant_user)
                await session.commit()

                # =========================================================
                # STEP 2: Permanently delete tenant via API
                # =========================================================
                resp_del = await ac.delete(
                    f"/api/v1/tenants/{tenant_1_id}/permanent",
                    headers=sa_headers
                )
                assert resp_del.status_code == 200, f"Step 2 failed: {resp_del.text}"
                del_data = resp_del.json()["data"]
                assert del_data["tenant_code"] == target_code
                assert del_data["dry_run"] is False
                assert del_data["total_records_deleted"] > 0

                # =========================================================
                # STEP 3: Verify tenant cannot be fetched via API
                # =========================================================
                resp_get_404 = await ac.get(f"/api/v1/tenants/{tenant_1_id}", headers=sa_headers)
                assert resp_get_404.status_code == 404, "Deleted tenant is still accessible via API!"

                resp_list = await ac.get("/api/v1/tenants", headers=sa_headers)
                assert resp_list.status_code == 200
                list_ids = [t["id"] for t in resp_list.json()["data"]]
                assert tenant_1_id not in list_ids, "Deleted tenant still present in list API!"

                # =========================================================
                # STEP 4: Direct DB verification
                # =========================================================
                res_tenant_db = await session.execute(
                    select(Tenant).where(Tenant.id == uuid.UUID(tenant_1_id))
                )
                assert res_tenant_db.scalar_one_or_none() is None, "Tenant row was not physically deleted!"

                res_school_db = await session.execute(
                    select(School).where(School.tenant_id == uuid.UUID(tenant_1_id))
                )
                assert len(res_school_db.fetchall()) == 0, "School rows were not deleted!"

                # =========================================================
                # STEP 5: Create a NEW tenant using the SAME code 'ts-edu'
                # Expected: SUCCESS (No ghost records blocking recreation)
                # =========================================================
                create_payload_2 = {
                    "name": "Telangana Educational Society New",
                    "code": target_code,
                    "subdomain": "ts-edu-subdomain",
                    "email": "newadmin@telanganaedu.org",
                    "phone": "+919876543210",
                    "address": "Secunderabad Campus",
                    "city": "Hyderabad",
                    "state": "Telangana",
                    "country": "India",
                    "postal_code": "500003",
                    "is_active": True,
                    "status": "ACTIVE"
                }
                resp_create_2 = await ac.post(
                    "/api/v1/tenants",
                    json=create_payload_2,
                    headers=sa_headers
                )
                assert resp_create_2.status_code == 201, f"Step 5 failed to recreate code 'ts-edu': {resp_create_2.text}"
                tenant_2 = resp_create_2.json()["data"]
                assert tenant_2["code"] == target_code
                assert tenant_2["id"] != tenant_1_id

                # Clean up tenant_2 so the test leaves the database completely clean
                resp_clean = await ac.delete(
                    f"/api/v1/tenants/{tenant_2['id']}/permanent",
                    headers=sa_headers
                )
                assert resp_clean.status_code == 200
    finally:
        await engine.dispose()
