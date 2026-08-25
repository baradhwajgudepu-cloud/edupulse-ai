import pytest
from typing import AsyncGenerator
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from app.main import app
from app.db.base import Base
from app.db.session import get_db

# Use a shared in-memory SQLite database for fast, self-contained unit testing
TEST_DATABASE_URL = "sqlite+aiosqlite:///file:testdb?mode=memory&cache=shared"

@pytest.fixture(scope="session")
def anyio_backend() -> str:
    """
    Defines backend runner for async test execution (AnyIO standard).
    """
    return "asyncio"

@pytest.fixture(scope="session")
async def test_engine():
    """
    Initializes async engine and creates schemas before running test suites.
    """
    engine = create_async_engine(
        TEST_DATABASE_URL,
        connect_args={"check_same_thread": False, "uri": True}
    )
    
    async with engine.begin() as conn:
        # Ensure a clean database state by dropping all existing tables first
        await conn.run_sync(Base.metadata.drop_all)
        # Create all tables defined in Base models metadata
        await conn.run_sync(Base.metadata.create_all)
        
        # Seed default system permissions for test runs
        from sqlalchemy import insert
        from app.models.permission import Permission
        import uuid
        
        permissions_data = [
            {"id": uuid.uuid4(), "name": "Read Tenant", "code": "tenant.read", "description": "View tenant metadata"},
            {"id": uuid.uuid4(), "name": "Write Tenant", "code": "tenant.write", "description": "Modify tenant metadata"},
            {"id": uuid.uuid4(), "name": "Create School", "code": "school.create", "description": "Create school campuses"},
            {"id": uuid.uuid4(), "name": "Read School", "code": "school.read", "description": "View school campus profiles"},
            {"id": uuid.uuid4(), "name": "Update School", "code": "school.update", "description": "Modify school campus profiles"},
            {"id": uuid.uuid4(), "name": "Delete School", "code": "school.delete", "description": "Soft delete school campuses"},
            {"id": uuid.uuid4(), "name": "Create Academic Year", "code": "academic_year.create", "description": "Add academic year periods"},
            {"id": uuid.uuid4(), "name": "Read Academic Year", "code": "academic_year.read", "description": "View academic year configurations"},
            {"id": uuid.uuid4(), "name": "Update Academic Year", "code": "academic_year.update", "description": "Modify academic year configurations"},
            {"id": uuid.uuid4(), "name": "Delete Academic Year", "code": "academic_year.delete", "description": "Soft delete academic year periods"},
            {"id": uuid.uuid4(), "name": "Create Role", "code": "role.create", "description": "Add custom roles"},
            {"id": uuid.uuid4(), "name": "Read Role", "code": "role.read", "description": "View roles"},
            {"id": uuid.uuid4(), "name": "Update Role", "code": "role.update", "description": "Modify custom roles"},
            {"id": uuid.uuid4(), "name": "Read Permission", "code": "permission.read", "description": "View system permissions list"},
            {"id": uuid.uuid4(), "name": "Create User", "code": "user.create", "description": "Register users"},
            {"id": uuid.uuid4(), "name": "Read User", "code": "user.read", "description": "View user profiles"},
            {"id": uuid.uuid4(), "name": "Update User", "code": "user.update", "description": "Modify user properties"},
            {"id": uuid.uuid4(), "name": "Delete User", "code": "user.delete", "description": "Soft delete users"},
            {"id": uuid.uuid4(), "name": "Create Class", "code": "class.create", "description": "Create school classes"},
            {"id": uuid.uuid4(), "name": "Read Class", "code": "class.read", "description": "View school classes"},
            {"id": uuid.uuid4(), "name": "Update Class", "code": "class.update", "description": "Modify class configurations"},
            {"id": uuid.uuid4(), "name": "Delete Class", "code": "class.delete", "description": "Soft delete class records"},
            {"id": uuid.uuid4(), "name": "Archive Class", "code": "class.archive", "description": "Archive class configurations"},
            {"id": uuid.uuid4(), "name": "Promote Class", "code": "class.promote", "description": "Configure or run class promotion sequence"},
            {"id": uuid.uuid4(), "name": "Create Section", "code": "section.create", "description": "Create school sections"},
            {"id": uuid.uuid4(), "name": "Read Section", "code": "section.read", "description": "View school sections"},
            {"id": uuid.uuid4(), "name": "Update Section", "code": "section.update", "description": "Modify section configurations"},
            {"id": uuid.uuid4(), "name": "Delete Section", "code": "section.delete", "description": "Soft delete section records"},
            {"id": uuid.uuid4(), "name": "Create Student", "code": "student.create", "description": "Register school students"},
            {"id": uuid.uuid4(), "name": "Read Student", "code": "student.read", "description": "View school students profile"},
            {"id": uuid.uuid4(), "name": "Update Student", "code": "student.update", "description": "Modify student profiles"},
            {"id": uuid.uuid4(), "name": "Delete Student", "code": "student.delete", "description": "Soft delete student records"},
            {"id": uuid.uuid4(), "name": "Create Guardian", "code": "guardian.create", "description": "Add school guardians profile"},
            {"id": uuid.uuid4(), "name": "Read Guardian", "code": "guardian.read", "description": "View school guardians profile and list"},
            {"id": uuid.uuid4(), "name": "Update Guardian", "code": "guardian.update", "description": "Modify guardian profiles"},
            {"id": uuid.uuid4(), "name": "Delete Guardian", "code": "guardian.delete", "description": "Soft delete guardian profiles"},
            {"id": uuid.uuid4(), "name": "Create Teacher", "code": "teacher.create", "description": "Add school teachers profile"},
            {"id": uuid.uuid4(), "name": "Read Teacher", "code": "teacher.read", "description": "View school teachers list and details"},
            {"id": uuid.uuid4(), "name": "Update Teacher", "code": "teacher.update", "description": "Modify teacher profile properties"},
            {"id": uuid.uuid4(), "name": "Delete Teacher", "code": "teacher.delete", "description": "Soft delete teacher records"},
            {"id": uuid.uuid4(), "name": "Create Subject", "code": "subject.create", "description": "Add school academic subject"},
            {"id": uuid.uuid4(), "name": "Read Subject", "code": "subject.read", "description": "View school academic subjects catalog"},
            {"id": uuid.uuid4(), "name": "Update Subject", "code": "subject.update", "description": "Modify academic subject properties"},
            {"id": uuid.uuid4(), "name": "Delete Subject", "code": "subject.delete", "description": "Soft delete academic subject records"},
            {"id": uuid.uuid4(), "name": "Create Teacher Subject Assignment", "code": "teacher_subject_assignment.create", "description": "Assign teacher to academic subjects"},
            {"id": uuid.uuid4(), "name": "Read Teacher Subject Assignment", "code": "teacher_subject_assignment.read", "description": "View teacher subject assignments mapping"},
            {"id": uuid.uuid4(), "name": "Update Teacher Subject Assignment", "code": "teacher_subject_assignment.update", "description": "Modify teacher subject assignments mapping"},
            {"id": uuid.uuid4(), "name": "Delete Teacher Subject Assignment", "code": "teacher_subject_assignment.delete", "description": "Soft delete teacher subject assignments mapping"},
            {"id": uuid.uuid4(), "name": "Create Timetable", "code": "timetable.create", "description": "Add school timetable periods"},
            {"id": uuid.uuid4(), "name": "Read Timetable", "code": "timetable.read", "description": "View school schedules and timetables"},
            {"id": uuid.uuid4(), "name": "Update Timetable", "code": "timetable.update", "description": "Modify school schedules and timetables"},
            {"id": uuid.uuid4(), "name": "Delete Timetable", "code": "timetable.delete", "description": "Soft delete timetable configurations"},
            {"id": uuid.uuid4(), "name": "Create Student Attendance", "code": "attendance.create", "description": "Mark student period attendance logs"},
            {"id": uuid.uuid4(), "name": "Read Student Attendance", "code": "attendance.read", "description": "View student attendance histories"},
            {"id": uuid.uuid4(), "name": "Update Student Attendance", "code": "attendance.update", "description": "Modify student attendance marks"},
            {"id": uuid.uuid4(), "name": "Delete Student Attendance", "code": "attendance.delete", "description": "Soft delete marked student attendances"},
            {"id": uuid.uuid4(), "name": "Create Homework", "code": "homework.create", "description": "Allows creating homework assignments"},
            {"id": uuid.uuid4(), "name": "Read Homework", "code": "homework.read", "description": "Allows viewing homework assignments"},
            {"id": uuid.uuid4(), "name": "Update Homework", "code": "homework.update", "description": "Allows updating homework assignments"},
            {"id": uuid.uuid4(), "name": "Delete Homework", "code": "homework.delete", "description": "Allows deleting homework assignments"},
            {"id": uuid.uuid4(), "name": "Create Examination", "code": "exam.create", "description": "Allows creating examinations"},
            {"id": uuid.uuid4(), "name": "Read Examination", "code": "exam.read", "description": "Allows viewing examinations"},
            {"id": uuid.uuid4(), "name": "Update Examination", "code": "exam.update", "description": "Allows updating examinations"},
            {"id": uuid.uuid4(), "name": "Delete Examination", "code": "exam.delete", "description": "Allows deleting examinations"},
            {"id": uuid.uuid4(), "name": "Create Marks", "code": "marks.create", "description": "Allows creating marks records"},
            {"id": uuid.uuid4(), "name": "Read Marks", "code": "marks.read", "description": "Allows viewing marks records"},
            {"id": uuid.uuid4(), "name": "Update Marks", "code": "marks.update", "description": "Allows updating marks records"},
            {"id": uuid.uuid4(), "name": "Delete Marks", "code": "marks.delete", "description": "Allows deleting marks records"},
            {"id": uuid.uuid4(), "name": "Publish Marks", "code": "marks.publish", "description": "Allows publishing marks records"},
            {"id": uuid.uuid4(), "name": "Generate Report Card", "code": "report_card.generate", "description": "Allows generating report cards"},
            {"id": uuid.uuid4(), "name": "Read Report Card", "code": "report_card.read", "description": "Allows viewing report cards"},
            {"id": uuid.uuid4(), "name": "Publish Report Card", "code": "report_card.publish", "description": "Allows publishing report cards"},
            {"id": uuid.uuid4(), "name": "Download Report Card", "code": "report_card.download", "description": "Allows downloading report cards"},
            {"id": uuid.uuid4(), "name": "Use AI Assistant", "code": "ai.use", "description": "Allows executing queries using the AI Service foundation"},
            {"id": uuid.uuid4(), "name": "Create Notification", "code": "notification.create", "description": "Allows creating notification records"},
            {"id": uuid.uuid4(), "name": "Read Notification", "code": "notification.read", "description": "Allows viewing notification records"},
            {"id": uuid.uuid4(), "name": "Update Notification", "code": "notification.update", "description": "Allows updating notification records"},
            {"id": uuid.uuid4(), "name": "Delete Notification", "code": "notification.delete", "description": "Allows deleting notification records"},
            {"id": uuid.uuid4(), "name": "Mark Read Notification", "code": "notification.mark_read", "description": "Allows marking notification as read"},
            {"id": uuid.uuid4(), "name": "Create Identity", "code": "identity.create", "description": "Allows creating user identities"},
            {"id": uuid.uuid4(), "name": "Read Identity", "code": "identity.read", "description": "Allows viewing user identities"},
            {"id": uuid.uuid4(), "name": "Update Identity", "code": "identity.update", "description": "Allows updating user identities"},
            {"id": uuid.uuid4(), "name": "Delete Identity", "code": "identity.delete", "description": "Allows deleting user identities"},
            {"id": uuid.uuid4(), "name": "Provision Identity", "code": "identity.provision", "description": "Allows provisioning user identities"},
            {"id": uuid.uuid4(), "name": "Reset Password Identity", "code": "identity.reset_password", "description": "Allows resetting passwords"},
            {"id": uuid.uuid4(), "name": "Read Reports", "code": "reports.read", "description": "Allows viewing reports"},
            {"id": uuid.uuid4(), "name": "Read Academic Reports", "code": "reports.academic.read", "description": "Allows viewing academic reports"},
            {"id": uuid.uuid4(), "name": "Read Attendance Reports", "code": "reports.attendance.read", "description": "Allows viewing attendance reports"},
            {"id": uuid.uuid4(), "name": "Read Fees Reports", "code": "reports.fees.read", "description": "Allows viewing fees reports"},
            {"id": uuid.uuid4(), "name": "Read AI Reports", "code": "reports.ai.read", "description": "Allows viewing AI reports"},
            {"id": uuid.uuid4(), "name": "Export Reports", "code": "reports.export", "description": "Allows exporting reports"},
            {"id": uuid.uuid4(), "name": "Read Settings", "code": "settings.read", "description": "Allows viewing settings"},
            {"id": uuid.uuid4(), "name": "Update Settings", "code": "settings.update", "description": "Allows updating settings"},
            {"id": uuid.uuid4(), "name": "Update School Settings", "code": "settings.school.update", "description": "Allows updating school settings"},
            {"id": uuid.uuid4(), "name": "Update Academic Settings", "code": "settings.academic.update", "description": "Allows updating academic settings"},
            {"id": uuid.uuid4(), "name": "Update Grading Settings", "code": "settings.grading.update", "description": "Allows updating grading settings"},
            {"id": uuid.uuid4(), "name": "Update Exam Settings", "code": "settings.exam.update", "description": "Allows updating exam settings"},
            {"id": uuid.uuid4(), "name": "Update Report Card Settings", "code": "settings.report_card.update", "description": "Allows updating report card settings"},
            {"id": uuid.uuid4(), "name": "Read Staff Attendance", "code": "staff_attendance.read", "description": "Allows viewing staff attendance logs"},
            {"id": uuid.uuid4(), "name": "Create Staff Check-In", "code": "staff_attendance.create", "description": "Allows checking in"},
            {"id": uuid.uuid4(), "name": "Update Staff Check-Out", "code": "staff_attendance.update", "description": "Allows checking out"},
            {"id": uuid.uuid4(), "name": "Admin Staff Attendance", "code": "staff_attendance.admin", "description": "Allows administrative staff attendance operations"},
            {"id": uuid.uuid4(), "name": "Read Teacher Leaves", "code": "teacher_leave.read", "description": "Allows viewing teacher leaves"},
            {"id": uuid.uuid4(), "name": "Create Teacher Leave", "code": "teacher_leave.create", "description": "Allows submitting teacher leave"},
            {"id": uuid.uuid4(), "name": "Cancel Teacher Leave", "code": "teacher_leave.cancel", "description": "Allows cancelling pending teacher leave"},
            {"id": uuid.uuid4(), "name": "Review Teacher Leave", "code": "teacher_leave.review", "description": "Allows reviewing teacher leaves"},
            {"id": uuid.uuid4(), "name": "Admin Teacher Leave", "code": "teacher_leave.admin", "description": "Allows administrative teacher leave operations"},
            # Fees Management
            {"id": uuid.uuid4(), "name": "Create Fee", "code": "fee.create", "description": "Allows creating fee structures"},
            {"id": uuid.uuid4(), "name": "Read Fee", "code": "fee.read", "description": "Allows viewing fee structures"},
            {"id": uuid.uuid4(), "name": "Update Fee", "code": "fee.update", "description": "Allows updating fee structures"},
            {"id": uuid.uuid4(), "name": "Delete Fee", "code": "fee.delete", "description": "Allows deleting fee structures"},
            {"id": uuid.uuid4(), "name": "Pay Fee", "code": "fee.pay", "description": "Allows processing fee payments"},
            {"id": uuid.uuid4(), "name": "Cancel Fee", "code": "fee.cancel", "description": "Allows cancelling fee transactions"},
            {"id": uuid.uuid4(), "name": "Report Fee", "code": "fee.report", "description": "Allows generating fee reports"},
            # School Planner (Events)
            {"id": uuid.uuid4(), "name": "Create Event", "code": "event.create", "description": "Allows creating events"},
            {"id": uuid.uuid4(), "name": "Read Event", "code": "event.read", "description": "Allows viewing events"},
            {"id": uuid.uuid4(), "name": "Update Event", "code": "event.update", "description": "Allows updating events"},
            {"id": uuid.uuid4(), "name": "Delete Event", "code": "event.delete", "description": "Allows deleting events"},
            {"id": uuid.uuid4(), "name": "Publish Event", "code": "event.publish", "description": "Allows publishing events"},
            # School Planner (Announcements)
            {"id": uuid.uuid4(), "name": "Create Announcement", "code": "announcement.create", "description": "Allows creating announcements"},
            {"id": uuid.uuid4(), "name": "Read Announcement", "code": "announcement.read", "description": "Allows viewing announcements"},
            {"id": uuid.uuid4(), "name": "Update Announcement", "code": "announcement.update", "description": "Allows updating announcements"},
            {"id": uuid.uuid4(), "name": "Delete Announcement", "code": "announcement.delete", "description": "Allows deleting announcements"},
            {"id": uuid.uuid4(), "name": "Publish Announcement", "code": "announcement.publish", "description": "Allows publishing announcements"},
            # Migrations
            {"id": uuid.uuid4(), "name": "Read Migration Job", "code": "migration.read", "description": "Allows viewing migration jobs"},
            {"id": uuid.uuid4(), "name": "Create Migration Job", "code": "migration.create", "description": "Allows creating migration jobs"},
            {"id": uuid.uuid4(), "name": "Execute Migration Job", "code": "migration.execute", "description": "Allows executing migration jobs"},
            {"id": uuid.uuid4(), "name": "Cancel Migration Job", "code": "migration.cancel", "description": "Allows canceling migration jobs"},
        ]
        from sqlalchemy import select
        res = await conn.execute(select(Permission))
        if not res.scalars().all():
            await conn.execute(insert(Permission), permissions_data)
        
    yield engine
    
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        
    await engine.dispose()

