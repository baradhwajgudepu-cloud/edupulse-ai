import sys, os
sys.path.insert(0, os.path.abspath('.'))
import asyncio
from app.db.session import AsyncSessionLocal
from app.models.user import User
from sqlalchemy import select
from sqlalchemy.orm import selectinload

async def main():
    async with AsyncSessionLocal() as db:
        ures = await db.execute(select(User).options(selectinload(User.roles), selectinload(User.schools)))
        users = ures.scalars().all()
        for u in users:
            role_names = [r.name for r in u.roles]
            if any(r != 'Parent' for r in role_names) or u.is_superuser:
                school_names = [s.name for s in u.schools]
                print(f"{u.email:<35} | Roles: {role_names} | Schools: {school_names} | Super: {u.is_superuser} | Tenant: {u.tenant_id}")

if __name__ == '__main__':
    asyncio.run(main())
