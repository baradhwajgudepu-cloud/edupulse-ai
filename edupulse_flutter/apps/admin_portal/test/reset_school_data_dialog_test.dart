import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/features/auth/presentation/providers/auth_provider.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/school_setup/data/models/school_setup_models.dart';
import 'package:admin_portal/features/bulk_import/presentation/widgets/reset_school_data_dialog.dart';
import 'package:admin_portal/features/bulk_import/presentation/pages/school_onboarding_screen.dart';

class FakeResetApiClient extends BaseApiClient {
  final List<Map<String, dynamic>> getCalls = [];
  final List<Map<String, dynamic>> postCalls = [];

  bool failSummary = false;
  bool summaryIneligible = false;
  List<String> summaryQueryErrors = [];
  List<String> summaryBlockingDependencies = [];

  bool failReset = false;
  String resetErrorMessage = 'Server error during reset';

  FakeResetApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    required T Function(dynamic json) mapper,
  }) async {
    getCalls.add({'path': path, 'query': queryParameters});

    if (failSummary) {
      return const ApiResult.failure(ApiFailure(
        type: ApiFailureType.server,
        statusCode: 500,
        message: 'Failed to retrieve school data summary from server.',
      ));
    }

    if (path.contains('/data-summary')) {
      final mockData = {
        'data': {
          'school_id': 'sch-123',
          'school_name': 'Greenwood High International School',
          'tenant_id': 'tenant-abc',
          'tenant_name': 'Greenwood Education Trust',
          'records_to_delete': {
            'students': 120,
            'teachers': 15,
            'classes': 8,
            'sections': 16,
            'timetables': 40,
            'attendances': 250,
          },
          'records_to_preserve': {
            'tenant': 'Greenwood Education Trust',
            'school_identity': 'Greenwood High (GWH01)',
            'user_accounts': '100% preserved (no users deleted)',
            'admin_access': 'Preserved',
            'auth_configuration': 'Preserved',
            'other_schools': 'Preserved',
          },
          'eligible': !summaryIneligible,
          'total_records_to_delete': summaryIneligible ? 0 : 449,
          'confirmation_token': summaryIneligible ? null : 'fake-confirmation-token-jwt-alpha-123',
          'token_expires_at': DateTime.now().add(const Duration(minutes: 15)).toIso8601String(),
          'query_errors': summaryQueryErrors,
          'blocking_dependencies': summaryBlockingDependencies,
        }
      };
      return ApiResult.success(mapper(mockData));
    }

    if (path.contains('/schools') && !path.contains('/data-summary')) {
      final mockSchools = [
        {
          'id': 'sch-123',
          'tenant_id': 'tenant-abc',
          'name': 'Greenwood High International School',
          'code': 'GWH01',
          'board': 'CBSE',
          'school_type': 'HIGH_SCHOOL',
          'email': 'gwh@school.test',
          'is_active': true,
          'status': 'ACTIVE',
          'version': 1,
        }
      ];
      return ApiResult.success(mapper({'data': mockSchools}));
    }

    return ApiResult.success(mapper({'data': {}}));
  }

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    required T Function(dynamic json) mapper,
  }) async {
    postCalls.add({'path': path, 'data': data});

    if (failReset) {
      return ApiResult.failure(ApiFailure(
        type: ApiFailureType.validation,
        statusCode: 422,
        message: resetErrorMessage,
      ));
    }

    if (path.contains('/reset-data')) {
      final mockData = {
        'data': {
          'status': 'completed',
          'school_id': 'sch-123',
          'deleted_counts': {
            'students': 120,
            'teachers': 15,
            'classes': 8,
            'sections': 16,
            'timetables': 40,
            'attendances': 250,
          },
          'total_records_deleted': 449,
          'audit_id': 'audit-reset-999-xyz',
        }
      };
      return ApiResult.success(mapper(mockData));
    }

    return ApiResult.success(mapper({'data': {}}));
  }
}

class FakeAuthStateNotifier extends AuthStateNotifier {
  final AuthState _initialState;
  FakeAuthStateNotifier(this._initialState);

  @override
  AuthState build() => _initialState;
}

class FakeSchoolsListNotifier extends StateNotifier<SchoolsListState> implements SchoolsListNotifier {
  FakeSchoolsListNotifier()
      : super(const SchoolsListState(isLoading: false, schools: [
          SchoolDto(
            id: 'sch-123',
            tenantId: 'tenant-abc',
            name: 'Greenwood High International School',
            code: 'GWH01',
            board: 'CBSE',
            schoolType: 'HIGH_SCHOOL',
            email: 'gwh@school.test',
            isActive: true,
            status: 'ACTIVE',
            version: 1,
          ),
        ]));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeResetApiClient fakeApiClient;

  setUp(() {
    fakeApiClient = FakeResetApiClient();
  });

