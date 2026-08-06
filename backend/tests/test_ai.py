import os
import uuid
import pytest
from unittest.mock import AsyncMock, patch
import httpx
from httpx import AsyncClient
from fastapi import status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.main import app
from app.models.tenant import Tenant
from app.models.school import School
from app.models.role import Role
from app.models.permission import Permission
from app.models.user import User, UserStatus
from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
from app.services.auth import AuthService
from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate, SchoolStatus
from app.schemas.auth import UserCreate
from app.core.settings import settings
from app.api.dependencies.auth import get_current_user
from app.api.dependencies.ai import get_ai_service
from app.services.ai.service import AIService, TokenBucketRateLimiter

class MockResponse:
    """
    Synchronous helper class to represent mocked HTTPX responses.
    Prevents nested AsyncMock awaitable errors.
    """
    def __init__(self, status_code: int, json_data: dict, text: str = "") -> None:
        self.status_code = status_code
        self.json_data = json_data
        self.text = text

    def json(self) -> dict:
        return self.json_data


@pytest.fixture
async def setup_ai_test_data(db_session: AsyncSession):
    suffix = uuid.uuid4().hex[:6].lower()

    # Create Tenant
    repo_t = TenantRepository(db_session)
    tenant_a = await repo_t.create(TenantCreate(name="AI Tenant", code=f"ai-t-{suffix}", subdomain=f"ai-sub-{suffix}", email=f"ai-{suffix}@t.com"))
    await db_session.commit()

    # Create School
    repo_s = SchoolRepository(db_session)
    school_a = await repo_s.create(tenant_a.id, SchoolCreate(
        name="AI School", code=f"AI_S_{suffix.upper()}", address="123 AI Street", city="Bangalore",
        state="Karnataka", country="India", pin_code="560001", board="CBSE", email=f"s-ai-{suffix}@a.com",
        status=SchoolStatus.ACTIVE
    ))
    await db_session.commit()

    # User & Permission Setup
    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    auth_service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, repo_s)

    # Load all permissions (includes seeded ai.use)
    stmt_p = select(Permission)
    res_p = await db_session.execute(stmt_p)
    all_perms = list(res_p.scalars().all())

    role_a = Role(name="Super Admin", code="SUPER_ADMIN", is_system=True, tenant_id=tenant_a.id)
    role_a.permissions = all_perms
    db_session.add(role_a)

    user_admin = await auth_service.create_user(
        tenant_a.id,
        UserCreate(email=f"ai-admin-{suffix}@a.com", password="Password123!", first_name="AI", last_name="Admin")
    )
    user_admin.roles.append(role_a)
    await db_session.commit()

    tokens_a = await auth_service.create_tokens(user_admin)

    return {
        "tenant_a": tenant_a,
        "school_a": school_a,
        "user_admin": user_admin,
        "auth_headers": {
            "Authorization": f"Bearer {tokens_a.access_token}",
            "X-Tenant-ID": str(tenant_a.id)
        }
    }


@pytest.mark.anyio
async def test_ai_config_endpoint(client: AsyncClient, setup_ai_test_data) -> None:
    headers = setup_ai_test_data["auth_headers"]

    # Call config route
    resp = await client.get("/api/v1/ai/config", headers=headers)
    assert resp.status_code == 200
    payload = resp.json()
    assert payload["success"] is True
    assert "provider" in payload["data"]
    assert "model" in payload["data"]
    assert payload["data"]["rate_limit"] == settings.AI_RATE_LIMIT_PER_MINUTE


@pytest.mark.anyio
async def test_gemini_text_query_mocked(client: AsyncClient, setup_ai_test_data) -> None:
    headers = setup_ai_test_data["auth_headers"]

    mock_gemini_resp = {
        "candidates": [
            {
                "content": {
                    "parts": [{"text": "Simulated Gemini response text output."}]
                }
            }
        ]
    }

    # Override config settings to target Gemini with a fake key
    with patch("app.core.settings.settings.AI_PROVIDER", "gemini"), \
         patch("app.core.settings.settings.GEMINI_API_KEY", "fake_key_gemini"), \
         patch("app.core.settings.settings.AI_MODEL", "gemini-1.5-flash"):

        # Reset singleton to capture patched settings
        import app.api.dependencies.ai as dep_ai
        dep_ai._ai_service_instance = None

        mock_response = MockResponse(status_code=200, json_data=mock_gemini_resp)

        # Selectively patch HTTPX post requests to preserve test server routing
        original_post = httpx.AsyncClient.post
        async def mock_post(self_client, url, *args, **kwargs):
            url_str = str(url)
            if "googleapis.com" in url_str:
                return mock_response
            return await original_post(self_client, url, *args, **kwargs)

        with patch("httpx.AsyncClient.post", new=mock_post):
            payload = {
                "prompt": "Analyze student performance",
                "temperature": 0.5
            }
            resp = await client.post("/api/v1/ai/query", json=payload, headers=headers)
            assert resp.status_code == 200
            data = resp.json()["data"]
            assert data["text"] == "Simulated Gemini response text output."
            assert data["provider"] == "gemini"
            assert data["model"] == "gemini-1.5-flash"


