import 'package:edupulse_network/edupulse_network.dart';

class StudentDatasource {
  final BaseApiClient _apiClient;

  StudentDatasource(this._apiClient);

  Future<ApiResult<List<Map<String, dynamic>>>> getStudents({
    required String schoolId,
    int skip = 0,
    int limit = 100,
    String? search,
    String? classId,
    String? sectionId,
  }) async {
    final Map<String, dynamic> queryParameters = {
      'school_id': schoolId,
      'skip': skip,
      'limit': limit,
    };
    if (search != null && search.isNotEmpty) {
      queryParameters['search'] = search;
    }
    if (classId != null && classId.isNotEmpty) {
      queryParameters['class_id'] = classId;
    }
    if (sectionId != null && sectionId.isNotEmpty) {
      queryParameters['section_id'] = sectionId;
    }

    return _apiClient.get<List<Map<String, dynamic>>>(
      '/students',
      queryParameters: queryParameters,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((e) => e as Map<String, dynamic>).toList();
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> getStudentById(String id, String schoolId) async {
    return _apiClient.get<Map<String, dynamic>>(
      '/students/$id',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? {};
      },
    );
  }
}
