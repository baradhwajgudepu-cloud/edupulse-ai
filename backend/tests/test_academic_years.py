import pytest
import uuid
from datetime import date
from httpx import AsyncClient
from sqlalchemy.orm.exc import StaleDataError
from app.models.academic_year import AcademicYearStatus

@pytest.mark.anyio
async def test_academic_year_crud_workflow(client: AsyncClient) -> None:
    """
    Tests the CRUD operations of Academic Year scoped by tenant header and school path parameter.
    """
    # 1. Pre-requisites: Create Tenant and School
    t_resp = await client.post("/api/v1/tenants", json={
        "name": "Society X", "code": "soc-x", "subdomain": "socx", "email": "socx@edu.in"
    })
    tenant_id = t_resp.json()["data"]["id"]
    headers = {"X-Tenant-ID": tenant_id}

    s_resp = await client.post("/api/v1/schools", json={
        "name": "Society High School", "code": "SOC_HIGH", "board": "CBSE",
        "school_type": "HIGH_SCHOOL", "email": "high@socx.edu.in"
    }, headers=headers)
    school_id = s_resp.json()["data"]["id"]

    # 2. Create Academic Year
    ay_data = {
        "name": "2026-2027",
        "code": "AY2026",
        "description": "Session 2026-2027",
        "start_date": "2026-06-01",
        "end_date": "2027-04-30",
        "status": "UPCOMING",
        "is_current": True,
        "settings": {"auto_promote": True}
    }
    
    url = f"/api/v1/schools/{school_id}/academic-years"
    resp = await client.post(url, json=ay_data, headers=headers)
    assert resp.status_code == 201
    ay_id = resp.json()["data"]["id"]
    assert resp.json()["data"]["name"] == "2026-2027"
    assert resp.json()["data"]["is_current"] is True
    assert resp.json()["data"]["version"] == 1

    # 3. Retrieve Academic Year
    resp_get = await client.get(f"{url}/{ay_id}", headers=headers)
    assert resp_get.status_code == 200
    assert resp_get.json()["data"]["code"] == "AY2026"

    # 4. List Academic Years
    resp_list = await client.get(url, params={"status": "UPCOMING"}, headers=headers)
    assert resp_list.status_code == 200
    assert len(resp_list.json()["data"]) >= 1

    # 5. Update Academic Year details
    resp_up = await client.put(f"{url}/{ay_id}", json={
        "description": "Updated Session 2026-2027"
    }, headers=headers)
    assert resp_up.status_code == 200
    assert resp_up.json()["data"]["description"] == "Updated Session 2026-2027"
    assert resp_up.json()["data"]["version"] == 2

    # 6. Retrieve current year
    resp_curr = await client.get(f"{url}/current", headers=headers)
    assert resp_curr.status_code == 200
    assert resp_curr.json()["data"]["id"] == ay_id

@pytest.mark.anyio
async def test_academic_year_business_validations(client: AsyncClient) -> None:
    """
    Validates rules:
    - Date chronology: start_date < end_date
    - Unique (school_id, name) and (school_id, code) -> HTTP 409
    - Date overlap prevention within same school -> HTTP 409
    - Bidirectional tenant-school isolation
    """
    # Create Tenant & School
    t_resp = await client.post("/api/v1/tenants", json={
        "name": "Society Y", "code": "soc-y", "subdomain": "socy", "email": "socy@edu.in"
    })
    tenant_id = t_resp.json()["data"]["id"]
    headers = {"X-Tenant-ID": tenant_id}

    s_resp = await client.post("/api/v1/schools", json={
        "name": "Society Campus Y", "code": "CAMPUS_Y", "board": "SSC",
        "school_type": "HIGH_SCHOOL", "email": "campusy@socy.edu.in"
    }, headers=headers)
    school_id = s_resp.json()["data"]["id"]
    url = f"/api/v1/schools/{school_id}/academic-years"

    # 1. Invalid date chronology (start_date >= end_date)
    bad_dates = {
        "name": "2026-2027", "code": "AY2026",
        "start_date": "2026-06-01", "end_date": "2026-05-31"
    }
    r = await client.post(url, json=bad_dates, headers=headers)
    assert r.status_code == 422
    assert "start_date" in r.json()["message"].lower()

    # Create base valid year
    base_year = {
        "name": "2026-2027", "code": "AY2026",
        "start_date": "2026-06-01", "end_date": "2027-04-30"
    }
    r_base = await client.post(url, json=base_year, headers=headers)
    assert r_base.status_code == 201

    # 2. Duplicate Code under same school -> Expects 409 Conflict
    dup_code = {
        "name": "2027-2028", "code": "AY2026",
        "start_date": "2027-06-01", "end_date": "2028-04-30"
    }
    r_dup_code = await client.post(url, json=dup_code, headers=headers)
    assert r_dup_code.status_code == 409
    assert "code" in r_dup_code.json()["message"].lower()

    # 3. Duplicate Name under same school -> Expects 409 Conflict
    dup_name = {
        "name": "2026-2027", "code": "AY2027",
        "start_date": "2027-06-01", "end_date": "2028-04-30"
    }
    r_dup_name = await client.post(url, json=dup_name, headers=headers)
    assert r_dup_name.status_code == 409
    assert "name" in r_dup_name.json()["message"].lower()

    # 4. Overlapping dates (starts inside the active 2026-2027 range) -> Expects 409 Conflict
    overlap = {
        "name": "2027-2028", "code": "AY2027",
        "start_date": "2027-03-01", "end_date": "2028-02-28"  # overlaps base end of 2027-04-30
    }
    r_overlap = await client.post(url, json=overlap, headers=headers)
    assert r_overlap.status_code == 409
    assert "overlap" in r_overlap.json()["message"].lower()

