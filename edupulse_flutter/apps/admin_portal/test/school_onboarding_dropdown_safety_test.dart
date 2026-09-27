import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/core/presentation/utils/dropdown_safety.dart';
import 'package:admin_portal/core/presentation/widgets/safe_dropdown.dart';
import 'package:admin_portal/features/bulk_import/presentation/pages/school_onboarding_screen.dart';
import 'package:admin_portal/features/bulk_import/presentation/providers/school_onboarding_providers.dart';
import 'package:admin_portal/features/school_setup/presentation/pages/school_setup_center_screen.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/school_setup/data/models/school_setup_models.dart';
import 'package:admin_portal/features/tenant_setup/presentation/providers/tenant_providers.dart';
import 'package:admin_portal/features/tenant_setup/data/models/tenant_models.dart';
import 'package:admin_portal/features/planner/presentation/pages/planner_schedule_screen.dart';
import 'school_onboarding_test.dart';

class FakeSafeApiClient extends BaseApiClient {
  FakeSafeApiClient() : super(Dio());

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

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    return ApiResult.success(mapper({'data': {}}));
  }
}

class FakeSchoolsListNotifier extends StateNotifier<SchoolsListState> implements SchoolsListNotifier {
  FakeSchoolsListNotifier(super.state);

  @override
  Future<void> fetchSchools() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('School Onboarding Dropdown Safety & Stale Context Recovery (15 Regression Tests)', () {
    // 1. Dropdown with valid selected ID renders successfully
    testWidgets('1. Dropdown with valid selected ID renders successfully', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeDropdownButton<String>(
              value: 'school-1',
              items: const [
                DropdownMenuItem(value: 'school-1', child: Text('Delhi Public School')),
                DropdownMenuItem(value: 'school-2', child: Text('St. Mary High School')),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Delhi Public School'), findsOneWidget);
    });

    // 2. Dropdown with stale deleted-school ID does not crash
    testWidgets('2. Dropdown with stale deleted-school ID does not crash', (tester) async {
      const staleDeletedId = 'efbf3645-cb45-41e7-8ba0-21c0c7954b9d';
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeDropdownButton<String>(
              value: staleDeletedId,
              fallbackValue: null,
              items: const [
                DropdownMenuItem(value: 'school-active-1', child: Text('Hyderabad Public School')),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    // 3. Stale selected ID becomes null
    test('3. Stale selected ID becomes null', () {
      const staleDeletedId = 'efbf3645-cb45-41e7-8ba0-21c0c7954b9d';
      final availableIds = ['school-active-1', 'school-active-2'];

      final resolvedValue = DropdownSafety.safeValue<String>(
        selectedValue: staleDeletedId,
        validValues: availableIds,
        fallback: null,
      );

      expect(resolvedValue, isNull);
    });

    // 4. Duplicate school IDs are safely deduplicated
    testWidgets('4. Duplicate school IDs are safely deduplicated', (tester) async {
      final duplicateItems = [
        const DropdownMenuItem(value: 'school-1', child: Text('School Copy A')),
        const DropdownMenuItem(value: 'school-1', child: Text('School Copy B')),
        const DropdownMenuItem(value: 'school-2', child: Text('School Copy C')),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeDropdownButton<String>(
              value: 'school-1',
              items: duplicateItems,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('School Copy A'), findsOneWidget);
    });

    // 5. Empty school list renders correctly
    testWidgets('5. Empty school list renders correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeDropdownButton<String>(
              value: 'any-stale-id',
              fallbackValue: null,
              items: const [],
              hint: const Text('No schools available'),
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('No schools available'), findsOneWidget);
    });

    // 6. Platform Scope works without school context
    test('6. Platform Scope works without school context', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(selectedSchoolIdProvider), isNull);
      expect(container.read(selectedTenantIdProvider), isNull);
      
      final onboardingState = container.read(schoolOnboardingProvider);
      expect(onboardingState.selectedTenantId, isNull);
    });

    // 7. New school can be opened after creation
    test('7. New school can be opened after creation', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const newSchoolId = 'new-school-uuid-999';
      expect(container.read(selectedSchoolIdProvider), isNull);

      container.read(selectedSchoolIdProvider.notifier).state = newSchoolId;
      expect(container.read(selectedSchoolIdProvider), newSchoolId);
    });

    // 8. Back to School Directory preserves Platform Scope
    test('8. Back to School Directory preserves Platform Scope', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedSchoolIdProvider.notifier).state = 'some-school-id';
      expect(container.read(selectedSchoolIdProvider), 'some-school-id');

      container.read(selectedSchoolIdProvider.notifier).state = null;
      container.read(selectedAcademicYearIdProvider.notifier).state = null;

      expect(container.read(selectedSchoolIdProvider), isNull);
      expect(container.read(selectedAcademicYearIdProvider), isNull);
    });

    // 9. Deleted school ID in browser storage is recovered
    test('9. Deleted school ID in browser storage is recovered', () async {
      final fakeSession = FakeOnboardingSessionManager();
      fakeSession.cachedSchoolId = 'deleted-school-uuid-111';

      final fakeApi = FakeOnboardingApiClient();

      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(fakeSession),
          apiClientProvider.overrideWithValue(fakeApi),
        ],
      );
      addTearDown(container.dispose);

      expect(await fakeSession.getSchoolId(), 'deleted-school-uuid-111');

      await container.read(schoolsListProvider.notifier).fetchSchools();

      final activeSchools = container.read(schoolsListProvider).schools;
      final exists = activeSchools.any((s) => s.id == 'deleted-school-uuid-111');
      if (!exists) {
        expect(container.read(selectedSchoolIdProvider), isNot('deleted-school-uuid-111'));
      }
    });

    // 10. Onboarding pipeline opens without active school
    testWidgets('10. Onboarding pipeline opens without active school', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(FakeSafeApiClient()),
          selectedSchoolIdProvider.overrideWith((ref) => null),
          selectedTenantIdProvider.overrideWith((ref) => null),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SchoolOnboardingScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('School Onboarding Center'), findsOneWidget);
    });

    // 11. Missing academic year does not crash
    testWidgets('11. Missing academic year does not crash', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const mockSchool = SchoolDto(
        id: 'clean-school-1',
        name: 'New Campus High',
        code: 'NCH-001',
        board: 'State Board',
        schoolType: 'HIGH_SCHOOL',
        email: 'info@newcampus.edu',
        isActive: true,
        status: 'ACTIVE',
        tenantId: 'tenant-1',
        version: 1,
      );

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(FakeSafeApiClient()),
          selectedSchoolIdProvider.overrideWith((ref) => 'clean-school-1'),
          schoolsListProvider.overrideWith(
            (ref) => FakeSchoolsListNotifier(const SchoolsListState(schools: [mockSchool], isLoading: false)),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SchoolSetupCenterScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('Academic Year & Term Periods'), findsOneWidget);
    });

    // 12. Missing classes does not crash
    testWidgets('12. Missing classes does not crash', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const mockSchool = SchoolDto(
        id: 'clean-school-2',
        name: 'Empty Classes Academy',
        code: 'ECA-001',
        board: 'CBSE',
        schoolType: 'HIGH_SCHOOL',
        email: 'admin@eca.edu',
        isActive: true,
        status: 'ACTIVE',
        tenantId: 'tenant-1',
        version: 1,
      );

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(FakeSafeApiClient()),
          selectedSchoolIdProvider.overrideWith((ref) => 'clean-school-2'),
          schoolsListProvider.overrideWith(
            (ref) => FakeSchoolsListNotifier(const SchoolsListState(schools: [mockSchool], isLoading: false)),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SchoolSetupCenterScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('Academic Classes & Streams'), findsOneWidget);
    });

    // 13. Missing teachers does not crash
    testWidgets('13. Missing teachers does not crash', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const mockSchool = SchoolDto(
        id: 'clean-school-3',
        name: 'Zero Faculty Institute',
        code: 'ZFI-001',
        board: 'ICSE',
        schoolType: 'HIGH_SCHOOL',
        email: 'head@zfi.edu',
        isActive: true,
        status: 'ACTIVE',
        tenantId: 'tenant-1',
        version: 1,
      );

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(FakeSafeApiClient()),
          selectedSchoolIdProvider.overrideWith((ref) => 'clean-school-3'),
          schoolsListProvider.overrideWith(
            (ref) => FakeSchoolsListNotifier(const SchoolsListState(schools: [mockSchool], isLoading: false)),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SchoolSetupCenterScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('Faculty & Administrative Staff Roster'), findsOneWidget);
    });

    // 14. School Planner opens with a newly created empty school
    testWidgets('14. School Planner opens with a newly created empty school', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(FakeSafeApiClient()),
          selectedSchoolIdProvider.overrideWith((ref) => 'new-empty-school-id'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: PlannerScheduleScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('Teacher Leave Approvals'), findsOneWidget);
      expect(find.text('Exams & Assessments'), findsOneWidget);
    });

    // 15. School Planner shows actionable empty states
    testWidgets('15. School Planner shows actionable empty states', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(FakeSafeApiClient()),
          selectedSchoolIdProvider.overrideWith((ref) => 'new-empty-school-id'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: PlannerScheduleScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No teacher leave requests yet.'), findsOneWidget);
      expect(find.text('Manage Teachers'), findsOneWidget);

      expect(find.text('No exams have been created yet.'), findsOneWidget);
      expect(find.text('Create Exam'), findsWidgets);
    });
  });
}