@pytest.fixture
async def db_session(test_engine) -> AsyncGenerator[AsyncSession, None]:
    """
    Yields an isolated transactional session. Rolls back changes automatically
    at the end of each test to ensure test isolation.
    """
    async_session = async_sessionmaker(
        bind=test_engine,
        class_=AsyncSession,
        expire_on_commit=False
    )
    
    async with async_session() as session:
        yield session
        await session.rollback()

@pytest.fixture
async def client(db_session, request) -> AsyncGenerator[AsyncClient, None]:
    """
    Provides an async HTTP client to execute request tests against FastAPI routes,
    with database dependency injection overridden.
    """
    async def override_get_db():
        yield db_session
        
    app.dependency_overrides[get_db] = override_get_db
    
    # Bypass auth and RBAC checks for non-auth test files by mock-seeding a superuser
    if "test_auth" not in request.node.nodeid and "test_communication" not in request.node.nodeid:
        from app.api.dependencies.auth import get_current_user
        from app.models.user import User, UserStatus
        from fastapi import Request
        import uuid
        
        async def mock_get_current_user(req: Request):
            t_id_str = req.headers.get("X-Tenant-ID")
            t_id = uuid.UUID(t_id_str) if t_id_str else uuid.uuid4()
            return User(
                id=uuid.uuid4(),
                email="mock_admin@edu.in",
                is_superuser=True,
                status=UserStatus.ACTIVE,
                tenant_id=t_id
            )
            
        app.dependency_overrides[get_current_user] = mock_get_current_user
    
    # Create transport client using the standard ASGITransport
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        yield ac
        
    app.dependency_overrides.clear()
