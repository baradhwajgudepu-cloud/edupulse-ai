import os
import uuid
import logging
from datetime import datetime, timezone
from typing import List, Optional, Dict, Any
from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import joinedload, selectinload

from app.models.report_card import ReportCardPublication, ReportCardStatus
from app.models.student import Student
from app.models.academic_year import AcademicYear
from app.models.school import School
from app.models.examination import ExamSchedule
from app.models.marks import Marks, ExamResult
from app.models.attendance import Attendance, AttendanceStatus, AttendanceSession
from app.models.user import User
from app.repositories.report_card import ReportCardRepository
from app.repositories.student import StudentRepository
from app.repositories.school import SchoolRepository
from app.schemas.report_card import (
    ReportCardGenerateRequest, ReportCardClassGenerateRequest,
    ReportCardPreviewResponse, ReportCardSubjectMarkRow,
    BulkClassGenerateResponse, StudentFailureDetail,
    VerificationResponse, ReportCardResponse
)
from app.services.notification import NotificationService

logger = logging.getLogger(__name__)

class ReportCardService:
    def __init__(
        self,
        report_repo: ReportCardRepository,
        student_repo: StudentRepository,
        school_repo: SchoolRepository,
        notification_service: NotificationService
    ) -> None:
        self.report_repo = report_repo
        self.student_repo = student_repo
        self.school_repo = school_repo
        self.notification_service = notification_service

    async def compile_live_data(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, student_id: uuid.UUID, teacher_remarks: Optional[str] = None
    ) -> ReportCardPreviewResponse:
        # 1. Load student with eagerly loaded relationships
        stmt_st = select(Student).where(
            Student.id == student_id,
            Student.school_id == school_id,
            Student.tenant_id == tenant_id,
            Student.deleted_at.is_(None)
        ).options(
            selectinload(Student.class_obj),
            selectinload(Student.section)
        )
        res_st = await self.report_repo.db.execute(stmt_st)
        student = res_st.scalar_one_or_none()
        if not student or not student.is_active:
            raise HTTPException(status_code=404, detail="Active student details not found.")

        # Resolve Class / Section / Academic Year
        stmt_ay = select(AcademicYear).where(
            AcademicYear.id == student.academic_year_id,
            AcademicYear.deleted_at.is_(None)
        )
        res_ay = await self.report_repo.db.execute(stmt_ay)
        ay = res_ay.scalar_one_or_none()
        if not ay:
            raise HTTPException(status_code=404, detail="Active academic year details not found.")

        warnings = []

        # 2. Fetch exam schedules and matching published marks
        stmt_sch = select(ExamSchedule).where(
            ExamSchedule.class_id == student.class_id,
            ExamSchedule.section_id == student.section_id,
            ExamSchedule.deleted_at.is_(None)
        ).options(
            joinedload(ExamSchedule.subject)
        )
        res_sch = await self.report_repo.db.execute(stmt_sch)
        schedules = list(res_sch.scalars().all())

        subject_marks_rows = []
        total_max_marks = 0
        total_obtained_marks = 0.0
        failed_subjects_count = 0

        # Load school grading policy configuration
        school = await self.school_repo.get_by_id(school_id, tenant_id)
        grade_policy = school.settings.get("grade_policy") if school else None
        if not grade_policy:
            grade_policy = [
                {"grade": "A+", "min_percentage": 90, "max_percentage": 100},
                {"grade": "A", "min_percentage": 80, "max_percentage": 89.99},
                {"grade": "B", "min_percentage": 70, "max_percentage": 79.99},
                {"grade": "C", "min_percentage": 60, "max_percentage": 69.99},
                {"grade": "D", "min_percentage": 50, "max_percentage": 59.99},
                {"grade": "E", "min_percentage": 35, "max_percentage": 49.99},
                {"grade": "F", "min_percentage": 0, "max_percentage": 34.99}
            ]

        def get_grade_for_percentage(pct: float) -> str:
            for g in grade_policy:
                if g["min_percentage"] <= pct <= g["max_percentage"]:
                    return g["grade"]
            return "F"

        for sched in schedules:
            # Query published mark
            stmt_m = select(Marks).where(
                Marks.exam_schedule_id == sched.id,
                Marks.student_id == student_id,
                Marks.deleted_at.is_(None)
            )
            res_m = await self.report_repo.db.execute(stmt_m)
            mark = res_m.scalar_one_or_none()

            subj_name = f"Subject {sched.subject_id}"
            if sched.subject:
                subj_name = sched.subject.subject_name

            if not mark:
                warnings.append(f"{subj_name} marks not entered.")
                continue
            
            if mark.status == "DRAFT":
                warnings.append(f"{subj_name} marks not published.")
                continue

            # Marks math
            obtained = float(mark.marks_obtained) if mark.marks_obtained is not None else None
            max_m = sched.max_marks
            total_max_marks += max_m

            res_status = mark.result_status.value
            grade = "F"
            if res_status in ["PRESENT", "EXEMPTED"] and obtained is not None:
                total_obtained_marks += obtained
                paper_pct = (obtained / max_m) * 100
                grade = get_grade_for_percentage(paper_pct)
                if obtained < max_m * 0.35: # Fail standard threshold
                    failed_subjects_count += 1
            else:
                failed_subjects_count += 1

            subject_marks_rows.append(ReportCardSubjectMarkRow(
                subject_name=subj_name,
                maximum_marks=max_m,
                marks_obtained=obtained,
                result_status=res_status,
                grade=grade,
                remarks=mark.remarks
            ))

        # 3. Attendance summaries
        stmt_att = select(Attendance).where(
            Attendance.student_id == student_id,
            Attendance.deleted_at.is_(None)
        )
        res_att = await self.report_repo.db.execute(stmt_att)
        att_logs = list(res_att.scalars().all())

        stmt_sess = select(AttendanceSession).where(
            AttendanceSession.class_id == student.class_id,
            AttendanceSession.section_id == student.section_id,
            AttendanceSession.deleted_at.is_(None)
        )
        res_sess = await self.report_repo.db.execute(stmt_sess)
        att_sessions = list(res_sess.scalars().all())

        total_days = len(att_sessions)
        present_days = sum(1 for a in att_logs if a.attendance_status in [AttendanceStatus.PRESENT, AttendanceStatus.LATE])
        attendance_pct = round((present_days / total_days) * 100, 2) if total_days > 0 else 0.0

        # Check if attendance taken
        if total_days == 0:
            warnings.append("Attendance records not finalized.")

        # Check remarks
        if not teacher_remarks:
            warnings.append("Teacher remark not entered.")

        # Determine promotion recommendation status
        promotion_policy = school.settings.get("promotion_policy") if school else None
        if not promotion_policy:
            promotion_policy = {
                "min_attendance_pct": 75.0,
                "min_overall_pct": 35.0,
                "max_failed_subjects": 0
            }

        overall_pct = round((total_obtained_marks / total_max_marks) * 100, 2) if total_max_marks > 0 else 0.0
        overall_grade = get_grade_for_percentage(overall_pct)

        # Promotion logic
        prom_status = "PROMOTED"
        if attendance_pct < promotion_policy.get("min_attendance_pct", 75.0):
            prom_status = "PROMOTION_UNDER_REVIEW"
        elif overall_pct < promotion_policy.get("min_overall_pct", 35.0) or failed_subjects_count > 1:
            prom_status = "DETAINED"
        elif failed_subjects_count == 1:
            prom_status = "CONDITIONALLY_PROMOTED"

        is_valid = len(warnings) == 0

        return ReportCardPreviewResponse(
            student_id=student_id,
            student_name=f"{student.first_name} {student.last_name}",
            admission_number=student.admission_number,
            roll_number=student.roll_number,
            class_name="Grade 8" if not student.class_obj else student.class_obj.name,
            section_name="A1" if not student.section else student.section.name,
            attendance_total=total_days,
            attendance_present=present_days,
            attendance_percentage=attendance_pct,
            overall_percentage=overall_pct,
            overall_grade=overall_grade,
            promotion_status=prom_status,
            subject_marks=subject_marks_rows,
            teacher_remarks=teacher_remarks,
            principal_remarks="Approved for promotion." if prom_status == "PROMOTED" else "Promotion under principal review.",
            ai_narrative="This section will be available after AI analysis.",
            is_valid=is_valid,
            missing_reasons=warnings
        )

    async def generate_report_card(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, obj_in: ReportCardGenerateRequest, current_user: User
    ) -> ReportCardPublication:
        # 1. Compile live validation check
        preview = await self.compile_live_data(tenant_id, school_id, obj_in.student_id, obj_in.teacher_remarks)
        if not preview.is_valid:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=preview.missing_reasons
            )

        student = await self.student_repo.get_by_id(obj_in.student_id, school_id, tenant_id)
        
        # 2. Check duplicate / load existing record
        db_rep = await self.report_repo.get_by_student_and_year(obj_in.student_id, student.academic_year_id, tenant_id)

        if db_rep:
            if db_rep.status in [ReportCardStatus.LOCKED, ReportCardStatus.ARCHIVED]:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="Report card is locked and cannot be regenerated."
                )

            if db_rep.status == ReportCardStatus.PUBLISHED:
                # Calculate max update timestamp of published marks
                stmt_max = select(Marks).where(
                    Marks.student_id == obj_in.student_id,
                    Marks.deleted_at.is_(None)
                )
                res_max = await self.report_repo.db.execute(stmt_max)
                marks_list = list(res_max.scalars().all())
                
                max_update = max((m.updated_at for m in marks_list), default=datetime.now(timezone.utc))
                
                # Check if publication matches (convert both to naive UTC for safe comparison across DB dialects)
                max_update_naive = max_update.astimezone(timezone.utc).replace(tzinfo=None) if max_update.tzinfo else max_update
                published_at_naive = db_rep.published_at.astimezone(timezone.utc).replace(tzinfo=None) if db_rep.published_at.tzinfo else db_rep.published_at
                
                if published_at_naive and max_update_naive <= published_at_naive:
                    raise HTTPException(
                        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                        detail="Report card is already published and no marks corrections have occurred since."
                    )

            # Move current details to history (Increment version)
            old_version = {
                "version": db_rep.version,
                "pdf_url": db_rep.pdf_url,
                "generated_at": db_rep.generated_at.isoformat() if db_rep.generated_at else None,
                "generated_by": str(db_rep.generated_by) if db_rep.generated_by else None
            }
            db_rep.pdf_history = list(db_rep.pdf_history) + [old_version]
            db_rep.version += 1
            db_rep.status = ReportCardStatus.DRAFT # Reverts to draft on regeneration
            db_rep.generated_at = datetime.now(timezone.utc)
            db_rep.generated_by = current_user.id
            db_rep.settings = obj_in.settings
        else:
            db_rep = ReportCardPublication(
                tenant_id=tenant_id,
                school_id=school_id,
                academic_year_id=student.academic_year_id,
                student_id=obj_in.student_id,
                status=ReportCardStatus.DRAFT,
                generated_at=datetime.now(timezone.utc),
                generated_by=current_user.id,
                settings=obj_in.settings,
                ai_metrics={"overall_trend": None, "risk_level": "LOW", "recommended_actions": None, "ai_narrative": "This section will be available after AI analysis."}
            )

        # 3. Generate Printable PDF Mock File
        static_dir = os.path.join("backend", "static", "report_cards", str(tenant_id), str(school_id))
        os.makedirs(static_dir, exist_ok=True)
        pdf_path = os.path.join(static_dir, f"{student.id}_report.pdf")

        # Compile PDF contents mock
        with open(pdf_path, "wb") as f:
            f.write(b"%PDF-1.4 Mock Printable Report Card PDF Content\n")
            f.write(f"Student: {preview.student_name} (Roll: {preview.roll_number})\n".encode("utf-8"))
            f.write(f"Class: {preview.class_name} Section: {preview.section_name}\n".encode("utf-8"))
            f.write(f"Attendance: {preview.attendance_present}/{preview.attendance_total}\n".encode("utf-8"))
            f.write(f"Overall Score: {preview.overall_percentage}% (Grade: {preview.overall_grade})\n".encode("utf-8"))
            f.write(f"Promotion recommendation: {preview.promotion_status}\n".encode("utf-8"))
            f.write(f"Verification UUID: {db_rep.verification_uuid}\n".encode("utf-8"))

        db_rep.pdf_url = f"/static/report_cards/{tenant_id}/{school_id}/{student.id}_report.pdf"
        self.report_repo.db.add(db_rep)
        await self.report_repo.db.commit()

        # Reload object
        return await self.report_repo.get_by_id(db_rep.id, school_id, tenant_id)

    async def bulk_generate_class(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, obj_in: ReportCardClassGenerateRequest, current_user: User
    ) -> BulkClassGenerateResponse:
        # Load students in class and section
        stmt_st = select(Student).where(
            Student.class_id == obj_in.class_id,
            Student.section_id == obj_in.section_id,
            Student.school_id == school_id,
            Student.tenant_id == tenant_id,
            Student.is_active == True,
            Student.deleted_at.is_(None)
        )
        res_st = await self.report_repo.db.execute(stmt_st)
        students = list(res_st.scalars().all())

        success_count = 0
        failed_count = 0
        failures = []

        for st in students:
            try:
                # Generate requesting one-by-one inside a sub-try block
                single_req = ReportCardGenerateRequest(
                    student_id=st.id,
                    school_id=school_id,
                    settings=obj_in.settings,
                    teacher_remarks="Dynamic Remarks"
                )
                await self.generate_report_card(tenant_id, school_id, single_req, current_user)
                success_count += 1
            except HTTPException as hex:
                # Catch dynamic missing data checks
                failed_count += 1
                failures.append(StudentFailureDetail(
                    student_id=st.id,
                    student_name=f"{st.first_name} {st.last_name}",
                    reasons=hex.detail if isinstance(hex.detail, list) else [hex.detail]
                ))
            except Exception as ex:
                failed_count += 1
                failures.append(StudentFailureDetail(
                    student_id=st.id,
                    student_name=f"{st.first_name} {st.last_name}",
                    reasons=[str(ex)]
                ))

        return BulkClassGenerateResponse(
            total_students=len(students),
            generated_count=success_count,
            failed_count=failed_count,
            failures=failures
        )

    async def submit_for_review(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, id: uuid.UUID, current_user: User
    ) -> ReportCardPublication:
        db_rep = await self.report_repo.get_by_id(id, school_id, tenant_id)
        if not db_rep:
            raise HTTPException(status_code=404, detail="Report card publication not found.")

        if db_rep.status != ReportCardStatus.DRAFT:
            raise HTTPException(status_code=422, detail="Report card must be in DRAFT status to submit for review.")

        db_rep.status = ReportCardStatus.UNDER_REVIEW
        db_rep.updated_by = current_user.id
        self.report_repo.db.add(db_rep)
        await self.report_repo.db.commit()
        return await self.report_repo.get_by_id(id, school_id, tenant_id)

    async def approve_report_card(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, id: uuid.UUID, current_user: User
    ) -> ReportCardPublication:
        db_rep = await self.report_repo.get_by_id(id, school_id, tenant_id)
        if not db_rep:
            raise HTTPException(status_code=404, detail="Report card publication not found.")

        if db_rep.status != ReportCardStatus.UNDER_REVIEW:
            raise HTTPException(status_code=422, detail="Report card must be in UNDER_REVIEW status to approve.")

        db_rep.status = ReportCardStatus.APPROVED
        db_rep.approved_by = current_user.id
        db_rep.approved_at = datetime.now(timezone.utc)
        db_rep.updated_by = current_user.id
        self.report_repo.db.add(db_rep)
        await self.report_repo.db.commit()
        return await self.report_repo.get_by_id(id, school_id, tenant_id)

    async def publish_report_cards(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, class_id: uuid.UUID, section_id: uuid.UUID, current_user: User
    ) -> List[ReportCardPublication]:
        # Fetch approved report cards for class
        stmt = select(ReportCardPublication).join(ReportCardPublication.student).where(
            Student.class_id == class_id,
            Student.section_id == section_id,
            ReportCardPublication.status == ReportCardStatus.APPROVED,
            ReportCardPublication.school_id == school_id,
            ReportCardPublication.tenant_id == tenant_id,
            ReportCardPublication.deleted_at.is_(None)
        )
        res = await self.report_repo.db.execute(stmt)
        pubs = list(res.scalars().all())

        if not pubs:
            raise HTTPException(status_code=422, detail="No approved report cards found to publish.")

        for p in pubs:
            p.status = ReportCardStatus.PUBLISHED
            p.published_by = current_user.id
            p.published_at = datetime.now(timezone.utc)
            p.updated_by = current_user.id
            self.report_repo.db.add(p)

        await self.report_repo.db.commit()

        # Trigger notifications for each published report card
        for p in pubs:
            try:
                await self.notification_service.notify_report_card(tenant_id, school_id, p.id)
            except Exception as ne:
                logger.error(f"Failed to send report card notification: {str(ne)}", exc_info=True)
        
        # Re-query
        res_reload = await self.report_repo.db.execute(
            select(ReportCardPublication).where(
                ReportCardPublication.student_id.in_([p.student_id for p in pubs]),
                ReportCardPublication.status == ReportCardStatus.PUBLISHED,
                ReportCardPublication.deleted_at.is_(None)
            )
        )
        return list(res_reload.scalars().all())

    async def lock_report_card(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, id: uuid.UUID, current_user: User
    ) -> ReportCardPublication:
        db_rep = await self.report_repo.get_by_id(id, school_id, tenant_id)
        if not db_rep:
            raise HTTPException(status_code=404, detail="Report card publication not found.")

        if db_rep.status != ReportCardStatus.PUBLISHED:
            raise HTTPException(status_code=422, detail="Report card must be in PUBLISHED status to lock.")

        db_rep.status = ReportCardStatus.LOCKED
        db_rep.updated_by = current_user.id
        self.report_repo.db.add(db_rep)
        await self.report_repo.db.commit()
        return await self.report_repo.get_by_id(id, school_id, tenant_id)

    async def unlock_report_card(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, id: uuid.UUID, current_user: User
    ) -> ReportCardPublication:
        db_rep = await self.report_repo.get_by_id(id, school_id, tenant_id)
        if not db_rep:
            raise HTTPException(status_code=404, detail="Report card publication not found.")

        if db_rep.status != ReportCardStatus.LOCKED:
            raise HTTPException(status_code=422, detail="Report card must be in LOCKED status to unlock.")

        db_rep.status = ReportCardStatus.PUBLISHED
        db_rep.updated_by = current_user.id
        self.report_repo.db.add(db_rep)
        await self.report_repo.db.commit()
        return await self.report_repo.get_by_id(id, school_id, tenant_id)

    async def get_verification_details(self, verification_uuid: uuid.UUID) -> VerificationResponse:
        db_rep = await self.report_repo.get_by_verification_uuid(verification_uuid)
        if not db_rep:
            raise HTTPException(status_code=404, detail="Verification link is invalid or expired.")

        student = db_rep.student
        ay = db_rep.academic_year

        return VerificationResponse(
            student_name=f"{student.first_name} {student.last_name}",
            roll_number=student.roll_number,
            class_name="Grade 8" if not student.class_obj else student.class_obj.name,
            section_name="A1" if not student.section else student.section.name,
            academic_year=ay.name if ay else "AY",
            status=db_rep.status,
            verification_date=datetime.now(timezone.utc),
            generated_at=db_rep.generated_at,
            published_at=db_rep.published_at,
            pdf_url=db_rep.pdf_url
        )
