import asyncio
import os
import sys
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

sys.path.append(os.path.abspath(os.path.dirname(__file__) + "/.."))
from app.core.settings import settings

async def main():
    db_url = os.environ.get("DATABASE_URL") or settings.DATABASE_URL
    print(f"Connecting to DB (target host: {db_url.split('@')[-1] if '@' in db_url else 'unknown'})...")
    
    engine = create_async_engine(db_url)
    async with engine.connect() as conn:
        query = """
            SELECT 
                u.id, 
                u.email, 
                u.login_id, 
                u.status, 
                u.is_superuser,
                u.failed_login_attempts, 
                u.locked_until, 
                u.last_login, 
                u.tenant_id,
                u.deleted_at,
                COALESCE(array_agg(r.code) FILTER (WHERE r.code IS NOT NULL), '{}') as roles
            FROM users u
            LEFT JOIN user_roles ur ON u.id = ur.user_id
            LEFT JOIN roles r ON ur.role_id = r.id
            GROUP BY u.id, u.email, u.login_id, u.status, u.is_superuser, 
                     u.failed_login_attempts, u.locked_until, u.last_login, 
                     u.tenant_id, u.deleted_at
            HAVING u.status = 'LOCKED' 
                OR u.is_superuser = TRUE 
                OR 'ADMIN' = ANY(COALESCE(array_agg(r.code) FILTER (WHERE r.code IS NOT NULL), '{}'))
                OR 'SUPER_ADMIN' = ANY(COALESCE(array_agg(r.code) FILTER (WHERE r.code IS NOT NULL), '{}'))
                OR 'TENANT_ADMIN' = ANY(COALESCE(array_agg(r.code) FILTER (WHERE r.code IS NOT NULL), '{}'))
                OR 'PRINCIPAL' = ANY(COALESCE(array_agg(r.code) FILTER (WHERE r.code IS NOT NULL), '{}'))
            ORDER BY u.created_at ASC
        """
        res = await conn.execute(text(query))
        rows = res.mappings().all()
        print(f"\nTotal users found: {len(rows)}\n")
        print("=" * 80)
        for r in rows:
            print(f"User ID:               {r['id']}")
            print(f"Email:                 {r['email']}")
            print(f"Login ID:              {r['login_id']}")
            print(f"Status:                {r['status']}")
            print(f"Is Superuser:          {r['is_superuser']}")
            print(f"Failed Login Attempts: {r['failed_login_attempts']}")
            print(f"Locked Until:          {r['locked_until']}")
            print(f"Last Login:            {r['last_login']}")
            print(f"Tenant ID:             {r['tenant_id']}")
            print(f"Deleted:               {r['deleted_at'] is not None}")
            print(f"Roles:                 {r['roles']}")
            print("-" * 80)

if __name__ == "__main__":
    asyncio.run(main())
