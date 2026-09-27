import io
import os
import uuid
from typing import List, Optional, Any
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, Query, status, HTTPException, UploadFile, File, Response
from PIL import Image as PILImage

from app.api.dependencies.common import get_tenant_id, verify_school_access
from app.api.dependencies.student import get_student_service
from app.api.dependencies.auth import require_permission, get_current_user
from app.services.storage import StorageService, get_storage_service
from app.services.student import StudentService
from app.schemas.student import StudentCreate, StudentUpdate, StudentResponse
from app.models.student import Student, StudentStatus
from app.models.user import User
from app.schemas.response import APIResponse
from app.schemas.student_analytics import (
    StudentAnalyticsResponse,
    Student360Attendance,
    Student360Academics,
    Student360Fees,
    Student360AiAnalysis,
    TrendPoint,
    ExamTrendPoint,
    SubjectScorePoint,
    HomeworkItem,
    StudentActivityLogItem,
)

router = APIRouter()

@router.post(
    "",
    response_model=APIResponse[StudentResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Register a new student",
    description="Registers a new student profile in the system under Class/Section boundaries, checking capacities."
)
async def create_student(
    obj_in: StudentCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("student.create")),
    service: StudentService = Depends(get_student_service)
) -> APIResponse[StudentResponse]:
    await verify_school_access(current_user, obj_in.school_id, service.student_repo.db)
    db_obj = await service.create_student(tenant_id, obj_in, created_by=current_user.id)
    return APIResponse[StudentResponse](
        success=True,
        message="Student registered successfully.",
        data=StudentResponse.model_validate(db_obj)
    )

