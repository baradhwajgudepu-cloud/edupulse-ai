import 'package:edupulse_network/edupulse_network.dart';
import '../../domain/entities/teacher_leave_entity.dart';
import '../../domain/repositories/teacher_leave_repository.dart';
import '../datasource/teacher_leave_remote_datasource.dart';
import '../models/teacher_leave_dto.dart';

class TeacherLeaveRepositoryImpl implements TeacherLeaveRepository {
  final TeacherLeaveRemoteDatasource _remoteDatasource;

  const TeacherLeaveRepositoryImpl(this._remoteDatasource);

  @override
  Future<ApiResult<TeacherLeaveEntity>> createLeave({
    required String leaveType,
    required String startDate,
    required String endDate,
    required String reason,
    String? remarks,
  }) async {
    final result = await _remoteDatasource.createLeave(
      leaveType: leaveType,
      startDate: startDate,
      endDate: endDate,
      reason: reason,
      remarks: remarks,
    );
    return result.when(
      onSuccess: (dto) => ApiResult.success(dto.toEntity()),
      onFailure: (error) => ApiResult.failure(error),
    );
  }

  @override
  Future<ApiResult<List<TeacherLeaveEntity>>> getMyLeaves() async {
    final result = await _remoteDatasource.getMyLeaves();
    return result.when(
      onSuccess: (list) => ApiResult.success(list.map((dto) => dto.toEntity()).toList()),
      onFailure: (error) => ApiResult.failure(error),
    );
  }

  @override
  Future<ApiResult<TeacherLeaveEntity>> getLeave(String leaveId) async {
    final result = await _remoteDatasource.getLeave(leaveId);
    return result.when(
      onSuccess: (dto) => ApiResult.success(dto.toEntity()),
      onFailure: (error) => ApiResult.failure(error),
    );
  }

  @override
  Future<ApiResult<TeacherLeaveEntity>> cancelLeave({
    required String leaveId,
    required String cancellationReason,
  }) async {
    final result = await _remoteDatasource.cancelLeave(
      leaveId: leaveId,
      cancellationReason: cancellationReason,
    );
    return result.when(
      onSuccess: (dto) => ApiResult.success(dto.toEntity()),
      onFailure: (error) => ApiResult.failure(error),
    );
  }
}
