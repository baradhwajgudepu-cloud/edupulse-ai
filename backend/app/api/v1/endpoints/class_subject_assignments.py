import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.common import get_tenant_id, get_db
from app.api.dependencies.auth import require_permission
from app.repositories.class_subject_assignment import ClassSubjectAssignmentRepository
from app.services.class_subject_assignment import ClassSubjectAssignmentService
from app.schemas.class_subject_assignment import (
    ClassSubjectAssignmentCreate,
    ClassSubjectAssignmentBatchCreate,
    ClassSubjectAssignmentUpdate,
    ClassSubjectAssignmentResponse
)
from app.models.user import User
from app.schemas.response import APIResponse

router = APIRouter()

def get_class_subject_service(db: AsyncSession = Depends(get_db)) -> ClassSubjectAssignmentService:
    repo = ClassSubjectAssignmentRepository(db)
    return ClassSubjectAssignmentService(db, repo)

@router.post(
    "",
    response_model=APIResponse[ClassSubjectAssignmentResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Assign a subject to a class or section",
    description="Maps a subject with period configuration (periods/week, duration, preferred days) and optional teacher."
)
async def create_class_subject_assignment(
    obj_in: ClassSubjectAssignmentCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("subject.create")),
    service: ClassSubjectAssignmentService = Depends(get_class_subject_service)
) -> APIResponse[ClassSubjectAssignmentResponse]:
    res = await service.create_assignment(tenant_id, obj_in, created_by=current_user.id)
    return APIResponse[ClassSubjectAssignmentResponse](
        success=True,
        message="Class subject assignment created successfully.",
        data=res
    )

@router.post(
    "/batch",
    response_model=APIResponse[List[ClassSubjectAssignmentResponse]],
    status_code=status.HTTP_201_CREATED,
    summary="Batch assign a subject to multiple classes",
    description="Maps a subject to multiple classes and sections simultaneously."
)
async def create_batch_class_subject_assignments(
    batch_in: ClassSubjectAssignmentBatchCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("subject.create")),
    service: ClassSubjectAssignmentService = Depends(get_class_subject_service)
) -> APIResponse[List[ClassSubjectAssignmentResponse]]:
    res = await service.create_batch(tenant_id, batch_in, created_by=current_user.id)
    return APIResponse[List[ClassSubjectAssignmentResponse]](
        success=True,
        message=f"Subject successfully assigned to {len(res)} class/section mappings.",
        data=res
    )

@router.get(
    "",
    response_model=APIResponse[List[ClassSubjectAssignmentResponse]],
    status_code=status.HTTP_200_OK,
    summary="List class subject assignments",
    description="Retrieves class subject mappings filtered by school, academic year, class, or section."
)
async def list_class_subject_assignments(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    academic_year_id: Optional[uuid.UUID] = Query(None, description="Filter by Academic Year ID"),
    class_id: Optional[uuid.UUID] = Query(None, description="Filter by Class ID"),
    section_id: Optional[uuid.UUID] = Query(None, description="Filter by Section ID"),
    subject_id: Optional[uuid.UUID] = Query(None, description="Filter by Subject ID"),
    teacher_id: Optional[uuid.UUID] = Query(None, description="Filter by Teacher ID"),
    is_active: Optional[bool] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("subject.read")),
    service: ClassSubjectAssignmentService = Depends(get_class_subject_service)
) -> APIResponse[List[ClassSubjectAssignmentResponse]]:
    assignments = await service.assignment_repo.get_multi(
        school_id=school_id,
        tenant_id=tenant_id,
        academic_year_id=academic_year_id,
        class_id=class_id,
        section_id=section_id,
        subject_id=subject_id,
        teacher_id=teacher_id,
        is_active=is_active,
        skip=skip,
        limit=limit
    )
    responses = [service._to_response(a) for a in assignments]
    return APIResponse[List[ClassSubjectAssignmentResponse]](
        success=True,
        message="Class subject assignments retrieved successfully.",
        data=responses
    )

@router.get(
    "/{id}",
    response_model=APIResponse[ClassSubjectAssignmentResponse],
    status_code=status.HTTP_200_OK,
    summary="Get class subject assignment details"
)
async def get_class_subject_assignment(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("subject.read")),
    service: ClassSubjectAssignmentService = Depends(get_class_subject_service)
) -> APIResponse[ClassSubjectAssignmentResponse]:
    obj = await service.assignment_repo.get_by_id(id, school_id, tenant_id)
    if not obj:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assignment not found.")
    return APIResponse[ClassSubjectAssignmentResponse](
        success=True,
        message="Assignment retrieved successfully.",
        data=service._to_response(obj)
    )

@router.put(
    "/{id}",
    response_model=APIResponse[ClassSubjectAssignmentResponse],
    status_code=status.HTTP_200_OK,
    summary="Update class subject assignment"
)
async def update_class_subject_assignment(
    id: uuid.UUID,
    obj_in: ClassSubjectAssignmentUpdate,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("subject.update")),
    service: ClassSubjectAssignmentService = Depends(get_class_subject_service)
) -> APIResponse[ClassSubjectAssignmentResponse]:
    res = await service.update_assignment(id, school_id, tenant_id, obj_in)
    return APIResponse[ClassSubjectAssignmentResponse](
        success=True,
        message="Assignment updated successfully.",
        data=res
    )

@router.delete(
    "/{id}",
    response_model=APIResponse[None],
    status_code=status.HTTP_200_OK,
    summary="Delete class subject assignment"
)
async def delete_class_subject_assignment(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("subject.delete")),
    service: ClassSubjectAssignmentService = Depends(get_class_subject_service)
) -> APIResponse[None]:
    await service.delete_assignment(id, school_id, tenant_id)
    return APIResponse[None](
        success=True,
        message="Class subject assignment deleted successfully.",
        data=None
    )
