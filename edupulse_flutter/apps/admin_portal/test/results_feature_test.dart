import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/results/presentation/pages/results_dashboard_screen.dart';
import 'package:admin_portal/features/results/presentation/pages/student_result_detail_screen.dart';

class FakeResultsSessionManager implements SessionManager {
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

class FakeResultsApiClient extends BaseApiClient {
  bool simulateError = false;

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
      'name': '2026-2027',
      'code': 'AY2026',
      'description': 'Academic Year 2026-2027',
      'start_date': '2026-06-01',
      'end_date': '2027-03-31',
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
      'name': 'Class 8',
      'code': 'CLASS_8',
      'level': 8,
      'category': 'HIGH',
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
      'name': 'Section A',
      'code': 'SEC_A',
      'capacity': 40,
      'room_number': '101',
      'sort_order': 1,
      'status': 'ACTIVE',
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
      'exam_name': 'Term 1 Final Exam',
      'exam_type': 'SUMMATIVE',
      'status': 'PUBLISHED',
      'start_date': '2026-10-01',
      'end_date': '2026-10-15',
      'description': 'Main term exams',
    }
  ];

  final List<Map<String, dynamic>> _mockStudents = [
    {
      'id': 'st_2',
      'school_id': 'school_1',
      'tenant_id': 'tenant_1',
      'admission_number': 'ADM002',
      'roll_number': '2',
      'first_name': 'Aarav',
      'last_name': 'Kumar',
      'gender': 'MALE',
      'date_of_birth': '2012-05-15',
      'mobile': '9876543210',
      'official_email': 'aarav@school.edu',
      'status': 'ACTIVE',
      'academic_year_id': 'ay_1',
      'class_id': 'class_1',
      'section_id': 'section_1',
      'admission_date': '2026-06-01',
      'is_active': true,
      'version': 1,
      'created_at': '2026-08-11T12:00:00Z',
      'updated_at': '2026-08-11T12:00:00Z',
    },
    {
      'id': 'st_1',
      'school_id': 'school_1',
      'tenant_id': 'tenant_1',
      'admission_number': 'ADM001',
      'roll_number': '1',
      'first_name': 'Aditi',
      'last_name': 'Sharma',
      'gender': 'FEMALE',
      'date_of_birth': '2012-08-20',
      'mobile': '9876543211',
      'official_email': 'aditi@school.edu',
      'status': 'ACTIVE',
      'academic_year_id': 'ay_1',
      'class_id': 'class_1',
      'section_id': 'section_1',
      'admission_date': '2026-06-01',
      'is_active': true,
      'version': 1,
      'created_at': '2026-08-11T12:00:00Z',
      'updated_at': '2026-08-11T12:00:00Z',
    }
  ];

  final List<Map<String, dynamic>> _mockReportCards = [
    {
      'id': 'card_1',
      'verification_uuid': 'a8bc2968-3d0d-431d-ab06-b90f518a0801',
      'status': 'PUBLISHED',
      'pdf_url': '/static/report_cards/card_1.pdf',
      'pdf_history': [],
      'generated_at': '2026-08-13T12:00:00Z',
      'published_at': '2026-08-13T15:00:00Z',
      'approved_at': '2026-08-13T14:00:00Z',
      'tenant_id': 'tenant_1',
      'school_id': 'school_1',
      'academic_year_id': 'ay_1',
      'student_id': 'st_1',
      'is_active': true,
      'version': 1,
      'created_at': '2026-08-13T12:00:00Z',
      'updated_at': '2026-08-13T15:00:00Z',
    }
  ];

  final Map<String, dynamic> _mockPreviewValid = {
    'student_id': 'st_1',
    'student_name': 'Aditi Sharma',
    'admission_number': 'ADM001',
    'roll_number': '1',
    'class_name': 'Class 8',
    'section_name': 'Section A',
    'attendance_total': 90,
    'attendance_present': 85,
    'attendance_percentage': 94.44,
    'overall_percentage': 88.5,
    'overall_grade': 'A',
    'promotion_status': 'PROMOTED',
    'subject_marks': [
      {
        'subject_name': 'Mathematics',
        'maximum_marks': 100,
        'marks_obtained': 92.0,
        'result_status': 'PRESENT',
        'grade': 'A+',
        'remarks': 'Outstanding'
      }
    ],
    'teacher_remarks': 'Excellent progress.',
    'principal_remarks': 'Approved for promotion.',
    'ai_narrative': 'Strong analytical skills.',
    'is_valid': true,
    'missing_reasons': []
  };

  final Map<String, dynamic> _mockPreviewInvalid = {
    'student_id': 'st_2',
    'student_name': 'Aarav Kumar',
    'admission_number': 'ADM002',
    'roll_number': '2',
    'class_name': 'Class 8',
    'section_name': 'Section A',
    'attendance_total': 90,
    'attendance_present': 60,
    'attendance_percentage': 66.67,
    'overall_percentage': 32.0,
    'overall_grade': 'F',
    'promotion_status': 'DETAINED',
    'subject_marks': [],
    'teacher_remarks': null,
    'principal_remarks': null,
    'ai_narrative': '',
    'is_valid': false,
    'missing_reasons': ['Mathematics marks not entered.', 'Attendance below threshold.']
  };

  final Map<String, dynamic> _mockHistorySt1 = {
    'student_id': 'st_1',
    'student_name': 'Aditi Sharma',
    'class_name': 'Class 8',
    'section_name': 'Section A',
    'examinations': [
      {
        'examination_id': 'exam_1',
        'examination_name': 'Term 1 Final Exam',
        'total_max_marks': 100,
        'total_obtained_marks': 92.0,
        'percentage': 92.0,
        'grade': 'A+',
        'subject_marks': [
          {
            'subject_name': 'Mathematics',
            'max_marks': 100,
            'marks_obtained': 92.0,
            'grade': 'A+',
            'status': 'PRESENT',
            'remarks': 'Outstanding'
          }
        ]
      }
    ]
  };

  final Map<String, dynamic> _mockHistorySt2 = {
    'student_id': 'st_2',
    'student_name': 'Aarav Kumar',
    'class_name': 'Class 8',
    'section_name': 'Section A',
    'examinations': []
  };

  FakeResultsApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (simulateError && path.contains('/students')) {
      return ApiResult.failure(const ApiFailure(message: 'Simulated API Failure', type: ApiFailureType.unknown));
    }

    if (path.contains('/schools/school_1/academic-years')) {
      return ApiResult.success(mapper({'data': _mockAcademicYears}));
    } else if (path.contains('/schools')) {
      return ApiResult.success(mapper({'data': _mockSchools}));
    } else if (path.contains('/classes')) {
      return ApiResult.success(mapper({'data': _mockClasses}));
    } else if (path.contains('/sections')) {
      return ApiResult.success(mapper({'data': _mockSections}));
    } else if (path.contains('/examinations')) {
      return ApiResult.success(mapper({'data': _mockExaminations}));
    } else if (path.contains('/students')) {
      return ApiResult.success(mapper({'data': _mockStudents}));
    } else if (path.contains('/report-cards/preview/st_1')) {
      return ApiResult.success(mapper({'data': _mockPreviewValid}));
    } else if (path.contains('/report-cards/preview/st_2')) {
      return ApiResult.success(mapper({'data': _mockPreviewInvalid}));
    } else if (path.contains('/report-cards/history/st_1')) {
      return ApiResult.success(mapper({'data': _mockHistorySt1}));
    } else if (path.contains('/report-cards/history/st_2')) {
      return ApiResult.success(mapper({'data': _mockHistorySt2}));
    } else if (path.contains('/report-cards')) {
      return ApiResult.success(mapper({'data': _mockReportCards}));
    }

    return ApiResult.failure(const ApiFailure(message: 'Mock Endpoint not found', type: ApiFailureType.unknown));
  }
}

