from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.repositories.section import SectionRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.class_entity import ClassRepository
from app.services.section import SectionService

def get_section_repository(db: AsyncSession = Depends(get_db)) -> SectionRepository:
    """
    Dependency provider for SectionRepository.
    """
    return SectionRepository(db)

def get_section_service(
    db: AsyncSession = Depends(get_db),
    section_repo: SectionRepository = Depends(get_section_repository)
) -> SectionService:
    """
    Dependency provider for SectionService.
    Injects SectionRepository, AcademicYearRepository, and ClassRepository.
    """
    ay_repo = AcademicYearRepository(db)
    class_repo = ClassRepository(db)
    return SectionService(
        section_repo=section_repo,
        ay_repo=ay_repo,
        class_repo=class_repo
    )
