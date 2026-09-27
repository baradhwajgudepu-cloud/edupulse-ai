import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_config/edupulse_config.dart';
import 'package:admin_portal/features/auth/presentation/providers/auth_provider.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/core/routing/app_router.dart';
import 'package:admin_portal/core/routing/routes.dart';

class InMemoryTokenStorage implements TokenStorage {
  String? accessToken;
  String? refreshToken;
  String? schoolId;
  String? tenantId;
  String? schoolName;
  String? tenantName;

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<String?> getTenantId() async => tenantId;

  @override
  Future<String?> getSchoolId() async => schoolId;

  @override
  Future<String?> getTenantName() async => tenantName;

  @override
  Future<String?> getSchoolName() async => schoolName;

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
  Future<void> saveTenantId(String tenantId) async => this.tenantId = tenantId;

  @override
  Future<void> saveSchoolId(String schoolId) async => this.schoolId = schoolId;

  @override
  Future<void> saveTenantName(String tenantName) async => this.tenantName = tenantName;

  @override
  Future<void> saveSchoolName(String schoolName) async => this.schoolName = schoolName;

  @override
  Future<void> clearTokens([String source = 'InMemoryTokenStorage.clearTokens']) async {
    accessToken = null;
    refreshToken = null;
    schoolId = null;
    tenantId = null;
    schoolName = null;
    tenantName = null;
  }
}

void main() {
  test('Live runtime reproduction against local backend', () async {
    const liveApiBaseUrl = 'http://127.0.0.1:8000/api/v1/';
    final buildConfig = BuildConfig(
      env: AppEnvironment.dev,
      apiBaseUrl: liveApiBaseUrl,
      tenantId: '09f2d4e7-2877-4e42-9e95-e97d52775687', // Simulate UAT build tenant fallback
    );

    final tokenStorage = InMemoryTokenStorage();
    final sessionManager = SessionManager(tokenStorage: tokenStorage);

    final container = ProviderContainer(
      overrides: [
        buildConfigProvider.overrideWithValue(buildConfig),
        tokenStorageProvider.overrideWithValue(tokenStorage),
        sessionManagerProvider.overrideWithValue(sessionManager),
        authTokenProvider.overrideWith((ref) {
          final sMgr = ref.watch(sessionManagerProvider);
          final refreshDio = ref.watch(refreshDioProvider);
          return TokenProviderImpl(
            sMgr,
            (refreshToken) async {
              final response = await refreshDio.post(
                'auth/refresh',
                data: {'refresh_token': refreshToken},
              );
              final payload = response.data as Map<String, dynamic>;
              final data = payload['data'] as Map<String, dynamic>;
              return SessionToken(
                accessToken: data['access_token'] as String,
                refreshToken: data['refresh_token'] as String,
                tokenType: data['token_type'] as String,
              );
            },
          );
        }),
      ],
    );

    // 1. Initial State Check
    final authNotifier = container.read(authStateProvider.notifier);
    await pumpEventQueue();

    // 2. Perform Live Principal Login
    print('--> Attempting live login...');
    await authNotifier.login('principal.ts001@telanganaschool.edu', 'EduPulse@123');
    await pumpEventQueue();

    final currentAuth = container.read(authStateProvider);
    print('--> Auth state after login: ${currentAuth.runtimeType}');
    expect(currentAuth, isA<Authenticated>());
    final user = (currentAuth as Authenticated).user;
    print('--> User logged in: ${user.email}, tenantId: ${user.tenantId}');

    // 3. Router redirect check on protected routes
    final redirect1 = appRouterRedirect(
      authState: currentAuth,
      matchedLocation: AppRoutes.dashboard,
    );
    print('--> Dashboard redirect: $redirect1');
    expect(redirect1, isNull);

    // 4. Fetch schools with real API client
    print('--> Fetching schools with real BaseApiClient...');
    final schoolsNotifier = container.read(schoolsListProvider.notifier);
    await schoolsNotifier.fetchSchools();
    final schoolsState = container.read(schoolsListProvider);
    print('--> Schools loaded count: ${schoolsState.schools.length}, error: ${schoolsState.error}');
    expect(schoolsState.error, isNull);

    // 5. Navigate to restricted route (e.g. /tenants)
    final redirectTenants = appRouterRedirect(
      authState: currentAuth,
      matchedLocation: AppRoutes.tenants,
    );
    print('--> Tenants route redirect (restricted): $redirectTenants');
    expect(redirectTenants, AppRoutes.dashboard);

    // Verify auth state remains Authenticated after restricted route check!
    expect(container.read(authStateProvider), isA<Authenticated>());
    expect(await sessionManager.hasSession(), isTrue);

    // 6. Idle period simulation
    await Future.delayed(const Duration(seconds: 1));
    await pumpEventQueue();
    expect(container.read(authStateProvider), isA<Authenticated>());
    print('--> All live checks completed successfully without logout!');
  });
}
