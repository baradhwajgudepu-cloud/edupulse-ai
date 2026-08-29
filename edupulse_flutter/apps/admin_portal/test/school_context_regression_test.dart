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
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/students/presentation/providers/student_providers.dart';

class FakeContextAuthRepository implements AuthRepository {
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

class FakeContextSessionManager implements SessionManager {
  String? cachedTenantId;

  @override
  Future<String?> getTenantId() async => cachedTenantId;

  @override
  Future<void> saveTenantId(String tenantId) async {
    cachedTenantId = tenantId;
  }

  String? _schoolId;

  FakeContextSessionManager([this._schoolId]);

  @override
  Future<String?> getAccessToken() async => 'mock_access';
  @override
  Future<String?> getRefreshToken() async => 'mock_refresh';
  @override
  Future<void> saveSession(SessionToken token) async {}
  @override
  Future<void> clearSession() async {
    _schoolId = null;
  }
  @override
  Future<bool> hasSession() async => true;
  @override
  Future<String?> getSchoolId() async => _schoolId;
  @override
  Future<void> saveSchoolId(String schoolId) async {
    _schoolId = schoolId;
  }
}

class FakeContextApiClient extends BaseApiClient {
  bool failSchools = false;

  FakeContextApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (path.contains('/academic-years')) {
      return ApiResult.success(mapper({'data': []}));
    } else if (path.contains('/classes')) {
      return ApiResult.success(mapper({'data': []}));
    } else if (path.contains('/sections')) {
      return ApiResult.success(mapper({'data': []}));
    } else if (path.contains('/schools')) {
      if (failSchools) {
        return ApiResult.failure(const ApiFailure(message: 'Database unavailable', type: ApiFailureType.unknown));
      }
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'school_1',
            'name': 'Delhi Public School Hyderabad',
            'tenant_id': 'd09b9362-3dc8-422d-a441-160735fcea96',
            'code': 'DPS001',
            'board': 'CBSE',
            'school_type': 'HIGH_SCHOOL',
            'email': 'info@dpshyd.edu.in',
            'is_active': true,
            'status': 'ACTIVE',
            'version': 1,
          },
          {
            'id': 'school_2',
            'name': 'DPS Bangalore Campus',
            'tenant_id': 'd09b9362-3dc8-422d-a441-160735fcea96',
            'code': 'DPS002',
            'board': 'CBSE',
            'school_type': 'HIGH_SCHOOL',
            'email': 'info@dpsblr.edu.in',
            'is_active': true,
            'status': 'ACTIVE',
            'version': 1,
          }
        ]
      }));
    } else if (path.contains('/students')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'student_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'admission_number': 'ADM-2026-001',
            'admission_date': '2026-08-01',
            'roll_number': '1',
            'first_name': 'Aarav',
            'last_name': 'Sharma',
            'email': 'aarav@example.com',
            'phone': '1234567890',
            'date_of_birth': '2015-05-15',
            'gender': 'MALE',
            'blood_group': 'O+',
            'status': 'ACTIVE',
            'academic_year_id': 'ay_1',
            'class_id': 'class_1',
            'section_id': 'section_1',
            'version': 1,
            'created_at': '2026-08-08T00:00:00Z',
            'updated_at': '2026-08-08T00:00:00Z',
          }
        ],
        'total': 1,
      }));
    }
    return ApiResult.success(mapper({'data': []}));
  }
}

void main() {
  testWidgets('School context loading, switching, and persistence validation flow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeApiClient = FakeContextApiClient();
    final fakeSessionManager = FakeContextSessionManager('school_1'); // Pre-persisted DPS Hyderabad ID

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWith((ref) => FakeContextAuthRepository()),
          sessionManagerProvider.overrideWith((ref) => fakeSessionManager),
          apiClientProvider.overrideWithValue(fakeApiClient),
          bootstrapResultProvider.overrideWithValue(BootstrapResult(success: true)),
        ],
        child: const EduPulseAdminApp(),
      ),
    );

    await tester.pumpAndSettle();

    final appContainer = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

    // Wait for school context to be restored (asynchronous secure storage read)
    int retries = 0;
    while (retries < 10) {
      final currentVal = appContainer.read(selectedSchoolIdProvider);
      // ignore: avoid_print
      print('Test retry loop: retry $retries, selectedSchoolIdProvider = $currentVal');
      if (currentVal != null) break;
      await tester.pump(const Duration(milliseconds: 10));
      retries++;
    }

    final router = appContainer.read(routerProvider);

    // 1. Tenant/Schools loaded successfully
    final schoolsState = appContainer.read(schoolsListProvider);
    expect(schoolsState.schools.length, 2);
    expect(schoolsState.schools.first.name, 'Delhi Public School Hyderabad');

    // 2. Active school context restored successfully from session manager on startup
    expect(appContainer.read(selectedSchoolIdProvider), 'school_1');
    expect(await fakeSessionManager.getSchoolId(), 'school_1');

    // 3. Header displays restored active school selection
    expect(find.text('Delhi Public School Hyderabad'), findsOneWidget);

    // 4. Students provider receives the restored schoolId context
    expect(appContainer.read(studentListProvider).schoolId, 'school_1');

    // 5. Active school context survives route changes
    await tester.tap(find.widgetWithText(ListTile, 'Students'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.students);
    expect(appContainer.read(selectedSchoolIdProvider), 'school_1');
    expect(find.text('Delhi Public School Hyderabad'), findsOneWidget);

    // 6. Navigate back to dashboard
    await tester.tap(find.widgetWithText(ListTile, 'Dashboard'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.dashboard);

    // 7. Switch school dropdown updates selectedSchoolId and triggers persistence update
    await tester.tap(find.text('Delhi Public School Hyderabad'));
    await tester.pumpAndSettle();
    
    // Tap on Bangalore campus
    await tester.tap(find.text('DPS Bangalore Campus').last);
    await tester.pumpAndSettle();

    expect(appContainer.read(selectedSchoolIdProvider), 'school_2');
    expect(await fakeSessionManager.getSchoolId(), 'school_2');
    expect(find.text('DPS Bangalore Campus'), findsOneWidget);

    // 8. Logout clears stored school context
    await tester.tap(find.byTooltip('Sign Out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Out'));
    await tester.pumpAndSettle();

    expect(await fakeSessionManager.getSchoolId(), isNull);
  });
}
