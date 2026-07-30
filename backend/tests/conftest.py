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
async def client(db_session) -> AsyncGenerator[AsyncClient, None]:
    """
    Provides an async HTTP client to execute request tests against FastAPI routes,
    with database dependency injection overridden.
    """
    async def override_get_db():
        yield db_session
        
    app.dependency_overrides[get_db] = override_get_db
    
    # Create transport client using the standard ASGITransport
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        yield ac
        
    app.dependency_overrides.clear()
