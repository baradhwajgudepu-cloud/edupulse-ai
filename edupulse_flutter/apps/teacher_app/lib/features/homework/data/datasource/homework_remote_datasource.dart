import 'package:edupulse_network/edupulse_network.dart';
import '../models/homework_dto.dart';

class HomeworkRemoteDatasource {
  final BaseApiClient _apiClient;

  const HomeworkRemoteDatasource(this._apiClient);

  Future<ApiResult<HomeworkDto>> createHomework({
    required String schoolId,
    required String academicYearId,
    required String teacherId,
    required String teacherSubjectAssignmentId,
    required String subjectId,
    required String classId,
    required String sectionId,
    String? timetableId,
    required String title,
    required String description,
    required String dueDate,
    required String priority,
    required String status,
    String? attachmentUrl,
    int? estimatedMinutes,
  }) {
    final data = <String, dynamic>{
      'school_id': schoolId,
      'academic_year_id': academicYearId,
      'teacher_id': teacherId,
      'teacher_subject_assignment_id': teacherSubjectAssignmentId,
      'subject_id': subjectId,
      'class_id': classId,
      'section_id': sectionId,
      'title': title,
      'description': description,
      'due_date': dueDate,
      'priority': priority,
      'status': status,
    };
    if (timetableId != null) data['timetable_id'] = timetableId;
    if (attachmentUrl != null) data['attachment_url'] = attachmentUrl;
    if (estimatedMinutes != null) data['estimated_minutes'] = estimatedMinutes;

    return _apiClient.post(
      '/homeworks',
      data: data,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return HomeworkDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }

  Future<ApiResult<HomeworkDto>> createFromTimetable({
    required String schoolId,
    required String timetableId,
    required String title,
    required String description,
    required String dueDate,
    required String priority,
    required String status,
    String? attachmentUrl,
    int? estimatedMinutes,
  }) {
    final data = <String, dynamic>{
      'title': title,
      'description': description,
      'due_date': dueDate,
      'priority': priority,
      'status': status,
    };
    if (attachmentUrl != null) data['attachment_url'] = attachmentUrl;
    if (estimatedMinutes != null) data['estimated_minutes'] = estimatedMinutes;

    return _apiClient.post(
      '/homeworks/timetable/$timetableId',
      queryParameters: {
        'school_id': schoolId,
      },
      data: data,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return HomeworkDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }

  Future<ApiResult<List<HomeworkDto>>> copyHomework({
    required String schoolId,
    required String homeworkId,
    required List<String> targetSectionIds,
  }) {
    return _apiClient.post(
      '/homeworks/copy',
      queryParameters: {
        'school_id': schoolId,
      },
      data: {
        'homework_id': homeworkId,
        'target_section_ids': targetSectionIds,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list
            .map((item) => HomeworkDto.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<ApiResult<HomeworkDto>> publishHomework({
    required String schoolId,
    required String id,
  }) {
    return _apiClient.post(
      '/homeworks/$id/publish',
      queryParameters: {
        'school_id': schoolId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return HomeworkDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }

  Future<ApiResult<List<HomeworkDto>>> getRecentHomework({
    required String schoolId,
  }) {
    return _apiClient.get(
      '/homeworks/recent',
      queryParameters: {
        'school_id': schoolId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list
            .map((item) => HomeworkDto.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<ApiResult<List<String>>> getTemplates({
    required String schoolId,
    String? subjectId,
  }) {
    final queryParams = <String, dynamic>{
      'school_id': schoolId,
    };
    if (subjectId != null) queryParams['subject_id'] = subjectId;

    return _apiClient.get(
      '/homeworks/templates',
      queryParameters: queryParams,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list.map((item) => item.toString()).toList();
      },
    );
  }

  Future<ApiResult<HomeworkDto>> getHomeworkById({
    required String schoolId,
    required String id,
  }) {
    return _apiClient.get(
      '/homeworks/$id',
      queryParameters: {
        'school_id': schoolId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return HomeworkDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }

  Future<ApiResult<List<HomeworkDto>>> listHomeworks({
    required String schoolId,
    String? academicYearId,
    String? classId,
    String? sectionId,
    String? subjectId,
    String? teacherId,
    String? status,
    String? search,
    int skip = 0,
    int limit = 100,
  }) {
    final queryParams = <String, dynamic>{
      'school_id': schoolId,
      'skip': skip,
      'limit': limit,
    };
    if (academicYearId != null) queryParams['academic_year_id'] = academicYearId;
    if (classId != null) queryParams['class_id'] = classId;
    if (sectionId != null) queryParams['section_id'] = sectionId;
    if (subjectId != null) queryParams['subject_id'] = subjectId;
    if (teacherId != null) queryParams['teacher_id'] = teacherId;
    if (status != null) queryParams['status'] = status;
    if (search != null) queryParams['search'] = search;

    return _apiClient.get(
      '/homeworks',
      queryParameters: queryParams,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list
            .map((item) => HomeworkDto.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<ApiResult<HomeworkDto>> updateHomework({
    required String schoolId,
    required String id,
    String? title,
    String? description,
    String? dueDate,
    String? priority,
    String? status,
    String? attachmentUrl,
    int? estimatedMinutes,
  }) {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (description != null) data['description'] = description;
    if (dueDate != null) data['due_date'] = dueDate;
    if (priority != null) data['priority'] = priority;
    if (status != null) data['status'] = status;
    if (attachmentUrl != null) data['attachment_url'] = attachmentUrl;
    if (estimatedMinutes != null) data['estimated_minutes'] = estimatedMinutes;

    return _apiClient.put(
      '/homeworks/$id',
      queryParameters: {
        'school_id': schoolId,
      },
      data: data,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return HomeworkDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }

  Future<ApiResult<HomeworkDto>> deleteHomework({
    required String schoolId,
    required String id,
  }) {
    return _apiClient.delete(
      '/homeworks/$id',
      queryParameters: {
        'school_id': schoolId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return HomeworkDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }
}
