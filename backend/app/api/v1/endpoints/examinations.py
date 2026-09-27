import io
import uuid
import logging
from typing import List, Optional, Dict, Any
from datetime import date, datetime, timezone
from fastapi import APIRouter, Depends, Query, status, HTTPException, UploadFile, File, Form

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
    BulkTimetablePreviewRequest, BulkTimetablePreviewResponse, BulkTimetableConfirmRequest,
    ExamPaperCreate, ExamPaperUpdate, ExamPaperResponse,
    ExamPaperClassConfigItem, ExamPaperClassResponse, ExamPaperClassBulkUpdate,
    ExaminationClassesUpdate
)
from app.schemas.exam_question import (
    ExamQuestionCreate, ExamQuestionBulkCreate, ExamQuestionUpdate, ExamQuestionResponse
)
from app.schemas.question_paper import (
    ExamDeletionImpactResponse, ExamDeleteRequest,
    QuestionPaperResponse, QuestionPaperExtractionResponse,
    QuestionPaperVerifyRequest, SyllabusTopicOption,
    QuestionWiseMarksMatrixResponse, QuestionWiseMarksBatchSubmit,
    QuestionWiseAnalyticsResponse, ExtractedQuestionItem
)
from app.repositories.exam_question import ExamQuestionRepository
from app.repositories.question_paper import QuestionPaperRepository
from app.services.question_paper_intelligence import QuestionPaperIntelligenceService
from app.models.question_paper import QuestionPaper
from app.models.examination import Examination, ExamSchedule, ExamPaper, ExamPaperClass
from app.models.exam_question import ExamQuestion, QuestionDifficulty, QuestionType
from app.models.user import User
from app.schemas.response import APIResponse

logger = logging.getLogger(__name__)

router = APIRouter()

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import get_db

async def _resolve_schedule_or_paper(db: AsyncSession, exam_id: uuid.UUID, paper_id: uuid.UUID, school_id: uuid.UUID):
    """
    Dual identifier resolver: paper_id can be ExamSchedule.id or ExamPaper.id.
    Returns: (sched: Optional[ExamSchedule], paper: Optional[ExamPaper], academic_year_id, subject_id, class_id, max_marks)
    """
    sched = await db.get(ExamSchedule, paper_id)
    if sched and sched.exam_id == exam_id and sched.school_id == school_id:
        return (sched, None, sched.academic_year_id, sched.subject_id, sched.class_id, float(sched.max_marks))

    paper = await db.get(ExamPaper, paper_id)
    if paper and paper.examination_id == exam_id and paper.school_id == school_id:
        stmt_s = select(ExamSchedule).where(
            ExamSchedule.exam_id == exam_id,
            ExamSchedule.paper_id == paper.id,
            ExamSchedule.school_id == school_id
        )
        res_s = await db.execute(stmt_s)
        rel_sched = res_s.scalars().first()
        class_id = rel_sched.class_id if rel_sched else (paper.class_configs[0].class_id if paper.class_configs else None)
        max_marks = float(rel_sched.max_marks) if rel_sched else float(paper.default_max_marks)
        return (rel_sched, paper, paper.academic_year_id, paper.subject_id, class_id, max_marks)

    return (None, None, None, None, None, None)

