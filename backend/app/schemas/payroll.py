import uuid
from decimal import Decimal
from datetime import date, datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field
from app.models.payroll import (
    PayrollCalculationBasis, DailyRateFormula, PayrollStatus, PayrollAuditAction
)


class PayrollPolicyCreate(BaseModel):
    policy_name: str = "Standard School Payroll Policy"
    calculation_basis: PayrollCalculationBasis = PayrollCalculationBasis.WORKING_DAYS
    standard_working_days: int = Field(24, ge=1, le=31)
    daily_rate_formula: DailyRateFormula = DailyRateFormula.GROSS_DIVIDED_BY_WORKING_DAYS
    half_day_deduction_factor: Decimal = Field(Decimal("0.50"), ge=0, le=1)
    unpaid_leave_deduction_factor: Decimal = Field(Decimal("1.00"), ge=0, le=2)
    late_grace_count: int = Field(3, ge=0)
    late_deduction_factor: Decimal = Field(Decimal("0.25"), ge=0, le=1)
    is_active: bool = True


class PayrollPolicyUpdate(BaseModel):
    policy_name: Optional[str] = None
    calculation_basis: Optional[PayrollCalculationBasis] = None
    standard_working_days: Optional[int] = Field(None, ge=1, le=31)
    daily_rate_formula: Optional[DailyRateFormula] = None
    half_day_deduction_factor: Optional[Decimal] = Field(None, ge=0, le=1)
    unpaid_leave_deduction_factor: Optional[Decimal] = Field(None, ge=0, le=2)
    late_grace_count: Optional[int] = Field(None, ge=0)
    late_deduction_factor: Optional[Decimal] = Field(None, ge=0, le=1)
    is_active: Optional[bool] = None


class PayrollPolicyResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    policy_name: str
    calculation_basis: PayrollCalculationBasis
    standard_working_days: int
    daily_rate_formula: DailyRateFormula
    half_day_deduction_factor: Decimal
    unpaid_leave_deduction_factor: Decimal
    late_grace_count: int
    late_deduction_factor: Decimal
    is_active: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class TeacherPayrollProfileCreate(BaseModel):
    teacher_id: uuid.UUID
    monthly_gross_salary: Decimal = Field(..., ge=0)
    basic_salary: Decimal = Field(Decimal("0.00"), ge=0)
    hra_allowance: Decimal = Field(Decimal("0.00"), ge=0)
    special_allowance: Decimal = Field(Decimal("0.00"), ge=0)
    other_allowances: Decimal = Field(Decimal("0.00"), ge=0)
    provident_fund_deduction: Decimal = Field(Decimal("0.00"), ge=0)
    tax_deduction: Decimal = Field(Decimal("0.00"), ge=0)
    other_deductions: Decimal = Field(Decimal("0.00"), ge=0)
    paid_leave_quota_per_year: int = Field(12, ge=0)
    bank_account_number: Optional[str] = None
    bank_ifsc: Optional[str] = None
    bank_name: Optional[str] = None
    effective_from: date = Field(default_factory=date.today)
    effective_until: Optional[date] = None
    is_active: bool = True


class TeacherPayrollProfileUpdate(BaseModel):
    monthly_gross_salary: Optional[Decimal] = Field(None, ge=0)
    basic_salary: Optional[Decimal] = Field(None, ge=0)
    hra_allowance: Optional[Decimal] = Field(None, ge=0)
    special_allowance: Optional[Decimal] = Field(None, ge=0)
    other_allowances: Optional[Decimal] = Field(None, ge=0)
    provident_fund_deduction: Optional[Decimal] = Field(None, ge=0)
    tax_deduction: Optional[Decimal] = Field(None, ge=0)
    other_deductions: Optional[Decimal] = Field(None, ge=0)
    paid_leave_quota_per_year: Optional[int] = Field(None, ge=0)
    bank_account_number: Optional[str] = None
    bank_ifsc: Optional[str] = None
    bank_name: Optional[str] = None
    effective_from: Optional[date] = None
    effective_until: Optional[date] = None
    is_active: Optional[bool] = None


class TeacherPayrollProfileResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    teacher_id: uuid.UUID
    teacher_name: str
    teacher_code: str
    designation: Optional[str] = None
    department: Optional[str] = None
    monthly_gross_salary: Decimal
    basic_salary: Decimal
    hra_allowance: Decimal
    special_allowance: Decimal
    other_allowances: Decimal
    provident_fund_deduction: Decimal
    tax_deduction: Decimal
    other_deductions: Decimal
    paid_leave_quota_per_year: int
    bank_account_number: Optional[str] = None
    bank_ifsc: Optional[str] = None
    bank_name: Optional[str] = None
    effective_from: date
    effective_until: Optional[date] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class CalculatePayrollRequest(BaseModel):
    school_id: uuid.UUID
    month: int = Field(..., ge=1, le=12)
    year: int = Field(..., ge=2020, le=2100)
    policy_id: Optional[uuid.UUID] = None
    teacher_ids: Optional[List[uuid.UUID]] = None


class TeacherPayrollItemResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    teacher_id: uuid.UUID
    teacher_name: str
    teacher_code: str
    designation: Optional[str] = None
    department: Optional[str] = None
    month: int
    year: int
    calculation_date: date

    calendar_days: int
    applicable_working_days: int
    present_days: Decimal
    approved_leave_days: Decimal
    half_days: int
    unpaid_absence_days: Decimal
    holidays_count: int
    on_duty_days: int
    late_days: int
    unmarked_days: int

    gross_salary: Decimal
    daily_rate: Decimal
    attendance_deductions: Decimal
    statutory_deductions: Decimal
    manual_adjustments: Decimal
    adjustment_reason: Optional[str] = None
    net_payable: Decimal

    ai_explanation: Optional[str] = None
    ai_anomalies: List[str] = Field(default_factory=list)

    status: PayrollStatus
    calculated_by_name: Optional[str] = None
    approved_by_name: Optional[str] = None
    approved_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class MonthlyPayrollSummaryResponse(BaseModel):
    school_id: uuid.UUID
    month: int
    year: int
    policy_name: str
    total_teachers: int
    draft_count: int
    approved_count: int
    total_gross_disbursement: Decimal
    total_attendance_deductions: Decimal
    total_statutory_deductions: Decimal
    total_net_payable: Decimal
    items: List[TeacherPayrollItemResponse]


class ApprovePayrollRequest(BaseModel):
    payroll_ids: List[uuid.UUID]
    remarks: Optional[str] = None


class PayrollAuditLogResponse(BaseModel):
    id: uuid.UUID
    school_id: uuid.UUID
    payroll_id: Optional[uuid.UUID] = None
    teacher_id: uuid.UUID
    teacher_name: str
    action: PayrollAuditAction
    actor_name: Optional[str] = None
    previous_net_pay: Optional[Decimal] = None
    revised_net_pay: Optional[Decimal] = None
    delta_amount: Optional[Decimal] = None
    notes: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class AttendanceCorrectionImpactRequest(BaseModel):
    school_id: uuid.UUID
    teacher_id: uuid.UUID
    date: date
    new_status: str  # PRESENT, APPROVED_LEAVE, UNPAID_ABSENCE, HALF_DAY, ON_DUTY


class PayrollImpactAlertResponse(BaseModel):
    has_impact: bool
    affected_month: int
    affected_year: int
    payroll_id: Optional[uuid.UUID] = None
    payroll_status: Optional[PayrollStatus] = None
    teacher_name: str
    previous_deduction: Decimal
    revised_deduction: Decimal
    delta_amount: Decimal
    explanation: str
