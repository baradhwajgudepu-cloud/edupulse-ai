import asyncio
import uuid
import sys
import os
from sqlalchemy import select
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

# Setup path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.models.teacher import Teacher
from app.models.teacher_subject_assignment import TeacherSubjectAssignment
from app.models.examination import ExamSchedule, Examination
from app.models.marks import Marks, MarksStatus
from app.models.user import User
from app.services.marks import MarksService
from app.repositories.marks import MarksRepository
from app.services.notification import NotificationService
from app.repositories.notification import NotificationRepository
from app.repositories.examination import ExamScheduleRepository, ExaminationRepository
from app.repositories.student import StudentRepository
from app.repositories.teacher_subject_assignment import TeacherSubjectAssignmentRepository
from app.repositories.school import SchoolRepository

DATABASE_URL = "postgresql+asyncpg://postgres:Gudepu%4084@localhost:5432/edupulse_db"

async def main():
    engine = create_async_engine(DATABASE_URL, echo=True)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    
    async with async_session() as db:
        try:
            print("Fetching Anita Sharma teacher profile...")
            stmt_t = select(Teacher).where(Teacher.first_name == "Anita", Teacher.last_name == "Sharma")
            res_t = await db.execute(stmt_t)
            teachers = res_t.scalars().all()
            if not teachers:
                print("Anita Sharma not found!")
                return
            
            for teacher in teachers:
                print(f"\n--- Teacher ID: {teacher.id}, School ID: {teacher.school_id}, Tenant ID: {teacher.tenant_id} ---")
                
                print("Fetching assignments...")
                stmt_tsa = select(TeacherSubjectAssignment).where(TeacherSubjectAssignment.teacher_id == teacher.id)
                res_tsa = await db.execute(stmt_tsa)
                assignments = res_tsa.scalars().all()
                print(f"Found {len(assignments)} assignments:")
                for tsa in assignments:
                    print(f"TSA ID: {tsa.id}, Class: {tsa.class_id}, Section: {tsa.section_id}, Subject: {tsa.subject_id}")
                
                print("Fetching exam schedules...")
                stmt_sched = select(ExamSchedule).where(ExamSchedule.school_id == teacher.school_id)
                res_sched = await db.execute(stmt_sched)
                schedules = res_sched.scalars().all()
                print(f"Found {len(schedules)} exam schedules:")
                for s in schedules:
                    print(f"Schedule ID: {s.id}, Exam: {s.exam_id}, Class: {s.class_id}, Section: {s.section_id}, Subject: {s.subject_id}")
                    
                for s in schedules:
                    stmt_m = select(Marks).where(Marks.exam_schedule_id == s.id)
                    res_m = await db.execute(stmt_m)
                    marks_list = res_m.scalars().all()
                    if marks_list:
                        print(f"-> Schedule {s.id} has {len(marks_list)} marks logs.")
                        for m in marks_list:
                            print(f"   Mark ID: {m.id}, Student ID: {m.student_id}, Obtained: {m.marks_obtained}, Status: {m.status}")
                        
                        # Try publishing
                        print(f"Attempting to publish marks for schedule {s.id}...")
                        user_stmt = select(User).where(User.id == teacher.user_id)
                        user_res = await db.execute(user_stmt)
                        user = user_res.scalar_one()
                        
                        marks_repo = MarksRepository(db)
                        schedule_repo = ExamScheduleRepository(db)
                        exam_repo = ExaminationRepository(db)
                        student_repo = StudentRepository(db)
                        tsa_repo = TeacherSubjectAssignmentRepository(db)
                        school_repo = SchoolRepository(db)

                        notif_repo = NotificationRepository(db)
                        notif_service = NotificationService(notif_repo)
                        
                        marks_service = MarksService(
                            marks_repo=marks_repo,
                            schedule_repo=schedule_repo,
                            exam_repo=exam_repo,
                            student_repo=student_repo,
                            tsa_repo=tsa_repo,
                            school_repo=school_repo,
                            notification_service=notif_service
                        )
                        
                        try:
                            res = await marks_service.publish_marks(
                                tenant_id=teacher.tenant_id,
                                school_id=teacher.school_id,
                                exam_schedule_id=s.id,
                                current_user=user
                            )
                            print("Publish succeeded!")
                            print(f"Published {len(res)} records.")
                        except Exception as ex:
                            print(f"Publish failed with exception: {ex}")
                            import traceback
                            traceback.print_exc()
                        
        except Exception as e:
            print(f"Error: {e}")
            import traceback
            traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(main())
