import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/core/routing/routes.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/results/presentation/pages/results_dashboard_screen.dart';
import 'package:admin_portal/features/results/presentation/pages/admin_marks_management_screen.dart';
import 'package:admin_portal/features/results/data/models/admin_marks_models.dart';
import 'package:admin_portal/features/results/presentation/providers/admin_marks_providers.dart';
import 'package:admin_portal/features/shell/presentation/admin_shell.dart';
import 'package:admin_portal/features/auth/presentation/providers/auth_provider.dart';

class FakeExamsSessionManager implements SessionManager {
  String? cachedTenantId = 'tenant_1';
  String? cachedSchoolId = 'school_1';

  @override
  Future<String?> getTenantId() async => cachedTenantId;
  @override
  Future<void> saveTenantId(String tenantId) async => cachedTenantId = tenantId;
  @override
  Future<String?> getTenantName() async => 'Mock Tenant';
  @override
  Future<void> saveTenantName(String tenantName) async {}
  @override
  Future<String?> getSchoolName() async => 'Mock School';
  @override
  Future<void> saveSchoolName(String schoolName) async {}
  @override
  Future<String?> getAccessToken() async => 'mock_access';
  @override
  Future<String?> getRefreshToken() async => 'mock_refresh';
  @override
  Future<void> saveSession(SessionToken token) async {}
  @override
  Future<void> clearSession([String source = 'SessionManager.clearSession']) async {}
  @override
  Future<bool> hasSession() async => true;
  @override
  Future<String?> getSchoolId() async => cachedSchoolId;
  @override
  Future<void> saveSchoolId(String schoolId) async => cachedSchoolId = schoolId;
}

class FakeExamsApiClient extends BaseApiClient {
  FakeExamsApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (path.contains('/academic-years')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'ay_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'name': '2026-2027',
            'code': 'AY2026',
            'description': 'Academic Year 2026-2027',
            'start_date': '2026-06-01',
            'end_date': '2027-04-30',
            'status': 'ACTIVE',
            'is_current': true,
            'is_active': true,
            'version': 1,
            'created_at': '2026-06-01T00:00:00Z',
            'updated_at': '2026-06-01T00:00:00Z',
          }
        ]
      }));
    } else if (path.contains('/schools')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'school_1',
            'tenant_id': 'tenant_1',
            'name': 'Delhi Public School',
            'code': 'DPS001',
            'board': 'CBSE',
            'school_type': 'HIGH_SCHOOL',
            'email': 'dps@school.edu',
            'is_active': true,
            'status': 'ACTIVE',
            'version': 1,
          }
        ]
      }));
    } else if (path.contains('/classes')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'cls_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'name': 'Class 8',
            'numeric_grade': 8,
            'code': 'CLS8',
            'description': 'Standard 8',
            'stream': 'GENERAL',
            'is_active': true,
            'version': 1,
            'created_at': '2026-06-01T00:00:00Z',
            'updated_at': '2026-06-01T00:00:00Z',
          }
        ]
      }));
    } else if (path.contains('/sections')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'sec_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'class_id': 'cls_1',
            'name': 'Section A',
            'code': 'SEC8A',
            'room_number': '101',
            'max_capacity': 40,
            'is_active': true,
            'version': 1,
            'created_at': '2026-06-01T00:00:00Z',
            'updated_at': '2026-06-01T00:00:00Z',
          }
        ]
      }));
    } else if (path.contains('/examinations')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'exam_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'exam_name': 'Midterm Examination',
            'exam_type': 'MIDTERM',
            'term': 'TERM_1',
            'start_date': '2026-09-01',
            'end_date': '2026-09-15',
            'is_published': true,
            'is_active': true,
            'created_at': '2026-08-01T00:00:00Z',
            'updated_at': '2026-08-01T00:00:00Z',
          }
        ]
      }));
    } else if (path.contains('/students')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'st_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'first_name': 'Aarav',
            'last_name': 'Sharma',
            'admission_number': 'ADM001',
            'roll_number': '1',
            'class_id': 'cls_1',
            'section_id': 'sec_1',
            'status': 'ACTIVE',
            'is_active': true,
            'created_at': '2026-06-01T00:00:00Z',
            'updated_at': '2026-06-01T00:00:00Z',
          }
        ]
      }));
    } else if (path.contains('/report-cards')) {
      return ApiResult.success(mapper({'data': []}));
    } else if (path.contains('/marks/wizard/entry')) {
      return ApiResult.success(mapper({
        'data': {
          'entries': [
            {
              'student': {
                'id': 'st_1',
                'first_name': 'Aarav',
                'last_name': 'Sharma',
                'roll_number': '1',
              },
              'mark_record': {
                'marks_obtained': 85.0,
                'result_status': 'PRESENT',
                'status': 'DRAFT',
              },
            }
          ]
        }
      }));
    }
    return ApiResult.success(mapper({'data': []}));
  }
}

class FakeAuthStateNotifier extends AuthStateNotifier {
  final UserEntity _mockUser;
  FakeAuthStateNotifier(this._mockUser);

  @override
  AuthState build() {
    return Authenticated(_mockUser);
  }
}

