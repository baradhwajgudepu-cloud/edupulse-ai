import uuid
from typing import Optional
from fastapi import Header, Query, HTTPException, status, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.constants import DEFAULT_PAGE_SIZE, MAX_PAGE_SIZE
from app.db.session import get_db
from app.api.dependencies.auth import get_current_user, LEGACY_PLAY_STORE_TENANT_ID
from app.models.user import User
from app.models.school import School

from app.core.security import decode_access_token

async def get_pagination_params(
    page: int = Query(1, ge=1, description="Page number"),
    size: int = Query(DEFAULT_PAGE_SIZE, ge=1, le=MAX_PAGE_SIZE, description="Items per page")
) -> dict:
    """
    Shared dependency to parse pagination parameters.
    """
    skip = (page - 1) * size
    return {"page": page, "size": size, "skip": skip}

async def get_tenant_id(
    x_tenant_id: Optional[str] = Header(None, alias="X-Tenant-ID", description="Active Tenant UUID"),
    authorization: Optional[str] = Header(None, alias="Authorization")
) -> uuid.UUID:
    """
    Shared dependency to extract and validate the active Tenant UUID from request headers
    or from verified JWT token claims.
    """
    parsed_header_tenant: Optional[uuid.UUID] = None
    if x_tenant_id and x_tenant_id.strip() and x_tenant_id != "None":
        try:
            parsed_header_tenant = uuid.UUID(x_tenant_id.strip())
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid X-Tenant-ID header format. Must be a valid UUID."
            )

    token_tenant: Optional[uuid.UUID] = None
    if authorization and authorization.startswith("Bearer "):
        token = authorization[7:].strip()
        try:
            payload = decode_access_token(token)
            t_id = payload.get("tenant_id")
            if t_id and t_id != "None":
                token_tenant = uuid.UUID(t_id)
        except Exception:
            pass

    # Legacy Play Store compatibility bridge:
    # If legacy Play Store header is sent with an authenticated token, ignore legacy header and use JWT tenant_id
    if parsed_header_tenant == LEGACY_PLAY_STORE_TENANT_ID and token_tenant:
        return token_tenant

    if parsed_header_tenant:
        return parsed_header_tenant

    if token_tenant:
        return token_tenant

    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="X-Tenant-ID header is missing."
    )


async def get_optional_tenant_id(
    x_tenant_id: Optional[str] = Header(None, alias="X-Tenant-ID", description="Active Tenant UUID")
) -> Optional[uuid.UUID]:
    """
    Shared dependency to optionally extract and validate the active Tenant UUID from request headers.
    Returns None if header is omitted, blank, or string 'none'/'null'/'undefined'.
    Raises 400 only if a non-empty header format is not a valid UUID.
    """
    if not x_tenant_id or not x_tenant_id.strip():
        return None
    cleaned = x_tenant_id.strip()
    if cleaned.lower() in ("none", "null", "undefined"):
        return None
    try:
        return uuid.UUID(cleaned)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid X-Tenant-ID header format. Must be a valid UUID."
        )

async def get_school_id(
    x_school_id: Optional[str] = Header(None, alias="X-School-ID", description="Active School UUID"),
    current_user: "User" = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
) -> uuid.UUID:
    """
    Shared dependency to extract and validate the active School UUID from request headers.
    Ensures that the authenticated user is authorized to access the requested school context (preventing IDOR).
    """
    if not x_school_id:
        # Auto-resolve school context if user is assigned to exactly one school
        if current_user.schools and len(current_user.schools) == 1:
            return current_user.schools[0].id
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="X-School-ID header is missing."
        )
    try:
        school_uuid = uuid.UUID(x_school_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid X-School-ID header format. Must be a valid UUID."
        )

    # 1. Platform Super Admin checks
    is_super = current_user.is_superuser or any(r.code in ["SUPER_ADMIN", "SYSTEM_ADMIN"] for r in current_user.roles)
    if is_super:
        return school_uuid

    # 2. Tenant Admin / Chairman checks
    is_tenant_admin = any(r.code in ["TENANT_ADMIN", "CHAIRMAN"] for r in current_user.roles)
    if is_tenant_admin:
        stmt = select(School).where(School.id == school_uuid, School.tenant_id == current_user.tenant_id)
        res = await db.execute(stmt)
        school = res.scalar_one_or_none()
        if not school:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. School does not belong to the user's tenant context."
            )
        return school_uuid

    # 3. School Admin / Principal / Teacher / Parent checks (strictly linked schools only)
    user_school_ids = {s.id for s in current_user.schools}
    if school_uuid not in user_school_ids:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. User is not authorized to access this school campus."
        )

    return school_uuid

