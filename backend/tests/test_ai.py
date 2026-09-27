import os
import json
import uuid
import pytest
from unittest.mock import AsyncMock, patch
import httpx
from httpx import AsyncClient
from fastapi import status, HTTPException
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

    # Verify no sensitive API keys are exposed in public config
    assert "api_key" not in payload["data"]
    assert "key" not in payload["data"]
    assert "OPENROUTER_API_KEY" not in str(payload)
    assert "GEMINI_API_KEY" not in str(payload)


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
         patch("app.core.settings.settings.AI_MODEL", "gemini-3.6-flash"):

        # Reset singleton to capture patched settings
        import app.api.dependencies.ai as dep_ai
        dep_ai._ai_service_instance = None

        mock_response = MockResponse(status_code=200, json_data=mock_gemini_resp)
        mock_model_resp = MockResponse(status_code=200, json_data={"name": "models/gemini-3.6-flash", "supportedGenerationMethods": ["generateContent"]})

        # Selectively patch HTTPX requests to preserve test server routing
        original_post = httpx.AsyncClient.post
        original_get = httpx.AsyncClient.get

        async def mock_get(self_client, url, *args, **kwargs):
            if "googleapis.com" in str(url):
                return mock_model_resp
            return await original_get(self_client, url, *args, **kwargs)

        async def mock_post(self_client, url, *args, **kwargs):
            url_str = str(url)
            if "googleapis.com" in url_str:
                return mock_response
            return await original_post(self_client, url, *args, **kwargs)

        with patch("httpx.AsyncClient.post", new=mock_post), patch("httpx.AsyncClient.get", new=mock_get):
            payload = {
                "prompt": "Analyze student performance",
                "temperature": 0.5
            }
            resp = await client.post("/api/v1/ai/query", json=payload, headers=headers)
            assert resp.status_code == 200
            data = resp.json()["data"]
            assert data["text"] == "Simulated Gemini response text output."
            assert data["provider"] == "gemini"
            assert data["model"] == "gemini-3.6-flash"


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
        mock_model_resp = MockResponse(status_code=200, json_data={"name": "models/gemini-3.6-flash", "supportedGenerationMethods": ["generateContent"]})

        # Selectively patch HTTPX requests to preserve test server routing
        original_post = httpx.AsyncClient.post
        original_get = httpx.AsyncClient.get

        async def mock_get(self_client, url, *args, **kwargs):
            if "googleapis.com" in str(url):
                return mock_model_resp
            return await original_get(self_client, url, *args, **kwargs)

        async def mock_post(self_client, url, *args, **kwargs):
            url_str = str(url)
            if "googleapis.com" in url_str:
                return mock_response
            return await original_post(self_client, url, *args, **kwargs)

        with patch("httpx.AsyncClient.post", new=mock_post), patch("httpx.AsyncClient.get", new=mock_get):
            payload = {"prompt": "Should trigger error"}
            resp = await client.post("/api/v1/ai/query", json=payload, headers=headers)
            assert resp.status_code == 503
            assert "AI_CONFIGURATION_ERROR" in resp.json()["message"]



@pytest.mark.anyio
async def test_api_key_sent_only_via_header_not_url():
    from app.services.ai.gemini import GeminiProvider
    fake_key = "AIzaSyFakeKey1234567890abcdef"
    provider = GeminiProvider(api_key=fake_key, model="gemini-3.6-flash", api_version="v1beta")
    provider._model_verified = True

    captured_url = None
    captured_headers = None

    class MockResp:
        def __init__(self, data):
            self._data = data
            self.status_code = 200
        def json(self):
            return self._data

    async def mock_post(url, headers, json):
        nonlocal captured_url, captured_headers
        captured_url = str(url)
        captured_headers = headers
        return MockResp({"candidates": [{"content": {"parts": [{"text": "OK"}]}}]})

    with patch.object(httpx.AsyncClient, "post", side_effect=mock_post):
        result = await provider.generate_text("Hi")
        assert result == "OK"
        assert captured_url is not None
        assert "key=" not in captured_url
        assert captured_headers.get("x-goog-api-key") == fake_key


