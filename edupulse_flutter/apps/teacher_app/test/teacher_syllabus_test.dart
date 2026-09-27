import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';

import 'package:teacher_app/features/my_classes/data/models/teacher_syllabus_models.dart';
import 'package:teacher_app/features/my_classes/data/datasource/teacher_syllabus_datasource.dart';
import 'package:teacher_app/features/my_classes/presentation/providers/teacher_syllabus_provider.dart';
import 'package:teacher_app/features/my_classes/presentation/pages/teacher_syllabus_screen.dart';

class MockTeacherSyllabusDatasource extends Fake implements TeacherSyllabusRemoteDatasource {
  List<TeacherSyllabusItem> items = [];
  List<TeacherCoverageProgressItem> progressList = [];
  TeacherSyllabusPrediction? prediction;
  bool recordProgressCalled = false;

  @override
  Future<ApiResult<List<TeacherSyllabusItem>>> getSyllabusItems({
    required String schoolId,
    required String classId,
    required String subjectId,
    String? academicYearId,
  }) async {
    return ApiResult.success(items);
  }

  @override
  Future<ApiResult<List<TeacherCoverageProgressItem>>> getSectionProgress({
    required String schoolId,
    required String academicYearId,
    required String sectionId,
    String? subjectId,
  }) async {
    return ApiResult.success(progressList);
  }

  @override
  Future<ApiResult<TeacherSyllabusPrediction?>> getPrediction({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String subjectId,
    required String sectionId,
  }) async {
    return ApiResult.success(prediction);
  }

  @override
  Future<ApiResult<TeacherCoverageProgressItem>> recordSectionProgress({
    required String schoolId,
    required String academicYearId,
    required String syllabusId,
    required String sectionId,
    String? teacherId,
    required String status,
    required double completionPercentage,
    String? startedAt,
    String? completedAt,
    String? remarks,
  }) async {
    recordProgressCalled = true;
    final item = TeacherCoverageProgressItem(
      id: 'prog-1',
      syllabusId: syllabusId,
      sectionId: sectionId,
      teacherId: teacherId,
      status: status,
      completionPercentage: completionPercentage,
      startedAt: startedAt,
      completedAt: completedAt,
      remarks: remarks,
    );
    return ApiResult.success(item);
  }
}

class FakeTeacherSyllabusNotifier extends TeacherSyllabusNotifier {
  FakeTeacherSyllabusNotifier(
    super.datasource,
    super.ref,
    super.query, {
    required TeacherSyllabusState presetState,
  }) {
    state = presetState;
  }

  @override
  Future<void> load() async {}
}

