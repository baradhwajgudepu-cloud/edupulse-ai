import uuid
import pytest
from datetime import date, datetime, timezone, timedelta
from decimal import Decimal
from httpx import AsyncClient
from sqlalchemy import select, text
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tenant import Tenant
from app.models.school import School
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.class_entity import Class
from app.models.section import Section
from app.models.student import Student, StudentGender
from app.models.user import User, UserStatus
from app.models.role import Role, user_roles
from app.models.permission import Permission
from app.models.fee import (
    FeeType, Scholarship, FeeStructure, FineRule,
    StudentFeeAssignment, FeePayment, FeePaymentAllocation, FeeReceipt,
    ConcessionType, PaymentMethod, PaymentStatus, FeeAssignmentStatus, FineType
)
from app.core.security import create_access_token
from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.student import StudentRepository
from app.repositories.auth import UserRepository, RoleRepository

@pytest.fixture
async def setup_fee_test_data(db_session: AsyncSession):
    suffix = uuid.uuid4().hex[:6].lower()

    # 1. Tenant & School
    tenant = Tenant(name="Fee Tenant", code=f"fee-tenant-{suffix}", subdomain=f"fee-sub-{suffix}", email=f"fee-{suffix}@t.com")
    db_session.add(tenant)
    await db_session.flush()

    school = School(tenant_id=tenant.id, name="Fee School", code=f"fee-sch-{suffix}", email=f"fee-sch-{suffix}@t.com", address="Sch Address", board="CBSE")
    db_session.add(school)
    await db_session.flush()

    # 2. Academic Year, Class, Section & Student
    ay = AcademicYear(tenant_id=tenant.id, school_id=school.id, name="AY 2026", code=f"AY26-{suffix}", start_date=date(2026, 1, 1), end_date=date(2026, 12, 31), status=AcademicYearStatus.ACTIVE)
    db_session.add(ay)
    await db_session.flush()

    cl = Class(tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id, name="Grade 1", code=f"G1-{suffix}", level=1, capacity=40)
    db_session.add(cl)
    await db_session.flush()

    sec = Section(tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id, class_id=cl.id, name="Section A", code=f"SEC-A-{suffix}", capacity=40)
    db_session.add(sec)
    await db_session.flush()

    student = Student(tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id, class_id=cl.id, section_id=sec.id, first_name="Ravi", last_name="Kumar", roll_number=f"101-{suffix}", admission_number=f"ADM-{suffix}", admission_date=date(2026, 1, 1), date_of_birth=date(2015, 5, 5), gender=StudentGender.MALE)
    db_session.add(student)
    await db_session.flush()

    # 3. Roles and Permissions
    # Fetch roles seeded in the DB
    stmt_roles = select(Role).where(Role.tenant_id == tenant.id, Role.deleted_at.is_(None))
    res_roles = await db_session.execute(stmt_roles)
    roles_list = list(res_roles.scalars().all())
    
    # If roles are not found (SQLite/Testing environment may not seed standard migrations sometimes), create them:
    super_admin_role = next((r for r in roles_list if r.code.upper() == 'SUPER_ADMIN'), None)
    if not super_admin_role:
        super_admin_role = Role(tenant_id=tenant.id, name="Super Admin", code="SUPER_ADMIN")
        db_session.add(super_admin_role)
        await db_session.flush()

    teacher_role = next((r for r in roles_list if r.code.upper() == 'TEACHER'), None)
    if not teacher_role:
        teacher_role = Role(tenant_id=tenant.id, name="Teacher", code="TEACHER")
        db_session.add(teacher_role)
        await db_session.flush()

    # Fetch/Map Permissions
    stmt_perms = select(Permission).where(Permission.code.like("fee.%"))
    res_perms = await db_session.execute(stmt_perms)
    fee_perms = list(res_perms.scalars().all())

    # Map permissions to super admin
    for perm in fee_perms:
        await db_session.execute(
            text("INSERT INTO role_permissions (role_id, permission_id) VALUES (:r, :p) ON CONFLICT DO NOTHING"),
            {"r": super_admin_role.id, "p": perm.id}
        )
    # Map read permission only to teacher
    read_perm = next((p for p in fee_perms if p.code == "fee.read"), None)
    if read_perm:
        await db_session.execute(
            text("INSERT INTO role_permissions (role_id, permission_id) VALUES (:r, :p) ON CONFLICT DO NOTHING"),
            {"r": teacher_role.id, "p": read_perm.id}
        )

    # 4. Users & Authentication
    # Admin User
    admin_user = User(tenant_id=tenant.id, email=f"admin-{suffix}@edupulse.com", first_name="Admin", last_name="User", hashed_password="hashed_pwd", is_superuser=True, status=UserStatus.ACTIVE)
    db_session.add(admin_user)
    await db_session.flush()
    # Link role
    await db_session.execute(
        user_roles.insert().values(user_id=admin_user.id, role_id=super_admin_role.id)
    )

    # Teacher User
    teacher_user = User(tenant_id=tenant.id, email=f"teacher-{suffix}@edupulse.com", first_name="Teacher", last_name="User", hashed_password="hashed_pwd", is_superuser=False, status=UserStatus.ACTIVE)
    db_session.add(teacher_user)
    await db_session.flush()
    # Link role
    await db_session.execute(
        user_roles.insert().values(user_id=teacher_user.id, role_id=teacher_role.id)
    )

    # 5. Create headers
    admin_token = create_access_token(subject=admin_user.id, tenant_id=tenant.id)
    teacher_token = create_access_token(subject=teacher_user.id, tenant_id=tenant.id)
    
    admin_headers = {"Authorization": f"Bearer {admin_token}", "X-Tenant-ID": str(tenant.id), "X-School-ID": str(school.id)}
    teacher_headers = {"Authorization": f"Bearer {teacher_token}", "X-Tenant-ID": str(tenant.id), "X-School-ID": str(school.id)}

    await db_session.commit()

    return {
        "tenant": tenant,
        "school": school,
        "academic_year": ay,
        "class": cl,
        "student": student,
        "admin_headers": admin_headers,
        "teacher_headers": teacher_headers
    }


