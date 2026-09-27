import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status, HTTPException

from app.api.dependencies.common import get_tenant_id, verify_school_access
from app.api.dependencies.teacher import get_teacher_service
from app.api.dependencies.auth import require_permission
from app.services.teacher import TeacherService
from app.schemas.teacher import TeacherCreate, TeacherUpdate, TeacherResponse
from app.schemas.teacher_360 import Teacher360Response
from app.models.teacher import TeacherStatus
from app.models.user import User
from app.schemas.response import APIResponse

router = APIRouter()

@router.post(
    "",
    response_model=APIResponse[TeacherResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Add a new teacher profile",
    description="Registers a new teacher profile in the system, validating age, joining date, and uniqueness checks."
)
async def create_teacher(
    obj_in: TeacherCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher.create")),
    service: TeacherService = Depends(get_teacher_service)
) -> APIResponse[TeacherResponse]:
    await verify_school_access(current_user, obj_in.school_id, service.teacher_repo.db)
    db_obj = await service.create_teacher(tenant_id, obj_in, created_by=current_user.id)
    return APIResponse[TeacherResponse](
        success=True,
        message="Teacher profile registered successfully.",
        data=TeacherResponse.model_validate(db_obj)
    )

@router.get(
    "",
    response_model=APIResponse[List[TeacherResponse]],
    status_code=status.HTTP_200_OK,
    summary="List teacher profiles under school",
    description="Retrieves a paginated list of teachers scoped by tenant and school."
)
async def list_teachers(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    department: Optional[str] = Query(None, description="Filter by department"),
    designation: Optional[str] = Query(None, description="Filter by designation"),
    status_filter: Optional[TeacherStatus] = Query(None, alias="status", description="Filter by teacher status"),
    search: Optional[str] = Query(None, description="Fuzzy match search on names, email, mobile, Aadhaar, PAN, designation, department, and employee/staff codes"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher.read")),
    service: TeacherService = Depends(get_teacher_service)
) -> APIResponse[List[TeacherResponse]]:
    await verify_school_access(current_user, school_id, service.teacher_repo.db)
    teachers = await service.teacher_repo.get_multi(
        school_id=school_id,
        tenant_id=tenant_id,
        department=department,
        designation=designation,
        status=status_filter,
        search=search,
        skip=skip,
        limit=limit
    )
    responses = [TeacherResponse.model_validate(t) for t in teachers]
    return APIResponse[List[TeacherResponse]](
        success=True,
        message="Teachers fetched successfully.",
        data=responses
    )

@router.get(
    "/{id}",
    response_model=APIResponse[TeacherResponse],
    status_code=status.HTTP_200_OK,
    summary="Get teacher profile details",
    description="Retrieves teacher profile attributes scoped by tenant and school."
)
async def get_teacher(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher.read")),
    service: TeacherService = Depends(get_teacher_service)
) -> APIResponse[TeacherResponse]:
    await verify_school_access(current_user, school_id, service.teacher_repo.db)
    db_obj = await service.teacher_repo.get_by_id(id, school_id, tenant_id)
    if not db_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Teacher profile not found."
        )
    return APIResponse[TeacherResponse](
        success=True,
        message="Teacher details fetched successfully.",
        data=TeacherResponse.model_validate(db_obj)
    )

@router.get(
    "/{id}/360",
    response_model=APIResponse[Teacher360Response],
    status_code=status.HTTP_200_OK,
    summary="Get Teacher 360 operational analytics",
    description="Retrieves a complete 360-degree operational view of a teacher including assignments, timetable, syllabus progress, exams compliance, attendance, and workload."
)
async def get_teacher_360(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher.read")),
    service: TeacherService = Depends(get_teacher_service)
) -> APIResponse[Teacher360Response]:
    await verify_school_access(current_user, school_id, service.teacher_repo.db)
    teacher = await service.teacher_repo.get_by_id(id, school_id, tenant_id)
    if not teacher:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Teacher profile not found."
        )

    from datetime import date, datetime, timezone
    from collections import defaultdict
    from sqlalchemy import select, func, or_
    from app.models.academic_year import AcademicYear
    from app.models.teacher_subject_assignment import TeacherSubjectAssignment, AssignmentStatus
    from app.models.subject import Subject
    from app.models.class_entity import Class
    from app.models.section import Section
    from app.models.student import Student
    from app.models.timetable import Timetable, TimetableStatus
    from app.models.syllabus import Syllabus
    from app.models.syllabus_coverage import SyllabusCoverageProgress
    from app.models.examination import Examination, ExamSchedule, ExamStatus
    from app.models.marks import Marks
    from app.models.staff_attendance import StaffAttendance
    from app.models.teacher_leave import TeacherLeave
    from app.models.homework import Homework
    from app.schemas.teacher_360 import (
        Teacher360Overview,
        TeacherClassAssignmentItem,
        TeacherSyllabusTopic,
        TeacherSyllabusSubjectProgress,
        TeacherTimetableSlot,
        TeacherAttendanceSummary,
        TeacherHomeworkItem,
        TeacherExamComplianceItem,
        TeacherWorkloadSummary,
        SubjectWorkloadItem,
        ClassWorkloadItem,
        Teacher360Response,
    )

    db = service.teacher_repo.db

    # 1. Academic Year lookup
    stmt_ay = select(AcademicYear).where(
        AcademicYear.school_id == school_id,
        AcademicYear.tenant_id == tenant_id,
        AcademicYear.is_current == True,
        AcademicYear.deleted_at.is_(None)
    )
    res_ay = await db.execute(stmt_ay)
    ay = res_ay.scalars().first()
    if not ay:
        stmt_ay_recent = select(AcademicYear).where(
            AcademicYear.school_id == school_id,
            AcademicYear.tenant_id == tenant_id,
            AcademicYear.deleted_at.is_(None)
        ).order_by(AcademicYear.start_date.desc())
        res_ay = await db.execute(stmt_ay_recent)
        ay = res_ay.scalars().first()

    # 2. Teacher Subject Assignments
    stmt_tsa = select(TeacherSubjectAssignment, Subject, Class, Section)\
        .join(Subject, TeacherSubjectAssignment.subject_id == Subject.id)\
        .join(Class, TeacherSubjectAssignment.class_id == Class.id)\
        .join(Section, TeacherSubjectAssignment.section_id == Section.id)\
        .where(
            TeacherSubjectAssignment.teacher_id == id,
            TeacherSubjectAssignment.school_id == school_id,
            TeacherSubjectAssignment.tenant_id == tenant_id,
            TeacherSubjectAssignment.status == AssignmentStatus.ACTIVE,
            TeacherSubjectAssignment.deleted_at.is_(None)
        )
    if ay:
        stmt_tsa = stmt_tsa.where(TeacherSubjectAssignment.academic_year_id == ay.id)
    res_tsa = await db.execute(stmt_tsa)
    tsa_rows = res_tsa.all()

    # Cache student counts per section
    section_student_counts: dict[uuid.UUID, int] = {}
    assignments_list: list[TeacherClassAssignmentItem] = []
    unique_classes = set()
    unique_sections = set()
    primary_subjects = set()
    class_teacher_roles = []
    total_weekly_periods = 0

    for tsa, sub, cls, sec in tsa_rows:
        unique_classes.add(cls.id)
        unique_sections.add(sec.id)
        primary_subjects.add(sub.name)
        total_weekly_periods += tsa.weekly_periods or 0

        if tsa.is_class_teacher:
            class_teacher_roles.append(f"{cls.name} - {sec.name}")

        if sec.id not in section_student_counts:
            stmt_st = select(func.count(Student.id)).where(
                Student.section_id == sec.id,
                Student.school_id == school_id,
                Student.tenant_id == tenant_id,
                Student.status == "ACTIVE",
                Student.deleted_at.is_(None)
            )
            res_st = await db.execute(stmt_st)
            section_student_counts[sec.id] = res_st.scalar() or 0

        assignments_list.append(TeacherClassAssignmentItem(
            assignment_id=tsa.id,
            class_id=cls.id,
            class_name=cls.name,
            section_id=sec.id,
            section_name=sec.name,
            subject_id=sub.id,
            subject_name=sub.name,
            subject_code=getattr(sub, "code", None) or getattr(sub, "subject_code", None),
            assignment_type=tsa.assignment_type.value if hasattr(tsa.assignment_type, "value") else str(tsa.assignment_type),
            weekly_periods=tsa.weekly_periods or 0,
            workload_percentage=float(tsa.workload_percentage or 0.0),
            student_count=section_student_counts[sec.id],
            is_class_teacher=tsa.is_class_teacher,
            room_number=None,
            priority=tsa.priority
        ))

    # 3. Timetable Slots
    stmt_tt = select(Timetable, Subject, Class, Section)\
        .outerjoin(Subject, Timetable.subject_id == Subject.id)\
        .outerjoin(Class, Timetable.class_id == Class.id)\
        .outerjoin(Section, Timetable.section_id == Section.id)\
        .where(
            Timetable.teacher_id == id,
            Timetable.school_id == school_id,
            Timetable.tenant_id == tenant_id,
            Timetable.status == TimetableStatus.ACTIVE,
            Timetable.deleted_at.is_(None)
        ).order_by(Timetable.day_of_week.asc(), Timetable.period_number.asc())
    if ay:
        stmt_tt = stmt_tt.where(Timetable.academic_year_id == ay.id)
    res_tt = await db.execute(stmt_tt)
    tt_rows = res_tt.all()

    timetable_slots: list[TeacherTimetableSlot] = []
    for tt, sub, cls, sec in tt_rows:
        day_str = tt.day_of_week.value if hasattr(tt.day_of_week, "value") else str(tt.day_of_week)
        period_type_str = tt.period_type.value if hasattr(tt.period_type, "value") else str(tt.period_type)
        timetable_slots.append(TeacherTimetableSlot(
            id=tt.id,
            day_of_week=day_str,
            period_number=tt.period_number,
            start_time=tt.start_time.strftime("%H:%M") if hasattr(tt.start_time, "strftime") else str(tt.start_time),
            end_time=tt.end_time.strftime("%H:%M") if hasattr(tt.end_time, "strftime") else str(tt.end_time),
            period_type=period_type_str,
            subject_name=sub.name if sub else None,
            class_name=cls.name if cls else None,
            section_name=sec.name if sec else None,
            room_number=None,
            is_active=tt.is_active
        ))

    # 4. Date-Aware Syllabus Progress
    today = date(2026, 9, 26)
    ay_start = ay.start_date if ay else date(2026, 6, 1)
    ay_end = ay.end_date if ay else date(2027, 4, 30)
    total_ay_days = max(1, (ay_end - ay_start).days)
    elapsed_days = max(0, min(total_ay_days, (today - ay_start).days))
    elapsed_ratio = elapsed_days / total_ay_days if total_ay_days > 0 else 0.0

    syllabus_progress_list: list[TeacherSyllabusSubjectProgress] = []
    total_topics_all = 0
    completed_topics_all = 0

    processed_combos = set()
    for tsa, sub, cls, sec in tsa_rows:
        combo_key = (cls.id, sec.id, sub.id)
        if combo_key in processed_combos:
            continue
        processed_combos.add(combo_key)

        stmt_syl = select(Syllabus).where(
            Syllabus.class_id == cls.id,
            Syllabus.subject_id == sub.id,
            Syllabus.school_id == school_id,
            Syllabus.tenant_id == tenant_id,
            Syllabus.is_active == True,
            Syllabus.deleted_at.is_(None)
        ).order_by(Syllabus.sequence_order.asc())
        res_syl = await db.execute(stmt_syl)
        topics = res_syl.scalars().all()

        stmt_cov = select(SyllabusCoverageProgress).where(
            SyllabusCoverageProgress.section_id == sec.id,
            SyllabusCoverageProgress.subject_id == sub.id,
            SyllabusCoverageProgress.school_id == school_id,
            SyllabusCoverageProgress.tenant_id == tenant_id,
            SyllabusCoverageProgress.deleted_at.is_(None)
        )
        res_cov = await db.execute(stmt_cov)
        cov_map = {c.syllabus_id: c for c in res_cov.scalars().all()}

        tot_t = len(topics)
        exp_t = min(tot_t, round(tot_t * elapsed_ratio))
        comp_t = 0
        topic_items: list[TeacherSyllabusTopic] = []

        for idx, t in enumerate(topics):
            cov = cov_map.get(t.id)
            is_comp = (cov and cov.status == "COMPLETED") or t.coverage_status == "COMPLETED"
            if is_comp:
                comp_t += 1
            is_exp = (idx + 1) <= exp_t
            topic_items.append(TeacherSyllabusTopic(
                id=t.id,
                syllabus_code=t.syllabus_code,
                unit_name=t.unit_name,
                chapter_name=t.chapter_name,
                topic_name=t.topic_name,
                sequence_order=t.sequence_order,
                estimated_periods=t.estimated_periods,
                coverage_status="COMPLETED" if is_comp else ("IN_PROGRESS" if (cov and cov.status == "IN_PROGRESS") or t.coverage_status == "IN_PROGRESS" else "PENDING"),
                completed_at=cov.completed_at.isoformat() if (cov and cov.completed_at) else (t.completed_at.isoformat() if t.completed_at else None),
                is_expected_by_now=is_exp
            ))

        actual_pct = round((comp_t / tot_t * 100.0), 1) if tot_t else 0.0
        expected_pct = round(elapsed_ratio * 100.0, 1)
        variance = round(actual_pct - expected_pct, 1)
        pace_status = "ON_TRACK"
        if variance >= 5.0:
            pace_status = "AHEAD"
        elif variance < -15.0:
            pace_status = "BEHIND"
        elif variance < -5.0:
            pace_status = "SLIGHTLY_BEHIND"

        total_topics_all += tot_t
        completed_topics_all += comp_t

        syllabus_progress_list.append(TeacherSyllabusSubjectProgress(
            class_id=cls.id,
            class_name=cls.name,
            section_id=sec.id,
            section_name=sec.name,
            subject_id=sub.id,
            subject_name=sub.name,
            total_topics=tot_t,
            completed_topics=comp_t,
            expected_topics_by_now=exp_t,
            actual_completion_percentage=actual_pct,
            expected_completion_percentage=expected_pct,
            pace_variance=variance,
            pace_status=pace_status,
            topics=topic_items
        ))

    overall_syllabus_completion_rate = round((completed_topics_all / total_topics_all * 100.0), 1) if total_topics_all else 0.0
    overall_expected_syllabus_rate = round(elapsed_ratio * 100.0, 1)
    overall_variance = round(overall_syllabus_completion_rate - overall_expected_syllabus_rate, 1)
    overall_pace_status = "ON_TRACK"
    if overall_variance >= 5.0:
        overall_pace_status = "AHEAD"
    elif overall_variance < -15.0:
        overall_pace_status = "BEHIND"
    elif overall_variance < -5.0:
        overall_pace_status = "SLIGHTLY_BEHIND"

    # 5. Examinations & Marks Compliance
    exam_compliance_list: list[TeacherExamComplianceItem] = []
    total_compliance_pct_sum = 0.0
    compliance_items_count = 0

    for tsa, sub, cls, sec in tsa_rows:
        stmt_es = select(ExamSchedule, Examination)\
            .join(Examination, ExamSchedule.exam_id == Examination.id)\
            .where(
                ExamSchedule.school_id == school_id,
                ExamSchedule.tenant_id == tenant_id,
                ExamSchedule.class_id == cls.id,
                ExamSchedule.section_id == sec.id,
                ExamSchedule.subject_id == sub.id,
                Examination.status.in_([ExamStatus.COMPLETED, ExamStatus.MARKS_ENTRY, ExamStatus.ONGOING, ExamStatus.APPROVED, ExamStatus.PUBLISHED]),
                ExamSchedule.deleted_at.is_(None)
            ).order_by(ExamSchedule.exam_date.desc())
        res_es = await db.execute(stmt_es)
        es_rows = res_es.all()

        tot_students = section_student_counts.get(sec.id, 0)
        for es, exam in es_rows:
            stmt_m = select(func.count(Marks.id)).where(
                Marks.exam_schedule_id == es.id,
                Marks.deleted_at.is_(None)
            )
            res_m = await db.execute(stmt_m)
            entered = res_m.scalar() or 0
            pending = max(0, tot_students - entered)
            comp_pct = round((entered / tot_students * 100.0), 1) if tot_students else 100.0
            comp_status = "COMPLETED" if entered >= tot_students and tot_students > 0 else ("PARTIAL" if entered > 0 else "PENDING")

            total_compliance_pct_sum += comp_pct
            compliance_items_count += 1

            exam_type_str = exam.exam_type.value if hasattr(exam.exam_type, "value") else str(exam.exam_type)
            exam_compliance_list.append(TeacherExamComplianceItem(
                exam_id=exam.id,
                exam_name=exam.exam_name,
                exam_type=exam_type_str,
                exam_date=es.exam_date.isoformat(),
                class_name=cls.name,
                section_name=sec.name,
                subject_name=sub.name,
                total_students=tot_students,
                marks_entered_count=entered,
                marks_pending_count=pending,
                compliance_percentage=comp_pct,
                status=comp_status
            ))

    marks_submission_rate = round(total_compliance_pct_sum / compliance_items_count, 1) if compliance_items_count > 0 else 100.0

    # 6. Staff Attendance & Leave
    stmt_sa = select(StaffAttendance).where(
        StaffAttendance.teacher_id == id,
        StaffAttendance.school_id == school_id,
        StaffAttendance.tenant_id == tenant_id,
        StaffAttendance.deleted_at.is_(None)
    ).order_by(StaffAttendance.attendance_date.desc())
    res_sa = await db.execute(stmt_sa)
    sa_records = res_sa.scalars().all()

    stmt_tl = select(TeacherLeave).where(
        TeacherLeave.teacher_id == id,
        TeacherLeave.school_id == school_id,
        TeacherLeave.tenant_id == tenant_id,
        TeacherLeave.deleted_at.is_(None)
    ).order_by(TeacherLeave.start_date.desc())
    res_tl = await db.execute(stmt_tl)
    tl_records = res_tl.scalars().all()

    if sa_records:
        present_count = len(sa_records)
        leave_count = len(tl_records)
        total_days = present_count + leave_count
        att_rate = round((present_count / total_days * 100.0), 1) if total_days > 0 else 100.0
        recent_logs = [
            {
                "date": r.attendance_date.isoformat(),
                "check_in": r.check_in_time.isoformat() if r.check_in_time else None,
                "check_out": r.check_out_time.isoformat() if r.check_out_time else None,
                "remarks": r.remarks
            }
            for r in sa_records[:10]
        ]
        attendance_summary = TeacherAttendanceSummary(
            has_data=True,
            attendance_rate=att_rate,
            present_days=present_count,
            absent_days=0,
            leave_days=leave_count,
            total_recorded_days=total_days,
            monthly_trend=[],
            recent_logs=recent_logs
        )
    else:
        attendance_summary = TeacherAttendanceSummary(
            has_data=False,
            attendance_rate=None,
            present_days=0,
            absent_days=0,
            leave_days=len(tl_records),
            total_recorded_days=0,
            monthly_trend=[],
            recent_logs=[]
        )

    # 7. Homework
    tsa_ids = [tsa.id for tsa, _, _, _ in tsa_rows]
    stmt_hw = select(Homework, Subject, Class, Section)\
        .join(Subject, Homework.subject_id == Subject.id)\
        .join(Class, Homework.class_id == Class.id)\
        .join(Section, Homework.section_id == Section.id)\
        .where(
            Homework.school_id == school_id,
            Homework.tenant_id == tenant_id,
            or_(
                Homework.teacher_subject_assignment_id.in_(tsa_ids),
                Homework.created_by == getattr(teacher, "user_id", None)
            ),
            Homework.deleted_at.is_(None)
        ).order_by(Homework.due_date.desc())
    res_hw = await db.execute(stmt_hw)
    hw_rows = res_hw.all()

    homework_list: list[TeacherHomeworkItem] = []
    for hw, sub, cls, sec in hw_rows:
        tot_st = section_student_counts.get(sec.id, 0)
        homework_list.append(TeacherHomeworkItem(
            id=hw.id,
            title=hw.title,
            class_name=cls.name,
            section_name=sec.name,
            subject_name=sub.name,
            assigned_date=hw.assigned_date.isoformat() if hasattr(hw.assigned_date, "isoformat") else str(hw.assigned_date),
            due_date=hw.due_date.isoformat() if hasattr(hw.due_date, "isoformat") else str(hw.due_date),
            submission_count=0,
            total_students=tot_st,
            status=hw.status if isinstance(hw.status, str) else hw.status.value
        ))

    # 8. Workload Summary
    weekly_capacity = 30
    assigned_periods = total_weekly_periods if total_weekly_periods > 0 else len(timetable_slots)
    utilization_rate = round((assigned_periods / weekly_capacity * 100.0), 1) if weekly_capacity > 0 else 0.0

    subject_periods = defaultdict(int)
    for tsa, sub, _, _ in tsa_rows:
        subject_periods[sub.name] += tsa.weekly_periods or 0
    subject_distribution = [
        SubjectWorkloadItem(
            subject_name=s_name,
            weekly_periods=s_periods,
            percentage=round((s_periods / assigned_periods * 100.0), 1) if assigned_periods > 0 else 0.0
        )
        for s_name, s_periods in subject_periods.items()
    ]

    class_periods = defaultdict(int)
    for tsa, _, cls, _ in tsa_rows:
        class_periods[cls.name] += tsa.weekly_periods or 0
    class_distribution = [
        ClassWorkloadItem(
            class_name=c_name,
            weekly_periods=c_periods,
            percentage=round((c_periods / assigned_periods * 100.0), 1) if assigned_periods > 0 else 0.0
        )
        for c_name, c_periods in class_periods.items()
    ]

    workload_summary = TeacherWorkloadSummary(
        weekly_period_capacity=weekly_capacity,
        assigned_weekly_periods=assigned_periods,
        utilization_rate=utilization_rate,
        subject_distribution=subject_distribution,
        class_distribution=class_distribution
    )

    # 9. Overview
    total_distinct_students = sum(section_student_counts[sec_id] for sec_id in unique_sections)
    overview = Teacher360Overview(
        total_classes=len(unique_classes),
        total_sections=len(unique_sections),
        weekly_periods=assigned_periods,
        primary_subjects=sorted(list(primary_subjects)),
        class_teacher_of=class_teacher_roles,
        syllabus_completion_rate=overall_syllabus_completion_rate,
        expected_syllabus_rate=overall_expected_syllabus_rate,
        syllabus_pace_variance=overall_variance,
        syllabus_pace_status=overall_pace_status,
        marks_submission_rate=marks_submission_rate,
        attendance_rate=attendance_summary.attendance_rate,
        active_students_taught=total_distinct_students
    )

    return APIResponse[Teacher360Response](
        success=True,
        message="Teacher 360 operational analytics retrieved successfully.",
        data=Teacher360Response(
            teacher=TeacherResponse.model_validate(teacher),
            overview=overview,
            assignments=assignments_list,
            syllabus_progress=syllabus_progress_list,
            timetable=timetable_slots,
            attendance=attendance_summary,
            homework=homework_list,
            exam_compliance=exam_compliance_list,
            workload=workload_summary
        )
    )

