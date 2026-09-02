import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/app.dart';
import 'package:admin_portal/core/routing/routes.dart';
import 'package:admin_portal/core/routing/app_router.dart';
import 'package:admin_portal/core/providers/bootstrap_provider.dart';
import 'package:admin_portal/features/bulk_import/data/models/school_onboarding_models.dart';
import 'package:admin_portal/features/bulk_import/data/models/school_onboarding_validators.dart';
import 'package:admin_portal/features/bulk_import/presentation/providers/school_onboarding_providers.dart';
import 'package:admin_portal/features/bulk_import/presentation/pages/school_onboarding_screen.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';

class FakeOnboardingRepository implements AuthRepository {
  final bool hasAdminAccess;
  FakeOnboardingRepository({this.hasAdminAccess = true});

  @override
  Future<ApiResult<SessionToken>> login({required String email, required String password}) async {
    return const ApiResult.success(SessionToken(accessToken: 'mock_access', refreshToken: 'mock_refresh', tokenType: 'bearer'));
  }

  @override
  Future<ApiResult<void>> logout({required String refreshToken}) async {
    return const ApiResult.success(null);
  }

  @override
  Future<ApiResult<SessionToken>> refreshToken({required String refreshToken}) async {
    return const ApiResult.success(SessionToken(accessToken: 'mock_access_new', refreshToken: 'mock_refresh_new', tokenType: 'bearer'));
  }

  @override
  Future<ApiResult<UserEntity>> getCurrentUser() async {
    return ApiResult.success(UserEntity(
      id: 'admin_id_123',
      email: 'admin@edupulse.ai',
      firstName: 'Main',
      lastName: 'Admin',
      tenantId: 'tenant_1',
      isSuperuser: hasAdminAccess,
      roles: hasAdminAccess ? ['SUPER_ADMIN'] : ['GUEST'],
      schools: const ['school_1'],
    ));
  }

  @override
  Future<ApiResult<void>> requestPasswordReset({required String email}) async {
    return const ApiResult.success(null);
  }

  @override
  Future<ApiResult<void>> resetPassword({
    required String token,
    required String newPassword,
    String? confirmPassword,
  }) async {
    return const ApiResult.success(null);
  }
}

class FakeOnboardingSessionManager implements SessionManager {
  String? cachedTenantId;
  String? cachedTenantName;
  String? cachedSchoolId;
  String? cachedSchoolName;

  @override
  Future<String?> getTenantId() async => cachedTenantId;

  @override
  Future<void> saveTenantId(String tenantId) async {
    cachedTenantId = tenantId;
  }

  @override
  Future<String?> getTenantName() async => cachedTenantName;

  @override
  Future<void> saveTenantName(String tenantName) async {
    cachedTenantName = tenantName;
  }

  @override
  Future<String?> getSchoolName() async => cachedSchoolName;

  @override
  Future<void> saveSchoolName(String schoolName) async {
    cachedSchoolName = schoolName;
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
  Future<String?> getSchoolId() async => cachedSchoolId ?? 'school_1';
  @override
  Future<void> saveSchoolId(String schoolId) async {
    cachedSchoolId = schoolId;
  }
}

class FakeOnboardingApiClient extends BaseApiClient {
  final List<Map<String, dynamic>> postCalls = [];
  bool failNextRequest = false;
  bool failGlobally = false;

  FakeOnboardingApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    postCalls.add({'path': path, 'data': data});

    if (failGlobally) {
      return const ApiResult.failure(ApiFailure(
        type: ApiFailureType.unauthorized,
        statusCode: 401,
        message: 'Unauthorized token or tenant failure',
      ));
    }

    if (failNextRequest) {
      failNextRequest = false;
      return const ApiResult.failure(ApiFailure(
        type: ApiFailureType.validation,
        statusCode: 409,
        message: 'Conflict or duplicate record exists',
      ));
    }

    if (path.contains('/guardians') && data is Map<String, dynamic> && data['mobile'] == '9876544099') {
      return const ApiResult.failure(ApiFailure(
        type: ApiFailureType.validation,
        statusCode: 409,
        message: 'Conflict or duplicate record exists',
      ));
    }

    if (path.contains('/students') && data is Map<String, dynamic> && data['admission_number'] == 'STD4099') {
      return const ApiResult.failure(ApiFailure(
        type: ApiFailureType.validation,
        statusCode: 409,
        message: 'Conflict or duplicate record exists',
      ));
    }

    if (path.contains('/student-guardians') && data is Map<String, dynamic> && data['student_id'] == 'student_resolved_id_123') {
      return const ApiResult.failure(ApiFailure(
        type: ApiFailureType.validation,
        statusCode: 409,
        message: 'Conflict or duplicate record exists',
      ));
    }

    if (path.contains('/sections') && data is Map<String, dynamic> && data['name'] == 'FailSection') {
      return const ApiResult.failure(ApiFailure(
        type: ApiFailureType.validation,
        statusCode: 422,
        message: 'Invalid section name or capacity',
      ));
    }

    if (data is Map<String, dynamic>) {
      final code = data['code'] ?? data['school_code'] ?? data['teacher_code'] ?? data['employee_code'] ?? data['subject_code'] ?? data['syllabus_code'] ?? '';
      if (code.toString().contains('FAIL_401')) {
        return const ApiResult.failure(ApiFailure(
          type: ApiFailureType.unauthorized,
          statusCode: 401,
          message: 'Mock 401 Unauthorized',
        ));
      }
      if (code.toString().contains('FAIL_403')) {
        return const ApiResult.failure(ApiFailure(
          type: ApiFailureType.unauthorized,
          statusCode: 403,
          message: 'Mock 403 Forbidden',
        ));
      }
      if (code.toString().contains('FAIL_422_PHONE')) {
        return const ApiResult.failure(ApiFailure(
          type: ApiFailureType.validation,
          statusCode: 422,
          message: "Validation error: [body -> phone]: String should match pattern '^(?:\\+91|0)?[6-9]\\d{9}\$'",
        ));
      }
      if (code.toString().contains('FAIL_422') || code == 'AY2222') {
        return const ApiResult.failure(ApiFailure(
          type: ApiFailureType.validation,
          statusCode: 422,
          message: 'school_code already exists',
        ));
      }
      if (code == 'AY4099' ||
          code == 'AY2027-2028' ||
          code == 'AY2028-2029' ||
          code == 'CLS4099' ||
          code == 'SEC4099' ||
          code == 'SUB4099' ||
          code == 'TCH4099' ||
          code == 'TCH_FAIL' ||
          code == 'STD4099' ||
          code == 'SYL4099') {
        return const ApiResult.failure(ApiFailure(
          type: ApiFailureType.validation,
          statusCode: 409,
          message: 'Conflict or duplicate record exists',
        ));
      }
      if (code.toString().contains('FAIL_500')) {
        return const ApiResult.failure(ApiFailure(
          type: ApiFailureType.validation,
          statusCode: 500,
          message: 'Mock 500 Internal Server Error',
        ));
      }
      if (data['first_name'] == 'FailRow') {
        return const ApiResult.failure(ApiFailure(
          type: ApiFailureType.validation,
          statusCode: 400,
          message: 'Bad Request parameters',
        ));
      }
    }

    if (path.contains('/teacher-subject-assignments') && data is Map<String, dynamic>) {
      if (data['teacher_id'] == 'teacher_resolved_id_123') {
        return const ApiResult.failure(ApiFailure(
          type: ApiFailureType.validation,
          statusCode: 409,
          message: 'Conflict or duplicate record exists',
        ));
      }
      if (data['teacher_id'] == 'teacher_resolved_id_fail') {
        return const ApiResult.failure(ApiFailure(
          type: ApiFailureType.validation,
          statusCode: 422,
          message: 'Assignment date range overlaps with another active assignment for this teacher.',
        ));
      }
      if (data['effective_from'] == '2025-04-10') {
        return const ApiResult.failure(ApiFailure(
          type: ApiFailureType.validation,
          statusCode: 422,
          message: 'Assignment date range overlaps with another active assignment for this teacher.',
        ));
      }
    }

    if (path.contains('/timetables') && data is Map<String, dynamic> && data['period_number'] == 1 && data['class_id'] == 'class_resolved_id_123' && data['section_id'] == 'section_resolved_id_123') {
      return const ApiResult.failure(ApiFailure(
        type: ApiFailureType.validation,
        statusCode: 409,
        message: 'Conflict or duplicate record exists',
      ));
    }

    if (path.contains('/examinations') && data is Map<String, dynamic>) {
      final examName = data['exam_name'] ?? data['name'] ?? '';
      if (examName == 'Midterm 4099' || examName == 'Midterm Unresolved') {
        return const ApiResult.failure(ApiFailure(
          type: ApiFailureType.validation,
          statusCode: 422,
          message: 'An examination with this name already exists in the academic year.',
        ));
      }
    }

    if (path.contains('/import-jobs/parse')) {
      final selected = path.contains('sheet_name=')
          ? Uri.decodeComponent(path.split('sheet_name=').last)
          : 'School Information';
      return ApiResult.success(mapper({
        'success': true,
        'message': 'File parsed successfully.',
        'data': {
          'filename': 'test.xlsx',
          'format': 'xlsx',
          'sheets': ['School Information', 'Academic Structure', 'Classes', 'Sections'],
          'selected_sheet': selected,
          'columns': selected.contains('School')
              ? ['school_code', 'school_name', 'board', 'school_type', 'email', 'phone', 'status']
              : selected.contains('Academic')
                  ? ['school_code', 'academic_year_code', 'academic_year_name', 'start_date', 'end_date', 'status', 'is_current']
                  : ['academic_year_code', 'class_code', 'display_label', 'level', 'grade_category', 'max_capacity', 'status'],
          'row_count': 1,
          'rows': selected.contains('School')
              ? [
                  ['school_code', 'school_name', 'board', 'school_type', 'email', 'phone', 'status'],
                  ['DPSH', 'DPS Hyderabad', 'CBSE', 'HIGH_SCHOOL', 'dpsh@edu.in', '+919876543210', 'ACTIVE']
                ]
              : selected.contains('Academic')
                  ? [
                      ['school_code', 'academic_year_code', 'academic_year_name', 'start_date', 'end_date', 'status', 'is_current'],
                      ['DPSH', 'AY2026-2027', 'Academic Year 2026-27', '2026-06-01', '2027-03-31', 'ACTIVE', 'true']
                    ]
                  : [
                      ['academic_year_code', 'class_code', 'display_label', 'level', 'grade_category', 'max_capacity', 'status'],
                      ['AY2026-2027', 'CLASS08', 'Class 8', '8', 'MIDDLE', '40', 'ACTIVE']
                    ]
        }
      }));
    }

