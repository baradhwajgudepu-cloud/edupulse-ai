import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status, HTTPException, Body, UploadFile, File, Response

from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.marks import get_marks_service
from app.api.dependencies.auth import require_permission, get_current_user
from app.services.marks import MarksService
from app.schemas.marks import (
    BulkMarksEntry, MarksResponse, SmartMissingSummary,
    PublishSummaryResponse, ResultSummaryResponse, LockUnlockRequest,
    MarksSubmitForReviewRequest, MarksApprovalRequest, MarksReturnRequest,
    MarksReviewQueueItem, ParentExamResultResponse, ParentTimetableSlot,
    ParentReportCardItem, MarksExcelUploadSummary,
    ExamWideUploadPreviewResponse, ExamWideUploadConfirmRequest,
    ExamWideUploadSummary, ExaminationPublishSummary
)
from app.models.user import User
from app.schemas.response import APIResponse

router = APIRouter()

# ==================================================
# Helpers for Security Audit
# ==================================================
async def check_schedule_assignment(db, current_user: User, tenant_id: uuid.UUID, school_id: uuid.UUID, exam_schedule_id: uuid.UUID) -> None:
    role_codes = {r.code for r in current_user.roles}
    is_admin_or_principal = current_user.is_superuser or any(
        code in ["SUPER_ADMIN", "SCHOOL_ADMIN", "PRINCIPAL"] for code in role_codes
    )
    if not is_admin_or_principal and "TEACHER" in role_codes:
        from app.models.examination import ExamSchedule
        from app.repositories.teacher import TeacherRepository
        from app.models.teacher_subject_assignment import TeacherSubjectAssignment, AssignmentStatus
        from sqlalchemy import select

        stmt_s = select(ExamSchedule).where(
            ExamSchedule.id == exam_schedule_id,
            ExamSchedule.school_id == school_id,
            ExamSchedule.tenant_id == tenant_id,
            ExamSchedule.deleted_at.is_(None)
        )
        res_s = await db.execute(stmt_s)
        sched = res_s.scalar_one_or_none()
        if not sched:
            raise HTTPException(status_code=404, detail="Exam schedule slot not found.")

        teacher_repo = TeacherRepository(db)
        teacher = await teacher_repo.get_by_user_id(current_user.id, tenant_id)
        if not teacher:
            raise HTTPException(status_code=403, detail="No active teacher profile found.")

        stmt_tsa = select(TeacherSubjectAssignment).where(
            TeacherSubjectAssignment.teacher_id == teacher.id,
            TeacherSubjectAssignment.class_id == sched.class_id,
            TeacherSubjectAssignment.section_id == sched.section_id,
            TeacherSubjectAssignment.subject_id == sched.subject_id,
            TeacherSubjectAssignment.status == AssignmentStatus.ACTIVE,
            TeacherSubjectAssignment.tenant_id == tenant_id
        )
        res_tsa = await db.execute(stmt_tsa)
        if not res_tsa.scalar_one_or_none():
            raise HTTPException(status_code=403, detail="Access denied. You are not assigned to this class, section, and subject.")

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
    role_codes = {r.code for r in current_user.roles}
    is_admin_or_principal = current_user.is_superuser or any(
        code in ["SUPER_ADMIN", "SCHOOL_ADMIN", "PRINCIPAL"] for code in role_codes
    )
    if not is_admin_or_principal and "TEACHER" in role_codes:
        await check_schedule_assignment(service.marks_repo.db, current_user, tenant_id, school_id, obj_in.exam_schedule_id)

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
    role_codes = {r.code for r in current_user.roles}
    is_admin_or_principal = current_user.is_superuser or any(
        code in ["SUPER_ADMIN", "SCHOOL_ADMIN", "PRINCIPAL"] for code in role_codes
    )
    if not is_admin_or_principal and "TEACHER" in role_codes:
        await check_schedule_assignment(service.marks_repo.db, current_user, tenant_id, school_id, obj_in.exam_schedule_id)

    db_objs = await service.bulk_save_marks(tenant_id, school_id, obj_in, current_user, autosave=False)
    return APIResponse[List[MarksResponse]](
        success=True,
        message="Marks bulk entries updated successfully.",
        data=[MarksResponse.model_validate(m) for m in db_objs]
    )

