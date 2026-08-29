import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/features/migrations/presentation/providers/migration_providers.dart';
import 'package:admin_portal/features/migrations/presentation/pages/migration_center_screen.dart';
import 'package:admin_portal/features/migrations/presentation/pages/guardian_mapping_migration_wizard_screen.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';

class FakeMappingRepository implements AuthRepository {
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

class FakeMappingSessionManager implements SessionManager {
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

class FakeMappingApiClient extends BaseApiClient {
  List<Map<String, dynamic>> mockJobs = [
    {
      'id': 'job-mapping-uuid-1',
      'tenant_id': 'tenant_1',
      'school_id': 'school_1',
      'import_type': 'GUARDIAN_MAPPING',
      'status': 'COMPLETED',
      'source_filename': 'guardian_mapping_registry_2026.csv',
      'file_checksum': 'checksum123',
      'total_rows': 5,
      'processed_rows': 5,
      'successful_rows': 5,
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

  FakeMappingApiClient() : super(Dio());

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

    if (path.contains('/import-jobs/job-mapping-uuid-1/rows') ||
        path.contains('/import-jobs/job-mapping-uuid-error/rows') ||
        path.contains('/import-jobs/job-mapping-uuid-fail/rows')) {
      return ApiResult.success(mapper({
        'data': mockRows,
      }));
    }

    if (path.contains('/import-jobs/job-mapping-uuid-1') ||
        path.contains('/import-jobs/job-mapping-uuid-error') ||
        path.contains('/import-jobs/job-mapping-uuid-fail')) {
      final id = path.split('/').last.split('?').first;
      String status = 'COMPLETED';
      int failedRows = 0;
      int skippedRows = 0;
      if (id == 'job-mapping-uuid-error') {
        status = 'VALIDATED';
        failedRows = 2;
        skippedRows = 1;
      } else if (id == 'job-mapping-uuid-fail') {
        status = 'VALIDATED';
      }
      return ApiResult.success(mapper({
        'data': {
          'id': id,
          'tenant_id': 'tenant_1',
          'school_id': 'school_1',
          'import_type': 'GUARDIAN_MAPPING',
          'status': status,
          'source_filename': 'guardian_mapping_registry_2026.csv',
          'file_checksum': 'checksum123',
          'total_rows': 5,
          'processed_rows': 5,
          'successful_rows': 5 - failedRows - skippedRows,
          'failed_rows': failedRows,
          'skipped_rows': skippedRows,
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
      final newJob = {
        'id': 'job-mapping-uuid-1',
        'tenant_id': 'tenant_1',
        'school_id': 'school_1',
        'import_type': 'GUARDIAN_MAPPING',
        'status': 'DRAFT',
        'source_filename': 'guardian_mapping_registry_2026.csv',
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
      int skippedRows = 0;
      if (jobId == 'job-mapping-uuid-error') {
        status = 'VALIDATED';
        failedRows = 2;
        skippedRows = 1;
      }

      final validatedJob = {
        'id': jobId,
        'tenant_id': 'tenant_1',
        'school_id': 'school_1',
        'import_type': 'GUARDIAN_MAPPING',
        'status': status,
        'source_filename': 'guardian_mapping_registry_2026.csv',
        'total_rows': 5,
        'processed_rows': 0,
        'successful_rows': 0,
        'failed_rows': failedRows,
        'skipped_rows': skippedRows,
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
      int failedRows = 0;
      int skippedRows = 0;
      if (jobId == 'job-mapping-uuid-error') {
        status = 'COMPLETED_WITH_ERRORS';
        failedRows = 2;
        skippedRows = 1;
      } else if (jobId == 'job-mapping-uuid-fail') {
        status = 'FAILED';
      }

      final completedJob = {
        'id': jobId,
        'tenant_id': 'tenant_1',
        'school_id': 'school_1',
        'import_type': 'GUARDIAN_MAPPING',
        'status': status,
        'source_filename': 'guardian_mapping_registry_2026.csv',
        'total_rows': 5,
        'processed_rows': 5,
        'successful_rows': 5 - failedRows - skippedRows,
        'failed_rows': failedRows,
        'skipped_rows': skippedRows,
        'started_at': '2026-08-12T12:00:00Z',
        'completed_at': '2026-08-12T12:00:05Z',
        'job_metadata': {},
        'created_at': '2026-08-12T11:59:00Z',
        'updated_at': '2026-08-12T12:00:05Z',
      };
      return ApiResult.success(mapper({'data': completedJob}));
    }

    return ApiResult.failure(const ApiFailure(message: 'Route not mocked', type: ApiFailureType.unknown));
  }
}

void main() {
  late FakeMappingApiClient fakeApiClient;

  setUp(() {
    fakeApiClient = FakeMappingApiClient();
  });

  Widget createTestWidget(Widget child) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        authRepositoryProvider.overrideWithValue(FakeMappingRepository()),
        sessionManagerProvider.overrideWithValue(FakeMappingSessionManager()),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
        selectedAcademicYearIdProvider.overrideWith((ref) => 'ay_1'),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  testWidgets('1. Migration Center displays Guardian Mappings option and filter chips', (tester) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    await binding.setSurfaceSize(const Size(1440, 1000));
    await tester.pumpWidget(createTestWidget(const MigrationCenterScreen()));
    await tester.pumpAndSettle();

    // Verify Action button exists
    expect(find.text('New Student-Guardian Mapping'), findsOneWidget);
    
    // Verify Filter Chip exists
    expect(find.text('Guardian Mappings'), findsOneWidget);
  });

  testWidgets('2. Wizard renders correctly with school selection context', (tester) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    await binding.setSurfaceSize(const Size(1440, 1000));
    await tester.pumpWidget(createTestWidget(const GuardianMappingMigrationWizardScreen()));
    await tester.pumpAndSettle();

    // Context step title
    expect(find.text('Select Target School'), findsOneWidget);
    
    // Dropdown field
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    
    // Academic Year selection dropdown MUST NOT exist
    expect(find.text('Academic Year Scope'), findsNothing);

    // Next button
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('3. Required template fields display and download template works', (tester) async {
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
      ],
    );
    final state = container.read(guardianMappingMigrationWizardProvider);
    expect(state.currentStep, 0);

    // Set step to 1 (CSV Upload)
    container.read(guardianMappingMigrationWizardProvider.notifier).nextStep();
    
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    await binding.setSurfaceSize(const Size(1440, 1000));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: GuardianMappingMigrationWizardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Upload Mapping File'), findsOneWidget);
    expect(find.text('Download Official Template'), findsOneWidget);
    
    // Check format guidelines
    expect(find.textContaining('student_admission_number, guardian_id, relationship'), findsOneWidget);
  });

  testWidgets('4. Full wizard execution mapping success workflow', (tester) async {
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
      ],
    );
    
    // Preload files selection
    container.read(guardianMappingMigrationWizardProvider.notifier).updateContext('school_1');
    container.read(guardianMappingMigrationWizardProvider.notifier).updateSelectedFile('mapping_registry.csv', Uint8List.fromList([1, 2, 3]));
    
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    await binding.setSurfaceSize(const Size(1440, 1000));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: GuardianMappingMigrationWizardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Step 0: Context
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 1: Upload & Validate
    await tester.tap(find.text('Validate File'));
    await tester.pumpAndSettle();

    expect(fakeApiClient.createTriggered, isTrue);
    expect(fakeApiClient.validateTriggered, isTrue);

    // Step 2: Validation results summary
    expect(find.text('Validation Results Summary'), findsOneWidget);
    expect(find.text('Proceed to Execute'), findsOneWidget);

    // Proceed to Step 4 (Execution Confirm)
    await tester.tap(find.text('Proceed to Execute'));
    await tester.pumpAndSettle();

    expect(find.text('Execution Confirmation'), findsOneWidget);
    expect(find.text('Confirm & Execute'), findsOneWidget);

    // Click confirm execution
    await tester.tap(find.text('Confirm & Execute'));
    await tester.pumpAndSettle();

    expect(fakeApiClient.startTriggered, isTrue);

    // Complete Step
    expect(find.text('Migration Completed'), findsOneWidget);
    expect(find.text('Successful Mappings Created'), findsOneWidget);
  });

  testWidgets('5. COMPLETED_WITH_ERRORS status and row errors render safely', (tester) async {
    fakeApiClient.mockRows = [
      {
        'id': 'row_1',
        'import_job_id': 'job-mapping-uuid-error',
        'row_number': 1,
        'status': 'failed',
        'error_code': 'MAPPING_ALREADY_EXISTS',
        'error_message': 'This mapping relationship already exists.',
        'source_identifier': 'STU001',
        'entity_id': null,
        'row_metadata': {},
        'created_at': '2026-08-12T12:00:00Z',
        'updated_at': '2026-08-12T12:00:00Z',
      },
      {
        'id': 'row_2',
        'import_job_id': 'job-mapping-uuid-error',
        'row_number': 2,
        'status': 'failed',
        'error_code': 'PRIMARY_GUARDIAN_LIMIT_EXCEEDED',
        'error_message': 'A primary guardian has already been assigned.',
        'source_identifier': 'STU002',
        'entity_id': null,
        'row_metadata': {},
        'created_at': '2026-08-12T12:00:00Z',
        'updated_at': '2026-08-12T12:00:00Z',
      }
    ];

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
      ],
    );

    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    await binding.setSurfaceSize(const Size(1440, 1000));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: GuardianMappingMigrationWizardScreen(jobId: 'job-mapping-uuid-error'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify it preloaded validation summary
    expect(find.text('Validation Results Summary'), findsOneWidget);
    expect(find.text('Failed / Invalid Rows'), findsOneWidget);
    expect(find.text('Skipped Rows'), findsOneWidget);

    // Verify Review Errors exists
    await tester.tap(find.text('Review Errors'));
    await tester.pumpAndSettle();

    // Verify data table contains the mock errors (rendered safely as row error, not Generic crash)
    expect(find.text('MAPPING_ALREADY_EXISTS'), findsOneWidget);
    expect(find.text('PRIMARY_GUARDIAN_LIMIT_EXCEEDED'), findsOneWidget);

    // Proceed to Execute
    await tester.tap(find.text('Proceed to Execute'));
    await tester.pumpAndSettle();

    // Execute
    await tester.tap(find.text('Confirm & Execute'));
    await tester.pumpAndSettle();

    // Verification of outcome counts
    expect(find.text('Migration Completed with Errors'), findsOneWidget);
    expect(find.text('Successful Mappings Created'), findsOneWidget);
    expect(find.text('Failed Rows During Execution'), findsOneWidget);
    expect(find.text('Skipped Rows'), findsOneWidget);
  });
}
