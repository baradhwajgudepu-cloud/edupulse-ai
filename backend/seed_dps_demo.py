import asyncio
import uuid
import random
import logging
from datetime import date, datetime, time as datetime_time, timezone
from decimal import Decimal
from sqlalchemy import text, select, and_, or_, func
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

from app.core.settings import settings
from app.core.security import hash_password
from app.models.tenant import Tenant, TenantStatus
from app.models.school import School, SchoolStatus
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.class_entity import Class, ClassStatus, ClassCategory
from app.models.section import Section, SectionStatus
from app.models.subject import Subject, SubjectStatus, SubjectCategory, SubjectType
from app.models.teacher import Teacher, TeacherStatus
from app.models.guardian import Guardian, GuardianStatus, GuardianType, StudentGuardianRelationship, StudentGuardian
from app.models.student import Student, StudentStatus, StudentGender
from app.models.teacher_subject_assignment import TeacherSubjectAssignment, AssignmentStatus, AssignmentType
from app.models.timetable import Timetable, TimetableStatus, DayOfWeek, PeriodType
from app.models.syllabus import Syllabus
from app.models.examination import Examination, ExamStatus, ExamType, ExamSchedule
from app.models.marks import Marks, MarksStatus, ExamResult
from app.models.attendance import AttendanceSession, AttendanceSessionStatus, Attendance, AttendanceStatus, AttendanceSource, AttendanceReason
from app.models.fee import FeeType, FeeStructure, StudentFeeAssignment, FeeAssignmentStatus
from app.models.report_card import ReportCardPublication, ReportCardStatus
from app.models.user import User, UserStatus

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

DATABASE_URL = settings.DATABASE_URL
DPS_TENANT_ID = uuid.UUID("e949f0ba-2f9e-495b-a3b0-8f672070746a")
DPS_SCHOOL_ID = uuid.UUID("2f85ebf4-315d-496a-9611-681ff0fed18f")

