import 'package:edupulse_network/edupulse_network.dart';

class HomeworkDatasource {
  final BaseApiClient _apiClient;

  HomeworkDatasource(this._apiClient);

  Future<ApiResult<List<Map<String, dynamic>>>> getHomeworks({
    required String schoolId,
    int skip = 0,
    int limit = 100,
  }) async {
    return _apiClient.get<List<Map<String, dynamic>>>(
      '/homeworks',
      queryParameters: {
        'school_id': schoolId,
        'skip': skip,
        'limit': limit,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((e) => e as Map<String, dynamic>).toList();
      },
    );
  }
}
