import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/school_setup/data/models/school_setup_models.dart';
import 'package:admin_portal/features/results/presentation/pages/report_card_management_screen.dart';
import 'package:admin_portal/features/results/presentation/providers/results_providers.dart';

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

class FakeReportCardApiClient extends BaseApiClient {
  bool simulateError = false;
  bool simulateFailure = false;
  bool pdfError = false;

  FakeReportCardApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (simulateError && path.contains('/students')) {
      return ApiResult.failure(const ApiFailure(message: 'Simulated API connection failure', type: ApiFailureType.unknown));
    }

    if (path.contains('/academic-years')) {
      return ApiResult.success(mapper({
        'data': [
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
        ]
      }));
    }

    if (path.contains('/classes')) {
      return ApiResult.success(mapper({
        'data': [
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
        ]
      }));
    }

    if (path.contains('/sections')) {
      return ApiResult.success(mapper({
        'data': [
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
        ]
      }));
    }

    if (path.contains('/examinations')) {
      return ApiResult.success(mapper({
        'data': [
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
        ]
      }));
    }

    if (path.contains('/students')) {
      return ApiResult.success(mapper({
        'data': [
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
            'id': 'st_3',
            'school_id': 'school_1',
            'tenant_id': 'tenant_1',
            'admission_number': 'ADM003',
            'roll_number': '3',
            'first_name': 'Chirag',
            'last_name': 'Patel',
            'gender': 'MALE',
            'date_of_birth': '2012-10-10',
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
            'id': 'st_4',
            'school_id': 'school_1',
            'tenant_id': 'tenant_1',
            'admission_number': 'ADM004',
            'roll_number': '4',
            'first_name': 'Divya',
            'last_name': 'Rao',
            'gender': 'FEMALE',
            'date_of_birth': '2012-03-22',
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
            'id': 'st_5',
            'school_id': 'school_1',
            'tenant_id': 'tenant_1',
            'admission_number': 'ADM005',
            'roll_number': '5',
            'first_name': 'Eshan',
            'last_name': 'Gupta',
            'gender': 'MALE',
            'date_of_birth': '2012-07-07',
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
            'id': 'st_6',
            'school_id': 'school_1',
            'tenant_id': 'tenant_1',
            'admission_number': 'ADM006',
            'roll_number': '6',
            'first_name': 'Fatima',
            'last_name': 'Sheikh',
            'gender': 'FEMALE',
            'date_of_birth': '2012-09-09',
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
        ]
      }));
    }

    if (path.contains('/report-cards/verify/')) {
      return ApiResult.success(mapper({
        'data': {
          'student_name': 'Aditi Sharma',
          'roll_number': '1',
          'class_name': 'Class 8',
          'section_name': 'Section A',
          'academic_year': '2026-2027',
          'status': 'published',
          'verification_date': '2026-08-14T12:00:00Z',
          'generated_at': '2026-08-14T10:00:00Z',
          'published_at': '2026-08-14T11:00:00Z',
          'pdf_url': '/static/report_cards/aditi.pdf',
        }
      }));
    }

    if (path.contains('/report-cards/download/')) {
      if (pdfError) {
        return ApiResult.failure(const ApiFailure(message: 'Simulated PDF generation timeout', type: ApiFailureType.unknown));
      }
      return ApiResult.success(mapper([37, 80, 68, 70, 45, 49, 46, 52]));
    }

    if (path.contains('/report-cards/preview/')) {
      return ApiResult.success(mapper({
        'data': {
          'student_id': 'st_1',
          'student_name': 'Aditi Sharma',
          'admission_number': 'ADM001',
          'roll_number': '1',
          'class_name': 'Class 8',
          'section_name': 'Section A',
          'attendance_total': 180,
          'attendance_present': 172,
          'attendance_percentage': 95.5,
          'overall_percentage': 89.2,
          'overall_grade': 'A',
          'promotion_status': 'PROMOTED',
          'subject_marks': [
            {
              'subject_name': 'Mathematics',
              'maximum_marks': 100,
              'marks_obtained': 92.0,
              'result_status': 'PASS',
              'grade': 'A',
              'remarks': 'Outstanding'
            }
          ],
          'teacher_remarks': 'Excellent performance in class.',
          'ai_narrative': 'A very analytical mind, excels in math.',
          'is_valid': true,
          'missing_reasons': []
        }
      }));
    }

