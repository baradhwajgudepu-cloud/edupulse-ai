import sys
import asyncio
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
from app.core.settings import settings
from app.core.security import verify_password

async def test_pwd():
    engine = create_async_engine(settings.DATABASE_URL)
    async with engine.connect() as conn:
        res = await conn.execute(
            text("SELECT id, email, hashed_password FROM users WHERE email = 'edupulsetechnolgies@gmail.com'")
        )
        row = res.fetchone()
        if row:
            matches = verify_password("Gudepu@84", row[2])
            print(f"User email in DB: {row[1]}")
            print(f"Password 'Gudepu@84' valid: {matches}")
        else:
            print("User not found.")

if __name__ == "__main__":
    asyncio.run(test_pwd())
