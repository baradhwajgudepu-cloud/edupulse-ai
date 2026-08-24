import asyncio
from sqlalchemy import text
from app.db.session import AsyncSessionLocal

async def main():
    try:
        async with AsyncSessionLocal() as session:
            result = await session.execute(text("SELECT 1"))
            print("✅ SQLAlchemy Connected:", result.scalar())
    except Exception as e:
        print("❌ SQLAlchemy Error:")
        print(type(e).__name__)
        print(e)

asyncio.run(main())