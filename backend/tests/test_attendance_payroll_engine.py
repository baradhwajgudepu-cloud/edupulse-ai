import pytest
import uuid
from decimal import Decimal
from datetime import date, datetime, timezone
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.teacher import Teacher
from app.models.staff_attendance import StaffAttendance
from app.models.teacher_leave import TeacherLeave, LeaveType, LeaveStatus
from app.models.payroll import (
    PayrollPolicy, TeacherPayrollProfile, TeacherPayroll, PayrollStatus,
    PayrollCalculationBasis, DailyRateFormula
)
from app.models.staff_salary import StaffSalary
from app.main import app
from app.api.dependencies.auth import get_current_user
from tests.test_examinations import setup_exam_test_data


@pytest.mark.anyio
async def test_attendance_based_payroll_flow(
    client: AsyncClient, setup_exam_test_data, db_session: AsyncSession
) -> None:
    data = setup_exam_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id
    tenant_id = data["tenant_a"].id
    admin_user = data["user_admin"]
    teacher = data["teacher_a"]

    async def mock_admin():
        return admin_user

    app.dependency_overrides[get_current_user] = mock_admin

    try:
        # 1. Configure School Payroll Policy (Working-day basis)
        pol_payload = {
            "policy_name": "Senior Faculty Attendance Policy",
            "calculation_basis": "WORKING_DAYS",
            "standard_working_days": 24,
            "daily_rate_formula": "GROSS_DIVIDED_BY_WORKING_DAYS",
            "half_day_deduction_factor": "0.50",
            "unpaid_leave_deduction_factor": "1.00",
            "late_grace_count": 2,
            "late_deduction_factor": "0.25",
            "is_active": True
        }
        resp_pol = await client.post(f"/api/v1/payroll/policies?school_id={school_id}", json=pol_payload, headers=headers)
        assert resp_pol.status_code == 201, resp_pol.text
        policy_id = resp_pol.json()["data"]["id"]

        # 2. Configure Teacher Payroll Profile (Monthly Gross ₹48,000)
        prof_payload = {
            "teacher_id": str(teacher.id),
            "monthly_gross_salary": "48000.00",
            "basic_salary": "24000.00",
            "hra_allowance": "12000.00",
            "special_allowance": "12000.00",
            "provident_fund_deduction": "2880.00",
            "tax_deduction": "1000.00",
            "other_deductions": "0.00",
            "paid_leave_quota_per_year": 12,
            "bank_account_number": "SBIN00012345678",
            "bank_ifsc": "SBIN0001234",
            "bank_name": "State Bank of India",
            "effective_from": "2026-09-01",
            "is_active": True
        }
        resp_prof = await client.post(f"/api/v1/payroll/profiles?school_id={school_id}", json=prof_payload, headers=headers)
        assert resp_prof.status_code == 201, resp_prof.text

        # 3. Seed Attendance check-ins for September 2026
        # Teacher attended 15 days, 1 half-day, 1 approved leave
        for d in range(1, 16):
            dt = date(2026, 9, d)
            if dt.weekday() == 6:  # Sunday
                continue
            att = StaffAttendance(
                tenant_id=tenant_id,
                school_id=school_id,
                teacher_id=teacher.id,
                attendance_date=dt,
                check_in_time=datetime(2026, 9, d, 8, 45, 0, tzinfo=timezone.utc),
                check_in_latitude=17.3850,
                check_in_longitude=78.4867,
                check_in_distance_meters=15.0,
                check_out_time=datetime(2026, 9, d, 16, 30, 0, tzinfo=timezone.utc),
                check_out_latitude=17.3850,
                check_out_longitude=78.4867,
                check_out_distance_meters=15.0
            )
            db_session.add(att)

        # 1 Half-Day on Sep 16 (Duration < 5h)
        att_half = StaffAttendance(
            tenant_id=tenant_id,
            school_id=school_id,
            teacher_id=teacher.id,
            attendance_date=date(2026, 9, 16),
            check_in_time=datetime(2026, 9, 16, 8, 50, 0, tzinfo=timezone.utc),
            check_in_latitude=17.3850,
            check_in_longitude=78.4867,
            check_in_distance_meters=12.0,
            check_out_time=datetime(2026, 9, 16, 12, 30, 0, tzinfo=timezone.utc),
            check_out_latitude=17.3850,
            check_out_longitude=78.4867,
            check_out_distance_meters=12.0
        )
        db_session.add(att_half)

        # 1 Approved Leave on Sep 17
        leave = TeacherLeave(
            tenant_id=tenant_id,
            school_id=school_id,
            teacher_id=teacher.id,
            leave_type=LeaveType.CASUAL,
            start_date=date(2026, 9, 17),
            end_date=date(2026, 9, 17),
            reason="Family obligation",
            status=LeaveStatus.APPROVED,
            reviewed_by=admin_user.id
        )
        db_session.add(leave)
        await db_session.commit()

        # 4. POST Run Monthly Payroll Calculation for Sep 2026
        calc_payload = {
            "school_id": str(school_id),
            "month": 9,
            "year": 2026,
            "policy_id": policy_id,
            "teacher_ids": [str(teacher.id)]
        }
        resp_calc = await client.post("/api/v1/payroll/calculate", json=calc_payload, headers=headers)
        assert resp_calc.status_code == 200, resp_calc.text
        calc_res = resp_calc.json()["data"]
        assert calc_res["total_teachers"] == 1
        item = calc_res["items"][0]

        # Verify daily rate: 48,000 / working_days (~26 working days in Sep 2026)
        assert Decimal(str(item["gross_salary"])) == Decimal("48000.00")
        assert Decimal(str(item["daily_rate"])) > Decimal("0.00")
        assert item["half_days"] == 1
        assert Decimal(str(item["approved_leave_days"])) >= Decimal("1.00")
        assert item["status"] == "DRAFT"
        assert "AI Payroll Insight" in item["ai_explanation"]

        payroll_id = item["id"]

        # 5. POST Approve Payroll
        resp_appr = await client.post(f"/api/v1/payroll/{payroll_id}/approve", headers=headers)
        assert resp_appr.status_code == 200, resp_appr.text
        approved_item = resp_appr.json()["data"]
        assert approved_item["status"] == "APPROVED"
        assert approved_item["approved_by_name"] is not None

        # Verify legacy StaffSalary synchronization
        stmt_sal = select(StaffSalary).where(
            StaffSalary.school_id == school_id,
            StaffSalary.staff_id == teacher.id,
            StaffSalary.month == 9,
            StaffSalary.year == 2026
        )
        sync_sal = (await db_session.execute(stmt_sal)).scalars().first()
        assert sync_sal is not None
        assert sync_sal.base_salary == Decimal("48000.00")
        assert sync_sal.net_salary == Decimal(str(approved_item["net_payable"]))

        # 6. GET Audit Logs
        resp_audit = await client.get(f"/api/v1/payroll/{payroll_id}/audit", headers=headers)
        assert resp_audit.status_code == 200, resp_audit.text
        audits = resp_audit.json()["data"]
        assert len(audits) >= 2
        actions = {a["action"] for a in audits}
        assert "CALCULATED" in actions
        assert "APPROVED" in actions

        # 7. GET Retroactive Attendance Correction Check
        resp_corr = await client.get(
            f"/api/v1/payroll/attendance-correction-check?school_id={school_id}&teacher_id={teacher.id}&correction_date=2026-09-18&new_status=PRESENT",
            headers=headers
        )
        assert resp_corr.status_code == 200, resp_corr.text
        corr = resp_corr.json()["data"]
        assert corr["has_impact"] is True
        assert corr["payroll_status"] == "APPROVED"
        assert "Payroll Impact Detected" in corr["explanation"]

    finally:
        app.dependency_overrides.pop(get_current_user, None)
