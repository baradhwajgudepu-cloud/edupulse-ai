import uuid
from datetime import date, datetime, timezone
from decimal import Decimal
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status, HTTPException
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.db.session import get_db
from app.api.dependencies.common import get_tenant_id, verify_school_access
from app.api.dependencies.auth import require_permission
from app.models.teacher import Teacher, TeacherStatus
from app.models.payroll import (
    PayrollPolicy, TeacherPayrollProfile, TeacherPayroll, PayrollAuditLog,
    PayrollStatus, PayrollAuditAction
)
from app.models.staff_salary import StaffSalary, SalaryStatus
from app.models.user import User
from app.schemas.response import APIResponse
from app.schemas.payroll import (
    PayrollPolicyCreate, PayrollPolicyUpdate, PayrollPolicyResponse,
    TeacherPayrollProfileCreate, TeacherPayrollProfileUpdate, TeacherPayrollProfileResponse,
    CalculatePayrollRequest, TeacherPayrollItemResponse, MonthlyPayrollSummaryResponse,
    ApprovePayrollRequest, PayrollAuditLogResponse, PayrollImpactAlertResponse
)
from app.services.payroll_engine import PayrollEngine

router = APIRouter()


def _to_profile_response(prof: TeacherPayrollProfile) -> TeacherPayrollProfileResponse:
    tname = f"{prof.teacher.first_name} {prof.teacher.last_name or ''}".strip() if prof.teacher else "Unknown Teacher"
    tcode = prof.teacher.staff_code or prof.teacher.employee_code or "N/A" if prof.teacher else "N/A"
    return TeacherPayrollProfileResponse(
        id=prof.id,
        tenant_id=prof.tenant_id,
        school_id=prof.school_id,
        teacher_id=prof.teacher_id,
        teacher_name=tname,
        teacher_code=tcode,
        designation=prof.teacher.designation if prof.teacher else None,
        department=prof.teacher.department if prof.teacher else None,
        monthly_gross_salary=prof.monthly_gross_salary,
        basic_salary=prof.basic_salary,
        hra_allowance=prof.hra_allowance,
        special_allowance=prof.special_allowance,
        other_allowances=prof.other_allowances,
        provident_fund_deduction=prof.provident_fund_deduction,
        tax_deduction=prof.tax_deduction,
        other_deductions=prof.other_deductions,
        paid_leave_quota_per_year=prof.paid_leave_quota_per_year,
        bank_account_number=prof.bank_account_number,
        bank_ifsc=prof.bank_ifsc,
        bank_name=prof.bank_name,
        effective_from=prof.effective_from,
        effective_until=prof.effective_until,
        is_active=prof.is_active,
        created_at=prof.created_at,
        updated_at=prof.updated_at
    )


def _to_item_response(p: TeacherPayroll) -> TeacherPayrollItemResponse:
    tname = f"{p.teacher.first_name} {p.teacher.last_name or ''}".strip() if p.teacher else "Unknown Teacher"
    tcode = p.teacher.staff_code or p.teacher.employee_code or "N/A" if p.teacher else "N/A"
    calc_name = f"{p.calculator_user.first_name} {p.calculator_user.last_name or ''}".strip() if p.calculator_user else None
    appr_name = f"{p.approver_user.first_name} {p.approver_user.last_name or ''}".strip() if p.approver_user else None

    return TeacherPayrollItemResponse(
        id=p.id,
        tenant_id=p.tenant_id,
        school_id=p.school_id,
        teacher_id=p.teacher_id,
        teacher_name=tname,
        teacher_code=tcode,
        designation=p.teacher.designation if p.teacher else None,
        department=p.teacher.department if p.teacher else None,
        month=p.month,
        year=p.year,
        calculation_date=p.calculation_date,
        calendar_days=p.calendar_days,
        applicable_working_days=p.applicable_working_days,
        present_days=p.present_days,
        approved_leave_days=p.approved_leave_days,
        half_days=p.half_days,
        unpaid_absence_days=p.unpaid_absence_days,
        holidays_count=p.holidays_count,
        on_duty_days=p.on_duty_days,
        late_days=p.late_days,
        unmarked_days=p.unmarked_days,
        gross_salary=p.gross_salary,
        daily_rate=p.daily_rate,
        attendance_deductions=p.attendance_deductions,
        statutory_deductions=p.statutory_deductions,
        manual_adjustments=p.manual_adjustments,
        adjustment_reason=p.adjustment_reason,
        net_payable=p.net_payable,
        ai_explanation=p.ai_explanation,
        ai_anomalies=p.ai_anomalies or [],
        status=p.status,
        calculated_by_name=calc_name,
        approved_by_name=appr_name,
        approved_at=p.approved_at,
        created_at=p.created_at,
        updated_at=p.updated_at
    )


