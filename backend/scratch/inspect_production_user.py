import asyncio
import sys
import os
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

# Add parent path to sys.path so we can import app packages
sys.path.append(os.path.abspath(os.path.dirname(__file__) + "/.."))
from app.core.security import verify_password

DATABASE_URL = "postgresql+asyncpg://postgres:Gudepu%4084@localhost:5432/edupulse_db"

async def main():
    engine = create_async_engine(DATABASE_URL)
    async with engine.connect() as conn:
        # 1. Fetch all tenants
        print("=== Checking Tenants ===")
        res_t = await conn.execute(text("SELECT id, name, code FROM tenants"))
        tenants = res_t.mappings().all()
        for t in tenants:
            print(f"Tenant ID: {t['id']} | Name: {t['name']} | Code: {t['code']}")

        # 2. Fetch specific user
        email = "principal.a2707e@edupulse.local"
        tenant_id = "09f2d4e7-2877-4e42-9e95-e97d52775687"
        
        print("\n=== Checking Target User ===")
        query = """
            SELECT u.id, u.email, u.tenant_id, u.status, u.deleted_at, 
                   u.must_change_password, u.failed_login_attempts, 
                   u.locked_until, u.is_superuser, u.hashed_password
            FROM users u
            WHERE u.email = :email
        """
        res_u = await conn.execute(text(query), {"email": email})
        users = res_u.mappings().all()
        print(f"Number of rows found matching email '{email}': {len(users)}")
        
        for idx, u in enumerate(users):
            print(f"\nRow {idx + 1}:")
            print(f"  ID: {u['id']}")
            print(f"  Email: {u['email']}")
            print(f"  Tenant ID: {u['tenant_id']}")
            print(f"  Status: {u['status']}")
            print(f"  Deleted At: {u['deleted_at']}")
            print(f"  Must Change Password: {u['must_change_password']}")
            print(f"  Failed Login Attempts: {u['failed_login_attempts']}")
            print(f"  Locked Until: {u['locked_until']}")
            print(f"  Is Superuser: {u['is_superuser']}")
            
            # Fetch user roles
            query_roles = """
                SELECT r.name, r.code
                FROM user_roles ur
                JOIN roles r ON ur.role_id = r.id
                WHERE ur.user_id = :user_id
            """
            res_r = await conn.execute(text(query_roles), {"user_id": u['id']})
            roles = [f"{r['name']} ({r['code']})" for r in res_r.mappings().all()]
            print(f"  Roles: {roles}")

            # Verify password hash internally
            try:
                match = verify_password("LocalUat@123", u['hashed_password'])
                print(f"  Password Match for 'LocalUat@123': {match}")
            except Exception as ex:
                print(f"  Password check error: {ex}")

if __name__ == "__main__":
    asyncio.run(main())
