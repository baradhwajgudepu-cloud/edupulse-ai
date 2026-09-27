import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/features/tenant_setup/data/models/tenant_models.dart';
import 'package:admin_portal/features/tenant_setup/presentation/providers/tenant_providers.dart';
import 'package:admin_portal/features/tenant_setup/presentation/pages/tenants_screen.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';

class MockSessionManager implements SessionManager {
  String? savedTenantId = 'init-tenant';
  String? savedSchoolId = 'init-school';

  @override
  Future<String?> getTenantId() async => savedTenantId;
  @override
  Future<void> saveTenantId(String tenantId) async {
    savedTenantId = tenantId;
  }
  @override
  Future<String?> getTenantName() async => 'Mock Tenant';
  @override
  Future<void> saveTenantName(String tenantName) async {}
  @override
  Future<String?> getSchoolId() async => savedSchoolId;
  @override
  Future<void> saveSchoolId(String schoolId) async {
    savedSchoolId = schoolId;
  }
  @override
  Future<String?> getSchoolName() async => 'Mock School';
  @override
  Future<void> saveSchoolName(String schoolName) async {}
  @override
  Future<String?> getAccessToken() async => 'mock-token';
  @override
  Future<String?> getRefreshToken() async => 'mock-refresh';
  @override
  Future<void> saveSession(SessionToken token) async {}
  @override
  Future<void> clearSession([String source = 'SessionManager.clearSession']) async {
    savedTenantId = null;
    savedSchoolId = null;
  }
  @override
  Future<bool> hasSession() async => true;
}

class FakeApiClient extends BaseApiClient {
  FakeApiClient() : super(Dio());

  String? lastDeletedPath;

