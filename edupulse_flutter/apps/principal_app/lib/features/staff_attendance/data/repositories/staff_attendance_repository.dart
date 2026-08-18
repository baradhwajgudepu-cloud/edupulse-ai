import 'package:edupulse_network/edupulse_network.dart';
import '../datasources/staff_attendance_datasource.dart';
import '../models/staff_attendance_model.dart';

class StaffAttendanceRepository {
  final StaffAttendanceDatasource _datasource;

  StaffAttendanceRepository(this._datasource);

  Future<ApiResult<StaffDailyAttendanceSummary>> getDailyStaffAttendance({
    required String schoolId,
    required String date,
  }) async {
    final result = await _datasource.getDailyStaffAttendance(schoolId: schoolId, date: date);
    return result.when(
      onSuccess: (map) {
        final summary = StaffDailyAttendanceSummary.fromJson(map);
        return ApiResult.success(summary);
      },
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  Future<ApiResult<List<StaffAttendanceHistoryItem>>> getTeacherAttendanceHistory({
    required String teacherId,
    String? startDate,
    String? endDate,
    int skip = 0,
    int limit = 100,
  }) async {
    final result = await _datasource.getTeacherAttendanceHistory(
      teacherId: teacherId,
      startDate: startDate,
      endDate: endDate,
      skip: skip,
      limit: limit,
    );
    return result.when(
      onSuccess: (list) {
        final history = list.map((e) => StaffAttendanceHistoryItem.fromJson(e as Map<String, dynamic>)).toList();
        return ApiResult.success(history);
      },
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  Future<ApiResult<SchoolGeofenceModel>> getSchoolGeofence({
    required String schoolId,
  }) async {
    final result = await _datasource.getSchoolGeofence(schoolId: schoolId);
    return result.when(
      onSuccess: (map) {
        final model = SchoolGeofenceModel.fromJson(map);
        return ApiResult.success(model);
      },
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  Future<ApiResult<SchoolGeofenceModel>> updateSchoolGeofence({
    required String schoolId,
    required double latitude,
    required double longitude,
    required int radius,
  }) async {
    final result = await _datasource.updateSchoolGeofence(
      schoolId: schoolId,
      latitude: latitude,
      longitude: longitude,
      radius: radius,
    );
    return result.when(
      onSuccess: (map) {
        final model = SchoolGeofenceModel.fromJson(map);
        return ApiResult.success(model);
      },
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }
}
