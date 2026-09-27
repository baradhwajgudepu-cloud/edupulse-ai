import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:admin_portal/core/routing/app_router.dart';
import 'package:admin_portal/core/routing/routes.dart';
import 'package:admin_portal/features/auth/presentation/pages/forgot_password_screen.dart';
import 'package:admin_portal/features/auth/presentation/pages/reset_password_screen.dart';

class MockAuthRepository implements AuthRepository {
  String? lastRequestedEmail;
  String? lastResetToken;
  String? lastResetNewPassword;
  String? lastResetConfirmPassword;

  ApiResult<void> forgotPasswordResult = const ApiResult.success(null);
  ApiResult<void> resetPasswordResult = const ApiResult.success(null);

  @override
  Future<ApiResult<void>> requestPasswordReset({required String email}) async {
    lastRequestedEmail = email;
    return forgotPasswordResult;
  }

  @override
  Future<ApiResult<void>> resetPassword({
    required String token,
    required String newPassword,
    String? confirmPassword,
  }) async {
    lastResetToken = token;
    lastResetNewPassword = newPassword;
    lastResetConfirmPassword = confirmPassword;
    return resetPasswordResult;
  }

  @override
  Future<ApiResult<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return const ApiResult.success(null);
  }

  @override
  Future<ApiResult<SessionToken>> login({required String email, required String password}) async =>
      throw UnimplementedError();

  @override
  Future<ApiResult<void>> logout({required String refreshToken}) async =>
      throw UnimplementedError();

  @override
  Future<ApiResult<SessionToken>> refreshToken({required String refreshToken}) async =>
      throw UnimplementedError();

  @override
  Future<ApiResult<UserEntity>> getCurrentUser() async =>
      throw UnimplementedError();
}

class FakeSessionManager implements SessionManager {
  @override
  Future<String?> getAccessToken() async => null;
  @override
  Future<String?> getRefreshToken() async => null;
  @override
  Future<bool> hasSession() async => false;
  @override
  Future<void> saveSession(SessionToken token) async {}
  @override
  Future<void> clearSession([String source = '']) async {}
  @override
  Future<String?> getSchoolId() async => null;
  @override
  Future<void> saveSchoolId(String schoolId) async {}
  @override
  Future<String?> getSchoolName() async => null;
  @override
  Future<void> saveSchoolName(String schoolName) async {}
  @override
  Future<String?> getTenantId() async => null;
  @override
  Future<void> saveTenantId(String tenantId) async {}
  @override
  Future<String?> getTenantName() async => null;
  @override
  Future<void> saveTenantName(String tenantName) async {}
}

