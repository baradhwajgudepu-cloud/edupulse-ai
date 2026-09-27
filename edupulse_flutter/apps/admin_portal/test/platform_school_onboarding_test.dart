import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/core/routing/routes.dart';
import 'package:admin_portal/core/providers/bootstrap_provider.dart';
import 'package:admin_portal/features/school_setup/presentation/widgets/quick_school_onboarding_dialog.dart';
import 'package:admin_portal/features/school_setup/presentation/pages/schools_screen.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';

class FakePlatformAuthRepository implements AuthRepository {
  @override
  Future<ApiResult<SessionToken>> login({required String email, required String password}) async {
    return const ApiResult.success(SessionToken(accessToken: 'mock_platform_token', refreshToken: 'mock_refresh', tokenType: 'bearer'));
  }

  @override
  Future<ApiResult<void>> logout({required String refreshToken}) async => const ApiResult.success(null);

  @override
  Future<ApiResult<SessionToken>> refreshToken({required String refreshToken}) async =>
      const ApiResult.success(SessionToken(accessToken: 'mock_new_token', refreshToken: 'mock_new_refresh', tokenType: 'bearer'));

  @override
  Future<ApiResult<UserEntity>> getCurrentUser() async {
    return const ApiResult.success(UserEntity(
      id: 'platform_admin_id',
      email: 'platform.admin@edupulse.local',
      firstName: 'Platform',
      lastName: 'SuperAdmin',
      tenantId: 'platform_tenant',
      isSuperuser: true,
      roles: ['SUPER_ADMIN', 'PLATFORM_ADMIN'],
      schools: [],
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
  }) async => const ApiResult.success(null);
}

class FakePlatformSessionManager implements SessionManager {
  String? cachedTenantId;
  String? cachedTenantName;
  String? cachedSchoolId;
  String? cachedSchoolName;

  @override
  Future<String?> getTenantId() async => cachedTenantId;

  @override
  Future<void> saveTenantId(String tenantId) async {
    cachedTenantId = tenantId;
  }

  @override
  Future<String?> getTenantName() async => cachedTenantName;

  @override
  Future<void> saveTenantName(String tenantName) async {
    cachedTenantName = tenantName;
  }

  @override
  Future<String?> getSchoolId() async => cachedSchoolId;

  @override
  Future<void> saveSchoolId(String schoolId) async {
    cachedSchoolId = schoolId;
  }

  @override
  Future<String?> getSchoolName() async => cachedSchoolName;

  @override
  Future<void> saveSchoolName(String schoolName) async {
    cachedSchoolName = schoolName;
  }

  @override
  Future<String?> getAccessToken() async => 'mock_platform_token';
  @override
  Future<String?> getRefreshToken() async => 'mock_refresh';
  @override
  Future<void> saveSession(SessionToken token) async {}
  @override
  Future<void> clearSession([String source = 'SessionManager.clearSession']) async {}
  @override
  Future<bool> hasSession() async => true;
}

class FakePlatformApiClient extends BaseApiClient {
  FakePlatformApiClient() : super(Dio());

  final List<Map<String, dynamic>> mockSchools = [
    {
      'id': 'school_existing_1',
      'tenant_id': 'tenant_existing',
      'name': 'Existing Telangana School',
      'code': 'TMS001',
      'board': 'CBSE',
      'school_type': 'HIGH_SCHOOL',
      'email': 'tms@edupulse.local',
      'principal_name': 'Dr. Existing Principal',
      'is_active': true,
      'status': 'ACTIVE',
      'version': 1,
    }
  ];

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (path == '/schools' || path.startsWith('/schools?')) {
      return ApiResult.success(mapper({'data': mockSchools}));
    }
    return ApiResult.failure(const ApiFailure(message: 'Endpoint not found', type: ApiFailureType.unknown));
  }

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    final body = (data is Map<String, dynamic>) ? data : <String, dynamic>{};

