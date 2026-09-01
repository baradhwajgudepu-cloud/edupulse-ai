import asyncio
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

DATABASE_URL = "postgresql+asyncpg://postgres:Gudepu%4084@localhost:5432/edupulse_db"
TENANT_ID = "d09b9362-3dc8-422d-a441-160735fcea96"

async def main():
    engine = create_async_engine(DATABASE_URL)
    async with engine.connect() as conn:
        # Check Tenant
        res = await conn.execute(text("SELECT * FROM tenants WHERE id = :t_id"), {"t_id": TENANT_ID})
        tenant = res.mappings().all()
        print("--- Tenant ---")
        for t in tenant:
            print(dict(t))

        # Check Schools in Tenant
        res = await conn.execute(text("SELECT * FROM schools WHERE tenant_id = :t_id"), {"t_id": TENANT_ID})
        schools = res.mappings().all()
        print("--- Schools ---")
        for s in schools:
            print(dict(s))

        # Check Users in Tenant
        res = await conn.execute(text("SELECT * FROM users WHERE tenant_id = :t_id"), {"t_id": TENANT_ID})
        users = res.mappings().all()
        print("--- Users ---")
        for u in users:
            print({k: str(v) for k, v in dict(u).items() if k not in ["hashed_password"]})

if __name__ == "__main__":
    asyncio.run(main())
