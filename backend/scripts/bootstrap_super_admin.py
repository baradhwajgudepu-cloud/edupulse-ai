import os
import sys
import argparse
import asyncio
from pathlib import Path

# Add backend directory to sys.path
BACKEND_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_DIR))

from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from app.core.settings import settings
from app.repositories.auth import (
    UserRepository, RoleRepository, PermissionRepository,
    RefreshTokenRepository
)
from app.repositories.school import SchoolRepository
from app.services.auth import AuthService

async def run_bootstrap(
    email: str | None = None,
    password: str | None = None,
    first_name: str | None = None,
    last_name: str | None = None,
    ensure_only: bool = False,
    reset_password: bool = False,
    dry_run: bool = False
) -> int:
    target_email = email or os.getenv("SUPER_ADMIN_EMAIL") or settings.SUPER_ADMIN_EMAIL
    target_password = password or os.getenv("SUPER_ADMIN_INITIAL_PASSWORD") or settings.SUPER_ADMIN_INITIAL_PASSWORD
    target_first_name = first_name or os.getenv("SUPER_ADMIN_FIRST_NAME") or settings.SUPER_ADMIN_FIRST_NAME
    target_last_name = last_name or os.getenv("SUPER_ADMIN_LAST_NAME") or settings.SUPER_ADMIN_LAST_NAME

    if not target_email:
        print("[ERROR] Super Admin email is required. Please set SUPER_ADMIN_EMAIL environment variable or use --email flag.", file=sys.stderr)
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

            result = await auth_service.bootstrap_super_admin(
                email=target_email,
                password=target_password,
                first_name=target_first_name,
                last_name=target_last_name,
                ensure_only=ensure_only,
                reset_password=reset_password,
                dry_run=dry_run
            )


            action = result.get("action")
            res_email = result.get("email")
            res_role = result.get("role")
            is_dry_run = result.get("dry_run", False)

            prefix = "[DRY-RUN] " if is_dry_run else ""

            if action == "CREATED":
                print(f"{prefix}[OK] Super Admin account created successfully: {res_email}")
                print(f"{prefix}[OK] Role assigned: {res_role}")
                print(f"{prefix}[OK] Status: ACTIVE (is_superuser=True)")
            elif action == "UPDATED":
                print(f"{prefix}[OK] Super Admin account exists: {res_email}")
                print(f"{prefix}[OK] Super Admin role verified: {res_role}")
                print(f"{prefix}[OK] Password reset and updated successfully")
            elif action == "VERIFIED":
                print(f"{prefix}[OK] Super Admin account exists: {res_email}")
                print(f"{prefix}[OK] Super Admin role verified: {res_role}")
                print(f"{prefix}[OK] Password unchanged")

            return 0
    except ValueError as ve:
        print(f"[ERROR] Configuration error: {str(ve)}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"[ERROR] Failed to execute Super Admin bootstrap: {str(e)}", file=sys.stderr)
        return 1
    finally:
        await engine.dispose()

def main():
    parser = argparse.ArgumentParser(
        description="Idempotent Super Admin Bootstrap / Update CLI for EduPulse AI"
    )
    parser.add_argument(
        "--email",
        type=str,
        default=None,
        help="Super Admin email address (defaults to SUPER_ADMIN_EMAIL env var)"
    )
    parser.add_argument(
        "--password",
        type=str,
        default=None,
        help="Super Admin password (defaults to SUPER_ADMIN_INITIAL_PASSWORD env var)"
    )
    parser.add_argument(
        "--first-name",
        type=str,
        default=None,
        help="Super Admin first name (defaults to SUPER_ADMIN_FIRST_NAME env var)"
    )
    parser.add_argument(
        "--last-name",
        type=str,
        default=None,
        help="Super Admin last name (defaults to SUPER_ADMIN_LAST_NAME env var)"
    )
    parser.add_argument(
        "--ensure",
        action="store_true",
        help="Ensures Super Admin account and role exists without modifying existing password"
    )
    parser.add_argument(
        "--reset-password",
        action="store_true",
        help="Explicitly updates/resets the Super Admin password"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Simulate the bootstrap operation without committing database changes"
    )

    args = parser.parse_args()

    exit_code = asyncio.run(
        run_bootstrap(
            email=args.email,
            password=args.password,
            first_name=args.first_name,
            last_name=args.last_name,
            ensure_only=args.ensure,
            reset_password=args.reset_password,
            dry_run=args.dry_run
        )
    )

    sys.exit(exit_code)

if __name__ == "__main__":
    main()
