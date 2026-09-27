import uuid
from typing import List, Optional, Dict, Any
from datetime import datetime, timezone
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.timetable_recommendation import TimetableRecommendation

class TimetableRecommendationRepository:
    """
    Repository for AI Timetable recommendation entities.
    Tracks lifecycle (SUGGESTED, ACCEPTED, REJECTED, SUPERSEDED) and audit records.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(
        self,
        recommendation_id: uuid.UUID,
        school_id: Optional[uuid.UUID] = None,
        tenant_id: Optional[uuid.UUID] = None
    ) -> Optional[TimetableRecommendation]:
        filters = [
            TimetableRecommendation.id == recommendation_id,
            TimetableRecommendation.deleted_at.is_(None)
        ]
        if school_id:
            filters.append(TimetableRecommendation.school_id == school_id)
        if tenant_id:
            filters.append(TimetableRecommendation.tenant_id == tenant_id)
        stmt = select(TimetableRecommendation).where(and_(*filters))
        res = await self.db.execute(stmt)
        return res.scalar_one_or_none()

    async def get_latest_for_section(
        self,
        school_id: uuid.UUID,
        section_id: uuid.UUID,
        tenant_id: uuid.UUID,
        status: Optional[str] = None
    ) -> Optional[TimetableRecommendation]:
        filters = [
            TimetableRecommendation.school_id == school_id,
            TimetableRecommendation.section_id == section_id,
            TimetableRecommendation.tenant_id == tenant_id,
            TimetableRecommendation.deleted_at.is_(None)
        ]
        if status:
            filters.append(TimetableRecommendation.status == status)

        stmt = select(TimetableRecommendation).where(and_(*filters)).order_by(
            TimetableRecommendation.created_at.desc()
        ).limit(1)
        res = await self.db.execute(stmt)
        return res.scalar_one_or_none()

    async def get_all_for_school(
        self,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        tenant_id: uuid.UUID,
        status: Optional[str] = None
    ) -> List[TimetableRecommendation]:
        filters = [
            TimetableRecommendation.school_id == school_id,
            TimetableRecommendation.academic_year_id == academic_year_id,
            TimetableRecommendation.tenant_id == tenant_id,
            TimetableRecommendation.deleted_at.is_(None)
        ]
        if status:
            filters.append(TimetableRecommendation.status == status)

        stmt = select(TimetableRecommendation).where(and_(*filters)).order_by(
            TimetableRecommendation.created_at.desc()
        )
        res = await self.db.execute(stmt)
        return list(res.scalars().all())

    async def create(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        class_id: uuid.UUID,
        section_id: uuid.UUID,
        suggested_slots: dict,
        rationale: dict,
        risk_factors: dict,
        audit_trail: dict,
        recommendation_type: str = "INITIAL_GENERATION",
        created_by: Optional[uuid.UUID] = None
    ) -> TimetableRecommendation:
        # Supersede any previous suggested recommendations for this section
        prev_stmt = select(TimetableRecommendation).where(
            TimetableRecommendation.section_id == section_id,
            TimetableRecommendation.status == "SUGGESTED",
            TimetableRecommendation.deleted_at.is_(None)
        )
        res = await self.db.execute(prev_stmt)
        prevs = res.scalars().all()
        now = datetime.now(timezone.utc)
        for p in prevs:
            p.status = "SUPERSEDED"
            p.updated_at = now
            self.db.add(p)

        rec = TimetableRecommendation(
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=academic_year_id,
            class_id=class_id,
            section_id=section_id,
            recommendation_type=recommendation_type,
            status="SUGGESTED",
            suggested_slots=suggested_slots,
            rationale=rationale,
            risk_factors=risk_factors,
            audit_trail=audit_trail,
            created_by=created_by,
            updated_by=created_by
        )
        self.db.add(rec)
        return rec
