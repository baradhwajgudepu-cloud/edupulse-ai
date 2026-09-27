import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/features/dashboard/presentation/dashboard_screen.dart';
import 'package:admin_portal/features/dashboard/presentation/providers/command_center_provider.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/school_setup/data/models/school_setup_models.dart';
import 'package:admin_portal/features/auth/presentation/providers/auth_provider.dart';

class FakeAuthStateNotifier extends AuthStateNotifier {
  final UserEntity _initialUser;
  FakeAuthStateNotifier(this._initialUser);

  @override
  AuthState build() {
    return Authenticated(_initialUser);
  }
}

class FakeSchoolsListNotifier extends StateNotifier<SchoolsListState> implements SchoolsListNotifier {
  FakeSchoolsListNotifier(super.state);

  @override
  Future<void> fetchSchools() async {}
}

class FakeCommandCenterNotifier extends StateNotifier<CommandCenterMetrics> implements CommandCenterNotifier {
  FakeCommandCenterNotifier(super.state);

  @override
  Future<void> loadDashboard() async {}
}

void main() {
  group('School Command Center Dashboard Tests', () {
    testWidgets('Renders School Command Center with natural language and 5 Snapshot KPIs in ₹', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const mockUser = UserEntity(
        id: 'usr-1',
        firstName: 'Principal',
        lastName: 'Sharma',
        email: 'principal@school.edu',
        tenantId: 'ten-1',
        isSuperuser: false,
        roles: ['PRINCIPAL'],
        schools: ['sch-1'],
        schoolNames: {'sch-1': 'Greenwood High School'},
      );

      const mockSchool = SchoolDto(
        id: 'sch-1',
        tenantId: 'ten-1',
        name: 'Greenwood High School',
        code: 'GW01',
        board: 'CBSE',
        schoolType: 'K12',
        email: 'info@greenwood.edu',
        isActive: true,
        status: 'ACTIVE',
        version: 1,
      );

      const mockMetrics = CommandCenterMetrics(
        totalStudents: 450,
        studentAttendancePct: 92.5,
        teachersPresent: 28,
        totalTeachers: 30,
        todayFeeCollection: 75000.0,
        outstandingFees: 120000.0,
        defaultersCount: 15,
        studentsRequiringAttention: 4,
        alerts: const [
          NeedsAttentionItem(
            id: 'fees_alert',
            title: '₹120000 Outstanding Fees Pending',
            subtitle: '15 student accounts currently have overdue fee installments.',
            severity: AlertSeverity.warning,
            actionLabel: 'View Fees',
            actionRoute: '/fees',
            icon: Icons.receipt_long_outlined,
          ),
        ],
        isLoading: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(() => FakeAuthStateNotifier(mockUser)),
            selectedSchoolIdProvider.overrideWith((ref) => 'sch-1'),
            schoolsListProvider.overrideWith(
              (ref) => FakeSchoolsListNotifier(SchoolsListState(schools: [mockSchool], isLoading: false)),
            ),
            commandCenterProvider.overrideWith(
              (ref) => FakeCommandCenterNotifier(mockMetrics),
            ),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Welcome Card Verification
      expect(find.textContaining('Principal Sharma'), findsOneWidget);
      expect(find.text('Greenwood High School'), findsWidgets);
      expect(find.text('CBSE • Code: GW01'), findsOneWidget);

      // 2. Elimination of Developer Jargon
      expect(find.textContaining('FastAPI Backend Uptime'), findsNothing);
      expect(find.textContaining('PostgreSQL Database Connection'), findsNothing);
      expect(find.textContaining('Active School ID:'), findsNothing);

      // 3. Today's Snapshot KPIs in ₹
      expect(find.text("Today's Operations Snapshot"), findsOneWidget);
      expect(find.text('Students'), findsWidgets);
      expect(find.text('450'), findsOneWidget);
      expect(find.text('92.5%'), findsOneWidget);
      expect(find.text('28 / 30'), findsOneWidget);
      expect(find.text('₹75000'), findsOneWidget);
      expect(find.text('₹120000'), findsWidgets);

      // 4. Needs Attention Actionable Feed
      expect(find.text('Needs Attention'), findsOneWidget);
      expect(find.text('₹120000 Outstanding Fees Pending'), findsOneWidget);
      expect(find.text('View Fees'), findsOneWidget);

      // 5. Quick Actions Bar
      expect(find.text('Add Student'), findsOneWidget);
      expect(find.text('Add Staff'), findsOneWidget);
      expect(find.text('Record Fee'), findsOneWidget);
      expect(find.text('Record Expense'), findsOneWidget);
    });
  });
}
