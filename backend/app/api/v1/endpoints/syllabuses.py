import uuid
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, Query, Body, status, HTTPException

from app.db.session import get_db
from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.syllabus import get_syllabus_service
from app.api.dependencies.auth import require_permission, get_current_user
from app.services.syllabus import SyllabusService
from app.schemas.syllabus import (
    SyllabusCreate, SyllabusUpdate, SyllabusResponse,
    SyllabusCoverageUpdate, SubjectCoverageSummary,
    SyllabusReorderRequest, SyllabusCoverageProgressUpdate,
    SyllabusCoverageProgressRead,
    UnitRenameRequest, UnitDeleteRequest,
    ChapterUpdateRequest, ChapterDeleteRequest,
    ClassSubjectDeleteRequest,
    TopicCreateRequest, ChapterCreateRequest, UnitCreateRequest
)
from app.models.user import User
from app.schemas.response import APIResponse

router = APIRouter()

@router.post(
    "",
    response_model=APIResponse[SyllabusResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create a new syllabus entry"
)
async def create_syllabus(
    obj_in: SyllabusCreate,
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("syllabus.create")),
    service: SyllabusService = Depends(get_syllabus_service)
) -> APIResponse[SyllabusResponse]:
    db_obj = await service.create_syllabus_entry(
        tenant_id=tenant_id,
        school_id=school_id,
        academic_year_id=academic_year_id,
        obj_in=obj_in,
        current_user=current_user
    )
    return APIResponse[SyllabusResponse](
        success=True,
        message="Syllabus entry created successfully.",
        data=SyllabusResponse.model_validate(db_obj)
    )

@router.post(
    "/topic",
    response_model=APIResponse[SyllabusResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Add a new custom syllabus topic"
)
async def create_topic(
    obj_in: TopicCreateRequest,
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("syllabus.create")),
    service: SyllabusService = Depends(get_syllabus_service)
) -> APIResponse[SyllabusResponse]:
    prefix = "".join([c for c in obj_in.topic_name if c.isalnum()][:6]).upper() or "TOPIC"
    code = f"{prefix}-{uuid.uuid4().hex[:4].upper()}"

    seq = obj_in.sequence_order
    if seq is None:
        existing = await service.syllabus_repo.get_multi(
            school_id=school_id,
            tenant_id=tenant_id,
            academic_year_id=academic_year_id,
            class_id=obj_in.class_id,
            subject_id=obj_in.subject_id,
            section_id=obj_in.section_id,
            limit=500
        )
        seq = (max([s.sequence_order for s in existing], default=0)) + 1

    s_create = SyllabusCreate(
        class_id=obj_in.class_id,
        subject_id=obj_in.subject_id,
        section_id=obj_in.section_id,
        syllabus_code=code,
        unit_name=obj_in.unit_name.strip(),
        chapter_name=obj_in.chapter_name.strip(),
        topic_name=obj_in.topic_name.strip(),
        description=obj_in.description,
        sequence_order=seq,
        estimated_periods=obj_in.estimated_periods,
        coverage_status="PENDING",
        lifecycle_status="PLANNED"
    )
    db_obj = await service.create_syllabus_entry(
        tenant_id=tenant_id,
        school_id=school_id,
        academic_year_id=academic_year_id,
        obj_in=s_create,
        current_user=current_user
    )
    db_obj.is_custom = True
    await service.syllabus_repo.db.commit()
    await service.syllabus_repo.db.refresh(db_obj)

    return APIResponse[SyllabusResponse](
        success=True,
        message=f"Topic '{obj_in.topic_name}' created successfully in {obj_in.unit_name} → {obj_in.chapter_name}.",
        data=SyllabusResponse.model_validate(db_obj)
    )