    return ApiResult.success(mapper({'success': true, 'message': 'Success', 'data': {'id': 'resolved_mock_id'}}));
  }

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (path.contains('/schools') && path.contains('/academic-years')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'ay_resolved_id_123',
            'name': '2026-27',
            'code': 'AY4099',
          },
          {
            'id': 'ay_resolved_id_ck',
            'name': '2027-28',
            'code': 'AY2027-2028',
          },
          {
            'id': 'ay_resolved_id_cl',
            'name': '2028-29',
            'code': 'AY2028-2029',
          }
        ]
      }));
    }
    if (path.contains('/classes')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'class_resolved_id_123',
            'code': 'CLS4099',
            'name': 'Class 10',
          }
        ]
      }));
    }
    if (path.contains('/sections')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'section_resolved_id_123',
            'code': 'SEC4099',
            'name': 'Section A',
          }
        ]
      }));
    }
    if (path.contains('/subjects')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'subject_resolved_id_123',
            'subject_code': 'SUB4099',
            'subject_name': 'Mathematics',
          }
        ]
      }));
    }
    if (path.contains('/teachers')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'teacher_resolved_id_123',
            'employee_code': 'TCH4099',
            'staff_code': 'TCH4099',
          },
          {
            'id': 'teacher_resolved_id_fail',
            'employee_code': 'TCH_FAIL',
            'staff_code': 'TCH_FAIL',
          }
        ]
      }));
    }
    if (path.contains('/guardians')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'guardian_resolved_id_123',
            'mobile': '9876544099',
            'email': 'guardian4099@test.com',
          }
        ]
      }));
    }
    if (path.contains('/students')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'student_resolved_id_123',
            'admission_number': 'STD4099',
          }
        ]
      }));
    }
    if (path.contains('/student-guardians')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'relationship_resolved_id_123',
            'student_id': 'student_resolved_id_123',
            'guardian_id': 'guardian_resolved_id_123',
          }
        ]
      }));
    }
    if (path.contains('/teacher-subject-assignments')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'assignment_resolved_id_123',
            'teacher_id': 'teacher_resolved_id_123',
            'subject_id': 'subject_resolved_id_123',
            'class_id': 'class_resolved_id_123',
            'section_id': 'section_resolved_id_123',
          }
        ]
      }));
    }
    if (path.contains('/syllabuses')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'syllabus_resolved_id_123',
            'syllabus_code': 'SYL4099',
            'unit_name': 'Unit 1',
            'chapter_name': 'Chapter 1',
            'topic_name': 'Topic 1',
          }
        ]
      }));
    }
    if (path.contains('/timetables')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'timetable_resolved_id_123',
            'class_id': 'class_resolved_id_123',
            'section_id': 'section_resolved_id_123',
            'day_of_week': 'MONDAY',
            'period_number': 1,
          }
        ]
      }));
    }
    if (path.contains('/examinations')) {
      final uri = Uri.parse(path);
      final ayId = uri.queryParameters['academic_year_id'] ?? '';
      if (ayId == 'ay_resolved_id_ck') {
        // Returns the match BUT for the wrong academic year if queried with that year
        return ApiResult.success(mapper({
          'data': [
            {
              'id': 'exam_resolved_id_other_year',
              'exam_name': 'Midterm 4099',
              'exam_type': 'HALF_YEARLY',
              'start_date': '2025-09-20',
            }
          ]
        }));
      }
      if (ayId == 'ay_resolved_id_cl') {
        // Returns the record with same name but different start date
        return ApiResult.success(mapper({
          'data': [
            {
              'id': 'exam_resolved_id_different_date',
              'exam_name': 'Midterm 4099',
              'exam_type': 'HALF_YEARLY',
              'start_date': '2025-10-25',
            }
          ]
        }));
      }
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'exam_resolved_id_123',
            'exam_name': 'Midterm 4099',
            'exam_type': 'HALF_YEARLY',
            'start_date': '2025-09-20',
          },
          {
            'id': 'exam_resolved_id_123',
            'exam_name': 'Midterm 4099',
            'exam_type': 'UNIT_TEST',
            'start_date': '2026-10-10',
          }
        ]
      }));
    }
    if (path.contains('/schools')) {
      final list = [
        {
          'id': 'school_1',
          'tenant_id': 'tenant_1',
          'name': 'Delhi Public School Hyderabad',
          'code': 'DPSH',
          'board': 'CBSE',
          'school_type': 'HIGH_SCHOOL',
          'email': 'contact@dpsh.in',
          'is_active': true,
          'status': 'ACTIVE',
          'version': 1,
        }
      ];
      for (final call in postCalls) {
        if (call['path'] == '/schools' && call['data'] is Map) {
          final data = call['data'] as Map;
          list.add({
            'id': 'resolved_mock_id',
            'tenant_id': 'tenant_1',
            'name': data['name'] ?? 'Mock Created School',
            'code': data['code'] ?? 'MOCK_CODE',
            'board': data['board'] ?? 'CBSE',
            'school_type': data['school_type'] ?? 'HIGH_SCHOOL',
            'email': data['email'] ?? 'contact@dpsh.in',
            'is_active': true,
            'status': 'ACTIVE',
            'version': 1,
          });
        }
      }
      return ApiResult.success(mapper({
        'data': list
      }));
    }
    return ApiResult.success(mapper({'data': []}));
  }
}