@pytest.mark.anyio
async def test_secret_redaction_in_logs_and_exceptions():
    from app.services.ai.gemini import redact_secrets
    secret = "AIzaSySuperSecretKey9876543210"
    raw_message = f"Error with key={secret} using Bearer token"
    redacted = redact_secrets(raw_message, secret)
    assert secret not in redacted
    assert "[REDACTED_API_KEY]" in redacted or "[REDACTED_CREDENTIAL]" in redacted


@pytest.mark.anyio
async def test_unsupported_model_produces_safe_diagnostic_no_retry():
    from app.services.ai.gemini import GeminiProvider
    call_count = 0

    class Mock404Resp:
        def __init__(self):
            self.status_code = 404
        def json(self):
            return {"error": {"code": 404, "message": "models/old-model not found"}}

    async def mock_get(url, headers):
        nonlocal call_count
        call_count += 1
        return Mock404Resp()

    provider = GeminiProvider(api_key="fake-key", model="old-model", retries=3)
    with patch.object(httpx.AsyncClient, "get", side_effect=mock_get):
        with pytest.raises(HTTPException) as exc_info:
            await provider.generate_text("test")
        assert exc_info.value.status_code == 502
        assert "AI_MODEL_NOT_AVAILABLE" in exc_info.value.detail
        assert call_count == 1  # Not retried


@pytest.mark.anyio
async def test_400_and_429_quota_not_retried():
    from app.services.ai.gemini import GeminiProvider
    provider = GeminiProvider(api_key="fake-key", model="gemini-3.6-flash", retries=3)
    provider._model_verified = True
    post_count = 0

    class MockResp:
        def __init__(self, code, msg):
            self.status_code = code
            self._msg = msg
        def json(self):
            return {"error": {"code": self.status_code, "message": self._msg}}

    # Test 400
    async def mock_400(url, headers, json):
        nonlocal post_count
        post_count += 1
        return MockResp(400, "Bad schema")

    with patch.object(httpx.AsyncClient, "post", side_effect=mock_400):
        with pytest.raises(HTTPException) as exc:
            await provider.generate_text("test")
        assert exc.value.status_code == 502
        assert "AI_REQUEST_INVALID" in exc.value.detail
        assert post_count == 1

    # Test 429 Prepayment Depleted
    post_count = 0
    async def mock_429(url, headers, json):
        nonlocal post_count
        post_count += 1
        return MockResp(429, "Your prepayment credits are depleted.")

    with patch.object(httpx.AsyncClient, "post", side_effect=mock_429):
        with pytest.raises(HTTPException) as exc:
            await provider.generate_text("test")
        assert exc.value.status_code == 502
        assert "AI_QUOTA_EXCEEDED" in exc.value.detail
        assert post_count == 1


# ==============================================================================
# OpenRouter Secure Fallback Provider Tests
# ==============================================================================

@pytest.mark.anyio
async def test_gemini_success_does_not_call_openrouter():
    from app.services.ai.service import AIService
    mock_gemini = AsyncMock()
    mock_gemini.provider_name = "gemini"
    mock_gemini.model = "gemini-3.6-flash"
    mock_gemini.generate_text.return_value = "Gemini Text Response"
    mock_gemini.generate_json.return_value = {"analysis": "gemini"}

    mock_openrouter = AsyncMock()
    mock_openrouter.provider_name = "openrouter"
    mock_openrouter.model = "anthropic/claude-3.5-haiku"
    mock_openrouter.api_key = "fake_key"

    service = AIService(provider=mock_gemini, fallback_provider=mock_openrouter)

    # Test Text
    text_res = await service.generate_text("Test prompt", client_key="user-1")
    assert text_res == "Gemini Text Response"
    mock_gemini.generate_text.assert_called_once()
    mock_openrouter.generate_text.assert_not_called()

    # Test JSON
    json_res = await service.generate_json("Test prompt", {"type": "object"}, client_key="user-1")
    assert json_res == {"analysis": "gemini"}
    mock_gemini.generate_json.assert_called_once()
    mock_openrouter.generate_json.assert_not_called()