@router.get(
    "/template",
    status_code=status.HTTP_200_OK,
    summary="Download pre-populated Excel or CSV marks entry template"
)
async def download_marks_template(
    exam_schedule_id: uuid.UUID = Query(...),
    school_id: uuid.UUID = Query(...),
    file_format: str = Query("xlsx", pattern="^(xlsx|csv)$"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("marks.read")),
    service: MarksService = Depends(get_marks_service)
) -> Response:
    await check_schedule_assignment(service.marks_repo.db, current_user, tenant_id, school_id, exam_schedule_id)
    content, filename, media_type = await service.generate_marks_template(
        tenant_id, school_id, exam_schedule_id, file_format
    )
    return Response(
        content=content,
        media_type=media_type,
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"'
        }
    )

@router.post(
    "/upload-excel",
    response_model=APIResponse[MarksExcelUploadSummary],
    status_code=status.HTTP_200_OK,
    summary="Upload and bulk import marks via Excel (.xlsx) or CSV file"
)
async def upload_marks_excel(
    file: UploadFile = File(...),
    exam_schedule_id: uuid.UUID = Query(...),
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("marks.create")),
    service: MarksService = Depends(get_marks_service)
) -> APIResponse[MarksExcelUploadSummary]:
    role_codes = {r.code for r in current_user.roles}
    is_admin_or_principal = current_user.is_superuser or any(
        code in ["SUPER_ADMIN", "SCHOOL_ADMIN", "PRINCIPAL"] for code in role_codes
    )
    if not is_admin_or_principal and "TEACHER" in role_codes:
        await check_schedule_assignment(service.marks_repo.db, current_user, tenant_id, school_id, exam_schedule_id)

    file_bytes = await file.read()
    summary = await service.import_marks_from_file(
        tenant_id, school_id, exam_schedule_id, file_bytes, file.filename or "upload.xlsx", current_user
    )
    return APIResponse[MarksExcelUploadSummary](
        success=True,
        message=f"Marks uploaded successfully for {summary.saved_count} students ({len(summary.errors)} error(s)).",
        data=summary
    )


# ==================================================
# Exam-Wide Bulk Marks Upload & Publishing
# ==================================================
@router.post(
    "/examinations/{exam_id}/bulk-upload-preview",
    response_model=APIResponse[ExamWideUploadPreviewResponse],
    status_code=status.HTTP_200_OK,
    summary="Preview and validate exam-wide bulk marks upload file"
)
async def preview_exam_wide_upload(
    exam_id: uuid.UUID,
    file: UploadFile = File(...),
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("marks.create")),
    service: MarksService = Depends(get_marks_service)
) -> APIResponse[ExamWideUploadPreviewResponse]:
    file_bytes = await file.read()
    preview = await service.preview_exam_wide_marks_file(
        tenant_id=tenant_id,
        school_id=school_id,
        exam_id=exam_id,
        file_bytes=file_bytes,
        filename=file.filename or "upload.xlsx",
        current_user=current_user
    )
    return APIResponse[ExamWideUploadPreviewResponse](
        success=True,
        message=f"File parsed: {preview.valid_rows_count} valid rows, {preview.invalid_rows_count} invalid rows.",
        data=preview
    )

@router.post(
    "/examinations/{exam_id}/bulk-upload-confirm",
    response_model=APIResponse[ExamWideUploadSummary],
    status_code=status.HTTP_200_OK,
    summary="Confirm and commit exam-wide bulk marks upload"
)
async def confirm_exam_wide_upload(
    exam_id: uuid.UUID,
    req: ExamWideUploadConfirmRequest = Body(...),
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("marks.create")),
    service: MarksService = Depends(get_marks_service)
) -> APIResponse[ExamWideUploadSummary]:
    req.exam_id = exam_id
    req.school_id = school_id
    summary = await service.confirm_exam_wide_marks(
        tenant_id=tenant_id,
        school_id=school_id,
        req=req,
        current_user=current_user
    )
    return APIResponse[ExamWideUploadSummary](
        success=True,
        message=f"Exam-wide marks imported: {summary.saved_count} saved for {summary.students_processed} students.",
        data=summary
    )

@router.post(
    "/examinations/{exam_id}/publish",
    response_model=APIResponse[ExaminationPublishSummary],
    status_code=status.HTTP_200_OK,
    summary="Publish all entered marks for a complete examination"
)
async def publish_examination_marks(
    exam_id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("marks.publish")),
    service: MarksService = Depends(get_marks_service)
) -> APIResponse[ExaminationPublishSummary]:
    summary = await service.publish_examination_marks(
        tenant_id=tenant_id,
        school_id=school_id,
        exam_id=exam_id,
        current_user=current_user
    )
    return APIResponse[ExaminationPublishSummary](
        success=True,
        message=f"Examination marks published ({summary.published_count} records). Missing: {summary.missing_count}.",
        data=summary
    )

