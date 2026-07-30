import asyncio
import asyncpg

async def test():
    try:
        conn = await asyncpg.connect(
            user="postgres",
            password="Gudepu@84",
            database="edupulse_db",
            host="localhost",
            port=5432,
        )
        print("✅ SUCCESS: Connected to PostgreSQL")
        await conn.close()
    except Exception as e:
        print("❌ ERROR:", e)

asyncio.run(test())