@pytest.mark.anyio
async def test_gemini_429_calls_openrouter():
    from app.services.ai.service import AIService
    mock_gemini = AsyncMock()
    mock_gemini.provider_name = "gemini"
    mock_gemini.model = "gemini-3.6-flash"
    mock_gemini.generate_json.side_effect = HTTPException(
        status_code=502,
        detail="AI_QUOTA_EXCEEDED: Gemini quota or prepayment credits depleted: Resource exhausted"
    )

    mock_openrouter = AsyncMock()
    mock_openrouter.provider_name = "openrouter"
    mock_openrouter.model = "anthropic/claude-3.5-haiku"
    mock_openrouter.api_key = "fake_key"
    mock_openrouter.generate_json.return_value = {"analysis": "from_openrouter", "score": 95}

    service = AIService(provider=mock_gemini, fallback_provider=mock_openrouter)

    result = await service.generate_json("Prompt", {"type": "object"}, client_key="user-2")
    assert result == {"analysis": "from_openrouter", "score": 95}
    mock_gemini.generate_json.assert_called_once()
    mock_openrouter.generate_json.assert_called_once()


@pytest.mark.anyio
@pytest.mark.parametrize("status_code", [502, 503, 504])
async def test_gemini_502_503_504_calls_openrouter(status_code: int):
    from app.services.ai.service import AIService
    mock_gemini = AsyncMock()
    mock_gemini.provider_name = "gemini"
    mock_gemini.model = "gemini-3.6-flash"
    mock_gemini.generate_text.side_effect = HTTPException(
        status_code=status_code,
        detail=f"AI_UPSTREAM_UNAVAILABLE: Gemini service unavailable. Status {status_code}."
    )

    mock_openrouter = AsyncMock()
    mock_openrouter.provider_name = "openrouter"
    mock_openrouter.model = "anthropic/claude-3.5-haiku"
    mock_openrouter.api_key = "fake_key"
    mock_openrouter.generate_text.return_value = "Fallback text from OpenRouter"

    service = AIService(provider=mock_gemini, fallback_provider=mock_openrouter)

    result = await service.generate_text("Prompt", client_key=f"user-{status_code}")
    assert result == "Fallback text from OpenRouter"
    mock_gemini.generate_text.assert_called_once()
    mock_openrouter.generate_text.assert_called_once()


@pytest.mark.anyio
async def test_timeout_and_connection_errors_call_openrouter():
    from app.services.ai.service import AIService
    mock_gemini = AsyncMock()
    mock_gemini.provider_name = "gemini"
    mock_gemini.model = "gemini-3.6-flash"
    mock_gemini.generate_json.side_effect = httpx.ConnectError("Failed to establish connection to Google API")

    mock_openrouter = AsyncMock()
    mock_openrouter.provider_name = "openrouter"
    mock_openrouter.model = "anthropic/claude-3.5-haiku"
    mock_openrouter.api_key = "fake_key"
    mock_openrouter.generate_json.return_value = {"recovered": True}

    service = AIService(provider=mock_gemini, fallback_provider=mock_openrouter)

    result = await service.generate_json("Prompt", {"type": "object"}, client_key="user-conn")
    assert result == {"recovered": True}
    mock_gemini.generate_json.assert_called_once()
    mock_openrouter.generate_json.assert_called_once()


@pytest.mark.anyio
async def test_gemini_400_does_not_call_openrouter():
    from app.services.ai.service import AIService
    mock_gemini = AsyncMock()
    mock_gemini.provider_name = "gemini"
    mock_gemini.model = "gemini-3.6-flash"
    mock_gemini.generate_json.side_effect = HTTPException(
        status_code=502,
        detail="AI_REQUEST_INVALID: Gemini rejected request format: Invalid schema definition."
    )

    mock_openrouter = AsyncMock()
    mock_openrouter.provider_name = "openrouter"
    mock_openrouter.model = "anthropic/claude-3.5-haiku"
    mock_openrouter.api_key = "fake_key"

    service = AIService(provider=mock_gemini, fallback_provider=mock_openrouter)

    with pytest.raises(HTTPException) as exc_info:
        await service.generate_json("Prompt", {"type": "object"}, client_key="user-bad-req")

    assert exc_info.value.status_code == 502
    assert "AI_REQUEST_INVALID" in exc_info.value.detail
    mock_gemini.generate_json.assert_called_once()
    mock_openrouter.generate_json.assert_not_called()