@router.get(
    "/examinations/{exam_id}/template",
    status_code=status.HTTP_200_OK,
    summary="Download Excel template for complete examination bulk marks upload"
)
async def download_exam_wide_template(
    exam_id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("marks.read")),
    service: MarksService = Depends(get_marks_service)
):
    template_bytes = await service.generate_exam_wide_template(tenant_id, school_id, exam_id)
    return Response(
        content=template_bytes,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f"attachment; filename=Exam_Marks_Template.xlsx"}
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
    await check_schedule_assignment(service.marks_repo.db, current_user, tenant_id, school_id, exam_schedule_id)
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
    await check_schedule_assignment(service.marks_repo.db, current_user, tenant_id, school_id, exam_schedule_id)
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
    await check_schedule_assignment(service.marks_repo.db, current_user, tenant_id, school_id, exam_schedule_id)
    db_objs = await service.publish_marks(tenant_id, school_id, exam_schedule_id, current_user)
    return APIResponse[List[MarksResponse]](
        success=True,
        message="Marks published successfully to parent portal.",
        data=[MarksResponse.model_validate(m) for m in db_objs]
    )

@router.post(
    "/lock",
    response_model=APIResponse[List[MarksResponse]],
    status_code=status.HTTP_200_OK,
    summary="Lock marks entries for an examination schedule"
)
async def lock_marks(
    req: LockUnlockRequest = Body(...),
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("marks.update")),
    service: MarksService = Depends(get_marks_service)
) -> APIResponse[List[MarksResponse]]:
    db_objs = await service.lock_marks(tenant_id, school_id, req.exam_schedule_id, current_user)
    return APIResponse[List[MarksResponse]](
        success=True,
        message="Marks successfully locked.",
        data=[MarksResponse.model_validate(m) for m in db_objs]
    )

@router.post(
    "/unlock",
    response_model=APIResponse[List[MarksResponse]],
    status_code=status.HTTP_200_OK,
    summary="Unlock marks entries for an examination schedule with administrative reason"
)
async def unlock_marks(
    req: LockUnlockRequest = Body(...),
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("marks.update")),
    service: MarksService = Depends(get_marks_service)
) -> APIResponse[List[MarksResponse]]:
    db_objs = await service.unlock_marks(tenant_id, school_id, req.exam_schedule_id, req.reason or "Administrative unlock", current_user)
    return APIResponse[List[MarksResponse]](
        success=True,
        message="Marks successfully unlocked.",
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
    await check_schedule_assignment(service.marks_repo.db, current_user, tenant_id, school_id, exam_schedule_id)
    summary = await service.get_result_summary(tenant_id, school_id, exam_schedule_id)
    return APIResponse[ResultSummaryResponse](
        success=True,
        message="Exam result summary compiled.",
        data=summary
    )


# ==================================================
# Workflow Review & Approval Endpoints
# ==================================================
@router.post(
    "/submit-for-review",
    response_model=APIResponse[List[MarksResponse]],
    status_code=status.HTTP_200_OK,
    summary="Submit entered marks batch for Principal review"
)
async def submit_for_review(
    req: MarksSubmitForReviewRequest = Body(...),
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("marks.update")),
    service: MarksService = Depends(get_marks_service)
) -> APIResponse[List[MarksResponse]]:
    await check_schedule_assignment(service.marks_repo.db, current_user, tenant_id, school_id, req.exam_schedule_id)
    db_objs = await service.submit_for_review(tenant_id, school_id, req.exam_schedule_id, req.notes, current_user, allow_partial=bool(req.allow_partial))
    return APIResponse[List[MarksResponse]](
        success=True,
        message="Marks successfully submitted for Principal review.",
        data=[MarksResponse.model_validate(m) for m in db_objs]
    )

@router.post(
    "/approve",
    response_model=APIResponse[List[MarksResponse]],
    status_code=status.HTTP_200_OK,
    summary="Approve submitted marks batch (Principal / Admin)"
)
async def approve_marks(
    req: MarksApprovalRequest = Body(...),
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("marks.publish")),
    service: MarksService = Depends(get_marks_service)
) -> APIResponse[List[MarksResponse]]:
    role_codes = {r.code for r in current_user.roles}
    is_admin_or_principal = current_user.is_superuser or any(
        code in ["SUPER_ADMIN", "SCHOOL_ADMIN", "PRINCIPAL"] for code in role_codes
    )
    if not is_admin_or_principal:
        raise HTTPException(status_code=403, detail="Only Principals and School Admins can approve marks.")

    db_objs = await service.approve_marks(tenant_id, school_id, req.exam_schedule_id, req.remarks, current_user)
    return APIResponse[List[MarksResponse]](
        success=True,
        message="Marks successfully approved.",
        data=[MarksResponse.model_validate(m) for m in db_objs]
    )

