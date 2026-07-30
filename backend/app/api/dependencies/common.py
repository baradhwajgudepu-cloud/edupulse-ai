import uuid
from typing import Optional
from fastapi import Header, Query, HTTPException, status
from app.core.constants import DEFAULT_PAGE_SIZE, MAX_PAGE_SIZE

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