@pytest.mark.anyio
async def test_academic_year_state_machine_and_current_switches(client: AsyncClient) -> None:
    """
    Validates state machine status transition rules and transactional current swaps.
    """
    t_resp = await client.post("/api/v1/tenants", json={
        "name": "Society Z", "code": "soc-z", "subdomain": "socz", "email": "socz@edu.in"
    })
    tenant_id = t_resp.json()["data"]["id"]
    headers = {"X-Tenant-ID": tenant_id}

    s_resp = await client.post("/api/v1/schools", json={
        "name": "Society Campus Z", "code": "CAMPUS_Z", "board": "SSC",
        "school_type": "JR_COLLEGE", "email": "campusz@socz.edu.in"
    }, headers=headers)
    school_id = s_resp.json()["data"]["id"]
    url = f"/api/v1/schools/{school_id}/academic-years"

    # Create Year 1 (marked current, starts upcoming)
    y1_data = {
        "name": "2026-2027", "code": "AY2026",
        "start_date": "2026-06-01", "end_date": "2027-04-30",
        "is_current": True
    }
    y1_resp = await client.post(url, json=y1_data, headers=headers)
    y1_id = y1_resp.json()["data"]["id"]

    # Create Year 2 (starts upcoming, overlaps check avoids clash)
    y2_data = {
        "name": "2027-2028", "code": "AY2027",
        "start_date": "2027-06-01", "end_date": "2028-04-30"
    }
    y2_resp = await client.post(url, json=y2_data, headers=headers)
    y2_id = y2_resp.json()["data"]["id"]

    # 1. Transactional current switch: Mark Year 2 as current
    up_y2 = await client.put(f"{url}/{y2_id}", json={"is_current": True}, headers=headers)
    assert up_y2.status_code == 200
    assert up_y2.json()["data"]["is_current"] is True

    # Check Year 1 was automatically turned off
    get_y1 = await client.get(f"{url}/{y1_id}", headers=headers)
    assert get_y1.json()["data"]["is_current"] is False

    # 2. State Machine Transitions checks:
    # Upcoming -> Completed: Illegal jump -> Expects 409 Conflict
    tr_1 = await client.put(f"{url}/{y1_id}", json={"status": "COMPLETED"}, headers=headers)
    assert tr_1.status_code == 409

    # Upcoming -> Active: Valid -> Expects 200 OK
    tr_2 = await client.put(f"{url}/{y1_id}", json={"status": "ACTIVE"}, headers=headers)
    assert tr_2.status_code == 200

    # Active -> Archived: Illegal jump -> Expects 409 Conflict
    tr_3 = await client.put(f"{url}/{y1_id}", json={"status": "ARCHIVED"}, headers=headers)
    assert tr_3.status_code == 409

    # Active -> Completed: Valid -> Expects 200 OK
    tr_4 = await client.put(f"{url}/{y1_id}", json={"status": "COMPLETED"}, headers=headers)
    assert tr_4.status_code == 200

    # Completed -> Active: Illegal reversal -> Expects 409 Conflict
    tr_5 = await client.put(f"{url}/{y1_id}", json={"status": "ACTIVE"}, headers=headers)
    assert tr_5.status_code == 409

    # Completed -> Archived: Valid -> Expects 200 OK
    tr_6 = await client.put(f"{url}/{y1_id}", json={"status": "ARCHIVED"}, headers=headers)
    assert tr_6.status_code == 200

