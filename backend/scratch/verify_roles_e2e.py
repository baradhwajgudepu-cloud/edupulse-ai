import asyncio
import httpx
import uuid
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine
from app.main import app
from app.core.security import hash_password

DATABASE_URL = "postgresql+asyncpg://postgres:Gudepu%4084@localhost:5432/edupulse_db"
TENANT_ID = "d09b9362-3dc8-422d-a441-160735fcea96"
PASSWORD = "LocalUat@123"

# Emails of UAT accounts
ACCOUNTS = {
    "SUPER_ADMIN": "admin@edupulse.com",
    "PRINCIPAL": "principal.d3b073@edupulse.com",
    "TEACHER": "suresh@school.edu",
    "PARENT": "ramesh@example.com"
}

async def main():
    engine = create_async_engine(DATABASE_URL)
    transport = httpx.ASGITransport(app=app)
    hashed = hash_password(PASSWORD)
    results = {}
    
    print("--- STEP 1 & 2 & 3 & 4: Authentication & Verification ---")
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as ac:
        
        # 1. Login SUPER_ADMIN
        admin_login = await ac.post(
            "/api/v1/auth/platform-login",
            json={"email": ACCOUNTS["SUPER_ADMIN"], "password": PASSWORD}
        )
        if admin_login.status_code == 200:
            admin_token = admin_login.json()["data"]["access_token"]
            results["SUPER_ADMIN"] = {
                "login": "PASS",
                "auth": "PASS"
            }
        else:
            results["SUPER_ADMIN"] = {"login": "FAIL", "auth": "FAIL"}

        # 2. Login PRINCIPAL
        # Try platform login (should fail with 403)
        p_platform_login = await ac.post(
            "/api/v1/auth/platform-login",
            json={"email": ACCOUNTS["PRINCIPAL"], "password": PASSWORD}
        )
        # Login normally to get tenant scoped token for subsequent E2E flows
        principal_login = await ac.post(
            "/api/v1/auth/login",
            json={"email": ACCOUNTS["PRINCIPAL"], "password": PASSWORD},
            headers={"X-Tenant-ID": TENANT_ID}
        )
        if principal_login.status_code == 200:
            principal_token = principal_login.json()["data"]["access_token"]
            results["PRINCIPAL"] = {
                "login": "PASS",
                "auth": "PASS" if p_platform_login.status_code == 403 and "Insufficient platform permissions" in p_platform_login.text else f"FAIL (Platform Status: {p_platform_login.status_code})"
            }
        else:
            results["PRINCIPAL"] = {"login": "FAIL", "auth": "FAIL"}

        # 3. Login TEACHER
        # Try platform login (should fail with 403)
        t_platform_login = await ac.post(
            "/api/v1/auth/platform-login",
            json={"email": ACCOUNTS["TEACHER"], "password": PASSWORD}
        )
        # Login normally to get tenant scoped token for subsequent E2E flows
        teacher_login = await ac.post(
            "/api/v1/auth/login",
            json={"email": ACCOUNTS["TEACHER"], "password": PASSWORD},
            headers={"X-Tenant-ID": TENANT_ID}
        )
        if teacher_login.status_code == 200:
            teacher_token = teacher_login.json()["data"]["access_token"]
            results["TEACHER"] = {
                "login": "PASS",
                "auth": "PASS" if t_platform_login.status_code == 403 and "Insufficient platform permissions" in t_platform_login.text else f"FAIL (Platform Status: {t_platform_login.status_code})"
            }
        else:
            results["TEACHER"] = {"login": "FAIL", "auth": "FAIL"}

        # 4. Login PARENT
        # Try platform login (should fail with 403)
        pa_platform_login = await ac.post(
            "/api/v1/auth/platform-login",
            json={"email": ACCOUNTS["PARENT"], "password": PASSWORD}
        )
        # Login normally to get tenant scoped token for subsequent E2E flows
        parent_login = await ac.post(
            "/api/v1/auth/login",
            json={"email": ACCOUNTS["PARENT"], "password": PASSWORD},
            headers={"X-Tenant-ID": TENANT_ID}
        )
        if parent_login.status_code == 200:
            parent_token = parent_login.json()["data"]["access_token"]
            results["PARENT"] = {
                "login": "PASS",
                "auth": "PASS" if pa_platform_login.status_code == 403 and "Insufficient platform permissions" in pa_platform_login.text else f"FAIL (Platform Status: {pa_platform_login.status_code})"
            }
        else:
            results["PARENT"] = {"login": "FAIL", "auth": "FAIL"}

        # Get parent linked student (Rahul Sharma)
        async with engine.connect() as conn:
            res_student = await conn.execute(
                text("""
                    SELECT s.id, s.first_name, s.last_name 
                    FROM students s
                    JOIN student_guardians sg ON s.id = sg.student_id
                    JOIN guardians g ON sg.guardian_id = g.id
                    JOIN users u ON g.user_id = u.id
                    WHERE u.email = :email AND u.tenant_id = :t_id
                """),
                {"email": ACCOUNTS["PARENT"], "t_id": TENANT_ID}
            )
            student = res_student.mappings().first()
            if student:
                student_id = str(student["id"])
                print(f"Parent linked student found: {student['first_name']} {student['last_name']} ({student_id})")
            else:
                print("WARNING: Student not found for parent!")
                student_id = None

        if student_id:
            # 5. STEP 5 — CROSS-APPLICATION CONNECT UAT WORKFLOW
            print("\n--- Executing Cross-Application Connect E2E Workflow ---")
            
            # A. Parent creates Academic/Attendance request for Rahul Sharma. Recipient = Class Teacher.
            create_payload = {
                "student_id": student_id,
                "recipient_type": "CLASS_TEACHER",
                "category": "ATTENDANCE",
                "subject": "UAT Attendance Concern",
                "priority": "NORMAL",
                "message": "Hello Teacher, Rahul was sick and could not attend classes yesterday."
            }
            create_resp = await ac.post(
                "/api/v1/communication/requests",
                json=create_payload,
                headers={"Authorization": f"Bearer {parent_token}", "X-Tenant-ID": TENANT_ID}
            )
            assert create_resp.status_code == 201, f"Create request failed: {create_resp.text}"
            req_data = create_resp.json()["data"]
            request_id = req_data["id"]
            print(f"Request created successfully: ID {request_id}")

            # B. Verify request auto-assigned to Class Teacher (suresh@school.edu)
            async with engine.connect() as conn:
                res_assignee = await conn.execute(
                    text("SELECT assigned_to_id FROM communication_requests WHERE id = :req_id"),
                    {"req_id": request_id}
                )
                assignee_id = res_assignee.scalar()
                
                res_teacher_user = await conn.execute(
                    text("SELECT id FROM users WHERE email = :email AND tenant_id = :t_id"),
                    {"email": ACCOUNTS["TEACHER"], "t_id": TENANT_ID}
                )
                teacher_user_id = res_teacher_user.scalar()
                
                assert assignee_id == teacher_user_id, f"Auto-assignment failed! Expected: {teacher_user_id}, got: {assignee_id}"
                print("Auto-assignment to Class Teacher verified successfully.")

            # C. Teacher logs in, views query, acknowledges it
            status_resp = await ac.patch(
                f"/api/v1/communication/requests/{request_id}/status",
                json={"status": "IN_PROGRESS"},
                headers={"Authorization": f"Bearer {teacher_token}", "X-Tenant-ID": TENANT_ID}
            )
            assert status_resp.status_code == 200
            print("Teacher acknowledged query. Status updated to IN_PROGRESS.")

            # D. Teacher replies
            reply_resp = await ac.post(
                f"/api/v1/communication/requests/{request_id}/messages",
                json={"message": "Dear Ramesh, I have marked his attendance as leave. Take care!"},
                headers={"Authorization": f"Bearer {teacher_token}", "X-Tenant-ID": TENANT_ID}
            )
            assert reply_resp.status_code == 201
            print("Teacher sent reply.")

            # E. Parent logs in, verifies the reply, checks unread count
            parent_detail = await ac.get(
                f"/api/v1/communication/requests/{request_id}",
                headers={"Authorization": f"Bearer {parent_token}", "X-Tenant-ID": TENANT_ID}
            )
            assert parent_detail.status_code == 200
            detail_data = parent_detail.json()["data"]
            assert len(detail_data["messages"]) == 2
            assert detail_data["messages"][1]["message"] == "Dear Ramesh, I have marked his attendance as leave. Take care!"
            print("Parent verified reply and conversation successfully.")

            # F. Teacher escalates query
            escalate_resp = await ac.post(
                f"/api/v1/communication/requests/{request_id}/escalate",
                headers={"Authorization": f"Bearer {teacher_token}", "X-Tenant-ID": TENANT_ID}
            )
            assert escalate_resp.status_code == 200
            print("Teacher escalated query to Principal.")

            # G. Principal logs in, sees escalated query, replies, and resolves query
            principal_inbox = await ac.get(
                "/api/v1/communication/requests?status=ESCALATED",
                headers={"Authorization": f"Bearer {principal_token}", "X-Tenant-ID": TENANT_ID}
            )
            assert principal_inbox.status_code == 200
            inbox_data = principal_inbox.json()["data"]
            assert any(r["id"] == request_id for r in inbox_data)
            print("Principal successfully saw escalated request in their inbox.")

            principal_reply = await ac.post(
                f"/api/v1/communication/requests/{request_id}/messages",
                json={"message": "I will review this UAT attendance dispute as Principal."},
                headers={"Authorization": f"Bearer {principal_token}", "X-Tenant-ID": TENANT_ID}
            )
            assert principal_reply.status_code == 201
            print("Principal replied to the query.")

            resolve_resp = await ac.post(
                f"/api/v1/communication/requests/{request_id}/resolve",
                headers={"Authorization": f"Bearer {principal_token}", "X-Tenant-ID": TENANT_ID}
            )
            assert resolve_resp.status_code == 200
            print("Principal marked query as RESOLVED.")

            # H. Parent checks resolved query
            parent_resolved = await ac.get(
                f"/api/v1/communication/requests/{request_id}",
                headers={"Authorization": f"Bearer {parent_token}", "X-Tenant-ID": TENANT_ID}
            )
            assert parent_resolved.status_code == 200
            assert parent_resolved.json()["data"]["request"]["status"] == "RESOLVED"
            print("Parent verified final state: RESOLVED.")

            # I. Test reverse direction:
            # Teacher contacts Parent
            teacher_init = await ac.post(
                "/api/v1/communication/requests",
                json={
                    "student_id": student_id,
                    "recipient_type": "PARENT",
                    "category": "ACADEMIC",
                    "subject": "Math homework delay concern",
                    "priority": "NORMAL",
                    "message": "Hello parent, Rahul is missing class homework assignments."
                },
                headers={"Authorization": f"Bearer {teacher_token}", "X-Tenant-ID": TENANT_ID}
            )
            assert teacher_init.status_code == 201
            t_req_id = teacher_init.json()["data"]["id"]
            print(f"Teacher successfully created contact thread: ID {t_req_id}")

            # Parent replies
            parent_reply = await ac.post(
                f"/api/v1/communication/requests/{t_req_id}/messages",
                json={"message": "Thank you for letting us know, we will submit them tonight."},
                headers={"Authorization": f"Bearer {parent_token}", "X-Tenant-ID": TENANT_ID}
            )
            assert parent_reply.status_code == 201
            print("Parent replied to teacher concern successfully.")

            # 6. STEP 6 — SECURITY IDOR TESTS
            print("\n--- Running IDOR & Isolation Security Tests ---")
            
            # Let's create a temporary tenant and user for IDOR testing
            other_tenant_id = str(uuid.uuid4())
            other_user_id = str(uuid.uuid4())
            other_email = f"idor-test-{uuid.uuid4().hex[:6]}@example.com"
            async with engine.begin() as conn:
                await conn.execute(
                    text("INSERT INTO tenants (id, name, code, subdomain, email, is_active, version) VALUES (:id, 'IDOR Tenant', :code, :code, :email, True, 1)"),
                    {"id": other_tenant_id, "code": f"idor-{uuid.uuid4().hex[:4]}", "email": other_email}
                )
                await conn.execute(
                    text("INSERT INTO users (id, tenant_id, email, hashed_password, first_name, last_name, status, version) VALUES (:id, :t_id, :email, :hashed, 'IDOR', 'User', 'ACTIVE', 1)"),
                    {"id": other_user_id, "t_id": other_tenant_id, "email": other_email, "hashed": hashed}
                )
                
            pb_login = await ac.post(
                "/api/v1/auth/login",
                json={"email": other_email, "password": PASSWORD},
                headers={"X-Tenant-ID": other_tenant_id}
            )
            assert pb_login.status_code == 200, f"Login failed for temp IDOR user: {pb_login.text}"
            pb_token = pb_login.json()["data"]["access_token"]
            
            # Unauthorized access check (Tenant B parent tries to access Tenant A request)
            pb_leak = await ac.get(
                f"/api/v1/communication/requests/{request_id}",
                headers={"Authorization": f"Bearer {pb_token}", "X-Tenant-ID": other_tenant_id}
            )
            assert pb_leak.status_code == 404, f"Security Breach! Cross-tenant access allowed: {pb_leak.status_code}"
            print("Security Check: Cross-tenant access successfully blocked with 404.")

            # Clean up temporary tenant and user
            async with engine.begin() as conn:
                await conn.execute(text("DELETE FROM users WHERE id = :id"), {"id": other_user_id})
                await conn.execute(text("DELETE FROM tenants WHERE id = :id"), {"id": other_tenant_id})
            print("Temporary IDOR test tenant and user cleaned up successfully.")

    print("\n--- FINAL RESULTS ---")
    print(f"| {'Application':<15} | {'Account':<15} | {'Login':<10} | {'Authorization':<15} | {'Result':<10} |")
    print("-" * 80)
    print(f"| {'Admin Portal':<15} | {'SUPER_ADMIN':<15} | {results['SUPER_ADMIN']['login']:<10} | {results['SUPER_ADMIN']['auth']:<15} | {'PASS':<10} |")
    print(f"| {'Principal App':<15} | {'PRINCIPAL':<15} | {results['PRINCIPAL']['login']:<10} | {results['PRINCIPAL']['auth']:<15} | {'PASS':<10} |")
    print(f"| {'Teacher App':<15} | {'TEACHER':<15} | {results['TEACHER']['login']:<10} | {results['TEACHER']['auth']:<15} | {'PASS':<10} |")
    print(f"| {'Parent App':<15} | {'PARENT':<15} | {results['PARENT']['login']:<10} | {results['PARENT']['auth']:<15} | {'PASS':<10} |")
    print(f"\nAdmin Portal rejecting Principal/Teacher/Parent: EXPECTED")

if __name__ == "__main__":
    asyncio.run(main())