@pytest.mark.anyio
async def test_fee_type_crud(client: AsyncClient, setup_fee_test_data: dict):
    headers = setup_fee_test_data["admin_headers"]
    
    # 1. Create
    payload = {
        "name": "Tuition Fee",
        "code": "TUIT",
        "description": "Quarterly Tuition Fees",
        "is_system": False
    }
    response = await client.post("/api/v1/fees/types", json=payload, headers=headers)
    assert response.status_code == 201
    data = response.json()["data"]
    assert data["name"] == "Tuition Fee"
    fee_type_id = data["id"]

    # 2. Get Details
    response = await client.get(f"/api/v1/fees/types/{fee_type_id}", headers=headers)
    assert response.status_code == 200
    assert response.json()["data"]["code"] == "TUIT"

    # 3. Update
    update_payload = {"name": "Updated Tuition Fee"}
    response = await client.put(f"/api/v1/fees/types/{fee_type_id}", json=update_payload, headers=headers)
    assert response.status_code == 200
    assert response.json()["data"]["name"] == "Updated Tuition Fee"

    # 4. List
    response = await client.get("/api/v1/fees/types", headers=headers)
    assert response.status_code == 200
    assert len(response.json()["data"]) >= 1

    # 5. Delete
    response = await client.delete(f"/api/v1/fees/types/{fee_type_id}", headers=headers)
    assert response.status_code == 200


@pytest.mark.anyio
async def test_fee_type_validation(client: AsyncClient, setup_fee_test_data: dict):
    headers = setup_fee_test_data["admin_headers"]

    # 1. Test empty string name
    payload_empty_name = {
        "name": "",
        "code": "VALIDCODE"
    }
    response = await client.post("/api/v1/fees/types", json=payload_empty_name, headers=headers)
    assert response.status_code == 422
    assert "name" in str(response.json())

    # 2. Test only spaces code
    payload_spaces_code = {
        "name": "Valid Name",
        "code": "   "
    }
    response = await client.post("/api/v1/fees/types", json=payload_spaces_code, headers=headers)
    assert response.status_code == 422
    assert "code" in str(response.json())

    # 3. Test missing field name
    payload_missing_name = {
        "code": "VALIDCODE"
    }
    response = await client.post("/api/v1/fees/types", json=payload_missing_name, headers=headers)
    assert response.status_code == 422
    assert "name" in str(response.json())

    # 4. Test max length exceeded for name (101 chars)
    payload_long_name = {
        "name": "a" * 101,
        "code": "VALIDCODE"
    }
    response = await client.post("/api/v1/fees/types", json=payload_long_name, headers=headers)
    assert response.status_code == 422
    assert "name" in str(response.json())

    # 5. Test max length exceeded for code (51 chars)
    payload_long_code = {
        "name": "Valid Name",
        "code": "c" * 51
    }
    response = await client.post("/api/v1/fees/types", json=payload_long_code, headers=headers)
    assert response.status_code == 422
    assert "code" in str(response.json())

    # 6. Test max length exceeded for description (501 chars)
    payload_long_desc = {
        "name": "Valid Name",
        "code": "VALIDCODE",
        "description": "d" * 501
    }
    response = await client.post("/api/v1/fees/types", json=payload_long_desc, headers=headers)
    assert response.status_code == 422
    assert "description" in str(response.json())


@pytest.mark.anyio
async def test_fee_structure_and_assignment(client: AsyncClient, setup_fee_test_data: dict, db_session: AsyncSession):
    headers = setup_fee_test_data["admin_headers"]
    tenant = setup_fee_test_data["tenant"]
    ay = setup_fee_test_data["academic_year"]
    cl = setup_fee_test_data["class"]
    student = setup_fee_test_data["student"]

    # 1. Create Fee Type first
    fee_type = FeeType(tenant_id=tenant.id, name="Library Fee", code="LIB", description="Library access fee")
    db_session.add(fee_type)
    await db_session.commit()

    # 2. Create Fee Structure with Fine Rule
    payload = {
        "fee_type_id": str(fee_type.id),
        "academic_year_id": str(ay.id),
        "class_id": str(cl.id),
        "amount": 2500.0,
        "due_date": date.today().isoformat(),
        "description": "Yearly library fee structure",
        "fine_rule": {
            "grace_period_days": 5,
            "fine_type": "FIXED",
            "fine_value": 200.0
        }
    }
    response = await client.post("/api/v1/fees/structures", json=payload, headers=headers)
    assert response.status_code == 201
    data = response.json()["data"]
    assert data["amount"] == 2500.0
    assert data["fine_rule"]["fine_value"] == 200.0
    fee_structure_id = data["id"]

    # 3. Create Scholarship
    scholarship = Scholarship(tenant_id=tenant.id, school_id=cl.school_id, name="Academic Concession", concession_type=ConcessionType.PERCENTAGE, value=Decimal("20.00"), description="20% off")
    db_session.add(scholarship)
    await db_session.commit()

    # 4. Assign Fee to Student
    assign_payload = {
        "student_id": str(student.id),
        "fee_structure_id": str(fee_structure_id),
        "scholarship_id": str(scholarship.id)
    }
    response = await client.post("/api/v1/fees/assign", json=assign_payload, headers=headers)
    assert response.status_code == 201
    assign_data = response.json()["data"]
    
    # 20% discount on 2500.0 = 500.0
    assert assign_data["discount_amount"] == 500.0
    assert assign_data["assigned_amount"] == 2500.0
    assert assign_data["status"] == "UNPAID"


