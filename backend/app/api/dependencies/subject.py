from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.repositories.subject import SubjectRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.services.subject import SubjectService

def get_subject_repository(db: AsyncSession = Depends(get_db)) -> SubjectRepository:
    """
    Dependency provider for SubjectRepository.
    """
    return SubjectRepository(db)

def get_subject_service(
    db: AsyncSession = Depends(get_db),
    subject_repo: SubjectRepository = Depends(get_subject_repository)
) -> SubjectService:
    """
    Dependency provider for SubjectService.
    Injects SubjectRepository, SchoolRepository, and AcademicYearRepository.
    """
    school_repo = SchoolRepository(db)
    academic_year_repo = AcademicYearRepository(db)
    return SubjectService(
        subject_repo=subject_repo,
        school_repo=school_repo,
        academic_year_repo=academic_year_repo
    )
