import asyncio
import sys
import os
import uuid
from sqlalchemy import select, text
from sqlalchemy.orm import selectinload

# Setup python path to load the application modules correctly
sys.path.append(os.path.abspath(os.path.dirname(__file__) + "/.."))
sys.path.append(os.path.abspath("."))

from app.db.session import AsyncSessionLocal
from app.models.user import User
from app.models.role import Role
from app.models.school import School
from app.models.teacher import Teacher
from app.models.teacher_subject_assignment import TeacherSubjectAssignment

async def main():
    target_tenant_id = uuid.UUID("09f2d4e7-2877-4e42-9e95-e97d52775687")
    target_school_id = uuid.UUID("55b95edf-c227-45fa-a225-c2d3366eba25")
    
    print("=== INSPECTING UAT TEACHERS ===")
    async with AsyncSessionLocal() as session:
        # First query all active users in this tenant
        stmt = (
            select(User)
            .where(User.tenant_id == target_tenant_id, User.deleted_at.is_(None))
            .options(selectinload(User.roles), selectinload(User.schools))
        )
        result = await session.execute(stmt)
        users = result.scalars().all()
        
        print(f"Total Users Found in Tenant: {len(users)}")
        
        for idx, user in enumerate(users):
            print(f"\n--- User {idx + 1} ---")
            print(f"User ID: {user.id}")
            print(f"Email: {user.email}")
            print(f"Status: {user.status}")
            print(f"Roles: {[r.code for r in user.roles]}")
            print(f"Schools: {[s.name for s in user.schools]}")
            
            # Check school mapping
            is_mapped_to_target_school = any(s.id == target_school_id for s in user.schools)
            print(f"Mapped to UAT School: {is_mapped_to_target_school}")
            
            # Check if there is a Teacher profile linked to this User ID
            stmt_profile = select(Teacher).where(Teacher.user_id == user.id, Teacher.deleted_at.is_(None))
            res_profile = await session.execute(stmt_profile)
            profile = res_profile.scalar_one_or_none()
            if profile:
                print(f"Teacher Profile Found! Profile ID: {profile.id} | Code: {profile.employee_number}")
                # Query subject assignments
                stmt_assign = (
                    select(TeacherSubjectAssignment)
                    .where(TeacherSubjectAssignment.teacher_id == profile.id, TeacherSubjectAssignment.deleted_at.is_(None))
                )
                res_assign = await session.execute(stmt_assign)
                assignments = res_assign.scalars().all()
                print(f"Number of subject assignments: {len(assignments)}")
                for a in assignments:
                    print(f"  Assignment: Subject ID {a.subject_id} | Class ID {a.class_id} | Section ID {a.section_id}")
            else:
                print("No Teacher Profile Linked to this User ID.")

if __name__ == "__main__":
    asyncio.run(main())
