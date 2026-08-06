import uuid
from typing import List, Optional
from datetime import date
from fastapi import APIRouter, Depends, Query, status, HTTPException

from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.homework import get_homework_service
from app.api.dependencies.auth import require_permission
from app.services.homework import HomeworkService
from app.schemas.homework import (
    HomeworkCreate,
    HomeworkCreateFromTimetable,
    HomeworkUpdate,
    HomeworkResponse,
    HomeworkCopyRequest
)
from app.models.homework import HomeworkStatus
from app.models.user import User
from app.schemas.response import APIResponse

router = APIRouter()

@router.post(
    "",
    response_model=APIResponse[HomeworkResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create a new homework assignment",
    description="Manually records a homework entry for a specific subject, class, and section."
)
async def create_homework(
    obj_in: HomeworkCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("homework.create")),
    service: HomeworkService = Depends(get_homework_service)
) -> APIResponse[HomeworkResponse]:
    db_obj = await service.create_homework(tenant_id, obj_in.school_id, obj_in, current_user)
    return APIResponse[HomeworkResponse](
        success=True,
        message="Homework assignment created successfully.",
        data=HomeworkResponse.model_validate(db_obj)
    )

@router.post(
    "/timetable/{timetable_id}",
    response_model=APIResponse[HomeworkResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create homework from a timetable slot",
    description="Automatically derives class, section, subject, and teacher context from today's timetable slot."
)
async def create_from_timetable(
    timetable_id: uuid.UUID,
    obj_in: HomeworkCreateFromTimetable,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("homework.create")),
    service: HomeworkService = Depends(get_homework_service)
) -> APIResponse[HomeworkResponse]:
    db_obj = await service.create_homework_from_timetable(tenant_id, school_id, timetable_id, obj_in, current_user)
    return APIResponse[HomeworkResponse](
        success=True,
        message="Homework created from timetable slot successfully.",
        data=HomeworkResponse.model_validate(db_obj)
    )

@router.post(
    "/copy",
    response_model=APIResponse[List[HomeworkResponse]],
    status_code=status.HTTP_201_CREATED,
    summary="Copy homework to multiple sections",
    description="Duplicates an existing homework record across multiple target sections."
)
async def copy_homework(
    obj_in: HomeworkCopyRequest,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("homework.create")),
    service: HomeworkService = Depends(get_homework_service)
) -> APIResponse[List[HomeworkResponse]]:
    db_objs = await service.copy_homework_to_sections(
        tenant_id=tenant_id,
        school_id=school_id,
        homework_id=obj_in.homework_id,
        target_section_ids=obj_in.target_section_ids,
        current_user=current_user
    )
    return APIResponse[List[HomeworkResponse]](
        success=True,
        message="Homework successfully copied to sections.",
        data=[HomeworkResponse.model_validate(h) for h in db_objs]
    )

@router.post(
    "/{id}/publish",
    response_model=APIResponse[HomeworkResponse],
    status_code=status.HTTP_200_OK,
    summary="Publish a homework assignment",
    description="Transitions draft homework to PUBLISHED status and queue parent notifications."
)
async def publish_homework(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("homework.update")),
    service: HomeworkService = Depends(get_homework_service)
) -> APIResponse[HomeworkResponse]:
    db_obj = await service.publish_homework(tenant_id, school_id, id, current_user)
    return APIResponse[HomeworkResponse](
        success=True,
        message="Homework published successfully.",
        data=HomeworkResponse.model_validate(db_obj)
    )

@router.get(
    "/recent",
    response_model=APIResponse[List[HomeworkResponse]],
    status_code=status.HTTP_200_OK,
    summary="Get recent homework entries",
    description="Retrieves the last 20 homework assignments created by the current teacher."
)
async def get_recent_homework(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("homework.read")),
    service: HomeworkService = Depends(get_homework_service)
) -> APIResponse[List[HomeworkResponse]]:
    teacher = await service.teacher_repo.get_by_official_email(current_user.email, tenant_id)
    if not teacher:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current logged in user is not registered as a teacher."
        )

    entries = await service.homework_repo.get_recent_homework(teacher.id, tenant_id)
    return APIResponse[List[HomeworkResponse]](
        success=True,
        message="Recent homework entries fetched successfully.",
        data=[HomeworkResponse.model_validate(e) for e in entries]
    )