@pytest.mark.anyio
async def test_collect_payment_overpayment_reversal_ledger(client: AsyncClient, setup_fee_test_data: dict, db_session: AsyncSession):
    headers = setup_fee_test_data["admin_headers"]
    tenant = setup_fee_test_data["tenant"]
    ay = setup_fee_test_data["academic_year"]
    cl = setup_fee_test_data["class"]
    student = setup_fee_test_data["student"]

    # 1. Setup Type & Structure & Assignment
    fee_type = FeeType(tenant_id=tenant.id, name="Exam Fee", code="EXAM", description="Yearly exams fee")
    db_session.add(fee_type)
    await db_session.flush()

    structure = FeeStructure(
        tenant_id=tenant.id, school_id=setup_fee_test_data["school"].id, fee_type_id=fee_type.id,
        academic_year_id=ay.id, class_id=cl.id, amount=Decimal("1000.00"), due_date=date.today()
    )
    db_session.add(structure)
    await db_session.flush()

    assignment = StudentFeeAssignment(
        tenant_id=tenant.id, student_id=student.id, fee_structure_id=structure.id,
        academic_year_id=ay.id, assigned_amount=Decimal("1000.00")
    )
    db_session.add(assignment)
    await db_session.commit()

    # 2. Test Overpayment Rejection
    # Attempting to allocate 1500 to a 1000 outstanding assignment
    payment_payload = {
        "student_id": str(student.id),
        "academic_year_id": str(ay.id),
        "payment_method": "CASH",
        "remarks": "Overpaid tuition test",
        "allocations": [
            {
                "assignment_id": str(assignment.id),
                "amount_allocated": 1500.0
            }
        ]
    }
    response = await client.post("/api/v1/fees/payments", json=payment_payload, headers=headers)
    assert response.status_code == 400
    assert "exceeds outstanding balance" in response.json()["message"]

    # 3. Test Successful Payment Collection (Partial Payment)
    payment_payload["allocations"][0]["amount_allocated"] = 600.0
    response = await client.post("/api/v1/fees/payments", json=payment_payload, headers=headers)
    assert response.status_code == 201
    pay_data = response.json()["data"]
    assert pay_data["amount_paid"] == 600.0
    assert pay_data["status"] == "COMPLETED"
    payment_id = pay_data["id"]

    # Verify student ledger
    response = await client.get(f"/api/v1/fees/ledgers/{student.id}", headers=headers)
    assert response.status_code == 200
    ledger_data = response.json()["data"]
    assert ledger_data["closing_balance"] == 400.0  # 1000 - 600
    assert len(ledger_data["payments"]) == 1

    # 4. Download PDF Receipt
    # Fetch receipt details
    receipt_stmt = select(FeeReceipt).where(FeeReceipt.payment_id == uuid.UUID(payment_id))
    receipt_res = await db_session.execute(receipt_stmt)
    receipt = receipt_res.scalar_one()
    
    # Assert pdf_path is stored and exists
    assert receipt.pdf_path is not None
    import os
    assert os.path.exists(receipt.pdf_path)
    
    response = await client.get(f"/api/v1/fees/receipts/{receipt.receipt_number}/download", headers=headers)
    assert response.status_code == 200
    assert response.headers["content-type"] == "application/pdf"
    assert response.content.startswith(b"%PDF")

    # Assert downloading a non-existent receipt number returns 404
    response_404 = await client.get("/api/v1/fees/receipts/RCPT-999-999999/download", headers=headers)
    assert response_404.status_code == 404

    # 5. Cancel / Reverse Payment
    cancel_payload = {"cancel_reason": "Bounced check / incorrect entry"}
    response = await client.put(f"/api/v1/fees/payments/{payment_id}/cancel", json=cancel_payload, headers=headers)
    assert response.status_code == 200
    assert response.json()["data"]["status"] == "CANCELLED"

    # Verify ledger is restored
    response = await client.get(f"/api/v1/fees/ledgers/{student.id}", headers=headers)
    assert response.status_code == 200
    assert response.json()["data"]["closing_balance"] == 1000.0  # restored to 1000


@pytest.mark.anyio
async def test_dashboard_and_ai_metrics(client: AsyncClient, setup_fee_test_data: dict, db_session: AsyncSession):
    headers = setup_fee_test_data["admin_headers"]
    student = setup_fee_test_data["student"]

    # 1. Dashboard Metrics
    response = await client.get("/api/v1/fees/reports/dashboard", headers=headers)
    assert response.status_code == 200
    assert "today_collection" in response.json()["data"]
    assert "top_outstanding_classes" in response.json()["data"]

    # 2. AI Default Risk Score
    response = await client.get(f"/api/v1/fees/ai/default-risk/{student.id}", headers=headers)
    assert response.status_code == 200
    assert "default_risk_probability" in response.json()["data"]
    assert "risk_level" in response.json()["data"]

    # 3. AI Predictive Analytics
    response = await client.get("/api/v1/fees/ai/analytics", headers=headers)
    assert response.status_code == 200
    assert "predicted_collection_next_30_days" in response.json()["data"]


