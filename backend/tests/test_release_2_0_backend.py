import uuid
from decimal import Decimal
from datetime import date
import pytest
from pydantic import ValidationError

from app.models.teacher import StaffType
from app.models.staff_salary import SalaryStatus, SalaryPaymentMethod
from app.models.expense import ExpenseCategory
from app.schemas.room import RoomCreate, RoomUpdate, RoomResponse
from app.schemas.staff_salary import StaffSalaryCreate, StaffSalaryPayRequest
from app.schemas.expense import ExpenseCreate, ExpenseSummaryResponse
from app.services.payment_provider import (
    OfflineMockPaymentProvider,
    assert_online_payments_enabled,
    get_payment_provider
)
from app.models.school import School

def test_room_schemas_validation():
    school_id = uuid.uuid4()
    # Valid room create
    room_in = RoomCreate(
        school_id=school_id,
        room_number="101",
        name="Physics Lab",
        room_type="LAB",
        capacity=35,
        floor="1st Floor",
        building="Main Block"
    )
    assert room_in.room_number == "101"
    assert room_in.capacity == 35

    # Invalid room capacity <= 0
    with pytest.raises(ValidationError):
        RoomCreate(
            school_id=school_id,
            room_number="102",
            name="Chemistry Lab",
            capacity=0
        )

def test_staff_type_enum():
    assert StaffType.TEACHING == "TEACHING"
    assert StaffType.NON_TEACHING == "NON_TEACHING"

def test_staff_salary_schemas():
    staff_id = uuid.uuid4()
    school_id = uuid.uuid4()

    req = StaffSalaryCreate(
        school_id=school_id,
        staff_id=staff_id,
        month=9,
        year=2026,
        base_salary=Decimal("50000.00"),
        allowances=Decimal("5000.00"),
        deductions=Decimal("2000.00"),
        remarks="September Salary"
    )
    assert req.base_salary == Decimal("50000.00")

    # Invalid month
    with pytest.raises(ValidationError):
        StaffSalaryCreate(
            school_id=school_id,
            staff_id=staff_id,
            month=13,
            year=2026,
            base_salary=Decimal("50000.00")
        )

def test_expense_schemas():
    school_id = uuid.uuid4()
    exp = ExpenseCreate(
        school_id=school_id,
        category=ExpenseCategory.INFRASTRUCTURE,
        amount=Decimal("15000.00"),
        expense_date=date(2026, 9, 20),
        description="Air Conditioning maintenance",
        paid_to="CoolAir Services",
        payment_method="BANK_TRANSFER"
    )
    assert exp.amount == Decimal("15000.00")
    assert exp.category == ExpenseCategory.INFRASTRUCTURE

    # Invalid amount <= 0
    with pytest.raises(ValidationError):
        ExpenseCreate(
            school_id=school_id,
            category=ExpenseCategory.OPERATIONS,
            amount=Decimal("-50.00"),
            expense_date=date(2026, 9, 20),
            description="Negative amount",
            paid_to="Vendor"
        )

import asyncio

def test_payment_provider_disabled_by_default():
    school = School(
        id=uuid.uuid4(),
        tenant_id=uuid.uuid4(),
        name="Greenwood High School",
        code="GW01",
        settings={}  # online_fee_payment_enabled is not set or false
    )

    with pytest.raises(Exception) as exc_info:
        assert_online_payments_enabled(school)
    assert "Online payments are currently unavailable" in str(exc_info.value)

    # When explicitly enabled
    school.settings = {"online_fee_payment_enabled": True}
    assert_online_payments_enabled(school)
    provider = get_payment_provider(school)
    assert isinstance(provider, OfflineMockPaymentProvider)

    async def _test():
        order = await provider.create_order(
            amount=Decimal("10000.00"),
            currency="INR",
            student_id=uuid.uuid4(),
            school_id=school.id
        )
        assert order.amount == Decimal("10000.00")
        assert order.gateway_name == "OFFLINE_MOCK"

    asyncio.run(_test())

