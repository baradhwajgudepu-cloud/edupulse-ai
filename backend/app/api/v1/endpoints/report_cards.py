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
from app.services.storage import get_storage_service, StorageService
from app.schemas.report_card import (
    ReportCardGenerateRequest, ReportCardClassGenerateRequest,
    ReportCardResponse, ReportCardPreviewResponse,
    BulkClassGenerateResponse, BulkReportCardActionRequest,
    BulkReportCardActionResponse, VerificationResponse,
    StudentAcademicHistoryResponse
)
from app.models.user import User
from app.schemas.response import APIResponse
from app.models.report_card import ReportCardStatus

router = APIRouter()

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

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

    # Parents are not registered in the school_users table (reserved for staff/teachers)
    # but are authorized to access school resources scoped to their children.
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
# Parent/Student Checks
# ==================================================
async def verify_student_access(current_user: User, student_id: uuid.UUID, section_id: uuid.UUID, db: AsyncSession) -> None:
    # 1. Bypass check for Super Admins
    if current_user.is_superuser:
        return

    # Check if the user is a teacher assigned to the student's section or a parent linked to the student
    user_roles = [role.code for role in current_user.roles]
    
    if "PARENT" in user_roles:
        # Check parent-child linkage via student_guardians table
        from app.models.guardian import Guardian, StudentGuardian
        
        stmt = select(1).select_from(StudentGuardian).join(
            Guardian, StudentGuardian.guardian_id == Guardian.id
        ).where(
            StudentGuardian.student_id == student_id,
            Guardian.user_id == current_user.id
        )
        res = await db.execute(stmt)
        if res.scalar():
            return
            
    if "TEACHER" in user_roles:
        # Check if the teacher has any subject assignment in the student's section
        from app.models.teacher import Teacher
        from app.models.teacher_subject_assignment import TeacherSubjectAssignment
        
        stmt_t = select(Teacher.id).where(
            (Teacher.user_id == current_user.id) |
            (Teacher.official_email == current_user.email)
        )
        res_t = await db.execute(stmt_t)
        teacher_id = res_t.scalar_one_or_none()
        
        if teacher_id:
            stmt = select(1).select_from(TeacherSubjectAssignment).where(
                TeacherSubjectAssignment.teacher_id == teacher_id,
                TeacherSubjectAssignment.section_id == section_id,
                TeacherSubjectAssignment.is_active == True
            )
            res = await db.execute(stmt)
            if res.scalar():
                return

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Access denied. You are not authorized to view report cards for this student."
    )


# ==================================================
# Generation Endpoints
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
    await verify_school_access(current_user, obj_in.school_id, service.report_repo.db)
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
    await verify_school_access(current_user, obj_in.school_id, service.report_repo.db)
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
    examination_id: Optional[uuid.UUID] = Query(None),
    teacher_remarks: Optional[str] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("report_card.read")),
    service: ReportCardService = Depends(get_report_card_service)
) -> APIResponse[ReportCardPreviewResponse]:
    await verify_school_access(current_user, school_id, service.report_repo.db)
    student = await service.student_repo.get_by_id(student_id, school_id, tenant_id)
    if not student:
        raise HTTPException(status_code=404, detail="Student not found.")
    await verify_student_access(current_user, student_id, student.section_id, service.report_repo.db)

    preview = await service.compile_live_data(tenant_id, school_id, student_id, teacher_remarks, examination_id)
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
    await verify_school_access(current_user, school_id, service.report_repo.db)
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
    await verify_school_access(current_user, school_id, service.report_repo.db)
    db_obj = await service.approve_report_card(tenant_id, school_id, id, current_user)
    return APIResponse[ReportCardResponse](
        success=True,
        message="Report card approved successfully.",
        data=ReportCardResponse.model_validate(db_obj)
    )

@router.post(
    "/bulk-approve",
    response_model=APIResponse[BulkReportCardActionResponse],
    status_code=status.HTTP_200_OK,
    summary="Bulk approve selected report cards"
)
async def bulk_approve_report_cards(
    obj_in: BulkReportCardActionRequest,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("report_card.publish")),
    service: ReportCardService = Depends(get_report_card_service)
) -> APIResponse[BulkReportCardActionResponse]:
    await verify_school_access(current_user, obj_in.school_id, service.report_repo.db)
    result = await service.bulk_approve_report_cards(tenant_id, obj_in.school_id, obj_in.report_card_ids, current_user)
    return APIResponse[BulkReportCardActionResponse](
        success=True,
        message="Bulk approval operation completed.",
        data=result
    )

