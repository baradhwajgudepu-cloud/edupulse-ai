import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/results/presentation/pages/results_dashboard_screen.dart';
import 'package:admin_portal/features/results/presentation/pages/student_result_detail_screen.dart';
import 'package:admin_portal/features/results/presentation/providers/results_providers.dart';

class FakeDPSSessionManager implements SessionManager {
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
  Future<String?> getSchoolId() async => '2f85ebf4-315d-496a-9611-681ff0fed18f';
  @override
  Future<void> saveSchoolId(String schoolId) async {}
}

class FakeDPSApiClient extends BaseApiClient {
  final List<Map<String, dynamic>> _mockSchools = [
    {
      'id': '2f85ebf4-315d-496a-9611-681ff0fed18f',
      'tenant_id': 'e949f0ba-2f9e-495b-a3b0-8f672070746a',
      'name': 'Delhi Public School Hyderabad - Campus 2',
      'code': 'DPSH_CAMPUS2',
      'board': 'CBSE',
      'school_type': 'CO_ED',
      'email': 'campus2@dps.edu',
      'is_active': true,
      'status': 'ACTIVE',
      'version': 1,
    }
  ];

  final List<Map<String, dynamic>> _mockAcademicYears = [
    {
      'id': '63509136-0525-4a49-96b1-22d139c237a3',
      'tenant_id': 'e949f0ba-2f9e-495b-a3b0-8f672070746a',
      'school_id': '2f85ebf4-315d-496a-9611-681ff0fed18f',
      'name': '2025-26',
      'code': 'AY2025',
      'description': 'Academic Year 2025-26',
      'start_date': '2025-06-01',
      'end_date': '2026-04-30',
      'status': 'ACTIVE',
      'is_current': true,
      'version': 1,
    }
  ];

  final List<Map<String, dynamic>> _mockClasses = [
    {
      'id': 'e67c0fab-1741-4acb-b18a-6c34a562a2c6',
      'tenant_id': 'e949f0ba-2f9e-495b-a3b0-8f672070746a',
      'school_id': '2f85ebf4-315d-496a-9611-681ff0fed18f',
      'academic_year_id': '63509136-0525-4a49-96b1-22d139c237a3',
      'name': 'Class 4',
      'code': 'CLS04',
      'level': 4,
      'category': 'PRIMARY',
      'capacity': 60,
      'status': 'ACTIVE',
      'is_active': true,
      'version': 1,
    }
  ];

  final List<Map<String, dynamic>> _mockSections = [
    {
      'id': 'a0add234-134f-4d5a-a96f-8d24e1f39086',
      'tenant_id': 'e949f0ba-2f9e-495b-a3b0-8f672070746a',
      'school_id': '2f85ebf4-315d-496a-9611-681ff0fed18f',
      'academic_year_id': '63509136-0525-4a49-96b1-22d139c237a3',
      'class_id': 'e67c0fab-1741-4acb-b18a-6c34a562a2c6',
      'name': '4 - A',
      'code': 'CLS04_SEC_4A',
      'capacity': 40,
      'room_number': '201',
      'sort_order': 1,
      'status': 'ACTIVE',
      'is_active': true,
      'version': 1,
    }
  ];

  final List<Map<String, dynamic>> _mockStudents = [
    {
      'id': 'be4546ff-db30-4e42-af9e-2b23e7b3f772',
      'tenant_id': 'e949f0ba-2f9e-495b-a3b0-8f672070746a',
      'school_id': '2f85ebf4-315d-496a-9611-681ff0fed18f',
      'academic_year_id': '63509136-0525-4a49-96b1-22d139c237a3',
      'class_id': 'e67c0fab-1741-4acb-b18a-6c34a562a2c6',
      'section_id': 'a0add234-134f-4d5a-a96f-8d24e1f39086',
      'first_name': 'Vihaan',
      'last_name': 'Rao',
      'admission_number': '10003',
      'roll_number': '1',
      'admission_date': '2025-04-05',
      'status': 'ACTIVE',
      'is_active': true,
      'version': 1,
    },
    {
      'id': '4aafbe91-344b-4d82-b7bb-c5ef7c4ed7bf',
      'tenant_id': 'e949f0ba-2f9e-495b-a3b0-8f672070746a',
      'school_id': '2f85ebf4-315d-496a-9611-681ff0fed18f',
      'academic_year_id': '63509136-0525-4a49-96b1-22d139c237a3',
      'class_id': 'e67c0fab-1741-4acb-b18a-6c34a562a2c6',
      'section_id': 'a0add234-134f-4d5a-a96f-8d24e1f39086',
      'first_name': 'Diya',
      'last_name': 'Rao',
      'admission_number': '10004',
      'roll_number': '2',
      'admission_date': '2025-04-05',
      'status': 'ACTIVE',
      'is_active': true,
      'version': 1,
    }
  ];