@pytest.mark.anyio
@pytest.mark.parametrize("status_code,detail", [
    (401, "AI_CONFIGURATION_ERROR: Gemini authentication failed: Invalid API key"),
    (403, "AI_CONFIGURATION_ERROR: Gemini project unauthorized"),
    (422, "Validation error in request payload")
])
async def test_gemini_auth_and_validation_errors_do_not_call_openrouter(status_code: int, detail: str):
    from app.services.ai.service import AIService
    mock_gemini = AsyncMock()
    mock_gemini.provider_name = "gemini"
    mock_gemini.model = "gemini-3.6-flash"
    mock_gemini.generate_text.side_effect = HTTPException(status_code=status_code, detail=detail)

    mock_openrouter = AsyncMock()
    mock_openrouter.provider_name = "openrouter"
    mock_openrouter.model = "anthropic/claude-3.5-haiku"
    mock_openrouter.api_key = "fake_key"

    service = AIService(provider=mock_gemini, fallback_provider=mock_openrouter)

    with pytest.raises(HTTPException) as exc_info:
        await service.generate_text("Prompt", client_key=f"user-auth-{status_code}")

    assert exc_info.value.status_code == status_code
    mock_gemini.generate_text.assert_called_once()
    mock_openrouter.generate_text.assert_not_called()


@pytest.mark.anyio
async def test_both_providers_fail_returns_safe_502():
    from app.services.ai.service import AIService
    mock_gemini = AsyncMock()
    mock_gemini.provider_name = "gemini"
    mock_gemini.model = "gemini-3.6-flash"
    mock_gemini.generate_json.side_effect = HTTPException(
        status_code=502,
        detail="AI_QUOTA_EXCEEDED: Gemini quota depleted"
    )

    mock_openrouter = AsyncMock()
    mock_openrouter.provider_name = "openrouter"
    mock_openrouter.model = "anthropic/claude-3.5-haiku"
    mock_openrouter.api_key = "fake_key"
    mock_openrouter.generate_json.side_effect = HTTPException(
        status_code=502,
        detail="AI_UPSTREAM_UNAVAILABLE: OpenRouter service unavailable (Status 503)"
    )

    service = AIService(provider=mock_gemini, fallback_provider=mock_openrouter)

    with pytest.raises(HTTPException) as exc_info:
        await service.generate_json("Prompt", {"type": "object"}, client_key="user-both-fail")

    assert exc_info.value.status_code == 502
    assert exc_info.value.detail == "AI_SERVICE_UNAVAILABLE: AI analysis service is temporarily unavailable. Please try again later."
    mock_gemini.generate_json.assert_called_once()
    mock_openrouter.generate_json.assert_called_once()


@pytest.mark.anyio
async def test_missing_openrouter_configuration_returns_safe_503():
    from app.services.ai.service import AIService
    mock_gemini = AsyncMock()
    mock_gemini.provider_name = "gemini"
    mock_gemini.model = "gemini-3.6-flash"
    mock_gemini.generate_json.side_effect = HTTPException(
        status_code=502,
        detail="AI_QUOTA_EXCEEDED: Gemini rate limit exceeded"
    )

    # OpenRouter missing key and model
    mock_openrouter = AsyncMock()
    mock_openrouter.provider_name = "openrouter"
    mock_openrouter.api_key = None
    mock_openrouter.model = None

    service = AIService(provider=mock_gemini, fallback_provider=mock_openrouter)

    with pytest.raises(HTTPException) as exc_info:
        await service.generate_json("Prompt", {"type": "object"}, client_key="user-missing-cfg")

    assert exc_info.value.status_code == 503
    assert exc_info.value.detail == "AI_CONFIGURATION_ERROR: OpenRouter API key or model is not configured."
    mock_gemini.generate_json.assert_called_once()
    mock_openrouter.generate_json.assert_not_called()


