import uuid
from typing import List, Optional
from datetime import datetime, timezone
from sqlalchemy import select, and_, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.exam_question import ExamQuestion, QuestionDifficulty, QuestionType
from app.schemas.exam_question import ExamQuestionBase, ExamQuestionCreate, ExamQuestionUpdate

class ExamQuestionRepository:
    """
    Repository layer for ExamQuestion operations.
    Enforces multi-tenancy, school scoping, and transaction isolation.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(
        self, question_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[ExamQuestion]:
        stmt = select(ExamQuestion).where(
            ExamQuestion.id == question_id,
            ExamQuestion.school_id == school_id,
            ExamQuestion.tenant_id == tenant_id,
            ExamQuestion.deleted_at.is_(None)
        )
        res = await self.db.execute(stmt)
        return res.scalar_one_or_none()

    async def get_by_examination(
        self,
        examination_id: uuid.UUID,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        subject_id: Optional[uuid.UUID] = None
    ) -> List[ExamQuestion]:
        filters = [
            ExamQuestion.examination_id == examination_id,
            ExamQuestion.school_id == school_id,
            ExamQuestion.tenant_id == tenant_id,
            ExamQuestion.deleted_at.is_(None)
        ]
        if subject_id:
            filters.append(ExamQuestion.subject_id == subject_id)

        stmt = select(ExamQuestion).where(and_(*filters)).order_by(ExamQuestion.sequence_order, ExamQuestion.question_number)
        res = await self.db.execute(stmt)
        return list(res.scalars().all())

    async def get_by_question_paper_id(
        self, question_paper_id: uuid.UUID
    ) -> List[ExamQuestion]:
        stmt = select(ExamQuestion).options(
            selectinload(ExamQuestion.syllabus),
            selectinload(ExamQuestion.sub_questions)
        ).where(
            ExamQuestion.question_paper_id == question_paper_id,
            ExamQuestion.deleted_at.is_(None)
        ).order_by(ExamQuestion.sequence_order, ExamQuestion.question_number)
        res = await self.db.execute(stmt)
        return list(res.scalars().all())

    async def get_by_schedule_id(
        self, exam_schedule_id: uuid.UUID
    ) -> List[ExamQuestion]:
        stmt = select(ExamQuestion).options(
            selectinload(ExamQuestion.syllabus),
            selectinload(ExamQuestion.sub_questions)
        ).where(
            ExamQuestion.exam_schedule_id == exam_schedule_id,
            ExamQuestion.deleted_at.is_(None)
        ).order_by(ExamQuestion.sequence_order, ExamQuestion.question_number)
        res = await self.db.execute(stmt)
        return list(res.scalars().all())

    async def create(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        examination_id: uuid.UUID,
        obj_in: ExamQuestionCreate,
        created_by: Optional[uuid.UUID] = None
    ) -> ExamQuestion:
        db_obj = ExamQuestion(
            id=uuid.uuid4(),
            examination_id=examination_id,
            subject_id=obj_in.subject_id,
            exam_schedule_id=obj_in.exam_schedule_id,
            question_number=obj_in.question_number.strip(),
            question_text=obj_in.question_text,
            max_marks=obj_in.max_marks,
            chapter_name=obj_in.chapter_name.strip(),
            topic_name=obj_in.topic_name.strip() if obj_in.topic_name else None,
            difficulty=obj_in.difficulty,
            question_type=obj_in.question_type,
            syllabus_id=obj_in.syllabus_id,
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=academic_year_id,
            created_by=created_by
        )
        self.db.add(db_obj)
        return db_obj

    async def bulk_create_or_replace(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        examination_id: uuid.UUID,
        subject_id: uuid.UUID,
        questions: List[ExamQuestionBase],
        created_by: Optional[uuid.UUID] = None
    ) -> List[ExamQuestion]:
        # Fetch existing for this exam and subject
        existing = await self.get_by_examination(examination_id, school_id, tenant_id, subject_id)
        existing_map = {q.question_number: q for q in existing}

        results = []
        for q in questions:
            num = q.question_number.strip()
            if num in existing_map:
                # Update existing
                eq = existing_map[num]
                eq.question_text = q.question_text
                eq.max_marks = q.max_marks
                eq.chapter_name = q.chapter_name.strip()
                eq.topic_name = q.topic_name.strip() if q.topic_name else None
                eq.difficulty = q.difficulty
                eq.question_type = q.question_type
                eq.syllabus_id = q.syllabus_id
                eq.exam_schedule_id = q.exam_schedule_id or eq.exam_schedule_id
                eq.updated_at = datetime.now(timezone.utc)
                if created_by:
                    eq.updated_by = created_by
                self.db.add(eq)
                results.append(eq)
            else:
                # Create new
                eq = ExamQuestion(
                    id=uuid.uuid4(),
                    examination_id=examination_id,
                    subject_id=subject_id,
                    exam_schedule_id=q.exam_schedule_id,
                    question_number=num,
                    question_text=q.question_text,
                    max_marks=q.max_marks,
                    chapter_name=q.chapter_name.strip(),
                    topic_name=q.topic_name.strip() if q.topic_name else None,
                    difficulty=q.difficulty,
                    question_type=q.question_type,
                    syllabus_id=q.syllabus_id,
                    tenant_id=tenant_id,
                    school_id=school_id,
                    academic_year_id=academic_year_id,
                    created_by=created_by
                )
                self.db.add(eq)
                results.append(eq)

        return results

    async def update(
        self,
        db_obj: ExamQuestion,
        obj_in: ExamQuestionUpdate,
        updated_by: Optional[uuid.UUID] = None
    ) -> ExamQuestion:
        update_data = obj_in.model_dump(exclude_unset=True)
        for field, val in update_data.items():
            if val is not None:
                setattr(db_obj, field, val)
        db_obj.updated_at = datetime.now(timezone.utc)
        if updated_by:
            db_obj.updated_by = updated_by
        self.db.add(db_obj)
        return db_obj

    async def delete(
        self, db_obj: ExamQuestion, deleted_by: Optional[uuid.UUID] = None
    ) -> ExamQuestion:
        now = datetime.now(timezone.utc)
        db_obj.deleted_at = now
        if deleted_by:
            db_obj.updated_by = deleted_by
        self.db.add(db_obj)
        return db_obj
