import uuid
from typing import List, Optional
from datetime import time, datetime, timezone
from sqlalchemy import select, and_, or_, func
from sqlalchemy.orm import joinedload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.timetable import Timetable, TimetableStatus, DayOfWeek
from app.models.teacher import Teacher
from app.models.subject import Subject
from app.models.class_entity import Class
from app.models.section import Section
from app.models.teacher_subject_assignment import TeacherSubjectAssignment
from app.schemas.timetable import TimetableCreate, TimetableUpdate

class TimetableRepository:
    """
    Repository layer for Timetable scheduling queries and mutations.
    Enforces multi-tenant boundaries and soft deletes.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(
        self, timetable_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[Timetable]:
        stmt = select(Timetable).where(
            Timetable.id == timetable_id,
            Timetable.school_id == school_id,
            Timetable.tenant_id == tenant_id,
            Timetable.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_conflicting_teacher(
        self,
        teacher_id: uuid.UUID,
        day_of_week: DayOfWeek,
        period_number: int,
        academic_year_id: uuid.UUID,
        tenant_id: uuid.UUID
    ) -> Optional[Timetable]:
        """
        Checks if teacher already has an active class assignment in the specified slot.
        """
        stmt = select(Timetable).where(
            Timetable.teacher_id == teacher_id,
            Timetable.day_of_week == day_of_week,
            Timetable.period_number == period_number,
            Timetable.academic_year_id == academic_year_id,
            Timetable.tenant_id == tenant_id,
            Timetable.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_conflicting_class(
        self,
        class_id: uuid.UUID,
        section_id: uuid.UUID,
        day_of_week: DayOfWeek,
        period_number: int,
        academic_year_id: uuid.UUID,
        tenant_id: uuid.UUID
    ) -> Optional[Timetable]:
        """
        Checks if the class/section already has an active period in the specified slot.
        """
        stmt = select(Timetable).where(
            Timetable.class_id == class_id,
            Timetable.section_id == section_id,
            Timetable.day_of_week == day_of_week,
            Timetable.period_number == period_number,
            Timetable.academic_year_id == academic_year_id,
            Timetable.tenant_id == tenant_id,
            Timetable.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_overlapping_class_slots(
        self,
        class_id: uuid.UUID,
        section_id: uuid.UUID,
        day_of_week: DayOfWeek,
        start_time: time,
        end_time: time,
        tenant_id: uuid.UUID
    ) -> List[Timetable]:
        """
        Checks if class/section already has overlapping time intervals in the same day.
        Condition: R.start_time < end_time AND start_time < R.end_time
        """
        stmt = select(Timetable).where(
            Timetable.class_id == class_id,
            Timetable.section_id == section_id,
            Timetable.day_of_week == day_of_week,
            Timetable.tenant_id == tenant_id,
            Timetable.start_time < end_time,
            Timetable.end_time > start_time,
            Timetable.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def get_assignment_slots_count(
        self, teacher_subject_assignment_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> int:
        """
        Returns number of active slots assigned to this TeacherSubjectAssignment.
        """
        stmt = select(func.count(Timetable.id)).where(
            Timetable.teacher_subject_assignment_id == teacher_subject_assignment_id,
            Timetable.tenant_id == tenant_id,
            Timetable.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar() or 0

    async def get_teacher_schedule(
        self, teacher_id: uuid.UUID, academic_year_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> List[Timetable]:
        stmt = select(Timetable).where(
            Timetable.teacher_id == teacher_id,
            Timetable.academic_year_id == academic_year_id,
            Timetable.tenant_id == tenant_id,
            Timetable.deleted_at.is_(None)
        ).order_by(Timetable.day_of_week, Timetable.period_number)
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def get_class_schedule(
        self, class_id: uuid.UUID, academic_year_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> List[Timetable]:
        stmt = select(Timetable).where(
            Timetable.class_id == class_id,
            Timetable.academic_year_id == academic_year_id,
            Timetable.tenant_id == tenant_id,
            Timetable.deleted_at.is_(None)
        ).order_by(Timetable.day_of_week, Timetable.period_number)
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def get_section_schedule(
        self, class_id: uuid.UUID, section_id: uuid.UUID, academic_year_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> List[Timetable]:
        stmt = select(Timetable).where(
            Timetable.class_id == class_id,
            Timetable.section_id == section_id,
            Timetable.academic_year_id == academic_year_id,
            Timetable.tenant_id == tenant_id,
            Timetable.deleted_at.is_(None)
        ).order_by(Timetable.day_of_week, Timetable.period_number)
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def get_multi(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        academic_year_id: Optional[uuid.UUID] = None,
        teacher_id: Optional[uuid.UUID] = None,
        subject_id: Optional[uuid.UUID] = None,
        class_id: Optional[uuid.UUID] = None,
        section_id: Optional[uuid.UUID] = None,
        day_of_week: Optional[DayOfWeek] = None,
        status: Optional[TimetableStatus] = None,
        search: Optional[str] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[Timetable]:
        """
        Queries paginated list of active timetable slots scoped to school/tenant.
        Allows searching on joined room_id placeholders, subject name/code, class/section names.
        """
        filters = [
            Timetable.school_id == school_id,
            Timetable.tenant_id == tenant_id,
            Timetable.deleted_at.is_(None)
        ]

        if academic_year_id:
            filters.append(Timetable.academic_year_id == academic_year_id)
        if teacher_id:
            filters.append(Timetable.teacher_id == teacher_id)
        if subject_id:
            filters.append(Timetable.subject_id == subject_id)
        if class_id:
            filters.append(Timetable.class_id == class_id)
        if section_id:
            filters.append(Timetable.section_id == section_id)
        if day_of_week:
            filters.append(Timetable.day_of_week == day_of_week)
        if status:
            filters.append(Timetable.status == status)

        stmt = select(Timetable).outerjoin(
            Teacher, Timetable.teacher_id == Teacher.id
        ).outerjoin(
            Subject, Timetable.subject_id == Subject.id
        ).join(
            Class, Timetable.class_id == Class.id
        ).join(
            Section, Timetable.section_id == Section.id
        )

        if search:
            search_clause = or_(
                Teacher.first_name.ilike(f"%{search}%"),
                Teacher.last_name.ilike(f"%{search}%"),
                Subject.subject_name.ilike(f"%{search}%"),
                Subject.subject_code.ilike(f"%{search}%"),
                Class.name.ilike(f"%{search}%"),
                Section.name.ilike(f"%{search}%")
            )
            filters.append(search_clause)

        stmt = (
            stmt.where(and_(*filters))
            .options(
                joinedload(Timetable.teacher),
                joinedload(Timetable.subject),
                joinedload(Timetable.class_obj),
                joinedload(Timetable.section),
                joinedload(Timetable.teacher_subject_assignment)
            )
            .order_by(Timetable.day_of_week, Timetable.period_number, Timetable.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def create(
        self,
        tenant_id: uuid.UUID,
        obj_in: TimetableCreate,
        teacher_id: Optional[uuid.UUID] = None,
        subject_id: Optional[uuid.UUID] = None,
        created_by: Optional[uuid.UUID] = None
    ) -> Timetable:
        db_obj = Timetable(
            day_of_week=obj_in.day_of_week,
            period_number=obj_in.period_number,
            period_id=obj_in.period_id,
            start_time=obj_in.start_time,
            end_time=obj_in.end_time,
            period_type=obj_in.period_type,
            room_id=obj_in.room_id,
            is_available=obj_in.is_available,
            settings=obj_in.settings,
            ai_metrics=obj_in.ai_metrics,
            tenant_id=tenant_id,
            school_id=obj_in.school_id,
            academic_year_id=obj_in.academic_year_id,
            teacher_subject_assignment_id=obj_in.teacher_subject_assignment_id,
            class_id=obj_in.class_id,
            section_id=obj_in.section_id,
            teacher_id=teacher_id,
            subject_id=subject_id,
            created_by=created_by
        )
        self.db.add(db_obj)
        return db_obj

    async def update(
        self,
        db_obj: Timetable,
        obj_in: TimetableUpdate | dict,
        updated_by: Optional[uuid.UUID] = None
    ) -> Timetable:
        if isinstance(obj_in, dict):
            update_data = obj_in
        else:
            update_data = obj_in.model_dump(exclude_unset=True)

        for field, value in update_data.items():
            setattr(db_obj, field, value)

        db_obj.updated_by = updated_by
        self.db.add(db_obj)
        return db_obj

    async def soft_delete(
        self,
        db_obj: Timetable,
        deleted_by: Optional[uuid.UUID] = None
    ) -> Timetable:
        db_obj.deleted_at = datetime.now(timezone.utc)
        db_obj.status = TimetableStatus.ARCHIVED
        db_obj.is_active = False
        db_obj.updated_by = deleted_by
        self.db.add(db_obj)
        return db_obj
