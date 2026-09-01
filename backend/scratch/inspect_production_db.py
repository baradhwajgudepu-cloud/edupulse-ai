import asyncio
import os
import sys
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

# Setup python path to load the application modules correctly
sys.path.append(os.path.abspath(os.path.dirname(__file__) + "/.."))
from app.core.settings import settings
from app.core.security import verify_password

async def main():
    db_url = os.environ.get("DATABASE_URL") or settings.DATABASE_URL
    if not db_url:
        print("Error: DATABASE_URL not set in environment or settings.")
        return

    # Print safe db target info (redacted password)
    safe_db_url = db_url.split("@")[-1] if "@" in db_url else db_url
    print(f"Connecting to database target: {safe_db_url} ...")

    engine = create_async_engine(db_url)
    async with engine.connect() as conn:
        email = "principal.a2707e@edupulse.local"
        
        query = """
            SELECT u.id, u.email, u.tenant_id, u.status, u.deleted_at, 
                   u.must_change_password, u.failed_login_attempts, 
                   u.locked_until, u.is_superuser, u.hashed_password
            FROM users u
            WHERE u.email = :email
        """
        res = await conn.execute(text(query), {"email": email})
        rows = res.mappings().all()
        print(f"User rows found: {len(rows)}")
        
        for idx, row in enumerate(rows):
            print(f"\nUser ID: {row['id']}")
            print(f"Email: {row['email']}")
            print(f"Tenant ID: {row['tenant_id']}")
            print(f"Status: {row['status']}")
            print(f"Deleted status: {'Deleted' if row['deleted_at'] else 'Not Deleted (NULL)'}")
            print(f"Locked status: {row['locked_until']}")
            print(f"must_change_password: {row['must_change_password']}")
            
            # Fetch roles
            role_q = """
                SELECT r.code, r.name 
                FROM user_roles ur
                JOIN roles r ON ur.role_id = r.id
                WHERE ur.user_id = :user_id
            """
            res_roles = await conn.execute(text(role_q), {"user_id": row['id']})
            role_rows = res_roles.mappings().all()
            roles = [f"{r['name']} ({r['code']})" for r in role_rows]
            print(f"Roles: {roles}")
            
            # Match password internally
            password = "LocalUat@123"
            try:
                matches = verify_password(password, row['hashed_password'])
                print(f"password_matches for {password}: {matches}")
            except Exception as e:
                print(f"Error checking password: {e}")

if __name__ == "__main__":
    asyncio.run(main())
