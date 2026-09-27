import asyncio
import sys
import os
import uuid
from sqlalchemy import select
from sqlalchemy.orm import selectinload

sys.path.append(os.path.abspath(os.path.dirname(__file__) + "/.."))
sys.path.append(os.path.abspath("."))

from app.db.session import AsyncSessionLocal
from app.models.role import Role
from app.models.permission import Permission

NEW_PERMISSIONS = [
    ("school.profile.read", "View School Profile, Category & Infrastructure"),
    ("school.profile.write", "Edit School Profile, Category & Infrastructure"),
    ("school.compliance.read", "View Government & UDISE+ Compliance Information"),
    ("school.compliance.write", "Edit and Verify Government Compliance & UDISE+"),
    ("school.recognition.read", "View State & Central Recognition Records"),
    ("school.recognition.write", "Manage State & Central Recognition Records"),
    ("school.documents.read", "View & Search School Documents"),
    ("school.documents.upload", "Upload New School Documents"),
    ("school.documents.download", "Download School Documents"),
    ("school.documents.delete", "Delete or Archive School Documents"),
    ("teacher.payroll.read", "View Teacher Payroll Profiles & Calculations"),
    ("teacher.payroll.calculate", "Execute Attendance-Based Payroll Calculation"),
    ("teacher.payroll.approve", "Approve & Finalize Teacher Monthly Payroll"),
    ("teacher.attendance.payroll_impact", "Review & Adjust Retroactive Attendance Payroll Impact"),
]

ROLES_TO_ATTACH = ["SUPER_ADMIN", "SYSTEM_ADMIN", "TENANT_ADMIN", "PRINCIPAL", "SCHOOL_ADMIN"]

async def main():
    async with AsyncSessionLocal() as session:
        print("Seeding new school admin & payroll permissions...")
        
        # 1. Ensure permissions exist
        perm_map = {}
        for code, desc in NEW_PERMISSIONS:
            stmt = select(Permission).where(Permission.code == code)
            perm = (await session.execute(stmt)).scalar_one_or_none()
            if not perm:
                perm = Permission(
                    name=desc,
                    code=code,
                    description=desc
                )
                session.add(perm)
                await session.flush()
                print(f"Created permission: {code}")
            perm_map[code] = perm

        # 2. Attach to appropriate roles across tenants
        roles_stmt = (
            select(Role)
            .where(
                Role.code.in_(ROLES_TO_ATTACH),
                Role.deleted_at.is_(None)
            )
            .options(selectinload(Role.permissions))
        )
        roles = (await session.execute(roles_stmt)).scalars().all()
        print(f"Found {len(roles)} roles to update.")

        for role in roles:
            existing_codes = {p.code for p in role.permissions}
            for code, perm in perm_map.items():
                if code not in existing_codes:
                    role.permissions.append(perm)
                    print(f"Attached {code} to role {role.code} (Tenant: {role.tenant_id})")

        await session.commit()
        print("Permissions successfully seeded and linked!")

if __name__ == "__main__":
    asyncio.run(main())
