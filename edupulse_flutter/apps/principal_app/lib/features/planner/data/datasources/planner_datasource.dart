import 'package:edupulse_network/edupulse_network.dart';

class PlannerDatasource {
  final BaseApiClient _apiClient;

  PlannerDatasource(this._apiClient);

  // --- CALENDAR Consolidated FEED ---
  Future<ApiResult<List<Map<String, dynamic>>>> getCalendarFeed({
    required String schoolId,
    required String startDate,
    required String endDate,
  }) async {
    return _apiClient.get<List<Map<String, dynamic>>>(
      '/calendar/feed',
      queryParameters: {
        'school_id': schoolId,
        'start_date': startDate,
        'end_date': endDate,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((e) => e as Map<String, dynamic>).toList();
      },
    );
  }

  // --- CLASSES & SECTIONS ---
  Future<ApiResult<List<Map<String, dynamic>>>> getClasses({required String schoolId}) async {
    return _apiClient.get<List<Map<String, dynamic>>>(
      '/classes',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((e) => e as Map<String, dynamic>).toList();
      },
    );
  }

  Future<ApiResult<List<Map<String, dynamic>>>> getSections({required String schoolId}) async {
    return _apiClient.get<List<Map<String, dynamic>>>(
      '/sections',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((e) => e as Map<String, dynamic>).toList();
      },
    );
  }

  Future<ApiResult<List<Map<String, dynamic>>>> getAcademicYears({required String schoolId}) async {
    return _apiClient.get<List<Map<String, dynamic>>>(
      '/schools/$schoolId/academic-years',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((e) => e as Map<String, dynamic>).toList();
      },
    );
  }

  // --- ACTION ITEMS ---
  Future<ApiResult<Map<String, dynamic>>> getActionItems({
    required String schoolId,
  }) async {
    return _apiClient.get<Map<String, dynamic>>(
      '/principal/action-items',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? {};
      },
    );
  }

  // --- EVENTS API ---
  Future<ApiResult<List<Map<String, dynamic>>>> getEvents({
    required String schoolId,
    String? status,
    String? audience,
  }) async {
    final params = {'school_id': schoolId};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (audience != null && audience.isNotEmpty) params['target_audience'] = audience;

    return _apiClient.get<List<Map<String, dynamic>>>(
      '/events',
      queryParameters: params,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((e) => e as Map<String, dynamic>).toList();
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> createEvent({
    required String schoolId,
    String? academicYearId,
    required Map<String, dynamic> data,
  }) async {
    final params = {'school_id': schoolId};
    if (academicYearId != null && academicYearId.isNotEmpty) {
      params['academic_year_id'] = academicYearId;
    }
    return _apiClient.post<Map<String, dynamic>>(
      '/events',
      queryParameters: params,
      data: data,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? {};
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> updateEvent({
    required String id,
    required String schoolId,
    required Map<String, dynamic> data,
  }) async {
    return _apiClient.put<Map<String, dynamic>>(
      '/events/$id',
      queryParameters: {'school_id': schoolId},
      data: data,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? {};
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> deleteEvent({
    required String id,
    required String schoolId,
  }) async {
    return _apiClient.delete<Map<String, dynamic>>(
      '/events/$id',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? {};
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> publishEvent({
    required String id,
    required String schoolId,
  }) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/events/$id/publish',
      queryParameters: {'school_id': schoolId},
      data: {},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? {};
      },
    );
  }

  // --- ANNOUNCEMENTS API ---
  Future<ApiResult<List<Map<String, dynamic>>>> getAnnouncements({
    required String schoolId,
    String? status,
  }) async {
    final params = {'school_id': schoolId};
    if (status != null && status.isNotEmpty) params['status'] = status;

    return _apiClient.get<List<Map<String, dynamic>>>(
      '/announcements',
      queryParameters: params,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((e) => e as Map<String, dynamic>).toList();
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> createAnnouncement({
    required String schoolId,
    String? academicYearId,
    required Map<String, dynamic> data,
  }) async {
    final params = {'school_id': schoolId};
    if (academicYearId != null && academicYearId.isNotEmpty) {
      params['academic_year_id'] = academicYearId;
    }
    return _apiClient.post<Map<String, dynamic>>(
      '/announcements',
      queryParameters: params,
      data: data,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? {};
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> updateAnnouncement({
    required String id,
    required String schoolId,
    required Map<String, dynamic> data,
  }) async {
    return _apiClient.put<Map<String, dynamic>>(
      '/announcements/$id',
      queryParameters: {'school_id': schoolId},
      data: data,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? {};
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> deleteAnnouncement({
    required String id,
    required String schoolId,
  }) async {
    return _apiClient.delete<Map<String, dynamic>>(
      '/announcements/$id',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? {};
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> publishAnnouncement({
    required String id,
    required String schoolId,
  }) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/announcements/$id/publish',
      queryParameters: {'school_id': schoolId},
      data: {},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? {};
      },
    );
  }
}
