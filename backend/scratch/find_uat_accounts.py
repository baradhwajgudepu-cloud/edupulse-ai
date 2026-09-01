import asyncio
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

DATABASE_URL = "postgresql+asyncpg://postgres:Gudepu%4084@localhost:5432/edupulse_db"
TENANT_ID = "d09b9362-3dc8-422d-a441-160735fcea96"

async def main():
    engine = create_async_engine(DATABASE_URL)
    async with engine.connect() as conn:
        # Check all roles present in database
        res_roles = await conn.execute(text("SELECT id, name, code FROM roles"))
        roles_map = {r['id']: (r['name'], r['code']) for r in res_roles.mappings().all()}
        print("--- All Roles Map ---")
        for k, v in roles_map.items():
            print(f"{k}: {v}")

        # Get all users in tenant
        query_users = """
            SELECT u.id, u.email, u.first_name, u.last_name, u.status
            FROM users u
            WHERE u.tenant_id = :t_id
        """
        res_users = await conn.execute(text(query_users), {"t_id": TENANT_ID})
        users = res_users.mappings().all()
        print(f"\n--- Total Users in Tenant: {len(users)} ---")

        for u in users:
            # Get user's roles
            query_r = """
                SELECT r.name, r.code
                FROM user_roles ur
                JOIN roles r ON ur.role_id = r.id
                WHERE ur.user_id = :u_id
            """
            res_r = await conn.execute(text(query_r), {"u_id": u['id']})
            u_roles = [f"{r['name']} ({r['code']})" for r in res_r.mappings().all()]
            
            # Check if user is a teacher
            res_teacher = await conn.execute(text("SELECT id, employee_code FROM teachers WHERE user_id = :u_id"), {"u_id": u['id']})
            teacher_info = res_teacher.mappings().first()
            teacher_str = f", Teacher ID: {teacher_info['id']}" if teacher_info else ""
            
            # Check if user is a guardian
            res_guardian = await conn.execute(text("SELECT id FROM guardians WHERE user_id = :u_id"), {"u_id": u['id']})
            guardian_info = res_guardian.mappings().first()
            guardian_str = f", Guardian ID: {guardian_info['id']}" if guardian_info else ""
            
            # Check schools mapped via school_users
            query_su = """
                SELECT s.name, s.code
                FROM school_users su
                JOIN schools s ON su.school_id = s.id
                WHERE su.user_id = :u_id
            """
            res_su = await conn.execute(text(query_su), {"u_id": u['id']})
            schools = [f"{s['name']} ({s['code']})" for s in res_su.mappings().all()]
            school_str = f", Schools: {schools}" if schools else ""

            # Check if this user is a tenant admin or principal or teacher or parent
            is_interesting = any(rc in "".join(u_roles).upper() for rc in ['ADMIN', 'PRINCIPAL', 'TEACHER', 'PARENT', 'CHAIRMAN'])
            if is_interesting or len(u_roles) > 0:
                print(f"User: {u['email']} | Name: {u['first_name']} {u['last_name']} | Roles: {u_roles}{teacher_str}{guardian_str}{school_str}")

if __name__ == "__main__":
    asyncio.run(main())
