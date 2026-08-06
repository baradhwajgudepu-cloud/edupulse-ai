import uuid
from typing import List, Optional, Dict, Any
from datetime import date
from fastapi import APIRouter, Depends, Query, status, HTTPException

from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.examination import get_examination_service
from app.api.dependencies.auth import require_permission
from app.services.examination import ExaminationService
from app.schemas.examination import (
    ExamTemplateCreate, ExamTemplateResponse,
    ExaminationCreate, ExaminationUpdate,
    ExaminationWizardCreate, ExaminationCopyRequest,
    ExaminationResponse, ExamScheduleResponse
)
from app.models.user import User
from app.schemas.response import APIResponse

router = APIRouter()

# ==================================================
# Template Endpoints
# ==================================================
@router.post(
    "/templates",
    response_model=APIResponse[ExamTemplateResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create a new reusable exam template"
)
async def create_template(
    obj_in: ExamTemplateCreate,
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.create")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[ExamTemplateResponse]:
    db_obj = await service.create_template(tenant_id, school_id, academic_year_id, obj_in, current_user)
    return APIResponse[ExamTemplateResponse](
        success=True,
        message="Examination template created successfully.",
        data=ExamTemplateResponse.model_validate(db_obj)
    )

@router.get(
    "/templates",
    response_model=APIResponse[List[ExamTemplateResponse]],
    status_code=status.HTTP_200_OK,
    summary="List all reusable exam templates"
)
async def list_templates(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.read")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[List[ExamTemplateResponse]]:
    db_objs = await service.template_repo.get_multi(school_id, tenant_id, skip, limit)
    return APIResponse[List[ExamTemplateResponse]](
        success=True,
        message="Examination templates listed successfully.",
        data=[ExamTemplateResponse.model_validate(t) for t in db_objs]
    )


# ==================================================
# Wizard Endpoints
# ==================================================
@router.get(
    "/wizard/suggest",
    response_model=APIResponse[List[Dict[str, Any]]],
    status_code=status.HTTP_200_OK,
    summary="Auto-suggest sequential paper schedules from TSA assignments"
)
async def suggest_schedules(
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    class_ids: List[uuid.UUID] = Query(...),
    start_date: date = Query(...),
    end_date: date = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.read")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[List[Dict[str, Any]]]:
    suggestions = await service.suggest_wizard_schedules(
        tenant_id=tenant_id,
        school_id=school_id,
        academic_year_id=academic_year_id,
        class_ids=class_ids,
        start_date=start_date,
        end_date=end_date
    )
    return APIResponse[List[Dict[str, Any]]](
        success=True,
        message="Suggested sequential exam schedules successfully loaded from TSA mappings.",
        data=suggestions
    )

@router.post(
    "/wizard",
    response_model=APIResponse[ExaminationResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Configure and schedule exam in a single request"
)
async def save_wizard(
    obj_in: ExaminationWizardCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.create")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[ExaminationResponse]:
    db_obj = await service.create_examination_wizard(tenant_id, obj_in.school_id, obj_in, current_user)
    return APIResponse[ExaminationResponse](
        success=True,
        message="Examination and all child schedules created successfully.",
        data=ExaminationResponse.model_validate(db_obj)
    )


# ==================================================
# Copy & Publish Endpoints
# ==================================================
@router.post(
    "/copy",
    response_model=APIResponse[ExaminationResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Copy master exam and shift schedule paper dates by offset"
)
async def copy_examination(
    obj_in: ExaminationCopyRequest,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.create")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[ExaminationResponse]:
    db_obj = await service.copy_examination(tenant_id, school_id, obj_in, current_user)
    return APIResponse[ExaminationResponse](
        success=True,
        message="Examination duplicated and schedules shifted successfully.",
        data=ExaminationResponse.model_validate(db_obj)
    )

@router.post(
    "/{id}/publish",
    response_model=APIResponse[ExaminationResponse],
    status_code=status.HTTP_200_OK,
    summary="Publish the examination schedule for parents and students"
)
async def publish_examination(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.update")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[ExaminationResponse]:
    db_obj = await service.publish_examination(tenant_id, school_id, id, current_user)
    return APIResponse[ExaminationResponse](
        success=True,
        message="Examination published successfully.",
        data=ExaminationResponse.model_validate(db_obj)
    )


# ==================================================
# Scoped Queries
# ==================================================
@router.get(
    "/parent",
    response_model=APIResponse[List[ExamScheduleResponse]],
    status_code=status.HTTP_200_OK,
    summary="Get clean schedule details scoped to parent's children"
)
async def get_parent_schedules(
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.read")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[List[ExamScheduleResponse]]:
    schedules = await service.exam_repo.get_parent_schedules(current_user.email, school_id, tenant_id)
    return APIResponse[List[ExamScheduleResponse]](
        success=True,
        message="Parent student examinations schedule list loaded.",
        data=[ExamScheduleResponse.model_validate(s) for s in schedules]
    )


# ==================================================
# CRUD Endpoints
# ==================================================
@router.post(
    "",
    response_model=APIResponse[ExaminationResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create a standard examination master"
)
async def create_exam(
    obj_in: ExaminationCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.create")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[ExaminationResponse]:
    db_obj = await service.create_examination(tenant_id, obj_in.school_id, obj_in, current_user)
    return APIResponse[ExaminationResponse](
        success=True,
        message="Examination master created successfully.",
        data=ExaminationResponse.model_validate(db_obj)
    )

@router.get(
    "/{id}",
    response_model=APIResponse[ExaminationResponse],
    status_code=status.HTTP_200_OK,
    summary="Get single examination details"
)
async def get_exam(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.read")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[ExaminationResponse]:
    db_obj = await service.exam_repo.get_by_id(id, school_id, tenant_id)
    if not db_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Examination not found."
        )
    return APIResponse[ExaminationResponse](
        success=True,
        message="Examination details fetched successfully.",
        data=ExaminationResponse.model_validate(db_obj)
    )

@router.get(
    "",
    response_model=APIResponse[List[ExaminationResponse]],
    status_code=status.HTTP_200_OK,
    summary="List examinations scoped to school"
)
async def list_exams(
    school_id: uuid.UUID = Query(...),
    academic_year_id: Optional[uuid.UUID] = Query(None),
    search: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.read")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[List[ExaminationResponse]]:
    db_objs = await service.exam_repo.get_multi(
        school_id=school_id,
        tenant_id=tenant_id,
        academic_year_id=academic_year_id,
        search=search,
        skip=skip,
        limit=limit
    )
    return APIResponse[List[ExaminationResponse]](
        success=True,
        message="Examinations listed successfully.",
        data=[ExaminationResponse.model_validate(e) for e in db_objs]
    )

@router.put(
    "/{id}",
    response_model=APIResponse[ExaminationResponse],
    status_code=status.HTTP_200_OK,
    summary="Update examination details"
)
async def update_exam(
    id: uuid.UUID,
    obj_in: ExaminationUpdate,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.update")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[ExaminationResponse]:
    db_obj = await service.update_examination(tenant_id, school_id, id, obj_in, current_user)
    return APIResponse[ExaminationResponse](
        success=True,
        message="Examination updated successfully.",
        data=ExaminationResponse.model_validate(db_obj)
    )

@router.delete(
    "/{id}",
    response_model=APIResponse[ExaminationResponse],
    status_code=status.HTTP_200_OK,
    summary="Soft delete examination"
)
async def delete_exam(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.delete")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[ExaminationResponse]:
    db_obj = await service.delete_examination(tenant_id, school_id, id, current_user)
    return APIResponse[ExaminationResponse](
        success=True,
        message="Examination deleted successfully.",
        data=ExaminationResponse.model_validate(db_obj)
    )
