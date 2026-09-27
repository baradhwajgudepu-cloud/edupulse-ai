import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_portal/features/attendance/presentation/pages/attendance_screen.dart';
import 'package:admin_portal/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:admin_portal/core/auth/portal_permissions.dart';

void main() {
  group('Attendance Riverpod Lifecycle and Mutation Guard Tests', () {
    testWidgets('Mounting AttendanceScreen with initial parameters does not throw provider build mutation error', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            portalPermissionsProvider.overrideWithValue(
              const PortalPermissions(
                isSuperAdmin: false,
                isTenantAdmin: true,
                isPrincipal: false,
                isTeacher: false,
                roles: {'TENANT_ADMIN'},
                schoolIds: ['school-1'],
              ),
            ),
          ],
          child: MaterialApp(
            home: AttendanceScreen(
              initialTab: 1,
              initialMarkClassId: 'cls-101',
              initialMarkSectionId: 'sec-202',
              initialMarkDate: DateTime(2026, 9, 21),
              initialMarkAyId: 'ay-303',
            ),
          ),
        ),
      );

      // Verify that building the widget tree did not throw "Tried to modify a provider while the widget tree was building"
      expect(tester.takeException(), isNull);

      // Allow post-frame callbacks to run
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Verify state was set safely in post-frame callback
      final container = ProviderScope.containerOf(tester.element(find.byType(AttendanceScreen)));
      final markState = container.read(dailyAttendanceMarkProvider);
      expect(markState.classId, 'cls-101');
      expect(markState.sectionId, 'sec-202');
      expect(markState.academicYearId, 'ay-303');
      expect(markState.attendanceDate, DateTime(2026, 9, 21));
    });

    testWidgets('Updating AttendanceScreen widget props schedules parameters in post-frame without build-time error', (tester) async {
      final key = GlobalKey();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            portalPermissionsProvider.overrideWithValue(
              const PortalPermissions(
                isSuperAdmin: false,
                isTenantAdmin: true,
                isPrincipal: false,
                isTeacher: false,
                roles: {'TENANT_ADMIN'},
                schoolIds: ['school-1'],
              ),
            ),
          ],
          child: MaterialApp(
            home: AttendanceScreen(
              key: key,
              initialTab: 0,
            ),
          ),
        ),
      );

      await tester.pump();

      // Rebuild with new initial params (simulating navigation/route change)
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            portalPermissionsProvider.overrideWithValue(
              const PortalPermissions(
                isSuperAdmin: false,
                isTenantAdmin: true,
                isPrincipal: false,
                isTeacher: false,
                roles: {'TENANT_ADMIN'},
                schoolIds: ['school-1'],
              ),
            ),
          ],
          child: MaterialApp(
            home: AttendanceScreen(
              key: key,
              initialTab: 1,
              initialMarkClassId: 'cls-updated',
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
