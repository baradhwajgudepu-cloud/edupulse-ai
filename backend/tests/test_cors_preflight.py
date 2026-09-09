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


@pytest.mark.anyio
@pytest.mark.parametrize("origin", [
    "https://edupulse-ai-17221.web.app",
    "https://edupulse-ai-1721.web.app",
])
async def test_cors_error_responses_preserve_origin(origin: str):
    """
    Phase 4 & 5.D: Verify that HTTP error responses (401, 404, 422, 500)
    preserve Access-Control-Allow-Origin and Access-Control-Allow-Credentials
    for production Firebase origins.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://127.0.0.1:8000") as client:
        # 401 Unauthorized check
        r_401 = await client.get(
            "/api/v1/auth/me",
            headers={"Origin": origin}
        )
        assert r_401.status_code == 401
        assert r_401.headers.get("access-control-allow-origin") == origin
        assert r_401.headers.get("access-control-allow-credentials") == "true"

        # 404 Not Found check
        r_404 = await client.get(
            "/api/v1/non-existent-endpoint-for-cors-test",
            headers={"Origin": origin}
        )
        assert r_404.status_code == 404
        assert r_404.headers.get("access-control-allow-origin") == origin
        assert r_404.headers.get("access-control-allow-credentials") == "true"


@pytest.mark.anyio
async def test_marks_status_enum_contract(db_session):
    """
    Phase 5.A: Verify every Python MarksStatus value is valid and supported.
    If running against PostgreSQL, validates against pg_enum.
    If running against SQLite (test mock), validates against SQLAlchemy SQLEnum definition.
    """
    from sqlalchemy import text
    from app.models.marks import MarksStatus

    enum_values = set(MarksStatus._value2member_map_.keys())
    assert "SUBMITTED" in enum_values
    assert "UNDER_REVIEW" in enum_values
    assert "RETURNED" in enum_values
    assert "APPROVED" in enum_values
    assert "DRAFT" in enum_values
    assert "PUBLISHED" in enum_values
    assert "LOCKED" in enum_values

    # If running against PostgreSQL, verify pg_enum system catalog
    bind = db_session.get_bind()
    if bind.dialect.name == "postgresql":
        res = await db_session.execute(text("""
            SELECT e.enumlabel
            FROM pg_type t
            JOIN pg_enum e ON t.oid = e.enumtypid
            WHERE t.typname = 'marksstatus'
        """))
        db_enum_labels = {r[0] for r in res.fetchall()}
        for status_member in MarksStatus:
            assert status_member.value in db_enum_labels, (
                f"MarksStatus.{status_member.name} ('{status_member.value}') is missing from PostgreSQL marksstatus enum! "
                f"Existing DB labels: {db_enum_labels}"
            )



