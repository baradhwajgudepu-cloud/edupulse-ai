import uuid
import logging
from datetime import datetime, timezone, time, date
from typing import List, Optional, Dict, Any, Tuple
from fastapi import HTTPException, status
from sqlalchemy import select, or_, func
from sqlalchemy.orm import joinedload

from app.models.marks import Marks, MarksStatus, ExamResult
from app.models.teacher import Teacher, EmploymentType, TeacherStatus
from app.models.teacher_subject_assignment import TeacherSubjectAssignment, AssignmentType, AssignmentStatus
from app.models.student import Student, StudentGender
from app.models.examination import Examination, ExamSchedule, ExamStatus, ExaminationClass, ExamPaper, ExamPaperClass
from app.models.class_entity import Class
from app.models.section import Section
from app.models.subject import Subject
from app.models.user import User
from app.repositories.marks import MarksRepository
from app.repositories.examination import ExamScheduleRepository, ExaminationRepository
from app.repositories.student import StudentRepository
from app.repositories.teacher_subject_assignment import TeacherSubjectAssignmentRepository
from app.repositories.school import SchoolRepository
from app.schemas.marks import (
    BulkMarksEntry, SingleMarkEntry,
    SmartMissingSummary, MarkWizardItem, StudentShortInfo,
    PublishSummaryResponse, ResultSummaryResponse, MarksResponse,
    MarksReviewQueueItem, ParentExamResultResponse, ParentSubjectMarkItem,
    ParentTimetableSlot, ParentReportCardItem, MarksExcelUploadSummary,
    ExamWideUploadRowPreview, ExamWideUploadPreviewResponse,
    ExamWideUploadConfirmRequest, ExamWideUploadSummary, ExaminationPublishSummary,
    ClassAllSubjectsUploadSummary, ExaminationResultReadiness, StudentResultReadinessItem
)
from app.models.guardian import Guardian, StudentGuardian
from app.services.notification import NotificationService
from app.core.normalization import normalize_subject_header, format_subject_header

logger = logging.getLogger(__name__)


class ExamWideTemplateBytes(bytes):
    def __new__(cls, data: bytes, filename: Optional[str] = None, mime: Optional[str] = None):
        obj = super().__new__(cls, data)
        obj.filename = filename or "Exam_Marks_Template.xlsx"
        obj.mime = mime or "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        return obj

    def __iter__(self):
        # Support unpacking into (content, filename, mime) for test backward-compatibility
        return iter([bytes(self), self.filename, self.mime])


