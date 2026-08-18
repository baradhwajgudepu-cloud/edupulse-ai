import 'package:edupulse_network/edupulse_network.dart';
import '../models/teacher_leave_dto.dart';

class TeacherLeaveRemoteDatasource {
  final BaseApiClient _apiClient;

  const TeacherLeaveRemoteDatasource(this._apiClient);

  Future<ApiResult<TeacherLeaveDto>> createLeave({
    required String leaveType,
    required String startDate,
    required String endDate,
    required String reason,
    String? remarks,
  }) {
    return _apiClient.post(
      '/teacher-leaves',
      data: {
        'leave_type': leaveType,
        'start_date': startDate,
        'end_date': endDate,
        'reason': reason,
        if (remarks != null) 'remarks': remarks,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return TeacherLeaveDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }

  Future<ApiResult<List<TeacherLeaveDto>>> getMyLeaves() {
    return _apiClient.get(
      '/teacher-leaves/my',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>;
        return list
            .map((item) => TeacherLeaveDto.fromJson(item as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<ApiResult<TeacherLeaveDto>> getLeave(String leaveId) {
    return _apiClient.get(
      '/teacher-leaves/$leaveId',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return TeacherLeaveDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }

  Future<ApiResult<TeacherLeaveDto>> cancelLeave({
    required String leaveId,
    required String cancellationReason,
  }) {
    return _apiClient.post(
      '/teacher-leaves/$leaveId/cancel',
      data: {
        'cancellation_reason': cancellationReason,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return TeacherLeaveDto.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );
  }
}
