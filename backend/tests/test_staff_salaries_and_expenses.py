import uuid
import pytest
from datetime import date, datetime, timezone
from decimal import Decimal
from httpx import AsyncClient
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tenant import Tenant
from app.models.school import School
from app.models.teacher import Teacher, TeacherStatus, EmploymentType, StaffType
from app.models.student import StudentGender
from app.models.user import User, UserStatus
from app.models.role import Role, user_roles, role_permissions, school_users
from app.models.permission import Permission
from app.models.staff_salary import StaffSalary, SalaryStatus, SalaryPaymentMethod
from app.models.expense import Expense, ExpenseCategory
from app.core.security import create_access_token

@pytest.fixture
async def setup_salary_test_data(db_session: AsyncSession):
    suffix = uuid.uuid4().hex[:6].lower()

    # 1. Tenants
    tenant_a = Tenant(
        name="Tenant A",
        code=f"ten-a-{suffix}",
        subdomain=f"ten-a-{suffix}",
        email=f"ten-a-{suffix}@example.com"
    )
    tenant_b = Tenant(
        name="Tenant B",
        code=f"ten-b-{suffix}",
        subdomain=f"ten-b-{suffix}",
        email=f"ten-b-{suffix}@example.com"
    )
    db_session.add_all([tenant_a, tenant_b])
    await db_session.flush()

    # 2. Schools
    # school_a and school_b belong to tenant_a
    school_a = School(
        tenant_id=tenant_a.id,
        name="Campus A",
        code=f"SCH-A-{suffix}",
        email=f"sch-a-{suffix}@example.com",
        address="Address A",
        board="CBSE",
        is_active=True
    )
    school_b = School(
        tenant_id=tenant_a.id,
        name="Campus B",
        code=f"SCH-B-{suffix}",
        email=f"sch-b-{suffix}@example.com",
        address="Address B",
        board="CBSE",
        is_active=True
    )
    # school_c belongs to tenant_b
    school_c = School(
        tenant_id=tenant_b.id,
        name="Campus C",
        code=f"SCH-C-{suffix}",
        email=f"sch-c-{suffix}@example.com",
        address="Address C",
        board="CBSE",
        is_active=True
    )
    db_session.add_all([school_a, school_b, school_c])
    await db_session.flush()

    # 3. Staff / Teacher under school_a
    teacher_1 = Teacher(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        first_name="Ramesh",
        last_name="Sharma",
        employee_code=f"EMP-{suffix}-1",
        staff_code=f"STF-{suffix}-1",
        gender=StudentGender.MALE,
        date_of_birth=date(1985, 3, 15),
        mobile="9876543210",
        official_email=f"ramesh-{suffix}@school.in",
        joining_date=date(2020, 6, 1),
        employment_type=EmploymentType.FULL_TIME,
        staff_type=StaffType.TEACHING,
        status=TeacherStatus.ACTIVE,
        salary=25000.00,
        address={},
        settings={},
        ai_metrics={}
    )
    db_session.add(teacher_1)
    await db_session.flush()

    # 4. Roles & Permissions setup
    # Fetch permissions
    stmt_perms = select(Permission)
    all_perms = list((await db_session.execute(stmt_perms)).scalars().all())
    perm_map = {p.code: p for p in all_perms}

    # Role in Tenant A with fee + school permissions (School Admin)
    role_admin = Role(
        tenant_id=tenant_a.id,
        name="School Admin",
        code="SCHOOL_ADMIN",
        is_system=False
    )
    # Role in Tenant A with no fee permissions (Regular Teacher)
    role_teacher = Role(
        tenant_id=tenant_a.id,
        name="Teacher Role",
        code="TEACHER_ROLE",
        is_system=False
    )
    # Role in Tenant B
    role_tenant_b_admin = Role(
        tenant_id=tenant_b.id,
        name="Tenant B Admin",
        code="SCHOOL_ADMIN",
        is_system=False
    )
    db_session.add_all([role_admin, role_teacher, role_tenant_b_admin])
    await db_session.flush()

    # Assign permissions to role_admin (fee.create, fee.update, fee.read, school.update, school.read)
    for p_code in ["fee.create", "fee.update", "fee.read", "school.update", "school.read"]:
        if p_code in perm_map:
            await db_session.execute(
                role_permissions.insert().values(role_id=role_admin.id, permission_id=perm_map[p_code].id)
            )
            await db_session.execute(
                role_permissions.insert().values(role_id=role_tenant_b_admin.id, permission_id=perm_map[p_code].id)
            )

    # Assign read-only or harmless permission to role_teacher
    if "student.read" in perm_map:
        await db_session.execute(
            role_permissions.insert().values(role_id=role_teacher.id, permission_id=perm_map["student.read"].id)
        )

    # 5. Users
    # Admin user for school_a
    admin_user = User(
        tenant_id=tenant_a.id,
        email=f"admin-{suffix}@school.in",
        first_name="Admin",
        last_name="User",
        hashed_password="dummy_hash_pwd",
        is_superuser=False,
        status=UserStatus.ACTIVE
    )
    # Admin user assigned ONLY to school_b (for cross-school testing)
    wrong_school_admin = User(
        tenant_id=tenant_a.id,
        email=f"wrong-sch-{suffix}@school.in",
        first_name="WrongSchool",
        last_name="Admin",
        hashed_password="dummy_hash_pwd",
        is_superuser=False,
        status=UserStatus.ACTIVE
    )
    # Unauthorized teacher user in school_a
    unauthorized_teacher = User(
        tenant_id=tenant_a.id,
        email=f"unauth-{suffix}@school.in",
        first_name="Unauth",
        last_name="Teacher",
        hashed_password="dummy_hash_pwd",
        is_superuser=False,
        status=UserStatus.ACTIVE
    )
    # Tenant B user in school_c
    tenant_b_admin = User(
        tenant_id=tenant_b.id,
        email=f"admin-b-{suffix}@school.in",
        first_name="TenantB",
        last_name="Admin",
        hashed_password="dummy_hash_pwd",
        is_superuser=False,
        status=UserStatus.ACTIVE
    )
    db_session.add_all([admin_user, wrong_school_admin, unauthorized_teacher, tenant_b_admin])
    await db_session.flush()

    # Link user roles
    await db_session.execute(user_roles.insert().values(user_id=admin_user.id, role_id=role_admin.id))
    await db_session.execute(user_roles.insert().values(user_id=wrong_school_admin.id, role_id=role_admin.id))
    await db_session.execute(user_roles.insert().values(user_id=unauthorized_teacher.id, role_id=role_teacher.id))
    await db_session.execute(user_roles.insert().values(user_id=tenant_b_admin.id, role_id=role_tenant_b_admin.id))

    # Link user schools
    await db_session.execute(school_users.insert().values(user_id=admin_user.id, school_id=school_a.id))
    await db_session.execute(school_users.insert().values(user_id=wrong_school_admin.id, school_id=school_b.id))
    await db_session.execute(school_users.insert().values(user_id=unauthorized_teacher.id, school_id=school_a.id))
    await db_session.execute(school_users.insert().values(user_id=tenant_b_admin.id, school_id=school_c.id))

    await db_session.commit()

    # 6. Auth Headers
    admin_token = create_access_token(subject=admin_user.id, tenant_id=tenant_a.id)
    wrong_school_token = create_access_token(subject=wrong_school_admin.id, tenant_id=tenant_a.id)
    teacher_token = create_access_token(subject=unauthorized_teacher.id, tenant_id=tenant_a.id)
    tenant_b_token = create_access_token(subject=tenant_b_admin.id, tenant_id=tenant_b.id)

    return {
        "tenant_a": tenant_a,
        "tenant_b": tenant_b,
        "school_a": school_a,
        "school_b": school_b,
        "school_c": school_c,
        "teacher_1": teacher_1,
        "admin_headers": {
            "Authorization": f"Bearer {admin_token}",
            "X-Tenant-ID": str(tenant_a.id),
            "X-School-ID": str(school_a.id)
        },
        "wrong_school_headers": {
            "Authorization": f"Bearer {wrong_school_token}",
            "X-Tenant-ID": str(tenant_a.id),
            "X-School-ID": str(school_b.id)
        },
        "unauthorized_headers": {
            "Authorization": f"Bearer {teacher_token}",
            "X-Tenant-ID": str(tenant_a.id),
            "X-School-ID": str(school_a.id)
        },
        "tenant_b_headers": {
            "Authorization": f"Bearer {tenant_b_token}",
            "X-Tenant-ID": str(tenant_b.id),
            "X-School-ID": str(school_c.id)
        }
    }


