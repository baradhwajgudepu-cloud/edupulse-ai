import 'package:edupulse_network/edupulse_network.dart';
import '../models/teacher_syllabus_models.dart';

class TeacherSyllabusRemoteDatasource {
  final BaseApiClient _apiClient;

  const TeacherSyllabusRemoteDatasource(this._apiClient);

  Future<ApiResult<List<TeacherSyllabusItem>>> getSyllabusItems({
    required String schoolId,
    required String classId,
    required String subjectId,
    String? academicYearId,
  }) {
    final queryParams = <String, dynamic>{
      'school_id': schoolId,
      'class_id': classId,
      'subject_id': subjectId,
      'limit': 200,
    };
    if (academicYearId != null) {
      queryParams['academic_year_id'] = academicYearId;
    }

    return _apiClient.get(
      '/syllabuses',
      queryParameters: queryParams,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = (payload['data'] as List<dynamic>?) ?? [];
        return list
            .map((item) => TeacherSyllabusItem.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<ApiResult<List<TeacherCoverageProgressItem>>> getSectionProgress({
    required String schoolId,
    required String academicYearId,
    required String sectionId,
    String? subjectId,
  }) {
    final queryParams = <String, dynamic>{
      'school_id': schoolId,
      'academic_year_id': academicYearId,
      'section_id': sectionId,
    };
    if (subjectId != null) {
      queryParams['subject_id'] = subjectId;
    }

    return _apiClient.get(
      '/syllabuses/coverage/progress',
      queryParameters: queryParams,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = (payload['data'] as List<dynamic>?) ?? [];
        return list
            .map((item) => TeacherCoverageProgressItem.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<ApiResult<TeacherSyllabusPrediction?>> getPrediction({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String subjectId,
    required String sectionId,
  }) {
    return _apiClient.get(
      '/academic-planning/predictions',
      queryParameters: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'class_id': classId,
        'subject_id': subjectId,
        'section_id': sectionId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = (payload['data'] as List<dynamic>?) ?? [];
        if (list.isEmpty) return null;
        return TeacherSyllabusPrediction.fromJson(list.first as Map<String, dynamic>);
      },
    );
  }

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
  }) {
    final queryParams = <String, dynamic>{
      'school_id': schoolId,
      'academic_year_id': academicYearId,
      'syllabus_id': syllabusId,
      'section_id': sectionId,
    };
    if (teacherId != null && teacherId.isNotEmpty) {
      queryParams['teacher_id'] = teacherId;
    }

    final body = <String, dynamic>{
      'status': status,
      'completion_percentage': completionPercentage,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
    };

    return _apiClient.post(
      '/syllabuses/coverage/progress',
      queryParameters: queryParams,
      data: body,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final data = payload['data'] as Map<String, dynamic>;
        return TeacherCoverageProgressItem.fromJson(data);
      },
    );
  }
}
