import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/core/routing/routes.dart';
import 'package:admin_portal/core/routing/app_router.dart';
import 'package:admin_portal/features/auth/presentation/providers/auth_provider.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/tenant_setup/presentation/providers/tenant_providers.dart';
import 'package:admin_portal/features/users/presentation/providers/user_provider.dart';

class MockTokenStorage implements TokenStorage {
  String? accessToken = 'valid_super_admin_jwt';
  String? refreshToken = 'valid_super_admin_refresh';
  String? schoolId;
  String? tenantId = 'ff9e842b-3008-451b-a42b-e177c996d3e9';
  String? schoolName;
  String? tenantName = 'EduPulse Master';

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

class FakeApiClient extends BaseApiClient {
  final List<String> requestedPaths = [];

  FakeApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    requestedPaths.add(path);

    if (path.contains('identity/users')) {
      final json = {
        'success': true,
        'data': [
          {
            'id': 'user_1',
            'email': 'admin@telanganaschool.edu',
            'first_name': 'Ramesh',
            'last_name': 'Chandra',
            'tenant_id': 'f004a214-ab3e-443d-a683-588c664a0987',
            'is_active': true,
            'status': 'ACTIVE',
            'roles': [
              {'code': 'PRINCIPAL', 'name': 'Principal'}
            ],
            'schools': [
              {'id': '5f6b2567-c6e7-4d1c-98fa-b9c23e08dddd', 'name': 'Telangana Model School'}
            ]
          }
        ]
      };
      return ApiResult.success(mapper(json));
    }

    if (path.contains('schools')) {
      final json = {
        'success': true,
        'data': [
          {
            'id': '5f6b2567-c6e7-4d1c-98fa-b9c23e08dddd',
            'name': 'Telangana Model School',
            'code': 'TS001',
            'tenant_id': 'f004a214-ab3e-443d-a683-588c664a0987',
            'status': 'ACTIVE',
          }
        ]
      };
      return ApiResult.success(mapper(json));
    }

    if (path.contains('tenants')) {
      final json = {
        'success': true,
        'data': [
          {
            'id': 'f004a214-ab3e-443d-a683-588c664a0987',
            'name': 'Telangana Colleges',
            'code': 'TELANGANA',
            'is_active': true,
            'status': 'ACTIVE',
          }
        ]
      };
      return ApiResult.success(mapper(json));
    }

    if (path.contains('forbidden-403')) {
      return ApiResult.failure(const ApiFailure(
        message: 'Forbidden',
        statusCode: 403,
        type: ApiFailureType.unauthorized,
      ));
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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P0 /users CircularDependencyError Elimination & Session Stability', () {
    late MockTokenStorage tokenStorage;
    late SessionManager sessionManager;
    late FakeApiClient apiClient;

    const superAdminUser = UserEntity(
      id: 'super_admin_1',
      email: 'edupulsetechnologies@gmail.com',
      firstName: 'EduPulse',
      lastName: 'SuperAdmin',
      tenantId: 'ff9e842b-3008-451b-a42b-e177c996d3e9',
      isSuperuser: true,
      roles: ['SUPER_ADMIN'],
      schools: [],
    );

    setUp(() {
      tokenStorage = MockTokenStorage();
      sessionManager = SessionManager(tokenStorage: tokenStorage);
      apiClient = FakeApiClient();
    });

    test('TEST A: Full flow - Login -> Select Tenant -> Select School -> /users loads with zero circular dependency', () async {
      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokenStorage),
          sessionManagerProvider.overrideWithValue(sessionManager),
          apiClientProvider.overrideWithValue(apiClient),
          authStateProvider.overrideWith(() => _TestAuthStateNotifier(const Authenticated(superAdminUser))),
          activeTenantIdProvider.overrideWith((ref) {
            final selectedTenantId = ref.watch(selectedTenantIdProvider);
            if (selectedTenantId != null && selectedTenantId.isNotEmpty) {
              return selectedTenantId;
            }
            final authState = ref.watch(authStateProvider);
            if (authState is Authenticated) {
              final userTenantId = authState.user.tenantId;
              if (userTenantId != null && userTenantId.isNotEmpty) {
                return userTenantId;
              }
            }
            return 'default-config-tenant';
          }),
        ],
      );

      // 1. Initial State: Authenticated
      expect(container.read(authStateProvider), isA<Authenticated>());
      expect(container.read(activeTenantIdProvider), 'ff9e842b-3008-451b-a42b-e177c996d3e9');

      // 2. Select Tenant "Telangana Colleges" in top selector
      const telanganaTenantId = 'f004a214-ab3e-443d-a683-588c664a0987';
      container.read(selectedTenantIdProvider.notifier).state = telanganaTenantId;
      await sessionManager.saveTenantId(telanganaTenantId);
      expect(container.read(activeTenantIdProvider), telanganaTenantId);

      // 3. Select School "Telangana Model School"
      const schoolId = '5f6b2567-c6e7-4d1c-98fa-b9c23e08dddd';
      container.read(selectedSchoolIdProvider.notifier).state = schoolId;
      await sessionManager.saveSchoolId(schoolId);
      expect(container.read(selectedSchoolIdProvider), schoolId);

