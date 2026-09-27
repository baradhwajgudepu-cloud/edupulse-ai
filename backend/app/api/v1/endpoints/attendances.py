import uuid
from typing import List, Optional
from datetime import date
from fastapi import APIRouter, Depends, Query, status, HTTPException, File, UploadFile, Form, Response

from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.attendance import get_attendance_service
from app.api.dependencies.auth import require_permission
from app.services.attendance import AttendanceService
from app.schemas.attendance import (
    AttendanceSessionCreate,
    AttendanceSessionUpdate,
    BulkAttendanceMark,
    AttendanceSessionResponse,
    AttendanceResponse,
    AttendanceCorrectionUpdate,
    DailyAttendanceMarkRequest,
    AttendanceAuditLogResponse,
    AttendanceDashboardStatsResponse,
    BulkAttendanceValidateResponse,
    BulkAttendanceImportRequest,
    BulkAttendanceImportResponse,
    BulkAttendanceChunkRequest,
    BulkAttendanceChunkResponse,
    AttendanceImportJobResponse,
    AttendanceImportRecordRequest,
    AttendanceAlertResponse,
)
from app.models.attendance import AttendanceSessionStatus, AttendanceStatus, AttendanceSessionType, AttendanceAction
from app.models.user import User
from app.schemas.response import APIResponse

router = APIRouter()

# ==================================================
# Attendance Session Endpoints
# ==================================================

@router.post(
    "/session",
    response_model=APIResponse[AttendanceSessionResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create a new attendance session",
    description="Registers a new attendance marking session for a class, section, date, and timetable period slot."
)
async def create_session(
    obj_in: AttendanceSessionCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("attendance.create")),
    service: AttendanceService = Depends(get_attendance_service)
) -> APIResponse[AttendanceSessionResponse]:
    from app.models.timetable import Timetable
    from sqlalchemy import select
    timetable_stmt = select(Timetable).where(Timetable.id == obj_in.timetable_id)
    timetable_res = await service.attendance_repo.db.execute(timetable_stmt)
    timetable = timetable_res.scalar_one_or_none()
    if not timetable:
        raise HTTPException(status_code=422, detail="Timetable slot not found.")
        
    role_codes = {r.code for r in current_user.roles}
    is_admin_or_principal = current_user.is_superuser or any(
        code in ["SUPER_ADMIN", "SCHOOL_ADMIN", "PRINCIPAL"] for code in role_codes
    )
    if not is_admin_or_principal and "TEACHER" in role_codes:
        from app.repositories.teacher import TeacherRepository
        teacher_repo = TeacherRepository(service.attendance_repo.db)
        teacher = await teacher_repo.get_by_user_id(current_user.id, tenant_id)
        if not teacher or timetable.teacher_id != teacher.id:
            raise HTTPException(status_code=403, detail="You cannot mark attendance for another teacher's class.")

    db_obj = await service.create_session(tenant_id, obj_in, created_by=current_user.id)
    return APIResponse[AttendanceSessionResponse](
        success=True,
        message="Attendance session initiated successfully.",
        data=AttendanceSessionResponse.model_validate(db_obj)
    )

@router.post(
    "/session/{session_id}/mark",
    response_model=APIResponse[AttendanceSessionResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Submit bulk student attendance",
    description="Marks attendance for multiple students under the session in a single database transaction."
)
async def mark_attendance(
    session_id: uuid.UUID,
    obj_in: BulkAttendanceMark,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("attendance.create")),
    service: AttendanceService = Depends(get_attendance_service)
) -> APIResponse[AttendanceSessionResponse]:
    session_obj = await service.attendance_repo.get_session_by_id(session_id, school_id, tenant_id)
    if not session_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Attendance session not found."
        )
        
    role_codes = {r.code for r in current_user.roles}
    is_admin_or_principal = current_user.is_superuser or any(
        code in ["SUPER_ADMIN", "SCHOOL_ADMIN", "PRINCIPAL"] for code in role_codes
    )
    if not is_admin_or_principal and "TEACHER" in role_codes:
        from app.repositories.teacher import TeacherRepository
        teacher_repo = TeacherRepository(service.attendance_repo.db)
        teacher = await teacher_repo.get_by_user_id(current_user.id, tenant_id)
        if not teacher or session_obj.teacher_id != teacher.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You cannot mark attendance for another teacher's session."
            )

    db_obj = await service.bulk_mark_attendance(
        tenant_id=tenant_id,
        school_id=school_id,
        session_id=session_id,
        obj_in=obj_in,
        current_user=current_user
    )
    return APIResponse[AttendanceSessionResponse](
        success=True,
        message="Student attendance marked successfully.",
        data=AttendanceSessionResponse.model_validate(db_obj)
    )

