import uuid
from typing import List, Optional
from datetime import date, datetime, timezone
from sqlalchemy import select, and_, or_
from sqlalchemy.orm import joinedload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.homework import Homework, HomeworkStatus
from app.models.guardian import Guardian, StudentGuardian
from app.models.student import Student
from app.schemas.homework import HomeworkCreate

class HomeworkRepository:
    """
    Repository layer for Homework database operations.
    Enforces multi-tenant scoping and soft deletion.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(
        self, homework_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[Homework]:
        stmt = select(Homework).where(
            Homework.id == homework_id,
            Homework.school_id == school_id,
            Homework.tenant_id == tenant_id,
            Homework.deleted_at.is_(None)
        ).options(
            joinedload(Homework.subject),
            joinedload(Homework.class_obj),
            joinedload(Homework.section)
        )
        result = await self.db.execute(stmt)
        return result.unique().scalar_one_or_none()

    async def create(
        self, tenant_id: uuid.UUID, obj_in: HomeworkCreate, created_by: Optional[uuid.UUID] = None
    ) -> Homework:
        db_obj = Homework(
            tenant_id=tenant_id,
            school_id=obj_in.school_id,
            academic_year_id=obj_in.academic_year_id,
            teacher_id=obj_in.teacher_id,
            teacher_subject_assignment_id=obj_in.teacher_subject_assignment_id,
            subject_id=obj_in.subject_id,
            class_id=obj_in.class_id,
            section_id=obj_in.section_id,
            timetable_id=obj_in.timetable_id,
            title=obj_in.title,
            description=obj_in.description,
            due_date=obj_in.due_date,
            priority=obj_in.priority,
            status=obj_in.status,
            attachment_url=obj_in.attachment_url,
            estimated_minutes=obj_in.estimated_minutes,
            settings=obj_in.settings,
            ai_metrics=obj_in.ai_metrics,
            created_by=created_by,
            updated_by=created_by
        )
        self.db.add(db_obj)
        return db_obj

    async def update(
        self, db_obj: Homework, update_data: dict, updated_by: Optional[uuid.UUID] = None
    ) -> Homework:
        for field, value in update_data.items():
            setattr(db_obj, field, value)
        db_obj.updated_by = updated_by
        self.db.add(db_obj)
        return db_obj

    async def soft_delete(
        self, db_obj: Homework, deleted_by: Optional[uuid.UUID] = None
    ) -> Homework:
        db_obj.deleted_at = datetime.now(timezone.utc)
        db_obj.is_active = False
        db_obj.updated_by = deleted_by
        self.db.add(db_obj)
        return db_obj

    async def get_multi(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        academic_year_id: Optional[uuid.UUID] = None,
        class_id: Optional[uuid.UUID] = None,
        section_id: Optional[uuid.UUID] = None,
        subject_id: Optional[uuid.UUID] = None,
        teacher_id: Optional[uuid.UUID] = None,
        status: Optional[HomeworkStatus] = None,
        search: Optional[str] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[Homework]:
        filters = [
            Homework.school_id == school_id,
            Homework.tenant_id == tenant_id,
            Homework.deleted_at.is_(None)
        ]
        if academic_year_id:
            filters.append(Homework.academic_year_id == academic_year_id)
        if class_id:
            filters.append(Homework.class_id == class_id)
        if section_id:
            filters.append(Homework.section_id == section_id)
        if subject_id:
            filters.append(Homework.subject_id == subject_id)
        if teacher_id:
            filters.append(Homework.teacher_id == teacher_id)
        if status:
            filters.append(Homework.status == status)
        if search:
            filters.append(or_(
                Homework.title.ilike(f"%{search}%"),
                Homework.description.ilike(f"%{search}%")
            ))

        stmt = select(Homework).where(
            and_(*filters)
        ).options(
            joinedload(Homework.subject),
            joinedload(Homework.class_obj),
            joinedload(Homework.section)
        ).order_by(
            Homework.due_date.desc(), Homework.created_at.desc()
        ).offset(skip).limit(limit)

        result = await self.db.execute(stmt)
        return list(result.unique().scalars().all())

    async def get_recent_homework(
        self, teacher_id: uuid.UUID, tenant_id: uuid.UUID, limit: int = 20
    ) -> List[Homework]:
        stmt = select(Homework).where(
            Homework.teacher_id == teacher_id,
            Homework.tenant_id == tenant_id,
            Homework.deleted_at.is_(None)
        ).options(
            joinedload(Homework.subject),
            joinedload(Homework.class_obj),
            joinedload(Homework.section)
        ).order_by(
            Homework.created_at.desc()
        ).limit(limit)
        result = await self.db.execute(stmt)
        return list(result.unique().scalars().all())

    async def get_duplicate_homework(
        self,
        teacher_id: uuid.UUID,
        subject_id: uuid.UUID,
        class_id: uuid.UUID,
        section_id: uuid.UUID,
        due_date: date,
        title: str,
        tenant_id: uuid.UUID
    ) -> Optional[Homework]:
        stmt = select(Homework).where(
            Homework.teacher_id == teacher_id,
            Homework.subject_id == subject_id,
            Homework.class_id == class_id,
            Homework.section_id == section_id,
            Homework.due_date == due_date,
            Homework.title.ilike(title),
            Homework.tenant_id == tenant_id,
            Homework.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.unique().scalar_one_or_none()

    async def get_parent_homeworks(
        self, parent_email: str, school_id: uuid.UUID, tenant_id: uuid.UUID, limit: int = 50
    ) -> List[Homework]:
        # 1. Load active Guardian and nested Student links
        stmt_g = select(Guardian).where(
            Guardian.email == parent_email,
            Guardian.school_id == school_id,
            Guardian.tenant_id == tenant_id,
            Guardian.deleted_at.is_(None)
        ).options(
            joinedload(Guardian.students).joinedload(StudentGuardian.student)
        )
        res_g = await self.db.execute(stmt_g)
        guardian = res_g.unique().scalar_one_or_none()
        if not guardian:
            return []

        # 2. Extract active student class & section values
        student_slots = []
        for sg in guardian.students:
            student = sg.student
            if student and student.is_active and not student.deleted_at:
                student_slots.append((student.class_id, student.section_id))

        if not student_slots:
            return []

        # 3. Compile class/section search parameters
        conditions = []
        for class_id, section_id in student_slots:
            conditions.append(
                and_(
                    Homework.class_id == class_id,
                    Homework.section_id == section_id
                )
            )

        stmt_h = select(Homework).where(
            Homework.school_id == school_id,
            Homework.tenant_id == tenant_id,
            Homework.status == HomeworkStatus.PUBLISHED,
            Homework.deleted_at.is_(None),
            or_(*conditions)
        ).options(
            joinedload(Homework.subject),
            joinedload(Homework.class_obj),
            joinedload(Homework.section)
        ).order_by(
            Homework.due_date.desc(), Homework.created_at.desc()
        ).limit(limit)

        res_h = await self.db.execute(stmt_h)
        return list(res_h.unique().scalars().all())
