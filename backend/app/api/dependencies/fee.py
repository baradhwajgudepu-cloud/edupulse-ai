from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.repositories.fee import FeeRepository
from app.services.fee import FeeService
from app.api.dependencies.notification import get_notification_service
from app.services.notification import NotificationService

def get_fee_repository(db: AsyncSession = Depends(get_db)) -> FeeRepository:
    return FeeRepository(db)

def get_fee_service(
    fee_repo: FeeRepository = Depends(get_fee_repository),
    notification_service: NotificationService = Depends(get_notification_service)
) -> FeeService:
    return FeeService(fee_repo, notification_service)
