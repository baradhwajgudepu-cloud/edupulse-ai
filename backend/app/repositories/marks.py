import uuid
from typing import List, Optional
from datetime import datetime, timezone
from sqlalchemy import select, and_, or_
from sqlalchemy.orm import joinedload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.marks import Marks, MarksStatus
from app.models.student import Student
from app.models.guardian import Guardian, StudentGuardian

class MarksRepository:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(
        self, marks_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[Marks]:
        stmt = select(Marks).where(
            Marks.id == marks_id,
            Marks.school_id == school_id,
            Marks.tenant_id == tenant_id,
            Marks.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_student_and_schedule(
        self, exam_schedule_id: uuid.UUID, student_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[Marks]:
        stmt = select(Marks).where(
            Marks.exam_schedule_id == exam_schedule_id,
            Marks.student_id == student_id,
            Marks.tenant_id == tenant_id,
            Marks.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_schedule_id(
        self, exam_schedule_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> List[Marks]:
        stmt = select(Marks).where(
            Marks.exam_schedule_id == exam_schedule_id,
            Marks.tenant_id == tenant_id,
            Marks.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def get_class_students_sorted(
        self, class_id: uuid.UUID, section_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> List[Student]:
        stmt = select(Student).where(
            Student.class_id == class_id,
            Student.section_id == section_id,
            Student.school_id == school_id,
            Student.tenant_id == tenant_id,
            Student.is_active == True,
            Student.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        students = list(result.scalars().all())
        
        # Sort roll numbers numerically if possible, otherwise string sort
        def sort_key(s: Student):
            val = s.roll_number or ""
            return (0, int(val)) if val.isdigit() else (1, val)

        students.sort(key=sort_key)
        return students

    async def get_parent_marks(
        self, parent_email: str, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> List[Marks]:
        # 1. Fetch Guardian and linked students
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

        student_ids = []
        for sg in guardian.students:
            student = sg.student
            if student and student.is_active and not student.deleted_at:
                student_ids.append(student.id)

        if not student_ids:
            return []

        # 2. Fetch only PUBLISHED marks for these students
        stmt_m = select(Marks).where(
            Marks.student_id.in_(student_ids),
            Marks.school_id == school_id,
            Marks.tenant_id == tenant_id,
            Marks.status == MarksStatus.PUBLISHED,
            Marks.deleted_at.is_(None)
        ).options(
            joinedload(Marks.student),
            joinedload(Marks.examination),
            joinedload(Marks.subject)
        ).order_by(
            Marks.created_at.desc()
        )

        res_m = await self.db.execute(stmt_m)
        return list(res_m.unique().scalars().all())

    async def get_multi(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        examination_id: Optional[uuid.UUID] = None,
        class_id: Optional[uuid.UUID] = None,
        section_id: Optional[uuid.UUID] = None,
        subject_id: Optional[uuid.UUID] = None,
        status: Optional[MarksStatus] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[Marks]:
        filters = [
            Marks.school_id == school_id,
            Marks.tenant_id == tenant_id,
            Marks.deleted_at.is_(None)
        ]
        if examination_id:
            filters.append(Marks.examination_id == examination_id)
        if class_id:
            filters.append(Marks.class_id == class_id)
        if section_id:
            filters.append(Marks.section_id == section_id)
        if subject_id:
            filters.append(Marks.subject_id == subject_id)
        if status:
            filters.append(Marks.status == status)

        stmt = select(Marks).where(
            and_(*filters)
        ).options(
            joinedload(Marks.student),
            joinedload(Marks.subject),
            joinedload(Marks.examination)
        ).offset(skip).limit(limit)

        result = await self.db.execute(stmt)
        return list(result.unique().scalars().all())
