import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:admin_portal/core/routing/routes.dart';
import 'package:admin_portal/core/routing/app_router.dart';
import 'package:admin_portal/features/auth/presentation/providers/auth_provider.dart';
import 'package:admin_portal/features/auth/presentation/pages/login_screen.dart';
import 'package:admin_portal/features/shell/presentation/admin_shell.dart';

class _FakeApiClient extends BaseApiClient {
  _FakeApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    return ApiResult.success(mapper({'data': []}));
  }
}

class _MockAuthStateNotifier extends AuthStateNotifier {
  final AuthState _initialState;
  int checkAuthCallCount = 0;
  int logoutCallCount = 0;

  _MockAuthStateNotifier(this._initialState);

  @override
  AuthState build() => _initialState;

  @override
  Future<void> checkAuth() async {
    checkAuthCallCount++;
  }

  @override
  Future<void> logout() async {
    logoutCallCount++;
    state = const Unauthenticated();
  }
}

void main() {
  const testUser = UserEntity(
    id: 'admin-1',
    email: 'admin@telanganaschool.edu',
    firstName: 'Admin',
    lastName: 'User',
    tenantId: 'tenant-1',
    isSuperuser: true,
    roles: ['SUPER_ADMIN'],
    schools: ['school-1'],
    schoolNames: {'school-1': 'Telangana Model School'},
  );

  Widget buildTestShellWithRouter({
    required _MockAuthStateNotifier authNotifier,
  }) {
    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AdminShell(child: child),
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const Scaffold(body: Text('Dashboard Child Content')),
            ),
          ],
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(_FakeApiClient()),
        authStateProvider.overrideWith(() => authNotifier),
      ],
      child: MaterialApp.router(
        theme: EduPulseTheme.lightTheme,
        routerConfig: router,
      ),
    );
  }

  group('AdminShell Auth State Presentation & Recovery Tests', () {
    testWidgets('1. AuthInitial / AuthLoading displays loading indicator with Loading EduPulse text', (tester) async {
      final notifier = _MockAuthStateNotifier(const AuthLoading());

      await tester.pumpWidget(buildTestShellWithRouter(authNotifier: notifier));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading EduPulse...'), findsOneWidget);
      expect(find.text('Unable to restore your session'), findsNothing);
      expect(find.text('Dashboard Child Content'), findsNothing);
    });

    testWidgets('2. Authenticated displays normal AdminShell with child content and app bar', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final notifier = _MockAuthStateNotifier(const Authenticated(testUser));

      await tester.pumpWidget(buildTestShellWithRouter(authNotifier: notifier));
      await tester.pumpAndSettle();

      expect(find.text('Dashboard Child Content'), findsOneWidget);
      expect(find.text('Loading EduPulse...'), findsNothing);
      expect(find.text('Unable to restore your session'), findsNothing);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('3. AuthError displays recovery UI with safe message and action buttons', (tester) async {
      final notifier = _MockAuthStateNotifier(
        const AuthError('DioExceptionType.connectionTimeout: Failed to connect to server'),
      );

      await tester.pumpWidget(buildTestShellWithRouter(authNotifier: notifier));
      await tester.pump();

      expect(find.text('Unable to restore your session'), findsOneWidget);
      expect(
        find.text('Unable to reach the EduPulse backend server. Please check your internet connection and try again.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('auth_recovery_retry_button')), findsOneWidget);
      expect(find.byKey(const Key('auth_recovery_login_button')), findsOneWidget);
      expect(find.text('Dashboard Child Content'), findsNothing);
    });

    testWidgets('4. Retry button on recovery screen invokes checkAuth()', (tester) async {
      final notifier = _MockAuthStateNotifier(
        const AuthError('Connection timed out'),
      );

      await tester.pumpWidget(buildTestShellWithRouter(authNotifier: notifier));
      await tester.pump();

      final retryBtn = find.byKey(const Key('auth_recovery_retry_button'));
      expect(retryBtn, findsOneWidget);

      await tester.tap(retryBtn);
      await tester.pump();

      expect(notifier.checkAuthCallCount, 1);
    });

    testWidgets('5. Return to Login button on recovery screen invokes logout()', (tester) async {
      final notifier = _MockAuthStateNotifier(
        const AuthError('Session invalid'),
      );

      await tester.pumpWidget(buildTestShellWithRouter(authNotifier: notifier));
      await tester.pump();

      final loginBtn = find.byKey(const Key('auth_recovery_login_button'));
      expect(loginBtn, findsOneWidget);

      await tester.tap(loginBtn);
      await tester.pump();

      expect(notifier.logoutCallCount, 1);
    });

    testWidgets('6. Unauthenticated displays empty scaffold allowing router to transition', (tester) async {
      final notifier = _MockAuthStateNotifier(const Unauthenticated());

      await tester.pumpWidget(buildTestShellWithRouter(authNotifier: notifier));
      await tester.pump();

      expect(find.text('Unable to restore your session'), findsNothing);
      expect(find.text('Loading EduPulse...'), findsNothing);
      expect(find.text('Dashboard Child Content'), findsNothing);
      expect(find.byType(AppBar), findsNothing);
    });
  });

  group('appRouterRedirect Safety & Recovery Routing Tests', () {
    test('7. AuthError keeps user on protected route so AdminShell recovery screen can display', () {
      const authError = AuthError('Transient connection error');

      final redirect = appRouterRedirect(
        authState: authError,
        matchedLocation: AppRoutes.dashboard,
      );

      expect(redirect, isNull);
    });

    test('8. Unauthenticated redirects protected routes to /login', () {
      const unauth = Unauthenticated();

      final redirectDashboard = appRouterRedirect(
        authState: unauth,
        matchedLocation: AppRoutes.dashboard,
      );
      expect(redirectDashboard, AppRoutes.login);

      final redirectStudents = appRouterRedirect(
        authState: unauth,
        matchedLocation: AppRoutes.students,
      );
      expect(redirectStudents, AppRoutes.login);
    });

    test('9. Unauthenticated on public auth routes does not cause redirect loops', () {
      const unauth = Unauthenticated();

      final redirectLogin = appRouterRedirect(
        authState: unauth,
        matchedLocation: AppRoutes.login,
      );
      expect(redirectLogin, isNull);

      final redirectForgot = appRouterRedirect(
        authState: unauth,
        matchedLocation: AppRoutes.forgotPassword,
      );
      expect(redirectForgot, isNull);
    });

    test('10. Authenticated on login page redirects to /dashboard', () {
      const auth = Authenticated(testUser);

      final redirect = appRouterRedirect(
        authState: auth,
        matchedLocation: AppRoutes.login,
      );
      expect(redirect, AppRoutes.dashboard);
    });

    testWidgets('11. AuthError with UserStatus.LOCKED displays Account Locked UI without Retry button', (tester) async {
      final notifier = _MockAuthStateNotifier(
        const AuthError("Access denied. Account status is currently 'UserStatus.LOCKED.'"),
      );

      await tester.pumpWidget(buildTestShellWithRouter(authNotifier: notifier));
      await tester.pump();

      expect(find.text('Account Locked'), findsOneWidget);
      expect(find.text('Unable to restore your session'), findsNothing);
      expect(
        find.text('Your account is locked. Please contact your school administrator to unlock your account.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('auth_recovery_login_button')), findsOneWidget);
      // Retry button MUST NOT be present to prevent retry loops
      expect(find.byKey(const Key('auth_recovery_retry_button')), findsNothing);
    });

    test('12. AccountLocked redirects protected routes to /login and permits /login', () {
      const locked = AccountLocked();

      final redirectDashboard = appRouterRedirect(
        authState: locked,
        matchedLocation: AppRoutes.dashboard,
      );
      expect(redirectDashboard, AppRoutes.login);

      final redirectLogin = appRouterRedirect(
        authState: locked,
        matchedLocation: AppRoutes.login,
      );
      expect(redirectLogin, isNull);
    });

    testWidgets('13. LoginScreen displays locked account banner when AccountLocked or authLockMessageProvider is set', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(() => _MockAuthStateNotifier(const AccountLocked())),
            authLockMessageProvider.overrideWith((ref) => 'Your account is locked. Please contact your school administrator to unlock your account.'),
          ],
          child: MaterialApp(
            theme: EduPulseTheme.lightTheme,
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('account_locked_banner')), findsOneWidget);
      expect(find.text('Account Locked'), findsOneWidget);
      expect(
        find.text('Your account is locked. Please contact your school administrator to unlock your account.'),
        findsOneWidget,
      );
    });
  });
}