@router.post(
    "/session/{session_id}/lock",
    response_model=APIResponse[AttendanceSessionResponse],
    status_code=status.HTTP_200_OK,
    summary="Lock attendance session",
    description="Locks an attendance session, blocking all future teacher modifications. Only Principal/Admin roles allowed."
)
async def lock_session(
    session_id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("attendance.update")),
    service: AttendanceService = Depends(get_attendance_service)
) -> APIResponse[AttendanceSessionResponse]:
    db_obj = await service.lock_session(
        tenant_id=tenant_id,
        school_id=school_id,
        session_id=session_id,
        current_user=current_user
    )
    return APIResponse[AttendanceSessionResponse](
        success=True,
        message="Attendance session locked successfully.",
        data=AttendanceSessionResponse.model_validate(db_obj)
    )

@router.get(
    "/sessions",
    response_model=APIResponse[List[AttendanceSessionResponse]],
    status_code=status.HTTP_200_OK,
    summary="List attendance sessions",
    description="Retrieves a paginated list of attendance sessions."
)
async def list_sessions(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    academic_year_id: Optional[uuid.UUID] = Query(None, description="Filter by Academic Year ID"),
    class_id: Optional[uuid.UUID] = Query(None, description="Filter by Class ID"),
    section_id: Optional[uuid.UUID] = Query(None, description="Filter by Section ID"),
    attendance_date: Optional[date] = Query(None, description="Filter by Date"),
    status_filter: Optional[AttendanceSessionStatus] = Query(None, alias="status", description="Filter by status"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("attendance.read")),
    service: AttendanceService = Depends(get_attendance_service)
) -> APIResponse[List[AttendanceSessionResponse]]:
    role_codes = {r.code for r in current_user.roles}
    is_admin_or_principal = current_user.is_superuser or any(
        code in ["SUPER_ADMIN", "SCHOOL_ADMIN", "PRINCIPAL"] for code in role_codes
    )
    teacher_id_filter = None
    if not is_admin_or_principal and "TEACHER" in role_codes:
        from app.repositories.teacher import TeacherRepository
        teacher_repo = TeacherRepository(service.attendance_repo.db)
        teacher = await teacher_repo.get_by_user_id(current_user.id, tenant_id)
        if not teacher:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. No active teacher profile found for user."
            )
        teacher_id_filter = teacher.id

    sessions = await service.attendance_repo.get_multi_sessions(
        school_id=school_id,
        tenant_id=tenant_id,
        academic_year_id=academic_year_id,
        class_id=class_id,
        section_id=section_id,
        attendance_date=attendance_date,
        status=status_filter,
        teacher_id=teacher_id_filter,
        skip=skip,
        limit=limit
    )
    responses = [AttendanceSessionResponse.model_validate(s) for s in sessions]
    return APIResponse[List[AttendanceSessionResponse]](
        success=True,
        message="Attendance sessions fetched successfully.",
        data=responses
    )

@router.get(
    "/session/{session_id}",
    response_model=APIResponse[AttendanceSessionResponse],
    status_code=status.HTTP_200_OK,
    summary="Get attendance session details",
    description="Retrieves details of a specific session, including marked student logs."
)
async def get_session(
    session_id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("attendance.read")),
    service: AttendanceService = Depends(get_attendance_service)
) -> APIResponse[AttendanceSessionResponse]:
    db_obj = await service.attendance_repo.get_session_by_id(session_id, school_id, tenant_id)
    if not db_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Attendance session not found."
        )

    role_codes = {r.code for r in current_user.roles}
    is_admin_or_principal = current_user.is_superuser or any(
        code in ["SUPER_ADMIN", "SCHOOL_ADMIN", "PRINCIPAL"] for code in role_codes
    )
    if not is_admin_or_principal and "TEACHER" in role_codes:
        from app.repositories.teacher import TeacherRepository
        teacher_repo = TeacherRepository(service.attendance_repo.db)
        teacher = await teacher_repo.get_by_user_id(current_user.id, tenant_id)
        if not teacher or db_obj.teacher_id != teacher.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. You do not own this attendance session."
            )

    return APIResponse[AttendanceSessionResponse](
        success=True,
        message="Attendance session details fetched successfully.",
        data=AttendanceSessionResponse.model_validate(db_obj)
    )

@router.delete(
    "/session/{session_id}",
    response_model=APIResponse[AttendanceSessionResponse],
    status_code=status.HTTP_200_OK,
    summary="Soft-delete attendance session",
    description="Soft-deletes the session and all child student logs."
)
async def delete_session(
    session_id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("attendance.delete")),
    service: AttendanceService = Depends(get_attendance_service)
) -> APIResponse[AttendanceSessionResponse]:
    db_obj = await service.delete_session(tenant_id, school_id, session_id, deleted_by=current_user.id)
    return APIResponse[AttendanceSessionResponse](
        success=True,
        message="Attendance session deleted successfully.",
        data=AttendanceSessionResponse.model_validate(db_obj)
    )

