import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/core/providers/bootstrap_provider.dart';
import 'package:admin_portal/features/users/presentation/pages/users_screen.dart';

class ResponsiveFakeAuthRepository implements AuthRepository {
  @override
  Future<ApiResult<SessionToken>> login({required String email, required String password}) async {
    return const ApiResult.success(SessionToken(accessToken: 'token', refreshToken: 'refresh', tokenType: 'bearer'));
  }

  @override
  Future<ApiResult<void>> logout({required String refreshToken}) async => const ApiResult.success(null);

  @override
  Future<ApiResult<SessionToken>> refreshToken({required String refreshToken}) async {
    return const ApiResult.success(SessionToken(accessToken: 'token', refreshToken: 'refresh', tokenType: 'bearer'));
  }

  @override
  Future<ApiResult<UserEntity>> getCurrentUser() async {
    return const ApiResult.success(UserEntity(
      id: 'principal_1',
      email: 'principal@school.edu',
      firstName: 'Principal',
      lastName: 'User',
      tenantId: 'tenant_1',
      isSuperuser: false,
      roles: ['PRINCIPAL'],
      schools: ['school_1'],
    ));
  }

  @override
  Future<ApiResult<void>> requestPasswordReset({required String email}) async => const ApiResult.success(null);

  @override
  Future<ApiResult<void>> resetPassword({
    required String token,
    required String newPassword,
    String? confirmPassword,
  }) async => const ApiResult.success(null);

  @override
  Future<ApiResult<void>> changePassword({
    required String currentPassword,
    required String newPassword,
    String? confirmPassword,
  }) async {
    return const ApiResult.success(null);
  }
}

class ResponsiveFakeSessionManager implements SessionManager {
  @override
  Future<String?> getTenantId() async => 'tenant_1';

  @override
  Future<void> saveTenantId(String tenantId) async {}

  @override
  Future<String?> getAccessToken() async => 'mock_token';

  @override
  Future<String?> getRefreshToken() async => 'mock_refresh';

  @override
  Future<void> saveSession(SessionToken token) async {}

  @override
  Future<void> clearSession([String source = 'SessionManager.clearSession']) async {}

  @override
  Future<bool> hasSession() async => true;

  @override
  Future<String?> getSchoolId() async => 'school_1';

  @override
  Future<void> saveSchoolId(String schoolId) async {}

  @override
  Future<String?> getSchoolName() async => 'Telangana Model School';

  @override
  Future<void> saveSchoolName(String schoolName) async {}

  @override
  Future<String?> getTenantName() async => 'Telangana Colleges';

  @override
  Future<void> saveTenantName(String tenantName) async {}
}

class ResponsiveFakeUserApiClient extends BaseApiClient {
  ResponsiveFakeUserApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    return ApiResult.success(mapper({
      'data': [
        {
          'id': 'user_1',
          'email': 'suresh.kumar@telanganaschool.edu',
          'first_name': 'Suresh',
          'last_name': 'Kumar',
          'tenant_id': 'tenant_1',
          'status': 'ACTIVE',
          'is_superuser': false,
          'schools': [
            {'id': 'school_1', 'name': 'Telangana Model School', 'code': 'TS001'}
          ],
          'roles': [
            {'id': 'role_1', 'name': 'Teacher', 'code': 'TEACHER'}
          ],
          'version': 1,
          'created_at': '2026-08-01T10:00:00Z',
          'updated_at': '2026-08-01T10:00:00Z',
        },
        {
          'id': 'user_2',
          'email': 'anita.sharma@telanganaschool.edu',
          'first_name': 'Anita',
          'last_name': 'Sharma',
          'tenant_id': 'tenant_1',
          'status': 'ACTIVE',
          'is_superuser': false,
          'schools': [
            {'id': 'school_1', 'name': 'Telangana Model School', 'code': 'TS001'}
          ],
          'roles': [
            {'id': 'role_2', 'name': 'Principal', 'code': 'PRINCIPAL'}
          ],
          'version': 1,
          'created_at': '2026-08-02T10:00:00Z',
          'updated_at': '2026-08-02T10:00:00Z',
        },
        {
          'id': 'user_3',
          'email': 'ramesh.parent@example.com',
          'first_name': 'Ramesh',
          'last_name': 'Parent',
          'tenant_id': 'tenant_1',
          'status': 'LOCKED',
          'is_superuser': false,
          'schools': [
            {'id': 'school_1', 'name': 'Telangana Model School', 'code': 'TS001'}
          ],
          'roles': [
            {'id': 'role_3', 'name': 'Parent', 'code': 'PARENT'}
          ],
          'version': 1,
          'created_at': '2026-08-03T10:00:00Z',
          'updated_at': '2026-08-03T10:00:00Z',
        }
      ]
    }));
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  const resolutions = [
    Size(1920, 1080), // Full HD Desktop
    Size(1440, 900),  // Standard Desktop
    Size(1366, 768),  // Standard Laptop
    Size(1280, 720),  // HD Laptop (1280x720)
    Size(1280, 800),  // Compact Laptop
    Size(1024, 768),  // Tablet Landscape / Small Desktop
    Size(768, 1024),  // Tablet Portrait (768x1024)
    Size(390, 844),   // Modern Mobile (390x844)
    Size(360, 640),   // Compact Mobile (360x640)
  ];

  for (final size in resolutions) {
    testWidgets('UsersScreen renders without RenderFlex overflow at ${size.width.toInt()}x${size.height.toInt()}',
        (WidgetTester tester) async {
      await binding.setSurfaceSize(size);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bootstrapResultProvider.overrideWithValue(BootstrapResult(success: true)),
            apiClientProvider.overrideWithValue(ResponsiveFakeUserApiClient()),
            authRepositoryProvider.overrideWithValue(ResponsiveFakeAuthRepository()),
            sessionManagerProvider.overrideWithValue(ResponsiveFakeSessionManager()),
          ],
          child: const MaterialApp(
            home: UsersScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure NO exception or overflow was thrown
      expect(tester.takeException(), isNull,
          reason: 'RenderFlex overflow occurred at ${size.width.toInt()}x${size.height.toInt()}');

      // Verify header and primary elements are rendered
      expect(find.text('User Management'), findsOneWidget);
      expect(find.text('Suresh Kumar'), findsOneWidget);
      expect(find.text('Anita Sharma'), findsOneWidget);
    });
  }
}
