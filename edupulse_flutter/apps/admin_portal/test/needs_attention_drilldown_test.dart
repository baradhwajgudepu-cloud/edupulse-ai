import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/core/routing/routes.dart';
import 'package:admin_portal/features/students/presentation/pages/students_screen.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/school_setup/data/models/school_setup_models.dart';
import 'package:admin_portal/features/auth/presentation/providers/auth_provider.dart';
import 'package:admin_portal/features/dashboard/presentation/dashboard_screen.dart';
import 'package:admin_portal/features/dashboard/presentation/providers/command_center_provider.dart';

class FakeAuthStateNotifier extends AuthStateNotifier {
  final UserEntity _initialUser;
  FakeAuthStateNotifier(this._initialUser);

  @override
  AuthState build() {
    return Authenticated(_initialUser);
  }
}

class FakeSchoolsListNotifier extends StateNotifier<SchoolsListState> implements SchoolsListNotifier {
  FakeSchoolsListNotifier(super.state);

  @override
  Future<void> fetchSchools() async {}
}

class FakeCommandCenterNotifier extends StateNotifier<CommandCenterMetrics> implements CommandCenterNotifier {
  FakeCommandCenterNotifier(super.state);

  @override
  Future<void> loadDashboard() async {}
}

class MockStudentApiClient extends BaseApiClient {
  final List<Map<String, dynamic>> allMockStudents;
  final List<Map<String, dynamic>> attentionMockStudents;
  int getCallsCount = 0;
  String? lastAttentionParam;
  String? lastSchoolIdParam;

  MockStudentApiClient({
    required this.allMockStudents,
    required this.attentionMockStudents,
  }) : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    getCallsCount++;
    final uri = Uri.parse(path);

    if (path.contains('/academic-years')) {
      return ApiResult.success(mapper({'data': []}));
    } else if (path.contains('/classes')) {
      return ApiResult.success(mapper({'data': []}));
    } else if (path.contains('/sections')) {
      return ApiResult.success(mapper({'data': []}));
    } else if (path.contains('/students')) {
      final attention = uri.queryParameters['attention'] ?? queryParameters?['attention'] ?? uri.queryParameters['filter'];
      final schoolId = uri.queryParameters['school_id'] ?? queryParameters?['school_id'];
      lastAttentionParam = attention;
      lastSchoolIdParam = schoolId;

      if (attention == 'needs_attention') {
        return ApiResult.success(mapper({
          'data': attentionMockStudents,
          'total': attentionMockStudents.length,
          'meta': {'total': attentionMockStudents.length},
        }));
      }

      return ApiResult.success(mapper({
        'data': allMockStudents,
        'total': allMockStudents.length,
        'meta': {'total': allMockStudents.length},
      }));
    }

    return ApiResult.success(mapper({'data': []}));
  }
}

