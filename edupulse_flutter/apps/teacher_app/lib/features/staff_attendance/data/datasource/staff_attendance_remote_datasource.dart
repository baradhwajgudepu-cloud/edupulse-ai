import 'package:edupulse_network/edupulse_network.dart';
import '../models/staff_attendance_dto.dart';

class StaffAttendanceRemoteDatasource {
  final BaseApiClient _apiClient;

  const StaffAttendanceRemoteDatasource(this._apiClient);

  Future<ApiResult<StaffAttendanceDto?>> getTodayStatus() {
    return _apiClient.get(
      '/staff-attendance/status',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final data = payload['data'];
        if (data == null) return null;
        return StaffAttendanceDto.fromJson(data as Map<String, dynamic>);
      },
    );
  }

  Future<ApiResult<StaffAttendanceDto>> checkIn({
    required double latitude,
    required double longitude,
    required bool isMocked,
    String? remarks,
  }) {
    return _apiClient.post(
      '/staff-attendance/check-in',
      data: {
        'latitude': latitude,
        'longitude': longitude,
        'is_mocked': isMocked,
        if (remarks != null) 'remarks': remarks,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return StaffAttendanceDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }

  Future<ApiResult<StaffAttendanceDto>> checkOut({
    required double latitude,
    required double longitude,
    required bool isMocked,
    String? remarks,
  }) {
    return _apiClient.post(
      '/staff-attendance/check-out',
      data: {
        'latitude': latitude,
        'longitude': longitude,
        'is_mocked': isMocked,
        if (remarks != null) 'remarks': remarks,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return StaffAttendanceDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }
}