@pytest.mark.anyio
async def test_openai_json_query_mocked(client: AsyncClient, setup_ai_test_data) -> None:
    headers = setup_ai_test_data["auth_headers"]

    mock_openai_resp = {
        "choices": [
            {
                "message": {
                    "content": '{"verdict": "Promoted", "confidence": 0.95}'
                }
            }
        ]
    }

    # Override config settings to target OpenAI with a fake key
    with patch("app.core.settings.settings.AI_PROVIDER", "openai"), \
         patch("app.core.settings.settings.OPENAI_API_KEY", "fake_key_openai"), \
         patch("app.core.settings.settings.AI_MODEL", "gpt-4o-mini"):

        # Reset singleton to capture patched settings
        import app.api.dependencies.ai as dep_ai
        dep_ai._ai_service_instance = None

        mock_response = MockResponse(status_code=200, json_data=mock_openai_resp)

        # Selectively patch HTTPX post requests to preserve test server routing
        original_post = httpx.AsyncClient.post
        async def mock_post(self_client, url, *args, **kwargs):
            url_str = str(url)
            if "api.openai.com" in url_str:
                return mock_response
            return await original_post(self_client, url, *args, **kwargs)

        with patch("httpx.AsyncClient.post", new=mock_post):
            payload = {
                "prompt": "Evaluate structured profile",
                "response_schema": {
                    "type": "object",
                    "properties": {
                        "verdict": {"type": "string"},
                        "confidence": {"type": "number"}
                    }
                }
            }
            resp = await client.post("/api/v1/ai/query", json=payload, headers=headers)
            assert resp.status_code == 200
            data = resp.json()["data"]
            assert data["structured_data"]["verdict"] == "Promoted"
            assert data["structured_data"]["confidence"] == 0.95
            assert data["provider"] == "openai"


@pytest.mark.anyio
async def test_ai_rate_limiter(client: AsyncClient, setup_ai_test_data) -> None:
    headers = setup_ai_test_data["auth_headers"]

    # Configure a custom rate limit of 2 calls per minute
    custom_limiter = TokenBucketRateLimiter(rate_limit=2, period=60.0)
    fake_provider = AsyncMock()
    fake_provider.generate_text.return_value = "Test response"
    fake_provider.model = "mock-model"
    
    # Initialize service with custom limiter
    service = AIService(provider=fake_provider, rate_limiter=custom_limiter)

    # Use FastAPI dependency overrides to inject the service
    app.dependency_overrides[get_ai_service] = lambda: service
    
    # Keep the user ID fixed to trigger rate limiting
    fixed_user = User(
        id=uuid.UUID("11111111-1111-1111-1111-111111111111"),
        email="mock_admin@edu.in",
        is_superuser=True,
        status=UserStatus.ACTIVE,
        tenant_id=setup_ai_test_data["tenant_a"].id
    )
    app.dependency_overrides[get_current_user] = lambda: fixed_user
    
    try:
        payload = {"prompt": "Quick hit prompt"}
        
        # 1st Call -> OK
        resp1 = await client.post("/api/v1/ai/query", json=payload, headers=headers)
        assert resp1.status_code == 200
        
        # 2nd Call -> OK
        resp2 = await client.post("/api/v1/ai/query", json=payload, headers=headers)
        assert resp2.status_code == 200
        
        # 3rd Call -> Rate Limited (429)
        resp3 = await client.post("/api/v1/ai/query", json=payload, headers=headers)
        assert resp3.status_code == 429
        assert "Rate limit exceeded" in resp3.json()["message"]
    finally:
        app.dependency_overrides.clear()


@pytest.mark.anyio
async def test_ai_provider_error_handling(client: AsyncClient, setup_ai_test_data) -> None:
    headers = setup_ai_test_data["auth_headers"]

    # Mock Gemini API returning 500 error payload
    with patch("app.core.settings.settings.AI_PROVIDER", "gemini"), \
         patch("app.core.settings.settings.GEMINI_API_KEY", "fake_key_gemini"):

        # Reset singleton to capture patched settings
        import app.api.dependencies.ai as dep_ai
        dep_ai._ai_service_instance = None

        mock_response = MockResponse(status_code=500, json_data={}, text="Internal Server Error")

        # Selectively patch HTTPX post requests to preserve test server routing
        original_post = httpx.AsyncClient.post
        async def mock_post(self_client, url, *args, **kwargs):
            url_str = str(url)
            if "googleapis.com" in url_str:
                return mock_response
            return await original_post(self_client, url, *args, **kwargs)

        with patch("httpx.AsyncClient.post", new=mock_post):
            payload = {"prompt": "Should trigger error"}
            resp = await client.post("/api/v1/ai/query", json=payload, headers=headers)
            assert resp.status_code == 502
            assert "Gemini service unavailable" in resp.json()["message"]
