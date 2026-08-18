import 'package:edupulse_network/edupulse_network.dart';
import '../../domain/entities/attendance_enums.dart';
import '../../domain/entities/attendance_response_entity.dart';
import '../../domain/entities/attendance_session_entity.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../datasource/attendance_remote_datasource.dart';
import '../models/attendance_session_dto.dart';
import '../models/attendance_response_dto.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  final AttendanceRemoteDatasource _remoteDatasource;

  const AttendanceRepositoryImpl(this._remoteDatasource);

  @override
  Future<ApiResult<AttendanceSessionEntity>> createSession({
    required String schoolId,
    required String academicYearId,
    required String timetableId,
    required String attendanceDate,
  }) async {
    final result = await _remoteDatasource.createSession(
      schoolId: schoolId,
      academicYearId: academicYearId,
      timetableId: timetableId,
      attendanceDate: attendanceDate,
    );

    return result.when(
      onSuccess: (dto) => ApiResult.success(dto.toEntity()),
      onFailure: (err) => ApiResult.failure(err),
    );
  }

  @override
  Future<ApiResult<AttendanceSessionEntity>> bulkMarkAttendance({
    required String schoolId,
    required String sessionId,
    required AttendanceSessionStatus sessionStatus,
    required List<AttendanceRecordPayload> records,
  }) async {
    final recordMaps = records.map((rec) {
      final map = <String, dynamic>{
        'student_id': rec.studentId,
        'attendance_status': rec.attendanceStatus.name,
        'attendance_source': rec.attendanceSource.name,
        'attendance_reason': rec.attendanceReason.name,
      };
      if (rec.remarks != null) {
        map['remarks'] = rec.remarks!;
      }
      return map;
    }).toList();

    final result = await _remoteDatasource.bulkMarkAttendance(
      schoolId: schoolId,
      sessionId: sessionId,
      sessionStatus: sessionStatus.name,
      records: recordMaps,
    );

    return result.when(
      onSuccess: (dto) => ApiResult.success(dto.toEntity()),
      onFailure: (err) => ApiResult.failure(err),
    );
  }

  @override
  Future<ApiResult<List<AttendanceSessionEntity>>> getSessions({
    required String schoolId,
    String? academicYearId,
    String? classId,
    String? sectionId,
    String? attendanceDate,
    AttendanceSessionStatus? status,
  }) async {
    final result = await _remoteDatasource.getSessions(
      schoolId: schoolId,
      academicYearId: academicYearId,
      classId: classId,
      sectionId: sectionId,
      attendanceDate: attendanceDate,
      status: status?.name,
    );

    return result.when(
      onSuccess: (list) => ApiResult.success(list.map((dto) => dto.toEntity()).toList()),
      onFailure: (err) => ApiResult.failure(err),
    );
  }

  @override
  Future<ApiResult<AttendanceSessionEntity>> getSessionDetails({
    required String schoolId,
    required String sessionId,
  }) async {
    final result = await _remoteDatasource.getSessionDetails(
      schoolId: schoolId,
      sessionId: sessionId,
    );

    return result.when(
      onSuccess: (dto) => ApiResult.success(dto.toEntity()),
      onFailure: (err) => ApiResult.failure(err),
    );
  }

  @override
  Future<ApiResult<AttendanceResponseEntity>> correctAttendance({
    required String schoolId,
    required String sessionId,
    required String studentId,
    required AttendanceStatus attendanceStatus,
    required String correctionReason,
    AttendanceSource? attendanceSource,
    AttendanceReason? attendanceReason,
    String? remarks,
  }) async {
    final result = await _remoteDatasource.correctAttendance(
      schoolId: schoolId,
      sessionId: sessionId,
      studentId: studentId,
      attendanceStatus: attendanceStatus.name,
      correctionReason: correctionReason,
      attendanceSource: attendanceSource?.name,
      attendanceReason: attendanceReason?.name,
      remarks: remarks,
    );

    return result.when(
      onSuccess: (dto) => ApiResult.success(dto.toEntity()),
      onFailure: (err) => ApiResult.failure(err),
    );
  }
}
