import asyncio
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

DATABASE_URL = "postgresql+asyncpg://postgres:Gudepu%4084@localhost:5432/edupulse_db"
TENANT_ID = "d09b9362-3dc8-422d-a441-160735fcea96"

async def main():
    engine = create_async_engine(DATABASE_URL)
    async with engine.begin() as conn:
        print("Restoring schools by clearing deleted_at...")
        res = await conn.execute(
            text("UPDATE schools SET deleted_at = NULL WHERE tenant_id = :t_id"),
            {"t_id": TENANT_ID}
        )
        print(f"Schools updated: {res.rowcount}")

        print("Restoring academic_years by clearing deleted_at...")
        res = await conn.execute(
            text("UPDATE academic_years SET deleted_at = NULL WHERE tenant_id = :t_id"),
            {"t_id": TENANT_ID}
        )
        print(f"Academic years updated: {res.rowcount}")

        print("Restoring classes by clearing deleted_at...")
        res = await conn.execute(
            text("UPDATE classes SET deleted_at = NULL WHERE tenant_id = :t_id"),
            {"t_id": TENANT_ID}
        )
        print(f"Classes updated: {res.rowcount}")

        print("Restoring sections by clearing deleted_at...")
        res = await conn.execute(
            text("UPDATE sections SET deleted_at = NULL WHERE tenant_id = :t_id"),
            {"t_id": TENANT_ID}
        )
        print(f"Sections updated: {res.rowcount}")

        print("Restoring students by clearing deleted_at...")
        res = await conn.execute(
            text("UPDATE students SET deleted_at = NULL WHERE tenant_id = :t_id"),
            {"t_id": TENANT_ID}
        )
        print(f"Students updated: {res.rowcount}")

        print("Restoring teachers by clearing deleted_at...")
        res = await conn.execute(
            text("UPDATE teachers SET deleted_at = NULL WHERE tenant_id = :t_id"),
            {"t_id": TENANT_ID}
        )
        print(f"Teachers updated: {res.rowcount}")

        print("Restoring guardians by clearing deleted_at...")
        res = await conn.execute(
            text("UPDATE guardians SET deleted_at = NULL WHERE tenant_id = :t_id"),
            {"t_id": TENANT_ID}
        )
        print(f"Guardians updated: {res.rowcount}")

if __name__ == "__main__":
    asyncio.run(main())
