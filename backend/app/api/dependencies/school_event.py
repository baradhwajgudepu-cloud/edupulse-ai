from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.repositories.school_event import SchoolEventRepository
from app.services.school_event import SchoolEventService

def get_school_event_repository(db: AsyncSession = Depends(get_db)) -> SchoolEventRepository:
    return SchoolEventRepository(db)

def get_school_event_service(
    db: AsyncSession = Depends(get_db),
    event_repo: SchoolEventRepository = Depends(get_school_event_repository)
) -> SchoolEventService:
    return SchoolEventService(event_repo=event_repo)
