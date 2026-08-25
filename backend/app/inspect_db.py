import asyncio
import sys
import os
from sqlalchemy import select
from sqlalchemy.orm import selectinload

# Setup python path to load the application modules correctly
sys.path.append(os.path.abspath(os.path.dirname(__file__) + "/.."))
sys.path.append(os.path.abspath("."))

from app.db.session import AsyncSessionLocal
from app.models.user import User
from app.core.security import verify_password

async def main():
    print("INSPECT_DB_START")
    
    email = "principal.a2707e@edupulse.local"
    password_to_check = "LocalUat@123"

    async with AsyncSessionLocal() as session:
        # Query User globally by email without tenant filtering
        stmt = (
            select(User)
            .where(User.email == email)
            .options(selectinload(User.roles), selectinload(User.schools))
        )
        
        result = await session.execute(stmt)
        users = result.scalars().all()
        
        print(f"USER_ROWS_FOUND: {len(users)}")
        
        for idx, user in enumerate(users):
            print(f"\n--- Row {idx + 1} ---")
            print(f"USER_ID: {user.id}")
            print(f"TENANT_ID: {user.tenant_id}")
            print(f"STATUS: {user.status}")
            print(f"DELETED_AT: {user.deleted_at}")
            print(f"LOCKED_UNTIL: {user.locked_until}")
            print(f"FAILED_LOGIN_ATTEMPTS: {user.failed_login_attempts}")
            print(f"MUST_CHANGE_PASSWORD: {user.must_change_password}")
            
            roles = [f"{r.name} ({r.code})" for r in user.roles]
            print(f"ROLES: {roles}")
            
            schools = [f"{s.name} ({s.id})" for s in user.schools]
            print(f"SCHOOLS: {schools}")
            
            # Verify password hash internally
            try:
                matches = verify_password(password_to_check, user.hashed_password)
                print(f"PASSWORD_MATCHES: {matches}")
            except Exception as e:
                print(f"PASSWORD_MATCHES: ERROR ({e})")

if __name__ == "__main__":
    asyncio.run(main())