void main() {
  const mockUser = UserEntity(
    id: 'usr-1',
    firstName: 'Principal',
    lastName: 'Sharma',
    email: 'principal@school.edu',
    tenantId: 'ten-1',
    isSuperuser: false,
    roles: ['PRINCIPAL'],
    schools: ['sch-1', 'sch-2'],
    schoolNames: {'sch-1': 'Greenwood High School', 'sch-2': 'Riverside Academy'},
  );

  const mockSchool = SchoolDto(
    id: 'sch-1',
    tenantId: 'ten-1',
    name: 'Greenwood High School',
    code: 'GW01',
    board: 'CBSE',
    schoolType: 'K12',
    email: 'info@greenwood.edu',
    isActive: true,
    status: 'ACTIVE',
    version: 1,
  );

  const mockSchool2 = SchoolDto(
    id: 'sch-2',
    tenantId: 'ten-1',
    name: 'Riverside Academy',
    code: 'RA01',
    board: 'CBSE',
    schoolType: 'K12',
    email: 'info@riverside.edu',
    isActive: true,
    status: 'ACTIVE',
    version: 1,
  );

  final studentRahul = {
    'id': 'stud-1',
    'tenant_id': 'ten-1',
    'school_id': 'sch-1',
    'academic_year_id': 'ay-1',
    'class_id': 'cls-1',
    'section_id': 'sec-1',
    'class_name': 'Class 8',
    'section_name': 'Section A',
    'first_name': 'Rahul',
    'last_name': 'Kumar',
    'gender': 'MALE',
    'date_of_birth': '2012-01-10',
    'admission_number': 'ADM-RK-001',
    'roll_number': '01',
    'admission_date': '2026-04-01',
    'status': 'ACTIVE',
    'is_active': true,
    'ai_metrics': {
      'needs_attention': true,
      'attention_reason': 'Attendance below 75%',
      'attendance_rate': 60.0,
    },
    'version': 1,
    'created_at': '2026-04-01T00:00:00Z',
    'updated_at': '2026-04-01T00:00:00Z',
  };

  final studentAnanya = {
    'id': 'stud-2',
    'tenant_id': 'ten-1',
    'school_id': 'sch-1',
    'academic_year_id': 'ay-1',
    'class_id': 'cls-1',
    'section_id': 'sec-1',
    'class_name': 'Class 8',
    'section_name': 'Section A',
    'first_name': 'Ananya',
    'last_name': 'Reddy',
    'gender': 'FEMALE',
    'date_of_birth': '2012-05-15',
    'admission_number': 'ADM-AR-002',
    'roll_number': '02',
    'admission_date': '2026-04-01',
    'status': 'ACTIVE',
    'is_active': true,
    'ai_metrics': {
      'needs_attention': true,
      'attention_reason': 'Academic trend: 3 consecutive assessment declines',
      'academic_trend': 'DECLINING',
      'consecutive_drops': 3,
    },
    'version': 1,
    'created_at': '2026-04-01T00:00:00Z',
    'updated_at': '2026-04-01T00:00:00Z',
  };

  final studentPriya = {
    'id': 'stud-3',
    'tenant_id': 'ten-1',
    'school_id': 'sch-1',
    'academic_year_id': 'ay-1',
    'class_id': 'cls-1',
    'section_id': 'sec-1',
    'class_name': 'Class 8',
    'section_name': 'Section A',
    'first_name': 'Priya',
    'last_name': 'Sharma',
    'gender': 'FEMALE',
    'date_of_birth': '2012-11-25',
    'admission_number': 'ADM-PS-003',
    'roll_number': '03',
    'admission_date': '2026-04-01',
    'status': 'ACTIVE',
    'is_active': true,
    'ai_metrics': {
      'needs_attention': false,
    },
    'version': 1,
    'created_at': '2026-04-01T00:00:00Z',
    'updated_at': '2026-04-01T00:00:00Z',
  };

  GoRouter createTestRouter(String initialLocation) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: AppRoutes.students,
          builder: (context, state) {
            final initialFilter = state.uri.queryParameters['filter'] ?? state.uri.queryParameters['attention'];
            return StudentsScreen(
              key: ValueKey('students_screen_${initialFilter ?? "all"}'),
              initialFilter: initialFilter,
            );
          },
        ),
        GoRoute(
          path: AppRoutes.dashboard,
          builder: (context, state) => const DashboardScreen(),
        ),
      ],
    );
  }

  group('Needs Attention Student Drill-Down & Lifecycle Tests', () {
    testWidgets('Dashboard alert links to /students?filter=needs_attention', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const mockMetrics = CommandCenterMetrics(
        totalStudents: 360,
        studentAttendancePct: 91.0,
        teachersPresent: 28,
        totalTeachers: 30,
        todayFeeCollection: 50000.0,
        outstandingFees: 20000.0,
        defaultersCount: 5,
        studentsRequiringAttention: 2,
        alerts: [
          NeedsAttentionItem(
            id: 'students_risk',
            title: '2 Students Need Attention',
            subtitle: 'Irregular attendance (<75%) or consecutive academic drops detected.',
            severity: AlertSeverity.warning,
            actionLabel: 'View Students',
            actionRoute: '/students?filter=needs_attention',
            icon: Icons.person_search_outlined,
          ),
        ],
        isLoading: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(() => FakeAuthStateNotifier(mockUser)),
            selectedSchoolIdProvider.overrideWith((ref) => 'sch-1'),
            schoolsListProvider.overrideWith(
              (ref) => FakeSchoolsListNotifier(const SchoolsListState(schools: [mockSchool], isLoading: false)),
            ),
            commandCenterProvider.overrideWith(
              (ref) => FakeCommandCenterNotifier(mockMetrics),
            ),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('2 Students Need Attention'), findsOneWidget);
      expect(find.text('Irregular attendance (<75%) or consecutive academic drops detected.'), findsOneWidget);
      expect(find.text('View Students'), findsOneWidget);

      final alertItem = mockMetrics.alerts.firstWhere((a) => a.id == 'students_risk');
      expect(alertItem.actionRoute, equals('/students?filter=needs_attention'));
    });

    testWidgets('1. /students loads all students and does not display attention banner', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockApi = MockStudentApiClient(
        allMockStudents: [studentRahul, studentAnanya, studentPriya],
        attentionMockStudents: [studentRahul, studentAnanya],
      );

      final router = createTestRouter(AppRoutes.students);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
            authStateProvider.overrideWith(() => FakeAuthStateNotifier(mockUser)),
            selectedSchoolIdProvider.overrideWith((ref) => 'sch-1'),
            schoolsListProvider.overrideWith(
              (ref) => FakeSchoolsListNotifier(const SchoolsListState(schools: [mockSchool], isLoading: false)),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // All 3 students are shown
      expect(find.text('Rahul Kumar'), findsOneWidget);
      expect(find.text('Ananya Reddy'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsOneWidget);

      // Attention banner should NOT be visible
      expect(find.text('Needs Attention (2)'), findsNothing);
      expect(find.text('Clear Filter'), findsNothing);
    });

    testWidgets('2. /students?filter=needs_attention loads only attention students', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockApi = MockStudentApiClient(
        allMockStudents: [studentRahul, studentAnanya, studentPriya],
        attentionMockStudents: [studentRahul, studentAnanya],
      );

      final router = createTestRouter('${AppRoutes.students}?filter=needs_attention');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
            authStateProvider.overrideWith(() => FakeAuthStateNotifier(mockUser)),
            selectedSchoolIdProvider.overrideWith((ref) => 'sch-1'),
            schoolsListProvider.overrideWith(
              (ref) => FakeSchoolsListNotifier(const SchoolsListState(schools: [mockSchool], isLoading: false)),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Banner is active
      expect(find.text('Needs Attention (2)'), findsOneWidget);
      expect(find.text('Clear Filter'), findsOneWidget);

      // Only the 2 qualifying students appear
      expect(find.text('Rahul Kumar'), findsOneWidget);
      expect(find.text('Ananya Reddy'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsNothing);

      // Attention details
      expect(find.text('⚠ Needs Attention'), findsNWidgets(2));
      expect(find.text('Reason: Attendance below 75%'), findsOneWidget);
      expect(find.text('Reason: Academic trend: 3 consecutive assessment declines'), findsOneWidget);
    });

    testWidgets('3. Navigating from filtered Students to /students clears filter', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockApi = MockStudentApiClient(
        allMockStudents: [studentRahul, studentAnanya, studentPriya],
        attentionMockStudents: [studentRahul, studentAnanya],
      );

      final router = createTestRouter('${AppRoutes.students}?filter=needs_attention');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
            authStateProvider.overrideWith(() => FakeAuthStateNotifier(mockUser)),
            selectedSchoolIdProvider.overrideWith((ref) => 'sch-1'),
            schoolsListProvider.overrideWith(
              (ref) => FakeSchoolsListNotifier(const SchoolsListState(schools: [mockSchool], isLoading: false)),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Needs Attention (2)'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsNothing);

      // Simulate navigating to /students (e.g. sidebar navigation)
      router.go(AppRoutes.students);
      await tester.pumpAndSettle();

      // Filter is gone, all students are visible
      expect(find.text('Needs Attention (2)'), findsNothing);
      expect(find.text('Clear Filter'), findsNothing);
      expect(find.text('Rahul Kumar'), findsOneWidget);
      expect(find.text('Ananya Reddy'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsOneWidget);
    });

    testWidgets('4 & 5. Clear Filter removes query parameter and reloads all students', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockApi = MockStudentApiClient(
        allMockStudents: [studentRahul, studentAnanya, studentPriya],
        attentionMockStudents: [studentRahul, studentAnanya],
      );

      final router = createTestRouter('${AppRoutes.students}?filter=needs_attention');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
            authStateProvider.overrideWith(() => FakeAuthStateNotifier(mockUser)),
            selectedSchoolIdProvider.overrideWith((ref) => 'sch-1'),
            schoolsListProvider.overrideWith(
              (ref) => FakeSchoolsListNotifier(const SchoolsListState(schools: [mockSchool], isLoading: false)),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(router.state.uri.queryParameters['filter'], equals('needs_attention'));

      // Tap Clear Filter
      final clearButton = find.text('Clear Filter');
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      // 4. Query param removed
      expect(router.state.uri.path, equals(AppRoutes.students));
      expect(router.state.uri.queryParameters['filter'], isNull);

      // 5. Reloads all students
      expect(find.text('Needs Attention (2)'), findsNothing);
      expect(find.text('Rahul Kumar'), findsOneWidget);
      expect(find.text('Ananya Reddy'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsOneWidget);
    });

    testWidgets('6 & 7. Browser Back restores unfiltered state and Forward restores filtered state', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockApi = MockStudentApiClient(
        allMockStudents: [studentRahul, studentAnanya, studentPriya],
        attentionMockStudents: [studentRahul, studentAnanya],
      );

      final router = createTestRouter(AppRoutes.students);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
            authStateProvider.overrideWith(() => FakeAuthStateNotifier(mockUser)),
            selectedSchoolIdProvider.overrideWith((ref) => 'sch-1'),
            schoolsListProvider.overrideWith(
              (ref) => FakeSchoolsListNotifier(const SchoolsListState(schools: [mockSchool], isLoading: false)),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Priya Sharma'), findsOneWidget);

      // Navigate to filtered drill-down
      router.go('${AppRoutes.students}?filter=needs_attention');
      await tester.pumpAndSettle();
      expect(find.text('Needs Attention (2)'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsNothing);

      // Simulate Browser Back: URL returns to /students
      router.go(AppRoutes.students);
      await tester.pumpAndSettle();
      expect(find.text('Needs Attention (2)'), findsNothing);
      expect(find.text('Priya Sharma'), findsOneWidget);

      // Simulate Browser Forward: URL returns to /students?filter=needs_attention
      router.go('${AppRoutes.students}?filter=needs_attention');
      await tester.pumpAndSettle();
      expect(find.text('Needs Attention (2)'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsNothing);
    });

    testWidgets('8. Sidebar Students navigation always opens unfiltered directory', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockApi = MockStudentApiClient(
        allMockStudents: [studentRahul, studentAnanya, studentPriya],
        attentionMockStudents: [studentRahul, studentAnanya],
      );

      final router = createTestRouter('${AppRoutes.students}?filter=needs_attention');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
            authStateProvider.overrideWith(() => FakeAuthStateNotifier(mockUser)),
            selectedSchoolIdProvider.overrideWith((ref) => 'sch-1'),
            schoolsListProvider.overrideWith(
              (ref) => FakeSchoolsListNotifier(const SchoolsListState(schools: [mockSchool], isLoading: false)),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Needs Attention (2)'), findsOneWidget);

      // Clicking sidebar Students triggers context.go(AppRoutes.students)
      router.go(AppRoutes.students);
      await tester.pumpAndSettle();

      expect(router.state.uri.toString(), equals('/students'));
      expect(find.text('Needs Attention (2)'), findsNothing);
      expect(find.text('Priya Sharma'), findsOneWidget);
    });

    testWidgets('9. School switching clears stale filter state', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockApi = MockStudentApiClient(
        allMockStudents: [studentRahul, studentAnanya, studentPriya],
        attentionMockStudents: [studentRahul, studentAnanya],
      );

      late StateController<String?> schoolController;

      final router = createTestRouter(AppRoutes.students);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
            authStateProvider.overrideWith(() => FakeAuthStateNotifier(mockUser)),
            selectedSchoolIdProvider.overrideWith((ref) => 'sch-1'),
            schoolsListProvider.overrideWith(
              (ref) => FakeSchoolsListNotifier(
                const SchoolsListState(schools: [mockSchool, mockSchool2], isLoading: false),
              ),
            ),
          ],
          child: Consumer(
            builder: (context, ref, child) {
              schoolController = ref.watch(selectedSchoolIdProvider.notifier);
              return MaterialApp.router(
                routerConfig: router,
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(mockApi.lastSchoolIdParam, equals('sch-1'));

      // Switch school to sch-2
      schoolController.state = 'sch-2';
      await tester.pumpAndSettle();

      expect(mockApi.lastSchoolIdParam, equals('sch-2'));
      // Stale attention filter was not applied
      expect(mockApi.lastAttentionParam, isNull);
    });

    testWidgets('10. Filter count matches backend total', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockApi = MockStudentApiClient(
        allMockStudents: [studentRahul, studentAnanya, studentPriya],
        attentionMockStudents: [studentRahul, studentAnanya],
      );

      final router = createTestRouter('${AppRoutes.students}?filter=needs_attention');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
            authStateProvider.overrideWith(() => FakeAuthStateNotifier(mockUser)),
            selectedSchoolIdProvider.overrideWith((ref) => 'sch-1'),
            schoolsListProvider.overrideWith(
              (ref) => FakeSchoolsListNotifier(const SchoolsListState(schools: [mockSchool], isLoading: false)),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify chip displays exact count from backend (2)
      expect(find.text('Needs Attention (2)'), findsOneWidget);
    });

    testWidgets('StudentsScreen renders empty state when 0 students require attention', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockApi = MockStudentApiClient(
        allMockStudents: [studentPriya],
        attentionMockStudents: [],
      );

      final router = createTestRouter('${AppRoutes.students}?filter=needs_attention');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
            authStateProvider.overrideWith(() => FakeAuthStateNotifier(mockUser)),
            selectedSchoolIdProvider.overrideWith((ref) => 'sch-1'),
            schoolsListProvider.overrideWith(
              (ref) => FakeSchoolsListNotifier(const SchoolsListState(schools: [mockSchool], isLoading: false)),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Empty state text
      expect(find.text('No students currently require attention.'), findsOneWidget);
      expect(find.text('All active students currently meet attendance thresholds (>75%) and maintain consistent academic performance.'), findsOneWidget);

      // Clear Filter in empty state
      final clearButtons = find.text('Clear Filter');
      expect(clearButtons, findsWidgets);
      await tester.tap(clearButtons.last);
      await tester.pumpAndSettle();

      // Displays all students
      expect(find.text('Priya Sharma'), findsOneWidget);
      expect(find.text('No students currently require attention.'), findsNothing);
    });
  });
}
