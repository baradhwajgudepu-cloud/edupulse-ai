import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:admin_portal/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:admin_portal/features/attendance/presentation/widgets/attendance_dashboard_view.dart';
import 'package:admin_portal/features/attendance/presentation/widgets/attendance_register_view.dart';
import 'package:admin_portal/features/attendance/presentation/widgets/attendance_mark_view.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';

class MockInteractiveApiClient implements BaseApiClient {
  final List<String> requestedUrls = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic p1) mapper,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    requestedUrls.add(path);

    if (path.contains('/attendances/sessions')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'sess_1',
            'tenant_id': 'ten_1',
            'school_id': 'sch_1',
            'academic_year_id': 'ay_1',
            'class_id': 'cls_1',
            'section_id': 'sec_1',
            'class_name': 'Grade 10',
            'section_name': 'Section A',
            'attendance_date': '2026-09-11',
            'session_type': 'FULL_DAY',
            'status': 'SUBMITTED',
            'is_active': true,
            'settings': {},
            'version': 1,
            'attendances': [
              for (int i = 1; i <= 80; i++)
                {
                  'id': 'att_p_$i',
                  'student_id': 'stu_$i',
                  'student_name': 'Student $i',
                  'admission_number': 'ADM$i',
                  'class_id': 'cls_1',
                  'section_id': 'sec_1',
                  'attendance_date': '2026-09-11',
                  'attendance_status': 'PRESENT',
                  'session_type': 'FULL_DAY',
                  'attendance_source': 'MANUAL',
                  'attendance_reason': 'UNKNOWN',
                },
              for (int i = 81; i <= 90; i++)
                {
                  'id': 'att_a_$i',
                  'student_id': 'stu_absent_$i',
                  'student_name': 'Absent Student $i',
                  'admission_number': 'ADM$i',
                  'class_id': 'cls_1',
                  'section_id': 'sec_1',
                  'attendance_date': '2026-09-11',
                  'attendance_status': 'ABSENT',
                  'session_type': 'FULL_DAY',
                  'attendance_source': 'MANUAL',
                  'attendance_reason': 'ILLNESS',
                },
              for (int i = 91; i <= 95; i++)
                {
                  'id': 'att_l_$i',
                  'student_id': 'stu_late_$i',
                  'student_name': 'Late Student $i',
                  'admission_number': 'ADM$i',
                  'class_id': 'cls_1',
                  'section_id': 'sec_1',
                  'attendance_date': '2026-09-11',
                  'attendance_status': 'LATE',
                  'session_type': 'FULL_DAY',
                  'attendance_source': 'MANUAL',
                  'attendance_reason': 'TRANSPORT',
                },
              for (int i = 96; i <= 100; i++)
                {
                  'id': 'att_e_$i',
                  'student_id': 'stu_excused_$i',
                  'student_name': 'Excused Student $i',
                  'admission_number': 'ADM$i',
                  'class_id': 'cls_1',
                  'section_id': 'sec_1',
                  'attendance_date': '2026-09-11',
                  'attendance_status': 'EXCUSED',
                  'session_type': 'FULL_DAY',
                  'attendance_source': 'MANUAL',
                  'attendance_reason': 'FAMILY_EMERGENCY',
                },
            ],
          },
          for (int d = 1; d <= 4; d++)
            {
              'id': 'sess_past_$d',
              'tenant_id': 'ten_1',
              'school_id': 'sch_1',
              'academic_year_id': 'ay_1',
              'class_id': 'cls_1',
              'section_id': 'sec_1',
              'class_name': 'Grade 10',
              'section_name': 'Section A',
              'attendance_date': '2026-09-0$d',
              'session_type': 'FULL_DAY',
              'status': 'SUBMITTED',
              'is_active': true,
              'settings': {},
              'version': 1,
              'attendances': [
                {
                  'id': 'att_past_${d}_streak',
                  'student_id': 'stu_absent_81',
                  'student_name': 'Absent Student 81',
                  'admission_number': 'ADM81',
                  'class_id': 'cls_1',
                  'section_id': 'sec_1',
                  'attendance_date': '2026-09-0$d',
                  'attendance_status': 'ABSENT',
                  'session_type': 'FULL_DAY',
                  'attendance_source': 'MANUAL',
                  'attendance_reason': 'ILLNESS',
                },
              ],
            },
        ],
      }));
    }

    if (path.contains('/academic-years')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'ay_1',
            'tenant_id': 'ten_1',
            'school_id': 'sch_1',
            'name': '2026-2027',
            'code': '2026-27',
            'start_date': '2026-06-01',
            'end_date': '2027-05-31',
            'status': 'ACTIVE',
            'is_current': true,
            'version': 1,
          },
        ],
      }));
    }

    if (path.contains('/attendances/daily')) {
      return ApiResult.success(mapper({'data': []}));
    }

    if (path.contains('/classes')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'cls_1',
            'tenant_id': 'ten_1',
            'school_id': 'sch_1',
            'academic_year_id': 'ay_1',
            'name': 'Grade 10',
            'code': 'G10',
            'capacity': 100,
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1,
          },
          {
            'id': 'cls_2',
            'tenant_id': 'ten_1',
            'school_id': 'sch_1',
            'academic_year_id': 'ay_1',
            'name': 'Grade 11',
            'code': 'G11',
            'capacity': 40,
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1,
          },
        ],
      }));
    }

    if (path.contains('/sections')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'sec_1',
            'tenant_id': 'ten_1',
            'school_id': 'sch_1',
            'academic_year_id': 'ay_1',
            'class_id': 'cls_1',
            'name': 'Section A',
            'code': '10A',
            'capacity': 100,
            'sort_order': 1,
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1,
          },
          {
            'id': 'sec_2',
            'tenant_id': 'ten_1',
            'school_id': 'sch_1',
            'academic_year_id': 'ay_1',
            'class_id': 'cls_2',
            'name': 'Section B',
            'code': '11B',
            'capacity': 40,
            'sort_order': 2,
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1,
          },
        ],
      }));
    }

    if (path.contains('/attendances/register')) {
      final uri = Uri.tryParse(path);
      final statusParam = uri?.queryParameters['status'] ?? queryParameters?['status'];
      if (statusParam == 'NON_EXISTENT' || path.contains('status=NON_EXISTENT')) {
        return ApiResult.success(mapper({
          'data': [],
          'meta': {'total': 0},
        }));
      }
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'reg_1',
            'student_id': 'stu_1',
            'student_name': 'Alice Johnson',
            'admission_number': 'ADM001',
            'class_id': 'cls_1',
            'class_name': 'Grade 10',
            'section_id': 'sec_1',
            'section_name': 'Section A',
            'attendance_date': '2026-09-11',
            'attendance_status': 'PRESENT',
            'session_type': 'FULL_DAY',
            'attendance_source': 'MANUAL',
            'attendance_reason': 'UNKNOWN',
          },
          {
            'id': 'reg_2',
            'student_id': 'stu_81',
            'student_name': 'Bob Smith',
            'admission_number': 'ADM081',
            'class_id': 'cls_1',
            'class_name': 'Grade 10',
            'section_id': 'sec_1',
            'section_name': 'Section A',
            'attendance_date': '2026-09-11',
            'attendance_status': 'ABSENT',
            'session_type': 'FULL_DAY',
            'attendance_source': 'MANUAL',
            'attendance_reason': 'ILLNESS',
          },
        ],
        'meta': {'total': 2},
      }));
    }

    return ApiResult.success(mapper({'data': []}));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockInteractiveApiClient mockClient;

  setUp(() {
    mockClient = MockInteractiveApiClient();
  });

  void setDesktopSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('Attendance Dashboard Interactive Command Center Tests', () {
    testWidgets('1. Attendance Rate KPI navigates to Register with monthly date range', (tester) async {
      setDesktopSize(tester);
      String? navStatus;
      DateTime? navStart;
      DateTime? navEnd;

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockClient),
          selectedSchoolIdProvider.overrideWith((ref) => 'sch_1'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(attendanceDashboardProvider.notifier).fetchDashboard(date: DateTime(2026, 9, 11));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AttendanceDashboardView(
                onNavigateToRegister: ({status, date, startDate, endDate, classId, sectionId}) {
                  navStatus = status;
                  navStart = startDate;
                  navEnd = endDate;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rateCard = find.byKey(const Key('kpi_card_attendance_rate'));
      expect(rateCard, findsOneWidget);

      expect(
        tester.getSemantics(rateCard).label,
        contains('View attendance rate register'),
      );

      await tester.tap(rateCard);
      await tester.pumpAndSettle();

      expect(navStatus, isNull, reason: 'Attendance rate register must not filter by status');
      expect(navStart, equals(DateTime(2026, 9, 1)));
      expect(navEnd, equals(DateTime(2026, 9, 30)));
    });

    testWidgets('2. Present Students KPI navigates to Register with status PRESENT and selectedDate', (tester) async {
      setDesktopSize(tester);
      String? navStatus;
      DateTime? navDate;

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockClient),
          selectedSchoolIdProvider.overrideWith((ref) => 'sch_1'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(attendanceDashboardProvider.notifier).fetchDashboard(date: DateTime(2026, 9, 11));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AttendanceDashboardView(
                onNavigateToRegister: ({status, date, startDate, endDate, classId, sectionId}) {
                  navStatus = status;
                  navDate = date;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final presentCard = find.byKey(const Key('kpi_card_present_students'));
      expect(presentCard, findsOneWidget);
      expect(tester.getSemantics(presentCard).label, contains('View present students'));

      await tester.tap(presentCard);
      await tester.pumpAndSettle();

      expect(navStatus, equals('PRESENT'));
      expect(navDate, equals(DateTime(2026, 9, 11)));
    });

    testWidgets('3. Absent KPI navigates to Register with status ABSENT and selectedDate', (tester) async {
      setDesktopSize(tester);
      String? navStatus;
      DateTime? navDate;

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockClient),
          selectedSchoolIdProvider.overrideWith((ref) => 'sch_1'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(attendanceDashboardProvider.notifier).fetchDashboard(date: DateTime(2026, 9, 11));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AttendanceDashboardView(
                onNavigateToRegister: ({status, date, startDate, endDate, classId, sectionId}) {
                  navStatus = status;
                  navDate = date;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final absentCard = find.byKey(const Key('kpi_card_absent'));
      expect(absentCard, findsOneWidget);
      expect(tester.getSemantics(absentCard).label, contains('View absent students'));

      await tester.tap(absentCard);
      await tester.pumpAndSettle();

      expect(navStatus, equals('ABSENT'));
      expect(navDate, equals(DateTime(2026, 9, 11)));
    });

    testWidgets('4. Late Arrivals KPI navigates to Register with status LATE and selectedDate', (tester) async {
      setDesktopSize(tester);
      String? navStatus;
      DateTime? navDate;

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockClient),
          selectedSchoolIdProvider.overrideWith((ref) => 'sch_1'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(attendanceDashboardProvider.notifier).fetchDashboard(date: DateTime(2026, 9, 11));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AttendanceDashboardView(
                onNavigateToRegister: ({status, date, startDate, endDate, classId, sectionId}) {
                  navStatus = status;
                  navDate = date;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final lateCard = find.byKey(const Key('kpi_card_late_arrivals'));
      expect(lateCard, findsOneWidget);
      expect(tester.getSemantics(lateCard).label, contains('View late arrivals'));

      await tester.tap(lateCard);
      await tester.pumpAndSettle();

      expect(navStatus, equals('LATE'));
      expect(navDate, equals(DateTime(2026, 9, 11)));
    });

    testWidgets('5. Excused / Leave KPI navigates to Register with status EXCUSED and selectedDate', (tester) async {
      setDesktopSize(tester);
      String? navStatus;
      DateTime? navDate;

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockClient),
          selectedSchoolIdProvider.overrideWith((ref) => 'sch_1'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(attendanceDashboardProvider.notifier).fetchDashboard(date: DateTime(2026, 9, 11));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AttendanceDashboardView(
                onNavigateToRegister: ({status, date, startDate, endDate, classId, sectionId}) {
                  navStatus = status;
                  navDate = date;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final excusedCard = find.byKey(const Key('kpi_card_excused_leave'));
      expect(excusedCard, findsOneWidget);
      expect(tester.getSemantics(excusedCard).label, contains('View students on leave'));

      await tester.tap(excusedCard);
      await tester.pumpAndSettle();

      expect(navStatus, equals('EXCUSED'));
      expect(navDate, equals(DateTime(2026, 9, 11)));
    });

    testWidgets('6. Classes Marked KPI opens Class Attendance Status modal with direct actions', (tester) async {
      setDesktopSize(tester);
      String? markedClassId;

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockClient),
          selectedSchoolIdProvider.overrideWith((ref) => 'sch_1'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(attendanceDashboardProvider.notifier).fetchDashboard(date: DateTime(2026, 9, 11));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AttendanceDashboardView(
                onNavigateToMark: ({classId, sectionId, date, academicYearId}) {
                  markedClassId = classId;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final classesMarkedCard = find.byKey(const Key('kpi_card_classes_marked'));
      expect(classesMarkedCard, findsOneWidget);
      expect(tester.getSemantics(classesMarkedCard).label, contains('View class attendance status'));

      await tester.tap(classesMarkedCard);
      await tester.pumpAndSettle();

      final dialog = find.byKey(const Key('class_attendance_status_dialog'));
      expect(dialog, findsOneWidget);
      expect(find.text('Class Attendance Status'), findsOneWidget);

      final dialogMarkBtn = find.byKey(const Key('dialog_mark_btn_cls_2'));
      expect(dialogMarkBtn, findsOneWidget);

      await tester.tap(dialogMarkBtn);
      await tester.pumpAndSettle();

      expect(markedClassId, equals('cls_2'));
    });

    testWidgets('7. Unmarked Classes Alert opens Pending Attendance Classes modal with one-click Mark button', (tester) async {
      setDesktopSize(tester);
      String? targetClassId;

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockClient),
          selectedSchoolIdProvider.overrideWith((ref) => 'sch_1'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(attendanceDashboardProvider.notifier).fetchDashboard(date: DateTime(2026, 9, 11));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AttendanceDashboardView(
                onNavigateToMark: ({classId, sectionId, date, academicYearId}) {
                  targetClassId = classId;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final unmarkedAlert = find.byKey(const Key('alert_unmarked_classes'));
      expect(unmarkedAlert, findsOneWidget);
      expect(tester.getSemantics(unmarkedAlert).label, contains('View pending attendance classes'));

      await tester.tap(unmarkedAlert);
      await tester.pumpAndSettle();

      final pendingDialog = find.byKey(const Key('pending_classes_dialog'));
      expect(pendingDialog, findsOneWidget);
      expect(find.text('Pending Attendance Classes'), findsOneWidget);

      final markBtn = find.byKey(const Key('pending_dialog_mark_btn_cls_2'));
      expect(markBtn, findsOneWidget);

      await tester.tap(markBtn);
      await tester.pumpAndSettle();

      expect(targetClassId, equals('cls_2'));
    });

    testWidgets('8. Consecutive Absence Alert navigates to Register with status ABSENT', (tester) async {
      setDesktopSize(tester);
      String? navStatus;

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockClient),
          selectedSchoolIdProvider.overrideWith((ref) => 'sch_1'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(attendanceDashboardProvider.notifier).fetchDashboard(date: DateTime(2026, 9, 11));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AttendanceDashboardView(
                onNavigateToRegister: ({status, date, startDate, endDate, classId, sectionId}) {
                  navStatus = status;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final streakAlert = find.byKey(const Key('alert_consecutive_absence'));
      expect(streakAlert, findsOneWidget);
      expect(tester.getSemantics(streakAlert).label, contains('View consecutive absence records'));

      await tester.tap(streakAlert);
      await tester.pumpAndSettle();

      expect(navStatus, equals('ABSENT'));
    });

    testWidgets('9. 7-Day Trend day card is clickable and navigates to Register with trend date', (tester) async {
      setDesktopSize(tester);
      DateTime? clickedDate;

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockClient),
          selectedSchoolIdProvider.overrideWith((ref) => 'sch_1'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(attendanceDashboardProvider.notifier).fetchDashboard(date: DateTime(2026, 9, 11));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AttendanceDashboardView(
                onNavigateToRegister: ({status, date, startDate, endDate, classId, sectionId}) {
                  clickedDate = date;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dayCard = find.byKey(const Key('trend_day_2026-09-11'));
      expect(dayCard, findsOneWidget);

      await tester.tap(dayCard);
      await tester.pumpAndSettle();

      expect(clickedDate, equals(DateTime(2026, 9, 11)));
    });

    testWidgets('10. Today\'s Class Attendance breakdown displays direct actions for marked and pending classes', (tester) async {
      setDesktopSize(tester);
      String? registerClassId;
      String? markClassId;

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockClient),
          selectedSchoolIdProvider.overrideWith((ref) => 'sch_1'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(attendanceDashboardProvider.notifier).fetchDashboard(date: DateTime(2026, 9, 11));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AttendanceDashboardView(
                onNavigateToRegister: ({status, date, startDate, endDate, classId, sectionId}) {
                  registerClassId = classId;
                },
                onNavigateToMark: ({classId, sectionId, date, academicYearId}) {
                  markClassId = classId;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // cls_1 is marked -> should have "View Register" button
      final regBtn = find.byKey(const Key('class_register_btn_cls_1'));
      expect(regBtn, findsOneWidget);

      await tester.tap(regBtn);
      await tester.pumpAndSettle();
      expect(registerClassId, equals('cls_1'));

      // cls_2 is pending -> should have "Mark Attendance" button
      final markBtn = find.byKey(const Key('class_mark_btn_cls_2'));
      expect(markBtn, findsOneWidget);

      await tester.tap(markBtn);
      await tester.pumpAndSettle();
      expect(markClassId, equals('cls_2'));
    });

    testWidgets('11. AttendanceRegisterView displays Active Filters banner, allows chip deletion, and Clear All', (tester) async {
      setDesktopSize(tester);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockClient),
          selectedSchoolIdProvider.overrideWith((ref) => 'sch_1'),
        ],
      );
      addTearDown(container.dispose);

      container.read(attendanceRegisterProvider.notifier).setFilters(
        status: 'ABSENT',
        startDate: DateTime(2026, 9, 11),
        endDate: DateTime(2026, 9, 11),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: AttendanceRegisterView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('active_filters_banner')), findsOneWidget);
      expect(find.byKey(const Key('filter_chip_status')), findsOneWidget);
      expect(find.byKey(const Key('filter_chip_date')), findsOneWidget);

      final clearAllBtn = find.byKey(const Key('banner_clear_all_btn'));
      expect(clearAllBtn, findsOneWidget);

      await tester.tap(clearAllBtn);
      await tester.pumpAndSettle();

      final state = container.read(attendanceRegisterProvider);
      expect(state.status, isNull);
      expect(state.startDate, isNull);
      expect(state.endDate, isNull);
      expect(find.byKey(const Key('active_filters_banner')), findsNothing);
    });

    testWidgets('12. AttendanceRegisterView has Back to Dashboard button', (tester) async {
      setDesktopSize(tester);
      bool backCalled = false;

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockClient),
          selectedSchoolIdProvider.overrideWith((ref) => 'sch_1'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AttendanceRegisterView(
                onBackToDashboard: () {
                  backCalled = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final backBtn = find.text('Back to Dashboard');
      expect(backBtn, findsOneWidget);

      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      expect(backCalled, isTrue);
    });

    testWidgets('13. AttendanceMarkView has Back to Dashboard button', (tester) async {
      setDesktopSize(tester);
      bool backCalled = false;

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockClient),
          selectedSchoolIdProvider.overrideWith((ref) => 'sch_1'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AttendanceMarkView(
                onBackToDashboard: () {
                  backCalled = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final backBtn = find.text('Back to Dashboard');
      expect(backBtn, findsOneWidget);

      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      expect(backCalled, isTrue);
    });

    testWidgets('14. Filter-aware empty state displays clear filters button which resets filters', (tester) async {
      setDesktopSize(tester);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockClient),
          selectedSchoolIdProvider.overrideWith((ref) => 'sch_1'),
        ],
      );
      addTearDown(container.dispose);

      // Set filter to NON_EXISTENT which returns 0 records in mock
      container.read(attendanceRegisterProvider.notifier).setFilters(
        status: 'NON_EXISTENT',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: AttendanceRegisterView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Try changing the filters or clear all filters.'), findsOneWidget);
      final clearBtn = find.byKey(const Key('empty_state_clear_filters_btn'));
      expect(clearBtn, findsOneWidget);

      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      final state = container.read(attendanceRegisterProvider);
      expect(state.status, isNull);
    });
  });
}
