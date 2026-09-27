import os
import uuid
import json
import logging
from datetime import datetime, timezone
from typing import List, Optional, Dict, Any, Union
from fastapi import HTTPException, status
from sqlalchemy import select, func
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
    ReportCardRejectRequest, ReportCardUnpublishRequest,
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
            school_ay = f"{getattr(self, 'school_name', 'EduPulse School').upper()} — Academic Year {getattr(self, 'academic_year', '2026-27')}"
            self.drawString(40, 800, school_ay)
            
            self.setFont("Helvetica", 8)
            self.setFillColor(text_color)
            self.drawRightString(555, 800, "Consolidated Multi-Exam Performance Matrix")
            
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

    async def get_reportable_examinations(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        student_id: Optional[uuid.UUID] = None,
        academic_year_id: Optional[uuid.UUID] = None,
        class_id: Optional[uuid.UUID] = None,
        section_id: Optional[uuid.UUID] = None,
        as_of_date: Optional[Any] = None,
        require_student_marks: bool = False
    ) -> List[Any]:
        """
        Authoritative single source of truth for reportable examinations.
        Rules:
        1. Belongs to student's school.
        2. Belongs to student's academic year.
        3. Participates in student's class/section.
        4. Not ARCHIVED.
        5. Not DRAFT.
        6. Scheduled examination date has occurred (exam.start_date <= as_of_date). Future exams are excluded.
        7. Lifecycle status in [COMPLETED, RESULTS_READY, PUBLISHED].
        8. Has actual marks for the class/student (or student if require_student_marks=True).
        """
        from datetime import date as dt_date
        from app.models.examination import Examination, ExamStatus, ExamSchedule
        from app.models.marks import Marks

        effective_as_of = as_of_date
        if not effective_as_of:
            effective_as_of = datetime.now(timezone.utc).date()
        elif isinstance(effective_as_of, datetime):
            effective_as_of = effective_as_of.date()

        # 1. Resolve student details if student_id provided
        if student_id and (not class_id or not academic_year_id):
            stmt_st = select(Student).where(
                Student.id == student_id,
                Student.school_id == school_id,
                Student.tenant_id == tenant_id,
                Student.deleted_at.is_(None)
            )
            res_st = await self.report_repo.db.execute(stmt_st)
            st = res_st.scalar_one_or_none()
            if st:
                class_id = class_id or st.class_id
                section_id = section_id or st.section_id
                academic_year_id = academic_year_id or st.academic_year_id

        # 2. Query candidate examinations
        stmt_exams = select(Examination).where(
            Examination.school_id == school_id,
            Examination.tenant_id == tenant_id,
            Examination.deleted_at.is_(None),
            Examination.status != ExamStatus.ARCHIVED,
            Examination.status != ExamStatus.DRAFT,
            Examination.status.in_([
                ExamStatus.COMPLETED,
                ExamStatus.PUBLISHED,
                ExamStatus.APPROVED,
                ExamStatus.LOCKED
            ]),
            Examination.start_date <= effective_as_of
        )
        if academic_year_id:
            stmt_exams = stmt_exams.where(Examination.academic_year_id == academic_year_id)

        res_exams = await self.report_repo.db.execute(stmt_exams)
        candidate_exams = list(res_exams.scalars().all())
        candidate_exams.sort(key=lambda x: x.start_date)

        reportable_exams = []
        for exam in candidate_exams:
            stmt_sch = select(ExamSchedule.id).where(
                ExamSchedule.exam_id == exam.id,
                ExamSchedule.deleted_at.is_(None)
            )
            if class_id:
                stmt_sch = stmt_sch.where(ExamSchedule.class_id == class_id)
            if section_id:
                res_sec_sch = await self.report_repo.db.execute(stmt_sch.where(ExamSchedule.section_id == section_id))
                sch_ids = [r[0] for r in res_sec_sch.fetchall()]
                if not sch_ids:
                    res_cls_sch = await self.report_repo.db.execute(stmt_sch)
                    sch_ids = [r[0] for r in res_cls_sch.fetchall()]
            else:
                res_cls_sch = await self.report_repo.db.execute(stmt_sch)
                sch_ids = [r[0] for r in res_cls_sch.fetchall()]

            if not sch_ids:
                continue

            if require_student_marks and student_id:
                stmt_m = select(func.count(Marks.id)).where(
                    Marks.exam_schedule_id.in_(sch_ids),
                    Marks.student_id == student_id,
                    Marks.deleted_at.is_(None),
                    Marks.marks_obtained.isnot(None)
                )
                res_m = await self.report_repo.db.execute(stmt_m)
                if (res_m.scalar() or 0) == 0:
                    continue

            reportable_exams.append(exam)

        return reportable_exams

    async def resolve_examination_weightages(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        examinations: List[Any]
    ) -> Dict[str, Any]:
        """
        Resolves examination weightages dynamically from school/academic year policy.
        Never hardcoded.
        Hierarchy:
          1. school.settings.get("result_policy", {}).get("examination_weights")
          2. academic_year.settings.get("examination_weightages")
          3. exam.settings.get("weightage") or exam.settings.get("weight")
          4. exam_type_masters.default_weightage
        Fallback: "PROPORTIONAL_MAX_MARKS"
        """
        if not examinations:
            return {
                "calculation_method": "PROPORTIONAL_MAX_MARKS",
                "weightages": {},
                "normalized_weights": {}
            }

        school = await self.school_repo.get_by_id(school_id, tenant_id)
        school_weights = {}
        if school and school.settings and isinstance(school.settings, dict):
            school_weights = (
                school.settings.get("result_policy", {}).get("examination_weights") or
                school.settings.get("examination_weightages") or
                school.settings.get("result_policy", {}).get("exam_weights") or
                {}
            )

        ay_weights = {}
        res_ay = await self.report_repo.db.execute(
            select(AcademicYear).where(AcademicYear.id == academic_year_id, AcademicYear.tenant_id == tenant_id)
        )
        academic_year = res_ay.scalar_one_or_none()
        if academic_year and academic_year.settings and isinstance(academic_year.settings, dict):
            ay_weights = (
                academic_year.settings.get("examination_weightages") or
                academic_year.settings.get("result_policy", {}).get("examination_weights") or
                {}
            )

        resolved_weights: Dict[str, float] = {}
        has_any_explicit_weight = False

        for exam in examinations:
            exam_id_str = str(exam.id)
            exam_name = exam.exam_name
            exam_type_val = exam.exam_type.value if hasattr(exam.exam_type, "value") else str(exam.exam_type)

            weight = None
            # 1. School policy
            if exam_id_str in school_weights:
                weight = float(school_weights[exam_id_str])
            elif exam_name in school_weights:
                weight = float(school_weights[exam_name])
            elif exam_type_val in school_weights:
                weight = float(school_weights[exam_type_val])

            # 2. Academic year policy
            if weight is None:
                if exam_id_str in ay_weights:
                    weight = float(ay_weights[exam_id_str])
                elif exam_name in ay_weights:
                    weight = float(ay_weights[exam_name])
                elif exam_type_val in ay_weights:
                    weight = float(ay_weights[exam_type_val])

            # 3. Individual exam settings
            if weight is None and exam.settings and isinstance(exam.settings, dict):
                if "weightage" in exam.settings:
                    try:
                        weight = float(exam.settings["weightage"])
                    except (ValueError, TypeError):
                        pass
                elif "weight" in exam.settings:
                    try:
                        weight = float(exam.settings["weight"])
                    except (ValueError, TypeError):
                        pass

            if weight is not None and weight > 0:
                has_any_explicit_weight = True
                resolved_weights[exam_id_str] = weight
            else:
                resolved_weights[exam_id_str] = 0.0

        total_weight = sum(resolved_weights.values())
        if has_any_explicit_weight and total_weight > 0:
            calculation_method = "WEIGHTED_POLICY"
            normalized_weights = {eid: w / total_weight for eid, w in resolved_weights.items()}
        else:
            calculation_method = "PROPORTIONAL_MAX_MARKS"
            normalized_weights = {eid: 1.0 / len(examinations) for eid in resolved_weights}
            resolved_weights = {str(exam.id): 1.0 for exam in examinations}

        return {
            "calculation_method": calculation_method,
            "weightages": resolved_weights,
            "normalized_weights": normalized_weights
        }

    async def validate_report_card_data(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        student_id: uuid.UUID,
        academic_year_id: Optional[uuid.UUID] = None,
        examination_id: Optional[uuid.UUID] = None,
        teacher_remarks: Optional[str] = None,
        report_card_type: Optional[str] = "CONSOLIDATED"
    ) -> Dict[str, Any]:
        """
        Authoritative single validation method for determining report card completeness.
        Supports both Consolidated Academic-Year evaluation and Single Examination evaluation.
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

        effective_teacher_remarks = teacher_remarks
        has_explicit_teacher_remarks = bool(teacher_remarks) or (
            db_rep and db_rep.settings and bool(db_rep.settings.get("teacher_remarks"))
        )
        if not effective_teacher_remarks and db_rep and db_rep.settings:
            effective_teacher_remarks = db_rep.settings.get("teacher_remarks")

        if not effective_teacher_remarks:
            effective_teacher_remarks = "Good academic progress and conduct."

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

        promotion_policy = school.settings.get("promotion_policy") if school else None
        if not promotion_policy:
            promotion_policy = {
                "min_attendance_pct": 75.0,
                "min_overall_pct": 35.0,
                "max_failed_subjects": 0
            }

        # Attendance summaries
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

        # ==================================================
        # Branch 1: Single Examination Validation
        # ==================================================
        if report_card_type == "SINGLE_EXAM" or (examination_id is not None and report_card_type != "CONSOLIDATED"):
            target_exam_id = examination_id
            if not target_exam_id and db_rep and db_rep.settings and db_rep.settings.get("examination_id"):
                try:
                    target_exam_id = uuid.UUID(str(db_rep.settings["examination_id"]))
                except Exception:
                    target_exam_id = None

            stmt_sch = select(ExamSchedule).where(
                ExamSchedule.class_id == student.class_id,
                ExamSchedule.section_id == student.section_id,
                ExamSchedule.school_id == school_id,
                ExamSchedule.tenant_id == tenant_id,
                ExamSchedule.deleted_at.is_(None)
            )
            if target_exam_id:
                stmt_sch = stmt_sch.where(ExamSchedule.exam_id == target_exam_id)

            stmt_sch = stmt_sch.options(joinedload(ExamSchedule.subject))
            res_sch = await self.report_repo.db.execute(stmt_sch)
            schedules = list(res_sch.scalars().all())

            warnings = []
            if not has_explicit_teacher_remarks:
                warnings.append("Teacher remark not entered.")
            if not schedules:
                warnings.append("No examination schedules configured for class and section.")

            subject_marks_rows = []
            total_max_marks = 0
            total_obtained_marks = 0.0
            failed_subjects_count = 0

            for sched in schedules:
                stmt_m = select(Marks).where(
                    Marks.exam_schedule_id == sched.id,
                    Marks.student_id == student_id,
                    Marks.deleted_at.is_(None)
                )
                res_m = await self.report_repo.db.execute(stmt_m)
                mark = res_m.scalar_one_or_none()

                subj_name = sched.subject.subject_name if sched.subject else "Subject"
                subj_code = sched.subject.subject_code if sched.subject else None

                if not mark or mark.marks_obtained is None:
                    warnings.append(f"{subj_name} marks not entered.")
                    subject_marks_rows.append(ReportCardSubjectMarkRow(
                        subject_id=sched.subject_id,
                        subject_name=subj_name,
                        subject_code=subj_code,
                        maximum_marks=sched.max_marks,
                        marks_obtained=None,
                        result_status="ABSENT" if not mark else (mark.result_status.value if hasattr(mark.result_status, "value") else str(mark.result_status)),
                        grade="N/A",
                        remarks=mark.remarks if mark else "Marks pending entry"
                    ))
                    continue

                obtained = float(mark.marks_obtained)
                max_m = sched.max_marks
                total_max_marks += max_m
                res_status = mark.result_status.value if hasattr(mark.result_status, "value") else str(mark.result_status)
                grade = "F"
                if res_status in ["PRESENT", "EXEMPTED"] and obtained is not None:
                    total_obtained_marks += obtained
                    paper_pct = (obtained / max_m) * 100 if max_m > 0 else 0.0
                    grade = get_grade_for_percentage(paper_pct)
                    if obtained < max_m * 0.35:
                        failed_subjects_count += 1
                else:
                    failed_subjects_count += 1

                subject_marks_rows.append(ReportCardSubjectMarkRow(
                    subject_id=sched.subject_id,
                    subject_name=subj_name,
                    subject_code=subj_code,
                    maximum_marks=max_m,
                    marks_obtained=obtained,
                    result_status=res_status,
                    grade=grade,
                    remarks=mark.remarks
                ))

            section_rank = "Rank unavailable - result incomplete"
            class_rank = "Rank unavailable - result incomplete"

            if not schedules:
                overall_pct = 0.0
                overall_grade = "N/A"
                prom_status = "NOT_CONFIGURED"
                section_rank = "Rank unavailable - not configured"
                class_rank = "Rank unavailable - not configured"
            else:
                overall_pct = round((total_obtained_marks / total_max_marks) * 100, 2) if total_max_marks > 0 else 0.0
                overall_grade = get_grade_for_percentage(overall_pct)
                prom_status = "PROMOTED"
                if attendance_pct < promotion_policy.get("min_attendance_pct", 75.0):
                    prom_status = "PROMOTION_UNDER_REVIEW"
                elif overall_pct < promotion_policy.get("min_overall_pct", 35.0) or failed_subjects_count > 1:
                    prom_status = "DETAINED"
                elif failed_subjects_count == 1:
                    prom_status = "CONDITIONALLY_PROMOTED"

                is_complete_for_rank = (len(schedules) > 0 and len(subject_marks_rows) == len(schedules) and all(r.marks_obtained is not None for r in subject_marks_rows))
                if is_complete_for_rank:
                    stmt_sec_m = select(
                        Marks.student_id,
                        func.sum(Marks.marks_obtained).label("tot"),
                        func.count(Marks.id).label("cnt")
                    ).where(
                        Marks.exam_schedule_id.in_([s.id for s in schedules]),
                        Marks.deleted_at.is_(None),
                        Marks.marks_obtained.isnot(None)
                    ).group_by(Marks.student_id)
                    res_sec_m = await self.report_repo.db.execute(stmt_sec_m)
                    sec_rows = res_sec_m.fetchall()
                    eligible_sec = [(r[0], float(r[1])) for r in sec_rows if r[2] == len(schedules)]
                    my_sec_tot = next((t for s_id, t in eligible_sec if s_id == student_id), None)
                    if my_sec_tot is not None:
                        sec_pos = 1 + sum(1 for _, t in eligible_sec if t > my_sec_tot)
                        section_rank = f"Rank {sec_pos} of {len(eligible_sec)}"

                    target_cls_exam_id = target_exam_id or (schedules[0].exam_id if schedules else None)
                    if target_cls_exam_id:
                        stmt_cls_sch = select(ExamSchedule.id).where(
                            ExamSchedule.exam_id == target_cls_exam_id,
                            ExamSchedule.class_id == student.class_id,
                            ExamSchedule.deleted_at.is_(None)
                        )
                        res_cls_sch = await self.report_repo.db.execute(stmt_cls_sch)
                        cls_sched_ids = [r[0] for r in res_cls_sch.fetchall()]
                        if cls_sched_ids:
                            stmt_cls_m = select(
                                Marks.student_id,
                                func.sum(Marks.marks_obtained).label("tot"),
                                func.count(Marks.id).label("cnt")
                            ).where(
                                Marks.exam_schedule_id.in_(cls_sched_ids),
                                Marks.deleted_at.is_(None),
                                Marks.marks_obtained.isnot(None)
                            ).group_by(Marks.student_id)
                            res_cls_m = await self.report_repo.db.execute(stmt_cls_m)
                            cls_rows = res_cls_m.fetchall()
                            eligible_cls = [(r[0], float(r[1])) for r in cls_rows if r[2] == len(schedules)]
                            my_cls_tot = next((t for s_id, t in eligible_cls if s_id == student_id), None)
                            if my_cls_tot is not None:
                                cls_pos = 1 + sum(1 for _, t in eligible_cls if t > my_cls_tot)
                                class_rank = f"Rank {cls_pos} of {len(eligible_cls)}"
                            else:
                                class_rank = section_rank
                        else:
                            class_rank = section_rank
                    else:
                        class_rank = section_rank

            return {
                "student": student,
                "db_rep": db_rep,
                "is_valid": len(warnings) == 0,
                "missing_reasons": warnings,
                "subject_marks_rows": subject_marks_rows,
                "consolidated_subject_marks": None,
                "total_days": total_days,
                "present_days": present_days,
                "attendance_pct": attendance_pct,
                "overall_pct": overall_pct,
                "overall_grade": overall_grade,
                "total_obtained": total_obtained_marks,
                "total_max": total_max_marks,
                "prom_status": prom_status,
                "class_rank": class_rank,
                "section_rank": section_rank,
                "teacher_remarks": effective_teacher_remarks,
                "report_card_type": "SINGLE_EXAM",
                "calculation_method": "SINGLE_EXAM",
                "examination_weightages": None
            }

        # ==================================================
        # Branch 2: Consolidated Academic-Year Validation
        # ==================================================
        candidate_exams = await self.get_reportable_examinations(
            tenant_id=tenant_id,
            school_id=school_id,
            student_id=student.id,
            academic_year_id=effective_ay_id,
            class_id=student.class_id,
            section_id=student.section_id,
            as_of_date=datetime.now(timezone.utc).date()
        )

        # Filter to examinations that have schedules for this student's class and section
        active_exams = []
        exam_schedules: Dict[uuid.UUID, List[ExamSchedule]] = {}
        for exam in candidate_exams:
            stmt_sch = select(ExamSchedule).where(
                ExamSchedule.exam_id == exam.id,
                ExamSchedule.class_id == student.class_id,
                ExamSchedule.section_id == student.section_id,
                ExamSchedule.deleted_at.is_(None)
            ).options(joinedload(ExamSchedule.subject))
            res_sch = await self.report_repo.db.execute(stmt_sch)
            schs = list(res_sch.scalars().all())
            if not schs:
                # Fallback to schedules configured for class regardless of section
                stmt_sch_cls = select(ExamSchedule).where(
                    ExamSchedule.exam_id == exam.id,
                    ExamSchedule.class_id == student.class_id,
                    ExamSchedule.deleted_at.is_(None)
                ).options(joinedload(ExamSchedule.subject))
                res_sch_cls = await self.report_repo.db.execute(stmt_sch_cls)
                schs = list(res_sch_cls.scalars().all())
            if schs:
                active_exams.append(exam)
                exam_schedules[exam.id] = schs

        warnings = []
        if not has_explicit_teacher_remarks:
            warnings.append("Teacher remark not entered.")
        if not active_exams:
            warnings.append("No examination schedules configured for class and section.")

        # Resolve weightages dynamically
        weight_res = await self.resolve_examination_weightages(
            tenant_id, school_id, effective_ay_id, active_exams
        )
        calc_method = weight_res["calculation_method"]
        weightages = weight_res["weightages"]
        normalized_weights = weight_res["normalized_weights"]

        # Map of subject_id -> subject metadata and exam marks
        subjects_map: Dict[uuid.UUID, Dict[str, Any]] = {}
        all_schedule_ids = []

        for exam in active_exams:
            for sched in exam_schedules[exam.id]:
                all_schedule_ids.append(sched.id)
                sub_id = sched.subject_id
                if sub_id not in subjects_map:
                    subj_name = sched.subject.subject_name if sched.subject else "Subject"
                    subj_code = sched.subject.subject_code if sched.subject else None
                    subjects_map[sub_id] = {
                        "subject_id": sub_id,
                        "subject_name": subj_name,
                        "subject_code": subj_code,
                        "exam_data": {}
                    }

                stmt_m = select(Marks).where(
                    Marks.exam_schedule_id == sched.id,
                    Marks.student_id == student_id,
                    Marks.deleted_at.is_(None)
                )
                res_m = await self.report_repo.db.execute(stmt_m)
                mark = res_m.scalar_one_or_none()
                subjects_map[sub_id]["exam_data"][exam.id] = {
                    "schedule": sched,
                    "mark": mark
                }

                if not mark or mark.marks_obtained is None:
                    subj_display = subjects_map[sub_id]["subject_name"]
                    warnings.append(f"{exam.exam_name}: {subj_display} marks not entered.")

        consolidated_subject_marks = []
        subject_marks_rows = []
        failed_subjects_count = 0
        total_obtained_marks = 0.0
        total_max_marks = 0

        # Per-exam totals for weighted calculation
        exam_totals: Dict[uuid.UUID, Dict[str, float]] = {
            e.id: {"obtained": 0.0, "max": 0.0} for e in active_exams
        }

        for sub_id, s_info in subjects_map.items():
            sub_name = s_info["subject_name"]
            sub_code = s_info["subject_code"]
            sub_exams_dict = {}

            sub_tot_obt = 0.0
            sub_tot_max = 0
            sub_weighted_pct_sum = 0.0
            sub_weight_sum = 0.0

            for exam in active_exams:
                e_data = s_info["exam_data"].get(exam.id)
                if not e_data:
                    continue
                sched = e_data["schedule"]
                mark = e_data["mark"]
                w = normalized_weights.get(str(exam.id), 0.0)

                if mark and mark.marks_obtained is not None:
                    obt = float(mark.marks_obtained)
                    max_m = sched.max_marks
                    sub_tot_obt += obt
                    sub_tot_max += max_m
                    exam_totals[exam.id]["obtained"] += obt
                    exam_totals[exam.id]["max"] += max_m

                    pct = (obt / max_m) * 100.0 if max_m > 0 else 0.0
                    gr = get_grade_for_percentage(pct)
                    st = mark.result_status.value if hasattr(mark.result_status, "value") else str(mark.result_status)

                    sub_exams_dict[str(exam.id)] = {
                        "exam_name": exam.exam_name,
                        "marks_obtained": obt,
                        "max_marks": max_m,
                        "percentage": round(pct, 2),
                        "grade": gr,
                        "status": st
                    }

                    sub_weighted_pct_sum += pct * w
                    sub_weight_sum += w
                else:
                    sub_exams_dict[str(exam.id)] = {
                        "exam_name": exam.exam_name,
                        "marks_obtained": None,
                        "max_marks": sched.max_marks,
                        "percentage": None,
                        "grade": "N/A",
                        "status": "ABSENT" if not mark else (mark.result_status.value if hasattr(mark.result_status, "value") else str(mark.result_status))
                    }

            # Calculate final consolidated subject score
            if calc_method == "WEIGHTED_POLICY" and sub_weight_sum > 0:
                final_sub_pct = round(sub_weighted_pct_sum / sub_weight_sum, 2)
                ref_max = 100
                final_sub_obt = round((final_sub_pct / 100.0) * ref_max, 2)
            elif sub_tot_max > 0:
                final_sub_pct = round((sub_tot_obt / sub_tot_max) * 100.0, 2)
                ref_max = sub_tot_max
                final_sub_obt = round(sub_tot_obt, 2)
            else:
                final_sub_pct = 0.0
                ref_max = 100
                final_sub_obt = 0.0

            final_sub_grade = get_grade_for_percentage(final_sub_pct)
            if final_sub_pct < 35.0:
                failed_subjects_count += 1

            total_obtained_marks += final_sub_obt
            total_max_marks += ref_max

            consolidated_subject_marks.append({
                "subject_id": str(sub_id),
                "subject_name": sub_name,
                "subject_code": sub_code,
                "exams": sub_exams_dict,
                "consolidated_marks": final_sub_obt,
                "consolidated_percentage": final_sub_pct,
                "maximum_marks": ref_max,
                "grade": final_sub_grade
            })

            subject_marks_rows.append(ReportCardSubjectMarkRow(
                subject_id=sub_id,
                subject_name=sub_name,
                subject_code=sub_code,
                maximum_marks=ref_max,
                marks_obtained=final_sub_obt if len(warnings) == 0 else None,
                result_status="PRESENT" if len(warnings) == 0 else "PENDING",
                grade=final_sub_grade if len(warnings) == 0 else "N/A",
                remarks=None
            ))

        if calc_method == "WEIGHTED_POLICY":
            weighted_overall_sum = 0.0
            active_w_sum = 0.0
            for exam in active_exams:
                e_id = exam.id
                w = normalized_weights.get(str(e_id), 0.0)
                e_obt = exam_totals[e_id]["obtained"]
                e_max = exam_totals[e_id]["max"]
                if e_max > 0:
                    e_pct = (e_obt / e_max) * 100.0
                    weighted_overall_sum += e_pct * w
                    active_w_sum += w
            overall_pct = round(weighted_overall_sum / active_w_sum, 2) if active_w_sum > 0 else 0.0
        else:
            grand_obt = sum(exam_totals[e.id]["obtained"] for e in active_exams)
            grand_max = sum(exam_totals[e.id]["max"] for e in active_exams)
            overall_pct = round((grand_obt / grand_max) * 100.0, 2) if grand_max > 0 else 0.0

        overall_grade = get_grade_for_percentage(overall_pct)

        section_rank = "Rank unavailable - result incomplete"
        class_rank = "Rank unavailable - result incomplete"

        if not active_exams:
            overall_pct = 0.0
            overall_grade = "N/A"
            prom_status = "NOT_CONFIGURED"
            section_rank = "Rank unavailable - not configured"
            class_rank = "Rank unavailable - not configured"
        elif len(warnings) > 0:
            prom_status = "PENDING_RESULTS"
            section_rank = "Rank unavailable - result incomplete"
            class_rank = "Rank unavailable - result incomplete"
        else:
            prom_status = "PROMOTED"
            if attendance_pct < promotion_policy.get("min_attendance_pct", 75.0):
                prom_status = "PROMOTION_UNDER_REVIEW"
            elif overall_pct < promotion_policy.get("min_overall_pct", 35.0) or failed_subjects_count > 1:
                prom_status = "DETAINED"
            elif failed_subjects_count == 1:
                prom_status = "CONDITIONALLY_PROMOTED"

            # -------------------------------------------------------------
            # Consolidated Ranking Calculation
            # -------------------------------------------------------------
            if len(all_schedule_ids) > 0:
                # 1. Section Ranking
                stmt_sec_st = select(Student.id).where(
                    Student.section_id == student.section_id,
                    Student.school_id == school_id,
                    Student.tenant_id == tenant_id,
                    Student.is_active == True,
                    Student.deleted_at.is_(None)
                )
                res_sec_st = await self.report_repo.db.execute(stmt_sec_st)
                sec_student_ids = [r[0] for r in res_sec_st.fetchall()]

                stmt_m_bulk = select(
                    Marks.student_id,
                    Marks.exam_schedule_id,
                    Marks.marks_obtained
                ).where(
                    Marks.exam_schedule_id.in_(all_schedule_ids),
                    Marks.student_id.in_(sec_student_ids),
                    Marks.deleted_at.is_(None),
                    Marks.marks_obtained.isnot(None)
                )
                res_m_bulk = await self.report_repo.db.execute(stmt_m_bulk)
                sec_marks_rows = res_m_bulk.fetchall()

                sec_marks_map = {}
                for s_id, sch_id, obt in sec_marks_rows:
                    sec_marks_map[(s_id, sch_id)] = float(obt)

                sch_max_map = {s.id: s.max_marks for exam in active_exams for s in exam_schedules[exam.id]}

                sec_eligible_scores = {}
                for s_id in sec_student_ids:
                    if all((s_id, sch_id) in sec_marks_map for sch_id in all_schedule_ids):
                        if calc_method == "WEIGHTED_POLICY":
                            s_wt_sum = 0.0
                            s_w_tot = 0.0
                            for exam in active_exams:
                                e_id = exam.id
                                w = normalized_weights.get(str(e_id), 0.0)
                                e_obt = sum(sec_marks_map[(s_id, s.id)] for s in exam_schedules[e_id])
                                e_max = sum(sch_max_map[s.id] for s in exam_schedules[e_id])
                                if e_max > 0:
                                    s_wt_sum += (e_obt / e_max) * 100.0 * w
                                    s_w_tot += w
                            s_score = round(s_wt_sum / s_w_tot, 2) if s_w_tot > 0 else 0.0
                        else:
                            g_obt = sum(sec_marks_map[(s_id, sch_id)] for sch_id in all_schedule_ids)
                            g_max = sum(sch_max_map[sch_id] for sch_id in all_schedule_ids)
                            s_score = round((g_obt / g_max) * 100.0, 2) if g_max > 0 else 0.0
                        sec_eligible_scores[s_id] = s_score

                if student_id in sec_eligible_scores:
                    my_sec_score = sec_eligible_scores[student_id]
                    sec_pos = 1 + sum(1 for s_id, sc in sec_eligible_scores.items() if sc > my_sec_score)
                    section_rank = f"Rank {sec_pos} of {len(sec_eligible_scores)}"
                else:
                    section_rank = "Rank unavailable - result incomplete"

                # 2. Class Ranking
                stmt_cls_st = select(Student.id, Student.section_id).where(
                    Student.class_id == student.class_id,
                    Student.school_id == school_id,
                    Student.tenant_id == tenant_id,
                    Student.is_active == True,
                    Student.deleted_at.is_(None)
                )
                res_cls_st = await self.report_repo.db.execute(stmt_cls_st)
                cls_students = res_cls_st.fetchall()
                cls_student_ids = [r[0] for r in cls_students]

                stmt_cls_sch = select(ExamSchedule).where(
                    ExamSchedule.exam_id.in_([e.id for e in active_exams]),
                    ExamSchedule.class_id == student.class_id,
                    ExamSchedule.deleted_at.is_(None)
                )
                res_cls_sch = await self.report_repo.db.execute(stmt_cls_sch)
                cls_all_schedules = list(res_cls_sch.scalars().all())
                cls_sch_ids = [s.id for s in cls_all_schedules]

                stmt_cls_m = select(
                    Marks.student_id,
                    Marks.exam_schedule_id,
                    Marks.marks_obtained
                ).where(
                    Marks.exam_schedule_id.in_(cls_sch_ids),
                    Marks.student_id.in_(cls_student_ids),
                    Marks.deleted_at.is_(None),
                    Marks.marks_obtained.isnot(None)
                )
                res_cls_m = await self.report_repo.db.execute(stmt_cls_m)
                cls_marks_rows = res_cls_m.fetchall()

                cls_marks_map = {}
                for s_id, sch_id, obt in cls_marks_rows:
                    cls_marks_map[(s_id, sch_id)] = float(obt)

                cls_sch_max_map = {s.id: s.max_marks for s in cls_all_schedules}

                cls_eligible_scores = {}
                for s_id, s_sec_id in cls_students:
                    expected_schs = [s for s in cls_all_schedules if s.section_id == s_sec_id or s.section_id is None]
                    if expected_schs and all((s_id, sch.id) in cls_marks_map for sch in expected_schs):
                        if calc_method == "WEIGHTED_POLICY":
                            s_wt_sum = 0.0
                            s_w_tot = 0.0
                            for exam in active_exams:
                                e_id = exam.id
                                w = normalized_weights.get(str(e_id), 0.0)
                                e_schs = [s for s in expected_schs if s.exam_id == e_id]
                                if e_schs:
                                    e_obt = sum(cls_marks_map[(s_id, s.id)] for s in e_schs)
                                    e_max = sum(cls_sch_max_map[s.id] for s in e_schs)
                                    if e_max > 0:
                                        s_wt_sum += (e_obt / e_max) * 100.0 * w
                                        s_w_tot += w
                            s_score = round(s_wt_sum / s_w_tot, 2) if s_w_tot > 0 else 0.0
                        else:
                            g_obt = sum(cls_marks_map[(s_id, sch.id)] for sch in expected_schs)
                            g_max = sum(cls_sch_max_map[sch.id] for sch in expected_schs)
                            s_score = round((g_obt / g_max) * 100.0, 2) if g_max > 0 else 0.0
                        cls_eligible_scores[s_id] = s_score

                if student_id in cls_eligible_scores:
                    my_cls_score = cls_eligible_scores[student_id]
                    cls_pos = 1 + sum(1 for s_id, sc in cls_eligible_scores.items() if sc > my_cls_score)
                    class_rank = f"Rank {cls_pos} of {len(cls_eligible_scores)}"
                else:
                    class_rank = "Rank unavailable - result incomplete"

        exam_weightages_display = {
            e.exam_name: weightages.get(str(e.id), 0.0) for e in active_exams
        }

        return {
            "student": student,
            "db_rep": db_rep,
            "is_valid": len(warnings) == 0,
            "missing_reasons": warnings,
            "subject_marks_rows": subject_marks_rows,
            "consolidated_subject_marks": consolidated_subject_marks,
            "total_days": total_days,
            "present_days": present_days,
            "attendance_pct": attendance_pct,
            "overall_pct": overall_pct,
            "overall_grade": overall_grade,
            "total_obtained": total_obtained_marks,
            "total_max": total_max_marks,
            "prom_status": prom_status,
            "class_rank": class_rank,
            "section_rank": section_rank,
            "teacher_remarks": effective_teacher_remarks,
            "report_card_type": report_card_type,
            "calculation_method": calc_method,
            "examination_weightages": exam_weightages_display
        }

    async def compile_live_data(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        student_id: uuid.UUID,
        teacher_remarks: Optional[str] = None,
        examination_id: Optional[uuid.UUID] = None,
        report_card_type: Optional[str] = "CONSOLIDATED"
    ) -> ReportCardPreviewResponse:
        val = await self.validate_report_card_data(
            tenant_id=tenant_id,
            school_id=school_id,
            student_id=student_id,
            examination_id=examination_id,
            teacher_remarks=teacher_remarks,
            report_card_type=report_card_type
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
            class_rank=val.get("class_rank"),
            section_rank=val.get("section_rank"),
            subject_marks=val["subject_marks_rows"],
            consolidated_subject_marks=val.get("consolidated_subject_marks"),
            report_card_type=val.get("report_card_type"),
            calculation_method=val.get("calculation_method"),
            examination_weightages=val.get("examination_weightages"),
            teacher_remarks=val["teacher_remarks"],
            principal_remarks="Approved for promotion." if prom_status == "PROMOTED" else ("Promotion under principal review." if prom_status not in ["NOT_CONFIGURED", "PENDING_RESULTS"] else "Pending examination completion."),
            ai_narrative="This section will be available after AI analysis.",
            is_valid=val["is_valid"],
            missing_reasons=val["missing_reasons"]
        )

    async def generate_report_card(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, obj_in: ReportCardGenerateRequest, current_user: User
    ) -> ReportCardPublication:
        # 1. Compile live validation check
        effective_remarks = obj_in.teacher_remarks or "Good academic progress and conduct."
        rep_type = obj_in.report_card_type or "CONSOLIDATED"
        preview = await self.compile_live_data(
            tenant_id, school_id, obj_in.student_id, effective_remarks, obj_in.examination_id, report_card_type=rep_type
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
            db_rep.settings["report_card_type"] = preview.report_card_type
            db_rep.settings["calculation_method"] = preview.calculation_method
            db_rep.settings["examination_weightages"] = preview.examination_weightages
            db_rep.settings["consolidated_subject_marks"] = preview.consolidated_subject_marks
            db_rep.settings["teacher_remarks"] = obj_in.teacher_remarks or effective_remarks
            db_rep.settings["class_rank"] = preview.class_rank
            db_rep.settings["section_rank"] = preview.section_rank
            db_rep.settings["overall_percentage"] = preview.overall_percentage
            db_rep.settings["overall_grade"] = preview.overall_grade
            db_rep.settings["promotion_status"] = preview.promotion_status
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
            db_rep.settings["report_card_type"] = preview.report_card_type
            db_rep.settings["calculation_method"] = preview.calculation_method
            db_rep.settings["examination_weightages"] = preview.examination_weightages
            db_rep.settings["consolidated_subject_marks"] = preview.consolidated_subject_marks
            db_rep.settings["teacher_remarks"] = obj_in.teacher_remarks or effective_remarks
            db_rep.settings["class_rank"] = preview.class_rank
            db_rep.settings["section_rank"] = preview.section_rank
            db_rep.settings["overall_percentage"] = preview.overall_percentage
            db_rep.settings["overall_grade"] = preview.overall_grade
            db_rep.settings["promotion_status"] = preview.promotion_status

        db_rep.settings = json.loads(json.dumps(db_rep.settings, default=str))

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
                    report_card_type=obj_in.report_card_type or "CONSOLIDATED",
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

            if db_rep.status not in [ReportCardStatus.APPROVED, ReportCardStatus.UNDER_REVIEW, ReportCardStatus.DRAFT]:
                failed_count += 1
                failures.append(StudentFailureDetail(
                    student_id=db_rep.student_id,
                    student_name=student_name,
                    reasons=[f"Report card is in {db_rep.status.value} status and cannot be published."]
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

            if db_rep.status != ReportCardStatus.APPROVED:
                db_rep.approved_by = current_user.id
                db_rep.approved_at = now

            if not db_rep.settings or not isinstance(db_rep.settings, dict):
                db_rep.settings = {}
            else:
                db_rep.settings = dict(db_rep.settings)

            raw_snapshot = {
                "overall_percentage": val["overall_pct"],
                "overall_grade": val["overall_grade"],
                "promotion_status": val["prom_status"],
                "attendance_total": val["total_days"],
                "attendance_present": val["present_days"],
                "attendance_percentage": val["attendance_pct"],
                "class_rank": val["class_rank"],
                "section_rank": val["section_rank"],
                "teacher_remarks": val["teacher_remarks"],
                "calculation_method": val.get("calculation_method"),
                "examination_weightages": val.get("examination_weightages"),
                "consolidated_subject_marks": val.get("consolidated_subject_marks"),
                "subject_marks_rows": [
                    row.model_dump() if hasattr(row, "model_dump") else (row.dict() if hasattr(row, "dict") else dict(row))
                    for row in val.get("subject_marks_rows", [])
                ],
                "published_at": now.isoformat()
            }
            db_rep.settings["snapshot"] = json.loads(json.dumps(raw_snapshot, default=str))
            db_rep.settings = json.loads(json.dumps(db_rep.settings, default=str))

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

    async def reject_report_card(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, id: uuid.UUID, obj_in: ReportCardRejectRequest, current_user: User
    ) -> ReportCardPublication:
        db_rep = await self.report_repo.get_by_id(id, school_id, tenant_id)
        if not db_rep:
            raise HTTPException(status_code=404, detail="Report card publication not found.")

        if db_rep.status not in [ReportCardStatus.UNDER_REVIEW, ReportCardStatus.APPROVED]:
            raise HTTPException(status_code=422, detail=f"Report card in status {db_rep.status.value} cannot be rejected.")

        db_rep.status = ReportCardStatus.DRAFT
        db_rep.updated_by = current_user.id
        now = datetime.now(timezone.utc)
        if not db_rep.settings or not isinstance(db_rep.settings, dict):
            db_rep.settings = {}
        db_rep.settings = dict(db_rep.settings)
        db_rep.settings["rejection_reason"] = obj_in.rejection_reason
        db_rep.settings["rejected_by"] = str(current_user.id)
        db_rep.settings["rejected_at"] = now.isoformat()

        self.report_repo.db.add(db_rep)
        await self.report_repo.db.commit()
        return await self.report_repo.get_by_id(id, school_id, tenant_id)

    async def unpublish_report_card(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, id: uuid.UUID, obj_in: ReportCardUnpublishRequest, current_user: User
    ) -> ReportCardPublication:
        db_rep = await self.report_repo.get_by_id(id, school_id, tenant_id)
        if not db_rep:
            raise HTTPException(status_code=404, detail="Report card publication not found.")

        if db_rep.status != ReportCardStatus.PUBLISHED:
            raise HTTPException(status_code=422, detail="Report card must be in PUBLISHED status to unpublish.")

        db_rep.status = ReportCardStatus.DRAFT
        db_rep.updated_by = current_user.id
        now = datetime.now(timezone.utc)
        if not db_rep.settings or not isinstance(db_rep.settings, dict):
            db_rep.settings = {}
        db_rep.settings = dict(db_rep.settings)
        db_rep.settings["unpublish_reason"] = obj_in.reason or "Reopened for correction"
        db_rep.settings["unpublished_by"] = str(current_user.id)
        db_rep.settings["unpublished_at"] = now.isoformat()

        self.report_repo.db.add(db_rep)
        await self.report_repo.db.commit()
        return await self.report_repo.get_by_id(id, school_id, tenant_id)

    async def publish_report_cards(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, class_id: uuid.UUID, section_id: uuid.UUID, current_user: User
    ) -> List[ReportCardPublication]:
        # Fetch report cards for class eligible to publish
        stmt = select(ReportCardPublication).join(ReportCardPublication.student).where(
            Student.class_id == class_id,
            Student.section_id == section_id,
            ReportCardPublication.status.in_([
                ReportCardStatus.APPROVED,
                ReportCardStatus.UNDER_REVIEW,
                ReportCardStatus.DRAFT
            ]),
            ReportCardPublication.school_id == school_id,
            ReportCardPublication.tenant_id == tenant_id,
            ReportCardPublication.deleted_at.is_(None)
        )
        res = await self.report_repo.db.execute(stmt)
        candidate_pubs = list(res.scalars().all())

        if not candidate_pubs:
            raise HTTPException(status_code=422, detail="No report cards found eligible to publish.")

        now = datetime.now(timezone.utc)
        pubs = []
        for p in candidate_pubs:
            exam_id_ctx = None
            if p.settings and p.settings.get("examination_id"):
                try:
                    exam_id_ctx = uuid.UUID(str(p.settings["examination_id"]))
                except Exception:
                    exam_id_ctx = None

            val = await self.validate_report_card_data(
                tenant_id=tenant_id,
                school_id=school_id,
                student_id=p.student_id,
                academic_year_id=p.academic_year_id,
                examination_id=exam_id_ctx,
                teacher_remarks=(p.settings or {}).get("teacher_remarks")
            )
            if not val["is_valid"]:
                continue

            if p.status != ReportCardStatus.APPROVED:
                p.approved_by = current_user.id
                p.approved_at = now

            if not p.settings or not isinstance(p.settings, dict):
                p.settings = {}
            else:
                p.settings = dict(p.settings)

            raw_snapshot = {
                "overall_percentage": val["overall_pct"],
                "overall_grade": val["overall_grade"],
                "promotion_status": val["prom_status"],
                "attendance_total": val["total_days"],
                "attendance_present": val["present_days"],
                "attendance_percentage": val["attendance_pct"],
                "class_rank": val["class_rank"],
                "section_rank": val["section_rank"],
                "teacher_remarks": val["teacher_remarks"],
                "calculation_method": val.get("calculation_method"),
                "examination_weightages": val.get("examination_weightages"),
                "consolidated_subject_marks": val.get("consolidated_subject_marks"),
                "subject_marks_rows": [
                    row.model_dump() if hasattr(row, "model_dump") else (row.dict() if hasattr(row, "dict") else dict(row))
                    for row in val.get("subject_marks_rows", [])
                ],
                "published_at": now.isoformat()
            }
            p.settings["snapshot"] = json.loads(json.dumps(raw_snapshot, default=str))
            p.settings = json.loads(json.dumps(p.settings, default=str))

            p.status = ReportCardStatus.PUBLISHED
            p.published_by = current_user.id
            p.published_at = now
            p.updated_by = current_user.id
            self.report_repo.db.add(p)
            pubs.append(p)

        if not pubs:
            raise HTTPException(status_code=422, detail="No complete report cards could be published. Please ensure marks and attendance are entered.")

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

        # 2. Fetch all reportable examinations for this academic year
        examinations = await self.get_reportable_examinations(
            tenant_id=tenant_id,
            school_id=school_id,
            student_id=student.id,
            academic_year_id=student.academic_year_id,
            class_id=student.class_id,
            section_id=student.section_id,
            as_of_date=datetime.now(timezone.utc).date()
        )

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
            schedules = list(res_sch.unique().scalars().all())
            
            if not schedules:
                continue

            subject_marks = []
            total_max_marks = 0
            total_obtained_marks = 0.0
            
            for sched in schedules:
                # Query entered mark
                stmt_m = select(Marks).where(
                    Marks.exam_schedule_id == sched.id,
                    Marks.student_id == student_id,
                    Marks.deleted_at.is_(None)
                )
                res_m = await self.report_repo.db.execute(stmt_m)
                mark = res_m.scalar_one_or_none()
                
                subj_name = None
                subj_code = None
                if sched.subject:
                    subj_name = sched.subject.subject_name
                    subj_code = sched.subject.subject_code
                if not subj_name:
                    from app.models.subject import Subject
                    res_sub = await self.report_repo.db.execute(
                        select(Subject).where(Subject.id == sched.subject_id, Subject.deleted_at.is_(None))
                    )
                    db_sub = res_sub.scalar_one_or_none()
                    if db_sub:
                        subj_name = db_sub.subject_name
                        subj_code = db_sub.subject_code
                if not subj_name:
                    subj_name = subj_code if subj_code else "Subject"

                obtained = float(mark.marks_obtained) if (mark and mark.marks_obtained is not None) else None
                max_m = sched.max_marks
                total_max_marks += max_m

                status = mark.result_status.value if (mark and hasattr(mark.result_status, "value")) else (str(mark.result_status) if (mark and mark.result_status) else ("PRESENT" if (mark and mark.marks_obtained is not None) else "ABSENT"))
                grade = "F"
                if (status in ["PRESENT", "EXEMPTED"] or (mark and mark.marks_obtained is not None)) and obtained is not None:
                    total_obtained_marks += obtained
                    paper_pct = (obtained / max_m) * 100 if max_m > 0 else 0.0
                    grade = get_grade_for_percentage(paper_pct)

                subject_marks.append(ExamSubjectMark(
                    subject_id=sched.subject_id,
                    subject_name=subj_name,
                    subject_code=subj_code,
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
        self,
        tenant_id: Union[uuid.UUID, ReportCardPublication],
        school_id: Optional[uuid.UUID] = None,
        student_id: Optional[uuid.UUID] = None,
        preview: Optional[ReportCardPreviewResponse] = None,
        history: Optional[StudentAcademicHistoryResponse] = None,
        db_rep: Optional[ReportCardPublication] = None
    ) -> bytes:
        if isinstance(tenant_id, ReportCardPublication):
            db_rep = tenant_id
            effective_tenant_id = db_rep.tenant_id
            effective_school_id = db_rep.school_id
            effective_student_id = db_rep.student_id
        else:
            effective_tenant_id = tenant_id
            effective_school_id = school_id
            effective_student_id = student_id

        if preview is None and db_rep is not None:
            r_type = db_rep.settings.get("report_card_type", "CONSOLIDATED") if db_rep.settings else "CONSOLIDATED"
            exam_id = None
            if db_rep.settings and db_rep.settings.get("examination_id"):
                try:
                    exam_id = uuid.UUID(str(db_rep.settings["examination_id"]))
                except Exception:
                    exam_id = None
            preview = await self.compile_live_data(
                tenant_id=effective_tenant_id,
                school_id=effective_school_id,
                student_id=effective_student_id,
                report_card_type=r_type,
                examination_id=exam_id
            )

        if history is None:
            history = await self.get_student_academic_history(effective_tenant_id, effective_school_id, effective_student_id)

        # Load student & school
        student = await self.student_repo.get_by_id(effective_student_id, effective_school_id, effective_tenant_id)
        school = await self.school_repo.get_by_id(effective_school_id, effective_tenant_id)
        
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
        logo_bytes = None

        candidate_sources = []
        if school and school.settings and isinstance(school.settings, dict):
            branding = school.settings.get("branding", {})
            if isinstance(branding, dict):
                if branding.get("logo_data"):
                    candidate_sources.append(branding["logo_data"])
                if branding.get("logo_base64"):
                    candidate_sources.append(branding["logo_base64"])
                if branding.get("logo_storage_key"):
                    candidate_sources.append(branding["logo_storage_key"])
                if branding.get("logo_url"):
                    candidate_sources.append(branding["logo_url"])

        if school and school.logo_url:
            candidate_sources.append(school.logo_url)

        try:
            from app.models.school_administration import SchoolProfile
            stmt_prof = select(SchoolProfile).where(
                SchoolProfile.school_id == effective_school_id,
                SchoolProfile.tenant_id == effective_tenant_id,
                SchoolProfile.deleted_at.is_(None)
            )
            prof_res = await self.report_repo.db.execute(stmt_prof)
            school_prof = prof_res.scalars().first()
            if school_prof:
                if getattr(school_prof, "school_photo_url", None):
                    candidate_sources.append(school_prof.school_photo_url)
                if getattr(school_prof, "logo_url", None):
                    candidate_sources.append(school_prof.logo_url)
        except Exception as e:
            logger.debug(f"Could not check SchoolProfile for branding: {e}")

        for src in candidate_sources:
            if not src or not isinstance(src, str):
                continue
            src = src.strip()
            if not src:
                continue

            try:
                # Case A: Base64 Data URI
                if src.startswith("data:image"):
                    import base64
                    _, b64_data = src.split(",", 1)
                    logo_bytes = base64.b64decode(b64_data)
                    if logo_bytes and len(logo_bytes) > 10:
                        break
                # Case B: Raw base64 string
                elif len(src) > 100 and not src.startswith("http") and not src.startswith("/") and not src.startswith("storage/"):
                    try:
                        import base64
                        raw_decoded = base64.b64decode(src)
                        if raw_decoded.startswith(b"\x89PNG") or raw_decoded.startswith(b"\xff\xd8") or raw_decoded.startswith(b"GIF"):
                            logo_bytes = raw_decoded
                            break
                    except Exception:
                        pass

                # Case C: HTTP / HTTPS URL
                if not logo_bytes and (src.startswith("http://") or src.startswith("https://")):
                    import httpx
                    async with httpx.AsyncClient(timeout=3.0) as client:
                        resp = await client.get(src)
                        if resp.status_code == 200 and len(resp.content) > 10:
                            logo_bytes = resp.content
                            break

                # Case D: Local file path
                if not logo_bytes and (os.path.isfile(src) or os.path.exists(src)):
                    with open(src, "rb") as f:
                        logo_bytes = f.read()
                        if len(logo_bytes) > 10:
                            break

                # Case E: Storage key (GCS / Local storage service)
                if not logo_bytes and hasattr(self, "storage_service") and self.storage_service:
                    try:
                        downloaded = await self.storage_service.download(src)
                        if downloaded and len(downloaded) > 10:
                            logo_bytes = downloaded
                            break
                    except Exception:
                        pass
            except Exception as e:
                logger.warning(f"Failed to load candidate school logo from {src[:50]}: {e}")

        if logo_bytes:
            try:
                from PIL import Image as PILImage
                im = PILImage.open(io.BytesIO(logo_bytes))
                orig_w, orig_h = im.size
                if orig_h > 0 and orig_w > 0:
                    aspect = orig_w / orig_h
                    max_w, max_h = 55.0, 50.0
                    if aspect >= 1:
                        w = min(max_w, max_h * aspect)
                        h = w / aspect
                    else:
                        h = min(max_h, max_w / aspect)
                        w = h * aspect
                    logo_flowable = Image(io.BytesIO(logo_bytes), width=w, height=h)
            except Exception as e:
                logger.warning(f"Error processing school logo dimensions for ReportLab PDF: {e}")
                logo_flowable = None
                    
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
                Paragraph("<b>Class Rank:</b>", body_style), Paragraph(preview.class_rank or "N/A", body_style),
                Paragraph("<b>Section Rank:</b>", body_style), Paragraph(preview.section_rank or "N/A", body_style)
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
                ('PADDING', (0,0), (-1,-1), 3),
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
                ('PADDING', (0,0), (-1,-1), 3),
                ('LINEBELOW', (0,0), (-1,-1), 0.25, colors.HexColor("#E2E8F0")),
            ]))
            student_card_table = detail_table

        student_info_card = Table([[student_card_table]], colWidths=[515])
        student_info_card.setStyle(TableStyle([
            ('BOX', (0,0), (-1,-1), 1, navy_primary),
            ('BACKGROUND', (0,0), (-1,-1), light_grey),
            ('PADDING', (0,0), (-1,-1), 6),
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
        
        # 4. Academic Performance Presentation: Dual-Section vs Single Exam
        exams_in_order = history.examinations
        
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

        is_consolidated = (preview.report_card_type == "CONSOLIDATED" or (preview.report_card_type != "SINGLE_EXAM" and len(exams_in_order) > 1))

        # -------------------------------------------------------------
        # Reusable Section 1 Elements: Grading Scale & Attendance Table
        # -------------------------------------------------------------
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

        # Reusable AI Insights Element
        ai_card_table = None
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
                    
            risk_color = colors.HexColor("#10B981")
            if ai_risk.upper() == "HIGH":
                risk_color = colors.HexColor("#EF4444")
            elif ai_risk.upper() == "MEDIUM":
                risk_color = colors.HexColor("#F59E0B")
                
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

        # Reusable Remarks & Signatures Footer Group
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
            footer_group.append(Spacer(1, 10))
            
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
        footer_group.append(Spacer(1, 10))
        
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

        # -------------------------------------------------------------
        # BRANCH A: CONSOLIDATED DUAL-SECTION PDF LAYOUT
        # -------------------------------------------------------------
        if is_consolidated:
            # SECTION 1: Academic-Year Summary (Page 1)
            story.append(Paragraph("GRADING SCALE & ATTENDANCE SUMMARY", section_title_style))
            story.append(side_by_side_table)
            story.append(Spacer(1, 10))

            if ai_card_table:
                story.append(Paragraph("AI ACADEMIC INSIGHTS", section_title_style))
                story.append(ai_card_table)
                story.append(Spacer(1, 10))

            # PAGE BREAK TO SECTION 2 (Page 2)
            story.append(PageBreak())

            # SECTION 2: Consolidated Multi-Exam Performance Matrix (Page 2)
            story.append(Paragraph("SECTION 2: CONSOLIDATED MULTI-EXAM PERFORMANCE MATRIX", section_title_style))
            
            subjects_set = {}
            for exam in exams_in_order:
                for sub_mark in exam.subject_marks:
                    subjects_set[sub_mark.subject_name] = True
            subjects_list = sorted(list(subjects_set.keys()))
            
            weightages_map = preview.examination_weightages or {}
            
            table_headers = [Paragraph("<b>Subject</b>", table_header_style)]
            for exam in exams_in_order:
                w_val = weightages_map.get(exam.examination_name)
                w_str = f"<br/><font size=6 color='#E2E8F0'>({w_val:g}%)</font>" if (w_val and preview.calculation_method == "WEIGHTED_POLICY") else ""
                table_headers.append(Paragraph(f"<b>{exam.examination_name}</b>{w_str}", table_header_style))
            table_headers.append(Paragraph("<b>Final Score</b>", table_header_style))
            table_headers.append(Paragraph("<b>Grade</b>", table_header_style))
            
            performance_rows = [table_headers]

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
                        
                # Match preview consolidated subject row if available
                matching_cons = None
                if preview.consolidated_subject_marks:
                    matching_cons = next((c for c in preview.consolidated_subject_marks if c.get("subject_name") == sub_name), None)

                if matching_cons and matching_cons.get("consolidated_percentage") is not None:
                    c_pct = matching_cons["consolidated_percentage"]
                    c_gr = matching_cons.get("grade", get_grade_for_percentage(c_pct))
                    row.append(Paragraph(f"{c_pct}%", table_cell_style))
                    row.append(Paragraph(c_gr, table_cell_style))
                elif sub_total_max > 0:
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
            
            # Compute exact column widths dynamically
            num_exams = len(exams_in_order)
            sub_width = 115
            rem_width = 515 - sub_width
            col_width_each = rem_width / max(1, (num_exams + 2))
            
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
            story.append(perf_table)
            story.append(Spacer(1, 6))

            # Footnote explaining calculation policy
            footnote_style = ParagraphStyle(
                'Footnote',
                parent=styles['Normal'],
                fontName='Helvetica-Oblique',
                fontSize=7.5,
                leading=10,
                textColor=colors.HexColor("#4A5568")
            )
            if preview.calculation_method == "WEIGHTED_POLICY" and weightages_map:
                w_items = [f"{k}: {v:g}%" for k, v in weightages_map.items() if v > 0]
                footnote_text = f"<b>* Calculation Policy:</b> <b>WEIGHTED_POLICY</b>. Final annual scores were consolidated using authoritative institutional assessment weightages ({', '.join(w_items)})."
            else:
                footnote_text = "<b>* Calculation Policy:</b> <b>PROPORTIONAL_MAX_MARKS</b>. Final annual scores were aggregated proportionally across all configured examinations (Total Marks Obtained / Total Maximum Marks)."
            
            story.append(Paragraph(footnote_text, footnote_style))
            story.append(Spacer(1, 14))

            # Performance Trend Progression Flowable
            if num_exams > 1:
                trend_table_data = []
                trend_widths = []
                recent_exams = exams_in_order[-5:]
                recent_num = len(recent_exams)
                t_card_w = max(50.0, min(85.0, (515.0 - (recent_num - 1) * 15.0) / recent_num))
                arrow_w = 15.0
                for i, exam in enumerate(recent_exams):
                    trend_table_data.append(
                        Paragraph(
                            f"<b>{exam.examination_name}</b><br/><font size=11 color='{navy_primary.hexval()}'><b>{exam.percentage}%</b></font>",
                            ParagraphStyle('TrendVal', parent=body_style, alignment=TA_CENTER)
                        )
                    )
                    trend_widths.append(t_card_w)
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
                story.append(Paragraph("ACADEMIC PROGRESSION TIMELINE", section_title_style))
                story.append(trend_table)

            story.append(Spacer(1, 10))
            story.append(KeepTogether(footer_group))

        # -------------------------------------------------------------
        # BRANCH B: SINGLE-EXAMINATION SINGLE-PAGE LAYOUT
        # -------------------------------------------------------------
        else:
            exam_title = exams_in_order[0].examination_name if exams_in_order else "EXAMINATION"
            table_headers = [
                Paragraph("<b>Subject</b>", table_header_style),
                Paragraph("<b>Max Marks</b>", table_header_style),
                Paragraph("<b>Marks Obtained</b>", table_header_style),
                Paragraph("<b>Percentage</b>", table_header_style),
                Paragraph("<b>Grade</b>", table_header_style),
                Paragraph("<b>Status</b>", table_header_style)
            ]
            performance_rows = [table_headers]
            total_max = 0
            total_obt = 0.0

            for sm in preview.subject_marks:
                total_max += sm.maximum_marks
                if sm.marks_obtained is not None:
                    total_obt += sm.marks_obtained
                obt_str = str(sm.marks_obtained) if sm.marks_obtained is not None else "-"
                pct = round((sm.marks_obtained / sm.maximum_marks) * 100, 1) if (sm.marks_obtained is not None and sm.maximum_marks > 0) else None
                pct_str = f"{pct}%" if pct is not None else "-"
                row = [
                    Paragraph(sm.subject_name, table_cell_left),
                    Paragraph(str(sm.maximum_marks), table_cell_style),
                    Paragraph(obt_str, table_cell_style),
                    Paragraph(pct_str, table_cell_style),
                    Paragraph(sm.grade, table_cell_bold),
                    Paragraph(sm.result_status, table_cell_style)
                ]
                performance_rows.append(row)

            total_row = [
                Paragraph("<b>TOTAL</b>", table_cell_left),
                Paragraph(f"<b>{total_max}</b>", table_cell_bold),
                Paragraph(f"<b>{total_obt}</b>", table_cell_bold),
                Paragraph(f"<b>{preview.overall_percentage}%</b>", table_cell_bold),
                Paragraph(f"<b>{preview.overall_grade}</b>", table_cell_bold),
                Paragraph(f"<b>{promotion_status_str}</b>", table_cell_bold)
            ]
            performance_rows.append(total_row)

            perf_table = Table(performance_rows, colWidths=[155, 70, 75, 75, 70, 70])
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
            story.append(Paragraph(f"ACADEMIC PERFORMANCE — {exam_title.upper()}", section_title_style))
            story.append(perf_table)
            story.append(Spacer(1, 10))

            secondary_group = [
                Paragraph("GRADING SCALE & ATTENDANCE SUMMARY", section_title_style),
                side_by_side_table,
                Spacer(1, 10)
            ]
            story.append(KeepTogether(secondary_group))

            if ai_card_table:
                story.append(Paragraph("AI ACADEMIC INSIGHTS", section_title_style))
                story.append(ai_card_table)
                story.append(Spacer(1, 10))

            story.append(KeepTogether(footer_group))
        
        # Build Document
        numbered_canvas_class = make_numbered_canvas_class(school.name if school else "", ay_name, report_card_title)
        doc.build(story, canvasmaker=numbered_canvas_class)
        
        pdf_bytes = buffer.getvalue()
        buffer.close()
        return pdf_bytes

