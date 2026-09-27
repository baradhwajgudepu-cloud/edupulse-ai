import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field
from app.models.staff_salary import SalaryStatus, SalaryPaymentMethod

class StaffSalaryBase(BaseModel):
    staff_id: uuid.UUID = Field(..., description="Staff member UUID")
    month: int = Field(..., ge=1, le=12, description="Month (1-12)")
    year: int = Field(..., ge=2020, le=2100, description="Year (e.g. 2026)")
    base_salary: Decimal = Field(..., ge=0, description="Base salary amount")
    allowances: Decimal = Field(default=Decimal("0.00"), ge=0, description="Additional allowances")
    deductions: Decimal = Field(default=Decimal("0.00"), ge=0, description="Deductions such as taxes/PF")
    remarks: Optional[str] = Field(None, max_length=500)

class StaffSalaryCreate(StaffSalaryBase):
    school_id: uuid.UUID

class StaffSalaryUpdate(BaseModel):
    base_salary: Optional[Decimal] = Field(None, ge=0)
    allowances: Optional[Decimal] = Field(None, ge=0)
    deductions: Optional[Decimal] = Field(None, ge=0)
    remarks: Optional[str] = Field(None, max_length=500)

class StaffSalaryPayRequest(BaseModel):
    payment_method: SalaryPaymentMethod = Field(default=SalaryPaymentMethod.BANK_TRANSFER)
    payment_date: Optional[date] = None
    reference_number: Optional[str] = Field(None, max_length=150)
    remarks: Optional[str] = Field(None, max_length=500)
    amount: Optional[Decimal] = Field(None, ge=0, description="Payment disbursement amount")

class StaffSalaryResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    staff_id: uuid.UUID
    month: int
    year: int
    base_salary: Decimal
    allowances: Decimal
    deductions: Decimal
    net_salary: Decimal
    status: SalaryStatus
    payment_date: Optional[date] = None
    payment_method: Optional[SalaryPaymentMethod] = None
    reference_number: Optional[str] = None
    remarks: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    staff_name: Optional[str] = None
    staff_code: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)
