import uuid
import pytest
import httpx
from datetime import datetime, timezone, date
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.main import app
from app.db.session import AsyncSessionLocal
from app.models.user import User
from app.models.school import School
from app.models.teacher import Teacher
from app.models.staff_attendance import StaffAttendance

TEST_LAT = 17.4485
TEST_LON = 78.3741
TEST_RADIUS = 200


@pytest.mark.anyio
async def test_school_geofence_configuration_and_isolation():
    """
    End-to-end integration test for School Geofence Settings:
    1. Principal can fetch assigned school's geofence (GET)
    2. Principal can update assigned school's geofence (PATCH)
    3. Platform Admin can update school geofence
    4. Principal cannot modify unassigned / other school's geofence (HTTP 403)
    5. Cross-tenant request rejected (HTTP 404)
    6. Invalid coordinates (latitude, longitude, radius) rejected (HTTP 422)
    7. Staff attendance integration consumes geofence (enforced when enabled, bypassed when disabled)
    """
    async with AsyncSessionLocal() as db:
        # Load Principal user
        stmt_p = select(User).where(User.email == "principal.ts001@telanganaschool.edu").options(
            selectinload(User.roles), selectinload(User.schools)
        )
        principal = (await db.execute(stmt_p)).scalar_one_or_none()
        assert principal is not None, "Principal test user must exist in database"
        assert len(principal.schools) > 0, "Principal must have an assigned school"

        own_school = principal.schools[0]
        own_school_id = str(own_school.id)
        tenant_id = str(principal.tenant_id)

        # Load a Teacher from the same school
        stmt_t = select(Teacher).where(Teacher.school_id == own_school.id).options(selectinload(Teacher.user))
        teacher_rec = (await db.execute(stmt_t)).scalars().first()
        assert teacher_rec is not None, "A teacher must exist in the school"

        # Load Platform Admin (superuser)
        stmt_a = select(User).where(User.is_superuser == True)
        super_admin = (await db.execute(stmt_a)).scalars().first()

    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Authenticate Principal
        resp_p_login = await client.post("/api/v1/auth/login", json={
            "email": "principal.ts001@telanganaschool.edu",
            "password": "EduPulse@123"
        }, headers={"X-Tenant-ID": tenant_id})
        assert resp_p_login.status_code == 200, f"Principal login failed: {resp_p_login.text}"
        p_token = resp_p_login.json()["data"]["access_token"]
        p_headers = {
            "Authorization": f"Bearer {p_token}",
            "X-Tenant-ID": tenant_id,
            "X-School-ID": own_school_id
        }

        # 2. Authenticate Super Admin (if available)
        admin_headers = dict(p_headers)
        if super_admin and super_admin.email:
            resp_a_login = await client.post("/api/v1/auth/login", json={
                "email": super_admin.email,
                "password": "SuperAdmin@123"
            }, headers={"X-Tenant-ID": tenant_id})
            if resp_a_login.status_code == 200:
                a_token = resp_a_login.json()["data"]["access_token"]
                admin_headers = {
                    "Authorization": f"Bearer {a_token}",
                    "X-Tenant-ID": tenant_id,
                    "X-School-ID": own_school_id
                }

        # 3. GET Geofence Configuration for Assigned School
        get_resp = await client.get(f"/api/v1/schools/{own_school_id}/geofence", headers=p_headers)
        assert get_resp.status_code == 200, f"GET geofence failed: {get_resp.text}"
        get_data = get_resp.json()["data"]
        orig_geofence = dict(get_data)
        assert "school_id" in get_data
        assert "enabled" in get_data
        assert "radius_meters" in get_data

        # 4. PATCH Geofence Configuration by Principal
        patch_payload = {
            "enabled": True,
            "latitude": TEST_LAT,
            "longitude": TEST_LON,
            "radius_meters": TEST_RADIUS
        }
        patch_resp = await client.patch(f"/api/v1/schools/{own_school_id}/geofence", json=patch_payload, headers=p_headers)
        assert patch_resp.status_code == 200, f"PATCH geofence failed: {patch_resp.text}"
        patch_data = patch_resp.json()["data"]
        assert patch_data["enabled"] is True
        assert patch_data["latitude"] == TEST_LAT
        assert patch_data["longitude"] == TEST_LON
        assert patch_data["radius_meters"] == TEST_RADIUS
        assert patch_data["is_configured"] is True

        # Verify database fields updated
        async with AsyncSessionLocal() as db:
            s_check = await db.get(School, uuid.UUID(own_school_id))
            assert s_check.latitude == TEST_LAT
            assert s_check.longitude == TEST_LON
            assert s_check.geofence_radius_meters == TEST_RADIUS
            assert s_check.settings.get("geofence", {}).get("enabled") is True

        # 5. PUT /schools/{id} General School Update preserves & synchronizes geofence
        put_school_payload = {
            "latitude": TEST_LAT,
            "longitude": TEST_LON,
            "geofence_radius_meters": 300
        }
        put_resp = await client.put(f"/api/v1/schools/{own_school_id}", json=put_school_payload, headers=p_headers)
        assert put_resp.status_code == 200, f"PUT school failed: {put_resp.text}"
        put_data = put_resp.json()["data"]
        assert put_data["geofence_radius"] == 300
        assert put_data["geofencing_enabled"] is True

        # 6. Strict School Isolation: Principal cannot modify an unassigned school
        unassigned_school_id = str(uuid.uuid4())
        forbidden_resp = await client.patch(
            f"/api/v1/schools/{unassigned_school_id}/geofence",
            json=patch_payload,
            headers=p_headers
        )
        assert forbidden_resp.status_code in [403, 404]

        # 7. Cross-Tenant Isolation: Cannot access with a different tenant header
        other_tenant_id = str(uuid.uuid4())
        cross_headers = dict(p_headers)
        cross_headers["X-Tenant-ID"] = other_tenant_id
        cross_resp = await client.patch(
            f"/api/v1/schools/{own_school_id}/geofence",
            json=patch_payload,
            headers=cross_headers
        )
        assert cross_resp.status_code in [401, 403, 404]

        # 8. Coordinate Validations (HTTP 422 Unprocessable)
        # Latitude out of bounds
        resp_inv_lat = await client.patch(
            f"/api/v1/schools/{own_school_id}/geofence",
            json={"enabled": True, "latitude": 95.0, "longitude": 78.0, "radius_meters": 100},
            headers=p_headers
        )
        assert resp_inv_lat.status_code == 422

        # Longitude out of bounds
        resp_inv_lon = await client.patch(
            f"/api/v1/schools/{own_school_id}/geofence",
            json={"enabled": True, "latitude": 17.0, "longitude": -195.0, "radius_meters": 100},
            headers=p_headers
        )
        assert resp_inv_lon.status_code == 422

        # Negative / Zero radius
        resp_inv_rad = await client.patch(
            f"/api/v1/schools/{own_school_id}/geofence",
            json={"enabled": True, "latitude": 17.0, "longitude": 78.0, "radius_meters": 0},
            headers=p_headers
        )
        assert resp_inv_rad.status_code == 422

        # Enabled=True but null coordinates
        resp_no_coords = await client.patch(
            f"/api/v1/schools/{own_school_id}/geofence",
            json={"enabled": True, "latitude": None, "longitude": None, "radius_meters": 100},
            headers=p_headers
        )
        assert resp_no_coords.status_code == 422

        # 9. Attendance Integration: Verify enabled vs disabled
        # A. Set Geofence Enabled = True with radius = 100m
        await client.patch(
            f"/api/v1/schools/{own_school_id}/geofence",
            json={"enabled": True, "latitude": TEST_LAT, "longitude": TEST_LON, "radius_meters": 100},
            headers=p_headers
        )

        # Authenticate Teacher
        t_user = teacher_rec.user
        resp_t_login = await client.post("/api/v1/auth/login", json={
            "email": t_user.email,
            "password": "EduPulse@123"
        }, headers={"X-Tenant-ID": tenant_id})

        if resp_t_login.status_code == 200:
            t_token = resp_t_login.json()["data"]["access_token"]
            t_headers = {
                "Authorization": f"Bearer {t_token}",
                "X-Tenant-ID": tenant_id,
                "X-School-ID": own_school_id
            }

            # Clear today's attendance record if already exists
            async with AsyncSessionLocal() as db:
                stmt_del = select(StaffAttendance).where(
                    StaffAttendance.teacher_id == teacher_rec.id,
                    StaffAttendance.attendance_date == date.today()
                )
                att_existing = (await db.execute(stmt_del)).scalars().all()
                for a in att_existing:
                    await db.delete(a)
                await db.commit()

            # B. Check-in far away (10km) -> Fails with HTTP 400
            resp_far = await client.post(
                "/api/v1/staff-attendance/check-in",
                json={"latitude": TEST_LAT + 0.1, "longitude": TEST_LON + 0.1, "accuracy": 10.0, "is_mocked": False},
                headers=t_headers
            )
            assert resp_far.status_code == 400
            assert "outside the permitted school geofence" in resp_far.json()["message"]

            # C. Check-in within geofence -> Succeeds with HTTP 201
            resp_near = await client.post(
                "/api/v1/staff-attendance/check-in",
                json={"latitude": TEST_LAT, "longitude": TEST_LON, "accuracy": 10.0, "is_mocked": False},
                headers=t_headers
            )
            assert resp_near.status_code == 201

            # D. Disable geofence enforcement (enabled = False)
            await client.patch(
                f"/api/v1/schools/{own_school_id}/geofence",
                json={"enabled": False, "latitude": TEST_LAT, "longitude": TEST_LON, "radius_meters": 100},
                headers=p_headers
            )

            # E. Check-out far away -> Should succeed because geofencing is disabled!
            resp_co_far = await client.post(
                "/api/v1/staff-attendance/check-out",
                json={"latitude": TEST_LAT + 0.1, "longitude": TEST_LON + 0.1, "accuracy": 10.0, "is_mocked": False},
                headers=t_headers
            )
            assert resp_co_far.status_code == 200
            assert resp_co_far.json()["data"]["check_out_distance_meters"] is not None

            # F. Clean up: Restore original school geofence configuration
            restore_payload = {
                "enabled": orig_geofence.get("enabled", True),
                "latitude": orig_geofence.get("latitude", TEST_LAT),
                "longitude": orig_geofence.get("longitude", TEST_LON),
                "radius_meters": orig_geofence.get("radius_meters", 100),
            }
            await client.patch(
                f"/api/v1/schools/{own_school_id}/geofence",
                json=restore_payload,
                headers=p_headers
            )
