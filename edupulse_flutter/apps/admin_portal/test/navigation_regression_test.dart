import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/app.dart';
import 'package:admin_portal/core/routing/routes.dart';
import 'package:admin_portal/core/routing/app_router.dart';
import 'package:admin_portal/core/providers/bootstrap_provider.dart';
import 'package:admin_portal/features/shell/presentation/admin_shell.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';

class FakeNavigationRepository implements AuthRepository {
  @override
  Future<ApiResult<SessionToken>> login({required String email, required String password}) async {
    return const ApiResult.success(SessionToken(accessToken: 'mock_access', refreshToken: 'mock_refresh', tokenType: 'bearer'));
  }

  @override
  Future<ApiResult<void>> logout({required String refreshToken}) async {
    return const ApiResult.success(null);
  }

  @override
  Future<ApiResult<SessionToken>> refreshToken({required String refreshToken}) async {
    return const ApiResult.success(SessionToken(accessToken: 'mock_access_new', refreshToken: 'mock_refresh_new', tokenType: 'bearer'));
  }

  @override
  Future<ApiResult<UserEntity>> getCurrentUser() async {
    return const ApiResult.success(UserEntity(
      id: 'admin_id_123',
      email: 'admin@edupulse.ai',
      firstName: 'Main',
      lastName: 'Admin',
      tenantId: 'tenant_1',
      isSuperuser: true,
      roles: ['SUPER_ADMIN'],
      schools: ['school_1'],
    ));
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

class FakeNavigationSessionManager implements SessionManager {
  String? cachedTenantId;

  @override
  Future<String?> getTenantId() async => cachedTenantId;

  @override
  Future<void> saveTenantId(String tenantId) async {
    cachedTenantId = tenantId;
  }

  @override
  Future<String?> getAccessToken() async => 'mock_access';
  @override
  Future<String?> getRefreshToken() async => 'mock_refresh';
  @override
  Future<void> saveSession(SessionToken token) async {}
  @override
  Future<void> clearSession() async {}
  @override
  Future<bool> hasSession() async => true;
  @override
  Future<String?> getSchoolId() async => null; // Simulate initial load / no school context
  @override
  Future<void> saveSchoolId(String schoolId) async {}
}

class FakeNavigationApiClient extends BaseApiClient {
  FakeNavigationApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    // Simulate API failure / timeout or empty response for schools listing
    if (path.contains('/schools')) {
      return ApiResult.failure(const ApiFailure(message: 'Database temporarily unavailable', type: ApiFailureType.unknown));
    }
    return ApiResult.success(mapper({'data': []}));
  }
}

void main() {
  testWidgets('Sidebar navigation regression test - all modules enabled even with null school context', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeApiClient = FakeNavigationApiClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWith((ref) => FakeNavigationRepository()),
          sessionManagerProvider.overrideWith((ref) => FakeNavigationSessionManager()),
          apiClientProvider.overrideWithValue(fakeApiClient),
          bootstrapResultProvider.overrideWithValue(BootstrapResult(success: true)),
        ],
        child: const EduPulseAdminApp(),
      ),
    );

    await tester.pumpAndSettle();

    final appContainer = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    final router = appContainer.read(routerProvider);

    // Verify user details on dashboard screen
    expect(find.byType(AdminShell), findsOneWidget);

    // Verify selectedSchoolId is null (as schools list fetch failed)
    expect(appContainer.read(selectedSchoolIdProvider), isNull);

    // 1. System Administrator sees Dashboard enabled
    final dashboardTile = tester.widget<ListTile>(find.widgetWithText(ListTile, 'Dashboard'));
    expect(dashboardTile.enabled, isTrue);

    // 2. System Administrator sees Students enabled (despite null schoolId)
    final studentsTile = tester.widget<ListTile>(find.widgetWithText(ListTile, 'Students'));
    expect(studentsTile.enabled, isTrue);

    // 3. School Setup sub-items are enabled
    // Expand the School Setup Tile
    await tester.tap(find.text('School Setup'));
    await tester.pumpAndSettle();

    final academicYearsTile = tester.widget<ListTile>(find.widgetWithText(ListTile, 'Academic Years'));
    expect(academicYearsTile.enabled, isTrue);

    final classesTile = tester.widget<ListTile>(find.widgetWithText(ListTile, 'Classes / Grade Levels'));
    expect(classesTile.enabled, isTrue);

    final sectionsTile = tester.widget<ListTile>(find.widgetWithText(ListTile, 'Sections & Rooms'));
    expect(sectionsTile.enabled, isTrue);

    final subjectCatalogTile = tester.widget<ListTile>(find.widgetWithText(ListTile, 'Subject Catalog'));
    expect(subjectCatalogTile.enabled, isTrue);

    // 4. Bulk Import, School Onboarding, and Fees are enabled
    final bulkImportTile = tester.widget<ListTile>(find.widgetWithText(ListTile, 'Bulk Import'));
    expect(bulkImportTile.enabled, isTrue);

    final schoolOnboardingTile = tester.widget<ListTile>(find.widgetWithText(ListTile, 'School Onboarding'));
    expect(schoolOnboardingTile.enabled, isTrue);

    final feesTile = tester.widget<ListTile>(find.widgetWithText(ListTile, 'Fees'));
    expect(feesTile.enabled, isTrue);

    // 5. Reports and Settings modules are enabled
    final reportsTile = tester.widget<ListTile>(find.widgetWithText(ListTile, 'Reports'));
    expect(reportsTile.enabled, isTrue);

    final settingsTile = tester.widget<ListTile>(find.widgetWithText(ListTile, 'Settings'));
    expect(settingsTile.enabled, isTrue);

    // 6. Navigation routing works
    await tester.tap(find.widgetWithText(ListTile, 'Students'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.students);

    // Should load StudentsScreen (which displays placeholder screen for null schoolId)
    expect(find.textContaining('Please select a school campus first'), findsOneWidget);
  });
}