# ==================================================
# Individual Attendance Log Endpoints
# ==================================================

@router.get(
    "",
    response_model=APIResponse[List[AttendanceResponse]],
    status_code=status.HTTP_200_OK,
    summary="List individual student attendance logs",
    description="Retrieves a paginated list of student attendance entries."
)
async def list_attendances(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    academic_year_id: Optional[uuid.UUID] = Query(None, description="Filter by Academic Year ID"),
    student_id: Optional[uuid.UUID] = Query(None, description="Filter by Student ID"),
    timetable_id: Optional[uuid.UUID] = Query(None, description="Filter by Timetable ID"),
    class_id: Optional[uuid.UUID] = Query(None, description="Filter by Class ID"),
    section_id: Optional[uuid.UUID] = Query(None, description="Filter by Section ID"),
    attendance_date: Optional[date] = Query(None, description="Filter by Date"),
    status_filter: Optional[AttendanceStatus] = Query(None, alias="status", description="Filter by status"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("attendance.read")),
    service: AttendanceService = Depends(get_attendance_service)
) -> APIResponse[List[AttendanceResponse]]:
    entries = await service.attendance_repo.get_multi_attendances(
        school_id=school_id,
        tenant_id=tenant_id,
        academic_year_id=academic_year_id,
        student_id=student_id,
        timetable_id=timetable_id,
        class_id=class_id,
        section_id=section_id,
        attendance_date=attendance_date,
        status=status_filter,
        skip=skip,
        limit=limit
    )
    responses = [AttendanceResponse.model_validate(e) for e in entries]
    return APIResponse[List[AttendanceResponse]](
        success=True,
        message="Student attendance logs fetched successfully.",
        data=responses
    )

@router.get(
    "/student",
    response_model=APIResponse[List[AttendanceResponse]],
    status_code=status.HTTP_200_OK,
    summary="Get student attendance schedule history",
    description="Retrieves active attendance logs mapped to a student in an academic year."
)
async def get_student_schedule(
    student_id: uuid.UUID = Query(..., description="Target student ID"),
    academic_year_id: uuid.UUID = Query(..., description="Target academic year ID"),
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("attendance.read")),
    service: AttendanceService = Depends(get_attendance_service)
) -> APIResponse[List[AttendanceResponse]]:
    role_codes = {r.code for r in current_user.roles}
    is_admin = current_user.is_superuser or any(code in ["SUPER_ADMIN", "ADMIN", "SCHOOL_ADMIN", "PRINCIPAL", "TENANT_ADMIN", "CHAIRMAN"] for code in role_codes)
    if not is_admin and "PARENT" in role_codes:
        from app.models.guardian import Guardian, StudentGuardian
        from sqlalchemy import select, or_
        stmt_guard = select(StudentGuardian).join(Guardian).where(
            StudentGuardian.student_id == student_id,
            StudentGuardian.school_id == school_id,
            StudentGuardian.tenant_id == tenant_id,
            or_(
                Guardian.user_id == current_user.id,
                Guardian.email == current_user.email
            )
        )
        res_guard = await service.attendance_repo.db.execute(stmt_guard)
        if not res_guard.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. You are not a linked guardian of this student."
            )

    entries = await service.attendance_repo.get_student_attendance(student_id, academic_year_id, tenant_id)
    responses = [AttendanceResponse.model_validate(e) for e in entries if e.school_id == school_id]
    return APIResponse[List[AttendanceResponse]](
        success=True,
        message="Student attendance history logs fetched successfully.",
        data=responses
    )

@router.get(
    "/class",
    response_model=APIResponse[List[AttendanceResponse]],
    status_code=status.HTTP_200_OK,
    summary="Get class attendance logs",
    description="Retrieves active attendance logs mapped to a class in an academic year."
)
async def get_class_schedule(
    class_id: uuid.UUID = Query(..., description="Target class ID"),
    academic_year_id: uuid.UUID = Query(..., description="Target academic year ID"),
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("attendance.read")),
    service: AttendanceService = Depends(get_attendance_service)
) -> APIResponse[List[AttendanceResponse]]:
    entries = await service.attendance_repo.get_class_attendance(class_id, academic_year_id, tenant_id)
    responses = [AttendanceResponse.model_validate(e) for e in entries if e.school_id == school_id]
    return APIResponse[List[AttendanceResponse]](
        success=True,
        message="Class attendance logs fetched successfully.",
        data=responses
    )

