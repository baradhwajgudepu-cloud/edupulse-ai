import asyncio
import uuid

from sqlalchemy import select

from app.core.security import hash_password
from app.db.session import AsyncSessionLocal
from app.models.user import User


ADMIN_EMAIL = "admin@edupulse.com"
NEW_PASSWORD = "LocalUat@123"


async def main():
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(User).where(
                User.email == ADMIN_EMAIL,
                User.deleted_at.is_(None),
            )
        )

        users = list(result.scalars().all())

        if not users:
            print("ERROR: admin@edupulse.com was not found")
            raise SystemExit(1)

        if len(users) > 1:
            print(f"ERROR: found {len(users)} matching users")
            raise SystemExit(1)

        user = users[0]

        user.hashed_password = hash_password(NEW_PASSWORD)
        user.failed_login_attempts = 0
        user.password_reset_hash = None
        user.password_reset_expires_at = None

        if str(user.status) == "LOCKED":
            user.status = "ACTIVE"
            user.locked_until = None

        db.add(user)
        await db.commit()

        print("SUCCESS: admin password updated")
        print(f"user_id={user.id}")
        print(f"tenant_id={user.tenant_id}")


if __name__ == "__main__":
    asyncio.run(main())