void main() {
  late FakeExamsApiClient fakeApiClient;
  late FakeExamsSessionManager fakeSessionManager;

  setUp(() {
    fakeApiClient = FakeExamsApiClient();
    fakeSessionManager = FakeExamsSessionManager();
  });

  void setScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('Exams & Assessments Navigation & Action Hub Suite', () {
    testWidgets('1. AdminShell displays "Exams & Assessments" sidebar item with proper icon and key', (tester) async {
      setScreenSize(tester);

      const authUser = UserEntity(
        id: 'u-1',
        email: 'admin@school.org',
        firstName: 'Admin',
        lastName: 'User',
        tenantId: 'tenant-1',
        isSuperuser: false,
        roles: ['ADMIN'],
        schools: ['school_1'],
      );

      final router = GoRouter(
        initialLocation: AppRoutes.dashboard,
        routes: [
          ShellRoute(
            builder: (context, state, child) => AdminShell(child: child),
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (context, state) => const Scaffold(body: Text('Dashboard Content')),
              ),
              GoRoute(
                path: AppRoutes.results,
                builder: (context, state) => const Scaffold(body: Text('Results Content')),
              ),
            ],
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(fakeApiClient),
          sessionManagerProvider.overrideWithValue(fakeSessionManager),
          authStateProvider.overrideWith(() => FakeAuthStateNotifier(authUser)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Exams & Assessments sidebar nav item
      final examsNavItem = find.byKey(const Key('sidebar_nav_exams_assessments'));
      expect(examsNavItem, findsOneWidget);
      expect(find.text('Exams & Assessments'), findsOneWidget);

      // Verify correct exam icon
      expect(
        find.descendant(of: examsNavItem, matching: find.byIcon(Icons.assignment_turned_in_outlined)),
        findsOneWidget,
      );
    });

    testWidgets('2. Results Dashboard renders AppBar action buttons and 6 Operations Hub cards', (tester) async {
      setScreenSize(tester);

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(fakeApiClient),
          sessionManagerProvider.overrideWithValue(fakeSessionManager),
        ],
      );
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

      await container.read(academicYearsProvider('school_1').notifier).fetchYears();
      await container.read(classesProvider('school_1').notifier).fetchClasses();
      await container.read(sectionsProvider('school_1').notifier).fetchSections();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ResultsDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify AppBar Title & Subtitle
      expect(find.text('Exams & Assessments Dashboard'), findsOneWidget);
      expect(find.text('Results & Report Cards'), findsOneWidget);

      // Verify Header Action Buttons
      expect(find.byKey(const Key('header_create_exam_btn')), findsOneWidget);
      expect(find.text('Create Examination'), findsOneWidget);

      expect(find.byKey(const Key('header_import_marks_btn')), findsOneWidget);
      expect(find.text('Import Marks'), findsNWidgets(2)); // in header + operations hub

      expect(find.byKey(const Key('header_manage_marks_btn')), findsOneWidget);
      expect(find.text('Manage Marks'), findsNWidgets(2)); // in header + operations hub

      // Verify Operations Hub section header
      expect(find.text('Exams & Assessments Hub'), findsOneWidget);

      // Verify all 6 Hub action cards
      expect(find.byKey(const Key('hub_create_examination_action')), findsOneWidget);
      expect(find.text('+ Create Examination'), findsOneWidget);

      expect(find.byKey(const Key('hub_import_marks_action')), findsOneWidget);
      expect(find.text('9-Step Ingestion Wizard'), findsOneWidget);

      expect(find.byKey(const Key('hub_manage_marks_action')), findsOneWidget);
      expect(find.text('Scores, Entry & Overrides'), findsOneWidget);

      expect(find.byKey(const Key('hub_syllabus_action')), findsOneWidget);
      expect(find.text('Syllabus & Coverage'), findsOneWidget);

      expect(find.byKey(const Key('hub_question_mapping_action')), findsOneWidget);
      expect(find.text('Question / Chapter Mapping'), findsOneWidget);

      expect(find.byKey(const Key('hub_academic_analytics_action')), findsOneWidget);
      expect(find.text('Academic Analytics'), findsOneWidget);
    });

    testWidgets('3. Marks Management Screen exposes Import Marks in AppBar, Empty State, and Toolbar', (tester) async {
      setScreenSize(tester);

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(fakeApiClient),
          sessionManagerProvider.overrideWithValue(fakeSessionManager),
        ],
      );
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AdminMarksManagementScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. AppBar Header action is always present
      expect(find.byKey(const Key('header_import_marks_board_btn')), findsOneWidget);

      // 2. Empty state prompt button is present before schedule selection
      expect(find.byKey(const Key('empty_state_import_marks_btn')), findsOneWidget);
      expect(find.text('Import Marks via 9-Step Wizard'), findsOneWidget);

      // 3. When a schedule is active on the board, Action Toolbar button appears
      const schedule = AdminExamScheduleOption(
        id: 'sched_1',
        examId: 'exam_1',
        examName: 'Midterm',
        classId: 'cls_1',
        className: 'Class 8',
        subjectId: 'sub_1',
        subjectName: 'Mathematics',
        subjectCode: 'MTH101',
        maxMarks: 100,
        passMarks: 35,
      );

      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      await container.read(adminMarksBoardProvider.notifier).loadMarksForSchedule(schedule);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('toolbar_import_marks_board_btn')), findsOneWidget);
      expect(find.text('Import Marks (Wizard)'), findsOneWidget);
    });
  });
}
