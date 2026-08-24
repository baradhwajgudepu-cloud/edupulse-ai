import uuid
from typing import List, Optional
from datetime import date
from fastapi import APIRouter, Depends, Query, status, HTTPException

from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.attendance import get_attendance_service
from app.api.dependencies.auth import require_permission
from app.services.attendance import AttendanceService
from app.schemas.attendance import AttendanceSessionCreate, AttendanceSessionUpdate, BulkAttendanceMark, AttendanceSessionResponse, AttendanceResponse, AttendanceCorrectionUpdate
from app.models.attendance import AttendanceSessionStatus, AttendanceStatus
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

