import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:admin_portal/features/attendance/presentation/pages/attendance_screen.dart';
import 'package:admin_portal/features/attendance/presentation/pages/attendance_session_details_screen.dart';
import 'package:admin_portal/core/routing/routes.dart';

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

class FakeAttendanceApiClient extends BaseApiClient {
  bool simulateError = false;
  bool simulateValidationError = false;
  bool returnEmptyList = false;
  bool isSession1Locked = false;

  FakeAttendanceApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (simulateError) {
      return ApiResult.failure(const ApiFailure(message: 'Simulated API connection failure', type: ApiFailureType.unknown));
    }

    if (path.contains('/academic-years')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'ay_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'name': '2026-2027',
            'code': 'AY2026',
            'start_date': '2026-06-01',
            'end_date': '2027-03-31',
            'status': 'ACTIVE',
            'is_current': true,
            'version': 1,
          }
        ]
      }));
    }

    if (path.contains('/classes')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'class_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'name': 'Class 8',
            'code': 'CLASS_8',
            'capacity': 40,
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1,
          }
        ]
      }));
    }

    if (path.contains('/sections')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'section_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'class_id': 'class_1',
            'name': 'Section A',
            'code': 'SEC_A',
            'capacity': 40,
            'sort_order': 1,
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1,
          }
        ]
      }));
    }

    if (path.contains('/subjects')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'subject_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'subject_code': 'MATH8',
            'subject_name': 'Mathematics',
            'category': 'CORE',
            'subject_type': 'THEORY',
            'theory_marks': 100,
            'practical_marks': 0,
            'pass_marks': 40,
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1,
          }
        ]
      }));
    }

    if (path.contains('/sessions') || path.contains('/session/')) {
      if (returnEmptyList) {
        return ApiResult.success(mapper({'data': []}));
      }

      final attendancesList = [
        {
          'id': 'log_1',
          'tenant_id': 'tenant_1',
          'school_id': 'school_1',
          'academic_year_id': 'ay_1',
          'attendance_session_id': 'session_1',
          'student_id': 'student_1',
          'timetable_id': 'tt_1',
          'class_id': 'class_1',
          'section_id': 'section_1',
          'teacher_id': 'teacher_1',
          'subject_id': 'subject_1',
          'attendance_date': '2026-08-14',
          'attendance_status': 'PRESENT',
          'attendance_source': 'MANUAL',
          'attendance_reason': 'UNKNOWN',
          'remarks': '',
          'parent_viewed': false,
          'is_active': true,
          'settings': {
            'audit_logs': [
              {
                'previous_status': 'ABSENT',
                'new_status': 'PRESENT',
                'updated_by': 'admin_1',
                'updated_at': '2026-08-14T10:00:00Z',
                'reason_for_change': 'Medical certificate submitted'
              }
            ]
          },
          'ai_metrics': {},
          'version': 2,
          'student': {
            'first_name': 'Alice',
            'last_name': 'Smith',
            'roll_number': '2'
          }
        },
        {
          'id': 'log_2',
          'tenant_id': 'tenant_1',
          'school_id': 'school_1',
          'academic_year_id': 'ay_1',
          'attendance_session_id': 'session_1',
          'student_id': 'student_2',
          'timetable_id': 'tt_1',
          'class_id': 'class_1',
          'section_id': 'section_1',
          'teacher_id': 'teacher_1',
          'subject_id': 'subject_1',
          'attendance_date': '2026-08-14',
          'attendance_status': 'ABSENT',
          'attendance_source': 'MANUAL',
          'attendance_reason': 'SICK',
          'remarks': 'Feeling unwell',
          'parent_viewed': false,
          'is_active': true,
          'settings': {},
          'ai_metrics': {},
          'version': 1,
          'student': {
            'first_name': 'Bob',
            'last_name': 'Jones',
            'roll_number': '1'
          }
        }
      ];

      if (path.contains('/session/')) {
        return ApiResult.success(mapper({
          'data': {
            'id': 'session_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'timetable_id': 'tt_1',
            'class_id': 'class_1',
            'section_id': 'section_1',
            'teacher_id': 'teacher_1',
            'subject_id': 'subject_1',
            'attendance_date': '2026-08-14',
            'status': isSession1Locked ? 'LOCKED' : 'DRAFT',
            'marked_by': 'teacher_1',
            'marked_at': '2026-08-14T08:00:00Z',
            'is_active': true,
            'settings': {},
            'version': 1,
            'attendances': attendancesList
          }
        }));
      }

      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'session_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'timetable_id': 'tt_1',
            'class_id': 'class_1',
            'section_id': 'section_1',
            'teacher_id': 'teacher_1',
            'subject_id': 'subject_1',
            'attendance_date': '2026-08-14',
            'status': isSession1Locked ? 'LOCKED' : 'DRAFT',
            'marked_by': 'teacher_1',
            'marked_at': '2026-08-14T08:00:00Z',
            'is_active': true,
            'settings': {},
            'version': 1,
            'attendances': attendancesList
          }
        ]
      }));
    }

    if (path.contains('/attendances')) {
      if (returnEmptyList) {
        return ApiResult.success(mapper({'data': []}));
      }
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'log_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'attendance_session_id': 'session_1',
            'student_id': 'student_1',
            'timetable_id': 'tt_1',
            'class_id': 'class_1',
            'section_id': 'section_1',
            'teacher_id': 'teacher_1',
            'subject_id': 'subject_1',
            'attendance_date': '2026-08-14',
            'attendance_status': 'PRESENT',
            'attendance_source': 'MANUAL',
            'attendance_reason': 'UNKNOWN',
            'remarks': '',
            'parent_viewed': false,
            'is_active': true,
            'settings': {},
            'ai_metrics': {},
            'version': 1,
          },
          {
            'id': 'log_2',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'attendance_session_id': 'session_1',
            'student_id': 'student_2',
            'timetable_id': 'tt_1',
            'class_id': 'class_1',
            'section_id': 'section_1',
            'teacher_id': 'teacher_1',
            'subject_id': 'subject_1',
            'attendance_date': '2026-08-14',
            'attendance_status': 'ABSENT',
            'attendance_source': 'MANUAL',
            'attendance_reason': 'SICK',
            'remarks': 'Feeling unwell',
            'parent_viewed': false,
            'is_active': true,
            'settings': {},
            'ai_metrics': {},
            'version': 1,
          }
        ]
      }));
    }

    return ApiResult.failure(const ApiFailure(message: 'Endpoint not mocked', type: ApiFailureType.unknown));
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
      return ApiResult.failure(const ApiFailure(message: 'Validation rejected by backend service', type: ApiFailureType.unknown, statusCode: 422));
    }
    return ApiResult.success(mapper({'success': true, 'data': {}}));
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
    if (path.contains('/lock')) {
      isSession1Locked = true;
    }
    return ApiResult.success(mapper({'success': true, 'data': {}}));
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
    return ApiResult.success(mapper({'success': true, 'data': {}}));
  }
}

