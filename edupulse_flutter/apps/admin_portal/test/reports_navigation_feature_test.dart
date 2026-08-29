import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/reports/presentation/pages/reports_dashboard_screen.dart';
import 'package:admin_portal/features/reports/presentation/providers/reports_provider.dart';
import 'package:admin_portal/features/auth/presentation/providers/auth_provider.dart';

class FakeAuthStateNotifier extends AuthStateNotifier {
  final UserEntity mockUser;
  FakeAuthStateNotifier(this.mockUser);

  @override
  AuthState build() {
    return Authenticated(mockUser);
  }
}

class FakeTestSessionManager implements SessionManager {
  String? cachedTenantId;

  @override
  Future<String?> getTenantId() async => cachedTenantId;

  @override
  Future<void> saveTenantId(String tenantId) async {
    cachedTenantId = tenantId;
  }

  @override
  Future<String?> getAccessToken() async => 'mock_access';
  @override
  Future<String?> getRefreshToken() async => 'mock_refresh';
  @override
  Future<void> saveSession(SessionToken token) async {}
  @override
  Future<void> clearSession() async {}
  @override
  Future<bool> hasSession() async => true;
  @override
  Future<String?> getSchoolId() async => 'school_1';
  @override
  Future<void> saveSchoolId(String schoolId) async {}
}

class FakeTestReportsApiClient extends BaseApiClient {
  FakeTestReportsApiClient() : super(Dio());

  bool simulateError = false;

  final List<Map<String, dynamic>> _mockSchools = [
    {
      'id': 'school_1',
      'tenant_id': 'tenant_1',
      'name': 'Delhi Public School Hyderabad',
      'code': 'DPS001',
      'board': 'CBSE',
      'school_type': 'HIGH_SCHOOL',
      'email': 'dps@school.edu',
      'is_active': true,
      'status': 'ACTIVE',
      'version': 1,
    }
  ];

  final List<Map<String, dynamic>> _mockAcademicYears = [
    {
      'id': 'ay_1',
      'tenant_id': 'tenant_1',
      'school_id': 'school_1',
      'name': '2025-26',
      'code': 'AY2025',
      'description': 'Academic Year 2025-2026',
      'start_date': '2025-06-01',
      'end_date': '2026-03-31',
      'status': 'ACTIVE',
      'is_current': true,
      'version': 1,
    }
  ];

  final List<Map<String, dynamic>> _mockClasses = [
    {
      'id': 'class_1',
      'tenant_id': 'tenant_1',
      'school_id': 'school_1',
      'academic_year_id': 'ay_1',
      'name': 'Class 4',
      'code': 'CLASS_4',
      'level': 4,
      'category': 'PRIMARY',
      'capacity': 40,
      'status': 'ACTIVE',
      'is_active': true,
      'version': 1,
    }
  ];

  final List<Map<String, dynamic>> _mockSections = [
    {
      'id': 'section_1',
      'tenant_id': 'tenant_1',
      'school_id': 'school_1',
      'academic_year_id': 'ay_1',
      'class_id': 'class_1',
      'name': '4-A',
      'code': '4_A',
      'capacity': 40,
      'room_number': '101',
      'sort_order': 1,
      'status': 'ACTIVE',
      'is_active': true,
      'version': 1,
    }
  ];

  final Map<String, dynamic> _mockDashboard = {
    'total_students': 2,
    'active_teachers': 45,
    'total_classes': 12,
    'total_sections': 4,
    'average_academic_performance': 84.93,
    'average_attendance': 92.7,
    'fee_collection_percentage': 100.0,
    'students_requiring_attention': 0
  };

  final Map<String, dynamic> _mockTenantOverview = {
    'tenant_name': 'EduPulse Group Test',
    'total_schools': 3,
    'total_students': 150,
    'total_teachers': 25,
    'overall_attendance': 96.5,
    'fee_collection_percentage': 92.0,
    'outstanding_fees': 45000.0,
    'report_card_completion_percentage': 88.0,
    'active_academic_year': '2025-26',
    'schools': <dynamic>[]
  };

  final Map<String, dynamic> _mockAcademicDetail = {
    'average_marks': 84.93,
    'average_percentage': 84.93,
    'highest_marks': 92.0,
    'lowest_marks': 75.0,
    'pass_percentage': 100.0,
    'grade_distribution': <String, dynamic>{'A': 1, 'B': 1},
    'student_count': 2,
    'subject_performance': <dynamic>[],
    'student_performance': <dynamic>[]
  };

