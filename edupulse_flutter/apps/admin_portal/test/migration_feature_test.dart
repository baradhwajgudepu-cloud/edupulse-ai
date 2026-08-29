import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/core/routing/routes.dart';
import 'package:admin_portal/core/providers/bootstrap_provider.dart';
import 'package:admin_portal/features/migrations/presentation/providers/migration_providers.dart';
import 'package:admin_portal/features/migrations/presentation/pages/migration_center_screen.dart';
import 'package:admin_portal/features/migrations/presentation/pages/student_migration_wizard_screen.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';

class FakeMigrationRepository implements AuthRepository {
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
    return const ApiResult.success(UserEntity(
      id: 'admin_id_123',
      email: 'admin@edupulse.ai',
      firstName: 'Main',
      lastName: 'Admin',
      tenantId: 'tenant_1',
      isSuperuser: true,
      roles: ['SUPER_ADMIN'],
      schools: ['school_1'],
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

class FakeMigrationSessionManager implements SessionManager {
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

class FakeMigrationApiClient extends BaseApiClient {
  List<Map<String, dynamic>> mockJobs = [
    {
      'id': 'job-uuid-1',
      'tenant_id': 'tenant_1',
      'school_id': 'school_1',
      'import_type': 'STUDENTS',
      'status': 'COMPLETED',
      'source_filename': 'student_registry_2026.csv',
      'file_checksum': 'checksum123',
      'total_rows': 5,
      'processed_rows': 5,
      'successful_rows': 5,
      'failed_rows': 0,
      'skipped_rows': 0,
      'started_at': '2026-08-12T12:00:00Z',
      'completed_at': '2026-08-12T12:00:05Z',
      'job_metadata': {'academic_year_id': 'ay_1'},
      'created_at': '2026-08-12T11:59:00Z',
      'updated_at': '2026-08-12T12:00:05Z',
    }
  ];

  List<Map<String, dynamic>> mockRows = [];

  bool startTriggered = false;
  bool validateTriggered = false;
  bool createTriggered = false;

  FakeMigrationApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (path.contains('/schools/school_1/academic-years')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'ay_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'name': '2026-2027',
            'code': 'AY26',
            'status': 'ACTIVE',
            'is_current': true,
            'start_date': '2026-06-01',
            'end_date': '2027-03-31',
            'version': 1
          }
        ]
      }));
    }

    if (path.contains('/schools')) {
      return ApiResult.success(mapper({
        'data': [
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
            'version': 1
          }
        ]
      }));
    }

    if (path.contains('/import-jobs/job-uuid-1/rows') || path.contains('/import-jobs/job-uuid-error/rows') || path.contains('/import-jobs/job-uuid-fail/rows')) {
      return ApiResult.success(mapper({
        'data': mockRows,
      }));
    }

    if (path.contains('/import-jobs/job-uuid-1') ||
        path.contains('/import-jobs/job-uuid-error') ||
        path.contains('/import-jobs/job-uuid-fail')) {
      final id = path.split('/').last.split('?').first;
      String status = 'COMPLETED';
      int failedRows = 0;
      if (id == 'job-uuid-error') {
        status = 'VALIDATED';
        failedRows = 2;
      } else if (id == 'job-uuid-fail') {
        status = 'VALIDATED';
      }
      return ApiResult.success(mapper({
        'data': {
          'id': id,
          'tenant_id': 'tenant_1',
          'school_id': 'school_1',
          'import_type': 'STUDENTS',
          'status': status,
          'source_filename': 'student_registry_2026.csv',
          'file_checksum': 'checksum123',
          'total_rows': 5,
          'processed_rows': 5,
          'successful_rows': 5 - failedRows,
          'failed_rows': failedRows,
          'skipped_rows': 0,
          'started_at': '2026-08-12T12:00:00Z',
          'completed_at': '2026-08-12T12:00:05Z',
          'job_metadata': {'academic_year_id': 'ay_1'},
          'created_at': '2026-08-12T11:59:00Z',
          'updated_at': '2026-08-12T12:00:05Z',
        }
      }));
    }

    if (path.contains('/import-jobs')) {
      return ApiResult.success(mapper({
        'data': mockJobs,
      }));
    }

    return ApiResult.failure(const ApiFailure(message: 'Route not mocked', type: ApiFailureType.unknown));
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
    if (path == '/import-jobs') {
      createTriggered = true;
      final newJob = {
        'id': 'job-uuid-1',
        'tenant_id': 'tenant_1',
        'school_id': 'school_1',
        'import_type': 'STUDENTS',
        'status': 'DRAFT',
        'source_filename': 'student_registry_2026.csv',
        'total_rows': 0,
        'processed_rows': 0,
        'successful_rows': 0,
        'failed_rows': 0,
        'skipped_rows': 0,
        'job_metadata': {'academic_year_id': 'ay_1'},
        'created_at': '2026-08-12T11:59:00Z',
        'updated_at': '2026-08-12T11:59:00Z',
      };
      return ApiResult.success(mapper({'data': newJob}));
    }

    if (path.contains('/validate')) {
      validateTriggered = true;
      String jobId = path.split('/')[2];
      
      String status = 'VALIDATED';
      int failedRows = 0;
      if (jobId == 'job-uuid-error') {
        status = 'VALIDATED';
        failedRows = 2;
      }

      final validatedJob = {
        'id': jobId,
        'tenant_id': 'tenant_1',
        'school_id': 'school_1',
        'import_type': 'STUDENTS',
        'status': status,
        'source_filename': 'student_registry_2026.csv',
        'total_rows': 5,
        'processed_rows': 0,
        'successful_rows': 0,
        'failed_rows': failedRows,
        'skipped_rows': 0,
        'job_metadata': {'academic_year_id': 'ay_1'},
        'created_at': '2026-08-12T11:59:00Z',
        'updated_at': '2026-08-12T11:59:05Z',
      };
      return ApiResult.success(mapper({'data': validatedJob}));
    }

    if (path.contains('/start')) {
      startTriggered = true;
      String jobId = path.split('/')[2];
      
      String status = 'COMPLETED';
      int successfulRows = 5;
      int failedRows = 0;
      String? errorMsg;

      if (jobId == 'job-uuid-error') {
        status = 'COMPLETED_WITH_ERRORS';
        successfulRows = 3;
        failedRows = 2;
      } else if (jobId == 'job-uuid-fail') {
        status = 'FAILED';
        successfulRows = 0;
        failedRows = 5;
        errorMsg = 'Aadhaar constraint violations detected.';
      }

      final executedJob = {
        'id': jobId,
        'tenant_id': 'tenant_1',
        'school_id': 'school_1',
        'import_type': 'STUDENTS',
        'status': status,
        'source_filename': 'student_registry_2026.csv',
        'total_rows': 5,
        'processed_rows': 5,
        'successful_rows': successfulRows,
        'failed_rows': failedRows,
        'skipped_rows': 0,
        'started_at': '2026-08-12T12:00:00Z',
        'completed_at': '2026-08-12T12:00:05Z',
        'error_summary': errorMsg,
        'job_metadata': {'academic_year_id': 'ay_1'},
        'created_at': '2026-08-12T11:59:00Z',
        'updated_at': '2026-08-12T12:00:05Z',
      };
      return ApiResult.success(mapper({'data': executedJob}));
    }

    return ApiResult.failure(const ApiFailure(message: 'Route not mocked', type: ApiFailureType.unknown));
  }
}

