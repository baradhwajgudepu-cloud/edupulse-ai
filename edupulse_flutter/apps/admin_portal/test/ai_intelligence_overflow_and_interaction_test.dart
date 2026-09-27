import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_portal/features/ai_intelligence/data/models/ai_intelligence_models.dart';
import 'package:admin_portal/features/ai_intelligence/presentation/pages/ai_intelligence_dashboard_screen.dart';
import 'package:admin_portal/features/ai_intelligence/presentation/providers/ai_intelligence_providers.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/school_setup/data/models/school_setup_models.dart';

class MockAcademicYearsNotifier extends StateNotifier<AcademicYearsState>
    implements AcademicYearsNotifier {
  MockAcademicYearsNotifier(super.state);
  @override
  Future<void> fetchYears() async {}
}

class MockClassesNotifier extends StateNotifier<ClassesState>
    implements ClassesNotifier {
  MockClassesNotifier(super.state);
  @override
  Future<void> fetchClasses({String? academicYearId}) async {}
}

class MockSectionsNotifier extends StateNotifier<SectionsState>
    implements SectionsNotifier {
  MockSectionsNotifier(super.state);
  @override
  Future<void> fetchSections({String? academicYearId, String? classId}) async {}
}

void main() {
  final sampleSummary = AIIntelligenceSummaryModel.fromJson({
    'school_health_score': 84,
    'ai_executive_summary':
        'Overall academic performance is steady at 72.4%. All systems operating within normal parameters.',
    'sub_scores': {
      'academic_performance': {'score': 88.0, 'status': 'EXCELLENT'},
      'attendance_correlation': {'score': 88.0, 'status': 'EXCELLENT'},
      'subject_difficulty': {'score': 75.0, 'status': 'MODERATE'},
      'marks_completion': {'score': 95.0, 'status': 'OPTIMAL'},
      'exam_readiness': {'score': 90.0, 'status': 'OPTIMAL'},
    },
    'academic_risk_radar': [],
    'performance_trends': [
      {
        'examination_id': 'exam-1',
        'examination_name': 'Midterm 2026',
        'start_date': '2026-02-15',
        'average_percentage': 74.2,
        'delta_percentage': 2.1,
        'trend_direction': 'UP',
        'ai_analysis': 'Positive progression across secondary grades.',
      }
    ],
    'subject_difficulty_analysis': [
      {
        'subject_id': 'subj-math',
        'subject_name': 'Mathematics',
        'total_students_evaluated': 30,
        'average_percentage': 68.5,
        'median_percentage': 71.0,
        'highest_percentage': 98.0,
        'lowest_percentage': 35.0,
        'pass_percentage': 83.3,
        'below_50_count': 5,
        'below_50_percentage': 16.7,
        'difficulty_index': 'WATCH',
        'difficulty_score': 16.7,
        'difficulty_explanation':
            'Mathematics requires observation: 16.7% (5/30) scored below 50% with an average score of 68.5% and a median score of 71.0%.',
        'marks_distribution': {
          'score_90_100': 4,
          'score_75_89': 10,
          'score_60_74': 11,
          'score_50_59': 0,
          'score_below_50': 5,
        },
      },
      {
        'subject_id': 'subj-sci',
        'subject_name': 'Physical Sciences',
        'total_students_evaluated': 30,
        'average_percentage': 78.0,
        'median_percentage': 80.0,
        'highest_percentage': 99.0,
        'lowest_percentage': 55.0,
        'pass_percentage': 100.0,
        'below_50_count': 0,
        'below_50_percentage': 0.0,
        'difficulty_index': 'NORMAL',
        'difficulty_score': 0.0,
        'difficulty_explanation':
            'Physical Sciences displays stable academic performance with 100.0% pass rate and an average score of 78.0%.',
        'marks_distribution': {
          'score_90_100': 8,
          'score_75_89': 14,
          'score_60_74': 8,
          'score_50_59': 0,
          'score_below_50': 0,
        },
      },
    ],
    'marks_anomalies': [],
  });

  final mockYear = AcademicYearDto.fromJson({
    'id': 'ay-2025-26',
    'tenant_id': 'tenant-1',
    'school_id': 'school-ts001',
    'name': '2025-2026',
    'code': 'AY25',
    'start_date': '2025-06-01',
    'end_date': '2026-04-30',
    'is_current': true,
    'status': 'ACTIVE',
    'is_active': true,
    'version': 1,
  });

  final mockClass = ClassDto.fromJson({
    'id': 'cls-10',
    'tenant_id': 'tenant-1',
    'school_id': 'school-ts001',
    'academic_year_id': 'ay-2025-26',
    'name': 'Grade 10',
    'code': 'G10',
    'level': 10,
    'category': 'SECONDARY',
    'capacity': 40,
    'status': 'ACTIVE',
    'is_active': true,
    'version': 1,
  });

  final mockSection = SectionDto.fromJson({
    'id': 'sec-a',
    'tenant_id': 'tenant-1',
    'school_id': 'school-ts001',
    'academic_year_id': 'ay-2025-26',
    'class_id': 'cls-10',
    'name': 'Section A',
    'code': 'A',
    'capacity': 40,
    'status': 'ACTIVE',
    'is_active': true,
    'version': 1,
  });

  Widget createTestWidget({Size screenSize = const Size(1280, 800)}) {
    return ProviderScope(
      overrides: [
        selectedSchoolIdProvider.overrideWith((ref) => 'school-ts001'),
        aiIntelligenceSummaryProvider.overrideWith((ref) => Future.value(sampleSummary)),
        academicYearsProvider('school-ts001').overrideWith(
          (ref) => MockAcademicYearsNotifier(
            AcademicYearsState(years: [mockYear], isLoading: false),
          ),
        ),
        classesProvider('school-ts001').overrideWith(
          (ref) => MockClassesNotifier(
            ClassesState(classes: [mockClass], isLoading: false),
          ),
        ),
        sectionsProvider('school-ts001').overrideWith(
          (ref) => MockSectionsNotifier(
            SectionsState(sections: [mockSection], isLoading: false),
          ),
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: screenSize),
          child: const AIIntelligenceDashboardScreen(),
        ),
      ),
    );
  }

  testWidgets('AI Intelligence Dashboard renders without RenderFlex overflow at 1280px desktop width', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createTestWidget(screenSize: const Size(1280, 800)));
    await tester.pumpAndSettle();

    // Verify Title and Subtitle rendered without overflow
    expect(find.text('School Intelligence Command Center'), findsOneWidget);
    expect(find.text('Refresh Analytics'), findsOneWidget);

    // Verify Scoping Filters rendered properly
    expect(find.text('Academic Year'), findsWidgets);
    expect(find.text('Class'), findsWidgets);
    expect(find.text('Reset Filters'), findsOneWidget);

    // Verify Health Index and executive summary
    expect(find.textContaining('School Academic Health Index'), findsOneWidget);
    expect(find.text('84'), findsOneWidget);

    // Verify Subject Difficulty Analysis section
    expect(find.text('Subject Difficulty Analysis'), findsOneWidget);
    expect(find.text('Mathematics'), findsOneWidget);
    expect(find.text('Physical Sciences'), findsOneWidget);
    expect(find.text('WATCH'), findsOneWidget);
    expect(find.text('NORMAL'), findsOneWidget);
  });

  testWidgets('AI Intelligence Dashboard renders without RenderFlex overflow at 768px tablet width', (tester) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createTestWidget(screenSize: const Size(768, 1024)));
    await tester.pumpAndSettle();

    expect(find.text('School Intelligence Command Center'), findsOneWidget);
    expect(find.text('Subject Difficulty Analysis'), findsOneWidget);
  });

  testWidgets('Tapping Subject row opens drill-down dialog with deterministic explanation and distribution', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Scroll and tap on Mathematics row
    final mathRow = find.text('Mathematics');
    expect(mathRow, findsOneWidget);
    await tester.ensureVisible(mathRow);
    await tester.pumpAndSettle();
    await tester.tap(mathRow);
    await tester.pumpAndSettle();

    // Verify drill-down dialog content
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Performance Metrics'), findsOneWidget);
    expect(find.text('30 Students'), findsOneWidget);
    expect(find.text('68.5%'), findsOneWidget); // Average %
    expect(find.text('71.0%'), findsOneWidget); // Median %
    expect(find.text('83.3%'), findsOneWidget); // Pass %
    expect(find.text('5 (16.7%)'), findsNWidgets(2)); // Below 50% in metric tile and distribution bar
    expect(find.text('16.7 / 100'), findsOneWidget); // Difficulty score

    // Verify deterministic explanation is shown
    expect(
      find.textContaining('Mathematics requires observation: 16.7% (5/30) scored below 50%'),
      findsOneWidget,
    );

    // Verify Marks Distribution bars
    expect(find.text('Marks Distribution'), findsOneWidget);
    expect(find.text('90–100%'), findsOneWidget);
    expect(find.text('Below 50%'), findsOneWidget);

    // Tap Close button
    final closeBtn = find.byIcon(Icons.close);
    expect(closeBtn, findsOneWidget);
    await tester.tap(closeBtn);
    await tester.pumpAndSettle();

    // Verify dialog is closed
    expect(find.byType(Dialog), findsNothing);
  });
}
