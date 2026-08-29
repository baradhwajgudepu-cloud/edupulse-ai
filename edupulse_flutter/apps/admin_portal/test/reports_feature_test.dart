import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/reports/presentation/pages/reports_dashboard_screen.dart';
import 'package:admin_portal/features/results/presentation/providers/results_providers.dart';

class FakeReportsSessionManager implements SessionManager {
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

class FakeReportsApiClient extends BaseApiClient {
  FakeReportsApiClient() : super(Dio());

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

  final List<Map<String, dynamic>> _mockDetailedStudents = [
    {
      'student_id': 'st_1',
      'student_name': 'Vihaan Rao',
      'admission_number': 'ADM2025001',
      'roll_number': '1',
      'class_name': 'Class 4',
      'section_name': '4-A',
      'class_id': 'class_1',
      'section_id': 'section_1',
      'attendance_percentage': 95.0,
      'academic_percentage': 89.5,
      'grade': 'A',
      'promotion_status': 'PROMOTED',
      'risk_level': 'LOW'
    },
    {
      'student_id': 'st_2',
      'student_name': 'Aarav Kumar',
      'admission_number': 'ADM2025002',
      'roll_number': '2',
      'class_name': 'Class 4',
      'section_name': '4-A',
      'class_id': 'class_1',
      'section_id': 'section_1',
      'attendance_percentage': 90.4,
      'academic_percentage': 80.36,
      'grade': 'B',
      'promotion_status': 'PROMOTED',
      'risk_level': 'LOW'
    }
  ];

  final List<Map<String, dynamic>> _mockDetailedTeachers = [
    {
      'teacher_id': 't_1',
      'teacher_name': 'Ananya Sharma',
      'subjects': ['Mathematics', 'Science'],
      'classes': ['Class 4'],
      'sections': ['4-A'],
      'status': 'ACTIVE'
    }
  ];

  final List<Map<String, dynamic>> _mockDetailedClasses = [
    {
      'class_id': 'class_1',
      'class_name': 'Class 4',
      'student_count': 2,
      'section_count': 1,
      'academic_percentage': 84.93,
      'attendance_percentage': 92.7,
      'risk_count': 0,
      'sections': [
        {
          'section_id': 'section_1',
          'section_name': '4-A',
          'student_count': 2,
          'academic_percentage': 84.93,
          'attendance_percentage': 92.7,
          'risk_count': 0
        }
      ]
    }
  ];

  final Map<String, dynamic> _mockAcademicDetail = {
    'average_marks': 84.93,
    'average_percentage': 84.93,
    'highest_marks': 92.0,
    'lowest_marks': 75.0,
    'pass_percentage': 100.0,
    'grade_distribution': {'A': 1, 'B': 1},
    'student_count': 2,
    'subject_performance': [
      {
        'subject_id': 'sub_1',
        'subject_name': 'Mathematics',
        'average_percentage': 88.0,
        'highest_percentage': 92.0,
        'lowest_percentage': 84.0
      }
    ],
    'student_performance': [
      {
        'student_id': 'st_1',
        'student_name': 'Vihaan Rao',
        'percentage': 89.5,
        'grade': 'A',
        'trend': 'IMPROVING'
      }
    ]
  };

  final Map<String, dynamic> _mockAttendanceDetail = {
    'overall_attendance': 92.7,
    'low_attendance_students': [],
    'monthly_attendance_trends': {'June': 92.7}
  };

  final Map<String, dynamic> _mockFeesDetail = {
    'total_assigned': 120000.0,
    'total_collected': 120000.0,
    'total_outstanding': 0.0,
    'paid_students_count': 2,
    'partial_payment_students_count': 0,
    'unpaid_students_count': 0,
    'collection_percentage': 100.0,
    'class_wise_collection': {'Class 4': 100.0},
    'fee_type_wise_collection': {'Tuition Fee': 100.0},
    'student_fees': [
      {
        'student_id': 'st_1',
        'student_name': 'Vihaan Rao',
        'class_name': 'Class 4',
        'section_name': '4-A',
        'assigned': 60000.0,
        'paid': 60000.0,
        'outstanding': 0.0,
        'status': 'PAID'
      }
    ]
  };

  final Map<String, dynamic> _mockAIDetail = {
    'high_risk_students': [],
    'medium_risk_students': [],
    'low_risk_students': [
      {
        'student_id': 'st_1',
        'student_name': 'Vihaan Rao',
        'class_name': 'Class 4',
        'section_name': '4-A',
        'current_percentage': 89.5,
        'previous_percentage': 87.0,
        'attendance_percentage': 95.0,
        'trend': 'IMPROVING',
        'risk_level': 'LOW',
        'ai_narrative': 'Student shows strong academic growth and steady attendance.',
        'recommendation': 'Provide advanced enrichment tasks.',
        'attendance_trend': 'STABLE',
        'weak_subjects': []
      }
    ],
    'improving_students': [
      {
        'student_id': 'st_1',
        'student_name': 'Vihaan Rao',
        'percentage': 89.5
      }
    ],
    'declining_students': [],
    'attendance_academic_risk_count': 0,
    'high_performers_count': 1
  };

