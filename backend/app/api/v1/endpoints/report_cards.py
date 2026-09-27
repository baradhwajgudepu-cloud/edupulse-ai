import os
import csv
import io
import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status, HTTPException
from fastapi.responses import FileResponse, StreamingResponse

from app.api.dependencies.common import get_tenant_id, verify_school_access
from app.api.dependencies.report_card import get_report_card_service
from app.api.dependencies.auth import require_permission, get_current_user
from app.services.report_card import ReportCardService
from app.services.storage import get_storage_service, StorageService
from app.schemas.report_card import (
    ReportCardGenerateRequest, ReportCardClassGenerateRequest,
    ReportCardRejectRequest, ReportCardUnpublishRequest,
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

# ==================================================
# Parent/Student/Principal Access Checks
# ==================================================
async def verify_student_access(current_user: User, student_id: uuid.UUID, section_id: uuid.UUID, db: AsyncSession) -> None:
    # 1. Bypass check for Super Admins
    if current_user.is_superuser:
        return

    user_roles = [role.code for role in current_user.roles]

    # 2. Platform / Tenant Admins: verify student belongs to active tenant
    if any(code in ["SUPER_ADMIN", "SYSTEM_ADMIN", "TENANT_ADMIN", "CHAIRMAN"] for code in user_roles):
        from app.models.student import Student
        stmt = select(1).select_from(Student).where(
            Student.id == student_id,
            Student.tenant_id == current_user.tenant_id
        )
        if (await db.execute(stmt)).scalar():
            return

    # 3. School Admins & Principals: verify student belongs to user's assigned school(s) and tenant
    if any(code in ["ADMIN", "PRINCIPAL", "SCHOOL_ADMIN"] for code in user_roles):
        from app.models.student import Student
        from app.models.role import school_users
        user_school_ids = [s.id for s in current_user.schools] if current_user.schools else []
        
        # Build school check conditions
        school_conditions = []
        if user_school_ids:
            school_conditions.append(Student.school_id.in_(user_school_ids))
        
        school_user_subq = select(school_users.c.school_id).where(school_users.c.user_id == current_user.id)
        school_conditions.append(Student.school_id.in_(school_user_subq))

        from sqlalchemy import or_
        stmt = select(1).select_from(Student).where(
            Student.id == student_id,
            Student.tenant_id == current_user.tenant_id,
            or_(*school_conditions)
        )
        if (await db.execute(stmt)).scalar():
            return

    # 4. Parents: Check parent-child linkage via student_guardians table
    if "PARENT" in user_roles:
        from app.models.guardian import Guardian, StudentGuardian
        
        from sqlalchemy import or_
        stmt = select(1).select_from(StudentGuardian).join(
            Guardian, StudentGuardian.guardian_id == Guardian.id
        ).where(
            StudentGuardian.student_id == student_id,
            or_(Guardian.user_id == current_user.id, Guardian.email == current_user.email)
        )
        res = await db.execute(stmt)
        if res.scalar():
            return

    # 5. Teachers: Check if teacher has active subject assignment in student's section
    if "TEACHER" in user_roles:
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


@router.get(
    "/student/{student_id}",
    response_model=APIResponse[ReportCardResponse],
    status_code=status.HTTP_200_OK,
    summary="Get published report card for student in academic year"
)
async def get_student_report_card(
    student_id: uuid.UUID,
    academic_year_id: Optional[uuid.UUID] = Query(None),
    school_id: Optional[uuid.UUID] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("report_card.read")),
    service: ReportCardService = Depends(get_report_card_service)
) -> APIResponse[ReportCardResponse]:
    from app.models.student import Student
    stmt_st = select(Student).where(
        Student.id == student_id,
        Student.tenant_id == tenant_id,
        Student.deleted_at.is_(None)
    )
    res_st = await service.report_repo.db.execute(stmt_st)
    student = res_st.scalar_one_or_none()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found.")

    target_school_id = school_id or student.school_id
    await verify_school_access(current_user, target_school_id, service.report_repo.db)
    await verify_student_access(current_user, student_id, student.section_id, service.report_repo.db)

    target_ay_id = academic_year_id or student.academic_year_id
    db_obj = await service.report_repo.get_by_student_and_year(student_id, target_ay_id, tenant_id)
    if not db_obj and not academic_year_id:
        db_obj = await service.report_repo.get_latest_published(student_id, tenant_id)
    if not db_obj:
        raise HTTPException(status_code=404, detail="No report card found for student.")

    role_codes = {r.code for r in current_user.roles}
    if "PARENT" in role_codes and not current_user.is_superuser and db_obj.status != ReportCardStatus.PUBLISHED:
        raise HTTPException(status_code=404, detail="Report card is not published.")

    return APIResponse[ReportCardResponse](
        success=True,
        message="Report card retrieved successfully.",
        data=ReportCardResponse.model_validate(db_obj)
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
    "/{id}/reject",
    response_model=APIResponse[ReportCardResponse],
    status_code=status.HTTP_200_OK,
    summary="Reject a report card under review with a required reason"
)
async def reject_report_card(
    id: uuid.UUID,
    obj_in: ReportCardRejectRequest,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("report_card.publish")),
    service: ReportCardService = Depends(get_report_card_service)
) -> APIResponse[ReportCardResponse]:
    await verify_school_access(current_user, school_id, service.report_repo.db)
    db_obj = await service.reject_report_card(tenant_id, school_id, id, obj_in, current_user)
    return APIResponse[ReportCardResponse](
        success=True,
        message="Report card rejected and returned to draft for corrections.",
        data=ReportCardResponse.model_validate(db_obj)
    )

