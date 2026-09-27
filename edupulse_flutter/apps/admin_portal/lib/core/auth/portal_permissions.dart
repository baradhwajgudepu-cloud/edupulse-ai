import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import '../routing/routes.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

/// Centralized role-based access control and capability resolver for the Admin Portal.
class PortalPermissions {
  final bool isSuperAdmin;
  final bool isTenantAdmin;
  final bool isPrincipal;
  final bool isTeacher;
  final Set<String> roles;
  final List<String> schoolIds;
  final String? tenantId;

  const PortalPermissions({
    required this.isSuperAdmin,
    required this.isTenantAdmin,
    required this.isPrincipal,
    required this.isTeacher,
    required this.roles,
    required this.schoolIds,
    this.tenantId,
  });

  factory PortalPermissions.fromUser(UserEntity? user) {
    if (user == null) {
      return const PortalPermissions(
        isSuperAdmin: false,
        isTenantAdmin: false,
        isPrincipal: false,
        isTeacher: false,
        roles: {},
        schoolIds: [],
        tenantId: null,
      );
    }

    final normalizedRoles = user.roles.map((r) => r.trim().toUpperCase()).toSet();
    final isSuper = user.isSuperuser ||
        normalizedRoles.contains('SUPER_ADMIN') ||
        normalizedRoles.contains('SYSTEM_ADMIN');
    final isTenant = !isSuper && (normalizedRoles.contains('TENANT_ADMIN') ||
        normalizedRoles.contains('CHAIRMAN') ||
        normalizedRoles.contains('ADMIN') ||
        normalizedRoles.contains('ADMINISTRATOR'));
    final isPrinc = normalizedRoles.contains('PRINCIPAL') ||
        normalizedRoles.contains('SCHOOL_ADMIN');
    final isTeach = normalizedRoles.contains('TEACHER');

    return PortalPermissions(
      isSuperAdmin: isSuper,
      isTenantAdmin: isTenant,
      isPrincipal: isPrinc,
      isTeacher: isTeach,
      roles: normalizedRoles,
      schoolIds: user.schools,
      tenantId: user.tenantId,
    );
  }

  // --- Administrative Capability Flags ---

  /// Platform Super Admin only
  bool get canManageTenants => isSuperAdmin;

  /// Super Admin & Tenant Admin
  bool get canManageSchools => isSuperAdmin || isTenantAdmin;
  bool get canOnboardSchools => isSuperAdmin || isTenantAdmin;
  bool get canMigrateData => isSuperAdmin || isTenantAdmin;

  /// School Operations (Super Admin, Tenant Admin, Principal)
  bool get canManageUsers => isSuperAdmin || isTenantAdmin || isPrincipal;
  bool get canManageRoles => isSuperAdmin || isTenantAdmin || isPrincipal;
  bool get canAccessSchoolSetup => isSuperAdmin || isTenantAdmin || isPrincipal;
  bool get canAccessSchoolAdministration => isSuperAdmin || isTenantAdmin || isPrincipal;
  bool get canManageTeachers => isSuperAdmin || isTenantAdmin || isPrincipal;
  bool get canManageGuardians => isSuperAdmin || isTenantAdmin || isPrincipal;
  bool get canManagePromotions => isSuperAdmin || isTenantAdmin || isPrincipal;
  bool get canManageFees => isSuperAdmin || isTenantAdmin || isPrincipal;
  bool get canManageSettings => isSuperAdmin || isTenantAdmin || isPrincipal;
  bool get canManageBulkImport => isSuperAdmin || isTenantAdmin || isPrincipal;
  bool get canConfigureExams => isSuperAdmin || isTenantAdmin || isPrincipal;
  bool get canViewConnectAnalytics => isSuperAdmin || isTenantAdmin || isPrincipal;

  // --- Operational Modules (Accessible to Teachers) ---
  bool get canAccessDashboard => true;
  bool get canAccessClasses => true;
  bool get canAccessStudents => true;
  bool get canAccessAttendance => true;
  bool get canUploadAttendance => isSuperAdmin || isTenantAdmin || isPrincipal;
  bool get canViewAttendanceImports => isSuperAdmin || isTenantAdmin || isPrincipal;
  bool get canViewAttendanceAuditLogs => isSuperAdmin || isTenantAdmin || isPrincipal;
  bool get canAccessMarks => true;
  bool get canAccessPlanner => true;
  bool get canAccessReports => !isTeacher;

  /// Validates whether the active role can access a specific route path.
  bool canAccessRoute(String location) {
    // 1. Platform Admin has unrestricted access across all portal routes
    if (isSuperAdmin) return true;

    // 2. Tenants management is strictly platform-only
    if (location.startsWith(AppRoutes.tenants)) {
      return false;
    }

    // 3. Tenant Admin can access all modules within their tenant scope
    if (isTenantAdmin) return true;

    // 4. Multi-School & Onboarding / Migration features are restricted to Platform/Tenant Admins
    if (location.startsWith(AppRoutes.schoolOnboarding) ||
        location.startsWith(AppRoutes.migrations) ||
        location == AppRoutes.schools) {
      return false;
    }

    // 5. Principal / School Admin has full school-level operational access
    if (isPrincipal) {
      return true;
    }

    // 6. Teacher access scoping
    if (isTeacher) {
      // Strictly restricted from administrative and cross-school modules
      if (location.startsWith(AppRoutes.users) ||
          location.startsWith(AppRoutes.rolesPermissions) ||
          location.startsWith(AppRoutes.schoolSetup) ||
          location.startsWith(AppRoutes.schoolAdministration) ||
          location.startsWith(AppRoutes.teachers) ||
          location.startsWith(AppRoutes.guardians) ||
          location.startsWith(AppRoutes.promotions) ||
          location.startsWith(AppRoutes.schools) ||
          location.startsWith(AppRoutes.bulkImport) ||
          location.startsWith(AppRoutes.fees) ||
          location.startsWith(AppRoutes.settings) ||
          location.startsWith(AppRoutes.reports) ||
          location.startsWith(AppRoutes.connectAnalytics) ||
          location.startsWith(AppRoutes.examTypes) ||
          location.startsWith('/attendance/upload') ||
          location.startsWith('/attendance/bulk-upload') ||
          location.startsWith('/attendance/imports') ||
          location.startsWith('/attendance/import-history') ||
          location.startsWith('/attendance/audit')) {
        return false;
      }
      return true;
    }

    // Default safe fallback for other school staff
    return false;
  }
}

/// Provider exposing the current user's computed portal permissions.
final portalPermissionsProvider = Provider<PortalPermissions>((ref) {
  final authState = ref.watch(authStateProvider);
  if (authState is Authenticated) {
    return PortalPermissions.fromUser(authState.user);
  }
  return PortalPermissions.fromUser(null);
});