# -------------------------------------------------------------
# Payroll Policy
# -------------------------------------------------------------

@router.get(
    "/payroll/policies",
    response_model=APIResponse[List[PayrollPolicyResponse]],
    status_code=status.HTTP_200_OK,
    summary="List school payroll policies"
)
async def list_payroll_policies(
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher.payroll.read", "school.read")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[List[PayrollPolicyResponse]]:
    await verify_school_access(current_user, school_id, db)
    # Ensure default exists
    await PayrollEngine.get_or_create_default_policy(db, tenant_id, school_id)
    await db.commit()

    stmt = select(PayrollPolicy).where(
        PayrollPolicy.tenant_id == tenant_id,
        PayrollPolicy.school_id == school_id,
        PayrollPolicy.deleted_at.is_(None)
    ).order_by(PayrollPolicy.created_at.desc())
    policies = list((await db.execute(stmt)).scalars().all())

    return APIResponse[List[PayrollPolicyResponse]](
        success=True,
        message="Payroll policies retrieved successfully",
        data=[PayrollPolicyResponse.model_validate(p) for p in policies]
    )


@router.post(
    "/payroll/policies",
    response_model=APIResponse[PayrollPolicyResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create new payroll policy"
)
async def create_payroll_policy(
    school_id: uuid.UUID,
    req: PayrollPolicyCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher.payroll.calculate", "school.update")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[PayrollPolicyResponse]:
    await verify_school_access(current_user, school_id, db)

    pol = PayrollPolicy(
        tenant_id=tenant_id,
        school_id=school_id,
        policy_name=req.policy_name,
        calculation_basis=req.calculation_basis,
        standard_working_days=req.standard_working_days,
        daily_rate_formula=req.daily_rate_formula,
        half_day_deduction_factor=req.half_day_deduction_factor,
        unpaid_leave_deduction_factor=req.unpaid_leave_deduction_factor,
        late_grace_count=req.late_grace_count,
        late_deduction_factor=req.late_deduction_factor,
        is_active=req.is_active
    )
    db.add(pol)
    await db.commit()
    await db.refresh(pol)

    return APIResponse[PayrollPolicyResponse](
        success=True,
        message="Payroll policy created successfully",
        data=PayrollPolicyResponse.model_validate(pol)
    )


@router.put(
    "/payroll/policies/{id}",
    response_model=APIResponse[PayrollPolicyResponse],
    status_code=status.HTTP_200_OK,
    summary="Update payroll policy"
)
async def update_payroll_policy(
    id: uuid.UUID,
    req: PayrollPolicyUpdate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher.payroll.calculate", "school.update")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[PayrollPolicyResponse]:
    pol = await db.get(PayrollPolicy, id)
    if not pol or pol.tenant_id != tenant_id or pol.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payroll policy not found")
    await verify_school_access(current_user, pol.school_id, db)

    for field, val in req.model_dump(exclude_unset=True).items():
        setattr(pol, field, val)

    await db.commit()
    await db.refresh(pol)

    return APIResponse[PayrollPolicyResponse](
        success=True,
        message="Payroll policy updated successfully",
        data=PayrollPolicyResponse.model_validate(pol)
    )


# -------------------------------------------------------------
# Teacher Payroll Profiles
# -------------------------------------------------------------

@router.get(
    "/payroll/profiles",
    response_model=APIResponse[List[TeacherPayrollProfileResponse]],
    status_code=status.HTTP_200_OK,
    summary="List teacher compensation profiles"
)
async def list_teacher_payroll_profiles(
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher.payroll.read", "school.read")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[List[TeacherPayrollProfileResponse]]:
    await verify_school_access(current_user, school_id, db)

    # Ensure all active teachers have a profile
    t_stmt = select(Teacher).where(
        Teacher.tenant_id == tenant_id,
        Teacher.school_id == school_id,
        Teacher.status == TeacherStatus.ACTIVE,
        Teacher.deleted_at.is_(None)
    )
    teachers = list((await db.execute(t_stmt)).scalars().all())
    for t in teachers:
        await PayrollEngine.get_or_create_teacher_profile(db, tenant_id, school_id, t)
    await db.commit()

    stmt = select(TeacherPayrollProfile).options(
        selectinload(TeacherPayrollProfile.teacher)
    ).where(
        TeacherPayrollProfile.tenant_id == tenant_id,
        TeacherPayrollProfile.school_id == school_id,
        TeacherPayrollProfile.deleted_at.is_(None)
    ).order_by(TeacherPayrollProfile.created_at.desc())
    profiles = list((await db.execute(stmt)).scalars().all())

    return APIResponse[List[TeacherPayrollProfileResponse]](
        success=True,
        message="Teacher payroll profiles retrieved successfully",
        data=[_to_profile_response(p) for p in profiles]
    )


@router.get(
    "/payroll/teachers/{teacher_id}",
    response_model=APIResponse[TeacherPayrollProfileResponse],
    status_code=status.HTTP_200_OK,
    summary="Get single teacher compensation profile"
)
async def get_teacher_payroll_profile(
    teacher_id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher.payroll.read", "school.read")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[TeacherPayrollProfileResponse]:
    await verify_school_access(current_user, school_id, db)
    teacher = await db.get(Teacher, teacher_id)
    if not teacher or teacher.tenant_id != tenant_id or teacher.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Teacher not found")

    profile = await PayrollEngine.get_or_create_teacher_profile(db, tenant_id, school_id, teacher)
    await db.commit()
    profile.teacher = teacher

    return APIResponse[TeacherPayrollProfileResponse](
        success=True,
        message="Teacher payroll profile retrieved successfully",
        data=_to_profile_response(profile)
    )


@router.post(
    "/payroll/profiles",
    response_model=APIResponse[TeacherPayrollProfileResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create or update teacher compensation profile"
)
async def save_teacher_payroll_profile(
    req: TeacherPayrollProfileCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    school_id: uuid.UUID = Query(...),
    current_user: User = Depends(require_permission("teacher.payroll.calculate", "school.update")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[TeacherPayrollProfileResponse]:
    await verify_school_access(current_user, school_id, db)
    teacher = await db.get(Teacher, req.teacher_id)
    if not teacher or teacher.tenant_id != tenant_id or teacher.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Teacher not found")

    stmt = select(TeacherPayrollProfile).where(
        TeacherPayrollProfile.school_id == school_id,
        TeacherPayrollProfile.teacher_id == req.teacher_id,
        TeacherPayrollProfile.deleted_at.is_(None)
    )
    profile = (await db.execute(stmt)).scalars().first()

    if profile:
        for field, val in req.model_dump().items():
            if field != "teacher_id":
                setattr(profile, field, val)
    else:
        profile = TeacherPayrollProfile(
            tenant_id=tenant_id,
            school_id=school_id,
            **req.model_dump()
        )
        db.add(profile)

    await db.commit()
    await db.refresh(profile)
    profile.teacher = teacher

    return APIResponse[TeacherPayrollProfileResponse](
        success=True,
        message="Teacher payroll profile saved successfully",
        data=_to_profile_response(profile)
    )


# -------------------------------------------------------------
# Payroll Calculation & Approval
# -------------------------------------------------------------

@router.get(
    "/payroll/monthly-summary",
    response_model=APIResponse[MonthlyPayrollSummaryResponse],
    status_code=status.HTTP_200_OK,
    summary="Get monthly payroll summary for school campus"
)
async def get_monthly_payroll_summary(
    school_id: uuid.UUID = Query(...),
    month: int = Query(..., ge=1, le=12),
    year: int = Query(..., ge=2020, le=2050),
    policy_id: Optional[uuid.UUID] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher.payroll.read", "school.read")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[MonthlyPayrollSummaryResponse]:
    await verify_school_access(current_user, school_id, db)

    # 1. Fetch policy
    if policy_id:
        policy = await db.get(PayrollPolicy, policy_id)
        if not policy or policy.school_id != school_id:
            policy = await PayrollEngine.get_or_create_default_policy(db, tenant_id, school_id)
    else:
        policy = await PayrollEngine.get_or_create_default_policy(db, tenant_id, school_id)

    # 2. Fetch existing payroll items for this school, month, year
    stmt = (
        select(TeacherPayroll)
        .options(
            selectinload(TeacherPayroll.teacher),
            selectinload(TeacherPayroll.calculator_user),
            selectinload(TeacherPayroll.approver_user)
        )
        .where(
            TeacherPayroll.tenant_id == tenant_id,
            TeacherPayroll.school_id == school_id,
            TeacherPayroll.month == month,
            TeacherPayroll.year == year,
            TeacherPayroll.deleted_at.is_(None)
        )
    )
    items = list((await db.execute(stmt)).scalars().all())

    # If no items exist yet, calculate a preview draft
    if not items:
        t_stmt = select(Teacher).where(
            Teacher.tenant_id == tenant_id,
            Teacher.school_id == school_id,
            Teacher.status == TeacherStatus.ACTIVE,
            Teacher.deleted_at.is_(None)
        )
        teachers = list((await db.execute(t_stmt)).scalars().all())
        for t in teachers:
            prof = await PayrollEngine.get_or_create_teacher_profile(db, tenant_id, school_id, t)
            rec = await PayrollEngine.calculate_teacher_payroll(
                db, tenant_id, school_id, t, policy, prof, year, month, calculator_id=current_user.id
            )
            rec.teacher = t
            rec.calculator_user = current_user
            items.append(rec)
        await db.commit()

    tot_gross = sum(c.gross_salary for c in items)
    tot_att_ded = sum(c.attendance_deductions for c in items)
    tot_stat_ded = sum(c.statutory_deductions for c in items)
    tot_net = sum(c.net_payable for c in items)
    approved_cnt = sum(1 for c in items if c.status == PayrollStatus.APPROVED)
    draft_cnt = len(items) - approved_cnt

    summary = MonthlyPayrollSummaryResponse(
        school_id=school_id,
        month=month,
        year=year,
        policy_name=policy.policy_name,
        total_teachers=len(items),
        draft_count=draft_cnt,
        approved_count=approved_cnt,
        total_gross_disbursement=tot_gross,
        total_attendance_deductions=tot_att_ded,
        total_statutory_deductions=tot_stat_ded,
        total_net_payable=tot_net,
        items=[_to_item_response(c) for c in items]
    )

    return APIResponse[MonthlyPayrollSummaryResponse](
        success=True,
        message=f"Payroll summary retrieved for {len(items)} teachers",
        data=summary
    )


@router.post(
    "/payroll/calculate",
    response_model=APIResponse[MonthlyPayrollSummaryResponse],
    status_code=status.HTTP_200_OK,
    summary="Execute attendance-based monthly payroll calculation"
)
async def calculate_monthly_payroll(
    req: CalculatePayrollRequest,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher.payroll.calculate", "school.update")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[MonthlyPayrollSummaryResponse]:
    await verify_school_access(current_user, req.school_id, db)

    # 1. Fetch policy
    if req.policy_id:
        policy = await db.get(PayrollPolicy, req.policy_id)
        if not policy or policy.school_id != req.school_id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Specified payroll policy not found")
    else:
        policy = await PayrollEngine.get_or_create_default_policy(db, tenant_id, req.school_id)

    # 2. Fetch target teachers
    t_stmt = select(Teacher).where(
        Teacher.tenant_id == tenant_id,
        Teacher.school_id == req.school_id,
        Teacher.status == TeacherStatus.ACTIVE,
        Teacher.deleted_at.is_(None)
    )
    if req.teacher_ids:
        t_stmt = t_stmt.where(Teacher.id.in_(req.teacher_ids))
    teachers = list((await db.execute(t_stmt)).scalars().all())

    if not teachers:
        return APIResponse[MonthlyPayrollSummaryResponse](
            success=True,
            message="No active teachers found for calculation",
            data=MonthlyPayrollSummaryResponse(
                school_id=req.school_id,
                month=req.month,
                year=req.year,
                policy_name=policy.policy_name,
                total_teachers=0,
                draft_count=0,
                approved_count=0,
                total_gross_disbursement=Decimal("0.00"),
                total_attendance_deductions=Decimal("0.00"),
                total_statutory_deductions=Decimal("0.00"),
                total_net_payable=Decimal("0.00"),
                items=[]
            )
        )

    # 3. Calculate for each teacher
    calculated_items = []
    for t in teachers:
        prof = await PayrollEngine.get_or_create_teacher_profile(db, tenant_id, req.school_id, t)
        rec = await PayrollEngine.calculate_teacher_payroll(
            db, tenant_id, req.school_id, t, policy, prof, req.year, req.month, calculator_id=current_user.id
        )
        rec.teacher = t
        rec.calculator_user = current_user
        calculated_items.append(rec)

    await db.commit()

    # Build summary
    tot_gross = sum(c.gross_salary for c in calculated_items)
    tot_att_ded = sum(c.attendance_deductions for c in calculated_items)
    tot_stat_ded = sum(c.statutory_deductions for c in calculated_items)
    tot_net = sum(c.net_payable for c in calculated_items)
    approved_cnt = sum(1 for c in calculated_items if c.status == PayrollStatus.APPROVED)
    draft_cnt = len(calculated_items) - approved_cnt

    summary = MonthlyPayrollSummaryResponse(
        school_id=req.school_id,
        month=req.month,
        year=req.year,
        policy_name=policy.policy_name,
        total_teachers=len(calculated_items),
        draft_count=draft_cnt,
        approved_count=approved_cnt,
        total_gross_disbursement=tot_gross,
        total_attendance_deductions=tot_att_ded,
        total_statutory_deductions=tot_stat_ded,
        total_net_payable=tot_net,
        items=[_to_item_response(c) for c in calculated_items]
    )

    return APIResponse[MonthlyPayrollSummaryResponse](
        success=True,
        message=f"Payroll calculated successfully for {len(calculated_items)} teachers",
        data=summary
    )


@router.post(
    "/payroll/{id}/approve",
    response_model=APIResponse[TeacherPayrollItemResponse],
    status_code=status.HTTP_200_OK,
    summary="Approve and finalize teacher monthly payroll"
)
async def approve_teacher_payroll(
    id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher.payroll.approve", "school.update")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[TeacherPayrollItemResponse]:
    payroll = await db.get(TeacherPayroll, id)
    if not payroll or payroll.tenant_id != tenant_id or payroll.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payroll record not found")
    await verify_school_access(current_user, payroll.school_id, db)

    payroll.status = PayrollStatus.APPROVED
    payroll.approved_by = current_user.id
    payroll.approved_at = datetime.now(timezone.utc)

    # Synchronize with legacy StaffSalary slip for seamless financial reporting
    sal_stmt = select(StaffSalary).where(
        StaffSalary.tenant_id == tenant_id,
        StaffSalary.school_id == payroll.school_id,
        StaffSalary.staff_id == payroll.teacher_id,
        StaffSalary.month == payroll.month,
        StaffSalary.year == payroll.year,
        StaffSalary.deleted_at.is_(None)
    )
    legacy_sal = (await db.execute(sal_stmt)).scalars().first()
    tot_deductions = payroll.attendance_deductions + payroll.statutory_deductions
    if legacy_sal:
        legacy_sal.base_salary = payroll.gross_salary
        legacy_sal.deductions = tot_deductions
        legacy_sal.net_salary = payroll.net_payable
        legacy_sal.status = SalaryStatus.PENDING
    else:
        legacy_sal = StaffSalary(
            tenant_id=tenant_id,
            school_id=payroll.school_id,
            staff_id=payroll.teacher_id,
            month=payroll.month,
            year=payroll.year,
            base_salary=payroll.gross_salary,
            allowances=Decimal("0.00"),
            deductions=tot_deductions,
            net_salary=payroll.net_payable,
            status=SalaryStatus.PENDING,
            remarks=f"Attendance payroll approved on {date.today().isoformat()}"
        )
        db.add(legacy_sal)

    # Audit log
    audit = PayrollAuditLog(
        tenant_id=tenant_id,
        school_id=payroll.school_id,
        payroll_id=payroll.id,
        teacher_id=payroll.teacher_id,
        action=PayrollAuditAction.APPROVED,
        actor_id=current_user.id,
        revised_net_pay=payroll.net_payable,
        notes=f"Approved payroll for {payroll.month:02d}/{payroll.year}. Net disbursement: ₹{payroll.net_payable:,.2f}."
    )
    db.add(audit)

    await db.commit()
    await db.refresh(payroll)
    payroll.teacher = await db.get(Teacher, payroll.teacher_id)
    payroll.approver_user = current_user

    return APIResponse[TeacherPayrollItemResponse](
        success=True,
        message="Payroll approved and finalized successfully",
        data=_to_item_response(payroll)
    )


@router.get(
    "/payroll/attendance-correction-check",
    response_model=APIResponse[PayrollImpactAlertResponse],
    status_code=status.HTTP_200_OK,
    summary="Check if retroactive attendance change affects payroll"
)
async def check_attendance_correction_impact(
    school_id: uuid.UUID = Query(...),
    teacher_id: uuid.UUID = Query(...),
    correction_date: date = Query(...),
    new_status: str = Query(..., description="PRESENT, APPROVED_LEAVE, HALF_DAY, UNPAID_ABSENCE"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher.attendance.payroll_impact", "school.read")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[PayrollImpactAlertResponse]:
    await verify_school_access(current_user, school_id, db)
    impact = await PayrollEngine.check_attendance_correction_impact(
        db, tenant_id, school_id, teacher_id, correction_date, new_status
    )
    return APIResponse[PayrollImpactAlertResponse](
        success=True,
        message="Attendance correction impact evaluated successfully",
        data=impact
    )


@router.get(
    "/payroll/{id}/audit",
    response_model=APIResponse[List[PayrollAuditLogResponse]],
    status_code=status.HTTP_200_OK,
    summary="Get audit logs for payroll"
)
async def get_payroll_audit_logs(
    id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("teacher.payroll.read", "school.read")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[List[PayrollAuditLogResponse]]:
    payroll = await db.get(TeacherPayroll, id)
    if not payroll or payroll.tenant_id != tenant_id or payroll.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payroll record not found")
    await verify_school_access(current_user, payroll.school_id, db)

    stmt = select(PayrollAuditLog).options(
        selectinload(PayrollAuditLog.teacher),
        selectinload(PayrollAuditLog.actor)
    ).where(
        PayrollAuditLog.tenant_id == tenant_id,
        PayrollAuditLog.payroll_id == id
    ).order_by(PayrollAuditLog.created_at.desc())
    logs = list((await db.execute(stmt)).scalars().all())

    items = []
    for l in logs:
        tname = f"{l.teacher.first_name} {l.teacher.last_name or ''}".strip() if l.teacher else "Unknown Teacher"
        aname = f"{l.actor.first_name} {l.actor.last_name or ''}".strip() if l.actor else None
        items.append(
            PayrollAuditLogResponse(
                id=l.id,
                school_id=l.school_id,
                payroll_id=l.payroll_id,
                teacher_id=l.teacher_id,
                teacher_name=tname,
                action=l.action,
                actor_name=aname,
                previous_net_pay=l.previous_net_pay,
                revised_net_pay=l.revised_net_pay,
                delta_amount=l.delta_amount,
                notes=l.notes,
                created_at=l.created_at
            )
        )

    return APIResponse[List[PayrollAuditLogResponse]](
        success=True,
        message="Payroll audit trail retrieved successfully",
        data=items
    )
