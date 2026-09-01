import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:principal_app/app.dart';
import 'package:principal_app/core/providers/bootstrap_provider.dart';

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
        id: 'principal_id_123',
        email: 'principal@school.edu',
        firstName: 'School',
        lastName: 'Principal',
        tenantId: 'd09b9362-3dc8-422d-a441-160735fcea96',
        isSuperuser: false,
        roles: ['PRINCIPAL'],
        schools: ['school_1'],
      ),
    );
  }

  @override
  Future<ApiResult<void>> requestPasswordReset({required String email}) async {
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
    if (path.contains('/fees/reports/dashboard')) {
      return ApiResult.success(mapper({
        'data': {
          'today_collection': 15000.0,
          'month_collection': 450000.0,
          'pending_dues': 800000.0,
        }
      }));
    } else if (path.contains('/notifications/unread-count')) {
      return ApiResult.success(mapper({
        'data': {
          'unread_count': 3,
        }
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

  testWidgets('Principal App without session redirects to Login Page',
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
        child: const EduPulseApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('Principal App with active session routes to Dashboard',
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
        child: const EduPulseApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('School Leadership Dashboard'), findsOneWidget);
    expect(find.text('Today\'s Snapshot'), findsOneWidget);
    expect(find.text('Key Operations'), findsOneWidget);
  });
}