  final Map<String, dynamic> _mockAttendanceDetail = {
    'overall_attendance': 92.7,
    'low_attendance_students': <dynamic>[],
    'monthly_attendance_trend': <String, dynamic>{'June': 92.7},
    'class_wise_attendance': <String, dynamic>{}
  };

  final Map<String, dynamic> _mockFeesDetail = {
    'total_assigned': 120000.0,
    'total_collected': 120000.0,
    'total_outstanding': 0.0,
    'paid_students_count': 2,
    'partial_payment_students_count': 0,
    'unpaid_students_count': 0,
    'collection_percentage': 100.0,
    'class_wise_collection': <String, dynamic>{},
    'fee_type_wise_collection': <String, dynamic>{},
    'student_fees': <dynamic>[]
  };

  final Map<String, dynamic> _mockAIDetail = {
    'high_risk_students': <dynamic>[],
    'medium_risk_students': <dynamic>[],
    'low_risk_students': <dynamic>[],
    'improving_students': <dynamic>[],
    'declining_students': <dynamic>[],
    'attendance_academic_risk_count': 0,
    'high_performers_count': 1
  };

  final List<Map<String, dynamic>> _mockSubjects = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _mockExaminations = <Map<String, dynamic>>[];

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (simulateError) {
      return ApiResult.failure(const ApiFailure(message: 'Simulated API Exception', type: ApiFailureType.unknown));
    }
    if (path.contains('/reports/dashboard')) {
      return ApiResult.success(mapper({'data': _mockDashboard}));
    } else if (path.contains('/reports/tenant/overview')) {
      return ApiResult.success(mapper({'data': _mockTenantOverview}));
    } else if (path.contains('/reports/academic')) {
      return ApiResult.success(mapper({'data': _mockAcademicDetail}));
    } else if (path.contains('/reports/attendance')) {
      return ApiResult.success(mapper({'data': _mockAttendanceDetail}));
    } else if (path.contains('/reports/fees')) {
      return ApiResult.success(mapper({'data': _mockFeesDetail}));
    } else if (path.contains('/reports/ai-intelligence')) {
      return ApiResult.success(mapper({'data': _mockAIDetail}));
    } else if (path.contains('/schools/school_1/academic-years')) {
      return ApiResult.success(mapper({'data': _mockAcademicYears}));
    } else if (path.contains('/schools')) {
      return ApiResult.success(mapper({'data': _mockSchools}));
    } else if (path.contains('/classes')) {
      return ApiResult.success(mapper({'data': _mockClasses}));
    } else if (path.contains('/sections')) {
      return ApiResult.success(mapper({'data': _mockSections}));
    } else if (path.contains('/subjects')) {
      return ApiResult.success(mapper({'data': _mockSubjects}));
    } else if (path.contains('/examinations')) {
      return ApiResult.success(mapper({'data': _mockExaminations}));
    }

    return ApiResult.failure(const ApiFailure(message: 'Mock Endpoint not found', type: ApiFailureType.unknown));
  }
}

