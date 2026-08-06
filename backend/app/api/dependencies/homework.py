from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.repositories.homework import HomeworkRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.subject import SubjectRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.section import SectionRepository
from app.repositories.timetable import TimetableRepository
from app.repositories.teacher_subject_assignment import TeacherSubjectAssignmentRepository
from app.services.homework import HomeworkService

from app.api.dependencies.notification import get_notification_service
from app.services.notification import NotificationService

def get_homework_repository(db: AsyncSession = Depends(get_db)) -> HomeworkRepository:
    return HomeworkRepository(db)

def get_homework_service(
    db: AsyncSession = Depends(get_db),
    homework_repo: HomeworkRepository = Depends(get_homework_repository),
    notification_service: NotificationService = Depends(get_notification_service)
) -> HomeworkService:
    teacher_repo = TeacherRepository(db)
    subject_repo = SubjectRepository(db)
    class_repo = ClassRepository(db)
    section_repo = SectionRepository(db)
    timetable_repo = TimetableRepository(db)
    tsa_repo = TeacherSubjectAssignmentRepository(db)
    return HomeworkService(
        homework_repo=homework_repo,
        teacher_repo=teacher_repo,
        subject_repo=subject_repo,
        class_repo=class_repo,
        section_repo=section_repo,
        timetable_repo=timetable_repo,
        tsa_repo=tsa_repo,
        notification_service=notification_service
    )