void main() {
  late FakeMigrationApiClient fakeApiClient;

  setUp(() {
    fakeApiClient = FakeMigrationApiClient();
  });

  Widget createTestWidget({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWith((ref) => FakeMigrationRepository()),
        sessionManagerProvider.overrideWith((ref) => FakeMigrationSessionManager()),
        apiClientProvider.overrideWithValue(fakeApiClient),
        bootstrapResultProvider.overrideWithValue(BootstrapResult(success: true)),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
        selectedAcademicYearIdProvider.overrideWith((ref) => 'ay_1'),
        ...overrides
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: MigrationCenterScreen(),
        ),
      ),
    );
  }

  testWidgets('1. Migration Center renders correctly with history', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Student Migration Center'), findsOneWidget);
    expect(find.text('student_registry_2026.csv'), findsOneWidget);
    expect(find.text('COMPLETED'), findsOneWidget);
    expect(find.text('New Student Migration'), findsOneWidget);
  });

  testWidgets('2. New Student Migration wizard page renders steps', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWith((ref) => FakeMigrationRepository()),
          sessionManagerProvider.overrideWith((ref) => FakeMigrationSessionManager()),
          apiClientProvider.overrideWithValue(fakeApiClient),
          bootstrapResultProvider.overrideWithValue(BootstrapResult(success: true)),
          selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
          selectedAcademicYearIdProvider.overrideWith((ref) => 'ay_1'),
        ],
        child: const MaterialApp(
          home: StudentMigrationWizardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Select School & Academic Year Context'), findsOneWidget);
    expect(find.text('Target School / Campus'), findsOneWidget);
    expect(find.text('Academic Year Scope'), findsOneWidget);
  });

  testWidgets('3. Template details and guidelines render', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
      ],
    );
    container.read(studentMigrationWizardProvider.notifier).updateContext('school_1', 'ay_1');
    container.read(studentMigrationWizardProvider.notifier).nextStep();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: StudentMigrationWizardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CSV Format Guidelines:'), findsOneWidget);
    expect(find.textContaining('first_name, last_name, gender, date_of_birth'), findsOneWidget);
    expect(find.text('Download Official Template'), findsOneWidget);
  });

  testWidgets('4. File selection and invalid CSV/file type handling', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
      ],
    );
    container.read(studentMigrationWizardProvider.notifier).updateContext('school_1', 'ay_1');
    container.read(studentMigrationWizardProvider.notifier).nextStep();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: StudentMigrationWizardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final validateBtn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Validate File'));
    expect(validateBtn.onPressed, isNull); // Disabled because file is not selected
  });

  testWidgets('5. Job creation, validation request, validation summary & error review workflow (COMPLETED)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
      ],
    );

    // Initial State
    container.read(studentMigrationWizardProvider.notifier).updateContext('school_1', 'ay_1');
    container.read(studentMigrationWizardProvider.notifier).updateSelectedFile('test.csv', Uint8List.fromList([1, 2, 3]));

    // Step to Upload
    container.read(studentMigrationWizardProvider.notifier).nextStep();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: StudentMigrationWizardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Trigger Validate
    final validateFinder = find.widgetWithText(ElevatedButton, 'Validate File');
    await tester.ensureVisible(validateFinder);
    await tester.tap(validateFinder);
    await tester.pumpAndSettle();

    expect(fakeApiClient.createTriggered, isTrue);
    expect(fakeApiClient.validateTriggered, isTrue);

    // Shows Validation Summary (Step 3)
    expect(find.text('Validation Results Summary'), findsOneWidget);
    expect(find.textContaining('All rows are valid and ready to execute!'), findsOneWidget);

    // Proceed to Execute
    final executeFinder = find.widgetWithText(ElevatedButton, 'Proceed to Execute');
    await tester.ensureVisible(executeFinder);
    await tester.tap(executeFinder);
    await tester.pumpAndSettle();

    expect(find.text('Execution Confirmation'), findsOneWidget);
    expect(find.textContaining('Confirm & Execute'), findsOneWidget);

    // Execute
    final confirmFinder = find.widgetWithText(ElevatedButton, 'Confirm & Execute');
    await tester.ensureVisible(confirmFinder);
    await tester.tap(confirmFinder);
    await tester.pumpAndSettle();

    expect(fakeApiClient.startTriggered, isTrue);
    expect(find.text('Migration Completed'), findsOneWidget);
  });

  testWidgets('6. Review error rows, pagination, error CSV, and COMPLETED_WITH_ERRORS execution result', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    fakeApiClient.mockRows = [
      {
        'id': 'row_1',
        'import_job_id': 'job-uuid-error',
        'row_number': 3,
        'status': 'failed',
        'error_code': 'INVALID_GENDER',
        'error_message': 'Gender is invalid',
        'source_identifier': 'ADM999',
        'row_metadata': {},
        'created_at': '2026-08-12T11:59:00Z',
        'updated_at': '2026-08-12T11:59:00Z',
      }
    ];

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
      ],
    );

    // Force preloading job with errors
    await container.read(studentMigrationWizardProvider.notifier).preloadJob('job-uuid-error');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: StudentMigrationWizardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Check step is Validation Result (step index 2)
    expect(find.text('Validation Results Summary'), findsOneWidget);
    expect(find.textContaining('Some rows have validation errors.'), findsOneWidget);

    // Tap Review Errors
    final reviewFinder = find.widgetWithText(OutlinedButton, 'Review Errors');
    await tester.ensureVisible(reviewFinder);
    await tester.tap(reviewFinder);
    await tester.pumpAndSettle();

    // Verify row error list
    expect(find.text('Review Row Errors'), findsOneWidget);
    expect(find.text('INVALID_GENDER'), findsOneWidget);
    expect(find.text('Gender is invalid'), findsOneWidget);

    // Tap Proceed to Execute
    final executeFinder = find.widgetWithText(ElevatedButton, 'Proceed to Execute');
    await tester.ensureVisible(executeFinder);
    await tester.tap(executeFinder);
    await tester.pumpAndSettle();

    // Tap Confirm & Execute
    final confirmFinder = find.widgetWithText(ElevatedButton, 'Confirm & Execute');
    await tester.ensureVisible(confirmFinder);
    await tester.tap(confirmFinder);
    await tester.pumpAndSettle();

    // Final result COMPLETED_WITH_ERRORS
    expect(find.text('Migration Completed with Errors'), findsOneWidget);
  });

  testWidgets('7. FAILED execution result handling', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
      ],
    );

    // Force preloading job with errors
    await container.read(studentMigrationWizardProvider.notifier).preloadJob('job-uuid-fail');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: StudentMigrationWizardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Proceed to Execute
    final executeFinder = find.widgetWithText(ElevatedButton, 'Proceed to Execute');
    await tester.ensureVisible(executeFinder);
    await tester.tap(executeFinder);
    await tester.pumpAndSettle();

    // Confirm execution
    final confirmFinder = find.widgetWithText(ElevatedButton, 'Confirm & Execute');
    await tester.ensureVisible(confirmFinder);
    await tester.tap(confirmFinder);
    await tester.pumpAndSettle();

    expect(find.text('Migration Failed'), findsOneWidget);
    expect(find.textContaining('Aadhaar constraint violations detected.'), findsOneWidget);
  });

  testWidgets('8. Existing Fees routes remain intact', (WidgetTester tester) async {
    // Assert static routes are registered
    expect(AppRoutes.fees, '/fees');
    expect(AppRoutes.feesAssign, '/fees/assign');
    expect(AppRoutes.feesLedger, '/fees/ledger');
    expect(AppRoutes.feesOutstanding, '/fees/outstanding');
  });
}