async def main():
    engine = create_async_engine(DATABASE_URL, echo=False)

    AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    
    async with AsyncSessionLocal() as session:
        # Phase 3: Verify or Create DPS Context
        logger.info("PHASE 3: Verifying or Creating DPS Tenant and School Context...")
        res = await session.execute(
            select(Tenant).where(Tenant.id == DPS_TENANT_ID)
        )
        tenant = res.scalar_one_or_none()
        if not tenant:
            logger.info("DPS Tenant not found. Creating Delhi Public School Hyderabad...")
            tenant = Tenant(
                id=DPS_TENANT_ID,
                name="Delhi Public School Hyderabad",
                code="DPS001",
                subdomain="dps",
                email="admin@dps.edupulse.com"
            )
            session.add(tenant)
            await session.flush()

        res = await session.execute(
            select(School).where(School.id == DPS_SCHOOL_ID, School.tenant_id == DPS_TENANT_ID)
        )
        school = res.scalar_one_or_none()
        if not school:
            logger.info("DPS School not found. Creating Delhi Public School Hyderabad - Campus 2...")
            school = School(
                id=DPS_SCHOOL_ID,
                tenant_id=DPS_TENANT_ID,
                name="Delhi Public School Hyderabad - Campus 2",
                code="DPSH002",
                board="CBSE",
                school_type="HIGH_SCHOOL",
                email="dps@edupulse.com"
            )
            session.add(school)
            await session.flush()
            
        logger.info(f"DPS Context Verified: Tenant '{tenant.name}', School '{school.name}'")


        # Configure School Geofence coordinates (Development/Testing defaults) if not already set
        if school.latitude is None or school.longitude is None:
            school.latitude = 17.4485
            school.longitude = 78.3741
            school.geofence_radius_meters = 100
            session.add(school)

        # Get Admin User ID for audit tracking
        res_adm = await session.execute(
            select(User.id).where(User.email == "admin@edupulse.com")
        )
        admin_user_id = res_adm.scalar()
        if not admin_user_id:
            logger.error("Admin user admin@edupulse.com not found in DB! Stopping.")
            return

        # Phase 4: Academic Year Verification & Date Correction
        logger.info("PHASE 4: Setting up Academic Year...")
        res_ay = await session.execute(
            select(AcademicYear).where(
                AcademicYear.school_id == DPS_SCHOOL_ID, 
                AcademicYear.code == "AY2025-2026"
            )
        )
        ay = res_ay.scalar_one_or_none()
        if ay:
            logger.info("Academic Year AY2025-2026 already exists. Reusing and updating dates.")
            ay.start_date = date(2025, 6, 1)
            ay.end_date = date(2026, 4, 30)
            ay.status = AcademicYearStatus.ACTIVE
            ay.is_current = True
            session.add(ay)
        else:
            logger.info("Academic Year AY2025-2026 not found. Creating it.")
            ay = AcademicYear(
                id=uuid.uuid4(),
                tenant_id=DPS_TENANT_ID,
                school_id=DPS_SCHOOL_ID,
                name="2025-26",
                code="AY2025-2026",
                start_date=date(2025, 6, 1),
                end_date=date(2026, 4, 30),
                status=AcademicYearStatus.ACTIVE,
                is_current=True,
                version=1
            )
            session.add(ay)
        
        await session.flush()
        ay_id = ay.id

        # Phase 5: Classes Setup (Class 1 to 12)
        logger.info("PHASE 5: Setting up Classes...")
        classes = {}
        for level in range(1, 13):
            class_name = f"Class {level}"
            res_cls = await session.execute(
                select(Class).where(
                    Class.school_id == DPS_SCHOOL_ID, 
                    Class.academic_year_id == ay_id,
                    Class.name == class_name
                )
            )
            cls_obj = res_cls.scalar_one_or_none()
            if cls_obj:
                logger.info(f"Class '{class_name}' already exists. Reusing.")
            else:
                category = ClassCategory.PRIMARY
                if level > 5 and level <= 8:
                    category = ClassCategory.MIDDLE
                elif level > 8 and level <= 10:
                    category = ClassCategory.HIGH
                elif level > 10:
                    category = ClassCategory.HIGHER_SECONDARY
                    
                cls_obj = Class(
                    id=uuid.uuid4(),
                    tenant_id=DPS_TENANT_ID,
                    school_id=DPS_SCHOOL_ID,
                    academic_year_id=ay_id,
                    name=class_name,
                    display_name=class_name,
                    code=f"CLASS_{level}",
                    level=level,
                    category=category,
                    capacity=60,
                    status=ClassStatus.ACTIVE,
                    is_active=True,
                    version=1
                )
                session.add(cls_obj)
            classes[level] = cls_obj
            
        await session.flush()

        # Phase 6: Sections Setup (A and B for every Class)
        logger.info("PHASE 6: Setting up Sections...")
        sections = {}
        for level, cls_obj in classes.items():
            sections[level] = []
            for sec_name in ["A", "B"]:
                res_sec = await session.execute(
                    select(Section).where(
                        Section.school_id == DPS_SCHOOL_ID,
                        Section.academic_year_id == ay_id,
                        Section.class_id == cls_obj.id,
                        Section.name == sec_name
                    )
                )
                sec_obj = res_sec.scalar_one_or_none()
                if sec_obj:
                    logger.info(f"Section '{sec_name}' for Class {level} already exists. Reusing.")
                else:
                    sec_obj = Section(
                        id=uuid.uuid4(),
                        tenant_id=DPS_TENANT_ID,
                        school_id=DPS_SCHOOL_ID,
                        academic_year_id=ay_id,
                        class_id=cls_obj.id,
                        name=sec_name,
                        code=f"{cls_obj.code}_SEC_{sec_name}",
                        capacity=30,
                        status=SectionStatus.ACTIVE,
                        is_active=True,
                        version=1
                    )
                    session.add(sec_obj)
                sections[level].append(sec_obj)
                
        await session.flush()

        # Phase 7: Subjects Setup
        logger.info("PHASE 7: Setting up Subjects...")
        # Define subjects list
        subject_names = [
            "English", "Hindi", "Mathematics", "EVS", "Science", "Social Science", 
            "Computer Science", "General Knowledge", "Physical Education",
            "English Core", "Physics", "Chemistry", "Biology", "Economics", 
            "Accountancy", "Business Studies", "Political Science"
        ]
        
        subjects = {}
        for sub_name in subject_names:
            res_sub = await session.execute(
                select(Subject).where(
                    Subject.school_id == DPS_SCHOOL_ID,
                    Subject.academic_year_id == ay_id,
                    Subject.subject_name == sub_name
                )
            )
            sub_obj = res_sub.scalar_one_or_none()
            if sub_obj:
                logger.info(f"Subject '{sub_name}' already exists. Reusing.")
            else:
                cat = SubjectCategory.CORE
                if sub_name in ["Physical Education", "General Knowledge"]:
                    cat = SubjectCategory.CO_CURRICULAR
                elif sub_name in ["Computer Science"]:
                    cat = SubjectCategory.LAB
                
                sub_obj = Subject(
                    id=uuid.uuid4(),
                    tenant_id=DPS_TENANT_ID,
                    school_id=DPS_SCHOOL_ID,
                    academic_year_id=ay_id,
                    subject_name=sub_name,
                    subject_code=f"SUB_{sub_name[:4].upper()}",
                    category=cat,
                    subject_type=SubjectType.THEORY if sub_name != "Computer Science" else SubjectType.THEORY_PRACTICAL,
                    theory_marks=100 if sub_name != "Computer Science" else 70,
                    practical_marks=0 if sub_name != "Computer Science" else 30,
                    pass_marks=40,
                    status=SubjectStatus.ACTIVE,
                    is_active=True,
                    version=1
                )
                session.add(sub_obj)
            subjects[sub_name] = sub_obj
            
        await session.flush()

        # Define class-to-subject mappings
        def get_subjects_for_level(level):
            if level <= 5:
                return ["English", "Hindi", "Mathematics", "EVS", "Computer Science", "General Knowledge", "Physical Education"]
            elif level <= 8:
                return ["English", "Hindi", "Mathematics", "Science", "Social Science", "Computer Science", "Physical Education"]
            elif level <= 10:
                return ["English", "Hindi", "Mathematics", "Science", "Social Science", "Computer Science"]
            else:
                # Level 11, 12
                return ["English Core", "Physics", "Chemistry", "Mathematics", "Biology", "Computer Science", "Economics", "Accountancy", "Business Studies", "Political Science", "Physical Education"]

        # Phase 8: Synthetic Teachers Setup (40 teachers)
        logger.info("PHASE 8: Setting up Synthetic Teachers...")
        first_names = [
            "Ananya", "Rahul", "Priya", "Arjun", "Neha", "Amit", "Rohan", "Siddharth", "Shreya", "Karan", 
            "Aditi", "Sanjay", "Vikram", "Divya", "Aarav", "Ishaan", "Kavya", "Riya", "Varun", "Meera", 
            "Sunita", "Rajesh", "Deepak", "Kiran", "Manish", "Pooja", "Suresh", "Swati", "Vijay", "Anjali", 
            "Geetha", "Harish", "Kartik", "Lata", "Madhav", "Nisha", "Preeti", "Ramesh", "Sunil", "Tara"
        ]
        last_names = [
            "Sharma", "Mehta", "Nair", "Kapoor", "Sen", "Gupta", "Joshi", "Patel", "Reddy", "Choudhury", 
            "Rao", "Verma", "Mishra", "Bose", "Singh", "Kumar", "Das", "Menon", "Pillai", "Trivedi"
        ]
        
        teachers = []
        for i in range(1, 41):
            emp_code = f"DPSH_EMP_{i:03d}"
            res_tch = await session.execute(
                select(Teacher).where(
                    Teacher.school_id == DPS_SCHOOL_ID,
                    Teacher.employee_code == emp_code
                )
            )
            tch_obj = res_tch.scalar_one_or_none()
            if tch_obj:
                logger.info(f"Teacher '{emp_code}' already exists. Reusing.")
            else:
                f_name = first_names[(i - 1) % len(first_names)]
                l_name = last_names[(i - 1) % len(last_names)]
                tch_obj = Teacher(
                    id=uuid.uuid4(),
                    tenant_id=DPS_TENANT_ID,
                    school_id=DPS_SCHOOL_ID,
                    employee_code=emp_code,
                    staff_code=f"DPSH_ST_{i:03d}",
                    first_name=f_name,
                    last_name=l_name,
                    gender=StudentGender.FEMALE if i % 2 == 0 else StudentGender.MALE,
                    date_of_birth=date(1980 + (i % 15), 5, 10),
                    mobile=f"+9198765432{i:02d}",
                    official_email=f"teacher{i:03d}@demo.edupulse.local",
                    joining_date=date(2018 + (i % 5), 6, 1),
                    employment_type="FULL_TIME",
                    status=TeacherStatus.ACTIVE,
                    is_active=True,
                    version=1
                )
                session.add(tch_obj)
            teachers.append(tch_obj)
            
        await session.flush()

        # Phase 9: Synthetic Students Setup (15 students per section = 360 students)
        logger.info("PHASE 9: Setting up Synthetic Students...")
        students = []
        stud_names_first = [
            "Aarav", "Vihaan", "Aditya", "Sai", "Arjun", "Krishna", "Ananya", "Diya", "Ishaan", "Kavya", 
            "Riya", "Aditi", "Siddharth", "Pranav", "Rahul", "Neha", "Karan", "Rohan", "Swati", "Pooja", 
            "Varun", "Vikram", "Divya", "Aaryan", "Kunal", "Tanvi", "Sanya", "Maya", "Ishita", "Yash", 
            "Abhishek", "Sneha", "Preeti", "Rakesh", "Harish", "Nikhil", "Shruti", "Meera", "Geetha", "Lata"
        ]
        stud_names_last = [
            "Sharma", "Reddy", "Patel", "Joshi", "Verma", "Gupta", "Mishra", "Bose", "Singh", "Kumar", 
            "Das", "Menon", "Pillai", "Rao", "Choudhury", "Soni", "Trivedi", "Mehta", "Bhat", "Dube"
        ]
        
        stud_idx = 0
        for level in range(1, 13):
            cls_obj = classes[level]
            for sec_obj in sections[level]:
                for idx in range(1, 16):
                    stud_idx += 1
                    adm_num = f"DPSH_2025_C{level}{sec_obj.name}_{idx:02d}"
                    res_stud = await session.execute(
                        select(Student).where(
                            Student.school_id == DPS_SCHOOL_ID,
                            Student.academic_year_id == ay_id,
                            Student.admission_number == adm_num
                        )
                    )
                    stud_obj = res_stud.scalar_one_or_none()
                    if stud_obj:
                        logger.info(f"Student '{adm_num}' already exists. Reusing.")
                    else:
                        f_name = stud_names_first[(stud_idx - 1) % len(stud_names_first)]
                        l_name = stud_names_last[(stud_idx - 1) % len(stud_names_last)]
                        stud_obj = Student(
                            id=uuid.uuid4(),
                            tenant_id=DPS_TENANT_ID,
                            school_id=DPS_SCHOOL_ID,
                            academic_year_id=ay_id,
                            class_id=cls_obj.id,
                            section_id=sec_obj.id,
                            admission_number=adm_num,
                            roll_number=str(idx),
                            first_name=f"Demo {f_name}",
                            last_name=l_name,
                            gender=StudentGender.MALE if idx % 2 != 0 else StudentGender.FEMALE,
                            date_of_birth=date(2020 - level, 5, 15),
                            admission_date=date(2023, 6, 1),
                            email=f"student{stud_idx:03d}@demo.edupulse.local",
                            mobile=f"+919900000{stud_idx:03d}",
                            status=StudentStatus.ACTIVE,
                            is_active=True,
                            version=1
                        )
                        session.add(stud_obj)
                    students.append(stud_obj)
                    
        await session.flush()

        # Phase 10: Synthetic Guardians Setup
        logger.info("PHASE 10: Setting up Guardians and Parent Links...")
        guardians = []
        for i, stud in enumerate(students, start=1):
            res_sg = await session.execute(
                select(StudentGuardian).where(
                    StudentGuardian.student_id == stud.id
                )
            )
            sg_link = res_sg.scalar_one_or_none()
            if sg_link:
                logger.info(f"Guardian link for student '{stud.admission_number}' already exists. Reusing.")
            else:
                g_mobile = f"+919888800{i:03d}"
                res_gd = await session.execute(
                    select(Guardian).where(
                        Guardian.tenant_id == DPS_TENANT_ID,
                        Guardian.mobile == g_mobile
                    )
                )
                gd_obj = res_gd.scalar_one_or_none()
                if not gd_obj:
                    gd_obj = Guardian(
                        id=uuid.uuid4(),
                        tenant_id=DPS_TENANT_ID,
                        school_id=DPS_SCHOOL_ID,
                        guardian_type=GuardianType.FATHER if i % 2 != 0 else GuardianType.MOTHER,
                        first_name=f"Parent {stud.first_name.split()[-1]}",
                        last_name=stud.last_name,
                        gender=StudentGender.MALE if i % 2 != 0 else StudentGender.FEMALE,
                        date_of_birth=date(1975 + (i % 15), 3, 20),
                        mobile=g_mobile,
                        email=f"guardian{i:03d}@demo.edupulse.local",
                        status=GuardianStatus.ACTIVE,
                        is_active=True,
                        version=1
                    )
                    session.add(gd_obj)
                    await session.flush()
                
                sg_link = StudentGuardian(
                    id=uuid.uuid4(),
                    tenant_id=DPS_TENANT_ID,
                    school_id=DPS_SCHOOL_ID,
                    student_id=stud.id,
                    guardian_id=gd_obj.id,
                    relationship=StudentGuardianRelationship.FATHER if i % 2 != 0 else StudentGuardianRelationship.MOTHER,
                    is_primary=True,
                    can_pickup_student=True,
                    receives_notifications=True,
                    version=1
                )
                session.add(sg_link)
                
        await session.flush()

        # Phase 11: Teacher Assignments
        logger.info("PHASE 11: Setting up Teacher Subject Assignments...")
        tsas = {}
        for level in range(1, 13):
            cls_obj = classes[level]
            sub_names = get_subjects_for_level(level)
            for sec_obj in sections[level]:
                tsas[(level, sec_obj.name)] = []
                for sub_idx, s_name in enumerate(sub_names):
                    sub_obj = subjects[s_name]
                    # Dynamically assign teacher
                    teacher_idx = (level * 7 + sub_idx) % 40
                    teacher_obj = teachers[teacher_idx]
                    
                    res_tsa = await session.execute(
                        select(TeacherSubjectAssignment).where(
                            TeacherSubjectAssignment.school_id == DPS_SCHOOL_ID,
                            TeacherSubjectAssignment.academic_year_id == ay_id,
                            TeacherSubjectAssignment.class_id == cls_obj.id,
                            TeacherSubjectAssignment.section_id == sec_obj.id,
                            TeacherSubjectAssignment.subject_id == sub_obj.id
                        )
                    )
                    tsa_obj = res_tsa.scalar_one_or_none()
                    if tsa_obj:
                        logger.info(f"Assignment for Class {level}{sec_obj.name} -> {s_name} already exists. Reusing.")
                    else:
                        tsa_obj = TeacherSubjectAssignment(
                            id=uuid.uuid4(),
                            tenant_id=DPS_TENANT_ID,
                            school_id=DPS_SCHOOL_ID,
                            academic_year_id=ay_id,
                            class_id=cls_obj.id,
                            section_id=sec_obj.id,
                            subject_id=sub_obj.id,
                            teacher_id=teacher_obj.id,
                            assignment_type=AssignmentType.PRIMARY,
                            weekly_periods=5,
                            effective_from=date(2025, 6, 1),
                            status=AssignmentStatus.ACTIVE,
                            is_class_teacher=True if sub_idx == 0 else False,
                            is_active=True,
                            version=1
                        )
                        session.add(tsa_obj)
                    tsas[(level, sec_obj.name)].append(tsa_obj)
                    
        await session.flush()

        # Phase 12: Timetable Setup (Monday-Friday, 7 periods)
        logger.info("PHASE 12: Setting up Timetables...")
        busy_teachers = set()  # Set of (teacher_id, day_of_week, period_number)
        
        # Load existing timetables to mark teachers as busy
        res_tt_all = await session.execute(
            select(Timetable.teacher_id, Timetable.day_of_week, Timetable.period_number).where(
                Timetable.school_id == DPS_SCHOOL_ID,
                Timetable.academic_year_id == ay_id,
                Timetable.teacher_id.is_not(None)
            )
        )
        for r_tt in res_tt_all.all():
            busy_teachers.add((r_tt[0], r_tt[1], r_tt[2]))

        for level in range(1, 13):
            cls_obj = classes[level]
            for sec_obj in sections[level]:
                sec_tsas = tsas[(level, sec_obj.name)]
                for day in [DayOfWeek.MONDAY, DayOfWeek.TUESDAY, DayOfWeek.WEDNESDAY, DayOfWeek.THURSDAY, DayOfWeek.FRIDAY]:
                    # Create 7 periods
                    for p_num in range(1, 8):
                        res_tt = await session.execute(
                            select(Timetable).where(
                                Timetable.school_id == DPS_SCHOOL_ID,
                                Timetable.academic_year_id == ay_id,
                                Timetable.class_id == cls_obj.id,
                                Timetable.section_id == sec_obj.id,
                                Timetable.day_of_week == day,
                                Timetable.period_number == p_num
                            )
                        )
                        tt_obj = res_tt.scalar_one_or_none()
                        if tt_obj:
                            if tt_obj.teacher_id:
                                busy_teachers.add((tt_obj.teacher_id, day, p_num))
                            continue
                        
                        if p_num == 4:
                            # Lunch Break
                            tt_obj = Timetable(
                                id=uuid.uuid4(),
                                tenant_id=DPS_TENANT_ID,
                                school_id=DPS_SCHOOL_ID,
                                academic_year_id=ay_id,
                                class_id=cls_obj.id,
                                section_id=sec_obj.id,
                                day_of_week=day,
                                period_number=p_num,
                                start_time=datetime_time(12, 0),
                                end_time=datetime_time(12, 45),
                                period_type=PeriodType.BREAK,
                                is_available=False,
                                status=TimetableStatus.ACTIVE,
                                is_active=True,
                                version=1
                            )
                        else:
                            # Try to find a teacher for this section who is not busy in this slot
                            assigned_tsa = None
                            # Shuffle or rotate options to distribute subjects
                            rotated_tsas = sec_tsas[(p_num * 3) % len(sec_tsas):] + sec_tsas[:(p_num * 3) % len(sec_tsas)]
                            for tsa in rotated_tsas:
                                if (tsa.teacher_id, day, p_num) not in busy_teachers:
                                    assigned_tsa = tsa
                                    break
                            
                            if assigned_tsa:
                                busy_teachers.add((assigned_tsa.teacher_id, day, p_num))
                                tt_obj = Timetable(
                                    id=uuid.uuid4(),
                                    tenant_id=DPS_TENANT_ID,
                                    school_id=DPS_SCHOOL_ID,
                                    academic_year_id=ay_id,
                                    class_id=cls_obj.id,
                                    section_id=sec_obj.id,
                                    day_of_week=day,
                                    period_number=p_num,
                                    start_time=datetime_time(8 + p_num, 0),
                                    end_time=datetime_time(8 + p_num, 50),
                                    period_type=PeriodType.REGULAR,
                                    teacher_subject_assignment_id=assigned_tsa.id,
                                    teacher_id=assigned_tsa.teacher_id,
                                    subject_id=assigned_tsa.subject_id,
                                    is_available=True,
                                    status=TimetableStatus.ACTIVE,
                                    is_active=True,
                                    version=1
                                )
                            else:
                                # Fall back to LIBRARY or SPORTS period without teacher to avoid collisions
                                tt_obj = Timetable(
                                    id=uuid.uuid4(),
                                    tenant_id=DPS_TENANT_ID,
                                    school_id=DPS_SCHOOL_ID,
                                    academic_year_id=ay_id,
                                    class_id=cls_obj.id,
                                    section_id=sec_obj.id,
                                    day_of_week=day,
                                    period_number=p_num,
                                    start_time=datetime_time(8 + p_num, 0),
                                    end_time=datetime_time(8 + p_num, 50),
                                    period_type=PeriodType.LIBRARY if p_num % 2 == 0 else PeriodType.SPORTS,
                                    is_available=True,
                                    status=TimetableStatus.ACTIVE,
                                    is_active=True,
                                    version=1
                                )
                        session.add(tt_obj)
                        
        await session.flush()

        # Phase 13: Syllabus
        logger.info("PHASE 13: Setting up Syllabus...")
        for level in range(1, 13):
            cls_obj = classes[level]
            sub_names = get_subjects_for_level(level)
            for s_name in sub_names:
                sub_obj = subjects[s_name]
                for unit in range(1, 4):
                    code = f"{sub_obj.subject_code}_U{unit}"
                    res_syl = await session.execute(
                        select(Syllabus).where(
                            Syllabus.academic_year_id == ay_id,
                            Syllabus.class_id == cls_obj.id,
                            Syllabus.subject_id == sub_obj.id,
                            Syllabus.syllabus_code == code
                        )
                    )
                    syl_obj = res_syl.scalar_one_or_none()
                    if not syl_obj:
                        syl_obj = Syllabus(
                            id=uuid.uuid4(),
                            tenant_id=DPS_TENANT_ID,
                            school_id=DPS_SCHOOL_ID,
                            academic_year_id=ay_id,
                            class_id=cls_obj.id,
                            subject_id=sub_obj.id,
                            syllabus_code=code,
                            unit_name=f"Unit {unit} of {s_name}",
                            chapter_name=f"Chapter {unit} - Foundations",
                            topic_name=f"Topic {unit} - Basic & Core Principles",
                            description=f"Description of unit {unit} for class level {level} subject {s_name}",
                            sequence_order=unit,
                            is_active=True,
                            version=1
                        )
                        session.add(syl_obj)
                        
        await session.flush()

        # Phase 14: Examinations Cycle Setup
        logger.info("PHASE 14: Setting up Examinations and Schedules...")
        exams_meta = [
            {"name": "Periodic Test 1", "type": ExamType.UNIT_TEST, "start": date(2025, 7, 10), "end": date(2025, 7, 15)},
            {"name": "Half Yearly Examination", "type": ExamType.HALF_YEARLY, "start": date(2025, 10, 10), "end": date(2025, 10, 15)},
            {"name": "Periodic Test 2", "type": ExamType.UNIT_TEST, "start": date(2025, 12, 10), "end": date(2025, 12, 15)},
            {"name": "Pre Final", "type": ExamType.PRE_FINAL, "start": date(2026, 2, 10), "end": date(2026, 2, 15)},
            {"name": "Annual Examination", "type": ExamType.ANNUAL, "start": date(2026, 3, 20), "end": date(2026, 3, 28)},
        ]
        
        exams_list = []
        for em in exams_meta:
            res_ex = await session.execute(
                select(Examination).where(
                    Examination.school_id == DPS_SCHOOL_ID,
                    Examination.academic_year_id == ay_id,
                    Examination.exam_name == em["name"]
                )
            )
            ex_obj = res_ex.scalar_one_or_none()
            if ex_obj:
                logger.info(f"Examination '{em['name']}' already exists. Reusing.")
            else:
                ex_obj = Examination(
                    id=uuid.uuid4(),
                    tenant_id=DPS_TENANT_ID,
                    school_id=DPS_SCHOOL_ID,
                    academic_year_id=ay_id,
                    exam_name=em["name"],
                    exam_type=em["type"],
                    start_date=em["start"],
                    end_date=em["end"],
                    status=ExamStatus.PUBLISHED,
                    description=f"{em['name']} description",
                    is_active=True,
                    version=1
                )
                session.add(ex_obj)
            exams_list.append(ex_obj)
            
        await session.flush()

        # Create Exam Schedules
        schedules_list = []
        for ex_obj in exams_list:
            for level in range(1, 13):
                cls_obj = classes[level]
                for sec_obj in sections[level]:
                    sec_tsas = tsas[(level, sec_obj.name)]
                    for tsa in sec_tsas:
                        res_sch = await session.execute(
                            select(ExamSchedule).where(
                                ExamSchedule.exam_id == ex_obj.id,
                                ExamSchedule.teacher_subject_assignment_id == tsa.id
                            )
                        )
                        sch_obj = res_sch.scalar_one_or_none()
                        if not sch_obj:
                            sch_obj = ExamSchedule(
                                id=uuid.uuid4(),
                                tenant_id=DPS_TENANT_ID,
                                school_id=DPS_SCHOOL_ID,
                                academic_year_id=ay_id,
                                exam_id=ex_obj.id,
                                class_id=cls_obj.id,
                                section_id=sec_obj.id,
                                subject_id=tsa.subject_id,
                                teacher_subject_assignment_id=tsa.id,
                                exam_date=ex_obj.start_date,
                                start_time=datetime_time(9, 0),
                                end_time=datetime_time(12, 0),
                                max_marks=100,
                                pass_marks=40,
                                is_active=True,
                                version=1
                            )
                            session.add(sch_obj)
                        schedules_list.append(sch_obj)
                        
        await session.flush()

        # Phase 15: Attendance Generation (10 specific dates)
        logger.info("PHASE 15: Setting up Attendance Sessions and Records...")
        dates_list = [
            date(2025, 6, 2), date(2025, 7, 7), date(2025, 8, 4), date(2025, 9, 1),
            date(2025, 10, 6), date(2025, 11, 3), date(2025, 12, 1), date(2026, 1, 5),
            date(2026, 2, 2), date(2026, 3, 2)
        ]
        
        # Cache students grouped by section to speed up loop
        students_by_sec = {}
        for level in range(1, 13):
            for sec_obj in sections[level]:
                res_st = await session.execute(
                    select(Student).where(
                        Student.school_id == DPS_SCHOOL_ID,
                        Student.academic_year_id == ay_id,
                        Student.section_id == sec_obj.id
                    )
                )
                students_by_sec[sec_obj.id] = res_st.scalars().all()

        for att_date in dates_list:
            for level in range(1, 13):
                cls_obj = classes[level]
                for sec_obj in sections[level]:
                    # Find any regular timetable slot for this day to link
                    res_tt = await session.execute(
                        select(Timetable).where(
                            Timetable.school_id == DPS_SCHOOL_ID,
                            Timetable.section_id == sec_obj.id,
                            Timetable.period_type == PeriodType.REGULAR
                        ).limit(1)
                    )
                    tt_row = res_tt.scalar_one_or_none()
                    if not tt_row:
                        continue
                        
                    res_sess = await session.execute(
                        select(AttendanceSession).where(
                            AttendanceSession.school_id == DPS_SCHOOL_ID,
                            AttendanceSession.section_id == sec_obj.id,
                            AttendanceSession.attendance_date == att_date
                        )
                    )
                    sess_obj = res_sess.scalar_one_or_none()
                    if not sess_obj:
                        sess_obj = AttendanceSession(
                            id=uuid.uuid4(),
                            tenant_id=DPS_TENANT_ID,
                            school_id=DPS_SCHOOL_ID,
                            academic_year_id=ay_id,
                            class_id=cls_obj.id,
                            section_id=sec_obj.id,
                            timetable_id=tt_row.id,
                            attendance_date=att_date,
                            status=AttendanceSessionStatus.SUBMITTED,
                            is_active=True,
                            version=1
                        )
                        session.add(sess_obj)
                        await session.flush()
                    
                    sec_students = students_by_sec[sec_obj.id]
                    for stud_idx, stud in enumerate(sec_students):
                        # Verify if record exists
                        res_att = await session.execute(
                            select(Attendance).where(
                                Attendance.attendance_session_id == sess_obj.id,
                                Attendance.student_id == stud.id
                            )
                        )
                        att_obj = res_att.scalar_one_or_none()
                        if not att_obj:
                            # Apply attendance patterns based on student profile index
                            # Toppers (idx 0), improver (idx 2), science/humanities (idx 6, 7), perfect att (idx 5) = 100% present
                            # Normal students = 90% (absent on 1st date)
                            # Decliner student (idx 3) = 80% (absent on 1st and 2nd dates)
                            # High marks poor att (idx 4) = 60% (absent on dates index 0, 2, 4, 6)
                            status_val = AttendanceStatus.PRESENT
                            reason_val = AttendanceReason.UNKNOWN
                            
                            if stud_idx == 4 and att_date in [dates_list[0], dates_list[2], dates_list[4], dates_list[6]]:
                                status_val = AttendanceStatus.ABSENT
                                reason_val = AttendanceReason.PERSONAL
                            elif stud_idx == 3 and att_date in [dates_list[0], dates_list[1]]:
                                status_val = AttendanceStatus.ABSENT
                                reason_val = AttendanceReason.SICK
                            elif stud_idx not in [0, 1, 2, 5, 6, 7] and att_date == dates_list[0]:
                                # General average student absent once
                                status_val = AttendanceStatus.ABSENT
                                reason_val = AttendanceReason.PERSONAL
                                
                            att_obj = Attendance(
                                id=uuid.uuid4(),
                                tenant_id=DPS_TENANT_ID,
                                school_id=DPS_SCHOOL_ID,
                                academic_year_id=ay_id,
                                attendance_session_id=sess_obj.id,
                                student_id=stud.id,
                                timetable_id=tt_row.id,
                                class_id=cls_obj.id,
                                section_id=sec_obj.id,
                                teacher_id=tt_row.teacher_id,
                                subject_id=tt_row.subject_id,
                                attendance_date=att_date,
                                attendance_status=status_val,
                                attendance_source=AttendanceSource.MANUAL,
                                attendance_reason=reason_val,
                                is_active=True,
                                version=1
                            )
                            session.add(att_obj)
                            
        await session.flush()

        # Phase 16: Realistic Marks Seeding (12,600 marks records)
        logger.info("PHASE 16: Setting up Student Marks...")
        # Resolve schedules list to map
        res_all_schedules = await session.execute(
            select(ExamSchedule).where(
                ExamSchedule.school_id == DPS_SCHOOL_ID,
                ExamSchedule.academic_year_id == ay_id
            )
        )
        all_schedules = res_all_schedules.scalars().all()
        
        # Group schedules by class and section to avoid massive inner loops
        sched_by_sec = {}
        for sch in all_schedules:
            sched_by_sec.setdefault((sch.class_id, sch.section_id), []).append(sch)

        marks_to_insert = []
        for level in range(1, 13):
            cls_obj = classes[level]
            for sec_obj in sections[level]:
                sec_students = students_by_sec[sec_obj.id]
                sec_schedules = sched_by_sec.get((cls_obj.id, sec_obj.id), [])
                
                for stud_idx, stud in enumerate(sec_students):
                    for sch in sec_schedules:
                        # Find examination details to apply trends
                        res_ex_detail = await session.execute(
                            select(Examination.exam_name).where(Examination.id == sch.exam_id)
                        )
                        ex_name = res_ex_detail.scalar()
                        
                        # Find subject details
                        res_sub_detail = await session.execute(
                            select(Subject.subject_name).where(Subject.id == sch.subject_id)
                        )
                        sub_name = res_sub_detail.scalar()
                        
                        # Verify duplicate constraint
                        res_mark_exists = await session.execute(
                            select(Marks.id).where(
                                Marks.exam_schedule_id == sch.id,
                                Marks.student_id == stud.id
                            )
                        )
                        m_id = res_mark_exists.scalar()
                        if m_id:
                            continue
                            
                        # Establish marks distribution
                        # Base marks range
                        if stud_idx == 0:
                            # Topper: consistently 92-98%
                            val = random.randint(92, 98)
                        elif stud_idx == 1:
                            # Math specialist / English weak
                            if sub_name == "Mathematics":
                                val = random.randint(95, 98)
                            elif sub_name in ["English", "English Core"]:
                                val = random.randint(35, 45)
                            else:
                                val = random.randint(75, 85)
                        elif stud_idx == 2:
                            # Improver: PT1: 45, Mid: 60, PT2: 75, Pre: 85, Annual: 92
                            if "Periodic Test 1" in ex_name:
                                val = random.randint(43, 47)
                            elif "Half Yearly" in ex_name:
                                val = random.randint(58, 62)
                            elif "Periodic Test 2" in ex_name:
                                val = random.randint(73, 77)
                            elif "Pre Final" in ex_name:
                                val = random.randint(83, 87)
                            else:
                                val = random.randint(90, 94)
                        elif stud_idx == 3:
                            # Decliner: PT1: 88, Mid: 75, PT2: 60, Pre: 48, Annual: 38
                            if "Periodic Test 1" in ex_name:
                                val = random.randint(86, 90)
                            elif "Half Yearly" in ex_name:
                                val = random.randint(73, 77)
                            elif "Periodic Test 2" in ex_name:
                                val = random.randint(58, 62)
                            elif "Pre Final" in ex_name:
                                val = random.randint(46, 50)
                            else:
                                val = random.randint(35, 40)
                        elif stud_idx == 4:
                            # High Marks, Poor Attendance (88-95)
                            val = random.randint(88, 95)
                        elif stud_idx == 5:
                            # High Attendance, Low Marks (32-38)
                            val = random.randint(32, 38)
                        elif stud_idx == 6:
                            # Science Specialist (Physics/Chem/Bio/Science: 94-98, English/Hindi: 50-60)
                            if sub_name in ["Science", "Physics", "Chemistry", "Biology"]:
                                val = random.randint(94, 98)
                            elif sub_name in ["English", "English Core", "Hindi"]:
                                val = random.randint(50, 60)
                            else:
                                val = random.randint(70, 80)
                        elif stud_idx == 7:
                            # Humanities Specialist (Social Science, Hindi, English: 92-96, Mathematics/Science: 45-52)
                            if sub_name in ["Social Science", "Social Studies", "Hindi", "English", "English Core"]:
                                val = random.randint(92, 96)
                            elif sub_name in ["Mathematics", "Science", "Physics", "Chemistry", "Biology"]:
                                val = random.randint(45, 52)
                            else:
                                val = random.randint(70, 80)
                        else:
                            # General distribution: average/strong/developing students
                            p_type = stud_idx % 4
                            if p_type == 0:
                                val = random.randint(75, 90) # Strong
                            elif p_type == 1 or p_type == 2:
                                val = random.randint(60, 84) # Average
                            else:
                                val = random.randint(40, 59) # Developing
                                
                        # Derive grade
                        grade_val = "A+"
                        if val < 40:
                            grade_val = "F"
                        elif val < 50:
                            grade_val = "D"
                        elif val < 60:
                            grade_val = "C"
                        elif val < 70:
                            grade_val = "B"
                        elif val < 80:
                            grade_val = "B+"
                        elif val < 90:
                            grade_val = "A"
                            
                        # Rescale marks obtained based on maximum marks of schedule
                        marks_ob = float(val) * (float(sch.max_marks) / 100.0)
                        
                        m_obj = Marks(
                            id=uuid.uuid4(),
                            tenant_id=DPS_TENANT_ID,
                            school_id=DPS_SCHOOL_ID,
                            academic_year_id=ay_id,
                            examination_id=sch.exam_id,
                            exam_schedule_id=sch.id,
                            student_id=stud.id,
                            teacher_subject_assignment_id=sch.teacher_subject_assignment_id,
                            teacher_id=sch.teacher_subject_assignment.teacher_id,
                            subject_id=sch.subject_id,
                            class_id=cls_obj.id,
                            section_id=sec_obj.id,
                            maximum_marks=sch.max_marks,
                            marks_obtained=Decimal(str(round(marks_ob, 2))),
                            result_status=ExamResult.PRESENT,
                            status=MarksStatus.PUBLISHED,
                            grade=grade_val,
                            remarks="Good performance" if val >= 60 else "Needs improvement",
                            is_active=True,
                            version=1
                        )
                        marks_to_insert.append(m_obj)
                        
        if marks_to_insert:
            logger.info(f"Bulk inserting {len(marks_to_insert)} marks records...")
            # Insert in chunks of 1000 to prevent timeouts/errors
            chunk_size = 1000
            for k in range(0, len(marks_to_insert), chunk_size):
                session.add_all(marks_to_insert[k:k+chunk_size])
                await session.flush()
            logger.info("Marks seeded successfully.")

        # Phase 17: Fees Setup
        logger.info("PHASE 17: Setting up Fees structures and assignments...")
        fee_types_meta = [
            {"name": "Tuition Fee", "code": "FT_TUIT"},
            {"name": "Transport Fee", "code": "FT_TRAN"},
            {"name": "Activity Fee", "code": "FT_ACT"},
            {"name": "Examination Fee", "code": "FT_EXAM"},
            {"name": "Computer Fee", "code": "FT_COMP"},
            {"name": "Annual Charges", "code": "FT_ANN"}
        ]
        
        fee_types = {}
        for ft in fee_types_meta:
            res_ft = await session.execute(
                select(FeeType).where(
                    FeeType.tenant_id == DPS_TENANT_ID,
                    FeeType.code == ft["code"]
                )
            )
            ft_obj = res_ft.scalar_one_or_none()
            if ft_obj:
                logger.info(f"Fee Type '{ft['name']}' already exists. Reusing.")
            else:
                ft_obj = FeeType(
                    id=uuid.uuid4(),
                    tenant_id=DPS_TENANT_ID,
                    name=ft["name"],
                    code=ft["code"],
                    description=f"{ft['name']} description",
                    is_system=False
                )
                session.add(ft_obj)
            fee_types[ft["code"]] = ft_obj
            
        await session.flush()

        # Fee structures per class level
        fee_structures = {}
        for level in range(1, 13):
            cls_obj = classes[level]
            # Primary pays less than senior secondary
            base_tuit = Decimal("2000.00") if level <= 5 else (Decimal("3000.00") if level <= 10 else Decimal("4500.00"))
            
            # Setup Tuition Fee Structure
            res_fs = await session.execute(
                select(FeeStructure).where(
                    FeeStructure.school_id == DPS_SCHOOL_ID,
                    FeeStructure.academic_year_id == ay_id,
                    FeeStructure.class_id == cls_obj.id,
                    FeeStructure.fee_type_id == fee_types["FT_TUIT"].id
                )
            )
            fs_obj = res_fs.scalar_one_or_none()
            if not fs_obj:
                fs_obj = FeeStructure(
                    id=uuid.uuid4(),
                    tenant_id=DPS_TENANT_ID,
                    school_id=DPS_SCHOOL_ID,
                    academic_year_id=ay_id,
                    fee_type_id=fee_types["FT_TUIT"].id,
                    class_id=cls_obj.id,
                    amount=base_tuit,
                    due_date=date(2025, 9, 30),
                    description=f"Tuition Fee structure for Class {level}",
                    version=1
                )
                session.add(fs_obj)
            fee_structures[level] = fs_obj
            
        await session.flush()

        # Student Fee Assignments
        for stud_idx, stud in enumerate(students):
            fs_obj = fee_structures[stud.class_obj.level]
            res_fa = await session.execute(
                select(StudentFeeAssignment).where(
                    StudentFeeAssignment.student_id == stud.id,
                    StudentFeeAssignment.fee_structure_id == fs_obj.id
                )
            )
            fa_obj = res_fa.scalar_one_or_none()
            if not fa_obj:
                # Distribute paid, partial, pending statuses
                status_val = FeeAssignmentStatus.PAID
                paid_val = fs_obj.amount
                if stud_idx % 5 == 0:
                    status_val = FeeAssignmentStatus.UNPAID
                    paid_val = Decimal("0.00")
                elif stud_idx % 5 == 1:
                    status_val = FeeAssignmentStatus.PARTIALLY_PAID
                    paid_val = fs_obj.amount / 2
                    
                fa_obj = StudentFeeAssignment(
                    id=uuid.uuid4(),
                    tenant_id=DPS_TENANT_ID,
                    academic_year_id=ay_id,
                    student_id=stud.id,
                    fee_structure_id=fs_obj.id,
                    assigned_amount=fs_obj.amount,
                    paid_amount=paid_val,
                    discount_amount=Decimal("0.00"),
                    fine_amount=Decimal("0.00"),
                    status=status_val,
                    version=1
                )
                session.add(fa_obj)
                
        await session.flush()

        # Phase 18: Report Card Publications Generation
        logger.info("PHASE 18: Generating Report Cards Publications...")
        rc_list = []
        for stud_idx, stud in enumerate(students):
            res_rc = await session.execute(
                select(ReportCardPublication).where(
                    ReportCardPublication.student_id == stud.id,
                    ReportCardPublication.academic_year_id == ay_id
                )
            )
            rc_obj = res_rc.scalar_one_or_none()
            if not rc_obj:
                # High performer (idx 0), math specialist (idx 1), improver (idx 2)
                ai_narrative_text = "Overall excellent performance."
                if stud_idx == 0:
                    ai_narrative_text = "Topper of the class. Excellent academic execution and logical capability."
                elif stud_idx == 1:
                    ai_narrative_text = "Excellent logical math capabilities, but requires language tutoring."
                elif stud_idx == 3:
                    ai_narrative_text = "Academic risk. Noticeable decline in scores across periodic examinations."
                    
                rc_obj = ReportCardPublication(
                    id=uuid.uuid4(),
                    tenant_id=DPS_TENANT_ID,
                    school_id=DPS_SCHOOL_ID,
                    academic_year_id=ay_id,
                    student_id=stud.id,
                    verification_uuid=uuid.uuid4(),
                    status=ReportCardStatus.PUBLISHED,
                    pdf_url=None,
                    pdf_history=[],
                    generated_at=datetime.now(timezone.utc),
                    published_at=datetime.now(timezone.utc),
                    approved_at=datetime.now(timezone.utc),
                    generated_by=admin_user_id,
                    published_by=admin_user_id,
                    approved_by=admin_user_id,
                    settings={"term_code": "FINAL"},
                    ai_metrics={
                        "risk_level": "LOW" if stud_idx != 3 else "HIGH",
                        "overall_trend": "IMPROVING" if stud_idx == 2 else ("DECLINING" if stud_idx == 3 else "STABLE"),
                        "ai_narrative": ai_narrative_text
                    },
                    is_active=True,
                    version=1
                )
                session.add(rc_obj)
                
        await session.flush()
        
        await session.commit()
        logger.info("Delhi Public School Hyderabad 2025-26 Demo Dataset seeded successfully!")

if __name__ == "__main__":
    asyncio.run(main())
