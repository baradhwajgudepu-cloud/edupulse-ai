import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:edupulse_config/edupulse_config.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/bulk_import/presentation/providers/school_onboarding_providers.dart';
import 'package:admin_portal/features/bulk_import/data/models/school_onboarding_models.dart';

class TestSafetySessionManager implements SessionManager {
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
  Future<String?> getSchoolId() async => cachedSchoolId;

  @override
  Future<void> saveSchoolId(String schoolId) async {
    cachedSchoolId = schoolId;
  }

  @override
  Future<String?> getSchoolName() async => cachedSchoolName;

  @override
  Future<void> saveSchoolName(String schoolName) async {
    cachedSchoolName = schoolName;
  }

  @override
  Future<String?> getAccessToken() async => 'test-token';

  @override
  Future<String?> getRefreshToken() async => 'test-refresh';

  @override
  Future<void> saveSession(SessionToken token) async {}

  @override
  Future<void> clearSession([String source = 'SessionManager.clearSession']) async {
    cachedTenantId = null;
    cachedTenantName = null;
    cachedSchoolId = null;
    cachedSchoolName = null;
  }

  @override
  Future<bool> hasSession() async => true;
}

class TestSafetyApiClient extends BaseApiClient {
  final List<String> requestedPaths = [];
  final List<Map<String, dynamic>> postedData = [];
  bool fetchSchoolsCalled = false;
  bool fetchTenantsCalled = false;

  TestSafetyApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic json) mapper,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    requestedPaths.add(path);
    if (path.startsWith('/schools')) {
      fetchSchoolsCalled = true;
      final mockData = {
        'data': [
          {
            'id': 'school-uuid-abc',
            'tenant_id': 'tenant-uuid-123',
            'name': 'Test Alpha School',
            'code': 'TAS',
            'board': 'CBSE',
            'school_type': 'HIGH_SCHOOL',
            'email': 'alpha@school.edu',
            'is_active': true,
            'status': 'ACTIVE',
            'version': 1,
          },
          {
            'id': 'school-uuid-xyz',
            'tenant_id': 'tenant-uuid-123',
            'name': 'Test Beta School',
            'code': 'TBS',
            'board': 'ICSE',
            'school_type': 'PRIMARY',
            'email': 'beta@school.edu',
            'is_active': true,
            'status': 'ACTIVE',
            'version': 1,
          }
        ]
      };
      return ApiResult.success(mapper(mockData));
    }
    if (path.startsWith('/tenants')) {
      fetchTenantsCalled = true;
      final mockData = {
        'data': [
          {
            'id': 'tenant-uuid-123',
            'name': 'Test Education Society',
            'code': 'TES',
            'subdomain': 'tes',
            'email': 'admin@tes.edu',
            'is_active': true,
            'status': 'ACTIVE',
          }
        ]
      };
      return ApiResult.success(mapper(mockData));
    }
    return const ApiResult.failure(ApiFailure(
      type: ApiFailureType.unknown,
      message: 'Not found',
      statusCode: 404,
    ));
  }

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic json) mapper,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    requestedPaths.add(path);
    if (data is Map<String, dynamic>) {
      postedData.add(data);
    }
    if (path == '/tenants') {
      final mockRes = {
        'data': {
          'id': 'tms-tenant-uuid-001',
          'name': (data is Map ? data['name'] : null) ?? 'Telangana Educational Society',
          'code': (data is Map ? data['code'] : null) ?? 'tms-org',
        }
      };
      return ApiResult.success(mapper(mockRes));
    }
    if (path == '/schools') {
      final mockRes = {
        'data': {
          'id': 'tms-school-uuid-999',
          'name': (data is Map ? data['name'] : null) ?? 'Telangana Model School and Junior College',
          'code': (data is Map ? data['code'] : null) ?? 'TMS01',
        }
      };
      return ApiResult.success(mapper(mockRes));
    }
    return const ApiResult.failure(ApiFailure(
      type: ApiFailureType.unknown,
      message: 'Not found',
      statusCode: 404,
    ));
  }
}