class MarksService:
    def __init__(
        self,
        marks_repo: Any = None,
        schedule_repo: Optional[ExamScheduleRepository] = None,
        exam_repo: Optional[ExaminationRepository] = None,
        student_repo: Optional[StudentRepository] = None,
        tsa_repo: Optional[TeacherSubjectAssignmentRepository] = None,
        school_repo: Optional[SchoolRepository] = None,
        notification_service: Optional[NotificationService] = None
    ) -> None:
        from sqlalchemy.ext.asyncio import AsyncSession
        if isinstance(marks_repo, AsyncSession):
            db = marks_repo
            self.marks_repo = MarksRepository(db)
            self.schedule_repo = schedule_repo or ExamScheduleRepository(db)
            self.exam_repo = exam_repo or ExaminationRepository(db)
            self.student_repo = student_repo or StudentRepository(db)
            self.tsa_repo = tsa_repo or TeacherSubjectAssignmentRepository(db)
            self.school_repo = school_repo or SchoolRepository(db)
            self.notification_service = notification_service
        else:
            self.marks_repo = marks_repo
            self.schedule_repo = schedule_repo
            self.exam_repo = exam_repo
            self.student_repo = student_repo
            self.tsa_repo = tsa_repo
            self.school_repo = school_repo
            self.notification_service = notification_service

    def _validate_marks_transition(self, current_status: MarksStatus, target_status: MarksStatus) -> None:
        """
        Canonical Marks Workflow State Machine:
        Allowed Transitions:
          DRAFT -> SUBMITTED
          RETURNED -> SUBMITTED
          SUBMITTED -> UNDER_REVIEW
          SUBMITTED -> APPROVED
          SUBMITTED -> RETURNED
          UNDER_REVIEW -> APPROVED
          UNDER_REVIEW -> RETURNED
          APPROVED -> PUBLISHED
          PUBLISHED -> LOCKED

        Self-transitions are allowed for idempotency.
        All other transitions raise 422 Unprocessable Content.
        """
        if current_status == target_status:
            return

        valid_transitions = {
            MarksStatus.DRAFT: {MarksStatus.SUBMITTED},
            MarksStatus.RETURNED: {MarksStatus.SUBMITTED},
            MarksStatus.SUBMITTED: {MarksStatus.UNDER_REVIEW, MarksStatus.APPROVED, MarksStatus.RETURNED},
            MarksStatus.UNDER_REVIEW: {MarksStatus.APPROVED, MarksStatus.RETURNED},
            MarksStatus.APPROVED: {MarksStatus.PUBLISHED},
            MarksStatus.PUBLISHED: {MarksStatus.LOCKED},
            MarksStatus.LOCKED: set(), # Locked marks are immutable and cannot transition
        }

        allowed = valid_transitions.get(current_status, set())
        if target_status not in allowed:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Illegal workflow transition from {current_status.value if hasattr(current_status, 'value') else current_status} to {target_status.value if hasattr(target_status, 'value') else target_status}."
            )

    async def get_wizard_entry(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, exam_schedule_id: uuid.UUID, current_user: User
    ) -> SmartMissingSummary:
        # 1. Fetch schedule
        stmt_s = select(ExamSchedule).where(
            ExamSchedule.id == exam_schedule_id,
            ExamSchedule.school_id == school_id,
            ExamSchedule.tenant_id == tenant_id,
            ExamSchedule.deleted_at.is_(None)
        ).options(joinedload(ExamSchedule.subject))
        res_s = await self.marks_repo.db.execute(stmt_s)
        sched = res_s.scalar_one_or_none()
        if not sched:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Exam schedule slot not found."
            )

        # 2. Fetch sorted class students list
        students = await self.marks_repo.get_class_students_sorted(sched.class_id, sched.section_id, school_id, tenant_id)

        # 3. Fetch existing mark records
        existing_marks = await self.marks_repo.get_by_schedule_id(exam_schedule_id, tenant_id)
        marks_map = {m.student_id: m for m in existing_marks}

        # 4. Compute statistics
        total = len(students)
        entered_count = 0
        scores = []
        missing_students = []
        wizard_items = []

        for student in students:
            record = marks_map.get(student.id)
            short_info = StudentShortInfo(
                id=student.id,
                first_name=student.first_name,
                last_name=student.last_name,
                roll_number=student.roll_number
            )
            
            if record:
                entered_count += 1
                if record.result_status in [ExamResult.PRESENT, ExamResult.EXEMPTED] and record.marks_obtained is not None:
                    scores.append(float(record.marks_obtained))
                
                wizard_items.append(MarkWizardItem(
                    student=short_info,
                    mark_record=MarksResponse.model_validate(record),
                    is_missing=False
                ))
            else:
                missing_students.append(short_info)
                wizard_items.append(MarkWizardItem(
                    student=short_info,
                    mark_record=None,
                    is_missing=True
                ))

        missing_count = total - entered_count
        avg = round(sum(scores) / len(scores), 2) if scores else None
        high = max(scores) if scores else None
        low = min(scores) if scores else None

        subj_name = sched.subject.subject_name if sched.subject else None
        subj_code = sched.subject.subject_code if sched.subject else None
        return SmartMissingSummary(
            total_students=total,
            entered_count=entered_count,
            missing_count=missing_count,
            average_score=avg,
            highest_score=high,
            lowest_score=low,
            missing_students=missing_students,
            entries=wizard_items,
            subject_id=sched.subject_id,
            subject_name=subj_name,
            subject_code=subj_code
        )

    async def bulk_save_marks(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, obj_in: BulkMarksEntry, current_user: User, autosave: bool = False
    ) -> List[Marks]:
        # 1. Fetch schedule
        stmt_s = select(ExamSchedule).where(
            ExamSchedule.id == obj_in.exam_schedule_id,
            ExamSchedule.school_id == school_id,
            ExamSchedule.tenant_id == tenant_id,
            ExamSchedule.deleted_at.is_(None)
        )
        res_s = await self.marks_repo.db.execute(stmt_s)
        sched = res_s.scalar_one_or_none()
        if not sched:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Exam schedule slot not found."
            )

        # 2. Check Lock constraints on Examination status
        stmt_e = select(Examination).where(
            Examination.id == sched.exam_id,
            Examination.deleted_at.is_(None)
        )
        res_e = await self.marks_repo.db.execute(stmt_e)
        exam = res_e.scalar_one_or_none()
        if not exam:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Examination master not found.")

        if exam.status in [ExamStatus.LOCKED, ExamStatus.COMPLETED, ExamStatus.ARCHIVED]:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Cannot modify marks because the examination is frozen."
            )

        # 3. TSA Assignment validation (optional for administrative superset operations)
        tsa = None
        if obj_in.teacher_subject_assignment_id:
            tsa = await self.tsa_repo.get_by_id(obj_in.teacher_subject_assignment_id, school_id, tenant_id)
            if not tsa or not tsa.is_active:
                raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Active Teacher Subject Assignment not found.")
            if tsa.class_id != sched.class_id or tsa.section_id != sched.section_id or tsa.subject_id != sched.subject_id:
                raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="TSA assignment parameters do not match exam schedule details.")
        else:
            stmt_auto = select(TeacherSubjectAssignment).where(
                TeacherSubjectAssignment.class_id == sched.class_id,
                TeacherSubjectAssignment.section_id == sched.section_id,
                TeacherSubjectAssignment.subject_id == sched.subject_id,
                TeacherSubjectAssignment.school_id == school_id,
                TeacherSubjectAssignment.tenant_id == tenant_id,
                TeacherSubjectAssignment.deleted_at.is_(None),
                TeacherSubjectAssignment.is_active == True
            )
            res_auto = await self.marks_repo.db.execute(stmt_auto)
            tsa = res_auto.scalars().first()

        effective_tsa_id = tsa.id if tsa else sched.id
        effective_teacher_id = tsa.teacher_id if tsa else current_user.id

        saved_marks = []
        last_saved_student_id = None
        last_saved_roll_number = None

        try:
            # 4. Iterate and validate each marks entry in a single transaction block
            for entry in obj_in.marks:
                # Check student details and containment
                stmt_st = select(Student).where(
                    Student.id == entry.student_id,
                    Student.school_id == school_id,
                    Student.tenant_id == tenant_id,
                    Student.deleted_at.is_(None)
                )
                res_st = await self.marks_repo.db.execute(stmt_st)
                student = res_st.scalar_one_or_none()
                if not student or not student.is_active:
                    raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=f"Active student not found for ID: {entry.student_id}")

                if student.class_id != sched.class_id or student.section_id != sched.section_id:
                    raise HTTPException(
                        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                        detail=f"Student {student.first_name} does not belong to target class/section of the scheduled exam."
                    )

                # Mark details sanitization
                marks_obtained = entry.marks_obtained
                if entry.result_status in [ExamResult.ABSENT, ExamResult.MALPRACTICE]:
                    marks_obtained = None
                elif entry.result_status == ExamResult.PRESENT and not autosave:
                    # If it's a save action (not autosave), force check value
                    if marks_obtained is None:
                        raise HTTPException(
                            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                            detail=f"Present status requires a mark value for student {student.first_name}."
                        )
                elif entry.result_status == ExamResult.EXEMPTED:
                    # Exempted students may have None marks
                    pass

                if marks_obtained is not None:
                    if marks_obtained < 0 or marks_obtained > sched.max_marks:
                        raise HTTPException(
                            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                            detail=f"Marks obtained ({marks_obtained}) must be between 0 and maximum marks ({sched.max_marks}) for student {student.first_name}."
                        )

                # Check duplicate / load existing record
                db_mark = await self.marks_repo.get_by_student_and_schedule(sched.id, student.id, tenant_id)

                if db_mark:
                    if db_mark.status == MarksStatus.LOCKED and not current_user.is_superuser and "SUPER_ADMIN" not in [r.code for r in current_user.roles]:
                        raise HTTPException(
                            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                            detail=f"Marks entries are already locked for student {student.first_name}."
                        )

                    # Optimistic concurrency check
                    if entry.version is not None and db_mark.version != entry.version:
                        raise HTTPException(
                            status_code=status.HTTP_409_CONFLICT,
                            detail={"detail": "Marks were modified by another user. Refresh and try again.", "code": "MARKS_CONFLICT"}
                        )

                    # Record corrections in Audit History JSONB array
                    if db_mark.marks_obtained != marks_obtained or db_mark.result_status != entry.result_status or entry.override_reason:
                        action_type = "MARK_OVERRIDDEN" if entry.override_reason else "MARK_UPDATED"
                        audit_record = {
                            "action": action_type,
                            "reason": entry.override_reason or entry.remarks or "Marks updated",
                            "old_marks": float(db_mark.marks_obtained) if db_mark.marks_obtained is not None else None,
                            "new_marks": float(marks_obtained) if marks_obtained is not None else None,
                            "old_status": db_mark.status.value if hasattr(db_mark.status, "value") else str(db_mark.status),
                            "new_status": (entry.status or db_mark.status).value if hasattr(entry.status or db_mark.status, "value") else str(entry.status or db_mark.status),
                            "updated_by": str(current_user.id),
                            "updated_at": datetime.now(timezone.utc).isoformat(),
                            "tenant_id": str(tenant_id),
                            "school_id": str(school_id)
                        }
                        db_mark.audit_history = list(db_mark.audit_history or []) + [audit_record]

                    db_mark.marks_obtained = marks_obtained
                    db_mark.result_status = entry.result_status
                    db_mark.remarks = entry.remarks
                    if entry.status is not None:
                        db_mark.status = entry.status
                    db_mark.version = db_mark.version + 1
                    db_mark.updated_by = current_user.id
                    self.marks_repo.db.add(db_mark)
                    saved_marks.append(db_mark)
                else:
                    initial_status = entry.status or MarksStatus.DRAFT
                    init_audit = [{
                        "action": "MARK_CREATED",
                        "reason": entry.override_reason or entry.remarks or "Initial entry",
                        "old_marks": None,
                        "new_marks": float(marks_obtained) if marks_obtained is not None else None,
                        "old_status": None,
                        "new_status": initial_status.value if hasattr(initial_status, "value") else str(initial_status),
                        "updated_by": str(current_user.id),
                        "updated_at": datetime.now(timezone.utc).isoformat(),
                        "tenant_id": str(tenant_id),
                        "school_id": str(school_id)
                    }]
                    db_mark = Marks(
                        tenant_id=tenant_id,
                        school_id=school_id,
                        academic_year_id=sched.academic_year_id,
                        examination_id=sched.exam_id,
                        exam_schedule_id=sched.id,
                        student_id=student.id,
                        teacher_subject_assignment_id=effective_tsa_id,
                        teacher_id=effective_teacher_id,
                        subject_id=sched.subject_id,
                        class_id=sched.class_id,
                        section_id=sched.section_id,
                        maximum_marks=sched.max_marks,
                        marks_obtained=marks_obtained,
                        result_status=entry.result_status,
                        remarks=entry.remarks,
                        status=initial_status,
                        version=1,
                        audit_history=init_audit,
                        created_by=current_user.id,
                        updated_by=current_user.id
                    )
                    self.marks_repo.db.add(db_mark)
                    saved_marks.append(db_mark)

                last_saved_student_id = str(student.id)
                last_saved_roll_number = student.roll_number

            # 5. Save the Resume Session pointer state inside TeacherSubjectAssignment settings if TSA exists
            if last_saved_student_id and tsa:
                tsa.settings = {
                    **(tsa.settings or {}),
                    "last_marks_session": {
                        "exam_schedule_id": str(obj_in.exam_schedule_id),
                        "last_student_id": last_saved_student_id,
                        "last_roll_number": last_saved_roll_number
                    }
                }
                self.marks_repo.db.add(tsa)

            await self.marks_repo.db.commit()
        except Exception as e:
            await self.marks_repo.db.rollback()
            raise e
        
        # Flush session and refresh items
        refreshed_marks = []
        for sm in saved_marks:
            refreshed_marks.append(await self.marks_repo.get_by_id(sm.id, school_id, tenant_id))
        return refreshed_marks

    async def get_publish_summary(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, exam_schedule_id: uuid.UUID
    ) -> PublishSummaryResponse:
        # Fetch schedule
        stmt_s = select(ExamSchedule).where(
            ExamSchedule.id == exam_schedule_id,
            ExamSchedule.school_id == school_id,
            ExamSchedule.tenant_id == tenant_id
        )
        res_s = await self.marks_repo.db.execute(stmt_s)
        sched = res_s.scalar_one_or_none()
        if not sched:
            raise HTTPException(status_code=404, detail="Schedule not found.")

        # Load exam name and subject name
        stmt_e = select(Examination).where(Examination.id == sched.exam_id)
        res_e = await self.marks_repo.db.execute(stmt_e)
        exam = res_e.scalar_one_or_none()

        # Load class name
        students = await self.marks_repo.get_class_students_sorted(sched.class_id, sched.section_id, school_id, tenant_id)
        total = len(students)

        # Load marks records
        marks = await self.marks_repo.get_by_schedule_id(exam_schedule_id, tenant_id)
        entered = len(marks)
        missing = total - entered

        pass_count = 0
        eval_count = 0
        for m in marks:
            if m.result_status in [ExamResult.PRESENT, ExamResult.EXEMPTED]:
                eval_count += 1
                if m.marks_obtained is not None and m.marks_obtained >= sched.pass_marks:
                    pass_count += 1

        pass_pct = round((pass_count / eval_count) * 100, 2) if eval_count else 0.0

        return PublishSummaryResponse(
            exam_name=exam.exam_name if exam else "Exam",
            subject_name="Subject",
            class_name="Class",
            total_students=total,
            entered_count=entered,
            missing_count=missing,
            pass_percentage=pass_pct
        )

    async def publish_marks(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, exam_schedule_id: uuid.UUID, current_user: User
    ) -> List[Marks]:
        marks = await self.marks_repo.get_by_schedule_id(exam_schedule_id, tenant_id)
        if not marks:
            raise HTTPException(status_code=422, detail="No marks logs found to publish.")

        for m in marks:
            self._validate_marks_transition(m.status, MarksStatus.PUBLISHED)
            old_st = m.status.value if hasattr(m.status, "value") else str(m.status)
            m.status = MarksStatus.PUBLISHED
            audit_record = {
                "action": "MARKS_PUBLISHED",
                "reason": "Marks published for official results",
                "old_status": old_st,
                "new_status": "PUBLISHED",
                "updated_by": str(current_user.id),
                "updated_at": datetime.now(timezone.utc).isoformat(),
                "tenant_id": str(tenant_id),
                "school_id": str(school_id)
            }
            m.audit_history = list(m.audit_history or []) + [audit_record]
            m.updated_by = current_user.id
            self.marks_repo.db.add(m)

        await self.marks_repo.db.commit()

        # Trigger notification
        if marks:
            first_mark = marks[0]
            try:
                await self.notification_service.notify_marks(
                    tenant_id=tenant_id,
                    school_id=school_id,
                    exam_id=first_mark.examination_id,
                    class_id=first_mark.class_id,
                    section_id=first_mark.section_id
                )
            except Exception as ne:
                logger.error(f"Failed to send marks notification: {str(ne)}", exc_info=True)

        return await self.marks_repo.get_by_schedule_id(exam_schedule_id, tenant_id)

    async def get_result_summary(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, exam_schedule_id: uuid.UUID
    ) -> ResultSummaryResponse:
        # Load marks
        marks = await self.marks_repo.get_by_schedule_id(exam_schedule_id, tenant_id)
        students = await self.marks_repo.get_class_students_sorted(
            # Fetch target class/sec from first mark entry or schedule
            marks[0].class_id if marks else uuid.uuid4(),
            marks[0].section_id if marks else uuid.uuid4(),
            school_id, tenant_id
        )
        total = len(students)
        entered = len(marks)
        missing = total - entered

        scores = []
        pass_count = 0
        absent_count = 0
        
        for m in marks:
            if m.result_status == ExamResult.ABSENT:
                absent_count += 1
            if m.result_status in [ExamResult.PRESENT, ExamResult.EXEMPTED] and m.marks_obtained is not None:
                scores.append(float(m.marks_obtained))
                if m.marks_obtained >= m.maximum_marks * 0.35: # Pass limit 35%
                    pass_count += 1

        avg = round(sum(scores) / len(scores), 2) if scores else 0.0
        pass_pct = round((pass_count / len(scores)) * 100, 2) if scores else 0.0
        high = max(scores) if scores else 0.0
        low = min(scores) if scores else 0.0

        return ResultSummaryResponse(
            class_average=avg,
            pass_percentage=pass_pct,
            highest_score=high,
            lowest_score=low,
            missing_count=missing,
            absent_count=absent_count
        )

    async def lock_marks(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, exam_schedule_id: uuid.UUID, current_user: User
    ) -> List[Marks]:
        marks = await self.marks_repo.get_by_schedule_id(exam_schedule_id, tenant_id)
        if not marks:
            raise HTTPException(status_code=404, detail="No marks records found to lock.")
        for m in marks:
            self._validate_marks_transition(m.status, MarksStatus.LOCKED)
            old_st = m.status.value if hasattr(m.status, "value") else str(m.status)
            m.status = MarksStatus.LOCKED
            audit_record = {
                "action": "MARKS_LOCKED",
                "reason": "Administrative marks locking",
                "old_status": old_st,
                "new_status": "LOCKED",
                "updated_by": str(current_user.id),
                "updated_at": datetime.now(timezone.utc).isoformat(),
                "tenant_id": str(tenant_id),
                "school_id": str(school_id)
            }
            m.audit_history = list(m.audit_history or []) + [audit_record]
            m.updated_by = current_user.id
            self.marks_repo.db.add(m)
        await self.marks_repo.db.commit()
        return await self.marks_repo.get_by_schedule_id(exam_schedule_id, tenant_id)

    async def unlock_marks(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, exam_schedule_id: uuid.UUID, reason: str, current_user: User
    ) -> List[Marks]:
        if not reason or not reason.strip():
            raise HTTPException(status_code=422, detail="An administrative unlock reason is mandatory.")
        marks = await self.marks_repo.get_by_schedule_id(exam_schedule_id, tenant_id)
        if not marks:
            raise HTTPException(status_code=404, detail="No marks records found to unlock.")
        for m in marks:
            old_st = m.status.value if hasattr(m.status, "value") else str(m.status)
            m.status = MarksStatus.DRAFT
            audit_record = {
                "action": "MARK_OVERRIDDEN",
                "reason": reason.strip(),
                "old_status": old_st,
                "new_status": "DRAFT",
                "updated_by": str(current_user.id),
                "updated_at": datetime.now(timezone.utc).isoformat(),
                "tenant_id": str(tenant_id),
                "school_id": str(school_id)
            }
            m.audit_history = list(m.audit_history or []) + [audit_record]
            m.updated_by = current_user.id
            self.marks_repo.db.add(m)
        await self.marks_repo.db.commit()
        return await self.marks_repo.get_by_schedule_id(exam_schedule_id, tenant_id)

    async def submit_for_review(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, exam_schedule_id: uuid.UUID, notes: Optional[str], current_user: User, allow_partial: bool = False
    ) -> List[Marks]:
        stmt_s = select(ExamSchedule).where(
            ExamSchedule.id == exam_schedule_id,
            ExamSchedule.school_id == school_id,
            ExamSchedule.tenant_id == tenant_id
        )
        res_s = await self.marks_repo.db.execute(stmt_s)
        sched = res_s.scalar_one_or_none()
        if not sched:
            raise HTTPException(status_code=404, detail="Schedule not found.")

        # Validate all active enrolled students in the section
        enrolled_students = await self.marks_repo.get_class_students_sorted(sched.class_id, sched.section_id, school_id, tenant_id)
        marks = await self.marks_repo.get_by_schedule_id(exam_schedule_id, tenant_id)
        if not marks:
            raise HTTPException(status_code=400, detail="No marks records found to submit for review.")

        marked_student_ids = {m.student_id for m in marks}
        missing_students = [s for s in enrolled_students if s.id not in marked_student_ids]

        if missing_students and not allow_partial:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Cannot submit marks. {len(missing_students)} enrolled student(s) have missing marks entries. Complete all entries or submit with explicit partial submission flag."
            )

        for m in marks:
            self._validate_marks_transition(m.status, MarksStatus.SUBMITTED)
            old_st = m.status.value if hasattr(m.status, "value") else str(m.status)
            m.status = MarksStatus.SUBMITTED
            audit_record = {
                "action": "MARKS_SUBMITTED" if not missing_students else "PARTIAL_MARKS_SUBMITTED",
                "notes": notes or ("Partial teacher marks submission" if missing_students else "Teacher submitted marks for Principal review"),
                "reason": notes or "Teacher submission",
                "old_status": old_st,
                "new_status": "SUBMITTED",
                "updated_by": str(current_user.id),
                "updated_at": datetime.now(timezone.utc).isoformat(),
                "tenant_id": str(tenant_id),
                "school_id": str(school_id)
            }
            m.audit_history = list(m.audit_history or []) + [audit_record]
            m.updated_by = current_user.id
            self.marks_repo.db.add(m)
        
        await self.marks_repo.db.commit()
        return await self.marks_repo.get_by_schedule_id(exam_schedule_id, tenant_id)

    async def approve_marks(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, exam_schedule_id: uuid.UUID, remarks: Optional[str], current_user: User
    ) -> List[Marks]:
        marks = await self.marks_repo.get_by_schedule_id(exam_schedule_id, tenant_id)
        if not marks:
            raise HTTPException(status_code=404, detail="No marks records found to approve.")
        
        for m in marks:
            self._validate_marks_transition(m.status, MarksStatus.APPROVED)
            old_st = m.status.value if hasattr(m.status, "value") else str(m.status)
            m.status = MarksStatus.APPROVED
            audit_record = {
                "action": "MARKS_APPROVED",
                "remarks": remarks or "Approved by Principal",
                "reason": remarks or "Principal approval",
                "old_status": old_st,
                "new_status": "APPROVED",
                "updated_by": str(current_user.id),
                "updated_at": datetime.now(timezone.utc).isoformat(),
                "tenant_id": str(tenant_id),
                "school_id": str(school_id)
            }
            m.audit_history = list(m.audit_history or []) + [audit_record]
            m.updated_by = current_user.id
            self.marks_repo.db.add(m)
        
        await self.marks_repo.db.commit()
        return await self.marks_repo.get_by_schedule_id(exam_schedule_id, tenant_id)

    async def return_marks_for_correction(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, exam_schedule_id: uuid.UUID, correction_reason: str, current_user: User
    ) -> List[Marks]:
        if not correction_reason or not correction_reason.strip():
            raise HTTPException(status_code=422, detail="A mandatory correction reason is required when returning marks.")
        
        marks = await self.marks_repo.get_by_schedule_id(exam_schedule_id, tenant_id)
        if not marks:
            raise HTTPException(status_code=404, detail="No marks records found to return.")
        
        for m in marks:
            self._validate_marks_transition(m.status, MarksStatus.RETURNED)
            old_st = m.status.value if hasattr(m.status, "value") else str(m.status)
            m.status = MarksStatus.RETURNED
            settings_dict = dict(m.settings or {})
            settings_dict["correction_reason"] = correction_reason.strip()
            m.settings = settings_dict
            audit_record = {
                "action": "MARKS_RETURNED",
                "reason": correction_reason.strip(),
                "old_status": old_st,
                "new_status": "RETURNED",
                "updated_by": str(current_user.id),
                "updated_at": datetime.now(timezone.utc).isoformat(),
                "tenant_id": str(tenant_id),
                "school_id": str(school_id)
            }
            m.audit_history = list(m.audit_history or []) + [audit_record]
            m.updated_by = current_user.id
            self.marks_repo.db.add(m)
        
        await self.marks_repo.db.commit()
        return await self.marks_repo.get_by_schedule_id(exam_schedule_id, tenant_id)

    async def get_review_queue(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, examination_id: Optional[uuid.UUID] = None, academic_year_id: Optional[uuid.UUID] = None
    ) -> List[MarksReviewQueueItem]:
        from sqlalchemy.orm import joinedload

        stmt = select(ExamSchedule).where(
            ExamSchedule.school_id == school_id,
            ExamSchedule.tenant_id == tenant_id,
            ExamSchedule.deleted_at.is_(None)
        ).options(
            joinedload(ExamSchedule.examination),
            joinedload(ExamSchedule.class_obj),
            joinedload(ExamSchedule.section),
            joinedload(ExamSchedule.subject)
        )
        if examination_id:
            stmt = stmt.where(ExamSchedule.exam_id == examination_id)
        if academic_year_id:
            stmt = stmt.where(ExamSchedule.academic_year_id == academic_year_id)
        
        stmt = stmt.order_by(ExamSchedule.exam_date.asc())
        res = await self.marks_repo.db.execute(stmt)
        schedules = list(res.unique().scalars().all())
        
        queue_items = []
        for sched in schedules:
            students = await self.marks_repo.get_class_students_sorted(sched.class_id, sched.section_id, school_id, tenant_id)
            marks = await self.marks_repo.get_by_schedule_id(sched.id, tenant_id)
            total = len(students)
            entered = len(marks)
            missing = total - entered
            
            scores = []
            pass_count = 0
            fail_count = 0
            absent_count = 0
            correction_reason = None
            last_submitted_at = None
            
            batch_status = MarksStatus.DRAFT
            if marks:
                statuses = [m.status for m in marks]
                if all(s == MarksStatus.PUBLISHED for s in statuses):
                    batch_status = MarksStatus.PUBLISHED
                elif all(s == MarksStatus.LOCKED for s in statuses):
                    batch_status = MarksStatus.LOCKED
                elif any(s == MarksStatus.RETURNED for s in statuses):
                    batch_status = MarksStatus.RETURNED
                elif all(s == MarksStatus.APPROVED for s in statuses):
                    batch_status = MarksStatus.APPROVED
                elif any(s in [MarksStatus.SUBMITTED, MarksStatus.UNDER_REVIEW] for s in statuses):
                    batch_status = MarksStatus.SUBMITTED
                else:
                    batch_status = MarksStatus.DRAFT
                
                for m in marks:
                    if m.result_status == ExamResult.ABSENT:
                        absent_count += 1
                    if m.result_status in [ExamResult.PRESENT, ExamResult.EXEMPTED] and m.marks_obtained is not None:
                        val = float(m.marks_obtained)
                        scores.append(val)
                        if val >= sched.pass_marks:
                            pass_count += 1
                        else:
                            fail_count += 1
                    if m.settings and "correction_reason" in m.settings:
                        correction_reason = m.settings["correction_reason"]
                    if m.audit_history:
                        for h in reversed(m.audit_history):
                            if h.get("action") == "SUBMIT_FOR_REVIEW" and "updated_at" in h:
                                try:
                                    last_submitted_at = datetime.fromisoformat(h["updated_at"])
                                except Exception:
                                    pass
                                break
            
            avg = round(sum(scores) / len(scores), 2) if scores else None
            pass_pct = round((pass_count / len(scores)) * 100, 2) if scores else 0.0
            high = max(scores) if scores else None
            low = min(scores) if scores else None
            
            # Fetch assigned teacher name
            teacher_name = None
            teacher_id = None
            stmt_tsa = select(TeacherSubjectAssignment).where(
                TeacherSubjectAssignment.class_id == sched.class_id,
                TeacherSubjectAssignment.section_id == sched.section_id,
                TeacherSubjectAssignment.subject_id == sched.subject_id,
                TeacherSubjectAssignment.tenant_id == tenant_id
            ).options(joinedload(TeacherSubjectAssignment.teacher))
            res_tsa = await self.marks_repo.db.execute(stmt_tsa)
            tsa = res_tsa.scalar_one_or_none()
            if tsa and tsa.teacher:
                teacher_id = tsa.teacher.id
                teacher_name = f"{tsa.teacher.first_name} {tsa.teacher.last_name}".strip()
            
            queue_items.append(MarksReviewQueueItem(
                exam_schedule_id=sched.id,
                examination_id=sched.exam_id,
                exam_name=getattr(sched.examination, "exam_name", getattr(sched.examination, "name", "Exam")) if sched.examination else "Exam",
                class_id=sched.class_id,
                class_name=sched.class_obj.name if sched.class_obj else "Class",
                section_id=sched.section_id,
                section_name=sched.section.name if sched.section else "Section",
                subject_id=sched.subject_id,
                subject_name=getattr(sched.subject, "subject_name", getattr(sched.subject, "name", "Subject")) if sched.subject else "Subject",
                subject_code=getattr(sched.subject, "subject_code", None) if sched.subject else None,
                teacher_id=teacher_id,
                teacher_name=teacher_name,
                exam_date=str(sched.exam_date),
                max_marks=sched.max_marks,
                pass_marks=sched.pass_marks,
                total_students=total,
                entered_count=entered,
                missing_count=missing,
                pass_count=pass_count,
                fail_count=fail_count,
                absent_count=absent_count,
                average_score=avg,
                highest_score=high,
                lowest_score=low,
                pass_percentage=pass_pct,
                batch_status=batch_status,
                last_submitted_at=last_submitted_at,
                correction_reason=correction_reason
            ))
        return queue_items

    async def get_parent_student_marks(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, student_id: uuid.UUID, current_user: User
    ) -> List[ParentExamResultResponse]:
        from sqlalchemy.orm import joinedload
        from sqlalchemy import or_

        role_codes = {r.code for r in current_user.roles}
        is_admin = current_user.is_superuser or any(code in ["SUPER_ADMIN", "SCHOOL_ADMIN", "PRINCIPAL"] for code in role_codes)
        if not is_admin:
            stmt_guard = select(StudentGuardian).join(Guardian).where(
                StudentGuardian.student_id == student_id,
                StudentGuardian.school_id == school_id,
                StudentGuardian.tenant_id == tenant_id,
                or_(
                    Guardian.user_id == current_user.id,
                    Guardian.email == current_user.email
                )
            )
            res_guard = await self.marks_repo.db.execute(stmt_guard)
            if not res_guard.scalar_one_or_none():
                raise HTTPException(status_code=403, detail="Access denied. You are not a linked guardian of this student.")

        stmt_st = select(Student).where(
            Student.id == student_id,
            Student.school_id == school_id,
            Student.tenant_id == tenant_id
        ).options(
            joinedload(Student.class_obj),
            joinedload(Student.section)
        )
        res_st = await self.marks_repo.db.execute(stmt_st)
        student = res_st.scalar_one_or_none()
        if not student:
            raise HTTPException(status_code=404, detail="Student not found.")

        stmt_m = select(Marks).where(
            Marks.student_id == student_id,
            Marks.school_id == school_id,
            Marks.tenant_id == tenant_id,
            Marks.status == MarksStatus.PUBLISHED,
            Marks.deleted_at.is_(None)
        ).options(
            joinedload(Marks.examination).joinedload(Examination.academic_year),
            joinedload(Marks.subject)
        ).order_by(Marks.created_at.asc())
        
        res_m = await self.marks_repo.db.execute(stmt_m)
        published_marks = list(res_m.unique().scalars().all())

        exams_map: Dict[uuid.UUID, List[Marks]] = {}
        for m in published_marks:
            exams_map.setdefault(m.examination_id, []).append(m)

        responses = []
        for exam_id, m_list in exams_map.items():
            first = m_list[0]
            exam = first.examination
            ay_name = exam.academic_year.name if exam and exam.academic_year else "Current"
            
            sub_items = []
            total_max = 0
            total_obt = 0.0
            all_passed = True
            
            for m in m_list:
                obt = float(m.marks_obtained) if m.marks_obtained is not None else 0.0
                if m.result_status == ExamResult.PRESENT:
                    total_max += m.maximum_marks
                    total_obt += obt
                    is_pass = (m.marks_obtained or 0) >= (m.maximum_marks * 0.35)
                    if not is_pass:
                        all_passed = False
                elif m.result_status == ExamResult.EXEMPTED:
                    is_pass = True
                else: # ABSENT, MALPRACTICE, WITHHELD
                    total_max += m.maximum_marks
                    is_pass = False
                    all_passed = False
                
                sub_items.append(ParentSubjectMarkItem(
                    subject_id=m.subject_id,
                    subject_name=getattr(m.subject, "subject_name", getattr(m.subject, "name", "Subject")) if m.subject else "Subject",
                    subject_code=getattr(m.subject, "subject_code", getattr(m.subject, "code", None)) if m.subject else None,
                    exam_date=None,
                    maximum_marks=m.maximum_marks,
                    pass_marks=int(m.maximum_marks * 0.35),
                    marks_obtained=float(m.marks_obtained) if m.marks_obtained is not None else None,
                    result_status=m.result_status,
                    grade=m.grade,
                    remarks=m.remarks,
                    is_passed=is_pass
                ))
            
            pct = round((total_obt / total_max) * 100, 2) if total_max > 0 else 0.0
            status_str = "PASSED" if all_passed else "FAILED"
            
            exam_name_val = getattr(exam, "exam_name", getattr(exam, "name", "Examination")) if exam else "Examination"
            exam_type_val = exam.exam_type.value if exam and hasattr(exam.exam_type, "value") else (str(exam.exam_type) if exam else "SCHOLASTIC")

            responses.append(ParentExamResultResponse(
                examination_id=exam_id,
                exam_name=exam_name_val,
                exam_type=exam_type_val,
                academic_year_name=ay_name,
                student_id=student.id,
                student_name=f"{student.first_name} {student.last_name}".strip(),
                roll_number=student.roll_number,
                class_name=student.class_obj.name if student.class_obj else "Class",
                section_name=student.section.name if student.section else "Section",
                total_max_marks=total_max,
                total_obtained_marks=round(total_obt, 2),
                overall_percentage=pct,
                overall_grade="A+" if pct >= 90 else "A" if pct >= 80 else "B" if pct >= 70 else "C" if pct >= 60 else "D" if pct >= 50 else "F",
                status=status_str,
                subject_marks=sub_items
            ))
        return responses

    async def get_parent_student_timetable(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, student_id: uuid.UUID, current_user: User
    ) -> List[ParentTimetableSlot]:
        from sqlalchemy.orm import joinedload
        from sqlalchemy import or_

        role_codes = {r.code for r in current_user.roles}
        is_admin = current_user.is_superuser or any(code in ["SUPER_ADMIN", "SCHOOL_ADMIN", "PRINCIPAL"] for code in role_codes)
        if not is_admin:
            stmt_guard = select(StudentGuardian).join(Guardian).where(
                StudentGuardian.student_id == student_id,
                StudentGuardian.school_id == school_id,
                StudentGuardian.tenant_id == tenant_id,
                or_(
                    Guardian.user_id == current_user.id,
                    Guardian.email == current_user.email
                )
            )
            res_guard = await self.marks_repo.db.execute(stmt_guard)
            if not res_guard.scalar_one_or_none():
                raise HTTPException(status_code=403, detail="Access denied. You are not a linked guardian of this student.")

        stmt_st = select(Student).where(
            Student.id == student_id,
            Student.school_id == school_id,
            Student.tenant_id == tenant_id
        )
        res_st = await self.marks_repo.db.execute(stmt_st)
        student = res_st.scalar_one_or_none()
        if not student:
            raise HTTPException(status_code=404, detail="Student not found.")

        stmt_s = select(ExamSchedule).where(
            ExamSchedule.class_id == student.class_id,
            ExamSchedule.section_id == student.section_id,
            ExamSchedule.school_id == school_id,
            ExamSchedule.tenant_id == tenant_id,
            ExamSchedule.deleted_at.is_(None)
        ).options(
            joinedload(ExamSchedule.examination),
            joinedload(ExamSchedule.subject)
        ).order_by(ExamSchedule.exam_date.asc(), ExamSchedule.start_time.asc())

        res_s = await self.marks_repo.db.execute(stmt_s)
        schedules = list(res_s.unique().scalars().all())

        return [
            ParentTimetableSlot(
                exam_schedule_id=s.id,
                examination_id=s.exam_id,
                exam_name=getattr(s.examination, "exam_name", getattr(s.examination, "name", "Examination")) if s.examination else "Examination",
                exam_type=s.examination.exam_type.value if (s.examination and hasattr(s.examination.exam_type, "value")) else (str(s.examination.exam_type) if s.examination else "SCHOLASTIC"),
                subject_id=s.subject_id,
                subject_name=getattr(s.subject, "subject_name", getattr(s.subject, "name", "Subject")) if s.subject else "Subject",
                subject_code=getattr(s.subject, "subject_code", None) if s.subject else None,
                exam_date=str(s.exam_date),
                start_time=s.start_time.strftime("%H:%M"),
                end_time=s.end_time.strftime("%H:%M"),
                max_marks=s.max_marks,
                pass_marks=s.pass_marks,
                room_number=s.room_number
            )
            for s in schedules
        ]

    async def get_parent_student_report_cards(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, student_id: uuid.UUID, current_user: User
    ) -> List[ParentReportCardItem]:
        from sqlalchemy.orm import joinedload
        from sqlalchemy import or_
        from app.models.report_card import ReportCardPublication, ReportCardStatus

        role_codes = {r.code for r in current_user.roles}
        is_admin = current_user.is_superuser or any(code in ["SUPER_ADMIN", "SCHOOL_ADMIN", "PRINCIPAL"] for code in role_codes)
        if not is_admin:
            stmt_guard = select(StudentGuardian).join(Guardian).where(
                StudentGuardian.student_id == student_id,
                StudentGuardian.school_id == school_id,
                StudentGuardian.tenant_id == tenant_id,
                or_(
                    Guardian.user_id == current_user.id,
                    Guardian.email == current_user.email
                )
            )
            res_guard = await self.marks_repo.db.execute(stmt_guard)
            if not res_guard.scalar_one_or_none():
                raise HTTPException(status_code=403, detail="Access denied. You are not a linked guardian of this student.")

        stmt_rc = select(ReportCardPublication).where(
            ReportCardPublication.student_id == student_id,
            ReportCardPublication.school_id == school_id,
            ReportCardPublication.tenant_id == tenant_id,
            ReportCardPublication.status == ReportCardStatus.PUBLISHED,
            ReportCardPublication.deleted_at.is_(None)
        ).options(
            joinedload(ReportCardPublication.academic_year)
        ).order_by(ReportCardPublication.created_at.desc())

        res_rc = await self.marks_repo.db.execute(stmt_rc)
        report_cards = list(res_rc.unique().scalars().all())

        return [
            ParentReportCardItem(
                report_card_id=rc.id,
                examination_id=uuid.UUID((rc.settings or {}).get("examination_id")) if (rc.settings and (rc.settings or {}).get("examination_id")) else uuid.UUID(int=0),
                exam_name=(rc.settings or {}).get("exam_name", "Academic Progress Report"),
                academic_year_name=rc.academic_year.name if rc.academic_year else "Academic Year",
                status=rc.status.value if hasattr(rc.status, "value") else str(rc.status),
                total_marks=float((rc.settings or {}).get("total_marks", 0.0)),
                percentage=float((rc.settings or {}).get("percentage", 0.0)),
                grade=(rc.settings or {}).get("grade"),
                rank=(rc.settings or {}).get("rank"),
                generated_at=rc.generated_at or rc.created_at,
                pdf_download_url=rc.pdf_url or f"/api/v1/report-cards/{rc.id}/pdf?school_id={school_id}"
            )
            for rc in report_cards
        ]

    async def generate_marks_template(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        exam_schedule_id: uuid.UUID,
        file_format: str = "xlsx"
    ) -> tuple[bytes, str, str]:
        import io
        import csv
        from openpyxl import Workbook
        from openpyxl.styles import Font, PatternFill, Alignment, Border, Side

        # Fetch schedule and details
        stmt_s = select(ExamSchedule).where(
            ExamSchedule.id == exam_schedule_id,
            ExamSchedule.school_id == school_id,
            ExamSchedule.tenant_id == tenant_id,
            ExamSchedule.deleted_at.is_(None)
        ).options(
            joinedload(ExamSchedule.examination),
            joinedload(ExamSchedule.subject),
            joinedload(ExamSchedule.class_obj),
            joinedload(ExamSchedule.section)
        )
        res_s = await self.marks_repo.db.execute(stmt_s)
        sched = res_s.scalar_one_or_none()
        if not sched:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Exam schedule slot not found.")

        students = await self.marks_repo.get_class_students_sorted(sched.class_id, sched.section_id, school_id, tenant_id)
        existing_marks = await self.marks_repo.get_by_schedule_id(exam_schedule_id, tenant_id)
        marks_map = {m.student_id: m for m in existing_marks}

        subject_name = sched.subject.subject_name if (getattr(sched, "subject", None) and getattr(sched.subject, "subject_name", None)) else "Subject"
        class_name = sched.class_obj.name if getattr(sched, "class_obj", None) else "Class"
        section_name = f"-{sched.section.name}" if getattr(sched, "section", None) else ""
        clean_filename_base = f"marks_template_{subject_name}_{class_name}{section_name}".replace(" ", "_")

        max_marks_val = getattr(sched, "maximum_marks", getattr(sched, "max_marks", 100))

        if file_format.lower() == "csv":
            output = io.StringIO()
            writer = csv.writer(output)
            writer.writerow(["Roll Number", "Student Name", "Max Marks", "Marks Obtained", "Status", "Remarks"])
            for s in students:
                existing = marks_map.get(s.id)
                obtained = existing.marks_obtained if (existing and existing.marks_obtained is not None) else ""
                st_val = existing.result_status.value if (existing and existing.result_status) else "PRESENT"
                rem = existing.remarks if (existing and existing.remarks) else ""
                writer.writerow([s.roll_number or "", s.full_name, max_marks_val, obtained, st_val, rem])
            
            content = output.getvalue().encode("utf-8-sig")
            return content, f"{clean_filename_base}.csv", "text/csv"

        # Default XLSX with openpyxl
        wb = Workbook()
        ws = wb.active
        ws.title = "Marks Entry"

        # Headers and Styling
        header_font = Font(name="Calibri", size=11, bold=True, color="FFFFFF")
        header_fill = PatternFill(start_color="1A365D", end_color="1A365D", fill_type="solid")
        thin_border = Border(
            left=Side(style="thin", color="CCCCCC"),
            right=Side(style="thin", color="CCCCCC"),
            top=Side(style="thin", color="CCCCCC"),
            bottom=Side(style="thin", color="CCCCCC")
        )
        center_align = Alignment(horizontal="center", vertical="center")
        left_align = Alignment(horizontal="left", vertical="center")

        headers = ["Roll Number", "Student Name", "Max Marks", "Marks Obtained", "Status (PRESENT/ABSENT/EXEMPTED/MALPRACTICE)", "Remarks"]
        ws.append(headers)

        for col_idx, header in enumerate(headers, 1):
            cell = ws.cell(row=1, column=col_idx)
            cell.font = header_font
            cell.fill = header_fill
            cell.alignment = center_align
            cell.border = thin_border

        for row_idx, s in enumerate(students, 2):
            existing = marks_map.get(s.id)
            obtained = existing.marks_obtained if (existing and existing.marks_obtained is not None) else None
            st_val = existing.result_status.value if (existing and existing.result_status) else "PRESENT"
            rem = existing.remarks if (existing and existing.remarks) else None

            ws.cell(row=row_idx, column=1, value=s.roll_number or "").alignment = center_align
            ws.cell(row=row_idx, column=2, value=s.full_name).alignment = left_align
            ws.cell(row=row_idx, column=3, value=max_marks_val).alignment = center_align
            ws.cell(row=row_idx, column=4, value=obtained).alignment = center_align
            ws.cell(row=row_idx, column=5, value=st_val).alignment = center_align
            ws.cell(row=row_idx, column=6, value=rem).alignment = left_align

            for c in range(1, 7):
                ws.cell(row=row_idx, column=c).border = thin_border

        # Adjust column widths
        ws.column_dimensions["A"].width = 15
        ws.column_dimensions["B"].width = 25
        ws.column_dimensions["C"].width = 14
        ws.column_dimensions["D"].width = 16
        ws.column_dimensions["E"].width = 45
        ws.column_dimensions["F"].width = 30

        output = io.BytesIO()
        wb.save(output)
        output.seek(0)
        return output.getvalue(), f"{clean_filename_base}.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

    async def import_marks_from_file(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        exam_schedule_id: uuid.UUID,
        file_bytes: bytes,
        filename: str,
        current_user: User
    ) -> MarksExcelUploadSummary:
        import io
        import csv
        from openpyxl import load_workbook

        # 1. Fetch schedule
        stmt_s = select(ExamSchedule).where(
            ExamSchedule.id == exam_schedule_id,
            ExamSchedule.school_id == school_id,
            ExamSchedule.tenant_id == tenant_id,
            ExamSchedule.deleted_at.is_(None)
        ).options(
            joinedload(ExamSchedule.examination)
        )
        res_s = await self.marks_repo.db.execute(stmt_s)
        sched = res_s.scalar_one_or_none()
        if not sched:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Exam schedule slot not found.")

        # Check if examination is frozen/archived
        if sched.examination and sched.examination.status in [ExamStatus.ARCHIVED, ExamStatus.COMPLETED]:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Cannot upload marks for an archived or completed examination.")

        max_marks_limit = getattr(sched, "maximum_marks", getattr(sched, "max_marks", 100))

        # 2. Fetch enrolled students
        students = await self.marks_repo.get_class_students_sorted(sched.class_id, sched.section_id, school_id, tenant_id)
        if not students:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="No enrolled students found for this class and section.")

        # Build lookup indices
        student_by_roll = {str(s.roll_number).strip().lower(): s for s in students if s.roll_number}
        student_by_id = {str(s.id): s for s in students}
        student_by_name = {str(s.full_name).strip().lower(): s for s in students if s.full_name}

        # 3. Parse rows from file
        parsed_rows: List[Dict[str, Any]] = []
        is_csv = filename.lower().endswith(".csv")

        if is_csv:
            try:
                text_content = file_bytes.decode("utf-8-sig", errors="replace")
                reader = csv.reader(io.StringIO(text_content))
                raw_rows = list(reader)
            except Exception as e:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Failed to parse CSV file: {str(e)}")
        else:
            try:
                wb = load_workbook(io.BytesIO(file_bytes), data_only=True)
                ws = wb.active
                raw_rows = [[cell.value for cell in row] for row in ws.iter_rows()]
            except Exception as e:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Failed to parse Excel workbook: {str(e)}")

        if not raw_rows or len(raw_rows) < 2:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="File is empty or missing data rows.")

        # Find header positions
        headers = [str(h or "").strip().lower() for h in raw_rows[0]]
        roll_idx = -1
        name_idx = -1
        marks_idx = -1
        status_idx = -1
        remarks_idx = -1

        for idx, h in enumerate(headers):
            if "remark" in h or "comment" in h or "note" in h:
                remarks_idx = idx
            elif "status" in h or "result" in h or "attendance" in h:
                status_idx = idx
            elif "roll" in h or "admission" in h:
                roll_idx = idx
            elif "name" in h or "student" in h:
                name_idx = idx
            elif "obtained" in h or "score" in h or ("mark" in h and "max" not in h):
                marks_idx = idx

        if roll_idx == -1 and name_idx == -1:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Could not detect student identification column ('Roll Number' or 'Student Name') in header."
            )
        if marks_idx == -1:
            marks_idx = 3 if len(headers) > 3 else -1

        errors: List[str] = []
        matched_entries: List[SingleMarkEntry] = []
        total_data_rows = 0

        for row_num, row in enumerate(raw_rows[1:], start=2):
            if not row or all(v is None or str(v).strip() == "" for v in row):
                continue
            total_data_rows += 1

            roll_val = str(row[roll_idx]).strip() if (roll_idx != -1 and roll_idx < len(row) and row[roll_idx] is not None) else ""
            name_val = str(row[name_idx]).strip() if (name_idx != -1 and name_idx < len(row) and row[name_idx] is not None) else ""
            raw_marks = row[marks_idx] if (marks_idx != -1 and marks_idx < len(row)) else None
            raw_status = str(row[status_idx]).strip().upper() if (status_idx != -1 and status_idx < len(row) and row[status_idx] is not None) else ""
            raw_remarks = str(row[remarks_idx]).strip() if (remarks_idx != -1 and remarks_idx < len(row) and row[remarks_idx] is not None) else None

            # Match student
            matched_student = None
            if roll_val and roll_val.lower() in student_by_roll:
                matched_student = student_by_roll[roll_val.lower()]
            elif roll_val in student_by_id:
                matched_student = student_by_id[roll_val]
            elif name_val and name_val.lower() in student_by_name:
                matched_student = student_by_name[name_val.lower()]

            if not matched_student:
                errors.append(f"Row {row_num}: Student '{roll_val or name_val}' not found in enrolled students.")
                continue

            # Parse status
            result_status = ExamResult.PRESENT
            if "ABSENT" in raw_status or raw_status == "A":
                result_status = ExamResult.ABSENT
            elif "EXEMPT" in raw_status or raw_status == "E":
                result_status = ExamResult.EXEMPTED
            elif "MALPRACTICE" in raw_status or raw_status == "M":
                result_status = ExamResult.MALPRACTICE
            elif raw_status in [e.value for e in ExamResult]:
                result_status = ExamResult(raw_status)

            # Parse marks
            marks_val: Optional[float] = None
            if result_status != ExamResult.ABSENT and raw_marks is not None and str(raw_marks).strip() != "":
                try:
                    marks_val = float(str(raw_marks).strip())
                    if marks_val < 0:
                        errors.append(f"Row {row_num} ({matched_student.full_name}): Marks cannot be negative ({marks_val}).")
                        continue
                    if marks_val > max_marks_limit:
                        errors.append(f"Row {row_num} ({matched_student.full_name}): Marks ({marks_val}) exceed Maximum Marks ({max_marks_limit}).")
                        continue
                except ValueError:
                    errors.append(f"Row {row_num} ({matched_student.full_name}): Invalid marks value '{raw_marks}'.")
                    continue
            elif result_status == ExamResult.ABSENT:
                marks_val = None

            matched_entries.append(
                SingleMarkEntry(
                    student_id=matched_student.id,
                    marks_obtained=marks_val,
                    result_status=result_status,
                    remarks=raw_remarks
                )
            )

        if not matched_entries:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"No valid student marks could be processed from file. {len(errors)} error(s) found: {'; '.join(errors[:3])}"
            )

        # 4. Save bulk marks via bulk_save_marks
        bulk_payload = BulkMarksEntry(
            exam_schedule_id=exam_schedule_id,
            marks=matched_entries
        )
        saved_objs = await self.bulk_save_marks(tenant_id, school_id, bulk_payload, current_user, autosave=False)

        return MarksExcelUploadSummary(
            total_rows=total_data_rows,
            matched_students=len(matched_entries),
            saved_count=len(saved_objs),
            errors=errors,
            marks=[MarksResponse.model_validate(m) for m in saved_objs]
        )

    def _compute_grade(self, marks_obtained: Optional[float], max_marks: int) -> Optional[str]:
        if marks_obtained is None or max_marks <= 0:
            return None
        pct = (marks_obtained / max_marks) * 100.0
        if pct >= 90: return "A+"
        elif pct >= 80: return "A"
        elif pct >= 70: return "B+"
        elif pct >= 60: return "B"
        elif pct >= 50: return "C"
        elif pct >= 35: return "D"
        else: return "F"

    async def preview_exam_wide_marks_file(
        self,
        tenant_id: Optional[uuid.UUID] = None,
        school_id: Optional[uuid.UUID] = None,
        exam_id: Optional[uuid.UUID] = None,
        file_bytes: bytes = b"",
        filename: str = "upload.xlsx",
        current_user: Optional[User] = None,
        class_ids: Optional[List[uuid.UUID]] = None,
        section_ids: Optional[List[uuid.UUID]] = None,
        academic_year_id: Optional[uuid.UUID] = None,
        scope: Optional[str] = "ALL_PARTICIPATING_CLASSES",
        duplicate_behavior: Optional[str] = "UPDATE_EXISTING",
        examination_id: Optional[uuid.UUID] = None,
    ) -> ExamWideUploadPreviewResponse:
        import io
        import csv
        from openpyxl import load_workbook

        effective_exam_id = exam_id or examination_id
        if not effective_exam_id:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="exam_id or examination_id is required.")
        exam_id = effective_exam_id

        # 1. Fetch Examination with participating classes and papers
        stmt_e = select(Examination).where(
            Examination.id == exam_id,
            Examination.deleted_at.is_(None)
        ).options(
            joinedload(Examination.participating_classes).joinedload(ExaminationClass.class_obj),
            joinedload(Examination.papers).joinedload(ExamPaper.class_configs),
            joinedload(Examination.papers).joinedload(ExamPaper.subject)
        )
        if school_id:
            stmt_e = stmt_e.where(Examination.school_id == school_id)
        if tenant_id:
            stmt_e = stmt_e.where(Examination.tenant_id == tenant_id)

        res_e = await self.marks_repo.db.execute(stmt_e)
        examination = res_e.unique().scalar_one_or_none()
        if not examination:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Examination not found.")

        tenant_id = examination.tenant_id
        school_id = examination.school_id

        # Academic year isolation check
        if academic_year_id and examination.academic_year_id != academic_year_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Selected academic year does not match examination cycle academic year."
            )

        # 2. Collect participating classes for the Examination Cycle
        participating_class_ids = set()
        participating_class_names = {}
        for pc in (examination.participating_classes or []):
            if pc.class_obj:
                c_uuid = uuid.UUID(str(pc.class_id))
                participating_class_ids.add(c_uuid)
                cn = pc.class_obj.name.strip().lower()
                participating_class_names[cn] = c_uuid
                participating_class_names[cn.replace("class", "").strip()] = c_uuid
                if pc.class_obj.code:
                    participating_class_names[pc.class_obj.code.strip().lower()] = c_uuid

        # Also support class_ids in examination.settings if participating_classes table empty
        if not participating_class_ids and examination.settings and "class_ids" in examination.settings:
            raw_cids = examination.settings["class_ids"]
            if isinstance(raw_cids, list):
                for cid_str in raw_cids:
                    try:
                        cid = uuid.UUID(str(cid_str))
                        participating_class_ids.add(cid)
                    except Exception:
                        pass

        # Validate that requested class_ids belong to the participating classes of this examination
        allowed_class_ids = None
        if class_ids:
            requested_set = set(uuid.UUID(str(cid)) for cid in class_ids)
            for r_cid in requested_set:
                if participating_class_ids and r_cid not in participating_class_ids:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=f"Class ID {r_cid} does not participate in this examination cycle."
                    )
            allowed_class_ids = requested_set
        else:
            allowed_class_ids = participating_class_ids if participating_class_ids else None

        allowed_section_ids = set(uuid.UUID(str(sid)) for sid in section_ids) if section_ids else None

        # 3. Build Paper and Class Overrides Lookup
        # paper_lookup: (norm_subject_name, class_id) -> (max_marks, pass_marks, subject_id, paper_id, subject_name)
        paper_lookup = {}
        for paper in (examination.papers or []):
            sub = paper.subject
            sub_id = paper.subject_id
            sub_name = (sub.subject_name if sub else paper.paper_name).strip().lower()
            sub_code = (sub.subject_code if sub and sub.subject_code else "").strip().lower()
            canonical_name = sub.subject_name if sub else paper.paper_name

            overrides = {cc.class_id: cc for cc in (paper.class_configs or [])}

            # Map default paper info (None class_id)
            def_tuple = (paper.default_max_marks, paper.default_pass_marks, sub_id, paper.id, canonical_name)
            for k in filter(None, [sub_name, sub_code, paper.paper_name.strip().lower()]):
                paper_lookup[(k, None)] = def_tuple

            # Map class overrides
            for p_cid in (participating_class_ids or []):
                cc = overrides.get(p_cid)
                max_m = cc.maximum_marks if (cc and cc.maximum_marks is not None) else paper.default_max_marks
                pass_m = cc.pass_marks if (cc and cc.pass_marks is not None) else paper.default_pass_marks
                override_tuple = (max_m, pass_m, sub_id, paper.id, canonical_name)

                for k in filter(None, [sub_name, sub_code, paper.paper_name.strip().lower()]):
                    paper_lookup[(k, p_cid)] = override_tuple

        # 4. Fetch all existing ExamSchedules for this Examination
        stmt_s = select(ExamSchedule).where(
            ExamSchedule.exam_id == exam_id,
            ExamSchedule.school_id == school_id,
            ExamSchedule.tenant_id == tenant_id,
            ExamSchedule.deleted_at.is_(None)
        ).options(
            joinedload(ExamSchedule.class_obj),
            joinedload(ExamSchedule.section),
            joinedload(ExamSchedule.subject)
        )
        res_s = await self.marks_repo.db.execute(stmt_s)
        schedules = list(res_s.unique().scalars().all())

        schedule_map = {}
        schedule_by_ids = {}
        for s in schedules:
            schedule_by_ids[(s.class_id, s.section_id, s.subject_id)] = s
            c_name = str(s.class_obj.name).strip().lower() if s.class_obj else ""
            c_code = str(s.class_obj.code).strip().lower() if s.class_obj and s.class_obj.code else ""
            sec_name = str(s.section.name).strip().lower() if s.section else ""
            sec_code = str(s.section.code).strip().lower() if s.section and s.section.code else ""
            sub_name = str(s.subject.subject_name).strip().lower() if s.subject else ""
            sub_code = str(s.subject.subject_code).strip().lower() if s.subject and s.subject.subject_code else ""

            for cn in filter(None, [c_name, c_code, c_name.replace("class", "").strip()]):
                for sn in filter(None, [sec_name, sec_code, sec_name.replace("section", "").strip()]):
                    for sbn in filter(None, [sub_name, sub_code]):
                        schedule_map[(cn, sn, sbn)] = s

        # 5. Fetch all School Classes and Sections for ID resolution
        stmt_all_c = select(Class).where(
            Class.school_id == school_id,
            Class.tenant_id == tenant_id,
            Class.deleted_at.is_(None)
        )
        all_classes = (await self.marks_repo.db.execute(stmt_all_c)).scalars().all()
        class_name_to_obj = {}
        for c in all_classes:
            cn = c.name.strip().lower()
            class_name_to_obj[cn] = c
            class_name_to_obj[cn.replace("class", "").strip()] = c
            if c.code:
                class_name_to_obj[c.code.strip().lower()] = c

        stmt_all_sec = select(Section).where(
            Section.school_id == school_id,
            Section.tenant_id == tenant_id,
            Section.deleted_at.is_(None)
        )
        all_sections = (await self.marks_repo.db.execute(stmt_all_sec)).scalars().all()
        sec_lookup = {}
        for sec in all_sections:
            sn = sec.name.strip().lower()
            sec_lookup[(sec.class_id, sn)] = sec
            sec_lookup[(sec.class_id, sn.replace("section", "").strip())] = sec
            if sec.code:
                sec_lookup[(sec.class_id, sec.code.strip().lower())] = sec

        # 6. Fetch all active enrolled students for targeted classes
        # 6. Fetch all active enrolled students for targeted classes
        target_class_ids = allowed_class_ids if allowed_class_ids else (participating_class_ids if participating_class_ids else {c.id for c in all_classes})
        stmt_st = select(Student).where(
            Student.class_id.in_(target_class_ids),
            Student.school_id == school_id,
            Student.tenant_id == tenant_id,
            Student.deleted_at.is_(None),
            Student.is_active == True
        )
        if allowed_section_ids:
            stmt_st = stmt_st.where(Student.section_id.in_(allowed_section_ids))
        res_st = await self.marks_repo.db.execute(stmt_st)
        students = list(res_st.scalars().all())

        # Student lookup maps
        student_map = {}
        for st in students:
            st_id_str = str(st.id).strip().lower()
            student_map[(st.class_id, st.section_id, st_id_str)] = st
            student_map[(st.class_id, st_id_str)] = st
            student_map[st_id_str] = st
            if st.roll_number:
                rn = str(st.roll_number).strip().lower()
                student_map[(st.class_id, st.section_id, rn)] = st
                student_map[(st.class_id, rn)] = st
                try:
                    rn_int = str(int(st.roll_number.strip())).lower()
                    student_map[(st.class_id, st.section_id, rn_int)] = st
                    student_map[(st.class_id, rn_int)] = st
                except Exception:
                    pass
            if st.admission_number:
                adm = str(st.admission_number).strip().lower()
                student_map[(st.class_id, st.section_id, adm)] = st
                student_map[(st.class_id, adm)] = st
                student_map[adm] = st

        # 7. Fetch existing marks to detect duplicate or re-import entries
        stmt_existing = select(Marks).where(
            Marks.examination_id == exam_id,
            Marks.school_id == school_id,
            Marks.tenant_id == tenant_id,
            Marks.deleted_at.is_(None)
        )
        res_ex = await self.marks_repo.db.execute(stmt_existing)
        existing_marks = list(res_ex.scalars().all())
        existing_sched_map = {(m.student_id, m.exam_schedule_id): m for m in existing_marks}
        existing_subj_map = {(m.student_id, m.class_id, m.subject_id): m for m in existing_marks}

        # 8. Parse file
        is_csv = filename.lower().endswith(".csv")
        if is_csv:
            try:
                text_content = file_bytes.decode("utf-8-sig", errors="replace")
                reader = csv.reader(io.StringIO(text_content))
                raw_rows = list(reader)
            except Exception as e:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Failed to parse CSV file: {str(e)}")
        else:
            try:
                wb = load_workbook(io.BytesIO(file_bytes), data_only=True)
                ws = wb.active
                raw_rows = [[cell.value for cell in row] for row in ws.iter_rows()]
            except Exception as e:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Failed to parse Excel workbook: {str(e)}")

        if not raw_rows or len(raw_rows) < 2:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="File is empty or missing data rows.")

        # 9. Flexible column header discovery with rich aliases
        headers = [str(h or "").strip().lower() for h in raw_rows[0]]

        def find_col_idx(aliases: List[str], fallback_idx: int = -1) -> int:
            # 1. Exact match first
            for i, h in enumerate(headers):
                norm_h = h.replace("_", " ").replace("-", " ").strip()
                for alias in aliases:
                    if alias == norm_h:
                        return i
            # 2. Substring match fallback (with conflict prevention)
            for i, h in enumerate(headers):
                norm_h = h.replace("_", " ").replace("-", " ").strip()
                for alias in aliases:
                    if alias in ["marks", "mark", "score"] and ("max" in norm_h or "maximum" in norm_h or "total" in norm_h):
                        continue
                    if alias in ["max", "maximum", "total"] and ("obtained" in norm_h):
                        continue
                    if alias in norm_h:
                        return i
            return fallback_idx

        class_idx = find_col_idx(["class", "grade", "standard"], fallback_idx=0)
        sec_idx = find_col_idx(["section", "division", "sec"], fallback_idx=1)
        adm_idx = find_col_idx(["admission no", "admission number", "admission_no", "adm no", "admission"], fallback_idx=-1)
        roll_idx = find_col_idx(["roll no", "roll number", "roll_no", "roll"], fallback_idx=-1)
        if roll_idx == -1 and adm_idx != -1:
            roll_idx = adm_idx
        elif roll_idx == -1:
            roll_idx = find_col_idx(["student id", "student_id", "identifier"], fallback_idx=2)
        if adm_idx == -1:
            adm_idx = roll_idx

        name_idx = find_col_idx(["student name", "name", "full name"], fallback_idx=3)
        sub_idx = find_col_idx(["subject name", "paper name", "subject", "paper", "course"], fallback_idx=4)
        max_idx = find_col_idx(["maximum marks", "max marks", "total marks", "maximum", "max"], fallback_idx=-1)
        marks_idx = find_col_idx(["marks obtained", "obtained marks", "marks", "score", "mark"], fallback_idx=-1)
        status_idx = find_col_idx(["status", "result status", "result", "attendance"], fallback_idx=-1)
        remarks_idx = find_col_idx(["remarks", "remark", "notes", "note", "comment"], fallback_idx=-1)

        if marks_idx == -1 and len(headers) > 5:
            marks_idx = 5

        preview_rows: List[ExamWideUploadRowPreview] = []
        classes_detected = set()
        sections_detected = set()
        subjects_detected = set()
        students_detected = set()
        errors_summary: List[str] = []
        seen_duplicates = set()
        existing_marks_count = 0
        grouped_summary: Dict[str, Dict[str, Dict[str, int]]] = {} # class -> sec -> sub -> count
        new_schedules_created = False

        # 10. Process each row
        for row_num, row in enumerate(raw_rows[1:], start=2):
            if not row or all(v is None or str(v).strip() == "" for v in row):
                continue

            raw_class = str(row[class_idx]).strip() if class_idx < len(row) and row[class_idx] is not None else ""
            raw_sec = str(row[sec_idx]).strip() if sec_idx < len(row) and row[sec_idx] is not None else ""
            raw_roll = str(row[roll_idx]).strip() if roll_idx < len(row) and row[roll_idx] is not None else ""
            raw_adm = str(row[adm_idx]).strip() if adm_idx < len(row) and row[adm_idx] is not None else ""
            raw_name = str(row[name_idx]).strip() if name_idx < len(row) and row[name_idx] is not None else ""
            raw_sub = str(row[sub_idx]).strip() if sub_idx < len(row) and row[sub_idx] is not None else ""
            raw_max = row[max_idx] if (max_idx != -1 and max_idx < len(row)) else None
            raw_obtained = row[marks_idx] if (marks_idx != -1 and marks_idx < len(row)) else None
            raw_status_val = str(row[status_idx]).strip().upper() if (status_idx != -1 and status_idx < len(row) and row[status_idx] is not None) else "PRESENT"
            raw_remarks_val = str(row[remarks_idx]).strip() if (remarks_idx != -1 and remarks_idx < len(row) and row[remarks_idx] is not None) else ""

            row_error = None
            is_valid = True
            is_existing_mark = False
            matched_sched = None
            matched_student = None
            matched_class = None
            matched_sec = None

            # Normalization
            norm_class = raw_class.lower().replace("class", "").strip()
            norm_sec = raw_sec.lower().replace("section", "").strip()
            norm_sub = raw_sub.lower().strip()

            if not raw_class or not raw_sec or (not raw_roll and not raw_adm) or not raw_sub:
                row_error = "Missing required fields (Class, Section, Roll/Admission No, or Subject)."
                is_valid = False

            # Validate Class
            if is_valid:
                matched_class = class_name_to_obj.get(norm_class) or class_name_to_obj.get(raw_class.lower().strip())
                if not matched_class:
                    row_error = f"Class '{raw_class}' not found in school."
                    is_valid = False
                else:
                    matched_c_uuid = uuid.UUID(str(matched_class.id))
                    if participating_class_ids and matched_c_uuid not in participating_class_ids:
                        row_error = f"Class '{raw_class}' does not participate in this examination cycle."
                        is_valid = False
                    elif allowed_class_ids and matched_c_uuid not in allowed_class_ids:
                        row_error = f"Class '{raw_class}' is not included in the selected import classes."
                        is_valid = False

            # Validate Section
            if is_valid and matched_class:
                matched_sec = sec_lookup.get((matched_class.id, norm_sec)) or sec_lookup.get((matched_class.id, raw_sec.lower().strip()))
                if not matched_sec:
                    row_error = f"Section '{raw_sec}' not found for Class '{raw_class}'."
                    is_valid = False
                elif allowed_section_ids and uuid.UUID(str(matched_sec.id)) not in allowed_section_ids:
                    row_error = f"Section '{raw_sec}' is not included in the selected import sections."
                    is_valid = False

            # Validate Student
            if is_valid and matched_class and matched_sec:
                norm_roll = raw_roll.lower().strip()
                norm_adm = raw_adm.lower().strip()
                matched_student = (
                    (student_map.get((matched_class.id, matched_sec.id, norm_adm)) if norm_adm else None) or
                    (student_map.get((matched_class.id, norm_adm)) if norm_adm else None) or
                    (student_map.get((matched_class.id, matched_sec.id, norm_roll)) if norm_roll else None) or
                    (student_map.get((matched_class.id, matched_sec.id, norm_roll.lstrip("0"))) if norm_roll else None) or
                    (student_map.get((matched_class.id, norm_roll)) if norm_roll else None) or
                    (student_map.get(norm_adm) if norm_adm else None)
                )
                if not matched_student:
                    identifier = raw_adm or raw_roll
                    row_error = f"Student with ID/Roll/Adm '{identifier}' not found in Class {raw_class} Section {raw_sec}."
                    is_valid = False

            # Validate Subject/Paper for this specific Class
            max_marks_val = 100
            resolved_subject_id = None
            resolved_subject_name = raw_sub

            if is_valid and matched_class and matched_sec:
                # 1. Try matching against existing schedule
                matched_sched = (
                    schedule_map.get((norm_class, norm_sec, norm_sub)) or
                    schedule_map.get((raw_class.lower(), raw_sec.lower(), norm_sub)) or
                    schedule_map.get((norm_class, norm_sec, raw_sub.lower()))
                )

                # 2. Try matching against ExamPaper / ExamPaperClass for this class
                paper_info = paper_lookup.get((norm_sub, matched_class.id)) or paper_lookup.get((norm_sub, None))
                if paper_info:
                    max_marks_val = paper_info[0]
                    resolved_subject_id = paper_info[2]
                    paper_id = paper_info[3]
                    resolved_subject_name = paper_info[4]

                    # Auto-provision or link schedule slot if missing
                    if not matched_sched:
                        matched_sched = schedule_by_ids.get((matched_class.id, matched_sec.id, resolved_subject_id))
                        if not matched_sched:
                            # Auto-provision an ExamSchedule for this class, section, paper
                            matched_sched = ExamSchedule(
                                tenant_id=tenant_id,
                                school_id=school_id,
                                academic_year_id=examination.academic_year_id,
                                exam_id=exam_id,
                                paper_id=paper_id,
                                class_id=matched_class.id,
                                section_id=matched_sec.id,
                                subject_id=resolved_subject_id,
                                exam_date=examination.start_date,
                                start_time=time(9, 30),
                                end_time=time(12, 30),
                                max_marks=max_marks_val,
                                pass_marks=paper_info[1],
                                room_number="Examination Hall"
                            )
                            self.marks_repo.db.add(matched_sched)
                            await self.marks_repo.db.flush()
                            schedule_by_ids[(matched_class.id, matched_sec.id, resolved_subject_id)] = matched_sched
                            schedules.append(matched_sched)
                            new_schedules_created = True
                elif matched_sched:
                    max_marks_val = matched_sched.max_marks
                    resolved_subject_id = matched_sched.subject_id
                    resolved_subject_name = matched_sched.subject.subject_name if matched_sched.subject else raw_sub
                else:
                    row_error = f"Subject '{raw_sub}' is not configured for Class {raw_class} in this examination cycle."
                    is_valid = False

            if raw_max is not None:
                try:
                    file_max = int(float(str(raw_max).strip()))
                    if file_max > 0:
                        max_marks_val = file_max
                except Exception:
                    pass

            # Intra-File Duplicate Detection
            if is_valid and matched_student and (resolved_subject_id or (matched_sched and matched_sched.subject_id)):
                s_id = resolved_subject_id or matched_sched.subject_id
                dup_key = (matched_student.id, s_id)
                if dup_key in seen_duplicates:
                    row_error = f"Duplicate marks entry for student '{raw_name or raw_roll}' in subject '{raw_sub}' within this file."
                    is_valid = False
                else:
                    seen_duplicates.add(dup_key)

            # Check Existing Mark in Database
            if is_valid and matched_student and matched_sched:
                existing = existing_sched_map.get((matched_student.id, matched_sched.id)) or (
                    existing_subj_map.get((matched_student.id, matched_class.id, matched_sched.subject_id)) if matched_class else None
                )
                if existing:
                    is_existing_mark = True
                    existing_marks_count += 1
                    if duplicate_behavior == "FAIL_DUPLICATE":
                        is_valid = False
                        row_error = f"Existing mark found for student '{raw_name or raw_roll}' in '{raw_sub}' (Duplicates not allowed)."

            # Marks Obtained Validation
            marks_val = None
            result_st = "PRESENT"
            if is_valid:
                raw_str = str(raw_obtained).strip().upper() if raw_obtained is not None else ""
                if raw_str in ["AB", "ABSENT", "A"]:
                    result_st = "ABSENT"
                elif raw_str in ["EX", "EXEMPTED"]:
                    result_st = "EXEMPTED"
                elif raw_str in ["MP", "MALPRACTICE"]:
                    result_st = "MALPRACTICE"
                elif raw_obtained is not None and str(raw_obtained).strip() != "":
                    try:
                        marks_val = round(float(str(raw_obtained).strip()), 2)
                        if marks_val < 0:
                            row_error = f"Marks cannot be negative ({marks_val})."
                            is_valid = False
                        elif marks_val > max_marks_val:
                            row_error = f"Marks obtained ({marks_val}) exceeds Maximum Marks ({max_marks_val}) for Class {raw_class}."
                            is_valid = False
                    except ValueError:
                        row_error = f"Invalid marks numeric value '{raw_obtained}'."
                        is_valid = False
                else:
                    marks_val = None

            # Track detected metadata
            if raw_class: classes_detected.add(raw_class)
            if raw_sec: sections_detected.add(f"{raw_class}-{raw_sec}")
            if raw_sub: subjects_detected.add(resolved_subject_name)
            if matched_student: students_detected.add(str(matched_student.id))

            # Grouped breakdown
            if is_valid and matched_class and matched_sec:
                c_display = matched_class.name
                s_display = matched_sec.name
                sub_display = resolved_subject_name
                grouped_summary.setdefault(c_display, {}).setdefault(s_display, {}).setdefault(sub_display, 0)
                grouped_summary[c_display][s_display][sub_display] += 1

            if not is_valid and row_error:
                errors_summary.append(f"Row {row_num} (Class {raw_class}-{raw_sec}, {raw_sub}, Roll {raw_roll}): {row_error}")

            preview_rows.append(
                ExamWideUploadRowPreview(
                    row_number=row_num,
                    class_name=raw_class,
                    section_name=raw_sec,
                    roll_number=raw_roll,
                    student_name=raw_name or (matched_student.full_name if matched_student else None),
                    subject_name=resolved_subject_name,
                    max_marks=max_marks_val,
                    marks_obtained=marks_val,
                    status=result_st,
                    remarks=raw_remarks_val,
                    is_valid=is_valid,
                    error_message=row_error,
                    student_id=str(matched_student.id) if matched_student else None,
                    exam_schedule_id=str(matched_sched.id) if matched_sched else None,
                    class_id=str(matched_class.id) if matched_class else (str(matched_sched.class_id) if matched_sched else None),
                    section_id=str(matched_sec.id) if matched_sec else (str(matched_sched.section_id) if matched_sched else None),
                    subject_id=str(resolved_subject_id) if resolved_subject_id else (str(matched_sched.subject_id) if matched_sched else None),
                    is_existing=is_existing_mark
                )
            )

        # Build classes_summary list
        classes_summary_list = []
        for c_k, sec_dict in sorted(grouped_summary.items()):
            sections_list = []
            for s_k, sub_dict in sorted(sec_dict.items()):
                subjects_list = [
                    {"subject_name": sub_k, "students_count": cnt}
                    for sub_k, cnt in sorted(sub_dict.items())
                ]
                sections_list.append({
                    "section_name": s_k,
                    "subjects": subjects_list
                })
            classes_summary_list.append({
                "class_name": c_k,
                "sections": sections_list
            })

        valid_count = sum(1 for r in preview_rows if r.is_valid)
        invalid_count = len(preview_rows) - valid_count

        if new_schedules_created:
            await self.marks_repo.db.commit()

        return ExamWideUploadPreviewResponse(
            total_rows=len(preview_rows),
            valid_rows_count=valid_count,
            invalid_rows_count=invalid_count,
            existing_marks_count=existing_marks_count,
            classes_detected=sorted(list(classes_detected)),
            sections_detected=sorted(list(sections_detected)),
            subjects_detected=sorted(list(subjects_detected)),
            students_count=len(students_detected),
            errors=errors_summary,
            classes_summary=classes_summary_list,
            preview_rows=preview_rows
        )

    async def confirm_exam_wide_marks(
        self,
        tenant_id: Optional[uuid.UUID] = None,
        school_id: Optional[uuid.UUID] = None,
        req: Optional[ExamWideUploadConfirmRequest] = None,
        current_user: Optional[User] = None,
        **kwargs
    ) -> ExamWideUploadSummary:
        if req is None:
            exam_id = kwargs.get("examination_id") or kwargs.get("exam_id")
            rows = kwargs.get("rows", [])
            auto_approve = kwargs.get("auto_approve", True)
            duplicate_behavior = kwargs.get("duplicate_behavior", "UPDATE_EXISTING")
            class_ids = kwargs.get("class_ids")
            section_ids = kwargs.get("section_ids")
            academic_year_id = kwargs.get("academic_year_id")
            req = ExamWideUploadConfirmRequest(
                exam_id=exam_id,
                school_id=school_id or uuid.uuid4(),
                rows=rows,
                auto_approve=auto_approve,
                duplicate_behavior=duplicate_behavior,
                class_ids=class_ids,
                section_ids=section_ids,
                academic_year_id=academic_year_id,
            )

        if tenant_id is None:
            res_t = await self.marks_repo.db.execute(select(Examination.tenant_id, Examination.school_id).where(Examination.id == req.exam_id))
            row_t = res_t.first()
            if row_t:
                tenant_id = row_t[0]
                if not school_id:
                    school_id = row_t[1]

        user_id = current_user.id if current_user else None

        # Load Examination with participating classes
        stmt_e = select(Examination).where(
            Examination.id == req.exam_id,
            Examination.school_id == school_id,
            Examination.tenant_id == tenant_id,
            Examination.deleted_at.is_(None)
        ).options(
            joinedload(Examination.participating_classes).joinedload(ExaminationClass.class_obj)
        )
        res_e = await self.marks_repo.db.execute(stmt_e)
        examination = res_e.unique().scalar_one_or_none()
        if not examination:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Examination not found.")

        # Academic year isolation check
        if req.academic_year_id and examination.academic_year_id != req.academic_year_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Selected academic year does not match examination cycle."
            )

        # Determine target participating classes
        target_class_ids = set()
        participating_class_objects = {}
        for pc in (examination.participating_classes or []):
            if pc.class_obj:
                c_uuid = uuid.UUID(str(pc.class_id))
                target_class_ids.add(c_uuid)
                participating_class_objects[c_uuid] = pc.class_obj

        if not target_class_ids and examination.settings and "class_ids" in examination.settings:
            raw_cids = examination.settings["class_ids"]
            if isinstance(raw_cids, list):
                for cid_str in raw_cids:
                    try:
                        c_uuid = uuid.UUID(str(cid_str))
                        target_class_ids.add(c_uuid)
                    except Exception:
                        pass

        if req.class_ids:
            requested_set = set(uuid.UUID(str(cid)) for cid in req.class_ids)
            target_class_ids = (target_class_ids & requested_set) if target_class_ids else requested_set
        elif req.class_id:
            requested_set = {uuid.UUID(str(req.class_id))}
            target_class_ids = (target_class_ids & requested_set) if target_class_ids else requested_set

        # Fetch Class entities for any missing class objects
        missing_cids = [cid for cid in target_class_ids if cid not in participating_class_objects]
        if missing_cids:
            stmt_cls = select(Class).where(Class.id.in_(missing_cids), Class.deleted_at.is_(None))
            res_cls = await self.marks_repo.db.execute(stmt_cls)
            for c in res_cls.scalars().all():
                participating_class_objects[c.id] = c

        # Pre-query sections and student counts for all expected classes
        expected_sections_map = {cid: [] for cid in target_class_ids}
        if target_class_ids:
            stmt_sec = select(Section).where(
                Section.class_id.in_(target_class_ids),
                Section.deleted_at.is_(None)
            )
            res_sec = await self.marks_repo.db.execute(stmt_sec)
            for sec in res_sec.scalars().all():
                expected_sections_map.setdefault(sec.class_id, []).append(sec.name)

        expected_students_map = {cid: 0 for cid in target_class_ids}
        if target_class_ids:
            stmt_st_cnt = select(Student.class_id, func.count(Student.id)).where(
                Student.class_id.in_(target_class_ids),
                Student.deleted_at.is_(None),
                Student.is_active == True
            ).group_by(Student.class_id)
            res_st_cnt = await self.marks_repo.db.execute(stmt_st_cnt)
            for cid, cnt in res_st_cnt.all():
                expected_students_map[cid] = cnt

        # Initialize class_stats for all expected participating classes
        class_stats: Dict[str, Dict[str, Any]] = {}
        for cid, c_obj in participating_class_objects.items():
            c_name = c_obj.name
            secs = expected_sections_map.get(cid, [])
            st_cnt = expected_students_map.get(cid, 0)
            class_stats[c_name] = {
                "class_id": str(cid),
                "class_name": c_name,
                "sections_count": len(secs),
                "sections": sorted(secs),
                "students_count": st_cnt,
                "total_records": 0,
                "created_count": 0,
                "updated_count": 0,
                "skipped_count": 0,
                "failed_count": 0,
                "processed": 0,
                "created": 0,
                "updated": 0,
                "skipped": 0,
                "failed": 0,
                "status": "NOT_FOUND",
                "reason": "No student marks records found in upload data for this class"
            }

        class_students_processed: Dict[str, set] = {cn: set() for cn in class_stats}
        class_sections_processed: Dict[str, set] = {cn: set() for cn in class_stats}

        # Fetch existing marks for this exam to update or skip existing records
        stmt_existing = select(Marks).where(
            Marks.examination_id == req.exam_id,
            Marks.school_id == school_id,
            Marks.tenant_id == tenant_id,
            Marks.deleted_at.is_(None)
        )
        res_ex = await self.marks_repo.db.execute(stmt_existing)
        existing_marks_list = list(res_ex.scalars().all())
        existing_map = {(m.student_id, m.exam_schedule_id): m for m in existing_marks_list}

        # Fetch schedules to get academic_year_id, teacher_id, etc.
        stmt_s = select(ExamSchedule).where(
            ExamSchedule.exam_id == req.exam_id,
            ExamSchedule.school_id == school_id,
            ExamSchedule.tenant_id == tenant_id,
            ExamSchedule.deleted_at.is_(None)
        )
        res_s = await self.marks_repo.db.execute(stmt_s)
        schedules_list = list(res_s.scalars().all())
        schedules = {s.id: s for s in schedules_list}
        schedules_by_combo = {(s.class_id, s.section_id, s.subject_id): s for s in schedules_list}

        # Fetch TeacherSubjectAssignments to resolve teacher_id and tsa_id
        stmt_tsa = select(TeacherSubjectAssignment).where(
            TeacherSubjectAssignment.school_id == school_id,
            TeacherSubjectAssignment.tenant_id == tenant_id,
            TeacherSubjectAssignment.deleted_at.is_(None)
        )
        res_tsa = await self.marks_repo.db.execute(stmt_tsa)
        all_tsas = list(res_tsa.scalars().all())
        tsa_map_by_id = {tsa.id: (tsa.teacher_id, tsa.id) for tsa in all_tsas}
        tsa_map_by_combo = {(tsa.class_id, tsa.section_id, tsa.subject_id): (tsa.teacher_id, tsa.id) for tsa in all_tsas}

        fallback_teacher_id = None
        fallback_tsa_id = None
        if all_tsas:
            fallback_teacher_id = all_tsas[0].teacher_id
            fallback_tsa_id = all_tsas[0].id
        else:
            teacher_stmt = select(Teacher.id).where(
                Teacher.school_id == school_id,
                Teacher.tenant_id == tenant_id,
                Teacher.deleted_at.is_(None)
            ).limit(1)
            fallback_teacher_id = (await self.marks_repo.db.execute(teacher_stmt)).scalar()
            if not fallback_teacher_id:
                u_hex = uuid.uuid4().hex[:6]
                sys_teacher = Teacher(
                    tenant_id=tenant_id,
                    school_id=school_id,
                    first_name="Exam",
                    last_name="Administrator",
                    employee_code=f"EXAM_ADMIN_{u_hex}",
                    staff_code=f"STF_ADMIN_{u_hex}",
                    official_email=f"exam_admin_{u_hex}@edupulse.local",
                    mobile=f"+9198765{u_hex[:5]}",
                    date_of_birth=date(1990, 1, 1),
                    joining_date=date.today(),
                    gender=StudentGender.MALE,
                    employment_type=EmploymentType.FULL_TIME,
                    status=TeacherStatus.ACTIVE
                )
                self.marks_repo.db.add(sys_teacher)
                await self.marks_repo.db.flush()
                fallback_teacher_id = sys_teacher.id

        saved_count = 0
        created_count = 0
        updated_count = 0
        skipped_count = 0
        failed_count = 0
        students_set = set()
        classes_set = set()
        sections_set = set()
        subjects_set = set()

        failure_breakdown: Dict[str, int] = {
            "Student not found": 0,
            "Paper not found": 0,
            "Wrong class": 0,
            "Wrong section": 0,
            "Duplicate": 0,
            "Invalid marks": 0,
            "Schedule missing": 0,
            "Other": 0
        }

        target_status = MarksStatus.PUBLISHED if req.auto_approve else MarksStatus.SUBMITTED
        duplicate_mode = req.duplicate_behavior or "UPDATE_EXISTING"

        for row in req.rows:
            c_name = row.class_name if row.class_name and row.class_name.strip() else "Unassigned Class"
            if c_name not in class_stats:
                class_stats[c_name] = {
                    "class_id": str(row.class_id) if row.class_id else None,
                    "class_name": c_name,
                    "sections_count": 0,
                    "sections": [],
                    "students_count": 0,
                    "total_records": 0,
                    "created_count": 0,
                    "updated_count": 0,
                    "skipped_count": 0,
                    "failed_count": 0,
                    "processed": 0,
                    "created": 0,
                    "updated": 0,
                    "skipped": 0,
                    "failed": 0,
                    "status": "PENDING",
                    "reason": None
                }
            class_stats[c_name]["total_records"] += 1
            class_stats[c_name]["processed"] += 1
            if row.section_name:
                class_sections_processed.setdefault(c_name, set()).add(row.section_name)
            if row.student_id:
                class_students_processed.setdefault(c_name, set()).add(str(row.student_id))

            if not row.is_valid:
                failed_count += 1
                class_stats[c_name]["failed_count"] += 1
                class_stats[c_name]["failed"] += 1
                err_msg = (row.error_message or "").lower()
                if "student" in err_msg:
                    failure_breakdown["Student not found"] += 1
                elif "paper" in err_msg or "subject" in err_msg:
                    failure_breakdown["Paper not found"] += 1
                elif "class" in err_msg:
                    failure_breakdown["Wrong class"] += 1
                elif "section" in err_msg:
                    failure_breakdown["Wrong section"] += 1
                elif "duplicate" in err_msg:
                    failure_breakdown["Duplicate"] += 1
                    if duplicate_mode == "FAIL_DUPLICATE":
                        raise HTTPException(
                            status_code=status.HTTP_409_CONFLICT,
                            detail=f"Duplicate mark detected: {row.error_message}"
                        )
                elif "mark" in err_msg:
                    failure_breakdown["Invalid marks"] += 1
                else:
                    failure_breakdown["Other"] += 1
                continue

            if not row.student_id:
                failed_count += 1
                class_stats[c_name]["failed_count"] += 1
                class_stats[c_name]["failed"] += 1
                failure_breakdown["Student not found"] += 1
                continue

            try:
                st_id = uuid.UUID(str(row.student_id))
                sched_id = uuid.UUID(str(row.exam_schedule_id)) if row.exam_schedule_id else None
                sched = schedules.get(sched_id) if sched_id else None

                # Resilient fallback: if sched is None, try resolving by (class_id, section_id, subject_id)
                if not sched and row.class_id and row.section_id and row.subject_id:
                    c_id = uuid.UUID(str(row.class_id))
                    sec_id = uuid.UUID(str(row.section_id))
                    sub_id = uuid.UUID(str(row.subject_id))
                    sched = schedules_by_combo.get((c_id, sec_id, sub_id))
                    if not sched:
                        sched = ExamSchedule(
                            tenant_id=tenant_id,
                            school_id=school_id,
                            academic_year_id=examination.academic_year_id,
                            exam_id=req.exam_id,
                            paper_id=None,
                            class_id=c_id,
                            section_id=sec_id,
                            subject_id=sub_id,
                            exam_date=examination.start_date,
                            start_time=time(9, 30),
                            end_time=time(12, 30),
                            max_marks=row.max_marks or 100,
                            pass_marks=int((row.max_marks or 100) * 0.35),
                            room_number="Examination Hall"
                        )
                        self.marks_repo.db.add(sched)
                        await self.marks_repo.db.flush()
                        schedules[sched.id] = sched
                        schedules_by_combo[(c_id, sec_id, sub_id)] = sched
                    sched_id = sched.id

                if not sched:
                    logger.error(f"Row {row.row_number} failed: ExamSchedule could not be resolved for class {row.class_name} subject {row.subject_name}")
                    failed_count += 1
                    class_stats[c_name]["failed_count"] += 1
                    class_stats[c_name]["failed"] += 1
                    failure_breakdown["Schedule missing"] += 1
                    continue

                res_status_enum = ExamResult(row.status) if row.status in ExamResult.__members__ else ExamResult.PRESENT
                grade_val = self._compute_grade(row.marks_obtained, row.max_marks) if row.marks_obtained is not None else None

                tsa_info = None
                if sched.teacher_subject_assignment_id:
                    tsa_info = tsa_map_by_id.get(sched.teacher_subject_assignment_id)
                if not tsa_info:
                    tsa_info = tsa_map_by_combo.get((sched.class_id, sched.section_id, sched.subject_id))

                if tsa_info:
                    t_id = tsa_info[0]
                    tsa_id = tsa_info[1]
                else:
                    t_id = fallback_teacher_id
                    tsa_id = sched.teacher_subject_assignment_id or fallback_tsa_id

                # If still no TSA (e.g. fresh environment), auto-provision one to satisfy DB constraint
                if not tsa_id and t_id:
                    auto_tsa = TeacherSubjectAssignment(
                        tenant_id=tenant_id,
                        school_id=school_id,
                        academic_year_id=sched.academic_year_id,
                        teacher_id=t_id,
                        class_id=sched.class_id,
                        section_id=sched.section_id,
                        subject_id=sched.subject_id,
                        assignment_type=AssignmentType.PRIMARY,
                        status=AssignmentStatus.ACTIVE,
                        weekly_periods=1,
                        effective_from=date.today()
                    )
                    self.marks_repo.db.add(auto_tsa)
                    await self.marks_repo.db.flush()
                    tsa_id = auto_tsa.id
                    tsa_map_by_id[auto_tsa.id] = (t_id, tsa_id)
                    tsa_map_by_combo[(sched.class_id, sched.section_id, sched.subject_id)] = (t_id, tsa_id)

                existing = existing_map.get((st_id, sched_id))
                if existing:
                    if duplicate_mode == "SKIP_EXISTING":
                        skipped_count += 1
                        class_stats[c_name]["skipped_count"] += 1
                        class_stats[c_name]["skipped"] += 1
                        continue
                    elif duplicate_mode == "FAIL_DUPLICATE":
                        raise HTTPException(
                            status_code=status.HTTP_409_CONFLICT,
                            detail=f"Duplicate mark detected for student '{row.student_name}' (Duplicates not allowed under FAIL_DUPLICATE policy)."
                        )
                    else: # UPDATE_EXISTING
                        existing.marks_obtained = row.marks_obtained
                        existing.maximum_marks = row.max_marks
                        existing.result_status = res_status_enum
                        existing.status = target_status
                        existing.grade = grade_val
                        existing.remarks = row.remarks
                        existing.updated_by = user_id
                        self.marks_repo.db.add(existing)
                        updated_count += 1
                        saved_count += 1
                        class_stats[c_name]["updated_count"] += 1
                        class_stats[c_name]["updated"] += 1
                else:
                    new_mark = Marks(
                        tenant_id=tenant_id,
                        school_id=school_id,
                        academic_year_id=sched.academic_year_id,
                        examination_id=req.exam_id,
                        exam_schedule_id=sched_id,
                        student_id=st_id,
                        teacher_subject_assignment_id=tsa_id,
                        teacher_id=t_id,
                        subject_id=sched.subject_id,
                        class_id=sched.class_id,
                        section_id=sched.section_id,
                        maximum_marks=row.max_marks,
                        marks_obtained=row.marks_obtained,
                        result_status=res_status_enum,
                        status=target_status,
                        grade=grade_val,
                        remarks=row.remarks,
                        created_by=user_id,
                        updated_by=user_id
                    )
                    self.marks_repo.db.add(new_mark)
                    created_count += 1
                    saved_count += 1
                    class_stats[c_name]["created_count"] += 1
                    class_stats[c_name]["created"] += 1

                students_set.add(str(st_id))
                classes_set.add(c_name)
                sections_set.add(f"{c_name}-{row.section_name}")
                subjects_set.add(row.subject_name)
            except HTTPException:
                raise
            except Exception as e:
                logger.error(f"Error saving row {row.row_number}: {e}")
                failed_count += 1
                class_stats[c_name]["failed_count"] += 1
                class_stats[c_name]["failed"] += 1
                failure_breakdown["Other"] += 1

        await self.marks_repo.db.commit()

        for c_name, st in class_stats.items():
            if st["total_records"] == 0:
                st["status"] = "NOT_FOUND"
                st["reason"] = "No student marks records found in upload data for this class"
            else:
                processed_secs = class_sections_processed.get(c_name, set())
                processed_st = class_students_processed.get(c_name, set())
                if processed_secs:
                    st["sections_count"] = len(processed_secs)
                    st["sections"] = sorted(list(processed_secs))
                if processed_st:
                    st["students_count"] = len(processed_st)

                if st["failed_count"] == st["total_records"]:
                    st["status"] = "FAILED"
                    st["reason"] = f"All {st['total_records']} rows failed validation"
                elif st["failed_count"] > 0:
                    st["status"] = "PARTIAL"
                    st["reason"] = f"{st['failed_count']} of {st['total_records']} rows encountered issues"
                else:
                    st["status"] = "SUCCESS"
                    st["reason"] = None

        classes_breakdown = [
            {
                "class_id": st.get("class_id"),
                "class_name": st["class_name"],
                "sections_count": st["sections_count"],
                "sections": st["sections"],
                "students_count": st["students_count"],
                "total_records": st["total_records"],
                "created_count": st["created_count"],
                "updated_count": st["updated_count"],
                "skipped_count": st["skipped_count"],
                "failed_count": st["failed_count"],
                "processed": st["processed"],
                "created": st["created"],
                "updated": st["updated"],
                "skipped": st["skipped"],
                "failed": st["failed"],
                "status": st["status"],
                "reason": st["reason"]
            }
            for st in sorted(class_stats.values(), key=lambda x: x["class_name"])
        ]

        return ExamWideUploadSummary(
            examination_id=req.exam_id,
            examination_name=examination.exam_name,
            students_processed=len(students_set),
            classes_count=len(classes_set),
            sections_count=len(sections_set),
            subjects_count=len(subjects_set),
            total_records=len(req.rows),
            saved_count=saved_count,
            created_count=created_count,
            updated_count=updated_count,
            skipped_count=skipped_count,
            failed_count=failed_count,
            classes_breakdown=classes_breakdown,
            failure_breakdown=failure_breakdown
        )

    async def publish_examination_marks(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        exam_id: uuid.UUID,
        current_user: User,
        class_id: Optional[uuid.UUID] = None,
        section_id: Optional[uuid.UUID] = None
    ) -> ExaminationPublishSummary:
        # 1. Fetch Examination
        stmt_e = select(Examination).where(
            Examination.id == exam_id,
            Examination.school_id == school_id,
            Examination.tenant_id == tenant_id,
            Examination.deleted_at.is_(None)
        )
        res_e = await self.marks_repo.db.execute(stmt_e)
        examination = res_e.scalar_one_or_none()
        if not examination:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Examination not found.")

        # 2. Fetch all schedules in scope
        stmt_s = select(ExamSchedule).where(
            ExamSchedule.exam_id == exam_id,
            ExamSchedule.school_id == school_id,
            ExamSchedule.tenant_id == tenant_id,
            ExamSchedule.deleted_at.is_(None)
        ).options(
            joinedload(ExamSchedule.class_obj),
            joinedload(ExamSchedule.section),
            joinedload(ExamSchedule.subject)
        )
        if class_id:
            stmt_s = stmt_s.where(ExamSchedule.class_id == class_id)
        if section_id:
            stmt_s = stmt_s.where(ExamSchedule.section_id == section_id)

        res_s = await self.marks_repo.db.execute(stmt_s)
        schedules = list(res_s.unique().scalars().all())
        if not schedules:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="No exam schedules found for this examination.")

        # 3. Calculate expected vs entered
        total_expected = 0
        marks_entered_count = 0
        missing_count = 0
        missing_breakdown = []

        # Fetch all marks for this examination in scope
        stmt_m = select(Marks).where(
            Marks.examination_id == exam_id,
            Marks.school_id == school_id,
            Marks.tenant_id == tenant_id,
            Marks.deleted_at.is_(None)
        )
        if class_id:
            stmt_m = stmt_m.where(Marks.class_id == class_id)
        if section_id:
            stmt_m = stmt_m.where(Marks.section_id == section_id)

        res_m = await self.marks_repo.db.execute(stmt_m)
        all_marks = list(res_m.scalars().all())
        marks_by_sched = {}
        for m in all_marks:
            marks_by_sched.setdefault(m.exam_schedule_id, []).append(m)

        for s in schedules:
            students = await self.marks_repo.get_class_students_sorted(s.class_id, s.section_id, school_id, tenant_id)
            sched_expected = len(students)
            sched_marks = marks_by_sched.get(s.id, [])
            sched_entered = len(sched_marks)
            sched_missing = max(0, sched_expected - sched_entered)

            total_expected += sched_expected
            marks_entered_count += sched_entered
            missing_count += sched_missing

            if sched_missing > 0:
                missing_breakdown.append({
                    "class_name": s.class_obj.name if s.class_obj else "Class",
                    "section_name": s.section.name if s.section else "Section",
                    "subject_name": s.subject.subject_name if s.subject else "Subject",
                    "class_id": str(s.class_id),
                    "section_id": str(s.section_id),
                    "schedule_id": str(s.id),
                    "missing_count": sched_missing,
                    "expected_count": sched_expected,
                    "entered_count": sched_entered
                })

        # 4. Transition all marks to PUBLISHED
        published_count = 0
        now_dt = datetime.now(timezone.utc)
        now_iso = now_dt.isoformat()
        user_name = f"{getattr(current_user, 'first_name', '')} {getattr(current_user, 'last_name', '')}".strip() or getattr(current_user, 'email', 'Administrator')

        for m in all_marks:
            if m.status != MarksStatus.LOCKED:
                m.status = MarksStatus.PUBLISHED
                m.audit_history = list(m.audit_history or []) + [{
                    "action": "EXAM_WIDE_PUBLISH",
                    "reason": "Complete examination publication",
                    "updated_by": str(current_user.id),
                    "updated_at": now_iso
                }]
                m.updated_by = current_user.id
                self.marks_repo.db.add(m)
                published_count += 1

        # Record publication metadata in examination settings
        examination.settings = dict(examination.settings or {})
        examination.settings["last_published_at"] = now_iso
        examination.settings["last_published_by_name"] = user_name
        examination.settings["last_published_by_id"] = str(current_user.id)

        # Also update Examination status to PUBLISHED if it was ongoing / marks entry / under review
        if examination.status not in [ExamStatus.COMPLETED, ExamStatus.ARCHIVED]:
            examination.status = ExamStatus.PUBLISHED
            self.marks_repo.db.add(examination)

        await self.marks_repo.db.commit()

        return ExaminationPublishSummary(
            examination_id=exam_id,
            examination_name=examination.exam_name,
            total_expected_records=total_expected,
            marks_entered_count=marks_entered_count,
            published_count=published_count,
            missing_count=missing_count,
            is_fully_published=(missing_count == 0),
            missing_breakdown=missing_breakdown
        )

    async def get_examination_result_readiness(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        exam_id: uuid.UUID,
        academic_year_id: Optional[uuid.UUID] = None,
        class_id: Optional[uuid.UUID] = None,
        section_id: Optional[uuid.UUID] = None,
        current_user: Optional[User] = None
    ) -> ExaminationResultReadiness:
        # 1. Fetch Examination
        stmt_e = select(Examination).where(
            Examination.id == exam_id,
            Examination.school_id == school_id,
            Examination.tenant_id == tenant_id,
            Examination.deleted_at.is_(None)
        )
        res_e = await self.marks_repo.db.execute(stmt_e)
        examination = res_e.scalar_one_or_none()
        if not examination:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Examination not found.")

        # 2. Fetch all schedules in scope
        stmt_s = select(ExamSchedule).where(
            ExamSchedule.exam_id == exam_id,
            ExamSchedule.school_id == school_id,
            ExamSchedule.tenant_id == tenant_id,
            ExamSchedule.deleted_at.is_(None)
        ).options(
            joinedload(ExamSchedule.class_obj),
            joinedload(ExamSchedule.section),
            joinedload(ExamSchedule.subject)
        )
        if class_id:
            stmt_s = stmt_s.where(ExamSchedule.class_id == class_id)
        if section_id:
            stmt_s = stmt_s.where(ExamSchedule.section_id == section_id)

        res_s = await self.marks_repo.db.execute(stmt_s)
        schedules = list(res_s.unique().scalars().all())

        # 3. Resolve class and section names
        class_name = None
        section_name = None
        if class_id:
            stmt_c = select(Class).where(Class.id == class_id)
            c_res = await self.marks_repo.db.execute(stmt_c)
            c_obj = c_res.scalar_one_or_none()
            if c_obj:
                class_name = c_obj.name
        if section_id:
            stmt_sec = select(Section).where(Section.id == section_id)
            sec_res = await self.marks_repo.db.execute(stmt_sec)
            sec_obj = sec_res.scalar_one_or_none()
            if sec_obj:
                section_name = sec_obj.name

        # 4. Resolve students
        students: List[Student] = []
        if class_id and section_id:
            students = await self.marks_repo.get_class_students_sorted(class_id, section_id, school_id, tenant_id)
        elif class_id:
            students = await self.marks_repo.get_class_students_sorted(class_id, None, school_id, tenant_id)
        else:
            pairs = set((s.class_id, s.section_id) for s in schedules if s.class_id and s.section_id)
            seen_st_ids = set()
            for cid, sid in pairs:
                sub_st = await self.marks_repo.get_class_students_sorted(cid, sid, school_id, tenant_id)
                for st in sub_st:
                    if st.id not in seen_st_ids:
                        seen_st_ids.add(st.id)
                        students.append(st)

        # 5. Fetch all marks in scope
        stmt_m = select(Marks).where(
            Marks.examination_id == exam_id,
            Marks.school_id == school_id,
            Marks.tenant_id == tenant_id,
            Marks.deleted_at.is_(None)
        )
        if class_id:
            stmt_m = stmt_m.where(Marks.class_id == class_id)
        if section_id:
            stmt_m = stmt_m.where(Marks.section_id == section_id)

        res_m = await self.marks_repo.db.execute(stmt_m)
        all_marks = list(res_m.scalars().all())

        marks_by_student: Dict[uuid.UUID, List[Marks]] = {}
        for m in all_marks:
            marks_by_student.setdefault(m.student_id, []).append(m)

        schedules_by_cs: Dict[Tuple[uuid.UUID, uuid.UUID], List[ExamSchedule]] = {}
        for s in schedules:
            if s.class_id and s.section_id:
                schedules_by_cs.setdefault((s.class_id, s.section_id), []).append(s)

        # 6. Evaluate per-student completion
        student_statuses: List[StudentResultReadinessItem] = []
        complete_count = 0
        incomplete_count = 0
        draft_count = 0
        ready_to_publish_count = 0
        published_count = 0

        for st in students:
            req_scheds = schedules_by_cs.get((st.class_id, st.section_id), [])
            if not req_scheds:
                req_scheds = [s for s in schedules if s.class_id == st.class_id]

            total_req = len(req_scheds)
            st_marks = marks_by_student.get(st.id, [])
            marked_sched_ids = {m.exam_schedule_id for m in st_marks}
            missing_scheds = [s for s in req_scheds if s.id not in marked_sched_ids]
            missing_subjects = [s.subject.subject_name for s in missing_scheds if s.subject]

            is_complete = (total_req > 0 and len(missing_scheds) == 0)
            if is_complete:
                complete_count += 1
                if all(m.status == MarksStatus.PUBLISHED for m in st_marks):
                    st_status = "PUBLISHED"
                    published_count += 1
                else:
                    st_status = "READY_TO_PUBLISH"
                    ready_to_publish_count += 1
                    draft_count += 1
            else:
                incomplete_count += 1
                st_status = "INCOMPLETE"
                if st_marks:
                    draft_count += 1

            student_statuses.append(StudentResultReadinessItem(
                student_id=st.id,
                student_name=f"{st.first_name} {st.last_name}".strip(),
                roll_number=st.roll_number or "",
                admission_number=st.admission_number or "",
                status=st_status,
                total_required_papers=total_req,
                entered_papers=len(st_marks),
                is_complete=is_complete,
                missing_subjects=missing_subjects
            ))

        total_students = len(students)
        is_fully_published = (total_students > 0 and published_count == total_students)
        is_ready = (total_students > 0 and incomplete_count == 0 and not is_fully_published)

        if total_students == 0:
            publication_status = "NOT_STARTED"
            status_msg = "No students enrolled in the selected class and section."
        elif is_fully_published:
            publication_status = "PUBLISHED"
            status_msg = f"All {total_students} student results are published and visible to parents."
        elif published_count > 0:
            publication_status = "PARTIALLY_PUBLISHED"
            status_msg = f"{published_count} of {total_students} students published. {incomplete_count} remain incomplete."
        elif is_ready:
            publication_status = "READY_TO_PUBLISH"
            status_msg = f"All {total_students} student results are complete and ready to publish."
        else:
            publication_status = "IN_PROGRESS"
            status_msg = f"{incomplete_count} student{'s' if incomplete_count > 1 else ''} remain incomplete. Complete all required marks before publishing."

        missing_breakdown = []
        for s in schedules:
            sched_marks = [m for m in all_marks if m.exam_schedule_id == s.id]
            st_in_sched = [st for st in students if st.class_id == s.class_id and (not s.section_id or st.section_id == s.section_id)]
            sched_missing = max(0, len(st_in_sched) - len(sched_marks))
            if sched_missing > 0:
                missing_breakdown.append({
                    "class_name": s.class_obj.name if s.class_obj else "Class",
                    "section_name": s.section.name if s.section else "Section",
                    "subject_name": s.subject.subject_name if s.subject else "Subject",
                    "missing_count": sched_missing,
                    "expected_count": len(st_in_sched),
                    "entered_count": len(sched_marks)
                })

        can_unpublish = False
        if current_user:
            role_codes = {r.code for r in current_user.roles}
            can_unpublish = current_user.is_superuser or any(c in ["SUPER_ADMIN", "SCHOOL_ADMIN", "PRINCIPAL"] for c in role_codes)

        settings = examination.settings or {}
        return ExaminationResultReadiness(
            examination_id=exam_id,
            examination_name=examination.exam_name,
            academic_year_id=academic_year_id or examination.academic_year_id,
            class_id=class_id,
            class_name=class_name,
            section_id=section_id,
            section_name=section_name,
            total_students=total_students,
            students_with_complete_results=complete_count,
            students_with_incomplete_results=incomplete_count,
            draft_results_count=draft_count,
            ready_to_publish_count=ready_to_publish_count,
            published_count=published_count,
            is_ready_to_publish=is_ready,
            is_fully_published=is_fully_published,
            publication_status=publication_status,
            last_published_date=settings.get("last_published_at"),
            published_by_name=settings.get("last_published_by_name"),
            status_message=status_msg,
            missing_breakdown=missing_breakdown,
            student_statuses=student_statuses,
            can_unpublish=can_unpublish
        )

    async def unpublish_examination_marks(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        exam_id: uuid.UUID,
        current_user: User,
        class_id: Optional[uuid.UUID] = None,
        section_id: Optional[uuid.UUID] = None,
        reason: Optional[str] = None
    ) -> Dict[str, Any]:
        # 1. Fetch Examination
        stmt_e = select(Examination).where(
            Examination.id == exam_id,
            Examination.school_id == school_id,
            Examination.tenant_id == tenant_id,
            Examination.deleted_at.is_(None)
        )
        res_e = await self.marks_repo.db.execute(stmt_e)
        examination = res_e.scalar_one_or_none()
        if not examination:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Examination not found.")

        # 2. Fetch published marks in scope
        stmt_m = select(Marks).where(
            Marks.examination_id == exam_id,
            Marks.school_id == school_id,
            Marks.tenant_id == tenant_id,
            Marks.status == MarksStatus.PUBLISHED,
            Marks.deleted_at.is_(None)
        )
        if class_id:
            stmt_m = stmt_m.where(Marks.class_id == class_id)
        if section_id:
            stmt_m = stmt_m.where(Marks.section_id == section_id)

        res_m = await self.marks_repo.db.execute(stmt_m)
        published_marks = list(res_m.scalars().all())

        now_iso = datetime.now(timezone.utc).isoformat()
        for m in published_marks:
            m.status = MarksStatus.APPROVED
            m.audit_history = list(m.audit_history or []) + [{
                "action": "EXAM_WIDE_UNPUBLISH",
                "reason": reason or "Administrative reopen for marks correction",
                "updated_by": str(current_user.id),
                "updated_at": now_iso
            }]
            m.updated_by = current_user.id
            self.marks_repo.db.add(m)

        # If examination was marked PUBLISHED, revert to APPROVED or ONGOING
        if examination.status == ExamStatus.PUBLISHED:
            examination.status = ExamStatus.APPROVED
            self.marks_repo.db.add(examination)

        await self.marks_repo.db.commit()

        return {
            "examination_id": str(exam_id),
            "unpublished_count": len(published_marks),
            "message": f"Successfully unpublished {len(published_marks)} marks. Results reopened for editing."
        }


    async def generate_exam_wide_template(
        self,
        tenant_id: Optional[uuid.UUID] = None,
        school_id: Optional[uuid.UUID] = None,
        exam_id: Optional[uuid.UUID] = None,
        class_ids: Optional[List[uuid.UUID]] = None,
        section_ids: Optional[List[uuid.UUID]] = None,
        **kwargs
    ) -> ExamWideTemplateBytes:
        import io
        from openpyxl import Workbook
        from openpyxl.styles import Font, PatternFill, Alignment

        if exam_id is None:
            exam_id = kwargs.get("examination_id") or kwargs.get("exam_id")

        if tenant_id is None:
            res_t = await self.marks_repo.db.execute(select(Examination.tenant_id, Examination.school_id).where(Examination.id == exam_id))
            row_t = res_t.first()
            if row_t:
                tenant_id = row_t[0]
                if not school_id:
                    school_id = row_t[1]

        # 1. Fetch Examination with participating classes and papers
        stmt_e = select(Examination).where(
            Examination.id == exam_id,
            Examination.school_id == school_id,
            Examination.tenant_id == tenant_id,
            Examination.deleted_at.is_(None)
        ).options(
            joinedload(Examination.participating_classes).joinedload(ExaminationClass.class_obj),
            joinedload(Examination.papers).joinedload(ExamPaper.class_configs),
            joinedload(Examination.papers).joinedload(ExamPaper.subject)
        )
        res_e = await self.marks_repo.db.execute(stmt_e)
        examination = res_e.unique().scalar_one_or_none()
        if not examination:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Examination not found.")

        # Determine target participating classes
        target_class_ids = set()
        for pc in (examination.participating_classes or []):
            if pc.class_obj:
                target_class_ids.add(uuid.UUID(str(pc.class_id)))

        if not target_class_ids and examination.settings and "class_ids" in examination.settings:
            raw_cids = examination.settings["class_ids"]
            if isinstance(raw_cids, list):
                for cid_str in raw_cids:
                    try:
                        target_class_ids.add(uuid.UUID(str(cid_str)))
                    except Exception:
                        pass

        if class_ids:
            requested_set = set(uuid.UUID(str(cid)) for cid in class_ids)
            target_class_ids = (target_class_ids & requested_set) if target_class_ids else requested_set

        normalized_sec_ids = set(uuid.UUID(str(sid)) for sid in section_ids) if section_ids else None

        # Fetch schedules
        stmt_s = select(ExamSchedule).where(
            ExamSchedule.exam_id == exam_id,
            ExamSchedule.school_id == school_id,
            ExamSchedule.tenant_id == tenant_id,
            ExamSchedule.deleted_at.is_(None)
        ).options(
            joinedload(ExamSchedule.class_obj),
            joinedload(ExamSchedule.section),
            joinedload(ExamSchedule.subject)
        ).order_by(ExamSchedule.class_id, ExamSchedule.section_id)

        if target_class_ids:
            stmt_s = stmt_s.where(ExamSchedule.class_id.in_(target_class_ids))
        if normalized_sec_ids:
            stmt_s = stmt_s.where(ExamSchedule.section_id.in_(normalized_sec_ids))

        res_s = await self.marks_repo.db.execute(stmt_s)
        schedules = list(res_s.unique().scalars().all())

        wb = Workbook()
        ws = wb.active
        ws.title = "Exam Marks"

        # Headers
        headers = ["Class", "Section", "Roll No", "Student Name", "Subject", "Max Marks", "Marks Obtained", "Status", "Remarks"]
        ws.append(headers)

        header_font = Font(name="Calibri", size=11, bold=True, color="FFFFFF")
        header_fill = PatternFill(start_color="1A365D", end_color="1A365D", fill_type="solid")
        for col_idx in range(1, len(headers) + 1):
            cell = ws.cell(row=1, column=col_idx)
            cell.font = header_font
            cell.fill = header_fill
            cell.alignment = Alignment(horizontal="center", vertical="center")

        # Track which (class, section, subject) combinations were handled by schedules
        handled_combos = set()
        for s in schedules:
            handled_combos.add((s.class_id, s.section_id, s.subject_id))
            students = await self.marks_repo.get_class_students_sorted(s.class_id, s.section_id, school_id, tenant_id)
            c_name = s.class_obj.name if s.class_obj else "Class"
            sec_name = s.section.name if s.section else "Section"
            sub_name = s.subject.subject_name if s.subject else "Subject"

            for st in students:
                ws.append([
                    c_name,
                    sec_name,
                    st.roll_number or "",
                    st.full_name or "",
                    sub_name,
                    s.max_marks,
                    "",
                    "PRESENT",
                    ""
                ])

        # If there are participating classes / papers that don't have schedules yet, also pre-populate them!
        if examination.papers and target_class_ids:
            stmt_classes = select(Class).where(Class.id.in_(target_class_ids), Class.deleted_at.is_(None))
            classes_objs = {c.id: c for c in (await self.marks_repo.db.execute(stmt_classes)).scalars().all()}

            stmt_sections = select(Section).where(Section.class_id.in_(target_class_ids), Section.deleted_at.is_(None))
            if section_ids:
                stmt_sections = stmt_sections.where(Section.id.in_(section_ids))
            sections_objs = (await self.marks_repo.db.execute(stmt_sections)).scalars().all()

            for sec in sections_objs:
                c_obj = classes_objs.get(sec.class_id)
                if not c_obj:
                    continue
                students = await self.marks_repo.get_class_students_sorted(sec.class_id, sec.id, school_id, tenant_id)
                for paper in examination.papers:
                    if (sec.class_id, sec.id, paper.subject_id) in handled_combos:
                        continue
                    handled_combos.add((sec.class_id, sec.id, paper.subject_id))
                    sub_name = paper.subject.subject_name if paper.subject else paper.paper_name

                    # class override max marks
                    override_max = paper.default_max_marks
                    for cc in (paper.class_configs or []):
                        if cc.class_id == sec.class_id and cc.maximum_marks is not None:
                            override_max = cc.maximum_marks
                            break

                    for st in students:
                        ws.append([
                            c_obj.name,
                            sec.name,
                            st.roll_number or "",
                            st.full_name or "",
                            sub_name,
                            override_max,
                            "",
                            "PRESENT",
                            ""
                        ])

        # Auto-adjust column widths
        for col in ws.columns:
            max_len = max(len(str(cell.value or "")) for cell in col)
            col_letter = col[0].column_letter
            ws.column_dimensions[col_letter].width = max(max_len + 4, 12)

        buf = io.BytesIO()
        wb.save(buf)
        safe_name = examination.exam_name.replace(' ', '_')
        return ExamWideTemplateBytes(buf.getvalue(), filename=f"{safe_name}_Template.xlsx")

    async def generate_class_all_subjects_template(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        exam_id: uuid.UUID,
        class_id: uuid.UUID,
        section_id: uuid.UUID
    ) -> Tuple[bytes, str]:
        import io
        from openpyxl import Workbook
        from openpyxl.styles import Font, PatternFill, Alignment, Border, Side

        # 1. Fetch Examination
        stmt_e = select(Examination).where(
            Examination.id == exam_id,
            Examination.school_id == school_id,
            Examination.tenant_id == tenant_id,
            Examination.deleted_at.is_(None)
        )
        res_e = await self.marks_repo.db.execute(stmt_e)
        examination = res_e.scalar_one_or_none()
        if not examination:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Examination not found.")

        # 2. Fetch all schedules for this class & section (or class-wide)
        stmt_s = select(ExamSchedule).where(
            ExamSchedule.exam_id == exam_id,
            ExamSchedule.class_id == class_id,
            or_(
                ExamSchedule.section_id == section_id,
                ExamSchedule.section_id.is_(None)
            ),
            ExamSchedule.school_id == school_id,
            ExamSchedule.tenant_id == tenant_id,
            ExamSchedule.deleted_at.is_(None)
        ).options(
            joinedload(ExamSchedule.class_obj),
            joinedload(ExamSchedule.section),
            joinedload(ExamSchedule.subject)
        ).order_by(ExamSchedule.created_at)

        res_s = await self.marks_repo.db.execute(stmt_s)
        schedules = list(res_s.unique().scalars().all())
        if not schedules:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="No examination schedules/papers configured for this class and section."
            )

        # De-duplicate by subject_id (prefer section-specific if both exist)
        subject_schedules: Dict[uuid.UUID, ExamSchedule] = {}
        for s in schedules:
            if s.subject_id not in subject_schedules or s.section_id == section_id:
                subject_schedules[s.subject_id] = s

        sorted_schedules = list(subject_schedules.values())

        # 3. Fetch enrolled students
        students = await self.marks_repo.get_class_students_sorted(class_id, section_id, school_id, tenant_id)
        if not students:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="No enrolled students found in this class and section."
            )

        c_name = sorted_schedules[0].class_obj.name if sorted_schedules[0].class_obj else "Class"
        sec_name = sorted_schedules[0].section.name if (sorted_schedules[0].section and sorted_schedules[0].section_id == section_id) else "Section"
        clean_c_name = c_name.replace(" ", "_")
        clean_sec_name = sec_name.replace(" ", "_")
        filename = f"{clean_c_name}_{clean_sec_name}_All_Subjects_Marks_Template.xlsx"

        wb = Workbook()
        ws = wb.active
        ws.title = "Marks Entry"

        # Construct headers
        headers = ["Roll No", "Student Name"]
        for s in sorted_schedules:
            sub_name = s.subject.subject_name if s.subject else "Subject"
            headers.append(format_subject_header(sub_name, s.max_marks))

        ws.append(headers)


        header_font = Font(name="Calibri", size=11, bold=True, color="FFFFFF")
        header_fill = PatternFill(start_color="1A365D", end_color="1A365D", fill_type="solid")
        thin_border = Border(
            left=Side(style="thin", color="D0D5DD"),
            right=Side(style="thin", color="D0D5DD"),
            top=Side(style="thin", color="D0D5DD"),
            bottom=Side(style="thin", color="D0D5DD")
        )
        center_align = Alignment(horizontal="center", vertical="center")
        left_align = Alignment(horizontal="left", vertical="center")

        for col_idx in range(1, len(headers) + 1):
            cell = ws.cell(row=1, column=col_idx)
            cell.font = header_font
            cell.fill = header_fill
            cell.alignment = center_align
            cell.border = thin_border

        # Existing marks lookup: (student_id, schedule_id) -> Marks
        sched_ids = [s.id for s in sorted_schedules]
        stmt_m = select(Marks).where(
            Marks.examination_id == exam_id,
            Marks.exam_schedule_id.in_(sched_ids),
            Marks.school_id == school_id,
            Marks.tenant_id == tenant_id,
            Marks.deleted_at.is_(None)
        )
        res_m = await self.marks_repo.db.execute(stmt_m)
        marks_map = {(m.student_id, m.exam_schedule_id): m for m in res_m.scalars().all()}

        # Populate student rows
        for row_idx, st in enumerate(students, start=2):
            row_data = [
                st.roll_number or "",
                st.full_name or ""
            ]
            for s in sorted_schedules:
                existing = marks_map.get((st.id, s.id))
                val = existing.marks_obtained if (existing and existing.marks_obtained is not None) else ""
                row_data.append(val)

            ws.append(row_data)

            # Apply formatting
            ws.cell(row=row_idx, column=1).alignment = center_align
            ws.cell(row=row_idx, column=1).border = thin_border
            ws.cell(row=row_idx, column=2).alignment = left_align
            ws.cell(row=row_idx, column=2).border = thin_border

            for col_idx in range(3, len(headers) + 1):
                c = ws.cell(row=row_idx, column=col_idx)
                c.alignment = center_align
                c.border = thin_border

        # Auto-adjust column widths
        ws.column_dimensions["A"].width = 14
        ws.column_dimensions["B"].width = 28
        for col_idx in range(3, len(headers) + 1):
            col_letter = ws.cell(row=1, column=col_idx).column_letter
            ws.column_dimensions[col_letter].width = 22

        buf = io.BytesIO()
        wb.save(buf)
        return buf.getvalue(), filename

    async def import_class_all_subjects_marks(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        exam_id: uuid.UUID,
        class_id: uuid.UUID,
        section_id: uuid.UUID,
        file_bytes: bytes,
        filename: str,
        current_user: User
    ) -> ClassAllSubjectsUploadSummary:
        import io
        import csv
        import re
        from openpyxl import load_workbook

        # 1. Fetch Examination
        stmt_e = select(Examination).where(
            Examination.id == exam_id,
            Examination.school_id == school_id,
            Examination.tenant_id == tenant_id,
            Examination.deleted_at.is_(None)
        )
        res_e = await self.marks_repo.db.execute(stmt_e)
        examination = res_e.scalar_one_or_none()
        if not examination:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Examination not found.")

        if examination.status in [ExamStatus.LOCKED, ExamStatus.ARCHIVED, ExamStatus.COMPLETED]:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Cannot upload marks because the examination is frozen."
            )

        # 2. Fetch all schedules for this class & section
        stmt_s = select(ExamSchedule).where(
            ExamSchedule.exam_id == exam_id,
            ExamSchedule.class_id == class_id,
            or_(
                ExamSchedule.section_id == section_id,
                ExamSchedule.section_id.is_(None)
            ),
            ExamSchedule.school_id == school_id,
            ExamSchedule.tenant_id == tenant_id,
            ExamSchedule.deleted_at.is_(None)
        ).options(
            joinedload(ExamSchedule.class_obj),
            joinedload(ExamSchedule.section),
            joinedload(ExamSchedule.subject),
            joinedload(ExamSchedule.teacher_subject_assignment)
        )
        res_s = await self.marks_repo.db.execute(stmt_s)
        schedules = list(res_s.unique().scalars().all())
        if not schedules:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="No examination schedules/papers configured for this class and section."
            )

        # De-duplicate by subject_id (prefer section-specific if both exist)
        subject_schedules: Dict[uuid.UUID, ExamSchedule] = {}
        for s in schedules:
            if s.subject_id not in subject_schedules or s.section_id == section_id:
                subject_schedules[s.subject_id] = s

        sorted_schedules = list(subject_schedules.values())

        # Build normalized lookup for each schedule
        schedule_by_norm: Dict[str, ExamSchedule] = {}
        for s in sorted_schedules:
            if not s.subject:
                continue
            sub_name = s.subject.subject_name
            sub_code = s.subject.subject_code or ""

            k_name = normalize_subject_header(sub_name)
            k_code = normalize_subject_header(sub_code)

            if k_name:
                schedule_by_norm[k_name] = s
            if k_code:
                schedule_by_norm[k_code] = s
            if k_code and k_name:
                schedule_by_norm[f"{k_code}{k_name}"] = s
                schedule_by_norm[f"{k_name}{k_code}"] = s

        # 3. Fetch enrolled students
        students = await self.marks_repo.get_class_students_sorted(class_id, section_id, school_id, tenant_id)
        if not students:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="No enrolled students found for this class and section."
            )

        student_by_roll = {}
        student_by_adm = {}
        student_by_name = {}
        for st in students:
            if st.roll_number:
                student_by_roll[str(st.roll_number).strip().lower()] = st
                try:
                    student_by_roll[str(int(str(st.roll_number).strip())).lower()] = st
                except Exception:
                    pass
            if st.admission_number:
                student_by_adm[str(st.admission_number).strip().lower()] = st
            if st.full_name:
                student_by_name[str(st.full_name).strip().lower()] = st

        # 4. Parse file
        # Production Structured Trace: [MARKS_UPLOAD_PARSE_STARTED]
        logger.info(
            "[MARKS_UPLOAD_PARSE_STARTED] exam_id=%s tenant_id=%s school_id=%s class_id=%s section_id=%s filename=%s file_size=%d",
            exam_id, tenant_id, school_id, class_id, section_id, filename, len(file_bytes)
        )

        is_csv = filename.lower().endswith(".csv")
        sheet_title = "CSV" if is_csv else "N/A"
        if is_csv:
            try:
                text_content = file_bytes.decode("utf-8-sig", errors="replace")
                reader = csv.reader(io.StringIO(text_content))
                raw_rows = list(reader)
            except Exception as e:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Failed to parse CSV file: {str(e)}")
        else:
            try:
                wb = load_workbook(io.BytesIO(file_bytes), data_only=True)
                if "Marks Entry" in wb.sheetnames:
                    ws = wb["Marks Entry"]
                elif "ALL_SUBJECTS" in wb.sheetnames:
                    ws = wb["ALL_SUBJECTS"]
                else:
                    ws = wb.active
                sheet_title = ws.title
                raw_rows = [[cell.value for cell in row] for row in ws.iter_rows()]
            except Exception as e:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Failed to parse Excel workbook: {str(e)}")

        if not raw_rows or len(raw_rows) < 2:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="File is empty or missing data rows.")

        # Identify header row (scans first 5 rows to be resilient to metadata/empty rows)
        header_row_idx = 0
        for r_idx, r in enumerate(raw_rows[:5]):
            r_str = [str(c or "").strip().lower() for c in r if c is not None]
            if any("roll" in c or "admission" in c or ("student" in c and "name" in c) for c in r_str):
                header_row_idx = r_idx
                break

        header_row = [str(h or "").strip() for h in raw_rows[header_row_idx]]

        # Phase 3 Structured Logging: [MARKS UPLOAD RAW]
        logger.info(
            "[MARKS UPLOAD RAW] sheet_name=%s row_count=%d column_count=%d detected_header_row=%s",
            sheet_title,
            len(raw_rows),
            len(raw_rows[0]) if raw_rows else 0,
            header_row
        )

        roll_idx = -1
        name_idx = -1
        adm_idx = -1
        subject_cols: List[Tuple[int, ExamSchedule, str]] = []
        unmatched_headers: List[str] = []

        for idx, h in enumerate(header_row):
            if not h:
                continue
            h_lower = h.lower()
            h_norm = normalize_subject_header(h)

            # Strict identification checks to prevent stealing subject columns
            if roll_idx == -1 and (
                h_lower in ["roll no", "roll no.", "roll number", "roll", "roll_no", "rollno", "roll #", "r.no", "rno"]
                or h_norm in ["roll", "rollno", "rollnumber", "rno"]
            ):
                roll_idx = idx
                continue

            if adm_idx == -1 and (
                h_lower in ["admission no", "admission no.", "admission number", "adm no", "adm_no", "admno", "adm #", "admission_no", "admission"]
                or h_norm in ["admissionno", "admissionnumber", "admno", "admission"]
            ):
                adm_idx = idx
                continue

            if name_idx == -1 and (
                h_lower in ["student name", "name of student", "student_name", "studentname", "full name", "fullname", "student"]
                or h_norm in ["studentname", "nameofstudent", "fullname"]
                or ("student" in h_lower and "name" in h_lower and "subject" not in h_lower)
            ):
                name_idx = idx
                continue

            # Deterministic Subject Matching
            matched_sched = schedule_by_norm.get(h_norm)
            if not matched_sched:
                for s in sorted_schedules:
                    if not s.subject:
                        continue
                    sn_norm = normalize_subject_header(s.subject.subject_name)
                    sc_norm = normalize_subject_header(s.subject.subject_code or "")
                    if h_norm == sn_norm or (sc_norm and h_norm == sc_norm):
                        matched_sched = s
                        break

            logger.debug(
                "[MARKS UPLOAD NORMALIZED] header='%s' normalized='%s' matched_subject=%s",
                h,
                h_norm,
                matched_sched.subject_id if matched_sched else None
            )

            if matched_sched:
                sub_label = matched_sched.subject.subject_name if matched_sched.subject else h
                subject_cols.append((idx, matched_sched, sub_label))
            else:
                unmatched_headers.append(h)

        if roll_idx == -1 and name_idx == -1 and adm_idx == -1:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Could not detect student identification column ('Roll No', 'Student Name', or 'Admission No') in header."
            )

        # Check if the spreadsheet is in Long Format (Row per subject with subject_code/name and marks_obtained columns)
        is_long_format = False
        if not subject_cols:
            sub_code_col = -1
            sub_name_col = -1
            for i, h in enumerate(header_row):
                hl = h.lower()
                if any(k in hl for k in ["subject_code", "subject code", "sub_code", "paper_code", "subcode"]) or ("subject" in hl and "code" in hl):
                    if sub_code_col == -1:
                        sub_code_col = i
                elif any(k in hl for k in ["subject_name", "subject name", "sub_name", "subname", "paper_name"]) or ("subject" in hl and "name" in hl):
                    if sub_name_col == -1:
                        sub_name_col = i
                elif "subject" in hl or "paper" in hl:
                    if sub_name_col == -1 and sub_code_col != i:
                        sub_name_col = i

            marks_col = next((i for i, h in enumerate(header_row) if any(k in h.lower() for k in ["marks_obtained", "marks obtained", "mark_obtained", "marks", "mark", "obtained", "score"]) and "max" not in h.lower()), -1)
            max_col = next((i for i, h in enumerate(header_row) if any(k in h.lower() for k in ["maximum_marks", "max_marks", "maximum", "max"])), -1)
            status_col = next((i for i, h in enumerate(header_row) if any(k in h.lower() for k in ["result_status", "status", "attendance"])), -1)
            remarks_col = next((i for i, h in enumerate(header_row) if any(k in h.lower() for k in ["remarks", "remark", "note", "comment"])), -1)

            if (sub_code_col != -1 or sub_name_col != -1) and marks_col != -1:
                is_long_format = True

        if not subject_cols and not is_long_format:
            detected_headers = [str(h or "").strip() for h in header_row if str(h or "").strip()]
            normalized_headers = [normalize_subject_header(h) for h in detected_headers]
            expected_subjects = [
                f"{s.subject.subject_name} (Code: {s.subject.subject_code or 'N/A'}, Max: {s.max_marks})"
                if s.subject else f"Schedule {s.id}"
                for s in sorted_schedules
            ]
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"Could not detect any matching subject columns in the uploaded file for this class and examination. "
                    f"Detected spreadsheet headers: {detected_headers}. "
                    f"Normalized headers: {normalized_headers}. "
                    f"Expected scheduled subjects: {expected_subjects}."
                )
            )

        # Production Structured Trace: [MARKS_UPLOAD_PARSE_COMPLETE]
        logger.info(
            "[MARKS_UPLOAD_PARSE_COMPLETE] format=%s exam_id=%s tenant_id=%s school_id=%s rows_count=%d subject_cols=%d is_long_format=%s",
            "long-format" if is_long_format else "wide-format",
            exam_id, tenant_id, school_id, len(raw_rows), len(subject_cols), is_long_format
        )

        # 5. Teacher Resolution (Authenticated user teacher mapping)
        # Verify if current_user has an associated Teacher entity in this school
        stmt_cur_teacher = select(Teacher.id).where(
            Teacher.user_id == current_user.id,
            Teacher.school_id == school_id,
            Teacher.tenant_id == tenant_id,
            Teacher.deleted_at.is_(None)
        ).limit(1)
        res_cur_teacher = await self.marks_repo.db.execute(stmt_cur_teacher)
        current_user_teacher_id: Optional[uuid.UUID] = res_cur_teacher.scalar()

        # 6. Resolve TeacherSubjectAssignments for all class schedules
        sched_tsa_ids = {s.teacher_subject_assignment_id for s in sorted_schedules if s.teacher_subject_assignment_id}
        sched_subject_ids = {s.subject_id for s in sorted_schedules if s.subject_id}
        stmt_tsa = select(TeacherSubjectAssignment).where(
            TeacherSubjectAssignment.school_id == school_id,
            TeacherSubjectAssignment.tenant_id == tenant_id,
            TeacherSubjectAssignment.deleted_at.is_(None),
            TeacherSubjectAssignment.is_active.is_(True),
            or_(
                TeacherSubjectAssignment.id.in_(sched_tsa_ids) if sched_tsa_ids else False,
                TeacherSubjectAssignment.class_id == class_id,
                TeacherSubjectAssignment.subject_id.in_(sched_subject_ids) if sched_subject_ids else False
            )
        )
        res_tsa = await self.marks_repo.db.execute(stmt_tsa)
        tsa_list = list(res_tsa.scalars().all())

        tsa_by_id: Dict[uuid.UUID, TeacherSubjectAssignment] = {t.id: t for t in tsa_list}
        tsa_exact_sec: Dict[Tuple[uuid.UUID, uuid.UUID], TeacherSubjectAssignment] = {}
        tsa_class_wide: Dict[uuid.UUID, TeacherSubjectAssignment] = {}

        for t in tsa_list:
            if t.section_id == section_id:
                tsa_exact_sec[(t.class_id, t.subject_id)] = t
            elif t.section_id is None:
                if t.subject_id not in tsa_class_wide:
                    tsa_class_wide[t.subject_id] = t

        # Helper: Safe Teacher & TSA resolution per schedule following strict data integrity hierarchy
        schedule_resolutions: Dict[uuid.UUID, Dict[str, Any]] = {}

        def resolve_schedule_context(s: ExamSchedule, subject_label: str) -> Dict[str, Any]:
            if s.id in schedule_resolutions:
                return schedule_resolutions[s.id]

            # Priority 1: TeacherSubjectAssignment explicitly linked to schedule
            resolved_tsa = None
            if s.teacher_subject_assignment_id and s.teacher_subject_assignment_id in tsa_by_id:
                resolved_tsa = tsa_by_id[s.teacher_subject_assignment_id]
            elif (
                s.teacher_subject_assignment
                and s.teacher_subject_assignment.is_active
                and s.teacher_subject_assignment.deleted_at is None
                and s.teacher_subject_assignment.school_id == school_id
                and s.teacher_subject_assignment.tenant_id == tenant_id
            ):
                resolved_tsa = s.teacher_subject_assignment

            # Priority 2: Exact TSA matching school + class + section + subject
            if not resolved_tsa:
                resolved_tsa = tsa_exact_sec.get((s.class_id, s.subject_id))

            resolved_teacher_id = None
            resolved_tsa_id = None

            if resolved_tsa and resolved_tsa.teacher_id:
                resolved_teacher_id = resolved_tsa.teacher_id
                resolved_tsa_id = resolved_tsa.id
            elif current_user_teacher_id:
                # Priority 3: Valid Teacher mapped through current_user.id (Teacher.user_id == current_user.id AND Teacher.school_id == school_id)
                resolved_teacher_id = current_user_teacher_id
                resolved_tsa_id = (
                    resolved_tsa.id
                    if resolved_tsa
                    else (
                        s.teacher_subject_assignment_id
                        if s.teacher_subject_assignment_id
                        else (tsa_class_wide.get(s.subject_id).id if tsa_class_wide.get(s.subject_id) else None)
                    )
                )
                if not resolved_tsa_id:
                    for t in tsa_list:
                        if t.subject_id == s.subject_id:
                            resolved_tsa_id = t.id
                            break
            else:
                # Priority 4: Any other explicitly configured teacher relationship already present in existing domain model
                # (a) Class-wide TSA for this subject (section is None)
                if not resolved_tsa:
                    resolved_tsa = tsa_class_wide.get(s.subject_id)
                # (b) Any TSA for this class & subject in this school
                if not resolved_tsa:
                    for t in tsa_list:
                        if t.subject_id == s.subject_id and t.class_id == s.class_id:
                            resolved_tsa = t
                            break
                # (c) Any TSA for this subject in this school
                if not resolved_tsa:
                    for t in tsa_list:
                        if t.subject_id == s.subject_id:
                            resolved_tsa = t
                            break

                if resolved_tsa and resolved_tsa.teacher_id:
                    resolved_teacher_id = resolved_tsa.teacher_id
                    resolved_tsa_id = resolved_tsa.id

            # Priority 5: Otherwise raise HTTP 422 (never use arbitrary active teacher or current_user.id)
            if not resolved_teacher_id or not resolved_tsa_id:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=(
                        f"Cannot upload marks for subject '{subject_label}': No assigned teacher or Teacher Subject Assignment "
                        f"is configured for class/section in this school, and the current user is not mapped to an active teacher. "
                        f"Please assign a teacher to this subject schedule before uploading marks."
                    )
                )

            ctx = {
                "tsa_id": resolved_tsa_id,
                "teacher_id": resolved_teacher_id,
                "subject_name": subject_label
            }
            schedule_resolutions[s.id] = ctx
            return ctx

        # Pre-resolve for all sorted_schedules
        for s in sorted_schedules:
            sub_title = s.subject.subject_name if s.subject else str(s.subject_id)
            try:
                resolve_schedule_context(s, sub_title)
            except HTTPException:
                pass

        # 7. Fetch all existing marks for this examination, class, section, and schedules
        all_sched_ids = {s.id for s in sorted_schedules}
        stmt_existing = select(Marks).where(
            Marks.examination_id == exam_id,
            Marks.class_id == class_id,
            or_(
                Marks.section_id == section_id,
                Marks.section_id.is_(None)
            ),
            Marks.exam_schedule_id.in_(all_sched_ids),
            Marks.school_id == school_id,
            Marks.tenant_id == tenant_id,
            Marks.deleted_at.is_(None)
        )
        res_ex = await self.marks_repo.db.execute(stmt_existing)
        existing_marks = list(res_ex.scalars().all())
        existing_map: Dict[Tuple[uuid.UUID, uuid.UUID], Marks] = {
            (m.student_id, m.exam_schedule_id): m for m in existing_marks
        }

        # Helper: Unified mark persistence and logging before creation
        def save_or_update_mark(
            matched_student: Student,
            sched: ExamSchedule,
            marks_val: Optional[float],
            res_status: ExamResult,
            raw_remarks_val: Optional[str]
        ) -> bool:
            nonlocal created_count, updated_count
            key = (matched_student.id, sched.id)
            sched_ctx = schedule_resolutions[sched.id]
            t_id = sched_ctx["teacher_id"]
            tsa_id = sched_ctx["tsa_id"]
            grade = self._compute_grade(marks_val, sched.max_marks) if marks_val is not None else None

            existing = existing_map.get(key)

            # Production Structured Diagnostic Trace: [MARKS_UPLOAD_RECORD]
            logger.info(
                "[MARKS_UPLOAD_RECORD] [MARKS DIAGNOSTIC] op=%s tenant=%s school=%s exam=%s class=%s section=%s "
                "student=%s subject=%s schedule=%s teacher=%s current_user=%s tsa=%s",
                "UPDATE" if existing else "INSERT",
                tenant_id,
                school_id,
                exam_id,
                class_id,
                section_id,
                matched_student.id,
                sched.subject_id,
                sched.id,
                t_id,
                current_user.id,
                tsa_id
            )

            if existing:
                existing.marks_obtained = marks_val
                existing.maximum_marks = sched.max_marks
                existing.result_status = res_status
                existing.grade = grade
                existing.remarks = raw_remarks_val or existing.remarks
                if t_id and (not existing.teacher_id or existing.teacher_id != t_id):
                    existing.teacher_id = t_id
                if tsa_id and (not existing.teacher_subject_assignment_id or existing.teacher_subject_assignment_id != tsa_id):
                    existing.teacher_subject_assignment_id = tsa_id
                existing.status = MarksStatus.SUBMITTED if existing.status == MarksStatus.DRAFT else existing.status
                existing.updated_at = datetime.now(timezone.utc)
                existing.updated_by = current_user.id
                self.marks_repo.db.add(existing)
                updated_count += 1
                return False
            else:
                new_mark = Marks(
                    tenant_id=tenant_id,
                    school_id=school_id,
                    examination_id=exam_id,
                    exam_schedule_id=sched.id,
                    student_id=matched_student.id,
                    class_id=class_id,
                    section_id=section_id,
                    subject_id=sched.subject_id,
                    academic_year_id=examination.academic_year_id,
                    teacher_id=t_id,
                    teacher_subject_assignment_id=tsa_id,
                    maximum_marks=sched.max_marks,
                    marks_obtained=marks_val,
                    result_status=res_status,
                    grade=grade,
                    status=MarksStatus.SUBMITTED,
                    remarks=raw_remarks_val,
                    created_by=current_user.id
                )
                self.marks_repo.db.add(new_mark)
                existing_map[key] = new_mark
                created_count += 1
                return True

        # Handle Long-Format Spreadsheet (e.g. quarterly dataset or per-subject rows)
        if is_long_format:
            logger.info(
                "[MARKS PARSER DETECTED] Long-format per-subject spreadsheet detected. sub_code_col=%s, sub_name_col=%s, marks_col=%s",
                sub_code_col,
                sub_name_col,
                marks_col
            )
            validation_errors: List[str] = []
            students_processed_set = set()
            subjects_detected_set = set()
            created_count = 0
            updated_count = 0
            failed_rows = 0

            for row_num, row in enumerate(raw_rows[header_row_idx + 1:], start=header_row_idx + 2):
                if not row or all(v is None or str(v).strip() == "" for v in row):
                    continue

                raw_roll = str(row[roll_idx]).strip() if (roll_idx != -1 and roll_idx < len(row) and row[roll_idx] is not None) else ""
                raw_name = str(row[name_idx]).strip() if (name_idx != -1 and name_idx < len(row) and row[name_idx] is not None) else ""
                raw_adm = str(row[adm_idx]).strip() if (adm_idx != -1 and adm_idx < len(row) and row[adm_idx] is not None) else ""

                matched_student = None
                if raw_roll:
                    matched_student = student_by_roll.get(raw_roll.lower())
                    if not matched_student:
                        try:
                            matched_student = student_by_roll.get(str(int(raw_roll)).lower())
                        except Exception:
                            pass
                if not matched_student and raw_adm:
                    matched_student = student_by_adm.get(raw_adm.lower())
                if not matched_student and raw_name:
                    matched_student = student_by_name.get(raw_name.lower())

                student_label = matched_student.full_name if matched_student else (raw_name or f"Roll {raw_roll}" or f"Row {row_num}")

                if not matched_student:
                    failed_rows += 1
                    validation_errors.append(f"Row {row_num}: Could not identify enrolled student (Roll: '{raw_roll}', Name: '{raw_name}').")
                    continue

                students_processed_set.add(matched_student.id)

                # Identify subject
                raw_sub_code = str(row[sub_code_col]).strip() if (sub_code_col != -1 and sub_code_col < len(row) and row[sub_code_col] is not None) else ""
                raw_sub_name = str(row[sub_name_col]).strip() if (sub_name_col != -1 and sub_name_col < len(row) and row[sub_name_col] is not None) else ""

                matched_sched = None
                for key in [normalize_subject_header(raw_sub_code), normalize_subject_header(raw_sub_name)]:
                    if key and key in schedule_by_norm:
                        matched_sched = schedule_by_norm[key]
                        break

                if not matched_sched:
                    failed_rows += 1
                    validation_errors.append(f"Row {row_num} ({matched_student.full_name}): Unrecognized subject '{raw_sub_code or raw_sub_name}'.")
                    continue

                subjects_detected_set.add(matched_sched.id)

                # Ensure schedule context is resolved
                sub_title = matched_sched.subject.subject_name if matched_sched.subject else str(matched_sched.subject_id)
                resolve_schedule_context(matched_sched, sub_title)

                # Parse mark
                raw_mark_val = row[marks_col] if marks_col < len(row) else None
                raw_status_val = str(row[status_col]).strip().upper() if (status_col != -1 and status_col < len(row) and row[status_col] is not None) else "PRESENT"
                raw_remarks_val = str(row[remarks_col]).strip() if (remarks_col != -1 and remarks_col < len(row) and row[remarks_col] is not None) else ""

                # Result status
                res_status = ExamResult.PRESENT
                if "ABSENT" in raw_status_val or raw_status_val == "A":
                    res_status = ExamResult.ABSENT
                    marks_val = 0.0
                elif "EXEMPT" in raw_status_val or raw_status_val == "E":
                    res_status = ExamResult.EXEMPTED
                    marks_val = None
                elif "MALPRACTICE" in raw_status_val or raw_status_val == "M":
                    res_status = ExamResult.MALPRACTICE
                    marks_val = 0.0
                else:
                    try:
                        if raw_mark_val is not None and str(raw_mark_val).strip() != "":
                            marks_val = float(str(raw_mark_val).strip())
                            if marks_val < 0:
                                validation_errors.append(f"Row {row_num} ({matched_student.full_name}): Negative marks ({marks_val}) not allowed.")
                                failed_rows += 1
                                continue
                            if marks_val > matched_sched.max_marks:
                                validation_errors.append(f"Row {row_num} ({matched_student.full_name}): Marks ({marks_val}) exceed Maximum Marks ({matched_sched.max_marks}) for {matched_sched.subject.subject_name if matched_sched.subject else 'Subject'}.")
                                failed_rows += 1
                                continue
                        else:
                            marks_val = None
                    except ValueError:
                        validation_errors.append(f"Row {row_num} ({matched_student.full_name}): Invalid marks value '{raw_mark_val}'.")
                        failed_rows += 1
                        continue

                # Upsert mark using unified helper
                save_or_update_mark(matched_student, matched_sched, marks_val, res_status, raw_remarks_val)

            # Production Structured Trace: [MARKS_UPLOAD_DB_PRE_FLUSH]
            logger.info(
                "[MARKS_UPLOAD_DB_PRE_FLUSH] [MARKS BATCH PRE-FLUSH] format=long-format tenant_id=%s school_id=%s exam_id=%s class_id=%s section_id=%s "
                "current_user_id=%s schedules_count=%d students_processed=%d marks_created=%d marks_updated=%d",
                tenant_id,
                school_id,
                exam_id,
                class_id,
                section_id,
                current_user.id,
                len(sorted_schedules),
                len(students_processed_set),
                created_count,
                updated_count
            )
            # Wrap commit in try/except Exception with rollback, traceback, [MARKS_UPLOAD_DB_COMMIT_ERROR], and re-raise
            try:
                await self.marks_repo.db.flush()
                await self.marks_repo.db.commit()
                # Production Structured Trace: [MARKS_UPLOAD_DB_COMMIT_SUCCESS]
                logger.info(
                    "[MARKS_UPLOAD_DB_COMMIT_SUCCESS] format=long-format tenant_id=%s school_id=%s exam_id=%s class_id=%s section_id=%s marks_created=%d marks_updated=%d",
                    tenant_id, school_id, exam_id, class_id, section_id, created_count, updated_count
                )
            except Exception as exc:
                await self.marks_repo.db.rollback()
                endpoint_path = f"/api/v1/marks/examinations/{exam_id}/upload-class-all-subjects"
                logger.error(
                    "[MARKS_UPLOAD_DB_COMMIT_ERROR] [MARKS_UPLOAD_ERROR] %s: %s | path=%s exam_id=%s tenant_id=%s school_id=%s",
                    type(exc).__name__,
                    str(exc),
                    endpoint_path,
                    exam_id,
                    tenant_id,
                    school_id,
                    exc_info=True
                )
                raise

            c_obj = schedules[0].class_obj if schedules else None
            sec_obj = schedules[0].section if schedules else None
            c_title = c_obj.name if c_obj else "Class"
            sec_title = sec_obj.name if sec_obj else "Section"

            return ClassAllSubjectsUploadSummary(
                total_students_processed=len(students_processed_set),
                total_subjects_detected=len(subjects_detected_set),
                total_marks_created=created_count,
                total_marks_updated=updated_count,
                failed_rows=failed_rows,
                validation_errors=validation_errors,
                examination_name=examination.exam_name,
                class_name=c_title,
                section_name=sec_title
            )

        # Wide-Format Spreadsheet processing
        validation_errors: List[str] = []
        students_processed_set = set()
        created_count = 0
        updated_count = 0
        failed_rows = 0

        # Pre-resolve all detected subject columns (raises HTTP 422 if teacher or TSA missing)
        for col_idx, sched, sub_name in subject_cols:
            resolve_schedule_context(sched, sub_name)

        for row_num, row in enumerate(raw_rows[header_row_idx + 1:], start=header_row_idx + 2):
            if not row or all(v is None or str(v).strip() == "" for v in row):
                continue

            matched_student = None
            raw_roll = str(row[roll_idx]).strip() if (roll_idx != -1 and roll_idx < len(row) and row[roll_idx] is not None) else ""
            raw_name = str(row[name_idx]).strip() if (name_idx != -1 and name_idx < len(row) and row[name_idx] is not None) else ""
            raw_adm = str(row[adm_idx]).strip() if (adm_idx != -1 and adm_idx < len(row) and row[adm_idx] is not None) else ""

            if raw_roll:
                matched_student = student_by_roll.get(raw_roll.lower())
                if not matched_student:
                    try:
                        matched_student = student_by_roll.get(str(int(raw_roll)).lower())
                    except Exception:
                        pass
            if not matched_student and raw_adm:
                matched_student = student_by_adm.get(raw_adm.lower())
            if not matched_student and raw_name:
                matched_student = student_by_name.get(raw_name.lower())

            student_label = matched_student.full_name if matched_student else (raw_name or f"Roll {raw_roll}" or f"Row {row_num}")

            if not matched_student:
                failed_rows += 1
                validation_errors.append(f"Row {row_num}: Could not identify enrolled student (Roll: '{raw_roll}', Name: '{raw_name}').")
                continue

            students_processed_set.add(matched_student.id)

            for col_idx, sched, sub_name in subject_cols:
                if col_idx >= len(row) or row[col_idx] is None:
                    continue

                raw_cell = str(row[col_idx]).strip()
                if raw_cell == "":
                    continue

                raw_cell_upper = raw_cell.upper()
                if raw_cell_upper in ["AB", "ABSENT", "A"]:
                    res_status = ExamResult.ABSENT
                    marks_val = 0.0
                elif raw_cell_upper in ["EX", "EXEMPTED"]:
                    res_status = ExamResult.EXEMPTED
                    marks_val = None
                elif raw_cell_upper in ["MP", "MALPRACTICE"]:
                    res_status = ExamResult.MALPRACTICE
                    marks_val = 0.0
                else:
                    try:
                        marks_val = float(raw_cell)
                    except ValueError:
                        validation_errors.append(f"Row {row_num} ({student_label}) - {sub_name}: Invalid numeric value '{raw_cell}'.")
                        continue

                    if marks_val < 0.0:
                        validation_errors.append(f"Row {row_num} ({student_label}) - {sub_name}: Marks cannot be negative ({marks_val}).")
                        continue
                    if marks_val > sched.max_marks:
                        validation_errors.append(f"Row {row_num} ({student_label}) - {sub_name}: Mark {marks_val} exceeds maximum allowed {sched.max_marks}.")
                        continue

                    res_status = ExamResult.PRESENT

                # Upsert mark using unified helper
                save_or_update_mark(matched_student, sched, marks_val, res_status, None)

        # Production Structured Trace: [MARKS_UPLOAD_DB_PRE_FLUSH]
        logger.info(
            "[MARKS_UPLOAD_DB_PRE_FLUSH] [MARKS BATCH PRE-FLUSH] format=wide-format tenant_id=%s school_id=%s exam_id=%s class_id=%s section_id=%s "
            "current_user_id=%s schedules_count=%d students_processed=%d marks_created=%d marks_updated=%d",
            tenant_id,
            school_id,
            exam_id,
            class_id,
            section_id,
            current_user.id,
            len(sorted_schedules),
            len(students_processed_set),
            created_count,
            updated_count
        )
        # Wrap commit in try/except Exception with rollback, traceback, [MARKS_UPLOAD_DB_COMMIT_ERROR], and re-raise
        try:
            await self.marks_repo.db.flush()
            await self.marks_repo.db.commit()
            # Production Structured Trace: [MARKS_UPLOAD_DB_COMMIT_SUCCESS]
            logger.info(
                "[MARKS_UPLOAD_DB_COMMIT_SUCCESS] format=wide-format tenant_id=%s school_id=%s exam_id=%s class_id=%s section_id=%s marks_created=%d marks_updated=%d",
                tenant_id, school_id, exam_id, class_id, section_id, created_count, updated_count
            )
        except Exception as exc:
            await self.marks_repo.db.rollback()
            endpoint_path = f"/api/v1/marks/examinations/{exam_id}/upload-class-all-subjects"
            logger.error(
                "[MARKS_UPLOAD_DB_COMMIT_ERROR] [MARKS_UPLOAD_ERROR] %s: %s | path=%s exam_id=%s tenant_id=%s school_id=%s",
                type(exc).__name__,
                str(exc),
                endpoint_path,
                exam_id,
                tenant_id,
                school_id,
                exc_info=True
            )
            raise

        c_obj = schedules[0].class_obj if schedules else None
        sec_obj = schedules[0].section if schedules else None
        c_title = c_obj.name if c_obj else "Class"
        sec_title = sec_obj.name if sec_obj else "Section"

        return ClassAllSubjectsUploadSummary(
            total_students_processed=len(students_processed_set),
            total_subjects_detected=len(subject_cols),
            total_marks_created=created_count,
            total_marks_updated=updated_count,
            failed_rows=failed_rows,
            validation_errors=validation_errors,
            examination_name=examination.exam_name,
            class_name=c_title,
            section_name=sec_title
        )



