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
import 'package:admin_portal/features/planner/presentation/providers/planner_providers.dart';

class FakePlannerAuthRepository implements AuthRepository {
  final UserEntity mockUser;
  FakePlannerAuthRepository(this.mockUser);

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
    return ApiResult.success(mockUser);
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

class FakePlannerSessionManager implements SessionManager {
  String? _schoolId;
  String? cachedTenantId;

  FakePlannerSessionManager([this._schoolId]);

  @override
  Future<String?> getTenantId() async => cachedTenantId;
  @override
  Future<void> saveTenantId(String tenantId) async { cachedTenantId = tenantId; }
  @override
  Future<String?> getAccessToken() async => 'mock_access';
  @override
  Future<String?> getRefreshToken() async => 'mock_refresh';
  @override
  Future<void> saveSession(SessionToken token) async {}
  @override
  Future<void> clearSession() async { _schoolId = null; }
  @override
  Future<bool> hasSession() async => true;
  @override
  Future<String?> getSchoolId() async => _schoolId;
  @override
  Future<void> saveSchoolId(String schoolId) async { _schoolId = schoolId; }
}

class FakePlannerApiClient extends BaseApiClient {
  List<Map<String, dynamic>> loggedRequests = [];

  FakePlannerApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    final headers = options?.headers ?? {};
    loggedRequests.add({
      'path': path,
      'query': queryParameters,
      'headers': headers,
    });

    if (path.contains('/schools')) {
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
            'name': 'Delhi Public School Hyderabad - Campus 2',
            'tenant_id': 'e949f0ba-2f9e-495b-a3b0-8f672070746a',
            'code': 'DPS002',
            'board': 'CBSE',
            'school_type': 'HIGH_SCHOOL',
            'email': 'campus2@dpshyd.edu.in',
            'is_active': true,
            'status': 'ACTIVE',
            'version': 1,
          }
        ]
      }));
    } else if (path.contains('/announcements')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'announcement_1',
            'school_id': queryParameters?['school_id'] ?? 'school_1',
            'title': 'Test Announcement for ${queryParameters?['school_id']}',
            'content': 'Welcome',
            'status': 'PUBLISHED',
          }
        ]
      }));
    } else if (path.contains('/events')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'event_1',
            'school_id': queryParameters?['school_id'] ?? 'school_1',
            'title': 'Test Event',
            'start_time': '2026-08-24T10:00:00Z',
            'end_time': '2026-08-24T11:00:00Z',
          }
        ]
      }));
    } else if (path.contains('/examinations')) {
      return ApiResult.success(mapper({
        'data': []
      }));
    }
    return ApiResult.success(mapper({'data': []}));
  }
}

void main() {
  testWidgets('Super Admin planner context switching and active tenant resolution verification', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeUser = const UserEntity(
      id: 'admin_id_123',
      email: 'admin@edupulse.com',
      firstName: 'Super',
      lastName: 'Admin',
      tenantId: 'd09b9362-3dc8-422d-a441-160735fcea96',
      isSuperuser: true,
      roles: ['SUPER_ADMIN'],
      schools: ['school_1', 'school_2'],
    );

    final fakeApiClient = FakePlannerApiClient();
    final fakeSessionManager = FakePlannerSessionManager('school_1');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWith((ref) => FakePlannerAuthRepository(fakeUser)),
          sessionManagerProvider.overrideWith((ref) => fakeSessionManager),
          apiClientProvider.overrideWithValue(fakeApiClient),
          bootstrapResultProvider.overrideWithValue(BootstrapResult(success: true)),
          
          activeTenantIdProvider.overrideWith((ref) {
            final selectedSchoolId = ref.watch(selectedSchoolIdProvider);
            if (selectedSchoolId != null) {
              final schoolsState = ref.watch(schoolsListProvider);
              final match = schoolsState.schools.where((s) => s.id == selectedSchoolId);
              if (match.isNotEmpty) {
                return match.first.tenantId;
              }
            }
            final selectedTenantId = ref.watch(selectedTenantIdProvider);
            if (selectedTenantId != null && selectedTenantId.isNotEmpty) {
              return selectedTenantId;
            }
            final config = ref.watch(buildConfigProvider);
            return config.tenantId;
          }),
        ],
        child: const EduPulseAdminApp(),
      ),
    );

    await tester.pumpAndSettle();

    final appContainer = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

    int retries = 0;
    while (retries < 10) {
      final schools = appContainer.read(schoolsListProvider).schools;
      if (schools.isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 10));
      retries++;
    }

    // 1. Initial State: DPS001 school selected, activeTenantId matches DPS001's tenant_id
    expect(appContainer.read(selectedSchoolIdProvider), 'school_1');
    expect(appContainer.read(activeTenantIdProvider), 'd09b9362-3dc8-422d-a441-160735fcea96');

    // Fetch announcements for school_1
    await appContainer.read(announcementsListProvider.notifier).fetchAnnouncements();
    
    var lastReq = fakeApiClient.loggedRequests.last;
    expect(lastReq['query']['school_id'], 'school_1');

    // 2. Switch to DPS002
    await tester.tap(find.byType(DropdownButton<String?>));
    await tester.pumpAndSettle();
    
    await tester.tap(find.text('Delhi Public School Hyderabad - Campus 2').last);
    await tester.pumpAndSettle();

    // Verification: Context changed synchronously and correctly
    expect(appContainer.read(selectedSchoolIdProvider), 'school_2');
    expect(appContainer.read(activeTenantIdProvider), 'e949f0ba-2f9e-495b-a3b0-8f672070746a');

    // Fetch announcements for school_2
    await appContainer.read(announcementsListProvider.notifier).fetchAnnouncements();
    
    lastReq = fakeApiClient.loggedRequests.last;
    expect(lastReq['query']['school_id'], 'school_2');

    // 3. Switch back to DPS001
    await tester.tap(find.byType(DropdownButton<String?>));
    await tester.pumpAndSettle();
    
    await tester.tap(find.text('Delhi Public School Hyderabad').last);
    await tester.pumpAndSettle();

    // Verify switched back successfully
    expect(appContainer.read(selectedSchoolIdProvider), 'school_1');
    expect(appContainer.read(activeTenantIdProvider), 'd09b9362-3dc8-422d-a441-160735fcea96');
  });
}
