import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Optional, List, Dict
from pydantic import BaseModel, ConfigDict, Field
from app.models.expense import ExpenseCategory

class ExpenseBase(BaseModel):
    category: ExpenseCategory = Field(..., description="STAFF, INFRASTRUCTURE, ACADEMIC, OPERATIONS, OTHER")
    subcategory: Optional[str] = Field(None, max_length=100)
    amount: Decimal = Field(..., gt=0, description="Expense amount in INR")
    expense_date: date = Field(..., description="Date expense occurred")
    description: str = Field(..., min_length=1, max_length=500)
    paid_to: str = Field(..., min_length=1, max_length=150)
    payment_method: str = Field(default="BANK_TRANSFER", max_length=50)
    reference_number: Optional[str] = Field(None, max_length=150)
    receipt_url: Optional[str] = Field(None, max_length=500)

class ExpenseCreate(ExpenseBase):
    school_id: uuid.UUID

class ExpenseUpdate(BaseModel):
    category: Optional[ExpenseCategory] = None
    subcategory: Optional[str] = Field(None, max_length=100)
    amount: Optional[Decimal] = Field(None, gt=0)
    expense_date: Optional[date] = None
    description: Optional[str] = Field(None, min_length=1, max_length=500)
    paid_to: Optional[str] = Field(None, min_length=1, max_length=150)
    payment_method: Optional[str] = Field(None, max_length=50)
    reference_number: Optional[str] = Field(None, max_length=150)
    receipt_url: Optional[str] = Field(None, max_length=500)

class ExpenseResponse(ExpenseBase):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    salary_payment_id: Optional[uuid.UUID] = None
    status: str
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

class ExpenseSummaryResponse(BaseModel):
    total_amount: Decimal
    total_count: int
    by_category: Dict[str, Decimal]