@router.get(
    "",
    response_model=APIResponse[List[StudentResponse]],
    status_code=status.HTTP_200_OK,
    summary="List student profiles under school",
    description="Retrieves a paginated list of students scoped by tenant, school, academic year, class, and section."
)
async def list_students(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    academic_year_id: Optional[uuid.UUID] = Query(None, description="Filter by Academic Year ID"),
    class_id: Optional[uuid.UUID] = Query(None, description="Filter by Class ID"),
    section_id: Optional[uuid.UUID] = Query(None, description="Filter by Section ID"),
    status_filter: Optional[StudentStatus] = Query(None, alias="status", description="Filter by student status"),
    search: Optional[str] = Query(None, description="Fuzzy match search on names, email, admission/roll codes, aadhaar, or mobile"),
    attention: Optional[str] = Query(None, description="Filter students by attention state (e.g. 'needs_attention')"),
    filter: Optional[str] = Query(None, description="Alias for attention filter (e.g. 'needs_attention')"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("student.read")),
    service: StudentService = Depends(get_student_service)
) -> APIResponse[List[StudentResponse]]:
    await verify_school_access(current_user, school_id, service.student_repo.db)
    role_codes = {r.code for r in current_user.roles}
    is_admin_or_principal = current_user.is_superuser or any(
        code in ["SUPER_ADMIN", "ADMIN", "SCHOOL_ADMIN", "PRINCIPAL", "TENANT_ADMIN", "CHAIRMAN"] for code in role_codes
    )
    class_section_pairs = None
    if not is_admin_or_principal and "TEACHER" in role_codes:
        from app.repositories.teacher import TeacherRepository
        from app.models.teacher_subject_assignment import TeacherSubjectAssignment, AssignmentStatus
        from sqlalchemy import select

        teacher_repo = TeacherRepository(service.student_repo.db)
        teacher = await teacher_repo.get_by_user_id(current_user.id, tenant_id)
        if not teacher:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. No active teacher profile found for user."
            )

        if class_id and section_id:
            stmt_tsa = select(TeacherSubjectAssignment).where(
                TeacherSubjectAssignment.teacher_id == teacher.id,
                TeacherSubjectAssignment.class_id == class_id,
                TeacherSubjectAssignment.section_id == section_id,
                TeacherSubjectAssignment.status == AssignmentStatus.ACTIVE,
                TeacherSubjectAssignment.tenant_id == tenant_id
            )
            res_tsa = await service.student_repo.db.execute(stmt_tsa)
            tsa = res_tsa.scalar_one_or_none()
            if not tsa:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Access denied. You are not assigned to this class and section."
                )
        else:
            stmt_tsa = select(TeacherSubjectAssignment.class_id, TeacherSubjectAssignment.section_id).where(
                TeacherSubjectAssignment.teacher_id == teacher.id,
                TeacherSubjectAssignment.status == AssignmentStatus.ACTIVE,
                TeacherSubjectAssignment.tenant_id == tenant_id
            )
            res_tsa = await service.student_repo.db.execute(stmt_tsa)
            assignments = res_tsa.all()
            if not assignments:
                return APIResponse[List[StudentResponse]](
                    success=True,
                    message="Students fetched successfully.",
                    data=[],
                    meta={"total": 0}
                )
            class_section_pairs = [(row.class_id, row.section_id) for row in assignments]

    # Needs Attention Filter Branch (Shared Single Source of Truth with Dashboard)
    is_attention_query = (attention == "needs_attention" or filter == "needs_attention")
    if is_attention_query:
        from app.services.student_risk_service import evaluate_active_risk_students
        risk_evaluation = await evaluate_active_risk_students(
            db=service.student_repo.db,
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=academic_year_id,
            class_id=class_id,
            section_id=section_id
        )
        high_risk_students = risk_evaluation.get("high_risk_students", [])

        # Filter by teacher assignments if applicable
        if class_section_pairs:
            valid_pairs = set(class_section_pairs)
            high_risk_students = [
                s for s in high_risk_students
                if (
                    uuid.UUID(s["class_id"]) if s.get("class_id") else None,
                    uuid.UUID(s["section_id"]) if s.get("section_id") else None
                ) in valid_pairs
            ]

        # Filter by status if specified
        if status_filter and status_filter != StudentStatus.ACTIVE:
            high_risk_students = []

        # Filter by search if provided
        if search:
            s_lower = search.lower()
            high_risk_students = [
                s for s in high_risk_students
                if s_lower in s.get("student_name", "").lower()
                or s_lower in (s.get("admission_number") or "").lower()
                or s_lower in (s.get("roll_number") or "").lower()
            ]

        total_qualifying = len(high_risk_students)
        paged_risk = high_risk_students[skip : skip + limit]

        if not paged_risk:
            return APIResponse[List[StudentResponse]](
                success=True,
                message="Students fetched successfully.",
                data=[],
                meta={"total": total_qualifying}
            )

        paged_ids = [uuid.UUID(item["student_id"]) for item in paged_risk]
        risk_map = {item["student_id"]: item for item in paged_risk}

        from sqlalchemy import select
        from sqlalchemy.orm import selectinload
        stmt_fetch = select(Student).where(
            Student.id.in_(paged_ids),
            Student.school_id == school_id,
            Student.tenant_id == tenant_id,
            Student.deleted_at.is_(None)
        ).options(
            selectinload(Student.class_obj),
            selectinload(Student.section)
        )
        res_fetch = await service.student_repo.db.execute(stmt_fetch)
        fetched_students = {s.id: s for s in res_fetch.scalars().all()}

        responses = []
        for s_id in paged_ids:
            s = fetched_students.get(s_id)
            if not s:
                continue
            r_item = risk_map.get(str(s_id), {})
            resp = StudentResponse.model_validate(s)
            current_metrics = dict(resp.ai_metrics or {})
            current_metrics.update({
                "needs_attention": True,
                "attention_reason": r_item.get("attention_reason"),
                "attendance_rate": r_item.get("attendance_rate"),
                "academic_trend": r_item.get("trend"),
                "consecutive_drops": r_item.get("consecutive_drops", 0),
                "risk_level": "HIGH",
            })
            resp.ai_metrics = current_metrics
            responses.append(resp)

        return APIResponse[List[StudentResponse]](
            success=True,
            message="Students fetched successfully.",
            data=responses,
            meta={"total": total_qualifying}
        )

    students = await service.student_repo.get_multi(
        school_id=school_id,
        tenant_id=tenant_id,
        academic_year_id=academic_year_id,
        class_id=class_id,
        section_id=section_id,
        status=status_filter,
        search=search,
        class_section_pairs=class_section_pairs,
        skip=skip,
        limit=limit
    )
    total_count = await service.student_repo.get_count(
        school_id=school_id,
        tenant_id=tenant_id,
        academic_year_id=academic_year_id,
        class_id=class_id,
        section_id=section_id,
        status=status_filter,
        search=search,
        class_section_pairs=class_section_pairs
    )
    responses = [StudentResponse.model_validate(s) for s in students]
    return APIResponse[List[StudentResponse]](
        success=True,
        message="Students fetched successfully.",
        data=responses,
        meta={"total": total_count}
    )

