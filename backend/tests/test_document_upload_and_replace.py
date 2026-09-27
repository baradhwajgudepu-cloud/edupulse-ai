import pytest
import uuid
import io
from datetime import date, timedelta
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from PIL import Image as PILImage

from app.models.school_administration import (
    SchoolDocument, DocumentAccessLog, DocumentCategory, ConfidentialityLevel, DocumentAction
)
from app.main import app
from app.api.dependencies.auth import get_current_user
from tests.test_examinations import setup_exam_test_data


def create_sample_png() -> bytes:
    img = PILImage.new("RGBA", (100, 100), color=(75, 70, 229, 255))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def create_sample_pdf(title: str = "Test Official Record") -> bytes:
    return f"%PDF-1.4\n% EduPulse Verified Document\n% Title: {title}\n%%EOF".encode()


@pytest.mark.anyio
async def test_document_upload_and_replace_lifecycle(
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
        # 1. Test PDF Document Upload via multipart/form-data
        pdf_bytes = create_sample_pdf("CBSE Formal Recognition Certificate")
        files = {
            "file": ("cbse_recognition_cert.pdf", pdf_bytes, "application/pdf")
        }
        form_data = {
            "category": "RECOGNITION",
            "title": "CBSE Formal Recognition Certificate",
            "issuing_authority": "Central Board of Secondary Education",
            "document_number": "CBSE/RECOG/2026/01",
            "issue_date": "2026-01-15",
            "expiry_date": (date.today() + timedelta(days=365)).isoformat(),
            "confidentiality_level": "STANDARD",
            "is_password_protected": "false",
            "remarks": "Official affiliation renewal certificate"
        }

        resp_pdf = await client.post(
            f"/api/v1/schools/{school_id}/documents/upload",
            data=form_data,
            files=files,
            headers=headers
        )
        assert resp_pdf.status_code == 201, resp_pdf.text
        doc_pdf = resp_pdf.json()["data"]
        doc_id = doc_pdf["id"]
        assert doc_pdf["category"] == "RECOGNITION"
        assert doc_pdf["title"] == "CBSE Formal Recognition Certificate"
        assert doc_pdf["issuing_authority"] == "Central Board of Secondary Education"
        assert doc_pdf["document_number"] == "CBSE/RECOG/2026/01"
        assert doc_pdf["file_name"] == "cbse_recognition_cert.pdf"
        assert doc_pdf["content_type"] == "application/pdf"
        assert doc_pdf["file_size_bytes"] == len(pdf_bytes)

        # Verify access log has UPLOAD
        stmt_log = select(DocumentAccessLog).where(
            DocumentAccessLog.document_id == uuid.UUID(doc_id),
            DocumentAccessLog.action == DocumentAction.UPLOAD
        )
        log_entry = (await db_session.execute(stmt_log)).scalar_one_or_none()
        assert log_entry is not None

        # 2. Test Image Upload (PNG)
        png_bytes = create_sample_png()
        files_img = {
            "file": ("fire_safety_inspection.png", png_bytes, "image/png")
        }
        form_data_img = {
            "category": "FIRE_SAFETY",
            "title": "Fire & Emergency Services Clearance",
            "issuing_authority": "State Disaster Response & Fire Services",
            "document_number": "NOC/FIRE/HYD/2026/99",
            "issue_date": "2026-03-01",
            "expiry_date": (date.today() + timedelta(days=30)).isoformat(),
            "confidentiality_level": "STANDARD",
            "is_password_protected": "false",
            "remarks": "Annual safety inspection clearance"
        }

        resp_img = await client.post(
            f"/api/v1/schools/{school_id}/documents/upload",
            data=form_data_img,
            files=files_img,
            headers=headers
        )
        assert resp_img.status_code == 201, resp_img.text
        doc_img = resp_img.json()["data"]
        img_id = doc_img["id"]
        assert doc_img["category"] == "FIRE_SAFETY"
        assert doc_img["content_type"] == "image/png"
        assert doc_img["is_expiring_soon"] is True

        # 3. Test Replace / Update File for an Existing Document (no duplicates)
        new_pdf_bytes = create_sample_pdf("CBSE Recognition Certificate - Updated Endorsement")
        files_replace = {
            "file": ("cbse_recognition_v2.pdf", new_pdf_bytes, "application/pdf")
        }
        resp_replace = await client.put(
            f"/api/v1/documents/{doc_id}/file",
            files=files_replace,
            headers=headers
        )
        assert resp_replace.status_code == 200, resp_replace.text
        replaced_doc = resp_replace.json()["data"]
        assert replaced_doc["id"] == doc_id  # Same document ID
        assert replaced_doc["file_name"] == "cbse_recognition_v2.pdf"
        assert replaced_doc["file_size_bytes"] == len(new_pdf_bytes)

        # Check access log has REPLACE
        stmt_replace_log = select(DocumentAccessLog).where(
            DocumentAccessLog.document_id == uuid.UUID(doc_id),
            DocumentAccessLog.action == DocumentAction.REPLACE
        )
        rep_log = (await db_session.execute(stmt_replace_log)).scalar_one_or_none()
        assert rep_log is not None

        # Verify no duplicate document records created
        stmt_count = select(SchoolDocument).where(
            SchoolDocument.id == uuid.UUID(doc_id)
        )
        docs_found = list((await db_session.execute(stmt_count)).scalars().all())
        assert len(docs_found) == 1

        # 4. Test View (Inline) and Download (Attachment)
        # Download (attachment)
        resp_dl = await client.get(f"/api/v1/documents/{doc_id}/download", headers=headers)
        assert resp_dl.status_code == 200
        assert "attachment" in resp_dl.headers["content-disposition"]
        assert resp_dl.content == new_pdf_bytes

        # View (inline)
        resp_view = await client.get(f"/api/v1/documents/{doc_id}/view", headers=headers)
        assert resp_view.status_code == 200
        assert "inline" in resp_view.headers["content-disposition"]
        assert resp_view.content == new_pdf_bytes

        # Image view (inline)
        resp_img_view = await client.get(f"/api/v1/documents/{img_id}/view", headers=headers)
        assert resp_img_view.status_code == 200
        assert "inline" in resp_img_view.headers["content-disposition"]
        assert resp_img_view.headers["content-type"] == "image/png"

        # 5. Test Password Protected Document Upload & Unlock Flow
        prot_pdf_bytes = create_sample_pdf("Executive Payroll & Financial Ledger 2026")
        files_prot = {
            "file": ("financial_audit_confidential.pdf", prot_pdf_bytes, "application/pdf")
        }
        form_data_prot = {
            "category": "FINANCIAL",
            "title": "Executive Payroll & Financial Ledger",
            "document_number": "FIN/2026/CONF",
            "confidentiality_level": "HIGHLY_CONFIDENTIAL",
            "is_password_protected": "true",
            "passcode": "AuditPass@2026",
            "remarks": "Restricted statutory document"
        }
        resp_prot = await client.post(
            f"/api/v1/schools/{school_id}/documents/upload",
            data=form_data_prot,
            files=files_prot,
            headers=headers
        )
        assert resp_prot.status_code == 201, resp_prot.text
        prot_doc_id = resp_prot.json()["data"]["id"]

        # Attempt download without token -> 403
        resp_blocked = await client.get(f"/api/v1/documents/{prot_doc_id}/download", headers=headers)
        assert resp_blocked.status_code == 403

        # Unlock with passcode
        resp_unlock = await client.post(
            f"/api/v1/documents/{prot_doc_id}/unlock",
            json={"passcode": "AuditPass@2026"},
            headers=headers
        )
        assert resp_unlock.status_code == 200
        unlock_token = resp_unlock.json()["data"]["unlock_token"]

        # Download with valid token -> 200
        resp_auth_dl = await client.get(
            f"/api/v1/documents/{prot_doc_id}/download?unlock_token={unlock_token}",
            headers=headers
        )
        assert resp_auth_dl.status_code == 200
        assert resp_auth_dl.content == prot_pdf_bytes

        # 6. Test File Size Validation (> 15 MB)
        oversized_bytes = b"%PDF-1.4\n" + b"X" * (16 * 1024 * 1024)
        files_oversized = {
            "file": ("huge_scan.pdf", oversized_bytes, "application/pdf")
        }
        resp_over = await client.post(
            f"/api/v1/schools/{school_id}/documents/upload",
            data=form_data,
            files=files_oversized,
            headers=headers
        )
        assert resp_over.status_code == 400
        assert "exceeds maximum allowed size" in resp_over.text

        # 7. Test Invalid File Format (.exe)
        files_invalid = {
            "file": ("malicious.exe", b"MZ\x90\x00\x03\x00\x00\x00", "application/x-msdownload")
        }
        resp_inv = await client.post(
            f"/api/v1/schools/{school_id}/documents/upload",
            data=form_data,
            files=files_invalid,
            headers=headers
        )
        assert resp_inv.status_code == 400
        assert "Unsupported file format" in resp_inv.text

        # 8. Test All Document Categories Upload Support
        all_categories = [
            "GOVERNMENT", "RECOGNITION", "AFFILIATION", "CERTIFICATE",
            "FIRE_SAFETY", "BUILDING", "STAFF", "FINANCIAL", "OTHER"
        ]
        for cat in all_categories:
            cat_files = {
                "file": (f"{cat.lower()}_test.pdf", create_sample_pdf(f"{cat} Certificate"), "application/pdf")
            }
            cat_form = {
                "category": cat,
                "title": f"Official {cat.replace('_', ' ').title()} Record",
                "is_password_protected": "false"
            }
            r_cat = await client.post(
                f"/api/v1/schools/{school_id}/documents/upload",
                data=cat_form,
                files=cat_files,
                headers=headers
            )
            assert r_cat.status_code == 201, f"Failed for category {cat}: {r_cat.text}"
            assert r_cat.json()["data"]["category"] == cat

    finally:
        app.dependency_overrides.pop(get_current_user, None)