import os
import sys
import argparse
import asyncio
from pathlib import Path

# Add backend root to sys.path
BACKEND_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_DIR))

from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from app.core.settings import settings
from app.repositories.auth import (
    UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
)
from app.repositories.school import SchoolRepository
from app.services.auth import AuthService

async def run_unlock(
    email: str | None = None,
    user_id: str | None = None,
    dry_run: bool = False
) -> int:
    target_email = email or os.getenv("TARGET_UNLOCK_EMAIL")
    target_user_id = user_id or os.getenv("TARGET_UNLOCK_USER_ID")

    if not target_email and not target_user_id:
        print("[ERROR] Target email (--email) or user ID (--user-id) is required.", file=sys.stderr)
        return 1

    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    try:
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

            result = await auth_service.unlock_account(
                email=target_email,
                user_id=target_user_id,
                dry_run=dry_run
            )

            prefix = "[DRY-RUN] " if dry_run else ""
            action = result.get("action")
            user_email = result.get("email")

            if action == "UNLOCKED":
                print(f"{prefix}[OK] Account successfully unlocked: {user_email}")
                print(f"{prefix}[OK] Previous Status: {result.get('previous_status')} -> New Status: {result.get('new_status')}")
                print(f"{prefix}[OK] Reset failed login attempts and lockout timestamp")
            elif action == "ALREADY_ACTIVE":
                print(f"{prefix}[INFO] Account is already ACTIVE: {user_email}")
                print(f"{prefix}[INFO] No changes made (idempotent).")

            return 0
    except Exception as e:
        detail = getattr(e, "detail", str(e))
        print(f"[ERROR] Failed to unlock account: {detail}", file=sys.stderr)
        return 1
    finally:
        await engine.dispose()

def main():
    parser = argparse.ArgumentParser(
        description="Safe, idempotent administrator account unlock utility for EduPulse AI"
    )
    parser.add_argument(
        "--email",
        type=str,
        default=None,
        help="Target administrator email to unlock"
    )
    parser.add_argument(
        "--user-id",
        type=str,
        default=None,
        help="Target administrator user UUID to unlock"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Simulate the unlock operation without committing database changes"
    )

    args = parser.parse_args()
    exit_code = asyncio.run(
        run_unlock(
            email=args.email,
            user_id=args.user_id,
            dry_run=args.dry_run
        )
    )
    sys.exit(exit_code)

if __name__ == "__main__":
    main()
