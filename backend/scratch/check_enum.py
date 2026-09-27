import asyncio, sys, os
sys.path.insert(0, os.path.abspath('.'))
from app.db.session import AsyncSessionLocal
from sqlalchemy import text

async def main():
    async with AsyncSessionLocal() as db:
        res = await db.execute(text("""
            SELECT pg_type.typname, enumlabel 
            FROM pg_enum 
            JOIN pg_type ON pg_enum.enumtypid = pg_type.oid 
            WHERE pg_type.typname LIKE 'exam%'
            ORDER BY pg_type.typname, pg_enum.enumsortorder;
        """))
        enums = {}
        for typname, label in res.all():
            enums.setdefault(typname, []).append(label)
        for k, v in enums.items():
            print(f'{k}: {v}')

if __name__ == '__main__':
    asyncio.run(main())
