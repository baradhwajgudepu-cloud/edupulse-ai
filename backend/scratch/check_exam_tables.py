import sys, os
sys.path.insert(0, os.path.abspath('.'))
import asyncio
from sqlalchemy import text
from app.db.session import AsyncSessionLocal

async def check():
    async with AsyncSessionLocal() as session:
        for tbl in ['examinations', 'examination_classes', 'exam_schedules']:
            res = await session.execute(text(f"""
                SELECT column_name, data_type, is_nullable
                FROM information_schema.columns
                WHERE table_schema='public' AND table_name='{tbl}'
                ORDER BY ordinal_position;
            """))
            cols = res.all()
            print(f"\n--- {tbl} ({len(cols)} columns) ---")
            for c in cols:
                print(f"  {c[0]}: {c[1]} (nullable: {c[2]})")

if __name__ == '__main__':
    asyncio.run(check())