@router.get(
    "/{id}",
    response_model=APIResponse[StudentResponse],
    status_code=status.HTTP_200_OK,
    summary="Get student details",
    description="Retrieves student profile attributes scoped by tenant and school."
)
async def get_student(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("student.read")),
    service: StudentService = Depends(get_student_service)
) -> APIResponse[StudentResponse]:
    await verify_school_access(current_user, school_id, service.student_repo.db)
    db_obj = await service.student_repo.get_by_id(id, school_id, tenant_id)
    if not db_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student not found."
        )

    role_codes = {r.code for r in current_user.roles}
    is_admin_or_principal = current_user.is_superuser or any(
        code in ["SUPER_ADMIN", "ADMIN", "SCHOOL_ADMIN", "PRINCIPAL", "TENANT_ADMIN", "CHAIRMAN"] for code in role_codes
    )
    if not is_admin_or_principal and "TEACHER" in role_codes:
        from app.repositories.teacher import TeacherRepository
        from app.models.teacher_subject_assignment import TeacherSubjectAssignment, AssignmentStatus
        from sqlalchemy import select

        teacher_repo = TeacherRepository(service.student_repo.db)
        teacher = await teacher_repo.get_by_user_id(current_user.id, tenant_id)
        if not teacher:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. No active teacher profile found for user."
            )
        stmt_tsa = select(TeacherSubjectAssignment).where(
            TeacherSubjectAssignment.teacher_id == teacher.id,
            TeacherSubjectAssignment.class_id == db_obj.class_id,
            TeacherSubjectAssignment.section_id == db_obj.section_id,
            TeacherSubjectAssignment.status == AssignmentStatus.ACTIVE,
            TeacherSubjectAssignment.tenant_id == tenant_id
        )
        res_tsa = await service.student_repo.db.execute(stmt_tsa)
        tsa = res_tsa.scalar_one_or_none()
        if not tsa:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. You are not assigned to this student's class and section."
            )

    if not is_admin_or_principal and "PARENT" in role_codes:
        from app.models.guardian import Guardian, StudentGuardian
        from sqlalchemy import select, or_
        stmt_guard = select(StudentGuardian).join(Guardian).where(
            StudentGuardian.student_id == id,
            StudentGuardian.school_id == school_id,
            StudentGuardian.tenant_id == tenant_id,
            or_(
                Guardian.user_id == current_user.id,
                Guardian.email == current_user.email
            )
        )
        res_guard = await service.student_repo.db.execute(stmt_guard)
        if not res_guard.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. You are not a linked guardian of this student."
            )

    return APIResponse[StudentResponse](
        success=True,
        message="Student details fetched successfully.",
        data=StudentResponse.model_validate(db_obj)
    )

@router.put(
    "/{id}",
    response_model=APIResponse[StudentResponse],
    status_code=status.HTTP_200_OK,
    summary="Update student details",
    description="Modifies student parameters scoped by tenant and school."
)
async def update_student(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    obj_in: StudentUpdate = ...,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("student.update")),
    service: StudentService = Depends(get_student_service)
) -> APIResponse[StudentResponse]:
    await verify_school_access(current_user, school_id, service.student_repo.db)
    db_obj = await service.update_student(tenant_id, school_id, id, obj_in, updated_by=current_user.id)
    return APIResponse[StudentResponse](
        success=True,
        message="Student updated successfully.",
        data=StudentResponse.model_validate(db_obj)
    )

@router.delete(
    "/{id}",
    response_model=APIResponse[StudentResponse],
    status_code=status.HTTP_200_OK,
    summary="Soft-delete student profile",
    description="Soft-deletes the student profile, updating status to INACTIVE."
)
async def delete_student(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("student.delete")),
    service: StudentService = Depends(get_student_service)
) -> APIResponse[StudentResponse]:
    await verify_school_access(current_user, school_id, service.student_repo.db)
    db_obj = await service.delete_student(tenant_id, school_id, id, deleted_by=current_user.id)
    return APIResponse[StudentResponse](
        success=True,
        message="Student deleted successfully.",
        data=StudentResponse.model_validate(db_obj)
    )

