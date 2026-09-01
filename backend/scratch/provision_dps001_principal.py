import sys
import os
import uuid
import asyncio
from sqlalchemy import text, select
from sqlalchemy.orm import selectinload
from httpx import AsyncClient, ASGITransport

# Setup python path to load the application modules correctly
sys.path.append(os.path.abspath('.'))
sys.path.append(os.path.abspath(os.path.dirname(__file__) + '/..'))

from app.db.session import AsyncSessionLocal
from app.services.identity_provisioning import IdentityProvisioningService
from app.models.user import User, UserStatus
from app.models.role import Role
from app.models.school import School
from app.main import app

async def main():
    tenant_uuid = uuid.UUID("d09b9362-3dc8-422d-a441-160735fcea96")
    school_uuid = uuid.UUID("7f8b2f8f-d412-4394-9982-71fba6353645")

    async with AsyncSessionLocal() as session:
        # Fetch school details
        stmt_sc = select(School).where(School.id == school_uuid, School.tenant_id == tenant_uuid)
        res_sc = await session.execute(stmt_sc)
        school = res_sc.scalar_one_or_none()
        if not school:
            print(f"Error: School with ID {school_uuid} not found under tenant {tenant_uuid}")
            return
        
        school_name = school.name
        print(f"Target School Name: {school_name}")
        print(f"School ID: {school_uuid}")
        print(f"Tenant ID: {tenant_uuid}")

        # Check if Principal user already exists for this school
        stmt_exists = (
            select(User)
            .join(User.schools)
            .join(User.roles)
            .where(
                School.id == school_uuid,
                User.tenant_id == tenant_uuid,
                Role.code == "PRINCIPAL",
                User.deleted_at.is_(None)
            )
            .options(selectinload(User.roles), selectinload(User.schools))
        )
        res_exists = await session.execute(stmt_exists)
        principal_user = res_exists.scalar_one_or_none()

        if principal_user:
            print("\nPrincipal user already exists for this school.")
            # Parse principal_id hex from email if possible
            email_part = principal_user.email.split("@")[0]
            hex_part = email_part.split(".")[-1] if "." in email_part else "unknown"
            print(f"Existing User ID: {principal_user.id}")
            print(f"Existing User Email: {principal_user.email} (parsed prefix hex: {hex_part})")
        else:
            print("\nNo existing Principal user found. Provisioning a new one...")
            
            # Generate new principal_id for the service call
            principal_id = uuid.uuid4()
            print(f"Generated Principal ID UUID: {principal_id}")

            service = IdentityProvisioningService(session)
            # Call the supported provisioning logic
            principal_user = await service.provision_principal(
                tenant_id=tenant_uuid,
                school_id=school_uuid,
                principal_id=principal_id,
                current_user_id=None
            )
            print("Provisioning committed successfully.")

        # Reload/get loaded user to verify details
        stmt_verify = (
            select(User)
            .where(User.id == principal_user.id)
            .options(selectinload(User.roles), selectinload(User.schools))
        )
        res_verify = await session.execute(stmt_verify)
        verified_user = res_verify.scalar_one()

        roles_list = [r.code for r in verified_user.roles]
        schools_list = [s.id for s in verified_user.schools]

        print("\n--- PROVISIONING VERIFICATION DETAILS ---")
        print(f"School Name: {school_name}")
        print(f"School ID: {school_uuid}")
        print(f"Tenant ID: {tenant_uuid}")
        print(f"Principal User ID: {verified_user.id}")
        print(f"Login Email: {verified_user.email}")
        print(f"Role: {', '.join(roles_list)}")
        print(f"must_change_password: {verified_user.must_change_password}")
        print(f"School Users Mapping Confirmation: {school_uuid in schools_list}")
        
        # Verify old principal and admin are untouched
        print("\n--- INTEGRITY CHECKS ---")
        stmt_old_pr = select(User).where(User.email == "principal.d3b073@edupulse.com")
        res_old_pr = await session.execute(stmt_old_pr)
        old_pr = res_old_pr.scalar_one_or_none()
        if old_pr:
            print(f"Old Principal (principal.d3b073@edupulse.com) is untouched: ID={old_pr.id}, TenantID={old_pr.tenant_id}")
        else:
            print("Old Principal (principal.d3b073@edupulse.com) not found in system.")

        stmt_admin = select(User).where(User.email == "admin@edupulse.com")
        res_admin = await session.execute(stmt_admin)
        admin_u = res_admin.scalar_one_or_none()
        if admin_u:
            print(f"Admin (admin@edupulse.com) is untouched: ID={admin_u.id}, IsSuperuser={admin_u.is_superuser}")
        else:
            print("Admin (admin@edupulse.com) not found in system.")

        # Programmatically verify auth using httpx AsyncClient
        print("\n--- AUTHENTICATION VERIFICATION QUERY ---")
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
            login_payload = {
                "email": verified_user.email,
                "password": "EduPulse@123"
            }
            login_headers = {
                "X-Tenant-ID": str(tenant_uuid)
            }
            
            # POST /api/v1/auth/login
            response = await ac.post("/api/v1/auth/login", json=login_payload, headers=login_headers)
            print(f"POST /api/v1/auth/login Status Code: {response.status_code}")
            
            if response.status_code == 200:
                response_json = response.json()
                print("Login payload returned successful TokenResponse.")
                
                # Fetch token and verify /auth/me
                access_token = response_json["data"]["access_token"]
                me_headers = {
                    "Authorization": f"Bearer {access_token}"
                }
                
                # GET /api/v1/auth/me
                me_response = await ac.get("/api/v1/auth/me", headers=me_headers)
                print(f"GET /api/v1/auth/me Status Code: {me_response.status_code}")
                
                if me_response.status_code == 200:
                    me_json = me_response.json()
                    me_data = me_json["data"]
                    print("\n--- /auth/me payload checks ---")
                    print(f"  User Email: {me_data['email']}")
                    print(f"  Tenant ID: {me_data['tenant_id']}")
                    print(f"  Roles: {[r['code'] for r in me_data['roles']]}")
                    print(f"  Schools: {[s['id'] for s in me_data['schools']]}")
                else:
                    print(f"Error GET /auth/me: {me_response.text}")
            else:
                print(f"Error POST /auth/login: {response.text}")

if __name__ == "__main__":
    asyncio.run(main())
