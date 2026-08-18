import 'package:edupulse_network/edupulse_network.dart';
import '../models/attendance_session_dto.dart';
import '../models/attendance_response_dto.dart';

class AttendanceRemoteDatasource {
  final BaseApiClient _apiClient;

  const AttendanceRemoteDatasource(this._apiClient);

  Future<ApiResult<AttendanceSessionDto>> createSession({
    required String schoolId,
    required String academicYearId,
    required String timetableId,
    required String attendanceDate,
  }) {
    return _apiClient.post(
      '/attendances/session',
      data: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'timetable_id': timetableId,
        'attendance_date': attendanceDate,
        'settings': {},
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return AttendanceSessionDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }

  Future<ApiResult<AttendanceSessionDto>> bulkMarkAttendance({
    required String schoolId,
    required String sessionId,
    required String sessionStatus,
    required List<Map<String, dynamic>> records,
  }) {
    return _apiClient.post(
      '/attendances/session/$sessionId/mark',
      queryParameters: {
        'school_id': schoolId,
      },
      data: {
        'attendance_session_status': sessionStatus,
        'records': records,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return AttendanceSessionDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }

  Future<ApiResult<List<AttendanceSessionDto>>> getSessions({
    required String schoolId,
    String? academicYearId,
    String? classId,
    String? sectionId,
    String? attendanceDate,
    String? status,
  }) {
    final queryParams = <String, dynamic>{
      'school_id': schoolId,
    };
    if (academicYearId != null) queryParams['academic_year_id'] = academicYearId;
    if (classId != null) queryParams['class_id'] = classId;
    if (sectionId != null) queryParams['section_id'] = sectionId;
    if (attendanceDate != null) queryParams['attendance_date'] = attendanceDate;
    if (status != null) queryParams['status'] = status;

    return _apiClient.get(
      '/attendances/sessions',
      queryParameters: queryParams,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list
            .map((item) => AttendanceSessionDto.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<ApiResult<AttendanceSessionDto>> getSessionDetails({
    required String schoolId,
    required String sessionId,
  }) {
    return _apiClient.get(
      '/attendances/session/$sessionId',
      queryParameters: {
        'school_id': schoolId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return AttendanceSessionDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }

  Future<ApiResult<AttendanceResponseDto>> correctAttendance({
    required String schoolId,
    required String sessionId,
    required String studentId,
    required String attendanceStatus,
    required String correctionReason,
    String? attendanceSource,
    String? attendanceReason,
    String? remarks,
  }) {
    final data = <String, dynamic>{
      'attendance_status': attendanceStatus,
      'correction_reason': correctionReason,
    };
    if (attendanceSource != null) data['attendance_source'] = attendanceSource;
    if (attendanceReason != null) data['attendance_reason'] = attendanceReason;
    if (remarks != null) data['remarks'] = remarks;

    return _apiClient.put(
      '/attendances/session/$sessionId/student/$studentId',
      queryParameters: {
        'school_id': schoolId,
      },
      data: data,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return AttendanceResponseDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }
}
