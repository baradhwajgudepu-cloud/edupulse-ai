import asyncio
import httpx
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine
from app.core.security import hash_password
from app.main import app

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

async def get_relationships(conn, email, role):
    # Retrieve tenant and school details
    if role == "SUPER_ADMIN":
        return "All Schools / Tenant Dashboard"
    elif role == "PRINCIPAL":
        # Find school principal belongs to
        query = """
            SELECT s.name 
            FROM school_users su
            JOIN schools s ON su.school_id = s.id
            JOIN users u ON su.user_id = u.id
            WHERE u.email = :email
        """
        res = await conn.execute(text(query), {"email": email})
        school = res.scalar()
        return f"School: {school}"
    elif role == "TEACHER":
        # Find classes/subjects assigned to teacher
        query = """
            SELECT s.name as school_name, c.name as class_name, sec.name as section_name
            FROM users u
            JOIN teachers t ON u.id = t.user_id
            JOIN teacher_subject_assignments tsa ON t.id = tsa.teacher_id
            JOIN classes c ON tsa.class_id = c.id
            JOIN sections sec ON tsa.section_id = sec.id
            JOIN schools s ON c.school_id = s.id
            WHERE u.email = :email
        """
        res = await conn.execute(text(query), {"email": email})
        rows = res.mappings().all()
        if not rows:
            return "No classes assigned"
        classes = [f"{r['class_name']} - {r['section_name']} ({r['school_name']})" for r in rows]
        return f"Classes: {', '.join(set(classes))}"
    elif role == "PARENT":
        # Find student and class
        query = """
            SELECT s.first_name, s.last_name, c.name as class_name, sch.name as school_name
            FROM users u
            JOIN guardians g ON u.id = g.user_id
            JOIN student_guardians sg ON g.id = sg.guardian_id
            JOIN students s ON sg.student_id = s.id
            JOIN classes c ON s.class_id = c.id
            JOIN schools sch ON s.school_id = sch.id
            WHERE u.email = :email
        """
        res = await conn.execute(text(query), {"email": email})
        rows = res.mappings().all()
        if not rows:
            return "No students linked"
        students = [f"Student: {r['first_name']} {r['last_name']} ({r['class_name']} @ {r['school_name']})" for r in rows]
        return ", ".join(students)
    return "N/A"

async def main():
    engine = create_async_engine(DATABASE_URL)
    hashed = hash_password(PASSWORD)
    
    # 1. Reset passwords in database
    async with engine.begin() as conn:
        for role, email in ACCOUNTS.items():
            print(f"Resetting password for {role}: {email}...")
            # Check user exists first
            res = await conn.execute(text("SELECT id FROM users WHERE email = :email AND tenant_id = :t_id"), {"email": email, "t_id": TENANT_ID})
            user = res.fetchone()
            if not user:
                print(f"WARNING: User {email} not found in DB!")
                continue
            
            await conn.execute(
                text("UPDATE users SET hashed_password = :hashed, status = 'ACTIVE' WHERE email = :email AND tenant_id = :t_id"),
                {"hashed": hashed, "email": email, "t_id": TENANT_ID}
            )
            print(f"Successfully updated {email}.")

    # 2. Verify endpoints using httpx AsyncClient
    print("\n--- Verifying logins and fetching details via HTTP ---")
    results_table = []
    
    async with engine.connect() as conn:
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as ac:
            for role, email in ACCOUNTS.items():
                print(f"\nVerifying {role} ({email})...")
                # POST to login
                login_resp = await ac.post(
                    "/api/v1/auth/login",
                    json={"email": email, "password": PASSWORD},
                    headers={"X-Tenant-ID": TENANT_ID}
                )
                
                if login_resp.status_code != 200:
                    print(f"ERROR: Login failed for {email} with status {login_resp.status_code}: {login_resp.text}")
                    results_table.append({
                        "ROLE": role,
                        "EMAIL": email,
                        "STATUS": "LOGIN_FAILED",
                        "DETAILS": "N/A"
                    })
                    continue
                
                token_data = login_resp.json()["data"]
                access_token = token_data["access_token"]
                print("Login successful. Access token received.")
                
                # GET auth/me
                me_resp = await ac.get(
                    "/api/v1/auth/me",
                    headers={"Authorization": f"Bearer {access_token}", "X-Tenant-ID": TENANT_ID}
                )
                
                if me_resp.status_code != 200:
                    print(f"ERROR: GET /auth/me failed with status {me_resp.status_code}: {me_resp.text}")
                    results_table.append({
                        "ROLE": role,
                        "EMAIL": email,
                        "STATUS": "ME_FAILED",
                        "DETAILS": "N/A"
                    })
                    continue
                
                me_data = me_resp.json()["data"]
                print(f"Me success. Roles reported: {me_data.get('roles', [])}")
                
                # Retrieve relationships from db
                details = await get_relationships(conn, email, role)
                
                # Get school name principal/teacher belongs to or super_admin
                school_str = "All"
                if role == "PRINCIPAL":
                    school_str = "Delhi Public School Hyderabad (DPS001)"
                elif role == "TEACHER":
                    school_str = "Delhi Public School Hyderabad (DPS001)"
                elif role == "PARENT":
                    school_str = "Delhi Public School Hyderabad (DPS001)"
                    
                results_table.append({
                    "ROLE": role,
                    "EMAIL": email,
                    "PASSWORD": PASSWORD,
                    "TENANT": TENANT_ID,
                    "SCHOOL": school_str,
                    "DETAILS": details
                })
                
    print("\n--- FINAL VERIFICATION TABLE ---")
    print(f"| {'ROLE':<15} | {'EMAIL':<30} | {'PASSWORD':<15} | {'TENANT':<36} | {'SCHOOL':<36} | {'STUDENT/CLASS'}")
    print("-" * 160)
    for r in results_table:
        print(f"| {r['ROLE']:<15} | {r['EMAIL']:<30} | {r['PASSWORD']:<15} | {r['TENANT']:<36} | {r['SCHOOL']:<36} | {r['DETAILS']}")

if __name__ == "__main__":
    asyncio.run(main())
