import io
import uuid
import pytest
from httpx import AsyncClient
from PIL import Image

def _create_test_image(format="PNG", size=(200, 200), color="blue") -> bytes:
    buf = io.BytesIO()
    img = Image.new("RGBA" if format == "PNG" else "RGB", size, color=color)
    img.save(buf, format=format)
    return buf.getvalue()

async def _create_tenant(client: AsyncClient, name: str, code: str) -> str:
    subdomain = code.replace("-", "").replace("_", "").lower()[:20]
    t_resp = await client.post("/api/v1/tenants", json={
        "name": name,
        "code": code,
        "subdomain": subdomain,
        "email": f"{subdomain}@edu.in"
    })
    assert t_resp.status_code == 201, f"Tenant creation failed: {t_resp.text}"
    return t_resp.json()["data"]["id"]

@pytest.mark.anyio
async def test_upload_school_logo_success(client: AsyncClient) -> None:
    # 1. Create a tenant and school
    tenant_id = await _create_tenant(client, "Logo Test Trust", "logo-trust")
    headers = {"X-Tenant-ID": tenant_id}

    s_resp = await client.post("/api/v1/schools", json={
        "name": "Logo Test Academy",
        "code": "LOGO_ACAD",
        "board": "CBSE",
        "school_type": "HIGH_SCHOOL",
        "email": "logo_acad@edu.in"
    }, headers=headers)
    assert s_resp.status_code == 201
    school_id = s_resp.json()["data"]["id"]

    # 2. Upload valid PNG logo
    png_bytes = _create_test_image("PNG", (400, 400), "navy")
    files = {"file": ("test_logo.png", png_bytes, "image/png")}
    
    upload_resp = await client.post(f"/api/v1/schools/{school_id}/logo", files=files, headers=headers)
    assert upload_resp.status_code == 200
    body = upload_resp.json()
    assert body["success"] is True
    assert "School logo uploaded successfully" in body["message"]
    data = body["data"]
    assert data["id"] == school_id
    assert data["school_id"] == school_id
    assert data["logo_url"] == f"/api/v1/schools/{school_id}/logo"
    assert data["logo_storage_key"] is not None
    assert f"schools/{school_id}/branding/" in data["logo_storage_key"]
    assert data["logo_updated_at"] is not None

@pytest.mark.anyio
async def test_invalid_logo_file_rejected(client: AsyncClient) -> None:
    tenant_id = await _create_tenant(client, "Invalid File Trust", "inv-trust")
    headers = {"X-Tenant-ID": tenant_id}

    s_resp = await client.post("/api/v1/schools", json={
        "name": "Invalid File Academy",
        "code": "INV_ACAD",
        "board": "CBSE",
        "school_type": "HIGH_SCHOOL",
        "email": "inv_acad@edu.in"
    }, headers=headers)
    school_id = s_resp.json()["data"]["id"]

    # 1. Reject invalid extension
    txt_bytes = b"This is not an image"
    files = {"file": ("malicious.exe", txt_bytes, "application/octet-stream")}
    resp1 = await client.post(f"/api/v1/schools/{school_id}/logo", files=files, headers=headers)
    assert resp1.status_code == 400
    msg1 = resp1.json().get("message", "") or resp1.json().get("detail", "")
    assert "Please upload a PNG, JPG, JPEG or WEBP image" in msg1

    # 2. Reject fake image with valid extension (integrity failure)
    fake_png = b"Not a real PNG content"
    files_fake = {"file": ("fake.png", fake_png, "image/png")}
    resp2 = await client.post(f"/api/v1/schools/{school_id}/logo", files=files_fake, headers=headers)
    assert resp2.status_code == 400
    msg2 = resp2.json().get("message", "") or resp2.json().get("detail", "")
    assert "Invalid image file or corrupted image data" in msg2

@pytest.mark.anyio
async def test_logo_file_size_rejected(client: AsyncClient) -> None:
    tenant_id = await _create_tenant(client, "Size Limit Trust", "size-trust")
    headers = {"X-Tenant-ID": tenant_id}

    s_resp = await client.post("/api/v1/schools", json={
        "name": "Size Limit Academy",
        "code": "SIZE_ACAD",
        "board": "CBSE",
        "school_type": "HIGH_SCHOOL",
        "email": "size_acad@edu.in"
    }, headers=headers)
    school_id = s_resp.json()["data"]["id"]

    # Oversized payload (> 5MB)
    large_bytes = b"x" * (5 * 1024 * 1024 + 100)
    files = {"file": ("huge.png", large_bytes, "image/png")}
    resp = await client.post(f"/api/v1/schools/{school_id}/logo", files=files, headers=headers)
    assert resp.status_code == 400
    msg_size = resp.json().get("message", "") or resp.json().get("detail", "")
    assert "Logo image must be smaller than 5 MB" in msg_size

