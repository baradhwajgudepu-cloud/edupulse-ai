import uuid
from datetime import date, datetime, timezone
from decimal import Decimal
from typing import List, Optional, Dict
from fastapi import APIRouter, Depends, Query, status, HTTPException
from sqlalchemy import select, and_, func, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.api.dependencies.common import get_tenant_id, verify_school_access
from app.api.dependencies.auth import require_permission
from app.models.expense import Expense, ExpenseCategory
from app.models.user import User
from app.schemas.expense import (
    ExpenseCreate, ExpenseUpdate, ExpenseResponse, ExpenseSummaryResponse
)
from app.schemas.response import APIResponse

router = APIRouter()

@router.post(
    "",
    response_model=APIResponse[ExpenseResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Record a school expense"
)
async def create_expense(
    obj_in: ExpenseCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("fee.create", "fee.update", "fee.write", "school.update")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[ExpenseResponse]:
    await verify_school_access(current_user, obj_in.school_id, db)

    expense = Expense(
        tenant_id=tenant_id,
        school_id=obj_in.school_id,
        category=obj_in.category,
        subcategory=obj_in.subcategory,
        amount=obj_in.amount,
        expense_date=obj_in.expense_date,
        description=obj_in.description.strip(),
        paid_to=obj_in.paid_to.strip(),
        payment_method=obj_in.payment_method,
        reference_number=obj_in.reference_number,
        receipt_url=obj_in.receipt_url,
        status="APPROVED",
        created_by=current_user.id,
        updated_by=current_user.id
    )
    db.add(expense)
    await db.commit()
    await db.refresh(expense)

    return APIResponse[ExpenseResponse](
        success=True,
        message="Expense recorded successfully.",
        data=ExpenseResponse.model_validate(expense)
    )

@router.get(
    "",
    response_model=APIResponse[List[ExpenseResponse]],
    status_code=status.HTTP_200_OK,
    summary="List school expenses"
)
async def list_expenses(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    category: Optional[ExpenseCategory] = Query(None, description="Filter by category"),
    start_date: Optional[date] = Query(None, description="Start date filter"),
    end_date: Optional[date] = Query(None, description="End date filter"),
    search: Optional[str] = Query(None, description="Search description or paid_to"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("fee.read", "school.read")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[List[ExpenseResponse]]:
    await verify_school_access(current_user, school_id, db)

    stmt = select(Expense).where(
        Expense.tenant_id == tenant_id,
        Expense.school_id == school_id,
        Expense.deleted_at.is_(None)
    )
    if category is not None:
        stmt = stmt.where(Expense.category == category)
    if start_date is not None:
        stmt = stmt.where(Expense.expense_date >= start_date)
    if end_date is not None:
        stmt = stmt.where(Expense.expense_date <= end_date)
    if search:
        search_fmt = f"%{search.strip()}%"
        stmt = stmt.where(
            or_(
                Expense.description.ilike(search_fmt),
                Expense.paid_to.ilike(search_fmt),
                Expense.reference_number.ilike(search_fmt)
            )
        )

    stmt = stmt.order_by(Expense.expense_date.desc(), Expense.created_at.desc())
    stmt = stmt.offset(skip).limit(limit)

    result = await db.execute(stmt)
    records = list(result.scalars().all())

    return APIResponse[List[ExpenseResponse]](
        success=True,
        message="Expenses retrieved successfully.",
        data=[ExpenseResponse.model_validate(r) for r in records]
    )

@router.get(
    "/summary",
    response_model=APIResponse[ExpenseSummaryResponse],
    status_code=status.HTTP_200_OK,
    summary="Get aggregated expense statistics"
)
async def get_expense_summary(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    start_date: Optional[date] = Query(None, description="Start date filter"),
    end_date: Optional[date] = Query(None, description="End date filter"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("fee.read", "school.read")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[ExpenseSummaryResponse]:
    await verify_school_access(current_user, school_id, db)

    filters = [
        Expense.tenant_id == tenant_id,
        Expense.school_id == school_id,
        Expense.deleted_at.is_(None)
    ]
    if start_date is not None:
        filters.append(Expense.expense_date >= start_date)
    if end_date is not None:
        filters.append(Expense.expense_date <= end_date)

    # Category totals
    cat_stmt = select(
        Expense.category,
        func.coalesce(func.sum(Expense.amount), 0),
        func.count(Expense.id)
    ).where(and_(*filters)).group_by(Expense.category)

    cat_res = await db.execute(cat_stmt)
    by_category: Dict[str, Decimal] = {}
    total_amount = Decimal("0.00")
    total_count = 0

    for cat, sum_amt, count in cat_res.all():
        cat_str = cat.value if hasattr(cat, "value") else str(cat)
        cat_decimal = Decimal(str(sum_amt))
        by_category[cat_str] = cat_decimal
        total_amount += cat_decimal
        total_count += count

    return APIResponse[ExpenseSummaryResponse](
        success=True,
        message="Expense summary computed successfully.",
        data=ExpenseSummaryResponse(
            total_amount=total_amount,
            total_count=total_count,
            by_category=by_category
        )
    )

@router.get(
    "/{id}",
    response_model=APIResponse[ExpenseResponse],
    status_code=status.HTTP_200_OK,
    summary="Get single expense details"
)
async def get_expense(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("fee.read", "school.read")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[ExpenseResponse]:
    await verify_school_access(current_user, school_id, db)
    stmt = select(Expense).where(
        Expense.id == id,
        Expense.tenant_id == tenant_id,
        Expense.school_id == school_id,
        Expense.deleted_at.is_(None)
    )
    result = await db.execute(stmt)
    expense = result.scalar_one_or_none()
    if not expense:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Expense record not found."
        )
    return APIResponse[ExpenseResponse](
        success=True,
        message="Expense details retrieved successfully.",
        data=ExpenseResponse.model_validate(expense)
    )

@router.put(
    "/{id}",
    response_model=APIResponse[ExpenseResponse],
    status_code=status.HTTP_200_OK,
    summary="Update an existing school expense"
)
async def update_expense(
    id: uuid.UUID,
    obj_in: ExpenseUpdate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("fee.create", "fee.update", "fee.write", "school.update")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[ExpenseResponse]:
    stmt = select(Expense).where(
        Expense.id == id,
        Expense.tenant_id == tenant_id,
        Expense.deleted_at.is_(None)
    )
    result = await db.execute(stmt)
    expense = result.scalar_one_or_none()
    if not expense:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Expense record not found."
        )
    await verify_school_access(current_user, expense.school_id, db)

    if expense.salary_payment_id is not None and obj_in.amount is not None and obj_in.amount != expense.amount:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot modify amount on an expense generated from staff salary disbursement."
        )

    update_data = obj_in.model_dump(exclude_unset=True)
    for field, val in update_data.items():
        if val is not None and isinstance(val, str):
            val = val.strip()
        setattr(expense, field, val)

    expense.updated_by = current_user.id
    expense.updated_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(expense)

    return APIResponse[ExpenseResponse](
        success=True,
        message="Expense updated successfully.",
        data=ExpenseResponse.model_validate(expense)
    )

@router.delete(
    "/{id}",
    response_model=APIResponse[dict],
    status_code=status.HTTP_200_OK,
    summary="Soft-delete expense"
)
async def delete_expense(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("fee.delete", "school.update")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[dict]:
    await verify_school_access(current_user, school_id, db)
    stmt = select(Expense).where(
        Expense.id == id,
        Expense.tenant_id == tenant_id,
        Expense.school_id == school_id,
        Expense.deleted_at.is_(None)
    )
    result = await db.execute(stmt)
    expense = result.scalar_one_or_none()
    if not expense:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Expense record not found."
        )

    if expense.salary_payment_id is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot delete an expense generated from a staff salary disbursement."
        )

    expense.deleted_at = datetime.now(timezone.utc)
    expense.updated_by = current_user.id
    await db.commit()

    return APIResponse[dict](
        success=True,
        message="Expense deleted successfully.",
        data={"id": str(id)}
    )
