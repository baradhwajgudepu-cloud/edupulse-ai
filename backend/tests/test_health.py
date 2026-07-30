import pytest
from httpx import AsyncClient

@pytest.mark.anyio
async def test_system_health_endpoint(client: AsyncClient) -> None:
    """
    Asserts that the custom system health check endpoint evaluates
    successfully, returns HTTP 200, and matches standard response format.
    """
    response = await client.get("/api/v1/system/health")
    
    assert response.status_code == 200
    
    payload = response.json()
    assert payload["application"] == "EduPulse AI"
    assert payload["version"] == "1.0"
    assert payload["status"] == "healthy"
    assert payload["database"] == "healthy"
    assert "uptime" in payload
    assert "timestamp" in payload
