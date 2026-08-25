import pytest
import uuid
from sqlalchemy import select, delete, func
from sqlalchemy.orm import selectinload
from app.repositories.tenant import TenantRepository
from app.schemas.tenant import TenantCreate
from app.models.role import Role, role_permissions
from app.models.permission import Permission
from app.services.identity_provisioning import IdentityProvisioningService
from app.services.rbac_provisioning import (
    ensure_tenant_rbac,
    ROLE_PERMISSIONS_MAP,
    ROLE_NAMES_MAP
)

async def get_role_permission_codes(session, role_id: uuid.UUID) -> set:
    """
    Helper to explicitly query the mapped permission codes for a role,
    bypassing ORM lazy loading/caching.
    """
    stmt = select(Permission.code).join(
        role_permissions,
        Permission.id == role_permissions.c.permission_id
    ).where(role_permissions.c.role_id == role_id)
    res = await session.execute(stmt)
    return set(res.scalars().all())

@pytest.mark.anyio
async def test_fresh_tenant_expected_roles_and_permissions(db_session) -> None:
    """
    1. Fresh tenant: expected system roles created and correct permissions mapped.
    """
    repo_t = TenantRepository(db_session)
    tenant = await repo_t.create(
        TenantCreate(
            name="Fresh Tenant",
            code="fresh-t",
            subdomain="fresht",
            email="fresht@test.com"
        )
    )

    # Query all roles for the tenant
    stmt_roles = select(Role).where(
        Role.tenant_id == tenant.id,
        Role.deleted_at.is_(None)
    )
    res_roles = await db_session.execute(stmt_roles)
    roles = {r.code: r for r in res_roles.scalars().all()}

    # Check system roles
    for code in ROLE_NAMES_MAP.keys():
        assert code in roles
        assert roles[code].is_system is True

    # PRINCIPAL count and exact list verification
    principal_role = roles["PRINCIPAL"]
    principal_perms = await get_role_permission_codes(db_session, principal_role.id)
    expected_principal = set(ROLE_PERMISSIONS_MAP["PRINCIPAL"])
    assert len(principal_perms) == 38
    assert principal_perms == expected_principal


@pytest.mark.anyio
async def test_identity_provisioning_check_scenarios(db_session, monkeypatch) -> None:
    """
    Covers repair checking logic in IdentityProvisioningService._get_role:
    1. 38/38 expected permissions -> no repair.
    2. 37/38 expected permissions -> repair missing permission.
    3. 37 expected + 1 custom permission -> repair missing expected permission.
    4. 38 expected + custom permission -> no repair and preserve custom permission.
    5. Zero permissions -> repair all expected permissions.
    """
    repo_t = TenantRepository(db_session)
    tenant = await repo_t.create(
        TenantCreate(
            name="Repair Check Tenant",
            code="repair-t",
            subdomain="repairt",
            email="repairt@test.com"
        )
    )

    # Resolve PRINCIPAL role
    stmt = select(Role).where(Role.tenant_id == tenant.id, Role.code == "PRINCIPAL")
    res = await db_session.execute(stmt)
    role = res.scalar_one()
    role_id = role.id

    # Track calls to ensure_tenant_rbac
    ensure_calls = []
    async def mock_ensure_tenant_rbac(session, t_id):
        ensure_calls.append(t_id)
        await ensure_tenant_rbac(session, t_id)

    monkeypatch.setattr("app.services.rbac_provisioning.ensure_tenant_rbac", mock_ensure_tenant_rbac)
    service = IdentityProvisioningService(db_session)

    # Scenario 1: 38/38 expected permissions -> no repair.
    ensure_calls.clear()
    role_retrieved = await service._get_role(tenant.id, "PRINCIPAL", "Principal")
    assert len(ensure_calls) == 0
    role_perms = await get_role_permission_codes(db_session, role_id)
    assert len(role_perms) == 38

    # Scenario 2: 37/38 expected permissions -> repair missing permission.
    # Manually delete 1 expected permission (fee.report)
    stmt_perm = select(Permission).where(Permission.code == "fee.report")
    res_perm = await db_session.execute(stmt_perm)
    perm_fee = res_perm.scalar_one()
    perm_fee_id = perm_fee.id

    await db_session.execute(
        delete(role_permissions).where(
            role_permissions.c.role_id == role_id,
            role_permissions.c.permission_id == perm_fee_id
        )
    )
    db_session.expire(role)
    await db_session.commit()

    ensure_calls.clear()
    await service._get_role(tenant.id, "PRINCIPAL", "Principal")
    assert len(ensure_calls) == 1
    
    # Verify permission was restored
    role_perms = await get_role_permission_codes(db_session, role_id)
    assert len(role_perms) == 38
    assert "fee.report" in role_perms

    # Scenario 3: 37 expected + 1 custom permission -> repair missing expected permission.
    # Remove fee.report again
    await db_session.execute(
        delete(role_permissions).where(
            role_permissions.c.role_id == role_id,
            role_permissions.c.permission_id == perm_fee_id
        )
    )
    # Add a custom permission 'tenant.write' to PRINCIPAL role (which is not in its defaults)
    stmt_custom = select(Permission).where(Permission.code == "tenant.write")
    res_custom = await db_session.execute(stmt_custom)
    perm_custom = res_custom.scalar_one()
    perm_custom_id = perm_custom.id
    
    # Insert custom permission directly into association
    await db_session.execute(
        role_permissions.insert().values(role_id=role_id, permission_id=perm_custom_id)
    )
    db_session.expire(role)
    await db_session.commit()

    # Verify count is 38 (37 expected + 1 custom) in the DB
    stmt_count = select(func.count()).select_from(role_permissions).where(role_permissions.c.role_id == role_id)
    res_count = await db_session.execute(stmt_count)
    assert res_count.scalar() == 38

    ensure_calls.clear()
    await service._get_role(tenant.id, "PRINCIPAL", "Principal")
    # Should trigger repair because fee.report is missing, even though count was 38
    assert len(ensure_calls) == 1
    
    # Verify restored to 39 (38 expected + 1 custom)
    role_perms = await get_role_permission_codes(db_session, role_id)
    assert len(role_perms) == 39
    assert "fee.report" in role_perms
    assert "tenant.write" in role_perms

    # Scenario 4: 38 expected + custom permission -> no repair and preserve custom permission.
    ensure_calls.clear()
    await service._get_role(tenant.id, "PRINCIPAL", "Principal")
    assert len(ensure_calls) == 0
    
    role_perms = await get_role_permission_codes(db_session, role_id)
    assert len(role_perms) == 39

    # Scenario 5: Zero permissions -> repair all expected permissions.
    await db_session.execute(
        delete(role_permissions).where(role_permissions.c.role_id == role_id)
    )
    db_session.expire(role)
    await db_session.commit()

    ensure_calls.clear()
    await service._get_role(tenant.id, "PRINCIPAL", "Principal")
    assert len(ensure_calls) == 1
    
    role_perms = await get_role_permission_codes(db_session, role_id)
    assert len(role_perms) == 38


