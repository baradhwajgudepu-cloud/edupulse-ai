from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.repositories.marks import MarksRepository
from app.repositories.examination import ExamScheduleRepository, ExaminationRepository
from app.repositories.student import StudentRepository
from app.repositories.teacher_subject_assignment import TeacherSubjectAssignmentRepository
from app.repositories.school import SchoolRepository
from app.services.marks import MarksService

from app.api.dependencies.notification import get_notification_service
from app.services.notification import NotificationService

def get_marks_repository(db: AsyncSession = Depends(get_db)) -> MarksRepository:
    return MarksRepository(db)

def get_marks_service(
    db: AsyncSession = Depends(get_db),
    marks_repo: MarksRepository = Depends(get_marks_repository),
    notification_service: NotificationService = Depends(get_notification_service)
) -> MarksService:
    schedule_repo = ExamScheduleRepository(db)
    exam_repo = ExaminationRepository(db)
    student_repo = StudentRepository(db)
    tsa_repo = TeacherSubjectAssignmentRepository(db)
    school_repo = SchoolRepository(db)
    
    return MarksService(
        marks_repo=marks_repo,
        schedule_repo=schedule_repo,
        exam_repo=exam_repo,
        student_repo=student_repo,
        tsa_repo=tsa_repo,
        school_repo=school_repo,
        notification_service=notification_service
    )
