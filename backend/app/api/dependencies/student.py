from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.repositories.student import StudentRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.section import SectionRepository
from app.services.student import StudentService

def get_student_repository(db: AsyncSession = Depends(get_db)) -> StudentRepository:
    """
    Dependency provider for StudentRepository.
    """
    return StudentRepository(db)

def get_student_service(
    db: AsyncSession = Depends(get_db),
    student_repo: StudentRepository = Depends(get_student_repository)
) -> StudentService:
    """
    Dependency provider for StudentService.
    Injects StudentRepository, AcademicYearRepository, ClassRepository, and SectionRepository.
    """
    ay_repo = AcademicYearRepository(db)
    class_repo = ClassRepository(db)
    section_repo = SectionRepository(db)
    return StudentService(
        student_repo=student_repo,
        ay_repo=ay_repo,
        class_repo=class_repo,
        section_repo=section_repo
    )
