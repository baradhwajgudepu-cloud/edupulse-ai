import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:edupulse_config/edupulse_config.dart';
import 'package:admin_portal/core/routing/routes.dart';
import 'package:admin_portal/core/routing/app_router.dart';
import 'package:admin_portal/features/auth/presentation/providers/auth_provider.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';

class MockStartupTokenStorage implements TokenStorage {
  String? accessToken;
  String? refreshToken;
  String? schoolId;
  String? tenantId;
  String? schoolName;
  String? tenantName;

  MockStartupTokenStorage({
    this.accessToken,
    this.refreshToken,
    this.schoolId,
    this.tenantId,
    this.schoolName,
    this.tenantName,
  });

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
  Future<void> clearTokens([String source = 'MockStartupTokenStorage.clearTokens']) async {
    accessToken = null;
    refreshToken = null;
  }
  Future<void> clearSchoolId() async => schoolId = null;
  Future<void> clearTenantId() async => tenantId = null;
  Future<void> clearAll() async {
    accessToken = null;
    refreshToken = null;
    schoolId = null;
    tenantId = null;
    schoolName = null;
    tenantName = null;
  }
}

class FakeStartupAuthRepository implements AuthRepository, PlatformAuthRepository {
  ApiResult<UserEntity>? currentUserResult;
  ApiResult<SessionToken>? loginResult;
  int logoutCallCount = 0;

  @override
  Future<ApiResult<UserEntity>> getCurrentUser() async {
    return currentUserResult ??
        const ApiResult.success(UserEntity(
          id: 'admin_principal_1',
          email: 'principal.ts001@telanganaschool.edu',
          firstName: 'Ramesh',
          lastName: 'Chandra',
          tenantId: 'tenant_ts_001',
          isSuperuser: false,
          roles: ['PRINCIPAL'],
          schools: ['school_ts_001'],
          schoolNames: {'school_ts_001': 'Telangana Model School'},
        ));
  }

  @override
  Future<ApiResult<SessionToken>> login({required String email, required String password}) async {
    return loginResult ??
        const ApiResult.success(SessionToken(
          accessToken: 'header.eyJzdWIiOiIxIiwidGVuYW50X2lkIjoidGVuYW50X3RzXzAwMSJ9.signature',
          refreshToken: 'valid_refresh_token',
          tokenType: 'bearer',
        ));
  }

  @override
  Future<ApiResult<SessionToken>> platformLogin({required String email, required String password}) async {
    return login(email: email, password: password);
  }

  @override
  Future<ApiResult<void>> logout({required String refreshToken}) async {
    logoutCallCount++;
    return const ApiResult.success(null);
  }