@router.get(
    "/templates",
    response_model=APIResponse[List[str]],
    status_code=status.HTTP_200_OK,
    summary="Get subject-specific templates",
    description="Provides quick description templates matching the selected subject's name/category."
)
async def get_templates(
    subject_id: Optional[uuid.UUID] = Query(None, description="Optional subject filter"),
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("homework.read")),
    service: HomeworkService = Depends(get_homework_service)
) -> APIResponse[List[str]]:
    templates = await service.get_templates(subject_id, school_id, tenant_id)
    return APIResponse[List[str]](
        success=True,
        message="Subject templates fetched successfully.",
        data=templates
    )

@router.get(
    "/parent",
    response_model=APIResponse[List[HomeworkResponse]],
    status_code=status.HTTP_200_OK,
    summary="Get parent scoped homework",
    description="Derives student classes and sections from the authenticated parent's linked children."
)
async def get_parent_homework(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("homework.read")),
    service: HomeworkService = Depends(get_homework_service)
) -> APIResponse[List[HomeworkResponse]]:
    entries = await service.homework_repo.get_parent_homeworks(current_user.email, school_id, tenant_id)
    return APIResponse[List[HomeworkResponse]](
        success=True,
        message="Parent student homework logs fetched successfully.",
        data=[HomeworkResponse.model_validate(e) for e in entries]
    )

@router.get(
    "/{id}",
    response_model=APIResponse[HomeworkResponse],
    status_code=status.HTTP_200_OK,
    summary="Get a single homework details",
    description="Retrieves granular information for a specific homework ID."
)
async def get_homework_by_id(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("homework.read")),
    service: HomeworkService = Depends(get_homework_service)
) -> APIResponse[HomeworkResponse]:
    db_obj = await service.homework_repo.get_by_id(id, school_id, tenant_id)
    if not db_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Homework assignment not found."
        )
    return APIResponse[HomeworkResponse](
        success=True,
        message="Homework details fetched successfully.",
        data=HomeworkResponse.model_validate(db_obj)
    )

@router.get(
    "",
    response_model=APIResponse[List[HomeworkResponse]],
    status_code=status.HTTP_200_OK,
    summary="List homework assignments",
    description="Retrieves homework list scoped to filters. Supports text search matching title/description."
)
async def list_homeworks(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    academic_year_id: Optional[uuid.UUID] = Query(None, description="Filter by Academic Year ID"),
    class_id: Optional[uuid.UUID] = Query(None, description="Filter by Class ID"),
    section_id: Optional[uuid.UUID] = Query(None, description="Filter by Section ID"),
    subject_id: Optional[uuid.UUID] = Query(None, description="Filter by Subject ID"),
    teacher_id: Optional[uuid.UUID] = Query(None, description="Filter by Teacher ID"),
    status_filter: Optional[HomeworkStatus] = Query(None, alias="status", description="Filter by homework status"),
    search: Optional[str] = Query(None, description="Text query matching title/description"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("homework.read")),
    service: HomeworkService = Depends(get_homework_service)
) -> APIResponse[List[HomeworkResponse]]:
    entries = await service.homework_repo.get_multi(
        school_id=school_id,
        tenant_id=tenant_id,
        academic_year_id=academic_year_id,
        class_id=class_id,
        section_id=section_id,
        subject_id=subject_id,
        teacher_id=teacher_id,
        status=status_filter,
        search=search,
        skip=skip,
        limit=limit
    )
    return APIResponse[List[HomeworkResponse]](
        success=True,
        message="Homework assignments fetched successfully.",
        data=[HomeworkResponse.model_validate(e) for e in entries]
    )

@router.put(
    "/{id}",
    response_model=APIResponse[HomeworkResponse],
    status_code=status.HTTP_200_OK,
    summary="Update homework details",
    description="Updates title, description, due date, priority, or status of an existing entry."
)
async def update_homework(
    id: uuid.UUID,
    obj_in: HomeworkUpdate,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("homework.update")),
    service: HomeworkService = Depends(get_homework_service)
) -> APIResponse[HomeworkResponse]:
    db_obj = await service.update_homework(tenant_id, school_id, id, obj_in, current_user)
    return APIResponse[HomeworkResponse](
        success=True,
        message="Homework updated successfully.",
        data=HomeworkResponse.model_validate(db_obj)
    )

@router.delete(
    "/{id}",
    response_model=APIResponse[HomeworkResponse],
    status_code=status.HTTP_200_OK,
    summary="Soft delete a homework",
    description="Soft deletes the homework log scoped to school and tenant."
)
async def delete_homework(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("homework.delete")),
    service: HomeworkService = Depends(get_homework_service)
) -> APIResponse[HomeworkResponse]:
    db_obj = await service.delete_homework(tenant_id, school_id, id, current_user)
    return APIResponse[HomeworkResponse](
        success=True,
        message="Homework deleted successfully.",
        data=HomeworkResponse.model_validate(db_obj)
    )
