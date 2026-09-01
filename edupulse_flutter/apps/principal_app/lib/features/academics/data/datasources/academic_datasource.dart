import 'package:edupulse_network/edupulse_network.dart';

class AcademicDatasource {
  final BaseApiClient _apiClient;

  AcademicDatasource(this._apiClient);

  Future<ApiResult<List<Map<String, dynamic>>>> getExaminations({
    required String schoolId,
  }) async {
    return _apiClient.get<List<Map<String, dynamic>>>(
      '/examinations',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((e) => e as Map<String, dynamic>).toList();
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> getMarksSummary({
    required String schoolId,
    required String examScheduleId,
  }) async {
    return _apiClient.get<Map<String, dynamic>>(
      '/marks/summary',
      queryParameters: {
        'school_id': schoolId,
        'exam_schedule_id': examScheduleId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? {};
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> createExamination({
    required Map<String, dynamic> data,
  }) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/examinations',
      data: data,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? {};
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> publishExamination({
    required String id,
    required String schoolId,
  }) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/examinations/$id/publish',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? {};
      },
    );
  }

  Future<ApiResult<List<Map<String, dynamic>>>> getClasses({
    required String schoolId,
  }) async {
    return _apiClient.get<List<Map<String, dynamic>>>(
      '/classes',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((e) => e as Map<String, dynamic>).toList();
      },
    );
  }

  Future<ApiResult<List<Map<String, dynamic>>>> getAcademicYears({
    required String schoolId,
  }) async {
    return _apiClient.get<List<Map<String, dynamic>>>(
      '/schools/$schoolId/academic-years',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((e) => e as Map<String, dynamic>).toList();
      },
    );
  }

  Future<ApiResult<List<Map<String, dynamic>>>> getSections({
    required String schoolId,
    String? classId,
  }) async {
    final query = {'school_id': schoolId};
    if (classId != null) {
      query['class_id'] = classId;
    }
    return _apiClient.get<List<Map<String, dynamic>>>(
      '/sections',
      queryParameters: query,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((e) => e as Map<String, dynamic>).toList();
      },
    );
  }

  Future<ApiResult<List<Map<String, dynamic>>>> getSuggestedSchedules({
    required String schoolId,
    required List<String> classIds,
    required String startDate,
    required String endDate,
  }) async {
    return _apiClient.get<List<Map<String, dynamic>>>(
      '/examinations/wizard/suggest',
      queryParameters: {
        'school_id': schoolId,
        'class_ids': classIds,
        'start_date': startDate,
        'end_date': endDate,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((e) => e as Map<String, dynamic>).toList();
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> createExaminationWizard({
    required Map<String, dynamic> data,
  }) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/examinations/wizard',
      data: data,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? {};
      },
    );
  }
}