@router.post(
    "/return-for-correction",
    response_model=APIResponse[List[MarksResponse]],
    status_code=status.HTTP_200_OK,
    summary="Return marks batch to teacher for correction with reason"
)
async def return_marks_for_correction(
    req: MarksReturnRequest = Body(...),
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("marks.update")),
    service: MarksService = Depends(get_marks_service)
) -> APIResponse[List[MarksResponse]]:
    role_codes = {r.code for r in current_user.roles}
    is_admin_or_principal = current_user.is_superuser or any(
        code in ["SUPER_ADMIN", "SCHOOL_ADMIN", "PRINCIPAL"] for code in role_codes
    )
    if not is_admin_or_principal:
        raise HTTPException(status_code=403, detail="Only Principals and School Admins can return marks for correction.")

    db_objs = await service.return_marks_for_correction(tenant_id, school_id, req.exam_schedule_id, req.correction_reason, current_user)
    return APIResponse[List[MarksResponse]](
        success=True,
        message="Marks returned to teacher for correction.",
        data=[MarksResponse.model_validate(m) for m in db_objs]
    )

@router.get(
    "/review-queue",
    response_model=APIResponse[List[MarksReviewQueueItem]],
    status_code=status.HTTP_200_OK,
    summary="List all exam schedule marks batches with submission status for Principal / Admin"
)
async def get_review_queue(
    school_id: uuid.UUID = Query(...),
    examination_id: Optional[uuid.UUID] = Query(None),
    academic_year_id: Optional[uuid.UUID] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("marks.read")),
    service: MarksService = Depends(get_marks_service)
) -> APIResponse[List[MarksReviewQueueItem]]:
    role_codes = {r.code for r in current_user.roles}
    is_admin_or_principal = current_user.is_superuser or any(
        code in ["SUPER_ADMIN", "SCHOOL_ADMIN", "PRINCIPAL"] for code in role_codes
    )
    if not is_admin_or_principal:
        raise HTTPException(status_code=403, detail="Only Principals and School Admins can access the marks review queue.")

    items = await service.get_review_queue(tenant_id, school_id, examination_id, academic_year_id)
    return APIResponse[List[MarksReviewQueueItem]](
        success=True,
        message="Marks review queue loaded.",
        data=items
    )

# ==================================================
# Parent Academics & Results Endpoints
# ==================================================
@router.get(
    "/parent/student/{student_id}",
    response_model=APIResponse[List[ParentExamResultResponse]],
    status_code=status.HTTP_200_OK,
    summary="Get published exam results for a parent's linked student"
)
async def get_parent_student_results(
    student_id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(get_current_user),
    service: MarksService = Depends(get_marks_service)
) -> APIResponse[List[ParentExamResultResponse]]:
    results = await service.get_parent_student_marks(tenant_id, school_id, student_id, current_user)
    return APIResponse[List[ParentExamResultResponse]](
        success=True,
        message="Student published exam results retrieved.",
        data=results
    )

@router.get(
    "/parent/student/{student_id}/timetable",
    response_model=APIResponse[List[ParentTimetableSlot]],
    status_code=status.HTTP_200_OK,
    summary="Get upcoming exam timetable for a parent's linked student"
)
async def get_parent_student_timetable(
    student_id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(get_current_user),
    service: MarksService = Depends(get_marks_service)
) -> APIResponse[List[ParentTimetableSlot]]:
    timetable = await service.get_parent_student_timetable(tenant_id, school_id, student_id, current_user)
    return APIResponse[List[ParentTimetableSlot]](
        success=True,
        message="Student exam timetable retrieved.",
        data=timetable
    )

