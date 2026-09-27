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
from app.models.school import School, SchoolBoard
from app.models.user import User, UserStatus
from app.models.role import Role
from app.core.security import create_access_token, hash_password
from app.services.tenant_deletion import TenantDeletionService

@pytest.mark.anyio
async def test_tenant_permanent_deletion_full_suite():
    try:
        async with AsyncSessionLocal() as session:
            # 1. Fetch or create a platform super-admin user
            res_sa = await session.execute(
                select(User).where(User.is_superuser == True).limit(1)
            )
            super_admin = res_sa.scalar_one_or_none()
            if not super_admin:
                super_admin = User(
                    email="superadmin_test@edupulse.local",
                    hashed_password=hash_password("SuperSecure123!"),
                    first_name="Super",
                    last_name="Admin",
                    is_superuser=True,
                    status=UserStatus.ACTIVE
                )
                session.add(super_admin)
                await session.commit()
                await session.refresh(super_admin)

            super_admin_id = super_admin.id
            sa_token = create_access_token(subject=str(super_admin_id), tenant_id=None)
            sa_headers = {"Authorization": f"Bearer {sa_token}"}

            # 2. Fetch or create system tenant
            res_sys = await session.execute(
                select(Tenant).where(Tenant.code == "EDUPULSE_SYSTEM").limit(1)
            )
            sys_tenant = res_sys.scalar_one_or_none()
            if not sys_tenant:
                sys_tenant = Tenant(
                    name="EduPulse System Master",
                    code="EDUPULSE_SYSTEM",
                    subdomain="system",
                    email="system@edupulse.local",
                    is_active=True,
                    status=TenantStatus.ACTIVE
                )
                session.add(sys_tenant)
                await session.commit()
                await session.refresh(sys_tenant)

            transport = httpx.ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as ac:

                # =========================================================
                # TEST 1: Unauthenticated request rejected (401)
                # =========================================================
                dummy_id = uuid.uuid4()
                resp_unauth = await ac.delete(f"/api/v1/tenants/{dummy_id}/permanent")
                assert resp_unauth.status_code == 401, f"Expected 401, got {resp_unauth.status_code}"

                # =========================================================
                # TEST 2: Protected System Tenant cannot be deleted (400)
                # =========================================================
                resp_sys = await ac.delete(
                    f"/api/v1/tenants/{sys_tenant.id}/permanent",
                    headers=sa_headers
                )
                assert resp_sys.status_code == 400, f"Expected 400 for EDUPULSE_SYSTEM, got {resp_sys.status_code}"
                err_msg = resp_sys.json().get("message") or resp_sys.json().get("detail", "")
                assert "protected" in err_msg.lower() or "edupulse_system" in err_msg.lower()

                # =========================================================
                # Setup a dedicated test tenant with nested entities
                # =========================================================
                test_tenant_code = f"del-test-{uuid.uuid4().hex[:8]}"
                test_tenant = Tenant(
                    name="Permanent Deletion Test Organization",
                    code=test_tenant_code,
                    subdomain=test_tenant_code,
                    email=f"{test_tenant_code}@edupulse.test",
                    status=TenantStatus.ACTIVE,
                    is_active=True
                )
                session.add(test_tenant)
                await session.commit()
                await session.refresh(test_tenant)

                test_school = School(
                    name="Deletion Test Campus",
                    code=f"SCH_{uuid.uuid4().hex[:6]}",
                    board=SchoolBoard.CBSE,
                    email=f"school_{test_tenant_code}@edupulse.test",
                    tenant_id=test_tenant.id,
                    is_active=True
                )
                session.add(test_school)

                regular_user = User(
                    email=f"admin@{test_tenant_code}.test",
                    hashed_password=hash_password("Pass123!"),
                    first_name="Tenant",
                    last_name="Admin",
                    tenant_id=test_tenant.id,
                    is_superuser=False,
                    status=UserStatus.ACTIVE
                )
                session.add(regular_user)
                await session.commit()
                await session.refresh(regular_user)

                # =========================================================
                # TEST 3: Regular Tenant Admin receives Forbidden (403)
                # =========================================================
                tenant_admin_token = create_access_token(
                    subject=str(regular_user.id),
                    tenant_id=str(test_tenant.id)
                )
                ta_headers = {
                    "Authorization": f"Bearer {tenant_admin_token}",
                    "X-Tenant-ID": str(test_tenant.id)
                }
                resp_forbidden = await ac.delete(
                    f"/api/v1/tenants/{test_tenant.id}/permanent",
                    headers=ta_headers
                )
                assert resp_forbidden.status_code == 403, f"Expected 403, got {resp_forbidden.status_code}"

                # =========================================================
                # TEST 4: Dry-Run Mode returns counts and deletes NOTHING
                # =========================================================
                resp_dry = await ac.delete(
                    f"/api/v1/tenants/{test_tenant.id}/permanent?dry_run=true",
                    headers=sa_headers
                )
                assert resp_dry.status_code == 200, f"Expected 200, got {resp_dry.status_code}"
                dry_payload = resp_dry.json()
                assert dry_payload["success"] is True
                dry_data = dry_payload["data"]
                assert dry_data["dry_run"] is True
                assert dry_data["tenant_code"] == test_tenant_code
                assert dry_data["total_records_deleted"] > 0
                assert "schools" in dry_data["deleted_counts"]
                assert "users" in dry_data["deleted_counts"]

                # Verify records STILL exist in DB after dry run
                res_verify_tenant = await session.execute(
                    select(Tenant).where(Tenant.id == test_tenant.id)
                )
                assert res_verify_tenant.scalar_one_or_none() is not None, "Tenant was deleted during dry-run!"

                res_verify_school = await session.execute(
                    select(School).where(School.tenant_id == test_tenant.id)
                )
                assert res_verify_school.scalar_one_or_none() is not None, "School was deleted during dry-run!"

                # =========================================================
                # TEST 5: Real Permanent Deletion succeeds and cleans all records
                # =========================================================
                resp_real = await ac.delete(
                    f"/api/v1/tenants/{test_tenant.id}/permanent",
                    headers=sa_headers
                )
                assert resp_real.status_code == 200, f"Expected 200, got {resp_real.status_code}"
                real_payload = resp_real.json()
                assert real_payload["success"] is True
                real_data = real_payload["data"]
                assert real_data["dry_run"] is False
                assert real_data["total_records_deleted"] > 0

                # Verify records are permanently wiped from the database
                res_after_tenant = await session.execute(
                    select(Tenant).where(Tenant.id == test_tenant.id)
                )
                assert res_after_tenant.scalar_one_or_none() is None, "Tenant was not deleted!"

                res_after_school = await session.execute(
                    select(School).where(School.tenant_id == test_tenant.id)
                )
                assert res_after_school.scalar_one_or_none() is None, "School was not deleted!"

                res_after_user = await session.execute(
                    select(User).where(User.id == regular_user.id)
                )
                assert res_after_user.scalar_one_or_none() is None, "Tenant user was not deleted!"

                # Super admin MUST still exist!
                res_after_sa = await session.execute(
                    select(User).where(User.id == super_admin_id)
                )
                assert res_after_sa.scalar_one_or_none() is not None, "Super admin was deleted!"

                # =========================================================
                # TEST 6: Atomic Rollback on Controlled Failure
                # =========================================================
                rb_tenant_code = f"rb-test-{uuid.uuid4().hex[:8]}"
                rb_tenant = Tenant(
                    name="Rollback Test Organization",
                    code=rb_tenant_code,
                    subdomain=rb_tenant_code,
                    email=f"{rb_tenant_code}@edupulse.test",
                    status=TenantStatus.ACTIVE,
                    is_active=True
                )
                session.add(rb_tenant)
                await session.commit()
                await session.refresh(rb_tenant)
                rb_tenant_id = rb_tenant.id

                # Perform rollback test with corrupted execution
                service = TenantDeletionService(db=session)
                original_exec = session.execute
                try:
                    with pytest.raises(Exception):
                        async def corrupted_exec(*args, **kwargs):
                            raise RuntimeError("Simulated Database Failure")
                        
                        session.execute = corrupted_exec
                        await service.delete_tenant_permanent(
                            tenant_id=rb_tenant_id,
                            current_user=super_admin,
                            dry_run=False
                        )
                finally:
                    session.execute = original_exec

                # Verify that rb_tenant STILL exists because transaction rolled back
                res_rb_tenant = await session.execute(
                    select(Tenant).where(Tenant.id == rb_tenant_id)
                )
                assert res_rb_tenant.scalar_one_or_none() is not None, "Rollback failed, tenant was deleted!"

                # Clean up rollback tenant cleanly
                res_refreshed_sa = await session.execute(
                    select(User).where(User.id == super_admin_id)
                )
                fresh_sa = res_refreshed_sa.scalar_one()

                await service.delete_tenant_permanent(
                    tenant_id=rb_tenant_id,
                    current_user=fresh_sa,
                    dry_run=False
                )
    finally:
        await engine.dispose()