@router.get(
    "/section",
    response_model=APIResponse[List[AttendanceResponse]],
    status_code=status.HTTP_200_OK,
    summary="Get section attendance logs",
    description="Retrieves active attendance logs mapped to a specific section in an academic year."
)
async def get_section_schedule(
    class_id: uuid.UUID = Query(..., description="Target class ID"),
    section_id: uuid.UUID = Query(..., description="Target section ID"),
    academic_year_id: uuid.UUID = Query(..., description="Target academic year ID"),
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("attendance.read")),
    service: AttendanceService = Depends(get_attendance_service)
) -> APIResponse[List[AttendanceResponse]]:
    entries = await service.attendance_repo.get_section_attendance(class_id, section_id, academic_year_id, tenant_id)
    responses = [AttendanceResponse.model_validate(e) for e in entries if e.school_id == school_id]
    return APIResponse[List[AttendanceResponse]](
        success=True,
        message="Section attendance logs fetched successfully.",
        data=responses
    )

@router.get(
    "/teacher",
    response_model=APIResponse[List[AttendanceResponse]],
    status_code=status.HTTP_200_OK,
    summary="Get teacher marked attendance logs",
    description="Retrieves attendance logs marked by or matching a teacher."
)
async def get_teacher_schedule(
    teacher_id: uuid.UUID = Query(..., description="Target teacher ID"),
    academic_year_id: uuid.UUID = Query(..., description="Target academic year ID"),
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("attendance.read")),
    service: AttendanceService = Depends(get_attendance_service)
) -> APIResponse[List[AttendanceResponse]]:
    role_codes = {r.code for r in current_user.roles}
    is_admin_or_principal = current_user.is_superuser or any(
        code in ["SUPER_ADMIN", "SCHOOL_ADMIN", "PRINCIPAL"] for code in role_codes
    )
    if not is_admin_or_principal and "TEACHER" in role_codes:
        from app.repositories.teacher import TeacherRepository
        teacher_repo = TeacherRepository(service.attendance_repo.db)
        teacher = await teacher_repo.get_by_user_id(current_user.id, tenant_id)
        if not teacher:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. No active teacher profile found for user."
            )
        teacher_id = teacher.id

    entries = await service.attendance_repo.get_teacher_attendance(teacher_id, academic_year_id, tenant_id)
    responses = [AttendanceResponse.model_validate(e) for e in entries if e.school_id == school_id]
    return APIResponse[List[AttendanceResponse]](
        success=True,
        message="Teacher marked attendance logs fetched successfully.",
        data=responses
    )

@router.get(
    "/daily",
    response_model=APIResponse[List[AttendanceResponse]],
    status_code=status.HTTP_200_OK,
    summary="Get daily school attendance logs",
    description="Retrieves attendance logs marked on a specific day in the school."
)
async def get_daily_logs(
    attendance_date: date = Query(..., description="Target date"),
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("attendance.read")),
    service: AttendanceService = Depends(get_attendance_service)
) -> APIResponse[List[AttendanceResponse]]:
    entries = await service.attendance_repo.get_daily_attendance(school_id, attendance_date, tenant_id)
    responses = [AttendanceResponse.model_validate(e) for e in entries]
    return APIResponse[List[AttendanceResponse]](
        success=True,
        message="Daily school attendance logs fetched successfully.",
        data=responses
    )

@router.put(
    "/session/{session_id}/student/{student_id}",
    response_model=APIResponse[AttendanceResponse],
    status_code=status.HTTP_200_OK,
    summary="Correct a student's attendance log",
    description="Updates an individual student's attendance under an unlocked session, adding audit information."
)
async def correct_attendance(
    session_id: uuid.UUID,
    student_id: uuid.UUID,
    obj_in: AttendanceCorrectionUpdate,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("attendance.update")),
    service: AttendanceService = Depends(get_attendance_service)
) -> APIResponse[AttendanceResponse]:
    session_obj = await service.attendance_repo.get_session_by_id(session_id, school_id, tenant_id)
    if not session_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Attendance session not found."
        )

    role_codes = {r.code for r in current_user.roles}
    is_admin_or_principal = current_user.is_superuser or any(
        code in ["SUPER_ADMIN", "SCHOOL_ADMIN", "PRINCIPAL"] for code in role_codes
    )
    if not is_admin_or_principal and "TEACHER" in role_codes:
        from app.repositories.teacher import TeacherRepository
        teacher_repo = TeacherRepository(service.attendance_repo.db)
        teacher = await teacher_repo.get_by_user_id(current_user.id, tenant_id)
        if not teacher or session_obj.teacher_id != teacher.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You cannot correct attendance for another teacher's session."
            )

    db_obj = await service.correct_student_attendance(
        tenant_id=tenant_id,
        school_id=school_id,
        session_id=session_id,
        student_id=student_id,
        obj_in=obj_in,
        current_user=current_user
    )
    return APIResponse[AttendanceResponse](
        success=True,
        message="Student attendance corrected successfully.",
        data=AttendanceResponse.model_validate(db_obj)
    )

