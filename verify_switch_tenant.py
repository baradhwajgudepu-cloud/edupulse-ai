import json
import urllib.request

# 1. Login as super admin to get access token
login_url = "http://127.0.0.1:8000/api/v1/auth/platform-login"
payload = json.dumps({
    "email": "edupulsetechnologies@gmail.com",
    "password": "Gudepu@84"
}).encode("utf-8")

req = urllib.request.Request(login_url, data=payload, headers={"Content-Type": "application/json"})
with urllib.request.urlopen(req) as resp:
    data = json.loads(resp.read().decode("utf-8"))
    access_token = data["data"]["access_token"]
    print("Logged in as Super Admin.")

# 2. Make request to /schools with X-Tenant-ID: Telangana (f004a214-ab3e-443d-a683-588c664a0987)
schools_url = "http://127.0.0.1:8000/api/v1/schools"
telangana_tenant_id = "f004a214-ab3e-443d-a683-588c664a0987"

req2 = urllib.request.Request(
    schools_url,
    headers={
        "Authorization": f"Bearer {access_token}",
        "X-Tenant-ID": telangana_tenant_id
    }
)

try:
    with urllib.request.urlopen(req2) as resp2:
        print("GET /schools with Telangana tenant -> Status:", resp2.status)
        schools_data = json.loads(resp2.read().decode("utf-8"))
        print("Schools returned:", len(schools_data.get("data", [])))
except urllib.error.HTTPError as e:
    print("GET /schools with Telangana tenant -> HTTPError:", e.code)
    print("Body:", e.read().decode("utf-8"))
