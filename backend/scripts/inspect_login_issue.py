import sys
import asyncio
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
from app.core.settings import settings

async def inspect():
    engine = create_async_engine(settings.DATABASE_URL)
    async with engine.connect() as conn:
        print("=== 1. EXACT SEARCH: edupulsetechnologies@gmail.com ===")
        res1 = await conn.execute(
            text("SELECT id, email, status, is_superuser, tenant_id, failed_login_attempts, locked_until FROM users WHERE LOWER(email) = 'edupulsetechnologies@gmail.com'")
        )
        rows1 = res1.fetchall()
        print(f"Found count: {len(rows1)}")
        for r in rows1:
            print(f"  ID: {r[0]} | Email: {r[1]} | Status: {r[2]} | Superuser: {r[3]} | Tenant: {r[4]} | Failed attempts: {r[5]} | Locked until: {r[6]}")

        print("\n=== 2. EXACT SEARCH: edupulsetechnolgies@gmail.com (Without 'o') ===")
        res2 = await conn.execute(
            text("SELECT id, email, status, is_superuser, tenant_id, failed_login_attempts, locked_until FROM users WHERE LOWER(email) = 'edupulsetechnolgies@gmail.com'")
        )
        rows2 = res2.fetchall()
        print(f"Found count: {len(rows2)}")
        for r in rows2:
            print(f"  ID: {r[0]} | Email: {r[1]} | Status: {r[2]} | Superuser: {r[3]} | Tenant: {r[4]} | Failed attempts: {r[5]} | Locked until: {r[6]}")

        print("\n=== 3. ALL USERS WITH 'edupulse' IN EMAIL ===")
        res3 = await conn.execute(
            text("SELECT u.id, u.email, u.status, u.is_superuser, u.tenant_id, t.name, t.code FROM users u LEFT JOIN tenants t ON u.tenant_id = t.id WHERE LOWER(u.email) LIKE '%edupulse%'")
        )
        for r in res3.fetchall():
            print(f"  ID: {r[0]} | Email: {r[1]} | Status: {r[2]} | Superuser: {r[3]} | Tenant: {r[4]} ({r[5]}, code={r[6]})")

        print("\n=== 4. ROLES FOR MATCHED USERS ===")
        res4 = await conn.execute(
            text("""
                SELECT u.email, r.code, r.name 
                FROM users u 
                JOIN user_roles ur ON u.id = ur.user_id 
                JOIN roles r ON ur.role_id = r.id 
                WHERE LOWER(u.email) LIKE '%edupulse%'
            """)
        )
        for r in res4.fetchall():
            print(f"  User: {r[0]} | Role Code: {r[1]} | Role Name: {r[2]}")

if __name__ == "__main__":
    asyncio.run(inspect())
