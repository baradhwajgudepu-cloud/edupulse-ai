import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status, HTTPException

from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.student import get_student_service
from app.api.dependencies.auth import require_permission
from app.services.student import StudentService
from app.schemas.student import StudentCreate, StudentUpdate, StudentResponse
from app.models.student import StudentStatus
from app.models.user import User
from app.schemas.response import APIResponse

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
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("student.read")),
    service: StudentService = Depends(get_student_service)
) -> APIResponse[List[StudentResponse]]:
    students = await service.student_repo.get_multi(
        school_id=school_id,
        tenant_id=tenant_id,
        academic_year_id=academic_year_id,
        class_id=class_id,
        section_id=section_id,
        status=status_filter,
        search=search,
        skip=skip,
        limit=limit
    )
    responses = [StudentResponse.model_validate(s) for s in students]
    return APIResponse[List[StudentResponse]](
        success=True,
        message="Students fetched successfully.",
        data=responses
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
    db_obj = await service.student_repo.get_by_id(id, school_id, tenant_id)
    if not db_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student not found."
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
    db_obj = await service.delete_student(tenant_id, school_id, id, deleted_by=current_user.id)
    return APIResponse[StudentResponse](
        success=True,
        message="Student deleted successfully.",
        data=StudentResponse.model_validate(db_obj)
    )
