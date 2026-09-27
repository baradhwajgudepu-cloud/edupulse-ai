import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/planner/presentation/pages/academic_planning_analytics_screen.dart';

class FakeAcademicPlanningApiClient extends BaseApiClient {
  bool failSummary = false;
  bool emptyAcademicYears = false;
  int summaryCallCount = 0;
  String currentSchool = 'school_ts001';

  FakeAcademicPlanningApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (path.contains('/academic-years')) {
      if (emptyAcademicYears) {
        return ApiResult.success(mapper({'data': []}));
      }
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'ay_2026',
            'tenant_id': 'tenant_1',
            'school_id': currentSchool,
            'name': '2026-2027',
            'code': 'AY2026',
            'start_date': '2026-06-01',
            'end_date': '2027-04-30',
            'status': 'ACTIVE',
            'is_current': true,
            'version': 1,
          },
          {
            'id': 'ay_2027',
            'tenant_id': 'tenant_1',
            'school_id': currentSchool,
            'name': '2027-2028',
            'code': 'AY2027',
            'start_date': '2027-06-01',
            'end_date': '2028-04-30',
            'status': 'UPCOMING',
            'is_current': false,
            'version': 1,
          },
        ]
      }));
    }

    if (path.contains('/academic-planning/summary')) {
      summaryCallCount++;
      if (failSummary) {
        return ApiResult.failure(const ApiFailure(
          message: 'Internal server error 500',
          type: ApiFailureType.server,
        ));
      }
      return ApiResult.success(mapper({
        'data': {
          'school_id': currentSchool,
          'academic_year_id': 'ay_2026',
          'school_wide_completion_pct': 42.5,
          'total_subjects_tracked': 36,
          'on_track_count': 28,
          'at_risk_count': 6,
          'likely_to_miss_count': 2,
          'upcoming_exams_count': 3,
          'class_summaries': [
            {
              'class_id': 'cls_10',
              'class_name': 'Class 10',
              'completion_percentage': 52.0,
              'at_risk_count': 1,
              'total_subjects': 6,
            }
          ],
          'at_risk_subjects': [
            {
              'class_id': 'cls_10',
              'class_name': 'Class 10',
              'section_id': 'sec_10a',
              'section_name': 'Section A',
              'subject_id': 'sub_math',
              'subject_name': 'Mathematics',
              'teacher_name': 'Dr. Sreenivas Sharma',
              'planned_pace': 3.0,
              'actual_pace': 2.1,
              'completion_percentage': 38.0,
              'status': 'AT_RISK',
              'target_exam_name': 'Quarterly Exams',
              'target_exam_date': '2026-10-15',
              'days_until_exam': 21,
              'projected_completion_date': '2026-11-05',
              'delay_days': 21,
            }
          ],
          'adaptive_recommendations': [],
        }
      }));
    }

    if (path.contains('/syllabus-recovery/academic-heatmap')) {
      return ApiResult.success(mapper({
        'data': {
          'school_id': currentSchool,
          'academic_year_id': 'ay_2026',
          'classes': [
            {'id': 'cls_10', 'name': 'Class 10'}
          ],
          'subjects': [
            {'id': 'sub_math', 'name': 'Mathematics'}
          ],
          'cells': [
            {
              'class_id': 'cls_10',
              'class_name': 'Class 10',
              'section_id': 'sec_10a',
              'section_name': 'Section A',
              'subject_id': 'sub_math',
              'subject_name': 'Mathematics',
              'teacher_name': 'Dr. Sreenivas Sharma',
              'completion_percentage': 38.0,
              'status': 'AT_RISK',
              'delay_days': 21,
              'forecast_date': '2026-11-05',
              'recovery_plan_active': true,
            }
          ],
          'summary': {
            'total_subjects': 1,
            'on_track': 0,
            'at_risk': 1,
            'delayed': 0,
            'average_completion': 38.0,
          },
        }
      }));
    }

    if (path.contains('/syllabus-recovery/plans')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'plan_001',
            'school_id': currentSchool,
            'academic_year_id': 'ay_2026',
            'class_id': 'cls_10',
            'class_name': 'Class 10',
            'section_id': 'sec_10a',
            'section_name': 'Section A',
            'subject_id': 'sub_math',
            'subject_name': 'Mathematics',
            'teacher_name': 'Dr. Sreenivas Sharma',
            'status': 'SUGGESTED',
            'reason': 'Exam Pacing Delay Recovery',
            'current_completion': 38.0,
            'target_completion_date': '2026-10-15',
            'forecast_completion_date': '2026-11-05',
            'new_forecast_date': '2026-10-14',
            'items': [
              {
                'id': 'item_1',
                'recovery_plan_id': 'plan_001',
                'tenant_id': 'tenant_1',
                'date': '2026-09-29',
                'period_number': 3,
                'phase': 'PHASE_1_CATCHUP',
                'topic_name': 'Quadratic Equations Catch-up',
                'duration_minutes': 45,
                'class_id': 'cls_10',
                'section_id': 'sec_10a',
                'status': 'SUGGESTED',
                'is_approved': false,
                'conflict_status': 'NO_CONFLICT',
                'is_active': true,
                'version': 1,
              }
            ],
          }
        ]
      }));
    }

    if (path.contains('/syllabus-recovery/analytics-summary')) {
      return ApiResult.success(mapper({
        'data': {
          'school_id': currentSchool,
          'academic_year_id': 'ay_2026',
          'normal_periods': 120,
          'recovery_periods': 14,
          'cross_teacher_support_periods': 6,
          'teacher_absence_recovery_periods': 8,
          'active_recovery_plans_count': 3,
          'approved_recovery_plans_count': 2,
          'completed_recovery_plans_count': 1,
          'subject_breakdown': [],
          'class_breakdown': [],
        }
      }));
    }

    return ApiResult.failure(const ApiFailure(message: 'Not found', type: ApiFailureType.unknown));
  }
}

