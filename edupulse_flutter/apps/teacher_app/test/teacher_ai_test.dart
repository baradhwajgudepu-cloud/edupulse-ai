import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:teacher_app/features/teacher_ai/data/datasource/teacher_ai_remote_datasource.dart';
import 'package:teacher_app/features/teacher_ai/data/models/teacher_ai_dtos.dart';
import 'package:teacher_app/features/teacher_ai/presentation/providers/teacher_ai_provider.dart';

class FakeTeacherAiRemoteDatasource implements TeacherAiRemoteDatasource {
  final bool shouldFail;
  final String errorMessage;

  FakeTeacherAiRemoteDatasource({
    this.shouldFail = false,
    this.errorMessage = 'AI service unavailable',
  });

  @override
  Future<ApiResult<StudentInsightDto>> getStudentInsight({
    required String studentId,
  }) async {
    if (shouldFail) {
      return ApiResult.failure(ApiFailure(statusCode: 500, message: errorMessage, type: ApiFailureType.unknown));
    }
    return ApiResult.success(StudentInsightDto(
      performanceTrend: 'Improving',
      attendanceTrend: 'Consistent',
      recentAcademicChanges: 'None',
      summary: 'Excellent progress',
      improvementAreas: const ['Math basics'],
      attentionAreas: const ['Late arrival'],
      suggestedActions: const ['Keep encouraging'],
    ));
  }

  @override
  Future<ApiResult<ClassAnalysisDto>> getClassAnalysis({
    required String classId,
    required String sectionId,
    required String subjectId,
  }) async {
    if (shouldFail) {
      return ApiResult.failure(ApiFailure(statusCode: 500, message: errorMessage, type: ApiFailureType.unknown));
    }
    return ApiResult.success(ClassAnalysisDto(
      classAverage: 82.5,
      passPercentage: 95.0,
      improvementTrend: 'Upward trend',
      gradeDistribution: const {'A': 5, 'B': 10},
      studentsImproving: const ['John Doe'],
      studentsDeclining: const ['Jane Doe'],
      strongAreas: const ['Gravity'],
      needsReinforcementAreas: const ['Motion'],
      suggestedActions: const ['Do quiz'],
    ));
  }

  @override
  Future<ApiResult<RemarkGenerationDto>> generateRemark({
    required String studentId,
    required String subjectId,
  }) async {
    if (shouldFail) {
      return ApiResult.failure(ApiFailure(statusCode: 500, message: errorMessage, type: ApiFailureType.unknown));
    }
    return ApiResult.success(RemarkGenerationDto(
      draftRemark: 'Showing great dedication.',
    ));
  }

  @override
  Future<ApiResult<HomeworkGenerationDto>> generateHomework({
    required String classId,
    required String sectionId,
    required String subjectId,
    required String topic,
    required String difficulty,
    required int numberOfQuestions,
    required int marks,
    String? questionType,
  }) async {
    if (shouldFail) {
      return ApiResult.failure(ApiFailure(statusCode: 500, message: errorMessage, type: ApiFailureType.unknown));
    }
    return ApiResult.success(HomeworkGenerationDto(
      title: 'Suggested Homework on Gravity',
      description: 'Practice questions.',
      learningObjective: 'Understand gravity forces.',
      estimatedMinutes: 30,
      difficulty: 'MEDIUM',
      questions: [
        GeneratedQuestionDto(
          text: 'What is 2+2?',
          marks: 5,
          choices: const ['3', '4', '5'],
          answerKey: '4',
          difficulty: 'EASY',
        ),
      ],
    ));
  }

  @override
  Future<ApiResult<QuestionsGenerationDto>> generateQuestions({
    required String classId,
    required String sectionId,
    required String subjectId,
    required String topic,
    required String difficulty,
    required int numberOfQuestions,
    required int marks,
    String? questionType,
  }) async {
    if (shouldFail) {
      return ApiResult.failure(ApiFailure(statusCode: 500, message: errorMessage, type: ApiFailureType.unknown));
    }
    return ApiResult.success(QuestionsGenerationDto(
      questions: const [],
    ));
  }
}

