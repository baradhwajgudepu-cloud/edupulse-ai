import uuid
from datetime import date, time, datetime, timedelta, timezone
from typing import List, Optional, Dict, Any
from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import joinedload

from app.models.examination import (
    ExamTypeMaster, ExamTemplate, Examination, ExamSchedule,
    ExaminationClass, ExamStatus, ExamType, ExamTypeCategory
)
from app.models.teacher_subject_assignment import TeacherSubjectAssignment
from app.models.class_entity import Class
from app.models.section import Section
from app.models.subject import Subject
from app.models.user import User
from app.repositories.examination import (
    ExamTypeMasterRepository, ExamTemplateRepository,
    ExaminationRepository, ExamScheduleRepository
)
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.teacher_subject_assignment import TeacherSubjectAssignmentRepository
from app.schemas.examination import (
    ExamTypeMasterCreate, ExamTypeMasterUpdate,
    ExamTemplateCreate, ExamTemplateUpdate,
    ExaminationCreate, ExaminationUpdate,
    ExamStatusTransitionRequest,
    ExaminationWizardCreate, ExaminationCopyRequest,
    ExamScheduleCreate, ExamScheduleUpdate,
    BulkTimetablePreviewRequest, BulkTimetablePreviewItem, BulkTimetablePreviewResponse,
    BulkTimetableConfirmRequest
)

ALLOWED_TRANSITIONS = {
    ExamStatus.DRAFT: [ExamStatus.SCHEDULED],
    ExamStatus.SCHEDULED: [ExamStatus.DRAFT, ExamStatus.ONGOING],
    ExamStatus.ONGOING: [ExamStatus.MARKS_ENTRY],
    ExamStatus.MARKS_ENTRY: [ExamStatus.UNDER_REVIEW],
    ExamStatus.UNDER_REVIEW: [ExamStatus.MARKS_ENTRY, ExamStatus.APPROVED],
    ExamStatus.APPROVED: [ExamStatus.PUBLISHED],
    ExamStatus.PUBLISHED: [ExamStatus.COMPLETED],
    ExamStatus.COMPLETED: [ExamStatus.ARCHIVED],
    ExamStatus.ARCHIVED: []
}

