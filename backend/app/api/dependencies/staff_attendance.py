from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.repositories.staff_attendance import StaffAttendanceRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.school import SchoolRepository
from app.services.staff_attendance import StaffAttendanceService
from app.api.dependencies.teacher import get_teacher_repository
from app.api.dependencies.school import get_school_repository

def get_staff_attendance_repository(db: AsyncSession = Depends(get_db)) -> StaffAttendanceRepository:
    """
    Dependency provider for StaffAttendanceRepository.
    """
    return StaffAttendanceRepository(db)

def get_staff_attendance_service(
    db: AsyncSession = Depends(get_db),
    staff_attendance_repo: StaffAttendanceRepository = Depends(get_staff_attendance_repository),
    teacher_repo: TeacherRepository = Depends(get_teacher_repository),
    school_repo: SchoolRepository = Depends(get_school_repository)
) -> StaffAttendanceService:
    """
    Dependency provider for StaffAttendanceService.
    Injects all child repositories.
    """
    return StaffAttendanceService(
        staff_attendance_repo=staff_attendance_repo,
        teacher_repo=teacher_repo,
        school_repo=school_repo
    )
