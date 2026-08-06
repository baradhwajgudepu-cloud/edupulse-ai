from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.repositories.report_card import ReportCardRepository
from app.repositories.student import StudentRepository
from app.repositories.school import SchoolRepository
from app.services.report_card import ReportCardService

from app.api.dependencies.notification import get_notification_service
from app.services.notification import NotificationService

def get_report_card_repository(db: AsyncSession = Depends(get_db)) -> ReportCardRepository:
    return ReportCardRepository(db)

def get_report_card_service(
    db: AsyncSession = Depends(get_db),
    report_repo: ReportCardRepository = Depends(get_report_card_repository),
    notification_service: NotificationService = Depends(get_notification_service)
) -> ReportCardService:
    student_repo = StudentRepository(db)
    school_repo = SchoolRepository(db)
    
    return ReportCardService(
        report_repo=report_repo,
        student_repo=student_repo,
        school_repo=school_repo,
        notification_service=notification_service
    )
