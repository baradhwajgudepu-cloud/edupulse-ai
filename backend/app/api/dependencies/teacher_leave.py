from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.repositories.teacher_leave import TeacherLeaveRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.school import SchoolRepository
from app.services.teacher_leave import TeacherLeaveService
from app.api.dependencies.teacher import get_teacher_repository
from app.api.dependencies.school import get_school_repository
from app.api.dependencies.notification import get_notification_service

def get_teacher_leave_repository(db: AsyncSession = Depends(get_db)) -> TeacherLeaveRepository:
    """
    Dependency provider for TeacherLeaveRepository.
    """
    return TeacherLeaveRepository(db)

def get_teacher_leave_service(
    db: AsyncSession = Depends(get_db),
    leave_repo: TeacherLeaveRepository = Depends(get_teacher_leave_repository),
    teacher_repo: TeacherRepository = Depends(get_teacher_repository),
    school_repo: SchoolRepository = Depends(get_school_repository),
    notification_service = Depends(get_notification_service)
) -> TeacherLeaveService:
    """
    Dependency provider for TeacherLeaveService.
    """
    return TeacherLeaveService(
        leave_repo=leave_repo,
        teacher_repo=teacher_repo,
        school_repo=school_repo,
        notification_service=notification_service
    )
