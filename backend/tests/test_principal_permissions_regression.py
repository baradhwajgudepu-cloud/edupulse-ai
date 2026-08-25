import uuid
from app.seed_uat_principal_permissions import INTENDED_PERMISSIONS

def test_intended_principal_permissions_count():
    """
    Verifies that the list of intended PRINCIPAL permission codes is unique
    and exactly equals 42 (compiled from all migrations).
    """
    unique_permissions = set(INTENDED_PERMISSIONS)
    
    # Assert there are no duplicates in the list
    assert len(INTENDED_PERMISSIONS) == len(unique_permissions), "Duplicate permission codes found in seed script!"
    
    # Assert the exact authoritative count of 42
    assert len(unique_permissions) == 42, f"Expected 42 permissions, got {len(unique_permissions)}"

    # Assert that the new read permissions exist
    assert "class.read" in unique_permissions
    assert "section.read" in unique_permissions
    assert "academic_year.read" in unique_permissions
    assert "academic_year.create" in unique_permissions

def test_target_tenant_is_fixed_correctly():
    """
    Verifies that the target tenant is strictly locked to the UAT tenant.
    """
    # Read the script and verify the tenant UUID
    with open("app/seed_uat_principal_permissions.py", "r", encoding="utf-8") as f:
        content = f.read()
    
    expected_tenant = "09f2d4e7-2877-4e42-9e95-e97d52775687"
    assert expected_tenant in content, f"Target tenant ID '{expected_tenant}' not found in the script!"

def test_script_has_no_password_reset_logic():
    """
    Verifies that the seeding script does not contain any user password modification or reset logic.
    """
    with open("app/seed_uat_principal_permissions.py", "r", encoding="utf-8") as f:
        content = f.read()
    
    # Disallowed patterns that would mutate user passwords
    disallowed = [
        "user.hashed_password =",
        "user.hashed_password=",
        "hashed_password =",
        "hashed_password=",
        "change_password",
        "update_password"
    ]
    
    for term in disallowed:
        assert term not in content, f"Disallowed password reset logic pattern '{term}' found in seeding script!"