  @override
  Future<ApiResult<SessionToken>> refreshToken({required String refreshToken}) async {
    return const ApiResult.success(SessionToken(
      accessToken: 'refreshed_access',
      refreshToken: 'refreshed_refresh',
      tokenType: 'bearer',
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

  @override
  Future<ApiResult<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return const ApiResult.success(null);
  }
}

ProviderContainer _createTestContainer({
  required MockStartupTokenStorage storage,
  required SessionManager sessionManager,
  required FakeStartupAuthRepository authRepo,
  BuildConfig? buildConfig,
}) {
  return ProviderContainer(
    overrides: [
      if (buildConfig != null) buildConfigProvider.overrideWithValue(buildConfig),
      tokenStorageProvider.overrideWithValue(storage),
      sessionManagerProvider.overrideWithValue(sessionManager),
      authRepositoryProvider.overrideWithValue(authRepo),
      validateSessionUseCaseProvider.overrideWithValue(ValidateSessionUseCase(authRepo)),
      logoutUseCaseProvider.overrideWithValue(LogoutUseCase(authRepo)),
      loginPlatformUseCaseProvider.overrideWithValue(LoginPlatformUseCase(authRepo)),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const validJwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidGVuYW50X2lkIjoidGVuYW50X3RzXzAwMSJ9.sig';

  late HttpServer mockBackendServer;
  late BuildConfig testBuildConfig;

  setUpAll(() async {
    mockBackendServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    mockBackendServer.listen((HttpRequest request) {
      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'status': 'healthy', 'database': 'healthy'}));
      request.response.close();
    });

    testBuildConfig = BuildConfig(
      env: AppEnvironment.dev,
      apiBaseUrl: 'http://${mockBackendServer.address.host}:${mockBackendServer.port}/api/v1/',
      tenantId: 'tenant_ts_001',
    );
  });

  tearDownAll(() async {
    await mockBackendServer.close(force: true);
  });

  group('EduPulse Admin Portal Startup Authentication Verification Suite', () {
    test('1. Valid session restores Authenticated state and resolves user context', () async {
      final storage = MockStartupTokenStorage(
        accessToken: validJwt,
        refreshToken: 'valid_refresh_token',
        tenantId: 'tenant_ts_001',
      );
      final sessionManager = SessionManager(tokenStorage: storage);
      final authRepo = FakeStartupAuthRepository();

      final container = _createTestContainer(
        storage: storage,
        sessionManager: sessionManager,
        authRepo: authRepo,
        buildConfig: testBuildConfig,
      );

      container.read(authStateProvider.notifier);
      await pumpEventQueue();

      final state = container.read(authStateProvider);
      expect(state, isA<Authenticated>());
      final user = (state as Authenticated).user;
      expect(user.email, 'principal.ts001@telanganaschool.edu');
      expect(user.roles, contains('PRINCIPAL'));
      expect(container.read(selectedSchoolIdProvider), 'school_ts_001');
      expect(container.read(selectedTenantIdProvider), 'tenant_ts_001');
      expect(await sessionManager.hasSession(), isTrue);
    });

    test('2. Missing token immediately routes to Unauthenticated without server call', () async {
      final storage = MockStartupTokenStorage(); // No tokens
      final sessionManager = SessionManager(tokenStorage: storage);
      final authRepo = FakeStartupAuthRepository();

      final container = _createTestContainer(
        storage: storage,
        sessionManager: sessionManager,
        authRepo: authRepo,
        buildConfig: testBuildConfig,
      );

      container.read(authStateProvider.notifier);
      await pumpEventQueue();

      final state = container.read(authStateProvider);
      expect(state, isA<Unauthenticated>());
      expect(await sessionManager.hasSession(), isFalse);

      // Verify router routes unauthenticated users on protected path to /login
      final redirect = appRouterRedirect(
        authState: state,
        matchedLocation: AppRoutes.dashboard,
      );
      expect(redirect, AppRoutes.login);
    });

    test('3. Expired or invalid token (HTTP 401 response) clears session and routes to Unauthenticated /login', () async {
      final storage = MockStartupTokenStorage(
        accessToken: 'expired_or_invalid_access',
        refreshToken: 'expired_or_invalid_refresh',
      );
      final sessionManager = SessionManager(tokenStorage: storage);
      final authRepo = FakeStartupAuthRepository();
      authRepo.currentUserResult = const ApiResult.failure(ApiFailure(
        message: 'Invalid authentication token.',
        type: ApiFailureType.unauthorized,
        statusCode: 401,
      ));

      final container = _createTestContainer(
        storage: storage,
        sessionManager: sessionManager,
        authRepo: authRepo,
        buildConfig: testBuildConfig,
      );

      container.read(authStateProvider.notifier);
      await pumpEventQueue();

      final state = container.read(authStateProvider);
      expect(state, isA<Unauthenticated>());
      // Storage and context MUST be cleared so user is never trapped in recovery loops
      expect(await sessionManager.getAccessToken(), isNull);
      expect(await sessionManager.getRefreshToken(), isNull);
      expect(await sessionManager.hasSession(), isFalse);
      expect(container.read(selectedSchoolIdProvider), isNull);
      expect(container.read(selectedTenantIdProvider), isNull);

      final redirect = appRouterRedirect(
        authState: state,
        matchedLocation: AppRoutes.dashboard,
      );
      expect(redirect, AppRoutes.login);
    });

    test('4. HTTP 403 response on session validation clears invalid session and routes to Unauthenticated /login', () async {
      final storage = MockStartupTokenStorage(
        accessToken: 'revoked_or_forbidden_access',
        refreshToken: 'revoked_or_forbidden_refresh',
      );
      final sessionManager = SessionManager(tokenStorage: storage);
      final authRepo = FakeStartupAuthRepository();
      authRepo.currentUserResult = const ApiResult.failure(ApiFailure(
        message: 'Forbidden: Account inactive or permissions revoked',
        type: ApiFailureType.unauthorized,
        statusCode: 403,
      ));

      final container = _createTestContainer(
        storage: storage,
        sessionManager: sessionManager,
        authRepo: authRepo,
        buildConfig: testBuildConfig,
      );

      container.read(authStateProvider.notifier);
      await pumpEventQueue();

      final state = container.read(authStateProvider);
      expect(state, isA<Unauthenticated>());
      // Storage and context MUST be cleared to prevent recurring 'Unable to restore your session' card
      expect(await sessionManager.getAccessToken(), isNull);
      expect(await sessionManager.getRefreshToken(), isNull);
      expect(await sessionManager.hasSession(), isFalse);
      expect(container.read(selectedSchoolIdProvider), isNull);
      expect(container.read(selectedTenantIdProvider), isNull);

      final redirect = appRouterRedirect(
        authState: state,
        matchedLocation: AppRoutes.dashboard,
      );
      expect(redirect, AppRoutes.login);
    });

    test('4B. HTTP 403 response with UserStatus.LOCKED clears tokens, context, sets AccountLocked, and routes to /login without retry loop', () async {
      final storage = MockStartupTokenStorage(
        accessToken: 'locked_user_access_token',
        refreshToken: 'locked_user_refresh_token',
        tenantId: 'tenant_locked_1',
        schoolId: 'school_locked_1',
      );
      final sessionManager = SessionManager(tokenStorage: storage);
      final authRepo = FakeStartupAuthRepository();
      authRepo.currentUserResult = const ApiResult.failure(ApiFailure(
        message: "Access denied. Account status is currently 'UserStatus.LOCKED.'",
        type: ApiFailureType.unknown,
        statusCode: 403,
      ));

      final container = _createTestContainer(
        storage: storage,
        sessionManager: sessionManager,
        authRepo: authRepo,
        buildConfig: testBuildConfig,
      );

      container.read(authStateProvider.notifier);
      await pumpEventQueue();

      final state = container.read(authStateProvider);
      expect(state, isA<AccountLocked>());
      expect(state, isA<Unauthenticated>());
      expect((state as AccountLocked).message, 'Your account is locked. Please contact your school administrator to unlock your account.');

      // 1. Tokens MUST be cleared
      expect(await sessionManager.getAccessToken(), isNull);
      expect(await sessionManager.getRefreshToken(), isNull);
      expect(await sessionManager.hasSession(), isFalse);

      // 2. Context MUST be cleared
      expect(container.read(selectedSchoolIdProvider), isNull);
      expect(container.read(selectedTenantIdProvider), isNull);
      expect(container.read(selectedAcademicYearIdProvider), isNull);

      // 3. authLockMessageProvider MUST be set for login screen
      expect(container.read(authLockMessageProvider), contains('Your account is locked'));

      // 4. Routes cleanly to /login
      final redirect = appRouterRedirect(
        authState: state,
        matchedLocation: AppRoutes.dashboard,
      );
      expect(redirect, AppRoutes.login);

      // 5. Subsequent checkAuth does NOT call server because tokens were purged (no retry loop)
      await container.read(authStateProvider.notifier).checkAuth();
      await pumpEventQueue();
      expect(container.read(authStateProvider), isA<Unauthenticated>());
    });

    test('5. Timeout failure preserves saved tokens and sets AuthError for recovery UI', () async {
      final storage = MockStartupTokenStorage(
        accessToken: 'valid_access_under_poor_connection',
        refreshToken: 'valid_refresh_under_poor_connection',
      );
      final sessionManager = SessionManager(tokenStorage: storage);
      final authRepo = FakeStartupAuthRepository();
      authRepo.currentUserResult = const ApiResult.failure(ApiFailure(
        message: 'Connection timed out while verifying your session. Please check your network.',
        type: ApiFailureType.network,
      ));

      final container = _createTestContainer(
        storage: storage,
        sessionManager: sessionManager,
        authRepo: authRepo,
        buildConfig: testBuildConfig,
      );

      container.read(authStateProvider.notifier);
      await pumpEventQueue();

      final state = container.read(authStateProvider);
      expect(state, isA<AuthError>());
      // Saved tokens MUST remain intact so user can Retry
      expect(await sessionManager.getAccessToken(), 'valid_access_under_poor_connection');
      expect(await sessionManager.getRefreshToken(), 'valid_refresh_under_poor_connection');
      expect(await sessionManager.hasSession(), isTrue);

      // Router redirect must keep user on protected route so recovery screen renders
      final redirect = appRouterRedirect(
        authState: state,
        matchedLocation: AppRoutes.dashboard,
      );
      expect(redirect, isNull);
    });

    test('6. Network failure preserves saved tokens and sets AuthError for recovery UI', () async {
      final storage = MockStartupTokenStorage(
        accessToken: 'valid_access_offline',
        refreshToken: 'valid_refresh_offline',
      );
      final sessionManager = SessionManager(tokenStorage: storage);
      final authRepo = FakeStartupAuthRepository();
      authRepo.currentUserResult = const ApiResult.failure(ApiFailure(
        message: 'SocketException: Failed host lookup: edupulse-api.run.app',
        type: ApiFailureType.network,
      ));

      final container = _createTestContainer(
        storage: storage,
        sessionManager: sessionManager,
        authRepo: authRepo,
        buildConfig: testBuildConfig,
      );

      container.read(authStateProvider.notifier);
      await pumpEventQueue();

      final state = container.read(authStateProvider);
      expect(state, isA<AuthError>());
      // Saved tokens MUST be preserved
      expect(await sessionManager.getAccessToken(), 'valid_access_offline');
      expect(await sessionManager.hasSession(), isTrue);

      final redirect = appRouterRedirect(
        authState: state,
        matchedLocation: AppRoutes.dashboard,
      );
      expect(redirect, isNull);
    });

    test('7. Malformed response or HTTP 500 Server Error preserves session and sets AuthError', () async {
      final storage = MockStartupTokenStorage(
        accessToken: 'valid_access_server_error',
        refreshToken: 'valid_refresh_server_error',
      );
      final sessionManager = SessionManager(tokenStorage: storage);
      final authRepo = FakeStartupAuthRepository();
      authRepo.currentUserResult = const ApiResult.failure(ApiFailure(
        message: 'HTTP 500 Internal Server Error: Database temporary restart',
        type: ApiFailureType.server,
        statusCode: 500,
      ));

      final container = _createTestContainer(
        storage: storage,
        sessionManager: sessionManager,
        authRepo: authRepo,
        buildConfig: testBuildConfig,
      );

      container.read(authStateProvider.notifier);
      await pumpEventQueue();

      final state = container.read(authStateProvider);
      expect(state, isA<AuthError>());
      // Server-side errors MUST NOT wipe client credentials
      expect(await sessionManager.getAccessToken(), 'valid_access_server_error');
      expect(await sessionManager.hasSession(), isTrue);

      final redirect = appRouterRedirect(
        authState: state,
        matchedLocation: AppRoutes.dashboard,
      );
      expect(redirect, isNull);
    });

    test('8. Successful login followed by session validation sets Authenticated', () async {
      final storage = MockStartupTokenStorage(); // Initially logged out
      final sessionManager = SessionManager(tokenStorage: storage);
      final authRepo = FakeStartupAuthRepository();

      final container = _createTestContainer(
        storage: storage,
        sessionManager: sessionManager,
        authRepo: authRepo,
        buildConfig: testBuildConfig,
      );

      final notifier = container.read(authStateProvider.notifier);
      await pumpEventQueue();
      expect(container.read(authStateProvider), isA<Unauthenticated>());

      // Perform login
      await notifier.login('principal.ts001@telanganaschool.edu', 'ValidPassword123!');
      await pumpEventQueue();

      final state = container.read(authStateProvider);
      expect(state, isA<Authenticated>());
      final user = (state as Authenticated).user;
      expect(user.email, 'principal.ts001@telanganaschool.edu');
      expect(await sessionManager.hasSession(), isTrue);
      expect(await sessionManager.getAccessToken(), isNotNull);
    });

    test('9. Explicit logout clears session, clears context, and sets Unauthenticated', () async {
      final storage = MockStartupTokenStorage(
        accessToken: validJwt,
        refreshToken: 'valid_refresh_token',
        schoolId: 'school_ts_001',
        tenantId: 'tenant_ts_001',
      );
      final sessionManager = SessionManager(tokenStorage: storage);
      final authRepo = FakeStartupAuthRepository();

      final container = _createTestContainer(
        storage: storage,
        sessionManager: sessionManager,
        authRepo: authRepo,
        buildConfig: testBuildConfig,
      );

      final notifier = container.read(authStateProvider.notifier);
      await pumpEventQueue();
      expect(container.read(authStateProvider), isA<Authenticated>());

      await notifier.logout();
      await pumpEventQueue();

      final state = container.read(authStateProvider);
      expect(state, isA<Unauthenticated>());
      expect(await sessionManager.hasSession(), isFalse);
      expect(await sessionManager.getAccessToken(), isNull);
      expect(await sessionManager.getRefreshToken(), isNull);
      expect(container.read(selectedSchoolIdProvider), isNull);
      expect(container.read(selectedTenantIdProvider), isNull);
      expect(authRepo.logoutCallCount, 1);
    });

    test('10. Empty, whitespace, "null", and "undefined" tokens are rejected by SessionManager', () async {
      final invalidTokens = ['', '   ', 'null', 'undefined', '\n\t'];
      for (final invalid in invalidTokens) {
        final storage = MockStartupTokenStorage(
          accessToken: invalid,
          refreshToken: invalid,
        );
        final sessionManager = SessionManager(tokenStorage: storage);
        expect(await sessionManager.hasSession(), isFalse, reason: 'Failed for token: "$invalid"');
      }
    });

    test('11. Failed post-login session validation clears invalid credentials', () async {
      final storage = MockStartupTokenStorage(); // Initially empty
      final sessionManager = SessionManager(tokenStorage: storage);
      final authRepo = FakeStartupAuthRepository();
      // Login endpoint succeeds, but subsequent getCurrentUser rejects with 401
      authRepo.currentUserResult = const ApiResult.failure(ApiFailure(
        message: 'Invalid authentication token post-login.',
        statusCode: 401,
        type: ApiFailureType.unauthorized,
      ));

      final container = _createTestContainer(
        storage: storage,
        sessionManager: sessionManager,
        authRepo: authRepo,
        buildConfig: testBuildConfig,
      );

      final notifier = container.read(authStateProvider.notifier);
      await pumpEventQueue();
      expect(container.read(authStateProvider), isA<Unauthenticated>());

      // Attempt login
      await notifier.login('principal.ts001@telanganaschool.edu', 'ValidPassword123!');
      await pumpEventQueue();

      final state = container.read(authStateProvider);
      expect(state, isA<AuthError>());
      // Invalid credentials must have been cleared from storage
      expect(await sessionManager.hasSession(), isFalse);
      expect(await sessionManager.getAccessToken(), isNull);
    });
  });
}
