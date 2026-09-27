import uuid
from typing import List, Optional
from datetime import datetime, timezone
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.syllabus_coverage import SyllabusCoverageProgress
from app.models.syllabus import Syllabus

class SyllabusCoverageRepository:
    """
    Repository layer for section and teacher-level syllabus teaching progress tracking.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_section_and_syllabus(
        self,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        section_id: uuid.UUID,
        syllabus_id: uuid.UUID
    ) -> Optional[SyllabusCoverageProgress]:
        stmt = select(SyllabusCoverageProgress).where(
            SyllabusCoverageProgress.school_id == school_id,
            SyllabusCoverageProgress.academic_year_id == academic_year_id,
            SyllabusCoverageProgress.section_id == section_id,
            SyllabusCoverageProgress.syllabus_id == syllabus_id,
            SyllabusCoverageProgress.deleted_at.is_(None)
        )
        res = await self.db.execute(stmt)
        return res.scalar_one_or_none()

    async def get_section_progress(
        self,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        section_id: uuid.UUID,
        subject_id: Optional[uuid.UUID] = None
    ) -> List[SyllabusCoverageProgress]:
        filters = [
            SyllabusCoverageProgress.school_id == school_id,
            SyllabusCoverageProgress.academic_year_id == academic_year_id,
            SyllabusCoverageProgress.section_id == section_id,
            SyllabusCoverageProgress.deleted_at.is_(None)
        ]
        if subject_id:
            filters.append(SyllabusCoverageProgress.subject_id == subject_id)

        stmt = select(SyllabusCoverageProgress).where(and_(*filters))
        res = await self.db.execute(stmt)
        return list(res.scalars().all())

    async def get_teacher_progress(
        self,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        teacher_id: uuid.UUID
    ) -> List[SyllabusCoverageProgress]:
        stmt = select(SyllabusCoverageProgress).where(
            SyllabusCoverageProgress.school_id == school_id,
            SyllabusCoverageProgress.academic_year_id == academic_year_id,
            SyllabusCoverageProgress.teacher_id == teacher_id,
            SyllabusCoverageProgress.deleted_at.is_(None)
        )
        res = await self.db.execute(stmt)
        return list(res.scalars().all())

    async def upsert_progress(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        class_id: uuid.UUID,
        section_id: uuid.UUID,
        subject_id: uuid.UUID,
        syllabus_id: uuid.UUID,
        status: str,
        completion_percentage: float = 0.0,
        teacher_id: Optional[uuid.UUID] = None,
        started_at: Optional[datetime] = None,
        completed_at: Optional[datetime] = None,
        remarks: Optional[str] = None,
        user_id: Optional[uuid.UUID] = None
    ) -> SyllabusCoverageProgress:
        existing = await self.get_by_section_and_syllabus(
            school_id=school_id,
            academic_year_id=academic_year_id,
            section_id=section_id,
            syllabus_id=syllabus_id
        )
        now = datetime.now(timezone.utc)
        if existing:
            existing.status = status
            existing.completion_percentage = completion_percentage
            if teacher_id:
                existing.teacher_id = teacher_id
            if started_at:
                existing.started_at = started_at
            elif status in ("IN_PROGRESS", "COMPLETED") and not existing.started_at:
                existing.started_at = now

            if completed_at:
                existing.completed_at = completed_at
            elif status == "COMPLETED" and not existing.completed_at:
                existing.completed_at = now
            elif status in ("PLANNED", "IN_PROGRESS", "REOPENED"):
                existing.completed_at = None

            if remarks is not None:
                existing.remarks = remarks

            existing.updated_at = now
            existing.updated_by = user_id
            self.db.add(existing)
            return existing

        new_obj = SyllabusCoverageProgress(
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=academic_year_id,
            class_id=class_id,
            section_id=section_id,
            subject_id=subject_id,
            syllabus_id=syllabus_id,
            teacher_id=teacher_id,
            status=status,
            completion_percentage=completion_percentage,
            started_at=started_at or (now if status in ("IN_PROGRESS", "COMPLETED") else None),
            completed_at=completed_at or (now if status == "COMPLETED" else None),
            remarks=remarks,
            created_by=user_id,
            updated_by=user_id
        )
        self.db.add(new_obj)
        return new_obj