@router.get(
    "/{id}/analytics",
    response_model=APIResponse[StudentAnalyticsResponse],
    status_code=status.HTTP_200_OK,
    summary="Get Student 360 operational analytics",
    description="Computes real-time Student 360 analytics (attendance, academics, fees, homework, activity, report cards) directly from database records without fabricated fallback numbers."
)
@router.get(
    "/{id}/360",
    response_model=APIResponse[StudentAnalyticsResponse],
    status_code=status.HTTP_200_OK,
    summary="Get Student 360 consolidated profile",
    description="Alias endpoint for Student 360 operational analytics."
)
async def get_student_analytics(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("student.read")),
    service: StudentService = Depends(get_student_service)
) -> APIResponse[StudentAnalyticsResponse]:
    await verify_school_access(current_user, school_id, service.student_repo.db)
    student = await service.student_repo.get_by_id(id, school_id, tenant_id)
    if not student:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student not found."
        )

    from collections import defaultdict
    from datetime import datetime, date
    from sqlalchemy import select, func
    from sqlalchemy.orm import selectinload
    from app.models.attendance import Attendance, AttendanceStatus
    from app.models.marks import Marks
    from app.models.subject import Subject
    from app.models.examination import Examination, ExamStatus
    from app.models.fee import StudentFeeAssignment, FeePayment, PaymentStatus
    from app.models.homework import Homework
    from app.models.report_card import ReportCardPublication
    from app.schemas.student_analytics import (
        TrendPoint,
        ExamTrendPoint,
        SubjectScorePoint,
        ExamSummaryItem,
        Student360Attendance,
        Student360Academics,
        Student360Fees,
        Student360AiAnalysis,
        HomeworkItem,
        StudentActivityLogItem,
        Student360ReportCard,
        StudentAnalyticsResponse,
    )

    # 1. Attendance Analytics
    stmt_att = select(Attendance).where(
        Attendance.student_id == id,
        Attendance.school_id == school_id,
        Attendance.tenant_id == tenant_id,
        Attendance.deleted_at.is_(None)
    ).order_by(Attendance.attendance_date.asc())
    res_att = await service.student_repo.db.execute(stmt_att)
    att_records = res_att.scalars().all()

    if not att_records:
        attendance_data = Student360Attendance(
            has_data=False,
            attendance_rate=None,
            total_days=0,
            present_days=0,
            absent_days=0,
            late_days=0,
            leave_days=0,
            working_days=0,
            monthly_trend=[]
        )
    else:
        total_days = len(att_records)
        present_days = sum(1 for a in att_records if a.attendance_status in [AttendanceStatus.PRESENT, AttendanceStatus.ONLINE])
        absent_days = sum(1 for a in att_records if a.attendance_status == AttendanceStatus.ABSENT)
        late_days = sum(1 for a in att_records if a.attendance_status == AttendanceStatus.LATE)
        leave_days = sum(1 for a in att_records if a.attendance_status in [AttendanceStatus.EXCUSED, AttendanceStatus.MEDICAL_LEAVE, AttendanceStatus.HALF_DAY])
        att_rate = round((present_days / total_days) * 100, 1) if total_days > 0 else None

        monthly_map = defaultdict(lambda: {"present": 0, "total": 0, "label": ""})
        for a in att_records:
            ym_key = (a.attendance_date.year, a.attendance_date.month)
            monthly_map[ym_key]["total"] += 1
            monthly_map[ym_key]["label"] = a.attendance_date.strftime("%b")
            if a.attendance_status in [AttendanceStatus.PRESENT, AttendanceStatus.ONLINE]:
                monthly_map[ym_key]["present"] += 1

        monthly_trend = [
            TrendPoint(
                label=counts["label"],
                value=round((counts["present"] / counts["total"]) * 100, 1) if counts["total"] > 0 else 0.0
            )
            for ym_key, counts in sorted(monthly_map.items())
        ]

        attendance_data = Student360Attendance(
            has_data=True,
            attendance_rate=att_rate,
            total_days=total_days,
            present_days=present_days,
            absent_days=absent_days,
            late_days=late_days,
            leave_days=leave_days,
            working_days=total_days,
            monthly_trend=monthly_trend
        )

    # 2. Academic / Examination Analytics (Completed examinations only)
    stmt_marks = select(Marks).where(
        Marks.student_id == id,
        Marks.school_id == school_id,
        Marks.tenant_id == tenant_id,
        Marks.deleted_at.is_(None)
    )
    res_marks = await service.student_repo.db.execute(stmt_marks)
    marks_records = res_marks.scalars().all()
    valid_marks = [m for m in marks_records if m.marks_obtained is not None and m.maximum_marks > 0]

    # Filter by completed/published examinations whose start_date <= today and not deleted
    exam_ids = {m.examination_id for m in valid_marks if m.examination_id}
    exams_by_id = {}
    if exam_ids:
        today = date.today()
        stmt_exam = select(Examination).where(
            Examination.id.in_(exam_ids),
            Examination.status.in_([ExamStatus.COMPLETED, ExamStatus.PUBLISHED, ExamStatus.APPROVED, ExamStatus.LOCKED]),
            Examination.start_date <= today,
            Examination.is_active.is_(True),
            Examination.deleted_at.is_(None)
        )
        res_exam = await service.student_repo.db.execute(stmt_exam)
        exams_by_id = {e.id: e for e in res_exam.scalars().all()}

    completed_marks = [m for m in valid_marks if m.examination_id in exams_by_id]

    if not completed_marks:
        academics_data = Student360Academics(
            has_data=False,
            academic_average=None,
            current_score=None,
            overall_grade=None,
            class_rank=None,
            section_rank=None,
            completed_examinations=[],
            exam_trends=[],
            subject_scores=[]
        )
    else:
        subject_ids = {m.subject_id for m in completed_marks if m.subject_id}
        subjects_by_id = {}
        if subject_ids:
            stmt_sub = select(Subject).where(Subject.id.in_(subject_ids))
            res_sub = await service.student_repo.db.execute(stmt_sub)
            subjects_by_id = {s.id: s.subject_name for s in res_sub.scalars().all()}

        subject_map = defaultdict(lambda: {"obtained": 0.0, "max": 0.0, "grades": []})
        for m in completed_marks:
            s_name = subjects_by_id.get(m.subject_id, "Subject")
            subject_map[s_name]["obtained"] += float(m.marks_obtained)
            subject_map[s_name]["max"] += float(m.maximum_marks)
            if m.grade:
                subject_map[s_name]["grades"].append(m.grade)

        subject_scores = []
        for s_name, stats in subject_map.items():
            pct = round((stats["obtained"] / stats["max"]) * 100, 1) if stats["max"] > 0 else 0.0
            grade = stats["grades"][-1] if stats["grades"] else None
            subject_scores.append(SubjectScorePoint(
                subject=s_name,
                score=pct,
                grade=grade,
                strong=pct >= 85.0,
                needs_support=pct < 60.0
            ))

        from app.models.school import School
        res_school = await service.student_repo.db.execute(
            select(School).where(School.id == school_id)
        )
        school_obj = res_school.scalar_one_or_none()
        grade_policy = school_obj.settings.get("grade_policy") if (school_obj and school_obj.settings) else None

        def compute_letter_grade(pct: float) -> str:
            if grade_policy:
                for g in grade_policy:
                    if g["min_percentage"] <= pct <= g["max_percentage"]:
                        return g["grade"]
            if pct >= 90.0:
                return "A+"
            elif pct >= 80.0:
                return "A"
            elif pct >= 70.0:
                return "B"
            elif pct >= 60.0:
                return "C"
            elif pct >= 50.0:
                return "D"
            elif pct >= 35.0:
                return "E"
            return "F"

        completed_examinations = []
        exam_groups = defaultdict(list)
        for m in completed_marks:
            exam_groups[m.examination_id].append(m)

        for eid, m_list in exam_groups.items():
            exam_obj = exams_by_id[eid]
            e_obtained = sum(float(m.marks_obtained) for m in m_list)
            e_max = sum(float(m.maximum_marks) for m in m_list)
            e_pct = round((e_obtained / e_max) * 100, 1) if e_max > 0 else 0.0
            e_grade = compute_letter_grade(e_pct)
            completed_examinations.append(ExamSummaryItem(
                examination_name=exam_obj.exam_name,
                exam_type=exam_obj.exam_type.value if hasattr(exam_obj.exam_type, "value") else str(exam_obj.exam_type),
                exam_date=exam_obj.start_date.strftime("%d %b %Y") if exam_obj.start_date else "",
                total_max_marks=e_max,
                total_obtained_marks=e_obtained,
                percentage=e_pct,
                grade=e_grade,
                status=exam_obj.status.value if hasattr(exam_obj.status, "value") else str(exam_obj.status)
            ))

        completed_examinations.sort(key=lambda x: x.exam_date)

        exam_trends = [
            ExamTrendPoint(
                label=e.examination_name,
                value=e.percentage,
                tooltip_detail=f"Score: {e.total_obtained_marks:.0f}/{e.total_max_marks:.0f} ({e.percentage}%)"
            )
            for e in completed_examinations
        ]

        total_obtained = sum(float(m.marks_obtained) for m in completed_marks)
        total_max = sum(float(m.maximum_marks) for m in completed_marks)
        current_score = round((total_obtained / total_max) * 100, 1) if total_max > 0 else None
        overall_grade = compute_letter_grade(current_score) if current_score is not None else None

        # Authoritative Rank Calculations
        class_rank = None
        section_rank = None
        if student.class_id and exams_by_id:
            stmt_peers = select(
                Marks.student_id,
                Student.section_id,
                func.sum(Marks.marks_obtained).label("peer_total")
            ).join(
                Student, Student.id == Marks.student_id
            ).where(
                Marks.examination_id.in_(list(exams_by_id.keys())),
                Marks.school_id == school_id,
                Marks.tenant_id == tenant_id,
                Marks.deleted_at.is_(None),
                Marks.marks_obtained.isnot(None),
                Student.class_id == student.class_id,
                Student.deleted_at.is_(None)
            ).group_by(Marks.student_id, Student.section_id)

            res_peers = await service.student_repo.db.execute(stmt_peers)
            peer_rows = res_peers.all()

            if peer_rows:
                class_scores = [(r[0], float(r[2])) for r in peer_rows]
                my_c_score = next((score for sid, score in class_scores if sid == id), total_obtained)
                c_rank_val = 1 + sum(1 for sid, score in class_scores if score > my_c_score)
                class_rank = f"{c_rank_val} / {len(class_scores)}"

                section_scores = [(r[0], float(r[2])) for r in peer_rows if r[1] == student.section_id]
                if section_scores:
                    my_s_score = next((score for sid, score in section_scores if sid == id), total_obtained)
                    s_rank_val = 1 + sum(1 for sid, score in section_scores if score > my_s_score)
                    section_rank = f"{s_rank_val} / {len(section_scores)}"

        academics_data = Student360Academics(
            has_data=True,
            academic_average=current_score,
            current_score=current_score,
            overall_grade=overall_grade,
            class_rank=class_rank,
            section_rank=section_rank,
            completed_examinations=completed_examinations,
            exam_trends=exam_trends,
            subject_scores=subject_scores
        )

    # 3. Fees Analytics
    stmt_fa = select(StudentFeeAssignment).where(
        StudentFeeAssignment.student_id == id,
        StudentFeeAssignment.tenant_id == tenant_id,
        StudentFeeAssignment.deleted_at.is_(None)
    )
    res_fa = await service.student_repo.db.execute(stmt_fa)
    assignments = res_fa.scalars().all()

    stmt_pay = select(FeePayment).where(
        FeePayment.student_id == id,
        FeePayment.tenant_id == tenant_id,
        FeePayment.status == PaymentStatus.COMPLETED,
        FeePayment.deleted_at.is_(None)
    )
    res_pay = await service.student_repo.db.execute(stmt_pay)
    payments = res_pay.scalars().all()

    if not assignments and not payments:
        fees_data = Student360Fees(
            has_data=False,
            total_assigned=0.0,
            total_paid=0.0,
            balance_outstanding=0.0,
            paid_percentage=None,
            status="No fee records"
        )
    else:
        total_assigned = sum(float(a.assigned_amount) for a in assignments)
        total_paid = sum(float(p.amount_paid) for p in payments)
        balance = total_assigned - total_paid
        paid_pct = round((total_paid / total_assigned) * 100, 1) if total_assigned > 0 else (100.0 if total_paid > 0 else None)

        if total_assigned > 0 and balance <= 0:
            status_str = "Cleared"
        elif total_paid > 0:
            status_str = "Partial"
        elif total_assigned > 0:
            status_str = "Pending"
        else:
            status_str = "No fee records"

        fees_data = Student360Fees(
            has_data=True,
            total_assigned=total_assigned,
            total_paid=total_paid,
            balance_outstanding=max(balance, 0.0),
            paid_percentage=paid_pct,
            status=status_str
        )

    # 4. AI Analytics State Machine
    has_att = attendance_data.has_data and attendance_data.total_days > 0
    has_acad = academics_data.has_data and len(academics_data.completed_examinations) > 0

    if not has_att and not has_acad:
        ai_data = Student360AiAnalysis(
            has_data=False,
            data_state="NO_DATA",
            trend=None,
            headline=None,
            insight="No attendance or academic records found for this student.",
            strong_highlights=[],
            support_highlights=[],
            action_recommendation=None,
            status_message="Insufficient data for AI analysis"
        )
    elif not has_att and has_acad:
        strong = [s.subject for s in academics_data.subject_scores if s.strong]
        needs = [s.subject for s in academics_data.subject_scores if s.needs_support]
        ai_data = Student360AiAnalysis(
            has_data=True,
            data_state="PARTIAL_DATA",
            trend="improving" if (academics_data.current_score or 0) >= 70 else "declining",
            headline=f"Academic performance recorded at {academics_data.current_score}%.",
            insight="Academic marks are available, but attendance records have not been submitted for this student yet.",
            strong_highlights=strong,
            support_highlights=needs,
            action_recommendation="Record class attendance to enable comprehensive correlation between attendance and performance.",
            status_message="Partial data: Attendance records pending"
        )
    elif has_att and not has_acad:
        ai_data = Student360AiAnalysis(
            has_data=True,
            data_state="PARTIAL_DATA",
            trend="improving" if (attendance_data.attendance_rate or 0) >= 75 else "declining",
            headline=f"Attendance rate stands at {attendance_data.attendance_rate}%.",
            insight=f"Student has attended {attendance_data.present_days} of {attendance_data.total_days} recorded sessions. No completed examination marks recorded yet.",
            strong_highlights=[],
            support_highlights=[],
            action_recommendation="Awaiting completed examination results to evaluate academic trajectory.",
            status_message="Partial data: Academic examination results pending"
        )
    else:
        # Both attendance and academic data are present
        trend = "improving" if (academics_data.current_score or 0) >= 70 and (attendance_data.attendance_rate or 0) >= 75 else "declining"
        strong = [s.subject for s in academics_data.subject_scores if s.strong]
        needs = [s.subject for s in academics_data.subject_scores if s.needs_support]

        recommendations = []
        if needs:
            recommendations.append(f"Focus targeted intervention on {', '.join(needs)}.")
        if (attendance_data.attendance_rate or 0) < 75:
            recommendations.append("Address attendance consistency to prevent learning gaps.")
        elif strong:
            recommendations.append(f"Maintain excellence in {', '.join(strong)} while reinforcing foundational topics.")
        else:
            recommendations.append("Continue regular revision and scheduled homework assignments.")

        ai_data = Student360AiAnalysis(
            has_data=True,
            data_state="SUFFICIENT_DATA",
            trend=trend,
            headline=f"{student.first_name}'s academic score stands at {academics_data.current_score}% with {attendance_data.attendance_rate}% attendance.",
            insight=f"Consolidated performance across {len(academics_data.completed_examinations)} completed examination(s) and {attendance_data.total_days} attendance sessions.",
            strong_highlights=strong,
            support_highlights=needs,
            action_recommendation=" ".join(recommendations),
            status_message=None
        )

    # 5. Homework
    homework_items = []
    if student.class_id and student.section_id:
        stmt_hw = select(Homework).where(
            Homework.school_id == school_id,
            Homework.tenant_id == tenant_id,
            Homework.class_id == student.class_id,
            Homework.section_id == student.section_id,
            Homework.deleted_at.is_(None)
        ).options(
            selectinload(Homework.subject)
        ).order_by(Homework.created_at.desc()).limit(10)
        res_hw = await service.student_repo.db.execute(stmt_hw)
        homework_objs = res_hw.scalars().all()

        homework_items = [
            HomeworkItem(
                title=h.title,
                subject=h.subject.subject_name if h.subject else "General",
                status=h.status.value if hasattr(h.status, "value") else str(h.status),
                date=h.due_date.strftime("%d %b %Y") if h.due_date else "No due date"
            )
            for h in homework_objs
        ]

    # 6. Activity Logs (Real events only)
    logs: List[StudentActivityLogItem] = []
    adm_date = student.admission_date.strftime("%d %b %Y") if student.admission_date else "Initial Registration"
    c_name = student.class_obj.name if student.class_obj else "Class"
    s_name = student.section.name if student.section else "Section"
    logs.append(StudentActivityLogItem(
        time=adm_date,
        event=f"Enrolled in {c_name} - {s_name}",
        by="Admin Portal"
    ))
    for p in payments[:3]:
        p_date = p.payment_date.strftime("%d %b %Y") if hasattr(p, "payment_date") and p.payment_date else "Recent"
        p_no = getattr(p, "transaction_reference", None) or f"REC-{str(p.id)[:8].upper()}"
        logs.append(StudentActivityLogItem(
            time=p_date,
            event=f"Tuition Fee Receipt {p_no} Logged (₹ {p.amount_paid:,.0f})",
            by="Accounts Desk"
        ))
    if completed_marks:
        latest_mark = max(completed_marks, key=lambda m: m.created_at or datetime.min)
        m_date = latest_mark.created_at.strftime("%d %b %Y") if latest_mark.created_at else "Recent"
        logs.append(StudentActivityLogItem(
            time=m_date,
            event="Examination Marks Published",
            by="Academic Controller"
        ))

    # 7. Authoritative Report Cards
    stmt_rc = select(ReportCardPublication).where(
        ReportCardPublication.student_id == id,
        ReportCardPublication.school_id == school_id,
        ReportCardPublication.tenant_id == tenant_id,
        ReportCardPublication.deleted_at.is_(None)
    ).order_by(ReportCardPublication.created_at.desc())
    res_rc = await service.student_repo.db.execute(stmt_rc)
    rc_records = res_rc.scalars().all()

    report_items = []
    for rc in rc_records:
        title = "Annual Consolidated Report Card 2026-2027"
        report_items.append(Student360ReportCard(
            id=rc.id,
            title=title,
            status=rc.status.value if hasattr(rc.status, "value") else str(rc.status),
            generated_date=rc.generated_at.strftime("%d %b %Y") if rc.generated_at else None,
            published_date=rc.published_at.strftime("%d %b %Y") if rc.published_at else None,
            is_available=bool(rc.pdf_url),
            pdf_url=rc.pdf_url
        ))

    return APIResponse[StudentAnalyticsResponse](
        success=True,
        message="Student 360 analytics computed successfully.",
        data=StudentAnalyticsResponse(
            student_id=id,
            school_id=school_id,
            academic_year_id=student.academic_year_id,
            attendance=attendance_data,
            academics=academics_data,
            fees=fees_data,
            ai_analysis=ai_data,
            homework=homework_items,
            activity_logs=logs,
            reports=report_items
        )
    )


