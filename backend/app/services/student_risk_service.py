import uuid
from typing import Dict, Any, List, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, or_, case, Integer
from sqlalchemy.orm import selectinload

from app.models.student import Student
from app.models.attendance import Attendance
from app.models.marks import Marks
from app.models.subject import Subject
from app.models.examination import Examination
from app.models.report_card import ReportCardPublication, ReportCardStatus


async def evaluate_active_risk_students(
    db: AsyncSession,
    tenant_id: uuid.UUID,
    school_id: Optional[uuid.UUID],
    academic_year_id: Optional[uuid.UUID],
    class_id: Optional[uuid.UUID] = None,
    section_id: Optional[uuid.UUID] = None,
    student_ids: Optional[List[uuid.UUID]] = None
) -> Dict[str, Any]:
    """
    Authoritative shared risk evaluation contract.
    Ensures 1:1 consistency between:
    1. Admin Dashboard KPI 'Students Need Attention'
    2. Reports AI Predictive Intelligence
    3. Student Directory drill-down: GET /api/v1/students?attention=needs_attention

    Attention Criteria:
    - Irregular attendance (<75%)
    - Consecutive academic drops detected (>=2 consecutive assessment declines)
    - Low academic average (<40%) or multiple subject failures (>=2)
    - Declining report card AI metrics

    Reasons generated:
    - Attendance below 75%
    - Academic trend: {n} consecutive assessment declines
    - Attendance below 75% + Academic performance decline
    """
    # 1. Base student query for active, enrolled students
    stmt_stds = select(Student).where(
        Student.tenant_id == tenant_id,
        Student.deleted_at.is_(None),
        Student.status == "ACTIVE"
    ).options(
        selectinload(Student.class_obj),
        selectinload(Student.section)
    )
    if school_id:
        stmt_stds = stmt_stds.where(Student.school_id == school_id)
    if academic_year_id:
        stmt_stds = stmt_stds.where(Student.academic_year_id == academic_year_id)
    if class_id:
        stmt_stds = stmt_stds.where(Student.class_id == class_id)
    if section_id:
        stmt_stds = stmt_stds.where(Student.section_id == section_id)
    if student_ids:
        stmt_stds = stmt_stds.where(Student.id.in_(student_ids))

    res_stds = await db.execute(stmt_stds)
    active_students = res_stds.scalars().all()
    if not active_students:
        return {
            "high_risk_students": [],
            "medium_risk_students": [],
            "low_risk_students": [],
            "improving_students": [],
            "declining_students": [],
            "attendance_academic_risk_count": 0,
            "high_performers_count": 0
        }

    active_student_ids = [s.id for s in active_students]

    # 2. Check published report cards with AI metrics for these students in this academic year
    stmt_pub = select(ReportCardPublication).where(
        ReportCardPublication.tenant_id == tenant_id,
        ReportCardPublication.status == ReportCardStatus.PUBLISHED,
        ReportCardPublication.deleted_at.is_(None),
        ReportCardPublication.student_id.in_(active_student_ids)
    ).order_by(ReportCardPublication.created_at.desc())
    if school_id:
        stmt_pub = stmt_pub.where(ReportCardPublication.school_id == school_id)
    if academic_year_id:
        stmt_pub = stmt_pub.where(ReportCardPublication.academic_year_id == academic_year_id)

    res_pub = await db.execute(stmt_pub)
    publications = res_pub.scalars().all()

    # Map latest published report card per student
    pub_by_student: Dict[uuid.UUID, ReportCardPublication] = {}
    for p in publications:
        if p.student_id not in pub_by_student:
            pub_by_student[p.student_id] = p

    high_risk_list = []
    med_risk_list = []
    low_risk_list = []
    improving_list = []
    declining_list = []

    for student in active_students:
        pub = pub_by_student.get(student.id)
        ai_data = pub.ai_metrics if (pub and pub.ai_metrics) else {}

        # 3. Attendance calculation
        stmt_att = select(
            func.count(Attendance.id).label("total"),
            func.sum(func.cast(Attendance.attendance_status.in_(["PRESENT", "LATE"]), Integer)).label("present")
        ).where(
            Attendance.student_id == student.id,
            Attendance.tenant_id == tenant_id,
            Attendance.is_active == True,
            Attendance.deleted_at.is_(None)
        )
        if school_id:
            stmt_att = stmt_att.where(Attendance.school_id == school_id)
        if academic_year_id:
            stmt_att = stmt_att.where(Attendance.academic_year_id == academic_year_id)

        res_att = await db.execute(stmt_att)
        att_row = res_att.first()
        total_days = att_row.total if att_row else 0
        present_days = att_row.present or 0 if att_row else 0
        has_attendance = total_days > 0
        att_pct = (present_days / total_days * 100.0) if has_attendance else 100.0
        att_qualifies = has_attendance and (att_pct < 75.0)

        # 4. Overall marks calculation
        stmt_marks = select(
            func.avg(Marks.marks_obtained / Marks.maximum_marks * 100.0).label("avg_pct"),
            func.sum(case((Marks.marks_obtained < (Marks.maximum_marks * 0.35), 1), else_=0)).label("fail_count"),
            func.count(Marks.id).label("total_marks_count")
        ).where(
            Marks.student_id == student.id,
            Marks.tenant_id == tenant_id,
            Marks.status == "PUBLISHED",
            Marks.deleted_at.is_(None)
        )
        if school_id:
            stmt_marks = stmt_marks.where(Marks.school_id == school_id)
        if academic_year_id:
            stmt_marks = stmt_marks.where(Marks.academic_year_id == academic_year_id)

        res_marks = await db.execute(stmt_marks)
        marks_row = res_marks.first()
        std_pct = float(marks_row.avg_pct or 0.0) if marks_row else 0.0
        fail_cnt = int(marks_row.fail_count or 0) if marks_row else 0
        has_marks = (marks_row.total_marks_count or 0) > 0 if marks_row else False

        # 5. Chronological Examination Marks (to evaluate consecutive drops)
        stmt_exam_marks = select(
            Examination.id.label("exam_id"),
            Examination.exam_name,
            Examination.start_date,
            func.avg(Marks.marks_obtained / Marks.maximum_marks * 100.0).label("exam_avg")
        ).join(Marks, Marks.examination_id == Examination.id).where(
            Marks.student_id == student.id,
            Marks.tenant_id == tenant_id,
            Marks.status == "PUBLISHED",
            Marks.deleted_at.is_(None)
        )
        if school_id:
            stmt_exam_marks = stmt_exam_marks.where(Marks.school_id == school_id)
        if academic_year_id:
            stmt_exam_marks = stmt_exam_marks.where(Marks.academic_year_id == academic_year_id)
        stmt_exam_marks = stmt_exam_marks.group_by(
            Examination.id, Examination.exam_name, Examination.start_date
        ).order_by(Examination.start_date.asc())

        res_exam_marks = await db.execute(stmt_exam_marks)
        chronological_exams = res_exam_marks.all()

        exam_averages = [float(row.exam_avg or 0.0) for row in chronological_exams]
        consecutive_drops = 0
        if len(exam_averages) >= 2:
            # Count consecutive assessment declines moving backward from latest
            for i in range(len(exam_averages) - 1, 0, -1):
                if exam_averages[i] < exam_averages[i - 1]:
                    consecutive_drops += 1
                else:
                    break

        consecutive_decline_qualifies = (consecutive_drops >= 2)

        # 6. Evaluate Academic Risk
        ai_risk_high = False
        ai_trend_declining = False
        if ai_data:
            if str(ai_data.get("risk_level", "")).upper() == "HIGH":
                ai_risk_high = True
            if str(ai_data.get("overall_trend", "")).upper() == "DECLINING":
                ai_trend_declining = True

        acad_qualifies = (
            consecutive_decline_qualifies
            or (has_marks and (std_pct < 40.0 or fail_cnt >= 2))
            or ai_risk_high
            or ai_trend_declining
        )

        # 7. Formulate Attention Reason (Single Source of Truth)
        if att_qualifies and acad_qualifies:
            attention_reason = "Attendance below 75% + Academic performance decline"
        elif att_qualifies:
            attention_reason = "Attendance below 75%"
        elif acad_qualifies:
            if consecutive_drops >= 2:
                attention_reason = f"Academic trend: {consecutive_drops} consecutive assessment declines"
            else:
                attention_reason = "Academic performance decline"
        else:
            attention_reason = None

        # 8. Classify Risk Level & Trend
        if att_qualifies or acad_qualifies:
            risk_lvl = "HIGH"
            trend = "DECLINING" if (consecutive_drops >= 2 or std_pct < 40.0 or att_qualifies) else "STABLE"
            narrative = (
                f"Student flagged for urgent attention: {attention_reason}."
                if attention_reason
                else "Student shows low performance indicators requiring intervention."
            )
            recommendation = "Assign dedicated tutoring and schedule guardian conference."
        elif (has_marks and (std_pct < 50.0 or fail_cnt == 1)) or (has_attendance and att_pct < 85.0):
            risk_lvl = "MEDIUM"
            trend = "STABLE"
            narrative = f"Student performance ({std_pct:.1f}% avg, {att_pct:.1f}% att) requires close monitoring."
            recommendation = "Monitor performance in subsequent assessments."
        else:
            risk_lvl = "LOW"
            trend = "IMPROVING" if (has_marks and std_pct >= 75.0 and att_pct >= 85.0) else "STABLE"
            narrative = "Student demonstrates consistent passing grades and satisfactory attendance."
            recommendation = "Maintain regular academic engagement."

        # Override with publication AI metrics if provided explicitly
        if ai_data and "risk_level" in ai_data:
            pub_risk = str(ai_data.get("risk_level", "")).upper()
            if pub_risk in ["HIGH", "MEDIUM", "LOW"]:
                risk_lvl = pub_risk
            if "overall_trend" in ai_data:
                trend = str(ai_data.get("overall_trend", trend)).upper()
            if "ai_narrative" in ai_data:
                narrative = ai_data["ai_narrative"]
            if "recommended_actions" in ai_data:
                recommendation = ai_data["recommended_actions"]

        # Weak subjects
        stmt_weak = select(Subject.subject_name).join(Marks, Marks.subject_id == Subject.id).where(
            Marks.student_id == student.id,
            Marks.tenant_id == tenant_id,
            Marks.status == "PUBLISHED",
            Marks.deleted_at.is_(None)
        )
        if school_id:
            stmt_weak = stmt_weak.where(Marks.school_id == school_id)
        if academic_year_id:
            stmt_weak = stmt_weak.where(Marks.academic_year_id == academic_year_id)
        stmt_weak = stmt_weak.group_by(Subject.subject_name).having(
            func.avg(Marks.marks_obtained / Marks.maximum_marks * 100.0) < 50.0
        )
        res_weak = await db.execute(stmt_weak)
        weak_subjects = [row[0] for row in res_weak.all()]

        att_trend = "STABLE"
        if has_attendance:
            if att_pct >= 90.0:
                att_trend = "EXCELLENT"
            elif att_pct < 75.0:
                att_trend = "DECLINING"

        item = {
            "student_id": str(student.id),
            "student_name": f"{student.first_name} {student.last_name}".strip(),
            "admission_number": student.admission_number,
            "roll_number": student.roll_number,
            "class_id": str(student.class_id) if student.class_id else None,
            "section_id": str(student.section_id) if student.section_id else None,
            "class_name": student.class_obj.name if student.class_obj else "N/A",
            "section_name": student.section.name if student.section else "N/A",
            "current_percentage": round(std_pct, 2) if has_marks else None,
            "previous_percentage": (
                round(exam_averages[-2], 2)
                if len(exam_averages) >= 2
                else round(std_pct * 0.95, 2)
                if has_marks
                else None
            ),
            "attendance_percentage": round(att_pct, 2) if has_attendance else None,
            "attendance_rate": round(att_pct, 2) if has_attendance else None,
            "trend": trend,
            "risk_level": risk_lvl,
            "ai_narrative": narrative,
            "recommendation": recommendation,
            "attendance_trend": att_trend,
            "weak_subjects": weak_subjects,
            "attention_reason": attention_reason,
            "needs_attention": (risk_lvl == "HIGH"),
            "consecutive_drops": consecutive_drops,
        }

        if risk_lvl == "HIGH":
            high_risk_list.append(item)
        elif risk_lvl == "MEDIUM":
            med_risk_list.append(item)
        else:
            low_risk_list.append(item)

        if trend == "IMPROVING":
            improving_list.append(item)
        elif trend == "DECLINING":
            declining_list.append(item)

    return {
        "high_risk_students": high_risk_list,
        "medium_risk_students": med_risk_list,
        "low_risk_students": low_risk_list,
        "improving_students": improving_list,
        "declining_students": declining_list,
        "attendance_academic_risk_count": len(high_risk_list),
        "high_performers_count": len(improving_list)
    }