# ============================================================================
# 1. STAFF SALARY CREATION & CALCULATION (BENCHMARK: 25000 + 3000 - 1500 = 26500)
# ============================================================================

@pytest.mark.anyio
async def test_create_staff_salary_and_calculation(client: AsyncClient, setup_salary_test_data):
    data = setup_salary_test_data
    payload = {
        "school_id": str(data["school_a"].id),
        "staff_id": str(data["teacher_1"].id),
        "month": 9,
        "year": 2026,
        "base_salary": 25000.00,
        "allowances": 3000.00,
        "deductions": 1500.00,
        "remarks": "September payroll benchmark test"
    }

    res = await client.post("/api/v1/staff-salaries", json=payload, headers=data["admin_headers"])
    assert res.status_code == 201, res.text
    body = res.json()
    assert body["success"] is True
    salary = body["data"]

    assert float(salary["base_salary"]) == 25000.0
    assert float(salary["allowances"]) == 3000.0
    assert float(salary["deductions"]) == 1500.0
    # Net salary assertion: 25000 + 3000 - 1500 = 26500
    assert float(salary["net_salary"]) == 26500.0
    assert salary["status"] == "PENDING"
    assert salary["staff_name"] == "Ramesh Sharma"


@pytest.mark.anyio
async def test_create_staff_salary_unauthorized(client: AsyncClient, setup_salary_test_data):
    data = setup_salary_test_data
    payload = {
        "school_id": str(data["school_a"].id),
        "staff_id": str(data["teacher_1"].id),
        "month": 10,
        "year": 2026,
        "base_salary": 25000.00,
        "allowances": 0.00,
        "deductions": 0.00
    }

    res = await client.post("/api/v1/staff-salaries", json=payload, headers=data["unauthorized_headers"])
    assert res.status_code == 403, res.text