@router.post(
    "/{id}/photo",
    response_model=APIResponse[StudentResponse],
    status_code=status.HTTP_200_OK,
    summary="Upload or update student profile photo",
    description="Uploads a student profile picture (PNG, JPG, JPEG, WebP) within tenant and school scope."
)
async def upload_student_photo(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    file: UploadFile = File(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("student.update")),
    service: StudentService = Depends(get_student_service),
    storage_service: StorageService = Depends(get_storage_service)
) -> APIResponse[StudentResponse]:
    """
    Uploads, normalizes, and replaces a student's profile photo with format, integrity, and size validation.
    """
    await verify_school_access(current_user, school_id, service.student_repo.db)

    student = await service.student_repo.get_by_id(id, school_id, tenant_id)
    if not student:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student not found."
        )

    contents = await file.read()
    file_size = len(contents)
    max_size = 5 * 1024 * 1024
    if file_size > max_size:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Profile photo must be smaller than 5 MB."
        )
    if file_size == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty."
        )

    filename = file.filename or "photo.png"
    ext = os.path.splitext(filename)[1].lower().strip(".")
    allowed_exts = {"png", "jpg", "jpeg", "webp"}
    if ext not in allowed_exts:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please upload a PNG, JPG, JPEG or WEBP image."
        )

    allowed_mimes = {"image/png", "image/jpeg", "image/pjpeg", "image/webp"}
    if file.content_type and file.content_type.lower() not in allowed_mimes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please upload a PNG, JPG, JPEG or WEBP image."
        )

    try:
        verify_img = PILImage.open(io.BytesIO(contents))
        verify_img.verify()
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid image file or corrupted image data."
        )

    try:
        proc_img = PILImage.open(io.BytesIO(contents))
        max_dim = 512
        if proc_img.width > max_dim or proc_img.height > max_dim:
            proc_img.thumbnail((max_dim, max_dim), PILImage.Resampling.LANCZOS)

        out_buf = io.BytesIO()
        ext_clean = ext.lower()
        if ext_clean == "png":
            proc_img.save(out_buf, format="PNG", optimize=True)
            upload_content_type = "image/png"
        elif ext_clean in ("jpg", "jpeg"):
            if proc_img.mode in ("RGBA", "LA", "P"):
                rgb_img = PILImage.new("RGB", proc_img.size, (255, 255, 255))
                mask = proc_img.split()[-1] if proc_img.mode == "RGBA" else None
                rgb_img.paste(proc_img, mask=mask)
                proc_img = rgb_img
            proc_img.save(out_buf, format="JPEG", quality=90, optimize=True)
            upload_content_type = "image/jpeg"
        elif ext_clean == "webp":
            proc_img.save(out_buf, format="WEBP", quality=90)
            upload_content_type = "image/webp"
        else:
            proc_img.save(out_buf, format="PNG", optimize=True)
            upload_content_type = "image/png"

        processed_bytes = out_buf.getvalue()
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Image processing failed: {e}"
        )

    old_key = None
    if student.settings and isinstance(student.settings, dict):
        old_key = student.settings.get("photo_storage_key")
    if not old_key and student.photo_url and not student.photo_url.startswith("http") and not student.photo_url.startswith("/api"):
        old_key = student.photo_url

    if old_key:
        try:
            await storage_service.delete(old_key)
        except Exception:
            pass

    storage_path = f"tenants/{tenant_id}/schools/{school_id}/students/{id}/photo/{uuid.uuid4().hex}.{ext_clean}"
    await storage_service.upload(processed_bytes, storage_path, content_type=upload_content_type)

    relative_url = f"/api/v1/students/{id}/photo?school_id={school_id}"
    updated_student = await service.update_photo(
        tenant_id=tenant_id,
        school_id=school_id,
        student_id=id,
        photo_url=relative_url,
        photo_storage_key=storage_path
    )
    return APIResponse[StudentResponse](
        success=True,
        message="Student photo uploaded successfully.",
        data=StudentResponse.model_validate(updated_student)
    )


