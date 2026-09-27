import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/core/routing/routes.dart';
import 'package:admin_portal/core/routing/app_router.dart';
import 'package:admin_portal/features/auth/presentation/pages/privacy_policy_screen.dart';
import 'package:admin_portal/features/auth/presentation/pages/login_screen.dart';
import 'package:admin_portal/features/auth/presentation/providers/auth_provider.dart';

class _FakeAuthStateNotifier extends AuthStateNotifier {
  final AuthState _initialState;
  _FakeAuthStateNotifier(this._initialState);

  @override
  AuthState build() => _initialState;

  @override
  Future<void> checkAuth() async {}
}

void main() {
  group('Privacy Policy Routing & Authentication Guard Tests', () {
    test('1. Unauthenticated user can access /privacy-policy without login redirect', () {
      final redirect = appRouterRedirect(
        authState: const Unauthenticated(),
        matchedLocation: AppRoutes.privacyPolicy,
      );
      expect(redirect, isNull, reason: 'Must not redirect unauthenticated users away from Privacy Policy');
    });

    test('2. Authenticated user can view /privacy-policy without dashboard redirect', () {
      const user = UserEntity(
        id: 'user_1',
        email: 'admin@school.edu',
        firstName: 'Admin',
        lastName: 'User',
        tenantId: 'tenant_1',
        isSuperuser: true,
        roles: ['SUPER_ADMIN'],
        schools: ['school_1'],
      );
      final redirect = appRouterRedirect(
        authState: const Authenticated(user),
        matchedLocation: AppRoutes.privacyPolicy,
      );
      expect(redirect, isNull, reason: 'Must allow authenticated users to view Privacy Policy');
    });

    test('3. Locked user can access /privacy-policy without login redirect', () {
      final redirect = appRouterRedirect(
        authState: const AccountLocked('Locked out'),
        matchedLocation: AppRoutes.privacyPolicy,
      );
      expect(redirect, isNull, reason: 'Must allow locked users to read Privacy Policy');
    });
  });

  group('Privacy Policy Screen Rendering & Content Tests', () {
    testWidgets('4. Renders all essential educational data privacy sections', (tester) async {
      tester.view.physicalSize = const Size(1024, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: PrivacyPolicyScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check title and hero
      expect(find.text('EduPulse AI Privacy Policy'), findsOneWidget);
      expect(find.text('LEGAL & COMPLIANCE'), findsOneWidget);

      Future<void> expectSection(String sectionTitle) async {
        await tester.scrollUntilVisible(
          find.text(sectionTitle),
          200.0,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(sectionTitle), findsOneWidget);
      }

      await expectSection('1. Introduction & Multi-Tenant Architecture');
      await expectSection('2. Student Personal & Academic Data');
      await expectSection('3. Parent & Guardian Information');
      await expectSection('4. Teacher & Staff Information');
      await expectSection('5. Principal & Administrative Accounts');
      await expectSection('6. Attendance Records & Campus Geofencing');
      await expectSection('7. Academic Analytics & Artificial Intelligence');
      await expectSection('8. Fee Payments & Financial Data');
      await expectSection('9. Security Controls & Data Protection');
      await expectSection('10. Data Retention, Portability & Deletion');
      await expectSection('11. Contact Our Data Protection Officer (DPO)');
      await expectSection('Return to Admin Portal Sign In');
    });

    testWidgets('5. Mobile viewport (390x844) renders without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: PrivacyPolicyScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Mobile layout must have zero RenderFlex overflows');
      expect(find.text('EduPulse AI Privacy Policy'), findsOneWidget);
    });
  });

  group('Public Footer Link Integration Tests', () {
    testWidgets('6. LoginScreen public footer contains clickable Privacy Policy link', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool privacyPolicyNavigated = false;

      final router = GoRouter(
        initialLocation: AppRoutes.login,
        routes: [
          GoRoute(
            path: AppRoutes.login,
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: AppRoutes.privacyPolicy,
            builder: (context, state) {
              privacyPolicyNavigated = true;
              return const Scaffold(body: Text('Privacy Policy Destination'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(() => _FakeAuthStateNotifier(const AuthInitial())),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final linkFinder = find.byKey(const Key('public_footer_privacy_policy_link'));
      expect(linkFinder, findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);

      await tester.tap(linkFinder);
      await tester.pumpAndSettle();

      expect(privacyPolicyNavigated, isTrue, reason: 'Clicking Privacy Policy footer link must navigate to /privacy-policy');
      expect(find.text('Privacy Policy Destination'), findsOneWidget);
    });
  });
}