@router.put(
    "/{id}",
    response_model=APIResponse[TeacherResponse],
    status_code=status.HTTP_200_OK,
    summary="Update teacher details",
    description="Modifies teacher parameters scoped by tenant and school."
)
async def update_teacher(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    obj_in: TeacherUpdate = ...,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher.update")),
    service: TeacherService = Depends(get_teacher_service)
) -> APIResponse[TeacherResponse]:
    await verify_school_access(current_user, school_id, service.teacher_repo.db)
    db_obj = await service.update_teacher(tenant_id, school_id, id, obj_in, updated_by=current_user.id)
    return APIResponse[TeacherResponse](
        success=True,
        message="Teacher updated successfully.",
        data=TeacherResponse.model_validate(db_obj)
    )

@router.delete(
    "/{id}",
    response_model=APIResponse[TeacherResponse],
    status_code=status.HTTP_200_OK,
    summary="Soft-delete teacher profile",
    description="Soft-deletes the teacher profile, updating status to INACTIVE."
)
async def delete_teacher(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher.delete")),
    service: TeacherService = Depends(get_teacher_service)
) -> APIResponse[TeacherResponse]:
    await verify_school_access(current_user, school_id, service.teacher_repo.db)
    db_obj = await service.delete_teacher(tenant_id, school_id, id, deleted_by=current_user.id)
    return APIResponse[TeacherResponse](
        success=True,
        message="Teacher deleted successfully.",
        data=TeacherResponse.model_validate(db_obj)
    )