  final List<Map<String, dynamic>> _mockSubjects = [
    {
      'id': 'sub_1',
      'tenant_id': 'tenant_1',
      'school_id': 'school_1',
      'academic_year_id': 'ay_1',
      'subject_name': 'Mathematics',
      'subject_code': 'MATH4',
      'is_active': true,
      'version': 1,
    }
  ];

  final List<Map<String, dynamic>> _mockExaminations = [
    {
      'id': 'exam_1',
      'tenant_id': 'tenant_1',
      'school_id': 'school_1',
      'academic_year_id': 'ay_1',
      'exam_name': 'Term 1 Exam',
      'exam_code': 'T1_2025',
      'exam_type': 'SUMMATIVE',
      'start_date': '2025-09-10',
      'end_date': '2025-09-20',
      'status': 'COMPLETED',
      'is_active': true,
      'version': 1,
    }
  ];

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (path.contains('/reports/dashboard')) {
      return ApiResult.success(mapper({'data': _mockDashboard}));
    } else if (path.contains('/reports/students')) {
      return ApiResult.success(mapper({'data': _mockDetailedStudents}));
    } else if (path.contains('/reports/teachers')) {
      return ApiResult.success(mapper({'data': _mockDetailedTeachers}));
    } else if (path.contains('/reports/classes')) {
      return ApiResult.success(mapper({'data': _mockDetailedClasses}));
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
  late FakeReportsApiClient fakeApiClient;
  late FakeReportsSessionManager fakeSessionManager;

  setUp(() {
    fakeApiClient = FakeReportsApiClient();
    fakeSessionManager = FakeReportsSessionManager();
  });

  void setScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget buildRouterApp({
    required Widget child,
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

  GoRouter createTestRouter(Widget screen) {
    return GoRouter(
      initialLocation: '/reports',
      routes: [
        GoRoute(
          path: '/reports',
          builder: (context, state) => screen,
        ),
        GoRoute(
          path: '/results/students/:studentId',
          builder: (context, state) => Scaffold(
            body: Text('Student Detail Page ${state.pathParameters['studentId']}'),
          ),
        ),
      ],
    );
  }

  Future<void> settlePage(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
  }

  testWidgets('Reports overview screen loads and displays 8 metric cards', (tester) async {
    setScreenSize(tester);
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        sessionManagerProvider.overrideWithValue(fakeSessionManager),
      ],
    );
    container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

    // Load setup data
    await container.read(academicYearsProvider('school_1').notifier).fetchYears();
    await container.read(classesProvider('school_1').notifier).fetchClasses();
    await container.read(sectionsProvider('school_1').notifier).fetchSections();

    final router = createTestRouter(const ReportsDashboardScreen());

    await tester.pumpWidget(buildRouterApp(child: const ReportsDashboardScreen(), container: container, router: router));
    await settlePage(tester);

    // Verify filter selections
    expect(find.text('2025-26'), findsWidgets);

    // Verify 8 overview metric cards are present
    expect(find.text('Total Students (School)'), findsOneWidget);
    expect(find.text('Active Teachers (School)'), findsOneWidget);
    expect(find.text('Total Classes (School)'), findsOneWidget);
    expect(find.text('Total Sections (School)'), findsOneWidget);
    expect(find.text('Academic Avg (School)'), findsOneWidget);
    expect(find.text('Attendance Rate (School)'), findsOneWidget);
    expect(find.text('Fee Collection (School)'), findsOneWidget);
    expect(find.text('Risk Alerts (School)'), findsOneWidget);

    // Verify card values
    expect(find.text('2'), findsWidgets); // Students
    expect(find.text('45'), findsOneWidget); // Teachers
    expect(find.text('12 Classes'), findsOneWidget); // Classes
    expect(find.text('4'), findsOneWidget); // Sections
    expect(find.text('84.93%'), findsOneWidget); // Academic average
    expect(find.text('92.7%'), findsOneWidget); // Attendance
    expect(find.text('100.0%'), findsOneWidget); // Fee Collection
    expect(find.text('0'), findsWidgets); // Risk alerts
  });

  testWidgets('Tapping Total Students card opens detailed students roster dialog and search filters', (tester) async {
    setScreenSize(tester);
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        sessionManagerProvider.overrideWithValue(fakeSessionManager),
      ],
    );
    container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

    await container.read(academicYearsProvider('school_1').notifier).fetchYears();
    await container.read(classesProvider('school_1').notifier).fetchClasses();
    await container.read(sectionsProvider('school_1').notifier).fetchSections();

    final router = createTestRouter(const ReportsDashboardScreen());

    await tester.pumpWidget(buildRouterApp(child: const ReportsDashboardScreen(), container: container, router: router));
    await settlePage(tester);

    // Tap Total Students card
    await tester.tap(find.text('Total Students (School)'));
    await settlePage(tester);

    // Verify detailed dialog is open
    expect(find.text('Detailed Student Roster'), findsOneWidget);
    expect(find.text('Vihaan Rao'), findsOneWidget);
    expect(find.text('Aarav Kumar'), findsOneWidget);

    // Test search filter
    await tester.enterText(find.byType(TextField), 'Vihaan');
    await settlePage(tester);

    // Aarav Kumar should be filtered out
    expect(find.text('Vihaan Rao'), findsOneWidget);
    expect(find.text('Aarav Kumar'), findsNothing);

    // Close Dialog
    await tester.tap(find.byIcon(Icons.close));
    await settlePage(tester);
    expect(find.text('Detailed Student Roster'), findsNothing);
  });