void main() {
  group('Teacher Syllabus Models & Logic', () {
    test('TeacherSyllabusItem deserializes correctly', () {
      final json = {
        'id': 'syl-1',
        'unit_name': 'Unit 1: Number Systems',
        'chapter_name': 'Real Numbers',
        'topic_name': 'Euclids Division Lemma',
        'sequence_order': 1,
        'estimated_periods': 3,
        'coverage_status': 'PENDING',
        'lifecycle_status': 'PLANNED',
      };

      final item = TeacherSyllabusItem.fromJson(json);
      expect(item.id, 'syl-1');
      expect(item.unitName, 'Unit 1: Number Systems');
      expect(item.chapterName, 'Real Numbers');
      expect(item.topicName, 'Euclids Division Lemma');
      expect(item.sequenceOrder, 1);
      expect(item.estimatedPeriods, 3);
    });

    test('TeacherSyllabusPrediction data sufficiency & risk colors', () {
      const pred = TeacherSyllabusPrediction(
        subjectId: 'sub-1',
        subjectName: 'Mathematics',
        classId: 'cls-1',
        className: 'Grade 10',
        sectionId: 'sec-1',
        sectionName: 'A',
        totalChapters: 10,
        completedChapters: 4,
        inProgressChapters: 1,
        remainingChapters: 5,
        totalTopics: 30,
        completedTopics: 12,
        completionPercentage: 40.0,
        plannedPace: 1.2,
        actualPace: 1.0,
        projectedCompletionDate: '2026-11-20',
        isEstimate: true,
        riskStatus: 'ON_TRACK',
        dataSufficiency: 'SUFFICIENT',
        message: 'On track to complete before final exams.',
      );

      expect(pred.riskColor, const Color(0xFF10B981));
      expect(pred.riskLabel, 'On Track');
      expect(pred.sufficiencyLabel, 'Verified Data');
    });
  });

  group('TeacherSyllabusScreen Widget Tests', () {
    testWidgets('renders syllabus screen with hero metrics and topic items', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1000));

      const query = TeacherSyllabusQuery(
        classId: 'cls-101',
        sectionId: 'sec-101',
        subjectId: 'sub-101',
      );

      const item = TeacherSyllabusItem(
        id: 'syl-101',
        unitName: 'Unit 1: Algebra',
        chapterName: 'Quadratic Equations',
        topicName: 'Standard Form & Factorization',
        sequenceOrder: 1,
        estimatedPeriods: 3,
        coverageStatus: 'PENDING',
        lifecycleStatus: 'PLANNED',
      );

      const prediction = TeacherSyllabusPrediction(
        subjectId: 'sub-101',
        subjectName: 'Mathematics',
        classId: 'cls-101',
        className: 'Grade 10',
        sectionId: 'sec-101',
        sectionName: 'A',
        totalChapters: 8,
        completedChapters: 3,
        inProgressChapters: 1,
        remainingChapters: 4,
        totalTopics: 24,
        completedTopics: 9,
        completionPercentage: 37.5,
        plannedPace: 1.1,
        actualPace: 0.9,
        projectedCompletionDate: '2026-11-15',
        isEstimate: true,
        targetExamName: 'Midterm Assessment',
        targetExamDate: '2026-10-15',
        daysGapToExam: 22,
        riskStatus: 'AT_RISK',
        dataSufficiency: 'SUFFICIENT',
        message: 'Current pace is 0.2 ch/wk below required exam timeline.',
        recommendedAction: 'Allocate +1 period/week for Mathematics',
      );

      final mockDs = MockTeacherSyllabusDatasource();
      final presetState = TeacherSyllabusState(
        isLoading: false,
        items: const [item],
        progressMap: const {},
        prediction: prediction,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teacherSyllabusProvider(query).overrideWith(
              (ref) => FakeTeacherSyllabusNotifier(
                mockDs,
                ref,
                query,
                presetState: presetState,
              ),
            ),
          ],
          child: const MaterialApp(
            home: TeacherSyllabusScreen(
              classId: 'cls-101',
              sectionId: 'sec-101',
              subjectId: 'sub-101',
              className: 'Grade 10',
              sectionName: 'A',
              subjectName: 'Mathematics',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Screen Header
      expect(find.text('Mathematics'), findsOneWidget);
      expect(find.text('Grade 10 - A • Syllabus Progress'), findsOneWidget);

      // Verify Pacing & Intelligence Hero
      expect(find.text('Pacing & Completion Intelligence'), findsOneWidget);
      expect(find.text('Pacing Alert: At Risk'), findsOneWidget);
      expect(find.textContaining('Planned Pace:'), findsOneWidget);
      expect(find.textContaining('Actual Pace:'), findsOneWidget);
      expect(find.textContaining('Target Exam: Midterm Assessment'), findsOneWidget);
      expect(find.textContaining('Adaptive Advice: Allocate +1 period/week'), findsOneWidget);

      // Verify Topic in list
      expect(find.text('Unit 1: Algebra'), findsOneWidget);
      expect(find.text('Quadratic Equations'), findsOneWidget);
      expect(find.text('Standard Form & Factorization'), findsOneWidget);
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('⏱️ 3 periods'), findsOneWidget);
    });
  });
}
