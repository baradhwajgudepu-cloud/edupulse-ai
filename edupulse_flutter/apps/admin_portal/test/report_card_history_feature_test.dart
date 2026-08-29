import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/results/data/models/results_models.dart';
import 'package:admin_portal/features/results/presentation/providers/results_providers.dart';
import 'package:admin_portal/features/results/presentation/pages/student_result_detail_screen.dart';

class FakeHistorySessionManager implements SessionManager {
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

class FakeHistoryResultsApiClient extends BaseApiClient {
  bool simulateHistoryError = false;

  final Map<String, dynamic> _mockPreview = {
    'student_id': 'st_1',
    'student_name': 'Demo Aditya Patel',
    'admission_number': 'ADM001',
    'roll_number': '1',
    'class_name': 'Class 1',
    'section_name': 'A',
    'attendance_total': 10,
    'attendance_present': 10,
    'attendance_percentage': 100.0,
    'overall_percentage': 82.5,
    'overall_grade': 'A',
    'promotion_status': 'PROMOTED',
    'subject_marks': [],
    'teacher_remarks': 'Excellent performance.',
    'principal_remarks': 'Approved for promotion.',
    'ai_narrative': 'Insights will load.',
    'is_valid': true,
    'missing_reasons': []
  };

  final Map<String, dynamic> _mockHistory = {
    'student_id': 'st_1',
    'student_name': 'Demo Aditya Patel',
    'class_name': 'Class 1',
    'section_name': 'A',
    'examinations': [
      {
        'examination_id': 'exam_pt1',
        'examination_name': 'Periodic Test 1',
        'total_max_marks': 100,
        'total_obtained_marks': 88.0,
        'percentage': 88.0,
        'grade': 'A',
        'subject_marks': [
          {
            'subject_name': 'Mathematics',
            'max_marks': 100,
            'marks_obtained': 88.0,
            'grade': 'A',
            'status': 'PRESENT',
            'remarks': 'Very Good'
          }
        ]
      },
      {
        'examination_id': 'exam_hy',
        'examination_name': 'Half Yearly Examination',
        'total_max_marks': 100,
        'total_obtained_marks': 92.5,
        'percentage': 92.5,
        'grade': 'A+',
        'subject_marks': [
          {
            'subject_name': 'Mathematics',
            'max_marks': 100,
            'marks_obtained': 92.5,
            'grade': 'A+',
            'status': 'PRESENT',
            'remarks': 'Exceptional'
          }
        ]
      }
    ]
  };

  final List<Map<String, dynamic>> _mockReportCards = [
    {
      'id': 'card_1',
      'verification_uuid': 'a8bc2968-3d0d-431d-ab06-b90f518a0801',
      'status': 'PUBLISHED',
      'pdf_url': '/static/report_cards/card_1.pdf',
      'pdf_history': [],
      'tenant_id': 'tenant_1',
      'school_id': 'school_1',
      'academic_year_id': 'ay_1',
      'student_id': 'st_1',
      'ai_metrics': {
        'risk_level': 'LOW',
        'overall_trend': 'IMPROVING',
        'ai_narrative': 'The student shows stellar academic growth across terms.'
      }
    }
  ];

  FakeHistoryResultsApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (path.contains('/report-cards/preview/st_1')) {
      return ApiResult.success(mapper({'data': _mockPreview}));
    }

    if (path.contains('/report-cards/history/st_1')) {
      if (simulateHistoryError) {
        return ApiResult.failure(const ApiFailure(message: 'Failed to fetch history', type: ApiFailureType.unknown));
      }
      return ApiResult.success(mapper({'data': _mockHistory}));
    }

    if (path.contains('/report-cards')) {
      return ApiResult.success(mapper({'data': _mockReportCards}));
    }

    return ApiResult.failure(const ApiFailure(message: 'Not Found', type: ApiFailureType.unknown));
  }
}