  testWidgets('Tapping on a student roster item sets result filters and navigates to Student Detail Page', (tester) async {
    setScreenSize(tester);
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        sessionManagerProvider.overrideWithValue(fakeSessionManager),
      ],
    );
    container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

    await container.read(academicYearsProvider('school_1').notifier).fetchYears();
    await container.read(classesProvider('school_1').notifier).fetchClasses();
    await container.read(sectionsProvider('school_1').notifier).fetchSections();

    final router = createTestRouter(const ReportsDashboardScreen());

    await tester.pumpWidget(buildRouterApp(child: const ReportsDashboardScreen(), container: container, router: router));
    await settlePage(tester);

    // Tap Students Card to open roster
    await tester.tap(find.text('Total Students (School)'));
    await settlePage(tester);

    // Tap Vihaan Rao item
    await tester.tap(find.text('Vihaan Rao'));
    await settlePage(tester);

    // Dialog should close, and router should navigate to Student Detail Page
    expect(find.text('Detailed Student Roster'), findsNothing);
    expect(find.textContaining('Student Detail Page st_1'), findsOneWidget);

    // Verify that the result filter state was updated to match the selected student context
    final resultsFilters = container.read(resultsFiltersProvider);
    expect(resultsFilters.classId, 'class_1');
    expect(resultsFilters.sectionId, 'section_1');
    expect(resultsFilters.academicYearId, 'ay_1');
  });

  testWidgets('Tapping other overview cards opens their respective detailed dialog breakdowns', (tester) async {
    setScreenSize(tester);
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        sessionManagerProvider.overrideWithValue(fakeSessionManager),
      ],
    );
    container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

    await container.read(academicYearsProvider('school_1').notifier).fetchYears();
    await container.read(classesProvider('school_1').notifier).fetchClasses();
    await container.read(sectionsProvider('school_1').notifier).fetchSections();

    final router = createTestRouter(const ReportsDashboardScreen());

    await tester.pumpWidget(buildRouterApp(child: const ReportsDashboardScreen(), container: container, router: router));
    await settlePage(tester);

    // 1. Tapping Teachers card
    await tester.tap(find.text('Active Teachers (School)'));
    await settlePage(tester);
    expect(find.text('Detailed Teacher Assignments'), findsOneWidget);
    expect(find.text('Ananya Sharma'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await settlePage(tester);

    // 2. Tapping Classes card
    await tester.tap(find.text('Total Classes (School)'));
    await settlePage(tester);
    expect(find.text('Class & Section Breakdowns'), findsOneWidget);
    expect(find.text('Class 4'), findsWidgets);
    await tester.tap(find.byIcon(Icons.close));
    await settlePage(tester);

    // 3. Tapping Academic Average card
    await tester.tap(find.text('Academic Avg (School)'));
    await settlePage(tester);
    expect(find.text('Academic Performance Analytics'), findsOneWidget);
    expect(find.text('Subject-wise Performance'), findsOneWidget);
    expect(find.text('Mathematics'), findsWidgets);
    await tester.tap(find.byIcon(Icons.close));
    await settlePage(tester);

    // 4. Tapping Attendance Rate card
    await tester.tap(find.text('Attendance Rate (School)'));
    await settlePage(tester);
    expect(find.text('Attendance Analytics & Warnings'), findsOneWidget);
    expect(find.text('Monthly Attendance Trends'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await settlePage(tester);

    // 5. Tapping Fee Collection card
    await tester.tap(find.text('Fee Collection (School)'));
    await settlePage(tester);
    expect(find.text('Fee Collection Ledgers'), findsOneWidget);
    expect(find.text('Vihaan Rao'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await settlePage(tester);
  });
}
