import 'package:edupulse_network/edupulse_network.dart';
import '../../domain/entities/staff_attendance_entity.dart';
import '../../domain/repositories/staff_attendance_repository.dart';
import '../datasource/staff_attendance_remote_datasource.dart';
import '../models/staff_attendance_dto.dart';

class StaffAttendanceRepositoryImpl implements StaffAttendanceRepository {
  final StaffAttendanceRemoteDatasource _remoteDatasource;

  const StaffAttendanceRepositoryImpl(this._remoteDatasource);

  @override
  Future<ApiResult<StaffAttendanceEntity?>> getTodayStatus() async {
    final result = await _remoteDatasource.getTodayStatus();
    return result.when(
      onSuccess: (dto) => ApiResult.success(dto?.toEntity()),
      onFailure: (error) => ApiResult.failure(error),
    );
  }

  @override
  Future<ApiResult<StaffAttendanceEntity>> checkIn({
    required double latitude,
    required double longitude,
    required bool isMocked,
    String? remarks,
  }) async {
    final result = await _remoteDatasource.checkIn(
      latitude: latitude,
      longitude: longitude,
      isMocked: isMocked,
      remarks: remarks,
    );
    return result.when(
      onSuccess: (dto) => ApiResult.success(dto.toEntity()),
      onFailure: (error) => ApiResult.failure(error),
    );
  }

  @override
  Future<ApiResult<StaffAttendanceEntity>> checkOut({
    required double latitude,
    required double longitude,
    required bool isMocked,
    String? remarks,
  }) async {
    final result = await _remoteDatasource.checkOut(
      latitude: latitude,
      longitude: longitude,
      isMocked: isMocked,
      remarks: remarks,
    );
    return result.when(
      onSuccess: (dto) => ApiResult.success(dto.toEntity()),
      onFailure: (error) => ApiResult.failure(error),
    );
  }
}
