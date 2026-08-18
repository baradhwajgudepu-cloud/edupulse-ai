import 'package:edupulse_network/edupulse_network.dart';

class TeacherDatasource {
  final BaseApiClient _apiClient;

  TeacherDatasource(this._apiClient);

  Future<ApiResult<List<Map<String, dynamic>>>> getTeachers({
    required String schoolId,
    int skip = 0,
    int limit = 100,
    String? search,
  }) async {
    final Map<String, dynamic> queryParameters = {
      'school_id': schoolId,
      'skip': skip,
      'limit': limit,
    };
    if (search != null && search.isNotEmpty) {
      queryParameters['search'] = search;
    }

    return _apiClient.get<List<Map<String, dynamic>>>(
      '/teachers',
      queryParameters: queryParameters,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((e) => e as Map<String, dynamic>).toList();
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> getTeacherById(String id, String schoolId) async {
    return _apiClient.get<Map<String, dynamic>>(
      '/teachers/$id',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? {};
      },
    );
  }
}
