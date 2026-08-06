import uuid
from typing import List, Optional
from sqlalchemy import select, and_
from sqlalchemy.orm import joinedload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.report_card import ReportCardPublication, ReportCardStatus

class ReportCardRepository:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(
        self, id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[ReportCardPublication]:
        stmt = select(ReportCardPublication).where(
            ReportCardPublication.id == id,
            ReportCardPublication.school_id == school_id,
            ReportCardPublication.tenant_id == tenant_id,
            ReportCardPublication.deleted_at.is_(None)
        ).options(
            joinedload(ReportCardPublication.student),
            joinedload(ReportCardPublication.academic_year)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_student_and_year(
        self, student_id: uuid.UUID, academic_year_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[ReportCardPublication]:
        stmt = select(ReportCardPublication).where(
            ReportCardPublication.student_id == student_id,
            ReportCardPublication.academic_year_id == academic_year_id,
            ReportCardPublication.tenant_id == tenant_id,
            ReportCardPublication.deleted_at.is_(None)
        ).options(
            joinedload(ReportCardPublication.student),
            joinedload(ReportCardPublication.academic_year)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_verification_uuid(
        self, verification_uuid: uuid.UUID
    ) -> Optional[ReportCardPublication]:
        stmt = select(ReportCardPublication).where(
            ReportCardPublication.verification_uuid == verification_uuid,
            ReportCardPublication.deleted_at.is_(None)
        ).options(
            joinedload(ReportCardPublication.student),
            joinedload(ReportCardPublication.academic_year),
            joinedload(ReportCardPublication.school)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_parent_publication(
        self, student_id: uuid.UUID, academic_year_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[ReportCardPublication]:
        stmt = select(ReportCardPublication).where(
            ReportCardPublication.student_id == student_id,
            ReportCardPublication.academic_year_id == academic_year_id,
            ReportCardPublication.tenant_id == tenant_id,
            ReportCardPublication.status == ReportCardStatus.PUBLISHED,
            ReportCardPublication.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_multi(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        academic_year_id: Optional[uuid.UUID] = None,
        class_id: Optional[uuid.UUID] = None,
        section_id: Optional[uuid.UUID] = None,
        status: Optional[ReportCardStatus] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[ReportCardPublication]:
        filters = [
            ReportCardPublication.school_id == school_id,
            ReportCardPublication.tenant_id == tenant_id,
            ReportCardPublication.deleted_at.is_(None)
        ]
        if academic_year_id:
            filters.append(ReportCardPublication.academic_year_id == academic_year_id)
        if status:
            filters.append(ReportCardPublication.status == status)

        stmt = select(ReportCardPublication).where(and_(*filters)).options(
            joinedload(ReportCardPublication.student),
            joinedload(ReportCardPublication.academic_year)
        )

        if class_id or section_id:
            # Join Student to filter by class/section
            from app.models.student import Student
            stmt = stmt.join(ReportCardPublication.student)
            if class_id:
                stmt = stmt.where(Student.class_id == class_id)
            if section_id:
                stmt = stmt.where(Student.section_id == section_id)

        stmt = stmt.offset(skip).limit(limit)
        result = await self.db.execute(stmt)
        return list(result.unique().scalars().all())
