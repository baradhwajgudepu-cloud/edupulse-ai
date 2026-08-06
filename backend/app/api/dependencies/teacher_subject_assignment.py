from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.repositories.teacher_subject_assignment import TeacherSubjectAssignmentRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.subject import SubjectRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.section import SectionRepository
from app.repositories.academic_year import AcademicYearRepository
from app.services.teacher_subject_assignment import TeacherSubjectAssignmentService

def get_assignment_repository(db: AsyncSession = Depends(get_db)) -> TeacherSubjectAssignmentRepository:
    """
    Dependency provider for TeacherSubjectAssignmentRepository.
    """
    return TeacherSubjectAssignmentRepository(db)

def get_assignment_service(
    db: AsyncSession = Depends(get_db),
    assignment_repo: TeacherSubjectAssignmentRepository = Depends(get_assignment_repository)
) -> TeacherSubjectAssignmentService:
    """
    Dependency provider for TeacherSubjectAssignmentService.
    Injects all child repositories.
    """
    teacher_repo = TeacherRepository(db)
    subject_repo = SubjectRepository(db)
    class_repo = ClassRepository(db)
    section_repo = SectionRepository(db)
    academic_year_repo = AcademicYearRepository(db)
    return TeacherSubjectAssignmentService(
        assignment_repo=assignment_repo,
        teacher_repo=teacher_repo,
        subject_repo=subject_repo,
        class_repo=class_repo,
        section_repo=section_repo,
        academic_year_repo=academic_year_repo
    )
