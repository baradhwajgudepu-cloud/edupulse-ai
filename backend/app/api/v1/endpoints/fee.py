import uuid
import os
import logging
from typing import List, Optional
from datetime import date
import io
from fastapi import APIRouter, Depends, status, HTTPException, Header, Query
from fastapi.responses import FileResponse, StreamingResponse

from app.api.dependencies.auth import require_permission, get_current_user
from app.api.dependencies.common import get_tenant_id, get_school_id
from app.api.dependencies.fee import get_fee_service
from app.services.fee import FeeService
from app.services.storage import get_storage_service, StorageService
from app.schemas.fee import (
    FeeTypeCreate, FeeTypeUpdate, FeeTypeResponse,
    ScholarshipCreate, ScholarshipUpdate, ScholarshipResponse,
    FeeStructureCreate, FeeStructureUpdate, FeeStructureResponse,
    StudentFeeAssignmentCreate, StudentFeeAssignmentResponse,
    FeePaymentCreate, FeePaymentResponse, PaymentCancelRequest,
    FeeReceiptResponse, StudentLedgerResponse, DashboardMetricsResponse,
    PaymentImportRequest, PaymentImportResponse,
    OutstandingFeeReportItem, DefaultRiskResponse, CollectionAnalyticsResponse
)
from app.schemas.response import APIResponse
from app.models.user import User

logger = logging.getLogger(__name__)

router = APIRouter()

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import get_db

async def verify_student_access(
    current_user: User,
    student_id: uuid.UUID,
    student_section_id: uuid.UUID,
    db: AsyncSession
) -> None:
    from app.models.guardian import StudentGuardian, Guardian
    from app.models.teacher import Teacher
    from app.models.teacher_subject_assignment import TeacherSubjectAssignment

    user_roles = {r.code for r in current_user.roles}
    user_names = {r.name for r in current_user.roles}
    
    if current_user.is_superuser or any(code in ["SUPER_ADMIN", "ADMIN", "PRINCIPAL", "STAFF"] for code in user_roles):
        return
        
    if "PARENT" in user_roles or "Parent" in user_names:
        stmt = select(StudentGuardian).join(Guardian).where(
            StudentGuardian.student_id == student_id,
            Guardian.user_id == current_user.id
        )
        res = await db.execute(stmt)
        if not res.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. You can only access your own child's fee data."
            )
            
    elif "TEACHER" in user_roles or "Teacher" in user_names:
        stmt_teach = select(Teacher).where(Teacher.user_id == current_user.id)
        res_teach = await db.execute(stmt_teach)
        teacher = res_teach.scalar_one_or_none()
        if not teacher:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. Teacher profile not found."
            )
        stmt_tsa = select(TeacherSubjectAssignment).where(
            TeacherSubjectAssignment.teacher_id == teacher.id,
            TeacherSubjectAssignment.section_id == student_section_id,
            TeacherSubjectAssignment.deleted_at.is_(None)
        )
        res_tsa = await db.execute(stmt_tsa)
        if not res_tsa.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. You are not assigned to this student's section."
            )
    else:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. Insufficient role permissions."
        )

