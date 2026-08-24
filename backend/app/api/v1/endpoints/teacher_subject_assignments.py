import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status, HTTPException

from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.teacher_subject_assignment import get_assignment_service
from app.api.dependencies.auth import require_permission
from app.services.teacher_subject_assignment import TeacherSubjectAssignmentService
from app.schemas.teacher_subject_assignment import TeacherSubjectAssignmentCreate, TeacherSubjectAssignmentUpdate, TeacherSubjectAssignmentResponse
from app.models.teacher_subject_assignment import AssignmentStatus
from app.models.user import User
from app.schemas.response import APIResponse

router = APIRouter()

@router.post(
    "",
    response_model=APIResponse[TeacherSubjectAssignmentResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Add a new teacher subject assignment",
    description="Maps a teacher to an academic subject, class, and section for the active academic year, validating dates and limits."
)
async def create_assignment(
    obj_in: TeacherSubjectAssignmentCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher_subject_assignment.create")),
    service: TeacherSubjectAssignmentService = Depends(get_assignment_service)
) -> APIResponse[TeacherSubjectAssignmentResponse]:
    db_obj = await service.create_assignment(tenant_id, obj_in, assigned_by=current_user.id)
    return APIResponse[TeacherSubjectAssignmentResponse](
        success=True,
        message="Teacher subject assignment registered successfully.",
        data=TeacherSubjectAssignmentResponse.model_validate(db_obj)
    )

@router.get(
    "",
    response_model=APIResponse[List[TeacherSubjectAssignmentResponse]],
    status_code=status.HTTP_200_OK,
    summary="List teacher subject assignments",
    description="Retrieves a paginated list of assignments, joining teachers, subjects, classes, and sections. Supports search."
)
async def list_assignments(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    academic_year_id: Optional[uuid.UUID] = Query(None, description="Filter by Academic Year ID"),
    teacher_id: Optional[uuid.UUID] = Query(None, description="Filter by Teacher ID"),
    subject_id: Optional[uuid.UUID] = Query(None, description="Filter by Subject ID"),
    class_id: Optional[uuid.UUID] = Query(None, description="Filter by Class ID"),
    section_id: Optional[uuid.UUID] = Query(None, description="Filter by Section ID"),
    status_filter: Optional[AssignmentStatus] = Query(None, alias="status", description="Filter by assignment status"),
    search: Optional[str] = Query(None, description="Fuzzy match search on teacher name, teacher code, subject name/code, class/section names"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher_subject_assignment.read")),
    service: TeacherSubjectAssignmentService = Depends(get_assignment_service)
) -> APIResponse[List[TeacherSubjectAssignmentResponse]]:
    role_codes = {r.code for r in current_user.roles}
    is_admin_or_principal = current_user.is_superuser or any(
        code in ["SUPER_ADMIN", "SCHOOL_ADMIN", "PRINCIPAL"] for code in role_codes
    )
    if not is_admin_or_principal and "TEACHER" in role_codes:
        from app.repositories.teacher import TeacherRepository
        teacher_repo = TeacherRepository(service.assignment_repo.db)
        teacher = await teacher_repo.get_by_user_id(current_user.id, tenant_id)
        if not teacher:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. No active teacher profile found for user."
            )
        teacher_id = teacher.id

    assignments = await service.assignment_repo.get_multi(
        school_id=school_id,
        tenant_id=tenant_id,
        academic_year_id=academic_year_id,
        teacher_id=teacher_id,
        subject_id=subject_id,
        class_id=class_id,
        section_id=section_id,
        status=status_filter,
        search=search,
        skip=skip,
        limit=limit
    )
    responses = [TeacherSubjectAssignmentResponse.model_validate(a) for a in assignments]
    return APIResponse[List[TeacherSubjectAssignmentResponse]](
        success=True,
        message="Teacher subject assignments fetched successfully.",
        data=responses
    )

@router.get(
    "/{id}",
    response_model=APIResponse[TeacherSubjectAssignmentResponse],
    status_code=status.HTTP_200_OK,
    summary="Get teacher subject assignment details",
    description="Retrieves details of a specific mapping scoped by tenant and school."
)
async def get_assignment(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher_subject_assignment.read")),
    service: TeacherSubjectAssignmentService = Depends(get_assignment_service)
) -> APIResponse[TeacherSubjectAssignmentResponse]:
    db_obj = await service.assignment_repo.get_by_id(id, school_id, tenant_id)
    if not db_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Teacher subject assignment not found."
        )

    role_codes = {r.code for r in current_user.roles}
    is_admin_or_principal = current_user.is_superuser or any(
        code in ["SUPER_ADMIN", "SCHOOL_ADMIN", "PRINCIPAL"] for code in role_codes
    )
    if not is_admin_or_principal and "TEACHER" in role_codes:
        from app.repositories.teacher import TeacherRepository
        teacher_repo = TeacherRepository(service.assignment_repo.db)
        teacher = await teacher_repo.get_by_user_id(current_user.id, tenant_id)
        if not teacher or db_obj.teacher_id != teacher.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. You are not authorized to view this assignment."
            )

    return APIResponse[TeacherSubjectAssignmentResponse](
        success=True,
        message="Teacher subject assignment details fetched successfully.",
        data=TeacherSubjectAssignmentResponse.model_validate(db_obj)
    )

@router.put(
    "/{id}",
    response_model=APIResponse[TeacherSubjectAssignmentResponse],
    status_code=status.HTTP_200_OK,
    summary="Update teacher subject assignment details",
    description="Modifies parameters of an assignment scoped by tenant and school."
)
async def update_assignment(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    obj_in: TeacherSubjectAssignmentUpdate = ...,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher_subject_assignment.update")),
    service: TeacherSubjectAssignmentService = Depends(get_assignment_service)
) -> APIResponse[TeacherSubjectAssignmentResponse]:
    db_obj = await service.update_assignment(tenant_id, school_id, id, obj_in, updated_by=current_user.id)
    return APIResponse[TeacherSubjectAssignmentResponse](
        success=True,
        message="Teacher subject assignment updated successfully.",
        data=TeacherSubjectAssignmentResponse.model_validate(db_obj)
    )

@router.delete(
    "/{id}",
    response_model=APIResponse[TeacherSubjectAssignmentResponse],
    status_code=status.HTTP_200_OK,
    summary="Soft-delete teacher subject assignment",
    description="Soft-deletes the assignment, updating status to ARCHIVED."
)
async def delete_assignment(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher_subject_assignment.delete")),
    service: TeacherSubjectAssignmentService = Depends(get_assignment_service)
) -> APIResponse[TeacherSubjectAssignmentResponse]:
    db_obj = await service.delete_assignment(tenant_id, school_id, id, deleted_by=current_user.id)
    return APIResponse[TeacherSubjectAssignmentResponse](
        success=True,
        message="Teacher subject assignment deleted successfully.",
        data=TeacherSubjectAssignmentResponse.model_validate(db_obj)
    )