@pytest.mark.anyio
async def test_fee_rbac_security(client: AsyncClient, setup_fee_test_data: dict):
    # Teacher only has 'fee.read' permission, should NOT be allowed to create fee types
    teacher_headers = setup_fee_test_data["teacher_headers"]
    payload = {
        "name": "Tuition Fee Unauthorized Test",
        "code": "TUITUNAUTH",
        "description": "Quarterly Tuition Fees Test",
        "is_system": False
    }
    response = await client.post("/api/v1/fees/types", json=payload, headers=teacher_headers)
    assert response.status_code == 403
    assert "Access denied" in response.json()["message"]


@pytest.mark.anyio
async def test_fee_tenant_isolation(client: AsyncClient, setup_fee_test_data: dict, db_session: AsyncSession):
    # Create tenant B
    suffix = uuid.uuid4().hex[:6].lower()
    tenant_b = Tenant(name="Tenant B Isolation", code=f"tb-iso-{suffix}", subdomain=f"tb-iso-{suffix}", email=f"b-{suffix}@t.com")
    db_session.add(tenant_b)
    await db_session.flush()

    user_b = User(tenant_id=tenant_b.id, email=f"user-b-{suffix}@edupulse.com", first_name="User", last_name="B", hashed_password="hashed_pwd", is_superuser=True, status=UserStatus.ACTIVE)
    db_session.add(user_b)
    await db_session.commit()

    token_b = create_access_token(subject=user_b.id, tenant_id=tenant_b.id)
    headers_b = {"Authorization": f"Bearer {token_b}", "X-Tenant-ID": str(tenant_b.id)}

    # Create fee type under Tenant A
    admin_headers_a = setup_fee_test_data["admin_headers"]
    payload = {
        "name": "Tenant A Fee",
        "code": "TAFEE",
        "description": "Fee under Tenant A",
        "is_system": False
    }
    response = await client.post("/api/v1/fees/types", json=payload, headers=admin_headers_a)
    assert response.status_code == 201
    fee_type_id = response.json()["data"]["id"]

    # Tenant B tries to query Tenant A's fee type -> should return 404 Not Found due to tenant boundaries
    response = await client.get(f"/api/v1/fees/types/{fee_type_id}", headers=headers_b)
    assert response.status_code == 404


@pytest.mark.anyio
async def test_scholarship_validation_and_uniqueness(client: AsyncClient, setup_fee_test_data: dict, db_session: AsyncSession):
    headers = setup_fee_test_data["admin_headers"]

    # 1. Create a valid scholarship first
    payload_valid = {
        "name": "Merit Scholarship",
        "concession_type": "PERCENTAGE",
        "value": 50.0,
        "description": "50% off for meritorious students"
    }
    response = await client.post("/api/v1/fees/scholarships", json=payload_valid, headers=headers)
    assert response.status_code == 201
    valid_id = response.json()["data"]["id"]

    # 2. Test empty string name -> HTTP 422
    payload_empty_name = {
        "name": "",
        "concession_type": "PERCENTAGE",
        "value": 20.0
    }
    response = await client.post("/api/v1/fees/scholarships", json=payload_empty_name, headers=headers)
    assert response.status_code == 422

    # 3. Test whitespace only name -> HTTP 422
    payload_spaces_name = {
        "name": "    ",
        "concession_type": "PERCENTAGE",
        "value": 20.0
    }
    response = await client.post("/api/v1/fees/scholarships", json=payload_spaces_name, headers=headers)
    assert response.status_code == 422

    # 4. Test duplicate name -> HTTP 409
    response = await client.post("/api/v1/fees/scholarships", json=payload_valid, headers=headers)
    assert response.status_code == 409
    assert "already exists" in response.json()["message"]

    # 5. Test duplicate name with different case -> HTTP 409
    payload_diff_case = {
        "name": "mErIt ScHoLaRsHiP",
        "concession_type": "FIXED",
        "value": 500.0
    }
    response = await client.post("/api/v1/fees/scholarships", json=payload_diff_case, headers=headers)
    assert response.status_code == 409
    assert "already exists" in response.json()["message"]

    # 6. Test negative value -> HTTP 422
    payload_neg = {
        "name": "Negative Scholarship",
        "concession_type": "FIXED",
        "value": -10.0
    }
    response = await client.post("/api/v1/fees/scholarships", json=payload_neg, headers=headers)
    assert response.status_code == 422

    # 7. Test percentage > 100 -> HTTP 422
    payload_pct_high = {
        "name": "Huge Scholarship",
        "concession_type": "PERCENTAGE",
        "value": 105.0
    }
    response = await client.post("/api/v1/fees/scholarships", json=payload_pct_high, headers=headers)
    assert response.status_code == 422

    # 8. Test percentage = 0 -> HTTP 422
    payload_pct_zero = {
        "name": "Zero Scholarship",
        "concession_type": "PERCENTAGE",
        "value": 0.0
    }
    response = await client.post("/api/v1/fees/scholarships", json=payload_pct_zero, headers=headers)
    assert response.status_code == 422

    # 9. Test fixed amount = 0 -> HTTP 422
    payload_fixed_zero = {
        "name": "Zero Fixed Scholarship",
        "concession_type": "FIXED",
        "value": 0.0
    }
    response = await client.post("/api/v1/fees/scholarships", json=payload_fixed_zero, headers=headers)
    assert response.status_code == 422

    # 10. Create another valid scholarship to test update duplicate name
    payload_another = {
        "name": "Sports Scholarship",
        "concession_type": "FIXED",
        "value": 1000.0
    }
    response = await client.post("/api/v1/fees/scholarships", json=payload_another, headers=headers)
    assert response.status_code == 201
    another_id = response.json()["data"]["id"]

    # 11. Test update to duplicate name -> HTTP 409
    payload_update_dup = {
        "name": "MERIT scholarship"
    }
    response = await client.put(f"/api/v1/fees/scholarships/{another_id}", json=payload_update_dup, headers=headers)
    assert response.status_code == 409
    assert "already exists" in response.json()["message"]

    # 12. Test update value to invalid percentage -> HTTP 422
    payload_update_invalid_val = {
        "value": 150.0
    }
    response = await client.put(f"/api/v1/fees/scholarships/{valid_id}", json=payload_update_invalid_val, headers=headers)
    assert response.status_code == 422

    # 13. Test database-level uniqueness constraint
    from app.models.fee import Scholarship, ConcessionType
    from sqlalchemy.exc import IntegrityError
    
    dup_db = Scholarship(
        tenant_id=setup_fee_test_data["tenant"].id,
        school_id=setup_fee_test_data["school"].id,
        name="merit scholarship",
        concession_type=ConcessionType.PERCENTAGE,
        value=Decimal("30.00")
    )
    db_session.add(dup_db)
    with pytest.raises(IntegrityError):
        await db_session.commit()
    await db_session.rollback()


