from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import get_db
from app.repositories.tenant import TenantRepository
from app.services.tenant import TenantService

async def get_tenant_repository(db: AsyncSession = Depends(get_db)) -> TenantRepository:
    """
    FastAPI dependency that injects an AsyncSession and returns a TenantRepository.
    """
    return TenantRepository(db)

async def get_tenant_service(
    repo: TenantRepository = Depends(get_tenant_repository)
) -> TenantService:
    """
    FastAPI dependency that injects a TenantRepository and returns a TenantService.
    """
    return TenantService(repo)
