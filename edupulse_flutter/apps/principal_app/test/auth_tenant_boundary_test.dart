import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:principal_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:principal_app/features/dashboard/presentation/providers/active_school_provider.dart';

const testJwt =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJkMGVlZDQzMS0zNDhmLTRiN2YtOTIxMy00Y2I4NzdlMTlhNjUiLCJ0ZW5hbnRfaWQiOiJmMDA0YTIxNC1hYjNlLTQ0M2QtYTY4My01ODhjNjY0YTA5ODcifQ.sig';

class MockAuthRepository implements AuthRepository {
  final String jwtToken;
  final String expectedTenantId;

  MockAuthRepository({
    this.jwtToken = testJwt,
    this.expectedTenantId = 'f004a214-ab3e-443d-a683-588c664a0987',
  });

  @override
  Future<ApiResult<SessionToken>> login({
    required String email,
    required String password,
  }) async {
    return ApiResult.success(
      SessionToken(
        accessToken: jwtToken,
        refreshToken: 'refresh_principal',
        tokenType: 'bearer',
      ),
    );
  }

  @override
  Future<ApiResult<UserEntity>> getCurrentUser() async {
    return ApiResult.success(
      UserEntity(
        id: 'd0eed431-348f-4b7f-9213-4cb877e19a65',
        email: 'principal.ts001@telanganaschool.edu',
        firstName: 'Telangana',
        lastName: 'Principal',
        tenantId: expectedTenantId,
        isSuperuser: false,
        roles: const ['PRINCIPAL'],
        schools: const ['5f6b2567-c6e7-4d1c-98fa-b9c23e08dddd'],
      ),
    );
  }

  @override
  Future<ApiResult<void>> logout({required String refreshToken}) async {
    return const ApiResult.success(null);
  }

  @override
  Future<ApiResult<SessionToken>> refreshToken({required String refreshToken}) async {
    return ApiResult.success(
      SessionToken(
        accessToken: jwtToken,
        refreshToken: 'refresh_rotated',
        tokenType: 'bearer',
      ),
    );
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

  @override
  Future<ApiResult<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return const ApiResult.success(null);
  }
}

class InMemorySessionManager implements SessionManager {
  String? accessToken;
  String? refreshToken;
  String? tenantId;
  String? schoolId;
  String? tenantName;
  String? schoolName;

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<String?> getTenantId() async => tenantId;

  @override
  Future<void> saveTenantId(String value) async {
    tenantId = value;
  }

  @override
  Future<String?> getSchoolId() async => schoolId;

  @override
  Future<void> saveSchoolId(String value) async {
    schoolId = value;
  }

  @override
  Future<String?> getTenantName() async => tenantName;

  @override
  Future<void> saveTenantName(String value) async {
    tenantName = value;
  }

  @override
  Future<String?> getSchoolName() async => schoolName;

  @override
  Future<void> saveSchoolName(String value) async {
    schoolName = value;
  }

  @override
  Future<void> saveSession(SessionToken token) async {
    accessToken = token.accessToken;
    refreshToken = token.refreshToken;
    final tid = token.tenantId;
    if (tid != null && tid.isNotEmpty) {
      tenantId = tid;
    }
  }

  @override
  Future<void> clearSession([String source = 'SessionManager.clearSession']) async {
    accessToken = null;
    refreshToken = null;
    tenantId = null;
    schoolId = null;
    tenantName = null;
    schoolName = null;
  }

  @override
  Future<bool> hasSession() async {
    return accessToken != null && accessToken!.isNotEmpty &&
           refreshToken != null && refreshToken!.isNotEmpty;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Principal App Auth Tenant Boundary Tests', () {
    late InMemorySessionManager sessionManager;
    late MockAuthRepository authRepo;

    setUp(() {
      sessionManager = InMemorySessionManager();
      authRepo = MockAuthRepository();
    });

    ProviderContainer createContainer() {
      return ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(sessionManager),
          authRepositoryProvider.overrideWithValue(authRepo),
        ],
      );
    }

    test('1. Successful login synchronizes tenant ID from JWT before user profile retrieval', () async {
      final container = createContainer();

      expect(container.read(selectedTenantIdProvider), isNull);

      final notifier = container.read(authStateProvider.notifier);
      await notifier.login('principal.ts001@telanganaschool.edu', 'ValidPassword@123');

      final state = container.read(authStateProvider);
      expect(state, isA<Authenticated>());
      final user = (state as Authenticated).user;
      expect(user.email, 'principal.ts001@telanganaschool.edu');

      expect(container.read(selectedTenantIdProvider), 'f004a214-ab3e-443d-a683-588c664a0987');
      expect(container.read(activeTenantIdProvider), 'f004a214-ab3e-443d-a683-588c664a0987');
      expect(await sessionManager.getTenantId(), 'f004a214-ab3e-443d-a683-588c664a0987');
      expect(container.read(activeSchoolIdProvider), '5f6b2567-c6e7-4d1c-98fa-b9c23e08dddd');
    });

    test('2. Stale persisted tenant in storage is overwritten by authoritative JWT claims on login', () async {
      sessionManager.tenantId = 'stale-tenant-previous-session';

      final container = createContainer();
      final notifier = container.read(authStateProvider.notifier);
      await notifier.login('principal.ts001@telanganaschool.edu', 'ValidPassword@123');

      expect(container.read(selectedTenantIdProvider), 'f004a214-ab3e-443d-a683-588c664a0987');
      expect(await sessionManager.getTenantId(), 'f004a214-ab3e-443d-a683-588c664a0987');
    });

    test('3. checkAuth restores tenant boundary from stored JWT if storage tenant was absent', () async {
      sessionManager.accessToken = testJwt;
      sessionManager.refreshToken = 'existing_refresh';
      sessionManager.tenantId = null;

      final container = createContainer();
      final notifier = container.read(authStateProvider.notifier);
      await notifier.checkAuth();

      expect(container.read(authStateProvider), isA<Authenticated>());
      expect(container.read(selectedTenantIdProvider), 'f004a214-ab3e-443d-a683-588c664a0987');
      expect(await sessionManager.getTenantId(), 'f004a214-ab3e-443d-a683-588c664a0987');
    });

    test('4. Logout completely wipes tenant context, school context, and session storage', () async {
      final container = createContainer();
      final notifier = container.read(authStateProvider.notifier);
      await notifier.login('principal.ts001@telanganaschool.edu', 'ValidPassword@123');

      expect(container.read(authStateProvider), isA<Authenticated>());
      expect(container.read(selectedTenantIdProvider), isNotNull);

      await notifier.logout();

      expect(container.read(authStateProvider), isA<Unauthenticated>());
      expect(container.read(selectedTenantIdProvider), isNull);
      expect(container.read(activeSchoolIdProvider), isNull);
      expect(await sessionManager.hasSession(), isFalse);
      expect(await sessionManager.getTenantId(), isNull);
    });
  });
}