Widget createAcademicPlanningTestWidget({
  required FakeAcademicPlanningApiClient client,
  String schoolId = 'school_ts001',
}) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(client),
      selectedSchoolIdProvider.overrideWith((ref) => schoolId),
    ],
    child: const MaterialApp(
      home: AcademicPlanningAnalyticsScreen(),
    ),
  );
}

void main() {
  testWidgets('Test 1: Academic Planning page loads and renders title and action buttons', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 850));
    final client = FakeAcademicPlanningApiClient();

    await tester.pumpWidget(createAcademicPlanningTestWidget(client: client));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Academic Planning Intelligence & Pace Analytics'), findsOneWidget);
    expect(find.text('Syllabus Editor'), findsOneWidget);
    expect(find.text('Timetable Management'), findsOneWidget);
    expect(find.text('Curriculum Pace & Analytics'), findsOneWidget);
    expect(find.text('Academic Heatmap (Class × Subject)'), findsOneWidget);
    expect(find.text('Recovery Plans & Validator'), findsOneWidget);
  });

  testWidgets('Test 2 & 7: Academic Year dropdown renders API-loaded items strongly typed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 850));
    final client = FakeAcademicPlanningApiClient();

    await tester.pumpWidget(createAcademicPlanningTestWidget(client: client));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final formFieldFinder = find.byKey(const Key('academic_year_dropdown'));
    expect(formFieldFinder, findsOneWidget);

    final dropdownFinder = find.descendant(
      of: formFieldFinder,
      matching: find.byType(DropdownButton<String>),
    );
    expect(dropdownFinder, findsOneWidget);

    final dropdownWidget = tester.widget<DropdownButton<String>>(dropdownFinder);
    expect(dropdownWidget.items, isNotNull);
    expect(dropdownWidget.items, isA<List<DropdownMenuItem<String>>>());
    expect(dropdownWidget.items!.length, equals(2));
    expect(dropdownWidget.items![0].value, equals('ay_2026'));
    expect(dropdownWidget.items![1].value, equals('ay_2027'));
  });

  testWidgets('Test 6: Empty dropdown data produces empty typed list rather than crash', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 850));
    final client = FakeAcademicPlanningApiClient();
    client.emptyAcademicYears = true;

    await tester.pumpWidget(createAcademicPlanningTestWidget(client: client));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No Academic Years Configured'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
  });

  testWidgets('Test 8: Academic Planning Analytics tab renders KPI metrics and pacing cards', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 850));
    final client = FakeAcademicPlanningApiClient();

    await tester.pumpWidget(createAcademicPlanningTestWidget(client: client));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('School Completion Rate'), findsOneWidget);
    expect(find.text('42.5%'), findsOneWidget);
    expect(find.text('Subjects On Track'), findsOneWidget);
    expect(find.text('28'), findsOneWidget);
    expect(find.text('Subjects At Risk'), findsOneWidget);
    expect(find.text('Class 10 • Mathematics'), findsWidgets);
    expect(find.text('Cross-Teacher Recovery AI'), findsOneWidget);
  });

  testWidgets('Test 9: Academic Heatmap tab switches and renders institutional matrix', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 850));
    final client = FakeAcademicPlanningApiClient();

    await tester.pumpWidget(createAcademicPlanningTestWidget(client: client));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap Tab 2
    await tester.tap(find.text('Academic Heatmap (Class × Subject)'));
    await tester.pumpAndSettle();

    expect(find.text('Institutional Academic Progress Matrix (Class × Subject)'), findsOneWidget);
    expect(find.text('38.0% Institutional Completion'), findsOneWidget);
    expect(find.text('1 Subjects Tracked'), findsOneWidget);
    expect(find.text('Recovery Plan Active'), findsWidgets);
  });

  testWidgets('Test 10: Recovery Plans tab switches and displays proposed recovery plans', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 850));
    final client = FakeAcademicPlanningApiClient();

    await tester.pumpWidget(createAcademicPlanningTestWidget(client: client));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap Tab 3
    await tester.tap(find.text('Recovery Plans & Validator'));
    await tester.pumpAndSettle();

    expect(find.text('AI Syllabus Recovery Plans & Operational Conflict Management'), findsOneWidget);
    expect(find.text('Open Recovery Editor & Validator'), findsOneWidget);
    expect(find.text('0 Conflicts (Verified Available)'), findsOneWidget);
    expect(find.text('SUGGESTED'), findsOneWidget);
  });

  testWidgets('Test 11: Retry button works after API failure without red-screen crash', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 850));
    final client = FakeAcademicPlanningApiClient();
    client.failSummary = true;

    await tester.pumpWidget(createAcademicPlanningTestWidget(client: client));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Error container is rendered
    expect(find.text('Academic Planning Analytics Unavailable'), findsOneWidget);
    expect(find.byKey(const Key('retry_academic_planning_button')), findsOneWidget);
    expect(find.byKey(const Key('academic_year_dropdown')), findsOneWidget);

    // Fix failure and tap retry
    client.failSummary = false;
    await tester.tap(find.byKey(const Key('retry_academic_planning_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('School Completion Rate'), findsOneWidget);
    expect(find.text('42.5%'), findsOneWidget);
  });

  testWidgets('Test 12 & 13: School switching and Academic Year switching', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 850));
    final client = FakeAcademicPlanningApiClient();

    await tester.pumpWidget(createAcademicPlanningTestWidget(client: client));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final dropdownFinder = find.byKey(const Key('academic_year_dropdown'));
    expect(dropdownFinder, findsOneWidget);

    // Select second academic year
    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();

    expect(find.text('2027-2028').last, findsOneWidget);
    await tester.tap(find.text('2027-2028').last);
    await tester.pumpAndSettle();

    final dropdownWidget = tester.widget<DropdownButton<String>>(
      find.descendant(
        of: dropdownFinder,
        matching: find.byType(DropdownButton<String>),
      ),
    );
    expect(dropdownWidget.value, equals('ay_2027'));
  });

  testWidgets('Test 14: Strong typing regression test - items is exactly List<DropdownMenuItem<String>>', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 850));
    final client = FakeAcademicPlanningApiClient();

    await tester.pumpWidget(createAcademicPlanningTestWidget(client: client));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final dropdownWidget = tester.widget<DropdownButton<String>>(
      find.descendant(
        of: find.byKey(const Key('academic_year_dropdown')),
        matching: find.byType(DropdownButton<String>),
      ),
    );

    final items = dropdownWidget.items;
    expect(items, isNotNull);
    // Explicit runtime check
    expect(items.runtimeType.toString(), contains('DropdownMenuItem<String>'));
    expect(items is List<DropdownMenuItem<String>>, isTrue);
  });
}
