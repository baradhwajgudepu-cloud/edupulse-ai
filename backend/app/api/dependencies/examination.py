from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.repositories.examination import ExamTemplateRepository, ExaminationRepository, ExamScheduleRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.teacher_subject_assignment import TeacherSubjectAssignmentRepository
from app.services.examination import ExaminationService

def get_template_repository(db: AsyncSession = Depends(get_db)) -> ExamTemplateRepository:
    return ExamTemplateRepository(db)

def get_examination_repository(db: AsyncSession = Depends(get_db)) -> ExaminationRepository:
    return ExaminationRepository(db)

def get_schedule_repository(db: AsyncSession = Depends(get_db)) -> ExamScheduleRepository:
    return ExamScheduleRepository(db)

def get_examination_service(
    db: AsyncSession = Depends(get_db),
    template_repo: ExamTemplateRepository = Depends(get_template_repository),
    exam_repo: ExaminationRepository = Depends(get_examination_repository),
    schedule_repo: ExamScheduleRepository = Depends(get_schedule_repository)
) -> ExaminationService:
    school_repo = SchoolRepository(db)
    academic_year_repo = AcademicYearRepository(db)
    tsa_repo = TeacherSubjectAssignmentRepository(db)
    
    return ExaminationService(
        template_repo=template_repo,
        exam_repo=exam_repo,
        schedule_repo=schedule_repo,
        school_repo=school_repo,
        academic_year_repo=academic_year_repo,
        tsa_repo=tsa_repo
    )
