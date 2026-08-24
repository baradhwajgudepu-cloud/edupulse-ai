from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.repositories.syllabus import SyllabusRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.subject import SubjectRepository
from app.services.syllabus import SyllabusService

def get_syllabus_repository(db: AsyncSession = Depends(get_db)) -> SyllabusRepository:
    """
    Dependency provider for SyllabusRepository.
    """
    return SyllabusRepository(db)

def get_syllabus_service(
    db: AsyncSession = Depends(get_db),
    syllabus_repo: SyllabusRepository = Depends(get_syllabus_repository)
) -> SyllabusService:
    """
    Dependency provider for SyllabusService.
    Injects all child repositories.
    """
    school_repo = SchoolRepository(db)
    academic_year_repo = AcademicYearRepository(db)
    class_repo = ClassRepository(db)
    subject_repo = SubjectRepository(db)
    return SyllabusService(
        syllabus_repo=syllabus_repo,
        school_repo=school_repo,
        academic_year_repo=academic_year_repo,
        class_repo=class_repo,
        subject_repo=subject_repo
    )
