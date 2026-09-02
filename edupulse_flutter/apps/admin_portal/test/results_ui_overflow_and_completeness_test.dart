import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/results/presentation/pages/student_result_detail_screen.dart';
import 'package:admin_portal/features/results/presentation/providers/results_providers.dart';

class MockSessionManager implements SessionManager {
  @override
  Future<String?> getTenantId() async => 'test-tenant-id';
  @override
  Future<void> saveTenantId(String tenantId) async {}
  @override
  Future<String?> getTenantName() async => 'Test Tenant';
  @override
  Future<void> saveTenantName(String tenantName) async {}
  @override
  Future<String?> getSchoolId() async => 'school-123';
  @override
  Future<void> saveSchoolId(String schoolId) async {}
  @override
  Future<String?> getSchoolName() async => 'Test School';
  @override
  Future<void> saveSchoolName(String schoolName) async {}
  @override
  Future<String?> getAccessToken() async => 'mock_token';
  @override
  Future<String?> getRefreshToken() async => 'mock_refresh';
  @override
  Future<void> saveSession(SessionToken token) async {}
  @override
  Future<void> clearSession() async {}
  @override
  Future<bool> hasSession() async => true;
}

class MockApiClient extends BaseApiClient {
  final Map<String, dynamic> previewJson;
  final Map<String, dynamic> historyJson;

  MockApiClient({required this.previewJson, required this.historyJson}) : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (path.contains('/report-cards/preview/')) {
      return ApiResult.success(mapper({'data': previewJson}));
    }
    if (path.contains('/report-cards/history/') || (path.contains('/report-cards/student/') && path.contains('/history'))) {
      return ApiResult.success(mapper({'data': historyJson}));
    }
    return ApiResult.success(mapper({'data': <String, dynamic>{}}));
  }
}

