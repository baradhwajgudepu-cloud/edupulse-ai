import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
from app.core.settings import settings

async def check():
    engine = create_async_engine(settings.DATABASE_URL)
    async with engine.connect() as conn:
        res = await conn.execute(text("SELECT id, name, code, email FROM tenants ORDER BY created_at"))
        print("=== TENANTS ===")
        for r in res.fetchall():
            print(f"Tenant: {r[0]} | {r[1]} | code={r[2]} | email={r[3]}")

        users = await conn.execute(text("SELECT id, email, is_superuser, tenant_id FROM users WHERE is_superuser = true"))
        print("\n=== SUPERUSERS ===")
        for u in users.fetchall():
            print(f"User: {u[0]} | {u[1]} | is_superuser={u[2]} | tenant_id={u[3]}")

if __name__ == "__main__":
    asyncio.run(check())