@router.post(
    "/{id}/unpublish",
    response_model=APIResponse[ReportCardResponse],
    status_code=status.HTTP_200_OK,
    summary="Unpublish a published report card for correction"
)
async def unpublish_report_card(
    id: uuid.UUID,
    obj_in: ReportCardUnpublishRequest,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("report_card.publish")),
    service: ReportCardService = Depends(get_report_card_service)
) -> APIResponse[ReportCardResponse]:
    await verify_school_access(current_user, school_id, service.report_repo.db)
    db_obj = await service.unpublish_report_card(tenant_id, school_id, id, obj_in, current_user)
    return APIResponse[ReportCardResponse](
        success=True,
        message="Report card unpublished successfully.",
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
    school_id: Optional[uuid.UUID] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("report_card.download")),
    service: ReportCardService = Depends(get_report_card_service),
    storage_service: StorageService = Depends(get_storage_service)
) -> StreamingResponse:
    if not school_id:
        from app.models.student import Student
        stmt = select(Student).where(
            Student.id == student_id,
            Student.tenant_id == tenant_id,
            Student.deleted_at.is_(None)
        )
        res = await service.report_repo.db.execute(stmt)
        student = res.scalars().first()
        if not student:
            raise HTTPException(status_code=404, detail="Student not found.")
        school_id = student.school_id
    else:
        student = await service.student_repo.get_by_id(student_id, school_id, tenant_id)
        if not student:
            raise HTTPException(status_code=404, detail="Student not found.")

    await verify_school_access(current_user, school_id, service.report_repo.db)
    await verify_student_access(current_user, student_id, student.section_id, service.report_repo.db)

    db_obj = await service.report_repo.get_by_student_and_year(student_id, student.academic_year_id, tenant_id)

    gcs_path = f"report_cards/{tenant_id}/{school_id}/{student_id}_report.pdf"
    
    needs_generation = True
    pdf_data = None
    if db_obj and db_obj.pdf_url:
        try:
            pdf_data = await storage_service.download(gcs_path)
            if b"%PDF-" in pdf_data[:100] and b"Mock" not in pdf_data and b"ReportLab" in pdf_data and len(pdf_data) > 300:
                needs_generation = False
        except Exception:
            pass

    if needs_generation:
        # Load or create dynamic preview details
        r_type = db_obj.settings.get("report_card_type", "CONSOLIDATED") if (db_obj and db_obj.settings) else "CONSOLIDATED"
        teacher_remarks = db_obj.settings.get("teacher_remarks") if (db_obj and db_obj.settings) else None
        exam_id = None
        if db_obj and db_obj.settings and db_obj.settings.get("examination_id"):
            try:
                exam_id = uuid.UUID(str(db_obj.settings["examination_id"]))
            except Exception:
                exam_id = None
        preview = await service.compile_live_data(
            tenant_id=tenant_id,
            school_id=school_id,
            student_id=student_id,
            teacher_remarks=teacher_remarks or "Generated on download",
            examination_id=exam_id,
            report_card_type=r_type,
        )
        
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