# --- FEE TYPE ENDPOINTS ---
@router.post(
    "/types",
    response_model=APIResponse[FeeTypeResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create Fee Type"
)
async def create_fee_type(
    obj_in: FeeTypeCreate,
    current_user: User = Depends(require_permission("fee.create")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: FeeService = Depends(get_fee_service)
) -> APIResponse[FeeTypeResponse]:
    db_obj = await service.create_fee_type(tenant_id, obj_in, current_user.id)
    return APIResponse(
        success=True,
        message="Fee Type created successfully.",
        data=FeeTypeResponse.model_validate(db_obj)
    )

@router.get(
    "/types",
    response_model=APIResponse[List[FeeTypeResponse]],
    summary="List Fee Types"
)
async def list_fee_types(
    current_user: User = Depends(require_permission("fee.read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: FeeService = Depends(get_fee_service)
) -> APIResponse[List[FeeTypeResponse]]:
    items = await service.list_fee_types(tenant_id)
    return APIResponse(
        success=True,
        message="Fee Types retrieved successfully.",
        data=[FeeTypeResponse.model_validate(x) for x in items]
    )

@router.get(
    "/types/{id}",
    response_model=APIResponse[FeeTypeResponse],
    summary="Get Fee Type Details"
)
async def get_fee_type(
    id: uuid.UUID,
    current_user: User = Depends(require_permission("fee.read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: FeeService = Depends(get_fee_service)
) -> APIResponse[FeeTypeResponse]:
    db_obj = await service.get_fee_type(id, tenant_id)
    return APIResponse(
        success=True,
        message="Fee Type retrieved successfully.",
        data=FeeTypeResponse.model_validate(db_obj)
    )

@router.put(
    "/types/{id}",
    response_model=APIResponse[FeeTypeResponse],
    summary="Update Fee Type"
)
async def update_fee_type(
    id: uuid.UUID,
    obj_in: FeeTypeUpdate,
    current_user: User = Depends(require_permission("fee.update")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: FeeService = Depends(get_fee_service)
) -> APIResponse[FeeTypeResponse]:
    updated = await service.update_fee_type(id, tenant_id, obj_in, current_user.id)
    return APIResponse(
        success=True,
        message="Fee Type updated successfully.",
        data=FeeTypeResponse.model_validate(updated)
    )

@router.delete(
    "/types/{id}",
    response_model=APIResponse[FeeTypeResponse],
    summary="Delete Fee Type"
)
async def delete_fee_type(
    id: uuid.UUID,
    current_user: User = Depends(require_permission("fee.delete")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: FeeService = Depends(get_fee_service)
) -> APIResponse[FeeTypeResponse]:
    deleted = await service.delete_fee_type(id, tenant_id, current_user.id)
    return APIResponse(
        success=True,
        message="Fee Type deleted successfully.",
        data=FeeTypeResponse.model_validate(deleted)
    )


# --- SCHOLARSHIP ENDPOINTS ---
@router.post(
    "/scholarships",
    response_model=APIResponse[ScholarshipResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create Scholarship/Concession"
)
async def create_scholarship(
    obj_in: ScholarshipCreate,
    current_user: User = Depends(require_permission("fee.create")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    school_id: uuid.UUID = Depends(get_school_id),
    service: FeeService = Depends(get_fee_service)
) -> APIResponse[ScholarshipResponse]:
    db_obj = await service.create_scholarship(tenant_id, school_id, obj_in, current_user.id)
    return APIResponse(
        success=True,
        message="Scholarship created successfully.",
        data=ScholarshipResponse.model_validate(db_obj)
    )

@router.get(
    "/scholarships",
    response_model=APIResponse[List[ScholarshipResponse]],
    summary="List Scholarships/Concessions"
)
async def list_scholarships(
    current_user: User = Depends(require_permission("fee.read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    school_id: uuid.UUID = Depends(get_school_id),
    service: FeeService = Depends(get_fee_service)
) -> APIResponse[List[ScholarshipResponse]]:
    items = await service.list_scholarships(tenant_id, school_id)
    return APIResponse(
        success=True,
        message="Scholarships retrieved successfully.",
        data=[ScholarshipResponse.model_validate(x) for x in items]
    )

@router.get(
    "/scholarships/{id}",
    response_model=APIResponse[ScholarshipResponse],
    summary="Get Scholarship Details"
)
async def get_scholarship(
    id: uuid.UUID,
    current_user: User = Depends(require_permission("fee.read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    school_id: uuid.UUID = Depends(get_school_id),
    service: FeeService = Depends(get_fee_service)
) -> APIResponse[ScholarshipResponse]:
    db_obj = await service.get_scholarship(id, tenant_id, school_id)
    return APIResponse(
        success=True,
        message="Scholarship retrieved successfully.",
        data=ScholarshipResponse.model_validate(db_obj)
    )

@router.put(
    "/scholarships/{id}",
    response_model=APIResponse[ScholarshipResponse],
    summary="Update Scholarship"
)
async def update_scholarship(
    id: uuid.UUID,
    obj_in: ScholarshipUpdate,
    current_user: User = Depends(require_permission("fee.update")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    school_id: uuid.UUID = Depends(get_school_id),
    service: FeeService = Depends(get_fee_service)
) -> APIResponse[ScholarshipResponse]:
    # Ensure update matches school boundary
    await service.get_scholarship(id, tenant_id, school_id)
    updated = await service.update_scholarship(id, tenant_id, obj_in, current_user.id)
    return APIResponse(
        success=True,
        message="Scholarship updated successfully.",
        data=ScholarshipResponse.model_validate(updated)
    )

@router.delete(
    "/scholarships/{id}",
    response_model=APIResponse[ScholarshipResponse],
    summary="Delete Scholarship"
)
async def delete_scholarship(
    id: uuid.UUID,
    current_user: User = Depends(require_permission("fee.delete")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    school_id: uuid.UUID = Depends(get_school_id),
    service: FeeService = Depends(get_fee_service)
) -> APIResponse[ScholarshipResponse]:
    # Ensure delete matches school boundary
    await service.get_scholarship(id, tenant_id, school_id)
    deleted = await service.delete_scholarship(id, tenant_id, current_user.id)
    return APIResponse(
        success=True,
        message="Scholarship deleted successfully.",
        data=ScholarshipResponse.model_validate(deleted)
    )


# --- FEE STRUCTURE ENDPOINTS ---
@router.post(
    "/structures",
    response_model=APIResponse[FeeStructureResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create Fee Structure"
)
async def create_fee_structure(
    obj_in: FeeStructureCreate,
    current_user: User = Depends(require_permission("fee.create")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    school_id: uuid.UUID = Depends(get_school_id),
    service: FeeService = Depends(get_fee_service)
) -> APIResponse[FeeStructureResponse]:
    db_obj = await service.create_fee_structure(tenant_id, school_id, obj_in, current_user.id)
    return APIResponse(
        success=True,
        message="Fee Structure created successfully.",
        data=FeeStructureResponse.model_validate(db_obj)
    )

@router.get(
    "/structures",
    response_model=APIResponse[List[FeeStructureResponse]],
    summary="List Fee Structures"
)
async def list_fee_structures(
    current_user: User = Depends(require_permission("fee.read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    school_id: uuid.UUID = Depends(get_school_id),
    service: FeeService = Depends(get_fee_service)
) -> APIResponse[List[FeeStructureResponse]]:
    items = await service.list_fee_structures(tenant_id, school_id)
    return APIResponse(
        success=True,
        message="Fee Structures retrieved successfully.",
        data=[FeeStructureResponse.model_validate(x) for x in items]
    )

@router.get(
    "/structures/{id}",
    response_model=APIResponse[FeeStructureResponse],
    summary="Get Fee Structure Details"
)
async def get_fee_structure(
    id: uuid.UUID,
    current_user: User = Depends(require_permission("fee.read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: FeeService = Depends(get_fee_service)
) -> APIResponse[FeeStructureResponse]:
    db_obj = await service.get_fee_structure(id, tenant_id)
    return APIResponse(
        success=True,
        message="Fee Structure retrieved successfully.",
        data=FeeStructureResponse.model_validate(db_obj)
    )

@router.put(
    "/structures/{id}",
    response_model=APIResponse[FeeStructureResponse],
    summary="Update Fee Structure"
)
async def update_fee_structure(
    id: uuid.UUID,
    obj_in: FeeStructureUpdate,
    current_user: User = Depends(require_permission("fee.update")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: FeeService = Depends(get_fee_service)
) -> APIResponse[FeeStructureResponse]:
    updated = await service.update_fee_structure(id, tenant_id, obj_in, current_user.id)
    return APIResponse(
        success=True,
        message="Fee Structure updated successfully.",
        data=FeeStructureResponse.model_validate(updated)
    )

@router.delete(
    "/structures/{id}",
    response_model=APIResponse[FeeStructureResponse],
    summary="Delete Fee Structure"
)
async def delete_fee_structure(
    id: uuid.UUID,
    current_user: User = Depends(require_permission("fee.delete")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: FeeService = Depends(get_fee_service)
) -> APIResponse[FeeStructureResponse]:
    deleted = await service.delete_fee_structure(id, tenant_id, current_user.id)
    return APIResponse(
        success=True,
        message="Fee Structure deleted successfully.",
        data=FeeStructureResponse.model_validate(deleted)
    )


# --- FEE ASSIGNMENT ENDPOINT ---
@router.post(
    "/assign",
    response_model=APIResponse[StudentFeeAssignmentResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Assign Fee Structure to Student"
)
async def assign_fee(
    obj_in: StudentFeeAssignmentCreate,
    current_user: User = Depends(require_permission("fee.create")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: FeeService = Depends(get_fee_service)
) -> APIResponse[StudentFeeAssignmentResponse]:
    db_obj = await service.assign_fee(tenant_id, obj_in, current_user.id)
    return APIResponse(
        success=True,
        message="Fee assigned successfully.",
        data=StudentFeeAssignmentResponse.model_validate(db_obj)
    )


# --- COLLECT PAYMENT & CANCEL PAYMENTS ---
@router.post(
    "/payments",
    response_model=APIResponse[FeePaymentResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Collect Payment and Allocate Dues"
)
async def collect_payment(
    obj_in: FeePaymentCreate,
    current_user: User = Depends(require_permission("fee.pay")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: FeeService = Depends(get_fee_service)
) -> APIResponse[FeePaymentResponse]:
    db_obj = await service.collect_payment(tenant_id, obj_in, current_user.id)
    return APIResponse(
        success=True,
        message="Fee payment collected successfully.",
        data=FeePaymentResponse.model_validate(db_obj)
    )

@router.put(
    "/payments/{payment_id}/cancel",
    response_model=APIResponse[FeePaymentResponse],
    summary="Cancel Fee Payment"
)
async def cancel_payment(
    payment_id: uuid.UUID,
    obj_in: PaymentCancelRequest,
    current_user: User = Depends(require_permission("fee.cancel")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: FeeService = Depends(get_fee_service)
) -> APIResponse[FeePaymentResponse]:
    db_obj = await service.cancel_payment(payment_id, tenant_id, obj_in, current_user.id)
    return APIResponse(
        success=True,
        message="Fee payment cancelled successfully.",
        data=FeePaymentResponse.model_validate(db_obj)
    )


# --- RECEIPT ENDPOINTS ---
@router.get(
    "/receipts/{receipt_number}",
    response_model=APIResponse[FeeReceiptResponse],
    summary="Get Receipt Details"
)
async def get_receipt(
    receipt_number: str,
    current_user: User = Depends(require_permission("fee.read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: FeeService = Depends(get_fee_service)
) -> APIResponse[FeeReceiptResponse]:
    receipt = await service.fee_repo.get_receipt_by_number(receipt_number, tenant_id)
    if not receipt:
        raise HTTPException(status_code=404, detail="Receipt not found.")
    return APIResponse(
        success=True,
        message="Receipt retrieved successfully.",
        data=FeeReceiptResponse.model_validate(receipt)
    )

@router.get(
    "/receipts/{receipt_number}/download",
    summary="Download PDF Receipt File"
)
async def download_receipt(
    receipt_number: str,
    current_user: User = Depends(require_permission("fee.read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: FeeService = Depends(get_fee_service),
    storage_service: StorageService = Depends(get_storage_service),
    db: AsyncSession = Depends(get_db)
) -> StreamingResponse:
    receipt = await service.fee_repo.get_receipt_by_number(receipt_number, tenant_id)
    if not receipt or not receipt.pdf_path:
        raise HTTPException(status_code=404, detail="PDF Receipt file record not found.")
    
    from app.models.fee import FeePayment
    from sqlalchemy.orm import selectinload
    stmt_payment = select(FeePayment).where(FeePayment.id == receipt.payment_id).options(selectinload(FeePayment.student))
    res_payment = await db.execute(stmt_payment)
    payment = res_payment.scalar_one_or_none()
    if not payment or not payment.student:
        raise HTTPException(status_code=404, detail="Payment student record not found.")

    await verify_student_access(current_user, payment.student_id, payment.student.section_id, db)
    
    try:
        pdf_bytes = await storage_service.download(receipt.pdf_path)
    except FileNotFoundError:
        if os.path.exists(receipt.pdf_path):
            with open(receipt.pdf_path, "rb") as f:
                pdf_bytes = f.read()
        else:
            raise HTTPException(status_code=404, detail="PDF Receipt file not found in storage.")
        
    return StreamingResponse(
        io.BytesIO(pdf_bytes),
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{receipt_number}.pdf"'}
    )


# --- STUDENT LEDGER ---
@router.get(
    "/ledgers/{student_id}",
    response_model=APIResponse[StudentLedgerResponse],
    summary="Retrieve Student Financial Ledger"
)
async def get_student_ledger(
    student_id: uuid.UUID,
    current_user: User = Depends(require_permission("fee.read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: FeeService = Depends(get_fee_service),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[StudentLedgerResponse]:
    from app.models.student import Student
    stmt_st = select(Student).where(Student.id == student_id, Student.tenant_id == tenant_id, Student.deleted_at.is_(None))
    res_st = await db.execute(stmt_st)
    student = res_st.scalar_one_or_none()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found.")

    await verify_student_access(current_user, student_id, student.section_id, db)
    ledger = await service.get_student_ledger(student_id, tenant_id)
    return APIResponse(
        success=True,
        message="Student financial ledger retrieved successfully.",
        data=StudentLedgerResponse.model_validate(ledger)
    )


# --- DASHBOARD METRICS & REPORTS ---
@router.get(
    "/reports/dashboard",
    response_model=APIResponse[DashboardMetricsResponse],
    summary="Get Fee Collection Dashboard Analytics Metrics"
)
async def get_dashboard_metrics(
    current_user: User = Depends(require_permission("fee.report")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    school_id: uuid.UUID = Depends(get_school_id),
    service: FeeService = Depends(get_fee_service)
) -> APIResponse[DashboardMetricsResponse]:
    metrics = await service.get_dashboard_metrics(tenant_id, school_id)
    return APIResponse(
        success=True,
        message="Dashboard collection metrics retrieved successfully.",
        data=DashboardMetricsResponse.model_validate(metrics)
    )


# --- AI PREDICTIVE METRICS ---
@router.get(
    "/ai/default-risk/{student_id}",
    response_model=APIResponse[DefaultRiskResponse],
    summary="Get AI Default Risk Probability Analysis"
)
async def get_default_risk(
    student_id: uuid.UUID,
    current_user: User = Depends(require_permission("fee.report")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: FeeService = Depends(get_fee_service)
) -> APIResponse[DefaultRiskResponse]:
    risk = await service.get_default_risk(student_id, tenant_id)
    return APIResponse(
        success=True,
        message="AI default risk report generated successfully.",
        data=DefaultRiskResponse.model_validate(risk)
    )

@router.get(
    "/ai/analytics",
    response_model=APIResponse[CollectionAnalyticsResponse],
    summary="Get AI 30-Day Collection Analytics Prediction"
)
async def get_collection_analytics(
    current_user: User = Depends(require_permission("fee.report")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    school_id: uuid.UUID = Depends(get_school_id),
    service: FeeService = Depends(get_fee_service)
) -> APIResponse[CollectionAnalyticsResponse]:
    analytics = await service.get_collection_analytics(tenant_id, school_id)
    return APIResponse(
        success=True,
        message="AI 30-day collection analytics predicted successfully.",
        data=CollectionAnalyticsResponse.model_validate(analytics)
    )

@router.post(
    "/payments/import",
    response_model=APIResponse[PaymentImportResponse],
    status_code=status.HTTP_200_OK,
    summary="Import Student Payments from CSV Data"
)
async def import_payments(
    obj_in: PaymentImportRequest,
    current_user: User = Depends(require_permission("fee.pay")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: FeeService = Depends(get_fee_service)
) -> APIResponse[PaymentImportResponse]:
    result = await service.import_payments(
        tenant_id=tenant_id,
        school_id=obj_in.school_id,
        academic_year_id=obj_in.academic_year_id,
        payments=obj_in.payments,
        current_user_id=current_user.id
    )
    return APIResponse(
        success=True,
        message="Payments import processed.",
        data=PaymentImportResponse.model_validate(result)
    )

@router.get(
    "/reports/outstanding",
    response_model=APIResponse[List[OutstandingFeeReportItem]],
    summary="Get Outstanding Dues and Defaulters Report"
)
async def get_outstanding_report(
    school_id: uuid.UUID = Query(..., description="Target School UUID"),
    class_id: Optional[uuid.UUID] = Query(None, description="Filter by Class UUID"),
    only_defaulters: Optional[bool] = Query(False, description="Filter only late/defaulter records"),
    current_user: User = Depends(require_permission("fee.report")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: FeeService = Depends(get_fee_service)
) -> APIResponse[List[OutstandingFeeReportItem]]:
    report = await service.get_outstanding_report(
        tenant_id=tenant_id,
        school_id=school_id,
        class_id=class_id,
        only_defaulters=only_defaulters
    )
    return APIResponse(
        success=True,
        message="Outstanding reports retrieved successfully.",
        data=[OutstandingFeeReportItem.model_validate(item) for item in report]
    )