void main() {
  group('Comprehensive Forgot-Password & Password-Reset Verification Tests', () {
    late MockAuthRepository mockAuthRepo;

    setUp(() {
      mockAuthRepo = MockAuthRepository();
    });

    testWidgets('1. ForgotPasswordScreen renders inputs, actions and returns to sign in', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
          ],
          child: const MaterialApp(
            home: ForgotPasswordScreen(),
          ),
        ),
      );

      expect(find.text('Forgot Password'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
      expect(find.text('Return to Sign In'), findsOneWidget);
      expect(find.text('Already have a reset token? Enter Token'), findsOneWidget);
    });

    testWidgets('2. Valid email submission invokes requestPasswordReset and displays generic success view', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
          ],
          child: const MaterialApp(
            home: ForgotPasswordScreen(),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'admin@school.com');
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(mockAuthRepo.lastRequestedEmail, 'admin@school.com');
      expect(find.text('Instructions Sent'), findsOneWidget);
      expect(find.textContaining('If an account exists with admin@school.com'), findsOneWidget);
      expect(find.text('Back to Sign In'), findsOneWidget);
      expect(find.text('Already have a reset token? Enter Token'), findsOneWidget);
    });

    testWidgets('3. Rate limit error (429) displays warning safely without crashing', (tester) async {
      mockAuthRepo.forgotPasswordResult = const ApiResult.failure(
        ApiFailure(
          message: 'Too many password reset requests for this email address. Please wait before trying again.',
          statusCode: 429,
          type: ApiFailureType.network,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
          ],
          child: const MaterialApp(
            home: ForgotPasswordScreen(),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'throttled@school.com');
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Too many password reset requests'), findsOneWidget);
      expect(find.text('Instructions Sent'), findsNothing);
    });

    testWidgets('3b. Service unavailable error (503) displays error message and does not show false success', (tester) async {
      mockAuthRepo.forgotPasswordResult = const ApiResult.failure(
        ApiFailure(
          message: 'Password reset service is temporarily unavailable. Please try again later or contact support.',
          statusCode: 503,
          type: ApiFailureType.server,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
          ],
          child: const MaterialApp(
            home: ForgotPasswordScreen(),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'admin@school.com');
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Password reset service is temporarily unavailable'), findsOneWidget);
      expect(find.text('Instructions Sent'), findsNothing);
      expect(find.text('Send Reset Link'), findsOneWidget);
    });

    testWidgets('3c. Internal server error (500) displays error message and does not show false success', (tester) async {
      mockAuthRepo.forgotPasswordResult = const ApiResult.failure(
        ApiFailure(
          message: 'Internal server error occurred.',
          statusCode: 500,
          type: ApiFailureType.server,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
          ],
          child: const MaterialApp(
            home: ForgotPasswordScreen(),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'admin@school.com');
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Internal server error occurred'), findsOneWidget);
      expect(find.text('Instructions Sent'), findsNothing);
      expect(find.text('Send Reset Link'), findsOneWidget);
    });

    testWidgets('4. /reset-password is a public auth route and does not redirect to /login without session', (tester) async {
      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(FakeSessionManager()),
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
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

      expect(router.state.uri.path, AppRoutes.resetPassword);
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
    });

    testWidgets('5. Link-provided token automatically loads into state without showing raw token input', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
          ],
          child: const MaterialApp(
            home: ResetPasswordScreen(initialToken: 'SECURE_TEST_TOKEN_XYZ'),
          ),
        ),
      );

      expect(find.text('Reset Password'), findsNWidgets(2));
      expect(find.text('Reset token automatically loaded from link'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('Reset Token'), findsNothing);
    });

    testWidgets('6. Missing token displays Invalid Reset Link view with manual entry and request new link options', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
          ],
          child: const MaterialApp(
            home: ResetPasswordScreen(initialToken: null),
          ),
        ),
      );

      expect(find.text('Invalid Reset Link'), findsOneWidget);
      expect(find.text('Request New Reset Link'), findsOneWidget);
      expect(find.text('Enter Token Manually'), findsOneWidget);

      await tester.tap(find.text('Enter Token Manually'));
      await tester.pumpAndSettle();

      expect(find.text('Reset Token'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
    });

    testWidgets('7. ResetPasswordScreen validates password complexity requirements', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
          ],
          child: const MaterialApp(
            home: ResetPasswordScreen(initialToken: 'VALID_TOKEN_123'),
          ),
        ),
      );

      final textFields = find.byType(TextFormField);

      // Short password (<8 chars)
      await tester.enterText(textFields.at(0), 'Short1!');
      await tester.enterText(textFields.at(1), 'Short1!');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reset Password'));
      await tester.pumpAndSettle();
      expect(find.text('Password must be at least 8 characters long'), findsOneWidget);

      // Missing uppercase
      await tester.enterText(textFields.at(0), 'lowercase123!');
      await tester.enterText(textFields.at(1), 'lowercase123!');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reset Password'));
      await tester.pumpAndSettle();
      expect(find.text('Password must contain at least one uppercase letter'), findsOneWidget);

      // Missing special character
      await tester.enterText(textFields.at(0), 'Password123');
      await tester.enterText(textFields.at(1), 'Password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reset Password'));
      await tester.pumpAndSettle();
      expect(find.text('Password must contain at least one special character'), findsOneWidget);

      // Passwords mismatch
      await tester.enterText(textFields.at(0), 'ValidPassword123!');
      await tester.enterText(textFields.at(1), 'MismatchPassword123!');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reset Password'));
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('8. Expired or invalid token error from API displays Expired Reset Link view', (tester) async {
      mockAuthRepo.resetPasswordResult = const ApiResult.failure(
        ApiFailure(
          message: 'Invalid or expired password reset token.',
          statusCode: 400,
          type: ApiFailureType.validation,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
          ],
          child: const MaterialApp(
            home: ResetPasswordScreen(initialToken: 'EXPIRED_TOKEN'),
          ),
        ),
      );

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'ValidPassword123!');
      await tester.enterText(textFields.at(1), 'ValidPassword123!');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Reset Password'));
      await tester.pumpAndSettle();

      expect(find.text('Reset Link Expired'), findsOneWidget);
      expect(find.text('Request New Reset Link'), findsOneWidget);
    });

    testWidgets('9. Successful password reset displays success view with sign-in action', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
          ],
          child: const MaterialApp(
            home: ResetPasswordScreen(initialToken: 'VALID_TOKEN'),
          ),
        ),
      );

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'ValidPassword123!');
      await tester.enterText(textFields.at(1), 'ValidPassword123!');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Reset Password'));
      await tester.pumpAndSettle();

      expect(mockAuthRepo.lastResetToken, 'VALID_TOKEN');
      expect(mockAuthRepo.lastResetNewPassword, 'ValidPassword123!');
      expect(find.text('Password Reset Complete'), findsOneWidget);
      expect(find.text('Sign In with New Password'), findsOneWidget);
    });
  });
}
