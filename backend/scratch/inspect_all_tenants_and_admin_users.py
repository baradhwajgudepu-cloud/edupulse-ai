import asyncio
import os
import sys
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

sys.path.append(os.path.abspath(os.path.dirname(__file__) + "/.."))
from app.core.settings import settings

async def main():
    db_url = os.environ.get("DATABASE_URL") or settings.DATABASE_URL
    engine = create_async_engine(db_url)
    async with engine.connect() as conn:
        print("=== TENANTS ===")
        res_t = await conn.execute(text("SELECT id, name, code, is_active FROM tenants ORDER BY created_at"))
        for t in res_t.mappings().all():
            print(f"Tenant: {t['id']} | Name: '{t['name']}' | Code: '{t['code']}' | Active: {t['is_active']}")

        print("\n=== USERS (ADMIN / PRINCIPAL / SUPERUSER / LOCKED) ===")
        res_u = await conn.execute(text("""
            SELECT u.id, u.email, u.first_name, u.last_name, u.status, u.is_superuser, 
                   u.failed_login_attempts, u.locked_until, u.tenant_id,
                   COALESCE(array_agg(r.code) FILTER (WHERE r.code IS NOT NULL), '{}') as roles
            FROM users u
            LEFT JOIN user_roles ur ON u.id = ur.user_id
            LEFT JOIN roles r ON ur.role_id = r.id
            GROUP BY u.id, u.email, u.first_name, u.last_name, u.status, u.is_superuser, 
                     u.failed_login_attempts, u.locked_until, u.tenant_id
            HAVING u.status = 'LOCKED' 
                OR u.is_superuser = TRUE 
                OR 'ADMIN' = ANY(COALESCE(array_agg(r.code) FILTER (WHERE r.code IS NOT NULL), '{}'))
                OR 'SUPER_ADMIN' = ANY(COALESCE(array_agg(r.code) FILTER (WHERE r.code IS NOT NULL), '{}'))
                OR 'PRINCIPAL' = ANY(COALESCE(array_agg(r.code) FILTER (WHERE r.code IS NOT NULL), '{}'))
            ORDER BY u.created_at ASC
        """))
        for u in res_u.mappings().all():
            print(f"User: {u['id']} | Email: {u['email']} | Name: {u['first_name']} {u['last_name']} | Status: {u['status']} | Roles: {u['roles']} | Superuser: {u['is_superuser']} | FailedAttempts: {u['failed_login_attempts']} | LockedUntil: {u['locked_until']} | TenantID: {u['tenant_id']}")

if __name__ == "__main__":
    asyncio.run(main())
