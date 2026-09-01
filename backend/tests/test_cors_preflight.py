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