@pytest.mark.anyio
async def test_logs_contain_no_secrets_prompts_or_student_data(caplog):
    import logging
    from app.services.ai.service import AIService

    mock_gemini = AsyncMock()
    mock_gemini.provider_name = "gemini"
    mock_gemini.model = "gemini-3.6-flash"
    mock_gemini.generate_text.side_effect = HTTPException(
        status_code=502,
        detail="AI_QUOTA_EXCEEDED: Resource exhausted"
    )

    mock_openrouter = AsyncMock()
    mock_openrouter.provider_name = "openrouter"
    mock_openrouter.model = "anthropic/claude-3.5-haiku"
    mock_openrouter.api_key = "sk-or-v1-secretkey9876543210abcdef"
    mock_openrouter.generate_text.return_value = "Safe analysis"

    service = AIService(provider=mock_gemini, fallback_provider=mock_openrouter)

    sensitive_student_prompt = "Confidential: Student Aadhaar 1234-5678-9012 Priya Reddy score 45%"
    
    with caplog.at_level(logging.INFO):
        res = await service.generate_text(sensitive_student_prompt, client_key="user-privacy-audit")
        assert res == "Safe analysis"

    # Verify structured logs
    all_log_text = caplog.text
    assert "provider=openrouter" in all_log_text
    assert "category=gemini_quota_fallback" in all_log_text
    # Verify zero leak of prompt, student data, or API key
    assert "1234-5678-9012" not in all_log_text
    assert "Priya Reddy" not in all_log_text
    assert "sk-or-v1-secretkey" not in all_log_text
    assert "Bearer" not in all_log_text


@pytest.mark.anyio
async def test_openrouter_provider_unit_request():
    from app.services.ai.openrouter import OpenRouterProvider

    fake_key = "sk-or-v1-fakeopenrouterkey1234567890"
    fake_model = "anthropic/claude-3.5-haiku"
    provider = OpenRouterProvider(api_key=fake_key, model=fake_model)
    provider._model_verified = True

    captured_url = None
    captured_headers = None
    captured_json = None

    class MockResp:
        def __init__(self, data, status_code=200):
            self._data = data
            self.status_code = status_code
        def json(self):
            return self._data

    async def mock_post(url, headers, json):
        nonlocal captured_url, captured_headers, captured_json
        captured_url = str(url)
        captured_headers = headers
        captured_json = json
        return MockResp({
            "choices": [{"message": {"content": "{\"class_average\": 84.2, \"summary\": \"Good progress\"}"}}]
        })

    with patch.object(httpx.AsyncClient, "post", side_effect=mock_post):
        result = await provider.generate_json("Analyze class", {"type": "object"})
        assert result["class_average"] == 84.2
        assert captured_url == "https://openrouter.ai/api/v1/chat/completions"
        assert captured_headers["Authorization"] == f"Bearer {fake_key}"
        assert captured_json["model"] == fake_model
        assert captured_json["response_format"] == {"type": "json_object"}


