import uuid
from typing import List, Optional
from datetime import date, time, datetime, timezone
from sqlalchemy import select, and_, or_, exists
from sqlalchemy.orm import joinedload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.examination import ExamTemplate, Examination, ExamSchedule, ExamStatus
from app.models.teacher_subject_assignment import TeacherSubjectAssignment
from app.models.student import Student
from app.models.guardian import Guardian, StudentGuardian
from app.schemas.examination import ExamTemplateCreate, ExaminationCreate, ExamScheduleCreate

class ExamTemplateRepository:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(
        self, template_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[ExamTemplate]:
        stmt = select(ExamTemplate).where(
            ExamTemplate.id == template_id,
            ExamTemplate.school_id == school_id,
            ExamTemplate.tenant_id == tenant_id,
            ExamTemplate.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def create(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        obj_in: ExamTemplateCreate,
        created_by: Optional[uuid.UUID] = None
    ) -> ExamTemplate:
        db_obj = ExamTemplate(
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=academic_year_id,
            template_name=obj_in.template_name,
            exam_type=obj_in.exam_type,
            subject_configs=obj_in.subject_configs,
            settings=obj_in.settings,
            created_by=created_by,
            updated_by=created_by
        )
        self.db.add(db_obj)
        return db_obj

    async def update(
        self, db_obj: ExamTemplate, update_data: dict, updated_by: Optional[uuid.UUID] = None
    ) -> ExamTemplate:
        for field, value in update_data.items():
            setattr(db_obj, field, value)
        db_obj.updated_by = updated_by
        self.db.add(db_obj)
        return db_obj

    async def get_multi(
        self, school_id: uuid.UUID, tenant_id: uuid.UUID, skip: int = 0, limit: int = 100
    ) -> List[ExamTemplate]:
        stmt = select(ExamTemplate).where(
            ExamTemplate.school_id == school_id,
            ExamTemplate.tenant_id == tenant_id,
            ExamTemplate.deleted_at.is_(None)
        ).offset(skip).limit(limit)
        result = await self.db.execute(stmt)
        return list(result.scalars().all())


class ExaminationRepository:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(
        self, exam_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[Examination]:
        stmt = select(Examination).where(
            Examination.id == exam_id,
            Examination.school_id == school_id,
            Examination.tenant_id == tenant_id,
            Examination.deleted_at.is_(None)
        ).options(
            joinedload(Examination.schedules)
        )
        result = await self.db.execute(stmt)
        return result.unique().scalar_one_or_none()

    async def create(
        self, tenant_id: uuid.UUID, obj_in: ExaminationCreate, created_by: Optional[uuid.UUID] = None
    ) -> Examination:
        db_obj = Examination(
            tenant_id=tenant_id,
            school_id=obj_in.school_id,
            academic_year_id=obj_in.academic_year_id,
            exam_name=obj_in.exam_name,
            exam_type=obj_in.exam_type,
            start_date=obj_in.start_date,
            end_date=obj_in.end_date,
            description=obj_in.description,
            settings=obj_in.settings,
            ai_metrics=obj_in.ai_metrics,
            created_by=created_by,
            updated_by=created_by
        )
        self.db.add(db_obj)
        return db_obj

    async def update(
        self, db_obj: Examination, update_data: dict, updated_by: Optional[uuid.UUID] = None
    ) -> Examination:
        for field, value in update_data.items():
            setattr(db_obj, field, value)
        db_obj.updated_by = updated_by
        self.db.add(db_obj)
        return db_obj

    async def soft_delete(
        self, db_obj: Examination, deleted_by: Optional[uuid.UUID] = None
    ) -> Examination:
        now = datetime.now(timezone.utc)
        db_obj.deleted_at = now
        db_obj.is_active = False
        db_obj.updated_by = deleted_by
        self.db.add(db_obj)
        
        # Cascade soft-delete to schedules
        for sched in db_obj.schedules:
            sched.deleted_at = now
            sched.is_active = False
            sched.updated_by = deleted_by
            self.db.add(sched)
            
        return db_obj

    async def get_multi(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        academic_year_id: Optional[uuid.UUID] = None,
        search: Optional[str] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[Examination]:
        filters = [
            Examination.school_id == school_id,
            Examination.tenant_id == tenant_id,
            Examination.deleted_at.is_(None)
        ]
        if academic_year_id:
            filters.append(Examination.academic_year_id == academic_year_id)
        if search:
            filters.append(or_(
                Examination.exam_name.ilike(f"%{search}%"),
                Examination.description.ilike(f"%{search}%")
            ))
            
        stmt = select(Examination).where(
            and_(*filters)
        ).options(
            joinedload(Examination.schedules)
        ).order_by(
            Examination.start_date.desc()
        ).offset(skip).limit(limit)
        
        result = await self.db.execute(stmt)
        return list(result.unique().scalars().all())

    async def get_duplicate(
        self, name: str, academic_year_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[Examination]:
        stmt = select(Examination).where(
            Examination.exam_name.ilike(name),
            Examination.academic_year_id == academic_year_id,
            Examination.school_id == school_id,
            Examination.tenant_id == tenant_id,
            Examination.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.unique().scalar_one_or_none()

    async def get_parent_schedules(
        self, parent_email: str, school_id: uuid.UUID, tenant_id: uuid.UUID, limit: int = 100
    ) -> List[ExamSchedule]:
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

        # 3. Compile class/section conditions
        conditions = []
        for class_id, section_id in student_slots:
            conditions.append(
                and_(
                    ExamSchedule.class_id == class_id,
                    ExamSchedule.section_id == section_id
                )
            )

        stmt_s = select(ExamSchedule).join(
            Examination, ExamSchedule.exam_id == Examination.id
        ).where(
            ExamSchedule.school_id == school_id,
            ExamSchedule.tenant_id == tenant_id,
            ExamSchedule.deleted_at.is_(None),
            Examination.status == ExamStatus.PUBLISHED,
            Examination.deleted_at.is_(None),
            or_(*conditions)
        ).options(
            joinedload(ExamSchedule.class_obj),
            joinedload(ExamSchedule.section),
            joinedload(ExamSchedule.subject)
        ).order_by(
            ExamSchedule.exam_date.asc(), ExamSchedule.start_time.asc()
        ).limit(limit)

        res_s = await self.db.execute(stmt_s)
        return list(res_s.unique().scalars().all())


class ExamScheduleRepository:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def check_class_overlap(
        self,
        class_id: uuid.UUID,
        section_id: uuid.UUID,
        exam_date: date,
        start_time: time,
        end_time: time,
        exclude_schedule_id: Optional[uuid.UUID] = None
    ) -> bool:
        """
        Returns True if there is an overlapping exam schedule for the class/section.
        """
        filters = [
            ExamSchedule.class_id == class_id,
            ExamSchedule.section_id == section_id,
            ExamSchedule.exam_date == exam_date,
            ExamSchedule.deleted_at.is_(None),
            # Overlaps logic: start_time < new_end_time AND end_time > new_start_time
            ExamSchedule.start_time < end_time,
            ExamSchedule.end_time > start_time
        ]
        if exclude_schedule_id:
            filters.append(ExamSchedule.id != exclude_schedule_id)

        stmt = select(exists().where(and_(*filters)))
        result = await self.db.execute(stmt)
        return result.scalar()

    async def check_teacher_overlap(
        self,
        teacher_id: uuid.UUID,
        exam_date: date,
        start_time: time,
        end_time: time,
        exclude_schedule_id: Optional[uuid.UUID] = None
    ) -> bool:
        """
        Returns True if the teacher is already scheduled for an exam at this slot.
        """
        filters = [
            ExamSchedule.exam_date == exam_date,
            ExamSchedule.deleted_at.is_(None),
            TeacherSubjectAssignment.teacher_id == teacher_id,
            ExamSchedule.start_time < end_time,
            ExamSchedule.end_time > start_time
        ]
        if exclude_schedule_id:
            filters.append(ExamSchedule.id != exclude_schedule_id)

        stmt = select(exists(
            select(ExamSchedule.id)
            .join(TeacherSubjectAssignment, ExamSchedule.teacher_subject_assignment_id == TeacherSubjectAssignment.id)
            .where(and_(*filters))
        ))
        result = await self.db.execute(stmt)
        return bool(result.scalar())

    async def create(
        self, tenant_id: uuid.UUID, exam_id: uuid.UUID, obj_in: ExamScheduleCreate, created_by: Optional[uuid.UUID] = None
    ) -> ExamSchedule:
        # Load academic_year_id and school_id from TSA or similar (caller passes them or resolves them)
        # We'll retrieve school_id and academic_year_id during service orchestration.
        pass