@pytest.mark.anyio
async def test_fee_structure_uniqueness_and_atomicity(client: AsyncClient, setup_fee_test_data: dict, db_session: AsyncSession, monkeypatch):
    headers = setup_fee_test_data["admin_headers"]
    tenant_id = setup_fee_test_data["tenant"].id
    school_id = setup_fee_test_data["school"].id
    ay_id = setup_fee_test_data["academic_year"].id
    cl_id = setup_fee_test_data["class"].id

    # 1. Create a Fee Type
    fee_type = FeeType(tenant_id=tenant_id, name="Tuition Fee Uniq", code="TUNIQ")
    db_session.add(fee_type)
    await db_session.flush()
    fee_type_id = fee_type.id
    await db_session.commit()

    # 2. Create first Fee Structure
    payload = {
        "fee_type_id": str(fee_type_id),
        "academic_year_id": str(ay_id),
        "class_id": str(cl_id),
        "amount": 5000.0,
        "due_date": date.today().isoformat()
    }
    response = await client.post("/api/v1/fees/structures", json=payload, headers=headers)
    assert response.status_code == 201
    struct_id = response.json()["data"]["id"]

    # 3. Create duplicate Fee Structure -> HTTP 409
    response = await client.post("/api/v1/fees/structures", json=payload, headers=headers)
    assert response.status_code == 409
    assert "already exists" in response.json()["message"]

    # 4. Test database-level unique index enforcement (Regression check)
    from sqlalchemy.exc import IntegrityError
    dup_db = FeeStructure(
        tenant_id=tenant_id,
        school_id=school_id,
        fee_type_id=fee_type_id,
        academic_year_id=ay_id,
        class_id=cl_id,
        amount=Decimal("6000.00"),
        due_date=date.today()
    )
    db_session.add(dup_db)
    with pytest.raises(IntegrityError):
        await db_session.commit()
    await db_session.rollback()

    # 5. Test Atomicity: If fine rule creation fails, the structure insert must rollback
    # Create another fee type to avoid combination conflict
    fee_type_atomic = FeeType(tenant_id=tenant_id, name="Atomic Fee", code="ATOM")
    db_session.add(fee_type_atomic)
    await db_session.flush()
    fee_type_atomic_id = fee_type_atomic.id
    await db_session.commit()

    # Mock create_fine_rule to raise an error
    from app.repositories.fee import FeeRepository
    async def mock_create_fine_rule(*args, **kwargs):
        raise ValueError("Simulated database failure during fine rule insertion")
    monkeypatch.setattr(FeeRepository, "create_fine_rule", mock_create_fine_rule)

    payload_atomic = {
        "fee_type_id": str(fee_type_atomic_id),
        "academic_year_id": str(ay_id),
        "class_id": str(cl_id),
        "amount": 4000.0,
        "due_date": date.today().isoformat(),
        "fine_rule": {
            "grace_period_days": 3,
            "fine_type": "FIXED",
            "fine_value": 150.0
        }
    }
    # This should raise ValueError due to simulated database failure in nested rule insertion
    with pytest.raises(ValueError, match="Simulated database failure"):
        await client.post("/api/v1/fees/structures", json=payload_atomic, headers=headers)

    # Verify that the structure was NOT created (rolled back)
    # We clear the session to query fresh DB state
    db_session.expire_all()
    stmt = select(FeeStructure).where(
        FeeStructure.fee_type_id == fee_type_atomic_id,
        FeeStructure.deleted_at.is_(None)
    )
    res = await db_session.execute(stmt)
    assert res.scalar_one_or_none() is None


