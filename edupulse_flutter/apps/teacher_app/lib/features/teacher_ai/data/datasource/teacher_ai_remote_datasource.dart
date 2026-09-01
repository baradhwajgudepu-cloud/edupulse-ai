import 'package:dio/dio.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../models/teacher_ai_dtos.dart';

class TeacherAiRemoteDatasource {
  final BaseApiClient _apiClient;

  const TeacherAiRemoteDatasource(this._apiClient);

  Future<ApiResult<StudentInsightDto>> getStudentInsight({
    required String studentId,
  }) {
    return _apiClient.post(
      '/teacher-ai/student-insight',
      options: Options(
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
      ),
      data: {'student_id': studentId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return StudentInsightDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }

  Future<ApiResult<ClassAnalysisDto>> getClassAnalysis({
    required String classId,
    required String sectionId,
    required String subjectId,
  }) {
    return _apiClient.post(
      '/teacher-ai/class-analysis',
      options: Options(
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
      ),
      data: {
        'class_id': classId,
        'section_id': sectionId,
        'subject_id': subjectId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return ClassAnalysisDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }

  Future<ApiResult<RemarkGenerationDto>> generateRemark({
    required String studentId,
    required String subjectId,
  }) {
    return _apiClient.post(
      '/teacher-ai/generate-remark',
      options: Options(
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
      ),
      data: {
        'student_id': studentId,
        'subject_id': subjectId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return RemarkGenerationDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }

  Future<ApiResult<HomeworkGenerationDto>> generateHomework({
    required String classId,
    required String sectionId,
    required String subjectId,
    required String topic,
    required String difficulty,
    required int numberOfQuestions,
    required int marks,
    String? questionType,
  }) {
    return _apiClient.post(
      '/teacher-ai/generate-homework',
      options: Options(
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
      ),
      data: {
        'class_id': classId,
        'section_id': sectionId,
        'subject_id': subjectId,
        'topic': topic,
        'difficulty': difficulty,
        'number_of_questions': numberOfQuestions,
        'marks': marks,
        if (questionType != null) 'question_type': questionType,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return HomeworkGenerationDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }

  Future<ApiResult<QuestionsGenerationDto>> generateQuestions({
    required String classId,
    required String sectionId,
    required String subjectId,
    required String topic,
    required String difficulty,
    required int numberOfQuestions,
    required int marks,
    String? questionType,
  }) {
    return _apiClient.post(
      '/teacher-ai/generate-questions',
      options: Options(
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
      ),
      data: {
        'class_id': classId,
        'section_id': sectionId,
        'subject_id': subjectId,
        'topic': topic,
        'difficulty': difficulty,
        'number_of_questions': numberOfQuestions,
        'marks': marks,
        if (questionType != null) 'question_type': questionType,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return QuestionsGenerationDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }
}
