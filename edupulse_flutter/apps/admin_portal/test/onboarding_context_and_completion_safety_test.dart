import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:admin_portal/features/bulk_import/presentation/providers/school_onboarding_providers.dart';
import 'package:admin_portal/features/bulk_import/data/models/school_onboarding_models.dart';
import 'package:admin_portal/features/bulk_import/data/models/school_onboarding_validators.dart';
import 'package:admin_portal/features/tenant_setup/presentation/providers/tenant_providers.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'school_onboarding_test.dart';

class SafetyTestApiClient extends BaseApiClient {
  final List<Map<String, dynamic>> postCalls = [];
  final List<String> getCalls = [];
  final List<Map<String, dynamic>> registeredTenants = [];
  bool simulateCollisionOnBaseCode = false;
  bool simulatePermanentTenantFailure = false;
  bool simulateSchoolCreationFailure = false;

  SafetyTestApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    getCalls.add(path);
    if (path.contains('/tenants')) {
      List<Map<String, dynamic>> resultList = registeredTenants;
      if (path.contains('code=')) {
        final uri = Uri.parse(path.startsWith('http') ? path : 'http://localhost$path');
        final codeParam = uri.queryParameters['code'];
        if (codeParam != null) {
          resultList = registeredTenants.where((t) => t['code'] == codeParam).toList();
        }
      }
      final json = {
        'success': true,
        'data': resultList,
      };
      return ApiResult.success(mapper(json));
    }
    if (path.contains('/schools')) {
      final json = {
        'success': true,
        'data': <Map<String, dynamic>>[],
      };
      return ApiResult.success(mapper(json));
    }
    final json = {'success': true, 'data': <Map<String, dynamic>>[]};
    return ApiResult.success(mapper(json));
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
    postCalls.add({'path': path, 'data': data});

    if (path.startsWith('/tenants')) {
      if (simulatePermanentTenantFailure) {
        return const ApiResult.failure(ApiFailure(
          type: ApiFailureType.server,
          statusCode: 500,
          message: 'Internal server error during tenant provisioning.',
        ));
      }
      final code = (data is Map) ? data['code'] as String? : null;
      if (simulateCollisionOnBaseCode && code != null && !code.contains('-2')) {
        return ApiResult.failure(ApiFailure(
          type: ApiFailureType.validation,
          statusCode: 409,
          message: "Tenant code '$code' is already registered.",
        ));
      }
      final tenantObj = {
        'id': 'tenant-uuid-${DateTime.now().millisecondsSinceEpoch}',
        'name': (data is Map ? data['name'] : null) ?? 'Generated Organization',
        'code': code ?? 'gen-code',
        'subdomain': code ?? 'gen-code',
        'email': (data is Map ? data['email'] : null) ?? 'admin@org.edu',
        'status': 'ACTIVE',
        'is_active': true,
      };
      registeredTenants.add(tenantObj);
      final json = {
        'success': true,
        'data': tenantObj,
      };
      return ApiResult.success(mapper(json));
    }

    if (path == '/schools') {
      if (simulateSchoolCreationFailure) {
        return const ApiResult.failure(ApiFailure(
          type: ApiFailureType.validation,
          statusCode: 400,
          message: 'Invalid campus metadata provided.',
        ));
      }
      final json = {
        'success': true,
        'data': {
          'id': 'school-uuid-${DateTime.now().millisecondsSinceEpoch}',
          'name': (data is Map ? data['name'] : null) ?? 'Generated Campus',
          'code': (data is Map ? data['code'] : null) ?? 'SCH01',
          'status': 'ACTIVE',
        }
      };
      return ApiResult.success(mapper(json));
    }

    // Default mock success for all subsequent modules (academic years, classes, etc.)
    final json = {
      'success': true,
      'data': {
        'id': 'entity-uuid-${DateTime.now().millisecondsSinceEpoch}',
        'status': 'ACTIVE',
      }
    };
    return ApiResult.success(mapper(json));
  }

  @override
  Future<ApiResult<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    final json = {
      'success': true,
      'message': 'Tenant permanently deleted successfully.',
      'data': {
        'tenant_id': 'target-tenant-to-delete',
        'tenant_name': 'Target Org',
        'tenant_code': 'target-code',
        'dry_run': false,
        'deleted_counts': {'schools': 1, 'tenants': 1},
        'total_records_deleted': 2,
        'storage_cleanup': {'attempted': false, 'status': 'skipped', 'files_removed': 0, 'errors': []},
        'warnings': []
      }
    };
    return ApiResult.success(mapper(json));
  }
}