@pytest.mark.anyio
async def test_cross_tenant_logo_upload_rejected(client: AsyncClient) -> None:
    # Tenant 1 & School 1
    t1_id = await _create_tenant(client, "Tenant One", "tenant-one")
    s1_resp = await client.post("/api/v1/schools", json={
        "name": "School One", "code": "SCH_ONE", "board": "CBSE", "school_type": "HIGH_SCHOOL", "email": "s1@edu.in"
    }, headers={"X-Tenant-ID": t1_id})
    s1_id = s1_resp.json()["data"]["id"]

    # Tenant 2
    t2_id = await _create_tenant(client, "Tenant Two", "tenant-two")

    # Attempt upload using Tenant 2 credentials to School 1
    png_bytes = _create_test_image("PNG")
    files = {"file": ("logo.png", png_bytes, "image/png")}
    cross_resp = await client.post(
        f"/api/v1/schools/{s1_id}/logo",
        files=files,
        headers={"X-Tenant-ID": t2_id}
    )
    assert cross_resp.status_code in (403, 404)

@pytest.mark.anyio
async def test_replace_school_logo(client: AsyncClient) -> None:
    tenant_id = await _create_tenant(client, "Replace Trust", "replace-trust")
    headers = {"X-Tenant-ID": tenant_id}

    s_resp = await client.post("/api/v1/schools", json={
        "name": "Replace Academy", "code": "REP_ACAD", "board": "CBSE", "school_type": "HIGH_SCHOOL", "email": "rep@edu.in"
    }, headers=headers)
    school_id = s_resp.json()["data"]["id"]

    # 1. Upload initial logo
    img1 = _create_test_image("PNG", (300, 300), "red")
    resp1 = await client.post(f"/api/v1/schools/{school_id}/logo", files={"file": ("logo1.png", img1, "image/png")}, headers=headers)
    assert resp1.status_code == 200
    key1 = resp1.json()["data"]["logo_storage_key"]

    # 2. Replace with new logo
    img2 = _create_test_image("PNG", (400, 400), "green")
    resp2 = await client.post(f"/api/v1/schools/{school_id}/logo", files={"file": ("logo2.png", img2, "image/png")}, headers=headers)
    assert resp2.status_code == 200
    key2 = resp2.json()["data"]["logo_storage_key"]

    assert key1 != key2
    assert key2 is not None

@pytest.mark.anyio
async def test_delete_school_logo(client: AsyncClient) -> None:
    tenant_id = await _create_tenant(client, "Delete Trust", "del-trust")
    headers = {"X-Tenant-ID": tenant_id}

    s_resp = await client.post("/api/v1/schools", json={
        "name": "Delete Academy", "code": "DEL_ACAD", "board": "CBSE", "school_type": "HIGH_SCHOOL", "email": "del@edu.in"
    }, headers=headers)
    school_id = s_resp.json()["data"]["id"]

    # Upload logo
    img = _create_test_image("PNG")
    await client.post(f"/api/v1/schools/{school_id}/logo", files={"file": ("logo.png", img, "image/png")}, headers=headers)

    # Delete logo
    del_resp = await client.delete(f"/api/v1/schools/{school_id}/logo", headers=headers)
    assert del_resp.status_code == 200
    body = del_resp.json()
    assert body["data"]["logo_url"] is None
    assert body["data"]["logo_storage_key"] is None

@pytest.mark.anyio
async def test_school_response_contains_logo_url(client: AsyncClient) -> None:
    tenant_id = await _create_tenant(client, "Response Trust", "resp-trust")
    headers = {"X-Tenant-ID": tenant_id}

    s_resp = await client.post("/api/v1/schools", json={
        "name": "Response Academy", "code": "RESP_ACAD", "board": "CBSE", "school_type": "HIGH_SCHOOL", "email": "resp_acad@edu.in"
    }, headers=headers)
    school_id = s_resp.json()["data"]["id"]

    # Upload logo
    img = _create_test_image("PNG")
    await client.post(f"/api/v1/schools/{school_id}/logo", files={"file": ("logo.png", img, "image/png")}, headers=headers)

    # Fetch school details via GET /api/v1/schools/{id}
    get_resp = await client.get(f"/api/v1/schools/{school_id}", headers=headers)
    assert get_resp.status_code == 200
    school_data = get_resp.json()["data"]
    assert school_data["logo_url"] == f"/api/v1/schools/{school_id}/logo"
    assert school_data["school_id"] == school_id
    assert school_data["logo_updated_at"] is not None

@pytest.mark.anyio
async def test_get_school_logo_streaming(client: AsyncClient) -> None:
    tenant_id = await _create_tenant(client, "Stream Trust", "stream-trust")
    headers = {"X-Tenant-ID": tenant_id}

    s_resp = await client.post("/api/v1/schools", json={
        "name": "Stream Academy", "code": "STREAM_ACAD", "board": "CBSE", "school_type": "HIGH_SCHOOL", "email": "stream_acad@edu.in"
    }, headers=headers)
    school_id = s_resp.json()["data"]["id"]

    # 1. 404 when no logo uploaded
    resp_empty = await client.get(f"/api/v1/schools/{school_id}/logo", headers=headers)
    assert resp_empty.status_code == 404

    # 2. Upload PNG logo
    original_bytes = _create_test_image("PNG", (150, 150), "purple")
    await client.post(f"/api/v1/schools/{school_id}/logo", files={"file": ("purple.png", original_bytes, "image/png")}, headers=headers)

    # 3. Stream logo back via GET /api/v1/schools/{id}/logo
    stream_resp = await client.get(f"/api/v1/schools/{school_id}/logo", headers=headers)
    assert stream_resp.status_code == 200
    assert stream_resp.headers["content-type"] == "image/png"
    assert "private, max-age=86400" in stream_resp.headers["cache-control"]
    assert len(stream_resp.content) > 0
