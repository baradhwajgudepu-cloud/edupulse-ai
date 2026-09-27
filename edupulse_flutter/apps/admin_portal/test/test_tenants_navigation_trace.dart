import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/core/routing/routes.dart';
import 'package:admin_portal/core/routing/app_router.dart';
import 'package:admin_portal/features/auth/presentation/providers/auth_provider.dart';
import 'package:admin_portal/features/tenant_setup/presentation/providers/tenant_providers.dart';

class MockTokenStorage implements TokenStorage {
  String? accessToken = 'mock_jwt_access';
  String? refreshToken = 'mock_jwt_refresh';
  String? schoolId = 'ts001_school_id';
  String? tenantId = 'f004a214-ab3e-443d-a683-588c664a0987';
  String? schoolName = 'Telangana School';
  String? tenantName = 'Telangana Colleges';

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
}

class FakeBaseApiClient extends BaseApiClient {
  final List<String> requestedPaths = [];

  FakeBaseApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    requestedPaths.add(path);
    if (path.contains('tenants')) {
      final json = {
        'data': [
          {
            'id': 'f004a214-ab3e-443d-a683-588c664a0987',
            'name': 'Telangana Colleges',
            'code': 'telangana-edu',
            'subdomain': 'telangana-edu',
            'email': 'principal.ts001@telanganaschool.edu',
            'is_active': true,
            'status': 'ACTIVE',
            'timezone': 'Asia/Kolkata',
            'currency': 'INR',
          },
          {
            'id': 'ff9e842b-3008-451b-a42b-e177c996d3e9',
            'name': 'EduPulse Master',
            'code': 'EDUPULSE_SYSTEM',
            'subdomain': 'system',
            'email': 'edupulsetechnolgies@gmail.com',
            'is_active': true,
            'status': 'ACTIVE',
            'timezone': 'Asia/Kolkata',
            'currency': 'INR',
          }
        ]
      };
      return ApiResult.success(mapper(json));
    }
    if (path.contains('schools')) {
      final json = {'data': []};
      return ApiResult.success(mapper(json));
    }
    return ApiResult.failure(const ApiFailure(message: 'Not found', statusCode: 404, type: ApiFailureType.unknown));
  }
}

class _TestAuthStateNotifier extends AuthStateNotifier {
  final AuthState initial;
  _TestAuthStateNotifier(this.initial);

  @override
  AuthState build() => initial;
}

void main() {
  late MockTokenStorage tokenStorage;
  late SessionManager sessionManager;
  late FakeBaseApiClient apiClient;

  setUp(() {
    tokenStorage = MockTokenStorage();
    sessionManager = SessionManager(tokenStorage: tokenStorage);
    apiClient = FakeBaseApiClient();
  });

  testWidgets('Principal navigation to /tenants redirects to /unauthorized (403) and NEVER logs out', (tester) async {
    const principalUser = UserEntity(
      id: 'principal_1',
      email: 'principal.ts001@telanganaschool.edu',
      firstName: 'Ramesh',
      lastName: 'Chandra',
      tenantId: 'f004a214-ab3e-443d-a683-588c664a0987',
      isSuperuser: false,
      roles: ['PRINCIPAL'],
      schools: ['ts001_school_id'],
      schoolNames: {'ts001_school_id': 'Telangana School'},
    );

    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokenStorage),
        sessionManagerProvider.overrideWithValue(sessionManager),
        apiClientProvider.overrideWithValue(apiClient),
        authStateProvider.overrideWith(() => _TestAuthStateNotifier(const Authenticated(principalUser))),
      ],
    );

    // Verify initial state
    expect(container.read(authStateProvider), isA<Authenticated>());
    expect(tokenStorage.accessToken, isNotNull);

    // 1. Check router redirect
    final redirectResult = appRouterRedirect(
      authState: container.read(authStateProvider),
      matchedLocation: AppRoutes.tenants,
    );

    // MUST redirect to unauthorized (HTTP 403 Access Denied page)
    expect(redirectResult, AppRoutes.unauthorized);

    // MUST remain Authenticated
    expect(container.read(authStateProvider), isA<Authenticated>());
    expect(tokenStorage.accessToken, isNotNull);
    expect(tokenStorage.refreshToken, isNotNull);
    expect(tokenStorage.tenantId, 'f004a214-ab3e-443d-a683-588c664a0987');
  });

  testWidgets('Super Admin navigation to /tenants loads successfully and NEVER logs out', (tester) async {
    const superAdminUser = UserEntity(
      id: 'super_admin_1',
      email: 'edupulsetechnolgies@gmail.com',
      firstName: 'EduPulse',
      lastName: 'SuperAdmin',
      tenantId: 'ff9e842b-3008-451b-a42b-e177c996d3e9',
      isSuperuser: true,
      roles: ['SUPER_ADMIN'],
      schools: [],
    );

    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokenStorage),
        sessionManagerProvider.overrideWithValue(sessionManager),
        apiClientProvider.overrideWithValue(apiClient),
        authStateProvider.overrideWith(() => _TestAuthStateNotifier(const Authenticated(superAdminUser))),
      ],
    );

    // 1. Check router redirect: Super Admin should NOT be redirected
    final redirectResult = appRouterRedirect(
      authState: container.read(authStateProvider),
      matchedLocation: AppRoutes.tenants,
    );
    expect(redirectResult, isNull);

    // 2. Call fetchTenants
    await container.read(tenantsListProvider.notifier).fetchTenants();
    expect(apiClient.requestedPaths, contains('/tenants'));
    expect(container.read(tenantsListProvider).tenants.length, 2);

    // 3. Ensure Super Admin remains Authenticated and tokens intact
    expect(container.read(authStateProvider), isA<Authenticated>());
    expect(tokenStorage.accessToken, isNotNull);
    expect(tokenStorage.refreshToken, isNotNull);
  });
}
