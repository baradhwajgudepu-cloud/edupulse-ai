import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status, HTTPException

from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.marks import get_marks_service
from app.api.dependencies.auth import require_permission
from app.services.marks import MarksService
from app.schemas.marks import (
    BulkMarksEntry, MarksResponse, SmartMissingSummary,
    PublishSummaryResponse, ResultSummaryResponse
)
from app.models.user import User
from app.schemas.response import APIResponse

router = APIRouter()

# ==================================================
# Bulk Operations
# ==================================================
@router.post(
    "/bulk",
    response_model=APIResponse[List[MarksResponse]],
    status_code=status.HTTP_201_CREATED,
    summary="Bulk insert or autosave marks for a class"
)
async def bulk_save_marks(
    obj_in: BulkMarksEntry,
    school_id: uuid.UUID = Query(...),
    autosave: bool = Query(False),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("marks.create")),
    service: MarksService = Depends(get_marks_service)
) -> APIResponse[List[MarksResponse]]:
    db_objs = await service.bulk_save_marks(tenant_id, school_id, obj_in, current_user, autosave)
    return APIResponse[List[MarksResponse]](
        success=True,
        message="Marks bulk entries saved successfully." if not autosave else "Marks autosaved successfully.",
        data=[MarksResponse.model_validate(m) for m in db_objs]
    )

@router.put(
    "/bulk",
    response_model=APIResponse[List[MarksResponse]],
    status_code=status.HTTP_200_OK,
    summary="Bulk update marks for a class"
)
async def bulk_update_marks(
    obj_in: BulkMarksEntry,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("marks.update")),
    service: MarksService = Depends(get_marks_service)
) -> APIResponse[List[MarksResponse]]:
    db_objs = await service.bulk_save_marks(tenant_id, school_id, obj_in, current_user, autosave=False)
    return APIResponse[List[MarksResponse]](
        success=True,
        message="Marks bulk entries updated successfully.",
        data=[MarksResponse.model_validate(m) for m in db_objs]
    )


# ==================================================
# Wizard Entry & Stats Summaries
# ==================================================
@router.get(
    "/wizard/entry",
    response_model=APIResponse[SmartMissingSummary],
    status_code=status.HTTP_200_OK,
    summary="Fetches entry sheet sorted by roll number with missing indicators and live stats"
)
async def get_wizard_entry(
    exam_schedule_id: uuid.UUID = Query(...),
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("marks.read")),
    service: MarksService = Depends(get_marks_service)
) -> APIResponse[SmartMissingSummary]:
    summary = await service.get_wizard_entry(tenant_id, school_id, exam_schedule_id, current_user)
    return APIResponse[SmartMissingSummary](
        success=True,
        message="Wizard entry list loaded successfully.",
        data=summary
    )

@router.get(
    "/publish/summary",
    response_model=APIResponse[PublishSummaryResponse],
    status_code=status.HTTP_200_OK,
    summary="Retrieve validation summary confirmation details before publishing"
)
async def get_publish_summary(
    exam_schedule_id: uuid.UUID = Query(...),
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("marks.read")),
    service: MarksService = Depends(get_marks_service)
) -> APIResponse[PublishSummaryResponse]:
    summary = await service.get_publish_summary(tenant_id, school_id, exam_schedule_id)
    return APIResponse[PublishSummaryResponse](
        success=True,
        message="Publish summary loaded successfully.",
        data=summary
    )

@router.post(
    "/publish",
    response_model=APIResponse[List[MarksResponse]],
    status_code=status.HTTP_200_OK,
    summary="Bulk publish draft marks for parent portal visibility"
)
async def publish_marks(
    exam_schedule_id: uuid.UUID = Query(...),
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("marks.publish")),
    service: MarksService = Depends(get_marks_service)
) -> APIResponse[List[MarksResponse]]:
    db_objs = await service.publish_marks(tenant_id, school_id, exam_schedule_id, current_user)
    return APIResponse[List[MarksResponse]](
        success=True,
        message="Marks published successfully to parent portal.",
        data=[MarksResponse.model_validate(m) for m in db_objs]
    )