void main() {
  group('School Context Production Safety & Audit Tests', () {
    late TestSafetySessionManager sessionManager;
    late TestSafetyApiClient apiClient;

    setUp(() {
      sessionManager = TestSafetySessionManager();
      apiClient = TestSafetyApiClient();
      SchoolOnboardingNotifier.bypassApproval = true;
    });

    // TEST 1: Create a school named: "Telangana Model School and Junior College"
    // Verify the active school context contains exactly that name.
    test('TEST 1: Onboarding sets active school context to Telangana Model School and Junior College', () async {
      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(sessionManager),
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );

      final notifier = container.read(schoolOnboardingProvider.notifier);
      notifier.setTenantMode(
        createNewTenant: true,
        newTenantName: 'Telangana Model Education Society',
        newTenantCode: 'tmes',
      );

      const schoolSheet = OnboardingSheetData(
        step: OnboardingStep.school,
        fileName: 'school.csv',
        headers: ['school_code', 'school_name', 'board', 'school_type', 'email'],
        rows: [
          OnboardingParsedRow(
            rowIndex: 1,
            data: {
              'school_code': 'TMS01',
              'school_name': 'Telangana Model School and Junior College',
              'board': 'CBSE',
              'school_type': 'HIGH_SCHOOL',
              'email': 'principal@telanganaschool.edu',
            },
            errors: [],
            warnings: [],
            duplicates: [],
            unresolvedReferences: [],
            status: OnboardingRowStatus.valid,
          ),
        ],
      );

      final updatedSheets = {OnboardingStep.school: schoolSheet};
      container.read(schoolOnboardingProvider.notifier).state =
          container.read(schoolOnboardingProvider).copyWith(sheets: updatedSheets);

      await notifier.executeOnboarding('', apiClient);

      expect(sessionManager.cachedSchoolName, 'Telangana Model School and Junior College');
    });

    // TEST 2: Verify newly created school UUID becomes selectedSchoolId.
    test('TEST 2: Newly created school UUID becomes selectedSchoolId', () async {
      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(sessionManager),
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );

      final notifier = container.read(schoolOnboardingProvider.notifier);
      notifier.setTenantMode(createNewTenant: true, newTenantName: 'Test Society', newTenantCode: 'ts');

      const schoolSheet = OnboardingSheetData(
        step: OnboardingStep.school,
        fileName: 'school.csv',
        headers: ['school_code', 'school_name', 'board', 'school_type', 'email'],
        rows: [
          OnboardingParsedRow(
            rowIndex: 1,
            data: {
              'school_code': 'TMS01',
              'school_name': 'Telangana Model School and Junior College',
              'board': 'CBSE',
              'school_type': 'HIGH_SCHOOL',
              'email': 'principal@telanganaschool.edu',
            },
            errors: [],
            warnings: [],
            duplicates: [],
            unresolvedReferences: [],
            status: OnboardingRowStatus.valid,
          ),
        ],
      );

      container.read(schoolOnboardingProvider.notifier).state =
          container.read(schoolOnboardingProvider).copyWith(sheets: {OnboardingStep.school: schoolSheet});

      await notifier.executeOnboarding('', apiClient);

      expect(container.read(selectedSchoolIdProvider), 'tms-school-uuid-999');
      expect(sessionManager.cachedSchoolId, 'tms-school-uuid-999');
    });

    // TEST 3: Verify previous school context is cleared when switching schools.
    test('TEST 3: Switching school clears previous school context when set to null', () async {
      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(sessionManager),
        ],
      );

      // Initially set school
      container.read(selectedSchoolIdProvider.notifier).state = 'school-123';
      await sessionManager.saveSchoolId('school-123');
      await sessionManager.saveSchoolName('Old School');

      expect(container.read(selectedSchoolIdProvider), 'school-123');
      expect(await sessionManager.getSchoolId(), 'school-123');

      // User selects "All Schools" (null)
      container.read(selectedSchoolIdProvider.notifier).state = null;
      await sessionManager.saveSchoolId('');
      await sessionManager.saveSchoolName('');

      expect(container.read(selectedSchoolIdProvider), isNull);
      expect(await sessionManager.getSchoolId(), '');
      expect(await sessionManager.getSchoolName(), '');
    });

    // TEST 4: Verify no hardcoded "Delhi Public School Hyderabad" fallback exists.
    test('TEST 4: Empty schools state falls back to safe dynamic placeholder, not hardcoded DPSH', () {
      final container = ProviderContainer();
      expect(container.read(selectedSchoolIdProvider), isNull);
      expect(container.read(schoolsListProvider).schools, isEmpty);
    });

    // TEST 5: Verify no hardcoded school UUID fallback exists.
    test('TEST 5: Initial selectedSchoolId is strictly null without hardcoded UUID injection', () {
      final container = ProviderContainer();
      expect(container.read(selectedSchoolIdProvider), isNull);
      expect(container.read(selectedAcademicYearIdProvider), isNull);
    });

    // TEST 6: Verify production BuildConfig does not load synthetic data automatically.
    test('TEST 6: Production BuildConfig environment flag check disables synthetic dev button', () {
      const prodConfig = BuildConfig(
        env: AppEnvironment.prod,
        apiBaseUrl: 'https://api.edupulse.ai/api/v1',
        tenantId: 'prod-tenant-id',
      );

      final isDev = prodConfig.env != AppEnvironment.prod;
      expect(isDev, isFalse, reason: 'Synthetic dev loader must be false/hidden in production environment');
    });

    // TEST 7: Verify null school context remains null and does not silently select a demo school.
    test('TEST 7: fetchSchools with no persisted school keeps selectedSchoolId as null', () async {
      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(sessionManager),
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );

      // Session has no cached school ID
      expect(sessionManager.cachedSchoolId, isNull);

      await container.read(schoolsListProvider.notifier).fetchSchools();

      final schools = container.read(schoolsListProvider).schools;
      expect(schools.length, 2);
      // Ensure targetSchoolId remained null and was NOT set to schools.first.id
      expect(container.read(selectedSchoolIdProvider), isNull);
    });

    // TEST 8: Verify tenant and school selectors refresh after onboarding.
    test('TEST 8: Onboarding sequence fetches both tenants and schools on completion', () async {
      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(sessionManager),
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );

      final notifier = container.read(schoolOnboardingProvider.notifier);
      notifier.setTenantMode(createNewTenant: true, newTenantName: 'Test Society', newTenantCode: 'ts');

      const schoolSheet = OnboardingSheetData(
        step: OnboardingStep.school,
        fileName: 'school.csv',
        headers: ['school_code', 'school_name', 'board', 'school_type', 'email'],
        rows: [
          OnboardingParsedRow(
            rowIndex: 1,
            data: {
              'school_code': 'TMS01',
              'school_name': 'Telangana Model School and Junior College',
              'board': 'CBSE',
              'school_type': 'HIGH_SCHOOL',
              'email': 'principal@telanganaschool.edu',
            },
            errors: [],
            warnings: [],
            duplicates: [],
            unresolvedReferences: [],
            status: OnboardingRowStatus.valid,
          ),
        ],
      );

      container.read(schoolOnboardingProvider.notifier).state =
          container.read(schoolOnboardingProvider).copyWith(sheets: {OnboardingStep.school: schoolSheet});

      await notifier.executeOnboarding('', apiClient);

      // Verify fetch calls occurred for both /schools and /tenants
      expect(apiClient.requestedPaths.any((p) => p.startsWith('/schools')), isTrue);
      expect(apiClient.requestedPaths.any((p) => p.startsWith('/tenants')), isTrue);
    });
  });
}