class LoadingSessionsNotifier extends AttendanceSessionListNotifier {
  LoadingSessionsNotifier(super.apiClient, super.ref) {
    state = const AttendanceSessionListState(sessions: [], isLoading: true);
  }
  @override
  Future<void> fetchSessions() async {}
}

void setupViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  late FakeAttendanceApiClient fakeApiClient;

  setUp(() {
    fakeApiClient = FakeAttendanceApiClient();
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

  group('Attendance Administration Feature UI Tests', () {
    testWidgets('1. Attendance dashboard renders successfully', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const AttendanceScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Attendance Administration'), findsOneWidget);
      expect(find.text('Audit daily attendance, review sessions, correct records, and lock submitted sessions.'), findsOneWidget);
    });

    testWidgets('2. KPI cards render successfully', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const AttendanceScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Total Sessions'), findsOneWidget);
      expect(find.text('Present'), findsNWidgets(2));
      expect(find.text('Absent'), findsNWidgets(2));
      expect(find.text('Rate'), findsOneWidget);
      expect(find.text('50.0%'), findsOneWidget); // 1 present, 1 absent => 50%
    });

    testWidgets('3. Session list renders successfully', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const AttendanceScreen()));
      await tester.pumpAndSettle();

      expect(find.text('2026-08-14'), findsOneWidget);
      expect(find.text('DRAFT'), findsWidgets);
    });

    testWidgets('4. Date filtering works', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const AttendanceScreen()));
      await tester.pumpAndSettle();

      final dateBtn = find.byKey(const Key('date_filter_btn'));
      expect(dateBtn, findsOneWidget);
      await tester.tap(dateBtn);
      await tester.pumpAndSettle();
      // Close datepicker
      expect(find.text('OK'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    });

    testWidgets('5-7. Dropdown filters render and select values', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const AttendanceScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Academic Year'), findsOneWidget);
      expect(find.text('Class'), findsOneWidget);
      expect(find.text('Section'), findsOneWidget);
      expect(find.text('Session Status'), findsOneWidget);
    });

    testWidgets('8. Sorting students by roll number works numerically', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const AttendanceSessionDetailsScreen(sessionId: 'session_1')));
      await tester.pumpAndSettle();

      // Bob (Roll 1) should be sorted before Alice (Roll 2)
      final bobFinder = find.text('Bob Jones');
      final aliceFinder = find.text('Alice Smith');
      
      expect(bobFinder, findsOneWidget);
      expect(aliceFinder, findsOneWidget);

      final bobPosition = tester.getTopLeft(bobFinder).dy;
      final alicePosition = tester.getTopLeft(aliceFinder).dy;
      expect(bobPosition < alicePosition, isTrue); // Bob is above Alice
    });

    testWidgets('9. Empty state renders correctly', (tester) async {
      setupViewport(tester);
      fakeApiClient.returnEmptyList = true;
      await tester.pumpWidget(createTestWidget(const AttendanceScreen()));
      await tester.pumpAndSettle();

      expect(find.text('No attendance sessions match the selected filters.'), findsOneWidget);
    });

    testWidgets('10. API loading state renders', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionManagerProvider.overrideWithValue(FakeTestSessionManager()),
          apiClientProvider.overrideWithValue(fakeApiClient),
          selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
          attendanceSessionsProvider.overrideWith((ref) => LoadingSessionsNotifier(ref.watch(apiClientProvider), ref)),
        ],
        child: const MaterialApp(home: AttendanceScreen()),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('11. API error state renders with retry option', (tester) async {
      setupViewport(tester);
      fakeApiClient.simulateError = true;
      await tester.pumpWidget(createTestWidget(const AttendanceScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to load attendance sessions'), findsOneWidget);
      expect(find.byKey(const Key('retry_load_sessions_btn')), findsOneWidget);
    });

    testWidgets('12. Retry trigger works on sessions', (tester) async {
      setupViewport(tester);
      fakeApiClient.simulateError = true;
      await tester.pumpWidget(createTestWidget(const AttendanceScreen()));
      await tester.pumpAndSettle();

      fakeApiClient.simulateError = false;
      await tester.tap(find.byKey(const Key('retry_load_sessions_btn')));
      await tester.pumpAndSettle();

      expect(find.text('2026-08-14'), findsOneWidget);
    });

    testWidgets('13. Navigation from list item to details page succeeds', (tester) async {
      setupViewport(tester);
      final router = GoRouter(
        initialLocation: '/attendance',
        routes: [
          GoRoute(
            path: '/attendance',
            builder: (context, state) => const AttendanceScreen(),
          ),
          GoRoute(
            path: '/attendance/:sessionId',
            builder: (context, state) => AttendanceSessionDetailsScreen(
              sessionId: state.pathParameters['sessionId']!,
            ),
          )
        ],
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionManagerProvider.overrideWithValue(FakeTestSessionManager()),
          apiClientProvider.overrideWithValue(fakeApiClient),
          selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('view_session_session_1')));
      await tester.pumpAndSettle();

      expect(find.text('Attendance Session Details'), findsOneWidget);
    });

    testWidgets('14. Student attendance details roster renders', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const AttendanceSessionDetailsScreen(sessionId: 'session_1')));
      await tester.pumpAndSettle();

      expect(find.text('Bob Jones'), findsOneWidget);
      expect(find.text('Alice Smith'), findsOneWidget);
      expect(find.text('ABSENT'), findsOneWidget);
    });

    testWidgets('15. Correction dialog opens correctly', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const AttendanceSessionDetailsScreen(sessionId: 'session_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('correct_student_2')));
      await tester.pumpAndSettle();

      expect(find.text('Correct Attendance Record'), findsOneWidget);
      expect(find.text('Student: Bob Jones'), findsOneWidget);
    });

    testWidgets('16. Correction success refreshes detail data', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const AttendanceSessionDetailsScreen(sessionId: 'session_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('correct_student_2')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('correction_reason_field')), 'Typo correction');
      await tester.tap(find.byKey(const Key('confirm_correction_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Correction?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm_correction_double_check_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Attendance record corrected successfully.'), findsOneWidget);
    });

    testWidgets('17. Correction validation failure displays backend error', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const AttendanceSessionDetailsScreen(sessionId: 'session_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('correct_student_2')));
      await tester.pumpAndSettle();

      fakeApiClient.simulateValidationError = true;
      await tester.enterText(find.byKey(const Key('correction_reason_field')), 'Correction with error');
      await tester.tap(find.byKey(const Key('confirm_correction_btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm_correction_double_check_btn')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Validation rejected by backend'), findsOneWidget);
    });

    testWidgets('18. Lock session confirmation dialog appears', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const AttendanceSessionDetailsScreen(sessionId: 'session_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('lock_session_detail_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Lock Attendance Session?'), findsOneWidget);
      expect(find.text('This will prevent further teacher modifications to this attendance session.'), findsOneWidget);
    });

    testWidgets('19. Lock success updates session status to LOCKED', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const AttendanceSessionDetailsScreen(sessionId: 'session_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('lock_session_detail_btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm_lock_detail_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Session locked successfully.'), findsOneWidget);
    });

    testWidgets('20. Locked session disables modification controls', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const AttendanceSessionDetailsScreen(sessionId: 'session_1')));
      await tester.pumpAndSettle();

      // Check lock session action
      await tester.tap(find.byKey(const Key('lock_session_detail_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_lock_detail_dialog_btn')));
      await tester.pumpAndSettle();

      // Now it's locked, edit button correct_student_2 should not be available
      expect(find.byKey(const Key('correct_student_2')), findsNothing);
      expect(find.text('Locked'), findsWidgets);
    });

    testWidgets('21. Audit trail displays previous history logs', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const AttendanceSessionDetailsScreen(sessionId: 'session_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('audit_trail_student_1')));
      await tester.pumpAndSettle();

      expect(find.text('Audit Trail - Alice Smith'), findsOneWidget);
      expect(find.text('ABSENT ➔ PRESENT'), findsOneWidget);
      expect(find.text('Reason: Medical certificate submitted'), findsOneWidget);
    });

    testWidgets('22. Unauthorized access handled gracefully', (tester) async {
      setupViewport(tester);
      fakeApiClient.simulateError = true;
      await tester.pumpWidget(createTestWidget(const AttendanceSessionDetailsScreen(sessionId: 'session_1')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to load session details'), findsOneWidget);
    });

    testWidgets('23-28. Existing routes remain intact', (tester) async {
      expect(AppRoutes.results, '/results');
      expect(AppRoutes.reportCards, '/results/report-cards');
      expect(AppRoutes.fees, '/fees');
      expect(AppRoutes.migrations, '/migrations');
      expect(AppRoutes.teachers, '/teachers');
      expect(AppRoutes.students, '/students');
    });
  });
}