@router.get(
    "/summary",
    response_model=APIResponse[ResultSummaryResponse],
    status_code=status.HTTP_200_OK,
    summary="Retrieve general exam results statistics and pass rates"
)
async def get_result_summary(
    exam_schedule_id: uuid.UUID = Query(...),
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("marks.read")),
    service: MarksService = Depends(get_marks_service)
) -> APIResponse[ResultSummaryResponse]:
    summary = await service.get_result_summary(tenant_id, school_id, exam_schedule_id)
    return APIResponse[ResultSummaryResponse](
        success=True,
        message="Exam result summary compiled.",
        data=summary
    )


# ==================================================
# Remarks Templates
# ==================================================
@router.get(
    "/remarks-templates",
    response_model=APIResponse[List[str]],
    status_code=status.HTTP_200_OK,
    summary="Fetches static remarks templates list for quick entry"
)
async def get_remarks_templates() -> APIResponse[List[str]]:
    templates = ["Excellent", "Good", "Needs Improvement", "Absent", "Medical Leave"]
    return APIResponse[List[str]](
        success=True,
        message="Remarks templates loaded.",
        data=templates
    )


# ==================================================
# Scoped Queries
# ==================================================
@router.get(
    "/student",
    response_model=APIResponse[List[MarksResponse]],
    status_code=status.HTTP_200_OK,
    summary="Query student's published marks for parent view"
)
async def get_parent_marks(
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("marks.read")),
    service: MarksService = Depends(get_marks_service)
) -> APIResponse[List[MarksResponse]]:
    db_objs = await service.marks_repo.get_parent_marks(current_user.email, school_id, tenant_id)
    return APIResponse[List[MarksResponse]](
        success=True,
        message="Student published marks loaded.",
        data=[MarksResponse.model_validate(m) for m in db_objs]
    )


# ==================================================
# Single CRUD Endpoints
# ==================================================
@router.get(
    "/{id}",
    response_model=APIResponse[MarksResponse],
    status_code=status.HTTP_200_OK,
    summary="Get single marks details"
)
async def get_mark(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("marks.read")),
    service: MarksService = Depends(get_marks_service)
) -> APIResponse[MarksResponse]:
    db_obj = await service.marks_repo.get_by_id(id, school_id, tenant_id)
    if not db_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Marks record not found."
        )
    return APIResponse[MarksResponse](
        success=True,
        message="Marks record loaded.",
        data=MarksResponse.model_validate(db_obj)
    )

@router.get(
    "",
    response_model=APIResponse[List[MarksResponse]],
    status_code=status.HTTP_200_OK,
    summary="Search and list marks with filters"
)
async def list_marks(
    school_id: uuid.UUID = Query(...),
    examination_id: Optional[uuid.UUID] = Query(None),
    class_id: Optional[uuid.UUID] = Query(None),
    section_id: Optional[uuid.UUID] = Query(None),
    subject_id: Optional[uuid.UUID] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("marks.read")),
    service: MarksService = Depends(get_marks_service)
) -> APIResponse[List[MarksResponse]]:
    db_objs = await service.marks_repo.get_multi(
        school_id=school_id,
        tenant_id=tenant_id,
        examination_id=examination_id,
        class_id=class_id,
        section_id=section_id,
        subject_id=subject_id,
        skip=skip,
        limit=limit
    )
    return APIResponse[List[MarksResponse]](
        success=True,
        message="Marks records listed successfully.",
        data=[MarksResponse.model_validate(m) for m in db_objs]
    )

@router.delete(
    "/{id}",
    response_model=APIResponse[MarksResponse],
    status_code=status.HTTP_200_OK,
    summary="Soft delete a marks record"
)
async def delete_mark(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("marks.delete")),
    service: MarksService = Depends(get_marks_service)
) -> APIResponse[MarksResponse]:
    db_obj = await service.marks_repo.get_by_id(id, school_id, tenant_id)
    if not db_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Marks record not found."
        )

    # Soft delete
    db_obj.is_active = False
    db_obj.deleted_at = datetime.now(timezone.utc)
    db_obj.updated_by = current_user.id
    service.marks_repo.db.add(db_obj)
    await service.marks_repo.db.commit()

    return APIResponse[MarksResponse](
        success=True,
        message="Marks record soft deleted.",
        data=MarksResponse.model_validate(db_obj)
    )
