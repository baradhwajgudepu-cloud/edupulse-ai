import 'package:edupulse_network/edupulse_network.dart';

class AcademicDatasource {
  final BaseApiClient _apiClient;

  AcademicDatasource(this._apiClient);

  Future<ApiResult<List<Map<String, dynamic>>>> getExaminations({
    required String schoolId,
  }) async {
    return _apiClient.get<List<Map<String, dynamic>>>(
      '/examinations',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((e) => e as Map<String, dynamic>).toList();
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> getMarksSummary({
    required String schoolId,
    required String examScheduleId,
  }) async {
    return _apiClient.get<Map<String, dynamic>>(
      '/marks/summary',
      queryParameters: {
        'school_id': schoolId,
        'exam_schedule_id': examScheduleId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? {};
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> createExamination({
    required Map<String, dynamic> data,
  }) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/examinations',
      data: data,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? {};
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> publishExamination({
    required String id,
    required String schoolId,
  }) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/examinations/$id/publish',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? {};
      },
    );
  }

  Future<ApiResult<List<Map<String, dynamic>>>> getClasses({
    required String schoolId,
  }) async {
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

  Future<ApiResult<List<Map<String, dynamic>>>> getAcademicYears({
    required String schoolId,
  }) async {
    return _apiClient.get<List<Map<String, dynamic>>>(
      '/schools/$schoolId/academic-years',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((e) => e as Map<String, dynamic>).toList();
      },
    );
  }

  Future<ApiResult<List<Map<String, dynamic>>>> getSections({
    required String schoolId,
    String? classId,
  }) async {
    final query = {'school_id': schoolId};
    if (classId != null) {
      query['class_id'] = classId;
    }
    return _apiClient.get<List<Map<String, dynamic>>>(
      '/sections',
      queryParameters: query,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((e) => e as Map<String, dynamic>).toList();
      },
    );
  }

  Future<ApiResult<List<Map<String, dynamic>>>> getSuggestedSchedules({
    required String schoolId,
    required List<String> classIds,
    required String startDate,
    required String endDate,
  }) async {
    return _apiClient.get<List<Map<String, dynamic>>>(
      '/examinations/wizard/suggest',
      queryParameters: {
        'school_id': schoolId,
        'class_ids': classIds,
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

  Future<ApiResult<Map<String, dynamic>>> createExaminationWizard({
    required Map<String, dynamic> data,
  }) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/examinations/wizard',
      data: data,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? {};
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> getAcademicPlanningSummary({
    required String schoolId,
    required String academicYearId,
  }) async {
    return _apiClient.get<Map<String, dynamic>>(
      '/academic-planning/summary',
      queryParameters: {
        'school_id': schoolId,
        if (academicYearId.isNotEmpty) 'academic_year_id': academicYearId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? payload;
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> getAcademicHeatmap({
    required String schoolId,
    String? academicYearId,
  }) async {
    final query = {'school_id': schoolId};
    if (academicYearId != null && academicYearId.isNotEmpty) {
      query['academic_year_id'] = academicYearId;
    }
    return _apiClient.get<Map<String, dynamic>>(
      '/syllabus-recovery/academic-heatmap',
      queryParameters: query,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? payload;
      },
    );
  }

  Future<ApiResult<List<Map<String, dynamic>>>> getRecoveryPlans({
    required String schoolId,
    String? classId,
    String? sectionId,
    String? subjectId,
    String? teacherId,
    String? status,
  }) async {
    final query = {'school_id': schoolId};
    if (classId != null && classId.isNotEmpty) query['class_id'] = classId;
    if (sectionId != null && sectionId.isNotEmpty) query['section_id'] = sectionId;
    if (subjectId != null && subjectId.isNotEmpty) query['subject_id'] = subjectId;
    if (teacherId != null && teacherId.isNotEmpty) query['teacher_id'] = teacherId;
    if (status != null && status.isNotEmpty) query['status'] = status;

    return _apiClient.get<List<Map<String, dynamic>>>(
      '/syllabus-recovery/plans',
      queryParameters: query,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((e) => e as Map<String, dynamic>).toList();
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> getTeacherAbsenceImpact({
    required String schoolId,
    required String teacherId,
    required String absenceDate,
  }) async {
    return _apiClient.get<Map<String, dynamic>>(
      '/syllabus-recovery/absence-impact',
      queryParameters: {
        'school_id': schoolId,
        'teacher_id': teacherId,
        'absence_date': absenceDate,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? payload;
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> updateRecoveryPlanItem({
    required String planId,
    required String itemId,
    required Map<String, dynamic> data,
  }) async {
    return _apiClient.put<Map<String, dynamic>>(
      '/syllabus-recovery/plans/$planId/items/$itemId',
      data: data,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? payload;
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> regenerateRecoveryPlan({
    required String planId,
    String? reason,
  }) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/syllabus-recovery/plans/$planId/regenerate',
      data: {'reason': reason ?? 'Regenerated by Principal'},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? payload;
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> approveRecoveryPlan({
    required String planId,
    String? remarks,
  }) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/syllabus-recovery/plans/$planId/approve',
      data: {'remarks': remarks},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? payload;
      },
    );
  }

  Future<ApiResult<Map<String, dynamic>>> rejectRecoveryPlan({
    required String planId,
    required String remarks,
  }) async {
    return _apiClient.post<Map<String, dynamic>>(
      '/syllabus-recovery/plans/$planId/reject',
      data: {'remarks': remarks},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as Map<String, dynamic>? ?? payload;
      },
    );
  }
}