void main() {
  group('Teacher AI Providers Test', () {
    test('Student Insight Provider Success Flow', () async {
      final fakeDs = FakeTeacherAiRemoteDatasource();
      final container = ProviderContainer(
        overrides: [
          teacherAiRemoteDatasourceProvider.overrideWithValue(fakeDs),
        ],
      );

      final notifier = container.read(studentInsightNotifierProvider('stud_123').notifier);
      
      // Initial state
      expect(container.read(studentInsightNotifierProvider('stud_123')), isA<StudentInsightInitial>());

      // Fetch
      final future = notifier.fetchStudentInsight(studentId: 'stud_123');
      expect(container.read(studentInsightNotifierProvider('stud_123')), isA<StudentInsightLoading>());

      await future;

      final state = container.read(studentInsightNotifierProvider('stud_123'));
      expect(state, isA<StudentInsightSuccess>());
      
      final successState = state as StudentInsightSuccess;
      expect(successState.insight.performanceTrend, 'Improving');
      expect(successState.insight.summary, 'Excellent progress');
    });

    test('Student Insight Provider Error Flow', () async {
      final fakeDs = FakeTeacherAiRemoteDatasource(shouldFail: true, errorMessage: 'Failed to generate');
      final container = ProviderContainer(
        overrides: [
          teacherAiRemoteDatasourceProvider.overrideWithValue(fakeDs),
        ],
      );

      final notifier = container.read(studentInsightNotifierProvider('stud_123').notifier);
      await notifier.fetchStudentInsight(studentId: 'stud_123');

      final state = container.read(studentInsightNotifierProvider('stud_123'));
      expect(state, isA<StudentInsightError>());
      
      final errorState = state as StudentInsightError;
      expect(errorState.message, 'Failed to generate');
    });

    test('Class Analysis Provider Success Flow', () async {
      final fakeDs = FakeTeacherAiRemoteDatasource();
      final container = ProviderContainer(
        overrides: [
          teacherAiRemoteDatasourceProvider.overrideWithValue(fakeDs),
        ],
      );

      final notifier = container.read(classAnalysisNotifierProvider.notifier);
      expect(container.read(classAnalysisNotifierProvider), isA<ClassAnalysisInitial>());

      final future = notifier.fetchClassAnalysis(classId: 'c1', sectionId: 's1', subjectId: 'sub1');
      expect(container.read(classAnalysisNotifierProvider), isA<ClassAnalysisLoading>());

      await future;

      final state = container.read(classAnalysisNotifierProvider);
      expect(state, isA<ClassAnalysisSuccess>());
      
      final successState = state as ClassAnalysisSuccess;
      expect(successState.analysis.classAverage, 82.5);
      expect(successState.analysis.studentsImproving.first, 'John Doe');
    });

    test('Remark Generation Provider Success Flow', () async {
      final fakeDs = FakeTeacherAiRemoteDatasource();
      final container = ProviderContainer(
        overrides: [
          teacherAiRemoteDatasourceProvider.overrideWithValue(fakeDs),
        ],
      );

      final notifier = container.read(remarkGenerationNotifierProvider.notifier);
      expect(container.read(remarkGenerationNotifierProvider), isA<RemarkGenerationInitial>());

      final future = notifier.generateRemark(studentId: 'stud1', subjectId: 'sub1');
      expect(container.read(remarkGenerationNotifierProvider), isA<RemarkGenerationLoading>());

      await future;

      final state = container.read(remarkGenerationNotifierProvider);
      expect(state, isA<RemarkGenerationSuccess>());
      
      final successState = state as RemarkGenerationSuccess;
      expect(successState.remark.draftRemark, 'Showing great dedication.');
    });

    test('Homework Generation Provider Success Flow', () async {
      final fakeDs = FakeTeacherAiRemoteDatasource();
      final container = ProviderContainer(
        overrides: [
          teacherAiRemoteDatasourceProvider.overrideWithValue(fakeDs),
        ],
      );

      final notifier = container.read(homeworkGenerationNotifierProvider.notifier);
      expect(container.read(homeworkGenerationNotifierProvider), isA<HomeworkGenerationInitial>());

      final future = notifier.generateHomework(
        classId: 'c1',
        sectionId: 's1',
        subjectId: 'sub1',
        topic: 'Gravity',
        difficulty: 'MEDIUM',
        numberOfQuestions: 5,
        marks: 20,
      );
      expect(container.read(homeworkGenerationNotifierProvider), isA<HomeworkGenerationLoading>());

      await future;

      final state = container.read(homeworkGenerationNotifierProvider);
      expect(state, isA<HomeworkGenerationSuccess>());
      
      final successState = state as HomeworkGenerationSuccess;
      expect(successState.homework.title, 'Suggested Homework on Gravity');
      expect(successState.homework.questions.first.text, 'What is 2+2?');
    });
  });
}
