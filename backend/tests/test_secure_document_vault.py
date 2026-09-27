import pytest
import uuid
from datetime import date, timedelta
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.school_administration import (
    SchoolDocument, DocumentAccessLog, DocumentCategory, ConfidentialityLevel
)
from app.main import app
from app.api.dependencies.auth import get_current_user
from tests.test_examinations import setup_exam_test_data


@pytest.mark.anyio
async def test_secure_document_vault_lifecycle(
    client: AsyncClient, setup_exam_test_data, db_session: AsyncSession
) -> None:
    data = setup_exam_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id
    tenant_id = data["tenant_a"].id
    admin_user = data["user_admin"]

    async def mock_admin():
        return admin_user

    app.dependency_overrides[get_current_user] = mock_admin

    try:
        # 1. POST Upload Standard Document (Building Safety)
        std_payload = {
            "category": "BUILDING",
            "title": "Structural Safety Certificate 2026",
            "document_number": "STRUCT-HYD-2026-09",
            "file_name": "structural_safety_cert.pdf",
            "file_path": f"schools/{school_id}/documents/building/structural_safety_cert.pdf",
            "file_size_bytes": 102400,
            "content_type": "application/pdf",
            "expiry_date": (date.today() + timedelta(days=45)).isoformat(),  # Expiring soon (<60 days)
            "confidentiality_level": "STANDARD",
            "is_password_protected": False,
            "remarks": "Issued by Municipal Engineers Department"
        }
        resp_std = await client.post(f"/api/v1/schools/{school_id}/documents", json=std_payload, headers=headers)
        assert resp_std.status_code == 201, resp_std.text
        std_doc = resp_std.json()["data"]
        assert std_doc["is_password_protected"] is False
        assert std_doc["is_expiring_soon"] is True

        # 2. POST Upload Password-Protected Highly Confidential Document (Faculty Salaries & Audit)
        conf_payload = {
            "category": "FINANCIAL",
            "title": "Annual Financial Audit & Statutory Filings",
            "document_number": "AUDIT-2025-2026-SEC",
            "file_name": "annual_financial_audit.pdf",
            "file_path": f"schools/{school_id}/documents/financial/annual_financial_audit.pdf",
            "file_size_bytes": 204800,
            "content_type": "application/pdf",
            "expiry_date": (date.today() + timedelta(days=365)).isoformat(),
            "confidentiality_level": "HIGHLY_CONFIDENTIAL",
            "is_password_protected": True,
            "passcode": "Vault@Pass#2026",
            "remarks": "Strictly confidential - Management and Statutory Auditor eyes only"
        }
        resp_conf = await client.post(f"/api/v1/schools/{school_id}/documents", json=conf_payload, headers=headers)
        assert resp_conf.status_code == 201, resp_conf.text
        conf_doc = resp_conf.json()["data"]
        conf_doc_id = conf_doc["id"]
        assert conf_doc["is_password_protected"] is True

        # Verify DB does NOT store plaintext passcode
        db_doc = await db_session.get(SchoolDocument, uuid.UUID(conf_doc_id))
        assert db_doc.passcode_hash is not None
        assert "Vault@Pass#2026" not in db_doc.passcode_hash
        assert db_doc.passcode_salt is not None

        # 3. Download attempt without unlock token should be rejected (403)
        resp_fail_dl = await client.get(f"/api/v1/documents/{conf_doc_id}/download", headers=headers)
        assert resp_fail_dl.status_code == 403, resp_fail_dl.text

        # 4. Attempt unlock with incorrect passcode should be rejected (403)
        resp_wrong_unlock = await client.post(
            f"/api/v1/documents/{conf_doc_id}/unlock",
            json={"passcode": "WrongPassword123"},
            headers=headers
        )
        assert resp_wrong_unlock.status_code == 403, resp_wrong_unlock.text

        # 5. Attempt unlock with correct passcode should succeed and return unlock token
        resp_unlock = await client.post(
            f"/api/v1/documents/{conf_doc_id}/unlock",
            json={"passcode": "Vault@Pass#2026"},
            headers=headers
        )
        assert resp_unlock.status_code == 200, resp_unlock.text
        unlock_data = resp_unlock.json()["data"]
        assert unlock_data["is_unlocked"] is True
        unlock_token = unlock_data["unlock_token"]
        assert unlock_token is not None

        # 6. Download with valid unlock token should succeed (200)
        resp_dl = await client.get(
            f"/api/v1/documents/{conf_doc_id}/download?unlock_token={unlock_token}",
            headers=headers
        )
        assert resp_dl.status_code == 200, resp_dl.text
        assert resp_dl.headers["content-type"] == "application/pdf"

        # 7. GET Document Expiry Monitor
        resp_monitor = await client.get(f"/api/v1/schools/{school_id}/documents/expiry-monitor", headers=headers)
        assert resp_monitor.status_code == 200, resp_monitor.text
        monitor_data = resp_monitor.json()["data"]
        assert monitor_data["total_monitored"] >= 2
        assert monitor_data["expiring_soon_count"] >= 1
        alerts = monitor_data["alerts"]
        alert_titles = [a["title"] for a in alerts]
        assert "Structural Safety Certificate 2026" in alert_titles

        # 8. GET Document Access Logs
        resp_logs = await client.get(f"/api/v1/schools/{school_id}/documents/access-logs", headers=headers)
        assert resp_logs.status_code == 200, resp_logs.text
        access_logs = resp_logs.json()["data"]
        actions = [l["action"] for l in access_logs]
        assert "UPLOAD" in actions
        assert "UNLOCK_FAILED" in actions
        assert "UNLOCK_SUCCESS" in actions
        assert "DOWNLOAD" in actions

    finally:
        app.dependency_overrides.pop(get_current_user, None)
