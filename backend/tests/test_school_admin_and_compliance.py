import pytest
import uuid
from datetime import date
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.school import School
from app.models.school_administration import (
    SchoolProfile, SchoolRecognition, SchoolCustomField, RecognitionAuthorityLevel,
    RecognitionType, RecognitionStatus, UdiseVerificationStatus
)
from app.main import app
from app.api.dependencies.auth import get_current_user
from tests.test_examinations import setup_exam_test_data


@pytest.mark.anyio
async def test_school_profile_and_compliance_lifecycle(
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
        # 1. GET School Profile
        resp = await client.get(f"/api/v1/schools/{school_id}/profile", headers=headers)
        assert resp.status_code == 200, resp.text
        body = resp.json()
        assert body["success"] is True
        assert body["data"]["school_id"] == str(school_id)
        assert body["data"]["medium_of_instruction"] == "English"

        # 2. PUT Update School Profile
        update_payload = {
            "school_category": "Co-Educational Senior Secondary",
            "management_type": "State Model School Society",
            "school_level": "Secondary & Higher Secondary",
            "established_year": 2012,
            "medium_of_instruction": "English & Telugu",
            "school_motto": "Knowledge, Discipline, Excellence",
            "total_capacity": 1500,
            "has_smart_classrooms": True,
            "has_cctv": True,
            "has_fire_safety": True,
            "custom_values": {"affiliation_zone": "South-Telangana", "inspection_cycle": "Annual"}
        }
        resp_update = await client.put(f"/api/v1/schools/{school_id}/profile", json=update_payload, headers=headers)
        assert resp_update.status_code == 200, resp_update.text
        updated = resp_update.json()["data"]
        assert updated["school_motto"] == "Knowledge, Discipline, Excellence"
        assert updated["total_capacity"] == 1500
        assert updated["has_smart_classrooms"] is True
        assert updated["custom_values"]["affiliation_zone"] == "South-Telangana"

        # 3. POST UDISE+ Verification
        udise_payload = {
            "is_verified": True,
            "notes": "Verified against Telangana State Educational MIS Portal"
        }
        resp_udise = await client.post(f"/api/v1/schools/{school_id}/udise/verify", json=udise_payload, headers=headers)
        assert resp_udise.status_code == 200, resp_udise.text
        udise_data = resp_udise.json()["data"]
        assert udise_data["udise_verification_status"] == "VERIFIED"
        assert udise_data["udise_status"] == "VERIFIED"
        assert udise_data["udise_notes"] == "Verified against Telangana State Educational MIS Portal"

        # 4. POST Create Central Recognition Record
        rec_payload = {
            "authority_level": "CENTRAL",
            "authority_name": "Central Board of Secondary Education (CBSE)",
            "recognition_type": "AFFILIATION",
            "recognition_number": "CBSE/AFF/3630123/2024",
            "certificate_number": "CERT-CBSE-9988",
            "issue_date": "2024-04-01",
            "valid_from": "2024-04-01",
            "valid_until": "2029-03-31",
            "status": "ACTIVE",
            "remarks": "Provisional affiliation granted for 5 years."
        }
        resp_rec = await client.post(f"/api/v1/schools/{school_id}/recognitions", json=rec_payload, headers=headers)
        assert resp_rec.status_code == 201, resp_rec.text
        rec_id = resp_rec.json()["data"]["id"]

        # 5. POST Create State Recognition Record (Telangana DSE)
        state_rec_payload = {
            "authority_level": "STATE",
            "authority_name": "Telangana Directorate of School Education",
            "recognition_type": "RECOGNITION",
            "recognition_number": "DSE-HYD-REC-2023-456",
            "proceedings_order_number": "PROC-TS-DSE-789",
            "issue_date": "2023-06-01",
            "valid_from": "2023-06-01",
            "valid_until": "2028-05-31",
            "status": "ACTIVE",
            "remarks": "State recognition for High School section."
        }
        resp_state_rec = await client.post(f"/api/v1/schools/{school_id}/recognitions", json=state_rec_payload, headers=headers)
        assert resp_state_rec.status_code == 201, resp_state_rec.text

        # 6. GET Recognitions list
        resp_recs = await client.get(f"/api/v1/schools/{school_id}/recognitions", headers=headers)
        assert resp_recs.status_code == 200, resp_recs.text
        recs_list = resp_recs.json()["data"]
        assert len(recs_list) >= 2
        auth_levels = {r["authority_level"] for r in recs_list}
        assert "CENTRAL" in auth_levels
        assert "STATE" in auth_levels

        # 7. GET Compliance Dashboard
        resp_comp = await client.get(f"/api/v1/schools/{school_id}/compliance", headers=headers)
        assert resp_comp.status_code == 200, resp_comp.text
        comp = resp_comp.json()["data"]
        assert comp["udise_verification_status"] == "VERIFIED"
        assert comp["active_recognitions"] >= 2
        assert comp["central_recognitions_count"] >= 1
        assert comp["state_recognitions_count"] >= 1

        # 8. POST Custom Field Schema
        cf_payload = {
            "field_name": "Mid-Day Meal Agency",
            "field_key": "mid_day_meal_agency",
            "field_type": "TEXT",
            "is_required": False,
            "visible_to_principal": True,
            "visible_to_teachers": True,
            "visible_to_parents": False
        }
        resp_cf = await client.post(f"/api/v1/schools/{school_id}/custom-fields", json=cf_payload, headers=headers)
        assert resp_cf.status_code == 201, resp_cf.text

        # 9. Tenant Isolation Guard: Verify request with Tenant B ID cannot access School A profile
        headers_b = {
            "Authorization": headers["Authorization"],
            "X-Tenant-ID": str(data["tenant_b"].id)
        }
        resp_isolation = await client.get(f"/api/v1/schools/{school_id}/profile", headers=headers_b)
        assert resp_isolation.status_code in (400, 403, 404), resp_isolation.text

    finally:
        app.dependency_overrides.pop(get_current_user, None)