@router.post(
    "/chapter",
    response_model=APIResponse[SyllabusResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Add a new chapter with initial topic under a unit"
)
async def create_chapter(
    obj_in: ChapterCreateRequest,
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("syllabus.create")),
    service: SyllabusService = Depends(get_syllabus_service)
) -> APIResponse[SyllabusResponse]:
    t_name = obj_in.initial_topic_name.strip() if obj_in.initial_topic_name and obj_in.initial_topic_name.strip() else f"Introduction to {obj_in.chapter_name.strip()}"
    prefix = "".join([c for c in obj_in.chapter_name if c.isalnum()][:6]).upper() or "CHAP"
    code = f"{prefix}-{uuid.uuid4().hex[:4].upper()}"

    existing = await service.syllabus_repo.get_multi(
        school_id=school_id,
        tenant_id=tenant_id,
        academic_year_id=academic_year_id,
        class_id=obj_in.class_id,
        subject_id=obj_in.subject_id,
        section_id=obj_in.section_id,
        limit=500
    )
    seq = (max([s.sequence_order for s in existing], default=0)) + 1

    s_create = SyllabusCreate(
        class_id=obj_in.class_id,
        subject_id=obj_in.subject_id,
        section_id=obj_in.section_id,
        syllabus_code=code,
        unit_name=obj_in.unit_name.strip(),
        chapter_name=obj_in.chapter_name.strip(),
        topic_name=t_name,
        description=obj_in.description,
        sequence_order=seq,
        estimated_periods=obj_in.estimated_periods,
        coverage_status="PENDING",
        lifecycle_status="PLANNED"
    )
    db_obj = await service.create_syllabus_entry(
        tenant_id=tenant_id,
        school_id=school_id,
        academic_year_id=academic_year_id,
        obj_in=s_create,
        current_user=current_user
    )
    db_obj.is_custom = True
    await service.syllabus_repo.db.commit()
    await service.syllabus_repo.db.refresh(db_obj)

    return APIResponse[SyllabusResponse](
        success=True,
        message=f"Chapter '{obj_in.chapter_name}' created successfully with initial topic.",
        data=SyllabusResponse.model_validate(db_obj)
    )

@router.post(
    "/unit",
    response_model=APIResponse[SyllabusResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Add a new unit with initial chapter and topic"
)
async def create_unit(
    obj_in: UnitCreateRequest,
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("syllabus.create")),
    service: SyllabusService = Depends(get_syllabus_service)
) -> APIResponse[SyllabusResponse]:
    c_name = obj_in.initial_chapter_name.strip() if obj_in.initial_chapter_name and obj_in.initial_chapter_name.strip() else "Chapter 1: Overview"
    t_name = obj_in.initial_topic_name.strip() if obj_in.initial_topic_name and obj_in.initial_topic_name.strip() else f"Introduction to {obj_in.unit_name.strip()}"
    prefix = "".join([c for c in obj_in.unit_name if c.isalnum()][:6]).upper() or "UNIT"
    code = f"{prefix}-{uuid.uuid4().hex[:4].upper()}"

    existing = await service.syllabus_repo.get_multi(
        school_id=school_id,
        tenant_id=tenant_id,
        academic_year_id=academic_year_id,
        class_id=obj_in.class_id,
        subject_id=obj_in.subject_id,
        section_id=obj_in.section_id,
        limit=500
    )
    seq = (max([s.sequence_order for s in existing], default=0)) + 1

    s_create = SyllabusCreate(
        class_id=obj_in.class_id,
        subject_id=obj_in.subject_id,
        section_id=obj_in.section_id,
        syllabus_code=code,
        unit_name=obj_in.unit_name.strip(),
        chapter_name=c_name,
        topic_name=t_name,
        description=None,
        sequence_order=seq,
        estimated_periods=obj_in.estimated_periods,
        coverage_status="PENDING",
        lifecycle_status="PLANNED"
    )
    db_obj = await service.create_syllabus_entry(
        tenant_id=tenant_id,
        school_id=school_id,
        academic_year_id=academic_year_id,
        obj_in=s_create,
        current_user=current_user
    )
    db_obj.is_custom = True
    await service.syllabus_repo.db.commit()
    await service.syllabus_repo.db.refresh(db_obj)

    return APIResponse[SyllabusResponse](
        success=True,
        message=f"Unit '{obj_in.unit_name}' created successfully with initial chapter and topic.",
        data=SyllabusResponse.model_validate(db_obj)
    )

@router.get(
    "",
    response_model=APIResponse[List[SyllabusResponse]],
    status_code=status.HTTP_200_OK,
    summary="List syllabus entries"
)
async def list_syllabuses(
    school_id: uuid.UUID = Query(...),
    academic_year_id: Optional[uuid.UUID] = Query(None),
    class_id: Optional[uuid.UUID] = Query(None),
    subject_id: Optional[uuid.UUID] = Query(None),
    section_id: Optional[uuid.UUID] = Query(None),
    search: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(500, ge=1, le=1000),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("syllabus.read")),
    service: SyllabusService = Depends(get_syllabus_service)
) -> APIResponse[List[SyllabusResponse]]:
    db_objs = await service.syllabus_repo.get_multi(
        school_id=school_id,
        tenant_id=tenant_id,
        academic_year_id=academic_year_id,
        class_id=class_id,
        subject_id=subject_id,
        section_id=section_id,
        search=search,
        skip=skip,
        limit=limit
    )
    return APIResponse[List[SyllabusResponse]](
        success=True,
        message="Syllabus entries listed successfully.",
        data=[SyllabusResponse.model_validate(s) for s in db_objs]
    )

