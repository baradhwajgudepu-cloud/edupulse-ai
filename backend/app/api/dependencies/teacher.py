from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.repositories.teacher import TeacherRepository
from app.repositories.school import SchoolRepository
from app.services.teacher import TeacherService

def get_teacher_repository(db: AsyncSession = Depends(get_db)) -> TeacherRepository:
    """
    Dependency provider for TeacherRepository.
    """
    return TeacherRepository(db)

def get_teacher_service(
    db: AsyncSession = Depends(get_db),
    teacher_repo: TeacherRepository = Depends(get_teacher_repository)
) -> TeacherService:
    """
    Dependency provider for TeacherService.
    Injects TeacherRepository and SchoolRepository.
    """
    school_repo = SchoolRepository(db)
    return TeacherService(
        teacher_repo=teacher_repo,
        school_repo=school_repo
    )