void main() {
  group('Critical School Onboarding Context Creation & Completion Safety Tests', () {
    setUp(() {
      SchoolOnboardingNotifier.bypassApproval = true;
    });

    test('Test 1: Completely New School — Dynamic tenant creation, proper naming, no hardcoded fallbacks', () async {
      final fakeSession = FakeOnboardingSessionManager();
      final fakeApi = SafetyTestApiClient();

      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(fakeSession),
          apiClientProvider.overrideWithValue(fakeApi),
        ],
      );

      final notifier = container.read(schoolOnboardingProvider.notifier);
      notifier.loadSyntheticFixture();

      // User sets school / organization information
      const schoolInputName = 'Telangana Model School and Junior College';
      notifier.setTenantMode(
        createNewTenant: true,
        newTenantName: schoolInputName,
      );

      await notifier.executeOnboarding('', fakeApi);

      final state = container.read(schoolOnboardingProvider);

      // Verify tenant creation
      final tenantPost = fakeApi.postCalls.firstWhere((c) => (c['path'] as String).startsWith('/tenants'));
      final tenantData = tenantPost['data'] as Map<String, dynamic>;
      expect(tenantData['name'], schoolInputName);
      expect(tenantData['code'], SchoolOnboardingValidators.generateTenantCode(schoolInputName));
      expect(tenantData['code'], isNot('ts-edu'));
      expect(tenantData['name'], isNot(contains('Delhi Public School')));

      // Verify active context persistence
      expect(container.read(selectedTenantIdProvider), isNotNull);
      expect(fakeSession.cachedTenantId, isNotNull);
      expect(fakeSession.cachedTenantName, schoolInputName);

      expect(container.read(selectedSchoolIdProvider), isNotNull);
      expect(fakeSession.cachedSchoolId, isNotNull);

      // Verify completion state is valid
      expect(state.isCompleted, isTrue);
      expect(state.approvalStatus, OnboardingApprovalStatus.completed);
      expect(state.globalErrorMessage, isNull);
    });

    test('Test 2: Tenant Code Collision — Handled safely without HTTP 409 crash via collision retry', () async {
      final fakeSession = FakeOnboardingSessionManager();
      final fakeApi = SafetyTestApiClient();
      fakeApi.simulateCollisionOnBaseCode = true; // Simulates existing base code

      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(fakeSession),
          apiClientProvider.overrideWithValue(fakeApi),
        ],
      );

      final notifier = container.read(schoolOnboardingProvider.notifier);
      notifier.loadSyntheticFixture();
      const schoolInputName = 'Telangana Model School and Junior College';
      notifier.setTenantMode(
        createNewTenant: true,
        newTenantName: schoolInputName,
      );

      await notifier.executeOnboarding('', fakeApi);

      final state = container.read(schoolOnboardingProvider);

      // Verify multiple tenant post calls occurred (initial + collision retry with suffix)
      final tenantPosts = fakeApi.postCalls.where((c) => (c['path'] as String).startsWith('/tenants')).toList();
      expect(tenantPosts.length, greaterThanOrEqualTo(2));

      final firstPost = tenantPosts[0]['data'] as Map<String, dynamic>;
      expect(firstPost['code'], SchoolOnboardingValidators.generateTenantCode(schoolInputName));

      final retryPost = tenantPosts[1]['data'] as Map<String, dynamic>;
      expect(retryPost['code'], SchoolOnboardingValidators.generateTenantCode(schoolInputName, attempt: 2));

      // Resolved successfully without crash
      expect(state.isCompleted, isTrue);
      expect(state.approvalStatus, OnboardingApprovalStatus.completed);
      expect(state.globalErrorMessage, isNull);
    });

    test('Test 3: Existing School Context — Uses existing context, does NOT call POST /tenants', () async {
      final fakeSession = FakeOnboardingSessionManager();
      await fakeSession.saveTenantId('existing-tenant-999');
      final fakeApi = SafetyTestApiClient();
      fakeApi.registeredTenants.add({
        'id': 'existing-tenant-999',
        'name': 'Existing Organization',
        'code': 'existing-org',
        'status': 'ACTIVE',
        'is_active': true,
      });

      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(fakeSession),
          apiClientProvider.overrideWithValue(fakeApi),
        ],
      );
      container.read(selectedTenantIdProvider.notifier).state = 'existing-tenant-999';
      container.read(selectedSchoolIdProvider.notifier).state = 'existing-school-888';

      final notifier = container.read(schoolOnboardingProvider.notifier);
      notifier.loadSyntheticFixture();
      notifier.setTenantMode(
        createNewTenant: false,
        selectedTenantId: 'existing-tenant-999',
      );

      await notifier.executeOnboarding('existing-school-888', fakeApi);

      final state = container.read(schoolOnboardingProvider);

      if (state.globalErrorMessage != null) {
        // ignore: avoid_print
        print('=== TEST 3 ERROR MESSAGE: ${state.globalErrorMessage} ===');
      }

      // Verify POST /tenants was NEVER called
      final postPaths = fakeApi.postCalls.map((c) => c['path'] as String).toList();
      expect(postPaths.contains('/tenants'), isFalse);

      // Existing contexts preserved
      expect(container.read(selectedTenantIdProvider), 'existing-tenant-999');
      expect(fakeSession.cachedTenantId, 'existing-tenant-999');

      expect(state.isCompleted, isTrue);
      expect(state.approvalStatus, OnboardingApprovalStatus.completed);
    });

    test('Test 4: Context Initialization Failure — Stops immediately, FAILED state, isCompleted is FALSE', () async {
      final fakeSession = FakeOnboardingSessionManager();
      final fakeApi = SafetyTestApiClient();
      fakeApi.simulatePermanentTenantFailure = true; // Force fatal failure on tenant creation

      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(fakeSession),
          apiClientProvider.overrideWithValue(fakeApi),
        ],
      );

      final notifier = container.read(schoolOnboardingProvider.notifier);
      notifier.loadSyntheticFixture();
      notifier.setTenantMode(
        createNewTenant: true,
        newTenantName: 'Failing Academy',
      );

      await notifier.executeOnboarding('', fakeApi);

      final state = container.read(schoolOnboardingProvider);

      // CRITICAL ASSERTIONS:
      // 1. approvalStatus is failed
      expect(state.approvalStatus, OnboardingApprovalStatus.failed);
      // 2. isCompleted is strictly FALSE (MUST NOT SHOW COMPLETED!)
      expect(state.isCompleted, isFalse);
      // 3. isProcessing is FALSE
      expect(state.isProcessing, isFalse);
      // 4. globalErrorMessage contains initialization failure detail
      expect(state.globalErrorMessage, contains('Onboarding could not start because tenant context initialization failed'));
      // 5. Subsequent import modules NEVER ran
      final postPaths = fakeApi.postCalls.map((c) => c['path'] as String).toList();
      expect(postPaths.contains('/schools'), isFalse);
      expect(postPaths.contains('/classes'), isFalse);
      expect(postPaths.contains('/students'), isFalse);
    });

    test('Test 5: Completion Validation — COMPLETED only when context succeeded and imports actually ran', () async {
      final fakeSession = FakeOnboardingSessionManager();
      final fakeApi = SafetyTestApiClient();
      fakeApi.simulateSchoolCreationFailure = true; // School context creation failure

      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(fakeSession),
          apiClientProvider.overrideWithValue(fakeApi),
        ],
      );

      final notifier = container.read(schoolOnboardingProvider.notifier);
      notifier.loadSyntheticFixture();
      notifier.setTenantMode(
        createNewTenant: true,
        newTenantName: 'Valid Organization',
      );

      await notifier.executeOnboarding('', fakeApi);

      final state = container.read(schoolOnboardingProvider);

      // When school context creation fails, onboarding must fail fast
      expect(state.approvalStatus, OnboardingApprovalStatus.failed);
      expect(state.isCompleted, isFalse);
      expect(state.globalErrorMessage, contains('Onboarding could not start because school context creation failed'));

      // Downstream modules (academic years, classes, students) must NOT have been executed
      final postPaths = fakeApi.postCalls.map((c) => c['path'] as String).toList();
      expect(postPaths.contains('/academic-years'), isFalse);
      expect(postPaths.contains('/classes'), isFalse);
      expect(postPaths.contains('/students'), isFalse);
    });

    test('Test 6: Stale Context Clearing — Deleted/Missing tenant clears stored context', () async {
      final fakeSession = FakeOnboardingSessionManager();
      await fakeSession.saveTenantId('deleted-tenant-123');
      await fakeSession.saveTenantName('Deleted Org');
      await fakeSession.saveSchoolId('deleted-school-456');
      await fakeSession.saveSchoolName('Deleted Campus');

      final fakeApi = SafetyTestApiClient();

      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(fakeSession),
          apiClientProvider.overrideWithValue(fakeApi),
        ],
      );

      // Set initial selected tenant
      container.read(selectedTenantIdProvider.notifier).state = 'deleted-tenant-123';
      container.read(selectedSchoolIdProvider.notifier).state = 'deleted-school-456';

      // Call fetchTenants() where backend returns empty list (tenant deleted)
      await container.read(tenantsListProvider.notifier).fetchTenants();

      // Verify selected tenant and school are cleared to null
      expect(container.read(selectedTenantIdProvider), isNull);
      expect(container.read(selectedSchoolIdProvider), isNull);

      // Verify session manager storage was wiped
      expect(await fakeSession.getTenantId(), '');
      expect(await fakeSession.getTenantName(), '');
      expect(await fakeSession.getSchoolId(), '');
      expect(await fakeSession.getSchoolName(), '');
    });

    test('Test 7: Clean Onboarding Startup — No tenant selected shows clean state without demo fallbacks', () {
      final fakeSession = FakeOnboardingSessionManager();
      final fakeApi = SafetyTestApiClient();

      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(fakeSession),
          apiClientProvider.overrideWithValue(fakeApi),
        ],
      );

      // Ensure no tenant selected
      expect(container.read(selectedTenantIdProvider), isNull);
      expect(container.read(selectedSchoolIdProvider), isNull);

      final state = container.read(schoolOnboardingProvider);

      // Clean initial state
      expect(state.selectedTenantId, isNull);
      expect(state.resolvedTenantId, isNull);
      expect(state.newTenantName, isNull);
      expect(state.newTenantCode, isNull);
      expect(state.createNewTenant, isTrue);
      expect(state.isCompleted, isFalse);
      expect(state.approvalStatus, OnboardingApprovalStatus.awaitingValidation);
    });

    test('Test 8: Permanent Deletion Context Clearing — deleteTenantPermanent clears all contexts', () async {
      final fakeSession = FakeOnboardingSessionManager();
      await fakeSession.saveTenantId('target-tenant-to-delete');
      await fakeSession.saveTenantName('Target Org');
      await fakeSession.saveSchoolId('target-school-to-delete');

      final fakeApi = SafetyTestApiClient();
      fakeApi.registeredTenants.add({
        'id': 'target-tenant-to-delete',
        'name': 'Target Org',
        'code': 'target-code',
        'status': 'ACTIVE',
        'is_active': true,
      });

      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(fakeSession),
          apiClientProvider.overrideWithValue(fakeApi),
        ],
      );

      container.read(selectedTenantIdProvider.notifier).state = 'target-tenant-to-delete';
      container.read(selectedSchoolIdProvider.notifier).state = 'target-school-to-delete';

      await container.read(tenantsListProvider.notifier).deleteTenantPermanent('target-tenant-to-delete');

      expect(container.read(selectedTenantIdProvider), isNull);
      expect(container.read(selectedSchoolIdProvider), isNull);
      expect(await fakeSession.getTenantId(), '');
      expect(await fakeSession.getSchoolId(), '');
    });

    test('Tenant code normalizer and slug generator unit tests', () {
      expect(SchoolOnboardingValidators.generateTenantCode('Telangana Model School and Junior College'), 'telangana-model-school-and-junior-college');
      expect(SchoolOnboardingValidators.generateTenantCode('Telangana Model School and Junior College', attempt: 2), 'telangana-model-school-and-junior-college-2');
      expect(SchoolOnboardingValidators.normalizeTenantCode('TS_EDU'), 'ts-edu');
      expect(SchoolOnboardingValidators.normalizeTenantCode('Special @#\$ Organization!!! Name'), 'special-organization-name');
    });
  });
}