@router.get(
    "/coverage/summary",
    response_model=APIResponse[List[SubjectCoverageSummary]],
    status_code=status.HTTP_200_OK,
    summary="Get syllabus coverage statistics and chapter breakdowns"
)
async def get_coverage_summary(
    school_id: uuid.UUID = Query(...),
    academic_year_id: Optional[uuid.UUID] = Query(None),
    class_id: Optional[uuid.UUID] = Query(None),
    section_id: Optional[uuid.UUID] = Query(None),
    subject_id: Optional[uuid.UUID] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("syllabus.read")),
    service: SyllabusService = Depends(get_syllabus_service)
) -> APIResponse[List[SubjectCoverageSummary]]:
    summaries = await service.get_coverage_summary(
        tenant_id=tenant_id,
        school_id=school_id,
        academic_year_id=academic_year_id,
        class_id=class_id,
        section_id=section_id,
        subject_id=subject_id
    )
    return APIResponse[List[SubjectCoverageSummary]](
        success=True,
        message="Syllabus coverage summary fetched successfully.",
        data=summaries
    )

@router.get(
    "/{id}",
    response_model=APIResponse[SyllabusResponse],
    status_code=status.HTTP_200_OK,
    summary="Get single syllabus entry details"
)
async def get_syllabus(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("syllabus.read")),
    service: SyllabusService = Depends(get_syllabus_service)
) -> APIResponse[SyllabusResponse]:
    db_obj = await service.syllabus_repo.get_by_id(id, school_id, tenant_id)
    if not db_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Syllabus entry not found."
        )
    return APIResponse[SyllabusResponse](
        success=True,
        message="Syllabus entry details fetched successfully.",
        data=SyllabusResponse.model_validate(db_obj)
    )

@router.put(
    "/{id}",
    response_model=APIResponse[SyllabusResponse],
    status_code=status.HTTP_200_OK,
    summary="Update syllabus entry"
)
async def update_syllabus(
    id: uuid.UUID,
    obj_in: SyllabusUpdate,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("syllabus.update")),
    service: SyllabusService = Depends(get_syllabus_service)
) -> APIResponse[SyllabusResponse]:
    db_obj = await service.update_syllabus_entry(tenant_id, school_id, id, obj_in, current_user)
    return APIResponse[SyllabusResponse](
        success=True,
        message="Syllabus entry updated successfully.",
        data=SyllabusResponse.model_validate(db_obj)
    )

@router.patch(
    "/{id}/coverage",
    response_model=APIResponse[SyllabusResponse],
    status_code=status.HTTP_200_OK,
    summary="Update syllabus coverage status (PENDING, ONGOING, COMPLETED)"
)
async def update_coverage(
    id: uuid.UUID,
    obj_in: SyllabusCoverageUpdate,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("syllabus.update")),
    service: SyllabusService = Depends(get_syllabus_service)
) -> APIResponse[SyllabusResponse]:
    db_obj = await service.update_coverage(
        tenant_id=tenant_id,
        school_id=school_id,
        syllabus_id=id,
        coverage_status=obj_in.coverage_status,
        current_user=current_user
    )
    return APIResponse[SyllabusResponse](
        success=True,
        message=f"Coverage status updated to {obj_in.coverage_status}.",
        data=SyllabusResponse.model_validate(db_obj)
    )

@router.post(
    "/reorder",
    response_model=APIResponse[int],
    status_code=status.HTTP_200_OK,
    summary="Batch reorder syllabus topics or chapters"
)
async def reorder_syllabus(
    req: SyllabusReorderRequest,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("syllabus.update")),
    service: SyllabusService = Depends(get_syllabus_service)
) -> APIResponse[int]:
    count = await service.reorder_entries(tenant_id, school_id, req.items, current_user)
    return APIResponse[int](
        success=True,
        message=f"Successfully updated sequence order for {count} syllabus items.",
        data=count
    )

