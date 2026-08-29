import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_portal/features/auth/presentation/pages/login_screen.dart';
import 'package:admin_portal/features/auth/presentation/pages/forgot_password_screen.dart';
import 'package:admin_portal/features/auth/presentation/pages/reset_password_screen.dart';

void main() {
  group('Forgot Password & Password Reset UI Tests', () {
    testWidgets('1. LoginScreen displays Forgot Password? button', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      expect(find.text('Forgot Password?'), findsOneWidget);
    });

    testWidgets('2. ForgotPasswordScreen renders email field and submit button', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ForgotPasswordScreen(),
          ),
        ),
      );

      expect(find.text('Forgot Password'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
      expect(find.text('Return to Sign In'), findsOneWidget);
    });

    testWidgets('3. ForgotPasswordScreen validates empty and invalid email', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ForgotPasswordScreen(),
          ),
        ),
      );

      // Tap Send without entering email
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);

      // Enter invalid email
      await tester.enterText(find.byType(TextFormField), 'invalid-email');
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
    });

    testWidgets('4. ResetPasswordScreen shows invalid token view when token is missing', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ResetPasswordScreen(initialToken: null),
          ),
        ),
      );

      expect(find.text('Invalid Reset Link'), findsOneWidget);
      expect(find.text('Request New Reset Link'), findsOneWidget);
    });

    testWidgets('5. ResetPasswordScreen displays password inputs when token is provided', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ResetPasswordScreen(initialToken: 'valid_test_token_123'),
          ),
        ),
      );

      expect(find.text('Reset Password'), findsNWidgets(2)); // Title and submit button
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Reset Password'), findsOneWidget);
    });

    testWidgets('6. ResetPasswordScreen validates password mismatch', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ResetPasswordScreen(initialToken: 'valid_test_token_123'),
          ),
        ),
      );

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Password123!');
      await tester.enterText(textFields.at(1), 'DifferentPassword456@');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Reset Password'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });
  });
}