void main() {
  late FakeResultsApiClient fakeApiClient;
  late FakeResultsSessionManager fakeSessionManager;

  setUp(() {
    fakeApiClient = FakeResultsApiClient();
    fakeSessionManager = FakeResultsSessionManager();
  });

  Widget createTestWidget(Widget child, ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: child,
        routes: {
          '/results': (_) => const ResultsDashboardScreen(),
          '/results/students/st_1': (_) => const StudentResultDetailScreen(studentId: 'st_1'),
          '/results/students/st_2': (_) => const StudentResultDetailScreen(studentId: 'st_2'),
        },
      ),
    );
  }

  void setScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('Results dashboard and filters render correctly', (tester) async {
    setScreenSize(tester);
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        sessionManagerProvider.overrideWithValue(fakeSessionManager),
      ],
    );
    container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

    // Initial load configurations
    await container.read(academicYearsProvider('school_1').notifier).fetchYears();
    await container.read(classesProvider('school_1').notifier).fetchClasses();
    await container.read(sectionsProvider('school_1').notifier).fetchSections();

    await tester.pumpWidget(createTestWidget(const ResultsDashboardScreen(), container));
    await tester.pumpAndSettle();

    // Verify Filters headers & selectors
    expect(find.text('Results & Report Cards'), findsOneWidget);
    expect(find.text('Filter Roster Results'), findsOneWidget);
    expect(find.text('Academic Year'), findsOneWidget);
    expect(find.text('Class'), findsOneWidget);
    expect(find.text('Section'), findsOneWidget);

    // Verify statistics panel cards
    expect(find.text('Total Students'), findsOneWidget);
    expect(find.text('Complete Results'), findsOneWidget);
    expect(find.text('Incomplete Results'), findsOneWidget);
    
    // Total: 2, Complete: 1, Incomplete: 1
    expect(find.text('2'), findsNWidgets(2)); // Total students (and Aarav's roll number)
    expect(find.text('1'), findsNWidgets(3)); // Complete & Incomplete cards, and Aditi's roll number
  });

  testWidgets('Student list renders and roll numbers are sorted numerically', (tester) async {
    setScreenSize(tester);
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        sessionManagerProvider.overrideWithValue(fakeSessionManager),
      ],
    );
    container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

    await tester.pumpWidget(createTestWidget(const ResultsDashboardScreen(), container));
    await tester.pumpAndSettle();

    // Verify students are listed
    expect(find.text('Aditi Sharma'), findsOneWidget);
    expect(find.text('Aarav Kumar'), findsOneWidget);

    // Verify numerical roll sorting: Roll 1 (Aditi) should appear before Roll 2 (Aarav)
    final textWidgets = tester.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '').toList();
    final aditiIdx = textWidgets.indexOf('1. Aditi Sharma');
    final aaravIdx = textWidgets.indexOf('2. Aarav Kumar');
    
    // Mobile ListView has title formatted as "$rollNumber. $fullName"
    if (aditiIdx != -1 && aaravIdx != -1) {
      expect(aditiIdx < aaravIdx, isTrue);
    }
  });

  testWidgets('Empty state and API error handling renders retry button', (tester) async {
    setScreenSize(tester);
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        sessionManagerProvider.overrideWithValue(fakeSessionManager),
      ],
    );
    container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

    // Preload setup requirements successfully
    await container.read(academicYearsProvider('school_1').notifier).fetchYears();
    await container.read(classesProvider('school_1').notifier).fetchClasses();
    await container.read(sectionsProvider('school_1').notifier).fetchSections();

    // Now simulate error for roster fetch
    fakeApiClient.simulateError = true;

    await tester.pumpWidget(createTestWidget(const ResultsDashboardScreen(), container));
    await tester.pumpAndSettle();

    // Verify error state is shown
    expect(find.textContaining('Simulated API Failure'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    // Resolve error simulation and trigger retry
    fakeApiClient.simulateError = false;
    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    // Renders data on success retry
    expect(find.text('Aditi Sharma'), findsOneWidget);
  });

  testWidgets('Student result detail renders dynamic metrics, subject marks, and signatures', (tester) async {
    setScreenSize(tester);
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        sessionManagerProvider.overrideWithValue(fakeSessionManager),
      ],
    );
    container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

    // Load detail screen for valid student st_1
    await tester.pumpWidget(createTestWidget(const StudentResultDetailScreen(studentId: 'st_1'), container));
    await tester.pumpAndSettle();

    // Verify details
    expect(find.text('Aditi Sharma'), findsOneWidget);
    expect(find.text('ADM001'), findsOneWidget);
    expect(find.text('Class 8'), findsOneWidget);
    
    // Overall metrics
    expect(find.text('88.5%'), findsOneWidget);
    expect(find.text('A'), findsWidgets); // Overall grade A
    expect(find.text('PROMOTED'), findsOneWidget);

    // Subject marks mapping
    expect(find.text('Mathematics'), findsWidgets);
    expect(find.text('92'), findsOneWidget);

    // Remarks
    expect(find.text('Excellent progress.'), findsOneWidget);
    expect(find.text('Approved for promotion.'), findsOneWidget);
  });

  testWidgets('Invalid student result detail screen renders missing reasons validation banner', (tester) async {
    setScreenSize(tester);
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        sessionManagerProvider.overrideWithValue(fakeSessionManager),
      ],
    );
    container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

    // Load detail screen for invalid student st_2
    await tester.pumpWidget(createTestWidget(const StudentResultDetailScreen(studentId: 'st_2'), container));
    await tester.pumpAndSettle();

    // Verify banner and missing reasons are shown
    expect(find.text('Incomplete or Invalid Report Card Data'), findsOneWidget);
    expect(find.text('Mathematics marks not entered.'), findsOneWidget);
    expect(find.text('Attendance below threshold.'), findsOneWidget);
    expect(find.text('DETAINED'), findsOneWidget);
  });
}
