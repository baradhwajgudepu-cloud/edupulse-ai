import asyncio
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

DATABASE_URL = "postgresql+asyncpg://postgres:Gudepu%4084@localhost:5432/edupulse_db"
TENANT_ID = "d09b9362-3dc8-422d-a441-160735fcea96"

async def main():
    engine = create_async_engine(DATABASE_URL)
    async with engine.connect() as conn:
        # Get tables
        res_tables = await conn.execute(text(
            "SELECT table_name FROM information_schema.tables WHERE table_schema='public'"
        ))
        print("--- Tables ---")
        tables = [r[0] for r in res_tables.fetchall()]
        print(tables)

        # Query all users for this tenant
        res_users = await conn.execute(text(
            "SELECT id, email, first_name, last_name, status FROM users WHERE tenant_id = :t_id"
        ), {"t_id": TENANT_ID})
        users = res_users.mappings().all()
        print("--- Users count ---", len(users))

        # Check user roles schema
        for tbl in ["roles", "user_roles", "permissions", "user_permissions", "role_permissions"]:
            if tbl in tables:
                res_tbl = await conn.execute(text(f"SELECT * FROM {tbl} LIMIT 5"))
                print(f"--- Table {tbl} ---")
                for row in res_tbl.mappings().all():
                    print(dict(row))

if __name__ == "__main__":
    asyncio.run(main())
