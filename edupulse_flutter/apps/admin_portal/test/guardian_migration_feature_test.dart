import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/features/migrations/presentation/providers/migration_providers.dart';
import 'package:admin_portal/features/migrations/presentation/pages/guardian_migration_wizard_screen.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';

class FakeGuardianRepository implements AuthRepository {
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

class FakeGuardianSessionManager implements SessionManager {
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

class FakeGuardianApiClient extends BaseApiClient {
  List<Map<String, dynamic>> mockJobs = [
    {
      'id': 'job-guardian-uuid-1',
      'tenant_id': 'tenant_1',
      'school_id': 'school_1',
      'import_type': 'GUARDIANS',
      'status': 'COMPLETED',
      'source_filename': 'guardian_registry_2026.csv',
      'file_checksum': 'checksum123',
      'total_rows': 5,
      'processed_rows': 5,
      'successful_rows': 5,
      'failed_rows': 0,
      'skipped_rows': 0,
      'started_at': '2026-08-12T12:00:00Z',
      'completed_at': '2026-08-12T12:00:05Z',
      'job_metadata': {'sheets': ['Sheet1', 'Sheet2'], 'selected_sheet': 'Sheet1'},
      'created_at': '2026-08-12T11:59:00Z',
      'updated_at': '2026-08-12T12:00:05Z',
    }
  ];

  List<Map<String, dynamic>> mockRows = [];

  bool startTriggered = false;
  bool validateTriggered = false;
  bool createTriggered = false;
  String? validateSheetPassed;

  FakeGuardianApiClient() : super(Dio());

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

    if (path.contains('/import-jobs/job-guardian-uuid-1/rows') ||
        path.contains('/import-jobs/job-guardian-uuid-error/rows') ||
        path.contains('/import-jobs/job-guardian-uuid-fail/rows')) {
      return ApiResult.success(mapper({
        'data': mockRows,
      }));
    }

    if (path.contains('/import-jobs/job-guardian-uuid-1') ||
        path.contains('/import-jobs/job-guardian-uuid-error') ||
        path.contains('/import-jobs/job-guardian-uuid-fail')) {
      final id = path.split('/').last;
      final job = mockJobs.firstWhere((j) => j['id'] == id, orElse: () => mockJobs.first);
      return ApiResult.success(mapper({'data': job}));
    }

    if (path.contains('/import-jobs')) {
      return ApiResult.success(mapper({'data': mockJobs}));
    }

    return ApiResult.failure(const ApiFailure(message: 'Unhandled get path', type: ApiFailureType.unknown));
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
    if (path.contains('/import-jobs/job-guardian-uuid-1/start') ||
        path.contains('/import-jobs/job-guardian-uuid-error/start') ||
        path.contains('/import-jobs/job-guardian-uuid-fail/start')) {
      startTriggered = true;
      final id = path.split('/')[2];
      final job = mockJobs.firstWhere((j) => j['id'] == id);
      job['status'] = 'COMPLETED';
      return ApiResult.success(mapper({'data': job}));
    }

    if (path.contains('/import-jobs/job-guardian-uuid-1/validate') ||
        path.contains('/import-jobs/job-guardian-uuid-error/validate') ||
        path.contains('/import-jobs/job-guardian-uuid-fail/validate')) {
      validateTriggered = true;
      final uri = Uri.parse(path);
      validateSheetPassed = uri.queryParameters['sheet_name'];

      final id = path.split('/')[2].split('?').first;
      final job = mockJobs.firstWhere((j) => j['id'] == id);
      job['status'] = id.contains('error')
          ? 'COMPLETED_WITH_ERRORS'
          : id.contains('fail')
              ? 'FAILED'
              : 'VALIDATED';
      if (validateSheetPassed != null) {
        job['job_metadata']['selected_sheet'] = validateSheetPassed;
      }
      return ApiResult.success(mapper({'data': job}));
    }

    if (path == '/import-jobs') {
      createTriggered = true;
      final payload = data as Map<String, dynamic>;
      final jobType = payload['import_type'];
      final newJob = {
        'id': jobType == 'GUARDIANS' ? 'job-guardian-uuid-1' : 'job-uuid-unknown',
        'tenant_id': 'tenant_1',
        'school_id': payload['school_id'],
        'import_type': payload['import_type'],
        'status': 'DRAFT',
        'source_filename': payload['source_filename'],
        'file_checksum': 'checksum123',
        'total_rows': 0,
        'processed_rows': 0,
        'successful_rows': 0,
        'failed_rows': 0,
        'skipped_rows': 0,
        'job_metadata': {'sheets': ['Sheet1', 'Sheet2'], 'selected_sheet': 'Sheet1'},
        'created_at': '2026-08-12T11:59:00Z',
        'updated_at': '2026-08-12T12:00:05Z',
      };
      if (mockJobs.any((j) => j['id'] == newJob['id'])) {
        mockJobs.removeWhere((j) => j['id'] == newJob['id']);
      }
      mockJobs.add(newJob);
      return ApiResult.success(mapper({'data': newJob}));
    }

