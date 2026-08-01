from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.repositories.class_entity import ClassRepository
from app.repositories.academic_year import AcademicYearRepository
from app.services.class_entity import ClassService

def get_class_repository(db: AsyncSession = Depends(get_db)) -> ClassRepository:
    """
    Dependency provider for ClassRepository.
    """
    return ClassRepository(db)

def get_class_service(
    db: AsyncSession = Depends(get_db),
    class_repo: ClassRepository = Depends(get_class_repository)
) -> ClassService:
    """
    Dependency provider for ClassService.
    Injects ClassRepository and AcademicYearRepository.
    """
    ay_repo = AcademicYearRepository(db)
    return ClassService(class_repo=class_repo, ay_repo=ay_repo)