    if (path.contains('/report-cards')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'card_1',
            'verification_uuid': 'uuid-12345',
            'status': 'DRAFT',
            'pdf_history': [],
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'student_id': 'st_1',
          },
          {
            'id': 'card_2',
            'verification_uuid': 'uuid-published',
            'status': 'PUBLISHED',
            'pdf_history': [],
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'student_id': 'st_2',
          },
          {
            'id': 'card_3',
            'verification_uuid': 'uuid-locked',
            'status': 'LOCKED',
            'pdf_history': [],
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'student_id': 'st_3',
          },
          {
            'id': 'card_4',
            'verification_uuid': 'uuid-under-review',
            'status': 'UNDER_REVIEW',
            'pdf_history': [],
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'student_id': 'st_4',
          },
          {
            'id': 'card_5',
            'verification_uuid': 'uuid-approved',
            'status': 'APPROVED',
            'pdf_history': [],
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'student_id': 'st_5',
          }
        ]
      }));
    }

    return ApiResult.failure(const ApiFailure(message: 'Endpoint not mocked', type: ApiFailureType.unknown));
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
    if (path.contains('/report-cards/generate/class')) {
      if (simulateFailure) {
        return ApiResult.success(mapper({
          'data': {
            'total_students': 6,
            'generated_count': 5,
            'failed_count': 1,
            'failures': [
              {
                'student_id': 'st_6',
                'student_name': 'Fatima Sheikh',
                'reasons': ['Missing final exam marks']
              }
            ]
          }
        }));
      }
      return ApiResult.success(mapper({
        'data': {
          'total_students': 6,
          'generated_count': 6,
          'failed_count': 0,
          'failures': []
        }
      }));
    }

    if (path.contains('/report-cards/generate')) {
      return ApiResult.success(mapper({
        'success': true,
        'message': 'Report card generated successfully',
        'data': {
          'id': 'new_card_id',
          'verification_uuid': 'new_verification_uuid',
          'status': 'DRAFT',
          'pdf_history': [],
          'tenant_id': 'tenant_1',
          'school_id': 'school_1',
          'academic_year_id': 'ay_1',
          'student_id': data['student_id'],
        }
      }));
    }

    if (path.contains('/submit-review')) {
      return ApiResult.success(mapper({
        'success': true,
        'message': 'Report card submitted for review',
        'data': {
          'status': 'UNDER_REVIEW',
        }
      }));
    }

    if (path.contains('/approve')) {
      return ApiResult.success(mapper({
        'success': true,
        'message': 'Report card approved',
        'data': {
          'status': 'APPROVED',
        }
      }));
    }

    if (path.contains('/publish')) {
      return ApiResult.success(mapper({
        'success': true,
        'message': 'Published successfully',
        'data': []
      }));
    }

    if (path.contains('/lock')) {
      return ApiResult.success(mapper({
        'success': true,
        'message': 'Report card locked',
        'data': {
          'status': 'LOCKED',
        }
      }));
    }

    if (path.contains('/unlock')) {
      return ApiResult.success(mapper({
        'success': true,
        'message': 'Report card unlocked',
        'data': {
          'status': 'DRAFT',
        }
      }));
    }

    return ApiResult.failure(const ApiFailure(message: 'Endpoint not mocked', type: ApiFailureType.unknown));
  }
}