@pytest.mark.anyio
async def test_create_staff_salary_negative_amounts(client: AsyncClient, setup_salary_test_data):
    data = setup_salary_test_data

    # Negative deductions
    res_ded = await client.post("/api/v1/staff-salaries", json={
        "school_id": str(data["school_a"].id),
        "staff_id": str(data["teacher_1"].id),
        "month": 11,
        "year": 2026,
        "base_salary": 25000.00,
        "allowances": 1000.00,
        "deductions": -500.00
    }, headers=data["admin_headers"])
    assert res_ded.status_code == 422

    # Negative base salary
    res_base = await client.post("/api/v1/staff-salaries", json={
        "school_id": str(data["school_a"].id),
        "staff_id": str(data["teacher_1"].id),
        "month": 11,
        "year": 2026,
        "base_salary": -25000.00,
        "allowances": 1000.00,
        "deductions": 500.00
    }, headers=data["admin_headers"])
    assert res_base.status_code == 422

    # Negative allowances
    res_allow = await client.post("/api/v1/staff-salaries", json={
        "school_id": str(data["school_a"].id),
        "staff_id": str(data["teacher_1"].id),
        "month": 11,
        "year": 2026,
        "base_salary": 25000.00,
        "allowances": -100.00,
        "deductions": 500.00
    }, headers=data["admin_headers"])
    assert res_allow.status_code == 422


# ============================================================================
# 2. STAFF SALARY UPDATE & CLAMPING INVARIANTS
# ============================================================================

@pytest.mark.anyio
async def test_update_staff_salary_and_net_calculation(client: AsyncClient, setup_salary_test_data):
    data = setup_salary_test_data
    # Create initial salary
    init_res = await client.post("/api/v1/staff-salaries", json={
        "school_id": str(data["school_a"].id),
        "staff_id": str(data["teacher_1"].id),
        "month": 1,
        "year": 2026,
        "base_salary": 20000.00,
        "allowances": 2000.00,
        "deductions": 1000.00
    }, headers=data["admin_headers"])
    assert init_res.status_code == 201
    salary_id = init_res.json()["data"]["id"]

    # Update: 30000 + 5000 - 2000 = 33000
    upd_res = await client.put(f"/api/v1/staff-salaries/{salary_id}", json={
        "base_salary": 30000.00,
        "allowances": 5000.00,
        "deductions": 2000.00,
        "remarks": "Annual increment applied"
    }, headers=data["admin_headers"])
    assert upd_res.status_code == 200
    upd_body = upd_res.json()["data"]
    assert float(upd_body["base_salary"]) == 30000.0
    assert float(upd_body["allowances"]) == 5000.0
    assert float(upd_body["deductions"]) == 2000.0
    assert float(upd_body["net_salary"]) == 33000.0


