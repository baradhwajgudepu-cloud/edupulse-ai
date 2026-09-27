import uuid
import pytest
import httpx
from app.main import app
from app.db.session import AsyncSessionLocal
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from app.models.user import User
from app.models.school import School
from app.models.student import Student

@pytest.mark.anyio
async def test_principal_rbac_parity_and_isolation():
    """
    Tests that a Principal has full operational access to their assigned school
    (Guardians, Examinations, Students, Teachers, Classes, Report Cards, Identity)
    while maintaining strict campus-level isolation against unauthorized schools.
    """
    # 1. Fetch Principal user and school context from database
    async with AsyncSessionLocal() as db:
        stmt = select(User).where(User.email == "principal.ts001@telanganaschool.edu").options(
            selectinload(User.roles), selectinload(User.schools)
        )
        principal = (await db.execute(stmt)).scalar_one_or_none()
        assert principal is not None, "Principal test user must exist in database"
        assert len(principal.schools) > 0, "Principal must be assigned to at least one school"

        own_school = principal.schools[0]
        own_school_id = str(own_school.id)
        tenant_id = str(principal.tenant_id)

        # Find a student in the Principal's school
        stmt_s = select(Student).where(Student.school_id == own_school.id)
        student = (await db.execute(stmt_s)).scalars().first()
        student_id = str(student.id) if student else None

        # Find another school in the same tenant (or create / query another school)
        stmt_other = select(School).where(School.tenant_id == principal.tenant_id, School.id != own_school.id)
        other_school = (await db.execute(stmt_other)).scalars().first()
        if not other_school:
            other_school_id = str(uuid.uuid4())
        else:
            other_school_id = str(other_school.id)

    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        # 2. Authenticate as Principal
        login_resp = await client.post("/api/v1/auth/login", json={
            "email": "principal.ts001@telanganaschool.edu",
            "password": "EduPulse@123"
        }, headers={"X-Tenant-ID": tenant_id})
        assert login_resp.status_code == 200, f"Login failed: {login_resp.text}"

        token = login_resp.json()["data"]["access_token"]
        headers = {
            "Authorization": f"Bearer {token}",
            "X-Tenant-ID": tenant_id,
            "X-School-ID": own_school_id
        }

        # 3. Test Full Operational Access for Own School (Parity: HTTP 200)
        # Guardians
        resp = await client.get(f"/api/v1/guardians?school_id={own_school_id}", headers=headers)
        assert resp.status_code == 200, f"Guardians list failed: {resp.text}"

        # Exam Types
        resp = await client.get(f"/api/v1/examinations/types?school_id={own_school_id}", headers=headers)
        assert resp.status_code == 200, f"Exam types list failed: {resp.text}"

        # Examinations
        resp = await client.get(f"/api/v1/examinations?school_id={own_school_id}", headers=headers)
        assert resp.status_code == 200, f"Examinations list failed: {resp.text}"

        # Students
        resp = await client.get(f"/api/v1/students?school_id={own_school_id}", headers=headers)
        assert resp.status_code == 200, f"Students list failed: {resp.text}"

        # Teachers
        resp = await client.get(f"/api/v1/teachers?school_id={own_school_id}", headers=headers)
        assert resp.status_code == 200, f"Teachers list failed: {resp.text}"

        # Classes
        resp = await client.get(f"/api/v1/classes?school_id={own_school_id}", headers=headers)
        assert resp.status_code == 200, f"Classes list failed: {resp.text}"

        # Identity Users (Scoped to own school)
        resp = await client.get("/api/v1/identity/users", headers=headers)
        assert resp.status_code == 200, f"Identity users failed: {resp.text}"
        users_data = resp.json()["data"]
        # Principal must not see platform superadmins
        for u in users_data:
            assert not u.get("is_superuser", False)

        # Report Cards History (if student exists)
        if student_id:
            resp = await client.get(f"/api/v1/report-cards/history/{student_id}?school_id={own_school_id}", headers=headers)
            assert resp.status_code == 200, f"Report cards history failed: {resp.text}"

            resp = await client.get(f"/api/v1/report-cards/preview/{student_id}?school_id={own_school_id}", headers=headers)
            assert resp.status_code == 200, f"Report cards preview failed: {resp.text}"

        # 4. Strict School Isolation (Cross-School Access: HTTP 403 / 404)
        cross_headers = dict(headers)
        cross_headers["X-School-ID"] = other_school_id

        resp_guardians = await client.get(f"/api/v1/guardians?school_id={other_school_id}", headers=cross_headers)
        assert resp_guardians.status_code in [403, 404], f"Expected 403/404 for cross-school guardians, got {resp_guardians.status_code}"

        resp_students = await client.get(f"/api/v1/students?school_id={other_school_id}", headers=cross_headers)
        assert resp_students.status_code in [403, 404], f"Expected 403/404 for cross-school students, got {resp_students.status_code}"

        resp_teachers = await client.get(f"/api/v1/teachers?school_id={other_school_id}", headers=cross_headers)
        assert resp_teachers.status_code in [403, 404], f"Expected 403/404 for cross-school teachers, got {resp_teachers.status_code}"
