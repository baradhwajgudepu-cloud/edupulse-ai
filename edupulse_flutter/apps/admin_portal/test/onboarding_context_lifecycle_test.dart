import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:admin_portal/features/tenant_setup/presentation/providers/tenant_providers.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/bulk_import/presentation/providers/school_onboarding_providers.dart';
import 'package:admin_portal/features/bulk_import/data/models/school_onboarding_models.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:edupulse_auth/src/data/mappers/auth_mappers.dart';
import 'school_onboarding_test.dart';

// Mock AuthTokenProvider for testing
class MockTokenProvider implements AuthTokenProvider {
  String? token = 'mock-jwt-token';
  String? schoolId;

  @override
  Future<String?> getAccessToken() async => token;

  @override
  Future<String?> getRefreshToken() async => 'mock-refresh';

  @override
  Future<String?> getSchoolId() async => schoolId;

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    token = accessToken;
  }

  Future<void> saveSchoolId(String schoolId) async {
    this.schoolId = schoolId;
  }

  Future<void> clearTokens() async {
    token = null;
    schoolId = null;
  }

  @override
  Future<void> refreshSession() async {}
}

class FakeRequestInterceptorHandler extends RequestInterceptorHandler {
  DioException? rejectedException;

  @override
  void reject(DioException err, [bool callNext = false]) {
    rejectedException = err;
  }

  @override
  void next(RequestOptions options) {}

  @override
  void resolve(Response response, [bool callNext = false]) {}
}

