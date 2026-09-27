import uuid
from datetime import date
from decimal import Decimal
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.db.session import get_db
from app.api.dependencies.common import get_tenant_id, verify_school_access
from app.api.dependencies.auth import require_permission
from app.models.staff_salary import StaffSalary, SalaryStatus, SalaryPaymentMethod
from app.models.expense import Expense, ExpenseCategory
from app.models.teacher import Teacher, TeacherStatus
from app.models.user import User
from app.schemas.staff_salary import (
    StaffSalaryCreate, StaffSalaryUpdate, StaffSalaryPayRequest, StaffSalaryResponse
)
from app.schemas.response import APIResponse

router = APIRouter()

class GenerateSalariesRequest(BaseModel):
    school_id: uuid.UUID
    month: int = Field(..., ge=1, le=12)
    year: int = Field(..., ge=2020, le=2100)
    staff_id: Optional[uuid.UUID] = None

def _to_response(salary: StaffSalary) -> StaffSalaryResponse:
    staff_name = None
    staff_code = None
    if salary.staff:
        name_parts = [salary.staff.first_name]
        if salary.staff.middle_name:
            name_parts.append(salary.staff.middle_name)
        name_parts.append(salary.staff.last_name)
        staff_name = " ".join(name_parts)
        staff_code = salary.staff.staff_code or salary.staff.employee_code

    return StaffSalaryResponse(
        id=salary.id,
        tenant_id=salary.tenant_id,
        school_id=salary.school_id,
        staff_id=salary.staff_id,
        month=salary.month,
        year=salary.year,
        base_salary=salary.base_salary,
        allowances=salary.allowances,
        deductions=salary.deductions,
        net_salary=salary.net_salary,
        status=salary.status,
        payment_date=salary.payment_date,
        payment_method=salary.payment_method,
        reference_number=salary.reference_number,
        remarks=salary.remarks,
        created_at=salary.created_at,
        updated_at=salary.updated_at,
        staff_name=staff_name,
        staff_code=staff_code
    )