    if (path == '/schools/onboard-quick' || path == '/schools/onboard/quick') {
      final schoolName = body['school_name'] ?? 'New School';
      final newSchool = {
        'tenant_id': 'tenant_new_999',
        'tenant_name': schoolName,
        'tenant_code': 'TNT_TMS002',
        'subdomain': 'tms002',
        'school_id': 'school_new_999',
        'school_name': schoolName,
        'school_code': 'TMS002',
        'board': body['board'] ?? 'Not Configured',
        'school_type': body['school_type'] ?? 'Not Configured',
        'logo_url': null,
        'principal_id': 'principal_new_999',
        'principal_name': body['principal_name'] ?? 'Baradhwaj',
        'principal_email': body['principal_email'] ?? 'baradhwaj@example.com',
        'access_token': 'new_principal_access_token',
        'token_type': 'bearer',
        'status': 'ACTIVE',
        'message': 'School created and activated successfully. Principal account provisioned.'
      };

      mockSchools.add({
        'id': 'school_new_999',
        'tenant_id': 'tenant_new_999',
        'name': schoolName,
        'code': 'TMS002',
        'board': 'Not Configured',
        'school_type': 'Not Configured',
        'email': body['principal_email'],
        'principal_name': body['principal_name'],
        'is_active': true,
        'status': 'ACTIVE',
        'version': 1,
      });

      return ApiResult.success(mapper({'data': newSchool}));
    }

    return ApiResult.failure(const ApiFailure(message: 'Endpoint not found', type: ApiFailureType.unknown));
  }

  @override
  Future<ApiResult<T>> put<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken, required T Function(dynamic json) mapper}) async =>
      ApiResult.failure(const ApiFailure(message: 'Not implemented', type: ApiFailureType.unknown));

  @override
  Future<ApiResult<T>> delete<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken, required T Function(dynamic json) mapper}) async =>
      ApiResult.failure(const ApiFailure(message: 'Not implemented', type: ApiFailureType.unknown));

  @override
  Future<ApiResult<T>> patch<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken, required T Function(dynamic json) mapper}) async =>
      ApiResult.failure(const ApiFailure(message: 'Not implemented', type: ApiFailureType.unknown));
}

