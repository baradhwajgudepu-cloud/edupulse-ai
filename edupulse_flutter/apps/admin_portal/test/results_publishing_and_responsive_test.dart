import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/results/presentation/pages/results_dashboard_screen.dart';
import 'package:admin_portal/features/results/presentation/pages/student_result_detail_screen.dart';
import 'package:admin_portal/features/results/presentation/widgets/predictive_analytics_view.dart';
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
  Future<String?> getSchoolName() async => 'Delhi Public School';
  @override
  Future<void> saveSchoolName(String schoolName) async {}
  @override
  Future<String?> getAccessToken() async => 'mock_token';
  @override
  Future<String?> getRefreshToken() async => 'mock_refresh';
  @override
  Future<void> saveSession(SessionToken token) async {}
  @override
  Future<void> clearSession([String source = 'SessionManager.clearSession']) async {}
  @override
  Future<bool> hasSession() async => true;
}

class MockPublishingApiClient extends BaseApiClient {
  bool isExamPublished = false;
  bool isExamComplete = false;

  MockPublishingApiClient() : super(Dio());

  final Map<String, dynamic> _mockSchool = {
    'id': 'school-123',
    'tenant_id': 'test-tenant-id',
    'name': 'Delhi Public School',
    'code': 'DPS001',
    'board': 'CBSE',
    'school_type': 'HIGH_SCHOOL',
    'email': 'admin@dps.edu',
    'is_active': true,
    'status': 'ACTIVE',
    'version': 1,
  };

  final List<Map<String, dynamic>> _mockAcademicYears = [
    {
      'id': 'ay-2026',
      'tenant_id': 'test-tenant-id',
      'school_id': 'school-123',
      'name': '2026-2027',
      'code': 'AY2026',
      'status': 'ACTIVE',
      'is_current': true,
      'start_date': '2026-06-01',
      'end_date': '2027-03-31',
    }
  ];

  final List<Map<String, dynamic>> _mockClasses = [
    {
      'id': 'class-10',
      'tenant_id': 'test-tenant-id',
      'school_id': 'school-123',
      'academic_year_id': 'ay-2026',
      'name': 'Class 10',
      'code': 'C10',
      'level': 10,
      'category': 'SECONDARY',
      'capacity': 40,
      'status': 'ACTIVE',
      'is_active': true,
    }
  ];

  final List<Map<String, dynamic>> _mockSections = [
    {
      'id': 'section-10a',
      'tenant_id': 'test-tenant-id',
      'school_id': 'school-123',
      'academic_year_id': 'ay-2026',
      'class_id': 'class-10',
      'name': 'Section A',
      'code': '10A',
      'capacity': 40,
      'status': 'ACTIVE',
      'is_active': true,
    }
  ];

  final List<Map<String, dynamic>> _mockExaminations = [
    {
      'id': 'exam-term1',
      'tenant_id': 'test-tenant-id',
      'school_id': 'school-123',
      'academic_year_id': 'ay-2026',
      'exam_name': 'Term 1 Summative Assessment',
      'exam_type': 'SUMMATIVE',
      'status': 'APPROVED',
      'start_date': '2026-09-01',
      'end_date': '2026-09-15',
      'description': 'Mid-term evaluation',
    }
  ];

