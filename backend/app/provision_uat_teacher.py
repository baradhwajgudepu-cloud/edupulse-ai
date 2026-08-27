import asyncio
import sys
import os
import uuid
from datetime import date
from sqlalchemy import select, and_
from sqlalchemy.orm import selectinload

# Setup python path to load the application modules correctly
sys.path.append(os.path.abspath(os.path.dirname(__file__) + "/.."))
sys.path.append(os.path.abspath("."))

from app.db.session import AsyncSessionLocal
from app.models.tenant import Tenant
from app.models.school import School
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.class_entity import Class, ClassStatus, ClassCategory
from app.models.section import Section, SectionStatus
from app.models.subject import Subject, SubjectStatus, SubjectCategory, SubjectType
from app.models.teacher import Teacher, TeacherStatus
from app.models.role import Role, user_roles
from app.models.user import User, UserStatus
from app.models.student import StudentGender
from app.models.teacher_subject_assignment import TeacherSubjectAssignment, AssignmentStatus, AssignmentType
from app.core.security import hash_password, verify_password
from app.services.rbac_provisioning import ensure_tenant_rbac

async def main():
    target_tenant_id = uuid.UUID("09f2d4e7-2877-4e42-9e95-e97d52775687")
    target_school_id = uuid.UUID("55b95edf-c227-45fa-a225-c2d3366eba25")
    target_ay_id = uuid.UUID("70892ebc-432c-4d02-80a3-b855e7d441c8")
    
    teacher_email = "teacher.t101@edupulse.local"
    uat_password = "LocalUat@123"
    
    print("=== UAT TEACHER PROVISIONING START ===")
    async with AsyncSessionLocal() as session:
        # 1. Verify Tenant & School Context
        res_t = await session.execute(select(Tenant).where(Tenant.id == target_tenant_id))
        tenant = res_t.scalar_one_or_none()
        if not tenant:
            print("Creating UAT Tenant context...")
            res_sub = await session.execute(select(Tenant).where(Tenant.subdomain == "demo"))
            sub_exists = res_sub.scalar_one_or_none()
            subdomain = "demo" if not sub_exists else f"demo-uat-{uuid.uuid4().hex[:4]}"
            tenant = Tenant(
                id=target_tenant_id,
                name="EduPulse Demo Tenant",
                code="DEMO_TENANT",
                subdomain=subdomain,
                email="admin@demo.edupulse.local"
            )
            session.add(tenant)
            await session.flush()
        print(f"Verified Tenant: {tenant.name} ({tenant.code})")

        res_sc = await session.execute(select(School).where(School.id == target_school_id, School.tenant_id == target_tenant_id))
        school = res_sc.scalar_one_or_none()
        if not school:
            print("Creating UAT School context...")
            school = School(
                id=target_school_id,
                tenant_id=target_tenant_id,
                name="EduPulse Demo High School",
                code="DEMO",
                board="CBSE",
                school_type="HIGH_SCHOOL",
                email="demo@edupulse.local"
            )
            session.add(school)
            await session.flush()
        print(f"Verified School: {school.name} ({school.code})")

        # 2. Verify Academic Year
        res_ay = await session.execute(select(AcademicYear).where(AcademicYear.id == target_ay_id, AcademicYear.school_id == target_school_id))
        ay = res_ay.scalar_one_or_none()
        if not ay:
            print("Creating UAT Academic Year...")
            ay = AcademicYear(
                id=target_ay_id,
                tenant_id=target_tenant_id,
                school_id=target_school_id,
                name="2026-2027",
                code="AY2026-2027",
                start_date=date(2026, 6, 1),
                end_date=date(2027, 4, 30),
                status=AcademicYearStatus.ACTIVE,
                is_current=True
            )
            session.add(ay)
            await session.flush()
        print(f"Verified Academic Year: {ay.name} ({ay.code})")

        # Ensure Role and permissions are synced in the tenant
        print("Ensuring RBAC permissions synced...")
        await ensure_tenant_rbac(session, target_tenant_id)
        
        # Fetch TEACHER role
        res_role = await session.execute(
            select(Role).where(
                Role.tenant_id == target_tenant_id,
                Role.code == "TEACHER",
                Role.deleted_at.is_(None)
            )
        )
        teacher_role = res_role.scalar_one_or_none()
        if not teacher_role:
            print("Creating default TEACHER role...")
            teacher_role = Role(
                tenant_id=target_tenant_id,
                name="Teacher",
                code="TEACHER",
                is_system=True,
                version=1
            )
            session.add(teacher_role)
            await session.flush()
        print(f"TEACHER Role Verified: {teacher_role.id}")

        # 3. Create Class: Grade 10
        res_cl = await session.execute(
            select(Class).where(
                Class.school_id == target_school_id,
                Class.academic_year_id == target_ay_id,
                Class.code == "GRADE_10"
            )
        )
        class_obj = res_cl.scalar_one_or_none()
        if not class_obj:
            print("Creating Class: Grade 10...")
            class_obj = Class(
                id=uuid.uuid4(),
                tenant_id=target_tenant_id,
                school_id=target_school_id,
                academic_year_id=target_ay_id,
                name="Grade 10",
                display_name="Grade 10",
                code="GRADE_10",
                level=10,
                category=ClassCategory.HIGH,
                capacity=40,
                status=ClassStatus.ACTIVE,
                is_active=True,
                version=1
            )
            session.add(class_obj)
            await session.flush()
        print(f"Class Verified: {class_obj.name} ({class_obj.id})")

        # 4. Create Section: Section A
        res_sec = await session.execute(
            select(Section).where(
                Section.school_id == target_school_id,
                Section.academic_year_id == target_ay_id,
                Section.class_id == class_obj.id,
                Section.name == "A"
            )
        )
        section_obj = res_sec.scalar_one_or_none()
        if not section_obj:
            print("Creating Section: Section A...")
            section_obj = Section(
                id=uuid.uuid4(),
                tenant_id=target_tenant_id,
                school_id=target_school_id,
                academic_year_id=target_ay_id,
                class_id=class_obj.id,
                name="A",
                code="GRADE_10_A",
                capacity=40,
                status=SectionStatus.ACTIVE,
                is_active=True,
                version=1
            )
            session.add(section_obj)
            await session.flush()
        print(f"Section Verified: {section_obj.name} ({section_obj.id})")

        # 5. Create Subject: Mathematics
        res_sub = await session.execute(
            select(Subject).where(
                Subject.school_id == target_school_id,
                Subject.subject_code == "SUB_MATH_10"
            )
        )
        subject_obj = res_sub.scalar_one_or_none()
        if not subject_obj:
            print("Creating Subject: Mathematics...")
            subject_obj = Subject(
                id=uuid.uuid4(),
                tenant_id=target_tenant_id,
                school_id=target_school_id,
                academic_year_id=target_ay_id,
                subject_name="Mathematics",
                subject_code="SUB_MATH_10",
                description="Grade 10 Mathematics",
                category=SubjectCategory.CORE,
                subject_type=SubjectType.THEORY,
                status=SubjectStatus.ACTIVE,
                is_active=True,
                version=1
            )
            session.add(subject_obj)
            await session.flush()
        print(f"Subject Verified: {subject_obj.subject_name} ({subject_obj.id})")

        # 6. Verify or Create Teacher Profile
        res_tch = await session.execute(
            select(Teacher).where(
                Teacher.school_id == target_school_id,
                Teacher.official_email == teacher_email
            )
        )
        teacher_profile = res_tch.scalar_one_or_none()
        if not teacher_profile:
            print("Creating Teacher Profile...")
            teacher_profile = Teacher(
                id=uuid.uuid4(),
                tenant_id=target_tenant_id,
                school_id=target_school_id,
                employee_code="T101",
                staff_code="ST_101",
                first_name="UAT",
                last_name="Teacher",
                gender=StudentGender.MALE,
                date_of_birth=date(1990, 1, 1),
                mobile="+919876543201",
                official_email=teacher_email,
                joining_date=date(2025, 6, 1),
                employment_type="FULL_TIME",
                status=TeacherStatus.ACTIVE,
                is_active=True,
                version=1
            )
            session.add(teacher_profile)
            await session.flush()
        print(f"Teacher Profile Verified: {teacher_profile.first_name} {teacher_profile.last_name} ({teacher_profile.id})")

        # 7. Verify or Create User Account
        res_usr = await session.execute(
            select(User)
            .where(User.tenant_id == target_tenant_id, User.email == teacher_email)
            .options(selectinload(User.roles), selectinload(User.schools))
        )
        user = res_usr.scalar_one_or_none()
        if not user:
            print("Creating Teacher User Account...")
            hashed = hash_password(uat_password)
            user = User(
                id=uuid.uuid4(),
                email=teacher_email,
                hashed_password=hashed,
                first_name="UAT",
                last_name="Teacher",
                status=UserStatus.ACTIVE,
                is_superuser=False,
                must_change_password=False,
                tenant_id=target_tenant_id,
                version=1
            )
            user.roles.append(teacher_role)
            user.schools.append(school)
            session.add(user)
            await session.flush()
        else:
            print("Teacher User Account already exists. Resetting password...")
            user.hashed_password = hash_password(uat_password)
            user.must_change_password = False
            if teacher_role not in user.roles:
                user.roles.append(teacher_role)
            if school not in user.schools:
                user.schools.append(school)
            session.add(user)
            await session.flush()
        
        # Link User ID to Teacher Profile
        if teacher_profile.user_id != user.id:
            teacher_profile.user_id = user.id
            session.add(teacher_profile)
            await session.flush()
            
        print(f"User Account Verified: {user.email} (ID={user.id}) | Linked={teacher_profile.user_id == user.id}")

        # 8. Create Teacher-Subject-Class Assignment
        res_assign = await session.execute(
            select(TeacherSubjectAssignment).where(
                TeacherSubjectAssignment.school_id == target_school_id,
                TeacherSubjectAssignment.academic_year_id == target_ay_id,
                TeacherSubjectAssignment.teacher_id == teacher_profile.id,
                TeacherSubjectAssignment.class_id == class_obj.id,
                TeacherSubjectAssignment.section_id == section_obj.id,
                TeacherSubjectAssignment.subject_id == subject_obj.id
            )
        )
        assign = res_assign.scalar_one_or_none()
        if not assign:
            print("Creating Teacher Subject Assignment...")
            assign = TeacherSubjectAssignment(
                id=uuid.uuid4(),
                tenant_id=target_tenant_id,
                school_id=target_school_id,
                academic_year_id=target_ay_id,
                teacher_id=teacher_profile.id,
                class_id=class_obj.id,
                section_id=section_obj.id,
                subject_id=subject_obj.id,
                assignment_type=AssignmentType.PRIMARY,
                weekly_periods=5,
                effective_from=date(2026, 6, 1),
                is_class_teacher=True,
                status=AssignmentStatus.ACTIVE,
                version=1
            )
            session.add(assign)
            await session.flush()
        print(f"Teacher Assignment Verified: Subject={subject_obj.subject_name} | Class={class_obj.name} | Section={section_obj.name}")

        await session.commit()
        print("=== UAT TEACHER PROVISIONING SUCCESSFUL ===")
        print(f"EMAIL: {user.email}")
        print(f"TENANT: {target_tenant_id}")
        print(f"SCHOOL: {target_school_id}")
        print("==========================================")

if __name__ == "__main__":
    asyncio.run(main())
