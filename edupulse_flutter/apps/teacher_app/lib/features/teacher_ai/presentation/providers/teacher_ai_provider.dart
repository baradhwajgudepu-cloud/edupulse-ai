import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../data/datasource/teacher_ai_remote_datasource.dart';
import '../../data/models/teacher_ai_dtos.dart';

// --- DI Providers ---

final teacherAiRemoteDatasourceProvider = Provider<TeacherAiRemoteDatasource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TeacherAiRemoteDatasource(apiClient);
});

// --- State Definitions ---

// 1. Student Insight State
sealed class StudentInsightState {
  const StudentInsightState();
}
class StudentInsightInitial extends StudentInsightState {
  const StudentInsightInitial();
}
class StudentInsightLoading extends StudentInsightState {
  const StudentInsightLoading();
}
class StudentInsightSuccess extends StudentInsightState {
  final StudentInsightDto insight;
  const StudentInsightSuccess(this.insight);
}
class StudentInsightError extends StudentInsightState {
  final String message;
  const StudentInsightError(this.message);
}

// 2. Class Analysis State
sealed class ClassAnalysisState {
  const ClassAnalysisState();
}
class ClassAnalysisInitial extends ClassAnalysisState {
  const ClassAnalysisInitial();
}
class ClassAnalysisLoading extends ClassAnalysisState {
  const ClassAnalysisLoading();
}
class ClassAnalysisSuccess extends ClassAnalysisState {
  final ClassAnalysisDto analysis;
  const ClassAnalysisSuccess(this.analysis);
}
class ClassAnalysisError extends ClassAnalysisState {
  final String message;
  const ClassAnalysisError(this.message);
}

// 3. Remark Generation State
sealed class RemarkGenerationState {
  const RemarkGenerationState();
}
class RemarkGenerationInitial extends RemarkGenerationState {
  const RemarkGenerationInitial();
}
class RemarkGenerationLoading extends RemarkGenerationState {
  const RemarkGenerationLoading();
}
class RemarkGenerationSuccess extends RemarkGenerationState {
  final RemarkGenerationDto remark;
  const RemarkGenerationSuccess(this.remark);
}
class RemarkGenerationError extends RemarkGenerationState {
  final String message;
  const RemarkGenerationError(this.message);
}

// 4. Homework Generation State
sealed class HomeworkGenerationState {
  const HomeworkGenerationState();
}
class HomeworkGenerationInitial extends HomeworkGenerationState {
  const HomeworkGenerationInitial();
}
class HomeworkGenerationLoading extends HomeworkGenerationState {
  const HomeworkGenerationLoading();
}
class HomeworkGenerationSuccess extends HomeworkGenerationState {
  final HomeworkGenerationDto homework;
  const HomeworkGenerationSuccess(this.homework);
}
class HomeworkGenerationError extends HomeworkGenerationState {
  final String message;
  const HomeworkGenerationError(this.message);
}

// --- Notifier Definitions ---

// 1. Student Insight Notifier
class StudentInsightNotifier extends StateNotifier<StudentInsightState> {
  final TeacherAiRemoteDatasource _datasource;

  StudentInsightNotifier(this._datasource) : super(const StudentInsightInitial());

  Future<void> fetchStudentInsight({required String studentId, bool forceRefresh = false}) async {
    // Prevent duplicate loading submissions
    if (state is StudentInsightLoading) return;

    state = const StudentInsightLoading();
    final result = await _datasource.getStudentInsight(studentId: studentId);
    result.when(
      onSuccess: (insight) {
        state = StudentInsightSuccess(insight);
      },
      onFailure: (err) {
        state = StudentInsightError(err.message);
      },
    );
  }
}

// 2. Class Analysis Notifier
class ClassAnalysisNotifier extends StateNotifier<ClassAnalysisState> {
  final TeacherAiRemoteDatasource _datasource;

  ClassAnalysisNotifier(this._datasource) : super(const ClassAnalysisInitial());

  Future<void> fetchClassAnalysis({
    required String classId,
    required String sectionId,
    required String subjectId,
  }) async {
    if (state is ClassAnalysisLoading) return;

    state = const ClassAnalysisLoading();
    final result = await _datasource.getClassAnalysis(
      classId: classId,
      sectionId: sectionId,
      subjectId: subjectId,
    );
    result.when(
      onSuccess: (analysis) {
        state = ClassAnalysisSuccess(analysis);
      },
      onFailure: (err) {
        state = ClassAnalysisError(err.message);
      },
    );
  }

  void clearAnalysis() {
    state = const ClassAnalysisInitial();
  }
}

// 3. Remark Generation Notifier
class RemarkGenerationNotifier extends StateNotifier<RemarkGenerationState> {
  final TeacherAiRemoteDatasource _datasource;

  RemarkGenerationNotifier(this._datasource) : super(const RemarkGenerationInitial());

  Future<void> generateRemark({
    required String studentId,
    required String subjectId,
  }) async {
    if (state is RemarkGenerationLoading) return;

    state = const RemarkGenerationLoading();
    final result = await _datasource.generateRemark(
      studentId: studentId,
      subjectId: subjectId,
    );
    result.when(
      onSuccess: (remark) {
        state = RemarkGenerationSuccess(remark);
      },
      onFailure: (err) {
        state = RemarkGenerationError(err.message);
      },
    );
  }
  
  void clearRemark() {
    state = const RemarkGenerationInitial();
  }
}

// 4. Homework Generation Notifier
class HomeworkGenerationNotifier extends StateNotifier<HomeworkGenerationState> {
  final TeacherAiRemoteDatasource _datasource;

  HomeworkGenerationNotifier(this._datasource) : super(const HomeworkGenerationInitial());

  Future<void> generateHomework({
    required String classId,
    required String sectionId,
    required String subjectId,
    required String topic,
    required String difficulty,
    required int numberOfQuestions,
    required int marks,
    String? questionType,
  }) async {
    if (state is HomeworkGenerationLoading) return;

    state = const HomeworkGenerationLoading();
    final result = await _datasource.generateHomework(
      classId: classId,
      sectionId: sectionId,
      subjectId: subjectId,
      topic: topic,
      difficulty: difficulty,
      numberOfQuestions: numberOfQuestions,
      marks: marks,
      questionType: questionType,
    );
    result.when(
      onSuccess: (hw) {
        state = HomeworkGenerationSuccess(hw);
      },
      onFailure: (err) {
        state = HomeworkGenerationError(err.message);
      },
    );
  }
  
  void clearHomework() {
    state = const HomeworkGenerationInitial();
  }
}

// --- Providers exposure ---

final studentInsightNotifierProvider = StateNotifierProvider.family<StudentInsightNotifier, StudentInsightState, String>((ref, studentId) {
  final ds = ref.watch(teacherAiRemoteDatasourceProvider);
  return StudentInsightNotifier(ds);
});

final classAnalysisNotifierProvider = StateNotifierProvider<ClassAnalysisNotifier, ClassAnalysisState>((ref) {
  final ds = ref.watch(teacherAiRemoteDatasourceProvider);
  return ClassAnalysisNotifier(ds);
});

final remarkGenerationNotifierProvider = StateNotifierProvider<RemarkGenerationNotifier, RemarkGenerationState>((ref) {
  final ds = ref.watch(teacherAiRemoteDatasourceProvider);
  return RemarkGenerationNotifier(ds);
});

final homeworkGenerationNotifierProvider = StateNotifierProvider<HomeworkGenerationNotifier, HomeworkGenerationState>((ref) {
  final ds = ref.watch(teacherAiRemoteDatasourceProvider);
  return HomeworkGenerationNotifier(ds);
});
