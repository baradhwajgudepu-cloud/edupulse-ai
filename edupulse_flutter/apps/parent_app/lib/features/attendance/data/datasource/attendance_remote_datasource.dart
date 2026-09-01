import 'package:edupulse_network/edupulse_network.dart';
import '../models/attendance_dto.dart';

class AttendanceRemoteDatasource {
  final BaseApiClient _apiClient;

  const AttendanceRemoteDatasource(this._apiClient);

  Future<ApiResult<List<AttendanceDto>>> getAttendanceRecords({
    required String studentId,
    required String academicYearId,
    required String schoolId,
  }) {
    return _apiClient.get(
      '/attendances/student',
      queryParameters: {
        'student_id': studentId,
        'academic_year_id': academicYearId,
        'school_id': schoolId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list
            .map((item) => AttendanceDto.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );
  }
}
