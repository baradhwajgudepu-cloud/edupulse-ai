import asyncio
import uuid
from sqlalchemy import select
from app.db.session import AsyncSessionLocal
from app.models.user import User
from app.models.role import Role

async def main():
    async with AsyncSessionLocal() as db:
        res = await db.execute(select(User).where(User.email == "low@edu.com"))
        user = res.scalar_one_or_none()
        if user:
            print("User is_superuser:", user.is_superuser)
            res_roles = await db.execute(
                select(Role).join(User.roles).where(User.id == user.id)
            )
            roles = res_roles.scalars().all()
            print("User roles:", [r.code for r in roles])
            for r in roles:
                print(f"Role {r.code} permissions:", [p.code for p in r.permissions])
        else:
            print("User not found in DB")

if __name__ == "__main__":
    asyncio.run(main())
