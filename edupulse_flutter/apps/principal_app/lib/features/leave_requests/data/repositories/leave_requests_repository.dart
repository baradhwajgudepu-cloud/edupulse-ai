import 'package:edupulse_network/edupulse_network.dart';
import '../datasources/leave_requests_datasource.dart';
import '../models/leave_request_model.dart';

class LeaveRequestsRepository {
  final LeaveRequestsDatasource _datasource;

  LeaveRequestsRepository(this._datasource);

  Future<ApiResult<List<LeaveRequest>>> getLeaveRequests({
    required String schoolId,
    String? status,
    String? leaveType,
    String? startDate,
    String? endDate,
    int skip = 0,
    int limit = 20,
  }) async {
    final result = await _datasource.getLeaveRequests(
      schoolId: schoolId,
      status: status,
      leaveType: leaveType,
      startDate: startDate,
      endDate: endDate,
      skip: skip,
      limit: limit,
    );
    return result.when(
      onSuccess: (list) {
        final records = list.map((e) => LeaveRequest.fromJson(e)).toList();
        return ApiResult.success(records);
      },
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  Future<ApiResult<LeaveRequest>> getTeacherLeave(String leaveId) async {
    final result = await _datasource.getTeacherLeave(leaveId);
    return result.when(
      onSuccess: (map) {
        final record = LeaveRequest.fromJson(map);
        return ApiResult.success(record);
      },
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  Future<ApiResult<LeaveRequest>> reviewLeaveRequest({
    required String leaveId,
    required String decision,
    String? remarks,
  }) async {
    final result = await _datasource.reviewLeaveRequest(
      leaveId: leaveId,
      decision: decision,
      remarks: remarks,
    );
    return result.when(
      onSuccess: (map) {
        final record = LeaveRequest.fromJson(map);
        return ApiResult.success(record);
      },
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  Future<ApiResult<List<LeaveRequest>>> getTeacherLeaveHistory({
    required String teacherId,
    String? status,
    String? leaveType,
    String? startDate,
    String? endDate,
    int skip = 0,
    int limit = 20,
  }) async {
    final result = await _datasource.getTeacherLeaveHistory(
      teacherId: teacherId,
      status: status,
      leaveType: leaveType,
      startDate: startDate,
      endDate: endDate,
      skip: skip,
      limit: limit,
    );
    return result.when(
      onSuccess: (list) {
        final records = list.map((e) => LeaveRequest.fromJson(e)).toList();
        return ApiResult.success(records);
      },
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }
}
