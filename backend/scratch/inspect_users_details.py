import asyncio
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

DATABASE_URL = "postgresql+asyncpg://postgres:Gudepu%4084@localhost:5432/edupulse_db"
TENANT_ID = "d09b9362-3dc8-422d-a441-160735fcea96"

async def main():
    engine = create_async_engine(DATABASE_URL)
    async with engine.connect() as conn:
        # Get users with roles
        query = """
            SELECT u.id as user_id, u.email, u.first_name, u.last_name, r.name as role_name, r.code as role_code
            FROM users u
            LEFT JOIN user_roles ur ON u.id = ur.user_id
            LEFT JOIN roles r ON ur.role_id = r.id
            WHERE u.tenant_id = :t_id
        """
        res = await conn.execute(text(query), {"t_id": TENANT_ID})
        users = res.mappings().all()
        print("--- Users & Roles ---")
        for u in users:
            print(dict(u))

        # Check schools
        res_schools = await conn.execute(text(
            "SELECT id, name, code FROM schools WHERE tenant_id = :t_id"
        ), {"t_id": TENANT_ID})
        print("--- Schools ---")
        for s in res_schools.mappings().all():
            print(dict(s))

        # Check school_users
        res_su = await conn.execute(text("""
            SELECT su.school_id, s.name as school_name, su.user_id, u.email
            FROM school_users su
            JOIN schools s ON su.school_id = s.id
            JOIN users u ON su.user_id = u.id
            WHERE u.tenant_id = :t_id
        """), {"t_id": TENANT_ID})
        print("--- School Users Mapping ---")
        for su in res_su.mappings().all():
            print(dict(su))

        # Check guardians and students relationships
        # Mappings of user_id to guardian to student to class/section
        query_g = """
            SELECT u.email as parent_email, g.id as guardian_id, s.first_name as student_first, s.last_name as student_last, 
                   c.name as class_name, sec.name as section_name, sch.name as school_name
            FROM users u
            JOIN guardians g ON u.id = g.user_id
            JOIN student_guardians sg ON g.id = sg.guardian_id
            JOIN students s ON sg.student_id = s.id
            LEFT JOIN classes c ON s.class_id = c.id
            LEFT JOIN sections sec ON s.section_id = sec.id
            LEFT JOIN schools sch ON s.school_id = sch.id
            WHERE u.tenant_id = :t_id
        """
        res_g = await conn.execute(text(query_g), {"t_id": TENANT_ID})
        print("--- Guardian-Student Links ---")
        for g in res_g.mappings().all():
            print(dict(g))

        # Check teachers and subject assignments
        query_t = """
            SELECT u.email as teacher_email, t.employee_code, c.name as class_name, sec.name as section_name, sub.subject_name
            FROM users u
            JOIN teachers t ON u.id = t.user_id
            LEFT JOIN teacher_subject_assignments tsa ON t.id = tsa.teacher_id
            LEFT JOIN classes c ON tsa.class_id = c.id
            LEFT JOIN sections sec ON tsa.section_id = sec.id
            LEFT JOIN subjects sub ON tsa.subject_id = sub.id
            WHERE u.tenant_id = :t_id
        """
        res_t = await conn.execute(text(query_t), {"t_id": TENANT_ID})
        print("--- Teacher-Subject Links ---")
        for t in res_t.mappings().all():
            print(dict(t))

if __name__ == "__main__":
    asyncio.run(main())
