import asyncio
import httpx

async def main():
    api_url = "https://edupulse-api-295242569787.asia-south1.run.app/api/v1"
    tenant_id = "09f2d4e7-2877-4e42-9e95-e97d52775687"
    
    print("=== TESTING UAT PRINCIPAL LOGIN ===")
    
    # 1. Login as Principal
    login_data = {
        "email": "principal.a2707e@edupulse.local",
        "password": "LocalUat@123"
    }
    
    headers = {
        "X-Tenant-ID": tenant_id
    }
    
    async with httpx.AsyncClient() as client:
        # Authentic login route
        response = await client.post(f"{api_url}/auth/login", json=login_data, headers=headers)
        if response.status_code != 200:
            print(f"Login failed: {response.status_code} | {response.text}")
            return
            
        token_data = response.json()
        print("Login Response JSON:", token_data)
        access_token = token_data.get("data", {}).get("access_token")
        if not access_token:
            access_token = token_data.get("access_token")
        print("Access Token Extracted:", access_token is not None)
        
        # 2. Get /auth/me
        headers["Authorization"] = f"Bearer {access_token}"
        me_resp = await client.get(f"{api_url}/auth/me", headers=headers)
        print(f"\n=== GET /auth/me ===")
        print(me_resp.status_code)
        print(me_resp.json())
        
        # 3. Get /academic-years
        school_id = "55b95edf-c227-45fa-a225-c2d3366eba25"
        ay_resp = await client.get(f"{api_url}/schools/{school_id}/academic-years", headers=headers)
        print(f"\n=== GET /schools/{school_id}/academic-years ===")
        print(ay_resp.status_code)
        if ay_resp.status_code == 200:
            ay_list = ay_resp.json().get("data", [])
            print(f"Number of academic years: {len(ay_list)}")
            for ay in ay_list:
                print(f"  AY: ID={ay['id']} | Name={ay['name']} | Code={ay['code']} | Status={ay['status']} | IsCurrent={ay['is_current']}")
                
        # 4. Get /sections
        sections_resp = await client.get(f"{api_url}/sections?school_id={school_id}", headers=headers)
        print(f"\n=== GET /sections?school_id={school_id} ===")
        print(sections_resp.status_code)
        sections_list = []
        if sections_resp.status_code == 200:
            sections_list = sections_resp.json().get("data", [])
            print(f"Number of sections: {len(sections_list)}")
            for s in sections_list[:5]:
                print(f"  Section: ID={s['id']} | Name={s['name']} | ClassID={s['class_id']}")
                
        # 5. Get /teachers
        teachers_resp = await client.get(f"{api_url}/teachers?school_id={school_id}", headers=headers)
        print(f"\n=== GET /teachers?school_id={school_id} ===")
        print(teachers_resp.status_code)
        if teachers_resp.status_code == 200:
            data = teachers_resp.json()
            teachers_list = data.get("data", [])
            print(f"Number of teachers: {len(teachers_list)}")
            for idx, t in enumerate(teachers_list):
                print(f"Teacher {idx+1}: ID={t['id']} | Code={t['employee_code']} | Name={t['first_name']} {t['last_name']} | Email={t.get('official_email')} | UserID={t.get('user_id')}")

if __name__ == "__main__":
    asyncio.run(main())
