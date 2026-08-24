import uuid
from typing import Optional, List, Dict, Any
from datetime import date
from decimal import Decimal
from fastapi import APIRouter, Depends, Query, HTTPException, status
from sqlalchemy import select, func, and_, Integer
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.db.session import get_db
from app.api.dependencies.auth import require_permission, get_current_user
from app.api.dependencies.common import get_tenant_id, get_school_id, get_optional_school_id
from app.models.user import User
from app.models.student import Student
from app.models.teacher import Teacher
from app.models.class_entity import Class
from app.models.section import Section
from app.models.marks import Marks
from app.models.attendance import Attendance
from app.models.fee import StudentFeeAssignment, FeeStructure, FeeAssignmentStatus, FeeType
from app.models.report_card import ReportCardPublication, ReportCardStatus
from app.models.examination import Examination
from app.models.subject import Subject
from app.models.school import School
from app.models.teacher_subject_assignment import TeacherSubjectAssignment
from app.schemas.response import APIResponse

router = APIRouter()

# Helper for grade policy fallback
DEFAULT_GRADE_POLICY = [
    {"grade": "A+", "min_percentage": 90.0, "max_percentage": 100.0},
    {"grade": "A", "min_percentage": 80.0, "max_percentage": 89.99},
    {"grade": "B", "min_percentage": 70.0, "max_percentage": 79.99},
    {"grade": "C", "min_percentage": 60.0, "max_percentage": 69.99},
    {"grade": "D", "min_percentage": 50.0, "max_percentage": 59.99},
    {"grade": "E", "min_percentage": 35.0, "max_percentage": 49.99},
    {"grade": "F", "min_percentage": 0.0, "max_percentage": 34.99}
]

def calculate_grade(percentage: float, grade_policy: Optional[List[Dict[str, Any]]] = None) -> str:
    policy = grade_policy or DEFAULT_GRADE_POLICY
    for g in policy:
        if g["min_percentage"] <= percentage <= g["max_percentage"]:
            return g["grade"]
    return "F"