@router.delete(
    "/{id}/photo",
    response_model=APIResponse[StudentResponse],
    status_code=status.HTTP_200_OK,
    summary="Remove student profile photo",
    description="Deletes the profile photo associated with the student."
)
async def delete_student_photo(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("student.update")),
    service: StudentService = Depends(get_student_service),
    storage_service: StorageService = Depends(get_storage_service)
) -> APIResponse[StudentResponse]:
    """
    Deletes the profile photo of a student and removes stored assets.
    """
    await verify_school_access(current_user, school_id, service.student_repo.db)

    student = await service.student_repo.get_by_id(id, school_id, tenant_id)
    if not student:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student not found."
        )

    old_key = None
    if student.settings and isinstance(student.settings, dict):
        old_key = student.settings.get("photo_storage_key")
    if not old_key and student.photo_url and not student.photo_url.startswith("http") and not student.photo_url.startswith("/api"):
        old_key = student.photo_url

    if old_key:
        try:
            await storage_service.delete(old_key)
        except Exception:
            pass

    updated_student = await service.update_photo(
        tenant_id=tenant_id,
        school_id=school_id,
        student_id=id,
        photo_url=None,
        photo_storage_key=None
    )
    return APIResponse[StudentResponse](
        success=True,
        message="Student photo removed successfully.",
        data=StudentResponse.model_validate(updated_student)
    )


