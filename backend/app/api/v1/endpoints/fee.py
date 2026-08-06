import uuid
import os
import logging
from typing import List, Optional
from datetime import date
from fastapi import APIRouter, Depends, status, HTTPException, Header
from fastapi.responses import FileResponse

from app.api.dependencies.auth import require_permission, get_current_user
from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.fee import get_fee_service
from app.services.fee import FeeService
from app.schemas.fee import (
    FeeTypeCreate, FeeTypeUpdate, FeeTypeResponse,
    ScholarshipCreate, ScholarshipUpdate, ScholarshipResponse,
    FeeStructureCreate, FeeStructureUpdate, FeeStructureResponse,
    StudentFeeAssignmentCreate, StudentFeeAssignmentResponse,
    FeePaymentCreate, FeePaymentResponse, PaymentCancelRequest,
    FeeReceiptResponse, StudentLedgerResponse, DashboardMetricsResponse,
    DefaultRiskResponse, CollectionAnalyticsResponse
)
from app.schemas.response import APIResponse
from app.models.user import User

logger = logging.getLogger(__name__)

async def get_school_id(
    x_school_id: Optional[str] = Header(None, alias="X-School-ID", description="Active School UUID")
) -> uuid.UUID:
    if not x_school_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="X-School-ID header is missing."
        )
    try:
        return uuid.UUID(x_school_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid X-School-ID header format. Must be a valid UUID."
        )

router = APIRouter()

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
    current_user: User = Depends(require_permission("fee.report")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: FeeService = Depends(get_fee_service)
):
    receipt = await service.fee_repo.get_receipt_by_number(receipt_number, tenant_id)
    if not receipt or not receipt.pdf_path or not os.path.exists(receipt.pdf_path):
        raise HTTPException(status_code=404, detail="PDF Receipt file not found on disk.")
    return FileResponse(receipt.pdf_path, media_type="application/pdf", filename=f"{receipt_number}.pdf")


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
    service: FeeService = Depends(get_fee_service)
) -> APIResponse[StudentLedgerResponse]:
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
