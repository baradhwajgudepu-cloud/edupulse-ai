from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.repositories.notification import NotificationRepository
from app.services.notification import NotificationService

def get_notification_repository(db: AsyncSession = Depends(get_db)) -> NotificationRepository:
    """
    Dependency provider returning the NotificationRepository.
    """
    return NotificationRepository(db)


def get_notification_service(
    notification_repo: NotificationRepository = Depends(get_notification_repository)
) -> NotificationService:
    """
    Dependency provider returning the NotificationService.
    """
    return NotificationService(notification_repo)
