from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.repositories.leave_request import LeaveRequestRepository
from app.repositories.teacher import TeacherRepository
from app.services.leave_request import LeaveRequestService
from app.api.dependencies.teacher import get_teacher_repository

def get_leave_repository(db: AsyncSession = Depends(get_db)) -> LeaveRequestRepository:
    """
    Dependency provider for LeaveRequestRepository.
    """
    return LeaveRequestRepository(db)

def get_leave_service(
    leave_repo: LeaveRequestRepository = Depends(get_leave_repository),
    teacher_repo: TeacherRepository = Depends(get_teacher_repository)
) -> LeaveRequestService:
    """
    Dependency provider for LeaveRequestService.
    """
    return LeaveRequestService(
        leave_repo=leave_repo,
        teacher_repo=teacher_repo
    )
