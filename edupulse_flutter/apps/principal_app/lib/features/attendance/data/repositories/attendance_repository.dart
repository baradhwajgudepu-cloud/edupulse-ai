import 'package:edupulse_network/edupulse_network.dart';
import '../datasources/attendance_datasource.dart';
import '../models/attendance_model.dart';

class AttendanceRepository {
  final AttendanceDatasource _datasource;

  AttendanceRepository(this._datasource);

  Future<ApiResult<List<AttendanceRecord>>> getDailyAttendance({
    required String schoolId,
    required String date,
  }) async {
    final result = await _datasource.getDailyAttendance(schoolId: schoolId, date: date);
    return result.when(
      onSuccess: (list) {
        final records = list.map((e) => AttendanceRecord.fromJson(e)).toList();
        return ApiResult.success(records);
      },
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }
}
