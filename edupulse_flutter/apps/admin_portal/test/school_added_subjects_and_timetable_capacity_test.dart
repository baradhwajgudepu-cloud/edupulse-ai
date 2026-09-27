import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:admin_portal/features/school_setup/data/models/school_setup_models.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/school_setup/presentation/pages/subjects_screen.dart';
import 'package:admin_portal/features/school_setup/presentation/widgets/ai_draft_syllabus_dialog.dart';
import 'package:admin_portal/features/planner/data/models/timetable_models.dart';
import 'package:admin_portal/features/planner/presentation/providers/working_hours_providers.dart';
import 'package:admin_portal/features/planner/presentation/widgets/timetable_capacity_card.dart';
import 'package:admin_portal/features/planner/presentation/widgets/working_hours_dialog.dart';

class FakeCapacityApiClient extends BaseApiClient {
  FakeCapacityApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (path.contains('/working-hours/capacity')) {
      return ApiResult.success(mapper({
        'data': {
          'school_id': 'school_1',
          'academic_year_id': 'ay_1',
          'working_days_count': 6,
          'periods_per_day': 8,
          'available_weekly_capacity': 48,
          'total_subjects_configured': 8,
          'official_subjects_count': 6,
          'school_added_subjects_count': 2,
          'total_required_periods': 52,
          'remaining_capacity': -4,
          'shortfall_periods': 4,
          'is_shortfall': true,
          'is_extended_hours_enabled': true,
          'extended_hours_potential_capacity': 3,
          'remediation_options': [
            'OPTIMIZE_EXISTING',
            'ADD_EXTENDED_HOURS',
            'REVIEW_SUBJECT_PERIODS',
            'REVIEW_ACTIVITIES'
          ],
        }
      }));
    }

