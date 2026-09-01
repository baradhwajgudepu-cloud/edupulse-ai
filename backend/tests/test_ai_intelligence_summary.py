import pytest
import uuid
from httpx import AsyncClient
from app.main import app
from app.db.session import AsyncSessionLocal
from app.models.user import User
from app.models.tenant import Tenant
from app.models.academic_year import AcademicYear
from app.models.class_entity import Class
from app.models.section import Section
from app.models.subject import Subject
from app.models.examination import Examination, ExamSchedule, ExamStatus
from app.models.marks import Marks, MarksStatus
from app.core.security import create_access_token


@pytest.mark.anyio
async def test_ai_intelligence_summary_endpoint():
    async with AsyncSessionLocal() as session:
        # Fetch or verify existing tenant
        from sqlalchemy import select
        res_t = await session.execute(select(Tenant).limit(1))
        tenant = res_t.scalar_one_or_none()
        if not tenant:
            pytest.skip("No test tenant available")

        res_u = await session.execute(select(User).where(User.tenant_id == tenant.id).limit(1))
        user = res_u.scalar_one_or_none()
        if not user:
            pytest.skip("No test user available")

        # Generate token
        token = create_access_token(
            subject=str(user.id),
            tenant_id=str(tenant.id)
        )

        headers = {
            "Authorization": f"Bearer {token}",
            "X-Tenant-ID": str(tenant.id)
        }

        import httpx
        transport = httpx.ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            response = await ac.get("/api/v1/ai-intelligence/summary", headers=headers)
            assert response.status_code == 200, f"Error: {response.text}"
            data = response.json()
            assert data["success"] is True
            payload = data["data"]
            assert "school_health_score" in payload
            assert "sub_scores" in payload
            assert "academic_risk_radar" in payload
            assert "performance_trends" in payload
            assert "subject_difficulty_analysis" in payload
            assert "marks_anomalies" in payload
            print("\nAI Intelligence Summary Test Passed Successfully!")
            print(f"School Health Score: {payload['school_health_score']}")
            print(f"Summary: {payload['ai_executive_summary']}")