void main() {
  final samplePreviewJson = {
    'student_id': 'student-001',
    'student_name': 'Aarav Sharma',
    'admission_number': 'ADM2025001',
    'roll_number': '01',
    'class_name': 'Class 10',
    'section_name': 'A',
    'attendance_total': 120,
    'attendance_present': 114,
    'attendance_percentage': 95.0,
    'overall_percentage': 88.5,
    'overall_grade': 'A',
    'promotion_status': 'PROMOTED',
    'subject_marks': [
      {
        'subject_name': 'Mathematics',
        'maximum_marks': 100,
        'marks_obtained': 95.0,
        'result_status': 'PRESENT',
        'grade': 'A+',
        'remarks': 'Excellent mastery',
      },
      {
        'subject_name': 'English Language',
        'maximum_marks': 100,
        'marks_obtained': 82.0,
        'result_status': 'PRESENT',
        'grade': 'A',
        'remarks': 'Strong vocabulary',
      },
    ],
    'teacher_remarks': 'Consistent effort and excellent classroom behavior.',
    'principal_remarks': 'Approved for promotion.',
    'ai_narrative': 'Aarav shows strong analytical skills in STEM subjects.',
    'is_valid': true,
    'missing_reasons': <String>[],
  };

  final sampleHistory3ExamsJson = {
    'student_id': 'student-001',
    'student_name': 'Aarav Sharma',
    'class_name': 'Class 10',
    'section_name': 'A',
    'examinations': [
      {
        'examination_id': 'exam-01',
        'examination_name': 'Quarterly Assessment 2025',
        'total_max_marks': 200,
        'total_obtained_marks': 175.0,
        'percentage': 87.5,
        'grade': 'A',
        'subject_marks': [
          {
            'subject_name': 'Mathematics',
            'max_marks': 100,
            'marks_obtained': 92.0,
            'status': 'PRESENT',
            'grade': 'A+',
          },
          {
            'subject_name': 'English Language',
            'max_marks': 100,
            'marks_obtained': 83.0,
            'status': 'PRESENT',
            'grade': 'A',
          },
        ],
      },
      {
        'examination_id': 'exam-02',
        'examination_name': 'Half-Yearly Examination 2025',
        'total_max_marks': 200,
        'total_obtained_marks': 180.0,
        'percentage': 90.0,
        'grade': 'A+',
        'subject_marks': [
          {
            'subject_name': 'Mathematics',
            'max_marks': 100,
            'marks_obtained': 96.0,
            'status': 'PRESENT',
            'grade': 'A+',
          },
          {
            'subject_name': 'English Language',
            'max_marks': 100,
            'marks_obtained': 84.0,
            'status': 'PRESENT',
            'grade': 'A',
          },
        ],
      },
      {
        'examination_id': 'exam-03',
        'examination_name': 'Pre-Annual Assessment 2026',
        'total_max_marks': 200,
        'total_obtained_marks': 177.0,
        'percentage': 88.5,
        'grade': 'A',
        'subject_marks': [
          {
            'subject_name': 'Mathematics',
            'max_marks': 100,
            'marks_obtained': 95.0,
            'status': 'PRESENT',
            'grade': 'A+',
          },
          {
            'subject_name': 'English Language',
            'max_marks': 100,
            'marks_obtained': 82.0,
            'status': 'PRESENT',
            'grade': 'A',
          },
        ],
      },
    ],
  };

  final sampleHistoryManyLongNamesJson = {
    'student_id': 'student-001',
    'student_name': 'Aarav Sharma With Very Long Registered Full Name',
    'class_name': 'Class 10 - Science & Advanced Computer Applications Stream',
    'section_name': 'Section A - Special Honours Batch',
    'examinations': [
      {
        'examination_id': 'exam-01',
        'examination_name': 'Comprehensive Formative Continuous Diagnostic Assessment Cycle 1 - Term A',
        'total_max_marks': 200,
        'total_obtained_marks': 184.0,
        'percentage': 92.0,
        'grade': 'A+',
        'subject_marks': [
          {
            'subject_name': 'Advanced Differential Mathematics & Applied Statistics',
            'max_marks': 100,
            'marks_obtained': 98.0,
            'status': 'PRESENT',
            'grade': 'A+',
          },
          {
            'subject_name': 'English Language Literature, Creative Composition & Rhetoric',
            'max_marks': 100,
            'marks_obtained': 86.0,
            'status': 'PRESENT',
            'grade': 'A',
          },
        ],
      },
      {
        'examination_id': 'exam-02',
        'examination_name': 'Mid-Year Evaluative Summative Benchmark Assessment Examination 2025-2026',
        'total_max_marks': 200,
        'total_obtained_marks': 180.0,
        'percentage': 90.0,
        'grade': 'A+',
        'subject_marks': [
          {
            'subject_name': 'Advanced Differential Mathematics & Applied Statistics',
            'max_marks': 100,
            'marks_obtained': 94.0,
            'status': 'PRESENT',
            'grade': 'A+',
          },
          {
            'subject_name': 'English Language Literature, Creative Composition & Rhetoric',
            'max_marks': 100,
            'marks_obtained': 86.0,
            'status': 'PRESENT',
            'grade': 'A',
          },
        ],
      },
      {
        'examination_id': 'exam-03',
        'examination_name': 'Pre-Board National Curriculum Rigorous Simulation Examination Series 2',
        'total_max_marks': 200,
        'total_obtained_marks': 183.0,
        'percentage': 91.5,
        'grade': 'A+',
        'subject_marks': [
          {
            'subject_name': 'Advanced Differential Mathematics & Applied Statistics',
            'max_marks': 100,
            'marks_obtained': 97.0,
            'status': 'PRESENT',
            'grade': 'A+',
          },
          {
            'subject_name': 'English Language Literature, Creative Composition & Rhetoric',
            'max_marks': 100,
            'marks_obtained': 86.0,
            'status': 'PRESENT',
            'grade': 'A',
          },
        ],
      },
      {
        'examination_id': 'exam-04',
        'examination_name': 'Final Annual Cumulative Board Standard Summative Evaluation 2026',
        'total_max_marks': 200,
        'total_obtained_marks': 183.0,
        'percentage': 91.5,
        'grade': 'A+',
        'subject_marks': [
          {
            'subject_name': 'Advanced Differential Mathematics & Applied Statistics',
            'max_marks': 100,
            'marks_obtained': 96.0,
            'status': 'PRESENT',
            'grade': 'A+',
          },
          {
            'subject_name': 'English Language Literature, Creative Composition & Rhetoric',
            'max_marks': 100,
            'marks_obtained': 87.0,
            'status': 'PRESENT',
            'grade': 'A',
          },
        ],
      },
    ],
  };

  Widget createTestWidget({
    required Map<String, dynamic> previewJson,
    required Map<String, dynamic> historyJson,
    Size viewportSize = const Size(1200, 900),
  }) {
    final mockApi = MockApiClient(previewJson: previewJson, historyJson: historyJson);
    return ProviderScope(
      overrides: [
        sessionManagerProvider.overrideWithValue(MockSessionManager()),
        apiClientProvider.overrideWithValue(mockApi),
        selectedSchoolIdProvider.overrideWith((ref) => 'school-123'),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: viewportSize),
          child: const Scaffold(
            body: StudentResultDetailScreen(studentId: 'student-001'),
          ),
        ),
      ),
    );
  }

  testWidgets('TEST UI 1: Subject Performance with 3 examinations renders without clipping or overflow', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget(
      previewJson: samplePreviewJson,
      historyJson: sampleHistory3ExamsJson,
      viewportSize: const Size(1200, 900),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Aarav Sharma'), findsOneWidget);
    expect(find.text('Academic Performance Trend'), findsOneWidget);
    expect(find.text('Subject Performance'), findsOneWidget);
    expect(find.text('Academic Performance History'), findsOneWidget);

    // Verify all 3 exams are present in the table
    expect(find.text('Quarterly Assessment 2025'), findsWidgets);
    expect(find.text('Half-Yearly Examination 2025'), findsWidgets);
    expect(find.text('Pre-Annual Assessment 2026'), findsWidgets);

    // Verify no red error banner because isValid is true
    expect(find.text('Incomplete or Invalid Report Card Data'), findsNothing);
  });

  testWidgets('TEST UI 2: Subject Performance with many examinations and long names scrolls horizontally without RenderFlex overflow', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget(
      previewJson: samplePreviewJson,
      historyJson: sampleHistoryManyLongNamesJson,
      viewportSize: const Size(1000, 900),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Subject Performance'), findsOneWidget);
  });

  testWidgets('TEST UI 3: Small mobile viewport (320px width) does not produce RenderFlex overflow', (tester) async {
    final samplePreviewLongJson = Map<String, dynamic>.from(samplePreviewJson);
    samplePreviewLongJson['student_name'] = 'Aarav Sharma With Very Long Registered Full Name';

    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget(
      previewJson: samplePreviewLongJson,
      historyJson: sampleHistoryManyLongNamesJson,
      viewportSize: const Size(320, 700),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Aarav Sharma With Very Long Registered Full Name'), findsOneWidget);
  });

  testWidgets('TEST UI 4: Incomplete report card correctly renders validation error banner with actionable messages', (tester) async {
    final invalidPreviewJson = Map<String, dynamic>.from(samplePreviewJson);
    invalidPreviewJson['is_valid'] = false;
    invalidPreviewJson['missing_reasons'] = [
      'Mathematics marks not published.',
      'English Language marks not entered.',
    ];

    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget(
      previewJson: invalidPreviewJson,
      historyJson: sampleHistory3ExamsJson,
      viewportSize: const Size(1200, 900),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Incomplete or Invalid Report Card Data'), findsOneWidget);
    expect(find.text('Mathematics marks not published.'), findsOneWidget);
    expect(find.text('English Language marks not entered.'), findsOneWidget);
  });
}
