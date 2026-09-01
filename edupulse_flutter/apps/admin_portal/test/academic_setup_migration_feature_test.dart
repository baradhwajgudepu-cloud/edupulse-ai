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
import 'package:admin_portal/features/migrations/presentation/pages/academic_setup_migration_wizard_screen.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';

class FakeAcademicSetupRepository implements AuthRepository {
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

class FakeAcademicSetupSessionManager implements SessionManager {
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

class FakeAcademicSetupApiClient extends BaseApiClient {
  List<Map<String, dynamic>> mockJobs = [
    {
      'id': 'job-academic-uuid-1',
      'tenant_id': 'tenant_1',
      'school_id': 'school_1',
      'import_type': 'ACADEMIC_SETUP',
      'status': 'COMPLETED',
      'source_filename': 'academic_setup_registry_2026.csv',
      'file_checksum': 'checksum123',
      'total_rows': 4,
      'processed_rows': 4,
      'successful_rows': 4,
      'failed_rows': 0,
      'skipped_rows': 0,
      'started_at': '2026-08-12T12:00:00Z',
      'completed_at': '2026-08-12T12:00:05Z',
      'job_metadata': {},
      'created_at': '2026-08-12T11:59:00Z',
      'updated_at': '2026-08-12T12:00:05Z',
    }
  ];

  List<Map<String, dynamic>> mockRows = [];

  bool startTriggered = false;
  bool validateTriggered = false;
  bool createTriggered = false;
  String? lastImportTypeCreated;

  FakeAcademicSetupApiClient() : super(Dio());

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

    if (path.contains('/import-jobs/job-academic-uuid-1/rows') || 
        path.contains('/import-jobs/job-academic-uuid-validated/rows') || 
        path.contains('/import-jobs/job-academic-uuid-error/rows') || 
        path.contains('/import-jobs/job-academic-uuid-fail/rows')) {
      return ApiResult.success(mapper({
        'data': mockRows,
      }));
    }