@pytest.mark.anyio
async def test_update_staff_salary_deductions_exceeding_gross(client: AsyncClient, setup_salary_test_data):
    data = setup_salary_test_data
    # Create salary
    init_res = await client.post("/api/v1/staff-salaries", json={
        "school_id": str(data["school_a"].id),
        "staff_id": str(data["teacher_1"].id),
        "month": 2,
        "year": 2026,
        "base_salary": 10000.00,
        "allowances": 0.00,
        "deductions": 0.00
    }, headers=data["admin_headers"])
    assert init_res.status_code == 201
    salary_id = init_res.json()["data"]["id"]

    # Deductions exceeding gross (15000 > 10000) -> net_salary must clamp to 0.00
    upd_res = await client.put(f"/api/v1/staff-salaries/{salary_id}", json={
        "base_salary": 10000.00,
        "allowances": 0.00,
        "deductions": 15000.00
    }, headers=data["admin_headers"])
    assert upd_res.status_code == 200
    assert float(upd_res.json()["data"]["net_salary"]) == 0.0


# ============================================================================
# 3. TENANT & SCHOOL ISOLATION (CROSS-SCHOOL & CROSS-TENANT SECURITY)
# ============================================================================

@pytest.mark.anyio
async def test_update_staff_salary_cross_school(client: AsyncClient, setup_salary_test_data):
    data = setup_salary_test_data
    # Create salary in school_a
    init_res = await client.post("/api/v1/staff-salaries", json={
        "school_id": str(data["school_a"].id),
        "staff_id": str(data["teacher_1"].id),
        "month": 3,
        "year": 2026,
        "base_salary": 25000.00,
        "allowances": 0.00,
        "deductions": 0.00
    }, headers=data["admin_headers"])
    assert init_res.status_code == 201
    salary_id = init_res.json()["data"]["id"]

    # Attempt modification by an admin belonging ONLY to school_b
    upd_res = await client.put(
        f"/api/v1/staff-salaries/{salary_id}",
        json={"base_salary": 28000.00},
        headers=data["wrong_school_headers"]
    )
    # Centralized school access policy returns 403 Forbidden
    assert upd_res.status_code == 403, upd_res.text


@pytest.mark.anyio
async def test_update_staff_salary_cross_tenant(client: AsyncClient, setup_salary_test_data):
    data = setup_salary_test_data
    # Create salary in tenant_a
    init_res = await client.post("/api/v1/staff-salaries", json={
        "school_id": str(data["school_a"].id),
        "staff_id": str(data["teacher_1"].id),
        "month": 4,
        "year": 2026,
        "base_salary": 25000.00,
        "allowances": 0.00,
        "deductions": 0.00
    }, headers=data["admin_headers"])
    assert init_res.status_code == 201
    salary_id = init_res.json()["data"]["id"]

    # Attempt modification by user in tenant_b -> Tenant isolation query returns 404
    upd_res = await client.put(
        f"/api/v1/staff-salaries/{salary_id}",
        json={"base_salary": 30000.00},
        headers=data["tenant_b_headers"]
    )
    assert upd_res.status_code == 404, upd_res.text


# ============================================================================
# 4. PAYMENT RECORDING & OVERPAYMENT SAFEGUARDS
# ============================================================================

@pytest.mark.anyio
async def test_pay_salary_and_linked_expense(client: AsyncClient, setup_salary_test_data, db_session: AsyncSession):
    data = setup_salary_test_data
    # Create salary: 25000 + 3000 - 1500 = 26500
    init_res = await client.post("/api/v1/staff-salaries", json={
        "school_id": str(data["school_a"].id),
        "staff_id": str(data["teacher_1"].id),
        "month": 5,
        "year": 2026,
        "base_salary": 25000.00,
        "allowances": 3000.00,
        "deductions": 1500.00
    }, headers=data["admin_headers"])
    assert init_res.status_code == 201
    salary_id = init_res.json()["data"]["id"]

    # Record payment for exact net amount 26500
    pay_res = await client.post(f"/api/v1/staff-salaries/{salary_id}/pay", json={
        "payment_method": "BANK_TRANSFER",
        "reference_number": "TXN-SAL-001",
        "amount": 26500.00,
        "remarks": "May salary disbursed via NEFT"
    }, headers=data["admin_headers"])
    assert pay_res.status_code == 200, pay_res.text
    pay_body = pay_res.json()["data"]
    assert pay_body["status"] == "PAID"
    assert pay_body["payment_method"] == "BANK_TRANSFER"
    assert pay_body["reference_number"] == "TXN-SAL-001"

    # Verify linked expense in database
    exp_stmt = select(Expense).where(
        Expense.salary_payment_id == uuid.UUID(salary_id),
        Expense.deleted_at.is_(None)
    )
    exp = (await db_session.execute(exp_stmt)).scalar_one_or_none()
    assert exp is not None
    assert exp.amount == Decimal("26500.00")
    assert exp.category == ExpenseCategory.STAFF
    assert exp.subcategory == "Salary Disbursement"
    assert exp.status == "APPROVED"
    assert exp.reference_number == "TXN-SAL-001"


