import uuid
from typing import List, Optional, Dict, Any
from datetime import date
from fastapi import APIRouter, Depends, Query, status, HTTPException

from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.examination import get_examination_service
from app.api.dependencies.auth import require_permission
from app.services.examination import ExaminationService
from app.schemas.examination import (
    ExamTypeMasterCreate, ExamTypeMasterUpdate, ExamTypeMasterResponse,
    ExamTemplateCreate, ExamTemplateResponse,
    ExaminationCreate, ExaminationUpdate, ExamStatusTransitionRequest,
    ExaminationWizardCreate, ExaminationCopyRequest,
    ExaminationResponse, ExamScheduleCreate, ExamScheduleUpdate, ExamScheduleResponse,
    BulkTimetablePreviewRequest, BulkTimetablePreviewResponse, BulkTimetableConfirmRequest
)
from app.models.user import User
from app.schemas.response import APIResponse

router = APIRouter()

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import get_db

async def verify_school_access(user: User, school_id: uuid.UUID, db: AsyncSession) -> None:
    from app.models.school import School

    school_stmt = select(School).where(School.id == school_id)
    school_res = await db.execute(school_stmt)
    school = school_res.scalar_one_or_none()
    if not school:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="School not found."
        )

    if not user.is_superuser and school.tenant_id != user.tenant_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. School belongs to a different tenant."
        )

    if not school.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="School is inactive."
        )

    if user.is_superuser:
        return

    user_role_codes = [role.code for role in user.roles]
    if "PARENT" in user_role_codes:
        return

    from app.models.role import school_users
    stmt = select(1).select_from(school_users).where(
        school_users.c.user_id == user.id,
        school_users.c.school_id == school_id
    )
    res = await db.execute(stmt)
    if not res.fetchone():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. You do not have permissions for this school."
        )

