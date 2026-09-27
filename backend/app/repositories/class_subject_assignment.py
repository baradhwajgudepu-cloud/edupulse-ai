import uuid
from typing import List, Optional
from sqlalchemy import select, and_, or_
from sqlalchemy.orm import joinedload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.class_subject_assignment import ClassSubjectAssignment
from app.models.subject import Subject
from app.models.class_entity import Class
from app.models.section import Section
from app.models.teacher import Teacher

class ClassSubjectAssignmentRepository:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(
        self,
        id: uuid.UUID,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID
    ) -> Optional[ClassSubjectAssignment]:
        stmt = (
            select(ClassSubjectAssignment)
            .options(
                joinedload(ClassSubjectAssignment.subject),
                joinedload(ClassSubjectAssignment.class_obj),
                joinedload(ClassSubjectAssignment.section),
                joinedload(ClassSubjectAssignment.teacher),
            )
            .where(
                ClassSubjectAssignment.id == id,
                ClassSubjectAssignment.school_id == school_id,
                ClassSubjectAssignment.tenant_id == tenant_id,
                ClassSubjectAssignment.deleted_at.is_(None)
            )
        )
        res = await self.db.execute(stmt)
        return res.scalars().first()

    async def get_by_unique(
        self,
        academic_year_id: uuid.UUID,
        class_id: uuid.UUID,
        section_id: Optional[uuid.UUID],
        subject_id: uuid.UUID,
        tenant_id: uuid.UUID
    ) -> Optional[ClassSubjectAssignment]:
        filters = [
            ClassSubjectAssignment.academic_year_id == academic_year_id,
            ClassSubjectAssignment.class_id == class_id,
            ClassSubjectAssignment.subject_id == subject_id,
            ClassSubjectAssignment.tenant_id == tenant_id,
            ClassSubjectAssignment.deleted_at.is_(None)
        ]
        if section_id is not None:
            filters.append(ClassSubjectAssignment.section_id == section_id)
        else:
            filters.append(ClassSubjectAssignment.section_id.is_(None))

        stmt = select(ClassSubjectAssignment).where(and_(*filters))
        res = await self.db.execute(stmt)
        return res.scalars().first()

    async def get_multi(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        academic_year_id: Optional[uuid.UUID] = None,
        class_id: Optional[uuid.UUID] = None,
        section_id: Optional[uuid.UUID] = None,
        subject_id: Optional[uuid.UUID] = None,
        teacher_id: Optional[uuid.UUID] = None,
        is_active: Optional[bool] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[ClassSubjectAssignment]:
        filters = [
            ClassSubjectAssignment.school_id == school_id,
            ClassSubjectAssignment.tenant_id == tenant_id,
            ClassSubjectAssignment.deleted_at.is_(None)
        ]
        if academic_year_id:
            filters.append(ClassSubjectAssignment.academic_year_id == academic_year_id)
        if class_id:
            filters.append(ClassSubjectAssignment.class_id == class_id)
        if section_id:
            filters.append(
                or_(
                    ClassSubjectAssignment.section_id == section_id,
                    ClassSubjectAssignment.section_id.is_(None)
                )
            )
        if subject_id:
            filters.append(ClassSubjectAssignment.subject_id == subject_id)
        if teacher_id:
            filters.append(ClassSubjectAssignment.teacher_id == teacher_id)
        if is_active is not None:
            filters.append(ClassSubjectAssignment.is_active == is_active)

        stmt = (
            select(ClassSubjectAssignment)
            .options(
                joinedload(ClassSubjectAssignment.subject),
                joinedload(ClassSubjectAssignment.class_obj),
                joinedload(ClassSubjectAssignment.section),
                joinedload(ClassSubjectAssignment.teacher),
            )
            .where(and_(*filters))
            .order_by(ClassSubjectAssignment.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        res = await self.db.execute(stmt)
        return list(res.scalars().all())

    async def create(self, db_obj: ClassSubjectAssignment) -> ClassSubjectAssignment:
        self.db.add(db_obj)
        await self.db.commit()
        await self.db.refresh(db_obj)
        return db_obj

    async def update(self, db_obj: ClassSubjectAssignment) -> ClassSubjectAssignment:
        await self.db.commit()
        await self.db.refresh(db_obj)
        return db_obj

    async def delete(self, db_obj: ClassSubjectAssignment) -> None:
        await self.db.delete(db_obj)
        await self.db.commit()