    return ApiResult.failure(const ApiFailure(message: 'Unhandled post path', type: ApiFailureType.unknown));
  }
}

void main() {
  late FakeGuardianApiClient fakeApiClient;
  late ProviderContainer container;

  setUp(() {
    fakeApiClient = FakeGuardianApiClient();
    container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('Guardian Migration Wizard State & Provider Tests', () {
    test('initial wizard state validation', () {
      final state = container.read(guardianMigrationWizardProvider);
      expect(state.currentStep, 0);
      expect(state.isActionInProgress, false);
      expect(state.validationErrors.isEmpty, true);
    });

    test('updateContext updates school context', () {
      final notifier = container.read(guardianMigrationWizardProvider.notifier);
      notifier.updateContext('school_abc');
      final state = container.read(guardianMigrationWizardProvider);
      expect(state.selectedSchoolId, 'school_abc');
    });

    test('createImportJob registers draft GUARDIANS job', () async {
      final notifier = container.read(guardianMigrationWizardProvider.notifier);
      notifier.updateContext('school_1');
      notifier.updateSelectedFile('guardians.xlsx', Uint8List.fromList([1, 2, 3]));

      final result = await notifier.createImportJob();
      expect(result, true);
      expect(fakeApiClient.createTriggered, true);

      final state = container.read(guardianMigrationWizardProvider);
      expect(state.jobId, 'job-guardian-uuid-1');
      expect(state.activeJob?.importType, 'GUARDIANS');
    });

    test('validateCsvFile uploads file for verification and extracts sheets', () async {
      final notifier = container.read(guardianMigrationWizardProvider.notifier);
      notifier.updateContext('school_1');
      notifier.updateSelectedFile('guardians.xlsx', Uint8List.fromList([1, 2, 3]));

      await notifier.createImportJob();
      final validated = await notifier.validateCsvFile();
      expect(validated, true);
      expect(fakeApiClient.validateTriggered, true);

      final state = container.read(guardianMigrationWizardProvider);
      expect(state.activeJob?.status, 'VALIDATED');
      expect(state.selectedSheet, 'Sheet1');
    });

    test('updateSelectedSheet triggers validate flow with correct sheet parameter', () async {
      final notifier = container.read(guardianMigrationWizardProvider.notifier);
      notifier.updateContext('school_1');
      notifier.updateSelectedFile('guardians.xlsx', Uint8List.fromList([1, 2, 3]));

      await notifier.createImportJob();
      notifier.updateSelectedSheet('Sheet2');

      final state = container.read(guardianMigrationWizardProvider);
      expect(state.selectedSheet, 'Sheet2');
      expect(fakeApiClient.validateSheetPassed, 'Sheet2');
    });

    test('executeMigration triggers database import execution', () async {
      final notifier = container.read(guardianMigrationWizardProvider.notifier);
      notifier.updateContext('school_1');
      notifier.updateSelectedFile('guardians.xlsx', Uint8List.fromList([1, 2, 3]));

      await notifier.createImportJob();
      await notifier.validateCsvFile();
      final executed = await notifier.executeMigration();
      expect(executed, true);
      expect(fakeApiClient.startTriggered, true);

      final state = container.read(guardianMigrationWizardProvider);
      expect(state.activeJob?.status, 'COMPLETED');
    });
  });

  group('Worksheet Selector Stale Response Discard Tests', () {
    test('stale validation response is discarded when newer request takes priority', () async {
      final notifier = container.read(guardianMigrationWizardProvider.notifier);
      notifier.updateContext('school_1');
      notifier.updateSelectedFile('guardians.xlsx', Uint8List.fromList([1, 2, 3]));
      await notifier.createImportJob();

      // Trigger first sheet validation
      notifier.updateSelectedSheet('Sheet1');
      // Trigger second sheet validation immediately (incrementing request ID)
      notifier.updateSelectedSheet('Sheet2');

      final state = container.read(guardianMigrationWizardProvider);
      // Selected sheet resolves to the latest selection
      expect(state.selectedSheet, 'Sheet2');
    });
  });

  group('Guardian Migration Widget Widget Tests', () {
    testWidgets('Wizard displays steps and context view correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeApiClient),
            selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
          ],
          child: MaterialApp(
            home: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (context) => const GuardianMigrationWizardScreen(),
              ),
            ),
          ),
        ),
      );

      // Verify header and steps progress are present
      expect(find.text('New Guardian Migration'), findsOneWidget);
      expect(find.text('Select School Context'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });
  });
}