class ExaminationService:
    def __init__(
        self,
        type_repo: ExamTypeMasterRepository,
        template_repo: ExamTemplateRepository,
        exam_repo: ExaminationRepository,
        schedule_repo: ExamScheduleRepository,
        school_repo: SchoolRepository,
        academic_year_repo: AcademicYearRepository,
        tsa_repo: TeacherSubjectAssignmentRepository
    ) -> None:
        self.type_repo = type_repo
        self.template_repo = template_repo
        self.exam_repo = exam_repo
        self.schedule_repo = schedule_repo
        self.school_repo = school_repo
        self.academic_year_repo = academic_year_repo
        self.tsa_repo = tsa_repo

    # ==================================================
    # Exam Types Workflows
    # ==================================================
    async def list_exam_types(
        self, tenant_id: uuid.UUID, school_id: Optional[uuid.UUID] = None, skip: int = 0, limit: int = 100
    ) -> List[ExamTypeMaster]:
        items = await self.type_repo.get_multi(tenant_id, school_id, skip, limit)
        if not items:
            # Seed default system exam types on first query
            defaults = [
                {"name": "Unit Test", "code": "UNIT_TEST", "category": ExamTypeCategory.SCHOLASTIC, "default_weightage": 20.0},
                {"name": "Weekly Test", "code": "WEEKLY_TEST", "category": ExamTypeCategory.SCHOLASTIC, "default_weightage": 10.0},
                {"name": "Monthly Test", "code": "MONTHLY", "category": ExamTypeCategory.SCHOLASTIC, "default_weightage": 25.0},
                {"name": "Quarterly Examination", "code": "QUARTERLY", "category": ExamTypeCategory.SCHOLASTIC, "default_weightage": 50.0},
                {"name": "Half-Yearly Examination", "code": "HALF_YEARLY", "category": ExamTypeCategory.SCHOLASTIC, "default_weightage": 80.0},
                {"name": "Pre-Final Examination", "code": "PRE_FINAL", "category": ExamTypeCategory.SCHOLASTIC, "default_weightage": 100.0},
                {"name": "Annual / Final Examination", "code": "ANNUAL", "category": ExamTypeCategory.SCHOLASTIC, "default_weightage": 100.0},
                {"name": "Practical Examination", "code": "PRACTICAL", "category": ExamTypeCategory.PRACTICAL, "default_weightage": 50.0},
                {"name": "Internal Assessment", "code": "INTERNAL_ASSESSMENT", "category": ExamTypeCategory.INTERNAL_ASSESSMENT, "default_weightage": 30.0},
            ]
            for d in defaults:
                db_t = ExamTypeMaster(
                    tenant_id=tenant_id,
                    school_id=school_id,
                    name=d["name"],
                    code=d["code"],
                    description=f"Standard {d['name']}",
                    category=d["category"],
                    default_weightage=d["default_weightage"],
                    is_system=True,
                    is_active=True
                )
                self.type_repo.db.add(db_t)
            await self.type_repo.db.commit()
            items = await self.type_repo.get_multi(tenant_id, school_id, skip, limit)
        return items

    async def get_exam_type(
        self, tenant_id: uuid.UUID, school_id: Optional[uuid.UUID], id: uuid.UUID
    ) -> ExamTypeMaster:
        db_obj = await self.type_repo.get_by_id(id, tenant_id, school_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Exam type master entity not found."
            )
        return db_obj

    async def create_exam_type(
        self, tenant_id: uuid.UUID, obj_in: ExamTypeMasterCreate, current_user: User
    ) -> ExamTypeMaster:
        existing = await self.type_repo.get_by_code(obj_in.code.upper(), tenant_id, obj_in.school_id)
        if existing:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"An exam type with code '{obj_in.code.upper()}' already exists."
            )
        db_obj = await self.type_repo.create(tenant_id, obj_in, created_by=current_user.id)
        await self.type_repo.db.commit()
        await self.type_repo.db.refresh(db_obj)
        return db_obj

    async def update_exam_type(
        self, tenant_id: uuid.UUID, school_id: Optional[uuid.UUID], id: uuid.UUID, obj_in: ExamTypeMasterUpdate, current_user: User
    ) -> ExamTypeMaster:
        db_obj = await self.get_exam_type(tenant_id, school_id, id)
        update_data = obj_in.model_dump(exclude_unset=True)
        await self.type_repo.update(db_obj, update_data, updated_by=current_user.id)
        await self.type_repo.db.commit()
        await self.type_repo.db.refresh(db_obj)
        return db_obj

    async def delete_exam_type(
        self, tenant_id: uuid.UUID, school_id: Optional[uuid.UUID], id: uuid.UUID, current_user: User
    ) -> ExamTypeMaster:
        db_obj = await self.get_exam_type(tenant_id, school_id, id)
        is_ref = await self.type_repo.is_referenced(db_obj.code, tenant_id, school_id)
        if is_ref:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Cannot delete exam type because it is referenced by existing examinations."
            )
        await self.type_repo.delete(db_obj)
        await self.type_repo.db.commit()
        return db_obj

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

        if not obj_in.academic_year_id:
            from app.models.academic_year import AcademicYear, AcademicYearStatus
            ay_stmt = select(AcademicYear).where(
                AcademicYear.school_id == school_id,
                AcademicYear.status == AcademicYearStatus.ACTIVE,
                AcademicYear.deleted_at.is_(None)
            )
            ay_res = await self.exam_repo.db.execute(ay_stmt)
            ay = ay_res.scalars().first()
            if not ay:
                ay_stmt_fallback = select(AcademicYear).where(
                    AcademicYear.school_id == school_id,
                    AcademicYear.deleted_at.is_(None)
                )
                ay_res_fallback = await self.exam_repo.db.execute(ay_stmt_fallback)
                ay = ay_res_fallback.scalars().first()
                if not ay:
                    raise HTTPException(
                        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                        detail="No academic year found for this school."
                    )
            obj_in.academic_year_id = ay.id

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
                status_code=status.HTTP_404_NOT_FOUND,
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

    # ==================================================
    # Examination Status Lifecycle Workflows
    # ==================================================
    async def transition_exam_status(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        exam_id: uuid.UUID,
        req: ExamStatusTransitionRequest,
        current_user: User
    ) -> Examination:
        db_obj = await self.exam_repo.get_by_id(exam_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Examination not found."
            )

        current_status = db_obj.status
        target_status = req.new_status

        if current_status == target_status:
            return db_obj

        if req.is_administrative_override:
            if not req.reason or len(req.reason.strip()) == 0:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="Administrative status override requires a mandatory justification reason."
                )
        else:
            allowed = ALLOWED_TRANSITIONS.get(current_status, [])
            if target_status not in allowed:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"Invalid examination status transition from {current_status.value} to {target_status.value}. Allowed transitions: {[s.value for s in allowed]}"
                )

            # Pre-condition check for SCHEDULED: must have participating classes
            if target_status == ExamStatus.SCHEDULED:
                if len(db_obj.participating_classes) == 0:
                    raise HTTPException(
                        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                        detail="Add participating classes before scheduling examination papers."
                    )

        # Record audit trail
        history = list(db_obj.settings.get("status_audit_trail", []))
        history.append({
            "from_status": current_status.value,
            "to_status": target_status.value,
            "is_override": req.is_administrative_override,
            "reason": req.reason or "Standard lifecycle progression",
            "transitioned_by": str(current_user.id),
            "transitioned_at": datetime.now(timezone.utc).isoformat()
        })
        db_obj.settings["status_audit_trail"] = history
        db_obj.status = target_status
        db_obj.updated_by = current_user.id
        self.exam_repo.db.add(db_obj)
        await self.exam_repo.db.commit()

        # If transitioning to PUBLISHED, attempt notification dispatch safely without breaking transaction
        if target_status == ExamStatus.PUBLISHED:
            try:
                from app.services.notification import get_notification_service
                notif_service = get_notification_service(self.exam_repo.db)
                await notif_service.notify_examination_published(tenant_id, school_id, exam_id)
            except Exception:
                pass

        return await self.exam_repo.get_by_id(exam_id, school_id, tenant_id)

    async def publish_examination(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, exam_id: uuid.UUID, current_user: User
    ) -> Examination:
        req = ExamStatusTransitionRequest(new_status=ExamStatus.PUBLISHED, is_administrative_override=True, reason="Direct publish trigger")
        return await self.transition_exam_status(tenant_id, school_id, exam_id, req, current_user)

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
        academic_year_id: Optional[uuid.UUID],
        class_ids: List[uuid.UUID],
        start_date: date,
        end_date: date
    ) -> List[Dict[str, Any]]:
        """
        UX Auto-loader: Queries TSAs for target classes, generates sequentially suggested paper schedules.
        """
        # Fetch active assignments for chosen classes
        from sqlalchemy.orm import selectinload
        stmt = select(TeacherSubjectAssignment).where(
            TeacherSubjectAssignment.class_id.in_(class_ids),
            TeacherSubjectAssignment.school_id == school_id,
            TeacherSubjectAssignment.tenant_id == tenant_id,
            TeacherSubjectAssignment.is_active == True,
            TeacherSubjectAssignment.deleted_at.is_(None)
        ).options(
            selectinload(TeacherSubjectAssignment.subject),
            selectinload(TeacherSubjectAssignment.class_obj),
            selectinload(TeacherSubjectAssignment.section)
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
                "class_name": tsa.class_obj.name if tsa.class_obj else "Class",
                "section_id": str(tsa.section_id),
                "section_name": tsa.section.name if tsa.section else "Section",
                "subject_id": str(tsa.subject_id),
                "subject_name": tsa.subject.subject_name if tsa.subject else "Subject",
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
        # Resolve target scoping metadata into settings dict
        settings = dict(obj_in.settings or {})
        settings["target_scope"] = obj_in.target_scope
        
        if obj_in.target_scope == "ALL_CLASSES":
            from app.models.class_entity import Class, ClassStatus
            classes_stmt = select(Class).where(
                Class.school_id == school_id,
                Class.status == ClassStatus.ACTIVE,
                Class.deleted_at.is_(None)
            )
            classes_res = await self.exam_repo.db.execute(classes_stmt)
            resolved_class_ids = [c.id for c in classes_res.scalars().all()]
            settings["class_ids"] = [str(cid) for cid in resolved_class_ids]
        elif obj_in.target_scope == "SPECIFIC_CLASSES":
            settings["class_ids"] = [str(cid) for cid in (obj_in.class_ids or [])]
        elif obj_in.target_scope == "SPECIFIC_SECTIONS":
            settings["section_ids"] = [str(sid) for sid in (obj_in.section_ids or [])]

        # 1. Create standard master examination
        master_create = ExaminationCreate(
            school_id=school_id,
            academic_year_id=obj_in.academic_year_id,
            exam_name=obj_in.exam_name,
            exam_type=obj_in.exam_type,
            start_date=obj_in.start_date,
            end_date=obj_in.end_date,
            description=obj_in.description,
            settings=settings
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

    # ==================================================
    # Timetable & Schedule Workflows
    # ==================================================
    async def list_schedules(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        exam_id: Optional[uuid.UUID] = None,
        class_id: Optional[uuid.UUID] = None,
        section_id: Optional[uuid.UUID] = None,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        skip: int = 0,
        limit: int = 500
    ) -> List[ExamSchedule]:
        return await self.schedule_repo.get_multi(
            school_id=school_id,
            tenant_id=tenant_id,
            exam_id=exam_id,
            class_id=class_id,
            section_id=section_id,
            start_date=start_date,
            end_date=end_date,
            skip=skip,
            limit=limit
        )

    async def create_schedule(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        exam_id: uuid.UUID,
        obj_in: ExamScheduleCreate,
        current_user: User
    ) -> ExamSchedule:
        exam = await self.exam_repo.get_by_id(exam_id, school_id, tenant_id)
        if not exam:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Examination not found.")

        if exam.status in [ExamStatus.LOCKED, ExamStatus.COMPLETED, ExamStatus.ARCHIVED]:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Cannot add schedule to a frozen or completed examination."
            )

        # 1. Date containment check
        if obj_in.exam_date < exam.start_date or obj_in.exam_date > exam.end_date:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Schedule date {obj_in.exam_date} falls outside examination dates range ({exam.start_date} to {exam.end_date})."
            )

        # 2. Timing check
        if obj_in.end_time <= obj_in.start_time:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Schedule end time must be later than start time."
            )

        # 3. Duplicate subject check in same exam
        dup_sub = await self.schedule_repo.check_duplicate_subject(
            exam_id=exam_id,
            class_id=obj_in.class_id,
            section_id=obj_in.section_id,
            subject_id=obj_in.subject_id
        )
        if dup_sub:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Duplicate schedule: This subject is already scheduled for this class and section in this examination."
            )

        # 4. Class timing overlap check
        class_clash = await self.schedule_repo.check_class_overlap(
            class_id=obj_in.class_id,
            section_id=obj_in.section_id,
            exam_date=obj_in.exam_date,
            start_time=obj_in.start_time,
            end_time=obj_in.end_time
        )
        if class_clash:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Scheduling conflict: Class/Section already has an examination paper at this time slot ({obj_in.exam_date} {obj_in.start_time}-{obj_in.end_time})."
            )

        db_obj = await self.schedule_repo.create(
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=exam.academic_year_id,
            exam_id=exam_id,
            obj_in=obj_in,
            created_by=current_user.id
        )
        await self.schedule_repo.db.commit()
        return await self.schedule_repo.get_by_id(db_obj.id, school_id, tenant_id)

    async def update_schedule(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        schedule_id: uuid.UUID,
        obj_in: ExamScheduleUpdate,
        current_user: User
    ) -> ExamSchedule:
        db_sched = await self.schedule_repo.get_by_id(schedule_id, school_id, tenant_id)
        if not db_sched:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Exam schedule not found.")

        exam = await self.exam_repo.get_by_id(db_sched.exam_id, school_id, tenant_id)
        if exam.status in [ExamStatus.LOCKED, ExamStatus.COMPLETED, ExamStatus.ARCHIVED]:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Cannot modify schedule of a frozen or completed examination."
            )

        update_data = obj_in.model_dump(exclude_unset=True)
        exam_date = update_data.get("exam_date", db_sched.exam_date)
        start_time = update_data.get("start_time", db_sched.start_time)
        end_time = update_data.get("end_time", db_sched.end_time)

        if end_time <= start_time:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Schedule end time must be later than start time."
            )

        if exam_date < exam.start_date or exam_date > exam.end_date:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Schedule date {exam_date} falls outside examination dates range ({exam.start_date} to {exam.end_date})."
            )

        class_clash = await self.schedule_repo.check_class_overlap(
            class_id=db_sched.class_id,
            section_id=db_sched.section_id,
            exam_date=exam_date,
            start_time=start_time,
            end_time=end_time,
            exclude_schedule_id=schedule_id
        )
        if class_clash:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Scheduling conflict: Class/Section already has an examination paper at this time slot ({exam_date} {start_time}-{end_time})."
            )

        await self.schedule_repo.update(db_sched, update_data, updated_by=current_user.id)
        await self.schedule_repo.db.commit()
        return await self.schedule_repo.get_by_id(schedule_id, school_id, tenant_id)

    async def delete_schedule(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        schedule_id: uuid.UUID,
        current_user: User
    ) -> None:
        db_sched = await self.schedule_repo.get_by_id(schedule_id, school_id, tenant_id)
        if not db_sched:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Exam schedule not found.")

        exam = await self.exam_repo.get_by_id(db_sched.exam_id, school_id, tenant_id)
        if exam.status in [ExamStatus.LOCKED, ExamStatus.COMPLETED, ExamStatus.ARCHIVED]:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Cannot delete schedule from a frozen or completed examination."
            )

        await self.schedule_repo.delete(db_sched, deleted_by=current_user.id)
        await self.schedule_repo.db.commit()

    # ==================================================
    # Bulk Timetable Auto-Generation Workflows
    # ==================================================
    async def preview_bulk_timetable(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        req: BulkTimetablePreviewRequest
    ) -> BulkTimetablePreviewResponse:
        exam = await self.exam_repo.get_by_id(req.examination_id, school_id, tenant_id)
        if not exam:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Examination not found.")

        stmt = select(TeacherSubjectAssignment).where(
            TeacherSubjectAssignment.class_id.in_(req.class_ids),
            TeacherSubjectAssignment.school_id == school_id,
            TeacherSubjectAssignment.tenant_id == tenant_id,
            TeacherSubjectAssignment.is_active == True,
            TeacherSubjectAssignment.deleted_at.is_(None)
        ).options(
            joinedload(TeacherSubjectAssignment.class_obj),
            joinedload(TeacherSubjectAssignment.section),
            joinedload(TeacherSubjectAssignment.subject)
        )
        if req.section_ids:
            stmt = stmt.where(TeacherSubjectAssignment.section_id.in_(req.section_ids))
        if req.subject_ids:
            stmt = stmt.where(TeacherSubjectAssignment.subject_id.in_(req.subject_ids))

        res = await self.schedule_repo.db.execute(stmt)
        tsas = list(res.scalars().all())

        start_time = req.start_time
        end_time = (datetime.combine(date.today(), start_time) + timedelta(minutes=req.duration_minutes)).time()

        grouped_by_class: Dict[uuid.UUID, List[TeacherSubjectAssignment]] = {}
        for tsa in tsas:
            grouped_by_class.setdefault(tsa.class_id, []).append(tsa)

        preview_items: List[BulkTimetablePreviewItem] = []

        for class_id, class_tsas in grouped_by_class.items():
            subject_map: Dict[uuid.UUID, List[TeacherSubjectAssignment]] = {}
            for tsa in class_tsas:
                subject_map.setdefault(tsa.subject_id, []).append(tsa)

            current_date = req.start_date
            for subject_id, sub_tsas in subject_map.items():
                if req.exclude_weekends:
                    while current_date.weekday() >= 5:
                        current_date += timedelta(days=1)

                seen_sections = set()
                for tsa in sub_tsas:
                    if tsa.section_id in seen_sections:
                        continue
                    seen_sections.add(tsa.section_id)

                    preview_items.append(BulkTimetablePreviewItem(
                        class_id=tsa.class_id,
                        class_name=tsa.class_obj.name if tsa.class_obj else "Class",
                        section_id=tsa.section_id,
                        section_name=tsa.section.name if tsa.section else "Section",
                        subject_id=tsa.subject_id,
                        subject_name=tsa.subject.subject_name if tsa.subject else "Subject",
                        teacher_subject_assignment_id=tsa.id,
                        exam_date=current_date,
                        start_time=start_time,
                        end_time=end_time,
                        max_marks=req.max_marks,
                        pass_marks=req.pass_marks,
                        room_number=None
                    ))

                current_date += timedelta(days=req.gap_days + 1)
                if req.exclude_weekends:
                    while current_date.weekday() >= 5:
                        current_date += timedelta(days=1)

        return BulkTimetablePreviewResponse(
            total_slots=len(preview_items),
            schedules=preview_items
        )

    async def confirm_bulk_timetable(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        req: BulkTimetableConfirmRequest,
        current_user: User
    ) -> List[ExamSchedule]:
        exam = await self.exam_repo.get_by_id(req.examination_id, school_id, tenant_id)
        if not exam:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Examination not found.")

        created_objs = []
        for sched_in in req.schedules:
            clash = await self.schedule_repo.check_class_overlap(
                class_id=sched_in.class_id,
                section_id=sched_in.section_id,
                exam_date=sched_in.exam_date,
                start_time=sched_in.start_time,
                end_time=sched_in.end_time
            )
            if clash:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"Clash detected for class/section on {sched_in.exam_date} {sched_in.start_time}-{sched_in.end_time}."
                )

            dup = await self.schedule_repo.check_duplicate_subject(
                exam_id=exam.id,
                class_id=sched_in.class_id,
                section_id=sched_in.section_id,
                subject_id=sched_in.subject_id
            )
            if dup:
                continue

            db_sched = await self.schedule_repo.create(
                tenant_id=tenant_id,
                school_id=school_id,
                academic_year_id=exam.academic_year_id,
                exam_id=exam.id,
                obj_in=sched_in,
                created_by=current_user.id
            )
            created_objs.append(db_sched)

        await self.schedule_repo.db.commit()
        return await self.schedule_repo.get_multi(school_id=school_id, tenant_id=tenant_id, exam_id=exam.id)
