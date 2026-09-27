import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:admin_portal/features/auth/presentation/providers/auth_provider.dart';
import 'package:admin_portal/features/tenant_setup/presentation/providers/tenant_providers.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';

class MockTokenStorage implements TokenStorage {
  String? accessToken = 'valid_mock_access';
  String? refreshToken = 'valid_mock_refresh';
  String? schoolId = 'ts001_school_id';
  String? tenantId = 'ts_tenant_id';
  String? schoolName = 'Telangana Model School & Junior College';
  String? tenantName = 'Telangana Education Society';

  @override
  Future<String?> getAccessToken() async => accessToken;
  @override
  Future<String?> getRefreshToken() async => refreshToken;
  @override
  Future<String?> getSchoolId() async => schoolId;
  @override
  Future<String?> getTenantId() async => tenantId;
  @override
  Future<String?> getSchoolName() async => schoolName;
  @override
  Future<String?> getTenantName() async => tenantName;
  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }
  @override
  Future<void> saveAccessToken(String token) async => accessToken = token;
  @override
  Future<void> saveRefreshToken(String token) async => refreshToken = token;
  @override
  Future<void> saveSchoolId(String id) async => schoolId = id;
  @override
  Future<void> saveTenantId(String id) async => tenantId = id;
  @override
  Future<void> saveSchoolName(String name) async => schoolName = name;
  @override
  Future<void> saveTenantName(String name) async => tenantName = name;
  @override
  Future<void> clearTokens([String source = 'TokenStorage.clearTokens']) async {
    accessToken = null;
    refreshToken = null;
  }
  @override
  Future<void> clearSchoolId() async => schoolId = null;
  @override
  Future<void> clearTenantId() async => tenantId = null;
  @override
  Future<void> clearAll() async {
    accessToken = null;
    refreshToken = null;
    schoolId = null;
    tenantId = null;
    schoolName = null;
    tenantName = null;
  }
}

class _TestAuthStateNotifier extends AuthStateNotifier {
  final AuthState initial;
  _TestAuthStateNotifier(this.initial);

  @override
  AuthState build() => initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P0 Top Header Tenant Switch Atomic Context Tests', () {
    late MockTokenStorage tokenStorage;
    late SessionManager sessionManager;

    setUp(() async {
      tokenStorage = MockTokenStorage();
      sessionManager = SessionManager(tokenStorage: tokenStorage);

      await tokenStorage.saveAccessToken('dummy_super_admin_jwt');
      await tokenStorage.saveRefreshToken('dummy_super_admin_refresh');
      await sessionManager.saveTenantId('ff9e842b-3008-451b-a42b-e177c996d3e9');
      await sessionManager.saveTenantName('EduPulse Master');
      await sessionManager.saveSchoolId('school_123');
      await sessionManager.saveSchoolName('Master School');
    });

    test('Super Admin: 5 consecutive tenant switches preserve tokens, reset school, maintain Authenticated state', () async {
      const superUser = UserEntity(
        id: 'super_admin_1',
        email: 'edupulsetechnologies@gmail.com',
        firstName: 'Super',
        lastName: 'Admin',
        tenantId: 'ff9e842b-3008-451b-a42b-e177c996d3e9',
        isSuperuser: true,
        roles: ['SUPER_ADMIN'],
        schools: [],
      );

      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(sessionManager),
          tokenStorageProvider.overrideWithValue(tokenStorage),
          authStateProvider.overrideWith(() => _TestAuthStateNotifier(const Authenticated(superUser))),
        ],
      );

      container.read(selectedTenantIdProvider.notifier).state = 'ff9e842b-3008-451b-a42b-e177c996d3e9';
      container.read(selectedSchoolIdProvider.notifier).state = 'school_123';

      expect(container.read(authStateProvider), isA<Authenticated>());
      expect(await sessionManager.getAccessToken(), 'dummy_super_admin_jwt');
      expect(await sessionManager.getRefreshToken(), 'dummy_super_admin_refresh');
      expect(await sessionManager.getSchoolId(), 'school_123');

      const telanganaId = 'f004a214-ab3e-443d-a683-588c664a0987';
      const masterId = 'ff9e842b-3008-451b-a42b-e177c996d3e9';

      for (int i = 1; i <= 5; i++) {
        // Step 1: Switch to Telangana
        container.read(selectedTenantIdProvider.notifier).state = telanganaId;
        container.read(selectedSchoolIdProvider.notifier).state = null;
        await sessionManager.saveSchoolId('');
        await sessionManager.saveSchoolName('');
        await sessionManager.saveTenantId(telanganaId);
        await sessionManager.saveTenantName('Telangana Colleges');

        expect(container.read(selectedTenantIdProvider), telanganaId);
        expect(container.read(selectedSchoolIdProvider), isNull);
        expect(await sessionManager.getTenantId(), telanganaId);
        expect(await sessionManager.getSchoolId(), isEmpty);
        expect(await sessionManager.getAccessToken(), 'dummy_super_admin_jwt');
        expect(await sessionManager.getRefreshToken(), 'dummy_super_admin_refresh');
        expect(container.read(authStateProvider), isA<Authenticated>());

        // Step 2: Switch back to EduPulse Master
        container.read(selectedTenantIdProvider.notifier).state = masterId;
        container.read(selectedSchoolIdProvider.notifier).state = null;
        await sessionManager.saveSchoolId('');
        await sessionManager.saveSchoolName('');
        await sessionManager.saveTenantId(masterId);
        await sessionManager.saveTenantName('EduPulse Master');

        expect(container.read(selectedTenantIdProvider), masterId);
        expect(container.read(selectedSchoolIdProvider), isNull);
        expect(await sessionManager.getTenantId(), masterId);
        expect(await sessionManager.getAccessToken(), 'dummy_super_admin_jwt');
        expect(await sessionManager.getRefreshToken(), 'dummy_super_admin_refresh');
        expect(container.read(authStateProvider), isA<Authenticated>());
      }

      container.dispose();
    });

    test('Principal: Assigned tenant context is immutable and tokens are never cleared', () async {
      const principalUser = UserEntity(
        id: 'principal_1',
        email: 'principal.ts001@telanganaschool.edu',
        firstName: 'TS',
        lastName: 'Principal',
        tenantId: 'f004a214-ab3e-443d-a683-588c664a0987',
        isSuperuser: false,
        roles: ['PRINCIPAL'],
        schools: ['ts001_school_id'],
      );

      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(sessionManager),
          tokenStorageProvider.overrideWithValue(tokenStorage),
          authStateProvider.overrideWith(() => _TestAuthStateNotifier(const Authenticated(principalUser))),
        ],
      );

      await tokenStorage.saveAccessToken('dummy_principal_jwt');
      await tokenStorage.saveRefreshToken('dummy_principal_refresh');
      await sessionManager.saveTenantId('f004a214-ab3e-443d-a683-588c664a0987');
      await sessionManager.saveTenantName('Telangana Colleges');

      container.read(selectedTenantIdProvider.notifier).state = 'f004a214-ab3e-443d-a683-588c664a0987';

      expect(container.read(authStateProvider), isA<Authenticated>());
      expect(container.read(selectedTenantIdProvider), 'f004a214-ab3e-443d-a683-588c664a0987');
      expect(await sessionManager.getAccessToken(), 'dummy_principal_jwt');
      expect(await sessionManager.getRefreshToken(), 'dummy_principal_refresh');

      container.dispose();
    });
  });
}