# ==================================================
# Daily Attendance Marking & Query Endpoints
# ==================================================

@router.post(
    "/daily/mark",
    response_model=APIResponse[AttendanceSessionResponse],
    status_code=status.HTTP_200_OK,
    summary="Mark daily attendance roster",
    description="Marks attendance for all students in a class roster for a full day or session."
)
async def mark_daily_attendance(
    obj_in: DailyAttendanceMarkRequest,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("attendance.create")),
    service: AttendanceService = Depends(get_attendance_service)
) -> APIResponse[AttendanceSessionResponse]:
    db_obj = await service.mark_daily_attendance(
        tenant_id=tenant_id,
        school_id=school_id,
        obj_in=obj_in,
        current_user=current_user
    )
    return APIResponse[AttendanceSessionResponse](
        success=True,
        message="Daily attendance marked successfully.",
        data=AttendanceSessionResponse.model_validate(db_obj)
    )

@router.get(
    "/daily/session",
    response_model=APIResponse[Optional[AttendanceSessionResponse]],
    status_code=status.HTTP_200_OK,
    summary="Get daily attendance session",
    description="Retrieves the daily attendance session for a class, section, and date."
)
async def get_daily_session(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    class_id: uuid.UUID = Query(..., description="Class ID"),
    section_id: uuid.UUID = Query(..., description="Section ID"),
    attendance_date: date = Query(..., description="Attendance date"),
    session_type: AttendanceSessionType = Query(AttendanceSessionType.FULL_DAY, description="Session type"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("attendance.read")),
    service: AttendanceService = Depends(get_attendance_service)
) -> APIResponse[Optional[AttendanceSessionResponse]]:
    await service.verify_teacher_class_access(current_user, school_id, class_id, section_id, tenant_id)
    session_obj = await service.attendance_repo.get_daily_session_by_class_section_date(
        school_id=school_id,
        class_id=class_id,
        section_id=section_id,
        attendance_date=attendance_date,
        session_type=session_type,
        tenant_id=tenant_id
    )
    data = AttendanceSessionResponse.model_validate(session_obj) if session_obj else None
    return APIResponse[Optional[AttendanceSessionResponse]](
        success=True,
        message="Daily session fetched successfully.",
        data=data
    )

# ==================================================
# Attendance Register, Dashboard & Alerts Endpoints
# ==================================================

@router.get(
    "/register",
    response_model=APIResponse[List[AttendanceResponse]],
    status_code=status.HTTP_200_OK,
    summary="Attendance register",
    description="Search and filter attendance records across classes and dates."
)
async def get_attendance_register(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    class_id: Optional[uuid.UUID] = Query(None, description="Filter by class"),
    section_id: Optional[uuid.UUID] = Query(None, description="Filter by section"),
    start_date: Optional[date] = Query(None, description="Start date"),
    end_date: Optional[date] = Query(None, description="End date"),
    attendance_status: Optional[AttendanceStatus] = Query(None, alias="status", description="Filter by status"),
    search: Optional[str] = Query(None, description="Search student name or admission number"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("attendance.read")),
    service: AttendanceService = Depends(get_attendance_service)
) -> APIResponse[List[AttendanceResponse]]:
    role = service.get_user_role_code(current_user)
    class_ids = None
    if role == "TEACHER":
        assigned = await service.get_teacher_assigned_classes(current_user, school_id, tenant_id)
        if class_id:
            if class_id not in assigned:
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied to requested class.")
            class_ids = [class_id]
        else:
            class_ids = assigned
    elif class_id:
        class_ids = [class_id]

    records, total = await service.attendance_repo.get_register_attendances_paginated(
        school_id=school_id,
        tenant_id=tenant_id,
        class_id=class_id,
        allowed_class_ids=assigned if (role == "TEACHER" and not class_id) else None,
        section_id=section_id,
        date_from=start_date,
        date_to=end_date,
        status=attendance_status,
        search=search,
        skip=skip,
        limit=limit
    )
    return APIResponse[List[AttendanceResponse]](
        success=True,
        message="Attendance register fetched successfully.",
        data=[AttendanceResponse.model_validate(r) for r in records],
        meta={"total": total, "skip": skip, "limit": limit}
    )

