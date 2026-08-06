import os
import csv
import io
import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status, HTTPException
from fastapi.responses import FileResponse, StreamingResponse

from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.report_card import get_report_card_service
from app.api.dependencies.auth import require_permission, get_current_user
from app.services.report_card import ReportCardService
from app.schemas.report_card import (
    ReportCardGenerateRequest, ReportCardClassGenerateRequest,
    ReportCardResponse, ReportCardPreviewResponse,
    BulkClassGenerateResponse, VerificationResponse
)
from app.models.user import User
from app.schemas.response import APIResponse
from app.models.report_card import ReportCardStatus

router = APIRouter()

# ==================================================
# Report Card Generations & Previews
# ==================================================
@router.post(
    "/generate",
    response_model=APIResponse[ReportCardResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Generate or regenerate a report card for a single student"
)
async def generate_report_card(
    obj_in: ReportCardGenerateRequest,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("report_card.generate")),
    service: ReportCardService = Depends(get_report_card_service)
) -> APIResponse[ReportCardResponse]:
    db_obj = await service.generate_report_card(tenant_id, obj_in.school_id, obj_in, current_user)
    return APIResponse[ReportCardResponse](
        success=True,
        message="Report card generated successfully.",
        data=ReportCardResponse.model_validate(db_obj)
    )

@router.post(
    "/generate/class",
    response_model=APIResponse[BulkClassGenerateResponse],
    status_code=status.HTTP_201_CREATED,
    summary="One-click bulk generate report cards for an entire class"
)
async def bulk_generate_class(
    obj_in: ReportCardClassGenerateRequest,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("report_card.generate")),
    service: ReportCardService = Depends(get_report_card_service)
) -> APIResponse[BulkClassGenerateResponse]:
    result = await service.bulk_generate_class(tenant_id, obj_in.school_id, obj_in, current_user)
    return APIResponse[BulkClassGenerateResponse](
        success=True,
        message="Bulk generation execution completed.",
        data=result
    )

@router.get(
    "/preview/{student_id}",
    response_model=APIResponse[ReportCardPreviewResponse],
    status_code=status.HTTP_200_OK,
    summary="Live preview compiled report card data before generation"
)
async def preview_report_card(
    student_id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    teacher_remarks: Optional[str] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("report_card.read")),
    service: ReportCardService = Depends(get_report_card_service)
) -> APIResponse[ReportCardPreviewResponse]:
    preview = await service.compile_live_data(tenant_id, school_id, student_id, teacher_remarks)
    return APIResponse[ReportCardPreviewResponse](
        success=True,
        message="Report card preview loaded successfully.",
        data=preview
    )


# ==================================================
# Workflow Approvals
# ==================================================
@router.post(
    "/{id}/submit-review",
    response_model=APIResponse[ReportCardResponse],
    status_code=status.HTTP_200_OK,
    summary="Submit report card for review"
)
async def submit_for_review(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("report_card.generate")),
    service: ReportCardService = Depends(get_report_card_service)
) -> APIResponse[ReportCardResponse]:
    db_obj = await service.submit_for_review(tenant_id, school_id, id, current_user)
    return APIResponse[ReportCardResponse](
        success=True,
        message="Report card submitted for review.",
        data=ReportCardResponse.model_validate(db_obj)
    )

@router.post(
    "/{id}/approve",
    response_model=APIResponse[ReportCardResponse],
    status_code=status.HTTP_200_OK,
    summary="Approve report card publication"
)
async def approve_report_card(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("report_card.publish")),
    service: ReportCardService = Depends(get_report_card_service)
) -> APIResponse[ReportCardResponse]:
    db_obj = await service.approve_report_card(tenant_id, school_id, id, current_user)
    return APIResponse[ReportCardResponse](
        success=True,
        message="Report card approved successfully.",
        data=ReportCardResponse.model_validate(db_obj)
    )

@router.post(
    "/publish",
    response_model=APIResponse[List[ReportCardResponse]],
    status_code=status.HTTP_200_OK,
    summary="Bulk publish approved report cards for class"
)
async def publish_report_cards(
    class_id: uuid.UUID = Query(...),
    section_id: uuid.UUID = Query(...),
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("report_card.publish")),
    service: ReportCardService = Depends(get_report_card_service)
) -> APIResponse[List[ReportCardResponse]]:
    db_objs = await service.publish_report_cards(tenant_id, school_id, class_id, section_id, current_user)
    return APIResponse[List[ReportCardResponse]](
        success=True,
        message="Approved report cards published successfully.",
        data=[ReportCardResponse.model_validate(p) for p in db_objs]
    )


# ==================================================
# Locks & Protections
# ==================================================
@router.post(
    "/{id}/lock",
    response_model=APIResponse[ReportCardResponse],
    status_code=status.HTTP_200_OK,
    summary="Freeze report card from future edits"
)
async def lock_report_card(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("report_card.publish")),
    service: ReportCardService = Depends(get_report_card_service)
) -> APIResponse[ReportCardResponse]:
    db_obj = await service.lock_report_card(tenant_id, school_id, id, current_user)
    return APIResponse[ReportCardResponse](
        success=True,
        message="Report card frozen successfully.",
        data=ReportCardResponse.model_validate(db_obj)
    )