  final List<Map<String, dynamic>> _mockReportCards = [
    {
      'id': 'rc_vihaan',
      'verification_uuid': 'a0000000-0000-0000-0000-000000000001',
      'status': 'PUBLISHED',
      'pdf_url': '/static/report_cards/be4546ff-db30-4e42-af9e-2b23e7b3f772.pdf',
      'pdf_history': [],
      'tenant_id': 'e949f0ba-2f9e-495b-a3b0-8f672070746a',
      'school_id': '2f85ebf4-315d-496a-9611-681ff0fed18f',
      'academic_year_id': '63509136-0525-4a49-96b1-22d139c237a3',
      'student_id': 'be4546ff-db30-4e42-af9e-2b23e7b3f772',
      'ai_metrics': {
        'risk_level': 'LOW',
        'overall_trend': 'IMPROVING',
        'ai_narrative': 'Vihaan shows exceptional conceptual clarity in Mathematics and Science.',
      }
    },
    {
      'id': 'rc_diya',
      'verification_uuid': 'a0000000-0000-0000-0000-000000000002',
      'status': 'PUBLISHED',
      'pdf_url': '/static/report_cards/4aafbe91-344b-4d82-b7bb-c5ef7c4ed7bf.pdf',
      'pdf_history': [],
      'tenant_id': 'e949f0ba-2f9e-495b-a3b0-8f672070746a',
      'school_id': '2f85ebf4-315d-496a-9611-681ff0fed18f',
      'academic_year_id': '63509136-0525-4a49-96b1-22d139c237a3',
      'student_id': '4aafbe91-344b-4d82-b7bb-c5ef7c4ed7bf',
      'ai_metrics': {
        'risk_level': 'LOW',
        'overall_trend': 'STABLE',
        'ai_narrative': 'Diya is a stable performer across all subjects.',
      }
    }
  ];

  final Map<String, dynamic> _mockPreviewVihaan = {
    'student_id': 'be4546ff-db30-4e42-af9e-2b23e7b3f772',
    'student_name': 'Vihaan Rao',
    'admission_number': '10003',
    'roll_number': '1',
    'class_name': 'Class 4',
    'section_name': '4 - A',
    'attendance_total': 185,
    'attendance_present': 178,
    'attendance_percentage': 96.22,
    'overall_percentage': 92.67,
    'overall_grade': 'A+',
    'promotion_status': 'PROMOTED',
    'subject_marks': [
      {
        'subject_name': 'Mathematics',
        'maximum_marks': 100,
        'marks_obtained': 96.0,
        'result_status': 'PRESENT',
        'grade': 'A+',
        'remarks': 'Good effort'
      }
    ],
    'teacher_remarks': 'Excellent performance throughout the academic year.',
    'principal_remarks': 'Approved for promotion.',
    'ai_narrative': 'The student shows high conceptual capabilities.',
    'is_valid': true,
    'missing_reasons': []
  };