@pytest.mark.anyio
async def test_pay_salary_overpayment_rejected(client: AsyncClient, setup_salary_test_data):
    data = setup_salary_test_data
    # Create salary with net 26500
    init_res = await client.post("/api/v1/staff-salaries", json={
        "school_id": str(data["school_a"].id),
        "staff_id": str(data["teacher_1"].id),
        "month": 6,
        "year": 2026,
        "base_salary": 25000.00,
        "allowances": 3000.00,
        "deductions": 1500.00
    }, headers=data["admin_headers"])
    assert init_res.status_code == 201
    salary_id = init_res.json()["data"]["id"]

    # Attempt overpayment: ₹30,000 > ₹26,500
    pay_res = await client.post(f"/api/v1/staff-salaries/{salary_id}/pay", json={
        "payment_method": "BANK_TRANSFER",
        "amount": 30000.00
    }, headers=data["admin_headers"])
    assert pay_res.status_code == 400
    msg = pay_res.json().get("message") or pay_res.json().get("detail", "")
    assert "exceeds net payable salary" in msg


@pytest.mark.anyio
async def test_pay_salary_duplicate_rejected(client: AsyncClient, setup_salary_test_data):
    data = setup_salary_test_data
    # Create & pay salary
    init_res = await client.post("/api/v1/staff-salaries", json={
        "school_id": str(data["school_a"].id),
        "staff_id": str(data["teacher_1"].id),
        "month": 7,
        "year": 2026,
        "base_salary": 25000.00,
        "allowances": 0.00,
        "deductions": 0.00
    }, headers=data["admin_headers"])
    assert init_res.status_code == 201
    salary_id = init_res.json()["data"]["id"]

    first_pay = await client.post(f"/api/v1/staff-salaries/{salary_id}/pay", json={
        "payment_method": "CASH"
    }, headers=data["admin_headers"])
    assert first_pay.status_code == 200

    # Attempt second payment on already PAID salary
    second_pay = await client.post(f"/api/v1/staff-salaries/{salary_id}/pay", json={
        "payment_method": "CASH"
    }, headers=data["admin_headers"])
    assert second_pay.status_code == 400
    msg = second_pay.json().get("message") or second_pay.json().get("detail", "")
    assert "already been marked as PAID" in msg


@pytest.mark.anyio
async def test_update_paid_salary_rejected(client: AsyncClient, setup_salary_test_data):
    data = setup_salary_test_data
    # Create & pay salary
    init_res = await client.post("/api/v1/staff-salaries", json={
        "school_id": str(data["school_a"].id),
        "staff_id": str(data["teacher_1"].id),
        "month": 8,
        "year": 2026,
        "base_salary": 25000.00,
        "allowances": 0.00,
        "deductions": 0.00
    }, headers=data["admin_headers"])
    assert init_res.status_code == 201
    salary_id = init_res.json()["data"]["id"]

    await client.post(f"/api/v1/staff-salaries/{salary_id}/pay", json={
        "payment_method": "ONLINE"
    }, headers=data["admin_headers"])

    # Attempt to modify paid salary breakdown
    upd_res = await client.put(f"/api/v1/staff-salaries/{salary_id}", json={
        "base_salary": 30000.00
    }, headers=data["admin_headers"])
    assert upd_res.status_code == 400
    msg = upd_res.json().get("message") or upd_res.json().get("detail", "")
    assert "Cannot modify a salary record that has already been PAID" in msg


