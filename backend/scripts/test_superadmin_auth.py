import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import asyncio
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from app.core.settings import settings
from app.schemas.auth import LoginRequest
from app.repositories.auth import (
    UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
)
from app.repositories.school import SchoolRepository
from app.services.auth import AuthService

async def test_auth_and_reset():
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    email = "edupulsetechnolgies@gmail.com"
    password = "Gudepu@84"

    async with async_session() as session:
        user_repo = UserRepository(session)
        role_repo = RoleRepository(session)
        perm_repo = PermissionRepository(session)
        refresh_repo = RefreshTokenRepository(session)
        school_repo = SchoolRepository(session)

        auth_service = AuthService(
            user_repo=user_repo,
            role_repo=role_repo,
            perm_repo=perm_repo,
            refresh_repo=refresh_repo,
            school_repo=school_repo
        )

        # 1. Test Platform Authentication
        print("Testing platform login with credentials...")
        login_req = LoginRequest(email=email, password=password)
        user = await auth_service.authenticate_platform(login_req)
        print(f"[OK] Platform Login SUCCESSFUL: {user.email} (is_superuser={user.is_superuser})")

        tokens = await auth_service.create_tokens(user, is_platform=True)
        print(f"[OK] Access Token generated successfully (len={len(tokens.access_token)})")

        # 2. Test Request Password Reset
        print("\nTesting password reset request...")
        await auth_service.request_password_reset(email=email, client_ip="127.0.0.1")
        
        user_db = await user_repo.get_by_email_platform(email)
        print(f"[OK] Reset Hash Generated in DB: {user_db.password_reset_hash is not None}")
        print(f"[OK] Reset Expires At: {user_db.password_reset_expires_at}")

    await engine.dispose()

if __name__ == "__main__":
    asyncio.run(test_auth_and_reset())
