from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.repositories.announcement import AnnouncementRepository
from app.services.announcement import AnnouncementService

def get_announcement_repository(db: AsyncSession = Depends(get_db)) -> AnnouncementRepository:
    return AnnouncementRepository(db)

def get_announcement_service(
    db: AsyncSession = Depends(get_db),
    announcement_repo: AnnouncementRepository = Depends(get_announcement_repository)
) -> AnnouncementService:
    return AnnouncementService(announcement_repo=announcement_repo)
