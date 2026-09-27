import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import asyncio
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy import select, text
from sqlalchemy.orm import selectinload
from app.core.settings import settings
from app.core.security import hash_password
from app.models.tenant import Tenant
from app.models.user import User, UserStatus
from app.models.role import Role
from app.models.permission import Permission

async def create_superadmin():
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    target_email = "edupulsetechnolgies@gmail.com".strip().lower()
    target_password = "Gudepu@84"

    async with async_session() as session:
        # 1. Fetch system master tenant
        res_t = await session.execute(
            select(Tenant).where(Tenant.code == "EDUPULSE_SYSTEM")
        )
        system_tenant = res_t.scalar_one_or_none()
        if not system_tenant:
            # Fallback to id or create
            res_t2 = await session.execute(
                select(Tenant).where(Tenant.id == "ff9e842b-3008-451b-a42b-e177c996d3e9")
            )
            system_tenant = res_t2.scalar_one_or_none()

        print(f"System Master Tenant: {system_tenant.id} | {system_tenant.name} | code={system_tenant.code}")

        # 2. Fetch or create SUPER_ADMIN role
        res_r = await session.execute(
            select(Role).where(
                Role.code == "SUPER_ADMIN",
                Role.tenant_id == system_tenant.id
            ).options(selectinload(Role.permissions))
        )
        super_admin_role = res_r.scalar_one_or_none()

        if not super_admin_role:
            res_perms = await session.execute(select(Permission))
            all_perms = list(res_perms.scalars().all())

            super_admin_role = Role(
                name="Super Administrator",
                code="SUPER_ADMIN",
                description="Global Platform Administrator with unrestricted administrative privileges.",
                is_system=True,
                tenant_id=system_tenant.id,
                permissions=all_perms
            )
            session.add(super_admin_role)
            await session.commit()
            await session.refresh(super_admin_role)
            print("Created SUPER_ADMIN role.")
        else:
            print("Found existing SUPER_ADMIN role.")

        # 3. Check if target user already exists
        res_u = await session.execute(
            select(User).where(User.email == target_email).options(selectinload(User.roles))
        )
        existing_user = res_u.scalar_one_or_none()

        hashed_pwd = hash_password(target_password)

        if existing_user:
            existing_user.hashed_password = hashed_pwd
            existing_user.is_superuser = True
            existing_user.status = UserStatus.ACTIVE
            existing_user.tenant_id = system_tenant.id
            existing_user.failed_login_attempts = 0
            existing_user.locked_until = None
            if super_admin_role not in existing_user.roles:
                existing_user.roles.append(super_admin_role)
            await session.commit()
            await session.refresh(existing_user)
            print(f"[OK] Updated existing user {target_email} as Super Admin.")
            user_id = existing_user.id
        else:
            new_user = User(
                email=target_email,
                hashed_password=hashed_pwd,
                first_name="EduPulse",
                last_name="SuperAdmin",
                is_superuser=True,
                status=UserStatus.ACTIVE,
                tenant_id=system_tenant.id,
                roles=[super_admin_role]
            )
            session.add(new_user)
            await session.commit()
            await session.refresh(new_user)
            print(f"[OK] Created new Super Admin user {target_email}.")
            user_id = new_user.id

        print(f"\n==========================================")
        print(f"Super Admin Account Details:")
        print(f"  User ID:    {user_id}")
        print(f"  Email:      {target_email}")
        print(f"  Password:   {target_password}")
        print(f"  Superuser:  True")
        print(f"  Role:       SUPER_ADMIN")
        print(f"  Tenant ID:  {system_tenant.id} ({system_tenant.name})")
        print(f"  Status:     ACTIVE")
        print(f"==========================================")

    await engine.dispose()

if __name__ == "__main__":
    asyncio.run(create_superadmin())
