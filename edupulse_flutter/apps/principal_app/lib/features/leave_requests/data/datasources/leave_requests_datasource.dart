import 'package:edupulse_network/edupulse_network.dart';

class LeaveRequestsDatasource {
  final BaseApiClient _apiClient;

  LeaveRequestsDatasource(this._apiClient);

  Future<ApiResult<List<Map<String, dynamic>>>> getLeaveRequests({
    required String schoolId,
    String? status,
    String? leaveType,
    String? startDate,
    String? endDate,
    int skip = 0,
    int limit = 20,
  }) async {
    final Map<String, dynamic> queryParams = {
      'school_id': schoolId,
      'skip': skip,
      'limit': limit,
    };
    if (status != null && status != 'ALL') {
      queryParams['status'] = status;
    }
    if (leaveType != null && leaveType != 'ALL') {
      queryParams['leave_type'] = leaveType;
    }
    if (startDate != null) {
      queryParams['start_date'] = startDate;
    }
    if (endDate != null) {
      queryParams['end_date'] = endDate;
    }

    return _apiClient.get<List<Map<String, dynamic>>>(
      '/teacher-leaves',
      queryParameters: queryParams,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((e) => e as Map<String, dynamic>).toList();
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> getTeacherLeave(String leaveId) async {
    return _apiClient.get<Map<String, dynamic>>(
      '/teacher-leaves/$leaveId',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>;
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> reviewLeaveRequest({
    required String leaveId,
    required String decision, // APPROVE or REJECT
    String? remarks,
  }) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/teacher-leaves/$leaveId/review',
      data: {
        'decision': decision,
        if (remarks != null) 'reviewer_remarks': remarks,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>;
      },
    );
  }

  Future<ApiResult<List<Map<String, dynamic>>>> getTeacherLeaveHistory({
    required String teacherId,
    String? status,
    String? leaveType,
    String? startDate,
    String? endDate,
    int skip = 0,
    int limit = 20,
  }) async {
    final Map<String, dynamic> queryParams = {
      'skip': skip,
      'limit': limit,
    };
    if (status != null && status != 'ALL') {
      queryParams['status'] = status;
    }
    if (leaveType != null && leaveType != 'ALL') {
      queryParams['leave_type'] = leaveType;
    }
    if (startDate != null) {
      queryParams['start_date'] = startDate;
    }
    if (endDate != null) {
      queryParams['end_date'] = endDate;
    }

    return _apiClient.get<List<Map<String, dynamic>>>(
      '/teacher-leaves/teacher/$teacherId/history',
      queryParameters: queryParams,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((e) => e as Map<String, dynamic>).toList();
      },
    );
  }
}
