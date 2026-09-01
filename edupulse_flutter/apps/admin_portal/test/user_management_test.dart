import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/core/providers/bootstrap_provider.dart';
import 'package:admin_portal/features/users/presentation/pages/users_screen.dart';
import 'package:admin_portal/features/users/presentation/pages/user_details_screen.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Future<ApiResult<SessionToken>> login({
    required String email,
    required String password,
  }) async {
    return const ApiResult.success(
      SessionToken(
        accessToken: 'mock_access',
        refreshToken: 'mock_refresh',
        tokenType: 'bearer',
      ),
    );
  }

  @override
  Future<ApiResult<void>> logout({required String refreshToken}) async {
    return const ApiResult.success(null);
  }

  @override
  Future<ApiResult<SessionToken>> refreshToken({
    required String refreshToken,
  }) async {
    return const ApiResult.success(
      SessionToken(
        accessToken: 'mock_access_new',
        refreshToken: 'mock_refresh_new',
        tokenType: 'bearer',
      ),
    );
  }

  @override
  Future<ApiResult<UserEntity>> getCurrentUser() async {
    return const ApiResult.success(
      UserEntity(
        id: 'admin_id_123',
        email: 'superadmin@edupulse.ai',
        firstName: 'System',
        lastName: 'Admin',
        tenantId: 'd09b9362-3dc8-422d-a441-160735fcea96',
        isSuperuser: true,
        roles: ['SUPER_ADMIN'],
        schools: ['school_1'],
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
}

class FakeSessionManager implements SessionManager {
  String? cachedTenantId;

  @override
  Future<String?> getTenantId() async => cachedTenantId;

  @override
  Future<void> saveTenantId(String tenantId) async {
    cachedTenantId = tenantId;
  }

  final bool _shouldHaveSession;

  FakeSessionManager({bool hasSession = true})
      : _shouldHaveSession = hasSession;

  @override
  Future<String?> getAccessToken() async => _shouldHaveSession ? 'mock_access' : null;

  @override
  Future<String?> getRefreshToken() async => _shouldHaveSession ? 'mock_refresh' : null;

  @override
  Future<void> saveSession(SessionToken token) async {}

  @override
  Future<void> clearSession() async {}

  @override
  Future<bool> hasSession() async => _shouldHaveSession;

  @override
  Future<String?> getSchoolId() async => 'school_1';

  @override
  Future<void> saveSchoolId(String schoolId) async {}
}

class FakeUserApiClient extends BaseApiClient {
  FakeUserApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (path.contains('/identity/users/user_1')) {
      return ApiResult.success(mapper({
        'data': {
          'id': 'user_1',
          'email': 'suresh@school.edu',
          'first_name': 'Suresh',
          'last_name': 'Kumar',
          'tenant_id': 'tenant_1',
          'status': 'ACTIVE',
          'is_superuser': false,
          'schools': [
            {'id': 'school_1', 'name': 'DPS Hyderabad', 'code': 'DPS001'}
          ],
          'roles': [
            {
              'id': 'role_1',
              'name': 'Teacher',
              'code': 'TEACHER',
              'description': 'Teacher Role',
              'tenant_id': 'tenant_1',
              'is_system': true,
              'permissions': [
                {'id': 'perm_1', 'name': 'Read Fee', 'code': 'fee.read'}
              ],
              'version': 1
            }
          ],
          'version': 1,
          'created_at': '2026-08-01T10:00:00Z',
          'updated_at': '2026-08-01T10:00:00Z',
        }
      }));
    } else if (path.contains('/identity/users')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'user_1',
            'email': 'suresh@school.edu',
            'first_name': 'Suresh',
            'last_name': 'Kumar',
            'tenant_id': 'tenant_1',
            'status': 'ACTIVE',
            'is_superuser': false,
            'schools': [
              {'id': 'school_1', 'name': 'DPS Hyderabad', 'code': 'DPS001'}
            ],
            'roles': [
              {
                'id': 'role_1',
                'name': 'Teacher',
                'code': 'TEACHER',
                'description': 'Teacher Role',
                'tenant_id': 'tenant_1',
                'is_system': true,
                'permissions': [],
                'version': 1
              }
            ],
            'version': 1,
            'created_at': '2026-08-01T10:00:00Z',
            'updated_at': '2026-08-01T10:00:00Z',
          },
          {
            'id': 'user_2',
            'email': 'ramesh@example.com',
            'first_name': 'Ramesh',
            'last_name': 'Kumar',
            'tenant_id': 'tenant_1',
            'status': 'LOCKED',
            'is_superuser': false,
            'schools': [
              {'id': 'school_1', 'name': 'DPS Hyderabad', 'code': 'DPS001'}
            ],
            'roles': [
              {
                'id': 'role_2',
                'name': 'Parent',
                'code': 'PARENT',
                'description': 'Parent Role',
                'tenant_id': 'tenant_1',
                'is_system': true,
                'permissions': [],
                'version': 1
              }
            ],
            'version': 1,
            'created_at': '2026-08-02T10:00:00Z',
            'updated_at': '2026-08-02T10:00:00Z',
          }
        ]
      }));
    }
    return ApiResult.failure(const ApiFailure(
      message: 'Unknown mock path',
      type: ApiFailureType.unknown,
      statusCode: 404,
    ));
  }

  @override
  Future<ApiResult<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    return ApiResult.success(mapper({}));
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
    if (path.contains('/reset-password')) {
      return ApiResult.success(mapper({
        'data': {
          'email': 'suresh@school.edu',
          'temporary_password': 'EduPulse@123_temp'
        }
      }));
    }
    return ApiResult.success(mapper({}));
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('UsersScreen renders user list and client-side filtering works',
      (WidgetTester tester) async {
    await binding.setSurfaceSize(const Size(1440, 900));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapResultProvider.overrideWithValue(
            BootstrapResult(success: true),
          ),
          apiClientProvider.overrideWithValue(FakeUserApiClient()),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          sessionManagerProvider.overrideWithValue(
            FakeSessionManager(hasSession: true),
          ),
        ],
        child: const MaterialApp(
          home: UsersScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify list renders both users
    expect(find.text('Suresh Kumar'), findsOneWidget);
    expect(find.text('suresh@school.edu'), findsOneWidget);
    expect(find.text('Ramesh Kumar'), findsOneWidget);
    expect(find.text('ramesh@example.com'), findsOneWidget);

    // Verify search matches
    await tester.enterText(find.byType(TextField).first, 'suresh');
    await tester.pumpAndSettle();

    expect(find.text('Suresh Kumar'), findsOneWidget);
    expect(find.text('Ramesh Kumar'), findsNothing);
  });

  testWidgets('UserDetailsScreen displays fields and triggers action confirmation',
      (WidgetTester tester) async {
    await binding.setSurfaceSize(const Size(1440, 900));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapResultProvider.overrideWithValue(
            BootstrapResult(success: true),
          ),
          apiClientProvider.overrideWithValue(FakeUserApiClient()),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          sessionManagerProvider.overrideWithValue(
            FakeSessionManager(hasSession: true),
          ),
        ],
        child: const MaterialApp(
          home: UserDetailsScreen(userId: 'user_1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify name, email, and ID are printed
    expect(find.text('Suresh Kumar'), findsOneWidget);
    expect(find.text('suresh@school.edu'), findsOneWidget);
    expect(find.text('User ID: user_1'), findsOneWidget);

    // Click Reset Password action
    await tester.tap(find.text('Reset Password'));
    await tester.pumpAndSettle();

    // Verify confirmation modal opens
    expect(find.text('Reset Password?'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);

    // Tap Confirm
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
  });
}
