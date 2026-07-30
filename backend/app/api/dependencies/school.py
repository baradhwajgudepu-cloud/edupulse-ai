from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import get_db
from app.repositories.school import SchoolRepository
from app.services.school import SchoolService

async def get_school_repository(db: AsyncSession = Depends(get_db)) -> SchoolRepository:
    """
    FastAPI dependency that injects an AsyncSession and returns a SchoolRepository.
    """
    return SchoolRepository(db)

async def get_school_service(
    repo: SchoolRepository = Depends(get_school_repository)
) -> SchoolService:
    """
    FastAPI dependency that injects a SchoolRepository and returns a SchoolService.
    """
    return SchoolService(repo)
