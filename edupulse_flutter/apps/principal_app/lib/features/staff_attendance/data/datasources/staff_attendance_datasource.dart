import 'package:edupulse_network/edupulse_network.dart';

class StaffAttendanceDatasource {
  final BaseApiClient _apiClient;

  StaffAttendanceDatasource(this._apiClient);

  Future<ApiResult<Map<String, dynamic>>> getDailyStaffAttendance({
    required String schoolId,
    required String date,
  }) async {
    return _apiClient.get<Map<String, dynamic>>(
      '/staff-attendance/daily',
      queryParameters: {
        'school_id': schoolId,
        'attendance_date': date,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>;
      },
    );
  }

  Future<ApiResult<List<dynamic>>> getTeacherAttendanceHistory({
    required String teacherId,
    String? startDate,
    String? endDate,
    int skip = 0,
    int limit = 100,
  }) async {
    final Map<String, dynamic> params = {
      'skip': skip,
      'limit': limit,
    };
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;

    return _apiClient.get<List<dynamic>>(
      '/staff-attendance/teacher/$teacherId/history',
      queryParameters: params,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as List<dynamic>;
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> getSchoolGeofence({
    required String schoolId,
  }) async {
    return _apiClient.get<Map<String, dynamic>>(
      '/schools/$schoolId',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>;
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> updateSchoolGeofence({
    required String schoolId,
    required double latitude,
    required double longitude,
    required int radius,
  }) async {
    return _apiClient.put<Map<String, dynamic>>(
      '/schools/$schoolId',
      data: {
        'latitude': latitude,
        'longitude': longitude,
        'geofence_radius_meters': radius,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>;
      },
    );
  }
}
