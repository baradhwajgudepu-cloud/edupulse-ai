import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app

ONBOARDING_ENDPOINTS = [
    "/api/v1/schools",
    "/api/v1/schools/31fc286c-06aa-43c6-8100-eec205b43965/academic-years",
    "/api/v1/classes",
    "/api/v1/sections",
    "/api/v1/subjects",
    "/api/v1/teachers",
    "/api/v1/guardians",
    "/api/v1/students",
    "/api/v1/student-guardians",
    "/api/v1/teacher-subject-assignments",
    "/api/v1/timetables",
    "/api/v1/syllabuses",
    "/api/v1/examinations",
]

@pytest.mark.anyio
@pytest.mark.parametrize("endpoint", ONBOARDING_ENDPOINTS)
async def test_cors_preflight_onboarding_matrix(endpoint: str):
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://127.0.0.1:8000") as client:
        # Preflight OPTIONS request from Admin Portal origin (127.0.0.1:11500)
        response = await client.options(
            endpoint,
            headers={
                "Origin": "http://127.0.0.1:11500",
                "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": "authorization,content-type,x-tenant-id,x-school-id",
            }
        )
        assert response.status_code == 200, f"Failed preflight for {endpoint}"
        assert response.headers.get("access-control-allow-origin") == "http://127.0.0.1:11500"
        assert response.headers.get("access-control-allow-credentials") == "true"
        assert "POST" in response.headers.get("access-control-allow-methods", "")
        
        # Preflight OPTIONS request from localhost:11500
        response_lh = await client.options(
            endpoint,
            headers={
                "Origin": "http://localhost:11500",
                "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": "authorization,content-type,x-tenant-id,x-school-id",
            }
        )
        assert response_lh.status_code == 200, f"Failed preflight for {endpoint} with localhost"
        assert response_lh.headers.get("access-control-allow-origin") == "http://localhost:11500"


@pytest.mark.anyio
@pytest.mark.parametrize("origin", [
    "https://edupulse-ai-1721.web.app",
    "https://edupulse-ai-1721.firebaseapp.com",
    "https://edupulse-ai-17221.web.app",
    "https://edupulse-ai-17221.firebaseapp.com",
    "http://localhost:3000",
    "http://127.0.0.1:3000",
])
async def test_cors_preflight_marks_upload_endpoint(origin: str):
    """
    Verify production browser preflight OPTIONS request containing:
    - Origin
    - Access-Control-Request-Method: POST
    - Access-Control-Request-Headers: authorization,content-type,x-tenant-id
    succeeds with 200 OK and includes X-Tenant-ID in Access-Control-Allow-Headers.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://127.0.0.1:8000") as client:
        exam_id = "c7a52511-b0db-4643-a6fe-4f113a968a3e"
        endpoint = f"/api/v1/marks/examinations/{exam_id}/upload-class-all-subjects"
        response = await client.options(
            endpoint,
            headers={
                "Origin": origin,
                "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": "authorization,content-type,x-tenant-id",
            }
        )
        assert response.status_code == 200, f"Failed preflight for {origin}"
        assert response.headers.get("access-control-allow-origin") == origin
        assert response.headers.get("access-control-allow-credentials") == "true"
        assert "POST" in response.headers.get("access-control-allow-methods", "")

        allow_headers = response.headers.get("access-control-allow-headers", "").lower()
        assert "x-tenant-id" in allow_headers, f"x-tenant-id missing from allow-headers: {allow_headers}"
        assert "authorization" in allow_headers, f"authorization missing from allow-headers: {allow_headers}"
        assert "content-type" in allow_headers, f"content-type missing from allow-headers: {allow_headers}"


@pytest.mark.anyio
async def test_cors_preflight_disallowed_origin():
    """
    Verify that an untrusted origin is strictly rejected by CORSMiddleware.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://127.0.0.1:8000") as client:
        endpoint = "/api/v1/marks/examinations/c7a52511-b0db-4643-a6fe-4f113a968a3e/upload-class-all-subjects"
        response = await client.options(
            endpoint,
            headers={
                "Origin": "https://malicious.attacker.com",
                "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": "authorization,content-type,x-tenant-id",
            }
        )
        assert response.status_code == 400
        assert "Disallowed CORS origin" in response.text
        assert response.headers.get("access-control-allow-origin") is None