@router.get(
    "/parent/student/{student_id}/report-cards",
    response_model=APIResponse[List[ParentReportCardItem]],
    status_code=status.HTTP_200_OK,
    summary="Get published report cards list for a parent's linked student"
)
async def get_parent_student_report_cards(
    student_id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(get_current_user),
    service: MarksService = Depends(get_marks_service)
) -> APIResponse[List[ParentReportCardItem]]:
    report_cards = await service.get_parent_student_report_cards(tenant_id, school_id, student_id, current_user)
    return APIResponse[List[ParentReportCardItem]](
        success=True,
        message="Student published report cards retrieved.",
        data=report_cards
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

    role_codes = {r.code for r in current_user.roles}
    is_admin_or_principal = current_user.is_superuser or any(
        code in ["SUPER_ADMIN", "SCHOOL_ADMIN", "PRINCIPAL"] for code in role_codes
    )
    if not is_admin_or_principal and "TEACHER" in role_codes:
        from app.repositories.teacher import TeacherRepository
        from app.models.teacher_subject_assignment import TeacherSubjectAssignment, AssignmentStatus
        from sqlalchemy import select
        
        teacher_repo = TeacherRepository(service.marks_repo.db)
        teacher = await teacher_repo.get_by_user_id(current_user.id, tenant_id)
        if not teacher:
            raise HTTPException(status_code=403, detail="No active teacher profile found.")
            
        stmt_tsa = select(TeacherSubjectAssignment).where(
            TeacherSubjectAssignment.teacher_id == teacher.id,
            TeacherSubjectAssignment.class_id == db_obj.class_id,
            TeacherSubjectAssignment.section_id == db_obj.section_id,
            TeacherSubjectAssignment.subject_id == db_obj.subject_id,
            TeacherSubjectAssignment.status == AssignmentStatus.ACTIVE,
            TeacherSubjectAssignment.tenant_id == tenant_id
        )
        res_tsa = await service.marks_repo.db.execute(stmt_tsa)
        if not res_tsa.scalar_one_or_none():
            raise HTTPException(status_code=403, detail="Access denied. You are not assigned to this marks record's class/section/subject.")

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
    role_codes = {r.code for r in current_user.roles}
    is_admin_or_principal = current_user.is_superuser or any(
        code in ["SUPER_ADMIN", "SCHOOL_ADMIN", "PRINCIPAL"] for code in role_codes
    )
    if not is_admin_or_principal and "TEACHER" in role_codes:
        if not class_id or not section_id or not subject_id:
            raise HTTPException(status_code=400, detail="Teachers must filter marks by class_id, section_id, and subject_id.")
        from app.repositories.teacher import TeacherRepository
        from app.models.teacher_subject_assignment import TeacherSubjectAssignment, AssignmentStatus
        from sqlalchemy import select
        
        teacher_repo = TeacherRepository(service.marks_repo.db)
        teacher = await teacher_repo.get_by_user_id(current_user.id, tenant_id)
        if not teacher:
            raise HTTPException(status_code=403, detail="No active teacher profile found.")
            
        stmt_tsa = select(TeacherSubjectAssignment).where(
            TeacherSubjectAssignment.teacher_id == teacher.id,
            TeacherSubjectAssignment.class_id == class_id,
            TeacherSubjectAssignment.section_id == section_id,
            TeacherSubjectAssignment.subject_id == subject_id,
            TeacherSubjectAssignment.status == AssignmentStatus.ACTIVE,
            TeacherSubjectAssignment.tenant_id == tenant_id
        )
        res_tsa = await service.marks_repo.db.execute(stmt_tsa)
        if not res_tsa.scalar_one_or_none():
            raise HTTPException(status_code=403, detail="Access denied. You are not assigned to this class/section/subject.")

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

    role_codes = {r.code for r in current_user.roles}
    is_admin_or_principal = current_user.is_superuser or any(
        code in ["SUPER_ADMIN", "SCHOOL_ADMIN", "PRINCIPAL"] for code in role_codes
    )
    if not is_admin_or_principal and "TEACHER" in role_codes:
        from app.repositories.teacher import TeacherRepository
        from app.models.teacher_subject_assignment import TeacherSubjectAssignment, AssignmentStatus
        from sqlalchemy import select
        
        teacher_repo = TeacherRepository(service.marks_repo.db)
        teacher = await teacher_repo.get_by_user_id(current_user.id, tenant_id)
        if not teacher:
            raise HTTPException(status_code=403, detail="No active teacher profile found.")
            
        stmt_tsa = select(TeacherSubjectAssignment).where(
            TeacherSubjectAssignment.teacher_id == teacher.id,
            TeacherSubjectAssignment.class_id == db_obj.class_id,
            TeacherSubjectAssignment.section_id == db_obj.section_id,
            TeacherSubjectAssignment.subject_id == db_obj.subject_id,
            TeacherSubjectAssignment.status == AssignmentStatus.ACTIVE,
            TeacherSubjectAssignment.tenant_id == tenant_id
        )
        res_tsa = await service.marks_repo.db.execute(stmt_tsa)
        if not res_tsa.scalar_one_or_none():
            raise HTTPException(status_code=403, detail="Access denied. You cannot delete this marks record.")

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
