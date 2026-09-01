import asyncio
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

DATABASE_URL = "postgresql+asyncpg://postgres:Gudepu%4084@localhost:5432/edupulse_db"
TENANT_ID = "d09b9362-3dc8-422d-a441-160735fcea96"

async def main():
    engine = create_async_engine(DATABASE_URL)
    async with engine.connect() as conn:
        # Get all roles
        res_roles = await conn.execute(text("SELECT * FROM roles"))
        print("--- All Roles ---")
        for r in res_roles.mappings().all():
            print(dict(r))

        # Get all schools in the tenant
        res_schools = await conn.execute(text("SELECT * FROM schools WHERE tenant_id = :t_id"), {"t_id": TENANT_ID})
        print("--- Schools in Target Tenant ---")
        for s in res_schools.mappings().all():
            print(dict(s))

        # Check user roles for this tenant
        query = """
            SELECT u.email, u.first_name, u.last_name, r.code as role_code, r.name as role_name
            FROM users u
            JOIN user_roles ur ON u.id = ur.user_id
            JOIN roles r ON ur.role_id = r.id
            WHERE u.tenant_id = :t_id
        """
        res_users = await conn.execute(text(query), {"t_id": TENANT_ID})
        print("--- Users in Target Tenant with Roles ---")
        for u in res_users.mappings().all():
            print(dict(u))

if __name__ == "__main__":
    asyncio.run(main())
