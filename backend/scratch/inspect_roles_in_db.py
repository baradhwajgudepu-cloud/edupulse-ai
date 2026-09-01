import asyncio
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

DATABASE_URL = "postgresql+asyncpg://postgres:Gudepu%4084@localhost:5432/edupulse_db"
TENANT_ID = "d09b9362-3dc8-422d-a441-160735fcea96"

async def main():
    engine = create_async_engine(DATABASE_URL)
    async with engine.connect() as conn:
        # Check all roles
        res_r = await conn.execute(text("SELECT id, name, code FROM roles"))
        roles = res_r.mappings().all()
        print("--- ALL ROLES IN DB ---")
        for r in roles:
            print(dict(r))

        # Check all user roles for the UAT tenant
        query = """
            SELECT u.email, u.first_name, u.last_name, r.name as role_name, r.code as role_code
            FROM users u
            JOIN user_roles ur ON u.id = ur.user_id
            JOIN roles r ON ur.role_id = r.id
            WHERE u.tenant_id = :t_id
        """
        res_u = await conn.execute(text(query), {"t_id": TENANT_ID})
        print("\n--- ALL USERS WITH ROLES IN TENANT ---")
        for u in res_u.mappings().all():
            print(dict(u))

if __name__ == "__main__":
    asyncio.run(main())