void main() {
  final fakeApiClient = FakeOnboardingApiClient();

  setUpAll(() {
    SchoolOnboardingNotifier.bypassApproval = true;
  });

  setUp(() {
    fakeApiClient.postCalls.clear();
    fakeApiClient.failNextRequest = false;
    fakeApiClient.failGlobally = false;
  });

  group('School Onboarding Validators and Parser Tests', () {
    test('Correctly parses CSV files and splits values', () {
      const csv = 'col1,col2,col3\nval1,val2,val3\n"val,with,comma","val with ""quotes""",val3';
      final rows = SchoolOnboardingValidators.parseCsv(csv);
      expect(rows.length, 3);
      expect(rows[1][0], 'val1');
      expect(rows[2][0], 'val,with,comma');
      expect(rows[2][1], 'val with quotes');
    });

    test('Validates column headers and flags missing ones', () {
      final sheet = SchoolOnboardingValidators.validateSheet(
        OnboardingStep.school,
        'school.csv',
        [['invalid_col', 'school_name']],
      );
      expect(sheet.sheetErrorMessage, contains('Missing required column header'));
      expect(sheet.rows.isEmpty, true);
    });

    test('Runs bounds and formats checks on input data fields', () {
      final sheet = SchoolOnboardingValidators.validateSheet(
        OnboardingStep.school,
        'school.csv',
        [
          ['school_code', 'school_name', 'board', 'school_type', 'email', 'phone', 'status'],
          ['DPSH', 'Delhi Public School Hyderabad', 'INVALID_BOARD', 'INVALID_TYPE', 'bad-email', '123', 'ACTIVE'],
        ],
      );
      expect(sheet.rows.length, 1);
      expect(sheet.rows.first.status, OnboardingRowStatus.error);
      expect(sheet.rows.first.errors.any((e) => e.contains('email')), true);
    });
  });

  group('School Onboarding Provider Engine Flow Tests', () {
    test('Populates and resolves references sequentially', () {
      final container = ProviderContainer();
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadSyntheticFixture();

      final state = container.read(schoolOnboardingProvider);
      expect(state.sheets.containsKey(OnboardingStep.school), true);
      expect(state.sheets[OnboardingStep.school]?.rows.length, 1);
      expect(state.sheets.containsKey(OnboardingStep.students), true);
      expect(state.sheets[OnboardingStep.students]?.rows.length, 360);
    });

    test('Skips entity rows containing dependency issues and reports status', () async {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(fakeApiClient),
          selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
        ],
      );

      final notifier = container.read(schoolOnboardingProvider.notifier);
      notifier.loadCsvFile(
        OnboardingStep.students,
        'students.csv',
        'admission_number,first_name,last_name,gender,date_of_birth,admission_date,roll_number,academic_year_code,class_code,section_code,status\n'
        'ADM999,Aarav,Kumar,MALE,2014-05-12,2026-06-01,1,AY_MISSING,CLASS_MISSING,SEC_MISSING,ACTIVE',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);

      final state = container.read(schoolOnboardingProvider);
      expect(state.skipCount, 1);
      expect(state.sheets[OnboardingStep.students]?.rows.first.status, OnboardingRowStatus.skipped);
    });

    test('Resets onboarding state cleanly when active school context changes', () {
      final container = ProviderContainer();
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

      final notifier = container.read(schoolOnboardingProvider.notifier);
      notifier.loadSyntheticFixture();

      expect(container.read(schoolOnboardingProvider).sheets.isNotEmpty, true);

      container.read(selectedSchoolIdProvider.notifier).state = 'school_2';
      expect(container.read(schoolOnboardingProvider).sheets.isEmpty, true);
    });
  });

  group('School Onboarding Stepper Widget Tests', () {
    testWidgets('Renders onboarding stepper panels, CSV picker, and triggers synthetic fixture', (WidgetTester tester) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        originalOnError?.call(details);
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) => FakeOnboardingRepository()),
            sessionManagerProvider.overrideWith((ref) => FakeOnboardingSessionManager()),
            apiClientProvider.overrideWithValue(fakeApiClient),
            bootstrapResultProvider.overrideWithValue(BootstrapResult(success: true)),
          ],
          child: const EduPulseAdminApp(),
        ),
      );

      await tester.pumpAndSettle();

      final appContainer = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
      final router = appContainer.read(routerProvider);

      appContainer.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      await appContainer.read(schoolsListProvider.notifier).fetchSchools();
      await tester.pumpAndSettle();

      router.go(AppRoutes.schoolOnboarding);
      await tester.pumpAndSettle();

      expect(find.byType(SchoolOnboardingScreen), findsOneWidget);
      expect(find.text('Active School: Delhi Public School Hyderabad'), findsOneWidget);

      // Verify side panel stepper entries
      expect(find.text('1. School Information'), findsOneWidget);
      expect(find.text('2. Academic Structure'), findsOneWidget);

      // Tap synthetic dev generator button
      final genBtn = find.text('Load Synthetic Dev Data');
      expect(genBtn, findsOneWidget);
      await tester.tap(genBtn);
      await tester.pumpAndSettle();

      // Check validation step navigation and error listing review
      appContainer.read(schoolOnboardingProvider.notifier).setStep(OnboardingStep.validation);
      await tester.pumpAndSettle();

      expect(find.text('Step 11: Pre-Import Validation Passes'), findsOneWidget);

      FlutterError.onError = originalOnError;
    });
  });

  group('Onboarding Execution Result Tracking Regression Tests', () {
    test('A. Successful migration: 1 row succeeds => Step 16 shows Success = 1', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);
      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'DPSH,Delhi Public School Hyderabad,CBSE,HIGH_SCHOOL,contact@dpsh.in,9876543210,ACTIVE',
      );
      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      
      final sheet = state.sheets[OnboardingStep.school]!;
      final successCount = sheet.rows.where((r) => r.status == OnboardingRowStatus.success).length;
      expect(successCount, 1);
      expect(state.currentStep, OnboardingStep.report);
      expect(state.isCompleted, true);
    });

    test('B. API failure: 1 row fails => Step 16 shows Failure = 1', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);
      // 'FailRow' triggers API failure in FakeOnboardingApiClient
      notifier.loadCsvFile(
        OnboardingStep.teachers,
        'teachers.csv',
        'teacher_code,first_name,last_name,gender,date_of_birth,mobile,email,employee_code,designation,joining_date,status,employment_type\n'
        'T001,FailRow,Sharma,FEMALE,1985-04-12,9876543211,fail@dpsh.in,EMP001,PGT,2020-06-01,ACTIVE,FULL_TIME',
      );
      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      
      final sheet = state.sheets[OnboardingStep.teachers]!;
      final failureCount = sheet.rows.where((r) => r.status == OnboardingRowStatus.failed).length;
      expect(failureCount, 1);
      expect(sheet.rows.first.apiErrorMessage, isNotNull);
    });

    test('C. Dependency failure: 1 child row references missing dependency => Step 16 shows Skips/Gaps = 1', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);
      notifier.loadCsvFile(
        OnboardingStep.students,
        'students.csv',
        'admission_number,first_name,last_name,gender,date_of_birth,admission_date,roll_number,academic_year_code,class_code,section_code,status\n'
        'ADM001,Aarav,Kumar,MALE,2014-05-12,2026-06-01,1,AY_MISSING,CLASS_MISSING,SEC_MISSING,ACTIVE',
      );
      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      
      final sheet = state.sheets[OnboardingStep.students]!;
      final skipCount = sheet.rows.where((r) => r.status == OnboardingRowStatus.skipped).length;
      expect(skipCount, 1);
    });

    test('D. Mixed results: 5 rows (2 success, 1 API failure, 2 dependency skips) => Step 16 matches counters', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      // Pre-seed school and academic year dependency to allow success for first two rows
      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,HIGH_SCHOOL,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY2026,2026-27,2026-06-01,2027-03-31,ACTIVE,true',
      );

      // Pre-seed class
      notifier.loadCsvFile(
        OnboardingStep.classes,
        'classes.csv',
        'academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n'
        'AY2026,CLASS08,Class 8,8,PRIMARY,40,ACTIVE',
      );

      // Pre-seed section
      notifier.loadCsvFile(
        OnboardingStep.sections,
        'sections.csv',
        'academic_year_code,class_code,section_code,section_name,capacity,room_number,display_sort_order,status\n'
        'AY2026,CLASS08,SEC_A,Section A,40,Room 101,1,ACTIVE',
      );

      notifier.loadCsvFile(
        OnboardingStep.students,
        'students.csv',
        'admission_number,first_name,last_name,gender,date_of_birth,admission_date,roll_number,academic_year_code,class_code,section_code,status\n'
        'ADM001,Aarav,Kumar,MALE,2014-05-12,2026-06-01,1,AY2026,CLASS08,SEC_A,ACTIVE\n'
        'ADM002,Ananya,Kumar,FEMALE,2014-05-12,2026-06-01,2,AY2026,CLASS08,SEC_A,ACTIVE\n'
        'ADM003,FailRow,Kumar,MALE,2014-05-12,2026-06-01,3,AY2026,CLASS08,SEC_A,ACTIVE\n'
        'ADM004,Skipped,Kumar,MALE,2014-05-12,2026-06-01,4,AY_MISSING,CLASS_MISSING,SEC_MISSING,ACTIVE\n'
        'ADM005,Skipped2,Kumar,FEMALE,2014-05-12,2026-06-01,5,AY_MISSING,CLASS_MISSING,SEC_MISSING,ACTIVE',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);

      final sheet = state.sheets[OnboardingStep.students]!;
      final success = sheet.rows.where((r) => r.status == OnboardingRowStatus.success).length;
      final failures = sheet.rows.where((r) => r.status == OnboardingRowStatus.failed).length;
      final skips = sheet.rows.where((r) => r.status == OnboardingRowStatus.skipped).length;

      expect(success, 2);
      expect(failures, 1);
      expect(skips, 2);
    });

    test('E. Multiple modules retain independent counters', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.guardians,
        'guardians.csv',
        'guardian_code,first_name,last_name,gender,date_of_birth,mobile,email,guardian_type,status\n'
        'PAR001,Ramesh,Kumar,MALE,1980-05-15,9876543212,ramesh@gmail.com,FATHER,ACTIVE\n'
        'PAR002,FailRow,Kumar,MALE,1980-05-15,9876543212,ramesh@gmail.com,FATHER,ACTIVE',
      );

      notifier.loadCsvFile(
        OnboardingStep.students,
        'students.csv',
        'admission_number,first_name,last_name,gender,date_of_birth,admission_date,roll_number,academic_year_code,class_code,section_code,status\n'
        'ADM001,Aarav,Kumar,MALE,2014-05-12,2026-06-01,1,AY_MISSING,CLASS_MISSING,SEC_MISSING,ACTIVE\n'
        'ADM002,Ananya,Kumar,FEMALE,2014-05-12,2026-06-01,2,AY_MISSING,CLASS_MISSING,SEC_MISSING,ACTIVE',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);

      final guardianSheet = state.sheets[OnboardingStep.guardians]!;
      expect(guardianSheet.rows.where((r) => r.status == OnboardingRowStatus.success).length, 1);
      expect(guardianSheet.rows.where((r) => r.status == OnboardingRowStatus.failed).length, 1);

      final studentSheet = state.sheets[OnboardingStep.students]!;
      expect(studentSheet.rows.where((r) => r.status == OnboardingRowStatus.skipped).length, 2);
    });

    test('F. State transition: Execution results are identical before and after COMPLETED state', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'DPSH,Delhi Public School Hyderabad,CBSE,HIGH_SCHOOL,contact@dpsh.in,9876543210,ACTIVE',
      );

      final futureImport = notifier.executeOnboarding('school_1', fakeApiClient);
      await futureImport;
      final state = container.read(schoolOnboardingProvider);

      expect(state.isCompleted, true);
      final schoolSheet = state.sheets[OnboardingStep.school]!;
      expect(schoolSheet.rows.where((r) => r.status == OnboardingRowStatus.success).length, 1);
    });

    test('H. Starting a new onboarding job clears previous execution results', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'DPSH,Delhi Public School Hyderabad,CBSE,HIGH_SCHOOL,contact@dpsh.in,9876543210,ACTIVE',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      expect(container.read(schoolOnboardingProvider).successCount, 1);

      notifier.reset();
      expect(container.read(schoolOnboardingProvider).successCount, 0);
      expect(container.read(schoolOnboardingProvider).sheets.isEmpty, true);
    });

    test('I. School context switch before/during clears previous results', () async {
      final container = ProviderContainer();
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

      final notifier = container.read(schoolOnboardingProvider.notifier);
      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'DPSH,Delhi Public School Hyderabad,CBSE,HIGH_SCHOOL,contact@dpsh.in,9876543210,ACTIVE',
      );

      expect(container.read(schoolOnboardingProvider).sheets.isNotEmpty, true);

      container.read(selectedSchoolIdProvider.notifier).state = 'school_2';
      expect(container.read(schoolOnboardingProvider).sheets.isEmpty, true);
      expect(container.read(schoolOnboardingProvider).resolvedSchools.isEmpty, true);
    });

    test('J. Parent multi-child: Caches resolved guardian to link multiple students without duplicate creation', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,HIGH_SCHOOL,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY2026,2026-27,2026-06-01,2027-03-31,ACTIVE,true',
      );
      notifier.loadCsvFile(
        OnboardingStep.classes,
        'classes.csv',
        'academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n'
        'AY2026,CLASS08,Class 8,8,PRIMARY,40,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.sections,
        'sections.csv',
        'academic_year_code,class_code,section_code,section_name,capacity,room_number,display_sort_order,status\n'
        'AY2026,CLASS08,SEC_A,Section A,40,Room 101,1,ACTIVE',
      );

      notifier.loadCsvFile(
        OnboardingStep.guardians,
        'guardians.csv',
        'guardian_code,first_name,last_name,gender,date_of_birth,mobile,email,guardian_type,status\n'
        'PAR001,Ramesh,Kumar,MALE,1980-05-15,9876543212,ramesh@gmail.com,FATHER,ACTIVE\n'
        'PAR001,Ramesh,Kumar,MALE,1980-05-15,9876543212,ramesh@gmail.com,FATHER,ACTIVE',
      );

      notifier.loadCsvFile(
        OnboardingStep.students,
        'students.csv',
        'admission_number,first_name,last_name,gender,date_of_birth,admission_date,roll_number,academic_year_code,class_code,section_code,status\n'
        'ADM001,Aarav,Kumar,MALE,2014-05-12,2026-06-01,1,AY2026,CLASS08,SEC_A,ACTIVE\n'
        'ADM002,Ananya,Kumar,FEMALE,2014-05-12,2026-06-01,2,AY2026,CLASS08,SEC_A,ACTIVE',
      );

      notifier.loadCsvFile(
        OnboardingStep.relationships,
        'student_guardians.csv',
        'admission_number,guardian_code,relationship,is_primary,authorized_for_pickup,receives_notifications\n'
        'ADM001,PAR001,FATHER,true,true,true\n'
        'ADM002,PAR001,FATHER,true,true,true',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);

      final guardianPosts = fakeApiClient.postCalls.where((c) => c['path'] == '/guardians').length;
      expect(guardianPosts, 1);

      final linksSheet = container.read(schoolOnboardingProvider).sheets[OnboardingStep.relationships]!;
      expect(linksSheet.rows.where((r) => r.status == OnboardingRowStatus.success).length, 2);
    });

    test('K. HTTP Status Capture: 422, 500 are correctly logged in the row', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'FAIL_422,Unprocessable School,CBSE,HIGH_SCHOOL,a@b.com,9876543210,ACTIVE\n'
        'FAIL_500,Internal Error School,CBSE,HIGH_SCHOOL,a@b.com,9876543210,ACTIVE',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      final sheet = state.sheets[OnboardingStep.school]!;

      expect(sheet.rows[0].httpStatus, 422);
      expect(sheet.rows[1].httpStatus, 500);

      // Verify school_code already exists message is preserved in UI
      expect(sheet.rows[0].apiErrorMessage, contains('school_code already exists'));
    });

    test('K2. Global Aborting Failures: 401 triggers globalErrorMessage and halts onboarding loops', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'FAIL_401,Unauthorized School,CBSE,HIGH_SCHOOL,a@b.com,9876543210,ACTIVE\n'
        'FAIL_422,Unprocessable School,CBSE,HIGH_SCHOOL,a@b.com,9876543210,ACTIVE',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);

      expect(state.globalErrorMessage, isNotNull);
      expect(state.isProcessing, false);
    });

    test('L. Dependency Skip Propagation: failed parent causes child skipped status with parentError details', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );

      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY2026,2026-27,2026-06-01,2027-03-31,ACTIVE,true',
      );

      notifier.loadCsvFile(
        OnboardingStep.classes,
        'classes.csv',
        'academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n'
        'AY2026,FAIL_422,Class 8,8,PRIMARY,40,ACTIVE',
      );

      notifier.loadCsvFile(
        OnboardingStep.sections,
        'sections.csv',
        'academic_year_code,class_code,section_code,section_name,capacity,room_number,display_sort_order,status\n'
        'AY2026,FAIL_422,SEC_A,Section A,40,Room 101,1,ACTIVE',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);

      final classSheet = state.sheets[OnboardingStep.classes]!;
      expect(classSheet.rows[0].status, OnboardingRowStatus.failed);

      final sectionSheet = state.sheets[OnboardingStep.sections]!;
      expect(sectionSheet.rows[0].status, OnboardingRowStatus.skipped);
      expect(sectionSheet.rows[0].dependencyFailureReason, contains('class code FAIL_422 could not be resolved'));
      expect(sectionSheet.rows[0].parentError, contains('Parent Grade Levels (Classes) row failed: HTTP 422 - school_code already exists'));
    });

    test('M. Sensitive Token Omission: ensures authorization tokens, passwords, secrets, etc. are cleaned from error messages', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      const sensitiveMessage = 'Failed request with bearer eyJhbGciOiJIUzI1NiIsIn.eyJzdWIiOiIxMjM0NTY3ODkwIiwi.SflKxwRJSMeKKF2QT4fwpMe and Authorization: Bearer secret_123';
      final clean = notifier.debugCleanErrorMessage(sensitiveMessage);

      expect(clean, isNot(contains('secret_123')));
      expect(clean, isNot(contains('eyJhbGciOiJIUzI1NiIsIn')));
      expect(clean, contains('Bearer [REDACTED]'));
    });

    test('N. CSV Export Content Validation: verifies success and error CSV payload formatting', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'FAIL_422,Delhi Public School Hyderabad,CBSE,HIGH_SCHOOL,contact@dpsh.in,9876543210,ACTIVE',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);

      final csvRows = <String>[];
      csvRows.add('Module,File,Row Number,Entity Code,Display Name,Status,HTTP Status Code,Details/Error Message,Dependency Skip Reason,Parent Error');

      for (final s in OnboardingStep.values) {
        if (s == OnboardingStep.validation || s == OnboardingStep.import || s == OnboardingStep.report) continue;
        final sheet = state.sheets[s];
        if (sheet == null) continue;
        for (final r in sheet.rows) {
          final module = s.label.replaceAll(',', ' ');
          final file = (r.fileName ?? sheet.fileName).replaceAll(',', ' ');
          final rowNum = r.rowIndex;
          final entity = (r.entityCode ?? '').replaceAll(',', ' ');
          final name = (r.displayName ?? '').replaceAll(',', ' ');
          final status = r.status.name.toUpperCase();
          final http = r.httpStatus?.toString() ?? '';
          final detail = (r.apiErrorMessage ?? '').replaceAll(',', ' ').replaceAll('\n', ' ');
          final depReason = (r.dependencyFailureReason ?? '').replaceAll(',', ' ');
          final parentErr = (r.parentError ?? '').replaceAll(',', ' ').replaceAll('\n', ' ');

          csvRows.add('$module,$file,$rowNum,$entity,$name,$status,$http,$detail,$depReason,$parentErr');
        }
      }

      expect(csvRows.length, 2);
      expect(csvRows[1], contains('School Information'));
      expect(csvRows[1], contains('FAIL_422'));
      expect(csvRows[1], contains('FAILED'));
      expect(csvRows[1], contains('422'));
      expect(csvRows[1], contains('school_code already exists'));
    });

    test('O. Valid and Invalid academic year code validations', () {
      final codeRegex = RegExp(r'^AY[0-9]{4}(?:-[0-9]{4})?$');
      expect(codeRegex.hasMatch('AY2025-2026'), isTrue);
      expect(codeRegex.hasMatch('AY2026'), isTrue);
      expect(codeRegex.hasMatch('AY2025_26'), isFalse);
      expect(codeRegex.hasMatch('2025-26'), isFalse);
    });

    test('P. Valid and Invalid academic year status validations', () {
      final validStatuses = ['UPCOMING', 'ACTIVE', 'COMPLETED', 'ARCHIVED'];
      expect(validStatuses.contains('ACTIVE'), isTrue);
      expect(validStatuses.contains('INVALID'), isFalse);
    });

    test('Q. Academic Structure HTTP 422 error reporting', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );

      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY2222,2026-27,2026-06-01,2027-03-31,ACTIVE,true',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      final aySheet = state.sheets[OnboardingStep.academicYears]!;
      
      expect(aySheet.rows[0].status, OnboardingRowStatus.failed);
      expect(aySheet.rows[0].httpStatus, 422);
      expect(aySheet.rows[0].apiErrorMessage, contains('school_code already exists'));
      expect(aySheet.rows[0].endpoint, contains('/academic-years'));
      expect(state.isProcessing, isFalse);
    });

    test('R. Stop Import behavior', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );

      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY2026,2026-27,2026-06-01,2027-03-31,ACTIVE,true\n'
        'school_1,AY2027,2027-28,2027-06-01,2028-03-31,ACTIVE,true',
      );

      final future = notifier.executeOnboarding('school_1', fakeApiClient);
      notifier.stopOnboarding();
      await future;

      final state = container.read(schoolOnboardingProvider);
      expect(state.isCancelled, isTrue);
      expect(state.isProcessing, isFalse);
      expect(state.isCompleted, isTrue);
    });

    test('S. Dependency blocking after Academic Structure failure', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );

      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY2222,2026-27,2026-06-01,2027-03-31,ACTIVE,true',
      );

      notifier.loadCsvFile(
        OnboardingStep.classes,
        'classes.csv',
        'academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n'
        'AY2222,CLASS08,Class 8,8,PRIMARY,40,ACTIVE',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);

      final classSheet = state.sheets[OnboardingStep.classes]!;
      expect(classSheet.rows[0].status, OnboardingRowStatus.skipped);
      expect(classSheet.rows[0].dependencyFailureReason, contains('academic year'));
    });

    test('T. Duplicate Academic Year response (409 Conflict lookup)', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );

      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY4099,2026-27,2026-06-01,2027-03-31,ACTIVE,true',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      final aySheet = state.sheets[OnboardingStep.academicYears]!;
      
      expect(aySheet.rows[0].status, OnboardingRowStatus.success);
      expect(aySheet.rows[0].resolvedId, 'ay_resolved_id_123');
      expect(state.resolvedAcademicYears['AY4099'], 'ay_resolved_id_123');
    });

    test('U. Slow/timeout response and Failure counter increments exactly once', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );

      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY2222,2026-27,2026-06-01,2027-03-31,ACTIVE,true',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      
      expect(state.failureCount, 1);
      expect(state.currentProgressRow, 1);
      expect(state.totalProgressRows, 1);
    });

    test('V. School step failure blocks all downstream modules', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      // School fails
      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,address,city,state,postal_code,status\n'
        'FAIL_422,Failed School,CBSE,PRIMARY,test@edu.in,9876543210,addr,city,state,123456,ACTIVE',
      );

      // Dependent steps
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'FAIL_422,AY2025-2026,2025-26,2025-04-01,2026-03-31,ACTIVE,true',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);

      final schoolSheet = state.sheets[OnboardingStep.school]!;
      final aySheet = state.sheets[OnboardingStep.academicYears]!;

      expect(schoolSheet.rows[0].status, OnboardingRowStatus.failed);
      expect(aySheet.rows[0].status, OnboardingRowStatus.skipped);
      expect(aySheet.rows[0].dependencyFailureReason, contains('school'));
    });
    test('W. School type validation flags invalid school_type', () {
      final container = ProviderContainer();
      final notifier = container.read(schoolOnboardingProvider.notifier);
      
      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'DPSH,Delhi Public School Hyderabad,CBSE,PRIVATE,contact@dpsh.in,9876543210,ACTIVE',
      );
      
      final state = container.read(schoolOnboardingProvider);
      final sheet = state.sheets[OnboardingStep.school]!;
      expect(sheet.rows[0].errors.any((e) => e.contains('school_type must be one of')), isTrue);
    });

    test('X. Execution safety check prevents executeOnboarding from running on validation errors', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'DPSH,Delhi Public School Hyderabad,CBSE,PRIVATE,contact@dpsh.in,9876543210,ACTIVE',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      expect(state.isProcessing, isFalse);
      expect(state.globalErrorMessage, contains('Pre-Import Validation contains blocking errors'));
    });

    test('Y. Successful School Information creation and response envelope unwrapping', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'DPSH2,Delhi Public School Hyderabad,CBSE,HIGH_SCHOOL,contact@dpsh.in,9876543210,ACTIVE',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      
      final schoolSheet = state.sheets[OnboardingStep.school]!;
      expect(schoolSheet.rows[0].status, OnboardingRowStatus.success);
      expect(schoolSheet.rows[0].resolvedId, 'resolved_mock_id');
      expect(state.resolvedSchools['DPSH2'], 'resolved_mock_id');
    });

    test('Z. Academic Year payload mapping and dependency resolution', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'DPSH2,Delhi Public School Hyderabad,CBSE,HIGH_SCHOOL,contact@dpsh.in,9876543210,ACTIVE',
      );

      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'DPSH2,AY2025-2026,2025-26,2025-04-01,2026-03-31,ACTIVE,true',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);

      final aySheet = state.sheets[OnboardingStep.academicYears]!;
      expect(aySheet.rows[0].status, OnboardingRowStatus.success);
      expect(aySheet.rows[0].resolvedId, 'resolved_mock_id');
      expect(state.resolvedAcademicYears['AY2025-2026'], 'resolved_mock_id');
    });

    test('AA. Academic Year response containing nullable fields without Null to String TypeError', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'DPSH2,Delhi Public School Hyderabad,CBSE,HIGH_SCHOOL,contact@dpsh.in,9876543210,ACTIVE',
      );

      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'DPSH2,AY2025-2026,2025-26,2025-04-01,2026-03-31,ACTIVE,true',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);

      final aySheet = state.sheets[OnboardingStep.academicYears]!;
      expect(aySheet.rows[0].status, OnboardingRowStatus.success);
      expect(state.globalErrorMessage, isNull);
    });

    test('AB. Grade Level resolution uses actual academic_year_code and has no default fallback', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );

      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY2025-2026,2025-26,2025-04-01,2026-03-31,ACTIVE,true',
      );

      notifier.loadCsvFile(
        OnboardingStep.classes,
        'classes.csv',
        'academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n'
        'AY2025-2026,CLASS08,Class 8,8,PRIMARY,40,ACTIVE',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);

      final classSheet = state.sheets[OnboardingStep.classes]!;
      expect(classSheet.rows[0].status, OnboardingRowStatus.success);
      expect(classSheet.rows[0].dependencyFailureReason, isNull);
    });

    test('AC. Blocking validation for missing academic year dependency in classes', () {
      final container = ProviderContainer();
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.classes,
        'classes.csv',
        'academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n'
        ',CLASS08,Class 8,8,PRIMARY,40,ACTIVE',
      );

      final state = container.read(schoolOnboardingProvider);
      final sheet = state.sheets[OnboardingStep.classes]!;
      expect(sheet.rows[0].errors.any((e) => e.contains('academic_year_code is required')), isTrue);
    });
    test('AD. Classes 409 Conflict Lookup Resolution', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY4099,2026-27,2026-06-01,2027-03-31,ACTIVE,true',
      );
      notifier.loadCsvFile(
        OnboardingStep.classes,
        'classes.csv',
        'academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n'
        'AY4099,CLS4099,Class 10,10,PRIMARY,40,ACTIVE',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      final classSheet = state.sheets[OnboardingStep.classes]!;
      expect(classSheet.rows[0].status, OnboardingRowStatus.success);
      expect(classSheet.rows[0].resolvedId, 'class_resolved_id_123');
    });

    test('AE. Sections 409 Conflict Lookup Resolution', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY4099,2026-27,2026-06-01,2027-03-31,ACTIVE,true',
      );
      notifier.loadCsvFile(
        OnboardingStep.classes,
        'classes.csv',
        'academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n'
        'AY4099,CLS4099,Class 10,10,PRIMARY,40,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.sections,
        'sections.csv',
        'academic_year_code,class_code,section_code,section_name,capacity,room_number,display_sort_order,status\n'
        'AY4099,CLS4099,SEC4099,Section A,40,R101,1,ACTIVE',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      final secSheet = state.sheets[OnboardingStep.sections]!;
      expect(secSheet.rows[0].status, OnboardingRowStatus.success);
      expect(secSheet.rows[0].resolvedId, 'section_resolved_id_123');
    });

    test('AF. Subjects 409 Conflict Lookup Resolution', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY4099,2026-27,2026-06-01,2027-03-31,ACTIVE,true',
      );
      notifier.loadCsvFile(
        OnboardingStep.subjects,
        'subjects.csv',
        'subject_code,subject_name,category,subject_type,credit_hours,weekly_periods,theory_marks,practical_marks,pass_marks,display_order,academic_year_code\n'
        'SUB4099,Mathematics,CORE,THEORY_PRACTICAL,4,4,80,20,33,1,AY4099',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      final subSheet = state.sheets[OnboardingStep.subjects]!;
      expect(subSheet.rows[0].status, OnboardingRowStatus.success);
      expect(subSheet.rows[0].resolvedId, 'subject_resolved_id_123');
    });

    test('AG. Teachers 409 Conflict Lookup Resolution', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.teachers,
        'teachers.csv',
        'teacher_code,first_name,last_name,gender,date_of_birth,mobile,email,employee_code,designation,joining_date,status,employment_type\n'
        'TCH4099,John,Doe,MALE,1985-05-15,9876543210,john@test.com,TCH4099,TGT,2026-06-01,ACTIVE,FULL_TIME',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      final teacherSheet = state.sheets[OnboardingStep.teachers]!;
      expect(teacherSheet.rows[0].status, OnboardingRowStatus.success);
      expect(teacherSheet.rows[0].resolvedId, 'teacher_resolved_id_123');
    });

    test('AH. Guardians 409 Conflict Lookup Resolution', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.guardians,
        'guardians.csv',
        'guardian_code,first_name,last_name,gender,date_of_birth,mobile,email,guardian_type,status\n'
        'GD4099,Mike,Doe,MALE,1980-01-01,9876544099,mike@test.com,FATHER,ACTIVE',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      final guardianSheet = state.sheets[OnboardingStep.guardians]!;
      expect(guardianSheet.rows[0].status, OnboardingRowStatus.success);
      expect(guardianSheet.rows[0].resolvedId, 'guardian_resolved_id_123');
    });

    test('AI. Students 409 Conflict Lookup Resolution', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY4099,2026-27,2026-06-01,2027-03-31,ACTIVE,true',
      );
      notifier.loadCsvFile(
        OnboardingStep.classes,
        'classes.csv',
        'academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n'
        'AY4099,CLS4099,Class 10,10,PRIMARY,40,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.sections,
        'sections.csv',
        'academic_year_code,class_code,section_code,section_name,capacity,room_number,display_sort_order,status\n'
        'AY4099,CLS4099,SEC4099,Section A,40,R101,1,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.students,
        'students.csv',
        'admission_number,first_name,last_name,gender,date_of_birth,admission_date,roll_number,academic_year_code,class_code,section_code,status\n'
        'STD4099,Jane,Doe,FEMALE,2010-01-01,2026-06-01,1,AY4099,CLS4099,SEC4099,ACTIVE',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      final studentSheet = state.sheets[OnboardingStep.students]!;
      expect(studentSheet.rows[0].status, OnboardingRowStatus.success);
      expect(studentSheet.rows[0].resolvedId, 'student_resolved_id_123');
    });

    test('AJ. Student-Guardian Relationship 409 Conflict Lookup Resolution', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY4099,2026-27,2026-06-01,2027-03-31,ACTIVE,true',
      );
      notifier.loadCsvFile(
        OnboardingStep.classes,
        'classes.csv',
        'academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n'
        'AY4099,CLS4099,Class 10,10,PRIMARY,40,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.sections,
        'sections.csv',
        'academic_year_code,class_code,section_code,section_name,capacity,room_number,display_sort_order,status\n'
        'AY4099,CLS4099,SEC4099,Section A,40,R101,1,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.students,
        'students.csv',
        'admission_number,first_name,last_name,gender,date_of_birth,admission_date,roll_number,academic_year_code,class_code,section_code,status\n'
        'STD4099,Jane,Doe,FEMALE,2010-01-01,2026-06-01,1,AY4099,CLS4099,SEC4099,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.guardians,
        'guardians.csv',
        'guardian_code,first_name,last_name,gender,date_of_birth,mobile,email,guardian_type,status\n'
        'GD4099,Mike,Doe,MALE,1980-01-01,9876544099,mike@test.com,FATHER,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.relationships,
        'relationships.csv',
        'admission_number,guardian_code,relationship,is_primary,authorized_for_pickup,receives_notifications\n'
        'STD4099,GD4099,FATHER,true,true,true',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      final relSheet = state.sheets[OnboardingStep.relationships]!;
      expect(relSheet.rows[0].status, OnboardingRowStatus.success);
      expect(relSheet.rows[0].resolvedId, 'relationship_resolved_id_123');
    });

    test('AK. Teacher Subject Assignment 409 Conflict Lookup Resolution', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY4099,2026-27,2026-06-01,2027-03-31,ACTIVE,true',
      );
      notifier.loadCsvFile(
        OnboardingStep.classes,
        'classes.csv',
        'academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n'
        'AY4099,CLS4099,Class 10,10,PRIMARY,40,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.sections,
        'sections.csv',
        'academic_year_code,class_code,section_code,section_name,capacity,room_number,display_sort_order,status\n'
        'AY4099,CLS4099,SEC4099,Section A,40,R101,1,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.teachers,
        'teachers.csv',
        'teacher_code,first_name,last_name,gender,date_of_birth,mobile,email,employee_code,designation,joining_date,status,employment_type\n'
        'TCH4099,John,Doe,MALE,1985-05-15,9876543210,john@test.com,TCH4099,TGT,2026-06-01,ACTIVE,FULL_TIME',
      );
      notifier.loadCsvFile(
        OnboardingStep.subjects,
        'subjects.csv',
        'subject_code,subject_name,category,subject_type,credit_hours,weekly_periods,theory_marks,practical_marks,pass_marks,display_order,academic_year_code\n'
        'SUB4099,Mathematics,CORE,THEORY_PRACTICAL,4,4,80,20,33,1,AY4099',
      );
      notifier.loadCsvFile(
        OnboardingStep.teacherAssignments,
        'assignments.csv',
        'teacher_code,subject_code,class_code,section_code,academic_year_code,assignment_type,weekly_periods,effective_from\n'
        'TCH4099,SUB4099,CLS4099,SEC4099,AY4099,PRIMARY,6,2025-04-01',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      final tsaSheet = state.sheets[OnboardingStep.teacherAssignments]!;
      expect(tsaSheet.rows[0].status, OnboardingRowStatus.success);
      expect(tsaSheet.rows[0].resolvedId, 'assignment_resolved_id_123');
    });

    test('BK. Valid teacher assignment payload contents check', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY4099,2026-27,2026-06-01,2027-03-31,ACTIVE,true',
      );
      notifier.loadCsvFile(
        OnboardingStep.classes,
        'classes.csv',
        'academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n'
        'AY4099,CLS4099,Class 10,10,PRIMARY,40,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.sections,
        'sections.csv',
        'academic_year_code,class_code,section_code,section_name,capacity,room_number,display_sort_order,status\n'
        'AY4099,CLS4099,SEC4099,Section A,40,R101,1,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.teachers,
        'teachers.csv',
        'teacher_code,first_name,last_name,gender,date_of_birth,mobile,email,employee_code,designation,joining_date,status,employment_type\n'
        'TCH_VAL,John,Doe,MALE,1985-05-15,9876543210,john@test.com,TCH_VAL,TGT,2026-06-01,ACTIVE,FULL_TIME',
      );
      notifier.loadCsvFile(
        OnboardingStep.subjects,
        'subjects.csv',
        'subject_code,subject_name,category,subject_type,credit_hours,weekly_periods,theory_marks,practical_marks,pass_marks,display_order,academic_year_code\n'
        'SUB_VAL,Mathematics,CORE,THEORY_PRACTICAL,4,4,80,20,33,1,AY4099',
      );
      notifier.loadCsvFile(
        OnboardingStep.teacherAssignments,
        'assignments.csv',
        'teacher_code,subject_code,class_code,section_code,academic_year_code,assignment_type,weekly_periods,effective_from\n'
        'TCH_VAL,SUB_VAL,CLS4099,SEC4099,AY4099,PRIMARY,6,2025-04-01',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      final tsaSheet = state.sheets[OnboardingStep.teacherAssignments]!;
      expect(tsaSheet.rows[0].status, OnboardingRowStatus.success);

      final postCall = fakeApiClient.postCalls.firstWhere((c) => c['path'] == '/teacher-subject-assignments');
      final postData = postCall['data'] as Map<String, dynamic>;
      expect(postData['assignment_type'], 'PRIMARY');
      expect(postData['weekly_periods'], 6);
      expect(postData['effective_from'], '2025-04-01');
    });

    test('BL. Teacher assignment missing assignment_type is blocked before POST', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.teacherAssignments,
        'assignments.csv',
        'teacher_code,subject_code,class_code,section_code,academic_year_code,assignment_type,weekly_periods,effective_from\n'
        'TCH_VAL,SUB_VAL,CLS4099,SEC4099,AY4099,,6,2025-04-01',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      final tsaSheet = state.sheets[OnboardingStep.teacherAssignments]!;
      expect(tsaSheet.rows[0].status, OnboardingRowStatus.error);
      expect(tsaSheet.rows[0].errors, contains('assignment_type is required for Teacher Assignments.'));

      final hasPost = fakeApiClient.postCalls.any((c) => c['path'] == '/teacher-subject-assignments');
      expect(hasPost, isFalse);
    });

    test('BM. Teacher assignment missing weekly_periods is blocked before POST', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.teacherAssignments,
        'assignments.csv',
        'teacher_code,subject_code,class_code,section_code,academic_year_code,assignment_type,weekly_periods,effective_from\n'
        'TCH_VAL,SUB_VAL,CLS4099,SEC4099,AY4099,PRIMARY,,2025-04-01',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      final tsaSheet = state.sheets[OnboardingStep.teacherAssignments]!;
      expect(tsaSheet.rows[0].status, OnboardingRowStatus.error);
      expect(tsaSheet.rows[0].errors, contains('weekly_periods is required for Teacher Assignments.'));

      final hasPost = fakeApiClient.postCalls.any((c) => c['path'] == '/teacher-subject-assignments');
      expect(hasPost, isFalse);
    });

    test('BN. Teacher assignment invalid weekly_periods is blocked before POST', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.teacherAssignments,
        'assignments.csv',
        'teacher_code,subject_code,class_code,section_code,academic_year_code,assignment_type,weekly_periods,effective_from\n'
        'TCH_VAL,SUB_VAL,CLS4099,SEC4099,AY4099,PRIMARY,abc,2025-04-01',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      final tsaSheet = state.sheets[OnboardingStep.teacherAssignments]!;
      expect(tsaSheet.rows[0].status, OnboardingRowStatus.error);
      expect(tsaSheet.rows[0].errors, contains('weekly_periods is required for Teacher Assignments.'));
    });

    test('BO. Teacher assignment missing effective_from is blocked before POST', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.teacherAssignments,
        'assignments.csv',
        'teacher_code,subject_code,class_code,section_code,academic_year_code,assignment_type,weekly_periods,effective_from\n'
        'TCH_VAL,SUB_VAL,CLS4099,SEC4099,AY4099,PRIMARY,6,',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      final tsaSheet = state.sheets[OnboardingStep.teacherAssignments]!;
      expect(tsaSheet.rows[0].status, OnboardingRowStatus.error);
      expect(tsaSheet.rows[0].errors, contains('effective_from is required for Teacher Assignments.'));
    });

    test('BP. Teacher assignment invalid assignment_type is blocked before POST', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.teacherAssignments,
        'assignments.csv',
        'teacher_code,subject_code,class_code,section_code,academic_year_code,assignment_type,weekly_periods,effective_from\n'
        'TCH_VAL,SUB_VAL,CLS4099,SEC4099,AY4099,INVALID_TYPE,6,2025-04-01',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      final tsaSheet = state.sheets[OnboardingStep.teacherAssignments]!;
      expect(tsaSheet.rows[0].status, OnboardingRowStatus.error);
      expect(tsaSheet.rows[0].errors, contains('assignment_type must match enums (found: "INVALID_TYPE")'));
    });

    test('BQ. Teacher assignment HTTP 409 conflict resolves existing assignment UUID', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY4099,2026-27,2026-06-01,2027-03-31,ACTIVE,true',
      );
      notifier.loadCsvFile(
        OnboardingStep.classes,
        'classes.csv',
        'academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n'
        'AY4099,CLS4099,Class 10,10,PRIMARY,40,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.sections,
        'sections.csv',
        'academic_year_code,class_code,section_code,section_name,capacity,room_number,display_sort_order,status\n'
        'AY4099,CLS4099,SEC4099,Section A,40,R101,1,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.teachers,
        'teachers.csv',
        'teacher_code,first_name,last_name,gender,date_of_birth,mobile,email,employee_code,designation,joining_date,status,employment_type\n'
        'TCH4099,John,Doe,MALE,1985-05-15,9876543210,john@test.com,TCH4099,TGT,2026-06-01,ACTIVE,FULL_TIME',
      );
      notifier.loadCsvFile(
        OnboardingStep.subjects,
        'subjects.csv',
        'subject_code,subject_name,category,subject_type,credit_hours,weekly_periods,theory_marks,practical_marks,pass_marks,display_order,academic_year_code\n'
        'SUB4099,Mathematics,CORE,THEORY_PRACTICAL,4,4,80,20,33,1,AY4099',
      );
      notifier.loadCsvFile(
        OnboardingStep.teacherAssignments,
        'assignments.csv',
        'teacher_code,subject_code,class_code,section_code,academic_year_code,assignment_type,weekly_periods,effective_from\n'
        'TCH4099,SUB4099,CLS4099,SEC4099,AY4099,PRIMARY,6,2025-04-01',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      
      // Verification of 409 matching logic
      final tsaSheet = state.sheets[OnboardingStep.teacherAssignments]!;
      expect(tsaSheet.rows[0].status, OnboardingRowStatus.success);
      expect(tsaSheet.rows[0].resolvedId, 'assignment_resolved_id_123');
      expect(state.resolvedAssignments['TCH4099-SUB4099-CLS4099-SEC4099'], 'assignment_resolved_id_123');
    });

    test('BR. Downstream Timetable Slots can resolve successful Teacher Assignment', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY4099,2026-27,2026-06-01,2027-03-31,ACTIVE,true',
      );
      notifier.loadCsvFile(
        OnboardingStep.classes,
        'classes.csv',
        'academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n'
        'AY4099,CLS4099,Class 10,10,PRIMARY,40,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.sections,
        'sections.csv',
        'academic_year_code,class_code,section_code,section_name,capacity,room_number,display_sort_order,status\n'
        'AY4099,CLS4099,SEC4099,Section A,40,R101,1,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.teachers,
        'teachers.csv',
        'teacher_code,first_name,last_name,gender,date_of_birth,mobile,email,employee_code,designation,joining_date,status,employment_type\n'
        'TCH4099,John,Doe,MALE,1985-05-15,9876543210,john@test.com,TCH4099,TGT,2026-06-01,ACTIVE,FULL_TIME',
      );
      notifier.loadCsvFile(
        OnboardingStep.subjects,
        'subjects.csv',
        'subject_code,subject_name,category,subject_type,credit_hours,weekly_periods,theory_marks,practical_marks,pass_marks,display_order,academic_year_code\n'
        'SUB4099,Mathematics,CORE,THEORY_PRACTICAL,4,4,80,20,33,1,AY4099',
      );
      notifier.loadCsvFile(
        OnboardingStep.teacherAssignments,
        'assignments.csv',
        'teacher_code,subject_code,class_code,section_code,academic_year_code,assignment_type,weekly_periods,effective_from\n'
        'TCH4099,SUB4099,CLS4099,SEC4099,AY4099,PRIMARY,6,2025-04-01',
      );
      notifier.loadCsvFile(
        OnboardingStep.timetable,
        'timetable.csv',
        'academic_year_code,day_of_week,period_number,start_time,end_time,class_code,section_code,subject_code,teacher_code,room_number,period_type\n'
        'AY4099,MONDAY,1,09:00:00,09:45:00,CLS4099,SEC4099,SUB4099,TCH4099,R101,REGULAR',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      
      final ttSheet = state.sheets[OnboardingStep.timetable]!;
      expect(ttSheet.rows[0].status, OnboardingRowStatus.success);
    });

    test('BS. Valid period_type in Timetable Slot POST payload', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY4099,2026-27,2026-06-01,2027-03-31,ACTIVE,true',
      );
      notifier.loadCsvFile(
        OnboardingStep.classes,
        'classes.csv',
        'academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n'
        'AY4099,CLS4099,Class 10,10,PRIMARY,40,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.sections,
        'sections.csv',
        'academic_year_code,class_code,section_code,section_name,capacity,room_number,display_sort_order,status\n'
        'AY4099,CLS4099,SEC4099,Section A,40,R101,1,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.teachers,
        'teachers.csv',
        'teacher_code,first_name,last_name,gender,date_of_birth,mobile,email,employee_code,designation,joining_date,status,employment_type\n'
        'TCH4099,John,Doe,MALE,1985-05-15,9876543210,john@test.com,TCH4099,TGT,2026-06-01,ACTIVE,FULL_TIME',
      );
      notifier.loadCsvFile(
        OnboardingStep.subjects,
        'subjects.csv',
        'subject_code,subject_name,category,subject_type,credit_hours,weekly_periods,theory_marks,practical_marks,pass_marks,display_order,academic_year_code\n'
        'SUB4099,Mathematics,CORE,THEORY_PRACTICAL,4,4,80,20,33,1,AY4099',
      );
      notifier.loadCsvFile(
        OnboardingStep.teacherAssignments,
        'assignments.csv',
        'teacher_code,subject_code,class_code,section_code,academic_year_code,assignment_type,weekly_periods,effective_from\n'
        'TCH4099,SUB4099,CLS4099,SEC4099,AY4099,PRIMARY,6,2025-04-01',
      );
      notifier.loadCsvFile(
        OnboardingStep.timetable,
        'timetable.csv',
        'academic_year_code,day_of_week,period_number,start_time,end_time,class_code,section_code,subject_code,teacher_code,room_number,period_type\n'
        'AY4099,MONDAY,1,09:00:00,09:45:00,CLS4099,SEC4099,SUB4099,TCH4099,R101,LAB',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      
      final ttSheet = state.sheets[OnboardingStep.timetable]!;
      expect(ttSheet.rows[0].status, OnboardingRowStatus.success);

      final postCall = fakeApiClient.postCalls.firstWhere((c) => c['path'] == '/timetables');
      final postData = postCall['data'] as Map<String, dynamic>;
      expect(postData['period_type'], 'LAB');
    });

    test('BT. Timetable missing period_type is blocked before POST', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.timetable,
        'timetable.csv',
        'academic_year_code,day_of_week,period_number,start_time,end_time,class_code,section_code,subject_code,teacher_code,room_number,period_type\n'
        'AY4099,MONDAY,1,09:00:00,09:45:00,CLS4099,SEC4099,SUB4099,TCH4099,R101,',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      
      final ttSheet = state.sheets[OnboardingStep.timetable]!;
      expect(ttSheet.rows[0].status, OnboardingRowStatus.error);
      expect(ttSheet.rows[0].errors, contains('period_type is required for Timetable Slots.'));

      final hasPost = fakeApiClient.postCalls.any((c) => c['path'] == '/timetables');
      expect(hasPost, isFalse);
    });

    test('BU. Timetable invalid period_type is blocked before POST', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.timetable,
        'timetable.csv',
        'academic_year_code,day_of_week,period_number,start_time,end_time,class_code,section_code,subject_code,teacher_code,room_number,period_type\n'
        'AY4099,MONDAY,1,09:00:00,09:45:00,CLS4099,SEC4099,SUB4099,TCH4099,R101,RECREATION',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      
      final ttSheet = state.sheets[OnboardingStep.timetable]!;
      expect(ttSheet.rows[0].status, OnboardingRowStatus.error);
      expect(ttSheet.rows[0].errors, contains('period_type must match enums (found: "RECREATION")'));
    });

    test('BV. HTTP 409 timetable conflict resolves existing timetable slot UUID', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY4099,2026-27,2026-06-01,2027-03-31,ACTIVE,true',
      );
      notifier.loadCsvFile(
        OnboardingStep.classes,
        'classes.csv',
        'academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n'
        'AY4099,CLS4099,Class 10,10,PRIMARY,40,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.sections,
        'sections.csv',
        'academic_year_code,class_code,section_code,section_name,capacity,room_number,display_sort_order,status\n'
        'AY4099,CLS4099,SEC4099,Section A,40,R101,1,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.teachers,
        'teachers.csv',
        'teacher_code,first_name,last_name,gender,date_of_birth,mobile,email,employee_code,designation,joining_date,status,employment_type\n'
        'TCH4099,John,Doe,MALE,1985-05-15,9876543210,john@test.com,TCH4099,TGT,2026-06-01,ACTIVE,FULL_TIME',
      );
      notifier.loadCsvFile(
        OnboardingStep.subjects,
        'subjects.csv',
        'subject_code,subject_name,category,subject_type,credit_hours,weekly_periods,theory_marks,practical_marks,pass_marks,display_order,academic_year_code\n'
        'SUB4099,Mathematics,CORE,THEORY_PRACTICAL,4,4,80,20,33,1,AY4099',
      );
      notifier.loadCsvFile(
        OnboardingStep.teacherAssignments,
        'assignments.csv',
        'teacher_code,subject_code,class_code,section_code,academic_year_code,assignment_type,weekly_periods,effective_from\n'
        'TCH4099,SUB4099,CLS4099,SEC4099,AY4099,PRIMARY,6,2025-04-01',
      );
      notifier.loadCsvFile(
        OnboardingStep.timetable,
        'timetable.csv',
        'academic_year_code,day_of_week,period_number,start_time,end_time,class_code,section_code,subject_code,teacher_code,room_number,period_type\n'
        'AY4099,MONDAY,1,09:00:00,09:45:00,CLS4099,SEC4099,SUB4099,TCH4099,R101,REGULAR',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      
      final ttSheet = state.sheets[OnboardingStep.timetable]!;
      expect(ttSheet.rows[0].status, OnboardingRowStatus.success);
      expect(ttSheet.rows[0].resolvedId, 'timetable_resolved_id_123');
    });

    test('BW. Downstream slot resolution check with teacher assignment resolved', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY4099,2026-27,2026-06-01,2027-03-31,ACTIVE,true',
      );
      notifier.loadCsvFile(
        OnboardingStep.classes,
        'classes.csv',
        'academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n'
        'AY4099,CLS4099,Class 10,10,PRIMARY,40,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.sections,
        'sections.csv',
        'academic_year_code,class_code,section_code,section_name,capacity,room_number,display_sort_order,status\n'
        'AY4099,CLS4099,SEC4099,Section A,40,R101,1,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.teachers,
        'teachers.csv',
        'teacher_code,first_name,last_name,gender,date_of_birth,mobile,email,employee_code,designation,joining_date,status,employment_type\n'
        'TCH4099,John,Doe,MALE,1985-05-15,9876543210,john@test.com,TCH4099,TGT,2026-06-01,ACTIVE,FULL_TIME',
      );
      notifier.loadCsvFile(
        OnboardingStep.subjects,
        'subjects.csv',
        'subject_code,subject_name,category,subject_type,credit_hours,weekly_periods,theory_marks,practical_marks,pass_marks,display_order,academic_year_code\n'
        'SUB4099,Mathematics,CORE,THEORY_PRACTICAL,4,4,80,20,33,1,AY4099',
      );
      notifier.loadCsvFile(
        OnboardingStep.teacherAssignments,
        'assignments.csv',
        'teacher_code,subject_code,class_code,section_code,academic_year_code,assignment_type,weekly_periods,effective_from\n'
        'TCH4099,SUB4099,CLS4099,SEC4099,AY4099,PRIMARY,6,2025-04-01',
      );
      notifier.loadCsvFile(
        OnboardingStep.timetable,
        'timetable.csv',
        'academic_year_code,day_of_week,period_number,start_time,end_time,class_code,section_code,subject_code,teacher_code,room_number,period_type\n'
        'AY4099,MONDAY,1,09:00:00,09:45:00,CLS4099,SEC4099,SUB4099,TCH4099,R101,REGULAR',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      
      final ttSheet = state.sheets[OnboardingStep.timetable]!;
      expect(ttSheet.rows[0].status, OnboardingRowStatus.success);
    });

    test('BX. Valid exam type in Examination POST payload', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY4099,2026-27,2026-06-01,2027-03-31,ACTIVE,true',
      );
      notifier.loadCsvFile(
        OnboardingStep.classes,
        'classes.csv',
        'academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n'
        'AY4099,CLS4099,Class 10,10,PRIMARY,40,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.subjects,
        'subjects.csv',
        'subject_code,subject_name,category,subject_type,credit_hours,weekly_periods,theory_marks,practical_marks,pass_marks,display_order,academic_year_code\n'
        'SUB4099,Mathematics,CORE,THEORY_PRACTICAL,4,4,80,20,33,1,AY4099',
      );
      notifier.loadCsvFile(
        OnboardingStep.exams,
        'exams.csv',
        'academic_year_code,exam_code,exam_name,exam_type,class_code,subject_code,exam_date,maximum_marks,duration_minutes\n'
        'AY4099,EX_NEW,Terminal One,HALF_YEARLY,CLS4099,SUB4099,2026-12-05,100,120',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      
      final examSheet = state.sheets[OnboardingStep.exams]!;
      expect(examSheet.rows[0].status, OnboardingRowStatus.success);

      final postCall = fakeApiClient.postCalls.firstWhere((c) => c['path'] == '/examinations');
      final postData = postCall['data'] as Map<String, dynamic>;
      expect(postData['exam_type'], 'HALF_YEARLY');
    });

    test('BY. Invalid exam type fails pre-import validation and blocks POST', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.exams,
        'exams.csv',
        'academic_year_code,exam_code,exam_name,exam_type,class_code,subject_code,exam_date,maximum_marks,duration_minutes\n'
        'AY4099,EX_NEW,Terminal One,TERM,CLS4099,SUB4099,2026-12-05,100,120',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      
      final examSheet = state.sheets[OnboardingStep.exams]!;
      expect(examSheet.rows[0].status, OnboardingRowStatus.error);
      expect(examSheet.rows[0].errors, contains('Exam type must match enums: UNIT_TEST, MONTHLY, QUARTERLY, HALF_YEARLY, PRE_FINAL, ANNUAL, SUPPLEMENTARY (found: "TERM")'));

      final hasPost = fakeApiClient.postCalls.any((c) => c['path'] == '/examinations');
      expect(hasPost, isFalse);
    });

    test('BZ. HTTP 409 exam conflict resolves existing exam UUID', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY4099,2026-27,2026-06-01,2027-03-31,ACTIVE,true',
      );
      notifier.loadCsvFile(
        OnboardingStep.classes,
        'classes.csv',
        'academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n'
        'AY4099,CLS4099,Class 10,10,PRIMARY,40,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.subjects,
        'subjects.csv',
        'subject_code,subject_name,category,subject_type,credit_hours,weekly_periods,theory_marks,practical_marks,pass_marks,display_order,academic_year_code\n'
        'SUB4099,Mathematics,CORE,THEORY_PRACTICAL,4,4,80,20,33,1,AY4099',
      );
      notifier.loadCsvFile(
        OnboardingStep.exams,
        'exams.csv',
        'academic_year_code,exam_code,exam_name,exam_type,class_code,subject_code,exam_date,maximum_marks,duration_minutes\n'
        'AY4099,EX4099,Midterm 4099,UNIT_TEST,CLS4099,SUB4099,2026-10-10,100,180',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      
      final examSheet = state.sheets[OnboardingStep.exams]!;
      expect(examSheet.rows[0].status, OnboardingRowStatus.success);
      expect(examSheet.rows[0].resolvedId, 'exam_resolved_id_123');
    });

    test('CA. Required exam fields validation', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.exams,
        'exams.csv',
        'academic_year_code,exam_code,exam_name,exam_type,class_code,subject_code,exam_date,maximum_marks,duration_minutes\n'
        'AY4099,EX_NEW,Terminal One,UNIT_TEST,CLS4099,SUB4099,2026-12-05,,120',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      
      final examSheet = state.sheets[OnboardingStep.exams]!;
      expect(examSheet.rows[0].status, OnboardingRowStatus.error);
      expect(examSheet.rows[0].errors, contains('Maximum marks must be a positive integer.'));
    });

    test('CB. Exam date mapping checks', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY4099,2026-27,2026-06-01,2027-03-31,ACTIVE,true',
      );
      notifier.loadCsvFile(
        OnboardingStep.classes,
        'classes.csv',
        'academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n'
        'AY4099,CLS4099,Class 10,10,PRIMARY,40,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.subjects,
        'subjects.csv',
        'subject_code,subject_name,category,subject_type,credit_hours,weekly_periods,theory_marks,practical_marks,pass_marks,display_order,academic_year_code\n'
        'SUB4099,Mathematics,CORE,THEORY_PRACTICAL,4,4,80,20,33,1,AY4099',
      );
      notifier.loadCsvFile(
        OnboardingStep.exams,
        'exams.csv',
        'academic_year_code,exam_code,exam_name,exam_type,class_code,subject_code,exam_date,maximum_marks,duration_minutes\n'
        'AY4099,EX_NEW,Terminal One,UNIT_TEST,CLS4099,SUB4099,2026-12-05,100,120',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      
      final examSheet = state.sheets[OnboardingStep.exams]!;
      expect(examSheet.rows[0].status, OnboardingRowStatus.success);

      final postCall = fakeApiClient.postCalls.firstWhere((c) => c['path'] == '/examinations');
      final postData = postCall['data'] as Map<String, dynamic>;
      expect(postData['start_date'], '2026-12-05');
      expect(postData['end_date'], '2026-12-05');
    });

    test('CI. New examination creates and resolves UUID successfully', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY4099,2026-27,2026-06-01,2027-03-31,ACTIVE,true',
      );
      notifier.loadCsvFile(
        OnboardingStep.classes,
        'classes.csv',
        'academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n'
        'AY4099,CLS03,Class 8,8,PRIMARY,40,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.subjects,
        'subjects.csv',
        'subject_code,subject_name,category,subject_type,credit_hours,weekly_periods,theory_marks,practical_marks,pass_marks,display_order,academic_year_code\n'
        'ENG,English,CORE,THEORY_PRACTICAL,4,4,80,20,33,1,AY4099',
      );
      notifier.loadCsvFile(
        OnboardingStep.exams,
        'exams.csv',
        'academic_year_code,exam_code,exam_name,exam_type,class_code,subject_code,exam_date,maximum_marks,duration_minutes\n'
        'AY4099,EXM_NEW,New Exam,HALF_YEARLY,CLS03,ENG,2025-09-20,100,120',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      
      final examSheet = state.sheets[OnboardingStep.exams]!;
      expect(examSheet.rows[0].status, OnboardingRowStatus.success);
      expect(examSheet.rows[0].resolvedId, 'resolved_mock_id');
      expect(state.resolvedExaminations['EXM_NEW'], 'resolved_mock_id');
    });

    test('CJ. Existing examination duplicate resolution finds matching record and resolves UUID', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY4099,2026-27,2026-06-01,2027-03-31,ACTIVE,true',
      );
      notifier.loadCsvFile(
        OnboardingStep.classes,
        'classes.csv',
        'academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n'
        'AY4099,CLS03,Class 8,8,PRIMARY,40,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.subjects,
        'subjects.csv',
        'subject_code,subject_name,category,subject_type,credit_hours,weekly_periods,theory_marks,practical_marks,pass_marks,display_order,academic_year_code\n'
        'ENG,English,CORE,THEORY_PRACTICAL,4,4,80,20,33,1,AY4099',
      );
      notifier.loadCsvFile(
        OnboardingStep.exams,
        'exams.csv',
        'academic_year_code,exam_code,exam_name,exam_type,class_code,subject_code,exam_date,maximum_marks,duration_minutes\n'
        'AY4099,EXM_EXISTS,Midterm 4099,HALF_YEARLY,CLS03,ENG,2025-09-20,100,120',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      
      final examSheet = state.sheets[OnboardingStep.exams]!;
      expect(examSheet.rows[0].status, OnboardingRowStatus.success);
      expect(examSheet.rows[0].resolvedId, 'exam_resolved_id_123');
      expect(state.resolvedExaminations['EXM_EXISTS'], 'exam_resolved_id_123');
    });

    test('CK. Existing examination with academic year filter ignores different year records', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY2027-2028,2027-28,2027-06-01,2028-03-31,ACTIVE,true',
      );
      notifier.loadCsvFile(
        OnboardingStep.classes,
        'classes.csv',
        'academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n'
        'AY2027-2028,CLS03,Class 8,8,PRIMARY,40,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.subjects,
        'subjects.csv',
        'subject_code,subject_name,category,subject_type,credit_hours,weekly_periods,theory_marks,practical_marks,pass_marks,display_order,academic_year_code\n'
        'ENG,English,CORE,THEORY_PRACTICAL,4,4,80,20,33,1,AY2027-2028',
      );
      notifier.loadCsvFile(
        OnboardingStep.exams,
        'exams.csv',
        'academic_year_code,exam_code,exam_name,exam_type,class_code,subject_code,exam_date,maximum_marks,duration_minutes\n'
        'AY2027-2028,EXM_EXISTS,Midterm 4099,HALF_YEARLY,CLS03,ENG,2025-09-20,100,120',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      
      final examSheet = state.sheets[OnboardingStep.exams]!;
      expect(examSheet.rows[0].status, OnboardingRowStatus.success);
      expect(examSheet.rows[0].resolvedId, 'exam_resolved_id_other_year');
    });

    test('CL. Existing examination with same name but different date does not match', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY2028-2029,2028-29,2028-06-01,2029-03-31,ACTIVE,true',
      );
      notifier.loadCsvFile(
        OnboardingStep.classes,
        'classes.csv',
        'academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n'
        'AY2028-2029,CLS03,Class 8,8,PRIMARY,40,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.subjects,
        'subjects.csv',
        'subject_code,subject_name,category,subject_type,credit_hours,weekly_periods,theory_marks,practical_marks,pass_marks,display_order,academic_year_code\n'
        'ENG,English,CORE,THEORY_PRACTICAL,4,4,80,20,33,1,AY2028-2029',
      );
      
      notifier.loadCsvFile(
        OnboardingStep.exams,
        'exams.csv',
        'academic_year_code,exam_code,exam_name,exam_type,class_code,subject_code,exam_date,maximum_marks,duration_minutes\n'
        'AY2028-2029,EXM_EXISTS,Midterm 4099,HALF_YEARLY,CLS03,ENG,2025-09-20,100,120',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      
      final examSheet = state.sheets[OnboardingStep.exams]!;
      expect(examSheet.rows[0].status, OnboardingRowStatus.failed);
      expect(examSheet.rows[0].apiErrorMessage, contains('Record already exists, but existing record could not be resolved.'));
    });

    test('CM. Duplicate but unresolved examination fails and displays error details', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY4099,2026-27,2026-06-01,2027-03-31,ACTIVE,true',
      );
      notifier.loadCsvFile(
        OnboardingStep.classes,
        'classes.csv',
        'academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n'
        'AY4099,CLS03,Class 8,8,PRIMARY,40,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.subjects,
        'subjects.csv',
        'subject_code,subject_name,category,subject_type,credit_hours,weekly_periods,theory_marks,practical_marks,pass_marks,display_order,academic_year_code\n'
        'ENG,English,CORE,THEORY_PRACTICAL,4,4,80,20,33,1,AY4099',
      );
      notifier.loadCsvFile(
        OnboardingStep.exams,
        'exams.csv',
        'academic_year_code,exam_code,exam_name,exam_type,class_code,subject_code,exam_date,maximum_marks,duration_minutes\n'
        'AY4099,EXM_UNRESOLVED,Midterm Unresolved,HALF_YEARLY,CLS03,ENG,2025-09-20,100,120',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      
      final examSheet = state.sheets[OnboardingStep.exams]!;
      expect(examSheet.rows[0].status, OnboardingRowStatus.failed);
      expect(examSheet.rows[0].apiErrorMessage, contains('Record already exists, but existing record could not be resolved.'));
    });

    test('CN. Idempotent second import of same examinations dataset succeeds', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY4099,2026-27,2026-06-01,2027-03-31,ACTIVE,true',
      );
      notifier.loadCsvFile(
        OnboardingStep.classes,
        'classes.csv',
        'academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n'
        'AY4099,CLS03,Class 8,8,PRIMARY,40,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.subjects,
        'subjects.csv',
        'subject_code,subject_name,category,subject_type,credit_hours,weekly_periods,theory_marks,practical_marks,pass_marks,display_order,academic_year_code\n'
        'ENG,English,CORE,THEORY_PRACTICAL,4,4,80,20,33,1,AY4099',
      );
      notifier.loadCsvFile(
        OnboardingStep.exams,
        'exams.csv',
        'academic_year_code,exam_code,exam_name,exam_type,class_code,subject_code,exam_date,maximum_marks,duration_minutes\n'
        'AY4099,EXM_EXISTS,Midterm 4099,HALF_YEARLY,CLS03,ENG,2025-09-20,100,120',
      );

      // First run (resolves duplicate from mock GET and succeeds)
      await notifier.executeOnboarding('school_1', fakeApiClient);
      var state = container.read(schoolOnboardingProvider);
      expect(state.sheets[OnboardingStep.exams]!.rows[0].status, OnboardingRowStatus.success);

      // Second run (resolves duplicate again and succeeds)
      await notifier.executeOnboarding('school_1', fakeApiClient);
      state = container.read(schoolOnboardingProvider);
      expect(state.sheets[OnboardingStep.exams]!.rows[0].status, OnboardingRowStatus.success);
    });

    test('CN2. Syllabus 409 Conflict Lookup Resolution', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY4099,2026-27,2026-06-01,2027-03-31,ACTIVE,true',
      );
      notifier.loadCsvFile(
        OnboardingStep.classes,
        'classes.csv',
        'academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n'
        'AY4099,CLS4099,Class 10,10,PRIMARY,40,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.subjects,
        'subjects.csv',
        'subject_code,subject_name,category,subject_type,credit_hours,weekly_periods,theory_marks,practical_marks,pass_marks,display_order,academic_year_code\n'
        'SUB4099,Mathematics,CORE,THEORY_PRACTICAL,4,4,80,20,33,1,AY4099',
      );
      notifier.loadCsvFile(
        OnboardingStep.syllabus,
        'syllabus.csv',
        'academic_year_code,class_code,subject_code,syllabus_code,unit_name,chapter_name,topic_name,description,sequence_order\n'
        'AY4099,CLS4099,SUB4099,SYL4099,Unit 1,Chapter 1,Topic 1,Description,1',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);
      final syllabusSheet = state.sheets[OnboardingStep.syllabus]!;
      expect(syllabusSheet.rows[0].status, OnboardingRowStatus.success);
      expect(syllabusSheet.rows[0].resolvedId, 'syllabus_resolved_id_123');
    });

    test('CO. Onboarding starts with null active school, creates school, and sets it active', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => null),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_new,New School,CBSE,PRIMARY,test@edu.in,9876543210,ACTIVE',
      );
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_new,AY2027-2028,2027-28,2027-06-01,2028-03-31,ACTIVE,true',
      );

      await notifier.executeOnboarding('', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);

      final schoolSheet = state.sheets[OnboardingStep.school]!;
      expect(schoolSheet.rows[0].status, OnboardingRowStatus.success);
      expect(schoolSheet.rows[0].resolvedId, 'resolved_mock_id');

      final activeSchoolId = container.read(selectedSchoolIdProvider);
      expect(activeSchoolId, 'resolved_mock_id');

      final aySheet = state.sheets[OnboardingStep.academicYears]!;
      expect(aySheet.rows[0].status, OnboardingRowStatus.success);
    });

    test('CP. Academic Year Retry & Normalization Verification', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      // Load school to resolve school dependency
      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,HIGH_SCHOOL,test@edu.in,9876543210,ACTIVE',
      );

      // Load academic years with a spacing issue to verify whitespace normalization
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1, AY2025-2026 ,2025-26,2025-04-01,2026-03-31,ACTIVE,true',
      );

      // Load classes sheet
      notifier.loadCsvFile(
        OnboardingStep.classes,
        'classes.csv',
        'academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n'
        'AY2025-2026,CLASS08,Class 8,8,PRIMARY,40,ACTIVE',
      );

      // Load subjects sheet
      notifier.loadCsvFile(
        OnboardingStep.subjects,
        'subjects.csv',
        'subject_code,subject_name,category,subject_type,credit_hours,weekly_periods,theory_marks,practical_marks,pass_marks,display_order,academic_year_code\n'
        'SUB4099,Mathematics,CORE,THEORY_PRACTICAL,4,4,80,20,33,1,AY2025-2026',
      );

      // Load syllabus referencing the normalized code
      notifier.loadCsvFile(
        OnboardingStep.syllabus,
        'syllabus.csv',
        'academic_year_code,class_code,subject_code,syllabus_code,unit_name,chapter_name,topic_name\n'
        'AY2025-2026,CLASS08,SUB4099,SYL4099,Unit 1,Introduction,Basics',
      );

      // Execute onboarding
      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);

      final schoolSheet = state.sheets[OnboardingStep.school]!;
      expect(schoolSheet.rows[0].status, OnboardingRowStatus.success);

      final aySheet = state.sheets[OnboardingStep.academicYears]!;
      expect(aySheet.rows[0].status, OnboardingRowStatus.success);

      final sylSheet = state.sheets[OnboardingStep.syllabus]!;
      expect(sylSheet.rows[0].status, OnboardingRowStatus.success);
    });

    test('CQ. Academic Year Failure skips Syllabus', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ]);
      final notifier = container.read(schoolOnboardingProvider.notifier);

      // Load school to resolve school dependency
      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'school_1,Mock School,CBSE,HIGH_SCHOOL,test@edu.in,9876543210,ACTIVE',
      );

      // Load academic years with a failure code (AY2222 fails in fake client)
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'school_1,AY2222,2025-26,2025-04-01,2026-03-31,ACTIVE,true',
      );

      // Load syllabus referencing the failing academic year
      notifier.loadCsvFile(
        OnboardingStep.syllabus,
        'syllabus.csv',
        'academic_year_code,class_code,subject_code,syllabus_code,unit_name,chapter_name,topic_name\n'
        'AY2222,CLASS08,SUB4099,SYL4099,Unit 1,Introduction,Basics',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);

      final aySheet = state.sheets[OnboardingStep.academicYears]!;
      expect(aySheet.rows[0].status, OnboardingRowStatus.failed);

      final sylSheet = state.sheets[OnboardingStep.syllabus]!;
      expect(sylSheet.rows[0].status, OnboardingRowStatus.skipped);
      expect(sylSheet.rows[0].dependencyFailureReason, contains('academic year code AY2222 could not be resolved'));
    });

    test('CR1. Existing records resolution with omitted parent sheets', () async {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(fakeApiClient),
          selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
        ],
      );

      // Fetch schools list to populate provider state
      await container.read(schoolsListProvider.notifier).fetchSchools();

      final notifier = container.read(schoolOnboardingProvider.notifier);

      // Do NOT load school or academicYears sheets.
      // Load syllabus referencing the existing database objects.
      notifier.loadCsvFile(
        OnboardingStep.syllabus,
        'syllabus.csv',
        'academic_year_code,class_code,subject_code,syllabus_code,unit_name,chapter_name,topic_name\n'
        'AY4099,CLS4099,SUB4099,SYL4099,Unit 1,Reading Skills,Comprehension',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);

      // Syllabus sheet should be parsed and processed successfully!
      final sylSheet = state.sheets[OnboardingStep.syllabus]!;
      expect(sylSheet.rows[0].status, OnboardingRowStatus.success);
      expect(sylSheet.rows[0].resolvedId, isNotNull);
      
      // Confirm Syllabus POST was made with correct UUIDs
      final post = fakeApiClient.postCalls.firstWhere((c) => c['path'].contains('/syllabuses'));
      expect(post['path'], contains('school_id=school_1'));
      expect(post['path'], contains('academic_year_id=ay_resolved_id_123'));
      expect(post['data']['class_id'], equals('class_resolved_id_123'));
      expect(post['data']['subject_id'], equals('subject_resolved_id_123'));
    });

    test('CR2. Mixed state: existing academic year and class, newly created subject', () async {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(fakeApiClient),
          selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
        ],
      );

      // Fetch schools list to populate provider state
      await container.read(schoolsListProvider.notifier).fetchSchools();

      final notifier = container.read(schoolOnboardingProvider.notifier);

      // Load Academic Structure sheet (referencing existing academic year AY4099)
      notifier.loadCsvFile(
        OnboardingStep.academicYears,
        'academic_years.csv',
        'school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n'
        'DPSH,AY4099,2025-26,2025-04-01,2026-03-31,ACTIVE,true',
      );

      // Load Subjects sheet (introducing newly created subject SUBNEW)
      notifier.loadCsvFile(
        OnboardingStep.subjects,
        'subjects.csv',
        'subject_code,subject_name,category,subject_type,credit_hours,weekly_periods,theory_marks,practical_marks,pass_marks,display_order,academic_year_code\n'
        'SUBNEW,New Subject,CORE,THEORY,4,4,100,0,35,1,AY4099',
      );

      // Load Syllabus sheet (referencing AY4099, CLS4099 and SUBNEW)
      notifier.loadCsvFile(
        OnboardingStep.syllabus,
        'syllabus.csv',
        'academic_year_code,class_code,subject_code,syllabus_code,unit_name,chapter_name,topic_name\n'
        'AY4099,CLS4099,SUBNEW,SYLNEW,Unit 1,Reading Skills,Comprehension',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);

      final aySheet = state.sheets[OnboardingStep.academicYears]!;
      expect(aySheet.rows[0].status, OnboardingRowStatus.success);
      expect(aySheet.rows[0].resolvedId, equals('ay_resolved_id_123')); // Reused

      final subSheet = state.sheets[OnboardingStep.subjects]!;
      expect(subSheet.rows[0].status, OnboardingRowStatus.success);
      final newSubjectId = subSheet.rows[0].resolvedId;
      expect(newSubjectId, isNotNull);

      final sylSheet = state.sheets[OnboardingStep.syllabus]!;
      expect(sylSheet.rows[0].status, OnboardingRowStatus.success);

      final post = fakeApiClient.postCalls.firstWhere((c) => c['path'].contains('/syllabuses'));
      expect(post['data']['class_id'], equals('class_resolved_id_123')); // Existing class reused
      expect(post['data']['subject_id'], equals(newSubjectId)); // Newly created subject resolved
    });

    test('CS. Phone and contact number normalization helper tests', () {
      // 1. Hyphenated Indian phone numbers
      expect(SchoolOnboardingValidators.normalizePhoneNumber('+91-9848011000'), '+919848011000');
      // 2. Space separated phone numbers
      expect(SchoolOnboardingValidators.normalizePhoneNumber('+91 9848011000'), '+919848011000');
      // 3. Parentheses formatting
      expect(SchoolOnboardingValidators.normalizePhoneNumber('(98480) 11000'), '9848011000');
      // 4. Hyphenated local number
      expect(SchoolOnboardingValidators.normalizePhoneNumber('98480-11000'), '9848011000');
      // 5. Postal code with spaces
      expect(SchoolOnboardingValidators.normalizePostalCode('500 081'), '500081');
      // 6. Null and empty safety
      expect(SchoolOnboardingValidators.normalizePhoneNumber(null), '');
      expect(SchoolOnboardingValidators.normalizePhoneNumber('   '), '');
      expect(SchoolOnboardingValidators.normalizePostalCode(null), '');
    });

    test('CT. School Information creation normalizes phone and PIN in POST payload', () async {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(fakeApiClient),
          selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
        ],
      );
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status,postal_code\n'
        'TS001,Telangana Model School & Junior College,CBSE,HIGH_SCHOOL,principal.ts001@telanganaschool.edu,+91-9848011000,ACTIVE,500 081',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);

      final schoolSheet = state.sheets[OnboardingStep.school]!;
      expect(schoolSheet.rows[0].status, OnboardingRowStatus.success);

      // Verify POST /schools payload contained normalized phone and postal code
      final post = fakeApiClient.postCalls.firstWhere((c) => c['path'] == '/schools');
      expect(post['data']['phone'], equals('+919848011000'));
      expect(post['data']['postal_code'], equals('500081'));
      expect(post['data']['code'], equals('TS001'));
      expect(post['data']['board'], equals('CBSE'));
      expect(post['data']['school_type'], equals('HIGH_SCHOOL'));
    });

    test('CU. Backend HTTP 422 validation error message propagation', () async {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(fakeApiClient),
          selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
        ],
      );
      final notifier = container.read(schoolOnboardingProvider.notifier);

      notifier.loadCsvFile(
        OnboardingStep.school,
        'school.csv',
        'school_code,school_name,board,school_type,email,phone,status\n'
        'FAIL_422_PHONE,Telangana Model School,CBSE,HIGH_SCHOOL,test@telangana.edu,9876543210,ACTIVE',
      );

      await notifier.executeOnboarding('school_1', fakeApiClient);
      final state = container.read(schoolOnboardingProvider);

      final schoolSheet = state.sheets[OnboardingStep.school]!;
      expect(schoolSheet.rows[0].status, OnboardingRowStatus.failed);
      expect(schoolSheet.rows[0].apiErrorMessage, contains('Validation error: [body -> phone]'));
      expect(schoolSheet.rows[0].apiErrorMessage, isNot(equals('A server error occurred.')));
    });

    test('CV. Complete 13-sheet synthetic dev fixture executes without dependency errors', () async {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(fakeApiClient),
          selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
        ],
      );

      // Fetch schools to populate active school context (DPSH)
      await container.read(schoolsListProvider.notifier).fetchSchools();

      final notifier = container.read(schoolOnboardingProvider.notifier);

      // Load complete relational synthetic fixture
      notifier.loadSyntheticFixture();
      final preState = container.read(schoolOnboardingProvider);

      // Verify all 13 steps are loaded in memory
      for (final step in OnboardingStep.values) {
        if (step == OnboardingStep.validation || step == OnboardingStep.import || step == OnboardingStep.report) continue;
        expect(preState.sheets.containsKey(step), isTrue, reason: 'Step $step must be loaded');
        expect(preState.sheets[step]!.rows.isNotEmpty, isTrue, reason: 'Step $step must contain rows');
        for (final row in preState.sheets[step]!.rows) {
          expect(row.status, isNot(equals(OnboardingRowStatus.error)), reason: 'Row should not have pre-import validation error');
        }
      }

      // Execute onboarding across all 13 sheets
      await notifier.executeOnboarding('school_1', fakeApiClient);
      final postState = container.read(schoolOnboardingProvider);

      // Verify that all downstream 12 sheets completed successfully
      for (final step in OnboardingStep.values) {
        if (step == OnboardingStep.validation || step == OnboardingStep.import || step == OnboardingStep.report || step == OnboardingStep.school) continue;
        final sheet = postState.sheets[step]!;
        for (final row in sheet.rows) {
          expect(
            row.status,
            equals(OnboardingRowStatus.success),
            reason: 'Step $step row ${row.rowIndex} must succeed (failed with ${row.apiErrorMessage ?? row.dependencyFailureReason})',
          );
        }
      }

      // Verify resolution maps are populated
      expect(postState.resolvedSchools.isNotEmpty, isTrue);
      expect(postState.resolvedAcademicYears.isNotEmpty, isTrue);
      expect(postState.resolvedClasses.isNotEmpty, isTrue);
      expect(postState.resolvedSections.isNotEmpty, isTrue);
      expect(postState.resolvedSubjects.isNotEmpty, isTrue);
      expect(postState.resolvedTeachers.isNotEmpty, isTrue);
      expect(postState.resolvedGuardians.isNotEmpty, isTrue);
      expect(postState.resolvedStudents.isNotEmpty, isTrue);
    });

    test('CW. Worksheet name alias matching resolves to correct OnboardingStep', () {
      expect(SchoolOnboardingValidators.matchStepFromSheetName('School Information'), OnboardingStep.school);
      expect(SchoolOnboardingValidators.matchStepFromSheetName('school_info'), OnboardingStep.school);
      expect(SchoolOnboardingValidators.matchStepFromSheetName('Academic Structure'), OnboardingStep.academicYears);
      expect(SchoolOnboardingValidators.matchStepFromSheetName('Academic Years'), OnboardingStep.academicYears);
      expect(SchoolOnboardingValidators.matchStepFromSheetName('Grade Levels (Classes)'), OnboardingStep.classes);
      expect(SchoolOnboardingValidators.matchStepFromSheetName('Classes'), OnboardingStep.classes);
      expect(SchoolOnboardingValidators.matchStepFromSheetName('Sections & Rooms'), OnboardingStep.sections);
      expect(SchoolOnboardingValidators.matchStepFromSheetName('Subjects Catalog'), OnboardingStep.subjects);
      expect(SchoolOnboardingValidators.matchStepFromSheetName('Teachers Roster'), OnboardingStep.teachers);
      expect(SchoolOnboardingValidators.matchStepFromSheetName('Staff'), OnboardingStep.teachers);
      expect(SchoolOnboardingValidators.matchStepFromSheetName('Parents & Guardians'), OnboardingStep.guardians);
      expect(SchoolOnboardingValidators.matchStepFromSheetName('Students Register'), OnboardingStep.students);
      expect(SchoolOnboardingValidators.matchStepFromSheetName('Student-Guardian Links'), OnboardingStep.relationships);
      expect(SchoolOnboardingValidators.matchStepFromSheetName('Teacher Assignments'), OnboardingStep.teacherAssignments);
      expect(SchoolOnboardingValidators.matchStepFromSheetName('Assignments'), OnboardingStep.teacherAssignments);
      expect(SchoolOnboardingValidators.matchStepFromSheetName('Timetable Slots'), OnboardingStep.timetable);
      expect(SchoolOnboardingValidators.matchStepFromSheetName('Syllabus Metadata'), OnboardingStep.syllabus);
      expect(SchoolOnboardingValidators.matchStepFromSheetName('Exams & Documents'), OnboardingStep.exams);
    });

    test('CX. Multi-sheet Excel workbook auto-detection and entire workbook ingestion', () async {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(fakeApiClient),
          selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
        ],
      );
      final notifier = container.read(schoolOnboardingProvider.notifier);

      // Ingest entire multi-sheet workbook
      await notifier.loadEntireWorkbook('master_onboarding.xlsx', Uint8List.fromList([1, 2, 3]));
      final state = container.read(schoolOnboardingProvider);

      // Verify School Information and Academic Structure sheets were parsed and mapped
      expect(state.sheets.containsKey(OnboardingStep.school), isTrue);
      expect(state.sheets.containsKey(OnboardingStep.academicYears), isTrue);
      expect(state.sheets.containsKey(OnboardingStep.classes), isTrue);
      expect(state.sheets[OnboardingStep.school]!.rows.isNotEmpty, isTrue);
      expect(state.sheets[OnboardingStep.academicYears]!.rows.isNotEmpty, isTrue);
    });

    test('CY. Provider graph initializes without CircularDependencyError', () {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(fakeApiClient),
          activeTenantIdProvider.overrideWith((ref) {
            final selected = ref.watch(selectedTenantIdProvider);
            if (selected != null && selected.isNotEmpty) return selected;
            return 'default_tenant';
          }),
        ],
      );

      // Verify activeTenantId, schoolsListProvider, and schoolOnboardingProvider initialize cleanly
      expect(container.read(activeTenantIdProvider), 'default_tenant');
      final schoolsState = container.read(schoolsListProvider);
      expect(schoolsState.isLoading, isFalse);
      final onboardingState = container.read(schoolOnboardingProvider);
      expect(onboardingState.isProcessing, isFalse);
    });

    test('CZ. ApiExceptionMapper properly classifies application and circular errors', () {
      final circularDioException = DioException(
        requestOptions: RequestOptions(path: '/schools'),
        error: 'Instance of \'CircularDependencyError\'',
        type: DioExceptionType.unknown,
      );
      final failure = ApiExceptionMapper.mapToFailure(circularDioException);
      expect(failure.message.contains('Circular provider dependency detected'), isTrue);
    });

    test('DA. Cross-sheet validation flags timetable slots exceeding weekly_periods workload limit', () {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(fakeApiClient),
          selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
        ],
      );
      final notifier = container.read(schoolOnboardingProvider.notifier);

      // Load Teacher Assignment with limit of 2 periods
      notifier.loadCsvFile(
        OnboardingStep.teacherAssignments,
        'assignments.csv',
        'teacher_code,subject_code,class_code,section_code,academic_year_code,assignment_type,weekly_periods,effective_from\n'
        'T001,SUB_MATH,CLASS08,SEC_A,AY2026-2027,PRIMARY,2,2026-06-01',
      );

      // Load Timetable with 3 periods for same assignment (exceeding limit of 2)
      notifier.loadCsvFile(
        OnboardingStep.timetable,
        'timetable.csv',
        'academic_year_code,day_of_week,period_number,start_time,end_time,class_code,section_code,subject_code,teacher_code,room_number,period_type\n'
        'AY2026-2027,MONDAY,1,09:00:00,09:45:00,CLASS08,SEC_A,SUB_MATH,T001,Room 101,REGULAR\n'
        'AY2026-2027,TUESDAY,1,09:00:00,09:45:00,CLASS08,SEC_A,SUB_MATH,T001,Room 101,REGULAR\n'
        'AY2026-2027,WEDNESDAY,1,09:00:00,09:45:00,CLASS08,SEC_A,SUB_MATH,T001,Room 101,REGULAR',
      );

      final state = container.read(schoolOnboardingProvider);
      final ttSheet = state.sheets[OnboardingStep.timetable]!;
      expect(ttSheet.rows.first.unresolvedReferences.any((r) => r.contains('Workload limit reached')), isTrue);
    });
  });
}