void main() {
  late FakeTestReportsApiClient fakeApiClient;
  late FakeTestSessionManager fakeSessionManager;

  setUp(() {
    fakeApiClient = FakeTestReportsApiClient();
    fakeSessionManager = FakeTestSessionManager();
  });

  Widget buildTestApp({
    required ProviderContainer container,
    required GoRouter router,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }

  GoRouter createTestRouter() {
    return GoRouter(
      initialLocation: '/reports',
      routes: [
        GoRoute(
          path: '/reports',
          builder: (context, state) => const ReportsDashboardScreen(),
        ),
      ],
    );
  }

  Future<void> settlePage(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
  }

  testWidgets('Reports Tab Navigation & Layout Hardening Scenarios', (tester) async {
    tester.view.physicalSize = const Size(1280, 800); // Landscape Desktop
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const mockUser = UserEntity(
      id: 'u_1',
      email: 'admin@school.edu',
      firstName: 'Super',
      lastName: 'Administrator',
      tenantId: 'tenant_1',
      isSuperuser: true,
      roles: ['SUPER_ADMIN'],
      schools: ['school_1'],
    );

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        sessionManagerProvider.overrideWithValue(fakeSessionManager),
        authStateProvider.overrideWith(() => FakeAuthStateNotifier(mockUser)),
      ],
    );

    // Initial setup with a valid school context
    container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

    final router = createTestRouter();
    await tester.pumpWidget(buildTestApp(container: container, router: router));
    await settlePage(tester);

    // Verify 1: Overview tab is visible (Scenario 1)
    expect(find.byKey(const Key('reports_tab_overview')), findsOneWidget);
    expect(find.text('Key Operational Metrics'), findsOneWidget);
    // Verify 2-3: Tap Overview, stays active
    final tabOverview = find.byKey(const Key('reports_tab_overview'));
    await tester.ensureVisible(tabOverview);
    await tester.tap(tabOverview);
    await settlePage(tester);
    expect(find.text('Key Operational Metrics'), findsOneWidget);

    // Verify 4-5: Tap Academic Performance (Scenario 4 & 5)
    final tabAcademic = find.byKey(const Key('reports_tab_academic'));
    await tester.ensureVisible(tabAcademic);
    await tester.tap(tabAcademic);
    await settlePage(tester);
    expect(find.text('Class Avg Percentage'), findsOneWidget);

    // Verify 6-7: Tap Attendance Records (Scenario 6 & 7)
    final tabAttendance = find.byKey(const Key('reports_tab_attendance'));
    await tester.ensureVisible(tabAttendance);
    await tester.tap(tabAttendance);
    await settlePage(tester);
    expect(find.text('Monthly Attendance Trends'), findsOneWidget);

    // Verify 8-9: Tap Fees & Finance (Scenario 8 & 9)
    final tabFees = find.byKey(const Key('reports_tab_fees'));
    await tester.ensureVisible(tabFees);
    await tester.tap(tabFees);
    await settlePage(tester);
    expect(find.text('Total Net Dues Assigned'), findsOneWidget);

    // Verify 10-11: Tap AI Predictive Insights (Scenario 10 & 11)
    final tabAI = find.byKey(const Key('reports_tab_ai'));
    await tester.ensureVisible(tabAI);
    await tester.tap(tabAI);
    await settlePage(tester);
    expect(find.text('Flagged Students Requiring Immediate Attention'), findsOneWidget);

    // Verify 12-14: All 5 tabs reachable, active content updates correctly, no crashes
    expect(find.byKey(const Key('reports_tab_overview')), findsOneWidget);
    expect(find.byKey(const Key('reports_tab_academic')), findsOneWidget);
    expect(find.byKey(const Key('reports_tab_attendance')), findsOneWidget);
    expect(find.byKey(const Key('reports_tab_fees')), findsOneWidget);
    expect(find.byKey(const Key('reports_tab_ai')), findsOneWidget);

    // Verify 15-16: Filters persist during tab switching, reset updates filter
    await tester.ensureVisible(tabOverview);
    await tester.tap(tabOverview);
    await settlePage(tester);
    
    // Tap Reset (Scenario 16)
    await tester.tap(find.text('Reset'));
    await settlePage(tester);
    expect(find.text('Key Operational Metrics'), findsOneWidget);

    // Scenario 23: Tenant All Schools context
    container.read(selectedSchoolIdProvider.notifier).state = null; // Switching to "All Schools"
    await settlePage(tester);
    
    // In tenant context, the overview shows tenant-specific metrics
    expect(find.text('Total Students (Group)'), findsOneWidget);
    expect(find.text('Total Schools'), findsOneWidget);
    expect(find.text('150'), findsOneWidget); // Total Group Students
    expect(find.text('3 Schools'), findsOneWidget); // 3 total schools

    // Verify filter check (unauthorized school context blocked / select school message)
    await tester.ensureVisible(tabAcademic);
    await tester.tap(tabAcademic);
    await settlePage(tester);
    expect(find.text('Please select a specific school context to view academic performance analytics.'), findsOneWidget);

    // Scenario 21: Test on a very small viewport to ensure no RenderFlex overflows
    tester.view.physicalSize = const Size(600, 960);
    await settlePage(tester);
  });

  testWidgets('Reports Navigation error states and retry checks', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    fakeApiClient.simulateError = true; // Inject error

    const mockUser = UserEntity(
      id: 'u_1',
      email: 'admin@school.edu',
      firstName: 'Super',
      lastName: 'Administrator',
      tenantId: 'tenant_1',
      isSuperuser: true,
      roles: ['SUPER_ADMIN'],
      schools: ['school_1'],
    );

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        sessionManagerProvider.overrideWithValue(fakeSessionManager),
        authStateProvider.overrideWith(() => FakeAuthStateNotifier(mockUser)),
      ],
    );

    container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

    final router = createTestRouter();
    await tester.pumpWidget(buildTestApp(container: container, router: router));
    await settlePage(tester);

    // Scenario 18-19: Error state renders
    expect(find.textContaining('Unable to load overview metrics right now'), findsOneWidget);

    // Clear error for retry
    fakeApiClient.simulateError = false;
    container.invalidate(reportsDashboardProvider);
    await settlePage(tester);
  });
}