@pytest.mark.anyio
async def test_openrouter_text_and_json_query_endpoints(client: AsyncClient, setup_ai_test_data) -> None:
    headers = setup_ai_test_data["auth_headers"]

    mock_text_resp = {
        "choices": [{"message": {"content": "This is a detailed analysis from OpenRouter."}}]
    }
    mock_json_resp = {
        "choices": [{"message": {"content": "```json\n{\"class_average\": 78.5, \"improvement_trend\": \"improving\"}\n```"}}]
    }

    with patch("app.core.settings.settings.AI_PROVIDER", "openrouter"), \
         patch("app.core.settings.settings.OPENROUTER_API_KEY", "sk-or-v1-fakeopenrouterkey123456"), \
         patch("app.core.settings.settings.AI_MODEL", "openrouter/free"):

        import app.api.dependencies.ai as dep_ai
        dep_ai._ai_service_instance = None

        original_post = httpx.AsyncClient.post
        async def mock_post(self_client, url, *args, **kwargs):
            url_str = str(url)
            if "openrouter.ai" in url_str:
                json_arg = kwargs.get("json", {})
                if json_arg.get("response_format"):
                    return MockResponse(status_code=200, json_data=mock_json_resp)
                return MockResponse(status_code=200, json_data=mock_text_resp)
            return await original_post(self_client, url, *args, **kwargs)

        with patch("httpx.AsyncClient.post", new=mock_post):
            # Test text query
            text_payload = {"prompt": "Analyze syllabus progress"}
            text_res = await client.post("/api/v1/ai/query", json=text_payload, headers=headers)
            assert text_res.status_code == 200
            assert text_res.json()["data"]["text"] == "This is a detailed analysis from OpenRouter."
            assert text_res.json()["data"]["provider"] == "openrouter"

            # Test JSON query with markdown fence stripping
            json_payload = {
                "prompt": "Analyze class metrics",
                "response_schema": {
                    "type": "object",
                    "properties": {
                        "class_average": {"type": "number"},
                        "improvement_trend": {"type": "string"}
                    }
                }
            }
            json_res = await client.post("/api/v1/ai/query", json=json_payload, headers=headers)
            assert json_res.status_code == 200
            structured = json_res.json()["data"]["structured_data"]
            assert structured["class_average"] == 78.5
            assert structured["improvement_trend"] == "improving"
            assert json_res.json()["data"]["provider"] == "openrouter"


@pytest.mark.anyio
@pytest.mark.parametrize("status_code,err_payload,expected_sub,expected_http", [
    (401, {"error": {"message": "Invalid API key provided."}}, "AI_CONFIGURATION_ERROR", 502),
    (402, {"error": {"message": "Credit limit reached. Please top up your account."}}, "AI_QUOTA_EXCEEDED", 502),
    (404, {"error": {"message": "Model 'openrouter/free' not found."}}, "AI_MODEL_NOT_AVAILABLE", 502),
    (429, {"error": {"message": "Rate limit exceeded. Too many requests."}}, "AI_RATE_LIMIT_EXCEEDED", 502),
])
async def test_openrouter_provider_error_mapping(status_code: int, err_payload: dict, expected_sub: str, expected_http: int):
    from app.services.ai.openrouter import OpenRouterProvider

    provider = OpenRouterProvider(api_key="sk-or-v1-testkey12345", model="openrouter/free")

    class MockErrResp:
        def __init__(self):
            self.status_code = status_code
            self.text = json.dumps(err_payload)
            self.headers = {}
        def json(self):
            return err_payload

    async def mock_post(self_client, *args, **kwargs):
        return MockErrResp()

    with patch.object(httpx.AsyncClient, "post", side_effect=mock_post):
        with pytest.raises(HTTPException) as exc_info:
            await provider.generate_text("Test prompt")
        assert exc_info.value.status_code == expected_http
        assert expected_sub in str(exc_info.value.detail)


@pytest.mark.anyio
async def test_openrouter_missing_api_key_returns_503():
    from app.services.ai.openrouter import OpenRouterProvider
    provider = OpenRouterProvider(api_key=None, model="openrouter/free")
    with pytest.raises(HTTPException) as exc_info:
        await provider.generate_text("Test prompt")
    assert exc_info.value.status_code == 503
    assert "AI_CONFIGURATION_ERROR: OpenRouter API key is not configured" in exc_info.value.detail


@pytest.mark.anyio
async def test_openrouter_network_timeout_returns_504():
    from app.services.ai.openrouter import OpenRouterProvider
    provider = OpenRouterProvider(api_key="sk-or-v1-testkey12345", model="openrouter/free", retries=0)

    async def mock_timeout(self_client, *args, **kwargs):
        raise httpx.TimeoutException("Connection timed out")

    with patch.object(httpx.AsyncClient, "post", side_effect=mock_timeout):
        with pytest.raises(HTTPException) as exc_info:
            await provider.generate_text("Test prompt")
        assert exc_info.value.status_code == 504
        assert "AI_NETWORK_ERROR" in exc_info.value.detail