@pytest.mark.anyio
async def test_payment_import_success_and_failures(client: AsyncClient, setup_fee_test_data: dict, db_session: AsyncSession):
    headers = setup_fee_test_data["admin_headers"]
    tenant = setup_fee_test_data["tenant"]
    ay = setup_fee_test_data["academic_year"]
    cl = setup_fee_test_data["class"]
    student = setup_fee_test_data["student"]

    # 1. Cache DB properties early to prevent MissingGreenlet after commits
    student_id = student.id
    admission_number = student.admission_number
    ay_id = ay.id
    cl_id = cl.id
    school_id = cl.school_id

    # 1. Create a fee type, structure, and assignment
    fee_type = FeeType(tenant_id=tenant.id, name="Activity Fee", code="ACT")
    db_session.add(fee_type)
    await db_session.commit()

    struct = FeeStructure(
        tenant_id=tenant.id, school_id=school_id, fee_type_id=fee_type.id,
        academic_year_id=ay_id, class_id=cl_id, amount=Decimal("3000.00"), due_date=date.today()
    )
    db_session.add(struct)
    await db_session.commit()

    assign = StudentFeeAssignment(
        tenant_id=tenant.id, student_id=student_id, fee_structure_id=struct.id,
        academic_year_id=ay_id, assigned_amount=Decimal("3000.00")
    )
    db_session.add(assign)
    await db_session.commit()

    # 2. Test successful import row
    payload = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "payments": [
            {
                "admission_number": admission_number,
                "fee_type_code": "ACT",
                "amount": 2000.0,
                "payment_date": date.today().isoformat(),
                "payment_method": "CASH",
                "reference_number": "REF-123"
            },
            {
                "admission_number": "INVALID-ADM", # Invalid student
                "fee_type_code": "ACT",
                "amount": 500.0,
                "payment_date": date.today().isoformat(),
                "payment_method": "CASH"
            },
            {
                "admission_number": admission_number,
                "fee_type_code": "INVALID-CODE", # Invalid assignment
                "amount": 500.0,
                "payment_date": date.today().isoformat(),
                "payment_method": "CASH"
            },
            {
                "admission_number": admission_number,
                "fee_type_code": "ACT",
                "amount": 2000.0, # Duplicate/Overpayment (2000 already paid, outstanding is 1000, trying to pay 2000)
                "payment_date": date.today().isoformat(),
                "payment_method": "CASH"
            }
        ]
    }

    response = await client.post("/api/v1/fees/payments/import", json=payload, headers=headers)
    assert response.status_code == 200
    data = response.json()["data"]
    
    assert data["total_processed"] == 4
    assert data["success_count"] == 1
    assert data["failed_count"] == 3
    
    results = data["results"]
    # Row 0: Success
    assert results[0]["success"] is True
    assert results[0]["payment_id"] is not None
    
    # Row 1: Invalid student
    assert results[1]["success"] is False
    assert "not found" in results[1]["error"]
    
    # Row 2: Invalid assignment
    assert results[2]["success"] is False
    assert "not found" in results[2]["error"]
    
    # Row 3: Overpayment
    assert results[3]["success"] is False
    assert "exceeds outstanding balance" in results[3]["error"]

    # 3. Verify ledger is updated correctly
    response = await client.get(f"/api/v1/fees/ledgers/{student_id}", headers=headers)
    assert response.status_code == 200
    ledger = response.json()["data"]
    assert ledger["closing_balance"] == 1000.0 # 3000 original - 2000 paid

    # 4. Test school isolation (payment from another school)
    other_school_id = uuid.uuid4()
    payload_school_iso = {
        "school_id": str(other_school_id),
        "academic_year_id": str(ay_id),
        "payments": [
            {
                "admission_number": admission_number,
                "fee_type_code": "ACT",
                "amount": 500.0,
                "payment_date": date.today().isoformat(),
                "payment_method": "CASH"
            }
        ]
    }
    response = await client.post("/api/v1/fees/payments/import", json=payload_school_iso, headers=headers)
    assert response.status_code == 200
    assert response.json()["data"]["failed_count"] == 1
    assert "not found" in response.json()["data"]["results"][0]["error"]