  Widget createTestWidget({VoidCallback? onResetComplete}) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ResetSchoolDataDialog(
            schoolId: 'sch-123',
            schoolName: 'Greenwood High International School',
            tenantName: 'Greenwood Education Trust',
            onResetComplete: onResetComplete,
          ),
        ),
      ),
    );
  }

  Widget createScreenWithUser({required List<String> roles, bool isSuperuser = false}) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
        authStateProvider.overrideWith(() => FakeAuthStateNotifier(
          Authenticated(
            UserEntity(
              id: 'u_1',
              email: 'test@school.test',
              firstName: 'Test',
              lastName: 'User',
              isSuperuser: isSuperuser,
              roles: roles,
              schools: const ['sch-123'],
              tenantId: 'tenant-abc',
            ),
          ),
        )),
        selectedSchoolIdProvider.overrideWith((ref) => 'sch-123'),
        schoolsListProvider.overrideWith((ref) => FakeSchoolsListNotifier()),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SchoolOnboardingScreen(),
        ),
      ),
    );
  }

  group('ResetSchoolDataDialog Widget Tests', () {
    testWidgets('Renders summary counts, preserved entities, and caution banner when loaded', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestWidget());

      // Initially shows loading
      expect(find.text('Analyzing school operational records...'), findsOneWidget);

      await tester.pumpAndSettle();

      // Header content
      expect(find.text('Reset School Data and Start Onboarding Again'), findsOneWidget);
      expect(find.textContaining('Greenwood High International School'), findsWidgets);
      expect(find.textContaining('Greenwood Education Trust'), findsNWidgets(2));

      // Warning callout
      expect(find.textContaining('CAUTION: This action is permanent and irreversible.'), findsOneWidget);

      // Records to be deleted chips
      expect(find.text('STUDENTS'), findsOneWidget);
      expect(find.text('TEACHERS'), findsOneWidget);
      expect(find.text('CLASSES'), findsOneWidget);
      expect(find.text('TIMETABLES'), findsOneWidget);

      // Preserved entities
      expect(find.text('Protected System Entities (Preserved):'), findsOneWidget);
      expect(find.text('Tenant Organization: '), findsOneWidget);
      expect(find.text('School Identity & Code: '), findsOneWidget);
      expect(find.text('User Accounts & Credentials: '), findsOneWidget);
      expect(find.text('Administrator Access: '), findsOneWidget);
    });

    testWidgets('Validation gate enforces exact name match, checkbox confirmation, and reason length', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final submitFinder = find.byKey(const ValueKey('reset_submit_button'));
      final nameField = find.byKey(const ValueKey('reset_confirm_school_name_field'));
      final reasonField = find.byKey(const ValueKey('reset_reason_field'));
      final checkbox = find.byKey(const ValueKey('reset_confirm_checkbox'));

      // 1. Initially disabled
      FilledButton button = tester.widget<FilledButton>(submitFinder);
      expect(button.onPressed, isNull);

      // 2. Type incorrect name (lowercase) -> still disabled
      await tester.enterText(nameField, 'greenwood high international school');
      await tester.pump();
      button = tester.widget<FilledButton>(submitFinder);
      expect(button.onPressed, isNull);

      // 3. Type exact matching name -> still disabled because checkbox is unchecked and reason empty
      await tester.enterText(nameField, 'Greenwood High International School');
      await tester.pump();
      button = tester.widget<FilledButton>(submitFinder);
      expect(button.onPressed, isNull);

      // 4. Check the confirmation checkbox -> still disabled because reason is empty
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pump();
      button = tester.widget<FilledButton>(submitFinder);
      expect(button.onPressed, isNull);

      // 5. Enter too short reason (2 chars) -> still disabled
      await tester.enterText(reasonField, 'no');
      await tester.pump();
      button = tester.widget<FilledButton>(submitFinder);
      expect(button.onPressed, isNull);

      // 6. Enter valid reason (>= 3 chars) -> now ENABLED!
      await tester.enterText(reasonField, 'Timetable import had broken rows; resetting to restart.');
      await tester.pump();
      button = tester.widget<FilledButton>(submitFinder);
      expect(button.onPressed, isNotNull);

      // 7. Unchecking checkbox disables button again
      await tester.tap(checkbox);
      await tester.pump();
      button = tester.widget<FilledButton>(submitFinder);
      expect(button.onPressed, isNull);

      // 8. Re-checking checkbox enables button again
      await tester.tap(checkbox);
      await tester.pump();
      button = tester.widget<FilledButton>(submitFinder);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('Submitting reset executes API call with confirmation_token, triggers callback, and displays post-reset dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      bool onResetCallbackFired = false;

      await tester.pumpWidget(createTestWidget(
        onResetComplete: () {
          onResetCallbackFired = true;
        },
      ));
      await tester.pumpAndSettle();

      final nameField = find.byKey(const ValueKey('reset_confirm_school_name_field'));
      final reasonField = find.byKey(const ValueKey('reset_reason_field'));
      final checkbox = find.byKey(const ValueKey('reset_confirm_checkbox'));
      final submitFinder = find.byKey(const ValueKey('reset_submit_button'));

      await tester.enterText(nameField, 'Greenwood High International School');
      await tester.enterText(reasonField, 'Corrupted onboarding rows; resetting from Step 1.');
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pump();

      // Tap submit
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      // Verify POST call was dispatched correctly with confirmation_token
      expect(fakeApiClient.postCalls.length, 1);
      final call = fakeApiClient.postCalls.first;
      expect(call['path'], '/schools/sch-123/reset-data');
      expect(call['data']['school_name'], 'Greenwood High International School');
      expect(call['data']['confirm_destruction'], true);
      expect(call['data']['reason'], 'Corrupted onboarding rows; resetting from Step 1.');
      expect(call['data']['confirmation_token'], 'fake-confirmation-token-jwt-alpha-123');

      // Verify onResetComplete callback was called
      expect(onResetCallbackFired, isTrue);

      // Verify post-reset success dialog appears with audit ID and records deleted
      expect(find.text('School Data Reset Completed'), findsOneWidget);
      expect(find.textContaining('Total records deleted: 449'), findsOneWidget);
      expect(find.textContaining('Audit Reference: audit-reset-999-xyz'), findsOneWidget);
      expect(find.text('Proceed to Onboarding'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.byKey(const ValueKey('reset_success_done_button')));
      await tester.pumpAndSettle();
      expect(find.text('School Data Reset Completed'), findsNothing);
    });

    testWidgets('Displays blocking dependency banner and keeps reset disabled when summary is ineligible', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      fakeApiClient.summaryIneligible = true;
      fakeApiClient.summaryQueryErrors = ['Failed to query operational records for category students'];
      fakeApiClient.summaryBlockingDependencies = ['Unresolved database dependency: students'];

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Blocking warning banner is displayed
      expect(find.byKey(const ValueKey('reset_dependencies_error_banner')), findsOneWidget);
      expect(find.text('UNRESOLVED DEPENDENCIES - RESET DISABLED'), findsOneWidget);
      expect(find.textContaining('Failed to query operational records for category students'), findsOneWidget);
      expect(find.textContaining('Unresolved database dependency: students'), findsOneWidget);

      final nameField = find.byKey(const ValueKey('reset_confirm_school_name_field'));
      final reasonField = find.byKey(const ValueKey('reset_reason_field'));
      final checkbox = find.byKey(const ValueKey('reset_confirm_checkbox'));
      final submitFinder = find.byKey(const ValueKey('reset_submit_button'));

      await tester.enterText(nameField, 'Greenwood High International School');
      await tester.enterText(reasonField, 'Attempting reset despite pre-flight error');
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pump();

      // Submit button must remain strictly disabled
      final FilledButton button = tester.widget<FilledButton>(submitFinder);
      expect(button.onPressed, isNull);
    });

    testWidgets('API error during reset displays inline error banner without dismissing form', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      fakeApiClient.failReset = true;
      fakeApiClient.resetErrorMessage = 'Confirmation school name does not match server record.';

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final nameField = find.byKey(const ValueKey('reset_confirm_school_name_field'));
      final reasonField = find.byKey(const ValueKey('reset_reason_field'));
      final checkbox = find.byKey(const ValueKey('reset_confirm_checkbox'));
      final submitFinder = find.byKey(const ValueKey('reset_submit_button'));

      await tester.enterText(nameField, 'Greenwood High International School');
      await tester.enterText(reasonField, 'Resetting test');
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pump();

      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      // Error banner is shown
      expect(find.text('Confirmation school name does not match server record.'), findsOneWidget);

      // Form inputs are preserved
      expect(find.text('Greenwood High International School'), findsWidgets);
      expect(find.text('Resetting test'), findsOneWidget);
    });

    testWidgets('Reset button is hidden in SchoolOnboardingScreen for TEACHER role', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createScreenWithUser(roles: ['TEACHER']));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('reset_school_data_button')), findsNothing);
    });

    testWidgets('Reset button is hidden in SchoolOnboardingScreen for ordinary ADMIN role', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createScreenWithUser(roles: ['ADMIN']));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('reset_school_data_button')), findsNothing);
    });

    testWidgets('Reset button is hidden in SchoolOnboardingScreen for ADMINISTRATOR role', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createScreenWithUser(roles: ['ADMINISTRATOR']));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('reset_school_data_button')), findsNothing);
    });

    testWidgets('Reset button is hidden in SchoolOnboardingScreen for PRINCIPAL role', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createScreenWithUser(roles: ['PRINCIPAL']));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('reset_school_data_button')), findsNothing);
    });

    testWidgets('Reset button is visible in SchoolOnboardingScreen for TENANT_ADMIN role', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createScreenWithUser(roles: ['TENANT_ADMIN']));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('reset_school_data_button')), findsOneWidget);
    });

    testWidgets('Reset button is visible in SchoolOnboardingScreen for SUPER_ADMIN and opens dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createScreenWithUser(roles: ['SUPER_ADMIN'], isSuperuser: true));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('reset_school_data_button')), findsOneWidget);
      expect(find.text('Reset School Data and Start Onboarding Again'), findsOneWidget);

      // Tapping it opens ResetSchoolDataDialog
      await tester.tap(find.byKey(const ValueKey('reset_school_data_button')));
      await tester.pumpAndSettle();

      expect(find.byType(ResetSchoolDataDialog), findsOneWidget);
    });
  });
}
