from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.repositories.timetable import TimetableRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.subject import SubjectRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.section import SectionRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.teacher_subject_assignment import TeacherSubjectAssignmentRepository
from app.services.timetable import TimetableService

def get_timetable_repository(db: AsyncSession = Depends(get_db)) -> TimetableRepository:
    """
    Dependency provider for TimetableRepository.
    """
    return TimetableRepository(db)

def get_timetable_service(
    db: AsyncSession = Depends(get_db),
    timetable_repo: TimetableRepository = Depends(get_timetable_repository)
) -> TimetableService:
    """
    Dependency provider for TimetableService.
    Injects all child repositories.
    """
    teacher_repo = TeacherRepository(db)
    subject_repo = SubjectRepository(db)
    class_repo = ClassRepository(db)
    section_repo = SectionRepository(db)
    academic_year_repo = AcademicYearRepository(db)
    assignment_repo = TeacherSubjectAssignmentRepository(db)
    return TimetableService(
        timetable_repo=timetable_repo,
        teacher_repo=teacher_repo,
        subject_repo=subject_repo,
        class_repo=class_repo,
        section_repo=section_repo,
        academic_year_repo=academic_year_repo,
        assignment_repo=assignment_repo
    )
