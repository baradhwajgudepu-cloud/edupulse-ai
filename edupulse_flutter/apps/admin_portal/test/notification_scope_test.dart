import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:admin_portal/features/shell/presentation/admin_shell.dart';
import 'package:admin_portal/features/auth/presentation/providers/auth_provider.dart';

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
  _MockAuthStateNotifier(this._initialState);

  @override
  AuthState build() => _initialState;

  @override
  Future<void> checkAuth() async {}

  @override
  Future<void> logout() async {
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

  group('Notification and SnackBar Scoping Tests', () {
    testWidgets('AdminShell clears active SnackBars when navigating to a new child widget', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authNotifier = _MockAuthStateNotifier(const Authenticated(testUser));
      final fakeApiClient = _FakeApiClient();

      final router = GoRouter(
        initialLocation: '/page-one',
        routes: [
          ShellRoute(
            builder: (context, state, child) => AdminShell(child: child),
            routes: [
              GoRoute(
                path: '/page-one',
                builder: (context, state) => const Scaffold(
                  body: Center(key: Key('page_one'), child: Text('Page One')),
                ),
              ),
              GoRoute(
                path: '/page-two',
                builder: (context, state) => const Scaffold(
                  body: Center(key: Key('page_two'), child: Text('Page Two')),
                ),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(() => authNotifier),
            apiClientProvider.overrideWithValue(fakeApiClient),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Show a floating SnackBar on Page One
      final messenger = ScaffoldMessenger.of(tester.element(find.byKey(const Key('page_one'))));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Leaked notification from Page One'),
          duration: Duration(seconds: 10),
        ),
      );

      await tester.pump();
      expect(find.text('Leaked notification from Page One'), findsOneWidget);

      // Now route to Page Two
      router.go('/page-two');
      await tester.pumpAndSettle();

      // Verify that didUpdateWidget cleared the SnackBar on route change
      expect(find.text('Leaked notification from Page One'), findsNothing);
      expect(find.text('Page Two'), findsOneWidget);
    });
  });
}