void main() {
  late FakeReportCardApiClient fakeApiClient;

  setUp(() {
    fakeApiClient = FakeReportCardApiClient();
  });

  Widget createTestWidget(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: ReportCardManagementScreen(),
      ),
    );
  }

  Future<void> initSetup(ProviderContainer container) async {
    container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
    await container.read(academicYearsProvider('school_1').notifier).fetchYears();
    await container.read(classesProvider('school_1').notifier).fetchClasses();
    await container.read(sectionsProvider('school_1').notifier).fetchSections();
  }

  testWidgets('Report Card Management Screen renders successfully with filters', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        sessionManagerProvider.overrideWith((ref) => FakeTestSessionManager()),
      ],
    );
    await initSetup(container);

    await tester.pumpWidget(createTestWidget(container));
    await tester.pumpAndSettle();

    expect(find.text('Report Card Management'), findsOneWidget);
    expect(find.text('Select Class & Roster View'), findsOneWidget);
    expect(find.byKey(const Key('filter_academic_year')), findsOneWidget);
    expect(find.byKey(const Key('filter_class')), findsOneWidget);
    expect(find.byKey(const Key('filter_section')), findsOneWidget);
  });

  testWidgets('Lists students sorted numerically by roll number', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        sessionManagerProvider.overrideWith((ref) => FakeTestSessionManager()),
      ],
    );
    await initSetup(container);

    await tester.pumpWidget(createTestWidget(container));
    await tester.pumpAndSettle();

    expect(find.text('Aditi Sharma'), findsOneWidget);
    expect(find.text('Aarav Kumar'), findsOneWidget);
    expect(find.text('Chirag Patel'), findsOneWidget);

    final textWidgets = tester.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '').toList();
    final aditiIdx = textWidgets.indexOf('Aditi Sharma');
    final aaravIdx = textWidgets.indexOf('Aarav Kumar');
    
    if (aditiIdx != -1 && aaravIdx != -1) {
      expect(aditiIdx < aaravIdx, isTrue);
    }
  });

  testWidgets('Shows correct status badge for student report card state', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        sessionManagerProvider.overrideWith((ref) => FakeTestSessionManager()),
      ],
    );
    await initSetup(container);

    await tester.pumpWidget(createTestWidget(container));
    await tester.pumpAndSettle();

    expect(find.text('DRAFT'), findsOneWidget);
    expect(find.text('PUBLISHED'), findsOneWidget);
    expect(find.text('LOCKED'), findsOneWidget);
    expect(find.text('UNDER_REVIEW'), findsOneWidget);
    expect(find.text('APPROVED'), findsOneWidget);
    expect(find.text('NOT GENERATED'), findsOneWidget);
  });

  testWidgets('Bulk generate report cards triggers confirmation and executes successfully', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        sessionManagerProvider.overrideWith((ref) => FakeTestSessionManager()),
      ],
    );
    await initSetup(container);

    await tester.pumpWidget(createTestWidget(container));
    await tester.pumpAndSettle();

    final genButton = find.byKey(const Key('btn_bulk_generate'));
    expect(genButton, findsOneWidget);
    await tester.tap(genButton);
    await tester.pumpAndSettle();

    expect(find.text('Bulk Generate Report Cards'), findsOneWidget);
    final confirmBtn = find.text('Generate');
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    expect(find.text('Bulk Generation Result'), findsOneWidget);
    expect(find.text('Successfully Generated: 6'), findsOneWidget);
  });

  testWidgets('Bulk generate report cards failure lists failures dialog', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    fakeApiClient.simulateFailure = true;

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        sessionManagerProvider.overrideWith((ref) => FakeTestSessionManager()),
      ],
    );
    await initSetup(container);

    await tester.pumpWidget(createTestWidget(container));
    await tester.pumpAndSettle();

    final genButton = find.byKey(const Key('btn_bulk_generate'));
    await tester.tap(genButton);
    await tester.pumpAndSettle();

    final confirmBtn = find.text('Generate');
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    expect(find.text('Bulk Generation Result'), findsOneWidget);
    expect(find.text('Failed: 1'), findsOneWidget);
    expect(find.textContaining('Fatima Sheikh: Missing final exam marks'), findsOneWidget);
  });

  testWidgets('Renders action popups based on report card status correctly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        sessionManagerProvider.overrideWith((ref) => FakeTestSessionManager()),
      ],
    );
    await initSetup(container);

    await tester.pumpWidget(createTestWidget(container));
    await tester.pumpAndSettle();

    final draftMenu = find.byKey(const Key('actions_menu_st_1'));
    await tester.ensureVisible(draftMenu);
    await tester.pumpAndSettle();
    await tester.tap(draftMenu);
    await tester.pumpAndSettle();

    expect(find.text('Submit Review'), findsOneWidget);
    expect(find.text('Regenerate'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    final underReviewMenu = find.byKey(const Key('actions_menu_st_4'));
    await tester.ensureVisible(underReviewMenu);
    await tester.pumpAndSettle();
    await tester.tap(underReviewMenu);
    await tester.pumpAndSettle();

    expect(find.text('Approve'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    final approvedMenu = find.byKey(const Key('actions_menu_st_5'));
    await tester.ensureVisible(approvedMenu);
    await tester.pumpAndSettle();
    await tester.tap(approvedMenu);
    await tester.pumpAndSettle();

    expect(find.text('Publish'), findsOneWidget);
  });

  testWidgets('Allows download and signature verification lookup on published cards', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        sessionManagerProvider.overrideWith((ref) => FakeTestSessionManager()),
      ],
    );
    await initSetup(container);

    await tester.pumpWidget(createTestWidget(container));
    await tester.pumpAndSettle();

    final publishedMenu = find.byKey(const Key('actions_menu_st_2'));
    await tester.ensureVisible(publishedMenu);
    await tester.pumpAndSettle();
    await tester.tap(publishedMenu);
    await tester.pumpAndSettle();

    expect(find.text('Download PDF'), findsOneWidget);
    expect(find.text('Verify Signature'), findsOneWidget);

    await tester.tap(find.text('Verify Signature'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Signature Verification'), findsOneWidget);
    expect(find.text('✓ Digitally Signed & Authenticated'), findsOneWidget);
    expect(find.textContaining('Student: Aditi Sharma'), findsOneWidget);
  });

  testWidgets('Handles PDF download API failures gracefully with error SnackBar', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    fakeApiClient.pdfError = true;

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        sessionManagerProvider.overrideWith((ref) => FakeTestSessionManager()),
      ],
    );
    await initSetup(container);

    await tester.pumpWidget(createTestWidget(container));
    await tester.pumpAndSettle();

    final publishedMenu = find.byKey(const Key('actions_menu_st_2'));
    await tester.ensureVisible(publishedMenu);
    await tester.pumpAndSettle();
    await tester.tap(publishedMenu);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Download PDF'));
    await tester.pumpAndSettle();

    expect(find.text('Simulated PDF generation timeout'), findsOneWidget);
  });

  testWidgets('Empty state and connection error state renders retry button', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    fakeApiClient.simulateError = true;

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        sessionManagerProvider.overrideWith((ref) => FakeTestSessionManager()),
      ],
    );
    container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
    await container.read(academicYearsProvider('school_1').notifier).fetchYears();
    await container.read(classesProvider('school_1').notifier).fetchClasses();
    await container.read(sectionsProvider('school_1').notifier).fetchSections();

    await tester.pumpWidget(createTestWidget(container));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
  });

  group('Report Card Dropdown Assertion and Lifecycle Tests', () {
    late FakeReportCardApiClient localFakeApiClient;

    setUp(() {
      localFakeApiClient = FakeReportCardApiClient();
    });

    test('TEST 1: Academic year change clears class, section and examination', () {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(localFakeApiClient),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(resultsFiltersProvider.notifier);
      
      notifier.setAcademicYear('ay_2025');
      notifier.setClass('class_1');
      notifier.setSection('section_1');
      notifier.setExamination('exam_1');

      expect(container.read(resultsFiltersProvider).academicYearId, 'ay_2025');
      expect(container.read(resultsFiltersProvider).classId, 'class_1');
      expect(container.read(resultsFiltersProvider).sectionId, 'section_1');
      expect(container.read(resultsFiltersProvider).examinationId, 'exam_1');

      // Change academic year
      notifier.setAcademicYear('ay_2026');
      
      final state = container.read(resultsFiltersProvider);
      expect(state.academicYearId, 'ay_2026');
      expect(state.classId, isNull);
      expect(state.sectionId, isNull);
      expect(state.examinationId, isNull);
    });

    test('TEST 2: Class change clears section', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(resultsFiltersProvider.notifier);
      
      notifier.setClass('class_1');
      notifier.setSection('section_1');

      expect(container.read(resultsFiltersProvider).classId, 'class_1');
      expect(container.read(resultsFiltersProvider).sectionId, 'section_1');

      // Change class
      notifier.setClass('class_2');
      
      final state = container.read(resultsFiltersProvider);
      expect(state.classId, 'class_2');
      expect(state.sectionId, isNull);
    });

    test('TEST 3: School change clears all result filters', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(resultsFiltersProvider.notifier);
      
      notifier.setAcademicYear('ay_2025');
      notifier.setClass('class_1');
      notifier.setSection('section_1');
      notifier.setExamination('exam_1');

      // Change school context
      container.read(selectedSchoolIdProvider.notifier).state = 'school_2';
      
      final state = container.read(resultsFiltersProvider);
      expect(state.academicYearId, isNull);
      expect(state.classId, isNull);
      expect(state.sectionId, isNull);
      expect(state.examinationId, isNull);
    });

    testWidgets('TEST 4, 5, 6, 8, 12: Stale dropdown IDs resolve to null or remain selected', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(localFakeApiClient),
          sessionManagerProvider.overrideWith((ref) => FakeTestSessionManager()),
        ],
      );
      addTearDown(container.dispose);

      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

      // Set stale IDs initially in filter state
      final filterNotifier = container.read(resultsFiltersProvider.notifier);
      filterNotifier.setAcademicYear('stale_ay_id');
      filterNotifier.setClass('stale_class_id');
      filterNotifier.setSection('stale_section_id');

      // Render the widget - should not crash and should resolve to fallback defaults
      await tester.pumpWidget(createTestWidget(container));
      await tester.pumpAndSettle();

      // State is fallback-populated because the lists loaded successfully
      expect(container.read(resultsFiltersProvider).academicYearId, 'ay_1');
      expect(container.read(resultsFiltersProvider).classId, 'class_1');
      expect(container.read(resultsFiltersProvider).sectionId, 'section_1');

      // Now override states to be empty and check cleanup to null
      container.read(academicYearsProvider('school_1').notifier).state = const AcademicYearsState(years: [], isLoading: false);
      container.read(classesProvider('school_1').notifier).state = const ClassesState(classes: [], isLoading: false);
      container.read(sectionsProvider('school_1').notifier).state = const SectionsState(sections: [], isLoading: false);

      filterNotifier.setAcademicYear('stale_ay_id');
      filterNotifier.setClass('stale_class_id');
      filterNotifier.setSection('stale_section_id');

      await tester.pumpAndSettle();

      // Since lists are empty, they resolve and cleanup to null!
      expect(container.read(resultsFiltersProvider).academicYearId, isNull);
      expect(container.read(resultsFiltersProvider).classId, isNull);
      expect(container.read(resultsFiltersProvider).sectionId, isNull);

      // Verify no DropdownButtonFormField asserts on invalid values
      expect(find.byType(ReportCardManagementScreen), findsOneWidget);
    });

    testWidgets('TEST 7: Duplicate dropdown values are removed', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Override the classes provider to return duplicates
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(localFakeApiClient),
          sessionManagerProvider.overrideWith((ref) => FakeTestSessionManager()),
          classesProvider('school_1').overrideWith((ref) {
            final notifier = ClassesNotifier(localFakeApiClient, 'school_1');
            notifier.state = const ClassesState(
              classes: [
                ClassDto(
                  id: 'class_1',
                  tenantId: 'tenant_1',
                  schoolId: 'school_1',
                  academicYearId: 'ay_1',
                  name: 'Class 8',
                  code: 'CLASS_8',
                  level: 8,
                  category: 'HIGH',
                  capacity: 40,
                  status: 'ACTIVE',
                  isActive: true,
                  version: 1,
                ),
                ClassDto(
                  id: 'class_1', // DUPLICATE ID
                  tenantId: 'tenant_1',
                  schoolId: 'school_1',
                  academicYearId: 'ay_1',
                  name: 'Class 8 (Duplicate)',
                  code: 'CLASS_8_DUP',
                  level: 8,
                  category: 'HIGH',
                  capacity: 40,
                  status: 'ACTIVE',
                  isActive: true,
                  version: 1,
                ),
              ],
              isLoading: false,
            );
            return notifier;
          }),
        ],
      );
      addTearDown(container.dispose);

      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      await container.read(academicYearsProvider('school_1').notifier).fetchYears();
      await container.read(sectionsProvider('school_1').notifier).fetchSections();

      // Render the widget - should not crash because duplicates are removed
      await tester.pumpWidget(createTestWidget(container));
      await tester.pumpAndSettle();

      expect(find.byType(ReportCardManagementScreen), findsOneWidget);
    });

    testWidgets('TEST 9: School A -> School B transition does not crash', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(localFakeApiClient),
          sessionManagerProvider.overrideWith((ref) => FakeTestSessionManager()),
        ],
      );
      addTearDown(container.dispose);

      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      await container.read(academicYearsProvider('school_1').notifier).fetchYears();
      await container.read(classesProvider('school_1').notifier).fetchClasses();
      await container.read(sectionsProvider('school_1').notifier).fetchSections();

      await tester.pumpWidget(createTestWidget(container));
      await tester.pumpAndSettle();

      // Select Class 1
      container.read(resultsFiltersProvider.notifier).setClass('class_1');
      await tester.pumpAndSettle();

      // Transition to School B
      container.read(selectedSchoolIdProvider.notifier).state = 'school_2';
      await tester.pumpAndSettle();

      // Should not crash, and all filters reset to null
      final state = container.read(resultsFiltersProvider);
      expect(state.academicYearId, isNull);
      expect(state.classId, isNull);
      expect(state.sectionId, isNull);
    });

    test('TEST 10: Class 1 -> Class 2 transition clears old section', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final filterNotifier = container.read(resultsFiltersProvider.notifier);
      filterNotifier.setClass('class_1');
      filterNotifier.setSection('section_1');

      expect(container.read(resultsFiltersProvider).classId, 'class_1');
      expect(container.read(resultsFiltersProvider).sectionId, 'section_1');

      // Change class to Class 2
      filterNotifier.setClass('class_2');
      
      final state = container.read(resultsFiltersProvider);
      expect(state.classId, 'class_2');
      expect(state.sectionId, isNull);
    });

    test('TEST 11: Academic Year 2025-26 -> 2026-27 clears dependent state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final filterNotifier = container.read(resultsFiltersProvider.notifier);
      filterNotifier.setAcademicYear('ay_2025');
      filterNotifier.setClass('class_1');
      filterNotifier.setSection('section_1');
      filterNotifier.setExamination('exam_1');

      // Change academic year
      filterNotifier.setAcademicYear('ay_2026');

      final state = container.read(resultsFiltersProvider);
      expect(state.academicYearId, 'ay_2026');
      expect(state.classId, isNull);
      expect(state.sectionId, isNull);
      expect(state.examinationId, isNull);
    });
  });
}
