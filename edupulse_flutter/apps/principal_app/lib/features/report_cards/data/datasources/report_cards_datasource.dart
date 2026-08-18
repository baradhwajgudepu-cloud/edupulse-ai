import 'package:edupulse_network/edupulse_network.dart';

class ReportCardsDatasource {
  final BaseApiClient _apiClient;

  ReportCardsDatasource(this._apiClient);

  Future<ApiResult<List<Map<String, dynamic>>>> getReportCards({
    required String schoolId,
    String? status,
  }) async {
    final Map<String, dynamic> queryParameters = {
      'school_id': schoolId,
    };
    if (status != null && status.isNotEmpty) {
      queryParameters['status'] = status;
    }

    return _apiClient.get<List<Map<String, dynamic>>>(
      '/report-cards',
      queryParameters: queryParameters,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((e) => e as Map<String, dynamic>).toList();
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> approveReportCard({
    required String id,
    required String schoolId,
  }) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/report-cards/$id/approve',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? {};
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> lockReportCard({
    required String id,
    required String schoolId,
  }) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/report-cards/$id/lock',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? {};
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> unlockReportCard({
    required String id,
    required String schoolId,
  }) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/report-cards/$id/unlock',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? {};
      },
    );
  }

  Future<ApiResult<List<Map<String, dynamic>>>> publishReportCards({
    required String schoolId,
    required String classId,
    required String sectionId,
  }) async {
    return _apiClient.post<List<Map<String, dynamic>>>(
      '/report-cards/publish',
      queryParameters: {
        'school_id': schoolId,
        'class_id': classId,
        'section_id': sectionId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((e) => e as Map<String, dynamic>).toList();
      },
    );
  }
}
