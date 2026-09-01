import sys
import os
sys.path.append(os.path.abspath('.'))

import asyncio
from sqlalchemy import text
from app.db.session import AsyncSessionLocal

async def main():
    async with AsyncSessionLocal() as session:
        # Get column names and types for the schools table
        result = await session.execute(text("""
            SELECT column_name, data_type 
            FROM information_schema.columns 
            WHERE table_name = 'schools'
        """))
        columns = result.fetchall()
        print("Schools table columns:")
        for col in columns:
            print(f"  {col[0]}: {col[1]}")

if __name__ == "__main__":
    asyncio.run(main())