@router.get(
    "/{id}/photo",
    summary="Get student profile photo",
    description="Streams the student profile photo image with authenticated access, MIME detection, and caching headers."
)
async def get_student_photo(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: Any = Depends(get_current_user),
    service: StudentService = Depends(get_student_service),
    storage_service: StorageService = Depends(get_storage_service)
) -> Response:
    """
    Streams the student profile photo with authenticated access, MIME detection, and caching headers.
    """
    await verify_school_access(current_user, school_id, service.student_repo.db)

    student = await service.student_repo.get_by_id(id, school_id, tenant_id)
    if not student:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student not found."
        )

    storage_key = None
    if student.settings and isinstance(student.settings, dict):
        storage_key = student.settings.get("photo_storage_key")
    if not storage_key and student.photo_url and not student.photo_url.startswith("http") and not student.photo_url.startswith("/api"):
        storage_key = student.photo_url

    if not storage_key:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student does not have a profile photo."
        )

    try:
        photo_bytes = await storage_service.download(storage_key)
    except FileNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student photo file not found in storage."
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Unable to read student photo: {e}"
        )

    ext = os.path.splitext(storage_key)[1].lower().strip(".")
    mime_map = {
        "png": "image/png",
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "webp": "image/webp"
    }
    media_type = mime_map.get(ext, "image/png")

    photo_time = student.settings.get("photo_updated_at") if student.settings else None
    etag = f'"{hash(photo_time or storage_key)}"'

    return Response(
        content=photo_bytes,
        media_type=media_type,
        headers={
            "Cache-Control": "private, max-age=86400",
            "ETag": etag,
        }
    )

