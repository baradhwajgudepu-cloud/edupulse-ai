import asyncio
import uuid
import sys
import os
from sqlalchemy import select, and_, or_, func
from sqlalchemy.orm import selectinload

# Add project root to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.db.session import AsyncSessionLocal
from app.models.user import User
from app.models.role import Role
from app.models.school import School
from app.models.parent_login_sequence import ParentLoginSequence
from app.services.identity_provisioning import IdentityProvisioningService

async def migrate_parents():
    async with AsyncSessionLocal() as db:
        print("Starting parent migration...")
        
        # 1. Fetch all parent roles to get their users
        stmt_parents = select(User).join(User.roles).where(
            Role.code == "PARENT",
            User.deleted_at.is_(None)
        ).options(
            selectinload(User.schools),
            selectinload(User.roles)
        )
        res = await db.execute(stmt_parents)
        parents = res.scalars().all()
        
        parents_inspected = len(parents)
        parents_migrated = 0
        already_migrated = 0
        failed = 0
        duplicate_conflicts = 0
        
        provision_service = IdentityProvisioningService(db)
        
        for parent in parents:
            if parent.login_id:
                already_migrated += 1
                continue
                
            # Determine school
            if not parent.schools:
                print(f"Parent '{parent.first_name} {parent.last_name}' (ID: {parent.id}) has no school mapping. Skipping.")
                failed += 1
                continue
                
            school = parent.schools[0]
            if not school.code or not school.code.strip():
                print(f"School '{school.name}' has no school code. Skipping parent ID generation.")
                failed += 1
                continue
                
            try:
                # Generate and allocate sequence-based Login ID
                login_id = await provision_service._generate_parent_login_id(parent.tenant_id, school.id, school.code)
                
                # Check for duplicate conflicts
                stmt_dup = select(User).where(
                    User.tenant_id == parent.tenant_id,
                    User.login_id == login_id
                )
                res_dup = await db.execute(stmt_dup)
                if res_dup.scalar_one_or_none():
                    print(f"Conflict: generated ID {login_id} already exists. Skipping.")
                    duplicate_conflicts += 1
                    continue
                
                parent.login_id = login_id
                db.add(parent)
                parents_migrated += 1
                print(f"Migrated parent {parent.email} -> {login_id}")
            except Exception as e:
                print(f"Failed to migrate parent {parent.email}: {e}")
                failed += 1
                
        await db.commit()
        
        print("\nMigration Complete Summary:")
        print(f"Parents inspected: {parents_inspected}")
        print(f"Parents migrated: {parents_migrated}")
        print(f"Already migrated: {already_migrated}")
        print(f"Failed: {failed}")
        print(f"Duplicate conflicts: {duplicate_conflicts}")

if __name__ == "__main__":
    asyncio.run(migrate_parents())
