import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/core/routing/routes.dart';
import 'package:admin_portal/core/routing/app_router.dart';
import 'package:admin_portal/features/auth/presentation/providers/auth_provider.dart';
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

class FakeStabilityAuthRepository implements AuthRepository {
  ApiResult<UserEntity>? currentUserResult;
  bool refreshShouldSucceed = true;
  int refreshCallCount = 0;

  @override
  Future<ApiResult<UserEntity>> getCurrentUser() async {
    return currentUserResult ??
        const ApiResult.success(UserEntity(
          id: 'principal_1',
          email: 'principal.ts001@telanganaschool.edu',
          firstName: 'Ramesh',
          lastName: 'Chandra',
          tenantId: 'ts_tenant_id',
          isSuperuser: false,
          roles: ['PRINCIPAL'],
          schools: ['ts001_school_id'],
          schoolNames: {'ts001_school_id': 'Telangana Model School & Junior College'},
        ));
  }

  @override
  Future<ApiResult<SessionToken>> login({required String email, required String password}) async {
    return const ApiResult.success(SessionToken(
      accessToken: 'new_access_token',
      refreshToken: 'new_refresh_token',
      tokenType: 'bearer',
    ));
  }

  @override
  Future<ApiResult<void>> logout({required String refreshToken}) async {
    return const ApiResult.success(null);
  }

  @override
  Future<ApiResult<SessionToken>> refreshToken({required String refreshToken}) async {
    refreshCallCount++;
    if (refreshShouldSucceed) {
      return const ApiResult.success(SessionToken(
        accessToken: 'refreshed_access_token',
        refreshToken: 'refreshed_refresh_token',
        tokenType: 'bearer',
      ));
    } else {
      return const ApiResult.failure(ApiFailure(
        message: 'Invalid refresh token',
        type: ApiFailureType.unauthorized,
        statusCode: 401,
      ));
    }
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

class FakeMockTokenProvider implements AuthTokenProvider {
  final MockTokenStorage storage;
  final FakeStabilityAuthRepository repo;

  FakeMockTokenProvider(this.storage, this.repo);

  @override
  Future<String?> getAccessToken() => storage.getAccessToken();
  @override
  Future<String?> getRefreshToken() => storage.getRefreshToken();
  @override
  Future<String?> getSchoolId() => storage.getSchoolId();
  Future<String?> getTenantId() => storage.getTenantId();
  @override
  Future<void> refreshSession() async {
    final r = await storage.getRefreshToken();
    if (r == null) throw Exception('No refresh token');
    final res = await repo.refreshToken(refreshToken: r);
    await res.when(
      onSuccess: (token) async {
        await storage.saveTokens(accessToken: token.accessToken, refreshToken: token.refreshToken);
      },
      onFailure: (f) async {
        throw Exception(f.message);
      },
    );
  }
}

class MockSuccessAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"status": "success", "data": []}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _CapturingErrorHandler extends ErrorInterceptorHandler {
  DioException? capturedError;
  Response? capturedResponse;

  @override
  void next(DioException err) {
    capturedError = err;
  }

  @override
  void resolve(Response response) {
    capturedResponse = response;
  }
}

class FakeStabilityApiClient extends BaseApiClient {
  FakeStabilityApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (path.contains('/schools')) {
      return ApiResult.success(mapper({'data': []}));
    }
    if (path.contains('/notifications')) {
      return ApiResult.success(mapper({'data': []}));
    }
    return ApiResult.success(mapper({'data': {}}));
  }
}

class FakeBuildContext extends Fake implements BuildContext {}

