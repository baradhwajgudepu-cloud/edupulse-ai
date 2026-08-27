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
from app.models.user import User
from app.models.teacher import Teacher
from app.models.class_entity import Class
from app.models.section import Section
from app.models.subject import Subject
from app.models.teacher_subject_assignment import TeacherSubjectAssignment

async def main():
    target_tenant_id = uuid.UUID("09f2d4e7-2877-4e42-9e95-e97d52775687")
    target_school_id = uuid.UUID("55b95edf-c227-45fa-a225-c2d3366eba25")
    teacher_email = "teacher.t101@edupulse.local"
    
    print("\n=== UAT TEACHER DATABASE VERIFICATION ===")
    async with AsyncSessionLocal() as session:
        # 1. Verify User Account
        res_usr = await session.execute(
            select(User)
            .where(User.tenant_id == target_tenant_id, User.email == teacher_email)
            .options(selectinload(User.roles), selectinload(User.schools))
        )
        user = res_usr.scalar_one_or_none()
        if not user:
            print("[-] USER ACCOUNT: NOT FOUND")
            return
        
        print(f"[+] USER ACCOUNT: EXISTS (ID: {user.id})")
        print(f"[+] EMAIL: {user.email}")
        
        # Verify Tenant
        if user.tenant_id == target_tenant_id:
            print(f"[+] TENANT MATCH: YES ({user.tenant_id})")
        else:
            print(f"[-] TENANT MATCH: NO (Found: {user.tenant_id})")
            
        # Verify Role
        role_codes = {r.code for r in user.roles}
        if "TEACHER" in role_codes:
            print("[+] ROLE 'TEACHER': ASSIGNED")
        else:
            print(f"[-] ROLE 'TEACHER': NOT ASSIGNED (Found roles: {role_codes})")
            
        # Verify School
        school_ids = {s.id for s in user.schools}
        if target_school_id in school_ids:
            print(f"[+] SCHOOL MAPPING: VERIFIED (Mapped to: {target_school_id})")
        else:
            print(f"[-] SCHOOL MAPPING: FAILED (Mapped schools: {school_ids})")

        # 2. Verify Teacher Profile
        res_tch = await session.execute(
            select(Teacher).where(
                Teacher.school_id == target_school_id,
                Teacher.official_email == teacher_email
            )
        )
        teacher_profile = res_tch.scalar_one_or_none()
        if not teacher_profile:
            print("[-] TEACHER PROFILE: NOT FOUND")
            return
            
        print(f"[+] TEACHER PROFILE: EXISTS (ID: {teacher_profile.id})")
        print(f"[+] LINKED USER ID MATCH: {'YES' if teacher_profile.user_id == user.id else 'NO'}")

        # 3. Verify Class & Section
        res_cl = await session.execute(
            select(Class).where(
                Class.school_id == target_school_id,
                Class.code == "GRADE_10"
            )
        )
        class_obj = res_cl.scalar_one_or_none()
        if class_obj:
            print(f"[+] CLASS 'Grade 10': EXISTS (ID: {class_obj.id})")
            
            res_sec = await session.execute(
                select(Section).where(
                    Section.school_id == target_school_id,
                    Section.class_id == class_obj.id,
                    Section.name == "A"
                )
            )
            section_obj = res_sec.scalar_one_or_none()
            if section_obj:
                print(f"[+] SECTION 'A': EXISTS (ID: {section_obj.id})")
            else:
                print("[-] SECTION 'A': NOT FOUND")
                section_obj = None
        else:
            print("[-] CLASS 'Grade 10': NOT FOUND")
            class_obj = None
            section_obj = None

        # 4. Verify Subject
        res_sub = await session.execute(
            select(Subject).where(
                Subject.school_id == target_school_id,
                Subject.subject_code == "SUB_MATH_10"
            )
        )
        subject_obj = res_sub.scalar_one_or_none()
        if subject_obj:
            print(f"[+] SUBJECT 'Mathematics': EXISTS (ID: {subject_obj.id})")
        else:
            print("[-] SUBJECT 'Mathematics': NOT FOUND")
            subject_obj = None

        # 5. Verify Teacher Subject Assignment
        if teacher_profile and class_obj and section_obj and subject_obj:
            res_assign = await session.execute(
                select(TeacherSubjectAssignment).where(
                    TeacherSubjectAssignment.school_id == target_school_id,
                    TeacherSubjectAssignment.teacher_id == teacher_profile.id,
                    TeacherSubjectAssignment.class_id == class_obj.id,
                    TeacherSubjectAssignment.section_id == section_obj.id,
                    TeacherSubjectAssignment.subject_id == subject_obj.id
                )
            )
            assign = res_assign.scalar_one_or_none()
            if assign:
                print("[+] TEACHER SUBJECT ASSIGNMENT: ACTIVE")
                print(f"[+] CLASS TEACHER ROLE: {'YES' if assign.is_class_teacher else 'NO'}")
            else:
                print("[-] TEACHER SUBJECT ASSIGNMENT: NOT FOUND")

        print("=========================================\n")

if __name__ == "__main__":
    asyncio.run(main())
