from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.repositories.attendance import AttendanceRepository
from app.repositories.student import StudentRepository
from app.repositories.timetable import TimetableRepository
from app.repositories.academic_year import AcademicYearRepository
from app.services.attendance import AttendanceService

from app.api.dependencies.notification import get_notification_service
from app.services.notification import NotificationService

def get_attendance_repository(db: AsyncSession = Depends(get_db)) -> AttendanceRepository:
    """
    Dependency provider for AttendanceRepository.
    """
    return AttendanceRepository(db)

def get_attendance_service(
    db: AsyncSession = Depends(get_db),
    attendance_repo: AttendanceRepository = Depends(get_attendance_repository),
    notification_service: NotificationService = Depends(get_notification_service)
) -> AttendanceService:
    """
    Dependency provider for AttendanceService.
    Injects all child repositories and the notification service.
    """
    student_repo = StudentRepository(db)
    timetable_repo = TimetableRepository(db)
    academic_year_repo = AcademicYearRepository(db)
    return AttendanceService(
        attendance_repo=attendance_repo,
        student_repo=student_repo,
        timetable_repo=timetable_repo,
        academic_year_repo=academic_year_repo,
        notification_service=notification_service
    )