# ============================================================================
# 5. EXPENSE ENDPOINTS, LINKED-SALARY AMOUNT IMMUTABILITY & RBAC
# ============================================================================

@pytest.mark.anyio
async def test_update_expense_valid_and_negative_amount(client: AsyncClient, setup_salary_test_data, db_session: AsyncSession):
    data = setup_salary_test_data
    # Create an operational expense
    expense = Expense(
        tenant_id=data["tenant_a"].id,
        school_id=data["school_a"].id,
        category=ExpenseCategory.OPERATIONS,
        subcategory="Electricity",
        amount=Decimal("5000.00"),
        expense_date=date(2026, 9, 1),
        description="Campus electric bill",
        paid_to="Power Corp",
        payment_method="BANK_TRANSFER",
        status="APPROVED"
    )
    db_session.add(expense)
    await db_session.commit()
    await db_session.refresh(expense)

    # Valid update
    upd_res = await client.put(f"/api/v1/expenses/{expense.id}", json={
        "description": "Campus electric bill - Revised",
        "reference_number": "BILL-1002"
    }, headers=data["admin_headers"])
    assert upd_res.status_code == 200
    assert upd_res.json()["data"]["description"] == "Campus electric bill - Revised"

    # Negative or zero amount rejection via schema validation
    neg_res = await client.put(f"/api/v1/expenses/{expense.id}", json={
        "amount": -500.00
    }, headers=data["admin_headers"])
    assert neg_res.status_code == 422


@pytest.mark.anyio
async def test_update_salary_linked_expense_amount_rejected(client: AsyncClient, setup_salary_test_data, db_session: AsyncSession):
    data = setup_salary_test_data
    # 1. Create and pay salary
    init_res = await client.post("/api/v1/staff-salaries", json={
        "school_id": str(data["school_a"].id),
        "staff_id": str(data["teacher_1"].id),
        "month": 12,
        "year": 2026,
        "base_salary": 25000.00,
        "allowances": 3000.00,
        "deductions": 1500.00
    }, headers=data["admin_headers"])
    salary_id = init_res.json()["data"]["id"]

    pay_res = await client.post(f"/api/v1/staff-salaries/{salary_id}/pay", json={
        "payment_method": "BANK_TRANSFER",
        "amount": 26500.00
    }, headers=data["admin_headers"])
    assert pay_res.status_code == 200

    # Retrieve generated linked expense
    exp_stmt = select(Expense).where(Expense.salary_payment_id == uuid.UUID(salary_id))
    expense = (await db_session.execute(exp_stmt)).scalar_one()

    # Attempt to modify amount of the salary-linked expense -> HTTP 400
    hack_res = await client.put(f"/api/v1/expenses/{expense.id}", json={
        "amount": 99999.00
    }, headers=data["admin_headers"])
    assert hack_res.status_code == 400
    msg = hack_res.json().get("message") or hack_res.json().get("detail", "")
    assert "Cannot modify amount on an expense generated from staff salary disbursement" in msg

    # Updating other non-amount fields (e.g. description, reference_number) is allowed
    ok_res = await client.put(f"/api/v1/expenses/{expense.id}", json={
        "description": "Salary disbursement - verified with bank statement",
        "reference_number": "UTR-REF-9988"
    }, headers=data["admin_headers"])
    assert ok_res.status_code == 200
    assert ok_res.json()["data"]["reference_number"] == "UTR-REF-9988"


@pytest.mark.anyio
async def test_expense_permissions_separation(client: AsyncClient, setup_salary_test_data, db_session: AsyncSession):
    data = setup_salary_test_data
    # Create an expense
    expense = Expense(
        tenant_id=data["tenant_a"].id,
        school_id=data["school_a"].id,
        category=ExpenseCategory.OPERATIONS,
        subcategory="Maintenance",
        amount=Decimal("1200.00"),
        expense_date=date(2026, 9, 1),
        description="Air conditioner service",
        paid_to="Cooling Services",
        payment_method="CASH",
        status="APPROVED"
    )
    db_session.add(expense)
    await db_session.commit()
    await db_session.refresh(expense)

    # Attempt to update expense with unauthorized user headers -> 403 Forbidden
    unauth_res = await client.put(f"/api/v1/expenses/{expense.id}", json={
        "description": "Malicious expense update"
    }, headers=data["unauthorized_headers"])
    assert unauth_res.status_code == 403