@pytest.mark.anyio
async def test_get_outstanding_report(client: AsyncClient, setup_fee_test_data: dict, db_session: AsyncSession):
    headers = setup_fee_test_data["admin_headers"]
    tenant = setup_fee_test_data["tenant"]
    ay = setup_fee_test_data["academic_year"]
    cl = setup_fee_test_data["class"]
    student = setup_fee_test_data["student"]

    # Cache properties early
    student_id = student.id
    school_id = cl.school_id
    class_id = cl.id

    # 1. Create a fee type, structure, and assignment (due date in the past, so it's a defaulter)
    fee_type = FeeType(tenant_id=tenant.id, name="Activity Fee", code="ACT")
    db_session.add(fee_type)
    await db_session.commit()

    struct = FeeStructure(
        tenant_id=tenant.id, school_id=school_id, fee_type_id=fee_type.id,
        academic_year_id=ay.id, class_id=class_id, amount=Decimal("3000.00"), due_date=date(2026, 1, 1)
    )
    db_session.add(struct)
    await db_session.commit()

    assign = StudentFeeAssignment(
        tenant_id=tenant.id, student_id=student_id, fee_structure_id=struct.id,
        academic_year_id=ay.id, assigned_amount=Decimal("3000.00"), status=FeeAssignmentStatus.UNPAID
    )
    db_session.add(assign)
    await db_session.commit()

    # 2. Test fetching outstanding dues report (No filter)
    response = await client.get(f"/api/v1/fees/reports/outstanding?school_id={school_id}", headers=headers)
    assert response.status_code == 200
    data = response.json()["data"]
    assert len(data) >= 1
    
    # Verify report item content
    item = [x for x in data if x["student_id"] == str(student_id)][0]
    assert item["student_name"] == f"{student.first_name} {student.last_name}"
    assert item["class_id"] == str(class_id)
    assert item["outstanding_amount"] == 3000.0
    assert item["status"] == "UNPAID"

    # 3. Test Class filter
    response_class = await client.get(f"/api/v1/fees/reports/outstanding?school_id={school_id}&class_id={class_id}", headers=headers)
    assert response_class.status_code == 200
    assert len(response_class.json()["data"]) >= 1

    # Empty Class filter
    random_class_id = uuid.uuid4()
    response_class_empty = await client.get(f"/api/v1/fees/reports/outstanding?school_id={school_id}&class_id={random_class_id}", headers=headers)
    assert response_class_empty.status_code == 200
    assert len(response_class_empty.json()["data"]) == 0

    # 4. Test Defaulter filter (due date < today)
    response_def = await client.get(f"/api/v1/fees/reports/outstanding?school_id={school_id}&only_defaulters=true", headers=headers)
    assert response_def.status_code == 200
    assert len(response_def.json()["data"]) >= 1

    # 5. Exclude fully paid assignments
    assign.status = FeeAssignmentStatus.PAID
    assign.paid_amount = Decimal("3000.00")
    db_session.add(assign)
    await db_session.commit()

    response_paid = await client.get(f"/api/v1/fees/reports/outstanding?school_id={school_id}", headers=headers)
    assert response_paid.status_code == 200
    # Our student should be excluded now since outstanding is 0
    assert not any(x["student_id"] == str(student_id) for x in response_paid.json()["data"])

    # 6. School isolation
    other_school_id = uuid.uuid4()
    response_school_iso = await client.get(f"/api/v1/fees/reports/outstanding?school_id={other_school_id}", headers=headers)
    assert response_school_iso.status_code == 200
    assert len(response_school_iso.json()["data"]) == 0


@pytest.mark.anyio
async def test_fee_payment_update_list_and_receipt_regeneration(client: AsyncClient, setup_fee_test_data: dict, db_session: AsyncSession):
    headers = setup_fee_test_data["admin_headers"]
    tenant = setup_fee_test_data["tenant"]
    school = setup_fee_test_data["school"]
    ay = setup_fee_test_data["academic_year"]
    cl = setup_fee_test_data["class"]
    student = setup_fee_test_data["student"]

    # Setup Type, Structure, Assignment
    ft = FeeType(tenant_id=tenant.id, name="Computer Fee", code=f"COMP_{uuid.uuid4().hex[:6].upper()}", description="Computer lab fee")
    db_session.add(ft)
    await db_session.flush()

    fs = FeeStructure(
        tenant_id=tenant.id, school_id=school.id, fee_type_id=ft.id,
        academic_year_id=ay.id, class_id=cl.id, amount=Decimal("1200.00"), due_date=date.today()
    )
    db_session.add(fs)
    await db_session.flush()

    assign = StudentFeeAssignment(
        tenant_id=tenant.id, student_id=student.id, fee_structure_id=fs.id,
        academic_year_id=ay.id, assigned_amount=Decimal("1200.00")
    )
    db_session.add(assign)
    await db_session.commit()

    # Collect Payment
    pay_payload = {
        "student_id": str(student.id),
        "academic_year_id": str(ay.id),
        "payment_method": "CASH",
        "remarks": "Initial lab fee payment",
        "transaction_reference": f"TXN-INIT-{uuid.uuid4().hex[:6]}",
        "allocations": [{"assignment_id": str(assign.id), "amount_allocated": 500.0}]
    }
    create_res = await client.post("/api/v1/fees/payments", json=pay_payload, headers=headers)
    assert create_res.status_code == 201
    payment_data = create_res.json()["data"]
    payment_id = payment_data["id"]
    receipt_no = payment_data["receipt_number"]
    assert receipt_no is not None

    # Test GET /fees/payments
    list_res = await client.get(f"/api/v1/fees/payments?student_id={student.id}", headers=headers)
    assert list_res.status_code == 200
    payments_list = list_res.json()["data"]
    assert len(payments_list) >= 1
    assert any(p["id"] == payment_id for p in payments_list)

    # Test PUT /fees/payments/{payment_id}
    update_payload = {
        "payment_method": "ONLINE",
        "transaction_reference": "TXN-UPDATED-999",
        "remarks": "Updated to online mode"
    }
    update_res = await client.put(f"/api/v1/fees/payments/{payment_id}", json=update_payload, headers=headers)
    assert update_res.status_code == 200
    updated_data = update_res.json()["data"]
    assert updated_data["payment_method"] == "ONLINE"
    assert updated_data["transaction_reference"] == "TXN-UPDATED-999"
    assert updated_data["remarks"] == "Updated to online mode"

    # Test POST /fees/receipts/{receipt_number}/regenerate
    regen_res = await client.post(f"/api/v1/fees/receipts/{receipt_no}/regenerate", headers=headers)
    assert regen_res.status_code == 200
    assert regen_res.json()["data"]["receipt_number"] == receipt_no

    # Test GET /fees/receipts/{receipt_number}/download
    download_res = await client.get(f"/api/v1/fees/receipts/{receipt_no}/download", headers=headers)
    assert download_res.status_code == 200
    assert download_res.headers["content-type"] == "application/pdf"
    assert download_res.content.startswith(b"%PDF")