@router.post(
    "/{id}/unlock",
    response_model=APIResponse[ReportCardResponse],
    status_code=status.HTTP_200_OK,
    summary="Authorized unlock of a frozen report card"
)
async def unlock_report_card(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("report_card.publish")),
    service: ReportCardService = Depends(get_report_card_service)
) -> APIResponse[ReportCardResponse]:
    db_obj = await service.unlock_report_card(tenant_id, school_id, id, current_user)
    return APIResponse[ReportCardResponse](
        success=True,
        message="Report card unlocked.",
        data=ReportCardResponse.model_validate(db_obj)
    )


# ==================================================
# Verification Public Route
# ==================================================
@router.get(
    "/verify/{verification_uuid}",
    response_model=APIResponse[VerificationResponse],
    status_code=status.HTTP_200_OK,
    summary="Verify PDF authenticity publicly via verification UUID link"
)
async def verify_report_card(
    verification_uuid: uuid.UUID,
    service: ReportCardService = Depends(get_report_card_service)
) -> APIResponse[VerificationResponse]:
    details = await service.get_verification_details(verification_uuid)
    return APIResponse[VerificationResponse](
        success=True,
        message="Report card signature verification successful.",
        data=details
    )


# ==================================================
# Servings & Remarks Templates
# ==================================================
@router.get(
    "/remarks-templates",
    response_model=APIResponse[List[str]],
    status_code=status.HTTP_200_OK,
    summary="Retrieve static comments template list for quick entry"
)
async def get_remarks_templates() -> APIResponse[List[str]]:
    templates = [
        "Excellent progress.",
        "Good improvement.",
        "Needs additional practice.",
        "Regular attendance and good participation.",
        "Improve consistency in homework."
    ]
    return APIResponse[List[str]](
        success=True,
        message="Remarks templates loaded.",
        data=templates
    )

@router.get(
    "/student/{student_id}",
    response_model=APIResponse[ReportCardResponse],
    status_code=status.HTTP_200_OK,
    summary="Query active student report card publication for parent view"
)
async def get_student_publication(
    student_id: uuid.UUID,
    academic_year_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("report_card.read")),
    service: ReportCardService = Depends(get_report_card_service)
) -> APIResponse[ReportCardResponse]:
    db_obj = await service.report_repo.get_parent_publication(student_id, academic_year_id, tenant_id)
    if not db_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Published report card not found for the student in this academic year."
        )
    return APIResponse[ReportCardResponse](
        success=True,
        message="Student report card loaded.",
        data=ReportCardResponse.model_validate(db_obj)
    )

@router.get(
    "/download/{student_id}",
    summary="Serve compiled PDF report card file download"
)
async def download_report_card(
    student_id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("report_card.download")),
    service: ReportCardService = Depends(get_report_card_service)
) -> FileResponse:
    student = await service.student_repo.get_by_id(student_id, school_id, tenant_id)
    if not student:
        raise HTTPException(status_code=404, detail="Student not found.")

    db_obj = await service.report_repo.get_by_student_and_year(student_id, student.academic_year_id, tenant_id)
    if not db_obj or not db_obj.pdf_url:
        raise HTTPException(status_code=404, detail="Report card PDF file has not been compiled yet.")

    # Convert url to local system path
    local_path = os.path.join("backend", "static", "report_cards", str(tenant_id), str(school_id), f"{student_id}_report.pdf")
    if not os.path.exists(local_path):
         raise HTTPException(status_code=404, detail="Report card PDF file not found on static disk storage.")

    return FileResponse(
        path=local_path,
        media_type="application/pdf",
        filename=f"{student.first_name}_{student.last_name}_ReportCard.pdf"
    )

# ==================================================
# Scoped List & CSV Exports
# ==================================================
@router.get(
    "",
    response_model=None, # Dynamic based on format
    status_code=status.HTTP_200_OK,
    summary="Search, list, and export report card publications"
)
async def list_report_cards(
    school_id: uuid.UUID = Query(...),
    academic_year_id: Optional[uuid.UUID] = Query(None),
    class_id: Optional[uuid.UUID] = Query(None),
    section_id: Optional[uuid.UUID] = Query(None),
    status: Optional[ReportCardStatus] = Query(None),
    format: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("report_card.read")),
    service: ReportCardService = Depends(get_report_card_service)
) -> Any:
    db_objs = await service.report_repo.get_multi(
        school_id=school_id,
        tenant_id=tenant_id,
        academic_year_id=academic_year_id,
        class_id=class_id,
        section_id=section_id,
        status=status,
        skip=skip,
        limit=limit
    )

    if format == "csv":
        # Dynamic CSV generation
        stream = io.StringIO()
        writer = csv.writer(stream)
        writer.writerow(["Report Card ID", "Student ID", "Status", "Version", "Generated At", "PDF URL"])
        
        for p in db_objs:
            writer.writerow([
                str(p.id),
                str(p.student_id),
                p.status.value,
                p.version,
                p.generated_at.isoformat() if p.generated_at else "",
                p.pdf_url or ""
            ])
            
        stream.seek(0)
        return StreamingResponse(
            io.BytesIO(stream.getvalue().encode("utf-8")),
            media_type="text/csv",
            headers={"Content-Disposition": "attachment; filename=report_cards_export.csv"}
        )

    # Standard JSON APIResponse
    return APIResponse[List[ReportCardResponse]](
        success=True,
        message="Report card publications listed successfully.",
        data=[ReportCardResponse.model_validate(p) for p in db_objs]
    )