@router.get(
    "/dashboard",
    response_model=APIResponse[Dict[str, Any]],
    status_code=status.HTTP_200_OK,
    summary="Get Reports Dashboard Overview Metrics"
)
async def get_dashboard_reports(
    current_user: User = Depends(require_permission("reports.read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    school_id: uuid.UUID = Depends(get_school_id),
    academic_year_id: Optional[uuid.UUID] = Query(None),
    class_id: Optional[uuid.UUID] = Query(None),
    section_id: Optional[uuid.UUID] = Query(None),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[Dict[str, Any]]:
    # 1. Total Students
    stmt_std = select(func.count(Student.id)).where(
        Student.tenant_id == tenant_id,
        Student.school_id == school_id,
        Student.is_active == True
    )
    if class_id:
        stmt_std = stmt_std.where(Student.class_id == class_id)
    if section_id:
        stmt_std = stmt_std.where(Student.section_id == section_id)
    total_students = (await db.execute(stmt_std)).scalar() or 0

    # 2. Active Teachers
    stmt_tch = select(func.count(Teacher.id)).where(
        Teacher.tenant_id == tenant_id,
        Teacher.school_id == school_id,
        Teacher.is_active == True
    )
    active_teachers = (await db.execute(stmt_tch)).scalar() or 0

    # 3. Total Classes
    stmt_cls = select(func.count(Class.id)).where(
        Class.tenant_id == tenant_id,
        Class.school_id == school_id,
        Class.is_active == True
    )
    total_classes = (await db.execute(stmt_cls)).scalar() or 0

    # 4. Total Sections
    stmt_sec = select(func.count(Section.id)).where(
        Section.tenant_id == tenant_id,
        Section.school_id == school_id,
        Section.is_active == True
    )
    if class_id:
        stmt_sec = stmt_sec.where(Section.class_id == class_id)
    total_sections = (await db.execute(stmt_sec)).scalar() or 0

    # 5. Average Academic Performance
    # Query published marks average for this tenant/school
    stmt_m = select(func.avg(Marks.marks_obtained / Marks.maximum_marks * 100.0)).where(
        Marks.tenant_id == tenant_id,
        Marks.school_id == school_id,
        Marks.status == "PUBLISHED"
    )
    if academic_year_id:
        stmt_m = stmt_m.where(Marks.academic_year_id == academic_year_id)
    if class_id:
        stmt_m = stmt_m.where(Marks.class_id == class_id)
    if section_id:
        stmt_m = stmt_m.where(Marks.section_id == section_id)
    avg_performance = (await db.execute(stmt_m)).scalar() or 0.0

    # 6. Average Attendance
    stmt_all = select(func.count(Attendance.id)).where(
        Attendance.tenant_id == tenant_id,
        Attendance.school_id == school_id,
        Attendance.is_active == True
    )
    stmt_pres = select(func.count(Attendance.id)).where(
        Attendance.tenant_id == tenant_id,
        Attendance.school_id == school_id,
        Attendance.is_active == True,
        Attendance.attendance_status.in_(["PRESENT", "LATE"])
    )
    if academic_year_id:
        stmt_all = stmt_all.where(Attendance.academic_year_id == academic_year_id)
        stmt_pres = stmt_pres.where(Attendance.academic_year_id == academic_year_id)
    if class_id:
        stmt_all = stmt_all.where(Attendance.class_id == class_id)
        stmt_pres = stmt_pres.where(Attendance.class_id == class_id)
    if section_id:
        stmt_all = stmt_all.where(Attendance.section_id == section_id)
        stmt_pres = stmt_pres.where(Attendance.section_id == section_id)

    all_att = (await db.execute(stmt_all)).scalar() or 0
    pres_att = (await db.execute(stmt_pres)).scalar() or 0
    avg_attendance = (pres_att / all_att * 100.0) if all_att > 0 else 100.0

    # 7. Fee Collection Percentage
    stmt_fees = select(
        func.sum(StudentFeeAssignment.assigned_amount),
        func.sum(StudentFeeAssignment.paid_amount)
    ).join(
        FeeStructure, FeeStructure.id == StudentFeeAssignment.fee_structure_id
    ).where(
        StudentFeeAssignment.tenant_id == tenant_id,
        FeeStructure.school_id == school_id,
        StudentFeeAssignment.deleted_at.is_(None)
    )
    if class_id or section_id:
        stmt_fees = stmt_fees.join(Student, Student.id == StudentFeeAssignment.student_id)
        if class_id:
            stmt_fees = stmt_fees.where(Student.class_id == class_id)
        if section_id:
            stmt_fees = stmt_fees.where(Student.section_id == section_id)

    res_fees = await db.execute(stmt_fees)
    assigned_sum, paid_sum = res_fees.first() or (Decimal("0.00"), Decimal("0.00"))
    assigned_sum = float(assigned_sum or 0.0)
    paid_sum = float(paid_sum or 0.0)
    fee_collection_percentage = (paid_sum / assigned_sum * 100.0) if assigned_sum > 0 else 100.0

    # 8. Students Requiring Attention
    # Query report cards with risk_level == "HIGH"
    stmt_risk = select(func.count(ReportCardPublication.id)).where(
        ReportCardPublication.tenant_id == tenant_id,
        ReportCardPublication.school_id == school_id,
        ReportCardPublication.status == ReportCardStatus.PUBLISHED
    )
    if academic_year_id:
        stmt_risk = stmt_risk.where(ReportCardPublication.academic_year_id == academic_year_id)
    if class_id or section_id:
        stmt_risk = stmt_risk.join(Student, Student.id == ReportCardPublication.student_id)
        if class_id:
            stmt_risk = stmt_risk.where(Student.class_id == class_id)
        if section_id:
            stmt_risk = stmt_risk.where(Student.section_id == section_id)

    risk_cond = and_(
        ReportCardPublication.ai_metrics.is_not(None),
        ReportCardPublication.ai_metrics['risk_level'].as_string() == 'HIGH'
    )
    stmt_high_risk = stmt_risk.where(risk_cond)
    students_requiring_attention = (await db.execute(stmt_high_risk)).scalar() or 0

    if students_requiring_attention == 0:
        # Fallback to counting students with average percentage < 50%
        subq = select(
            Marks.student_id
        ).where(
            Marks.tenant_id == tenant_id,
            Marks.school_id == school_id,
            Marks.status == "PUBLISHED"
        )
        if academic_year_id:
            subq = subq.where(Marks.academic_year_id == academic_year_id)
        if class_id:
            subq = subq.where(Marks.class_id == class_id)
        if section_id:
            subq = subq.where(Marks.section_id == section_id)
        subq = subq.group_by(Marks.student_id).having(func.avg(Marks.marks_obtained / Marks.maximum_marks * 100.0) < 50.0)
        
        stmt_count = select(func.count()).select_from(subq.subquery())
        students_requiring_attention = (await db.execute(stmt_count)).scalar() or 0

    dashboard_data = {
        "total_students": total_students,
        "active_teachers": active_teachers,
        "total_classes": total_classes,
        "total_sections": total_sections,
        "average_academic_performance": round(float(avg_performance or 0.0), 2),
        "average_attendance": round(avg_attendance, 2),
        "fee_collection_percentage": round(fee_collection_percentage, 2),
        "students_requiring_attention": students_requiring_attention
    }

    return APIResponse(
        success=True,
        message="Dashboard report metrics compiled successfully.",
        data=dashboard_data
    )

@router.get(
    "/academic",
    response_model=APIResponse[Dict[str, Any]],
    status_code=status.HTTP_200_OK,
    summary="Get Scoped Academic Analytics Report"
)
async def get_academic_reports(
    current_user: User = Depends(require_permission("reports.academic.read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    school_id: uuid.UUID = Depends(get_school_id),
    academic_year_id: Optional[uuid.UUID] = Query(None),
    examination_id: Optional[uuid.UUID] = Query(None),
    class_id: Optional[uuid.UUID] = Query(None),
    section_id: Optional[uuid.UUID] = Query(None),
    subject_id: Optional[uuid.UUID] = Query(None),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[Dict[str, Any]]:
    # Build query on Marks table
    stmt = select(Marks).where(
        Marks.tenant_id == tenant_id,
        Marks.school_id == school_id,
        Marks.status == "PUBLISHED"
    )
    if academic_year_id:
        stmt = stmt.where(Marks.academic_year_id == academic_year_id)
    if examination_id:
        stmt = stmt.where(Marks.examination_id == examination_id)
    if class_id:
        stmt = stmt.where(Marks.class_id == class_id)
    if section_id:
        stmt = stmt.where(Marks.section_id == section_id)
    if subject_id:
        stmt = stmt.where(Marks.subject_id == subject_id)

    res = await db.execute(stmt)
    marks_list = res.scalars().all()

    if not marks_list:
        return APIResponse(
            success=True,
            message="No academic records match specified parameters.",
            data={
                "average_marks": 0.0,
                "average_percentage": 0.0,
                "highest_marks": 0.0,
                "lowest_marks": 0.0,
                "pass_percentage": 0.0,
                "grade_distribution": {},
                "student_count": 0,
                "top_performers": [],
                "students_needing_intervention": [],
                "subject_performance": [],
                "student_performance": []
            }
        )

    tot_marks = 0.0
    tot_max = 0.0
    highest = 0.0
    lowest = float('inf')
    passed_count = 0
    grade_counts = {}
    student_totals = {}

    for mark in marks_list:
        obt = float(mark.marks_obtained or 0.0)
        mx = float(mark.maximum_marks or 100.0)
        tot_marks += obt
        tot_max += mx

        # Track percentage
        pct = (obt / mx * 100.0) if mx > 0 else 0.0
        if pct > highest:
            highest = pct
        if pct < lowest:
            lowest = pct

        # Pass check (default threshold 35% of max marks)
        if obt >= (mx * 0.35):
            passed_count += 1

        # Track student level aggregation
        std_id = mark.student_id
        if std_id not in student_totals:
            student_totals[std_id] = {"obtained": 0.0, "max": 0.0, "highest_score": 0.0}
        student_totals[std_id]["obtained"] += obt
        student_totals[std_id]["max"] += mx
        if pct > student_totals[std_id]["highest_score"]:
            student_totals[std_id]["highest_score"] = pct

    # Compute overall statistics
    average_marks = tot_marks / len(marks_list)
    average_percentage = (tot_marks / tot_max * 100.0) if tot_max > 0 else 0.0
    pass_percentage = (passed_count / len(marks_list) * 100.0)
    lowest_marks = lowest if lowest != float('inf') else 0.0

    # Grade distribution based on student aggregate averages
    for std_id, stats in student_totals.items():
        std_pct = (stats["obtained"] / stats["max"] * 100.0) if stats["max"] > 0 else 0.0
        g = calculate_grade(std_pct)
        grade_counts[g] = grade_counts.get(g, 0) + 1

    # Fetch top performers (top 5 by overall percentage)
    top_perf = []
    need_int = []

    stmt_stds = select(Student).where(
        Student.tenant_id == tenant_id,
        Student.school_id == school_id,
        Student.id.in_(list(student_totals.keys()))
    ).options(selectinload(Student.class_obj), selectinload(Student.section))
    res_stds = await db.execute(stmt_stds)
    db_students = {s.id: s for s in res_stds.scalars().all()}

    for std_id, stats in student_totals.items():
        student_obj = db_students.get(std_id)
        if not student_obj:
            continue
        std_pct = (stats["obtained"] / stats["max"] * 100.0) if stats["max"] > 0 else 0.0
        perf_item = {
            "student_id": str(std_id),
            "student_name": f"{student_obj.first_name} {student_obj.last_name}",
            "class_name": student_obj.class_obj.name if student_obj.class_obj else "N/A",
            "section_name": student_obj.section.name if student_obj.section else "N/A",
            "percentage": round(std_pct, 2)
        }
        if std_pct >= 85.0:
            top_perf.append(perf_item)
        if std_pct < 50.0:
            need_int.append(perf_item)

    # Sort arrays
    top_performers = sorted(top_perf, key=lambda x: x["percentage"], reverse=True)[:5]
    students_needing_intervention = sorted(need_int, key=lambda x: x["percentage"])[:10]

    # Subject-wise aggregation
    subject_totals = {}
    for mark in marks_list:
        sub_id = mark.subject_id
        obt = float(mark.marks_obtained or 0.0)
        mx = float(mark.maximum_marks or 100.0)
        pct = (obt / mx * 100.0) if mx > 0 else 0.0
        
        if sub_id not in subject_totals:
            subject_totals[sub_id] = {"obtained": 0.0, "max": 0.0, "percentages": []}
        subject_totals[sub_id]["obtained"] += obt
        subject_totals[sub_id]["max"] += mx
        subject_totals[sub_id]["percentages"].append(pct)
        
    subject_perf = []
    if subject_totals:
        stmt_subs = select(Subject).where(
            Subject.tenant_id == tenant_id,
            Subject.school_id == school_id,
            Subject.id.in_(list(subject_totals.keys()))
        )
        res_subs = await db.execute(stmt_subs)
        db_subjects = {s.id: s for s in res_subs.scalars().all()}
        
        for sub_id, stats in subject_totals.items():
            sub_obj = db_subjects.get(sub_id)
            if not sub_obj:
                continue
            sub_pct = (stats["obtained"] / stats["max"] * 100.0) if stats["max"] > 0 else 0.0
            p_list = stats["percentages"]
            subject_perf.append({
                "subject_id": str(sub_id),
                "subject_name": sub_obj.subject_name,
                "average_percentage": round(sub_pct, 2),
                "highest_percentage": round(max(p_list), 2) if p_list else 0.0,
                "lowest_percentage": round(min(p_list), 2) if p_list else 0.0
            })

    student_perf = []
    for std_id, stats in student_totals.items():
        student_obj = db_students.get(std_id)
        if not student_obj:
            continue
        std_pct = (stats["obtained"] / stats["max"] * 100.0) if stats["max"] > 0 else 0.0
        g = calculate_grade(std_pct)
        student_perf.append({
            "student_id": str(std_id),
            "student_name": f"{student_obj.first_name} {student_obj.last_name}",
            "admission_number": student_obj.admission_number,
            "class_name": student_obj.class_obj.name if student_obj.class_obj else "N/A",
            "section_name": student_obj.section.name if student_obj.section else "N/A",
            "percentage": round(std_pct, 2),
            "grade": g,
            "highest_score": round(stats["highest_score"], 2),
            "trend": student_obj.ai_metrics.get("overall_trend", "STABLE") if student_obj.ai_metrics else "STABLE"
        })

    academic_data = {
        "average_marks": round(average_marks, 2),
        "average_percentage": round(average_percentage, 2),
        "highest_marks": round(highest, 2),
        "lowest_marks": round(lowest_marks, 2),
        "pass_percentage": round(pass_percentage, 2),
        "grade_distribution": grade_counts,
        "student_count": len(student_totals),
        "top_performers": top_performers,
        "students_needing_intervention": students_needing_intervention,
        "subject_performance": subject_perf,
        "student_performance": student_perf
    }

    return APIResponse(
        success=True,
        message="Academic report metrics compiled successfully.",
        data=academic_data
    )

@router.get(
    "/examinations",
    response_model=APIResponse[List[Dict[str, Any]]],
    status_code=status.HTTP_200_OK,
    summary="Compare Chronological Examination Averages"
)
async def get_examination_reports(
    current_user: User = Depends(require_permission("reports.academic.read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    school_id: uuid.UUID = Depends(get_school_id),
    academic_year_id: Optional[uuid.UUID] = Query(None),
    class_id: Optional[uuid.UUID] = Query(None),
    section_id: Optional[uuid.UUID] = Query(None),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[List[Dict[str, Any]]]:
    # Query all examinations for this tenant/school
    stmt_ex = select(Examination).where(
        Examination.tenant_id == tenant_id,
        Examination.school_id == school_id,
        Examination.is_active == True
    )
    if academic_year_id:
        stmt_ex = stmt_ex.where(Examination.academic_year_id == academic_year_id)
    stmt_ex = stmt_ex.order_by(Examination.start_date.asc())
    res_ex = await db.execute(stmt_ex)
    exams = res_ex.scalars().all()

    exam_comparison = []

    for exam in exams:
        # Get published marks average for this exam
        stmt_m = select(
            func.avg(Marks.marks_obtained / Marks.maximum_marks * 100.0),
            func.count(func.distinct(Marks.student_id))
        ).where(
            Marks.examination_id == exam.id,
            Marks.status == "PUBLISHED"
        )
        if class_id:
            stmt_m = stmt_m.where(Marks.class_id == class_id)
        if section_id:
            stmt_m = stmt_m.where(Marks.section_id == section_id)
        res_m = await db.execute(stmt_m)
        avg_pct, std_count = res_m.first() or (None, 0)
        
        if avg_pct is not None:
            exam_comparison.append({
                "examination_id": str(exam.id),
                "name": exam.name,
                "average_percentage": round(float(avg_pct), 2),
                "student_count": std_count
            })

    return APIResponse(
        success=True,
        message="Examination comparisons retrieved successfully.",
        data=exam_comparison
    )

@router.get(
    "/attendance",
    response_model=APIResponse[Dict[str, Any]],
    status_code=status.HTTP_200_OK,
    summary="Get Attendance Metrics & Trends"
)
async def get_attendance_reports(
    current_user: User = Depends(require_permission("reports.attendance.read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    school_id: uuid.UUID = Depends(get_school_id),
    academic_year_id: Optional[uuid.UUID] = Query(None),
    class_id: Optional[uuid.UUID] = Query(None),
    section_id: Optional[uuid.UUID] = Query(None),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[Dict[str, Any]]:
    # Get attendance totals grouped by student
    stmt = select(
        Attendance.student_id,
        func.count(Attendance.id).label("total"),
        func.sum(func.cast(Attendance.attendance_status.in_(["PRESENT", "LATE"]), Integer)).label("present")
    ).where(
        Attendance.tenant_id == tenant_id,
        Attendance.school_id == school_id,
        Attendance.is_active == True
    )
    if academic_year_id:
        stmt = stmt.where(Attendance.academic_year_id == academic_year_id)
    if class_id:
        stmt = stmt.where(Attendance.class_id == class_id)
    if section_id:
        stmt = stmt.where(Attendance.section_id == section_id)
    stmt = stmt.group_by(Attendance.student_id)
    res = await db.execute(stmt)
    rows = res.all()

    if not rows:
        return APIResponse(
            success=True,
            message="No attendance metrics available.",
            data={
                "overall_attendance": 100.0,
                "class_wise_attendance": {},
                "section_wise_attendance": {},
                "monthly_attendance_trend": {},
                "low_attendance_students": []
            }
        )

    # 1. Overall
    tot_days = sum(r.total for r in rows)
    pres_days = sum(r.present or 0 for r in rows)
    overall_attendance = (pres_days / tot_days * 100.0) if tot_days > 0 else 100.0

    # 2. Low attendance alert limit (default < 75%)
    # Retrieve school attendance warning settings if available
    stmt_school = select(Class).where(Class.school_id == school_id)
    # Check threshold settings on school
    stmt_sc = select(School).where(School.id == school_id, School.tenant_id == tenant_id)
    res_sc = await db.execute(stmt_sc)
    school_obj = res_sc.scalar_one_or_none()
    threshold = 75.0
    if school_obj and school_obj.settings:
        threshold = float(school_obj.settings.get("attendance_alert_threshold", 75.0))

    low_att_stds = []
    std_ids = [r.student_id for r in rows]
    stmt_stds = select(Student).where(
        Student.tenant_id == tenant_id,
        Student.school_id == school_id,
        Student.id.in_(std_ids)
    ).options(selectinload(Student.class_obj), selectinload(Student.section))
    res_stds = await db.execute(stmt_stds)
    db_students = {s.id: s for s in res_stds.scalars().all()}

    for r in rows:
        pct = (r.present / r.total * 100.0) if r.total > 0 else 100.0
        if pct < threshold:
            student_obj = db_students.get(r.student_id)
            if student_obj:
                low_att_stds.append({
                    "student_id": str(r.student_id),
                    "student_name": f"{student_obj.first_name} {student_obj.last_name}",
                    "class_name": student_obj.class_obj.name if student_obj.class_obj else "N/A",
                    "section_name": student_obj.section.name if student_obj.section else "N/A",
                    "attendance_percentage": round(pct, 2)
                })

    # 3. Class wise & Section wise averages
    stmt_cls = select(
        Class.name,
        func.count(Attendance.id).label("total"),
        func.sum(func.cast(Attendance.attendance_status.in_(["PRESENT", "LATE"]), Integer)).label("present")
    ).join(Class, Class.id == Attendance.class_id).where(
        Attendance.tenant_id == tenant_id,
        Attendance.school_id == school_id,
        Attendance.is_active == True
    )
    if academic_year_id:
        stmt_cls = stmt_cls.where(Attendance.academic_year_id == academic_year_id)
    stmt_cls = stmt_cls.group_by(Class.name)
    res_cls = await db.execute(stmt_cls)
    class_att = {row.name: round(row.present / row.total * 100.0, 2) for row in res_cls.all() if row.total > 0}

    stmt_sec = select(
        Section.name,
        func.count(Attendance.id).label("total"),
        func.sum(func.cast(Attendance.attendance_status.in_(["PRESENT", "LATE"]), Integer)).label("present")
    ).join(Section, Section.id == Attendance.section_id).where(
        Attendance.tenant_id == tenant_id,
        Attendance.school_id == school_id,
        Attendance.is_active == True
    )
    if academic_year_id:
        stmt_sec = stmt_sec.where(Attendance.academic_year_id == academic_year_id)
    stmt_sec = stmt_sec.group_by(Section.name)
    res_sec = await db.execute(stmt_sec)
    sec_att = {row.name: round(row.present / row.total * 100.0, 2) for row in res_sec.all() if row.total > 0}

    # 4. Monthly attendance trend
    # Extract month in SQL
    # Postgres specific func.to_char, fallback to standard date extraction
    # Standard: func.extract('month', Attendance.attendance_date)
    # Check DB dialet
    stmt_m = select(
        func.extract('month', Attendance.attendance_date).label("month"),
        func.count(Attendance.id).label("total"),
        func.sum(func.cast(Attendance.attendance_status.in_(["PRESENT", "LATE"]), Integer)).label("present")
    ).where(
        Attendance.tenant_id == tenant_id,
        Attendance.school_id == school_id,
        Attendance.is_active == True
    )
    if academic_year_id:
        stmt_m = stmt_m.where(Attendance.academic_year_id == academic_year_id)
    stmt_m = stmt_m.group_by(func.extract('month', Attendance.attendance_date))
    res_m = await db.execute(stmt_m)
    
    month_names = {
        1: "January", 2: "February", 3: "March", 4: "April", 5: "May", 6: "June",
        7: "July", 8: "August", 9: "September", 10: "October", 11: "November", 12: "December"
    }
    monthly_trend = {}
    for r in res_m.all():
        m_idx = int(r.month)
        m_name = month_names.get(m_idx, f"Month {m_idx}")
        monthly_trend[m_name] = round(r.present / r.total * 100.0, 2)

    return APIResponse(
        success=True,
        message="Attendance reports compiled successfully.",
        data={
            "overall_attendance": round(overall_attendance, 2),
            "class_wise_attendance": class_att,
            "section_wise_attendance": sec_att,
            "monthly_attendance_trend": monthly_trend,
            "low_attendance_students": sorted(low_att_stds, key=lambda x: x["attendance_percentage"])
        }
    )

@router.get(
    "/fees",
    response_model=APIResponse[Dict[str, Any]],
    status_code=status.HTTP_200_OK,
    summary="Get Financial Fee Collection Report"
)
async def get_fee_reports(
    current_user: User = Depends(require_permission("reports.fees.read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    school_id: uuid.UUID = Depends(get_school_id),
    class_id: Optional[uuid.UUID] = Query(None),
    section_id: Optional[uuid.UUID] = Query(None),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[Dict[str, Any]]:
    # Sum totals assigned, collected, outstanding
    stmt = select(
        StudentFeeAssignment.assigned_amount,
        StudentFeeAssignment.paid_amount,
        StudentFeeAssignment.fine_amount,
        StudentFeeAssignment.discount_amount,
        StudentFeeAssignment.status,
        StudentFeeAssignment.student_id,
        FeeType.code.label("fee_type")
    ).join(
        FeeStructure, FeeStructure.id == StudentFeeAssignment.fee_structure_id
    ).join(
        FeeType, FeeType.id == FeeStructure.fee_type_id
    ).where(
        StudentFeeAssignment.tenant_id == tenant_id,
        FeeStructure.school_id == school_id,
        StudentFeeAssignment.deleted_at.is_(None)
    )
    if class_id or section_id:
        stmt = stmt.join(Student, Student.id == StudentFeeAssignment.student_id)
        if class_id:
            stmt = stmt.where(Student.class_id == class_id)
        if section_id:
            stmt = stmt.where(Student.section_id == section_id)
            
    res = await db.execute(stmt)
    assignments = res.all()

    if not assignments:
        return APIResponse(
            success=True,
            message="No fee records match requirements.",
            data={
                "total_assigned": 0.0,
                "total_collected": 0.0,
                "total_outstanding": 0.0,
                "paid_students_count": 0,
                "partial_payment_students_count": 0,
                "unpaid_students_count": 0,
                "collection_percentage": 0.0,
                "class_wise_collection": {},
                "fee_type_wise_collection": {},
                "student_fees": []
            }
        )

    total_assigned = 0.0
    total_collected = 0.0
    total_outstanding = 0.0
    student_status = {}
    fee_type_metrics = {}

    for a in assignments:
        asg = float(a.assigned_amount or 0.0)
        pd = float(a.paid_amount or 0.0)
        fine = float(a.fine_amount or 0.0)
        disc = float(a.discount_amount or 0.0)
        
        assigned_net = asg + fine - disc
        outstanding = max(assigned_net - pd, 0.0)

        total_assigned += assigned_net
        total_collected += pd
        total_outstanding += outstanding

        # Track per student
        s_id = a.student_id
        if s_id not in student_status:
            student_status[s_id] = {"assigned": 0.0, "paid": 0.0}
        student_status[s_id]["assigned"] += assigned_net
        student_status[s_id]["paid"] += pd

        # Fee type metrics
        ft = a.fee_type
        if ft not in fee_type_metrics:
            fee_type_metrics[ft] = {"assigned": 0.0, "paid": 0.0}
        fee_type_metrics[ft]["assigned"] += assigned_net
        fee_type_metrics[ft]["paid"] += pd

    # Categorize student payment states
    paid_count = 0
    partial_count = 0
    unpaid_count = 0

    for s_id, s_vals in student_status.items():
        if s_vals["paid"] >= s_vals["assigned"] and s_vals["assigned"] > 0:
            paid_count += 1
        elif s_vals["paid"] > 0:
            partial_count += 1
        else:
            unpaid_count += 1

    col_pct = (total_collected / total_assigned * 100.0) if total_assigned > 0 else 100.0

    # Class wise collection
    stmt_cls = select(
        Class.name,
        func.sum(StudentFeeAssignment.assigned_amount + StudentFeeAssignment.fine_amount - StudentFeeAssignment.discount_amount).label("assigned"),
        func.sum(StudentFeeAssignment.paid_amount).label("paid")
    ).join(FeeStructure, FeeStructure.id == StudentFeeAssignment.fee_structure_id)\
     .join(Student, Student.id == StudentFeeAssignment.student_id)\
     .join(Class, Class.id == Student.class_id)\
     .where(
         StudentFeeAssignment.tenant_id == tenant_id,
         FeeStructure.school_id == school_id,
         StudentFeeAssignment.deleted_at.is_(None)
     ).group_by(Class.name)
    res_cls = await db.execute(stmt_cls)
    class_coll = {}
    for r in res_cls.all():
        a_val = float(r.assigned or 0.0)
        p_val = float(r.paid or 0.0)
        class_coll[r.name] = round(p_val / a_val * 100.0, 2) if a_val > 0 else 100.0

    fee_type_coll = {}
    for ft, vals in fee_type_metrics.items():
        fee_type_coll[ft] = round(vals["paid"] / vals["assigned"] * 100.0, 2) if vals["assigned"] > 0 else 100.0

    student_fees_list = []
    if student_status:
        stmt_stds = select(Student).where(
            Student.tenant_id == tenant_id,
            Student.school_id == school_id,
            Student.id.in_(list(student_status.keys()))
        ).options(selectinload(Student.class_obj), selectinload(Student.section))
        res_stds = await db.execute(stmt_stds)
        db_students = {s.id: s for s in res_stds.scalars().all()}
        
        for s_id, s_vals in student_status.items():
            student_obj = db_students.get(s_id)
            if not student_obj:
                continue
            assigned_net = s_vals["assigned"]
            pd = s_vals["paid"]
            outstanding = max(assigned_net - pd, 0.0)
            
            status_str = "PAID"
            if pd >= assigned_net and assigned_net > 0:
                status_str = "PAID"
            elif pd > 0:
                status_str = "PARTIAL"
            else:
                status_str = "UNPAID"
                
            student_fees_list.append({
                "student_id": str(s_id),
                "student_name": f"{student_obj.first_name} {student_obj.last_name}",
                "class_name": student_obj.class_obj.name if student_obj.class_obj else "N/A",
                "section_name": student_obj.section.name if student_obj.section else "N/A",
                "assigned": round(assigned_net, 2),
                "paid": round(pd, 2),
                "outstanding": round(outstanding, 2),
                "status": status_str
            })

    return APIResponse(
        success=True,
        message="Fee report metrics compiled successfully.",
        data={
            "total_assigned": round(total_assigned, 2),
            "total_collected": round(total_collected, 2),
            "total_outstanding": round(total_outstanding, 2),
            "paid_students_count": paid_count,
            "partial_payment_students_count": partial_count,
            "unpaid_students_count": unpaid_count,
            "collection_percentage": round(col_pct, 2),
            "class_wise_collection": class_coll,
            "fee_type_wise_collection": fee_type_coll,
            "student_fees": student_fees_list
        }
    )

@router.get(
    "/ai-intelligence",
    response_model=APIResponse[Dict[str, Any]],
    status_code=status.HTTP_200_OK,
    summary="Get Scoped AI Academic Risk & Forecast Report"
)
async def get_ai_intelligence_reports(
    current_user: User = Depends(require_permission("reports.ai.read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    school_id: Optional[uuid.UUID] = Depends(get_optional_school_id),
    academic_year_id: Optional[uuid.UUID] = Query(None),
    class_id: Optional[uuid.UUID] = Query(None),
    section_id: Optional[uuid.UUID] = Query(None),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[Dict[str, Any]]:
    # Retrieve published report card AI metrics
    stmt = select(ReportCardPublication).where(
        ReportCardPublication.tenant_id == tenant_id,
        ReportCardPublication.status == ReportCardStatus.PUBLISHED
    ).options(
        selectinload(ReportCardPublication.student).selectinload(Student.class_obj),
        selectinload(ReportCardPublication.student).selectinload(Student.section)
    )
    if school_id:
        stmt = stmt.where(ReportCardPublication.school_id == school_id)
    if academic_year_id:
        stmt = stmt.where(ReportCardPublication.academic_year_id == academic_year_id)
        
    # Class/section filter join
    if class_id or section_id:
        # student already loaded but we filter query
        stmt = stmt.join(Student, Student.id == ReportCardPublication.student_id)
        if class_id:
            stmt = stmt.where(Student.class_id == class_id)
        if section_id:
            stmt = stmt.where(Student.section_id == section_id)

    res = await db.execute(stmt)
    publications = res.scalars().all()

    high_risk_list = []
    med_risk_list = []
    low_risk_list = []
    improving_list = []
    declining_list = []

    for pub in publications:
        student = pub.student
        if not student:
            continue
        
        ai_data = pub.ai_metrics or {}
        risk_lvl = ai_data.get("risk_level", "LOW")
        trend = ai_data.get("overall_trend", "STABLE")
        narrative = ai_data.get("ai_narrative", "Academic progress is monitored and stable.")
        
        # Calculate attendance percentage
        stmt_att = select(
            func.count(Attendance.id).label("total"),
            func.sum(func.cast(Attendance.attendance_status.in_(["PRESENT", "LATE"]), Integer)).label("present")
        ).where(
            Attendance.student_id == student.id,
            Attendance.is_active == True
        )
        if academic_year_id:
            stmt_att = stmt_att.where(Attendance.academic_year_id == academic_year_id)
        res_att = await db.execute(stmt_att)
        att_row = res_att.first()
        att_pct = 100.0
        if att_row and att_row.total > 0:
            att_pct = (att_row.present or 0) / att_row.total * 100.0

        # Calculate current percentage
        stmt_std_pct = select(func.avg(Marks.marks_obtained / Marks.maximum_marks * 100.0)).where(
            Marks.student_id == student.id,
            Marks.status == "PUBLISHED"
        )
        if academic_year_id:
            stmt_std_pct = stmt_std_pct.where(Marks.academic_year_id == academic_year_id)
        std_pct = (await db.execute(stmt_std_pct)).scalar() or 0.0

        # Identify weak subjects (published marks percentage < 50%)
        stmt_weak = select(Subject.subject_name).join(Marks, Marks.subject_id == Subject.id).where(
            Marks.student_id == student.id,
            Marks.status == "PUBLISHED"
        )
        if academic_year_id:
            stmt_weak = stmt_weak.where(Marks.academic_year_id == academic_year_id)
        stmt_weak = stmt_weak.group_by(Subject.subject_name).having(func.avg(Marks.marks_obtained / Marks.maximum_marks * 100.0) < 50.0)
        res_weak = await db.execute(stmt_weak)
        weak_subjects = [row[0] for row in res_weak.all()]
        if not weak_subjects:
            # Fallback to the single lowest performing subject if it is below 75%
            stmt_lowest = select(Subject.subject_name, func.avg(Marks.marks_obtained / Marks.maximum_marks * 100.0).label("avg_pct")).join(Marks, Marks.subject_id == Subject.id).where(
                Marks.student_id == student.id,
                Marks.status == "PUBLISHED"
            )
            if academic_year_id:
                stmt_lowest = stmt_lowest.where(Marks.academic_year_id == academic_year_id)
            stmt_lowest = stmt_lowest.group_by(Subject.subject_name).order_by(func.avg(Marks.marks_obtained / Marks.maximum_marks * 100.0).asc()).limit(1)
            res_lowest = await db.execute(stmt_lowest)
            lowest_row = res_lowest.first()
            if lowest_row and lowest_row[1] < 75.0:
                weak_subjects = [lowest_row[0]]
            else:
                weak_subjects = []

        att_trend = "STABLE"
        if att_pct >= 90.0:
            att_trend = "EXCELLENT"
        elif att_pct < 75.0:
            att_trend = "DECLINING"

        item = {
            "student_id": str(student.id),
            "student_name": f"{student.first_name} {student.last_name}",
            "class_name": student.class_obj.name if student.class_obj else "N/A",
            "section_name": student.section.name if student.section else "N/A",
            "current_percentage": round(float(std_pct), 2),
            "previous_percentage": round(float(std_pct) * 0.95, 2),  # Mock trajectory delta
            "attendance_percentage": round(att_pct, 2),
            "trend": trend,
            "risk_level": risk_lvl,
            "ai_narrative": narrative,
            "recommendation": ai_data.get("recommended_actions") or ("Provide standard tutoring." if risk_lvl == "HIGH" else "Maintain existing performance."),
            "attendance_trend": att_trend,
            "weak_subjects": weak_subjects
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

    return APIResponse(
        success=True,
        message="AI Intelligence analytical metrics fetched successfully.",
        data={
            "high_risk_students": high_risk_list,
            "medium_risk_students": med_risk_list,
            "low_risk_students": low_risk_list,
            "improving_students": improving_list,
            "declining_students": declining_list,
            "attendance_academic_risk_count": len(high_risk_list),
            "high_performers_count": len(improving_list)
        }
    )


@router.get(
    "/students",
    response_model=APIResponse[List[Dict[str, Any]]],
    status_code=status.HTTP_200_OK,
    summary="Get Detailed Student Analytics Roster"
)
async def get_student_reports(
    current_user: User = Depends(require_permission("reports.read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    school_id: uuid.UUID = Depends(get_school_id),
    academic_year_id: Optional[uuid.UUID] = Query(None),
    class_id: Optional[uuid.UUID] = Query(None),
    section_id: Optional[uuid.UUID] = Query(None),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[List[Dict[str, Any]]]:
    # Query students matching filters
    stmt = select(Student).where(
        Student.tenant_id == tenant_id,
        Student.school_id == school_id,
        Student.is_active == True
    ).options(selectinload(Student.class_obj), selectinload(Student.section))
    
    if class_id:
        stmt = stmt.where(Student.class_id == class_id)
    if section_id:
        stmt = stmt.where(Student.section_id == section_id)
        
    res = await db.execute(stmt)
    students = res.scalars().all()
    
    student_reports = []
    for student in students:
        # 1. Attendance percentage
        stmt_att = select(
            func.count(Attendance.id).label("total"),
            func.sum(func.cast(Attendance.attendance_status.in_(["PRESENT", "LATE"]), Integer)).label("present")
        ).where(
            Attendance.student_id == student.id,
            Attendance.is_active == True
        )
        if academic_year_id:
            stmt_att = stmt_att.where(Attendance.academic_year_id == academic_year_id)
        res_att = await db.execute(stmt_att)
        att_row = res_att.first()
        att_pct = 100.0
        if att_row and att_row.total > 0:
            att_pct = (att_row.present or 0) / att_row.total * 100.0
            
        # 2. Overall academic percentage (average of published marks)
        stmt_std_pct = select(func.avg(Marks.marks_obtained / Marks.maximum_marks * 100.0)).where(
            Marks.student_id == student.id,
            Marks.status == "PUBLISHED"
        )
        if academic_year_id:
            stmt_std_pct = stmt_std_pct.where(Marks.academic_year_id == academic_year_id)
        std_pct = (await db.execute(stmt_std_pct)).scalar() or 0.0
        
        # 3. Grade
        grade = calculate_grade(std_pct)
        
        # 4. Risk Level
        stmt_risk = select(ReportCardPublication.ai_metrics).where(
            ReportCardPublication.student_id == student.id,
            ReportCardPublication.status == ReportCardStatus.PUBLISHED
        )
        if academic_year_id:
            stmt_risk = stmt_risk.where(ReportCardPublication.academic_year_id == academic_year_id)
        res_risk = await db.execute(stmt_risk)
        ai_metrics = res_risk.scalar_one_or_none() or {}
        risk_level = ai_metrics.get("risk_level", "LOW")
        
        student_reports.append({
            "student_id": str(student.id),
            "student_name": f"{student.first_name} {student.last_name}",
            "admission_number": student.admission_number,
            "roll_number": student.roll_number,
            "class_name": student.class_obj.name if student.class_obj else "N/A",
            "section_name": student.section.name if student.section else "N/A",
            "class_id": str(student.class_id),
            "section_id": str(student.section_id),
            "attendance_percentage": round(att_pct, 2),
            "academic_percentage": round(std_pct, 2),
            "grade": grade,
            "promotion_status": student.status.value,
            "risk_level": risk_level
        })
        
    return APIResponse(
        success=True,
        message="Student detailed reports compiled successfully.",
        data=student_reports
    )


@router.get(
    "/teachers",
    response_model=APIResponse[List[Dict[str, Any]]],
    status_code=status.HTTP_200_OK,
    summary="Get Detailed Teacher Analytics Roster"
)
async def get_teacher_reports(
    current_user: User = Depends(require_permission("reports.read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    school_id: uuid.UUID = Depends(get_school_id),
    academic_year_id: Optional[uuid.UUID] = Query(None),
    class_id: Optional[uuid.UUID] = Query(None),
    section_id: Optional[uuid.UUID] = Query(None),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[List[Dict[str, Any]]]:
    # Query active teachers for tenant/school
    stmt = select(Teacher).where(
        Teacher.tenant_id == tenant_id,
        Teacher.school_id == school_id,
        Teacher.is_active == True
    )
    
    if class_id or section_id:
        stmt_tsa = select(TeacherSubjectAssignment.teacher_id).where(
            TeacherSubjectAssignment.tenant_id == tenant_id,
            TeacherSubjectAssignment.school_id == school_id,
            TeacherSubjectAssignment.is_active == True
        )
        if academic_year_id:
            stmt_tsa = stmt_tsa.where(TeacherSubjectAssignment.academic_year_id == academic_year_id)
        if class_id:
            stmt_tsa = stmt_tsa.where(TeacherSubjectAssignment.class_id == class_id)
        if section_id:
            stmt_tsa = stmt_tsa.where(TeacherSubjectAssignment.section_id == section_id)
        
        res_tsa = await db.execute(stmt_tsa)
        teacher_ids = [row[0] for row in res_tsa.all()]
        stmt = stmt.where(Teacher.id.in_(teacher_ids))
        
    res = await db.execute(stmt)
    teachers = res.scalars().all()
    
    teacher_reports = []
    for teacher in teachers:
        # Load assignments for this teacher
        stmt_assigns = select(TeacherSubjectAssignment).where(
            TeacherSubjectAssignment.teacher_id == teacher.id,
            TeacherSubjectAssignment.is_active == True
        ).options(
            selectinload(TeacherSubjectAssignment.subject),
            selectinload(TeacherSubjectAssignment.class_obj),
            selectinload(TeacherSubjectAssignment.section)
        )
        if academic_year_id:
            stmt_assigns = stmt_assigns.where(TeacherSubjectAssignment.academic_year_id == academic_year_id)
            
        res_assigns = await db.execute(stmt_assigns)
        assigns = res_assigns.scalars().all()
        
        subjects = list(set([a.subject.subject_name for a in assigns if a.subject]))
        classes = list(set([a.class_obj.name for a in assigns if a.class_obj]))
        sections = list(set([f"{a.class_obj.name} - {a.section.name}" for a in assigns if a.class_obj and a.section]))
        
        teacher_reports.append({
            "teacher_id": str(teacher.id),
            "teacher_name": f"{teacher.first_name} {teacher.last_name}",
            "subjects": subjects,
            "classes": classes,
            "sections": sections,
            "status": "ACTIVE" if len(assigns) > 0 else "UNASSIGNED"
        })
        
    return APIResponse(
        success=True,
        message="Teacher detailed reports compiled successfully.",
        data=teacher_reports
    )


@router.get(
    "/classes",
    response_model=APIResponse[List[Dict[str, Any]]],
    status_code=status.HTTP_200_OK,
    summary="Get Detailed Class/Section Analytics"
)
async def get_class_reports(
    current_user: User = Depends(require_permission("reports.read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    school_id: uuid.UUID = Depends(get_school_id),
    academic_year_id: Optional[uuid.UUID] = Query(None),
    class_id: Optional[uuid.UUID] = Query(None),
    section_id: Optional[uuid.UUID] = Query(None),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[List[Dict[str, Any]]]:
    # Query classes for tenant/school
    stmt_cls = select(Class).where(
        Class.tenant_id == tenant_id,
        Class.school_id == school_id,
        Class.is_active == True
    )
    if class_id:
        stmt_cls = stmt_cls.where(Class.id == class_id)
    res_cls = await db.execute(stmt_cls)
    classes = res_cls.scalars().all()
    
    class_reports = []
    for cls in classes:
        # Get sections of this class
        stmt_sec = select(Section).where(
            Section.class_id == cls.id,
            Section.is_active == True
        )
        if section_id:
            stmt_sec = stmt_sec.where(Section.id == section_id)
        res_sec = await db.execute(stmt_sec)
        sections = res_sec.scalars().all()
        
        sections_data = []
        for sec in sections:
            # Query section student count
            stmt_std_c = select(func.count(Student.id)).where(
                Student.section_id == sec.id,
                Student.is_active == True
            )
            std_c = (await db.execute(stmt_std_c)).scalar() or 0
            
            # Query section academic avg
            stmt_m = select(func.avg(Marks.marks_obtained / Marks.maximum_marks * 100.0)).where(
                Marks.section_id == sec.id,
                Marks.status == "PUBLISHED"
            )
            if academic_year_id:
                stmt_m = stmt_m.where(Marks.academic_year_id == academic_year_id)
            avg_pct = (await db.execute(stmt_m)).scalar() or 0.0
            
            # Query section attendance avg
            stmt_all = select(func.count(Attendance.id)).where(
                Attendance.section_id == sec.id,
                Attendance.is_active == True
            )
            stmt_pres = select(func.count(Attendance.id)).where(
                Attendance.section_id == sec.id,
                Attendance.is_active == True,
                Attendance.attendance_status.in_(["PRESENT", "LATE"])
            )
            if academic_year_id:
                stmt_all = stmt_all.where(Attendance.academic_year_id == academic_year_id)
                stmt_pres = stmt_pres.where(Attendance.academic_year_id == academic_year_id)
            all_att = (await db.execute(stmt_all)).scalar() or 0
            pres_att = (await db.execute(stmt_pres)).scalar() or 0
            sec_att_pct = (pres_att / all_att * 100.0) if all_att > 0 else 100.0
            
            # Query section risk count
            stmt_risk = select(func.count(ReportCardPublication.id)).where(
                ReportCardPublication.status == ReportCardStatus.PUBLISHED
            ).join(Student, Student.id == ReportCardPublication.student_id).where(
                Student.section_id == sec.id
            )
            if academic_year_id:
                stmt_risk = stmt_risk.where(ReportCardPublication.academic_year_id == academic_year_id)
            risk_cond = and_(
                ReportCardPublication.ai_metrics.is_not(None),
                ReportCardPublication.ai_metrics['risk_level'].as_string() == 'HIGH'
            )
            sec_risk_c = (await db.execute(stmt_risk.where(risk_cond))).scalar() or 0
            
            sections_data.append({
                "section_id": str(sec.id),
                "section_name": sec.name,
                "student_count": std_c,
                "academic_percentage": round(avg_pct, 2),
                "attendance_percentage": round(sec_att_pct, 2),
                "risk_count": sec_risk_c
            })
            
        # Class level aggregation
        stmt_cls_std_c = select(func.count(Student.id)).where(
            Student.class_id == cls.id,
            Student.is_active == True
        )
        if section_id:
            stmt_cls_std_c = stmt_cls_std_c.where(Student.section_id == section_id)
        cls_std_c = (await db.execute(stmt_cls_std_c)).scalar() or 0
        
        stmt_cls_m = select(func.avg(Marks.marks_obtained / Marks.maximum_marks * 100.0)).where(
            Marks.class_id == cls.id,
            Marks.status == "PUBLISHED"
        )
        if academic_year_id:
            stmt_cls_m = stmt_cls_m.where(Marks.academic_year_id == academic_year_id)
        if section_id:
            stmt_cls_m = stmt_cls_m.where(Marks.section_id == section_id)
        cls_avg_pct = (await db.execute(stmt_cls_m)).scalar() or 0.0
        
        stmt_cls_all = select(func.count(Attendance.id)).where(
            Attendance.class_id == cls.id,
            Attendance.is_active == True
        )
        stmt_cls_pres = select(func.count(Attendance.id)).where(
            Attendance.class_id == cls.id,
            Attendance.is_active == True,
            Attendance.attendance_status.in_(["PRESENT", "LATE"])
        )
        if academic_year_id:
            stmt_cls_all = stmt_cls_all.where(Attendance.academic_year_id == academic_year_id)
            stmt_cls_pres = stmt_cls_pres.where(Attendance.academic_year_id == academic_year_id)
        if section_id:
            stmt_cls_all = stmt_cls_all.where(Attendance.section_id == section_id)
            stmt_cls_pres = stmt_cls_pres.where(Attendance.section_id == section_id)
            
        cls_all_att = (await db.execute(stmt_cls_all)).scalar() or 0
        cls_pres_att = (await db.execute(stmt_cls_pres)).scalar() or 0
        cls_att_pct = (cls_pres_att / cls_all_att * 100.0) if cls_all_att > 0 else 100.0
        
        stmt_cls_risk = select(func.count(ReportCardPublication.id)).where(
            ReportCardPublication.status == ReportCardStatus.PUBLISHED
        ).join(Student, Student.id == ReportCardPublication.student_id).where(
            Student.class_id == cls.id
        )
        if academic_year_id:
            stmt_cls_risk = stmt_cls_risk.where(ReportCardPublication.academic_year_id == academic_year_id)
        if section_id:
            stmt_cls_risk = stmt_cls_risk.where(Student.section_id == section_id)
            
        risk_cond = and_(
            ReportCardPublication.ai_metrics.is_not(None),
            ReportCardPublication.ai_metrics['risk_level'].as_string() == 'HIGH'
        )
        cls_risk_c = (await db.execute(stmt_cls_risk.where(risk_cond))).scalar() or 0
        
        class_reports.append({
            "class_id": str(cls.id),
            "class_name": cls.name,
            "student_count": cls_std_c,
            "section_count": len(sections_data),
            "academic_percentage": round(cls_avg_pct, 2),
            "attendance_percentage": round(cls_att_pct, 2),
            "risk_count": cls_risk_c,
            "sections": sections_data
        })
        
    return APIResponse(
        success=True,
        message="Class detailed reports compiled successfully.",
        data=class_reports
    )


@router.get(
    "/tenant/overview",
    response_model=APIResponse[Dict[str, Any]],
    status_code=status.HTTP_200_OK,
    summary="Get Tenant-wide Overview Metrics & Schools Analytics"
)
async def get_tenant_analytics_overview(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[Dict[str, Any]]:
    from app.models.tenant import Tenant
    from app.models.academic_year import AcademicYear
    from app.api.dependencies.auth import get_current_user
    
    # Authenticate user and verify tenant permission (SUPER_ADMIN, TENANT_ADMIN, CHAIRMAN)
    is_authorized = current_user.is_superuser or any(
        r.code in ["SUPER_ADMIN", "TENANT_ADMIN", "CHAIRMAN"] for r in current_user.roles
    )
    if not is_authorized:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. Insufficient permissions to view tenant-wide analytics."
        )

    tenant_id = current_user.tenant_id
    # Fetch tenant name
    stmt_tenant = select(Tenant.name).where(Tenant.id == tenant_id)
    tenant_name = (await db.execute(stmt_tenant)).scalar() or "Unknown Tenant"

    # Fetch all schools under this tenant
    stmt_schools = select(School).where(School.tenant_id == tenant_id, School.deleted_at.is_(None))
    schools = (await db.execute(stmt_schools)).scalars().all()

    # 1. Total Schools
    total_schools = len(schools)

    # Compile school analytics mapping
    school_ids = [s.id for s in schools]
    schools_data = []

    # If tenant has no schools, return empty overview
    if not school_ids:
        return APIResponse(
            success=True,
            message="Tenant analytics fetched successfully.",
            data={
                "tenant_id": str(tenant_id),
                "tenant_name": tenant_name,
                "total_schools": 0,
                "total_students": 0,
                "total_teachers": 0,
                "overall_attendance": 100.0,
                "fee_collection_percentage": 100.0,
                "outstanding_fees": 0.0,
                "report_card_completion_percentage": 100.0,
                "schools": []
            }
        )

    # Bulk queries to avoid N+1 issues
    # 2. Students count by school
    stmt_std = select(Student.school_id, func.count(Student.id))\
        .where(Student.school_id.in_(school_ids), Student.is_active == True, Student.deleted_at.is_(None))\
        .group_by(Student.school_id)
    res_std = await db.execute(stmt_std)
    std_counts = {row[0]: row[1] for row in res_std.all()}

    # 3. Teachers count by school
    stmt_tch = select(Teacher.school_id, func.count(Teacher.id))\
        .where(Teacher.school_id.in_(school_ids), Teacher.is_active == True, Teacher.deleted_at.is_(None))\
        .group_by(Teacher.school_id)
    res_tch = await db.execute(stmt_tch)
    tch_counts = {row[0]: row[1] for row in res_tch.all()}

    # 4. Attendance overall percentage by school
    stmt_att = select(
        Attendance.school_id,
        Attendance.attendance_status,
        func.count(Attendance.id)
    ).where(
        Attendance.school_id.in_(school_ids),
        Attendance.is_active == True,
        Attendance.deleted_at.is_(None)
    ).group_by(Attendance.school_id, Attendance.attendance_status)
    res_att = await db.execute(stmt_att)
    
    att_stats = {} # school_id -> {"total": int, "present": int}
    for row in res_att.all():
        sch_id, status_val, count_val = row[0], row[1], row[2]
        if sch_id not in att_stats:
            att_stats[sch_id] = {"total": 0, "present": 0}
        att_stats[sch_id]["total"] += count_val
        if status_val in ["PRESENT", "LATE"]:
            att_stats[sch_id]["present"] += count_val

    # 5. Fees collection statistics by school (joined with Student since StudentFeeAssignment has no school_id)
    stmt_fees = select(
        Student.school_id,
        func.sum(StudentFeeAssignment.assigned_amount),
        func.sum(StudentFeeAssignment.paid_amount)
    ).join(Student, Student.id == StudentFeeAssignment.student_id)\
     .where(Student.school_id.in_(school_ids), StudentFeeAssignment.deleted_at.is_(None))\
     .group_by(Student.school_id)
    res_fees = await db.execute(stmt_fees)
    fees_stats = {row[0]: {"assigned": row[1] or Decimal("0.00"), "paid": row[2] or Decimal("0.00")} for row in res_fees.all()}

    # 6. Report Card Completion counts by status & school
    stmt_rc = select(
        ReportCardPublication.school_id,
        ReportCardPublication.status,
        func.count(ReportCardPublication.id)
    ).where(
        ReportCardPublication.school_id.in_(school_ids),
        ReportCardPublication.is_active == True,
        ReportCardPublication.deleted_at.is_(None)
    ).group_by(ReportCardPublication.school_id, ReportCardPublication.status)
    res_rc = await db.execute(stmt_rc)
    
    rc_stats = {} # school_id -> {"total": int, "published": int}
    for row in res_rc.all():
        sch_id, status_val, count_val = row[0], row[1], row[2]
        if sch_id not in rc_stats:
            rc_stats[sch_id] = {"total": 0, "published": 0}
        rc_stats[sch_id]["total"] += count_val
        if status_val == ReportCardStatus.PUBLISHED:
            rc_stats[sch_id]["published"] += count_val

    # Build the final schools detail list and global aggregated stats
    total_students = 0
    total_teachers = 0
    global_total_attendance = 0
    global_present_attendance = 0
    global_assigned_fees = Decimal("0.00")
    global_paid_fees = Decimal("0.00")
    global_total_rcs = 0
    global_published_rcs = 0

    for sch in schools:
        sch_id = sch.id
        std_c = std_counts.get(sch_id, 0)
        tch_c = tch_counts.get(sch_id, 0)
        
        # Calculate attendance percentage
        att_info = att_stats.get(sch_id, {"total": 0, "present": 0})
        att_pct = (att_info["present"] / att_info["total"] * 100.0) if att_info["total"] > 0 else 100.0
        
        # Calculate fee collection percentage
        fee_info = fees_stats.get(sch_id, {"assigned": Decimal("0.00"), "paid": Decimal("0.00")})
        assigned_val = float(fee_info["assigned"])
        paid_val = float(fee_info["paid"])
        fee_pct = (paid_val / assigned_val * 100.0) if assigned_val > 0 else 100.0
        
        # Calculate report card completion percentage
        rc_info = rc_stats.get(sch_id, {"total": 0, "published": 0})
        rc_pct = (rc_info["published"] / std_c * 100.0) if std_c > 0 else 100.0
        if rc_pct > 100.0:
            rc_pct = 100.0
            
        # Accumulate global aggregates
        total_students += std_c
        total_teachers += tch_c
        global_total_attendance += att_info["total"]
        global_present_attendance += att_info["present"]
        global_assigned_fees += fee_info["assigned"]
        global_paid_fees += fee_info["paid"]
        global_total_rcs += rc_info["total"]
        global_published_rcs += rc_info["published"]

        schools_data.append({
            "school_id": str(sch_id),
            "school_name": sch.name,
            "students_count": std_c,
            "teachers_count": tch_c,
            "attendance_percentage": round(att_pct, 2),
            "fee_collection_percentage": round(fee_pct, 2),
            "report_card_completion_percentage": round(rc_pct, 2),
            "is_active": sch.is_active
        })

    overall_att_pct = (global_present_attendance / global_total_attendance * 100.0) if global_total_attendance > 0 else 100.0
    overall_fee_pct = (float(global_paid_fees) / float(global_assigned_fees) * 100.0) if global_assigned_fees > 0 else 100.0
    overall_rc_pct = (global_published_rcs / total_students * 100.0) if total_students > 0 else 100.0
    if overall_rc_pct > 100.0:
        overall_rc_pct = 100.0
    outstanding_fees_val = float(global_assigned_fees - global_paid_fees)

    # Find active academic year code under active tenant context (if available, e.g. from first school's current year)
    active_ay_code = "Not available"
    if school_ids:
        stmt_ay = select(AcademicYear.code).where(
            AcademicYear.school_id.in_(school_ids),
            AcademicYear.is_current == True,
            AcademicYear.deleted_at.is_(None)
        ).limit(1)
        active_ay_code = (await db.execute(stmt_ay)).scalar() or "Not available"

    overview_data = {
        "tenant_id": str(tenant_id),
        "tenant_name": tenant_name,
        "total_schools": total_schools,
        "total_students": total_students,
        "total_teachers": total_teachers,
        "overall_attendance": round(overall_att_pct, 2),
        "fee_collection_percentage": round(overall_fee_pct, 2),
        "outstanding_fees": round(outstanding_fees_val, 2),
        "report_card_completion_percentage": round(overall_rc_pct, 2),
        "active_academic_year": active_ay_code,
        "schools": schools_data
    }

    return APIResponse(
        success=True,
        message="Tenant overview analytics retrieved successfully.",
        data=overview_data
    )