async def verify_school_access(user: User, school_id: uuid.UUID, db: AsyncSession) -> School:
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
        return school

    user_role_codes = [role.code for role in user.roles]
    if "PARENT" in user_role_codes:
        return school

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
    return school

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
    school = await verify_school_access(current_user, school_id, service.exam_repo.db)
    effective_tenant_id = school.tenant_id if (current_user.is_superuser or tenant_id != school.tenant_id) else tenant_id
    items = await service.list_schedules(
        tenant_id=effective_tenant_id,
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
    school = await verify_school_access(current_user, school_id, service.exam_repo.db)
    effective_tenant_id = school.tenant_id if (current_user.is_superuser or tenant_id != school.tenant_id) else tenant_id
    items = await service.list_schedules(
        tenant_id=effective_tenant_id,
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
    schedules = await service.exam_repo.get_parent_schedules(
        current_user.email, school_id, tenant_id, parent_user_id=current_user.id
    )
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

import re

def _format_exam_response(e: Examination) -> ExaminationResponse:
    item = ExaminationResponse.model_validate(e)
    if e.participating_classes:
        item.participating_class_ids = [pc.class_id for pc in e.participating_classes]
        item.participating_class_names = [pc.class_obj.name for pc in e.participating_classes if pc.class_obj]
    else:
        item.participating_class_ids = []
        item.participating_class_names = []

    if item.participating_class_names:
        def class_num(name: str) -> int:
            m = re.search(r'\d+', name)
            return int(m.group()) if m else 999
        c_names_sorted = sorted(item.participating_class_names, key=class_num)
        if len(c_names_sorted) > 2 and class_num(c_names_sorted[0]) != 999 and class_num(c_names_sorted[-1]) != 999:
            item.classes_range_formatted = f"Classes {class_num(c_names_sorted[0])}–{class_num(c_names_sorted[-1])}"
        else:
            item.classes_range_formatted = ", ".join(c_names_sorted)
    else:
        item.classes_range_formatted = "All Classes"

    item.total_papers_count = len(e.papers) if hasattr(e, "papers") and e.papers else 0
    item.total_schedules_count = len(e.schedules) if hasattr(e, "schedules") and e.schedules else 0
    if hasattr(e, "papers") and e.papers:
        item.papers = [ExamPaperResponse.model_validate(p) for p in e.papers]
    return item

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
    school = await verify_school_access(current_user, school_id, service.exam_repo.db)
    effective_tenant_id = school.tenant_id if (current_user.is_superuser or tenant_id != school.tenant_id) else tenant_id
    db_obj = await service.exam_repo.get_by_id(id, school_id, effective_tenant_id)
    if not db_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Examination not found."
        )
    return APIResponse[ExaminationResponse](
        success=True,
        message="Examination details fetched successfully.",
        data=_format_exam_response(db_obj)
    )

@router.get(
    "/{id}/detail",
    response_model=APIResponse[ExaminationResponse],
    status_code=status.HTTP_200_OK,
    summary="Get comprehensive examination cycle details including papers and participating classes"
)
async def get_exam_detail(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.read")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[ExaminationResponse]:
    school = await verify_school_access(current_user, school_id, service.exam_repo.db)
    effective_tenant_id = school.tenant_id if (current_user.is_superuser or tenant_id != school.tenant_id) else tenant_id
    db_obj = await service.exam_repo.get_by_id(id, school_id, effective_tenant_id)
    if not db_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Examination not found."
        )
    return APIResponse[ExaminationResponse](
        success=True,
        message="Examination cycle details loaded.",
        data=_format_exam_response(db_obj)
    )

@router.post(
    "/{id}/classes",
    response_model=APIResponse[List[uuid.UUID]],
    status_code=status.HTTP_200_OK,
    summary="Update participating classes for an examination cycle"
)
async def update_exam_classes(
    id: uuid.UUID,
    obj_in: ExaminationClassesUpdate,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.update")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[List[uuid.UUID]]:
    await verify_school_access(current_user, school_id, service.exam_repo.db)
    updated = await service.update_examination_classes(
        tenant_id=tenant_id,
        school_id=school_id,
        examination_id=id,
        class_ids=obj_in.class_ids,
        current_user=current_user
    )
    return APIResponse[List[uuid.UUID]](
        success=True,
        message="Examination participating classes updated successfully.",
        data=updated
    )

@router.get(
    "/{id}/papers",
    response_model=APIResponse[List[ExamPaperResponse]],
    status_code=status.HTTP_200_OK,
    summary="List papers configured for an examination cycle"
)
async def list_exam_papers(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.read")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[List[ExamPaperResponse]]:
    await verify_school_access(current_user, school_id, service.exam_repo.db)
    papers = await service.list_papers(tenant_id, school_id, id, skip, limit)
    return APIResponse[List[ExamPaperResponse]](
        success=True,
        message="Examination papers listed successfully.",
        data=[ExamPaperResponse.model_validate(p) for p in papers]
    )

@router.post(
    "/{id}/papers",
    response_model=APIResponse[ExamPaperResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Add a new examination paper to a cycle"
)
async def create_exam_paper(
    id: uuid.UUID,
    obj_in: ExamPaperCreate,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.create")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[ExamPaperResponse]:
    await verify_school_access(current_user, school_id, service.exam_repo.db)
    db_obj = await service.create_paper(tenant_id, school_id, id, obj_in, current_user)
    return APIResponse[ExamPaperResponse](
        success=True,
        message="Examination paper created successfully.",
        data=ExamPaperResponse.model_validate(db_obj)
    )

@router.get(
    "/papers/{paper_id}",
    response_model=APIResponse[ExamPaperResponse],
    status_code=status.HTTP_200_OK,
    summary="Get single examination paper details"
)
async def get_exam_paper(
    paper_id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.read")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[ExamPaperResponse]:
    await verify_school_access(current_user, school_id, service.exam_repo.db)
    db_obj = await service.get_paper(tenant_id, school_id, paper_id)
    return APIResponse[ExamPaperResponse](
        success=True,
        message="Examination paper loaded successfully.",
        data=ExamPaperResponse.model_validate(db_obj)
    )

@router.put(
    "/papers/{paper_id}",
    response_model=APIResponse[ExamPaperResponse],
    status_code=status.HTTP_200_OK,
    summary="Update examination paper details"
)
async def update_exam_paper(
    paper_id: uuid.UUID,
    obj_in: ExamPaperUpdate,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.update")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[ExamPaperResponse]:
    await verify_school_access(current_user, school_id, service.exam_repo.db)
    db_obj = await service.update_paper(tenant_id, school_id, paper_id, obj_in, current_user)
    return APIResponse[ExamPaperResponse](
        success=True,
        message="Examination paper updated successfully.",
        data=ExamPaperResponse.model_validate(db_obj)
    )

@router.delete(
    "/papers/{paper_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete an examination paper from a cycle"
)
async def delete_exam_paper(
    paper_id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.delete")),
    service: ExaminationService = Depends(get_examination_service)
) -> None:
    await verify_school_access(current_user, school_id, service.exam_repo.db)
    await service.delete_paper(tenant_id, school_id, paper_id, current_user)

@router.post(
    "/papers/{paper_id}/classes",
    response_model=APIResponse[List[ExamPaperClassResponse]],
    status_code=status.HTTP_200_OK,
    summary="Configure class-specific marks and duration overrides for a paper"
)
async def configure_paper_classes(
    paper_id: uuid.UUID,
    obj_in: ExamPaperClassBulkUpdate,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.update")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[List[ExamPaperClassResponse]]:
    await verify_school_access(current_user, school_id, service.exam_repo.db)
    configs = await service.configure_paper_classes(
        tenant_id=tenant_id,
        school_id=school_id,
        paper_id=paper_id,
        configs=obj_in.configs,
        current_user=current_user
    )
    return APIResponse[List[ExamPaperClassResponse]](
        success=True,
        message="Class-specific paper configurations updated successfully.",
        data=[ExamPaperClassResponse.model_validate(c) for c in configs]
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
    include_inactive: bool = Query(False),
    include_archived: bool = Query(False),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.read")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[List[ExaminationResponse]]:
    school = await verify_school_access(current_user, school_id, service.exam_repo.db)
    effective_tenant_id = school.tenant_id if (current_user.is_superuser or tenant_id != school.tenant_id) else tenant_id
    db_objs = await service.exam_repo.get_multi(
        school_id=school_id,
        tenant_id=effective_tenant_id,
        academic_year_id=academic_year_id,
        class_id=class_id,
        search=search,
        include_inactive=include_inactive,
        include_archived=include_archived,
        skip=skip,
        limit=limit
    )
    return APIResponse[List[ExaminationResponse]](
        success=True,
        message="Examinations listed successfully.",
        data=[_format_exam_response(e) for e in db_objs]
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
    return APIResponse[ExaminationResponse](
        success=True,
        message="Examination updated successfully.",
        data=_format_exam_response(db_obj)
    )

@router.get(
    "/{id}/delete-impact",
    response_model=APIResponse[ExamDeletionImpactResponse],
    status_code=status.HTTP_200_OK,
    summary="Get deletion impact assessment before deleting an examination"
)
async def get_exam_deletion_impact(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.delete")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[ExamDeletionImpactResponse]:
    await verify_school_access(current_user, school_id, service.exam_repo.db)
    impact = await service.get_deletion_impact(tenant_id, school_id, id)
    return APIResponse[ExamDeletionImpactResponse](
        success=True,
        message="Examination deletion impact calculated successfully.",
        data=ExamDeletionImpactResponse.model_validate(impact)
    )

@router.post(
    "/{id}/archive",
    response_model=APIResponse[ExaminationResponse],
    status_code=status.HTTP_200_OK,
    summary="Safely archive an examination to preserve academic records"
)
async def archive_examination(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.update")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[ExaminationResponse]:
    await verify_school_access(current_user, school_id, service.exam_repo.db)
    exam = await service.archive_examination(tenant_id, school_id, id, current_user)
    resp = ExaminationResponse.model_validate(exam)
    resp.participating_class_ids = [pc.class_id for pc in exam.participating_classes] if exam.participating_classes else []
    return APIResponse[ExaminationResponse](
        success=True,
        message=f"Examination '{exam.exam_name}' successfully archived.",
        data=resp
    )

@router.delete(
    "/{id}",
    response_model=APIResponse[ExaminationResponse],
    status_code=status.HTTP_200_OK,
    summary="Delete or archive examination with safety rules"
)
async def delete_exam(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    mode: str = Query("standard", description="standard, archive, permanent"),
    confirmation_name: Optional[str] = Query(None, description="Exact examination name when mode is permanent"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.delete")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[ExaminationResponse]:
    await verify_school_access(current_user, school_id, service.exam_repo.db)
    db_obj = await service.delete_examination(
        tenant_id=tenant_id,
        school_id=school_id,
        exam_id=id,
        current_user=current_user,
        mode=mode,
        confirmation_name=confirmation_name
    )
    resp = ExaminationResponse.model_validate(db_obj)
    resp.participating_class_ids = [pc.class_id for pc in db_obj.participating_classes] if db_obj.participating_classes else []
    action_label = "permanently deleted" if mode == "permanent" else ("archived" if mode == "archive" else "deleted")
    return APIResponse[ExaminationResponse](
        success=True,
        message=f"Examination '{db_obj.exam_name}' successfully {action_label}.",
        data=resp
    )

# ==================================================
# Exam Question Mapping Endpoints
# ==================================================
@router.get(
    "/{exam_id}/questions",
    response_model=APIResponse[List[ExamQuestionResponse]],
    status_code=status.HTTP_200_OK,
    summary="Get questions mapped to an examination"
)
async def get_exam_questions(
    exam_id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    subject_id: Optional[uuid.UUID] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.read")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[List[ExamQuestionResponse]]:
    await verify_school_access(current_user, school_id, db)
    repo = ExamQuestionRepository(db)
    questions = await repo.get_by_examination(exam_id, school_id, tenant_id, subject_id)
    return APIResponse[List[ExamQuestionResponse]](
        success=True,
        message="Examination questions loaded successfully.",
        data=[ExamQuestionResponse.model_validate(q) for q in questions]
    )

@router.post(
    "/{exam_id}/questions",
    response_model=APIResponse[ExamQuestionResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Map a single question to an examination"
)
async def create_exam_question(
    exam_id: uuid.UUID,
    obj_in: ExamQuestionCreate,
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.update")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[ExamQuestionResponse]:
    await verify_school_access(current_user, school_id, db)
    repo = ExamQuestionRepository(db)
    q = await repo.create(
        tenant_id=tenant_id,
        school_id=school_id,
        academic_year_id=academic_year_id,
        examination_id=exam_id,
        obj_in=obj_in,
        created_by=current_user.id
    )
    await db.commit()
    await db.refresh(q)
    return APIResponse[ExamQuestionResponse](
        success=True,
        message=f"Question {q.question_number} mapped successfully.",
        data=ExamQuestionResponse.model_validate(q)
    )

@router.post(
    "/{exam_id}/questions/bulk",
    response_model=APIResponse[List[ExamQuestionResponse]],
    status_code=status.HTTP_200_OK,
    summary="Bulk map or update questions for an examination and subject"
)
async def bulk_create_exam_questions(
    exam_id: uuid.UUID,
    req: ExamQuestionBulkCreate,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.update")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[List[ExamQuestionResponse]]:
    await verify_school_access(current_user, school_id, service.exam_repo.db)
    exam = await service.exam_repo.get_by_id(exam_id, school_id, tenant_id)
    if not exam:
        raise HTTPException(status_code=404, detail="Examination not found.")

    ay_id = req.academic_year_id or exam.academic_year_id
    repo = ExamQuestionRepository(service.exam_repo.db)
    questions = await repo.bulk_create_or_replace(
        tenant_id=tenant_id,
        school_id=school_id,
        academic_year_id=ay_id,
        examination_id=exam_id,
        subject_id=req.subject_id,
        questions=req.questions,
        created_by=current_user.id
    )
    await service.exam_repo.db.commit()
    for q in questions:
        await service.exam_repo.db.refresh(q)
    return APIResponse[List[ExamQuestionResponse]](
        success=True,
        message=f"Successfully mapped {len(questions)} question(s) for examination.",
        data=[ExamQuestionResponse.model_validate(q) for q in questions]
    )

@router.put(
    "/{exam_id}/questions/{question_id}",
    response_model=APIResponse[ExamQuestionResponse],
    status_code=status.HTTP_200_OK,
    summary="Update a question mapping"
)
async def update_exam_question(
    exam_id: uuid.UUID,
    question_id: uuid.UUID,
    obj_in: ExamQuestionUpdate,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.update")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[ExamQuestionResponse]:
    await verify_school_access(current_user, school_id, db)
    repo = ExamQuestionRepository(db)
    q = await repo.get_by_id(question_id, school_id, tenant_id)
    if not q or q.examination_id != exam_id:
        raise HTTPException(status_code=404, detail="Question not found for this examination.")

    updated_q = await repo.update(q, obj_in, updated_by=current_user.id)
    await db.commit()
    await db.refresh(updated_q)
    return APIResponse[ExamQuestionResponse](
        success=True,
        message="Question updated successfully.",
        data=ExamQuestionResponse.model_validate(updated_q)
    )

@router.delete(
    "/{exam_id}/questions/{question_id}",
    response_model=APIResponse[ExamQuestionResponse],
    status_code=status.HTTP_200_OK,
    summary="Delete a question mapping"
)
async def delete_exam_question(
    exam_id: uuid.UUID,
    question_id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.update")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[ExamQuestionResponse]:
    await verify_school_access(current_user, school_id, db)
    repo = ExamQuestionRepository(db)
    q = await repo.get_by_id(question_id, school_id, tenant_id)
    if not q or q.examination_id != exam_id:
        raise HTTPException(status_code=404, detail="Question not found for this examination.")

    del_q = await repo.delete(q, deleted_by=current_user.id)
    res_data = ExamQuestionResponse.model_validate(del_q)
    await db.commit()
    return APIResponse[ExamQuestionResponse](
        success=True,
        message="Question mapping deleted.",
        data=res_data
    )


# ==================================================
# Question Paper Intelligence & Analytics Endpoints
# ==================================================

def safe_difficulty(val: Optional[str]) -> QuestionDifficulty:
    if not val:
        return QuestionDifficulty.MEDIUM
    u = val.upper()
    if u in QuestionDifficulty.__members__:
        return QuestionDifficulty[u]
    return QuestionDifficulty.MEDIUM

def safe_question_type(val: Optional[str]) -> QuestionType:
    if not val:
        return QuestionType.SHORT
    u = val.upper()
    if u in QuestionType.__members__:
        return QuestionType[u]
    return QuestionType.SHORT

def extract_text_from_upload(filename: str, content: bytes) -> str:
    ext = filename.lower().split('.')[-1] if '.' in filename else ''
    if ext == 'pdf':
        try:
            import pypdf
            reader = pypdf.PdfReader(io.BytesIO(content))
            pages_text = []
            for idx, page in enumerate(reader.pages):
                txt = page.extract_text() or ''
                if txt.strip():
                    pages_text.append(f"--- Page {idx + 1} ---\n{txt}")
            return "\n\n".join(pages_text)
        except Exception as e:
            logger.warning(f"Failed to extract PDF text with pypdf: {e}")
            return ""
    else:
        try:
            return content.decode("utf-8")
        except UnicodeDecodeError:
            try:
                return content.decode("latin-1")
            except Exception:
                return ""

def build_question_paper_response(qp: QuestionPaper) -> QuestionPaperResponse:
    root_questions = [q for q in (qp.questions or []) if q.parent_question_id is None]
    root_questions.sort(key=lambda x: (x.sequence_order, x.question_number))
    
    extracted_items = []
    for rq in root_questions:
        sub_items = []
        if rq.sub_questions:
            sorted_subs = sorted(rq.sub_questions, key=lambda s: (s.sequence_order, s.question_number))
            for sq in sorted_subs:
                sub_items.append(ExtractedQuestionItem(
                    id=sq.id,
                    question_number=sq.question_number,
                    parent_question_id=sq.parent_question_id,
                    section_name=sq.section_name,
                    sequence_order=sq.sequence_order,
                    question_text=sq.question_text,
                    max_marks=float(sq.max_marks),
                    question_type=sq.question_type.value if hasattr(sq.question_type, 'value') else str(sq.question_type),
                    difficulty=sq.difficulty.value if hasattr(sq.difficulty, 'value') else str(sq.difficulty),
                    chapter_name=sq.chapter_name,
                    topic_name=sq.topic_name,
                    syllabus_id=sq.syllabus_id,
                    extraction_confidence=float(sq.extraction_confidence) if sq.extraction_confidence is not None else None,
                    mapping_confidence=float(sq.mapping_confidence) if sq.mapping_confidence is not None else None,
                    mapping_source=sq.mapping_source,
                    review_status=sq.review_status,
                    sub_questions=[]
                ))

        extracted_items.append(ExtractedQuestionItem(
            id=rq.id,
            question_number=rq.question_number,
            parent_question_id=None,
            section_name=rq.section_name,
            sequence_order=rq.sequence_order,
            question_text=rq.question_text,
            max_marks=float(rq.max_marks),
            question_type=rq.question_type.value if hasattr(rq.question_type, 'value') else str(rq.question_type),
            difficulty=rq.difficulty.value if hasattr(rq.difficulty, 'value') else str(rq.difficulty),
            chapter_name=rq.chapter_name,
            topic_name=rq.topic_name,
            syllabus_id=rq.syllabus_id,
            extraction_confidence=float(rq.extraction_confidence) if rq.extraction_confidence is not None else None,
            mapping_confidence=float(rq.mapping_confidence) if rq.mapping_confidence is not None else None,
            mapping_source=rq.mapping_source,
            review_status=rq.review_status,
            sub_questions=sub_items
        ))

    return QuestionPaperResponse(
        id=qp.id,
        tenant_id=qp.tenant_id,
        school_id=qp.school_id,
        academic_year_id=qp.academic_year_id,
        examination_id=qp.examination_id,
        paper_id=qp.paper_id,
        title=qp.title,
        total_marks=float(qp.total_marks),
        total_questions=qp.total_questions,
        sections_count=qp.sections_count,
        source_file_name=qp.source_file_name,
        source_file_type=qp.source_file_type,
        storage_reference=qp.storage_reference,
        processing_status=qp.processing_status,
        verification_status=qp.verification_status,
        verified_by=qp.verified_by,
        verified_at=qp.verified_at,
        ai_extraction_metadata=qp.ai_extraction_metadata or {},
        syllabus_coverage_metrics=qp.syllabus_coverage_metrics or {},
        questions=extracted_items,
        created_at=qp.created_at,
        updated_at=qp.updated_at
    )


@router.get(
    "/{exam_id}/papers",
    response_model=APIResponse[List[ExamScheduleResponse]],
    status_code=status.HTTP_200_OK,
    summary="List all paper schedules for an examination"
)
async def list_exam_papers(
    exam_id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    class_id: Optional[uuid.UUID] = Query(None),
    section_id: Optional[uuid.UUID] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.read")),
    service: ExaminationService = Depends(get_examination_service)
) -> APIResponse[List[ExamScheduleResponse]]:
    return await list_exam_schedules(
        exam_id=exam_id,
        school_id=school_id,
        class_id=class_id,
        section_id=section_id,
        tenant_id=tenant_id,
        current_user=current_user,
        service=service
    )


@router.post(
    "/{exam_id}/papers/{paper_id}/question-paper/upload",
    response_model=APIResponse[QuestionPaperExtractionResponse],
    status_code=status.HTTP_200_OK,
    summary="Upload question paper document and extract questions with syllabus mapping"
)
async def upload_and_extract_question_paper(
    exam_id: uuid.UUID,
    paper_id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    file: Optional[UploadFile] = File(None),
    raw_text: Optional[str] = Form(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.update")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[QuestionPaperExtractionResponse]:
    await verify_school_access(current_user, school_id, db)
    sched, paper, ay_id, sub_id, cls_id, default_max = await _resolve_schedule_or_paper(db, exam_id, paper_id, school_id)
    if not (sched or paper):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Paper schedule or paper definition not found for this examination.")

    extracted_text = raw_text or ""
    file_name = None
    file_type = None

    if file:
        file_name = file.filename
        file_type = file.content_type
        content = await file.read()
        f_text = extract_text_from_upload(file.filename or "file.txt", content)
        if f_text:
            extracted_text = f_text if not extracted_text else f"{extracted_text}\n\n{f_text}"

    if not extracted_text.strip():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="No readable content found in uploaded document or input text. Please provide question paper text or upload a valid file."
        )

    intel_svc = QuestionPaperIntelligenceService(db)
    questions, overall_conf, low_conf_cnt = intel_svc.parse_raw_text_to_questions(extracted_text)

    # Map to school configured syllabus topics (strictly zero-hallucination)
    syllabus_options = await intel_svc.get_configured_syllabus_options(
        school_id=school_id,
        academic_year_id=ay_id,
        class_id=cls_id,
        subject_id=sub_id
    )
    mapped_questions = await intel_svc.map_questions_to_syllabus(questions, syllabus_options)

    detected_max_marks = sum(q.max_marks for q in mapped_questions)
    detected_sections = len(set(q.section_name for q in mapped_questions if q.section_name)) or 1

    # Upsert QuestionPaper record
    qp_repo = QuestionPaperRepository(db)
    qp = await qp_repo.get_by_paper_id(paper_id, school_id, tenant_id)
    if not qp:
        qp = QuestionPaper(
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=ay_id,
            examination_id=exam_id,
            paper_id=paper_id,
            title=f"Question Paper - {paper.paper_name if paper else (sched.subject.subject_name if sched and sched.subject else 'Subject')}",
            total_marks=detected_max_marks or default_max,
            total_questions=len(mapped_questions),
            sections_count=detected_sections,
            source_file_name=file_name or "Direct Input",
            source_file_type=file_type or "text/plain",
            processing_status="EXTRACTED",
            verification_status="PENDING_REVIEW",
            ai_extraction_metadata={
                "overall_confidence": overall_conf,
                "low_confidence_count": low_conf_cnt,
                "extracted_at": datetime.now(timezone.utc).isoformat()
            },
            created_by=current_user.id,
            updated_by=current_user.id
        )
        db.add(qp)
        await db.flush()
    else:
        qp.total_marks = detected_max_marks or qp.total_marks
        qp.total_questions = len(mapped_questions)
        qp.sections_count = detected_sections
        qp.processing_status = "EXTRACTED"
        qp.verification_status = "PENDING_REVIEW"
        if file_name:
            qp.source_file_name = file_name
            qp.source_file_type = file_type
        qp.ai_extraction_metadata = {
            "overall_confidence": overall_conf,
            "low_confidence_count": low_conf_cnt,
            "extracted_at": datetime.now(timezone.utc).isoformat()
        }
        qp.updated_by = current_user.id
        db.add(qp)
        await db.flush()

    # Clear previous questions for this paper schedule and persist
    from sqlalchemy import delete
    await db.execute(delete(ExamQuestion).where(ExamQuestion.exam_schedule_id == paper_id))

    for idx, q_item in enumerate(mapped_questions, start=1):
        parent_db_q = ExamQuestion(
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=ay_id,
            examination_id=exam_id,
            subject_id=sub_id,
            exam_schedule_id=paper_id,
            question_paper_id=qp.id,
            parent_question_id=None,
            question_number=q_item.question_number,
            section_name=q_item.section_name or "Section A",
            sequence_order=q_item.sequence_order or idx,
            question_text=q_item.question_text,
            max_marks=q_item.max_marks,
            difficulty=safe_difficulty(q_item.difficulty),
            question_type=safe_question_type(q_item.question_type),
            chapter_name=q_item.chapter_name,
            topic_name=q_item.topic_name,
            syllabus_id=q_item.syllabus_id,
            extraction_confidence=q_item.extraction_confidence,
            mapping_confidence=q_item.mapping_confidence,
            mapping_source=q_item.mapping_source,
            review_status=q_item.review_status,
            created_by=current_user.id,
            updated_by=current_user.id
        )
        db.add(parent_db_q)
        await db.flush()
        q_item.id = parent_db_q.id

        for s_idx, sub_item in enumerate(q_item.sub_questions, start=1):
            sub_db_q = ExamQuestion(
                tenant_id=tenant_id,
                school_id=school_id,
                academic_year_id=ay_id,
                examination_id=exam_id,
                subject_id=sub_id,
                exam_schedule_id=paper_id,
                question_paper_id=qp.id,
                parent_question_id=parent_db_q.id,
                question_number=sub_item.question_number,
                section_name=sub_item.section_name or parent_db_q.section_name,
                sequence_order=sub_item.sequence_order or s_idx,
                question_text=sub_item.question_text,
                max_marks=sub_item.max_marks,
                difficulty=safe_difficulty(sub_item.difficulty or parent_db_q.difficulty.value),
                question_type=safe_question_type(sub_item.question_type or parent_db_q.question_type.value),
                chapter_name=sub_item.chapter_name or parent_db_q.chapter_name,
                topic_name=sub_item.topic_name or parent_db_q.topic_name,
                syllabus_id=sub_item.syllabus_id or parent_db_q.syllabus_id,
                extraction_confidence=sub_item.extraction_confidence,
                mapping_confidence=sub_item.mapping_confidence or parent_db_q.mapping_confidence,
                mapping_source=sub_item.mapping_source or parent_db_q.mapping_source,
                review_status=sub_item.review_status,
                created_by=current_user.id,
                updated_by=current_user.id
            )
            db.add(sub_db_q)
            await db.flush()
            sub_item.id = sub_db_q.id
            sub_item.parent_question_id = parent_db_q.id

    await db.commit()

    return APIResponse[QuestionPaperExtractionResponse](
        success=True,
        message=f"Question paper successfully extracted with {len(mapped_questions)} questions ({low_conf_cnt} flagged for review).",
        data=QuestionPaperExtractionResponse(
            paper_id=paper_id,
            question_paper_id=qp.id,
            title=qp.title,
            detected_questions_count=len(mapped_questions),
            detected_maximum_marks=detected_max_marks,
            detected_sections_count=detected_sections,
            overall_confidence=overall_conf,
            low_confidence_count=low_conf_cnt,
            verification_status=qp.verification_status,
            questions=mapped_questions
        )
    )


@router.get(
    "/{exam_id}/papers/{paper_id}/question-paper",
    response_model=APIResponse[QuestionPaperResponse],
    status_code=status.HTTP_200_OK,
    summary="Get question paper details with mapped questions"
)
async def get_question_paper(
    exam_id: uuid.UUID,
    paper_id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.read")),
    db: AsyncSession = Depends(get_db)
):
    await verify_school_access(current_user, school_id, db)
    qp_repo = QuestionPaperRepository(db)
    qp = await qp_repo.get_by_paper_id(paper_id, school_id, tenant_id)
    if not qp:
        stmt_q = select(QuestionPaper).where(
            QuestionPaper.paper_id == paper_id,
            QuestionPaper.school_id == school_id,
            QuestionPaper.tenant_id == tenant_id,
            QuestionPaper.deleted_at.is_(None)
        )
        res_q = await db.execute(stmt_q)
        qp = res_q.scalars().first()

    if not qp:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Question paper not found for this schedule.")

    return APIResponse[QuestionPaperResponse](
        success=True,
        message="Question paper loaded successfully.",
        data=build_question_paper_response(qp)
    )


@router.put(
    "/{exam_id}/papers/{paper_id}/question-paper/verify",
    response_model=APIResponse[QuestionPaperResponse],
    status_code=status.HTTP_200_OK,
    summary="Save, adjust, and verify question paper after teacher review"
)
async def verify_question_paper(
    exam_id: uuid.UUID,
    paper_id: uuid.UUID,
    payload: QuestionPaperVerifyRequest,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.update")),
    db: AsyncSession = Depends(get_db)
):
    await verify_school_access(current_user, school_id, db)
    sched, paper, ay_id, sub_id, cls_id, default_max = await _resolve_schedule_or_paper(db, exam_id, paper_id, school_id)
    if not (sched or paper):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Paper schedule or paper definition not found.")

    qp_repo = QuestionPaperRepository(db)
    qp = await qp_repo.get_by_paper_id(paper_id, school_id, tenant_id)
    if not qp:
        stmt_q = select(QuestionPaper).where(
            QuestionPaper.paper_id == paper_id,
            QuestionPaper.school_id == school_id,
            QuestionPaper.tenant_id == tenant_id,
            QuestionPaper.deleted_at.is_(None)
        )
        res_q = await db.execute(stmt_q)
        qp = res_q.scalars().first()

    if not qp:
        qp = QuestionPaper(
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=ay_id,
            examination_id=exam_id,
            paper_id=paper_id,
            title=payload.title or (paper.paper_name if paper else "Question Paper"),
            total_marks=payload.total_marks or default_max,
            total_questions=len(payload.questions),
            sections_count=1,
            processing_status="EXTRACTED",
            verification_status="VERIFIED" if payload.mark_as_verified else "PENDING_REVIEW",
            verified_by=current_user.id if payload.mark_as_verified else None,
            verified_at=datetime.now(timezone.utc) if payload.mark_as_verified else None,
            created_by=current_user.id,
            updated_by=current_user.id
        )
        db.add(qp)
        await db.flush()
    else:
        if payload.title:
            qp.title = payload.title
        if payload.total_marks is not None:
            qp.total_marks = payload.total_marks
        qp.total_questions = len(payload.questions)
        if payload.mark_as_verified:
            qp.verification_status = "VERIFIED"
            qp.verified_by = current_user.id
            qp.verified_at = datetime.now(timezone.utc)
        qp.updated_by = current_user.id
        db.add(qp)
        await db.flush()

    # Clear previous questions and re-insert verified hierarchy
    from sqlalchemy import delete
    await db.execute(delete(ExamQuestion).where(ExamQuestion.exam_schedule_id == paper_id))

    for idx, q_item in enumerate(payload.questions, start=1):
        parent_db_q = ExamQuestion(
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=ay_id,
            examination_id=exam_id,
            subject_id=sub_id,
            exam_schedule_id=paper_id,
            question_paper_id=qp.id,
            parent_question_id=None,
            question_number=q_item.question_number,
            section_name=q_item.section_name or "Section A",
            sequence_order=q_item.sequence_order or idx,
            question_text=q_item.question_text,
            max_marks=q_item.max_marks,
            difficulty=safe_difficulty(q_item.difficulty),
            question_type=safe_question_type(q_item.question_type),
            chapter_name=q_item.chapter_name,
            topic_name=q_item.topic_name,
            syllabus_id=q_item.syllabus_id,
            extraction_confidence=q_item.extraction_confidence,
            mapping_confidence=q_item.mapping_confidence or 1.0,
            mapping_source="TEACHER_REVIEWED",
            review_status="VERIFIED" if payload.mark_as_verified else "PENDING",
            created_by=current_user.id,
            updated_by=current_user.id
        )
        db.add(parent_db_q)
        await db.flush()

        for s_idx, sub_item in enumerate(q_item.sub_questions, start=1):
            sub_db_q = ExamQuestion(
                tenant_id=tenant_id,
                school_id=school_id,
                academic_year_id=ay_id,
                examination_id=exam_id,
                subject_id=sub_id,
                exam_schedule_id=paper_id,
                question_paper_id=qp.id,
                parent_question_id=parent_db_q.id,
                question_number=sub_item.question_number,
                section_name=sub_item.section_name or parent_db_q.section_name,
                sequence_order=sub_item.sequence_order or s_idx,
                question_text=sub_item.question_text,
                max_marks=sub_item.max_marks,
                difficulty=safe_difficulty(sub_item.difficulty or parent_db_q.difficulty.value),
                question_type=safe_question_type(sub_item.question_type or parent_db_q.question_type.value),
                chapter_name=sub_item.chapter_name or parent_db_q.chapter_name,
                topic_name=sub_item.topic_name or parent_db_q.topic_name,
                syllabus_id=sub_item.syllabus_id or parent_db_q.syllabus_id,
                extraction_confidence=sub_item.extraction_confidence,
                mapping_confidence=1.0,
                mapping_source="TEACHER_REVIEWED",
                review_status="VERIFIED" if payload.mark_as_verified else "PENDING",
                created_by=current_user.id,
                updated_by=current_user.id
            )
            db.add(sub_db_q)
            await db.flush()

    await db.commit()
    refreshed_qp = await qp_repo.get_by_paper_id(paper_id, school_id, tenant_id)
    if not refreshed_qp:
        stmt_q = select(QuestionPaper).where(
            QuestionPaper.paper_id == paper_id,
            QuestionPaper.school_id == school_id,
            QuestionPaper.tenant_id == tenant_id,
            QuestionPaper.deleted_at.is_(None)
        )
        res_q = await db.execute(stmt_q)
        refreshed_qp = res_q.scalars().first()

    return APIResponse[QuestionPaperResponse](
        success=True,
        message="Question paper successfully reviewed and verified.",
        data=build_question_paper_response(refreshed_qp)
    )


@router.get(
    "/{exam_id}/papers/{paper_id}/syllabus-topics",
    response_model=APIResponse[List[SyllabusTopicOption]],
    status_code=status.HTTP_200_OK,
    summary="Get configured syllabus topics for this paper's class and subject"
)
async def get_paper_syllabus_topics(
    exam_id: uuid.UUID,
    paper_id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.read")),
    db: AsyncSession = Depends(get_db)
):
    await verify_school_access(current_user, school_id, db)
    sched, paper, ay_id, sub_id, cls_id, default_max = await _resolve_schedule_or_paper(db, exam_id, paper_id, school_id)
    if not (sched or paper):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Paper schedule or paper definition not found.")

    intel_svc = QuestionPaperIntelligenceService(db)
    topics = await intel_svc.get_configured_syllabus_options(
        school_id=school_id,
        academic_year_id=ay_id,
        class_id=cls_id,
        subject_id=sub_id
    )
    return APIResponse[List[SyllabusTopicOption]](
        success=True,
        message="Configured syllabus topics retrieved.",
        data=topics
    )


@router.get(
    "/{exam_id}/papers/{paper_id}/marks/question-wise",
    response_model=APIResponse[QuestionWiseMarksMatrixResponse],
    status_code=status.HTTP_200_OK,
    summary="Get question-wise marks spreadsheet matrix for a paper"
)
async def get_question_wise_marks_matrix(
    exam_id: uuid.UUID,
    paper_id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.read")),
    db: AsyncSession = Depends(get_db)
):
    await verify_school_access(current_user, school_id, db)
    sched_id = paper_id
    sched = await db.get(ExamSchedule, paper_id)
    if not sched:
        stmt_s = select(ExamSchedule.id).where(
            ExamSchedule.exam_id == exam_id,
            ExamSchedule.paper_id == paper_id,
            ExamSchedule.school_id == school_id
        )
        res_s = await db.execute(stmt_s)
        found_id = res_s.scalars().first()
        if found_id:
            sched_id = found_id

    intel_svc = QuestionPaperIntelligenceService(db)
    sched, questions, rows, mode = await intel_svc.get_or_build_marks_matrix(sched_id, school_id, tenant_id)

    q_items = [
        ExtractedQuestionItem(
            id=q.id,
            question_number=q.question_number,
            parent_question_id=q.parent_question_id,
            section_name=q.section_name,
            sequence_order=q.sequence_order,
            question_text=q.question_text,
            max_marks=float(q.max_marks),
            question_type=q.question_type.value if hasattr(q.question_type, 'value') else str(q.question_type),
            difficulty=q.difficulty.value if hasattr(q.difficulty, 'value') else str(q.difficulty),
            chapter_name=q.chapter_name,
            topic_name=q.topic_name,
            syllabus_id=q.syllabus_id,
            extraction_confidence=float(q.extraction_confidence) if q.extraction_confidence is not None else None,
            mapping_confidence=float(q.mapping_confidence) if q.mapping_confidence is not None else None,
            mapping_source=q.mapping_source,
            review_status=q.review_status,
            sub_questions=[]
        )
        for q in questions
    ]

    return APIResponse[QuestionWiseMarksMatrixResponse](
        success=True,
        message="Marks matrix loaded successfully.",
        data=QuestionWiseMarksMatrixResponse(
            paper_id=paper_id,
            exam_id=exam_id,
            class_id=sched.class_id,
            section_id=sched.section_id,
            subject_id=sched.subject_id,
            class_name=sched.class_obj.name if sched.class_obj else "Class",
            section_name=sched.section.name if sched.section else "Section",
            subject_name=sched.subject.subject_name if sched.subject else "Subject",
            total_max_marks=float(sched.max_marks),
            questions=q_items,
            rows=rows,
            mode=mode
        )
    )


@router.post(
    "/{exam_id}/papers/{paper_id}/marks/question-wise",
    response_model=APIResponse[Dict[str, Any]],
    status_code=status.HTTP_200_OK,
    summary="Batch save question-wise student marks (draft or final)"
)
async def save_question_wise_marks(
    exam_id: uuid.UUID,
    paper_id: uuid.UUID,
    payload: QuestionWiseMarksBatchSubmit,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.update")),
    db: AsyncSession = Depends(get_db)
):
    await verify_school_access(current_user, school_id, db)
    intel_svc = QuestionPaperIntelligenceService(db)
    result = await intel_svc.save_question_wise_marks(
        paper_id=paper_id,
        rows=payload.rows,
        is_draft=payload.is_draft,
        current_user_id=current_user.id,
        school_id=school_id,
        tenant_id=tenant_id
    )
    return APIResponse[Dict[str, Any]](
        success=True,
        message=result["message"],
        data=result
    )


@router.get(
    "/{exam_id}/papers/{paper_id}/analytics",
    response_model=APIResponse[QuestionWiseAnalyticsResponse],
    status_code=status.HTTP_200_OK,
    summary="Get question-wise and topic assessment analytics"
)
async def get_paper_analytics(
    exam_id: uuid.UUID,
    paper_id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("exam.read")),
    db: AsyncSession = Depends(get_db)
):
    await verify_school_access(current_user, school_id, db)
    intel_svc = QuestionPaperIntelligenceService(db)
    analytics = await intel_svc.get_question_wise_analytics(paper_id, school_id, tenant_id)
    return APIResponse[QuestionWiseAnalyticsResponse](
        success=True,
        message="Analytics calculated successfully.",
        data=analytics
    )


