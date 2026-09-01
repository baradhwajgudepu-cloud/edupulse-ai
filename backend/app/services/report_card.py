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
from app.models.marks import Marks, MarksStatus, ExamResult
from app.models.attendance import Attendance, AttendanceStatus, AttendanceSession
from app.models.user import User
from app.repositories.report_card import ReportCardRepository
from app.repositories.student import StudentRepository
from app.repositories.school import SchoolRepository
from app.schemas.report_card import (
    ReportCardGenerateRequest, ReportCardClassGenerateRequest,
    ReportCardPreviewResponse, ReportCardSubjectMarkRow,
    BulkClassGenerateResponse, StudentFailureDetail,
    VerificationResponse, ReportCardResponse,
    StudentAcademicHistoryResponse, ExamHistorySummary, ExamSubjectMark
)
from app.services.notification import NotificationService

import io
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether, Image
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT, TA_JUSTIFY
from reportlab.pdfgen import canvas

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            super().showPage()
        super().save()

    def draw_page_decorations(self, page_count):
        self.saveState()
        
        primary_color = colors.HexColor("#1A365D")
        gold_color = colors.HexColor("#D4AF37")
        text_color = colors.HexColor("#4A5568")
        line_color = colors.HexColor("#E2E8F0")
        
        # Draw header on pages > 1
        if self._pageNumber > 1:
            self.setFont("Helvetica-Bold", 8)
            self.setFillColor(primary_color)
            self.drawString(40, 800, getattr(self, "school_name", "EduPulse School").upper())
            
            self.setFont("Helvetica", 8)
            self.setFillColor(text_color)
            self.drawRightString(555, 800, f"Academic Year: {getattr(self, 'academic_year', '2025-26')}")
            
            # Header double accent lines
            self.setStrokeColor(primary_color)
            self.setLineWidth(1)
            self.line(40, 792, 555, 792)
            self.setStrokeColor(gold_color)
            self.setLineWidth(0.5)
            self.line(40, 790, 555, 790)
            
        # Draw footer on ALL pages
        self.setStrokeColor(line_color)
        self.setLineWidth(0.5)
        self.line(40, 48, 555, 48)
        
        self.setFont("Helvetica-Bold", 8)
        self.setFillColor(primary_color)
        self.drawString(40, 36, "EduPulse AI")
        
        self.setFont("Helvetica-Oblique", 7)
        self.setFillColor(text_color)
        self.drawString(100, 36, '"Educating Minds. Inspiring Hearts. Shaping Futures."')
        
        self.setFont("Helvetica", 8)
        self.drawRightString(555, 36, f"Page {self._pageNumber} of {page_count}")
        
        self.restoreState()

def make_numbered_canvas_class(school_name: str, academic_year: str, report_card_title: str):
    class DynamicNumberedCanvas(NumberedCanvas):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, **kwargs)
            self.school_name = school_name
            self.academic_year = academic_year
            self.report_card_title = report_card_title
    return DynamicNumberedCanvas

logger = logging.getLogger(__name__)

def _generate_valid_pdf(title: str, lines: list[str]) -> bytes:
    obj1 = b"<< /Type /Catalog /Pages 2 0 R >>"
    obj2 = b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>"
    obj4 = b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
    
    stream_content = b"BT\n/F1 18 Tf\n50 750 Td\n(" + title.encode('utf-8') + b") Tj\n/F1 12 Tf\n0 -30 Td\n"
    for line in lines:
        safe_line = line.replace('\\', '\\\\').replace('(', '\\(').replace(')', '\\)')
        stream_content += b"0 -20 Td\n(" + safe_line.encode('utf-8') + b") Tj\n"
    stream_content += b"ET"
    
    obj5 = f"<< /Length {len(stream_content)} >>\nstream\n".encode('utf-8') + stream_content + b"\nendstream"
    obj3 = b"<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 4 0 R >> >> /MediaBox [0 0 612 792] /Contents 5 0 R >>"
    
    objects = [obj1, obj2, obj3, obj4, obj5]
    pdf_bytes = b"%PDF-1.4\n"
    offsets = []
    
    for i, obj in enumerate(objects):
        obj_num = i + 1
        offsets.append(len(pdf_bytes))
        pdf_bytes += f"{obj_num} 0 obj\n".encode('utf-8') + obj + b"\nendobj\n"
        
    xref_offset = len(pdf_bytes)
    xref_lines = [f"0 {len(objects) + 1}\n", "0000000000 65535 f \n"]
    for offset in offsets:
        xref_lines.append(f"{offset:010d} 00000 n \n")
        
    xref_str = "xref\n" + "".join(xref_lines)
    trailer_str = f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\nstartxref\n{xref_offset}\n%%EOF\n"
    
    pdf_bytes += xref_str.encode('utf-8') + trailer_str.encode('utf-8')
    return pdf_bytes

