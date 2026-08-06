from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.repositories.guardian import GuardianRepository, StudentGuardianRepository
from app.repositories.student import StudentRepository
from app.repositories.school import SchoolRepository
from app.services.guardian import GuardianService

def get_guardian_repository(db: AsyncSession = Depends(get_db)) -> GuardianRepository:
    """
    Dependency provider for GuardianRepository.
    """
    return GuardianRepository(db)

def get_student_guardian_repository(db: AsyncSession = Depends(get_db)) -> StudentGuardianRepository:
    """
    Dependency provider for StudentGuardianRepository.
    """
    return StudentGuardianRepository(db)

def get_guardian_service(
    db: AsyncSession = Depends(get_db),
    guardian_repo: GuardianRepository = Depends(get_guardian_repository),
    student_guardian_repo: StudentGuardianRepository = Depends(get_student_guardian_repository)
) -> GuardianService:
    """
    Dependency provider for GuardianService.
    Injects GuardianRepository, StudentGuardianRepository, StudentRepository, and SchoolRepository.
    """
    student_repo = StudentRepository(db)
    school_repo = SchoolRepository(db)
    return GuardianService(
        guardian_repo=guardian_repo,
        student_guardian_repo=student_guardian_repo,
        student_repo=student_repo,
        school_repo=school_repo
    )
