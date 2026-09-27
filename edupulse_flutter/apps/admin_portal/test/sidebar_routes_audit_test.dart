import 'package:flutter_test/flutter_test.dart';
import 'package:admin_portal/core/routing/routes.dart';
import 'package:admin_portal/core/routing/app_router.dart';
import 'package:admin_portal/features/auth/presentation/providers/auth_provider.dart';
import 'package:edupulse_auth/edupulse_auth.dart';

void main() {
  group('16 Sidebar Routes Audit & Validation Tests', () {
    final expectedSidebarRoutes = <String, String>{
      'Dashboard': AppRoutes.dashboard, // /dashboard
      'Students': AppRoutes.students, // /students
      'Parents & Guardians': AppRoutes.guardians, // /guardians
      'Teachers & Staff': AppRoutes.teachers, // /teachers
      'Classes & Sections': AppRoutes.classes, // /classes
      'Classrooms & Rooms': AppRoutes.rooms, // /rooms
      'Attendance': AppRoutes.attendance, // /attendance
      'Exams & Assessments': AppRoutes.results, // /results
      'Fees & Collection': AppRoutes.fees, // /fees
      'Expenses': AppRoutes.expenses, // /fees/expenses
      'Staff Salaries': AppRoutes.salaries, // /fees/salaries
      'Reports & Analytics': AppRoutes.reports, // /reports
      'Imports Wizard': AppRoutes.bulkImport, // /bulk-import
      'School Setup': AppRoutes.schoolSetup, // /school-setup
      'Roles & Permissions': AppRoutes.rolesPermissions, // /roles-permissions
      'Settings': AppRoutes.settings, // /settings
    };

    test('All 16 expected sidebar routes have non-empty valid URI paths', () {
      expect(expectedSidebarRoutes.length, 16);
      for (final entry in expectedSidebarRoutes.entries) {
        expect(entry.value.startsWith('/'), isTrue,
            reason: '${entry.key} route (${entry.value}) must start with /');
      }
    });

    test('appRouterRedirect handles root / and /staff aliases correctly for authenticated users', () {
      const authUser = UserEntity(
        id: 'u-1',
        email: 'admin@school.org',
        firstName: 'Admin',
        lastName: 'User',
        tenantId: 'tenant-1',
        isSuperuser: false,
        roles: ['ADMIN'],
        schools: ['school-1'],
      );
      const authState = Authenticated(authUser);

      // Root path / redirects to /dashboard
      final rootRedirect = appRouterRedirect(authState: authState, matchedLocation: '/');
      expect(rootRedirect, AppRoutes.dashboard);

      // /staff alias redirects to /teachers
      final staffRedirect = appRouterRedirect(authState: authState, matchedLocation: '/staff');
      expect(staffRedirect, AppRoutes.teachers);
    });

    test('appRouterRedirect permits authenticated admin to all 16 sidebar routes', () {
      const authUser = UserEntity(
        id: 'u-1',
        email: 'admin@school.org',
        firstName: 'Admin',
        lastName: 'User',
        tenantId: 'tenant-1',
        isSuperuser: false,
        roles: ['ADMIN'],
        schools: ['school-1'],
      );
      const authState = Authenticated(authUser);

      for (final entry in expectedSidebarRoutes.entries) {
        final redirect = appRouterRedirect(authState: authState, matchedLocation: entry.value);
        expect(redirect, isNull,
            reason: 'Authenticated admin should have direct access to ${entry.key} (${entry.value}) without redirect');
      }
    });

    test('appRouterRedirect blocks unauthenticated access to all 16 sidebar routes and redirects to /login', () {
      const authState = Unauthenticated();

      for (final entry in expectedSidebarRoutes.entries) {
        final redirect = appRouterRedirect(authState: authState, matchedLocation: entry.value);
        expect(redirect, AppRoutes.login,
            reason: 'Unauthenticated user must be redirected to /login when attempting to access ${entry.key} (${entry.value})');
      }
    });
  });
}