void main() {
  late FakeHistoryResultsApiClient fakeApiClient;
  late FakeHistorySessionManager fakeSessionManager;

  setUp(() {
    fakeApiClient = FakeHistoryResultsApiClient();
    fakeSessionManager = FakeHistorySessionManager();
  });

  Widget createTestWidget(Widget child, ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: child,
      ),
    );
  }

  Future<void> setScreenSize(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 2000);
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(1280, 2000));
    addTearDown(() async {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await tester.binding.setSurfaceSize(null);
    });
  }


  group('Student Academic History Feature Tests', () {
    test('StudentAcademicHistoryDto parsing test', () {
      final json = {
        'student_id': 'st_123',
        'student_name': 'Jane Doe',
        'class_name': 'Grade 5',
        'section_name': 'B',
        'examinations': [
          {
            'examination_id': 'ex_1',
            'examination_name': 'Term 1',
            'total_max_marks': 200,
            'total_obtained_marks': 175.5,
            'percentage': 87.75,
            'grade': 'A',
            'subject_marks': [
              {
                'subject_name': 'Science',
                'max_marks': 100,
                'marks_obtained': 92.0,
                'grade': 'A+',
                'status': 'PRESENT',
                'remarks': 'Great job'
              }
            ]
          }
        ]
      };

      final history = StudentAcademicHistoryDto.fromJson(json);

      expect(history.studentId, 'st_123');
      expect(history.studentName, 'Jane Doe');
      expect(history.className, 'Grade 5');
      expect(history.sectionName, 'B');
      expect(history.examinations.length, 1);
      
      final exam = history.examinations.first;
      expect(exam.examinationId, 'ex_1');
      expect(exam.examinationName, 'Term 1');
      expect(exam.totalMaxMarks, 200);
      expect(exam.totalObtainedMarks, 175.5);
      expect(exam.percentage, 87.75);
      expect(exam.grade, 'A');
      expect(exam.subjectMarks.length, 1);

      final mark = exam.subjectMarks.first;
      expect(mark.subjectName, 'Science');
      expect(mark.maxMarks, 100);
      expect(mark.marksObtained, 92.0);
      expect(mark.grade, 'A+');
      expect(mark.status, 'PRESENT');
      expect(mark.remarks, 'Great job');
    });

    testWidgets('StudentResultDetailScreen renders trends, matrix, and expandable examinations', (tester) async {
      await setScreenSize(tester);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(fakeApiClient),
          sessionManagerProvider.overrideWithValue(fakeSessionManager),
          resultsReportCardsProvider.overrideWith((ref) async => [
            ReportCardDto(
              id: 'card_1',
              verificationUuid: 'a8bc2968-3d0d-431d-ab06-b90f518a0801',
              status: 'PUBLISHED',
              pdfHistory: const [],
              tenantId: 'tenant_1',
              schoolId: 'school_1',
              academicYearId: 'ay_1',
              studentId: 'st_1',
              aiMetrics: const {
                'risk_level': 'LOW',
                'overall_trend': 'IMPROVING',
                'ai_narrative': 'The student shows stellar academic growth across terms.'
              },
            )
          ]),
        ],
      );
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

      await tester.pumpWidget(createTestWidget(
        const StudentResultDetailScreen(studentId: 'st_1'),
        container,
      ));

      // Wait for layout and providers to resolve
      await tester.pump();
      await tester.pumpAndSettle();

      // 1. Verify Student Details card renders
      expect(find.text('Demo Aditya Patel'), findsWidgets);
      expect(find.text('ADM001'), findsOneWidget);

      // 2. Verify Academic Summary Card details
      expect(find.text('82.5%'), findsOneWidget);
      expect(find.text('PROMOTED'), findsOneWidget);
      expect(find.text('10/10 (100.0%)'), findsOneWidget);

      // 3. Verify Academic Performance Trend elements
      expect(find.text('Academic Performance Trend'), findsOneWidget);
      expect(find.text('Periodic Test 1'), findsWidgets);
      expect(find.text('Half Yearly Examination'), findsWidgets);
      expect(find.text('88.0%'), findsOneWidget);
      expect(find.text('92.5%'), findsOneWidget);

      // 4. Verify Subject Performance Matrix elements
      expect(find.text('Subject Performance'), findsOneWidget);
      expect(find.text('Mathematics'), findsWidgets);
      expect(find.text('88'), findsOneWidget);
      expect(find.text('93'), findsOneWidget); 

      // 5. Verify Academic Performance History (Expandable Tiles)
      expect(find.text('Academic Performance History'), findsOneWidget);
      final pt1Text = find.text('Periodic Test 1').last;
      expect(pt1Text, findsOneWidget);
      
      // Ensure visible and click
      await tester.ensureVisible(pt1Text);
      // Tap text to expand the tile and reveal detailed marks table
      await tester.tap(pt1Text);
      await tester.pumpAndSettle();


      expect(find.text('Max Marks'), findsWidgets);
      expect(find.text('Marks Obtained'), findsWidgets);
      expect(find.text('Very Good'), findsOneWidget);

      // 6. Verify Signatures & Remarks Card
      final remarksTitle = find.text('Signatures & Remarks');
      expect(remarksTitle, findsOneWidget);
      await tester.ensureVisible(remarksTitle);
      expect(find.text('Teacher Remarks'), findsOneWidget);
      expect(find.text('Excellent performance.'), findsOneWidget);
      expect(find.text('Principal Remarks'), findsOneWidget);
      expect(find.text('Approved for promotion.'), findsOneWidget);

      // 7. Verify AI Predictive Analytics Card
      final aiTitle = find.text('AI Predictive Analytics');
      expect(aiTitle, findsOneWidget);
      await tester.ensureVisible(aiTitle);
      expect(find.text('IMPROVING'), findsOneWidget);
      expect(find.text('LOW'), findsOneWidget);
      expect(find.text('The student shows stellar academic growth across terms.'), findsOneWidget);
    });

    testWidgets('Academic History error state shows retry button', (tester) async {
      await setScreenSize(tester);
      fakeApiClient.simulateHistoryError = true;

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(fakeApiClient),
          sessionManagerProvider.overrideWithValue(fakeSessionManager),
          resultsReportCardsProvider.overrideWith((ref) async => [
            ReportCardDto(
              id: 'card_1',
              verificationUuid: 'a8bc2968-3d0d-431d-ab06-b90f518a0801',
              status: 'PUBLISHED',
              pdfHistory: const [],
              tenantId: 'tenant_1',
              schoolId: 'school_1',
              academicYearId: 'ay_1',
              studentId: 'st_1',
              aiMetrics: const {
                'risk_level': 'LOW',
                'overall_trend': 'IMPROVING',
                'ai_narrative': 'The student shows stellar academic growth across terms.'
              },
            )
          ]),
        ],
      );
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

      await tester.pumpWidget(createTestWidget(
        const StudentResultDetailScreen(studentId: 'st_1'),
        container,
      ));

      // Wait for layout and providers to resolve
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify overall preview loads fine but history shows error
      expect(find.text('Demo Aditya Patel'), findsWidgets);
      expect(find.text('Unable to load academic history.'), findsOneWidget);
      final retryButton = find.byType(ElevatedButton);
      expect(retryButton, findsOneWidget); 

      // Reset simulated error and tap retry
      fakeApiClient.simulateHistoryError = false;
      await tester.ensureVisible(retryButton);
      await tester.tap(retryButton);
      await tester.pumpAndSettle();

      // History should load fine now
      expect(find.text('Academic Performance Trend'), findsOneWidget);
      expect(find.text('Periodic Test 1'), findsWidgets);
    });
  });
}
