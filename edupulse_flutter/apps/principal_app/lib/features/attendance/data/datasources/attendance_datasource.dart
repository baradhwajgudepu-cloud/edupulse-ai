import 'package:edupulse_network/edupulse_network.dart';

class AttendanceDatasource {
  final BaseApiClient _apiClient;

  AttendanceDatasource(this._apiClient);

  Future<ApiResult<List<Map<String, dynamic>>>> getDailyAttendance({
    required String schoolId,
    required String date,
  }) async {
    return _apiClient.get<List<Map<String, dynamic>>>(
      '/attendances/daily',
      queryParameters: {
        'school_id': schoolId,
        'attendance_date': date,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((e) => e as Map<String, dynamic>).toList();
      },
    );
  }
}
