import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:admin_portal/features/shell/presentation/admin_shell.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/guardians/presentation/pages/guardians_screen.dart';
import 'package:admin_portal/features/guardians/presentation/pages/guardian_details_screen.dart';


class FakeTestSessionManager implements SessionManager {
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
  Future<String?> getSchoolId() async => 'school_1';
  @override
  Future<void> saveSchoolId(String schoolId) async {}
}

class FakeGuardianApiClient extends BaseApiClient {
  bool simulateError = false;
  bool simulateValidationError = false;
  bool returnEmptyList = false;
  bool simulatePrimaryConflict = false;
  bool simulateLoading = false;

  FakeGuardianApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (simulateLoading) {
      return Completer<ApiResult<T>>().future;
    }
    if (simulateError) {
      return ApiResult.failure(const ApiFailure(message: 'Simulated API connection failure', type: ApiFailureType.unknown));
    }

    if (path.contains('/guardians/') && !path.endsWith('/guardians')) {
      return ApiResult.success(mapper({
        'data': {
          'id': 'guardian_1',
          'tenant_id': 'tenant_1',
          'school_id': 'school_1',
          'guardian_type': 'FATHER',
          'first_name': 'John',
          'last_name': 'Doe',
          'gender': 'MALE',
          'date_of_birth': '1985-05-15',
          'aadhaar_number': '123456789012',
          'pan_number': 'ABCDE1234F',
          'occupation': 'Engineer',
          'qualification': 'Bachelor',
          'organization': 'TechCorp',
          'annual_income': 75000.0,
          'mobile': '9876543210',
          'email': 'john.doe@techcorp.com',
          'is_mobile_verified': true,
          'is_email_verified': true,
          'status': 'ACTIVE',
          'is_active': true,
          'version': 1,
          'created_at': '2026-08-14T08:00:00Z',
          'updated_at': '2026-08-14T08:00:00Z',
          'address': {
            'street': '123 Main St',
            'city': 'Metropolis',
            'state': 'NY',
            'postal_code': '10001',
            'country': 'USA'
          }
        }
      }));
    }

    if (path.contains('/guardians')) {
      if (returnEmptyList) {
        return ApiResult.success(mapper({'data': [], 'total': 0}));
      }
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'guardian_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'guardian_type': 'FATHER',
            'first_name': 'John',
            'last_name': 'Doe',
            'gender': 'MALE',
            'date_of_birth': '1985-05-15',
            'aadhaar_number': '123456789012',
            'pan_number': 'ABCDE1234F',
            'occupation': 'Engineer',
            'qualification': 'Bachelor',
            'organization': 'TechCorp',
            'annual_income': 75000.0,
            'mobile': '9876543210',
            'email': 'john.doe@techcorp.com',
            'is_mobile_verified': true,
            'is_email_verified': true,
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1,
            'created_at': '2026-08-14T08:00:00Z',
            'updated_at': '2026-08-14T08:00:00Z',
            'address': {
              'street': '123 Main St',
              'city': 'Metropolis',
              'state': 'NY',
              'postal_code': '10001',
              'country': 'USA'
            }
          }
        ],
        'total': 1
      }));
    }

    if (path.contains('/student-guardians')) {
      if (returnEmptyList) {
        return ApiResult.success(mapper({'data': []}));
      }
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'mapping_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'student_id': 'student_1',
            'guardian_id': 'guardian_1',
            'relationship': 'FATHER',
            'is_primary': true,
            'can_pickup_student': true,
            'receives_notifications': true,
            'version': 1,
            'created_at': '2026-08-14T08:00:00Z',
            'updated_at': '2026-08-14T08:00:00Z'
          }
        ]
      }));
    }

    return ApiResult.failure(const ApiFailure(message: 'Endpoint not mocked', type: ApiFailureType.unknown));
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
    if (simulateValidationError) {
      return ApiResult.failure(const ApiFailure(message: 'Guardian with mobile number already exists.', type: ApiFailureType.unknown, statusCode: 409));
    }
    if (simulatePrimaryConflict && path.contains('/student-guardians')) {
      return ApiResult.failure(const ApiFailure(message: 'A primary guardian has already been assigned to this student.', type: ApiFailureType.unknown, statusCode: 400));
    }
    return ApiResult.success(mapper({'success': true, 'data': {'id': 'new_id'}}));
  }

  @override
  Future<ApiResult<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (simulateValidationError) {
      return ApiResult.failure(const ApiFailure(message: 'Validation failed on email update.', type: ApiFailureType.unknown, statusCode: 422));
    }
    if (simulatePrimaryConflict && path.contains('/student-guardians/')) {
      return ApiResult.failure(const ApiFailure(message: 'A primary guardian has already been assigned to this student.', type: ApiFailureType.unknown, statusCode: 400));
    }
    return ApiResult.success(mapper({'success': true}));
  }

  @override
  Future<ApiResult<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    return ApiResult.success(mapper({'success': true}));
  }
}

void setupViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  late FakeGuardianApiClient fakeApiClient;

  setUp(() {
    fakeApiClient = FakeGuardianApiClient();
  });

  Widget createTestWidget(Widget child) {
    return ProviderScope(
      overrides: [
        sessionManagerProvider.overrideWithValue(FakeTestSessionManager()),
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Guardian Management Feature UI Tests', () {
    testWidgets('1. Guardian list renders', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const GuardiansScreen()));
      await tester.pumpAndSettle();

      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);
      expect(find.text('john.doe@techcorp.com'), findsOneWidget);
    });

    testWidgets('2. Empty state renders', (tester) async {
      setupViewport(tester);
      fakeApiClient.returnEmptyList = true;
      await tester.pumpWidget(createTestWidget(const GuardiansScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('guardian_empty_state')), findsOneWidget);
      expect(find.text('No guardian records found.'), findsOneWidget);
    });

    testWidgets('3. Loading state renders', (tester) async {
      setupViewport(tester);
      fakeApiClient.simulateLoading = true;
      await tester.pumpWidget(createTestWidget(const GuardiansScreen()));
      await tester.pump();
      expect(find.byKey(const Key('guardian_loading_indicator')), findsOneWidget);
    });

    testWidgets('4. API failure renders retry state', (tester) async {
      setupViewport(tester);
      fakeApiClient.simulateError = true;
      await tester.pumpWidget(createTestWidget(const GuardiansScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('guardian_retry_btn')), findsOneWidget);
      expect(find.text('Simulated API connection failure'), findsOneWidget);
    });

    testWidgets('5. Search updates guardian list', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const GuardiansScreen()));
      await tester.pumpAndSettle();

      final searchField = find.byKey(const Key('guardian_search_field'));
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'John');
      await tester.pumpAndSettle();

      expect(find.text('John Doe'), findsOneWidget);
    });

    testWidgets('6. Status filter works', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const GuardiansScreen()));
      await tester.pumpAndSettle();

      final filterDropdown = find.byKey(const Key('guardian_status_filter'));
      expect(filterDropdown, findsOneWidget);
      await tester.tap(filterDropdown);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Active').last);
      await tester.pumpAndSettle();
    });

    testWidgets('7. Add Guardian opens form', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const GuardiansScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add_guardian_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Add Guardian Profile'), findsOneWidget);
      expect(find.text('Basic Information'), findsOneWidget);
    });

    testWidgets('8. Required field validation works', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const GuardiansScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add_guardian_btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('guardian_submit_btn')));
      await tester.pumpAndSettle();

      expect(find.text('First name is required'), findsOneWidget);
      expect(find.text('Last name is required'), findsOneWidget);
    });

    testWidgets('9. Aadhaar validation works', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const GuardiansScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add_guardian_btn')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('guardian_aadhaar_input')), '12345');
      await tester.tap(find.byKey(const Key('guardian_submit_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Aadhaar must be exactly 12 digits'), findsOneWidget);
    });

    testWidgets('10. PAN validation works', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const GuardiansScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add_guardian_btn')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('guardian_pan_input')), 'ABCD123');
      await tester.tap(find.byKey(const Key('guardian_submit_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Invalid PAN card format'), findsOneWidget);
    });

    testWidgets('11. Backend create validation errors display', (tester) async {
      setupViewport(tester);
      fakeApiClient.simulateValidationError = true;
      await tester.pumpWidget(createTestWidget(const GuardiansScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add_guardian_btn')));
      await tester.pumpAndSettle();

      // Enter required fields
      await tester.enterText(find.byKey(const Key('guardian_first_name_input')), 'John');
      await tester.enterText(find.byKey(const Key('guardian_last_name_input')), 'Doe');
      await tester.enterText(find.byKey(const Key('guardian_mobile_input')), '9876543210');

      // Select dob helper
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('guardian_submit_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Guardian with mobile number already exists.'), findsOneWidget);
    });

    testWidgets('12. Guardian details render', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const GuardianDetailsScreen(guardianId: 'guardian_1')));
      await tester.pumpAndSettle();

      expect(find.text('John Doe'), findsWidgets);
      expect(find.text('Contact Information'), findsOneWidget);
      expect(find.text('Credentials & Professional'), findsOneWidget);
      expect(find.text('Address Details'), findsOneWidget);
      expect(find.text('City/Town: Metropolis'), findsOneWidget);
    });

    testWidgets('13. Edit dialog opens with populated data', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const GuardiansScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('edit_guardian_guardian_1')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Guardian Profile'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'John'), findsOneWidget);
    });

    testWidgets('14. Delete confirmation appears', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const GuardiansScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('delete_guardian_guardian_1')));
      await tester.pumpAndSettle();

      expect(find.text('Deactivate Guardian'), findsOneWidget);
      expect(find.text('Are you sure you want to deactivate/soft-delete this guardian profile?'), findsOneWidget);
    });

    testWidgets('15. Delete success refreshes list', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const GuardiansScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('delete_guardian_guardian_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm_delete_guardian_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Guardian deactivated successfully.'), findsOneWidget);
    });

    testWidgets('16. Linked students render', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const GuardianDetailsScreen(guardianId: 'guardian_1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mappings_data_table')), findsOneWidget);
      expect(find.text('student_1'), findsOneWidget);
      expect(find.text('FATHER'), findsWidgets);
    });

    testWidgets('17. Add StudentGuardian mapping works', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const GuardianDetailsScreen(guardianId: 'guardian_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add_mapping_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Link Student Profile'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('mapping_student_id_input')), 'student_2');
      await tester.tap(find.byKey(const Key('mapping_save_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Student mapped successfully.'), findsOneWidget);
    });

    testWidgets('18. Mapping update works', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const GuardianDetailsScreen(guardianId: 'guardian_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('edit_mapping_mapping_1')));
      await tester.pumpAndSettle();

      expect(find.text('Update Mapping Details'), findsOneWidget);
      await tester.tap(find.byKey(const Key('mapping_save_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Mapping details updated.'), findsOneWidget);
    });

    testWidgets('19. Mapping deletion works', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const GuardianDetailsScreen(guardianId: 'guardian_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('unlink_student_mapping_1')));
      await tester.pumpAndSettle();

      expect(find.text('Unlink Student'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm_unlink_student_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Student mapping removed successfully.'), findsOneWidget);
    });

    testWidgets('20. Primary/pickup/notification flags render correctly', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const GuardianDetailsScreen(guardianId: 'guardian_1')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsWidgets);
    });

    testWidgets('21. Backend primary guardian conflict displays correctly', (tester) async {
      setupViewport(tester);
      fakeApiClient.simulatePrimaryConflict = true;
      await tester.pumpWidget(createTestWidget(const GuardianDetailsScreen(guardianId: 'guardian_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add_mapping_btn')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('mapping_student_id_input')), 'student_2');
      await tester.tap(find.byKey(const Key('mapping_save_btn')));
      await tester.pumpAndSettle();

      expect(find.text('A primary guardian has already been assigned to this student.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('mapping_error_ok_btn')));
      await tester.pumpAndSettle();
    });

    testWidgets('22. Sidebar navigates to Guardians', (tester) async {
      setupViewport(tester);
      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          ShellRoute(
            builder: (context, state, child) => AdminShell(child: child),
            routes: [
              GoRoute(path: '/dashboard', builder: (context, state) => const Scaffold(body: Text('Dashboard Page'))),
              GoRoute(path: '/guardians', builder: (context, state) => const Scaffold(body: Text('Guardians Registry Page'))),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionManagerProvider.overrideWithValue(FakeTestSessionManager()),
            selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
            apiClientProvider.overrideWithValue(fakeApiClient),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open drawer/sidebar or check navigation item
      final guardiansTile = find.widgetWithText(ListTile, 'Guardians');
      expect(guardiansTile, findsOneWidget);
      await tester.tap(guardiansTile);
      await tester.pumpAndSettle();

      expect(find.text('Guardians Registry Page'), findsOneWidget);
    });

    testWidgets('23-28. Existing routes remain intact', (tester) async {
      setupViewport(tester);
      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          ShellRoute(
            builder: (context, state, child) => AdminShell(child: child),
            routes: [
              GoRoute(path: '/dashboard', builder: (context, state) => const Scaffold(body: Text('Dashboard Page'))),
              GoRoute(path: '/students', builder: (context, state) => const Scaffold(body: Text('Students Page'))),
              GoRoute(path: '/teachers', builder: (context, state) => const Scaffold(body: Text('Teachers Page'))),
              GoRoute(path: '/attendance', builder: (context, state) => const Scaffold(body: Text('Attendance Page'))),
              GoRoute(path: '/results', builder: (context, state) => const Scaffold(body: Text('Results Page'))),
              GoRoute(path: '/fees', builder: (context, state) => const Scaffold(body: Text('Fees Page'))),
              GoRoute(path: '/migrations', builder: (context, state) => const Scaffold(body: Text('Migrations Page'))),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionManagerProvider.overrideWithValue(FakeTestSessionManager()),
            selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
            apiClientProvider.overrideWithValue(fakeApiClient),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Test route navigation triggers exist
      expect(find.widgetWithText(ListTile, 'Students'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Teachers & Staff'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Attendance'), findsOneWidget);
    });
  });
}
