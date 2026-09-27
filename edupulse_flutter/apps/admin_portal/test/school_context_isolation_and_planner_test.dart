import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:admin_portal/features/dashboard/presentation/dashboard_screen.dart';
import 'package:admin_portal/features/dashboard/presentation/providers/command_center_provider.dart';
import 'package:admin_portal/features/planner/presentation/pages/planner_schedule_screen.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';

class FakePlannerApiClient extends BaseApiClient {
  FakePlannerApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    return ApiResult.success(mapper({'data': []}));
  }

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    return ApiResult.success(mapper({'data': {}}));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('School Context Isolation & Zero-Baseline Dashboard Tests', () {
    testWidgets('Dashboard displays authoritative zero-baseline for new school with 0 students', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const zeroMetrics = CommandCenterMetrics(
        totalStudents: 0,
        studentAttendancePct: 0.0,
        teachersPresent: 0,
        totalTeachers: 0,
        todayFeeCollection: 0.0,
        outstandingFees: 0.0,
        studentsRequiringAttention: 0,
        defaultersCount: 0,
        alerts: [
          NeedsAttentionItem(
            id: 'setup_incomplete',
            title: 'School setup is incomplete.',
            subtitle: 'Academic year, class sections, or faculty accounts are pending initial setup.',
            severity: AlertSeverity.warning,
            actionLabel: 'Setup Checklist',
            actionRoute: '/school-setup',
            icon: Icons.app_registration_rounded,
          ),
        ],
        recentPayments: [],
        isLoading: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            commandCenterProvider.overrideWith((ref) => _FakeCommandCenterNotifier(zeroMetrics)),
            selectedSchoolIdProvider.overrideWith((ref) => 'school-123'),
            selectedSchoolNameProvider.overrideWithValue('Telangana School'),
          ],
          child: MaterialApp(
            theme: EduPulseTheme.lightTheme,
            home: const DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify KPI zero baseline values
      expect(find.text('0'), findsWidgets); // Total Students = 0
      expect(find.text('0 / 0'), findsOneWidget); // Teachers = 0 / 0
      expect(find.text('Not configured'), findsOneWidget); // Attendance = Not configured
      expect(find.text('₹0'), findsWidgets); // Collections = ₹0, Overdue = ₹0

      // 2. Verify incomplete setup guidance in Needs Attention
      expect(find.text('School setup is incomplete.'), findsOneWidget);
      expect(find.text('Add Academic Year'), findsOneWidget);
      expect(find.text('Configure Classes'), findsOneWidget);
      expect(find.text('Import Teachers'), findsOneWidget);
      expect(find.text('Import Students'), findsOneWidget);
      expect(find.text('Configure School Planner'), findsOneWidget);

      // 3. Verify clean empty state for Visual Analytics
      expect(
        find.text('Analytics will generate automatically once daily attendance and academic classes are recorded.'),
        findsOneWidget,
      );

      // 4. Verify clean empty state for Recent Fee Receipts
      expect(find.text('No fee receipts recorded today.'), findsOneWidget);
      expect(find.text('Record Fee'), findsWidgets);
    });
  });

  group('School Operations & Planning Center Tests', () {
    testWidgets('Planner displays School Operations & Planning header with context chips', (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(FakePlannerApiClient()),
            selectedSchoolIdProvider.overrideWith((ref) => 'school-123'),
            selectedSchoolNameProvider.overrideWithValue('Telangana School'),
          ],
          child: MaterialApp(
            theme: EduPulseTheme.lightTheme,
            home: const PlannerScheduleScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Header & Subtitle
      expect(find.text('School Operations & Planning'), findsOneWidget);
      expect(find.text('Plan, approve, publish and coordinate school operations.'), findsOneWidget);

      // 2. Context Chips
      expect(find.text('Campus: Telangana School'), findsOneWidget);
      expect(find.text('Current Term: Term 1'), findsOneWidget);

      // 3. Quick Actions
      expect(find.text('Operational Quick Actions'), findsOneWidget);
      expect(find.text('Review Leave Requests'), findsWidgets);
      expect(find.text('Create Exam'), findsWidgets);
      expect(find.text('Publish Exam'), findsWidgets);
      expect(find.text('Create Circular'), findsWidgets);
      expect(find.text('Create Notification'), findsWidgets);
      expect(find.text('Add School Event'), findsWidgets);
      expect(find.text('Open Academic Calendar'), findsWidgets);
      expect(find.text('Manage Timetable'), findsOneWidget);

      // 4. Five Primary Operations Cards
      expect(find.text('Teacher Leave Approvals'), findsOneWidget);
      expect(find.text('Exams & Assessments'), findsOneWidget);
      expect(find.text('Circulars & Announcements'), findsOneWidget);
      expect(find.text('Notifications & Alerts'), findsOneWidget);
      expect(find.text('School Events & Holidays'), findsOneWidget);

      // 5. Clean Empty States for new school
      expect(find.text('No teacher leave requests yet.'), findsOneWidget);
      expect(find.text('No exams have been created yet.'), findsOneWidget);
      expect(find.text('No circulars have been published yet.'), findsOneWidget);
      expect(find.text('No notifications scheduled yet.'), findsOneWidget);
      expect(find.text('No school events scheduled yet.'), findsOneWidget);

      // 6. Unified Timeline
      expect(find.text('School Operations Timeline'), findsOneWidget);
    });
  });
}

class _FakeCommandCenterNotifier extends StateNotifier<CommandCenterMetrics>
    implements CommandCenterNotifier {
  _FakeCommandCenterNotifier(super.state);

  @override
  Future<void> loadDashboard({bool forceRefresh = false}) async {}
}