@pytest.mark.anyio
async def test_academic_year_protections_and_deletes(client: AsyncClient) -> None:
    """
    Verifies that:
    1. Attempting to delete the current academic year is blocked (returns 409).
    2. Attempting to archive the current academic year is blocked (returns 409).
    """
    t_resp = await client.post("/api/v1/tenants", json={
        "name": "Society W", "code": "soc-w", "subdomain": "socw", "email": "socw@edu.in"
    })
    tenant_id = t_resp.json()["data"]["id"]
    headers = {"X-Tenant-ID": tenant_id}

    s_resp = await client.post("/api/v1/schools", json={
        "name": "Society Campus W", "code": "CAMPUS_W", "board": "SSC",
        "school_type": "JR_COLLEGE", "email": "campusw@socw.edu.in"
    }, headers=headers)
    school_id = s_resp.json()["data"]["id"]
    url = f"/api/v1/schools/{school_id}/academic-years"

    # Create current year
    y_data = {
        "name": "2026-2027", "code": "AY2026",
        "start_date": "2026-06-01", "end_date": "2027-04-30",
        "is_current": True
    }
    y_resp = await client.post(url, json=y_data, headers=headers)
    y_id = y_resp.json()["data"]["id"]

    # 1. Try to delete current year -> Expects 409 Conflict
    r_del = await client.delete(f"{url}/{y_id}", headers=headers)
    assert r_del.status_code == 409
    assert "current" in r_del.json()["message"].lower()

    # 2. Try to archive current year -> Expects 409 Conflict
    r_arch = await client.put(f"{url}/{y_id}", json={"status": "ARCHIVED"}, headers=headers)
    assert r_arch.status_code == 409
    assert "current" in r_arch.json()["message"].lower()

@pytest.mark.anyio
async def test_academic_year_optimistic_concurrency_control(db_session) -> None:
    """
    Asserts that concurrent modifications trigger StaleDataError.
    """
    from app.repositories.tenant import TenantRepository
    from app.repositories.school import SchoolRepository
    from app.repositories.academic_year import AcademicYearRepository
    from app.schemas.tenant import TenantCreate
    from app.schemas.school import SchoolCreate
    from app.schemas.academic_year import AcademicYearCreate
    from sqlalchemy.ext.asyncio import async_sessionmaker, AsyncSession

    # Set up Tenant & School
    repo_t = TenantRepository(db_session)
    tenant = await repo_t.create(TenantCreate(name="Society V", code="society-v", subdomain="societyv", email="v@edu.in"))
    
    repo_s = SchoolRepository(db_session)
    school = await repo_s.create(tenant.id, SchoolCreate(name="School V", code="SCH_V", board="CBSE", email="s_v@edu.in"))

    # 1. Create Academic Year in Session A
    repo_a = AcademicYearRepository(db_session)
    ay = await repo_a.create(
        tenant_id=tenant.id,
        school_id=school.id,
        obj_in=AcademicYearCreate(
            name="2026-2027", code="AY2026", start_date="2026-06-01", end_date="2027-04-30"
        )
    )
    assert ay.version == 1

    # 2. Open Session B and load the same academic year
    async_session_b = async_sessionmaker(
        bind=db_session.bind,
        class_=AsyncSession,
        expire_on_commit=False
    )
    async with async_session_b() as session_b:
        repo_b = AcademicYearRepository(session_b)
        ay_b = await repo_b.get_by_id(ay.id, school.id, tenant.id)
        assert ay_b.version == 1

        # 3. Modify and commit in Session A (version increases to 2)
        ay.description = "Session A Edit"
        await repo_a.db.commit()
        await repo_a.db.refresh(ay)
        assert ay.version == 2

        # 4. Modify and commit in Session B (raises StaleDataError due to stale version 1)
        ay_b.description = "Session B Edit"
        with pytest.raises(StaleDataError):
            await repo_b.db.commit()
            
        await repo_b.db.close()
