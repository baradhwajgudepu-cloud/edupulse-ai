"""
Repair Script: Provision missing Principal User for Telangana Model School & Junior College (TS001).
"""

import asyncio
import uuid
import sys
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.db.session import AsyncSessionLocal
from app.models.tenant import Tenant
from app.models.school import School
from app.models.user import User, UserStatus
from app.models.role import Role
from app.services.identity_provisioning import IdentityProvisioningService
from app.core.security import verify_password, create_access_token


async def repair():
    print("=" * 60)
    print("STARTING DATA REPAIR: TS001 PRINCIPAL ACCOUNT PROVISIONING")
    print("=" * 60)

    async with AsyncSessionLocal() as db:
        # 1. Locate Tenant
        tenant_id = uuid.UUID("f004a214-ab3e-443d-a683-588c664a0987")
        stmt_t = select(Tenant).where(Tenant.id == tenant_id, Tenant.deleted_at.is_(None))
        res_t = await db.execute(stmt_t)
        tenant = res_t.scalar_one_or_none()

        if not tenant:
            stmt_t_any = select(Tenant).where(Tenant.code.ilike("%telangana%"), Tenant.deleted_at.is_(None))
            res_t_any = await db.execute(stmt_t_any)
            tenant = res_t_any.scalar_one_or_none()

        if not tenant:
            print("[ERROR] Target tenant not found!")
            sys.exit(1)

        print(f"[1/5] Tenant verified: {tenant.name} (ID: {tenant.id}, Code: {tenant.code})")

        # 2. Locate School TS001
        stmt_s = select(School).where(
            School.tenant_id == tenant.id,
            School.code == "TS001",
            School.deleted_at.is_(None)
        )
        res_s = await db.execute(stmt_s)
        school = res_s.scalar_one_or_none()

        if not school:
            stmt_s_any = select(School).where(
                School.tenant_id == tenant.id,
                School.deleted_at.is_(None)
            )
            res_s_any = await db.execute(stmt_s_any)
            schools = res_s_any.scalars().all()
            for sc in schools:
                if "telangana" in sc.name.lower() or sc.code == "TS001":
                    school = sc
                    break

        if not school:
            print("[ERROR] School TS001 not found under tenant!")
            sys.exit(1)

        print(f"[2/5] School verified: {school.name} (ID: {school.id}, Code: {school.code}, Stored Contact Email: {school.email})")

        # 3. Clean up placeholder dummy principal if present
        stmt_dummy = select(User).where(
            User.tenant_id == tenant.id,
            User.email.ilike("principal.%@edupulse.local"),
            User.deleted_at.is_(None)
        ).options(selectinload(User.roles), selectinload(User.schools))
        res_dummy = await db.execute(stmt_dummy)
        dummy_users = res_dummy.scalars().all()

        for d in dummy_users:
            print(f"[3/5] Cleaning dummy placeholder user: {d.email} ({d.id})")
            d.roles.clear()
            d.schools.clear()
            await db.delete(d)
        await db.commit()

        # 4. Provision Principal using IdentityProvisioningService
        service = IdentityProvisioningService(db)
        target_email = "principal.ts001@telanganaschool.edu"
        target_first_name = "Principal"
        target_last_name = "TS001"
        target_password = "EduPulse@123"

        print(f"[4/5] Provisioning Principal user '{target_email}' for school '{school.name}'...")
        principal_user = await service.provision_principal(
            tenant_id=tenant.id,
            school_id=school.id,
            email=target_email,
            first_name=target_first_name,
            last_name=target_last_name,
            password=target_password,
        )

        print(f"[4/5] Principal user successfully provisioned: ID: {principal_user.id}")
        print(f"      - Email: {principal_user.email}")
        print(f"      - Name: {principal_user.first_name} {principal_user.last_name}")
        print(f"      - Status: {principal_user.status}")
        print(f"      - Roles: {[r.name for r in principal_user.roles]}")
        print(f"      - Schools: {[s.name for s in principal_user.schools]}")

        # 5. Programmatic Authentication & JWT Verification
        print("\n[5/5] Verifying Authentication & Token Resolution...")
        is_pwd_valid = verify_password(target_password, principal_user.hashed_password)
        assert is_pwd_valid, "Password verification failed!"

        roles_list = [r.code.upper() for r in principal_user.roles]
        assert "PRINCIPAL" in roles_list, "User lacks PRINCIPAL role!"

        schools_list = [s.id for s in principal_user.schools]
        assert school.id in schools_list, "User is not linked to school TS001!"

        token = create_access_token(
            subject=str(principal_user.id),
            tenant_id=str(tenant.id)
        )
        assert token and len(token) > 20, "JWT creation failed!"

        print("[OK] Authentication verification passed!")
        print(f"      - Password check: Valid")
        print(f"      - Role resolution: {roles_list}")
        print(f"      - School context: {school.name} ({school.id})")
        print(f"      - Generated Access Token: {token[:25]}... (length={len(token)})")

        print("\n" + "=" * 60)
        print("DATA REPAIR COMPLETE: TS001 PRINCIPAL READY FOR LOGIN")
        print("Email:    principal.ts001@telanganaschool.edu")
        print("Password: EduPulse@123")
        print("Role:     PRINCIPAL")
        print("School:   TS001")
        print("=" * 60)


if __name__ == "__main__":
    asyncio.run(repair())