    if (path.contains('/working-hours')) {
      return ApiResult.success(mapper({
        'data': {
          'id': 'ewh_1',
          'school_id': 'school_1',
          'academic_year_id': 'ay_1',
          'normal_start_time': '08:30',
          'normal_end_time': '15:30',
          'periods_per_day': 8,
          'lunch_period_number': 4,
          'working_days': ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'],
          'is_extended_hours_enabled': true,
          'extended_start_time': '15:30',
          'extended_end_time': '16:15',
          'applicable_days': ['MONDAY', 'WEDNESDAY', 'FRIDAY'],
          'additional_periods': 1,
          'activity_type': 'ADDITIONAL_SUBJECT',
          'weekly_normal_periods': 48,
          'weekly_extended_periods': 3,
          'total_weekly_capacity': 51,
        }
      }));
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
            'id': 'c1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'name': 'Class 10',
            'code': 'CLS10',
            'level': 10,
            'category': 'SECONDARY',
            'capacity': 40,
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
            'id': 'sub_board',
            'tenant_id': 't1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'subject_code': 'MATH101',
            'subject_name': 'Mathematics',
            'category': 'CORE',
            'subject_type': 'THEORY',
            'theory_marks': 80,
            'practical_marks': 20,
            'pass_marks': 35,
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1,
            'source_type': 'BOARD_OFFICIAL',
            'is_examination_applicable': true,
            'is_marks_applicable': true,
            'max_marks': 100,
            'appears_in_report_card': true,
            'included_in_consolidated_result': true,
            'included_in_rank_calculation': true,
            'weekly_periods': 6,
          },
          {
            'id': 'sub_school',
            'tenant_id': 't1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'subject_code': 'ROBO101',
            'subject_name': 'Robotics & AI Lab',
            'category': 'ADDITIONAL',
            'subject_type': 'THEORY_PRACTICAL',
            'theory_marks': 40,
            'practical_marks': 60,
            'pass_marks': 35,
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1,
            'source_type': 'SCHOOL_ADDED',
            'is_examination_applicable': true,
            'is_marks_applicable': true,
            'max_marks': 100,
            'appears_in_report_card': true,
            'included_in_consolidated_result': true,
            'included_in_rank_calculation': false,
            'weekly_periods': 4,
          }
        ]
      }));
    }

    return ApiResult.success(mapper({'data': []}));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('School-Added Subjects & Timetable Capacity Verification Suite', () {
    test('1. SubjectDto correctly identifies source_type and assessment flags', () {
      const boardSub = SubjectDto(
        id: '1',
        tenantId: 't1',
        schoolId: 's1',
        academicYearId: 'ay1',
        subjectCode: 'PHY101',
        subjectName: 'Physics',
        category: 'CORE',
        subjectType: 'THEORY',
        theoryMarks: 70,
        practicalMarks: 30,
        passMarks: 35,
        status: 'ACTIVE',
        isActive: true,
        version: 1,
        sourceType: 'BOARD_OFFICIAL',
      );

      const schoolSub = SubjectDto(
        id: '2',
        tenantId: 't1',
        schoolId: 's1',
        academicYearId: 'ay1',
        subjectCode: 'ROBO101',
        subjectName: 'Robotics',
        category: 'ADDITIONAL',
        subjectType: 'THEORY_PRACTICAL',
        theoryMarks: 50,
        practicalMarks: 50,
        passMarks: 35,
        status: 'ACTIVE',
        isActive: true,
        version: 1,
        sourceType: 'SCHOOL_ADDED',
        isExaminationApplicable: true,
        isMarksApplicable: true,
        maxMarks: 100,
        appearsInReportCard: true,
        includedInConsolidatedResult: true,
        includedInRankCalculation: false,
      );

      expect(boardSub.isBoardOfficial, isTrue);
      expect(boardSub.isSchoolAdded, isFalse);

      expect(schoolSub.isBoardOfficial, isFalse);
      expect(schoolSub.isSchoolAdded, isTrue);
      expect(schoolSub.includedInRankCalculation, isFalse);
    });

    test('2. TimetableCapacitySummaryDto correctly parses shortfall and remediation choices', () {
      final json = {
        'school_id': 's1',
        'academic_year_id': 'ay1',
        'total_periods_available': 48,
        'total_periods_required': 52,
        'shortfall_periods': 4,
        'is_shortfall': true,
        'is_extended_hours_enabled': true,
        'extended_periods_available': 3,
        'remediation_choices': [
          'OPTIMIZE_EXISTING',
          'ADD_EXTENDED_HOURS',
          'REVIEW_SUBJECT_PERIODS',
          'REVIEW_ACTIVITIES'
        ],
        'breakdown_by_category': {
          'CORE': 32,
          'ADDITIONAL': 8,
        },
      };

      final dto = TimetableCapacitySummaryDto.fromJson(json);

      expect(dto.isShortfall, isTrue);
      expect(dto.shortfallPeriods, equals(4));
      expect(dto.availableWeeklyCapacity, equals(48));
      expect(dto.totalRequiredPeriods, equals(52));
      expect(dto.isExtendedHoursEnabled, isTrue);
      expect(dto.extendedHoursPotentialCapacity, equals(3));
      expect(dto.remediationOptions, contains('OPTIMIZE_EXISTING'));
      expect(dto.remediationOptions, contains('ADD_EXTENDED_HOURS'));
    });

    testWidgets('3. TimetableCapacityCard renders capacity shortfall alert and remediation actions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      final fakeApi = FakeCapacityApiClient();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeApi),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: TimetableCapacityCard(
                schoolId: 'school_1',
                academicYearId: 'ay_1',
                onConfigureWorkingHours: () {},
                onOptimizeTimetable: () {},
                onReviewSubjects: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Weekly Timetable Capacity'), findsOneWidget);
      expect(find.text('SHORTFALL: -4 PERIODS'), findsOneWidget);
      expect(find.text('Optimize Existing Timetable'), findsOneWidget);
      expect(find.text('Configure School Hours'), findsOneWidget);
      expect(find.text('Review Subject Periods'), findsOneWidget);
    });

    testWidgets('4. WorkingHoursDialog displays normal hours and extended teaching hours controls', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      final fakeApi = FakeCapacityApiClient();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeApi),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: WorkingHoursDialog(
                schoolId: 'school_1',
                academicYearId: 'ay_1',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('School Working Hours & Teaching Capacity'), findsOneWidget);
      expect(find.text('Regular School Hours'), findsOneWidget);
      expect(find.text('Extended Teaching Hours'), findsOneWidget);
    });

    testWidgets('5. AIDraftSyllabusDialog shows Zero-Hallucination safety banner and Generator Form', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      final fakeApi = FakeCapacityApiClient();

      const testClass = ClassDto(
        id: 'c1',
        tenantId: 't1',
        schoolId: 's1',
        academicYearId: 'ay1',
        name: 'Class 10',
        code: 'CLS10',
        level: 10,
        category: 'SECONDARY',
        capacity: 40,
        status: 'ACTIVE',
        isActive: true,
        version: 1,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeApi),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AIDraftSyllabusDialog(
                schoolId: 'school_1',
                academicYearId: 'ay_1',
                subjectId: 'sub_school',
                subjectName: 'Robotics & AI Lab',
                classes: [testClass],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('AI Draft Syllabus Proposal'), findsOneWidget);
      expect(find.text('AI DRAFT'), findsOneWidget);
      expect(find.text('Zero-Hallucination Safety Protocol'), findsOneWidget);
      expect(find.text('Generate Syllabus Draft'), findsOneWidget);
    });

    testWidgets('6. SubjectsScreen renders source filter chips and distinguishes OFFICIAL BOARD vs SCHOOL ADDED', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final fakeApi = FakeCapacityApiClient();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeApi),
            selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SubjectsScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Curriculum & Subjects Directory'), findsOneWidget);
      expect(find.text('+ Add School Subject'), findsOneWidget);
      expect(find.text('All Sources'), findsOneWidget);
      expect(find.text('Official Board'), findsOneWidget);
      expect(find.text('School Added'), findsOneWidget);

      // Verify badges rendered in table
      expect(find.text('OFFICIAL BOARD'), findsOneWidget);
      expect(find.text('SCHOOL ADDED'), findsOneWidget);
      expect(find.text('Robotics & AI Lab'), findsOneWidget);
      expect(find.text('Mathematics'), findsOneWidget);
    });
  });
}
