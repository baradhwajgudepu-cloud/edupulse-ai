import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/reports/presentation/pages/reports_dashboard_screen.dart';
import 'package:admin_portal/features/reports/presentation/providers/reports_provider.dart';
import 'package:admin_portal/features/results/presentation/providers/results_providers.dart';

class FakeCompleteReportsSessionManager implements SessionManager {
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

class FakeCompleteReportsApiClient extends BaseApiClient {
  FakeCompleteReportsApiClient() : super(Dio());

  final List<Map<String, dynamic>> _mockSchools = [
    {
      'id': 'school_1',
      'tenant_id': 'tenant_1',
      'name': 'Delhi Public School',
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
    'students_requiring_attention': 1
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
      'subjects': ['Mathematics'],
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
    'grade_distribution': {'A+': 53, 'A': 48, 'B': 180, 'C': 41, 'D': 7, 'E': 31, 'F': 10},
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
    'top_performers': [
      {
        'student_id': 'st_1',
        'student_name': 'Vihaan Rao',
        'academic_percentage': 89.5,
        'grade': 'A',
        'trend': 'IMPROVING'
      }
    ],
    'students_needing_intervention': [
      {
        'student_id': 'st_2',
        'student_name': 'Aarav Kumar',
        'academic_percentage': 60.5,
        'grade': 'D',
        'trend': 'DECLINING'
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
    'low_attendance_students': [
      {
        'student_id': 'st_2',
        'student_name': 'Aarav Kumar',
        'class_name': 'Class 4',
        'section_name': '4-A',
        'class_id': 'class_1',
        'section_id': 'section_1',
        'attendance_percentage': 72.5,
        'present_days': 72,
        'total_days': 100
      }
    ],
    'monthly_attendance_trends': {'June': 92.7},
    'monthly_attendance_trend': {'June': 92.7},
    'class_wise_attendance': {'Class 4': 92.7}
  };

  final Map<String, dynamic> _mockFeesDetail = {
    'total_assigned': 120000.0,
    'total_collected': 100000.0,
    'total_outstanding': 20000.0,
    'paid_students_count': 1,
    'partial_payment_students_count': 1,
    'unpaid_students_count': 0,
    'collection_percentage': 83.3,
    'class_wise_collection': {'Class 4': 83.3},
    'fee_type_wise_collection': {'Tuition Fee': 83.3},
    'student_fees': [
      {
        'student_id': 'st_1',
        'student_name': 'Vihaan Rao',
        'class_name': 'Class 4',
        'section_name': '4-A',
        'class_id': 'class_1',
        'section_id': 'section_1',
        'assigned': 60000.0,
        'paid': 60000.0,
        'outstanding': 0.0,
        'status': 'PAID'
      }
    ]
  };

  final Map<String, dynamic> _mockAIDetail = {
    'high_risk_students': [
      {
        'student_id': 'st_2',
        'student_name': 'Aarav Kumar',
        'class_name': 'Class 4',
        'section_name': '4-A',
        'class_id': 'class_1',
        'section_id': 'section_1',
        'current_percentage': 60.5,
        'previous_percentage': 75.0,
        'attendance_percentage': 72.5,
        'trend': 'DECLINING',
        'risk_level': 'HIGH',
        'ai_narrative': 'Student displays attendance warnings and sliding scores.',
        'recommendation': 'Conduct parental counselor meeting.',
        'attendance_trend': 'DECLINING',
        'weak_subjects': ['Mathematics']
      }
    ],
    'medium_risk_students': [],
    'low_risk_students': [
      {
        'student_id': 'st_1',
        'student_name': 'Vihaan Rao',
        'class_name': 'Class 4',
        'section_name': '4-A',
        'class_id': 'class_1',
        'section_id': 'section_1',
        'current_percentage': 89.5,
        'previous_percentage': 87.0,
        'attendance_percentage': 95.0,
        'trend': 'IMPROVING',
        'risk_level': 'LOW',
        'ai_narrative': 'Student shows strong academic growth.',
        'recommendation': 'Provide advanced enrichment tasks.',
        'attendance_trend': 'STABLE',
        'weak_subjects': []
      }
    ],
    'improving_students': [],
    'declining_students': [],
    'attendance_academic_risk_count': 1,
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

  final Map<String, dynamic> _mockTenantOverview = {
    'total_schools': 3,
    'total_students': 1500,
    'total_teachers': 120,
    'total_classes': 45,
    'total_sections': 120,
    'average_academic_performance': 81.2,
    'average_attendance': 94.1,
    'fee_collection_percentage': 89.5,
    'students_requiring_attention': 15,
    'active_academic_year': '2025-26'
  };

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (path.contains('/reports/tenant/overview')) {
      return ApiResult.success(mapper({'data': _mockTenantOverview}));
    } else if (path.contains('/reports/dashboard')) {
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
  late FakeCompleteReportsApiClient fakeApiClient;
  late FakeCompleteReportsSessionManager fakeSessionManager;

  setUp(() {
    fakeApiClient = FakeCompleteReportsApiClient();
    fakeSessionManager = FakeCompleteReportsSessionManager();
  });

  void setScreenSize(WidgetTester tester, {double width = 1280, double height = 1024}) {
    tester.view.physicalSize = Size(width, height);
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
    await tester.pumpAndSettle();
  }

  testWidgets('Reports Interactive Audit - Complete Suite for all 5 Tabs', (tester) async {
    setScreenSize(tester);

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        sessionManagerProvider.overrideWithValue(fakeSessionManager),
      ],
    );
    container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

    // Seed background data
    await container.read(academicYearsProvider('school_1').notifier).fetchYears();
    await container.read(classesProvider('school_1').notifier).fetchClasses();
    await container.read(sectionsProvider('school_1').notifier).fetchSections();

    final router = createTestRouter(const ReportsDashboardScreen());
    await tester.pumpWidget(buildRouterApp(child: const ReportsDashboardScreen(), container: container, router: router));
    await settlePage(tester);

    // ==========================================
    // 1. OVERVIEW TAB & INTERACTIVE DIALOGS
    // ==========================================
    // Verify Overview Tab is loaded
    expect(find.text('Total Students (School)'), findsOneWidget);

    // Tap "Total Students" KPI card
    await tester.tap(find.text('Total Students (School)'));
    await settlePage(tester);

    // Verify dialog opens
    expect(find.text('Detailed Student Roster'), findsOneWidget);

    // Click Close button in dialog
    await tester.tap(find.byIcon(Icons.close));
    await settlePage(tester);

    // Tap "Total Classes" KPI card to open class breakdown dialog
    await tester.tap(find.text('Total Classes (School)'));
    await settlePage(tester);
    expect(find.text('Class & Section Breakdowns'), findsOneWidget);

    // Tap a section (e.g. 4-A) in class breakdown dialog to update class/section filters and close dialog
    expect(find.text('4-A'), findsWidgets);
    await tester.tap(find.text('4-A').first);
    await settlePage(tester);

    // Dialog should be closed, and filters set
    expect(find.text('Class & Section Breakdowns'), findsNothing);
    final currentFilters = container.read(reportsFiltersProvider);
    expect(currentFilters.classId, isNotNull);
    expect(currentFilters.sectionId, isNotNull);

    // ==========================================
    // 2. ACADEMIC PERFORMANCE TAB & GRADE FILTER
    // ==========================================
    // Switch to Academic Performance Tab
    await tester.tap(find.text('Academic Performance'));
    await settlePage(tester);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await settlePage(tester);

    // Verify Grade Distribution ChoiceChips exist
    expect(find.text('Grade Distribution'), findsOneWidget);
    expect(find.text('A+'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);

    // Select A+ grade chip
    final gradeChip = find.text('A+');
    await tester.ensureVisible(gradeChip);
    await tester.tap(gradeChip);
    await settlePage(tester);
    expect(container.read(reportsFiltersProvider).grade, equals('A+'));

    // Deselect grade chip
    await tester.tap(gradeChip);
    await settlePage(tester);
    expect(container.read(reportsFiltersProvider).grade, isNull);

    // Select Top Performers student to test navigation
    final studentTile = find.text('Vihaan Rao').first;
    await tester.ensureVisible(studentTile);
    await tester.tap(studentTile);
    await settlePage(tester);
    expect(find.text('Student Detail Page st_1'), findsOneWidget);

    // Navigate back to reports
    router.go('/reports');
    await settlePage(tester);

    // ==========================================
    // 3. ATTENDANCE RECORDS TAB
    // ==========================================
    await tester.tap(find.text('Attendance Records'));
    await settlePage(tester);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await settlePage(tester);

    // Verify overall school attendance card is clickable
    expect(find.text('Overall School Attendance'), findsOneWidget);
    final attCard = find.text('Overall School Attendance');
    await tester.ensureVisible(attCard);
    await tester.tap(attCard);
    await settlePage(tester);
    expect(find.text('Attendance Analytics & Warnings'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await settlePage(tester);

    // Verify Month Trend chip works
    expect(find.text('June: 92.7%'), findsOneWidget);
    final monthChip = find.text('June: 92.7%');
    await tester.ensureVisible(monthChip);
    await tester.tap(monthChip);
    await settlePage(tester);
    expect(find.text('Attendance Analytics & Warnings'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await settlePage(tester);

    // ==========================================
    // 4. FEES & FINANCE TAB
    // ==========================================
    await tester.tap(find.text('Fees & Finance'));
    await settlePage(tester);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await settlePage(tester);

    // Verify fee stats cards are clickable
    expect(find.text('Total Net Dues Assigned'), findsOneWidget);
    final duesCard = find.text('Total Net Dues Assigned');
    await tester.ensureVisible(duesCard);
    await tester.tap(duesCard);
    await settlePage(tester);
    expect(find.text('Fee Collection Ledgers'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await settlePage(tester);

    // Verify Fee counts are clickable
    expect(find.text('Fully Paid'), findsOneWidget);
    final paidCount = find.text('Fully Paid');
    await tester.ensureVisible(paidCount);
    await tester.tap(paidCount);
    await settlePage(tester);
    expect(find.text('Fee Collection Ledgers'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await settlePage(tester);

    // ==========================================
    // 5. AI PREDICTIVE INSIGHTS TAB
    // ==========================================
    await tester.tap(find.text('AI Predictive Insights'));
    await settlePage(tester);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await settlePage(tester);

    // Verify risk stats card is clickable
    expect(find.text('High Risk Students'), findsOneWidget);
    final riskCard = find.text('High Risk Students');
    await tester.ensureVisible(riskCard);
    await tester.tap(riskCard);
    await settlePage(tester);
    expect(find.text('AI Predictive Risk Insights'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await settlePage(tester);

    // Verify risk student row is clickable
    expect(find.text('Aarav Kumar'), findsWidgets);
    final riskStudent = find.text('Aarav Kumar').first;
    await tester.ensureVisible(riskStudent);
    await tester.tap(riskStudent);
    await settlePage(tester);
    expect(find.text('Student Detail Page st_2'), findsOneWidget);
  });
}
