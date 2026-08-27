import asyncio
import httpx

async def verify_endpoint(client, url, name, headers):
    try:
        resp = await client.get(url, headers=headers)
        print(f"[+] {name}: Status {resp.status_code} | Success: {resp.status_code == 200}")
        if resp.status_code != 200:
            print(f"    Detail: {resp.text[:200]}")
    except Exception as e:
        print(f"[-] {name}: Exception ({e})")

async def main():
    api_url = "https://edupulse-api-295242569787.asia-south1.run.app/api/v1"
    tenant_id = "09f2d4e7-2877-4e42-9e95-e97d52775687"
    teacher_email = "teacher.t101@edupulse.local"
    uat_password = "LocalUat@123"
    
    print("\n=== UAT TEACHER API VERIFICATION ===")
    
    headers = {
        "X-Tenant-ID": tenant_id
    }
    
    async with httpx.AsyncClient() as client:
        # 1. Login
        login_data = {
            "email": teacher_email,
            "password": uat_password
        }
        response = await client.post(f"{api_url}/auth/login", json=login_data, headers=headers)
        if response.status_code != 200:
            print(f"[-] Authentication Failed: Status {response.status_code} | {response.text}")
            return
            
        token_data = response.json()
        access_token = token_data.get("data", {}).get("access_token")
        if not access_token:
            access_token = token_data.get("access_token")
            
        if not access_token:
            print("[-] Access Token missing from login response.")
            return
            
        print("[+] Authentication: SUCCESSFUL")
        print("[+] Access Token: [REDACTED]")
        
        # 2. Build authenticated headers
        headers["Authorization"] = f"Bearer {access_token}"
        
        # 3. /auth/me
        await verify_endpoint(client, f"{api_url}/auth/me", "/auth/me", headers)
        
        # 4. /classes
        await verify_endpoint(client, f"{api_url}/classes", "/classes", headers)
        
        # 5. /sections
        await verify_endpoint(client, f"{api_url}/sections", "/sections", headers)
        
        # 6. /students
        await verify_endpoint(client, f"{api_url}/students", "/students", headers)
        
        # 7. /subjects
        await verify_endpoint(client, f"{api_url}/subjects", "/subjects", headers)
        
        # 8. /timetables
        await verify_endpoint(client, f"{api_url}/timetables", "/timetables", headers)
        
        # 9. /attendances (using school parameter if needed)
        school_id = "55b95edf-c227-45fa-a225-c2d3366eba25"
        await verify_endpoint(client, f"{api_url}/attendances?school_id={school_id}", "/attendances", headers)
        
        # 10. /homeworks
        await verify_endpoint(client, f"{api_url}/homeworks?school_id={school_id}", "/homeworks", headers)
        
        # 11. /examinations
        await verify_endpoint(client, f"{api_url}/examinations?school_id={school_id}", "/examinations", headers)
        
        # 12. /teacher-leaves
        await verify_endpoint(client, f"{api_url}/teacher-leaves", "/teacher-leaves", headers)
        
        # 13. /notifications
        await verify_endpoint(client, f"{api_url}/notifications", "/notifications", headers)
        
        # 14. /teacher-ai
        await verify_endpoint(client, f"{api_url}/teacher-ai", "/teacher-ai", headers)
        
    print("===================================\n")

if __name__ == "__main__":
    asyncio.run(main())
