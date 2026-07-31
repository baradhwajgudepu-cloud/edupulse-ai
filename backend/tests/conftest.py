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
        ]
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
    if "test_auth" not in request.node.nodeid:
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
