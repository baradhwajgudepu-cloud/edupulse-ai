import 'package:edupulse_network/edupulse_network.dart';
import '../entities/staff_attendance_entity.dart';

abstract class StaffAttendanceRepository {
  Future<ApiResult<StaffAttendanceEntity?>> getTodayStatus();

  Future<ApiResult<StaffAttendanceEntity>> checkIn({
    required double latitude,
    required double longitude,
    required bool isMocked,
    String? remarks,
  });

  Future<ApiResult<StaffAttendanceEntity>> checkOut({
    required double latitude,
    required double longitude,
    required bool isMocked,
    String? remarks,
  });
}
