from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.services.import_job import ImportJobService

def get_import_job_service(db: AsyncSession = Depends(get_db)) -> ImportJobService:
    return ImportJobService(db)