@router.get(
    "/dashboard",
    response_model=APIResponse[AttendanceDashboardStatsResponse],
    status_code=status.HTTP_200_OK,
    summary="Attendance dashboard statistics",
    description="Metrics, 7-day trend, class breakdowns, and low attendance students."
)
async def get_dashboard_stats(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    target_date: Optional[date] = Query(None, description="Target date (defaults to today)"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("attendance.read")),
    service: AttendanceService = Depends(get_attendance_service)
) -> APIResponse[AttendanceDashboardStatsResponse]:
    t_date = target_date or date.today()
    role = service.get_user_role_code(current_user)
    class_ids = None
    if role == "TEACHER":
        class_ids = await service.get_teacher_assigned_classes(current_user, school_id, tenant_id)

    stats = await service.attendance_repo.get_dashboard_stats(
        school_id=school_id,
        tenant_id=tenant_id,
        target_date=t_date,
        allowed_class_ids=class_ids
    )
    return APIResponse[AttendanceDashboardStatsResponse](
        success=True,
        message="Dashboard statistics retrieved successfully.",
        data=AttendanceDashboardStatsResponse.model_validate(stats)
    )

@router.get(
    "/alerts",
    response_model=APIResponse[List[AttendanceAlertResponse]],
    status_code=status.HTTP_200_OK,
    summary="Attendance alerts",
    description="Identifies multi-day absence streaks and un-marked classes today."
)
async def get_attendance_alerts(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    target_date: Optional[date] = Query(None, description="Target date (defaults to today)"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("attendance.read")),
    service: AttendanceService = Depends(get_attendance_service)
) -> APIResponse[List[AttendanceAlertResponse]]:
    t_date = target_date or date.today()
    role = service.get_user_role_code(current_user)
    class_ids = None
    if role == "TEACHER":
        class_ids = await service.get_teacher_assigned_classes(current_user, school_id, tenant_id)

    alerts = await service.attendance_repo.evaluate_alerts(
        school_id=school_id,
        tenant_id=tenant_id,
        target_date=t_date,
        allowed_class_ids=class_ids
    )
    return APIResponse[List[AttendanceAlertResponse]](
        success=True,
        message="Attendance alerts evaluated successfully.",
        data=[AttendanceAlertResponse.model_validate(a) for a in alerts]
    )

@router.get(
    "/audit-logs",
    response_model=APIResponse[List[AttendanceAuditLogResponse]],
    status_code=status.HTTP_200_OK,
    summary="Attendance audit logs",
    description="Paginated audit logs tracking attendance creates, updates, and imports."
)
async def get_audit_logs(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    student_id: Optional[uuid.UUID] = Query(None, description="Filter by student"),
    start_date: Optional[date] = Query(None, description="Start date"),
    end_date: Optional[date] = Query(None, description="End date"),
    action: Optional[AttendanceAction] = Query(None, description="Filter by action"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("attendance.read")),
    service: AttendanceService = Depends(get_attendance_service)
) -> APIResponse[List[AttendanceAuditLogResponse]]:
    role = service.get_user_role_code(current_user)
    if role in ["TEACHER", "PARENT"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Teachers and parents are not authorized to view attendance audit logs."
        )

    logs, total = await service.attendance_repo.get_audit_logs_paginated(
        school_id=school_id,
        tenant_id=tenant_id,
        student_id=student_id,
        date_from=start_date,
        date_to=end_date,
        action=action.value if action else None,
        skip=skip,
        limit=limit
    )
    return APIResponse[List[AttendanceAuditLogResponse]](
        success=True,
        message="Attendance audit logs fetched successfully.",
        data=[AttendanceAuditLogResponse.model_validate(log) for log in logs],
        meta={"total": total, "skip": skip, "limit": limit}
    )

# ==================================================
# Bulk Import & Export Endpoints
# ==================================================

@router.get(
    "/template",
    status_code=status.HTTP_200_OK,
    summary="Download attendance CSV template",
    description="Generates and downloads a standardized CSV template for bulk attendance import."
)
async def download_attendance_template(
    current_user: User = Depends(require_permission("attendance.create")),
    service: AttendanceService = Depends(get_attendance_service)
) -> Response:
    role = service.get_user_role_code(current_user)
    if role in ["TEACHER", "PARENT"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Teachers and parents are not authorized to download bulk attendance templates."
        )
    content = service.generate_csv_template()
    return Response(
        content=content,
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=attendance_import_template.csv"}
    )

