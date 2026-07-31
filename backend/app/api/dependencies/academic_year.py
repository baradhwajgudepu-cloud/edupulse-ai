from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import get_db
from app.repositories.academic_year import AcademicYearRepository
from app.services.academic_year import AcademicYearService

async def get_academic_year_repository(db: AsyncSession = Depends(get_db)) -> AcademicYearRepository:
    """
    FastAPI dependency that injects an AsyncSession and returns an AcademicYearRepository.
    """
    return AcademicYearRepository(db)

async def get_academic_year_service(
    repo: AcademicYearRepository = Depends(get_academic_year_repository)
) -> AcademicYearService:
    """
    FastAPI dependency that injects an AcademicYearRepository and returns an AcademicYearService.
    """
    return AcademicYearService(repo)