# ==================================================
# Exam Types Endpoints
# ==================================================
@router.get(
    "/types",
    response_model=APIResponse[List[ExamTypeMasterResponse]],
    status_code=status.HTTP_200_OK,
    summary="List all exam types for school / tenant"
)
async def list_exam_types(
    school_id: Optional[uuid.UUID] = Query(None, description="Optional target school ID"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.read")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[List[ExamTypeMasterResponse]]:
    if school_id:
        await verify_school_access(current_user, school_id, service.exam_repo.db)
    items = await service.list_exam_types(tenant_id, school_id, skip, limit)
    return APIResponse[List[ExamTypeMasterResponse]](
        success=True,
        message="Exam types listed successfully.",
        data=[ExamTypeMasterResponse.model_validate(t) for t in items]
    )

@router.post(
    "/types",
    response_model=APIResponse[ExamTypeMasterResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create a custom exam type"
)
async def create_exam_type(
    obj_in: ExamTypeMasterCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.create")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[ExamTypeMasterResponse]:
    if obj_in.school_id:
        await verify_school_access(current_user, obj_in.school_id, service.exam_repo.db)
    db_obj = await service.create_exam_type(tenant_id, obj_in, current_user)
    return APIResponse[ExamTypeMasterResponse](
        success=True,
        message="Exam type created successfully.",
        data=ExamTypeMasterResponse.model_validate(db_obj)
    )

@router.get(
    "/types/{id}",
    response_model=APIResponse[ExamTypeMasterResponse],
    status_code=status.HTTP_200_OK,
    summary="Get single exam type details"
)
async def get_exam_type(
    id: uuid.UUID,
    school_id: Optional[uuid.UUID] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.read")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[ExamTypeMasterResponse]:
    if school_id:
        await verify_school_access(current_user, school_id, service.exam_repo.db)
    db_obj = await service.get_exam_type(tenant_id, school_id, id)
    return APIResponse[ExamTypeMasterResponse](
        success=True,
        message="Exam type fetched successfully.",
        data=ExamTypeMasterResponse.model_validate(db_obj)
    )

@router.put(
    "/types/{id}",
    response_model=APIResponse[ExamTypeMasterResponse],
    status_code=status.HTTP_200_OK,
    summary="Update custom exam type"
)
async def update_exam_type(
    id: uuid.UUID,
    obj_in: ExamTypeMasterUpdate,
    school_id: Optional[uuid.UUID] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.update")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[ExamTypeMasterResponse]:
    if school_id:
        await verify_school_access(current_user, school_id, service.exam_repo.db)
    db_obj = await service.update_exam_type(tenant_id, school_id, id, obj_in, current_user)
    return APIResponse[ExamTypeMasterResponse](
        success=True,
        message="Exam type updated successfully.",
        data=ExamTypeMasterResponse.model_validate(db_obj)
    )

@router.delete(
    "/types/{id}",
    response_model=APIResponse[ExamTypeMasterResponse],
    status_code=status.HTTP_200_OK,
    summary="Delete custom exam type"
)
async def delete_exam_type(
    id: uuid.UUID,
    school_id: Optional[uuid.UUID] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.delete")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[ExamTypeMasterResponse]:
    if school_id:
        await verify_school_access(current_user, school_id, service.exam_repo.db)
    db_obj = await service.delete_exam_type(tenant_id, school_id, id, current_user)
    return APIResponse[ExamTypeMasterResponse](
        success=True,
        message="Exam type deleted successfully.",
        data=ExamTypeMasterResponse.model_validate(db_obj)
    )


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
    await verify_school_access(current_user, school_id, service.exam_repo.db)
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
    await verify_school_access(current_user, school_id, service.exam_repo.db)
    db_objs = await service.template_repo.get_multi(school_id, tenant_id, skip, limit)
    return APIResponse[List[ExamTemplateResponse]](
        success=True,
        message="Examination templates listed successfully.",
        data=[ExamTemplateResponse.model_validate(t) for t in db_objs]
    )


# ==================================================
# Timetable & Schedule Endpoints
# ==================================================
@router.get(
    "/schedules",
    response_model=APIResponse[List[ExamScheduleResponse]],
    status_code=status.HTTP_200_OK,
    summary="List examination timetable schedules"
)
async def list_schedules(
    school_id: uuid.UUID = Query(...),
    exam_id: Optional[uuid.UUID] = Query(None),
    class_id: Optional[uuid.UUID] = Query(None),
    section_id: Optional[uuid.UUID] = Query(None),
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(500, ge=1, le=500),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.read")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[List[ExamScheduleResponse]]:
    await verify_school_access(current_user, school_id, service.exam_repo.db)
    items = await service.list_schedules(
        tenant_id=tenant_id,
        school_id=school_id,
        exam_id=exam_id,
        class_id=class_id,
        section_id=section_id,
        start_date=start_date,
        end_date=end_date,
        skip=skip,
        limit=limit
    )
    return APIResponse[List[ExamScheduleResponse]](
        success=True,
        message="Examination schedules fetched successfully.",
        data=[ExamScheduleResponse.model_validate(s) for s in items]
    )

@router.get(
    "/{exam_id}/schedules",
    response_model=APIResponse[List[ExamScheduleResponse]],
    status_code=status.HTTP_200_OK,
    summary="List schedules for a specific examination"
)
async def list_exam_schedules(
    exam_id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    class_id: Optional[uuid.UUID] = Query(None),
    section_id: Optional[uuid.UUID] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.read")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[List[ExamScheduleResponse]]:
    await verify_school_access(current_user, school_id, service.exam_repo.db)
    items = await service.list_schedules(
        tenant_id=tenant_id,
        school_id=school_id,
        exam_id=exam_id,
        class_id=class_id,
        section_id=section_id,
        skip=0,
        limit=500
    )
    return APIResponse[List[ExamScheduleResponse]](
        success=True,
        message="Examination schedules fetched successfully.",
        data=[ExamScheduleResponse.model_validate(s) for s in items]
    )

@router.post(
    "/schedules",
    response_model=APIResponse[ExamScheduleResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create a single exam schedule slot"
)
async def create_schedule(
    obj_in: ExamScheduleCreate,
    school_id: uuid.UUID = Query(...),
    exam_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.create")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[ExamScheduleResponse]:
    await verify_school_access(current_user, school_id, service.exam_repo.db)
    db_obj = await service.create_schedule(tenant_id, school_id, exam_id, obj_in, current_user)
    return APIResponse[ExamScheduleResponse](
        success=True,
        message="Examination schedule slot created successfully.",
        data=ExamScheduleResponse.model_validate(db_obj)
    )

@router.put(
    "/schedules/{id}",
    response_model=APIResponse[ExamScheduleResponse],
    status_code=status.HTTP_200_OK,
    summary="Update exam schedule slot"
)
async def update_schedule(
    id: uuid.UUID,
    obj_in: ExamScheduleUpdate,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.update")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[ExamScheduleResponse]:
    await verify_school_access(current_user, school_id, service.exam_repo.db)
    db_obj = await service.update_schedule(tenant_id, school_id, id, obj_in, current_user)
    return APIResponse[ExamScheduleResponse](
        success=True,
        message="Examination schedule slot updated successfully.",
        data=ExamScheduleResponse.model_validate(db_obj)
    )

@router.delete(
    "/schedules/{id}",
    response_model=APIResponse[dict],
    status_code=status.HTTP_200_OK,
    summary="Delete exam schedule slot"
)
async def delete_schedule(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.delete")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[dict]:
    await verify_school_access(current_user, school_id, service.exam_repo.db)
    await service.delete_schedule(tenant_id, school_id, id, current_user)
    return APIResponse[dict](
        success=True,
        message="Examination schedule slot deleted successfully.",
        data={"id": str(id)}
    )

@router.post(
    "/schedules/bulk-preview",
    response_model=APIResponse[BulkTimetablePreviewResponse],
    status_code=status.HTTP_200_OK,
    summary="Preview auto-generated timetable without persisting"
)
async def preview_bulk_timetable(
    obj_in: BulkTimetablePreviewRequest,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.create")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[BulkTimetablePreviewResponse]:
    await verify_school_access(current_user, obj_in.school_id, service.exam_repo.db)
    preview = await service.preview_bulk_timetable(tenant_id, obj_in.school_id, obj_in)
    return APIResponse[BulkTimetablePreviewResponse](
        success=True,
        message="Bulk timetable preview generated successfully.",
        data=preview
    )

@router.post(
    "/schedules/bulk-confirm",
    response_model=APIResponse[List[ExamScheduleResponse]],
    status_code=status.HTTP_201_CREATED,
    summary="Confirm and persist auto-generated timetable schedules"
)
async def confirm_bulk_timetable(
    obj_in: BulkTimetableConfirmRequest,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.create")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[List[ExamScheduleResponse]]:
    await verify_school_access(current_user, obj_in.school_id, service.exam_repo.db)
    schedules = await service.confirm_bulk_timetable(tenant_id, obj_in.school_id, obj_in, current_user)
    return APIResponse[List[ExamScheduleResponse]](
        success=True,
        message="Bulk timetable confirmed and saved successfully.",
        data=[ExamScheduleResponse.model_validate(s) for s in schedules]
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
    academic_year_id: Optional[uuid.UUID] = Query(None),
    class_ids: List[uuid.UUID] = Query(...),
    start_date: date = Query(...),
    end_date: date = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.read")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[List[Dict[str, Any]]]:
    await verify_school_access(current_user, school_id, service.exam_repo.db)
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
    await verify_school_access(current_user, obj_in.school_id, service.exam_repo.db)
    db_obj = await service.create_examination_wizard(tenant_id, obj_in.school_id, obj_in, current_user)
    resp = ExaminationResponse.model_validate(db_obj)
    resp.participating_class_ids = [pc.class_id for pc in db_obj.participating_classes] if db_obj.participating_classes else []
    return APIResponse[ExaminationResponse](
        success=True,
        message="Examination and all child schedules created successfully.",
        data=resp
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
    await verify_school_access(current_user, school_id, service.exam_repo.db)
    db_obj = await service.copy_examination(tenant_id, school_id, obj_in, current_user)
    resp = ExaminationResponse.model_validate(db_obj)
    resp.participating_class_ids = [pc.class_id for pc in db_obj.participating_classes] if db_obj.participating_classes else []
    return APIResponse[ExaminationResponse](
        success=True,
        message="Examination duplicated and schedules shifted successfully.",
        data=resp
    )

@router.put(
    "/{id}/status",
    response_model=APIResponse[ExaminationResponse],
    status_code=status.HTTP_200_OK,
    summary="Transition examination lifecycle status with validation"
)
async def transition_examination_status(
    id: uuid.UUID,
    req: ExamStatusTransitionRequest,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.update")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[ExaminationResponse]:
    await verify_school_access(current_user, school_id, service.exam_repo.db)
    db_obj = await service.transition_exam_status(tenant_id, school_id, id, req, current_user)
    resp = ExaminationResponse.model_validate(db_obj)
    resp.participating_class_ids = [pc.class_id for pc in db_obj.participating_classes] if db_obj.participating_classes else []
    return APIResponse[ExaminationResponse](
        success=True,
        message=f"Examination status successfully changed to {req.new_status.value}.",
        data=resp
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
    await verify_school_access(current_user, school_id, service.exam_repo.db)
    db_obj = await service.publish_examination(tenant_id, school_id, id, current_user)
    resp = ExaminationResponse.model_validate(db_obj)
    resp.participating_class_ids = [pc.class_id for pc in db_obj.participating_classes] if db_obj.participating_classes else []
    return APIResponse[ExaminationResponse](
        success=True,
        message="Examination published successfully.",
        data=resp
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
    await verify_school_access(current_user, school_id, service.exam_repo.db)
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
    await verify_school_access(current_user, obj_in.school_id, service.exam_repo.db)
    db_obj = await service.create_examination(tenant_id, obj_in.school_id, obj_in, current_user)
    resp = ExaminationResponse.model_validate(db_obj)
    resp.participating_class_ids = [pc.class_id for pc in db_obj.participating_classes] if db_obj.participating_classes else []
    return APIResponse[ExaminationResponse](
        success=True,
        message="Examination master created successfully.",
        data=resp
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
    await verify_school_access(current_user, school_id, service.exam_repo.db)
    db_obj = await service.exam_repo.get_by_id(id, school_id, tenant_id)
    if not db_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Examination not found."
        )
    resp = ExaminationResponse.model_validate(db_obj)
    resp.participating_class_ids = [pc.class_id for pc in db_obj.participating_classes] if db_obj.participating_classes else []
    return APIResponse[ExaminationResponse](
        success=True,
        message="Examination details fetched successfully.",
        data=resp
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
    class_id: Optional[uuid.UUID] = Query(None),
    search: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.read")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[List[ExaminationResponse]]:
    await verify_school_access(current_user, school_id, service.exam_repo.db)
    db_objs = await service.exam_repo.get_multi(
        school_id=school_id,
        tenant_id=tenant_id,
        academic_year_id=academic_year_id,
        class_id=class_id,
        search=search,
        skip=skip,
        limit=limit
    )
    result = []
    for e in db_objs:
        item = ExaminationResponse.model_validate(e)
        item.participating_class_ids = [pc.class_id for pc in e.participating_classes] if e.participating_classes else []
        result.append(item)
    return APIResponse[List[ExaminationResponse]](
        success=True,
        message="Examinations listed successfully.",
        data=result
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
    await verify_school_access(current_user, school_id, service.exam_repo.db)
    db_obj = await service.update_examination(tenant_id, school_id, id, obj_in, current_user)
    resp = ExaminationResponse.model_validate(db_obj)
    resp.participating_class_ids = [pc.class_id for pc in db_obj.participating_classes] if db_obj.participating_classes else []
    return APIResponse[ExaminationResponse](
        success=True,
        message="Examination updated successfully.",
        data=resp
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
    await verify_school_access(current_user, school_id, service.exam_repo.db)
    db_obj = await service.delete_examination(tenant_id, school_id, id, current_user)
    resp = ExaminationResponse.model_validate(db_obj)
    resp.participating_class_ids = [pc.class_id for pc in db_obj.participating_classes] if db_obj.participating_classes else []
    return APIResponse[ExaminationResponse](
        success=True,
        message="Examination deleted successfully.",
        data=resp
    )