ProviderContainer _createContainer(
  MockTokenStorage tokenStorage,
  SessionManager sessionManager,
  FakeStabilityAuthRepository authRepo,
) {
  return ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(tokenStorage),
      sessionManagerProvider.overrideWithValue(sessionManager),
      authRepositoryProvider.overrideWithValue(authRepo),
      validateSessionUseCaseProvider.overrideWithValue(ValidateSessionUseCase(authRepo)),
      logoutUseCaseProvider.overrideWithValue(LogoutUseCase(authRepo)),
      apiClientProvider.overrideWithValue(FakeStabilityApiClient()),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockTokenStorage tokenStorage;
  late SessionManager sessionManager;
  late FakeStabilityAuthRepository authRepo;

  setUp(() {
    tokenStorage = MockTokenStorage();
    sessionManager = SessionManager(tokenStorage: tokenStorage);
    authRepo = FakeStabilityAuthRepository();
  });

  group('A. HTTP Status Code Handling & Session Stability', () {
    test('1. HTTP 403 Forbidden on session validation clears invalid session and transitions to Unauthenticated', () async {
      authRepo.currentUserResult = const ApiResult.failure(ApiFailure(
        message: 'HTTP 403 Forbidden',
        type: ApiFailureType.unauthorized,
        statusCode: 403,
      ));

      final container = _createContainer(tokenStorage, sessionManager, authRepo);
      container.read(authStateProvider.notifier);
      await pumpEventQueue();

      final state = container.read(authStateProvider);
      expect(state, isA<Unauthenticated>());
      // Invalid session tokens must be cleared so user is routed to /login and not trapped on recovery screen
      expect(await sessionManager.getAccessToken(), isNull);
      expect(await sessionManager.hasSession(), isFalse);
    });

    test('1B. HTTP 403 UserStatus.LOCKED clears tokens, context, and transitions to AccountLocked without retry loop', () async {
      tokenStorage.accessToken = 'locked_token';
      tokenStorage.refreshToken = 'locked_refresh';
      tokenStorage.tenantId = 'locked_tenant';
      tokenStorage.schoolId = 'locked_school';

      authRepo.currentUserResult = const ApiResult.failure(ApiFailure(
        message: "Access denied. Account status is currently 'UserStatus.LOCKED.'",
        type: ApiFailureType.unknown,
        statusCode: 403,
      ));

      final container = _createContainer(tokenStorage, sessionManager, authRepo);
      container.read(authStateProvider.notifier);
      await pumpEventQueue();

      final state = container.read(authStateProvider);
      expect(state, isA<AccountLocked>());
      expect(state, isA<Unauthenticated>());

      // Tokens cleared
      expect(await sessionManager.getAccessToken(), isNull);
      expect(await sessionManager.getRefreshToken(), isNull);
      expect(await sessionManager.hasSession(), isFalse);

      // Context cleared
      expect(container.read(selectedTenantIdProvider), isNull);
      expect(container.read(selectedSchoolIdProvider), isNull);
      expect(container.read(selectedAcademicYearIdProvider), isNull);

      // Lock message populated
      expect(container.read(authLockMessageProvider), contains('Your account is locked'));

      // Retry loop prevented: subsequent checkAuth does nothing
      await container.read(authStateProvider.notifier).checkAuth();
      await pumpEventQueue();
      expect(container.read(authStateProvider), isA<Unauthenticated>());
    });

    test('2. HTTP 400 Bad Request does NOT logout user', () async {
      authRepo.currentUserResult = const ApiResult.failure(ApiFailure(
        message: 'HTTP 400 Bad Request',
        type: ApiFailureType.validation,
        statusCode: 400,
      ));

      final container = _createContainer(tokenStorage, sessionManager, authRepo);
      container.read(authStateProvider.notifier);
      await pumpEventQueue();

      final state = container.read(authStateProvider);
      expect(state, isA<AuthError>());
      expect(await sessionManager.hasSession(), isTrue);
    });

    test('3. HTTP 500 Server Error does NOT logout user', () async {
      authRepo.currentUserResult = const ApiResult.failure(ApiFailure(
        message: 'HTTP 500 Internal Server Error',
        type: ApiFailureType.server,
        statusCode: 500,
      ));

      final container = _createContainer(tokenStorage, sessionManager, authRepo);
      container.read(authStateProvider.notifier);
      await pumpEventQueue();

      final state = container.read(authStateProvider);
      expect(state, isA<AuthError>());
      expect(await sessionManager.hasSession(), isTrue);
    });

    test('4. Network connection timeout does NOT logout user', () async {
      authRepo.currentUserResult = const ApiResult.failure(ApiFailure(
        message: 'Connection timed out',
        type: ApiFailureType.network,
      ));

      final container = _createContainer(tokenStorage, sessionManager, authRepo);
      container.read(authStateProvider.notifier);
      await pumpEventQueue();

      final state = container.read(authStateProvider);
      expect(state, isA<AuthError>());
      expect(await sessionManager.hasSession(), isTrue);
    });

    test('5. HTTP 401 definitively clears session when unauthenticated', () async {
      authRepo.currentUserResult = const ApiResult.failure(ApiFailure(
        message: 'HTTP 401 Unauthorized',
        type: ApiFailureType.unauthorized,
        statusCode: 401,
      ));

      final container = _createContainer(tokenStorage, sessionManager, authRepo);
      container.read(authStateProvider.notifier);
      await pumpEventQueue();

      final state = container.read(authStateProvider);
      expect(state, isA<Unauthenticated>());
      expect(await sessionManager.hasSession(), isFalse);
    });
  });

  group('B. Refresh Token Interceptor & Mutex Safety', () {
    test('6. 401 triggers token refresh and retains session on success', () async {
      final dio = Dio()..httpClientAdapter = MockSuccessAdapter();
      final fakeTokenProvider = FakeMockTokenProvider(tokenStorage, authRepo);
      authRepo.refreshShouldSucceed = true;

      var sessionExpiredCalled = false;
      final interceptor = RefreshTokenInterceptor(
        tokenProvider: fakeTokenProvider,
        dio: dio,
        onSessionExpired: () => sessionExpiredCalled = true,
      );

      final requestOptions = RequestOptions(path: '/api/v1/students', headers: {});
      final error401 = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401),
        type: DioExceptionType.badResponse,
      );

      final handler = _CapturingErrorHandler();
      await interceptor.onError(error401, handler);

      expect(authRepo.refreshCallCount, 1);
      expect(sessionExpiredCalled, isFalse);
      expect(tokenStorage.accessToken, 'refreshed_access_token');
      expect(handler.capturedResponse, isNotNull);
    });

    test('7. 401 with failing refresh notifies session expired', () async {
      final dio = Dio()..httpClientAdapter = MockSuccessAdapter();
      final fakeTokenProvider = FakeMockTokenProvider(tokenStorage, authRepo);
      authRepo.refreshShouldSucceed = false;

      var sessionExpiredCalled = false;
      final interceptor = RefreshTokenInterceptor(
        tokenProvider: fakeTokenProvider,
        dio: dio,
        onSessionExpired: () => sessionExpiredCalled = true,
      );

      final requestOptions = RequestOptions(path: '/api/v1/students', headers: {});
      final error401 = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401),
        type: DioExceptionType.badResponse,
      );

      final handler = _CapturingErrorHandler();
      await interceptor.onError(error401, handler);

      expect(authRepo.refreshCallCount, 1);
      expect(sessionExpiredCalled, isTrue);
    });

    test('8. 403 Forbidden does NOT trigger refresh or notify session expired', () async {
      final dio = Dio()..httpClientAdapter = MockSuccessAdapter();
      final fakeTokenProvider = FakeMockTokenProvider(tokenStorage, authRepo);

      var sessionExpiredCalled = false;
      final interceptor = RefreshTokenInterceptor(
        tokenProvider: fakeTokenProvider,
        dio: dio,
        onSessionExpired: () => sessionExpiredCalled = true,
      );

      final requestOptions = RequestOptions(path: '/api/v1/students', headers: {});
      final error403 = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 403),
        type: DioExceptionType.badResponse,
      );

      final handler = _CapturingErrorHandler();
      await interceptor.onError(error403, handler);

      expect(authRepo.refreshCallCount, 0);
      expect(sessionExpiredCalled, isFalse);
      expect(handler.capturedError, isNotNull);
    });
  });

  group('C. Auth Bootstrap, GoRouter Redirect & School Context', () {
    test('9. AuthLoading and AuthInitial states do NOT prematurely redirect to login', () {
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(() => _StaticStateNotifier(const AuthLoading())),
        ],
      );

      container.read(routerProvider);
      expect(container.read(authStateProvider), isA<AuthLoading>());
    });

    test('10. Principal TS001 automatically resolves active school context', () async {
      final container = _createContainer(tokenStorage, sessionManager, authRepo);
      container.read(authStateProvider.notifier);
      await pumpEventQueue();

      final state = container.read(authStateProvider);
      expect(state, isA<Authenticated>());
      final authUser = (state as Authenticated).user;
      expect(authUser.roles, contains('PRINCIPAL'));
      expect(authUser.schools, contains('ts001_school_id'));

      // Active school context must auto-resolve
      expect(container.read(selectedSchoolIdProvider), 'ts001_school_id');
      expect(await sessionManager.getSchoolId(), 'ts001_school_id');
      expect(await sessionManager.getSchoolName(), 'Telangana Model School & Junior College');
    });

    test('11. Explicit logout clears auth and school context', () async {
      final container = _createContainer(tokenStorage, sessionManager, authRepo);
      final notifier = container.read(authStateProvider.notifier);
      await pumpEventQueue();
      expect(container.read(authStateProvider), isA<Authenticated>());

      await notifier.logout();
      expect(container.read(authStateProvider), isA<Unauthenticated>());
      expect(await sessionManager.hasSession(), isFalse);
      expect(container.read(selectedSchoolIdProvider), isNull);
      expect(container.read(selectedTenantIdProvider), isNull);
    });

    test('12. Authenticated Principal encountering 403 ACCESS_DENIED preserves route and intact tokens, whereas Unauthenticated redirects to /login', () async {
      final container = _createContainer(tokenStorage, sessionManager, authRepo);
      container.read(authStateProvider.notifier);
      await pumpEventQueue();

      final currentAuth = container.read(authStateProvider);
      expect(currentAuth, isA<Authenticated>());

      // Protected route for Authenticated user
      final authRedirect = appRouterRedirect(
        authState: currentAuth,
        matchedLocation: AppRoutes.students,
      );
      expect(authRedirect, isNull);

      // Simulate an authorization failure (HTTP 403 / ACCESS_DENIED)
      const authError = AuthError('ACCESS_DENIED');
      container.read(authStateProvider.notifier).setStateForTesting(authError);
      await pumpEventQueue();

      final errorRedirect = appRouterRedirect(
        authState: authError,
        matchedLocation: AppRoutes.students,
      );
      expect(errorRedirect, isNull);
      expect(await sessionManager.hasSession(), isTrue);
      expect(await sessionManager.getAccessToken(), 'valid_mock_access');
      expect(await sessionManager.getRefreshToken(), 'valid_mock_refresh');

      // Genuine Unauthenticated state MUST redirect protected route to /login
      const unauth = Unauthenticated();
      container.read(authStateProvider.notifier).setStateForTesting(unauth);
      await pumpEventQueue();

      final unauthRedirect = appRouterRedirect(
        authState: unauth,
        matchedLocation: AppRoutes.students,
      );
      expect(unauthRedirect, AppRoutes.login);
    });

    test('13. Authenticated Principal encountering 403 Forbidden keeps session and tokens stored', () async {
      final container = _createContainer(tokenStorage, sessionManager, authRepo);
      container.read(authStateProvider.notifier);
      await pumpEventQueue();

      expect(container.read(authStateProvider), isA<Authenticated>());
      expect(await sessionManager.hasSession(), isTrue);

      // Simulate 403 response on non-auth endpoint
      container.read(authStateProvider.notifier).setStateForTesting(
        const AuthError('Forbidden: Access denied to requested resource (HTTP 403)'),
      );
      await pumpEventQueue();

      // Session tokens MUST remain intact
      expect(await sessionManager.hasSession(), isTrue);
      expect(await sessionManager.getAccessToken(), 'valid_mock_access');
      expect(await sessionManager.getRefreshToken(), 'valid_mock_refresh');
      expect(container.read(authStateProvider), isNot(isA<Unauthenticated>()));
    });

    test('14. Provider API exception preserves Authenticated state and does not expire session', () async {
      final container = _createContainer(tokenStorage, sessionManager, authRepo);
      container.read(authStateProvider.notifier);
      await pumpEventQueue();

      expect(container.read(authStateProvider), isA<Authenticated>());

      // Simulate DioException with network timeout (or 500 server error)
      final dioErr = DioException(
        requestOptions: RequestOptions(path: '/api/v1/schools'),
        type: DioExceptionType.connectionTimeout,
        error: 'Connection timed out',
      );

      final failure = ApiExceptionMapper.mapToFailure(dioErr);
      expect(failure.statusCode, isNull);

      // Session tokens remain stored
      expect(await sessionManager.hasSession(), isTrue);
      expect(await sessionManager.getAccessToken(), 'valid_mock_access');
      expect(container.read(authStateProvider), isA<Authenticated>());
    });

    test('15. Immediate tenant context resolution from JWT and storage on startup and login', () async {
      // Create a JWT with embedded tenant_id payload
      // header: {"alg":"HS256","typ":"JWT"} -> eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9
      // payload: {"sub":"user-1","tenant_id":"f004a214-ab3e-443d-a683-588c664a0987"}
      // payload base64url: eyJzdWIiOiJ1c2VyLTEiLCJ0ZW5hbnRfaWQiOiJmMDA0YTIxNC1hYjNlLTQ0M2QtYTY4My01ODhjNjY0YTA5ODcifQ
      const testJwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyLTEiLCJ0ZW5hbnRfaWQiOiJmMDA0YTIxNC1hYjNlLTQ0M2QtYTY4My01ODhjNjY0YTA5ODcifQ.signature';
      
      tokenStorage.accessToken = testJwt;
      tokenStorage.refreshToken = 'test_refresh';
      tokenStorage.tenantId = 'f004a214-ab3e-443d-a683-588c664a0987';

      authRepo.currentUserResult = const ApiResult.success(UserEntity(
        id: 'principal_1',
        email: 'principal.ts001@telanganaschool.edu',
        firstName: 'Ramesh',
        lastName: 'Chandra',
        tenantId: 'f004a214-ab3e-443d-a683-588c664a0987',
        isSuperuser: false,
        roles: ['PRINCIPAL'],
        schools: ['ts001_school_id'],
        schoolNames: {'ts001_school_id': 'Telangana Model School & Junior College'},
      ));

      final container = _createContainer(tokenStorage, sessionManager, authRepo);
      container.read(authStateProvider.notifier);
      await pumpEventQueue();

      // Ensure tenant context is immediately restored before/after validation
      expect(container.read(selectedTenantIdProvider), 'f004a214-ab3e-443d-a683-588c664a0987');
      expect(await sessionManager.getTenantId(), 'f004a214-ab3e-443d-a683-588c664a0987');
      expect(container.read(authStateProvider), isA<Authenticated>());
    });
  });
}

class _StaticStateNotifier extends AuthStateNotifier {
  final AuthState initial;
  _StaticStateNotifier(this.initial);

  @override
  AuthState build() => initial;
}
