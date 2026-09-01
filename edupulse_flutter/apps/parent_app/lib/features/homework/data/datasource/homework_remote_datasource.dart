import 'package:edupulse_network/edupulse_network.dart';
import '../models/homework_dto.dart';

class HomeworkRemoteDatasource {
  final BaseApiClient _apiClient;

  const HomeworkRemoteDatasource(this._apiClient);

  Future<ApiResult<List<HomeworkDto>>> getHomeworkRecords({
    required String schoolId,
  }) {
    return _apiClient.get(
      '/homeworks/parent',
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
}
