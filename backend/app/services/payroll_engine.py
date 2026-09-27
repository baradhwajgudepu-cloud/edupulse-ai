import uuid
import calendar
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from typing import List, Dict, Any, Optional, Tuple
from sqlalchemy import select, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.teacher import Teacher, TeacherStatus
from app.models.school import School
from app.models.staff_attendance import StaffAttendance
from app.models.teacher_leave import TeacherLeave, LeaveStatus
from app.models.academic_calendar import AcademicCalendarEvent, CalendarEventType
from app.models.payroll import (
    PayrollPolicy, TeacherPayrollProfile, TeacherPayroll, PayrollAuditLog,
    PayrollCalculationBasis, DailyRateFormula, PayrollStatus, PayrollAuditAction
)
from app.schemas.payroll import (
    CalculatePayrollRequest, TeacherPayrollItemResponse, MonthlyPayrollSummaryResponse,
    PayrollImpactAlertResponse
)


class PayrollEngine:
    """
    Authoritative Attendance-Based Payroll & AI Explainability Engine.
    Strictly tenant-isolated, policy-driven, and non-destructive.
    """

    @staticmethod
    async def get_or_create_default_policy(
        db: AsyncSession, tenant_id: uuid.UUID, school_id: uuid.UUID
    ) -> PayrollPolicy:
        stmt = select(PayrollPolicy).where(
            PayrollPolicy.tenant_id == tenant_id,
            PayrollPolicy.school_id == school_id,
            PayrollPolicy.is_active == True,
            PayrollPolicy.deleted_at.is_(None)
        )
        policy = (await db.execute(stmt)).scalars().first()
        if not policy:
            policy = PayrollPolicy(
                tenant_id=tenant_id,
                school_id=school_id,
                policy_name="Standard Model School Payroll Policy",
                calculation_basis=PayrollCalculationBasis.WORKING_DAYS,
                standard_working_days=24,
                daily_rate_formula=DailyRateFormula.GROSS_DIVIDED_BY_WORKING_DAYS,
                half_day_deduction_factor=Decimal("0.50"),
                unpaid_leave_deduction_factor=Decimal("1.00"),
                late_grace_count=3,
                late_deduction_factor=Decimal("0.25"),
                is_active=True
            )
            db.add(policy)
            await db.flush()
        return policy

    @staticmethod
    async def get_or_create_teacher_profile(
        db: AsyncSession, tenant_id: uuid.UUID, school_id: uuid.UUID, teacher: Teacher
    ) -> TeacherPayrollProfile:
        stmt = select(TeacherPayrollProfile).where(
            TeacherPayrollProfile.tenant_id == tenant_id,
            TeacherPayrollProfile.school_id == school_id,
            TeacherPayrollProfile.teacher_id == teacher.id,
            TeacherPayrollProfile.deleted_at.is_(None)
        )
        profile = (await db.execute(stmt)).scalars().first()
        if not profile:
            # Fall back to base teacher salary if configured, else default ₹40,000 standard
            base_amt = Decimal(str(teacher.salary)) if teacher.salary else Decimal("40000.00")
            basic = (base_amt * Decimal("0.50")).quantize(Decimal("0.01"))
            hra = (base_amt * Decimal("0.30")).quantize(Decimal("0.01"))
            special = base_amt - basic - hra
            pf = (basic * Decimal("0.12")).quantize(Decimal("0.01"))

            profile = TeacherPayrollProfile(
                tenant_id=tenant_id,
                school_id=school_id,
                teacher_id=teacher.id,
                monthly_gross_salary=base_amt,
                basic_salary=basic,
                hra_allowance=hra,
                special_allowance=special,
                other_allowances=Decimal("0.00"),
                provident_fund_deduction=pf,
                tax_deduction=Decimal("0.00"),
                other_deductions=Decimal("0.00"),
                paid_leave_quota_per_year=12,
                effective_from=date(date.today().year, 1, 1),
                is_active=True
            )
            db.add(profile)
            await db.flush()
        return profile

    @classmethod
    async def calculate_teacher_payroll(
        cls,
        db: AsyncSession,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        teacher: Teacher,
        policy: PayrollPolicy,
        profile: TeacherPayrollProfile,
        year: int,
        month: int,
        calculator_id: Optional[uuid.UUID] = None
    ) -> TeacherPayroll:
        """
        Classifies every calendar day in the month into attendance states,
        applies school payroll policy, generates AI explanation & anomaly alerts,
        and saves or updates the draft TeacherPayroll record.
        """
        _, total_days = calendar.monthrange(year, month)
        start_date = date(year, month, 1)
        end_date = date(year, month, total_days)
        today = date.today()

        # 1. Fetch Staff Attendance check-ins
        att_stmt = select(StaffAttendance).where(
            StaffAttendance.tenant_id == tenant_id,
            StaffAttendance.school_id == school_id,
            StaffAttendance.teacher_id == teacher.id,
            StaffAttendance.attendance_date >= start_date,
            StaffAttendance.attendance_date <= end_date,
            StaffAttendance.deleted_at.is_(None)
        )
        att_records = {a.attendance_date: a for a in (await db.execute(att_stmt)).scalars().all()}

        # 2. Fetch Approved Teacher Leaves
        leave_stmt = select(TeacherLeave).where(
            TeacherLeave.tenant_id == tenant_id,
            TeacherLeave.school_id == school_id,
            TeacherLeave.teacher_id == teacher.id,
            TeacherLeave.status == LeaveStatus.APPROVED,
            TeacherLeave.start_date <= end_date,
            TeacherLeave.end_date >= start_date,
            TeacherLeave.deleted_at.is_(None)
        )
        approved_leaves = (await db.execute(leave_stmt)).scalars().all()
        leave_dates = set()
        for l in approved_leaves:
            curr = max(l.start_date, start_date)
            l_end = min(l.end_date, end_date)
            while curr <= l_end:
                leave_dates.add(curr)
                curr += timedelta(days=1)

        # 3. Fetch Academic Calendar Holidays & Closures
        cal_stmt = select(AcademicCalendarEvent).where(
            AcademicCalendarEvent.tenant_id == tenant_id,
            AcademicCalendarEvent.school_id == school_id,
            AcademicCalendarEvent.event_date >= start_date,
            AcademicCalendarEvent.event_date <= end_date,
            AcademicCalendarEvent.deleted_at.is_(None)
        )
        cal_events = (await db.execute(cal_stmt)).scalars().all()
        holiday_dates = set()
        for ev in cal_events:
            ev_type_str = str(ev.event_type)
            if "HOLIDAY" in ev_type_str or ev.event_type in (
                CalendarEventType.PUBLIC_HOLIDAY, CalendarEventType.SCHOOL_HOLIDAY,
                CalendarEventType.PRINCIPAL_DECLARED_HOLIDAY
            ):
                holiday_dates.add(ev.event_date)

        # 4. Classify each day
        present_count = Decimal("0.0")
        approved_leave_count = Decimal("0.0")
        half_day_count = 0
        unpaid_absence_count = Decimal("0.0")
        holiday_count = 0
        on_duty_count = 0
        late_count = 0
        unmarked_count = 0
        working_days_count = 0

        consecutive_unmarked = 0
        max_consecutive_unmarked = 0

        for d in range(1, total_days + 1):
            curr_date = date(year, month, d)
            is_sunday = curr_date.weekday() == 6

            if is_sunday or curr_date in holiday_dates:
                holiday_count += 1
                consecutive_unmarked = 0
                continue

            working_days_count += 1

            if curr_date in leave_dates:
                approved_leave_count += Decimal("1.0")
                consecutive_unmarked = 0
            elif curr_date in att_records:
                att = att_records[curr_date]
                consecutive_unmarked = 0
                
                # Check for half day or late
                check_in = att.check_in_time
                check_out = att.check_out_time
                if check_in and check_out:
                    diff_hours = (check_out - check_in).total_seconds() / 3600.0
                    if diff_hours < 5.0:
                        half_day_count += 1
                        present_count += Decimal("0.5")
                    else:
                        present_count += Decimal("1.0")
                else:
                    present_count += Decimal("1.0")

                # Late check-in: after 09:15 AM
                if check_in and (check_in.hour > 9 or (check_in.hour == 9 and check_in.minute > 15)):
                    late_count += 1
            else:
                # No check-in and no approved leave
                if curr_date <= today:
                    # In past
                    unmarked_count += 1
                    consecutive_unmarked += 1
                    if consecutive_unmarked > max_consecutive_unmarked:
                        max_consecutive_unmarked = consecutive_unmarked
                else:
                    # Future day in current month: not an absence
                    pass

        # Calculate applicable working days
        if policy.calculation_basis == PayrollCalculationBasis.CALENDAR_DAYS:
            divisor = Decimal(str(total_days))
        elif policy.calculation_basis == PayrollCalculationBasis.FIXED_30_DAYS:
            divisor = Decimal("30.0")
        else:
            divisor = Decimal(str(max(1, working_days_count)))

        daily_rate = (profile.monthly_gross_salary / divisor).quantize(Decimal("0.01"))

        # Calculate Deductions
        # Note: Unpaid absence only counts confirmed absences or if school policy counts unmarked
        # We treat half-days and excess lates as policy-mandated deductions
        half_day_deduction = (Decimal(str(half_day_count)) * daily_rate * policy.half_day_deduction_factor).quantize(Decimal("0.01"))
        
        excess_lates = max(0, late_count - policy.late_grace_count)
        late_deduction = (Decimal(str(excess_lates)) * daily_rate * policy.late_deduction_factor).quantize(Decimal("0.01"))

        # Unpaid absence deduction: if any explicitly flagged or unmarked days exceeding 3
        # (Standard grace rule: 1-2 unmarked days require admin inquiry; 3+ considered unapproved)
        penalized_unpaid = unpaid_absence_count
        if unmarked_count > 2:
            penalized_unpaid += Decimal(str(unmarked_count - 2))
        
        unpaid_deduction = (penalized_unpaid * daily_rate * policy.unpaid_leave_deduction_factor).quantize(Decimal("0.01"))

        total_attendance_deduction = half_day_deduction + late_deduction + unpaid_deduction
        total_statutory = (profile.provident_fund_deduction + profile.tax_deduction + profile.other_deductions).quantize(Decimal("0.01"))

        net_payable = max(Decimal("0.00"), profile.monthly_gross_salary - total_attendance_deduction - total_statutory)

        # AI Anomaly Detection & Insights
        anomalies = []
        if max_consecutive_unmarked >= 3:
            anomalies.append(f"{max_consecutive_unmarked} consecutive unmarked days detected between {month}/{year}. Recommend verifying medical leave or physical register.")
        if excess_lates > 0:
            anomalies.append(f"Recorded {late_count} late arrivals exceeding the school's grace limit of {policy.late_grace_count}. Penalty factor applied.")
        if half_day_count > 0:
            anomalies.append(f"{half_day_count} half-day sessions logged based on duration < 5 hours.")
        if unmarked_count == 0 and present_count > Decimal("0"):
            anomalies.append("100% full attendance compliance achieved for this period.")

        # AI Explanation Generation
        teacher_display = f"{teacher.first_name} {teacher.last_name or ''}".strip()
        explanation_parts = [
            f"✨ AI Payroll Insight for {teacher_display} ({month:02d}/{year}):",
            f"Monthly Gross Salary: ₹{profile.monthly_gross_salary:,.2f} on {policy.calculation_basis.value} policy (Daily Rate: ₹{daily_rate:,.2f}).",
            f"Attendance Breakdown: {present_days_fmt(present_count)} Present, {approved_leave_count} Approved Leave, {half_day_count} Half Day, {holiday_count} Holidays/Sundays, {unmarked_count} Unmarked."
        ]
        if total_attendance_deduction > Decimal("0.00"):
            explanation_parts.append(
                f"Calculated Attendance Deductions: ₹{total_attendance_deduction:,.2f} "
                f"(Half-Day: ₹{half_day_deduction:,.2f}, Late Penalty: ₹{late_deduction:,.2f}, Unpaid: ₹{unpaid_deduction:,.2f})."
            )
        else:
            explanation_parts.append("Zero attendance penalties incurred. Clean attendance record.")
        explanation_parts.append(f"Net Payable after statutory deductions (PF/Tax: ₹{total_statutory:,.2f}) is ₹{net_payable:,.2f}.")
        ai_explanation = "\n".join(explanation_parts)

        # Check existing TeacherPayroll record for this month
        existing_stmt = select(TeacherPayroll).where(
            TeacherPayroll.tenant_id == tenant_id,
            TeacherPayroll.school_id == school_id,
            TeacherPayroll.teacher_id == teacher.id,
            TeacherPayroll.month == month,
            TeacherPayroll.year == year,
            TeacherPayroll.deleted_at.is_(None)
        )
        existing_payroll = (await db.execute(existing_stmt)).scalars().first()

        if existing_payroll:
            # Update draft
            existing_payroll.policy_id = policy.id
            existing_payroll.calculation_date = today
            existing_payroll.calendar_days = total_days
            existing_payroll.applicable_working_days = working_days_count
            existing_payroll.present_days = present_count
            existing_payroll.approved_leave_days = approved_leave_count
            existing_payroll.half_days = half_day_count
            existing_payroll.unpaid_absence_days = penalized_unpaid
            existing_payroll.holidays_count = holiday_count
            existing_payroll.on_duty_days = on_duty_count
            existing_payroll.late_days = late_count
            existing_payroll.unmarked_days = unmarked_count
            existing_payroll.gross_salary = profile.monthly_gross_salary
            existing_payroll.daily_rate = daily_rate
            existing_payroll.attendance_deductions = total_attendance_deduction
            existing_payroll.statutory_deductions = total_statutory
            existing_payroll.net_payable = net_payable
            existing_payroll.ai_explanation = ai_explanation
            existing_payroll.ai_anomalies = anomalies
            existing_payroll.calculated_by = calculator_id
            payroll_rec = existing_payroll
        else:
            payroll_rec = TeacherPayroll(
                tenant_id=tenant_id,
                school_id=school_id,
                teacher_id=teacher.id,
                policy_id=policy.id,
                month=month,
                year=year,
                calculation_date=today,
                calendar_days=total_days,
                applicable_working_days=working_days_count,
                present_days=present_count,
                approved_leave_days=approved_leave_count,
                half_days=half_day_count,
                unpaid_absence_days=penalized_unpaid,
                holidays_count=holiday_count,
                on_duty_days=on_duty_count,
                late_days=late_count,
                unmarked_days=unmarked_count,
                gross_salary=profile.monthly_gross_salary,
                daily_rate=daily_rate,
                attendance_deductions=total_attendance_deduction,
                statutory_deductions=total_statutory,
                manual_adjustments=Decimal("0.00"),
                net_payable=net_payable,
                ai_explanation=ai_explanation,
                ai_anomalies=anomalies,
                status=PayrollStatus.DRAFT,
                calculated_by=calculator_id
            )
            db.add(payroll_rec)

        await db.flush()

        # Audit Log
        audit = PayrollAuditLog(
            tenant_id=tenant_id,
            school_id=school_id,
            payroll_id=payroll_rec.id,
            teacher_id=teacher.id,
            action=PayrollAuditAction.CALCULATED,
            actor_id=calculator_id,
            revised_net_pay=net_payable,
            notes=f"Calculated monthly payroll for {month:02d}/{year} via {policy.policy_name}."
        )
        db.add(audit)
        await db.flush()

        return payroll_rec

    @classmethod
    async def check_attendance_correction_impact(
        cls,
        db: AsyncSession,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        teacher_id: uuid.UUID,
        correction_date: date,
        new_status: str
    ) -> PayrollImpactAlertResponse:
        """
        Detects if an attendance or leave change alters an existing approved or reviewed payroll.
        """
        month = correction_date.month
        year = correction_date.year

        # Fetch Teacher and existing payroll
        teacher = await db.get(Teacher, teacher_id)
        teacher_name = f"{teacher.first_name} {teacher.last_name or ''}".strip() if teacher else "Teacher"

        stmt = select(TeacherPayroll).where(
            TeacherPayroll.tenant_id == tenant_id,
            TeacherPayroll.school_id == school_id,
            TeacherPayroll.teacher_id == teacher_id,
            TeacherPayroll.month == month,
            TeacherPayroll.year == year,
            TeacherPayroll.deleted_at.is_(None)
        )
        payroll = (await db.execute(stmt)).scalars().first()

        if not payroll:
            return PayrollImpactAlertResponse(
                has_impact=False,
                affected_month=month,
                affected_year=year,
                teacher_name=teacher_name,
                previous_deduction=Decimal("0.00"),
                revised_deduction=Decimal("0.00"),
                delta_amount=Decimal("0.00"),
                explanation="No existing payroll calculation found for this period. No impact."
            )

        daily_rate = payroll.daily_rate
        prev_deduction = payroll.attendance_deductions
        
        # Estimate revised deduction
        # If corrected from UNPAID to APPROVED_LEAVE or PRESENT, deduction is reduced
        if new_status in ("PRESENT", "APPROVED_LEAVE"):
            delta = -daily_rate
        elif new_status == "HALF_DAY":
            delta = -(daily_rate * Decimal("0.50"))
        else:
            delta = Decimal("0.00")

        revised_deduction = max(Decimal("0.00"), prev_deduction + delta)
        delta_amount = revised_deduction - prev_deduction

        return PayrollImpactAlertResponse(
            has_impact=True,
            affected_month=month,
            affected_year=year,
            payroll_id=payroll.id,
            payroll_status=payroll.status,
            teacher_name=teacher_name,
            previous_deduction=prev_deduction,
            revised_deduction=revised_deduction,
            delta_amount=delta_amount,
            explanation=(
                f"⚠ Payroll Impact Detected: Modifying attendance for {correction_date.strftime('%d %b %Y')} "
                f"to {new_status} alters the {calendar.month_name[month]} {year} payroll. "
                f"Previous deduction: ₹{prev_deduction:,.2f}, Revised: ₹{revised_deduction:,.2f} "
                f"(Adjustment: ₹{abs(delta_amount):,.2f})."
            )
        )


def present_days_fmt(val: Decimal) -> str:
    if val % 1 == 0:
        return str(int(val))
    return f"{val:.1f}"
