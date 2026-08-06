import uuid
import logging
from datetime import datetime, timezone
from typing import List, Optional, Dict, Any
from fastapi import HTTPException, status
from sqlalchemy import select

from app.models.marks import Marks, MarksStatus, ExamResult
from app.models.teacher_subject_assignment import TeacherSubjectAssignment
from app.models.student import Student
from app.models.examination import Examination, ExamSchedule, ExamStatus
from app.models.user import User
from app.repositories.marks import MarksRepository
from app.repositories.examination import ExamScheduleRepository, ExaminationRepository
from app.repositories.student import StudentRepository
from app.repositories.teacher_subject_assignment import TeacherSubjectAssignmentRepository
from app.repositories.school import SchoolRepository
from app.schemas.marks import (
    BulkMarksEntry, SingleMarkEntry,
    SmartMissingSummary, MarkWizardItem, StudentShortInfo,
    PublishSummaryResponse, ResultSummaryResponse, MarksResponse
)
from app.services.notification import NotificationService

logger = logging.getLogger(__name__)

class MarksService:
    def __init__(
        self,
        marks_repo: MarksRepository,
        schedule_repo: ExamScheduleRepository,
        exam_repo: ExaminationRepository,
        student_repo: StudentRepository,
        tsa_repo: TeacherSubjectAssignmentRepository,
        school_repo: SchoolRepository,
        notification_service: NotificationService
    ) -> None:
        self.marks_repo = marks_repo
        self.schedule_repo = schedule_repo
        self.exam_repo = exam_repo
        self.student_repo = student_repo
        self.tsa_repo = tsa_repo
        self.school_repo = school_repo
        self.notification_service = notification_service

    async def get_wizard_entry(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, exam_schedule_id: uuid.UUID, current_user: User
    ) -> SmartMissingSummary:
        # 1. Fetch schedule
        stmt_s = select(ExamSchedule).where(
            ExamSchedule.id == exam_schedule_id,
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

        return SmartMissingSummary(
            total_students=total,
            entered_count=entered_count,
            missing_count=missing_count,
            average_score=avg,
            highest_score=high,
            lowest_score=low,
            missing_students=missing_students,
            entries=wizard_items
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

        # 3. TSA Assignment validation
        tsa = await self.tsa_repo.get_by_id(obj_in.teacher_subject_assignment_id, school_id, tenant_id)
        if not tsa or not tsa.is_active:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Active Teacher Subject Assignment not found.")
        
        if tsa.class_id != sched.class_id or tsa.section_id != sched.section_id or tsa.subject_id != sched.subject_id:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="TSA assignment parameters do not match exam schedule details.")

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
                elif entry.result_status in [ExamResult.PRESENT, ExamResult.EXEMPTED] and not autosave:
                    # If it's a save action (not autosave), force check value
                    if marks_obtained is None:
                        raise HTTPException(
                            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                            detail=f"Present status requires a mark value for student {student.first_name}."
                        )

                if marks_obtained is not None:
                    if marks_obtained < 0 or marks_obtained > sched.max_marks:
                        raise HTTPException(
                            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                            detail=f"Marks obtained ({marks_obtained}) must be between 0 and maximum marks ({sched.max_marks}) for student {student.first_name}."
                        )

                # Check duplicate / load existing record
                db_mark = await self.marks_repo.get_by_student_and_schedule(sched.id, student.id, tenant_id)

                if db_mark:
                    if db_mark.status == MarksStatus.LOCKED:
                        raise HTTPException(
                            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                            detail=f"Marks entries are already locked for student {student.first_name}."
                        )

                    # Record corrections in Audit History JSONB array
                    if db_mark.marks_obtained != marks_obtained or db_mark.result_status != entry.result_status:
                        audit_record = {
                            "old_marks": float(db_mark.marks_obtained) if db_mark.marks_obtained is not None else None,
                            "new_marks": float(marks_obtained) if marks_obtained is not None else None,
                            "updated_by": str(current_user.id),
                            "updated_at": datetime.now(timezone.utc).isoformat()
                        }
                        db_mark.audit_history = list(db_mark.audit_history) + [audit_record]

                    db_mark.marks_obtained = marks_obtained
                    db_mark.result_status = entry.result_status
                    db_mark.remarks = entry.remarks
                    db_mark.updated_by = current_user.id
                    self.marks_repo.db.add(db_mark)
                    saved_marks.append(db_mark)
                else:
                    db_mark = Marks(
                        tenant_id=tenant_id,
                        school_id=school_id,
                        academic_year_id=sched.academic_year_id,
                        examination_id=sched.exam_id,
                        exam_schedule_id=sched.id,
                        student_id=student.id,
                        teacher_subject_assignment_id=tsa.id,
                        teacher_id=tsa.teacher_id,
                        subject_id=sched.subject_id,
                        class_id=sched.class_id,
                        section_id=sched.section_id,
                        maximum_marks=sched.max_marks,
                        marks_obtained=marks_obtained,
                        result_status=entry.result_status,
                        remarks=entry.remarks,
                        status=MarksStatus.DRAFT,
                        created_by=current_user.id,
                        updated_by=current_user.id
                    )
                    self.marks_repo.db.add(db_mark)
                    saved_marks.append(db_mark)

                last_saved_student_id = str(student.id)
                last_saved_roll_number = student.roll_number

            # 5. Save the Resume Session pointer state inside TeacherSubjectAssignment settings
            if last_saved_student_id:
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
            m.status = MarksStatus.PUBLISHED
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
