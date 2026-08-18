import 'package:edupulse_network/edupulse_network.dart';
import '../entities/attendance_enums.dart';
import '../entities/attendance_response_entity.dart';
import '../entities/attendance_session_entity.dart';

class AttendanceRecordPayload {
  final String studentId;
  final AttendanceStatus attendanceStatus;
  final AttendanceSource attendanceSource;
  final AttendanceReason attendanceReason;
  final String? remarks;

  const AttendanceRecordPayload({
    required this.studentId,
    required this.attendanceStatus,
    this.attendanceSource = AttendanceSource.MANUAL,
    this.attendanceReason = AttendanceReason.UNKNOWN,
    this.remarks,
  });
}

abstract class AttendanceRepository {
  Future<ApiResult<AttendanceSessionEntity>> createSession({
    required String schoolId,
    required String academicYearId,
    required String timetableId,
    required String attendanceDate,
  });

  Future<ApiResult<AttendanceSessionEntity>> bulkMarkAttendance({
    required String schoolId,
    required String sessionId,
    required AttendanceSessionStatus sessionStatus,
    required List<AttendanceRecordPayload> records,
  });

  Future<ApiResult<List<AttendanceSessionEntity>>> getSessions({
    required String schoolId,
    String? academicYearId,
    String? classId,
    String? sectionId,
    String? attendanceDate,
    AttendanceSessionStatus? status,
  });

  Future<ApiResult<AttendanceSessionEntity>> getSessionDetails({
    required String schoolId,
    required String sessionId,
  });

  Future<ApiResult<AttendanceResponseEntity>> correctAttendance({
    required String schoolId,
    required String sessionId,
    required String studentId,
    required AttendanceStatus attendanceStatus,
    required String correctionReason,
    AttendanceSource? attendanceSource,
    AttendanceReason? attendanceReason,
    String? remarks,
  });
}