class ReportCardService:
    def __init__(
        self,
        report_repo: ReportCardRepository,
        student_repo: StudentRepository,
        school_repo: SchoolRepository,
        notification_service: NotificationService,
        storage_service = None
    ) -> None:
        self.report_repo = report_repo
        self.student_repo = student_repo
        self.school_repo = school_repo
        self.notification_service = notification_service
        from app.services.storage import get_storage_service
        self.storage_service = storage_service or get_storage_service()

    async def validate_report_card_data(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        student_id: uuid.UUID,
        academic_year_id: Optional[uuid.UUID] = None,
        examination_id: Optional[uuid.UUID] = None,
        teacher_remarks: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Authoritative single validation method for determining report card completeness.
        Used consistently by generation, preview, approval, and publication workflows.
        """
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

        effective_ay_id = academic_year_id or student.academic_year_id
        if not effective_ay_id:
            raise HTTPException(status_code=404, detail="Active academic year details not found.")

        # Check if we have an existing publication to load remarks/metadata from
        stmt_pub = select(ReportCardPublication).where(
            ReportCardPublication.student_id == student_id,
            ReportCardPublication.academic_year_id == effective_ay_id,
            ReportCardPublication.school_id == school_id,
            ReportCardPublication.tenant_id == tenant_id,
            ReportCardPublication.deleted_at.is_(None)
        )
        res_pub = await self.report_repo.db.execute(stmt_pub)
        db_rep = res_pub.scalar_one_or_none()

        warnings = []

        if not teacher_remarks and db_rep and db_rep.settings:
            teacher_remarks = db_rep.settings.get("teacher_remarks")

        if not teacher_remarks:
            warnings.append("Teacher remark not entered.")

        # Resolve target examination context
        target_exam_id = examination_id
        if not target_exam_id and db_rep and db_rep.settings and db_rep.settings.get("examination_id"):
            try:
                target_exam_id = uuid.UUID(str(db_rep.settings["examination_id"]))
            except Exception:
                target_exam_id = None

        # 2. Fetch exam schedules
        stmt_sch = select(ExamSchedule).where(
            ExamSchedule.class_id == student.class_id,
            ExamSchedule.section_id == student.section_id,
            ExamSchedule.school_id == school_id,
            ExamSchedule.tenant_id == tenant_id,
            ExamSchedule.deleted_at.is_(None)
        )
        if target_exam_id:
            stmt_sch = stmt_sch.where(ExamSchedule.exam_id == target_exam_id)
        elif effective_ay_id:
            # Query examinations in this AY that are completed/published/approved
            from app.models.examination import Examination, ExamStatus
            stmt_sch = stmt_sch.join(Examination, ExamSchedule.exam_id == Examination.id).where(
                ExamSchedule.academic_year_id == effective_ay_id,
                Examination.status.in_([
                    ExamStatus.PUBLISHED, ExamStatus.APPROVED, ExamStatus.COMPLETED,
                    "PUBLISHED", "APPROVED", "COMPLETED"
                ])
            )

        stmt_sch = stmt_sch.options(joinedload(ExamSchedule.subject))
        res_sch = await self.report_repo.db.execute(stmt_sch)
        schedules = list(res_sch.scalars().all())

        # If no published/completed exams exist in the AY yet, fall back to checking all configured schedules for the AY
        if not schedules and not target_exam_id:
            stmt_sch_fallback = select(ExamSchedule).where(
                ExamSchedule.class_id == student.class_id,
                ExamSchedule.section_id == student.section_id,
                ExamSchedule.school_id == school_id,
                ExamSchedule.tenant_id == tenant_id,
                ExamSchedule.academic_year_id == effective_ay_id,
                ExamSchedule.deleted_at.is_(None)
            ).options(joinedload(ExamSchedule.subject))
            res_sch_fallback = await self.report_repo.db.execute(stmt_sch_fallback)
            schedules = list(res_sch_fallback.scalars().all())

        if not schedules:
            warnings.append("No examination schedules configured for class and section.")

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
            
            if mark.status not in [MarksStatus.PUBLISHED, MarksStatus.APPROVED, MarksStatus.LOCKED, "PUBLISHED", "APPROVED", "LOCKED"]:
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
                if obtained < max_m * 0.35:
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
        attendance_pct = round((present_days / total_days) * 100, 2) if total_days > 0 else 100.0

        promotion_policy = school.settings.get("promotion_policy") if school else None
        if not promotion_policy:
            promotion_policy = {
                "min_attendance_pct": 75.0,
                "min_overall_pct": 35.0,
                "max_failed_subjects": 0
            }

        overall_pct = round((total_obtained_marks / total_max_marks) * 100, 2) if total_max_marks > 0 else 0.0
        overall_grade = get_grade_for_percentage(overall_pct)

        prom_status = "PROMOTED"
        if attendance_pct < promotion_policy.get("min_attendance_pct", 75.0):
            prom_status = "PROMOTION_UNDER_REVIEW"
        elif overall_pct < promotion_policy.get("min_overall_pct", 35.0) or failed_subjects_count > 1:
            prom_status = "DETAINED"
        elif failed_subjects_count == 1:
            prom_status = "CONDITIONALLY_PROMOTED"

        is_valid = len(warnings) == 0

        return {
            "student": student,
            "db_rep": db_rep,
            "is_valid": is_valid,
            "missing_reasons": warnings,
            "subject_marks_rows": subject_marks_rows,
            "total_days": total_days,
            "present_days": present_days,
            "attendance_pct": attendance_pct,
            "overall_pct": overall_pct,
            "overall_grade": overall_grade,
            "prom_status": prom_status,
            "teacher_remarks": teacher_remarks
        }

    async def compile_live_data(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, student_id: uuid.UUID, teacher_remarks: Optional[str] = None, examination_id: Optional[uuid.UUID] = None
    ) -> ReportCardPreviewResponse:
        val = await self.validate_report_card_data(
            tenant_id=tenant_id,
            school_id=school_id,
            student_id=student_id,
            examination_id=examination_id,
            teacher_remarks=teacher_remarks
        )
        student = val["student"]
        prom_status = val["prom_status"]

        return ReportCardPreviewResponse(
            student_id=student_id,
            student_name=f"{student.first_name} {student.last_name}",
            admission_number=student.admission_number,
            roll_number=student.roll_number,
            class_name="Grade 8" if not student.class_obj else student.class_obj.name,
            section_name="A1" if not student.section else student.section.name,
            attendance_total=val["total_days"],
            attendance_present=val["present_days"],
            attendance_percentage=val["attendance_pct"],
            overall_percentage=val["overall_pct"],
            overall_grade=val["overall_grade"],
            promotion_status=prom_status,
            subject_marks=val["subject_marks_rows"],
            teacher_remarks=val["teacher_remarks"],
            principal_remarks="Approved for promotion." if prom_status == "PROMOTED" else "Promotion under principal review.",
            ai_narrative="This section will be available after AI analysis.",
            is_valid=val["is_valid"],
            missing_reasons=val["missing_reasons"]
        )

    async def generate_report_card(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, obj_in: ReportCardGenerateRequest, current_user: User
    ) -> ReportCardPublication:
        # 1. Compile live validation check
        effective_remarks = obj_in.teacher_remarks or "Good academic progress and conduct."
        preview = await self.compile_live_data(
            tenant_id, school_id, obj_in.student_id, effective_remarks, obj_in.examination_id
        )
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
            db_rep.settings = dict(obj_in.settings or {})
            if obj_in.examination_id:
                db_rep.settings["examination_id"] = str(obj_in.examination_id)
            if obj_in.teacher_remarks:
                db_rep.settings["teacher_remarks"] = obj_in.teacher_remarks
        else:
            db_rep = ReportCardPublication(
                tenant_id=tenant_id,
                school_id=school_id,
                academic_year_id=student.academic_year_id,
                student_id=obj_in.student_id,
                status=ReportCardStatus.DRAFT,
                generated_at=datetime.now(timezone.utc),
                generated_by=current_user.id,
                settings=dict(obj_in.settings or {}),
                ai_metrics={"overall_trend": None, "risk_level": "LOW", "recommended_actions": None, "ai_narrative": "This section will be available after AI analysis."}
            )
            if obj_in.examination_id:
                db_rep.settings["examination_id"] = str(obj_in.examination_id)
            if obj_in.teacher_remarks:
                db_rep.settings["teacher_remarks"] = obj_in.teacher_remarks

        # 3. Generate Printable PDF Report File
        # Compile PDF contents using ReportLab
        history = await self.get_student_academic_history(tenant_id, school_id, student.id)
        pdf_data = await self.generate_professional_report_card_pdf(
            tenant_id, school_id, student.id, preview, history, db_rep
        )
        
        gcs_path = f"report_cards/{tenant_id}/{school_id}/{student.id}_report.pdf"
        await self.storage_service.upload(pdf_data, gcs_path, "application/pdf")

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
        if obj_in.academic_year_id:
            stmt_st = stmt_st.where(Student.academic_year_id == obj_in.academic_year_id)

        res_st = await self.report_repo.db.execute(stmt_st)
        students = list(res_st.scalars().all())

        success_count = 0
        failed_count = 0
        failures = []

        for st in students:
            try:
                single_req = ReportCardGenerateRequest(
                    student_id=st.id,
                    school_id=school_id,
                    examination_id=obj_in.examination_id,
                    academic_year_id=obj_in.academic_year_id or st.academic_year_id,
                    settings=obj_in.settings,
                    teacher_remarks="Good academic progress and conduct."
                )
                await self.generate_report_card(tenant_id, school_id, single_req, current_user)
                success_count += 1
            except HTTPException as hex:
                if isinstance(hex.detail, str) and "already published and no marks corrections" in hex.detail:
                    # Idempotent re-run on unchanged published cards
                    success_count += 1
                else:
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

    async def bulk_approve_report_cards(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, report_card_ids: List[uuid.UUID], current_user: User
    ) -> BulkReportCardActionResponse:
        from app.schemas.report_card import BulkReportCardActionResponse
        success_count = 0
        failed_count = 0
        failures = []
        now = datetime.now(timezone.utc)

        for rep_id in report_card_ids:
            db_rep = await self.report_repo.get_by_id(rep_id, school_id, tenant_id)
            if not db_rep:
                failed_count += 1
                failures.append(StudentFailureDetail(
                    student_id=rep_id,
                    student_name="Unknown Student",
                    reasons=["Report card record not found."]
                ))
                continue

            student_name = f"{db_rep.student.first_name} {db_rep.student.last_name}" if db_rep.student else f"Student ({rep_id})"

            if db_rep.status in [ReportCardStatus.APPROVED, ReportCardStatus.PUBLISHED]:
                # Already approved or published - idempotent
                success_count += 1
                continue

            if db_rep.status not in [ReportCardStatus.UNDER_REVIEW, ReportCardStatus.DRAFT]:
                failed_count += 1
                failures.append(StudentFailureDetail(
                    student_id=db_rep.student_id,
                    student_name=student_name,
                    reasons=[f"Report card is in {db_rep.status.value} status and cannot be approved."]
                ))
                continue

            # Authoritative completeness validation
            exam_id_ctx = None
            if db_rep.settings and db_rep.settings.get("examination_id"):
                try:
                    exam_id_ctx = uuid.UUID(str(db_rep.settings["examination_id"]))
                except Exception:
                    exam_id_ctx = None

            val = await self.validate_report_card_data(
                tenant_id=tenant_id,
                school_id=school_id,
                student_id=db_rep.student_id,
                academic_year_id=db_rep.academic_year_id,
                examination_id=exam_id_ctx,
                teacher_remarks=db_rep.settings.get("teacher_remarks")
            )
            if not val["is_valid"]:
                failed_count += 1
                failures.append(StudentFailureDetail(
                    student_id=db_rep.student_id,
                    student_name=student_name,
                    reasons=val["missing_reasons"]
                ))
                continue

            db_rep.status = ReportCardStatus.APPROVED
            db_rep.approved_by = current_user.id
            db_rep.approved_at = now
            db_rep.updated_by = current_user.id
            self.report_repo.db.add(db_rep)
            success_count += 1

        await self.report_repo.db.commit()

        return BulkReportCardActionResponse(
            total_requested=len(report_card_ids),
            success_count=success_count,
            failed_count=failed_count,
            failures=failures
        )

    async def bulk_publish_selected_cards(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, report_card_ids: List[uuid.UUID], current_user: User
    ) -> BulkReportCardActionResponse:
        from app.schemas.report_card import BulkReportCardActionResponse
        success_count = 0
        failed_count = 0
        failures = []
        now = datetime.now(timezone.utc)
        published_cards = []

        for rep_id in report_card_ids:
            db_rep = await self.report_repo.get_by_id(rep_id, school_id, tenant_id)
            if not db_rep:
                failed_count += 1
                failures.append(StudentFailureDetail(
                    student_id=rep_id,
                    student_name="Unknown Student",
                    reasons=["Report card record not found."]
                ))
                continue

            student_name = f"{db_rep.student.first_name} {db_rep.student.last_name}" if db_rep.student else f"Student ({rep_id})"

            if db_rep.status == ReportCardStatus.PUBLISHED:
                # Already published - idempotent
                success_count += 1
                continue

            if db_rep.status != ReportCardStatus.APPROVED:
                failed_count += 1
                failures.append(StudentFailureDetail(
                    student_id=db_rep.student_id,
                    student_name=student_name,
                    reasons=[f"Report card must be in APPROVED status to publish (currently {db_rep.status.value})."]
                ))
                continue

            # Authoritative completeness validation
            exam_id_ctx = None
            if db_rep.settings and db_rep.settings.get("examination_id"):
                try:
                    exam_id_ctx = uuid.UUID(str(db_rep.settings["examination_id"]))
                except Exception:
                    exam_id_ctx = None

            val = await self.validate_report_card_data(
                tenant_id=tenant_id,
                school_id=school_id,
                student_id=db_rep.student_id,
                academic_year_id=db_rep.academic_year_id,
                examination_id=exam_id_ctx,
                teacher_remarks=db_rep.settings.get("teacher_remarks")
            )
            if not val["is_valid"]:
                failed_count += 1
                failures.append(StudentFailureDetail(
                    student_id=db_rep.student_id,
                    student_name=student_name,
                    reasons=val["missing_reasons"]
                ))
                continue

            db_rep.status = ReportCardStatus.PUBLISHED
            db_rep.published_by = current_user.id
            db_rep.published_at = now
            db_rep.updated_by = current_user.id
            self.report_repo.db.add(db_rep)
            published_cards.append(db_rep)
            success_count += 1

        await self.report_repo.db.commit()

        # Notify parents for published report cards
        for p in published_cards:
            try:
                await self.notification_service.notify_report_card(tenant_id, school_id, p.id)
            except Exception as ne:
                logger.error(f"Failed to send report card notification: {str(ne)}", exc_info=True)

        return BulkReportCardActionResponse(
            total_requested=len(report_card_ids),
            success_count=success_count,
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

        # Completeness check
        exam_id_ctx = None
        if db_rep.settings and db_rep.settings.get("examination_id"):
            try:
                exam_id_ctx = uuid.UUID(str(db_rep.settings["examination_id"]))
            except Exception:
                exam_id_ctx = None

        val = await self.validate_report_card_data(
            tenant_id=tenant_id,
            school_id=school_id,
            student_id=db_rep.student_id,
            academic_year_id=db_rep.academic_year_id,
            examination_id=exam_id_ctx,
            teacher_remarks=db_rep.settings.get("teacher_remarks")
        )
        if not val["is_valid"]:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=val["missing_reasons"]
            )

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

    async def get_student_academic_history(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, student_id: uuid.UUID
    ) -> StudentAcademicHistoryResponse:
        # 1. Fetch student
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

        # 2. Fetch all examinations for this academic year
        from app.models.examination import Examination
        stmt_exams = select(Examination).where(
            Examination.academic_year_id == student.academic_year_id,
            Examination.school_id == school_id,
            Examination.tenant_id == tenant_id,
            Examination.deleted_at.is_(None)
        )
        res_exams = await self.report_repo.db.execute(stmt_exams)
        examinations = list(res_exams.scalars().all())

        # Sort examinations chronologically by their start date
        examinations.sort(key=lambda x: x.start_date)

        # 3. For each examination, fetch the exam schedules and corresponding student marks
        exam_summaries = []
        
        # Load school grading policy
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

        for exam in examinations:
            # Fetch exam schedules for this exam and class/section
            stmt_sch = select(ExamSchedule).where(
                ExamSchedule.exam_id == exam.id,
                ExamSchedule.class_id == student.class_id,
                ExamSchedule.section_id == student.section_id,
                ExamSchedule.deleted_at.is_(None)
            ).options(
                joinedload(ExamSchedule.subject)
            )
            res_sch = await self.report_repo.db.execute(stmt_sch)
            schedules = list(res_sch.scalars().all())
            
            if not schedules:
                continue

            subject_marks = []
            total_max_marks = 0
            total_obtained_marks = 0.0
            
            for sched in schedules:
                # Query published mark
                stmt_m = select(Marks).where(
                    Marks.exam_schedule_id == sched.id,
                    Marks.student_id == student_id,
                    Marks.status == "PUBLISHED",
                    Marks.deleted_at.is_(None)
                )
                res_m = await self.report_repo.db.execute(stmt_m)
                mark = res_m.scalar_one_or_none()
                
                subj_name = f"Subject {sched.subject_id}"
                if sched.subject:
                    subj_name = sched.subject.subject_name

                obtained = float(mark.marks_obtained) if (mark and mark.marks_obtained is not None) else None
                max_m = sched.max_marks
                total_max_marks += max_m

                status = mark.result_status.value if mark else "ABSENT"
                grade = "F"
                if status in ["PRESENT", "EXEMPTED"] and obtained is not None:
                    total_obtained_marks += obtained
                    paper_pct = (obtained / max_m) * 100
                    grade = get_grade_for_percentage(paper_pct)

                subject_marks.append(ExamSubjectMark(
                    subject_name=subj_name,
                    max_marks=max_m,
                    marks_obtained=obtained,
                    grade=grade,
                    status=status,
                    remarks=mark.remarks if mark else None
                ))

            # Compute exam total metrics
            percentage = round((total_obtained_marks / total_max_marks) * 100, 2) if total_max_marks > 0 else 0.0
            grade = get_grade_for_percentage(percentage)

            exam_summaries.append(ExamHistorySummary(
                examination_id=exam.id,
                examination_name=exam.exam_name,
                subject_marks=subject_marks,
                total_max_marks=total_max_marks,
                total_obtained_marks=total_obtained_marks,
                percentage=percentage,
                grade=grade
            ))

        return StudentAcademicHistoryResponse(
            student_id=student.id,
            student_name=f"{student.first_name} {student.last_name}",
            class_name="" if not student.class_obj else student.class_obj.name,
            section_name="" if not student.section else student.section.name,
            examinations=exam_summaries
        )

    async def generate_professional_report_card_pdf(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, student_id: uuid.UUID, preview: ReportCardPreviewResponse, history: StudentAcademicHistoryResponse, db_rep: ReportCardPublication
    ) -> bytes:
        # Load student & school
        student = await self.student_repo.get_by_id(student_id, school_id, tenant_id)
        school = await self.school_repo.get_by_id(school_id, tenant_id)
        
        report_card_settings = school.settings.get("report_card_settings", {}) if school and school.settings else {}
        report_card_title = report_card_settings.get("title", "EduPulse Report Card")
        show_grades = report_card_settings.get("show_grades", True)
        show_attendance = report_card_settings.get("show_attendance", True)
        show_remarks = report_card_settings.get("show_remarks", True)
        show_promotion = report_card_settings.get("show_promotion", True)
        show_ai_insights = report_card_settings.get("show_ai_insights", True)
        teacher_sig_label = report_card_settings.get("teacher_signature_label", "Class Teacher")
        principal_sig_label = report_card_settings.get("principal_signature_label", "Principal")
        
        # Load academic year
        stmt_ay = select(AcademicYear).where(AcademicYear.id == student.academic_year_id)
        res_ay = await self.report_repo.db.execute(stmt_ay)
        academic_year = res_ay.scalar_one_or_none()
        ay_name = academic_year.name if academic_year else "2025-26"
        
        # Required reportlab components
        from reportlab.lib.pagesizes import A4
        from reportlab.graphics.shapes import Drawing
        from reportlab.graphics.barcode.qr import QrCodeWidget

        buffer = io.BytesIO()
        doc = SimpleDocTemplate(
            buffer,
            pagesize=A4,
            leftMargin=40,
            rightMargin=40,
            topMargin=50,
            bottomMargin=60
        )
        
        styles = getSampleStyleSheet()
        
        # Colors
        navy_primary = colors.HexColor("#1A365D")
        gold_accent = colors.HexColor("#D4AF37")
        dark_grey = colors.HexColor("#2D3748")
        light_grey = colors.HexColor("#F8FAFC")
        border_grey = colors.HexColor("#CBD5E0")
        
        # Custom styles
        title_style = ParagraphStyle(
            'SchoolTitle',
            parent=styles['Normal'],
            fontName='Helvetica-Bold',
            fontSize=16,
            leading=20,
            textColor=navy_primary,
            alignment=TA_LEFT
        )
        
        subtitle_style = ParagraphStyle(
            'SchoolSubtitle',
            parent=styles['Normal'],
            fontName='Helvetica',
            fontSize=9,
            leading=13,
            textColor=colors.HexColor("#4A5568"),
            alignment=TA_LEFT
        )
        
        section_title_style = ParagraphStyle(
            'SectionTitle',
            parent=styles['Normal'],
            fontName='Helvetica-Bold',
            fontSize=10,
            leading=14,
            textColor=navy_primary,
            spaceBefore=14,
            spaceAfter=6,
            keepWithNext=True
        )
        
        body_style = ParagraphStyle(
            'ReportBody',
            parent=styles['Normal'],
            fontName='Helvetica',
            fontSize=9,
            leading=13,
            textColor=dark_grey
        )
        
        body_bold = ParagraphStyle(
            'ReportBodyBold',
            parent=body_style,
            fontName='Helvetica-Bold'
        )

        body_bold_center = ParagraphStyle(
            'ReportBodyBoldCenter',
            parent=body_style,
            fontName='Helvetica-Bold',
            alignment=TA_CENTER
        )
        
        table_header_style = ParagraphStyle(
            'TableHeader',
            parent=styles['Normal'],
            fontName='Helvetica-Bold',
            fontSize=8,
            leading=11,
            textColor=colors.white,
            alignment=TA_CENTER
        )
        
        table_cell_style = ParagraphStyle(
            'TableCell',
            parent=styles['Normal'],
            fontName='Helvetica',
            fontSize=8,
            leading=11,
            alignment=TA_CENTER
        )

        table_cell_bold = ParagraphStyle(
            'TableCellBold',
            parent=styles['Normal'],
            fontName='Helvetica-Bold',
            fontSize=8,
            leading=11,
            alignment=TA_CENTER
        )
        
        table_cell_left = ParagraphStyle(
            'TableCellLeft',
            parent=styles['Normal'],
            fontName='Helvetica',
            fontSize=8,
            leading=11,
            alignment=TA_LEFT
        )
        
        story = []
        
        # 1. School Branding Header
        logo_flowable = None
        if school and school.logo_url:
            if school.logo_url.startswith("http"):
                try:
                    import httpx
                    resp = httpx.get(school.logo_url, timeout=1.0)
                    if resp.status_code == 200:
                        logo_flowable = Image(io.BytesIO(resp.content), width=50, height=50)
                except Exception as e:
                    logger.warning(f"Could not load school logo from URL {school.logo_url}: {e}")
            elif os.path.exists(school.logo_url):
                try:
                    logo_flowable = Image(school.logo_url, width=50, height=50)
                except Exception as e:
                    logger.warning(f"Could not load school logo from path {school.logo_url}: {e}")
            else:
                try:
                    import asyncio
                    # Try downloading from storage_service
                    logo_bytes = asyncio.run(self.storage_service.download(school.logo_url)) if asyncio.get_event_loop().is_running() is False else None
                    if not logo_bytes:
                        # If inside running loop
                        logo_bytes = self.storage_service.download_sync(school.logo_url) if hasattr(self.storage_service, 'download_sync') else None
                    if logo_bytes:
                        logo_flowable = Image(io.BytesIO(logo_bytes), width=50, height=50)
                except Exception as e:
                    logger.debug(f"Could not load school logo from storage {school.logo_url}: {e}")
                    
        if not logo_flowable:
            initials = "".join([w[0] for w in school.name.split() if w])[:3].upper() if school and school.name else "EP"
            emblem_style = ParagraphStyle('Emblem', parent=styles['Normal'], fontName='Helvetica-Bold', fontSize=14, leading=18, textColor=colors.white, alignment=TA_CENTER)
            logo_flowable = Table([[Paragraph(initials, emblem_style)]], colWidths=[50], rowHeights=[50])
            logo_flowable.setStyle(TableStyle([
                ('BACKGROUND', (0,0), (-1,-1), navy_primary),
                ('ALIGN', (0,0), (-1,-1), 'CENTER'),
                ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
                ('BOTTOMPADDING', (0,0), (-1,-1), 16),
            ]))

        school_info_lines = [
            f"<font size=14 color='{navy_primary.hexval()}'><b>{school.name.upper() if school else 'EDUPULSE HIGH SCHOOL'}</b></font>",
        ]
        sub_text = []
        if school and school.address:
            sub_text.append(school.address)
        if school and school.phone:
            sub_text.append(f"Phone: {school.phone}")
        if school and school.email:
            sub_text.append(f"Email: {school.email}")
        if sub_text:
            school_info_lines.append(f"<font size=8 color='#4A5568'>{'  |  '.join(sub_text)}</font>")
        
        board_board = school.board.value if school and hasattr(school, 'board') and hasattr(school.board, 'value') else "CBSE"
        school_code = school.code if school and hasattr(school, 'code') else "N/A"
        school_info_lines.append(f"<font size=8 color='#718096'>Affiliated to {board_board}  |  School Code: {school_code}</font>")
        
        school_info_p = Paragraph("<br/>".join(school_info_lines), ParagraphStyle('SchoolInfo', parent=styles['Normal'], leading=13))
        
        title_lines = [
            f"<font size=10 color='{gold_accent.hexval()}'><b>{report_card_title.upper()}</b></font>",
            f"<font size=8 color='#4A5568'><b>ACADEMIC YEAR: {ay_name}</b></font>",
            f"<font size=7 color='#A0AEC0'>Powered by EduPulse AI</font>"
        ]
        title_p = Paragraph("<br/>".join(title_lines), ParagraphStyle('RightTitle', parent=styles['Normal'], leading=11, alignment=TA_RIGHT))

        header_table = Table([[logo_flowable, school_info_p, title_p]], colWidths=[60, 315, 140])
        header_table.setStyle(TableStyle([
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ('ALIGN', (0,0), (-1,-1), 'LEFT'),
            ('BOTTOMPADDING', (0,0), (-1,-1), 8),
        ]))
        story.append(header_table)
        
        # Header accent gold line
        accent_bar = Table([[""]], colWidths=[515], rowHeights=[2])
        accent_bar.setStyle(TableStyle([
            ('BACKGROUND', (0,0), (-1,-1), gold_accent),
            ('BOTTOMPADDING', (0,0), (-1,-1), 0),
            ('TOPPADDING', (0,0), (-1,-1), 0),
        ]))
        story.append(accent_bar)
        story.append(Spacer(1, 10))
        
        # 2. Student Information Table & Optional Photo
        photo_flowable = None
        if student.photo_url:
            if student.photo_url.startswith("http"):
                try:
                    import httpx
                    resp = httpx.get(student.photo_url, timeout=1.0)
                    if resp.status_code == 200:
                        photo_flowable = Image(io.BytesIO(resp.content), width=65, height=75)
                except Exception as e:
                    logger.warning(f"Could not load student photo from URL {student.photo_url}: {e}")
            elif os.path.exists(student.photo_url):
                try:
                    photo_flowable = Image(student.photo_url, width=65, height=75)
                except Exception as e:
                    logger.warning(f"Could not load student photo from path {student.photo_url}: {e}")

        father_name = "N/A"
        from sqlalchemy.orm import joinedload
        from app.models.guardian import StudentGuardian, StudentGuardianRelationship, GuardianType
        stmt_g = select(StudentGuardian).where(
            StudentGuardian.student_id == student_id,
            StudentGuardian.school_id == school_id
        ).options(joinedload(StudentGuardian.guardian))
        res_g = await self.report_repo.db.execute(stmt_g)
        student_guardians = list(res_g.scalars().all())
        
        mother_obj = None
        for g_link in student_guardians:
            if g_link.guardian:
                rel = g_link.relationship
                g_type = g_link.guardian.guardian_type
                if rel == StudentGuardianRelationship.FATHER or g_type == GuardianType.FATHER:
                    father_name = f"{g_link.guardian.first_name} {g_link.guardian.last_name}"
                    break
                elif rel == StudentGuardianRelationship.MOTHER or g_type == GuardianType.MOTHER:
                    mother_obj = g_link.guardian
                    
        if father_name == "N/A" and mother_obj:
            father_name = f"{mother_obj.first_name} {mother_obj.last_name} (Mother)"

        class_teacher_name = "N/A"
        from app.models.teacher_subject_assignment import TeacherSubjectAssignment
        stmt_ct = select(TeacherSubjectAssignment).where(
            TeacherSubjectAssignment.section_id == student.section_id,
            TeacherSubjectAssignment.is_class_teacher == True,
            TeacherSubjectAssignment.deleted_at.is_(None)
        )
        res_ct = await self.report_repo.db.execute(stmt_ct)
        ct_assignment = res_ct.scalar_one_or_none()
        if ct_assignment:
            from app.models.teacher import Teacher
            stmt_teach = select(Teacher).where(Teacher.id == ct_assignment.teacher_id)
            res_teach = await self.report_repo.db.execute(stmt_teach)
            teacher_obj = res_teach.scalar_one_or_none()
            if teacher_obj:
                class_teacher_name = f"{teacher_obj.first_name} {teacher_obj.last_name}"

        dob_str = student.date_of_birth.strftime("%d-%b-%y") if student.date_of_birth else "N/A"
        
        student_details_data = [
            [
                Paragraph("<b>Student Name:</b>", body_style), Paragraph(f"{student.first_name} {student.last_name}", body_style),
                Paragraph("<b>Admission No:</b>", body_style), Paragraph(student.admission_number, body_style)
            ],
            [
                Paragraph("<b>Class & Section:</b>", body_style), Paragraph(f"{preview.class_name} - {preview.section_name}", body_style),
                Paragraph("<b>Roll Number:</b>", body_style), Paragraph(student.roll_number, body_style)
            ],
            [
                Paragraph("<b>Date of Birth:</b>", body_style), Paragraph(dob_str, body_style),
                Paragraph("<b>Father/Guardian:</b>", body_style), Paragraph(father_name, body_style)
            ],
            [
                Paragraph("<b>Class Teacher:</b>", body_style), Paragraph(class_teacher_name, body_style),
                Paragraph("<b>Blood Group:</b>", body_style), Paragraph(student.blood_group or "N/A", body_style)
            ]
        ]

        if photo_flowable:
            photo_table = Table([[photo_flowable]], colWidths=[69], rowHeights=[79])
            photo_table.setStyle(TableStyle([
                ('BOX', (0,0), (-1,-1), 1, gold_accent),
                ('ALIGN', (0,0), (-1,-1), 'CENTER'),
                ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
                ('PADDING', (0,0), (-1,-1), 2),
            ]))
            
            detail_table = Table(student_details_data, colWidths=[80, 135, 90, 135])
            detail_table.setStyle(TableStyle([
                ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
                ('PADDING', (0,0), (-1,-1), 4),
                ('LINEBELOW', (0,0), (-1,-1), 0.25, colors.HexColor("#E2E8F0")),
            ]))
            
            student_card_table = Table([[detail_table, photo_table]], colWidths=[440, 75])
            student_card_table.setStyle(TableStyle([
                ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
                ('ALIGN', (0,0), (-1,-1), 'CENTER'),
                ('PADDING', (0,0), (-1,-1), 0),
            ]))
        else:
            detail_table = Table(student_details_data, colWidths=[90, 167, 90, 168])
            detail_table.setStyle(TableStyle([
                ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
                ('PADDING', (0,0), (-1,-1), 4),
                ('LINEBELOW', (0,0), (-1,-1), 0.25, colors.HexColor("#E2E8F0")),
            ]))
            student_card_table = detail_table

        student_info_card = Table([[student_card_table]], colWidths=[515])
        student_info_card.setStyle(TableStyle([
            ('BOX', (0,0), (-1,-1), 1, navy_primary),
            ('BACKGROUND', (0,0), (-1,-1), light_grey),
            ('PADDING', (0,0), (-1,-1), 8),
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ]))
        story.append(student_info_card)
        story.append(Spacer(1, 10))
        
        # 3. Academic Snapshot (KPI Cards)
        attendance_val_str = f"{preview.attendance_present} / {preview.attendance_total}"
        attendance_pct_str = f"{preview.attendance_percentage}%"
        percentage_val_str = f"{preview.overall_percentage}%"
        grade_val_str = preview.overall_grade
        promotion_status_str = preview.promotion_status.replace('_', ' ').upper()

        kpi_title_style = ParagraphStyle('KPITitle', parent=styles['Normal'], fontName='Helvetica-Bold', fontSize=8, leading=10, textColor=colors.HexColor("#4A5568"), alignment=TA_CENTER)
        kpi_val_style = ParagraphStyle('KPIVal', parent=styles['Normal'], fontName='Helvetica-Bold', fontSize=14, leading=18, textColor=navy_primary, alignment=TA_CENTER)
        kpi_sub_style = ParagraphStyle('KPISub', parent=styles['Normal'], fontName='Helvetica', fontSize=7, leading=9, textColor=colors.HexColor("#718096"), alignment=TA_CENTER)

        card_w = 120
        space_w = 11.6
        
        c1 = Table([
            [Paragraph("ATTENDANCE", kpi_title_style)],
            [Paragraph(attendance_val_str, kpi_val_style)],
            [Paragraph(attendance_pct_str, kpi_sub_style)]
        ], colWidths=[card_w], rowHeights=[14, 20, 12])
        c1.setStyle(TableStyle([
            ('BOX', (0,0), (-1,-1), 1, border_grey),
            ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#F8FAFC")),
            ('LINEBELOW', (0,0), (-1,0), 1, gold_accent),
            ('ALIGN', (0,0), (-1,-1), 'CENTER'),
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ('PADDING', (0,0), (-1,-1), 2),
        ]))

        c2 = Table([
            [Paragraph("OVERALL MARKS", kpi_title_style)],
            [Paragraph(percentage_val_str, kpi_val_style)],
            [Paragraph("Percentage", kpi_sub_style)]
        ], colWidths=[card_w], rowHeights=[14, 20, 12])
        c2.setStyle(TableStyle([
            ('BOX', (0,0), (-1,-1), 1, border_grey),
            ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#F8FAFC")),
            ('LINEBELOW', (0,0), (-1,0), 1, gold_accent),
            ('ALIGN', (0,0), (-1,-1), 'CENTER'),
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ('PADDING', (0,0), (-1,-1), 2),
        ]))

        c3 = Table([
            [Paragraph("OVERALL GRADE", kpi_title_style)],
            [Paragraph(grade_val_str, kpi_val_style)],
            [Paragraph("Letter Grade", kpi_sub_style)]
        ], colWidths=[card_w], rowHeights=[14, 20, 12])
        c3.setStyle(TableStyle([
            ('BOX', (0,0), (-1,-1), 1, border_grey),
            ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#F8FAFC")),
            ('LINEBELOW', (0,0), (-1,0), 1, gold_accent),
            ('ALIGN', (0,0), (-1,-1), 'CENTER'),
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ('PADDING', (0,0), (-1,-1), 2),
        ]))

        promo_color = colors.HexColor("#10B981") if "PROMOTED" in promotion_status_str else colors.HexColor("#F59E0B")
        kpi_promo_val_style = ParagraphStyle('KPIPromoVal', parent=kpi_val_style, textColor=promo_color, fontSize=11, leading=15)
        
        c4 = Table([
            [Paragraph("STATUS", kpi_title_style)],
            [Paragraph(promotion_status_str, kpi_promo_val_style)],
            [Paragraph("Promotion Decision", kpi_sub_style)]
        ], colWidths=[card_w], rowHeights=[14, 20, 12])
        c4.setStyle(TableStyle([
            ('BOX', (0,0), (-1,-1), 1, border_grey),
            ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#F8FAFC")),
            ('LINEBELOW', (0,0), (-1,0), 1, gold_accent),
            ('ALIGN', (0,0), (-1,-1), 'CENTER'),
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ('PADDING', (0,0), (-1,-1), 2),
        ]))

        snapshot_table = Table([[c1, "", c2, "", c3, "", c4]], colWidths=[card_w, space_w, card_w, space_w, card_w, space_w, card_w])
        snapshot_table.setStyle(TableStyle([
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ('ALIGN', (0,0), (-1,-1), 'CENTER'),
        ]))
        story.append(snapshot_table)
        story.append(Spacer(1, 10))
        
        # 4. Academic Performance Table
        exams_in_order = history.examinations
        subjects_set = {}
        for exam in exams_in_order:
            for sub_mark in exam.subject_marks:
                subjects_set[sub_mark.subject_name] = True
        subjects_list = sorted(list(subjects_set.keys()))
        
        table_headers = [Paragraph("<b>Subject</b>", table_header_style)]
        for exam in exams_in_order:
            table_headers.append(Paragraph(f"<b>{exam.examination_name}</b>", table_header_style))
        table_headers.append(Paragraph("<b>Overall Avg</b>", table_header_style))
        table_headers.append(Paragraph("<b>Grade</b>", table_header_style))
        
        performance_rows = [table_headers]
        
        # School grading policy loader
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

        for sub_name in subjects_list:
            row = [Paragraph(sub_name, table_cell_left)]
            sub_total_obtained = 0.0
            sub_total_max = 0
            
            for exam in exams_in_order:
                sub_mark = next((sm for sm in exam.subject_marks if sm.subject_name == sub_name), None)
                if sub_mark and sub_mark.status == "PRESENT" and sub_mark.marks_obtained is not None:
                    obtained_val = sub_mark.marks_obtained
                    row.append(Paragraph(f"{obtained_val} ({sub_mark.grade})", table_cell_style))
                    sub_total_obtained += obtained_val
                    sub_total_max += sub_mark.max_marks
                elif sub_mark and sub_mark.status == "ABSENT":
                    row.append(Paragraph("ABS", table_cell_style))
                else:
                    row.append(Paragraph("-", table_cell_style))
                    
            if sub_total_max > 0:
                avg_pct = round((sub_total_obtained / sub_total_max) * 100, 2)
                overall_grade = get_grade_for_percentage(avg_pct)
                row.append(Paragraph(f"{avg_pct}%", table_cell_style))
                row.append(Paragraph(overall_grade, table_cell_style))
            else:
                row.append(Paragraph("-", table_cell_style))
                row.append(Paragraph("-", table_cell_style))
                
            performance_rows.append(row)
            
        # Add authoritative overall totals row
        total_row = [Paragraph("<b>TOTAL</b>", table_cell_left)]
        for exam in exams_in_order:
            total_row.append(Paragraph(f"<b>{exam.total_obtained_marks} / {exam.total_max_marks}</b>", table_cell_bold))
        total_row.append(Paragraph(f"<b>{preview.overall_percentage}%</b>", table_cell_bold))
        total_row.append(Paragraph(f"<b>{preview.overall_grade}</b>", table_cell_bold))
        performance_rows.append(total_row)
        
        # Compute exact widths dynamically
        num_exams = len(exams_in_order)
        sub_width = 115
        rem_width = 515 - sub_width
        col_width_each = rem_width / (num_exams + 2)
        
        perf_table = Table(performance_rows, colWidths=[sub_width] + [col_width_each] * (num_exams + 2))
        
        t_style = [
            ('BACKGROUND', (0,0), (-1,0), navy_primary),
            ('GRID', (0,0), (-1,-1), 0.5, border_grey),
            ('ALIGN', (0,0), (-1,-1), 'CENTER'),
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ('PADDING', (0,0), (-1,-1), 4),
            ('BACKGROUND', (0, -1), (-1, -1), colors.HexColor("#E2E8F0")),
            ('LINEABOVE', (0, -1), (-1, -1), 1.5, gold_accent),
        ]
        
        for i in range(1, len(performance_rows) - 1):
            bg = colors.HexColor("#F8FAFC") if i % 2 == 1 else colors.white
            t_style.append(('BACKGROUND', (0, i), (-1, i), bg))
            
        perf_table.setStyle(TableStyle(t_style))
        story.append(Paragraph("ACADEMIC PERFORMANCE MATRIX", section_title_style))
        story.append(perf_table)
        story.append(Spacer(1, 10))
        
        # 5. Side-by-side Grading Scale and Detailed Attendance Record (grouped together)
        secondary_group = []
        
        # Grade Scale table
        grade_headers = [
            Paragraph("<b>Range</b>", table_header_style),
            Paragraph("<b>Grade</b>", table_header_style)
        ]
        grade_scale_rows = [grade_headers]
        sorted_policy = sorted(grade_policy, key=lambda x: x.get("min_percentage", 0), reverse=True)
        for g in sorted_policy:
            min_p = g.get("min_percentage", 0)
            max_p = g.get("max_percentage", 100)
            label = f"{min_p}% and Above" if max_p >= 100 else f"{min_p}% - {max_p}%"
            grade_scale_rows.append([
                Paragraph(label, table_cell_style),
                Paragraph(f"<b>{g.get('grade')}</b>", table_cell_style)
            ])
            
        grade_scale_table = Table(grade_scale_rows, colWidths=[150, 90])
        grade_scale_table.setStyle(TableStyle([
            ('BACKGROUND', (0,0), (-1,0), navy_primary),
            ('GRID', (0,0), (-1,-1), 0.5, border_grey),
            ('ALIGN', (0,0), (-1,-1), 'CENTER'),
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ('PADDING', (0,0), (-1,-1), 3.5),
        ] + [
            ('BACKGROUND', (0, i), (-1, i), colors.HexColor("#F8FAFC") if i % 2 == 1 else colors.white)
            for i in range(1, len(grade_scale_rows))
        ]))

        # Attendance Record details
        attendance_detail_rows = [
            [Paragraph("<b>Attendance Metric</b>", table_header_style), Paragraph("<b>Value</b>", table_header_style)],
            [Paragraph("Total Working Days", table_cell_left), Paragraph(str(preview.attendance_total), table_cell_style)],
            [Paragraph("Days Present", table_cell_left), Paragraph(str(preview.attendance_present), table_cell_style)],
            [Paragraph("Days Absent", table_cell_left), Paragraph(str(preview.attendance_total - preview.attendance_present), table_cell_style)],
            [Paragraph("Attendance Percentage", table_cell_left), Paragraph(f"<b>{preview.attendance_percentage}%</b>", table_cell_style)]
        ]
        attendance_detail_table = Table(attendance_detail_rows, colWidths=[150, 90])
        attendance_detail_table.setStyle(TableStyle([
            ('BACKGROUND', (0,0), (-1,0), navy_primary),
            ('GRID', (0,0), (-1,-1), 0.5, border_grey),
            ('ALIGN', (0,0), (-1,-1), 'CENTER'),
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ('PADDING', (0,0), (-1,-1), 5),
        ] + [
            ('BACKGROUND', (0, i), (-1, i), colors.HexColor("#F8FAFC") if i % 2 == 1 else colors.white)
            for i in range(1, len(attendance_detail_rows))
        ]))

        side_by_side_table = Table([[grade_scale_table, "", attendance_detail_table]], colWidths=[240, 35, 240])
        side_by_side_table.setStyle(TableStyle([
            ('VALIGN', (0,0), (-1,-1), 'TOP'),
            ('ALIGN', (0,0), (-1,-1), 'CENTER'),
            ('PADDING', (0,0), (-1,-1), 0),
        ]))
        
        secondary_group.append(Paragraph("GRADING SCALE & ATTENDANCE SUMMARY", section_title_style))
        secondary_group.append(side_by_side_table)
        secondary_group.append(Spacer(1, 10))
        
        # 6. Academic Performance Trend Visualization
        trend_table_data = []
        trend_widths = []
        if num_exams > 0:
            # Display up to latest 5 examinations to ensure clean layout without table overflow
            recent_exams = exams_in_order[-5:]
            recent_num = len(recent_exams)
            card_w = max(50.0, min(85.0, (515.0 - (recent_num - 1) * 15.0) / recent_num))
            arrow_w = 15.0
            for i, exam in enumerate(recent_exams):
                trend_table_data.append(
                    Paragraph(
                        f"<b>{exam.examination_name}</b><br/><font size=11 color='{navy_primary.hexval()}'><b>{exam.percentage}%</b></font>",
                        ParagraphStyle('TrendVal', parent=body_style, alignment=TA_CENTER)
                    )
                )
                trend_widths.append(card_w)
                if i < len(recent_exams) - 1:
                    trend_table_data.append(
                        Paragraph("<font size=14 color='#A0AEC0'>→</font>", ParagraphStyle('Arrow', parent=body_style, alignment=TA_CENTER))
                    )
                    trend_widths.append(arrow_w)
            
            trend_table = Table([trend_table_data], colWidths=trend_widths)
            trend_table.setStyle(TableStyle([
                ('ALIGN', (0,0), (-1,-1), 'CENTER'),
                ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
                ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#F8FAFC")),
                ('BOX', (0,0), (-1,-1), 1, border_grey),
                ('PADDING', (0,0), (-1,-1), 6),
            ]))
            secondary_group.append(Paragraph("ACADEMIC PERFORMANCE TREND", section_title_style))
            secondary_group.append(trend_table)
            secondary_group.append(Spacer(1, 10))
            
        story.append(KeepTogether(secondary_group))

        # 7. AI Predictive Insights Section
        if show_ai_insights:
            ai_risk = "LOW"
            ai_trend = "STABLE"
            ai_narrative = "AI Insights not computed for this student."
            if db_rep and db_rep.ai_metrics:
                ai_data = db_rep.ai_metrics
                if isinstance(ai_data, str):
                    try:
                        import json
                        ai_data = json.loads(ai_data)
                    except Exception:
                        ai_data = {}
                if isinstance(ai_data, dict):
                    ai_risk = ai_data.get("risk_level", "LOW")
                    ai_trend = ai_data.get("overall_trend", "STABLE")
                    ai_narrative = ai_data.get("ai_narrative", ai_narrative)
                    
            risk_color = colors.HexColor("#10B981") # Green
            if ai_risk.upper() == "HIGH":
                risk_color = colors.HexColor("#EF4444") # Red
            elif ai_risk.upper() == "MEDIUM":
                risk_color = colors.HexColor("#F59E0B") # Amber
                
            ai_card_data = [
                [
                    Paragraph(f"<b>Academic Risk:</b> <font color='{risk_color.hexval()}'><b>{ai_risk}</b></font><br/><b>Academic Trend:</b> <b>{ai_trend}</b>", body_style),
                    Paragraph(f"<i>{ai_narrative}</i>", ParagraphStyle('AINarrative', parent=body_style, fontName='Helvetica-Oblique', fontSize=8.5, leading=12))
                ]
            ]
            ai_card_table = Table(ai_card_data, colWidths=[150, 365])
            ai_card_table.setStyle(TableStyle([
                ('BOX', (0,0), (-1,-1), 1, gold_accent),
                ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#FFFDF5")),
                ('PADDING', (0,0), (-1,-1), 8),
                ('VALIGN', (0,0), (-1,-1), 'TOP'),
            ]))
            story.append(Paragraph("AI ACADEMIC INSIGHTS", section_title_style))
            story.append(ai_card_table)
            story.append(Spacer(1, 10))

        # 8. Remarks & Signatures & Verification (Grouped together at bottom)
        footer_group = []
        remarks_data = []
        if show_remarks:
            remarks_data.append([
                Paragraph("<b>Class Teacher's Remarks:</b>", body_bold),
                Paragraph(preview.teacher_remarks or "No remarks recorded.", body_style)
            ])
            remarks_data.append([
                Paragraph("<b>Principal's Remarks:</b>", body_bold),
                Paragraph(preview.principal_remarks or "No remarks recorded.", body_style)
            ])
        if show_promotion:
            remarks_data.append([
                Paragraph("<b>Promotion Status:</b>", body_bold),
                Paragraph(f"<b>{promotion_status_str}</b>", body_bold)
            ])
            
        if remarks_data:
            remarks_table = Table(remarks_data, colWidths=[150, 365])
            remarks_table.setStyle(TableStyle([
                ('GRID', (0,0), (-1,-1), 0.5, border_grey),
                ('BACKGROUND', (0,0), (0,-1), colors.HexColor("#F8FAFC")),
                ('PADDING', (0,0), (-1,-1), 6),
                ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ]))
            footer_group.append(Paragraph("SIGNATURES & REMARKS", section_title_style))
            footer_group.append(remarks_table)
            footer_group.append(Spacer(1, 12))
            
        # Signatures
        sig_data = [
            [
                Paragraph(f"<br/><br/>_______________________<br/><b>{teacher_sig_label}</b>", ParagraphStyle('Sig', parent=body_style, alignment=TA_CENTER)),
                Paragraph(f"<br/><br/>_______________________<br/><b>{principal_sig_label}</b>", ParagraphStyle('Sig', parent=body_style, alignment=TA_CENTER)),
                Paragraph("<br/><br/>_______________________<br/><b>Parent / Guardian</b>", ParagraphStyle('Sig', parent=body_style, alignment=TA_CENTER))
            ]
        ]
        sig_table = Table(sig_data, colWidths=[171, 171, 171])
        sig_table.setStyle(TableStyle([
            ('ALIGN', (0,0), (-1,-1), 'CENTER'),
            ('VALIGN', (0,0), (-1,-1), 'BOTTOM'),
            ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ]))
        footer_group.append(sig_table)
        footer_group.append(Spacer(1, 12))
        
        # Digital Verification QR & UUID Card
        verification_uuid = db_rep.verification_uuid if db_rep else uuid.uuid4()
        qr_value = f"/api/v1/report-cards/verify/{verification_uuid}"
        
        qr_widget = QrCodeWidget(value=qr_value)
        qr_widget.barWidth = 55
        qr_widget.barHeight = 55
        qr_drawing = Drawing(55, 55)
        qr_drawing.add(qr_widget)
        
        verif_text = (
            f"<font size=8 color='{navy_primary.hexval()}'><b>SECURE DIGITAL VERIFICATION RECORD</b></font><br/>"
            f"<font size=7 color='#4A5568'>This report card is digitally signed and verified by EduPulse AI.<br/>"
            f"Verification UUID: <b>{verification_uuid}</b><br/>"
            f"Scan the QR code to verify the authenticity of this academic record.</font>"
        )
        verif_p = Paragraph(verif_text, ParagraphStyle('VerifText', parent=body_style, leading=11))
        
        verif_table = Table([[qr_drawing, verif_p]], colWidths=[65, 450])
        verif_table.setStyle(TableStyle([
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ('ALIGN', (0,0), (-1,-1), 'LEFT'),
            ('PADDING', (0,0), (-1,-1), 4),
            ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#F8FAFC")),
            ('BOX', (0,0), (-1,-1), 0.5, border_grey),
            ('LINELEFT', (1,0), (1,-1), 1.5, gold_accent),
        ]))
        footer_group.append(verif_table)
        
        story.append(KeepTogether(footer_group))
        
        # Build Document
        numbered_canvas_class = make_numbered_canvas_class(school.name if school else "Delhi Public School", ay_name, report_card_title)
        doc.build(story, canvasmaker=numbered_canvas_class)
        
        pdf_bytes = buffer.getvalue()
        buffer.close()
        return pdf_bytes