  final List<Map<String, dynamic>> _mockStudents = [
    {
      'id': 'student-01',
      'school_id': 'school-123',
      'tenant_id': 'test-tenant-id',
      'admission_number': 'ADM101',
      'roll_number': '1',
      'first_name': 'Rohan',
      'last_name': 'Verma',
      'gender': 'MALE',
      'date_of_birth': '2011-04-12',
      'status': 'ACTIVE',
      'academic_year_id': 'ay-2026',
      'class_id': 'class-10',
      'section_id': 'section-10a',
      'admission_date': '2026-06-01',
      'is_active': true,
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
    if (path.contains('/schools/school-123/academic-years')) {
      return ApiResult.success(mapper({'data': _mockAcademicYears}));
    } else if (path.contains('/schools')) {
      return ApiResult.success(mapper({'data': [_mockSchool]}));
    } else if (path.contains('/classes')) {
      return ApiResult.success(mapper({'data': _mockClasses}));
    } else if (path.contains('/sections')) {
      return ApiResult.success(mapper({'data': _mockSections}));
    } else if (path.contains('/examinations') && !path.contains('result-readiness')) {
      return ApiResult.success(mapper({'data': _mockExaminations}));
    } else if (path.contains('/students')) {
      return ApiResult.success(mapper({'data': _mockStudents}));
    } else if (path.contains('/marks/examinations/exam-term1/result-readiness')) {
      return ApiResult.success(mapper({
        'data': {
          'examination_id': 'exam-term1',
          'examination_name': 'Term 1 Summative Assessment',
          'academic_year_id': 'ay-2026',
          'class_id': 'class-10',
          'class_name': 'Class 10',
          'section_id': 'section-10a',
          'section_name': 'Section A',
          'total_students': 30,
          'students_with_complete_results': isExamComplete ? 30 : 0,
          'students_with_incomplete_results': isExamComplete ? 0 : 30,
          'draft_results_count': isExamComplete ? 0 : 30,
          'ready_to_publish_count': isExamComplete && !isExamPublished ? 30 : 0,
          'published_count': isExamPublished ? 30 : 0,
          'is_ready_to_publish': isExamComplete && !isExamPublished,
          'is_fully_published': isExamPublished,
          'publication_status': isExamPublished ? 'PUBLISHED' : (isExamComplete ? 'READY' : 'INCOMPLETE'),
          'last_published_date': isExamPublished ? '2026-09-24T18:00:00Z' : null,
          'published_by_name': isExamPublished ? 'Principal Sharma' : null,
          'status_message': isExamPublished
              ? 'Results are published and visible to parents and students.'
              : (isExamComplete
                  ? 'All 30 students have complete results. Ready to publish.'
                  : '30 students remain incomplete. Complete all required marks before publishing.'),
          'missing_breakdown': isExamComplete ? [] : [
            {'subject_name': 'Mathematics', 'missing_count': 30}
          ],
          'can_unpublish': true,
        }
      }));
    } else if (path.contains('/report-cards/preview/student-01')) {
      return ApiResult.success(mapper({
        'data': {
          'student_id': 'student-01',
          'student_name': 'Rohan Verma',
          'admission_number': 'ADM101',
          'roll_number': '1',
          'class_name': 'Class 10',
          'section_name': 'Section A',
          'attendance_total': 100,
          'attendance_present': 92,
          'attendance_percentage': 92.0,
          'overall_percentage': 85.0,
          'overall_grade': 'A',
          'promotion_status': 'PROMOTED',
          'subject_marks': [
            {
              'subject_name': 'Mathematics',
              'maximum_marks': 100,
              'marks_obtained': 85.0,
              'result_status': 'PRESENT',
              'grade': 'A',
              'remarks': 'Good problem solving'
            }
          ],
          'teacher_remarks': null,
          'principal_remarks': null,
          'ai_narrative': 'Solid academic foundation.',
          'is_valid': false,
          'missing_reasons': [
            'Teacher remark not entered for final evaluation.',
            'No examination schedules configured for Practical Paper.'
          ]
        }
      }));
    } else if (path.contains('/report-cards/history/student-01')) {
      return ApiResult.success(mapper({
        'data': {
          'student_id': 'student-01',
          'student_name': 'Rohan Verma',
          'class_name': 'Class 10',
          'section_name': 'Section A',
          'examinations': []
        }
      }));
    } else if (path.contains('/report-cards')) {
      return ApiResult.success(mapper({'data': <dynamic>[]}));
    }

    return ApiResult.success(mapper({'data': <dynamic>[]}));
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
    if (path.contains('/publish')) {
      isExamPublished = true;
      return ApiResult.success(mapper({
        'published_count': 30,
        'missing_count': 0,
        'is_fully_published': true,
      }));
    } else if (path.contains('/unpublish')) {
      isExamPublished = false;
      return ApiResult.success(mapper({
        'unpublished_count': 30,
        'message': 'Successfully unpublished',
      }));
    } else if (path.contains('/report-cards/generate')) {
      return ApiResult.success(mapper({'status': 'SUCCESS'}));
    }
    return ApiResult.success(mapper({'status': 'SUCCESS'}));
  }
}

void main() {
  late MockPublishingApiClient fakeApi;
  late MockSessionManager fakeSession;

  setUp(() {
    fakeApi = MockPublishingApiClient();
    fakeSession = MockSessionManager();
  });

  Widget buildTestApp(Widget child, ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: child,
      ),
    );
  }

  testWidgets('Results Readiness card shows incomplete status and disabled publish button when results are incomplete', (tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    fakeApi.isExamComplete = false;
    fakeApi.isExamPublished = false;

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApi),
        sessionManagerProvider.overrideWithValue(fakeSession),
      ],
    );
    container.read(selectedSchoolIdProvider.notifier).state = 'school-123';

    await container.read(academicYearsProvider('school-123').notifier).fetchYears();
    await container.read(classesProvider('school-123').notifier).fetchClasses();
    await container.read(sectionsProvider('school-123').notifier).fetchSections();

    // Select examination
    container.read(resultsFiltersProvider.notifier).setExamination('exam-term1');

    await tester.pumpWidget(buildTestApp(const ResultsDashboardScreen(), container));
    await tester.pumpAndSettle();

    // Verify Result Readiness card renders
    expect(find.byKey(const Key('result_readiness_status_card')), findsOneWidget);
    expect(find.text('Results Readiness & Publication Status'), findsOneWidget);
    expect(find.text('INCOMPLETE DATA'), findsOneWidget);

    // Verify warning message explaining completion requirement
    expect(find.textContaining('30 students remain incomplete. Complete all required marks before publishing.'), findsWidgets);

    // Verify Publish Results button is disabled
    final publishBtnFinder = find.byKey(const Key('readiness_publish_results_btn'));
    expect(publishBtnFinder, findsOneWidget);
    final FilledButton publishBtn = tester.widget(publishBtnFinder);
    expect(publishBtn.onPressed, isNull);

    // Verify Resolve Missing Data button exists
    expect(find.byKey(const Key('readiness_resolve_missing_btn')), findsOneWidget);
  });

  testWidgets('Results Readiness allows publishing with confirmation dialog when results are complete', (tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    fakeApi.isExamComplete = true;
    fakeApi.isExamPublished = false;

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApi),
        sessionManagerProvider.overrideWithValue(fakeSession),
      ],
    );
    container.read(selectedSchoolIdProvider.notifier).state = 'school-123';

    await container.read(academicYearsProvider('school-123').notifier).fetchYears();
    await container.read(classesProvider('school-123').notifier).fetchClasses();
    await container.read(sectionsProvider('school-123').notifier).fetchSections();

    container.read(resultsFiltersProvider.notifier).setExamination('exam-term1');

    await tester.pumpWidget(buildTestApp(const ResultsDashboardScreen(), container));
    await tester.pumpAndSettle();

    // Status is now READY TO PUBLISH
    expect(find.text('READY TO PUBLISH'), findsOneWidget);
    expect(find.text('Complete Results'), findsWidgets);

    // Publish Results button is now enabled
    final publishBtnFinder = find.byKey(const Key('readiness_publish_results_btn'));
    expect(publishBtnFinder, findsOneWidget);
    final FilledButton publishBtn = tester.widget(publishBtnFinder);
    expect(publishBtn.onPressed, isNotNull);

    // Tap Publish Results button -> opens confirmation dialog
    await tester.tap(publishBtnFinder);
    await tester.pumpAndSettle();

    expect(find.text('Publish Examination Results'), findsOneWidget);
    expect(find.textContaining('Term 1 Summative Assessment'), findsWidgets);
    expect(find.textContaining('Publishing will immediately make these marks'), findsOneWidget);
    expect(find.byKey(const Key('confirm_publish_dialog_btn')), findsOneWidget);

    // Tap Confirm Publish
    await tester.tap(find.byKey(const Key('confirm_publish_dialog_btn')));
    await tester.pumpAndSettle();

    // API should now mark exam as published
    expect(fakeApi.isExamPublished, isTrue);
  });

  testWidgets('Published exam displays PUBLISHED badge, Last Published info, and Unpublish / Reopen button', (tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    fakeApi.isExamComplete = true;
    fakeApi.isExamPublished = true;

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApi),
        sessionManagerProvider.overrideWithValue(fakeSession),
      ],
    );
    container.read(selectedSchoolIdProvider.notifier).state = 'school-123';

    await container.read(academicYearsProvider('school-123').notifier).fetchYears();
    await container.read(classesProvider('school-123').notifier).fetchClasses();
    await container.read(sectionsProvider('school-123').notifier).fetchSections();

    container.read(resultsFiltersProvider.notifier).setExamination('exam-term1');

    await tester.pumpWidget(buildTestApp(const ResultsDashboardScreen(), container));
    await tester.pumpAndSettle();

    // Displays PUBLISHED badge
    expect(find.text('PUBLISHED'), findsWidgets);
    expect(find.textContaining('Principal Sharma'), findsOneWidget);
    expect(find.textContaining('Last Published'), findsOneWidget);

    // Displays View Published Results and Unpublish / Reopen
    expect(find.byKey(const Key('readiness_review_results_btn')), findsOneWidget);
    expect(find.byKey(const Key('readiness_unpublish_results_btn')), findsOneWidget);

    // Tap Unpublish -> confirmation dialog
    await tester.tap(find.byKey(const Key('readiness_unpublish_results_btn')));
    await tester.pumpAndSettle();

    expect(find.text('Unpublish Examination Results?'), findsOneWidget);
    expect(find.textContaining('revoke result visibility from Parent and Student portals'), findsOneWidget);
    expect(find.byKey(const Key('confirm_unpublish_dialog_btn')), findsOneWidget);

    // Confirm unpublish
    await tester.tap(find.byKey(const Key('confirm_unpublish_dialog_btn')));
    await tester.pumpAndSettle();

    expect(fakeApi.isExamPublished, isFalse);
  });

  testWidgets('Student Result Detail provides actionable buttons for validation errors and remarks dialog', (tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApi),
        sessionManagerProvider.overrideWithValue(fakeSession),
      ],
    );
    container.read(selectedSchoolIdProvider.notifier).state = 'school-123';

    await tester.pumpWidget(buildTestApp(const StudentResultDetailScreen(studentId: 'student-01'), container));
    await tester.pumpAndSettle();

    // Verify Action Required validation card
    expect(find.text('Incomplete or Invalid Report Card Data'), findsOneWidget);
    expect(find.text('Teacher remark not entered for final evaluation.'), findsOneWidget);
    expect(find.text('No examination schedules configured for Practical Paper.'), findsOneWidget);

    // Verify actionable buttons appear next to missing reasons
    expect(find.byKey(const Key('action_add_remark_btn')), findsOneWidget);
    expect(find.byKey(const Key('action_configure_exam_btn')), findsOneWidget);

    // Tap Add Remark -> opens dialog with suggestions and text area
    await tester.tap(find.byKey(const Key('action_add_remark_btn')));
    await tester.pumpAndSettle();

    expect(find.text('Quick Template Suggestions:'), findsOneWidget);
    expect(find.byKey(const Key('save_remark_and_regenerate_btn')), findsOneWidget);

    // Tap a template suggestion chip
    final chipFinder = find.byType(ActionChip).first;
    await tester.tap(chipFinder);
    await tester.pumpAndSettle();

    // Tap Save & Regenerate
    await tester.tap(find.byKey(const Key('save_remark_and_regenerate_btn')));
    await tester.pumpAndSettle();

    // Dialog closes
    expect(find.text('Quick Template Suggestions:'), findsNothing);
  });

  testWidgets('PredictiveAnalyticsView renders without overflow on 1024x768 and 1280x800', (tester) async {
    for (final size in [const Size(1024, 768), const Size(1280, 800), const Size(1920, 1080)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(fakeApi),
          sessionManagerProvider.overrideWithValue(fakeSession),
        ],
      );
      container.read(selectedSchoolIdProvider.notifier).state = 'school-123';

      await tester.pumpWidget(buildTestApp(
        const Scaffold(
          body: SingleChildScrollView(
            child: PredictiveAnalyticsView(
              initialClassId: 'class-10',
              initialAcademicYearId: 'ay-2026',
            ),
          ),
        ),
        container,
      ));
      await tester.pumpAndSettle();

      // No RenderFlex overflow
      expect(tester.takeException(), isNull);
      expect(find.text('Academic Predictive Intelligence'), findsOneWidget);
    }
    tester.view.resetPhysicalSize();
  });
}
