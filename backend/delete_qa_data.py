import asyncio
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

DATABASE_URL = "postgresql+asyncpg://postgres:Gudepu%4084@localhost:5432/edupulse_db"

async def run_cleanup():
    engine = create_async_engine(DATABASE_URL)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    
    async with async_session() as session:
        # Find auto tenants
        res = await session.execute(text(
            "SELECT id FROM tenants WHERE name LIKE 'AUTO Tenant%' OR code LIKE 'edupulse-auto%'"
        ))
        auto_tenant_ids = [row[0] for row in res.all()]
        
        # Find auto schools
        res = await session.execute(text(
            "SELECT id FROM schools WHERE tenant_id = ANY(:ids) OR name LIKE 'AUTO School%'"
        ), {"ids": auto_tenant_ids})
        auto_school_ids = [row[0] for row in res.all()]
        
        print(f"Loaded {len(auto_tenant_ids)} AUTO Tenant IDs.")
        print(f"Loaded {len(auto_school_ids)} AUTO School IDs.")
        
        if not auto_tenant_ids:
            print("No AUTO Tenants found. Cleanup skipped.")
            return
            
        print("Starting sequential deletion of AUTO QA data...")
        
        # Delete helper function to log and execute
        async def delete_from(table, condition, params):
            res = await session.execute(text(f"DELETE FROM {table} WHERE {condition}"), params)
            print(f"Deleted {res.rowcount} rows from {table}")

        # 1. report_card_publications
        await delete_from(
            "report_card_publications", 
            "student_id IN (SELECT id FROM students WHERE tenant_id = ANY(:ids))",
            {"ids": auto_tenant_ids}
        )
        
        # 2. marks
        await delete_from(
            "marks", 
            "tenant_id = ANY(:ids)", 
            {"ids": auto_tenant_ids}
        )
        
        # 3. attendances / attendance_records
        await delete_from(
            "attendances", 
            "student_id IN (SELECT id FROM students WHERE tenant_id = ANY(:ids))", 
            {"ids": auto_tenant_ids}
        )
        
        # 4. attendance_sessions
        await delete_from(
            "attendance_sessions", 
            "school_id = ANY(:ids)", 
            {"ids": auto_school_ids}
        )
        
        # 5. student_guardians
        await delete_from(
            "student_guardians", 
            "student_id IN (SELECT id FROM students WHERE tenant_id = ANY(:ids))", 
            {"ids": auto_tenant_ids}
        )
        
        # 6. student_fee_assignments
        await delete_from(
            "student_fee_assignments", 
            "tenant_id = ANY(:ids)", 
            {"ids": auto_tenant_ids}
        )
        
        # 7. fee_payment_allocations
        await delete_from(
            "fee_payment_allocations", 
            "payment_id IN (SELECT id FROM fee_payments WHERE tenant_id = ANY(:ids))", 
            {"ids": auto_tenant_ids}
        )
        
        # 8. fee_payments
        await delete_from(
            "fee_payments", 
            "tenant_id = ANY(:ids)", 
            {"ids": auto_tenant_ids}
        )
        
        # 9. fee_structures
        await delete_from(
            "fee_structures", 
            "tenant_id = ANY(:ids)", 
            {"ids": auto_tenant_ids}
        )
        
        # 10. fee_types
        await delete_from(
            "fee_types", 
            "tenant_id = ANY(:ids)", 
            {"ids": auto_tenant_ids}
        )
        
        # 11. students
        await delete_from(
            "students", 
            "tenant_id = ANY(:ids)", 
            {"ids": auto_tenant_ids}
        )
        
        # 12. guardians
        await delete_from(
            "guardians", 
            "tenant_id = ANY(:ids)", 
            {"ids": auto_tenant_ids}
        )
        
        # 13. timetables
        await delete_from(
            "timetables", 
            "tenant_id = ANY(:ids)", 
            {"ids": auto_tenant_ids}
        )
        
        # 14. teacher_subject_assignments
        await delete_from(
            "teacher_subject_assignments", 
            "tenant_id = ANY(:ids)", 
            {"ids": auto_tenant_ids}
        )
        
        # 15. teachers
        await delete_from(
            "teachers", 
            "tenant_id = ANY(:ids)", 
            {"ids": auto_tenant_ids}
        )
        
        # 16. syllabuses
        await delete_from(
            "syllabuses", 
            "tenant_id = ANY(:ids)", 
            {"ids": auto_tenant_ids}
        )
        
        # 17. exam_schedules
        await delete_from(
            "exam_schedules", 
            "tenant_id = ANY(:ids)", 
            {"ids": auto_tenant_ids}
        )
        
        # 18. examinations
        await delete_from(
            "examinations", 
            "tenant_id = ANY(:ids)", 
            {"ids": auto_tenant_ids}
        )
        
        # 19. student_import_rows
        await delete_from(
            "student_import_rows", 
            "tenant_id = ANY(:ids)", 
            {"ids": auto_tenant_ids}
        )
        
        # 20. academic_setup_import_rows
        await delete_from(
            "academic_setup_import_rows", 
            "tenant_id = ANY(:ids)", 
            {"ids": auto_tenant_ids}
        )
        
        # 21. import_job_rows
        await delete_from(
            "import_job_rows", 
            "import_job_id IN (SELECT id FROM import_jobs WHERE tenant_id = ANY(:ids))", 
            {"ids": auto_tenant_ids}
        )
        
        # 22. import_jobs
        await delete_from(
            "import_jobs", 
            "tenant_id = ANY(:ids)", 
            {"ids": auto_tenant_ids}
        )
        
        # 23. sections
        await delete_from(
            "sections", 
            "tenant_id = ANY(:ids)", 
            {"ids": auto_tenant_ids}
        )
        
        # 24. classes
        await delete_from(
            "classes", 
            "tenant_id = ANY(:ids)", 
            {"ids": auto_tenant_ids}
        )
        
        # 25. academic_years
        await delete_from(
            "academic_years", 
            "tenant_id = ANY(:ids)", 
            {"ids": auto_tenant_ids}
        )
        
        # 26. users
        await delete_from(
            "users", 
            "tenant_id = ANY(:ids) OR email LIKE 'auto-%' OR email LIKE 'auto_%'", 
            {"ids": auto_tenant_ids}
        )
        
        # 27. schools
        await delete_from(
            "schools", 
            "tenant_id = ANY(:ids)", 
            {"ids": auto_tenant_ids}
        )
        
        # 28. tenants
        await delete_from(
            "tenants", 
            "id = ANY(:ids)", 
            {"ids": auto_tenant_ids}
        )
        
        await session.commit()
        print("All AUTO QA records deleted successfully and transaction committed.")

if __name__ == "__main__":
    asyncio.run(run_cleanup())
