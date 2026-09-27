import uuid
from typing import List, Optional, Dict, Any
from datetime import datetime, timezone
from sqlalchemy import select, and_, delete
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.syllabus_recovery import SyllabusRecoveryPlan, RecoveryPlanItem


class SyllabusRecoveryRepository:
    """
    Repository for Syllabus Recovery Plans and candidate recovery periods.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def create_plan(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        class_id: uuid.UUID,
        section_id: uuid.UUID,
        subject_id: uuid.UUID,
        reason: str,
        current_completion: float,
        target_completion_date: Optional[datetime.date] = None,
        forecast_completion_date: Optional[datetime.date] = None,
        new_forecast_date: Optional[datetime.date] = None,
        expected_recovery_periods: float = 0.0,
        teacher_id: Optional[uuid.UUID] = None,
        primary_teacher_id: Optional[uuid.UUID] = None,
        support_teacher_id: Optional[uuid.UUID] = None,
        recovery_type: str = "CROSS_TEACHER_RECOVERY",
        delay_days: int = 0,
        duration_weeks: int = 2,
        recommended_periods_per_week: int = 1,
        projected_improvement_days: int = 0,
        parent_notes: Optional[str] = None,
        candidate_evaluations: Optional[List[Dict[str, Any]]] = None,
        created_by: Optional[uuid.UUID] = None,
        status: str = "SUGGESTED",
        audit_trail: Optional[Dict[str, Any]] = None,
        items_data: Optional[List[Dict[str, Any]]] = None
    ) -> SyllabusRecoveryPlan:
        plan = SyllabusRecoveryPlan(
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=academic_year_id,
            class_id=class_id,
            section_id=section_id,
            subject_id=subject_id,
            teacher_id=teacher_id or primary_teacher_id,
            primary_teacher_id=primary_teacher_id or teacher_id,
            support_teacher_id=support_teacher_id,
            recovery_type=recovery_type,
            reason=reason,
            current_completion=current_completion,
            target_completion_date=target_completion_date,
            forecast_completion_date=forecast_completion_date,
            new_forecast_date=new_forecast_date,
            delay_days=delay_days,
            duration_weeks=duration_weeks,
            recommended_periods_per_week=recommended_periods_per_week,
            expected_recovery_periods=expected_recovery_periods,
            projected_improvement_days=projected_improvement_days,
            parent_notes=parent_notes,
            candidate_evaluations=candidate_evaluations or [],
            status=status,
            created_by=created_by,
            audit_trail=audit_trail or {
                "events": [{
                    "action": "CREATED",
                    "by": str(created_by) if created_by else "AI_ENGINE",
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "status": status,
                    "recovery_type": recovery_type
                }]
            }
        )
        self.db.add(plan)
        await self.db.flush()

        if items_data:
            for item in items_data:
                rec_item = RecoveryPlanItem(
                    recovery_plan_id=plan.id,
                    tenant_id=tenant_id,
                    date=item["date"],
                    period_number=item["period_number"],
                    phase=item.get("phase", "PHASE_1_CATCHUP"),
                    syllabus_item_id=item.get("syllabus_item_id"),
                    topic_name=item["topic_name"],
                    duration_minutes=item.get("duration_minutes", 45),
                    teacher_id=item.get("teacher_id") or support_teacher_id or teacher_id,
                    class_id=class_id,
                    section_id=section_id,
                    room_id=item.get("room_id"),
                    timetable_id=item.get("timetable_id"),
                    status=item.get("status", "SUGGESTED"),
                    is_approved=item.get("is_approved", False),
                    conflict_status=item.get("conflict_status", "NO_CONFLICT"),
                    conflict_message=item.get("conflict_message")
                )
                self.db.add(rec_item)
            await self.db.flush()

        # Re-fetch with loaded items
        return await self.get_plan_by_id(plan.id, school_id)

    async def get_plan_by_id(
        self,
        plan_id: uuid.UUID,
        school_id: Optional[uuid.UUID] = None
    ) -> Optional[SyllabusRecoveryPlan]:
        filters = [SyllabusRecoveryPlan.id == plan_id, SyllabusRecoveryPlan.deleted_at.is_(None)]
        if school_id:
            filters.append(SyllabusRecoveryPlan.school_id == school_id)

        stmt = select(SyllabusRecoveryPlan).options(
            selectinload(SyllabusRecoveryPlan.items),
            selectinload(SyllabusRecoveryPlan.class_obj),
            selectinload(SyllabusRecoveryPlan.section),
            selectinload(SyllabusRecoveryPlan.subject),
            selectinload(SyllabusRecoveryPlan.teacher),
            selectinload(SyllabusRecoveryPlan.primary_teacher),
            selectinload(SyllabusRecoveryPlan.support_teacher)
        ).where(and_(*filters))
        res = await self.db.execute(stmt)
        return res.scalar_one_or_none()

    async def get_plans(
        self,
        school_id: uuid.UUID,
        academic_year_id: Optional[uuid.UUID] = None,
        class_id: Optional[uuid.UUID] = None,
        section_id: Optional[uuid.UUID] = None,
        subject_id: Optional[uuid.UUID] = None,
        teacher_id: Optional[uuid.UUID] = None,
        recovery_type: Optional[str] = None,
        status: Optional[str] = None
    ) -> List[SyllabusRecoveryPlan]:
        filters = [
            SyllabusRecoveryPlan.school_id == school_id,
            SyllabusRecoveryPlan.deleted_at.is_(None)
        ]
        if academic_year_id:
            filters.append(SyllabusRecoveryPlan.academic_year_id == academic_year_id)
        if class_id:
            filters.append(SyllabusRecoveryPlan.class_id == class_id)
        if section_id:
            filters.append(SyllabusRecoveryPlan.section_id == section_id)
        if subject_id:
            filters.append(SyllabusRecoveryPlan.subject_id == subject_id)
        if teacher_id:
            from sqlalchemy import or_
            filters.append(or_(
                SyllabusRecoveryPlan.teacher_id == teacher_id,
                SyllabusRecoveryPlan.primary_teacher_id == teacher_id,
                SyllabusRecoveryPlan.support_teacher_id == teacher_id
            ))
        if recovery_type:
            filters.append(SyllabusRecoveryPlan.recovery_type == recovery_type)
        if status:
            filters.append(SyllabusRecoveryPlan.status == status)

        stmt = select(SyllabusRecoveryPlan).options(
            selectinload(SyllabusRecoveryPlan.items),
            selectinload(SyllabusRecoveryPlan.class_obj),
            selectinload(SyllabusRecoveryPlan.section),
            selectinload(SyllabusRecoveryPlan.subject),
            selectinload(SyllabusRecoveryPlan.teacher),
            selectinload(SyllabusRecoveryPlan.primary_teacher),
            selectinload(SyllabusRecoveryPlan.support_teacher)
        ).where(and_(*filters)).order_by(SyllabusRecoveryPlan.created_at.desc())
        res = await self.db.execute(stmt)
        return list(res.scalars().all())

    async def get_active_plan_for_section_subject(
        self,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        section_id: uuid.UUID,
        subject_id: uuid.UUID
    ) -> Optional[SyllabusRecoveryPlan]:
        stmt = select(SyllabusRecoveryPlan).options(
            selectinload(SyllabusRecoveryPlan.items)
        ).where(
            SyllabusRecoveryPlan.school_id == school_id,
            SyllabusRecoveryPlan.academic_year_id == academic_year_id,
            SyllabusRecoveryPlan.section_id == section_id,
            SyllabusRecoveryPlan.subject_id == subject_id,
            SyllabusRecoveryPlan.status.in_(["SUGGESTED", "EDITED", "APPROVED"]),
            SyllabusRecoveryPlan.deleted_at.is_(None)
        ).order_by(SyllabusRecoveryPlan.created_at.desc())
        res = await self.db.execute(stmt)
        return res.scalars().first()

    async def get_item_by_id(self, item_id: uuid.UUID) -> Optional[RecoveryPlanItem]:
        stmt = select(RecoveryPlanItem).where(
            RecoveryPlanItem.id == item_id,
            RecoveryPlanItem.deleted_at.is_(None)
        )
        res = await self.db.execute(stmt)
        return res.scalar_one_or_none()

    async def delete_unapproved_items(self, plan_id: uuid.UUID) -> int:
        stmt = delete(RecoveryPlanItem).where(
            RecoveryPlanItem.recovery_plan_id == plan_id,
            RecoveryPlanItem.is_approved.is_(False),
            RecoveryPlanItem.status != "MODIFIED"
        )
        res = await self.db.execute(stmt)
        await self.db.flush()
        return res.rowcount

    async def add_item(self, item_data: Dict[str, Any]) -> RecoveryPlanItem:
        item = RecoveryPlanItem(**item_data)
        self.db.add(item)
        await self.db.flush()
        return item