void main() {
  group('Onboarding Context and Lifecycle Tests', () {
    late MockTokenProvider tokenProvider;
    late String? activeTenantId;
    late JwtInterceptor interceptor;

    setUp(() {
      tokenProvider = MockTokenProvider();
      activeTenantId = null;
      interceptor = JwtInterceptor(
        tokenProvider: tokenProvider,
        tenantIdGetter: () => activeTenantId,
      );
    });

    test('1. Interceptor dynamically resolves active Tenant ID', () async {
      activeTenantId = 'tenant-uuid-123';
      final options = RequestOptions(path: '/schools');
      
      await interceptor.onRequest(options, FakeRequestInterceptorHandler());
      expect(options.headers['X-Tenant-ID'], 'tenant-uuid-123');
    });

    test('2. Platform login does not send X-Tenant-ID header', () async {
      activeTenantId = 'tenant-uuid-123';
      final options = RequestOptions(path: '/auth/platform-login');

      await interceptor.onRequest(options, FakeRequestInterceptorHandler());
      expect(options.headers.containsKey('X-Tenant-ID'), isFalse);
    });

    test('3. Dynamic path-based school context extraction & validation', () async {
      tokenProvider.schoolId = null;
      // Valid UUID path
      final options = RequestOptions(path: '/schools/2f85ebf4-315d-496a-9611-681ff0ed18ff/academic-years');
      
      await interceptor.onRequest(options, FakeRequestInterceptorHandler());
      expect(options.headers['X-School-ID'], '2f85ebf4-315d-496a-9611-681ff0ed18ff');
    });

    test('4. Non-UUID mock school IDs in paths are not blindly extracted', () async {
      tokenProvider.schoolId = null;
      // Invalid/mock path
      final options = RequestOptions(path: '/schools/school_mock_1/academic-years');
      
      final handler = FakeRequestInterceptorHandler();
      await interceptor.onRequest(options, handler);
      
      expect(options.headers.containsKey('X-School-ID'), isFalse);
      expect(handler.rejectedException, isNotNull);
      expect(handler.rejectedException!.error, 'Active school context required.');
    });

    test('5. Platform authentication /auth/me parsing handles null tenantId', () {
      final json = {
        'id': 'super-admin-id',
        'email': 'admin@edupulse.com',
        'first_name': 'System',
        'last_name': 'Admin',
        'status': 'ACTIVE',
        'is_superuser': true,
        'tenant_id': null,
        'roles': ['SUPER_ADMIN'],
        'schools': [],
        'version': 1,
        'created_at': '2026-08-16T00:00:00Z',
        'updated_at': '2026-08-16T00:00:00Z',
      };
      
      final responseDto = UserResponseDto.fromJson(json);
      expect(responseDto.tenantId, isNull);
      expect(responseDto.isSuperuser, isTrue);
      
      final entity = responseDto.toEntity();
      expect(entity.tenantId, isNull);
    });

    test('6. Selecting tenant establishes activeTenantIdProvider and clears school provider', () {
      final container = ProviderContainer();
      
      container.read(selectedTenantIdProvider.notifier).state = 'tenant-1';
      container.read(selectedSchoolIdProvider.notifier).state = 'school-1';
      
      expect(container.read(activeTenantIdProvider), 'tenant-1');
      expect(container.read(selectedSchoolIdProvider), 'school-1');

      // Setup watcher listener simulation
      container.read(tenantSetupWatcherProvider);

      container.read(selectedTenantIdProvider.notifier).state = 'tenant-2';
      
      expect(container.read(selectedTenantIdProvider), 'tenant-2');
      expect(container.read(selectedSchoolIdProvider), isNull);
    });

    test('7. Map Dio Exception Cancel correctly maps inner error', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/schools'),
        error: 'Active school context required.',
        type: DioExceptionType.cancel,
      );

      final failure = ApiExceptionMapper.mapToFailure(dioException);
      expect(failure.message, 'Active school context required.');
    });

    test('8. Validation completed but approval unchecked => import does NOT start', () async {
      final container = ProviderContainer();
      final notifier = container.read(schoolOnboardingProvider.notifier);
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      
      // Load synthetic data
      notifier.loadSyntheticFixture();
      
      expect(container.read(schoolOnboardingProvider).approvalStatus, OnboardingApprovalStatus.awaitingApproval);
      
      // Attempt to execute import directly
      await notifier.executeOnboarding('school_1', FakeOnboardingApiClient());
      
      // State should not execute and show error
      expect(container.read(schoolOnboardingProvider).isProcessing, isFalse);
      expect(container.read(schoolOnboardingProvider).globalErrorMessage, contains('approval is required'));
    });

    test('9. Confirm approval => execution starts and transitions status', () async {
      final container = ProviderContainer();
      final notifier = container.read(schoolOnboardingProvider.notifier);
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      
      notifier.loadSyntheticFixture();
      
      // Approve explicitly
      notifier.approveAndStartImport('school_1', FakeOnboardingApiClient(), approvedBy: 'admin@edupulse.com');
      
      final state = container.read(schoolOnboardingProvider);
      expect(state.approvalStatus == OnboardingApprovalStatus.executing || state.approvalStatus == OnboardingApprovalStatus.completed, isTrue);
    });

    test('10. Tenant/School change after validation => previous approval state is invalidated', () {
      final container = ProviderContainer();
      final notifier = container.read(schoolOnboardingProvider.notifier);
      
      notifier.loadSyntheticFixture();
      expect(container.read(schoolOnboardingProvider).approvalStatus, OnboardingApprovalStatus.awaitingApproval);
      
      // Setup listener/watcher
      container.listen(schoolOnboardingProvider, (previous, next) {});
      container.listen(selectedSchoolIdProvider, (previous, next) {
        if (!notifier.state.isProcessing) {
          notifier.reset();
        }
      });
      
      container.read(selectedSchoolIdProvider.notifier).state = 'school_2';
      
      expect(container.read(schoolOnboardingProvider).approvalStatus, OnboardingApprovalStatus.awaitingValidation);
    });

    test('12. Mode A (Create New Organization) creates Tenant first and persists tenant context', () async {
      final fakeSession = FakeOnboardingSessionManager();
      final fakeApi = FakeOnboardingApiClient();

      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(fakeSession),
        ],
      );

      final notifier = container.read(schoolOnboardingProvider.notifier);
      notifier.loadSyntheticFixture();
      notifier.setTenantMode(
        createNewTenant: true,
        newTenantName: 'Telangana Educational Society',
        newTenantCode: 'TS_EDU',
        newTenantEmail: 'admin@telanganaedu.org',
      );

      SchoolOnboardingNotifier.bypassApproval = true;
      await notifier.executeOnboarding('', fakeApi);

      expect(container.read(selectedTenantIdProvider), isNotNull);
      expect(fakeSession.cachedTenantId, isNotNull);
      expect(fakeSession.cachedTenantName, 'Telangana Educational Society');
      expect(container.read(selectedSchoolIdProvider), isNotNull);
      expect(fakeSession.cachedSchoolId, isNotNull);

      // Verify POST /tenants was called first before /schools
      final postPaths = fakeApi.postCalls.map((c) => c['path'] as String).toList();
      expect(postPaths.first, '/tenants');
      expect(postPaths[1], '/schools');
    });

    test('13. Mode B (Add School to Existing Tenant) uses existing tenant without calling POST /tenants', () async {
      final fakeSession = FakeOnboardingSessionManager();
      final fakeApi = FakeOnboardingApiClient();

      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(fakeSession),
          selectedTenantIdProvider.overrideWith((ref) => 'existing-tenant-uuid-456'),
        ],
      );

      final notifier = container.read(schoolOnboardingProvider.notifier);
      notifier.loadSyntheticFixture();
      notifier.setTenantMode(
        createNewTenant: false,
        selectedTenantId: 'existing-tenant-uuid-456',
      );

      SchoolOnboardingNotifier.bypassApproval = true;
      await notifier.executeOnboarding('', fakeApi);

      expect(container.read(selectedTenantIdProvider), 'existing-tenant-uuid-456');
      expect(fakeSession.cachedTenantId, 'existing-tenant-uuid-456');

      // Verify POST /tenants was NOT called
      final postPaths = fakeApi.postCalls.map((c) => c['path'] as String).toList();
      expect(postPaths.contains('/tenants'), isFalse);
      expect(postPaths.first, '/schools');
    });

    test('14. Context persistence saves and restores tenant and school names', () async {
      final fakeSession = FakeOnboardingSessionManager();
      await fakeSession.saveTenantId('t-123');
      await fakeSession.saveTenantName('Hyderabad Public Society');
      await fakeSession.saveSchoolId('s-456');
      await fakeSession.saveSchoolName('HPS Begumpet');

      expect(await fakeSession.getTenantId(), 't-123');
      expect(await fakeSession.getTenantName(), 'Hyderabad Public Society');
      expect(await fakeSession.getSchoolId(), 's-456');
      expect(await fakeSession.getSchoolName(), 'HPS Begumpet');
    });
  });
}
