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

async def get_tenant_deletion_service(
    db: AsyncSession = Depends(get_db)
) -> "TenantDeletionService":
    """
    FastAPI dependency that injects an AsyncSession and StorageService to return a TenantDeletionService.
    """
    from app.services.tenant_deletion import TenantDeletionService
    from app.services.storage import get_storage_service
    storage_service = get_storage_service()
    return TenantDeletionService(db=db, storage_service=storage_service)
