import asyncio
import sys
import os
import uuid
from sqlalchemy import select
from sqlalchemy.orm import selectinload

# Setup python path to load the application modules correctly
sys.path.append(os.path.abspath(os.path.dirname(__file__) + "/.."))
sys.path.append(os.path.abspath("."))

from app.db.session import AsyncSessionLocal
from app.models.role import Role
from app.models.permission import Permission

INTENDED_PERMISSIONS = [
    "student.read",
    "teacher.read",
    "attendance.read",
    "exam.read",
    "marks.read",
    "marks.publish",
    "homework.read",
    "report_card.read",
    "report_card.download",
    "report_card.publish",
    
    "staff_attendance.read",
    "staff_attendance.admin",
    
    "fee.create",
    "fee.read",
    "fee.update",
    "fee.delete",
    "fee.pay",
    "fee.cancel",
    "fee.report",
    
    "notification.read",
    "notification.mark_read",
    
    "teacher_leave.read",
    "teacher_leave.review",
    "teacher_leave.admin",
    
    "event.create",
    "event.read",
    "event.update",
    "event.delete",
    "event.publish",
    
    "announcement.create",
    "announcement.read",
    "announcement.update",
    "announcement.delete",
    "announcement.publish",
    
    "migration.read",
    "migration.create",
    "migration.execute",
    "migration.cancel"
]

async def main():
    target_tenant_id = uuid.UUID("09f2d4e7-2877-4e42-9e95-e97d52775687")
    
    async with AsyncSessionLocal() as session:
        # 1. Retrieve the PRINCIPAL role for the target tenant
        stmt_role = (
            select(Role)
            .where(
                Role.tenant_id == target_tenant_id,
                Role.code == "PRINCIPAL",
                Role.deleted_at.is_(None)
            )
            .options(selectinload(Role.permissions))
        )
        res_role = await session.execute(stmt_role)
        roles = res_role.scalars().all()
        
        # Safety Guard 1: Abort unless exactly one PRINCIPAL role exists
        if len(roles) != 1:
            print(f"ABORTING: Expected exactly 1 PRINCIPAL role, found {len(roles)}.")
            return
            
        role = roles[0]
        
        # 2. Retrieve all intended permissions from the database
        stmt_perms = (
            select(Permission)
            .where(
                Permission.code.in_(INTENDED_PERMISSIONS),
                Permission.deleted_at.is_(None)
            )
        )
        res_perms = await session.execute(stmt_perms)
        db_perms = {p.code: p for p in res_perms.scalars().all()}
        
        # Safety Guard 2: Abort if any intended permission code is missing from the database
        missing_db_perms = [p for p in INTENDED_PERMISSIONS if p not in db_perms]
        if missing_db_perms:
            print(f"ABORTING: The following required permissions are missing from the database: {missing_db_perms}")
            return
            
        existing_codes = {p.code for p in role.permissions}
        missing_from_role = [p for p in INTENDED_PERMISSIONS if p not in existing_codes]

        # Print current metadata before applying updates
        print(f"TARGET_TENANT_ID: {target_tenant_id}")
        print(f"TARGET_ROLE_ID: {role.id}")
        print(f"TARGET_ROLE_CODE: {role.code}")
        print(f"CURRENTLY_MAPPED_PERMISSIONS_COUNT: {len(existing_codes)}")
        print(f"INTENDED_PERMISSIONS_COUNT: {len(INTENDED_PERMISSIONS)}")
        print(f"MISSING_PERMISSIONS_COUNT: {len(missing_from_role)}")
        print(f"MISSING_PERMISSION_CODES: {missing_from_role}")

        # 3. Mappings updates (idempotent, only append missing ones)
        if not missing_from_role:
            print("NO_CHANGES_REQUIRED")
            return

        for code in missing_from_role:
            role.permissions.append(db_perms[code])
                
        session.add(role)
        await session.commit()
        print("COMMIT_SUCCESSFUL")
            
        # 4. Reload and verify output
        await session.refresh(role)
        final_codes = sorted([p.code for p in role.permissions])
        print(f"FINAL_PERMISSIONS_COUNT: {len(final_codes)}")
        print(f"FINAL_PERMISSION_CODES: {final_codes}")

if __name__ == "__main__":
    asyncio.run(main())