    if (path.contains('/import-jobs/job-academic-uuid-1') ||
        path.contains('/import-jobs/job-academic-uuid-validated') ||
        path.contains('/import-jobs/job-academic-uuid-error') ||
        path.contains('/import-jobs/job-academic-uuid-fail')) {
      final id = path.split('/').last.split('?').first;
      String status = 'COMPLETED';
      int failedRows = 0;
      if (id == 'job-academic-uuid-error') {
        status = 'VALIDATED';
        failedRows = 2;
      } else if (id == 'job-academic-uuid-fail' || id == 'job-academic-uuid-validated') {
        status = 'VALIDATED';
      }
      return ApiResult.success(mapper({
        'data': {
          'id': id,
          'tenant_id': 'tenant_1',
          'school_id': 'school_1',
          'import_type': 'ACADEMIC_SETUP',
          'status': status,
          'source_filename': 'academic_setup_registry_2026.csv',
          'file_checksum': 'checksum123',
          'total_rows': 4,
          'processed_rows': 4,
          'successful_rows': 4 - failedRows,
          'failed_rows': failedRows,
          'skipped_rows': 0,
          'started_at': '2026-08-12T12:00:00Z',
          'completed_at': '2026-08-12T12:00:05Z',
          'job_metadata': {},
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
      if (data is Map<String, dynamic>) {
        lastImportTypeCreated = data['import_type'] as String?;
      }
      final newJob = {
        'id': 'job-academic-uuid-1',
        'tenant_id': 'tenant_1',
        'school_id': 'school_1',
        'import_type': lastImportTypeCreated ?? 'ACADEMIC_SETUP',
        'status': 'DRAFT',
        'source_filename': 'academic_setup_registry_2026.csv',
        'total_rows': 0,
        'processed_rows': 0,
        'successful_rows': 0,
        'failed_rows': 0,
        'skipped_rows': 0,
        'job_metadata': {},
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
      if (jobId == 'job-academic-uuid-error') {
        status = 'VALIDATED';
        failedRows = 2;
      }

      final validatedJob = {
        'id': jobId,
        'tenant_id': 'tenant_1',
        'school_id': 'school_1',
        'import_type': 'ACADEMIC_SETUP',
        'status': status,
        'source_filename': 'academic_setup_registry_2026.csv',
        'total_rows': 4,
        'processed_rows': 0,
        'successful_rows': 0,
        'failed_rows': failedRows,
        'skipped_rows': 0,
        'job_metadata': {},
        'created_at': '2026-08-12T11:59:00Z',
        'updated_at': '2026-08-12T11:59:05Z',
      };
      return ApiResult.success(mapper({'data': validatedJob}));
    }

    if (path.contains('/start')) {
      startTriggered = true;
      String jobId = path.split('/')[2];
      
      String status = 'COMPLETED';
      int successfulRows = 4;
      int failedRows = 0;
      String? errorMsg;

      if (jobId == 'job-academic-uuid-error') {
        status = 'COMPLETED_WITH_ERRORS';
        successfulRows = 2;
        failedRows = 2;
      } else if (jobId == 'job-academic-uuid-fail') {
        status = 'FAILED';
        successfulRows = 0;
        failedRows = 4;
        errorMsg = 'Academic Year start date exceeds end date constraint.';
      }

      final executedJob = {
        'id': jobId,
        'tenant_id': 'tenant_1',
        'school_id': 'school_1',
        'import_type': 'ACADEMIC_SETUP',
        'status': status,
        'source_filename': 'academic_setup_registry_2026.csv',
        'total_rows': 4,
        'processed_rows': 4,
        'successful_rows': successfulRows,
        'failed_rows': failedRows,
        'skipped_rows': 0,
        'started_at': '2026-08-12T12:00:00Z',
        'completed_at': '2026-08-12T12:00:05Z',
        'error_summary': errorMsg,
        'job_metadata': {},
        'created_at': '2026-08-12T11:59:00Z',
        'updated_at': '2026-08-12T12:00:05Z',
      };
      return ApiResult.success(mapper({'data': executedJob}));
    }

    return ApiResult.failure(const ApiFailure(message: 'Route not mocked', type: ApiFailureType.unknown));
  }
}

void main() {
  late FakeAcademicSetupApiClient fakeApiClient;

  setUp(() {
    fakeApiClient = FakeAcademicSetupApiClient();
  });

  Widget createTestWidget({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWith((ref) => FakeAcademicSetupRepository()),
        sessionManagerProvider.overrideWith((ref) => FakeAcademicSetupSessionManager()),
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

  testWidgets('1. Migration Center displays Academic Setup option and filter chips', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Student Migration Center'), findsOneWidget);
    expect(find.text('academic_setup_registry_2026.csv'), findsOneWidget);
    expect(find.text('Academic Setup'), findsWidgets);
    expect(find.text('New Academic Setup Migration'), findsOneWidget);
    expect(find.text('New Student Migration'), findsOneWidget);
  });

  testWidgets('2. Wizard renders correctly with school context steps', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWith((ref) => FakeAcademicSetupRepository()),
          sessionManagerProvider.overrideWith((ref) => FakeAcademicSetupSessionManager()),
          apiClientProvider.overrideWithValue(fakeApiClient),
          bootstrapResultProvider.overrideWithValue(BootstrapResult(success: true)),
          selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
          selectedAcademicYearIdProvider.overrideWith((ref) => 'ay_1'),
        ],
        child: const MaterialApp(
          home: AcademicSetupMigrationWizardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Select School Context'), findsOneWidget);
    expect(find.text('Target School / Campus'), findsOneWidget);
    expect(find.text('Academic Year Scope (Reference Context)'), findsOneWidget);
  });

  testWidgets('3. Required template fields display and download template works', (WidgetTester tester) async {
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
    container.read(academicSetupMigrationWizardProvider.notifier).updateContext('school_1', 'ay_1');
    container.read(academicSetupMigrationWizardProvider.notifier).nextStep();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AcademicSetupMigrationWizardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CSV Format Guidelines:'), findsOneWidget);
    expect(find.textContaining('academic_year_name, academic_year_code'), findsOneWidget);
    expect(find.text('Download Template CSV'), findsOneWidget);
  });

  testWidgets('4. Invalid file type validation button is disabled by default', (WidgetTester tester) async {
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
    container.read(academicSetupMigrationWizardProvider.notifier).updateContext('school_1', 'ay_1');
    container.read(academicSetupMigrationWizardProvider.notifier).nextStep();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AcademicSetupMigrationWizardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final validateBtn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Validate CSV'));
    expect(validateBtn.onPressed, isNull);
  });

  testWidgets('5. ImportJob creation sends ACADEMIC_SETUP & executes validation', (WidgetTester tester) async {
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

    container.read(academicSetupMigrationWizardProvider.notifier).updateContext('school_1', 'ay_1');
    container.read(academicSetupMigrationWizardProvider.notifier).updateSelectedFile('setup.csv', Uint8List.fromList([10, 20]));
    container.read(academicSetupMigrationWizardProvider.notifier).nextStep();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AcademicSetupMigrationWizardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final validateFinder = find.widgetWithText(ElevatedButton, 'Validate CSV');
    await tester.ensureVisible(validateFinder);
    await tester.tap(validateFinder);
    await tester.pumpAndSettle();

    expect(fakeApiClient.createTriggered, isTrue);
    expect(fakeApiClient.lastImportTypeCreated, 'ACADEMIC_SETUP');
    expect(fakeApiClient.validateTriggered, isTrue);

    expect(find.text('Validation Results Summary'), findsOneWidget);
    expect(find.textContaining('Ready for migration.'), findsOneWidget);
  });

  testWidgets('6. Error Review table renders and exports CSV report', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    fakeApiClient.mockRows = [
      {
        'id': 'row_a',
        'import_job_id': 'job-academic-uuid-error',
        'row_number': 2,
        'status': 'failed',
        'error_code': 'INVALID_ACADEMIC_PERIOD',
        'error_message': 'Start date must precede end date',
        'source_identifier': 'AY-2026',
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

    await container.read(academicSetupMigrationWizardProvider.notifier).preloadJob('job-academic-uuid-error');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AcademicSetupMigrationWizardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Validation Results Summary'), findsOneWidget);
    expect(find.textContaining('Validation errors found.'), findsOneWidget);

    final reviewFinder = find.widgetWithText(OutlinedButton, 'Review Errors');
    await tester.ensureVisible(reviewFinder);
    await tester.tap(reviewFinder);
    await tester.pumpAndSettle();

    expect(find.text('Review Row Errors'), findsOneWidget);
    expect(find.text('INVALID_ACADEMIC_PERIOD'), findsOneWidget);
    expect(find.text('Start date must precede end date'), findsOneWidget);
    expect(find.text('Download Error Report'), findsOneWidget);
  });

  testWidgets('7. Execution confirmation screen requires Start Migration trigger', (WidgetTester tester) async {
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

    await container.read(academicSetupMigrationWizardProvider.notifier).preloadJob('job-academic-uuid-validated');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AcademicSetupMigrationWizardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final executeFinder = find.widgetWithText(ElevatedButton, 'Proceed to Execute');
    await tester.ensureVisible(executeFinder);
    await tester.tap(executeFinder);
    await tester.pumpAndSettle();

    expect(find.text('Execution Confirmation'), findsOneWidget);
    expect(find.text('Start Academic Setup Migration'), findsOneWidget);

    final startFinder = find.widgetWithText(ElevatedButton, 'Start Academic Setup Migration');
    await tester.ensureVisible(startFinder);
    await tester.tap(startFinder);
    await tester.pumpAndSettle();

    expect(fakeApiClient.startTriggered, isTrue);
    expect(find.text('✓ Academic Setup Migration Completed'), findsOneWidget);
  });

  testWidgets('8. COMPLETED_WITH_ERRORS status handling in outcome page', (WidgetTester tester) async {
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

    await container.read(academicSetupMigrationWizardProvider.notifier).preloadJob('job-academic-uuid-error');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AcademicSetupMigrationWizardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final executeFinder = find.widgetWithText(ElevatedButton, 'Proceed to Execute');
    await tester.ensureVisible(executeFinder);
    await tester.tap(executeFinder);
    await tester.pumpAndSettle(); // to step 3 (review errors)

    await tester.ensureVisible(executeFinder);
    await tester.tap(executeFinder);
    await tester.pumpAndSettle(); // to step 4 (execution confirmation)

    final startFinder = find.widgetWithText(ElevatedButton, 'Start Academic Setup Migration');
    await tester.ensureVisible(startFinder);
    await tester.tap(startFinder);
    await tester.pumpAndSettle();

    expect(find.text('Migration completed with errors'), findsOneWidget);
  });

  testWidgets('9. FAILED execution outcome page renders error message', (WidgetTester tester) async {
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

    await container.read(academicSetupMigrationWizardProvider.notifier).preloadJob('job-academic-uuid-fail');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AcademicSetupMigrationWizardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final executeFinder = find.widgetWithText(ElevatedButton, 'Proceed to Execute');
    await tester.ensureVisible(executeFinder);
    await tester.tap(executeFinder);
    await tester.pumpAndSettle();

    final startFinder = find.widgetWithText(ElevatedButton, 'Start Academic Setup Migration');
    await tester.ensureVisible(startFinder);
    await tester.tap(startFinder);
    await tester.pumpAndSettle();

    expect(find.text('Migration failed'), findsOneWidget);
    expect(find.textContaining('Academic Year start date exceeds end date constraint.'), findsOneWidget);
  });

  testWidgets('10. Existing Student migration and Fees features remain unharmed', (WidgetTester tester) async {
    expect(AppRoutes.fees, '/fees');
    expect(AppRoutes.feesAssign, '/fees/assign');
    expect(AppRoutes.feesLedger, '/fees/ledger');
    expect(AppRoutes.feesOutstanding, '/fees/outstanding');

    expect(AppRoutes.migrations, '/migrations');
    expect(AppRoutes.migrationNew, '/migrations/students/new');
    expect(AppRoutes.migrationDetail, '/migrations/students/:jobId');
  });
}
