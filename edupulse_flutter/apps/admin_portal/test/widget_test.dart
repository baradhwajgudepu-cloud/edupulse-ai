import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/app.dart';
import 'package:admin_portal/core/providers/bootstrap_provider.dart';

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

class FakeBaseApiClient extends BaseApiClient {
  FakeBaseApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (path.contains('/system/health')) {
      return ApiResult.success(mapper({
        'status': 'healthy',
        'database': 'healthy',
        'uptime': '12h 4m 5s',
        'timestamp': '2026-08-08T11:20:00+05:30'
      }));
    }
    if (path.contains('/schools')) {
      return ApiResult.success(mapper({
        'success': true,
        'message': 'Schools fetched successfully.',
        'data': [
          {
            'id': 'school_1',
            'name': 'Delhi Public School Hyderabad',
            'code': 'DPS-HYD',
            'board': 'CBSE',
            'school_type': 'HIGH_SCHOOL',
            'email': 'dpshyd@example.com',
            'is_active': true,
            'status': 'ACTIVE'
          }
        ]
      }));
    }
    return ApiResult.failure(const ApiFailure(
      message: 'Not found in mock',
      type: ApiFailureType.unknown,
      statusCode: 404,
    ));
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Admin Portal without session redirects to Login Page',
      (WidgetTester tester) async {
    await binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapResultProvider.overrideWithValue(
            BootstrapResult(success: true),
          ),
          apiClientProvider.overrideWithValue(FakeBaseApiClient()),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          sessionManagerProvider.overrideWithValue(
            FakeSessionManager(hasSession: false),
          ),
        ],
        child: const EduPulseAdminApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Should find login page text components
    expect(find.text('EduPulse Admin'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
  });

  testWidgets('Admin Portal with active session routes to Dashboard',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapResultProvider.overrideWithValue(
            BootstrapResult(success: true),
          ),
          apiClientProvider.overrideWithValue(FakeBaseApiClient()),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          sessionManagerProvider.overrideWithValue(
            FakeSessionManager(hasSession: true),
          ),
        ],
        child: const EduPulseAdminApp(),
      ),
    );

    // Initial checkAuth runs, and the router transitions
    await tester.pumpAndSettle();

    // Check we entered the shell and dashboard
    expect(find.text('EduPulse Admin Portal'), findsOneWidget);
    expect(find.text('System Health & Performance'), findsOneWidget);
    expect(find.text('FastAPI Backend Uptime'), findsOneWidget);
  });

  testWidgets('Dashboard UI renders real health details from mockup API client',
      (WidgetTester tester) async {
    await binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapResultProvider.overrideWithValue(
            BootstrapResult(success: true),
          ),
          apiClientProvider.overrideWithValue(FakeBaseApiClient()),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          sessionManagerProvider.overrideWithValue(
            FakeSessionManager(hasSession: true),
          ),
        ],
        child: const EduPulseAdminApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Confirm backend health data matches our FakeBaseApiClient definition
    expect(find.text('12h 4m 5s'), findsOneWidget);
    expect(find.text('HEALTHY'), findsNWidgets(2));
  });
}
