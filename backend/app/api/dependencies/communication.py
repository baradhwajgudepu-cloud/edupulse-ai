from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.repositories.communication import CommunicationRepository
from app.services.communication import CommunicationService
from app.api.dependencies.notification import get_notification_service
from app.api.dependencies.ai import get_ai_service
from app.services.notification import NotificationService
from app.services.ai.service import AIService

def get_communication_repository(db: AsyncSession = Depends(get_db)) -> CommunicationRepository:
    """
    Dependency provider returning the CommunicationRepository.
    """
    return CommunicationRepository(db)


def get_communication_service(
    repo: CommunicationRepository = Depends(get_communication_repository),
    notification_service: NotificationService = Depends(get_notification_service),
    ai_service: AIService = Depends(get_ai_service)
) -> CommunicationService:
    """
    Dependency provider returning the CommunicationService.
    """
    return CommunicationService(
        repo=repo,
        notification_service=notification_service,
        ai_service=ai_service
    )