@router.post(
    "/bulk-publish",
    response_model=APIResponse[BulkReportCardActionResponse],
    status_code=status.HTTP_200_OK,
    summary="Bulk publish selected report cards"
)
async def bulk_publish_selected_cards(
    obj_in: BulkReportCardActionRequest,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("report_card.publish")),
    service: ReportCardService = Depends(get_report_card_service)
) -> APIResponse[BulkReportCardActionResponse]:
    await verify_school_access(current_user, obj_in.school_id, service.report_repo.db)
    result = await service.bulk_publish_selected_cards(tenant_id, obj_in.school_id, obj_in.report_card_ids, current_user)
    return APIResponse[BulkReportCardActionResponse](
        success=True,
        message="Bulk publish operation completed.",
        data=result
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
    await verify_school_access(current_user, school_id, service.report_repo.db)
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
    await verify_school_access(current_user, school_id, service.report_repo.db)
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
    await verify_school_access(current_user, school_id, service.report_repo.db)
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
    student = await service.student_repo.get_by_id(student_id, db_obj.school_id, tenant_id)
    if student:
        await verify_school_access(current_user, db_obj.school_id, service.report_repo.db)
        await verify_student_access(current_user, student_id, student.section_id, service.report_repo.db)
    return APIResponse[ReportCardResponse](
        success=True,
        message="Student report card loaded.",
        data=ReportCardResponse.model_validate(db_obj)
    )

@router.get(
    "/history/{student_id}",
    response_model=APIResponse[StudentAcademicHistoryResponse],
    status_code=status.HTTP_200_OK,
    summary="Query student academic mark history across all examinations"
)
async def get_student_academic_history(
    student_id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("report_card.read")),
    service: ReportCardService = Depends(get_report_card_service)
) -> APIResponse[StudentAcademicHistoryResponse]:
    await verify_school_access(current_user, school_id, service.report_repo.db)
    student = await service.student_repo.get_by_id(student_id, school_id, tenant_id)
    if not student:
        raise HTTPException(status_code=404, detail="Student not found.")
    await verify_student_access(current_user, student_id, student.section_id, service.report_repo.db)
    
    history = await service.get_student_academic_history(tenant_id, school_id, student_id)
    return APIResponse[StudentAcademicHistoryResponse](
        success=True,
        message="Student academic history loaded successfully.",
        data=history
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
    service: ReportCardService = Depends(get_report_card_service),
    storage_service: StorageService = Depends(get_storage_service)
) -> StreamingResponse:
    await verify_school_access(current_user, school_id, service.report_repo.db)
    student = await service.student_repo.get_by_id(student_id, school_id, tenant_id)
    if not student:
        raise HTTPException(status_code=404, detail="Student not found.")
    await verify_student_access(current_user, student_id, student.section_id, service.report_repo.db)

    db_obj = await service.report_repo.get_by_student_and_year(student_id, student.academic_year_id, tenant_id)
    if not db_obj or not db_obj.pdf_url:
        raise HTTPException(status_code=404, detail="Report card PDF file has not been compiled yet.")

    gcs_path = f"report_cards/{tenant_id}/{school_id}/{student_id}_report.pdf"
    
    needs_generation = True
    pdf_data = None
    try:
        pdf_data = await storage_service.download(gcs_path)
        if b"%PDF-" in pdf_data[:100] and b"Mock" not in pdf_data and b"ReportLab" in pdf_data and len(pdf_data) > 300:
            needs_generation = False
    except Exception:
        pass

    if needs_generation:
        # Load or create dynamic preview details
        preview = await service.compile_live_data(tenant_id, school_id, student_id, "Generated on download")
        
        # Load student academic history and generate ReportLab PDF
        history = await service.get_student_academic_history(tenant_id, school_id, student_id)
        pdf_data = await service.generate_professional_report_card_pdf(
            tenant_id, school_id, student_id, preview, history, db_obj
        )
        await storage_service.upload(pdf_data, gcs_path, "application/pdf")

    return StreamingResponse(
        io.BytesIO(pdf_data),
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{student.first_name}_{student.last_name}_ReportCard.pdf"'}
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
    await verify_school_access(current_user, school_id, service.report_repo.db)
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