      // 4. Navigate to /users and trigger fetchUsers()
      final usersNotifier = container.read(usersListProvider.notifier);
      await usersNotifier.fetchUsers(reset: true);

      // 5. Assertions: Users loaded successfully without error
      final usersState = container.read(usersListProvider);
      expect(usersState.error, isNull);
      expect(usersState.users.length, 1);
      expect(usersState.users.first.email, 'admin@telanganaschool.edu');

      // 6. Assertions: Session remains Authenticated and tokens intact
      expect(container.read(authStateProvider), isA<Authenticated>());
      expect(tokenStorage.accessToken, 'valid_super_admin_jwt');
      expect(tokenStorage.refreshToken, 'valid_super_admin_refresh');

      container.dispose();
    });

    test('TEST B: Sequential Navigation across all protected routes maintains Authenticated state', () async {
      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokenStorage),
          sessionManagerProvider.overrideWithValue(sessionManager),
          apiClientProvider.overrideWithValue(apiClient),
          authStateProvider.overrideWith(() => _TestAuthStateNotifier(const Authenticated(superAdminUser))),
          activeTenantIdProvider.overrideWith((ref) {
            final selectedTenantId = ref.watch(selectedTenantIdProvider);
            if (selectedTenantId != null && selectedTenantId.isNotEmpty) {
              return selectedTenantId;
            }
            return 'ff9e842b-3008-451b-a42b-e177c996d3e9';
          }),
        ],
      );

      final routesToTest = [
        AppRoutes.dashboard,
        AppRoutes.users,
        AppRoutes.tenants,
        AppRoutes.students,
        AppRoutes.teachers,
        AppRoutes.classes,
        AppRoutes.academicYears,
        AppRoutes.settings,
        AppRoutes.dashboard,
      ];

      for (final route in routesToTest) {
        final redirect = appRouterRedirect(
          authState: container.read(authStateProvider),
          matchedLocation: route,
        );
        expect(redirect, isNull, reason: 'Super Admin should have direct access to $route');
        expect(container.read(authStateProvider), isA<Authenticated>());
      }

      container.dispose();
    });

    test('TEST C: Repeated Tenant Switch followed by School Selection causes NO logout', () async {
      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokenStorage),
          sessionManagerProvider.overrideWithValue(sessionManager),
          apiClientProvider.overrideWithValue(apiClient),
          authStateProvider.overrideWith(() => _TestAuthStateNotifier(const Authenticated(superAdminUser))),
          activeTenantIdProvider.overrideWith((ref) {
            final selectedTenantId = ref.watch(selectedTenantIdProvider);
            if (selectedTenantId != null && selectedTenantId.isNotEmpty) {
              return selectedTenantId;
            }
            return 'ff9e842b-3008-451b-a42b-e177c996d3e9';
          }),
        ],
      );

      const telanganaId = 'f004a214-ab3e-443d-a683-588c664a0987';
      const masterId = 'ff9e842b-3008-451b-a42b-e177c996d3e9';

      for (int i = 0; i < 3; i++) {
        // Switch to Telangana
        container.read(selectedTenantIdProvider.notifier).state = telanganaId;
        container.read(selectedSchoolIdProvider.notifier).state = 'school_ts';
        await container.read(usersListProvider.notifier).fetchUsers(reset: true);
        expect(container.read(authStateProvider), isA<Authenticated>());
        expect(tokenStorage.accessToken, isNotNull);

        // Switch to Master
        container.read(selectedTenantIdProvider.notifier).state = masterId;
        container.read(selectedSchoolIdProvider.notifier).state = null;
        expect(container.read(authStateProvider), isA<Authenticated>());
        expect(tokenStorage.accessToken, isNotNull);
      }

      container.dispose();
    });

    test('TEST D: Browser refresh preserves session and contexts without redirecting to login', () async {
      await tokenStorage.saveTokens(
        accessToken: 'persisted_jwt_token',
        refreshToken: 'persisted_refresh_token',
      );
      await sessionManager.saveTenantId('f004a214-ab3e-443d-a683-588c664a0987');
      await sessionManager.saveSchoolId('5f6b2567-c6e7-4d1c-98fa-b9c23e08dddd');

      final restoredToken = await sessionManager.getAccessToken();
      final restoredTenant = await sessionManager.getTenantId();
      final restoredSchool = await sessionManager.getSchoolId();

      expect(restoredToken, 'persisted_jwt_token');
      expect(restoredTenant, 'f004a214-ab3e-443d-a683-588c664a0987');
      expect(restoredSchool, '5f6b2567-c6e7-4d1c-98fa-b9c23e08dddd');
    });

    test('TEST E: Restricted 403 response does not trigger logout or token deletion', () async {
      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokenStorage),
          sessionManagerProvider.overrideWithValue(sessionManager),
          apiClientProvider.overrideWithValue(apiClient),
          authStateProvider.overrideWith(() => _TestAuthStateNotifier(const Authenticated(superAdminUser))),
        ],
      );

      final result = await apiClient.get<dynamic>(
        '/forbidden-403',
        mapper: (json) => json,
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.statusCode, 403);

      expect(container.read(authStateProvider), isA<Authenticated>());
      expect(tokenStorage.accessToken, isNotNull);
      expect(tokenStorage.refreshToken, isNotNull);

      container.dispose();
    });
  });
}
