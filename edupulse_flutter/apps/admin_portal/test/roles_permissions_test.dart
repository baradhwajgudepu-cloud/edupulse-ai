import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_portal/core/auth/portal_permissions.dart';
import 'package:admin_portal/core/routing/routes.dart';
import 'package:admin_portal/features/roles_permissions/presentation/pages/roles_permissions_screen.dart';
import 'package:edupulse_auth/edupulse_auth.dart';

void main() {
  group('PortalPermissions RBAC Unit Tests', () {
    test('Super Admin has canManageRoles and canAccessSchoolSetup and canAccessRoute', () {
      const user = UserEntity(
        id: 'user-super',
        email: 'superadmin@edupulse.org',
        firstName: 'Super',
        lastName: 'Admin',
        tenantId: null,
        isSuperuser: true,
        roles: ['SUPER_ADMIN'],
        schools: [],
      );
      final perms = PortalPermissions.fromUser(user);

      expect(perms.isSuperAdmin, isTrue);
      expect(perms.canManageRoles, isTrue);
      expect(perms.canAccessSchoolSetup, isTrue);
      expect(perms.canAccessRoute(AppRoutes.rolesPermissions), isTrue);
      expect(perms.canAccessRoute(AppRoutes.schoolSetup), isTrue);
      expect(perms.canAccessRoute(AppRoutes.reports), isTrue);
    });

    test('School Admin / Principal has canManageRoles and canAccessSchoolSetup', () {
      const adminUser = UserEntity(
        id: 'user-admin',
        email: 'admin@school.org',
        firstName: 'School',
        lastName: 'Admin',
        tenantId: 'tenant-1',
        isSuperuser: false,
        roles: ['ADMIN'],
        schools: ['school-1'],
      );
      final adminPerms = PortalPermissions.fromUser(adminUser);

      expect(adminPerms.isTenantAdmin, isTrue);
      expect(adminPerms.canManageRoles, isTrue);
      expect(adminPerms.canAccessSchoolSetup, isTrue);
      expect(adminPerms.canAccessRoute(AppRoutes.rolesPermissions), isTrue);
      expect(adminPerms.canAccessRoute(AppRoutes.schoolSetup), isTrue);
      expect(adminPerms.canAccessRoute(AppRoutes.reports), isTrue);

      const principalUser = UserEntity(
        id: 'user-principal',
        email: 'principal@school.org',
        firstName: 'School',
        lastName: 'Principal',
        tenantId: 'tenant-1',
        isSuperuser: false,
        roles: ['PRINCIPAL'],
        schools: ['school-1'],
      );
      final principalPerms = PortalPermissions.fromUser(principalUser);

      expect(principalPerms.isPrincipal, isTrue);
      expect(principalPerms.canManageRoles, isTrue);
      expect(principalPerms.canAccessSchoolSetup, isTrue);
      expect(principalPerms.canAccessRoute(AppRoutes.rolesPermissions), isTrue);
      expect(principalPerms.canAccessRoute(AppRoutes.schoolSetup), isTrue);
    });

    test('Teacher role CANNOT access Roles & Permissions or School Setup', () {
      const teacherUser = UserEntity(
        id: 'user-teacher',
        email: 'teacher@school.org',
        firstName: 'Teacher',
        lastName: 'User',
        tenantId: 'tenant-1',
        isSuperuser: false,
        roles: ['TEACHER'],
        schools: ['school-1'],
      );
      final teacherPerms = PortalPermissions.fromUser(teacherUser);

      expect(teacherPerms.isTeacher, isTrue);
      expect(teacherPerms.canManageRoles, isFalse);
      expect(teacherPerms.canAccessSchoolSetup, isFalse);
      expect(teacherPerms.canAccessRoute(AppRoutes.rolesPermissions), isFalse);
      expect(teacherPerms.canAccessRoute(AppRoutes.schoolSetup), isFalse);
    });
  });

  group('RolesPermissionsScreen Widget Tests', () {
    testWidgets('Renders Roles & Permissions UI with role cards and permission matrix', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RolesPermissionsScreen(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Header should render
      expect(find.text('Roles & Permissions'), findsOneWidget);
      expect(find.text('Control what each role can view and manage across the school.'), findsOneWidget);
      expect(find.text('RBAC Active'), findsOneWidget);

      // Roles should be listed in the sidebar
      expect(find.text('School Admin'), findsAtLeastNWidgets(1));
      expect(find.text('Teacher'), findsOneWidget);
      expect(find.text('Parent / Guardian'), findsOneWidget);

      // System role badge should appear
      expect(find.text('SYSTEM'), findsAtLeastNWidgets(1));
      expect(find.text('School Admin Permissions Matrix'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);

      // Tapping Save Changes on a protected system role shows backend policy protection notice
      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      expect(find.textContaining('is protected by backend policy'), findsOneWidget);

      // Matrix permission categories and items should be visible
      expect(find.text('Students'), findsAtLeastNWidgets(1));
      expect(find.text('View Student Directory & Profiles'), findsOneWidget);
    });

    testWidgets('Clicking another role updates the active role detail and permissions', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RolesPermissionsScreen(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on Teacher role
      await tester.tap(find.text('Teacher'));
      await tester.pumpAndSettle();

      // Detail header should reflect Teacher Permissions Matrix
      expect(find.text('Teacher Permissions Matrix'), findsOneWidget);
    });
  });
}
