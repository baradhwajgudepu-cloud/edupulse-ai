import uuid
from datetime import date, time, datetime, timedelta, timezone
from typing import List, Optional, Dict, Any
from fastapi import HTTPException, status
from sqlalchemy import select

from app.models.examination import ExamTemplate, Examination, ExamSchedule, ExamStatus, ExamType
from app.models.teacher_subject_assignment import TeacherSubjectAssignment
from app.models.user import User
from app.repositories.examination import ExamTemplateRepository, ExaminationRepository, ExamScheduleRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.teacher_subject_assignment import TeacherSubjectAssignmentRepository
from app.schemas.examination import (
    ExamTemplateCreate, ExamTemplateUpdate,
    ExaminationCreate, ExaminationUpdate,
    ExaminationWizardCreate, ExaminationCopyRequest,
    ExamScheduleCreate
)

class ExaminationService:
    def __init__(
        self,
        template_repo: ExamTemplateRepository,
        exam_repo: ExaminationRepository,
        schedule_repo: ExamScheduleRepository,
        school_repo: SchoolRepository,
        academic_year_repo: AcademicYearRepository,
        tsa_repo: TeacherSubjectAssignmentRepository
    ) -> None:
        self.template_repo = template_repo
        self.exam_repo = exam_repo
        self.schedule_repo = schedule_repo
        self.school_repo = school_repo
        self.academic_year_repo = academic_year_repo
        self.tsa_repo = tsa_repo

    # ==================================================
    # Templates Workflows
    # ==================================================
    async def create_template(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        obj_in: ExamTemplateCreate,
        current_user: User
    ) -> ExamTemplate:
        # Check active academic year
        ay = await self.academic_year_repo.get_by_id(academic_year_id, school_id, tenant_id)
        if not ay or ay.status.value != "ACTIVE":
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Active academic year not found."
            )

        db_obj = await self.template_repo.create(
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=academic_year_id,
            obj_in=obj_in,
            created_by=current_user.id
        )
        await self.template_repo.db.commit()
        await self.template_repo.db.refresh(db_obj)
        return db_obj

    # ==================================================
    # Examination Standard Workflows
    # ==================================================
    async def create_examination(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, obj_in: ExaminationCreate, current_user: User
    ) -> Examination:
        # 1. Date Validation
        if obj_in.end_date < obj_in.start_date:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Exam end date cannot be earlier than start date."
            )

        # 2. Scoping Existential Checks
        school = await self.school_repo.get_by_id(school_id, tenant_id)
        if not school or not school.is_active:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Active school entity not found."
            )

        ay = await self.academic_year_repo.get_by_id(obj_in.academic_year_id, school_id, tenant_id)
        if not ay or ay.status.value != "ACTIVE":
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Active academic year entity not found."
            )

        # 3. Containment Check: Exam start/end must lie within academic year start/end dates
        if obj_in.start_date < ay.start_date or obj_in.end_date > ay.end_date:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Exam dates must lie within the academic year bounds ({ay.start_date} to {ay.end_date})."
            )

        # 4. Duplicate Check
        dup = await self.exam_repo.get_duplicate(obj_in.exam_name, obj_in.academic_year_id, school_id, tenant_id)
        if dup:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="An examination with this name already exists in the academic year."
            )

        db_obj = await self.exam_repo.create(tenant_id, obj_in, created_by=current_user.id)
        await self.exam_repo.db.commit()
        return await self.exam_repo.get_by_id(db_obj.id, school_id, tenant_id)

    async def update_examination(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        exam_id: uuid.UUID,
        obj_in: ExaminationUpdate,
        current_user: User
    ) -> Examination:
        db_obj = await self.exam_repo.get_by_id(exam_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_440_NOT_FOUND if hasattr(status, "HTTP_440_NOT_FOUND") else 404,
                detail="Examination entity not found."
            )

        # 1. Freeze Lock Verification
        if db_obj.status in [ExamStatus.LOCKED, ExamStatus.COMPLETED, ExamStatus.ARCHIVED]:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Cannot modify exam details or schedule because the examination is frozen."
            )

        update_data = obj_in.model_dump(exclude_unset=True)

        # 2. Date Boundary Checks
        start = update_data.get("start_date", db_obj.start_date)
        end = update_data.get("end_date", db_obj.end_date)
        if end < start:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Exam end date cannot be earlier than start date."
            )

        # Containment Check
        ay = await self.academic_year_repo.get_by_id(db_obj.academic_year_id, school_id, tenant_id)
        if start < ay.start_date or end > ay.end_date:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Exam dates must lie within the academic year bounds ({ay.start_date} to {ay.end_date})."
            )

        await self.exam_repo.update(db_obj, update_data, updated_by=current_user.id)
        await self.exam_repo.db.commit()
        return await self.exam_repo.get_by_id(exam_id, school_id, tenant_id)

    async def publish_examination(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, exam_id: uuid.UUID, current_user: User
    ) -> Examination:
        db_obj = await self.exam_repo.get_by_id(exam_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Examination not found."
            )

        # Transition to PUBLISHED status
        update_data = {"status": ExamStatus.PUBLISHED}
        await self.exam_repo.update(db_obj, update_data, updated_by=current_user.id)
        await self.exam_repo.db.commit()
        return await self.exam_repo.get_by_id(exam_id, school_id, tenant_id)

    async def delete_examination(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, exam_id: uuid.UUID, current_user: User
    ) -> Examination:
        db_obj = await self.exam_repo.get_by_id(exam_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Examination not found."
            )

        if db_obj.status in [ExamStatus.LOCKED, ExamStatus.COMPLETED, ExamStatus.ARCHIVED]:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Cannot delete examination when status is locked, completed, or archived."
            )

        await self.exam_repo.soft_delete(db_obj, deleted_by=current_user.id)
        await self.exam_repo.db.commit()
        return db_obj

    # ==================================================
    # Wizard Workflows
    # ==================================================
    async def suggest_wizard_schedules(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        class_ids: List[uuid.UUID],
        start_date: date,
        end_date: date
    ) -> List[Dict[str, Any]]:
        """
        UX Auto-loader: Queries TSAs for target classes, generates sequentially suggested paper schedules.
        """
        # Fetch active assignments for chosen classes
        stmt = select(TeacherSubjectAssignment).where(
            TeacherSubjectAssignment.class_id.in_(class_ids),
            TeacherSubjectAssignment.school_id == school_id,
            TeacherSubjectAssignment.tenant_id == tenant_id,
            TeacherSubjectAssignment.is_active == True,
            TeacherSubjectAssignment.deleted_at.is_(None)
        )
        res = await self.exam_repo.db.execute(stmt)
        assignments = list(res.scalars().all())

        suggestions = []
        current_date = start_date
        
        # Sequentially map assignments to dates (wrapping inside start/end range)
        for i, tsa in enumerate(assignments):
            paper_date = current_date + timedelta(days=(i // 2)) # 2 exams max per day
            if paper_date > end_date:
                paper_date = end_date # Clamp to end date

            # Toggle morning vs afternoon slot
            start_time = time(9, 0) if (i % 2 == 0) else time(13, 30)
            end_time = time(12, 0) if (i % 2 == 0) else time(16, 30)

            suggestions.append({
                "class_id": str(tsa.class_id),
                "section_id": str(tsa.section_id),
                "subject_id": str(tsa.subject_id),
                "teacher_subject_assignment_id": str(tsa.id),
                "exam_date": paper_date.isoformat(),
                "start_time": start_time.strftime("%H:%M:%S"),
                "end_time": end_time.strftime("%H:%M:%S"),
                "max_marks": 100,
                "pass_marks": 35,
                "room_number": f"Hall {101 + (i % 3)}"
            })

        return suggestions

    async def create_examination_wizard(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, obj_in: ExaminationWizardCreate, current_user: User
    ) -> Examination:
        # 1. Create standard master examination
        master_create = ExaminationCreate(
            school_id=school_id,
            academic_year_id=obj_in.academic_year_id,
            exam_name=obj_in.exam_name,
            exam_type=obj_in.exam_type,
            start_date=obj_in.start_date,
            end_date=obj_in.end_date,
            description=obj_in.description,
            settings=obj_in.settings
        )
        
        exam_master = await self.create_examination(tenant_id, school_id, master_create, current_user)

        # 2. Iterate and validate schedules
        for sched in obj_in.schedules:
            # Date containment check: sched date falls within exam start/end dates
            if sched.exam_date < exam_master.start_date or sched.exam_date > exam_master.end_date:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"Schedule date {sched.exam_date} falls outside examination dates range ({exam_master.start_date} to {exam_master.end_date})."
                )

            # Timings checks
            if sched.end_time <= sched.start_time:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="Schedule end time must be later than start time."
                )

            # TSA checks
            tsa = await self.tsa_repo.get_by_id(sched.teacher_subject_assignment_id, school_id, tenant_id)
            if not tsa or not tsa.is_active:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"Active Teacher Subject Assignment not found for ID: {sched.teacher_subject_assignment_id}"
                )

            if tsa.class_id != sched.class_id or tsa.section_id != sched.section_id or tsa.subject_id != sched.subject_id:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="Teacher Subject Assignment parameters do not match class/section/subject mappings."
                )

            # Clash Detection 1: Class booking conflict
            class_clash = await self.schedule_repo.check_class_overlap(
                class_id=sched.class_id,
                section_id=sched.section_id,
                exam_date=sched.exam_date,
                start_time=sched.start_time,
                end_time=sched.end_time
            )
            if class_clash:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"Scheduling conflict: Class is already scheduled for another paper at this time slot ({sched.exam_date} {sched.start_time}-{sched.end_time})."
                )

            # Clash Detection 2: Teacher booking conflict
            teacher_clash = await self.schedule_repo.check_teacher_overlap(
                teacher_id=tsa.teacher_id,
                exam_date=sched.exam_date,
                start_time=sched.start_time,
                end_time=sched.end_time
            )
            if teacher_clash:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"Scheduling conflict: Teacher is already invigilating another exam paper at this time slot ({sched.exam_date} {sched.start_time}-{sched.end_time})."
                )

            # Create transient Schedule entry
            db_sched = ExamSchedule(
                tenant_id=tenant_id,
                school_id=school_id,
                academic_year_id=obj_in.academic_year_id,
                exam_id=exam_master.id,
                class_id=sched.class_id,
                section_id=sched.section_id,
                subject_id=sched.subject_id,
                teacher_subject_assignment_id=sched.teacher_subject_assignment_id,
                exam_date=sched.exam_date,
                start_time=sched.start_time,
                end_time=sched.end_time,
                max_marks=sched.max_marks,
                pass_marks=sched.pass_marks,
                room_number=sched.room_number,
                created_by=current_user.id,
                updated_by=current_user.id
            )
            self.schedule_repo.db.add(db_sched)

        exam_id = exam_master.id
        await self.schedule_repo.db.commit()
        self.exam_repo.db.expire(exam_master)
        return await self.exam_repo.get_by_id(exam_id, school_id, tenant_id)

    # ==================================================
    # Exam Copy Shift dates Workflows
    # ==================================================
    async def copy_examination(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        obj_in: ExaminationCopyRequest,
        current_user: User
    ) -> Examination:
        source_exam = await self.exam_repo.get_by_id(obj_in.source_exam_id, school_id, tenant_id)
        if not source_exam:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Source examination not found."
            )

        # 1. Verify date bounds range
        if obj_in.new_end_date < obj_in.new_start_date:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="New exam end date cannot be earlier than start date."
            )

        # Duplicate check on name
        dup = await self.exam_repo.get_duplicate(obj_in.new_exam_name, source_exam.academic_year_id, school_id, tenant_id)
        if dup:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="An examination with this name already exists in the academic year."
            )

        # Compute date offset (days delta)
        date_offset = obj_in.new_start_date - source_exam.start_date

        # Create master exam copy
        new_master = Examination(
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=source_exam.academic_year_id,
            exam_name=obj_in.new_exam_name,
            exam_type=source_exam.exam_type,
            start_date=obj_in.new_start_date,
            end_date=obj_in.new_end_date,
            status=ExamStatus.DRAFT,
            description=source_exam.description,
            settings={"copied_from_template": False},
            ai_metrics={
                "predicted_completion": None,
                "exam_complexity": None,
                "student_risk_prediction": None,
                "average_expected_score": None
            },
            created_by=current_user.id,
            updated_by=current_user.id
        )
        self.exam_repo.db.add(new_master)
        
        # Flush to get the new exam UUID
        await self.exam_repo.db.flush()

        # Copy child schedules by applying dates delta shift
        for sched in source_exam.schedules:
            shifted_date = sched.exam_date + date_offset
            
            # Bound shift check
            if shifted_date < new_master.start_date or shifted_date > new_master.end_date:
                # clamp to bounds
                shifted_date = new_master.end_date

            # Conflict checks
            class_clash = await self.schedule_repo.check_class_overlap(
                class_id=sched.class_id,
                section_id=sched.section_id,
                exam_date=shifted_date,
                start_time=sched.start_time,
                end_time=sched.end_time
            )
            if class_clash:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"Cloning failed due to overlapping class schedule clash on {shifted_date}."
                )

            # Create schedule copy
            db_sched = ExamSchedule(
                tenant_id=tenant_id,
                school_id=school_id,
                academic_year_id=source_exam.academic_year_id,
                exam_id=new_master.id,
                class_id=sched.class_id,
                section_id=sched.section_id,
                subject_id=sched.subject_id,
                teacher_subject_assignment_id=sched.teacher_subject_assignment_id,
                exam_date=shifted_date,
                start_time=sched.start_time,
                end_time=sched.end_time,
                max_marks=sched.max_marks,
                pass_marks=sched.pass_marks,
                room_number=sched.room_number,
                created_by=current_user.id,
                updated_by=current_user.id
            )
            self.schedule_repo.db.add(db_sched)

        new_exam_id = new_master.id
        await self.exam_repo.db.commit()
        self.exam_repo.db.expire(new_master)
        return await self.exam_repo.get_by_id(new_exam_id, school_id, tenant_id)