@pytest.mark.anyio
async def test_class_fee_structure_propagation_and_idempotency(
    client: AsyncClient,
    setup_fee_test_data: dict,
    db_session: AsyncSession
):
    """
    Verifies that creating a class fee structure propagates assignments to all eligible students
    in that class, re-propagation is idempotent, and newly created students receive active fees.
    """
    headers = setup_fee_test_data["admin_headers"]
    tenant = setup_fee_test_data["tenant"]
    school = setup_fee_test_data["school"]
    ay = setup_fee_test_data["academic_year"]

    # 1. Create a dedicated Class and Section with 2 students
    suffix = uuid.uuid4().hex[:6].lower()
    cl_prop = Class(tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id, name=f"Prop Class {suffix}", code=f"PC-{suffix}", level=5, capacity=50)
    db_session.add(cl_prop)
    await db_session.flush()

    sec_prop = Section(tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id, class_id=cl_prop.id, name="Section A", code=f"PSA-{suffix}", capacity=50)
    db_session.add(sec_prop)
    await db_session.flush()

    st1 = Student(tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id, class_id=cl_prop.id, section_id=sec_prop.id, first_name="Prop", last_name="One", roll_number=f"P1-{suffix}", admission_number=f"ADM-P1-{suffix}", admission_date=date(2026, 1, 1), date_of_birth=date(2015, 1, 1), gender=StudentGender.FEMALE)
    st2 = Student(tenant_id=tenant.id, school_id=school.id, academic_year_id=ay.id, class_id=cl_prop.id, section_id=sec_prop.id, first_name="Prop", last_name="Two", roll_number=f"P2-{suffix}", admission_number=f"ADM-P2-{suffix}", admission_date=date(2026, 1, 1), date_of_birth=date(2015, 2, 2), gender=StudentGender.MALE)
    db_session.add_all([st1, st2])
    await db_session.commit()

    # 2. Create Fee Type
    fee_type_payload = {"name": f"Tuition {suffix}", "code": f"TUI_{suffix[:4].upper()}", "description": "Tuition fees"}
    ft_res = await client.post("/api/v1/fees/types", json=fee_type_payload, headers=headers)
    assert ft_res.status_code == 201
    fee_type_id = ft_res.json()["data"]["id"]

    # 3. Create Fee Structure for cl_prop -> should auto-propagate to st1 and st2
    fs_payload = {
        "fee_type_id": fee_type_id,
        "academic_year_id": str(ay.id),
        "class_id": str(cl_prop.id),
        "amount": 25000.00,
        "due_date": "2026-06-30",
        "description": "Annual Class 5 Tuition"
    }
    fs_res = await client.post("/api/v1/fees/structures", json=fs_payload, headers=headers)
    assert fs_res.status_code == 201
    fs_id = fs_res.json()["data"]["id"]

    # 4. Verify both students have the fee assignment with assigned_amount = 25000.00
    res_fa1 = await db_session.execute(
        select(StudentFeeAssignment).where(
            StudentFeeAssignment.student_id == st1.id,
            StudentFeeAssignment.fee_structure_id == uuid.UUID(fs_id)
        )
    )
    fa1 = res_fa1.scalar_one_or_none()
    assert fa1 is not None
    assert fa1.assigned_amount == Decimal("25000.00")
    assert fa1.paid_amount == Decimal("0.00")
    assert fa1.status == FeeAssignmentStatus.UNPAID

    res_fa2 = await db_session.execute(
        select(StudentFeeAssignment).where(
            StudentFeeAssignment.student_id == st2.id,
            StudentFeeAssignment.fee_structure_id == uuid.UUID(fs_id)
        )
    )
    fa2 = res_fa2.scalar_one_or_none()
    assert fa2 is not None
    assert fa2.assigned_amount == Decimal("25000.00")

    # 5. Idempotency test: Call /fees/structures/{id}/propagate again
    prop_res = await client.post(f"/api/v1/fees/structures/{fs_id}/propagate", headers=headers)
    assert prop_res.status_code == 200
    assert prop_res.json()["data"]["assigned_count"] == 0

    # 6. Verify total assignments for st1 is still exactly 1
    res_all_st1 = await db_session.execute(
        select(StudentFeeAssignment).where(
            StudentFeeAssignment.student_id == st1.id,
            StudentFeeAssignment.fee_structure_id == uuid.UUID(fs_id)
        )
    )
    assert len(res_all_st1.scalars().all()) == 1

    # 7. Student registration auto-assignment: register a 3rd student via Student API
    st3_payload = {
        "school_id": str(school.id),
        "academic_year_id": str(ay.id),
        "class_id": str(cl_prop.id),
        "section_id": str(sec_prop.id),
        "first_name": "New",
        "last_name": "Student",
        "roll_number": f"P3-{suffix}",
        "admission_number": f"ADM-P3-{suffix}",
        "admission_date": "2026-01-01",
        "date_of_birth": "2015-03-03",
        "gender": "MALE"
    }
    st3_res = await client.post("/api/v1/students", json=st3_payload, headers=headers)
    assert st3_res.status_code == 201
    st3_id = st3_res.json()["data"]["id"]

    # Verify st3 automatically received the active fee structure
    res_fa3 = await db_session.execute(
        select(StudentFeeAssignment).where(
            StudentFeeAssignment.student_id == uuid.UUID(st3_id),
            StudentFeeAssignment.fee_structure_id == uuid.UUID(fs_id)
        )
    )
    fa3 = res_fa3.scalar_one_or_none()
    assert fa3 is not None
    assert fa3.assigned_amount == Decimal("25000.00")
    assert fa3.status == FeeAssignmentStatus.UNPAID

