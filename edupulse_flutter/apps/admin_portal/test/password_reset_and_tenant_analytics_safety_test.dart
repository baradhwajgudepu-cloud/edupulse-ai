import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:admin_portal/core/routing/app_router.dart';
import 'package:admin_portal/core/routing/routes.dart';
import 'package:admin_portal/features/auth/presentation/pages/reset_password_screen.dart';
import 'package:admin_portal/features/auth/presentation/pages/forgot_password_screen.dart';

class FakeTokenProvider implements AuthTokenProvider {
  String? currentSchoolId;
  FakeTokenProvider([this.currentSchoolId]);

  @override
  Future<String?> getAccessToken() async => 'fake_access_token';

  @override
  Future<String?> getRefreshToken() async => 'fake_refresh_token';

  @override
  Future<String?> getSchoolId() async => currentSchoolId;

  @override
  Future<void> refreshSession() async {}
}

class FakeSessionManager implements SessionManager {
  String? _schoolId;
  String? _schoolName;
  String? _tenantId;
  String? _tenantName;

  @override
  Future<String?> getAccessToken() async => 'mock_token';
  @override
  Future<String?> getRefreshToken() async => 'mock_refresh';
  @override
  Future<bool> hasSession() async => false;
  @override
  Future<void> saveSession(SessionToken token) async {}
  @override
  Future<void> clearSession([String source = 'SessionManager.clearSession']) async {
    _schoolId = null;
    _schoolName = null;
    _tenantId = null;
    _tenantName = null;
  }
  @override
  Future<String?> getSchoolId() async => _schoolId;
  @override
  Future<void> saveSchoolId(String schoolId) async { _schoolId = schoolId; }
  @override
  Future<String?> getSchoolName() async => _schoolName;
  @override
  Future<void> saveSchoolName(String schoolName) async { _schoolName = schoolName; }
  @override
  Future<String?> getTenantId() async => _tenantId;
  @override
  Future<void> saveTenantId(String tenantId) async { _tenantId = tenantId; }
  @override
  Future<String?> getTenantName() async => _tenantName;
  @override
  Future<void> saveTenantName(String tenantName) async { _tenantName = tenantName; }
}

void main() {
  group('Password Reset & Tenant Analytics Production Safety Tests', () {
    testWidgets('TEST A: /reset-password?token=test-token-12345 loads ResetPasswordScreen without redirecting to login', (tester) async {
      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(FakeSessionManager()),
        ],
      );

      final router = container.read(routerProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      // Navigate to deep link
      router.go('${AppRoutes.resetPassword}?token=test-token-12345');
      await tester.pumpAndSettle();

      // Route remains resetPassword and does not redirect to login
      expect(router.state.uri.path, AppRoutes.resetPassword);
      expect(router.state.uri.queryParameters['token'], 'test-token-12345');
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(find.text('Reset Password'), findsWidgets);
      expect(find.text('Reset token automatically loaded from link'), findsOneWidget);
    });

    testWidgets('TEST B: /reset-password without query param shows manual token input rather than permanent lockout', (tester) async {
      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(FakeSessionManager()),
        ],
      );

      final router = container.read(routerProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      router.go(AppRoutes.resetPassword);
      await tester.pumpAndSettle();

      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(find.text('Invalid Reset Link'), findsOneWidget);
      expect(find.text('Enter Token Manually'), findsOneWidget);

      await tester.tap(find.text('Enter Token Manually'));
      await tester.pumpAndSettle();

      expect(find.text('Reset Token'), findsOneWidget);
      expect(find.text('Enter or paste the token received in your password reset email'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
    });

    testWidgets('TEST C: ForgotPasswordScreen has explicit Enter Token navigation action', (tester) async {
      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(FakeSessionManager()),
        ],
      );

      final router = container.read(routerProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      router.go(AppRoutes.forgotPassword);
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
      expect(find.text('Already have a reset token? Enter Token'), findsOneWidget);

      await tester.tap(find.text('Already have a reset token? Enter Token'));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.resetPassword);
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
    });

    test('TEST D: JWT Interceptor allows tenant-level analytics when schoolId is null', () async {
      final tokenProvider = FakeTokenProvider(null); // No school selected
      final interceptor = JwtInterceptor(
        tokenProvider: tokenProvider,
        tenantIdGetter: () => 'tenant-uuid-123',
      );

      // 1. /ai-intelligence/summary should be permitted without throwing cancellation
      final aiReq = RequestOptions(path: '/ai-intelligence/summary');
      bool aiRejected = false;
      final aiHandler = RequestInterceptorHandler();
      
      try {
        await interceptor.onRequest(aiReq, aiHandler);
      } on DioException {
        aiRejected = true;
      }
      expect(aiRejected, isFalse, reason: '/ai-intelligence/summary must be allowed with null schoolId');

      // 2. /reports/tenant/overview should be permitted without throwing cancellation
      final tenantReq = RequestOptions(path: '/reports/tenant/overview');
      bool tenantRejected = false;
      try {
        await interceptor.onRequest(tenantReq, RequestInterceptorHandler());
      } on DioException {
        tenantRejected = true;
      }
      expect(tenantRejected, isFalse, reason: '/reports/tenant/overview must be allowed with null schoolId');
    });

    test('TEST E: JWT Interceptor strictly protects school-scoped endpoints when schoolId is null', () async {
      final tokenProvider = FakeTokenProvider(null); // No school selected
      final interceptor = JwtInterceptor(
        tokenProvider: tokenProvider,
        tenantIdGetter: () => 'tenant-uuid-123',
      );

      // School-specific route must throw DioException: Active school context required.
      final studentReq = RequestOptions(path: '/students');
      
      expect(
        () async {
          final handler = _CapturingHandler();
          await interceptor.onRequest(studentReq, handler);
          if (handler.rejectedException != null) {
            throw handler.rejectedException!;
          }
        },
        throwsA(isA<DioException>().having((e) => e.error, 'error', 'Active school context required.')),
      );
    });

    test('TEST F: JWT Interceptor attaches X-School-ID when schoolId is present', () async {
      final tokenProvider = FakeTokenProvider('school-uuid-abc');
      final interceptor = JwtInterceptor(
        tokenProvider: tokenProvider,
        tenantIdGetter: () => 'tenant-uuid-123',
      );

      final aiReq = RequestOptions(path: '/ai-intelligence/summary');
      final handler = RequestInterceptorHandler();
      await interceptor.onRequest(aiReq, handler);

      expect(aiReq.headers['X-School-ID'], 'school-uuid-abc');
      expect(aiReq.headers['X-Tenant-ID'], 'tenant-uuid-123');
    });
  });
}

class _CapturingHandler extends RequestInterceptorHandler {
  DioException? rejectedException;

  @override
  void reject(DioException error, [bool callFollowingErrorInterceptor = false]) {
    rejectedException = error;
  }
}