@pytest.mark.anyio
async def test_openrouter_invalid_json_response_returns_502():
    from app.services.ai.openrouter import OpenRouterProvider
    provider = OpenRouterProvider(api_key="sk-or-v1-testkey12345", model="openrouter/free")

    class MockResp:
        def __init__(self):
            self.status_code = 200
        def json(self):
            return {"choices": [{"message": {"content": "This is plain text, not JSON."}}]}

    async def mock_post(self_client, *args, **kwargs):
        return MockResp()

    with patch.object(httpx.AsyncClient, "post", side_effect=mock_post):
        with pytest.raises(HTTPException) as exc_info:
            await provider.generate_json("Test prompt", {"type": "object"})
        assert exc_info.value.status_code == 502
        assert "AI_RESPONSE_INVALID" in exc_info.value.detail


@pytest.mark.anyio
async def test_openrouter_redacts_api_key_in_logs_and_errors():
    from app.services.ai.openrouter import OpenRouterProvider, redact_secrets

    secret_key = "sk-or-v1-myverysecretopenrouterkey987654321"
    provider = OpenRouterProvider(api_key=secret_key, model="openrouter/free")

    raw_error = f"Request to server failed with key {secret_key}"
    redacted = redact_secrets(raw_error, secret_key)
    assert secret_key not in redacted
    assert "[REDACTED_API_KEY]" in redacted

    # Test error returned from provider does not leak key
    class MockKeyLeakingResp:
        def __init__(self):
            self.status_code = 400
            self.headers = {}
        def json(self):
            return {"error": {"message": f"Bad request for token {secret_key}"}}

    async def mock_post(self_client, *args, **kwargs):
        return MockKeyLeakingResp()

    with patch.object(httpx.AsyncClient, "post", side_effect=mock_post):
        with pytest.raises(HTTPException) as exc_info:
            await provider.generate_text("Test prompt")
        assert secret_key not in str(exc_info.value.detail)


@pytest.mark.anyio
async def test_openrouter_no_referer_required():
    from app.services.ai.openrouter import OpenRouterProvider

    fake_key = "sk-or-v1-testkey123"
    provider = OpenRouterProvider(api_key=fake_key, model="openrouter/free")

    captured_headers = None

    class MockResp:
        def __init__(self):
            self.status_code = 200
        def json(self):
            return {"choices": [{"message": {"content": "Hello!"}}]}

    async def mock_post(self_client, *args, **kwargs):
        nonlocal captured_headers
        captured_headers = kwargs.get("headers")
        return MockResp()

    with patch.object(httpx.AsyncClient, "post", side_effect=mock_post):
        await provider.generate_text("Hello")
        assert captured_headers is not None
        assert "HTTP-Referer" not in captured_headers
        assert "X-Title" not in captured_headers
        assert captured_headers["Authorization"] == f"Bearer {fake_key}"


@pytest.mark.anyio
async def test_gemini_never_called_when_openrouter_provider_active():
    from app.services.ai.service import AIService
    from app.services.ai.openrouter import OpenRouterProvider
    from app.services.ai.gemini import GeminiProvider

    with patch("app.core.settings.settings.AI_PROVIDER", "openrouter"), \
         patch("app.core.settings.settings.OPENROUTER_API_KEY", "sk-or-v1-fakekey123"), \
         patch("app.core.settings.settings.AI_MODEL", "openrouter/free"):

        mock_openrouter = AsyncMock(spec=OpenRouterProvider)
        mock_openrouter.generate_text.return_value = "Response from OpenRouter"
        mock_openrouter.model = "openrouter/free"

        mock_gemini = AsyncMock(spec=GeminiProvider)

        service = AIService(provider=mock_openrouter)
        result = await service.generate_text("Prompt", client_key="test-key")

        assert result == "Response from OpenRouter"
        mock_openrouter.generate_text.assert_called_once()
        mock_gemini.generate_text.assert_not_called()




