import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Optional, List, Dict, Any, Annotated
from pydantic import BaseModel, Field, ConfigDict, StringConstraints, model_validator, PlainSerializer
from app.models.fee import ConcessionType, PaymentMethod, PaymentStatus, FeeAssignmentStatus, FineType

DecimalFloat = Annotated[Decimal, PlainSerializer(lambda x: float(x), return_type=float)]

# Types with strict string constraints
NameStr = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)]
CodeStr = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=50)]
DescStr = Annotated[str, StringConstraints(strip_whitespace=True, max_length=500)]

SchNameStr = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)]
SchDescStr = Annotated[str, StringConstraints(strip_whitespace=True, max_length=500)]

# --- FEE TYPE SCHEMAS ---
class FeeTypeCreate(BaseModel):
    name: NameStr
    code: CodeStr
    description: Optional[DescStr] = None
    is_system: Optional[bool] = False

class FeeTypeUpdate(BaseModel):
    name: Optional[NameStr] = None
    code: Optional[CodeStr] = None
    description: Optional[DescStr] = None
    is_system: Optional[bool] = None

class FeeTypeResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    name: str
    code: str
    description: Optional[str]
    is_system: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


# --- SCHOLARSHIP SCHEMAS ---
class ScholarshipCreate(BaseModel):
    name: SchNameStr
    concession_type: ConcessionType
    value: Decimal
    description: Optional[SchDescStr] = None

    @model_validator(mode="after")
    def validate_values(self) -> "ScholarshipCreate":
        if self.value <= Decimal("0"):
            raise ValueError("Value must be greater than zero.")
        if self.concession_type == ConcessionType.PERCENTAGE:
            if self.value < Decimal("1.0") or self.value > Decimal("100.0"):
                raise ValueError("Percentage scholarship values must be between 1 and 100 inclusive.")
        return self

class ScholarshipUpdate(BaseModel):
    name: Optional[SchNameStr] = None
    concession_type: Optional[ConcessionType] = None
    value: Optional[Decimal] = None
    description: Optional[SchDescStr] = None

    @model_validator(mode="after")
    def validate_values(self) -> "ScholarshipUpdate":
        if self.value is not None and self.value <= Decimal("0"):
            raise ValueError("Value must be greater than zero.")
        if self.concession_type is not None and self.value is not None:
            if self.concession_type == ConcessionType.PERCENTAGE:
                if self.value < Decimal("1.0") or self.value > Decimal("100.0"):
                    raise ValueError("Percentage scholarship values must be between 1 and 100 inclusive.")
        return self

class ScholarshipResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    name: str
    concession_type: ConcessionType
    value: DecimalFloat
    description: Optional[str]
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


# --- FINE RULE SCHEMAS ---
class FineRuleCreate(BaseModel):
    grace_period_days: int = Field(..., ge=0)
    fine_type: FineType
    fine_value: Decimal = Field(..., gt=0)

class FineRuleUpdate(BaseModel):
    grace_period_days: Optional[int] = Field(None, ge=0)
    fine_type: Optional[FineType] = None
    fine_value: Optional[Decimal] = Field(None, gt=0)

class FineRuleResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    fee_structure_id: uuid.UUID
    grace_period_days: int
    fine_type: FineType
    fine_value: DecimalFloat
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


# --- FEE STRUCTURE SCHEMAS ---
class FeeStructureCreate(BaseModel):
    fee_type_id: uuid.UUID
    academic_year_id: uuid.UUID
    class_id: Optional[uuid.UUID] = None
    amount: Decimal = Field(..., gt=0)
    due_date: date
    description: Optional[str] = Field(None, max_length=500)
    fine_rule: Optional[FineRuleCreate] = None

class FeeStructureUpdate(BaseModel):
    amount: Optional[Decimal] = Field(None, gt=0)
    due_date: Optional[date] = None
    description: Optional[str] = Field(None, max_length=500)
    fine_rule: Optional[FineRuleUpdate] = None

class FeeStructureResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    fee_type_id: uuid.UUID
    academic_year_id: uuid.UUID
    class_id: Optional[uuid.UUID]
    amount: DecimalFloat
    due_date: date
    description: Optional[str]
    fine_rule: Optional[FineRuleResponse] = None
    version: int
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


# --- STUDENT FEE ASSIGNMENT SCHEMAS ---
class StudentFeeAssignmentCreate(BaseModel):
    student_id: uuid.UUID
    fee_structure_id: uuid.UUID
    scholarship_id: Optional[uuid.UUID] = None

class StudentFeeAssignmentResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    student_id: uuid.UUID
    fee_structure_id: uuid.UUID
    academic_year_id: uuid.UUID
    assigned_amount: DecimalFloat
    scholarship_id: Optional[uuid.UUID]
    discount_amount: DecimalFloat
    fine_amount: DecimalFloat
    paid_amount: DecimalFloat
    status: FeeAssignmentStatus
    version: int
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


# --- PAYMENT ALLOCATION SCHEMAS ---
class FeePaymentAllocationCreate(BaseModel):
    assignment_id: uuid.UUID
    amount_allocated: Decimal = Field(..., gt=0)

class FeePaymentAllocationResponse(BaseModel):
    assignment_id: uuid.UUID
    amount_allocated: DecimalFloat

    model_config = ConfigDict(from_attributes=True)


# --- FEE PAYMENT SCHEMAS ---
class FeePaymentCreate(BaseModel):
    student_id: uuid.UUID
    academic_year_id: uuid.UUID
    payment_method: PaymentMethod
    transaction_reference: Optional[str] = Field(None, max_length=150)
    remarks: Optional[str] = Field(None, max_length=500)
    allocations: List[FeePaymentAllocationCreate]

class FeePaymentResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    student_id: uuid.UUID
    academic_year_id: uuid.UUID
    amount_paid: DecimalFloat
    payment_date: datetime
    payment_method: PaymentMethod
    status: PaymentStatus
    transaction_reference: Optional[str]
    receipt_number: Optional[str] = None
    remarks: Optional[str]
    cancel_reason: Optional[str]
    cancelled_by: Optional[uuid.UUID]
    cancelled_at: Optional[datetime]
    allocations: List[FeePaymentAllocationResponse]
    version: int
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


# --- RECEIPT SCHEMAS ---
class FeeReceiptResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    payment_id: uuid.UUID
    receipt_number: str
    pdf_path: Optional[str]
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


# --- PAYMENT REVERSAL/CANCEL PAYLOAD ---
class PaymentCancelRequest(BaseModel):
    cancel_reason: str = Field(..., max_length=250)


# --- STUDENT LEDGER RESPONSE ---
class StudentLedgerResponse(BaseModel):
    student_id: uuid.UUID
    opening_balance: DecimalFloat
    assignments: List[StudentFeeAssignmentResponse]
    scholarships: List[ScholarshipResponse]
    payments: List[FeePaymentResponse]
    closing_balance: DecimalFloat


# --- DASHBOARD METRICS ---
class OutstandingClassMetric(BaseModel):
    class_name: str
    outstanding_amount: DecimalFloat

class DashboardMetricsResponse(BaseModel):
    today_collection: DecimalFloat
    month_collection: DecimalFloat
    pending_dues: DecimalFloat
    collection_percentage: DecimalFloat
    defaulters_count: int
    top_outstanding_classes: List[OutstandingClassMetric]


# --- AI PREDICTIONS ---
class DefaultRiskResponse(BaseModel):
    student_id: uuid.UUID
    default_risk_probability: DecimalFloat
    payment_score: int
    risk_level: str

class CollectionAnalyticsResponse(BaseModel):
    predicted_collection_next_30_days: DecimalFloat
    historical_trend: Dict[str, DecimalFloat]


# --- PAYMENT IMPORT SCHEMAS ---
class PaymentImportRow(BaseModel):
    admission_number: str
    fee_type_code: str
    amount: DecimalFloat = Field(..., gt=0)
    payment_date: date
    payment_method: PaymentMethod
    reference_number: Optional[str] = None

class PaymentImportRequest(BaseModel):
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    payments: List[PaymentImportRow]

class PaymentImportRowResult(BaseModel):
    row_index: int
    admission_number: str
    fee_type_code: str
    success: bool
    error: Optional[str] = None
    payment_id: Optional[uuid.UUID] = None

class PaymentImportResponse(BaseModel):
    total_processed: int
    success_count: int
    failed_count: int
    results: List[PaymentImportRowResult]


# --- OUTSTANDING FEE REPORT SCHEMAS ---
class OutstandingFeeReportItem(BaseModel):
    student_id: uuid.UUID
    student_name: str
    admission_number: str
    class_id: uuid.UUID
    class_name: str
    section_id: uuid.UUID
    section_name: str
    fee_structure_id: uuid.UUID
    fee_type_id: uuid.UUID
    fee_type_name: str
    assigned_amount: DecimalFloat
    discount_amount: DecimalFloat
    fine_amount: DecimalFloat
    paid_amount: DecimalFloat
    outstanding_amount: DecimalFloat
    due_date: date
    status: FeeAssignmentStatus

    model_config = ConfigDict(from_attributes=True)
