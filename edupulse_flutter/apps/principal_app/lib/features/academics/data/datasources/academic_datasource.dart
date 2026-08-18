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
}
