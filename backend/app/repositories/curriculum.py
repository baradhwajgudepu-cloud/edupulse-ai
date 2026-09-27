import uuid
from typing import List, Optional
from datetime import datetime, timezone
from sqlalchemy import select, and_
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.curriculum import CurriculumMaster, CurriculumMasterItem
from app.models.school import SchoolBoard

class CurriculumRepository:
    """
    Repository for querying and populating the verified board curriculum master catalog.
    Master entries are read-only to individual schools to prevent global catalog mutation.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_templates(
        self,
        board: Optional[str] = None,
        state: Optional[str] = None,
        class_level: Optional[int] = None,
        subject_code: Optional[str] = None,
        academic_year_code: Optional[str] = None
    ) -> List[CurriculumMaster]:
        filters = [CurriculumMaster.is_active.is_(True)]
        if board:
            board_val = board.upper()
            try:
                sb = SchoolBoard(board_val)
                filters.append(CurriculumMaster.board == sb)
            except Exception:
                return []
        if state:
            filters.append(CurriculumMaster.state.ilike(f"%{state}%"))
        if class_level is not None:
            filters.append(CurriculumMaster.class_level == class_level)
        if subject_code:
            filters.append(CurriculumMaster.subject_code.ilike(f"%{subject_code}%"))
        if academic_year_code:
            filters.append(CurriculumMaster.academic_year_code == academic_year_code)

        stmt = select(CurriculumMaster).options(
            selectinload(CurriculumMaster.items)
        ).where(and_(*filters)).order_by(
            CurriculumMaster.class_level,
            CurriculumMaster.subject_name
        )
        res = await self.db.execute(stmt)
        return list(res.scalars().all())

    async def get_by_id(self, master_id: uuid.UUID) -> Optional[CurriculumMaster]:
        stmt = select(CurriculumMaster).options(
            selectinload(CurriculumMaster.items)
        ).where(CurriculumMaster.id == master_id)
        res = await self.db.execute(stmt)
        return res.scalar_one_or_none()

    async def create_master(self, master: CurriculumMaster) -> CurriculumMaster:
        self.db.add(master)
        await self.db.flush()
        return master

    async def create_item(self, item: CurriculumMasterItem) -> CurriculumMasterItem:
        self.db.add(item)
        await self.db.flush()
        return item