@router.put(
    "/{id}/lifecycle",
    response_model=APIResponse[SyllabusResponse],
    status_code=status.HTTP_200_OK,
    summary="Update syllabus lifecycle state (PLANNED, IN_PROGRESS, COMPLETED, DEFERRED, REOPENED)"
)
@router.patch(
    "/{id}/lifecycle",
    response_model=APIResponse[SyllabusResponse],
    status_code=status.HTTP_200_OK,
    summary="Update syllabus lifecycle state (PATCH alias)"
)
async def update_lifecycle(
    id: uuid.UUID,
    lifecycle_status: Optional[str] = Query(None, description="PLANNED, IN_PROGRESS, COMPLETED, DEFERRED, REOPENED"),
    school_id: Optional[uuid.UUID] = Query(None),
    data: Optional[Dict[str, Any]] = Body(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("syllabus.update")),
    service: SyllabusService = Depends(get_syllabus_service)
) -> APIResponse[SyllabusResponse]:
    status_val = lifecycle_status
    sid = school_id
    if data:
        if not status_val and "status" in data:
            status_val = data["status"]
        if not status_val and "lifecycle_status" in data:
            status_val = data["lifecycle_status"]
        if not sid and "school_id" in data:
            sid = uuid.UUID(data["school_id"]) if isinstance(data["school_id"], str) else data["school_id"]

    if not status_val:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="lifecycle_status is required")
    if not sid:
        sid = current_user.school_id

    db_obj = await service.update_lifecycle_status(tenant_id, sid, id, status_val, current_user)
    return APIResponse[SyllabusResponse](
        success=True,
        message=f"Lifecycle status updated to {status_val}.",
        data=SyllabusResponse.model_validate(db_obj)
    )


@router.post(
    "/coverage/progress",
    response_model=APIResponse[SyllabusCoverageProgressRead],
    status_code=status.HTTP_200_OK,
    summary="Record section and teacher syllabus coverage progress"
)
async def record_section_progress(
    obj_in: SyllabusCoverageProgressUpdate,
    syllabus_id: uuid.UUID = Query(...),
    section_id: uuid.UUID = Query(...),
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    teacher_id: Optional[uuid.UUID] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("syllabus.update")),
    service: SyllabusService = Depends(get_syllabus_service)
) -> APIResponse[SyllabusCoverageProgressRead]:
    t_id = teacher_id
    if not t_id and hasattr(current_user, "teacher_id") and current_user.teacher_id:
        t_id = current_user.teacher_id

    progress = await service.record_section_progress(
        tenant_id=tenant_id,
        school_id=school_id,
        academic_year_id=academic_year_id,
        section_id=section_id,
        syllabus_id=syllabus_id,
        obj_in=obj_in,
        current_user=current_user,
        teacher_id=t_id
    )
    return APIResponse[SyllabusCoverageProgressRead](
        success=True,
        message=f"Section progress recorded: {obj_in.status} ({obj_in.completion_percentage}%).",
        data=SyllabusCoverageProgressRead.model_validate(progress)
    )

@router.get(
    "/coverage/progress",
    response_model=APIResponse[List[SyllabusCoverageProgressRead]],
    status_code=status.HTTP_200_OK,
    summary="Get section syllabus coverage progress items"
)
async def get_section_progress(
    section_id: uuid.UUID = Query(...),
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    subject_id: Optional[uuid.UUID] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("syllabus.read")),
    service: SyllabusService = Depends(get_syllabus_service)
) -> APIResponse[List[SyllabusCoverageProgressRead]]:
    progress_list = await service.get_section_progress_list(
        tenant_id=tenant_id,
        school_id=school_id,
        academic_year_id=academic_year_id,
        section_id=section_id,
        subject_id=subject_id
    )
    return APIResponse[List[SyllabusCoverageProgressRead]](
        success=True,
        message="Retrieved section progress records.",
        data=[SyllabusCoverageProgressRead.model_validate(p) for p in progress_list]
    )

@router.put(
    "/unit/rename",
    response_model=APIResponse[int],
    status_code=status.HTTP_200_OK,
    summary="Rename a unit across all its topics for a specific class and subject"
)
async def rename_unit(
    req: UnitRenameRequest,
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("syllabus.update")),
    service: SyllabusService = Depends(get_syllabus_service)
) -> APIResponse[int]:
    count = await service.rename_unit(
        tenant_id=tenant_id,
        school_id=school_id,
        academic_year_id=academic_year_id,
        class_id=req.class_id,
        subject_id=req.subject_id,
        old_unit_name=req.old_unit_name,
        new_unit_name=req.new_unit_name,
        current_user=current_user
    )
    return APIResponse[int](
        success=True,
        message=f"Unit renamed successfully across {count} topics.",
        data=count
    )