@router.post(
    "/bulk/validate",
    response_model=APIResponse[BulkAttendanceValidateResponse],
    status_code=status.HTTP_200_OK,
    summary="Validate bulk attendance file",
    description="Parses an uploaded CSV or Excel spreadsheet, checks validation and conflict states, and creates preview records."
)
async def validate_bulk_attendance(
    school_id: uuid.UUID = Form(..., description="Target school ID"),
    academic_year_id: uuid.UUID = Form(..., description="Target Academic Year ID"),
    file: UploadFile = File(..., description="Excel or CSV file to validate"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("attendance.create")),
    service: AttendanceService = Depends(get_attendance_service)
) -> APIResponse[BulkAttendanceValidateResponse]:
    file_bytes = await file.read()
    result = await service.validate_bulk_attendance(
        tenant_id=tenant_id,
        school_id=school_id,
        academic_year_id=academic_year_id,
        file_bytes=file_bytes,
        filename=file.filename or "upload.csv",
        current_user=current_user
    )
    return APIResponse[BulkAttendanceValidateResponse](
        success=True,
        message="File validation completed.",
        data=BulkAttendanceValidateResponse.model_validate(result)
    )

@router.post(
    "/bulk/chunk",
    response_model=APIResponse[BulkAttendanceChunkResponse],
    status_code=status.HTTP_200_OK,
    summary="Import attendance chunk (high-performance batch)",
    description="Imports a safe chunk of 500-1,000 attendance records with idempotent batch processing and tenant isolation."
)
async def import_attendance_chunk(
    obj_in: BulkAttendanceChunkRequest,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("attendance.create")),
    service: AttendanceService = Depends(get_attendance_service)
) -> APIResponse[BulkAttendanceChunkResponse]:
    result = await service.import_attendance_chunk(
        tenant_id=tenant_id,
        school_id=school_id,
        obj_in=obj_in,
        current_user=current_user
    )
    return APIResponse[BulkAttendanceChunkResponse](
        success=True,
        message=f"Batch {result.batch_index} processed successfully.",
        data=result
    )

@router.post(
    "/bulk/import",
    response_model=APIResponse[BulkAttendanceImportResponse],
    status_code=status.HTTP_200_OK,
    summary="Execute bulk attendance import",
    description="Imports validated rows with the selected conflict strategy (SKIP_EXISTING or REPLACE_EXISTING)."
)
async def execute_bulk_attendance_import(
    obj_in: BulkAttendanceImportRequest,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("attendance.create")),
    service: AttendanceService = Depends(get_attendance_service)
) -> APIResponse[BulkAttendanceImportResponse]:
    result = await service.execute_bulk_attendance_import(
        tenant_id=tenant_id,
        school_id=school_id,
        job_id=obj_in.job_id,
        conflict_strategy=obj_in.conflict_strategy,
        current_user=current_user
    )
    return APIResponse[BulkAttendanceImportResponse](
        success=True,
        message="Bulk attendance import executed successfully.",
        data=BulkAttendanceImportResponse.model_validate(result)
    )

@router.post(
    "/imports/record",
    response_model=APIResponse[AttendanceImportJobResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Record completed attendance batch import",
    description="Records batch results and failed row details into import_jobs and import_job_rows for persistent audit trail and error report downloading."
)
async def record_attendance_import(
    obj_in: AttendanceImportRecordRequest,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("attendance.create")),
    service: AttendanceService = Depends(get_attendance_service)
) -> APIResponse[AttendanceImportJobResponse]:
    from datetime import datetime, timezone
    from app.models.import_job import ImportJob, ImportJobRow, ImportType, ImportJobStatus

    status_val = (
        ImportJobStatus.COMPLETED
        if obj_in.failed_rows == 0
        else ImportJobStatus.COMPLETED_WITH_ERRORS
    )
    if obj_in.status == "FAILED":
        status_val = ImportJobStatus.FAILED

    now = datetime.now(timezone.utc)
    job_id = uuid.uuid4()
    job_metadata = {}
    if obj_in.date_range:
        job_metadata["date_range"] = obj_in.date_range

    import_job = ImportJob(
        id=job_id,
        tenant_id=tenant_id,
        school_id=obj_in.school_id,
        import_type=ImportType.ATTENDANCE,
        status=status_val,
        source_filename=obj_in.filename or "attendance_upload.csv",
        total_rows=obj_in.total_rows,
        processed_rows=obj_in.successful_rows + obj_in.failed_rows,
        successful_rows=obj_in.successful_rows,
        failed_rows=obj_in.failed_rows,
        skipped_rows=obj_in.skipped_rows,
        created_by=current_user.id,
        completed_at=now,
        error_summary=obj_in.error_summary,
        job_metadata=job_metadata
    )
    service.attendance_repo.db.add(import_job)

    for err in obj_in.errors:
        job_row = ImportJobRow(
            import_job_id=job_id,
            row_number=err.row_number,
            status="failed",
            error_code=err.error_code or "IMPORT_ERROR",
            error_message=err.error_message,
            source_identifier=err.admission_number,
            row_metadata=err.row_data
        )
        service.attendance_repo.db.add(job_row)

    await service.attendance_repo.db.commit()
    await service.attendance_repo.db.refresh(import_job)

    user_name = f"{current_user.first_name} {current_user.last_name}".strip()
    user_role = current_user.roles[0].name if current_user.roles else None

    response_data = AttendanceImportJobResponse(
        id=import_job.id,
        tenant_id=import_job.tenant_id,
        school_id=import_job.school_id,
        filename=import_job.source_filename,
        status=import_job.status.value if hasattr(import_job.status, "value") else str(import_job.status),
        total_rows=import_job.total_rows,
        successful_rows=import_job.successful_rows,
        failed_rows=import_job.failed_rows,
        skipped_rows=import_job.skipped_rows,
        date_range=obj_in.date_range,
        uploaded_by=import_job.created_by,
        uploaded_by_name=user_name,
        uploaded_by_role=user_role,
        created_at=import_job.created_at or now,
        completed_at=import_job.completed_at,
        error_summary=import_job.error_summary
    )

    return APIResponse[AttendanceImportJobResponse](
        success=True,
        message="Attendance import recorded successfully.",
        data=response_data
    )