Widget createTestWidget({required Widget child, required ProviderContainer container}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => child),
      GoRoute(path: AppRoutes.dashboard, builder: (context, state) => const Scaffold(body: Text('Dashboard Page'))),
      GoRoute(path: AppRoutes.schools, builder: (context, state) => const Scaffold(body: Text('Schools Page'))),
    ],
  );

  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: router,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Platform-Level School Creation & Context-Free Onboarding Tests', () {
    late ProviderContainer container;
    late FakePlatformSessionManager fakeSessionManager;
    late FakePlatformApiClient fakeApiClient;

    setUp(() {
      fakeSessionManager = FakePlatformSessionManager();
      fakeApiClient = FakePlatformApiClient();

      container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWith((ref) => FakePlatformAuthRepository()),
          sessionManagerProvider.overrideWith((ref) => fakeSessionManager),
          apiClientProvider.overrideWith((ref) => fakeApiClient),
          bootstrapResultProvider.overrideWithValue(BootstrapResult(success: true)),
        ],
      );

      // Invariant: Platform Admin has NO active school context
      container.read(selectedSchoolIdProvider.notifier).state = null;
      container.read(selectedTenantIdProvider.notifier).state = null;
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('1. Platform Admin opens Create School dialog with NO active school context', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Verify active school context is null
      expect(container.read(selectedSchoolIdProvider), isNull);

      await tester.pumpWidget(
        createTestWidget(
          child: const Scaffold(body: QuickSchoolOnboardingDialog()),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      // Dialog opens successfully
      expect(find.text('CREATE YOUR SCHOOL'), findsOneWidget);
      // Platform Scope Banner is clearly displayed
      expect(find.text('PLATFORM SCOPE'), findsOneWidget);
      expect(find.text('Current Scope: PLATFORM ADMINISTRATION'), findsOneWidget);
      expect(find.textContaining('Active school context required'), findsNothing);
    });

    testWidgets('2. Create School form renders required fields and confirms School Code is NOT an input', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWidget(
          child: const Scaffold(body: QuickSchoolOnboardingDialog()),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      // Required field labels
      expect(find.text('School Name'), findsOneWidget);
      expect(find.text('Principal Name'), findsOneWidget);
      expect(find.text('Principal Email / Login ID'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);

      // School Code must NEVER be an input field (server generates it)
      expect(find.text('School Code *'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'School Code'), findsNothing);

      // Logo upload box is present and optional
      expect(find.text('School Logo'), findsOneWidget);
      expect(find.text('Optional'), findsWidgets);
    });

    testWidgets('3. Required fields validation blocks empty submission', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWidget(
          child: const Scaffold(body: QuickSchoolOnboardingDialog()),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      // Find the Create School submit button
      final createSchoolBtn = find.text('Create School');
      expect(createSchoolBtn, findsOneWidget);

      await tester.tap(createSchoolBtn);
      await tester.pumpAndSettle();

      // Validation errors appear
      expect(find.text('School name is required'), findsOneWidget);
      expect(find.text('Principal name is required'), findsOneWidget);
      expect(find.text('Principal email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('4. Successful school creation displays celebration view with auto-generated code', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWidget(
          child: const Scaffold(body: QuickSchoolOnboardingDialog()),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      // Fill in all 5 required fields
      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(5));

      await tester.enterText(textFields.at(0), 'Telangana Model School');
      await tester.enterText(textFields.at(1), 'Baradhwaj Gudepu');
      await tester.enterText(textFields.at(2), 'baradhwaj@example.com');
      await tester.enterText(textFields.at(3), 'SecurePassword@123');
      await tester.enterText(textFields.at(4), 'SecurePassword@123');

      // Submit
      final createSchoolBtn = find.text('Create School');
      expect(createSchoolBtn, findsOneWidget);
      await tester.tap(createSchoolBtn);
      await tester.pumpAndSettle();

      // Celebration view is presented
      expect(find.text('✓ School Created Successfully'), findsOneWidget);
      expect(find.text('Telangana Model School'), findsOneWidget);
      expect(find.text('TMS002'), findsOneWidget); // Auto-generated code displayed
      expect(find.text('baradhwaj@example.com'), findsWidgets);

      // 3 Verification checkmarks
      expect(find.text('Tenant created'), findsOneWidget);
      expect(find.text('Principal account created'), findsOneWidget);
      expect(find.text('School workspace initialized'), findsOneWidget);

      // Actions are available
      expect(find.text('Open School'), findsOneWidget);
      expect(find.text('Back to School Directory'), findsOneWidget);
    });

    testWidgets('5. Back to School Directory preserves Platform Scope without forcing school context', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWidget(
          child: const Scaffold(body: QuickSchoolOnboardingDialog()),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      // Fill fields and submit
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Telangana Model School');
      await tester.enterText(textFields.at(1), 'Baradhwaj Gudepu');
      await tester.enterText(textFields.at(2), 'baradhwaj@example.com');
      await tester.enterText(textFields.at(3), 'SecurePassword@123');
      await tester.enterText(textFields.at(4), 'SecurePassword@123');

      await tester.tap(find.text('Create School'));
      await tester.pumpAndSettle();

      // Click "Back to School Directory"
      final backBtn = find.text('Back to School Directory');
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      // Platform Scope is preserved: selectedSchoolIdProvider remains NULL
      expect(container.read(selectedSchoolIdProvider), isNull);
    });

    testWidgets('6. Open School action intentionally switches context to newly created school', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWidget(
          child: const Scaffold(body: QuickSchoolOnboardingDialog()),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      // Fill fields and submit
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Telangana Model School');
      await tester.enterText(textFields.at(1), 'Baradhwaj Gudepu');
      await tester.enterText(textFields.at(2), 'baradhwaj@example.com');
      await tester.enterText(textFields.at(3), 'SecurePassword@123');
      await tester.enterText(textFields.at(4), 'SecurePassword@123');

      await tester.tap(find.text('Create School'));
      await tester.pumpAndSettle();

      // Click "Open School"
      final openSchoolBtn = find.text('Open School');
      await tester.tap(openSchoolBtn);
      await tester.pumpAndSettle();

      // Active school context is intentionally updated
      expect(container.read(selectedSchoolIdProvider), equals('school_new_999'));
      expect(container.read(selectedTenantIdProvider), equals('tenant_new_999'));
      expect(fakeSessionManager.cachedSchoolId, equals('school_new_999'));
      expect(fakeSessionManager.cachedTenantId, equals('tenant_new_999'));
    });

    testWidgets('7. School Directory exposes Open School button to enter school context', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWidget(
          child: const SchoolsScreen(),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      // Verify school is listed in table
      expect(find.text('Existing Telangana School'), findsOneWidget);
      expect(find.text('TMS001'), findsOneWidget);

      // Verify Open School button is present
      final openSchoolBtns = find.text('Open School');
      expect(openSchoolBtns, findsWidgets);

      // Tap Open School
      await tester.tap(openSchoolBtns.first, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Context is switched to existing school
      expect(container.read(selectedSchoolIdProvider), equals('school_existing_1'));
    });
  });
}
