import 'package:edupulse_network/edupulse_network.dart';
import '../entities/attendance_record.dart';

abstract class AttendanceRepository {
  Future<ApiResult<List<AttendanceRecordEntity>>> getAttendanceRecords({
    required String studentId,
    required String academicYearId,
    required String schoolId,
  });
}
