import asyncio
import sys
import os
import uuid
from sqlalchemy import select

# Setup python path to load the application modules correctly
sys.path.append(os.path.abspath(os.path.dirname(__file__) + "/.."))
sys.path.append(os.path.abspath("."))

from app.db.session import AsyncSessionLocal
from app.models.user import User
from app.core.security import hash_password, verify_password

async def main():
    target_tenant_id = uuid.UUID("09f2d4e7-2877-4e42-9e95-e97d52775687")
    target_user_id = uuid.UUID("a1698e3b-dbce-464a-aaf8-d79d16e37ff8")
    target_email = "principal.a2707e@edupulse.local"
    new_password = "LocalUat@123"

    async with AsyncSessionLocal() as session:
        # Fetch the user by all three identifiers to ensure absolute safety
        stmt = (
            select(User)
            .where(
                User.id == target_user_id,
                User.tenant_id == target_tenant_id,
                User.email == target_email
            )
        )
        
        result = await session.execute(stmt)
        user = result.scalar_one_or_none()
        
        if not user:
            print("ERROR: Exact target user not found matching all three identifiers. Aborting.")
            return

        print("RESET_TARGET_VERIFIED: True")
        print(f"USER_ID: {user.id}")
        print(f"TENANT_ID: {user.tenant_id}")
        print(f"EMAIL: {user.email}")

        # Update password hash and must_change_password flag
        hashed = hash_password(new_password)
        user.hashed_password = hashed
        user.must_change_password = False

        session.add(user)
        await session.commit()

        # Reload and verify
        await session.refresh(user)
        matches = verify_password(new_password, user.hashed_password)
        
        print(f"PASSWORD_MATCHES_AFTER_RESET: {matches}")
        print(f"MUST_CHANGE_PASSWORD: {user.must_change_password}")

if __name__ == "__main__":
    asyncio.run(main())