  final Map<String, dynamic> _mockHistoryVihaan = {
    'student_id': 'be4546ff-db30-4e42-af9e-2b23e7b3f772',
    'student_name': 'Vihaan Rao',
    'class_name': 'Class 4',
    'section_name': '4 - A',
    'examinations': [
      {
        'examination_id': 'exam_pt1',
        'examination_name': 'Periodic Test 1',
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
            'remarks': 'Good effort'
          }
        ]
      }
    ]
  };

  FakeDPSApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (path.contains('/schools/2f85ebf4-315d-496a-9611-681ff0fed18f/academic-years')) {
      return ApiResult.success(mapper({'data': _mockAcademicYears}));
    } else if (path.contains('/schools')) {
      return ApiResult.success(mapper({'data': _mockSchools}));
    } else if (path.contains('/classes')) {
      return ApiResult.success(mapper({'data': _mockClasses}));
    } else if (path.contains('/sections')) {
      return ApiResult.success(mapper({'data': _mockSections}));
    } else if (path.contains('/students')) {
      return ApiResult.success(mapper({'data': _mockStudents}));
    } else if (path.contains('/report-cards/preview/be4546ff-db30-4e42-af9e-2b23e7b3f772')) {
      return ApiResult.success(mapper({'data': _mockPreviewVihaan}));
    } else if (path.contains('/report-cards/history/be4546ff-db30-4e42-af9e-2b23e7b3f772')) {
      return ApiResult.success(mapper({'data': _mockHistoryVihaan}));
    } else if (path.contains('/report-cards')) {
      return ApiResult.success(mapper({'data': _mockReportCards}));
    }

    return ApiResult.failure(const ApiFailure(message: 'Mock Endpoint not found', type: ApiFailureType.unknown));
  }
}

void main() {
  late FakeDPSApiClient fakeApiClient;
  late FakeDPSSessionManager fakeSessionManager;

  setUp(() {
    fakeApiClient = FakeDPSApiClient();
    fakeSessionManager = FakeDPSSessionManager();
  });

  Widget createTestWidget(Widget child, ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: child,
        routes: {
          '/results/students/be4546ff-db30-4e42-af9e-2b23e7b3f772': (_) => const StudentResultDetailScreen(studentId: 'be4546ff-db30-4e42-af9e-2b23e7b3f772'),
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

  testWidgets('DPS Vihaan Rao details page renders correctly with realistic values', (tester) async {
    setScreenSize(tester);
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        sessionManagerProvider.overrideWithValue(fakeSessionManager),
      ],
    );

    container.read(selectedSchoolIdProvider.notifier).state = '2f85ebf4-315d-496a-9611-681ff0fed18f';

    // Seed mock providers
    await container.read(academicYearsProvider('2f85ebf4-315d-496a-9611-681ff0fed18f').notifier).fetchYears();
    await container.read(classesProvider('2f85ebf4-315d-496a-9611-681ff0fed18f').notifier).fetchClasses();
    await container.read(sectionsProvider('2f85ebf4-315d-496a-9611-681ff0fed18f').notifier).fetchSections();

    // Set Filters for Report Cards Provider
    container.read(resultsFiltersProvider.notifier).setClass('e67c0fab-1741-4acb-b18a-6c34a562a2c6');
    container.read(resultsFiltersProvider.notifier).setSection('a0add234-134f-4d5a-a96f-8d24e1f39086');

    // Pump details screen
    await tester.pumpWidget(createTestWidget(
      const StudentResultDetailScreen(studentId: 'be4546ff-db30-4e42-af9e-2b23e7b3f772'),
      container,
    ));

    await tester.pumpAndSettle();

    // 1. Verify Student Info Card
    expect(find.text('Student Details'), findsOneWidget);
    expect(find.text('Vihaan Rao'), findsOneWidget);
    expect(find.text('10003'), findsOneWidget);
    expect(find.text('Class 4'), findsOneWidget);
    expect(find.text('4 - A'), findsOneWidget);

    // 2. Verify Academic Summary Card
    expect(find.text('Academic Summary'), findsOneWidget);
    expect(find.text('92.67%'), findsOneWidget);
    expect(find.text('A+'), findsNWidgets(2)); // Overall Grade & PT1 grade
    expect(find.text('178/185 (96.22%)'), findsOneWidget);
    expect(find.text('PROMOTED'), findsOneWidget);

    // 3. Verify Remarks & Signatures Card
    expect(find.text('Signatures & Remarks'), findsOneWidget);
    expect(find.text('Excellent performance throughout the academic year.'), findsOneWidget);
    expect(find.text('Approved for promotion.'), findsOneWidget);

    // 4. Verify AI predictive card
    expect(find.text('AI Predictive Analytics'), findsOneWidget);
    expect(find.text('LOW'), findsOneWidget);
    expect(find.text('IMPROVING'), findsOneWidget);
    expect(find.text('Vihaan shows exceptional conceptual clarity in Mathematics and Science.'), findsOneWidget);

    // 5. Verify Academic History Section
    expect(find.text('Academic Performance History'), findsOneWidget);
    expect(find.text('Periodic Test 1'), findsAtLeastNWidgets(1));
  });
}
