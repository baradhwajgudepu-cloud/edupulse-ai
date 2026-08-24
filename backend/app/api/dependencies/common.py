import uuid
from typing import Optional
from fastapi import Header, Query, HTTPException, status, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.constants import DEFAULT_PAGE_SIZE, MAX_PAGE_SIZE
from app.db.session import get_db
from app.api.dependencies.auth import get_current_user
from app.models.user import User
from app.models.school import School

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
    x_tenant_id: Optional[str] = Header(None, alias="X-Tenant-ID", description="Active Tenant UUID")
) -> uuid.UUID:
    """
    Shared dependency to extract and validate the active Tenant UUID from request headers.
    """
    if not x_tenant_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="X-Tenant-ID header is missing."
        )
    try:
        return uuid.UUID(x_tenant_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid X-Tenant-ID header format. Must be a valid UUID."
        )

async def get_optional_tenant_id(
    x_tenant_id: Optional[str] = Header(None, alias="X-Tenant-ID", description="Active Tenant UUID")
) -> Optional[uuid.UUID]:
    """
    Shared dependency to extract and validate the active Tenant UUID from request headers optionally.
    """
    if not x_tenant_id:
        return None
    try:
        return uuid.UUID(x_tenant_id)
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

async def get_optional_school_id(
    x_school_id: Optional[str] = Header(None, alias="X-School-ID", description="Active School UUID"),
    current_user: "User" = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
) -> Optional[uuid.UUID]:
    """
    Shared dependency to extract and validate the active School UUID from request headers optionally.
    If the header is missing:
      - If the user is a platform admin (SUPER_ADMIN) or tenant admin (TENANT_ADMIN, CHAIRMAN), return None.
      - Otherwise, raise HTTP 400 Bad Request.
    If the header is present, it validates context permissions exactly like get_school_id.
    """
    if not x_school_id:
        is_platform = current_user.is_superuser or any(r.code == "SUPER_ADMIN" for r in current_user.roles)
        is_tenant_admin = any(r.code in ["TENANT_ADMIN", "CHAIRMAN"] for r in current_user.roles)
        if is_platform or is_tenant_admin:
            return None
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