@router.get(
    "",
    response_model=APIResponse[List[StaffSalaryResponse]],
    status_code=status.HTTP_200_OK,
    summary="List staff salaries"
)
async def list_staff_salaries(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    month: Optional[int] = Query(None, ge=1, le=12),
    year: Optional[int] = Query(None, ge=2020, le=2100),
    staff_id: Optional[uuid.UUID] = Query(None),
    status_filter: Optional[SalaryStatus] = Query(None, alias="status"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("fee.read", "school.read")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[List[StaffSalaryResponse]]:
    await verify_school_access(current_user, school_id, db)

    stmt = select(StaffSalary).options(selectinload(StaffSalary.staff)).where(
        StaffSalary.tenant_id == tenant_id,
        StaffSalary.school_id == school_id,
        StaffSalary.deleted_at.is_(None)
    )
    if month is not None:
        stmt = stmt.where(StaffSalary.month == month)
    if year is not None:
        stmt = stmt.where(StaffSalary.year == year)
    if staff_id is not None:
        stmt = stmt.where(StaffSalary.staff_id == staff_id)
    if status_filter is not None:
        stmt = stmt.where(StaffSalary.status == status_filter)

    stmt = stmt.order_by(StaffSalary.year.desc(), StaffSalary.month.desc(), StaffSalary.created_at.desc())
    stmt = stmt.offset(skip).limit(limit)

    result = await db.execute(stmt)
    records = list(result.scalars().all())

    return APIResponse[List[StaffSalaryResponse]](
        success=True,
        message="Staff salaries retrieved successfully.",
        data=[_to_response(r) for r in records]
    )

@router.post(
    "/generate",
    response_model=APIResponse[List[StaffSalaryResponse]],
    status_code=status.HTTP_201_CREATED,
    summary="Generate staff salary slips for a month"
)
async def generate_salaries(
    req: GenerateSalariesRequest,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("fee.write", "school.update")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[List[StaffSalaryResponse]]:
    await verify_school_access(current_user, req.school_id, db)

    # Fetch active staff
    staff_stmt = select(Teacher).where(
        Teacher.tenant_id == tenant_id,
        Teacher.school_id == req.school_id,
        Teacher.status == TeacherStatus.ACTIVE,
        Teacher.deleted_at.is_(None)
    )
    if req.staff_id:
        staff_stmt = staff_stmt.where(Teacher.id == req.staff_id)

    staff_result = await db.execute(staff_stmt)
    staff_list = list(staff_result.scalars().all())

    if not staff_list:
        return APIResponse[List[StaffSalaryResponse]](
            success=True,
            message="No eligible staff members found for salary generation.",
            data=[]
        )

    # Check existing salaries for month/year
    existing_stmt = select(StaffSalary.staff_id).where(
        StaffSalary.tenant_id == tenant_id,
        StaffSalary.school_id == req.school_id,
        StaffSalary.month == req.month,
        StaffSalary.year == req.year,
        StaffSalary.deleted_at.is_(None)
    )
    existing_result = await db.execute(existing_stmt)
    existing_staff_ids = set(existing_result.scalars().all())

    generated = []
    for member in staff_list:
        if member.id in existing_staff_ids:
            continue
        base_amt = Decimal(str(member.salary)) if member.salary is not None else Decimal("0.00")
        allowances = Decimal("0.00")
        deductions = Decimal("0.00")
        net = base_amt + allowances - deductions

        record = StaffSalary(
            tenant_id=tenant_id,
            school_id=req.school_id,
            staff_id=member.id,
            month=req.month,
            year=req.year,
            base_salary=base_amt,
            allowances=allowances,
            deductions=deductions,
            net_salary=net,
            status=SalaryStatus.PENDING,
            created_by=current_user.id,
            updated_by=current_user.id
        )
        record.staff = member
        db.add(record)
        generated.append(record)

    await db.commit()
    for rec in generated:
        await db.refresh(rec)

    return APIResponse[List[StaffSalaryResponse]](
        success=True,
        message=f"Successfully generated {len(generated)} salary records." if generated else "No new salary records were generated. All active staff already have salary slips for this period.",
        data=[_to_response(r) for r in generated]
    )

@router.post(
    "",
    response_model=APIResponse[StaffSalaryResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create or initialize a staff salary record"
)
async def create_staff_salary(
    obj_in: StaffSalaryCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("fee.create", "fee.update", "fee.write", "school.update")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[StaffSalaryResponse]:
    await verify_school_access(current_user, obj_in.school_id, db)

    existing_stmt = select(StaffSalary).where(
        StaffSalary.tenant_id == tenant_id,
        StaffSalary.school_id == obj_in.school_id,
        StaffSalary.staff_id == obj_in.staff_id,
        StaffSalary.month == obj_in.month,
        StaffSalary.year == obj_in.year,
        StaffSalary.deleted_at.is_(None)
    )
    existing = (await db.execute(existing_stmt)).scalar_one_or_none()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Salary record already exists for this staff member for the selected period."
        )

    calculated_net = obj_in.base_salary + obj_in.allowances - obj_in.deductions
    net_salary = max(Decimal("0.00"), calculated_net)
    salary = StaffSalary(
        tenant_id=tenant_id,
        school_id=obj_in.school_id,
        staff_id=obj_in.staff_id,
        month=obj_in.month,
        year=obj_in.year,
        base_salary=obj_in.base_salary,
        allowances=obj_in.allowances,
        deductions=obj_in.deductions,
        net_salary=net_salary,
        status=SalaryStatus.PENDING,
        remarks=obj_in.remarks,
        created_by=current_user.id,
        updated_by=current_user.id
    )
    db.add(salary)
    await db.commit()

    stmt = select(StaffSalary).options(selectinload(StaffSalary.staff)).where(StaffSalary.id == salary.id)
    salary_with_staff = (await db.execute(stmt)).scalar_one()

    return APIResponse[StaffSalaryResponse](
        success=True,
        message="Staff salary record created successfully.",
        data=_to_response(salary_with_staff)
    )

@router.put(
    "/{id}",
    response_model=APIResponse[StaffSalaryResponse],
    status_code=status.HTTP_200_OK,
    summary="Update staff salary breakdown (Base, Allowances, Deductions)"
)
async def update_staff_salary(
    id: uuid.UUID,
    obj_in: StaffSalaryUpdate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("fee.create", "fee.update", "fee.write", "school.update")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[StaffSalaryResponse]:
    stmt = select(StaffSalary).options(selectinload(StaffSalary.staff)).where(
        StaffSalary.id == id,
        StaffSalary.tenant_id == tenant_id,
        StaffSalary.deleted_at.is_(None)
    )
    result = await db.execute(stmt)
    salary = result.scalar_one_or_none()
    if not salary:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Staff salary record not found."
        )
    await verify_school_access(current_user, salary.school_id, db)
    if salary.status == SalaryStatus.PAID:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot modify a salary record that has already been PAID."
        )

    if obj_in.base_salary is not None:
        salary.base_salary = obj_in.base_salary
    if obj_in.allowances is not None:
        salary.allowances = obj_in.allowances
    if obj_in.deductions is not None:
        salary.deductions = obj_in.deductions
    if obj_in.remarks is not None:
        salary.remarks = obj_in.remarks

    calculated_net = salary.base_salary + salary.allowances - salary.deductions
    salary.net_salary = max(Decimal("0.00"), calculated_net)
    salary.updated_by = current_user.id

    await db.commit()
    await db.refresh(salary)

    return APIResponse[StaffSalaryResponse](
        success=True,
        message="Staff salary updated successfully.",
        data=_to_response(salary)
    )

@router.post(
    "/{id}/pay",
    response_model=APIResponse[StaffSalaryResponse],
    status_code=status.HTTP_200_OK,
    summary="Mark staff salary as paid and record linked school expense"
)
async def pay_salary(
    id: uuid.UUID,
    req: StaffSalaryPayRequest,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("fee.create", "fee.update", "fee.write", "school.update")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[StaffSalaryResponse]:
    stmt = select(StaffSalary).options(selectinload(StaffSalary.staff)).where(
        StaffSalary.id == id,
        StaffSalary.tenant_id == tenant_id,
        StaffSalary.deleted_at.is_(None)
    )
    result = await db.execute(stmt)
    salary = result.scalar_one_or_none()
    if not salary:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Staff salary record not found."
        )

    await verify_school_access(current_user, salary.school_id, db)

    if salary.status == SalaryStatus.PAID:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Salary has already been marked as PAID."
        )

    if salary.net_salary <= Decimal("0.00") and salary.base_salary <= Decimal("0.00"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot disburse an unconfigured salary with net amount ₹0.00. Please configure the salary breakdown first."
        )

    if req.amount is not None:
        if req.amount > salary.net_salary:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Payment amount (₹{req.amount}) exceeds net payable salary (₹{salary.net_salary}). Overpayment is not permitted."
            )
        if req.amount < Decimal("0.01") and salary.net_salary > Decimal("0.00"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Payment amount must be greater than zero."
            )

    p_date = req.payment_date or date.today()
    salary.status = SalaryStatus.PAID
    salary.payment_date = p_date
    salary.payment_method = req.payment_method
    if req.reference_number:
        salary.reference_number = req.reference_number
    if req.remarks:
        salary.remarks = req.remarks
    salary.updated_by = current_user.id

    # Create linked expense record if not exists
    exp_stmt = select(Expense).where(
        Expense.salary_payment_id == salary.id,
        Expense.deleted_at.is_(None)
    )
    exp_existing = (await db.execute(exp_stmt)).scalar_one_or_none()

    if not exp_existing:
        staff_name = "Staff Member"
        if salary.staff:
            staff_name = f"{salary.staff.first_name} {salary.staff.last_name}".strip()

        disbursed_amount = req.amount or salary.net_salary
        expense = Expense(
            tenant_id=tenant_id,
            school_id=salary.school_id,
            category=ExpenseCategory.STAFF,
            subcategory="Salary Disbursement",
            amount=disbursed_amount,
            expense_date=p_date,
            description=f"Salary disbursement for {salary.month:02d}/{salary.year} to {staff_name}",
            paid_to=staff_name,
            payment_method=req.payment_method.value,
            reference_number=req.reference_number,
            salary_payment_id=salary.id,
            status="APPROVED",
            created_by=current_user.id,
            updated_by=current_user.id
        )
        db.add(expense)

    await db.commit()
    await db.refresh(salary)

    return APIResponse[StaffSalaryResponse](
        success=True,
        message="Salary marked as paid and linked expense registered.",
        data=_to_response(salary)
    )