@router.get(
    "/imports",
    response_model=APIResponse[List[AttendanceImportJobResponse]],
    status_code=status.HTTP_200_OK,
    summary="List attendance import jobs",
    description="Lists previous attendance import batches with statuses and row counts."
)
async def list_attendance_imports(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("attendance.read")),
    service: AttendanceService = Depends(get_attendance_service)
) -> APIResponse[List[AttendanceImportJobResponse]]:
    role = service.get_user_role_code(current_user)
    if role in ["TEACHER", "PARENT"]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied to import jobs.")

    from sqlalchemy import select, func
    from app.models.import_job import ImportJob, ImportType

    base_query = select(ImportJob).where(
        ImportJob.tenant_id == tenant_id,
        ImportJob.school_id == school_id,
        ImportJob.import_type == ImportType.ATTENDANCE,
        ImportJob.deleted_at.is_(None)
    )
    count_stmt = select(func.count()).select_from(base_query.subquery())
    total_res = await service.attendance_repo.db.execute(count_stmt)
    total = total_res.scalar_one()

    query = base_query.order_by(ImportJob.created_at.desc()).offset(skip).limit(limit)
    res = await service.attendance_repo.db.execute(query)
    jobs = list(res.scalars().all())

    job_responses = []
    for j in jobs:
        user_name = None
        user_role = None
        if j.created_by:
            from app.models.user import User as UserModel
            u_stmt = select(UserModel).where(UserModel.id == j.created_by)
            u_res = await service.attendance_repo.db.execute(u_stmt)
            u = u_res.scalar_one_or_none()
            if u:
                user_name = f"{u.first_name} {u.last_name}".strip()
                user_role = u.roles[0].name if u.roles else None
        
        meta = j.job_metadata or {}
        date_range = meta.get("date_range")
        job_responses.append(AttendanceImportJobResponse(
            id=j.id,
            tenant_id=j.tenant_id,
            school_id=j.school_id,
            filename=j.source_filename or "attendance_upload.csv",
            status=j.status.value if hasattr(j.status, 'value') else str(j.status),
            total_rows=j.total_rows,
            successful_rows=j.successful_rows,
            failed_rows=j.failed_rows,
            skipped_rows=j.skipped_rows,
            date_range=date_range,
            uploaded_by=j.created_by,
            uploaded_by_name=user_name,
            uploaded_by_role=user_role,
            created_at=j.created_at,
            completed_at=j.completed_at,
            error_summary=j.error_summary
        ))

    return APIResponse[List[AttendanceImportJobResponse]](
        success=True,
        message="Import jobs fetched successfully.",
        data=job_responses,
        meta={"total": total, "skip": skip, "limit": limit}
    )

@router.get(
    "/imports/{job_id}/errors",
    status_code=status.HTTP_200_OK,
    summary="Download import job errors CSV",
    description="Generates and downloads a CSV file containing all failed and invalid rows with error details."
)
async def download_import_errors(
    job_id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("attendance.read")),
    service: AttendanceService = Depends(get_attendance_service)
) -> Response:
    role = service.get_user_role_code(current_user)
    if role in ["TEACHER", "PARENT"]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied.")

    csv_text = await service.get_import_job_errors_csv(tenant_id=tenant_id, school_id=school_id, job_id=job_id)
    return Response(
        content=csv_text,
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename=attendance_errors_{job_id}.csv"}
    )