@pytest.mark.anyio
async def test_tenant_rbac_idempotency_no_deletion_isolation(db_session) -> None:
    """
    6. Repeated repair -> idempotent.
    7. No existing permission mappings are deleted.
    8. Tenant isolation remains intact.
    """
    repo_t = TenantRepository(db_session)
    tenant_a = await repo_t.create(
        TenantCreate(name="Tenant A", code="tenant-a", subdomain="tenanta", email="tenanta@test.com")
    )
    tenant_b = await repo_t.create(
        TenantCreate(name="Tenant B", code="tenant-b", subdomain="tenantb", email="tenantb@test.com")
    )

    stmt_a = select(Role).where(Role.tenant_id == tenant_a.id, Role.code == "PRINCIPAL")
    stmt_b = select(Role).where(Role.tenant_id == tenant_b.id, Role.code == "PRINCIPAL")

    res_a = await db_session.execute(stmt_a)
    role_a = res_a.scalar_one()
    role_a_id = role_a.id

    res_b = await db_session.execute(stmt_b)
    role_b = res_b.scalar_one()
    role_b_id = role_b.id

    # 7. Add custom permission to Tenant A and verify it's never deleted
    stmt_perm = select(Permission).where(Permission.code == "tenant.write")
    res_perm = await db_session.execute(stmt_perm)
    perm = res_perm.scalar_one()
    perm_id = perm.id

    await db_session.execute(
        role_permissions.insert().values(role_id=role_a_id, permission_id=perm_id)
    )
    db_session.expire(role_a)
    await db_session.commit()

    # Clear Tenant B mappings entirely to verify isolation
    await db_session.execute(
        delete(role_permissions).where(role_permissions.c.role_id == role_b_id)
    )
    db_session.expire(role_b)
    await db_session.commit()

    # 6. Run repair twice on Tenant A
    await ensure_tenant_rbac(db_session, tenant_a.id)
    await db_session.commit()
    await ensure_tenant_rbac(db_session, tenant_a.id)
    await db_session.commit()

    # Reload Tenant A permissions
    role_a_perms = await get_role_permission_codes(db_session, role_a_id)
    assert len(role_a_perms) == 39
    assert "tenant.write" in role_a_perms

    # 8. Verify Tenant B remained completely untouched by Tenant A's repair
    stmt_count_b = select(func.count()).select_from(role_permissions).where(role_permissions.c.role_id == role_b_id)
    res_count_b = await db_session.execute(stmt_count_b)
    assert res_count_b.scalar() == 0
