import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:admin_portal/features/planner/presentation/pages/planner_calendar_screen.dart';
import 'package:admin_portal/features/planner/presentation/pages/planner_schedule_screen.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';

class FakeCalendarRecoveryApiClient extends BaseApiClient {
  final bool isStateVerified;
  final int affectedPeriods;

  FakeCalendarRecoveryApiClient({
    this.isStateVerified = true,
    this.affectedPeriods = 4,
  }) : super(Dio());

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
            'id': 'ay-2026-27',
            'tenant_id': 'tenant-1',
            'school_id': 'school-123',
            'name': '2026-2027',
            'code': 'AY2026-2027',
            'start_date': '2026-06-01',
            'end_date': '2027-04-30',
            'status': 'ACTIVE',
            'is_current': true,
            'terms_count': 2,
          }
        ]
      }));
    }

    if (path.contains('/calendar/feed')) {
      final nowStr = DateTime.now().toIso8601String().substring(0, 10);
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'cal-event-1',
            'type': 'PUBLIC_HOLIDAY',
            'title': 'Telangana Formation Day',
            'description': 'State Public Holiday',
            'date': nowStr,
            'start_time': '00:00:00',
            'end_time': '23:59:59',
            'extra_data': {
              'source': 'Government of Telangana G.O.Rt.No. 2026/GAD',
              'source_reference': 'G.O.Rt.No. 2026/V1',
              'is_holiday': true,
              'is_non_working_day': true,
              'event_type': 'PUBLIC_HOLIDAY',
            },
          },
          {
            'id': 'cal-event-2',
            'type': 'EXAMINATION',
            'title': 'Midterm Mathematics Exam',
            'description': 'Grade 10 Assessment',
            'date': nowStr,
            'start_time': '09:00:00',
            'end_time': '12:00:00',
            'extra_data': {'status': 'SCHEDULED'},
          },
        ]
      }));
    }

    if (path.contains('/calendar/holidays/state/status')) {
      if (isStateVerified) {
        return ApiResult.success(mapper({
          'data': {
            'state': 'TELANGANA',
            'academic_year_code': '2026-2027',
            'is_verified': true,
            'source': 'Government of Telangana G.A. (Spl.E) Dept G.O.Rt.No. 2026/GAD',
            'source_version': 'G.O.Rt.No. 2026/V1',
            'holidays_count': 16,
            'message': 'Verified public holiday calendar found from Government of Telangana.',
            'can_import': false,
          }
        }));
      } else {
        return ApiResult.success(mapper({
          'data': {
            'state': 'SIKKIM',
            'academic_year_code': '2026-2027',
            'is_verified': false,
            'source': null,
            'source_version': null,
            'holidays_count': 0,
            'message': 'Public holiday calendar could not be verified.',
            'can_import': true,
          }
        }));
      }
    }

    if (path.contains('/academic-planning/holiday-impact')) {
      return ApiResult.success(mapper({
        'data': {
          'holiday_date': '2026-06-02',
          'holiday_title': 'Telangana Formation Day',
          'holiday_type': 'PUBLIC_HOLIDAY',
          'affected_periods_count': affectedPeriods,
          'affected_sections_count': affectedPeriods > 0 ? 2 : 0,
          'affected_teachers_count': affectedPeriods > 0 ? 2 : 0,
          'syllabus_risks_count': affectedPeriods > 0 ? 1 : 0,
          'syllabus_risk_details': affectedPeriods > 0 ? ['Mathematics Class 5A may miss syllabus deadline before Midterm'] : [],
        }
      }));
    }

    if (path.contains('/academic-planning/summary')) {
      return ApiResult.success(mapper({
        'data': {
          'school_wide_completion_pct': 78.5,
          'at_risk_count': 1,
          'likely_to_miss_count': 0,
          'ahead_of_schedule_count': 4,
          'total_subjects_tracked': 6,
          'adaptive_recommendations': [],
        }
      }));
    }

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
    if (path.contains('/academic-planning/holiday-recovery/generate')) {
      return ApiResult.success(mapper({
        'data': {
          'recovery_id': 'rec-12345',
          'holiday_event_id': 'cal-event-1',
          'holiday_date': '2026-06-02',
          'holiday_title': 'Telangana Formation Day',
          'total_slots_affected': 4,
          'total_slots_recovered': 4,
          'unrecovered_slots': 0,
          'summary': 'Minimum-Disruption Engine: 4 periods successfully rebalanced without secondary conflicts.',
          'status': 'PENDING_APPROVAL',
          'changes': [
            {
              'original_timetable_id': 'tt-1',
              'class_id': 'cls-1',
              'section_id': 'sec-1',
              'class_name': 'Class 5',
              'section_name': 'A',
              'teacher_id': 't-1',
              'teacher_name': 'Radha Sharma',
              'subject_id': 'sub-1',
              'subject_name': 'Mathematics',
              'original_day': 'TUESDAY',
              'original_period_number': 2,
              'target_day': 'WEDNESDAY',
              'target_period_number': 5,
              'target_date': '2026-06-03',
              'action': 'MOVE_SLOT',
              'reason': 'Moved to free period on Wednesday P5'
            },
            {
              'original_timetable_id': 'tt-2',
              'class_id': 'cls-1',
              'section_id': 'sec-2',
              'class_name': 'Class 5',
              'section_name': 'B',
              'teacher_id': 't-2',
              'teacher_name': 'Curie Patel',
              'subject_id': 'sub-2',
              'subject_name': 'Science',
              'original_day': 'TUESDAY',
              'original_period_number': 3,
              'target_day': 'THURSDAY',
              'target_period_number': 6,
              'target_date': '2026-06-04',
              'action': 'MOVE_SLOT',
              'reason': 'Moved to free period on Thursday P6'
            },
          ]
        }
      }));
    }

    if (path.contains('/calendar/holidays/principal-declare')) {
      return ApiResult.success(mapper({
        'data': {'id': 'declared-holiday-1', 'title': 'Declared Holiday'}
      }));
    }

    if (path.contains('/calendar/holidays/state/populate')) {
      return ApiResult.success(mapper({
        'data': {'count': 16, 'success': true}
      }));
    }

    if (path.contains('/apply')) {
      return ApiResult.success(mapper({'data': {'status': 'APPLIED'}}));
    }

    return ApiResult.success(mapper({'data': {}}));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Intelligent Academic Calendar Widget Tests', () {
    testWidgets('Test 1: Calendar Screen renders header, AY badge, view switcher and category filter chips', (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(FakeCalendarRecoveryApiClient(isStateVerified: true)),
            selectedSchoolIdProvider.overrideWith((ref) => 'school-123'),
          ],
          child: MaterialApp(
            theme: EduPulseTheme.lightTheme,
            home: const PlannerCalendarScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Header & Title
      expect(find.text('Academic Calendar & Holiday Operations'), findsOneWidget);
      expect(find.text('AY 2026-2027'), findsOneWidget);

      // 2. View Mode Switcher
      expect(find.text('Month'), findsOneWidget);
      expect(find.text('Week'), findsOneWidget);
      expect(find.text('Day'), findsOneWidget);

      // 3. Category Filter Chips
      expect(find.text('All Events'), findsOneWidget);
      expect(find.text('Public Holiday'), findsWidgets);
      expect(find.text('School Holiday'), findsOneWidget);
      expect(find.text('Principal Declared'), findsOneWidget);
      expect(find.text('Examination'), findsWidgets);
      expect(find.text('School Event'), findsOneWidget);
      expect(find.text('Timetable Change'), findsOneWidget);
    });

    testWidgets('Test 2: Calendar Screen displays Verified State Gazette banner with G.O. details and Sync action', (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(FakeCalendarRecoveryApiClient(isStateVerified: true)),
            selectedSchoolIdProvider.overrideWith((ref) => 'school-123'),
          ],
          child: MaterialApp(
            theme: EduPulseTheme.lightTheme,
            home: const PlannerCalendarScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verified State Gazette Master Banner
      expect(find.text('Verified State Gazette Master: '), findsOneWidget);
      expect(find.text('TELANGANA (G.O.Rt.No. 2026/V1)'), findsOneWidget);
      expect(find.text('16 Public Holidays'), findsOneWidget);
      expect(find.text('Sync State Holidays'), findsOneWidget);
    });

    testWidgets('Test 3: Calendar Screen displays Unverified State Gazette fallback banner when verification fails', (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(FakeCalendarRecoveryApiClient(isStateVerified: false)),
            selectedSchoolIdProvider.overrideWith((ref) => 'school-123'),
          ],
          child: MaterialApp(
            theme: EduPulseTheme.lightTheme,
            home: const PlannerCalendarScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Unverified State Gazette Banner
      expect(
        find.text('Public holiday calendar could not be verified. Gazette master required before state holidays can be imported.'),
        findsOneWidget,
      );
      expect(find.text('Import Manual'), findsOneWidget);
    });

    testWidgets('Test 4: Calendar Screen opens Declare Principal Holiday dialog with title, date, and toggle', (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(FakeCalendarRecoveryApiClient(isStateVerified: true)),
            selectedSchoolIdProvider.overrideWith((ref) => 'school-123'),
          ],
          child: MaterialApp(
            theme: EduPulseTheme.lightTheme,
            home: const PlannerCalendarScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Click "Declare Holiday" button in top-right header
      final declareBtn = find.text('Declare Holiday');
      expect(declareBtn, findsOneWidget);
      await tester.tap(declareBtn);
      await tester.pumpAndSettle();

      // Verify Modal Dialog contents
      expect(find.text('Declare Principal Holiday'), findsOneWidget);
      expect(find.text('Holiday Date'), findsOneWidget);
      expect(find.text('Holiday Title *'), findsOneWidget);
      expect(find.text('Reason / Remarks'), findsOneWidget);
      expect(find.text('Designate as Non-Working Day'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Test 5: Calendar Agenda card displays holiday event with Non-working day badge and AI Rebalance button', (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(FakeCalendarRecoveryApiClient(isStateVerified: true)),
            selectedSchoolIdProvider.overrideWith((ref) => 'school-123'),
          ],
          child: MaterialApp(
            theme: EduPulseTheme.lightTheme,
            home: const PlannerCalendarScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Operational Agenda
      expect(find.text('Operational Agenda'), findsOneWidget);
      expect(find.text('Telangana Formation Day'), findsOneWidget);
      expect(find.text('State Public Holiday'), findsOneWidget);
      expect(find.text('Analyze Timetable Impact & AI Rebalance'), findsOneWidget);
    });
  });

  group('AI Timetable Recovery Center & Dialog Tests', () {
    testWidgets('Test 6: Planner Schedule Screen renders AI Timetable Recovery Center with Zero-Cascade Policy badge', (tester) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(FakeCalendarRecoveryApiClient(isStateVerified: true)),
            selectedSchoolIdProvider.overrideWith((ref) => 'school-123'),
            selectedSchoolNameProvider.overrideWithValue('Telangana Model School'),
          ],
          child: MaterialApp(
            theme: EduPulseTheme.lightTheme,
            home: const PlannerScheduleScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify AI Timetable Recovery Center Card
      expect(find.text('AI Timetable Recovery Center'), findsOneWidget);
      expect(find.text('Zero-Cascade Policy Active'), findsOneWidget);
      expect(find.text('Declare Principal Holiday'), findsOneWidget);
      expect(find.text('Review Holiday Impact & AI Recovery'), findsOneWidget);
    });

    testWidgets('Test 7: Holiday Impact Dialog renders metrics and risk evaluation', (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(FakeCalendarRecoveryApiClient(isStateVerified: true, affectedPeriods: 4)),
            selectedSchoolIdProvider.overrideWith((ref) => 'school-123'),
          ],
          child: MaterialApp(
            theme: EduPulseTheme.lightTheme,
            home: const PlannerCalendarScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open impact dialog from agenda
      final rebalanceBtn = find.text('Analyze Timetable Impact & AI Rebalance');
      expect(rebalanceBtn, findsOneWidget);
      await tester.tap(rebalanceBtn);
      await tester.pumpAndSettle();

      // Verify Impact metrics
      expect(find.text('AI Timetable Impact & Recovery Center'), findsOneWidget);
      expect(find.text('Periods Affected'), findsOneWidget);
      expect(find.text('4'), findsWidgets);
      expect(find.text('Sections Affected'), findsOneWidget);
      expect(find.text('Teachers Impacted'), findsOneWidget);
      expect(find.text('Syllabus Risks'), findsOneWidget);
      expect(find.text('Syllabus Completion Risks Identified:'), findsOneWidget);
    });

    testWidgets('Test 8: AI Recovery Preview displays Minimum-Disruption surgical slot movements with Apply flow', (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(FakeCalendarRecoveryApiClient(isStateVerified: true, affectedPeriods: 4)),
            selectedSchoolIdProvider.overrideWith((ref) => 'school-123'),
          ],
          child: MaterialApp(
            theme: EduPulseTheme.lightTheme,
            home: const PlannerCalendarScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.text('Analyze Timetable Impact & AI Rebalance'));
      await tester.pumpAndSettle();

      // Verify AI Recovery changes are listed
      expect(find.text('Proposed Rebalancing Schedule (Minimum Disruption):'), findsOneWidget);
      expect(find.text('Class 5 (A) - Mathematics'), findsOneWidget);
      expect(find.text('Class 5 (B) - Science'), findsOneWidget);
      expect(find.text('Teacher: Radha Sharma'), findsOneWidget);
      expect(find.text('Teacher: Curie Patel'), findsOneWidget);

      // Verify Actions
      expect(find.text('Reject'), findsOneWidget);
      expect(find.text('Apply Changes & Dispatch Notifications'), findsOneWidget);
    });
  });
}
