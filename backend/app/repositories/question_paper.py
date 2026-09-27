import uuid
from typing import List, Optional, Dict, Any
from datetime import datetime, timezone
from sqlalchemy import select, and_, delete
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.question_paper import QuestionPaper, StudentQuestionMarks
from app.models.exam_question import ExamQuestion

class QuestionPaperRepository:
    """
    Repository for managing Question Paper master records and student question-wise marks.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_paper_id(
        self, paper_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[QuestionPaper]:
        stmt = select(QuestionPaper).options(
            selectinload(QuestionPaper.questions).selectinload(ExamQuestion.syllabus),
            selectinload(QuestionPaper.questions).selectinload(ExamQuestion.sub_questions),
            selectinload(QuestionPaper.paper_schedule),
            selectinload(QuestionPaper.examination)
        ).where(
            QuestionPaper.paper_id == paper_id,
            QuestionPaper.school_id == school_id,
            QuestionPaper.tenant_id == tenant_id,
            QuestionPaper.deleted_at.is_(None)
        )
        res = await self.db.execute(stmt)
        return res.scalar_one_or_none()

    async def get_by_id(
        self, id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[QuestionPaper]:
        stmt = select(QuestionPaper).options(
            selectinload(QuestionPaper.questions).selectinload(ExamQuestion.syllabus),
            selectinload(QuestionPaper.questions).selectinload(ExamQuestion.sub_questions),
            selectinload(QuestionPaper.paper_schedule),
            selectinload(QuestionPaper.examination)
        ).where(
            QuestionPaper.id == id,
            QuestionPaper.school_id == school_id,
            QuestionPaper.tenant_id == tenant_id,
            QuestionPaper.deleted_at.is_(None)
        )
        res = await self.db.execute(stmt)
        return res.scalar_one_or_none()

    async def create(self, paper: QuestionPaper) -> QuestionPaper:
        self.db.add(paper)
        await self.db.flush()
        return paper

    async def update(self, paper: QuestionPaper, updated_by: uuid.UUID) -> QuestionPaper:
        paper.updated_by = updated_by
        paper.updated_at = datetime.now(timezone.utc)
        self.db.add(paper)
        await self.db.flush()
        return paper

    async def soft_delete(self, paper: QuestionPaper, deleted_by: uuid.UUID) -> None:
        paper.deleted_at = datetime.now(timezone.utc)
        paper.updated_by = deleted_by
        self.db.add(paper)
        await self.db.flush()

    async def get_student_marks_for_paper(
        self, exam_schedule_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> List[StudentQuestionMarks]:
        stmt = select(StudentQuestionMarks).options(
            selectinload(StudentQuestionMarks.question),
            selectinload(StudentQuestionMarks.student)
        ).where(
            StudentQuestionMarks.exam_schedule_id == exam_schedule_id,
            StudentQuestionMarks.school_id == school_id,
            StudentQuestionMarks.tenant_id == tenant_id,
            StudentQuestionMarks.deleted_at.is_(None)
        )
        res = await self.db.execute(stmt)
        return list(res.scalars().all())

    async def save_student_marks_bulk(
        self, entries: List[StudentQuestionMarks]
    ) -> None:
        for entry in entries:
            # Check existing to upsert
            stmt = select(StudentQuestionMarks).where(
                StudentQuestionMarks.question_id == entry.question_id,
                StudentQuestionMarks.student_id == entry.student_id
            )
            res = await self.db.execute(stmt)
            existing = res.scalar_one_or_none()
            if existing:
                existing.marks_obtained = entry.marks_obtained
                existing.max_marks = entry.max_marks
                existing.is_attempted = entry.is_attempted
                existing.remarks = entry.remarks
                existing.updated_at = datetime.now(timezone.utc)
                existing.updated_by = entry.updated_by
                self.db.add(existing)
            else:
                self.db.add(entry)
        await self.db.flush()

    async def get_student_exam_question_marks(
        self, student_id: uuid.UUID, examination_id: uuid.UUID
    ) -> List[StudentQuestionMarks]:
        stmt = select(StudentQuestionMarks).options(
            selectinload(StudentQuestionMarks.question).selectinload(ExamQuestion.syllabus),
            selectinload(StudentQuestionMarks.exam_schedule)
        ).where(
            StudentQuestionMarks.student_id == student_id,
            StudentQuestionMarks.examination_id == examination_id,
            StudentQuestionMarks.deleted_at.is_(None)
        )
        res = await self.db.execute(stmt)
        return list(res.scalars().all())