  @override
  Future<ApiResult<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    dynamic options,
    dynamic cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    lastDeletedPath = path;
    if (path.contains('dry_run=true')) {
      final mockSummary = {
        'data': {
          'tenant_id': 'tenant-123',
          'tenant_name': 'Test Tenant High',
          'tenant_code': 'test-th',
          'dry_run': true,
          'deleted_counts': {'schools': 2, 'students': 500, 'teachers': 25},
          'total_records_deleted': 527,
          'storage_cleanup': {'status': 'skipped'},
          'warnings': <String>[]
        }
      };
      return ApiResult.success(mapper(mockSummary));
    } else {
      final mockSummary = {
        'data': {
          'tenant_id': 'tenant-123',
          'tenant_name': 'Test Tenant High',
          'tenant_code': 'test-th',
          'dry_run': false,
          'deleted_counts': {'schools': 2, 'students': 500, 'teachers': 25},
          'total_records_deleted': 527,
          'storage_cleanup': {'status': 'success', 'files_removed': 3},
          'warnings': <String>[]
        }
      };
      return ApiResult.success(mapper(mockSummary));
    }
  }

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    dynamic options,
    dynamic cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    return ApiResult.success(mapper({'data': []}));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testTenant = TenantDto(
    id: 'tenant-123',
    name: 'Delhi Public School Society',
    code: 'dps-soc',
    subdomain: 'dps',
    email: 'admin@dps.edu',
    timezone: 'Asia/Kolkata',
    currency: 'INR',
    isActive: true,
    status: 'ACTIVE',
  );

  final systemTenant = TenantDto(
    id: 'ff9e842b-3008-451b-a42b-e177c996d3e9',
    name: 'EduPulse Platform Master',
    code: 'EDUPULSE_SYSTEM',
    subdomain: 'platform',
    email: 'admin@edupulse.local',
    timezone: 'Asia/Kolkata',
    currency: 'INR',
    isActive: true,
    status: 'ACTIVE',
  );

  group('Permanent Tenant Deletion Unit & Lifecycle Tests', () {
    test('deleteTenantPermanent clears active context and session storage when deleting active tenant', () async {
      final fakeApi = FakeApiClient();
      final mockSession = MockSessionManager();

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(fakeApi),
          sessionManagerProvider.overrideWithValue(mockSession),
        ],
      );

      // Set active tenant to tenant-123
      container.read(selectedTenantIdProvider.notifier).state = 'tenant-123';
      container.read(selectedSchoolIdProvider.notifier).state = 'school-abc';

      final notifier = container.read(tenantsListProvider.notifier);
      final result = await notifier.deleteTenantPermanent('tenant-123');

      expect(result.isSuccess, true);
      expect(fakeApi.lastDeletedPath, '/tenants/tenant-123/permanent');

      // Verify active context was reset
      expect(container.read(selectedTenantIdProvider), isNull);
      expect(container.read(selectedSchoolIdProvider), isNull);
      expect(mockSession.savedTenantId, '');
      expect(mockSession.savedSchoolId, '');
    });

    test('previewTenantDeletion queries with dry_run=true', () async {
      final fakeApi = FakeApiClient();
      final mockSession = MockSessionManager();

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(fakeApi),
          sessionManagerProvider.overrideWithValue(mockSession),
        ],
      );

      final notifier = container.read(tenantsListProvider.notifier);
      final result = await notifier.previewTenantDeletion('tenant-123');

      expect(result.isSuccess, true);
      expect(fakeApi.lastDeletedPath, '/tenants/tenant-123/permanent?dry_run=true');

      result.when(
        onSuccess: (summary) {
          expect(summary.dryRun, true);
          expect(summary.totalRecordsDeleted, 527);
          expect(summary.deletedCounts['students'], 500);
        },
        onFailure: (f) => fail(f.message),
      );
    });

    test('EDUPULSE_SYSTEM master tenant is recognized and protected', () {
      expect(systemTenant.code.toUpperCase(), 'EDUPULSE_SYSTEM');
      expect(systemTenant.id, 'ff9e842b-3008-451b-a42b-e177c996d3e9');
    });
  });

  group('TenantDeleteDialog Confirmation Safety Widget Tests', () {
    testWidgets('Confirmation button is disabled until EXACT tenant name is typed', (tester) async {
      final fakeApi = FakeApiClient();
      final mockSession = MockSessionManager();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeApi),
            sessionManagerProvider.overrideWithValue(mockSession),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: TenantDeleteDialog(tenant: testTenant),
            ),
          ),
        ),
      );

      // Let dry run preview complete
      await tester.pumpAndSettle();

      expect(find.text('Delete Tenant Permanently'), findsOneWidget);
      expect(find.text('Delhi Public School Society'), findsWidgets);
      expect(find.textContaining('DANGER: This action is irreversible'), findsOneWidget);

      final deleteButtonFinder = find.widgetWithText(ElevatedButton, 'DELETE TENANT PERMANENTLY');
      expect(deleteButtonFinder, findsOneWidget);

      // 1. Button must be initially disabled
      ElevatedButton button = tester.widget(deleteButtonFinder);
      expect(button.onPressed, isNull, reason: 'Delete button must be disabled initially');

      // 2. Typing wrong name keeps button disabled
      final inputFinder = find.byType(TextField);
      await tester.enterText(inputFinder, 'Wrong School Name');
      await tester.pump();

      button = tester.widget(deleteButtonFinder);
      expect(button.onPressed, isNull, reason: 'Delete button must remain disabled with mismatched name');

      // 3. Typing case-differing name keeps button disabled
      await tester.enterText(inputFinder, 'delhi public school society');
      await tester.pump();

      button = tester.widget(deleteButtonFinder);
      expect(button.onPressed, isNull, reason: 'Delete button must remain disabled when case differs');

      // 4. Typing exact name enables the button
      await tester.enterText(inputFinder, 'Delhi Public School Society');
      await tester.pump();

      button = tester.widget(deleteButtonFinder);
      expect(button.onPressed, isNotNull, reason: 'Delete button must be enabled when exact name matches');

      // 5. Click the enabled button and verify deletion is executed
      await tester.tap(deleteButtonFinder);
      await tester.pumpAndSettle();

      expect(fakeApi.lastDeletedPath, '/tenants/tenant-123/permanent');
    });
  });
}