@router.delete(
    "/unit",
    response_model=APIResponse[int],
    status_code=status.HTTP_200_OK,
    summary="Delete a unit and all its chapters/topics for a specific class and subject"
)
async def delete_unit(
    req: UnitDeleteRequest,
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("syllabus.delete")),
    service: SyllabusService = Depends(get_syllabus_service)
) -> APIResponse[int]:
    count = await service.delete_unit(
        tenant_id=tenant_id,
        school_id=school_id,
        academic_year_id=academic_year_id,
        class_id=req.class_id,
        subject_id=req.subject_id,
        unit_name=req.unit_name,
        current_user=current_user
    )
    return APIResponse[int](
        success=True,
        message=f"Unit '{req.unit_name}' deleted ({count} topics removed).",
        data=count
    )

@router.put(
    "/chapter/update",
    response_model=APIResponse[int],
    status_code=status.HTTP_200_OK,
    summary="Update chapter name, estimated periods, or lifecycle status across all its topics"
)
async def update_chapter(
    req: ChapterUpdateRequest,
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("syllabus.update")),
    service: SyllabusService = Depends(get_syllabus_service)
) -> APIResponse[int]:
    count = await service.update_chapter(
        tenant_id=tenant_id,
        school_id=school_id,
        academic_year_id=academic_year_id,
        class_id=req.class_id,
        subject_id=req.subject_id,
        old_chapter_name=req.old_chapter_name,
        new_chapter_name=req.new_chapter_name,
        unit_name=req.unit_name,
        estimated_periods=req.estimated_periods,
        lifecycle_status=req.lifecycle_status,
        remarks=req.remarks,
        current_user=current_user
    )
    return APIResponse[int](
        success=True,
        message=f"Chapter '{req.new_chapter_name}' updated across {count} topics.",
        data=count
    )

@router.delete(
    "/chapter",
    response_model=APIResponse[int],
    status_code=status.HTTP_200_OK,
    summary="Delete a chapter and all its topics for a class and subject"
)
async def delete_chapter(
    req: ChapterDeleteRequest,
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("syllabus.delete")),
    service: SyllabusService = Depends(get_syllabus_service)
) -> APIResponse[int]:
    count = await service.delete_chapter(
        tenant_id=tenant_id,
        school_id=school_id,
        academic_year_id=academic_year_id,
        class_id=req.class_id,
        subject_id=req.subject_id,
        unit_name=req.unit_name,
        chapter_name=req.chapter_name,
        current_user=current_user
    )
    return APIResponse[int](
        success=True,
        message=f"Chapter '{req.chapter_name}' deleted ({count} topics removed).",
        data=count
    )

@router.delete(
    "/class-subject",
    response_model=APIResponse[int],
    status_code=status.HTTP_200_OK,
    summary="Delete all syllabus entries for a subject within a class"
)
async def delete_class_subject(
    req: ClassSubjectDeleteRequest,
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("syllabus.delete")),
    service: SyllabusService = Depends(get_syllabus_service)
) -> APIResponse[int]:
    count = await service.delete_class_subject(
        tenant_id=tenant_id,
        school_id=school_id,
        academic_year_id=academic_year_id,
        class_id=req.class_id,
        subject_id=req.subject_id,
        current_user=current_user
    )
    return APIResponse[int](
        success=True,
        message=f"Deleted {count} syllabus topics for subject in this class.",
        data=count
    )

@router.delete(
    "/{id}",
    response_model=APIResponse[SyllabusResponse],
    status_code=status.HTTP_200_OK,
    summary="Delete syllabus entry"
)
async def delete_syllabus(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("syllabus.delete")),
    service: SyllabusService = Depends(get_syllabus_service)
) -> APIResponse[SyllabusResponse]:
    db_obj = await service.delete_syllabus_entry(tenant_id, school_id, id, current_user)
    return APIResponse[SyllabusResponse](
        success=True,
        message="Syllabus entry deleted successfully.",
        data=SyllabusResponse.model_validate(db_obj)
    )

@router.get(
    "/student-progress",
    summary="Get sanitized student syllabus progress for parents and students"
)
async def get_student_syllabus_progress_route(
    student_id: uuid.UUID = Query(...),
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    from app.services.syllabus_prediction_engine import SyllabusPredictionEngine
    engine = SyllabusPredictionEngine(db)
    progress = await engine.get_student_syllabus_progress(
        school_id=school_id,
        academic_year_id=academic_year_id,
        student_id=student_id
    )
    return APIResponse(
        success=True,
        message="Retrieved student syllabus progress.",
        data=progress
    )