async def get_optional_school_id(
    x_school_id: Optional[str] = Header(None, alias="X-School-ID", description="Active School UUID"),
    current_user: "User" = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
) -> Optional[uuid.UUID]:
    """
    Shared dependency to extract and validate the active School UUID from request headers optionally.
    If the header is missing:
      - If user is assigned to exactly one school, automatically resolves to that school.
      - If the user is a platform admin (SUPER_ADMIN) or tenant admin (TENANT_ADMIN, CHAIRMAN), return None.
      - Otherwise, raise HTTP 400 Bad Request.
    If the header is present, it validates context permissions exactly like get_school_id.
    """
    if not x_school_id:
        is_platform = current_user.is_superuser or any(r.code in ["SUPER_ADMIN", "SYSTEM_ADMIN"] for r in current_user.roles)
        is_tenant_admin = any(r.code in ["TENANT_ADMIN", "CHAIRMAN"] for r in current_user.roles)
        if is_platform or is_tenant_admin:
            return None
        if current_user.schools and len(current_user.schools) == 1:
            return current_user.schools[0].id
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="X-School-ID header is missing."
        )

    try:
        school_uuid = uuid.UUID(x_school_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid X-School-ID header format. Must be a valid UUID."
        )

    # 1. Platform Super Admin checks
    is_super = current_user.is_superuser or any(r.code == "SUPER_ADMIN" for r in current_user.roles)
    if is_super:
        return school_uuid

    # 2. Tenant Admin / Chairman checks
    is_tenant_admin = any(r.code in ["TENANT_ADMIN", "CHAIRMAN"] for r in current_user.roles)
    if is_tenant_admin:
        stmt = select(School).where(School.id == school_uuid, School.tenant_id == current_user.tenant_id)
        res = await db.execute(stmt)
        school = res.scalar_one_or_none()
        if not school:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. School does not belong to the user's tenant context."
            )
        return school_uuid

    # 3. School Admin / Principal / Teacher / Parent checks (strictly linked schools only)
    user_school_ids = {s.id for s in current_user.schools}
    if school_uuid not in user_school_ids:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. User is not authorized to access this school campus."
        )

    return school_uuid


async def verify_school_access(user: "User", school_id: uuid.UUID, db: AsyncSession) -> None:
    """
    Centralized school isolation check.
    Verifies that school exists, is active, belongs to user's tenant,
    and that the user has authorization for this campus.
    """
    stmt = select(School).where(School.id == school_id)
    res = await db.execute(stmt)
    school = res.scalar_one_or_none()
    if not school:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="School not found."
        )

    if not user.is_superuser and school.tenant_id != user.tenant_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. School belongs to a different tenant."
        )

    if not school.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="School is inactive."
        )

    if user.is_superuser:
        return

    user_role_codes = [role.code for role in user.roles]
    if any(code in ["SUPER_ADMIN", "SYSTEM_ADMIN", "TENANT_ADMIN", "CHAIRMAN"] for code in user_role_codes):
        return

    # Check if school is in user's assigned schools
    user_school_ids = {s.id for s in user.schools} if user.schools else set()
    if school_id in user_school_ids:
        return

    # Check school_users table
    from app.models.role import school_users
    stmt_su = select(1).select_from(school_users).where(
        school_users.c.user_id == user.id,
        school_users.c.school_id == school_id
    )
    res_su = await db.execute(stmt_su)
    if res_su.fetchone():
        return

    # Parents are verified at the object level via linked student enrollments
    if "PARENT" in user_role_codes:
        return

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Access denied. User is not authorized to access this school campus."
    )

