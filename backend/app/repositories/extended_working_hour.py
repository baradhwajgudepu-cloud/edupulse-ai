import uuid
from typing import Optional
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.extended_working_hour import ExtendedWorkingHour

class ExtendedWorkingHourRepository:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_school_and_ay(
        self,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        tenant_id: uuid.UUID
    ) -> Optional[ExtendedWorkingHour]:
        stmt = select(ExtendedWorkingHour).where(
            ExtendedWorkingHour.school_id == school_id,
            ExtendedWorkingHour.academic_year_id == academic_year_id,
            ExtendedWorkingHour.tenant_id == tenant_id,
            ExtendedWorkingHour.deleted_at.is_(None)
        )
        res = await self.db.execute(stmt)
        return res.scalars().first()

    async def create(self, db_obj: ExtendedWorkingHour) -> ExtendedWorkingHour:
        self.db.add(db_obj)
        await self.db.commit()
        await self.db.refresh(db_obj)
        return db_obj

    async def update(self, db_obj: ExtendedWorkingHour) -> ExtendedWorkingHour:
        await self.db.commit()
        await self.db.refresh(db_obj)
        return db_obj
