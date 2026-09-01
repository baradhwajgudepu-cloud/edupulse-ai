import uuid
from typing import List, Optional
from datetime import date, time, datetime, timezone
from sqlalchemy import select, and_, or_, exists, func
from sqlalchemy.orm import joinedload, selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.examination import (
    ExamTypeMaster, ExamTemplate, Examination, ExamSchedule,
    ExaminationClass, ExamStatus, ExamType
)
from app.models.teacher_subject_assignment import TeacherSubjectAssignment
from app.models.student import Student
from app.models.guardian import Guardian, StudentGuardian
from app.schemas.examination import (
    ExamTypeMasterCreate, ExamTemplateCreate, ExaminationCreate, ExamScheduleCreate
)

class ExamTypeMasterRepository:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(
        self, id: uuid.UUID, tenant_id: uuid.UUID, school_id: Optional[uuid.UUID] = None
    ) -> Optional[ExamTypeMaster]:
        filters = [
            ExamTypeMaster.id == id,
            ExamTypeMaster.tenant_id == tenant_id,
            ExamTypeMaster.deleted_at.is_(None)
        ]
        if school_id:
            filters.append(or_(ExamTypeMaster.school_id == school_id, ExamTypeMaster.school_id.is_(None)))
        stmt = select(ExamTypeMaster).where(and_(*filters))
        res = await self.db.execute(stmt)
        return res.scalar_one_or_none()

    async def get_by_code(
        self, code: str, tenant_id: uuid.UUID, school_id: Optional[uuid.UUID] = None
    ) -> Optional[ExamTypeMaster]:
        filters = [
            ExamTypeMaster.code == code,
            ExamTypeMaster.tenant_id == tenant_id,
            ExamTypeMaster.deleted_at.is_(None)
        ]
        if school_id:
            filters.append(or_(ExamTypeMaster.school_id == school_id, ExamTypeMaster.school_id.is_(None)))
        stmt = select(ExamTypeMaster).where(and_(*filters))
        res = await self.db.execute(stmt)
        return res.scalar_one_or_none()

    async def create(
        self, tenant_id: uuid.UUID, obj_in: ExamTypeMasterCreate, created_by: Optional[uuid.UUID] = None
    ) -> ExamTypeMaster:
        db_obj = ExamTypeMaster(
            tenant_id=tenant_id,
            school_id=obj_in.school_id,
            name=obj_in.name,
            code=obj_in.code.upper(),
            description=obj_in.description,
            category=obj_in.category,
            default_weightage=obj_in.default_weightage,
            is_active=obj_in.is_active,
            is_system=False,
            created_by=created_by,
            updated_by=created_by
        )
        self.db.add(db_obj)
        return db_obj

    async def update(
        self, db_obj: ExamTypeMaster, update_data: dict, updated_by: Optional[uuid.UUID] = None
    ) -> ExamTypeMaster:
        for field, value in update_data.items():
            if value is not None:
                setattr(db_obj, field, value)
        db_obj.updated_by = updated_by
        self.db.add(db_obj)
        return db_obj

    async def delete(self, db_obj: ExamTypeMaster) -> None:
        await self.db.delete(db_obj)

    async def is_referenced(self, code: str, tenant_id: uuid.UUID, school_id: Optional[uuid.UUID] = None) -> bool:
        # Check if any Examination uses this exam_type code
        stmt_exam = select(exists().where(
            Examination.tenant_id == tenant_id,
            Examination.exam_type == code,
            Examination.deleted_at.is_(None)
        ))
        res_exam = await self.db.execute(stmt_exam)
        if res_exam.scalar():
            return True
        return False

    async def get_multi(
        self, tenant_id: uuid.UUID, school_id: Optional[uuid.UUID] = None, skip: int = 0, limit: int = 100
    ) -> List[ExamTypeMaster]:
        filters = [
            ExamTypeMaster.tenant_id == tenant_id,
            ExamTypeMaster.deleted_at.is_(None)
        ]
        if school_id:
            filters.append(or_(ExamTypeMaster.school_id == school_id, ExamTypeMaster.school_id.is_(None)))
        stmt = select(ExamTypeMaster).where(and_(*filters)).order_by(ExamTypeMaster.name.asc()).offset(skip).limit(limit)
        res = await self.db.execute(stmt)
        return list(res.scalars().all())


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
            selectinload(Examination.schedules).joinedload(ExamSchedule.subject),
            selectinload(Examination.schedules).joinedload(ExamSchedule.class_obj),
            selectinload(Examination.schedules).joinedload(ExamSchedule.section),
            selectinload(Examination.participating_classes)
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
        await self.db.flush()

        if obj_in.participating_class_ids:
            for cid in obj_in.participating_class_ids:
                ec = ExaminationClass(
                    examination_id=db_obj.id,
                    class_id=cid,
                    tenant_id=tenant_id,
                    school_id=obj_in.school_id
                )
                self.db.add(ec)

        return db_obj

    async def update(
        self, db_obj: Examination, update_data: dict, updated_by: Optional[uuid.UUID] = None
    ) -> Examination:
        participating_class_ids = update_data.pop("participating_class_ids", None)
        for field, value in update_data.items():
            setattr(db_obj, field, value)
        db_obj.updated_by = updated_by
        self.db.add(db_obj)

        if participating_class_ids is not None:
            # Refresh participating classes
            stmt_del = select(ExaminationClass).where(ExaminationClass.examination_id == db_obj.id)
            res_del = await self.db.execute(stmt_del)
            for existing_ec in res_del.scalars().all():
                await self.db.delete(existing_ec)

            for cid in participating_class_ids:
                ec = ExaminationClass(
                    examination_id=db_obj.id,
                    class_id=cid,
                    tenant_id=db_obj.tenant_id,
                    school_id=db_obj.school_id
                )
                self.db.add(ec)

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
        class_id: Optional[uuid.UUID] = None,
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
            selectinload(Examination.schedules).joinedload(ExamSchedule.subject),
            selectinload(Examination.schedules).joinedload(ExamSchedule.class_obj),
            selectinload(Examination.schedules).joinedload(ExamSchedule.section),
            selectinload(Examination.participating_classes)
        ).order_by(
            Examination.start_date.desc()
        ).offset(skip).limit(limit)
        
        result = await self.db.execute(stmt)
        exams = list(result.unique().scalars().all())

        if class_id:
            # Filter to exams that include class_id in participating_classes or have no class restrictions
            exams = [e for e in exams if not e.participating_classes or any(pc.class_id == class_id for pc in e.participating_classes)]

        return exams

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

        student_slots = []
        for sg in guardian.students:
            student = sg.student
            if student and student.is_active and not student.deleted_at:
                student_slots.append((student.class_id, student.section_id))

        if not student_slots:
            return []

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

    async def get_by_id(
        self, schedule_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[ExamSchedule]:
        stmt = select(ExamSchedule).where(
            ExamSchedule.id == schedule_id,
            ExamSchedule.school_id == school_id,
            ExamSchedule.tenant_id == tenant_id,
            ExamSchedule.deleted_at.is_(None)
        ).options(
            joinedload(ExamSchedule.class_obj),
            joinedload(ExamSchedule.section),
            joinedload(ExamSchedule.subject)
        )
        result = await self.db.execute(stmt)
        return result.unique().scalar_one_or_none()

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
            ExamSchedule.start_time < end_time,
            ExamSchedule.end_time > start_time
        ]
        if exclude_schedule_id:
            filters.append(ExamSchedule.id != exclude_schedule_id)

        stmt = select(exists().where(and_(*filters)))
        result = await self.db.execute(stmt)
        return bool(result.scalar())

    async def check_duplicate_subject(
        self,
        exam_id: uuid.UUID,
        class_id: uuid.UUID,
        section_id: uuid.UUID,
        subject_id: uuid.UUID,
        exclude_schedule_id: Optional[uuid.UUID] = None
    ) -> bool:
        """
        Returns True if this subject is already scheduled in this exam for this class/section.
        """
        filters = [
            ExamSchedule.exam_id == exam_id,
            ExamSchedule.class_id == class_id,
            ExamSchedule.section_id == section_id,
            ExamSchedule.subject_id == subject_id,
            ExamSchedule.deleted_at.is_(None)
        ]
        if exclude_schedule_id:
            filters.append(ExamSchedule.id != exclude_schedule_id)

        stmt = select(exists().where(and_(*filters)))
        result = await self.db.execute(stmt)
        return bool(result.scalar())

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
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        exam_id: uuid.UUID,
        obj_in: ExamScheduleCreate,
        created_by: Optional[uuid.UUID] = None
    ) -> ExamSchedule:
        db_obj = ExamSchedule(
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=academic_year_id,
            exam_id=exam_id,
            class_id=obj_in.class_id,
            section_id=obj_in.section_id,
            subject_id=obj_in.subject_id,
            teacher_subject_assignment_id=obj_in.teacher_subject_assignment_id,
            exam_date=obj_in.exam_date,
            start_time=obj_in.start_time,
            end_time=obj_in.end_time,
            max_marks=obj_in.max_marks,
            pass_marks=obj_in.pass_marks,
            room_number=obj_in.room_number,
            created_by=created_by,
            updated_by=created_by
        )
        self.db.add(db_obj)
        return db_obj

    async def update(
        self, db_obj: ExamSchedule, update_data: dict, updated_by: Optional[uuid.UUID] = None
    ) -> ExamSchedule:
        for field, value in update_data.items():
            if value is not None:
                setattr(db_obj, field, value)
        db_obj.updated_by = updated_by
        self.db.add(db_obj)
        return db_obj

    async def delete(self, db_obj: ExamSchedule, deleted_by: Optional[uuid.UUID] = None) -> None:
        now = datetime.now(timezone.utc)
        db_obj.deleted_at = now
        db_obj.is_active = False
        db_obj.updated_by = deleted_by
        self.db.add(db_obj)

    async def get_multi(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        exam_id: Optional[uuid.UUID] = None,
        class_id: Optional[uuid.UUID] = None,
        section_id: Optional[uuid.UUID] = None,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        skip: int = 0,
        limit: int = 500
    ) -> List[ExamSchedule]:
        filters = [
            ExamSchedule.school_id == school_id,
            ExamSchedule.tenant_id == tenant_id,
            ExamSchedule.deleted_at.is_(None)
        ]
        if exam_id:
            filters.append(ExamSchedule.exam_id == exam_id)
        if class_id:
            filters.append(ExamSchedule.class_id == class_id)
        if section_id:
            filters.append(ExamSchedule.section_id == section_id)
        if start_date:
            filters.append(ExamSchedule.exam_date >= start_date)
        if end_date:
            filters.append(ExamSchedule.exam_date <= end_date)

        stmt = select(ExamSchedule).where(and_(*filters)).options(
            joinedload(ExamSchedule.class_obj),
            joinedload(ExamSchedule.section),
            joinedload(ExamSchedule.subject),
            joinedload(ExamSchedule.examination)
        ).order_by(
            ExamSchedule.exam_date.asc(), ExamSchedule.start_time.asc()
        ).offset(skip).limit(limit)

        res = await self.db.execute(stmt)
        return list(res.unique().scalars().all())
