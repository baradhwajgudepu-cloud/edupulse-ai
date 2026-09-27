import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../data/models/academic_planning_models.dart';
import '../../data/models/timetable_models.dart';
import '../../../school_setup/data/models/school_setup_models.dart';

typedef AcademicPlanningParams = ({
  String schoolId,
  String academicYearId,
});

final academicPlanningSummaryProvider =
    FutureProvider.family<AcademicPlanningSummary, AcademicPlanningParams>((ref, params) async {
  final apiClient = ref.watch(apiClientProvider);

  final result = await apiClient.get(
    '/academic-planning/summary?school_id=${params.schoolId}&academic_year_id=${params.academicYearId}',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final data = payload['data'] ?? payload;
      return AcademicPlanningSummary.fromJson(Map<String, dynamic>.from(data as Map));
    },
  );

  return result.when(
    onSuccess: (summary) => summary,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

typedef SubjectPredictionParams = ({
  String schoolId,
  String academicYearId,
  String classId,
  String? subjectId,
  String? sectionId,
});

final subjectPredictionProvider =
    FutureProvider.family<List<SyllabusPredictionItem>, SubjectPredictionParams>((ref, params) async {
  final apiClient = ref.watch(apiClientProvider);

  var url = '/academic-planning/predictions?school_id=${params.schoolId}&academic_year_id=${params.academicYearId}&class_id=${params.classId}';
  if (params.subjectId != null) url += '&subject_id=${params.subjectId}';
  if (params.sectionId != null) url += '&section_id=${params.sectionId}';

  final result = await apiClient.get(
    url,
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = (payload['data'] as List<dynamic>?) ?? [];
      return list
          .map((item) => SyllabusPredictionItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    },
  );

  return result.when(
    onSuccess: (items) => items,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

typedef ClassAssignedSubjectsParams = ({
  String schoolId,
  String academicYearId,
  String classId,
});

final classAssignedSubjectsProvider =
    FutureProvider.family<List<SubjectDto>, ClassAssignedSubjectsParams>((ref, params) async {
  final apiClient = ref.watch(apiClientProvider);

  // 1. Fetch class-assigned subjects
  final assignmentResult = await apiClient.get(
    '/class-subject-assignments?school_id=${params.schoolId}&academic_year_id=${params.academicYearId}&class_id=${params.classId}&limit=100',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = (payload['data'] as List<dynamic>?) ?? [];
      return list;
    },
  );

  final List<dynamic>? rawAssignments = assignmentResult.when(
    onSuccess: (data) => data,
    onFailure: (_) => null,
  );

  if (rawAssignments != null && rawAssignments.isNotEmpty) {
    final Map<String, SubjectDto> subjectsMap = {};
    for (final item in rawAssignments) {
      final map = Map<String, dynamic>.from(item as Map);
      final subId = (map['subject_id'] ?? map['id'])?.toString();
      if (subId != null && subId.isNotEmpty && !subjectsMap.containsKey(subId)) {
        subjectsMap[subId] = SubjectDto(
          id: subId,
          tenantId: map['tenant_id']?.toString() ?? '',
          schoolId: params.schoolId,
          academicYearId: params.academicYearId,
          subjectCode: map['subject_code']?.toString() ?? '',
          subjectName: map['subject_name']?.toString() ?? 'Unnamed Subject',
          category: 'CORE',
          subjectType: 'THEORY',
          theoryMarks: 0,
          practicalMarks: 0,
          passMarks: 0,
          status: 'ACTIVE',
          isActive: true,
          version: 1,
          sourceType: map['source_type']?.toString() ?? 'BOARD_OFFICIAL',
        );
      }
    }
    if (subjectsMap.isNotEmpty) {
      return subjectsMap.values.toList();
    }
  }

  // 2. Fallback: Query all subjects for the school and academic year
  final subjectsResult = await apiClient.get(
    '/subjects?school_id=${params.schoolId}&academic_year_id=${params.academicYearId}&limit=100',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = (payload['data'] as List<dynamic>?) ?? [];
      return list
          .map((item) => SubjectDto.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    },
  );

  return subjectsResult.when(
    onSuccess: (subs) async {
      if (subs.isNotEmpty) return subs;
      // 3. Secondary fallback: Query school-wide subjects
      final fallbackAll = await apiClient.get(
        '/subjects?school_id=${params.schoolId}&limit=100',
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          final list = (payload['data'] as List<dynamic>?) ?? [];
          return list
              .map((item) => SubjectDto.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
        },
      );
      return fallbackAll.when(
        onSuccess: (allSubs) => allSubs,
        onFailure: (_) => <SubjectDto>[],
      );
    },
    onFailure: (_) async {
      final fallbackAll = await apiClient.get(
        '/subjects?school_id=${params.schoolId}&limit=100',
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          final list = (payload['data'] as List<dynamic>?) ?? [];
          return list
              .map((item) => SubjectDto.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
        },
      );
      return fallbackAll.when(
        onSuccess: (allSubs) => allSubs,
        onFailure: (f) => throw Exception(f.message),
      );
    },
  );
});

typedef SyllabusFilterParams = ({
  String schoolId,
  String academicYearId,
  String classId,
  String subjectId,
  String? sectionId,
});

final syllabusListProvider =
    FutureProvider.family<List<SyllabusItem>, SyllabusFilterParams>((ref, params) async {
  final apiClient = ref.watch(apiClientProvider);

  var url = '/syllabuses?school_id=${params.schoolId}&academic_year_id=${params.academicYearId}&class_id=${params.classId}&subject_id=${params.subjectId}';
  if (params.sectionId != null && params.sectionId!.isNotEmpty) {
    url += '&section_id=${params.sectionId}';
  }

  final result = await apiClient.get(
    url,
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = (payload['data'] as List<dynamic>?) ?? [];
      return list
          .map((item) => SyllabusItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    },
  );

  return result.when(
    onSuccess: (items) => items,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

typedef CoverageSummaryParams = ({
  String schoolId,
  String academicYearId,
  String classId,
  String subjectId,
  String? sectionId,
});

final coverageSummaryProvider =
    FutureProvider.family<SubjectCoverageSummary?, CoverageSummaryParams>((ref, params) async {
  final apiClient = ref.watch(apiClientProvider);

  var url = '/syllabuses/coverage/summary?school_id=${params.schoolId}&academic_year_id=${params.academicYearId}&class_id=${params.classId}&subject_id=${params.subjectId}';
  if (params.sectionId != null && params.sectionId!.isNotEmpty) {
    url += '&section_id=${params.sectionId}';
  }

  final result = await apiClient.get(
    url,
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final data = payload['data'] ?? payload;
      return SubjectCoverageSummary.fromJson(Map<String, dynamic>.from(data as Map));
    },
  );

  return result.when(
    onSuccess: (summary) => summary,
    onFailure: (_) => null,
  );
});

class AcademicPlanningActionState {
  final bool isLoading;
  final String? successMessage;
  final String? errorMessage;
  final dynamic resultData;

  const AcademicPlanningActionState({
    required this.isLoading,
    this.successMessage,
    this.errorMessage,
    this.resultData,
  });
}

class AcademicPlanningController extends StateNotifier<AcademicPlanningActionState> {
  final BaseApiClient _apiClient;

  AcademicPlanningController(this._apiClient)
      : super(const AcademicPlanningActionState(isLoading: false));

  Future<CurriculumPopulateResult?> populateFromBoard({
    required String schoolId,
    required String academicYearId,
    required String board,
    required List<String> classIds,
    String? stateName,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);

    final payload = {
      'school_id': schoolId,
      'academic_year_id': academicYearId,
      'board': board,
      'class_ids': classIds,
      if (stateName != null) 'state': stateName,
    };

    final result = await _apiClient.post(
      '/curriculum/populate-school-syllabus',
      data: payload,
      mapper: (json) {
        final res = json as Map<String, dynamic>;
        final data = res['data'] ?? res;
        return CurriculumPopulateResult.fromJson(Map<String, dynamic>.from(data as Map));
      },
    );

    return result.when(
      onSuccess: (popResult) {
        state = AcademicPlanningActionState(
          isLoading: false,
          successMessage: popResult.message,
          resultData: popResult,
        );
        return popResult;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(
          isLoading: false,
          errorMessage: failure.message,
        );
        return null;
      },
    );
  }

  Future<bool> reorderSyllabus({
    required String schoolId,
    required String classId,
    required String subjectId,
    required List<Map<String, dynamic>> items,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);

    final result = await _apiClient.post(
      '/syllabuses/reorder',
      data: {
        'school_id': schoolId,
        'class_id': classId,
        'subject_id': subjectId,
        'items': items,
      },
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        state = const AcademicPlanningActionState(
          isLoading: false,
          successMessage: 'Syllabus order updated successfully.',
        );
        return true;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(
          isLoading: false,
          errorMessage: failure.message,
        );
        return false;
      },
    );
  }

  Future<bool> updateLifecycleStatus({
    required String syllabusId,
    required String status,
    String? remarks,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);

    final result = await _apiClient.patch(
      '/syllabuses/$syllabusId/lifecycle',
      data: {
        'status': status,
        if (remarks != null) 'remarks': remarks,
      },
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        state = const AcademicPlanningActionState(
          isLoading: false,
          successMessage: 'Lifecycle status updated successfully.',
        );
        return true;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(
          isLoading: false,
          errorMessage: failure.message,
        );
        return false;
      },
    );
  }

  Future<bool> updateCoverageStatus({
    required String schoolId,
    required String syllabusId,
    required String coverageStatus,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);

    final result = await _apiClient.patch(
      '/syllabuses/$syllabusId/coverage?school_id=$schoolId',
      data: {
        'coverage_status': coverageStatus,
      },
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        state = AcademicPlanningActionState(
          isLoading: false,
          successMessage: 'Coverage status updated to $coverageStatus.',
        );
        return true;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(
          isLoading: false,
          errorMessage: failure.message,
        );
        return false;
      },
    );
  }

  Future<bool> recordSectionProgress({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String sectionId,
    required String subjectId,
    required String syllabusId,
    required String status,
    double completionPercentage = 100.0,
    String? remarks,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);

    final result = await _apiClient.post(
      '/syllabuses/coverage/progress',
      data: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'class_id': classId,
        'section_id': sectionId,
        'subject_id': subjectId,
        'syllabus_id': syllabusId,
        'status': status,
        'completion_percentage': completionPercentage,
        if (remarks != null) 'remarks': remarks,
      },
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        state = const AcademicPlanningActionState(
          isLoading: false,
          successMessage: 'Section teaching progress saved.',
        );
        return true;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(
          isLoading: false,
          errorMessage: failure.message,
        );
        return false;
      },
    );
  }

  Future<TimetableAIRecommendation?> generateTimetableAI({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String sectionId,
    bool avoidTeacherClashes = true,
    bool balanceDailyWorkload = true,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);

    final result = await _apiClient.post(
      '/academic-planning/timetable-ai/recommend',
      data: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'class_id': classId,
        'section_id': sectionId,
        'avoid_teacher_clashes': avoidTeacherClashes,
        'balance_daily_workload': balanceDailyWorkload,
      },
      mapper: (json) {
        final res = json as Map<String, dynamic>;
        final data = res['data'] ?? res;
        return TimetableAIRecommendation.fromJson(Map<String, dynamic>.from(data as Map));
      },
    );

    return result.when(
      onSuccess: (rec) {
        state = AcademicPlanningActionState(
          isLoading: false,
          successMessage: 'AI Timetable recommendation generated successfully.',
          resultData: rec,
        );
        return rec;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(
          isLoading: false,
          errorMessage: failure.message,
        );
        return null;
      },
    );
  }

  Future<bool> approveAndPublishTimetable({
    required String recommendationId,
    bool publishImmediately = false,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);

    final result = await _apiClient.post(
      '/academic-planning/timetable-ai/approve',
      data: {
        'recommendation_id': recommendationId,
        'publish_immediately': publishImmediately,
      },
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        state = AcademicPlanningActionState(
          isLoading: false,
          successMessage: publishImmediately
              ? 'Timetable approved and published successfully.'
              : 'Timetable approved and saved as active draft.',
        );
        return true;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(
          isLoading: false,
          errorMessage: failure.message,
        );
        return false;
      },
    );
  }

  Future<TimetableGridValidation?> validateTimetableGrid({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String sectionId,
    required List<Map<String, dynamic>> slots,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);

    final result = await _apiClient.post(
      '/academic-planning/timetable-grid/validate',
      data: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'class_id': classId,
        'section_id': sectionId,
        'slots': slots,
      },
      mapper: (json) {
        final res = json as Map<String, dynamic>;
        final data = res['data'] ?? res;
        return TimetableGridValidation.fromJson(Map<String, dynamic>.from(data as Map));
      },
    );

    return result.when(
      onSuccess: (val) {
        state = const AcademicPlanningActionState(isLoading: false);
        return val;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(
          isLoading: false,
          errorMessage: failure.message,
        );
        return null;
      },
    );
  }

  Future<HolidayImpactData?> fetchHolidayImpact({
    required String schoolId,
    required String academicYearId,
    required String holidayDate,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);
    final result = await _apiClient.get(
      '/academic-planning/holiday-impact?school_id=$schoolId&academic_year_id=$academicYearId&holiday_date=$holidayDate',
      mapper: (json) {
        final res = json as Map<String, dynamic>;
        final data = res['data'] ?? res;
        return HolidayImpactData.fromJson(Map<String, dynamic>.from(data as Map));
      },
    );
    return result.when(
      onSuccess: (data) {
        state = const AcademicPlanningActionState(isLoading: false);
        return data;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(isLoading: false, errorMessage: failure.message);
        return null;
      },
    );
  }

  Future<AIRecoveryPreview?> generateHolidayRecovery({
    required String schoolId,
    required String academicYearId,
    required String holidayDate,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);
    final result = await _apiClient.post(
      '/academic-planning/holiday-recovery/generate',
      data: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'holiday_date': holidayDate,
      },
      mapper: (json) {
        final res = json as Map<String, dynamic>;
        final data = res['data'] ?? res;
        return AIRecoveryPreview.fromJson(Map<String, dynamic>.from(data as Map));
      },
    );
    return result.when(
      onSuccess: (preview) {
        state = const AcademicPlanningActionState(isLoading: false);
        return preview;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(isLoading: false, errorMessage: failure.message);
        return null;
      },
    );
  }

  Future<bool> applyHolidayRecovery({
    required String recoveryId,
    required String schoolId,
    required String academicYearId,
    required List<Map<String, dynamic>> changes,
    String? remarks,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);
    final result = await _apiClient.post(
      '/academic-planning/holiday-recovery/$recoveryId/apply',
      data: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'changes': changes,
        'remarks': remarks,
      },
      mapper: (json) => json,
    );
    return result.when(
      onSuccess: (_) {
        state = const AcademicPlanningActionState(
          isLoading: false,
          successMessage: 'Timetable rebalanced successfully. Teacher notifications dispatched.',
        );
        return true;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> rejectHolidayRecovery({
    required String recoveryId,
    required String schoolId,
    required String reason,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);
    final result = await _apiClient.post(
      '/academic-planning/holiday-recovery/$recoveryId/reject',
      data: {
        'school_id': schoolId,
        'reason': reason,
      },
      mapper: (json) => json,
    );
    return result.when(
      onSuccess: (_) {
        state = const AcademicPlanningActionState(
          isLoading: false,
          successMessage: 'Recovery plan rejected.',
        );
        return true;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> declarePrincipalHoliday({
    required String schoolId,
    required String academicYearId,
    required String eventDate,
    required String title,
    String? description,
    bool isNonWorkingDay = true,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);
    final result = await _apiClient.post(
      '/calendar/holidays/principal-declare',
      data: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'event_date': eventDate,
        'title': title,
        'description': description,
        'is_non_working_day': isNonWorkingDay,
      },
      mapper: (json) => json,
    );
    return result.when(
      onSuccess: (_) {
        state = const AcademicPlanningActionState(
          isLoading: false,
          successMessage: 'Principal holiday declared successfully.',
        );
        return true;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<StateHolidayVerificationStatus?> fetchStateHolidayStatus({
    required String stateName,
    required String academicYearCode,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);
    final result = await _apiClient.get(
      '/calendar/holidays/state/status?state=$stateName&academic_year_code=$academicYearCode',
      mapper: (json) {
        final res = json as Map<String, dynamic>;
        final data = res['data'] ?? res;
        return StateHolidayVerificationStatus.fromJson(Map<String, dynamic>.from(data as Map));
      },
    );
    return result.when(
      onSuccess: (data) {
        state = const AcademicPlanningActionState(isLoading: false);
        return data;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(isLoading: false, errorMessage: failure.message);
        return null;
      },
    );
  }

  Future<bool> populateStateHolidays({
    required String schoolId,
    required String academicYearId,
    required String stateName,
    required String academicYearCode,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);
    final result = await _apiClient.post(
      '/calendar/holidays/state/populate',
      data: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'state': stateName,
        'academic_year_code': academicYearCode,
      },
      mapper: (json) => json,
    );
    return result.when(
      onSuccess: (res) {
        final resMap = res as Map<String, dynamic>? ?? {};
        final count = resMap['count'] ?? 0;
        state = AcademicPlanningActionState(
          isLoading: false,
          successMessage: 'Successfully populated $count verified state public holidays.',
        );
        return true;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<CrossTeacherRecoveryRecommendationModel?> generateCrossTeacherRecommendation({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String sectionId,
    required String subjectId,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);
    final result = await _apiClient.post(
      '/syllabus-recovery/cross-teacher/recommendations/generate',
      data: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'class_id': classId,
        'section_id': sectionId,
        'subject_id': subjectId,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final data = payload['data'] ?? payload;
        return CrossTeacherRecoveryRecommendationModel.fromJson(Map<String, dynamic>.from(data as Map));
      },
    );
    return result.when(
      onSuccess: (rec) {
        state = AcademicPlanningActionState(isLoading: false, resultData: rec);
        return rec;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(isLoading: false, errorMessage: failure.message);
        return null;
      },
    );
  }

  Future<bool> approveRecoveryPlan({
    required String schoolId,
    required String planId,
    String? selectedTeacherId,
    String? parentNotes,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);
    final body = <String, dynamic>{
      if (selectedTeacherId != null) 'selected_teacher_id': selectedTeacherId,
      if (parentNotes != null) 'parent_notes': parentNotes,
    };
    final result = await _apiClient.post(
      '/syllabus-recovery/cross-teacher/plans/$planId/approve?school_id=$schoolId',
      data: body,
      mapper: (json) => json,
    );
    return result.when(
      onSuccess: (_) {
        state = const AcademicPlanningActionState(
          isLoading: false,
          successMessage: 'Cross-teacher recovery plan successfully approved and timetable updated.',
        );
        return true;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> rejectRecoveryPlan({
    required String schoolId,
    required String planId,
    required String rejectionReason,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);
    final result = await _apiClient.post(
      '/syllabus-recovery/cross-teacher/plans/$planId/reject?school_id=$schoolId',
      data: {'rejection_reason': rejectionReason},
      mapper: (json) => json,
    );
    return result.when(
      onSuccess: (_) {
        state = const AcademicPlanningActionState(
          isLoading: false,
          successMessage: 'Recovery recommendation rejected.',
        );
        return true;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> cancelRecoveryPlan({
    required String schoolId,
    required String planId,
    required String cancellationReason,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);
    final result = await _apiClient.post(
      '/syllabus-recovery/cross-teacher/plans/$planId/cancel?school_id=$schoolId',
      data: {'cancellation_reason': cancellationReason},
      mapper: (json) => json,
    );
    return result.when(
      onSuccess: (_) {
        state = const AcademicPlanningActionState(
          isLoading: false,
          successMessage: 'Recovery plan cancelled and associated timetable slots removed.',
        );
        return true;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> updateRecoveryItem({
    required String planId,
    required String itemId,
    required Map<String, dynamic> data,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);
    final result = await _apiClient.put(
      '/syllabus-recovery/plans/$planId/items/$itemId',
      data: data,
      mapper: (json) => json,
    );
    return result.when(
      onSuccess: (_) {
        state = const AcademicPlanningActionState(
          isLoading: false,
          successMessage: 'Slot updated and timetable conflict validation recomputed.',
        );
        return true;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> regenerateRecoveryPlan({
    required String planId,
    String? reason,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);
    final result = await _apiClient.post(
      '/syllabus-recovery/plans/$planId/regenerate',
      data: {'reason': reason ?? 'Regenerated by Admin'},
      mapper: (json) => json,
    );
    return result.when(
      onSuccess: (_) {
        state = const AcademicPlanningActionState(
          isLoading: false,
          successMessage: 'Recovery plan recomputed successfully.',
        );
        return true;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> approveSyllabusRecoveryPlan({
    required String planId,
    String? remarks,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);
    final result = await _apiClient.post(
      '/syllabus-recovery/plans/$planId/approve',
      data: {'remarks': remarks ?? 'Approved by School Admin'},
      mapper: (json) => json,
    );
    return result.when(
      onSuccess: (_) {
        state = const AcademicPlanningActionState(
          isLoading: false,
          successMessage: 'Recovery plan approved, timetable updated, and teacher notified.',
        );
        return true;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> rejectSyllabusRecoveryPlan({
    required String planId,
    required String remarks,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);
    final result = await _apiClient.post(
      '/syllabus-recovery/plans/$planId/reject',
      data: {'remarks': remarks},
      mapper: (json) => json,
    );
    return result.when(
      onSuccess: (_) {
        state = const AcademicPlanningActionState(
          isLoading: false,
          successMessage: 'Recovery plan rejected.',
        );
        return true;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<SyllabusItem?> createTopic({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String subjectId,
    String? sectionId,
    required String unitName,
    required String chapterName,
    required String topicName,
    int estimatedPeriods = 3,
    String? description,
    int? sequenceOrder,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);
    final payload = <String, dynamic>{
      'class_id': classId,
      'subject_id': subjectId,
      if (sectionId != null && sectionId.isNotEmpty) 'section_id': sectionId,
      'unit_name': unitName.trim(),
      'chapter_name': chapterName.trim(),
      'topic_name': topicName.trim(),
      'estimated_periods': estimatedPeriods,
      if (description != null && description.isNotEmpty) 'description': description.trim(),
      if (sequenceOrder != null) 'sequence_order': sequenceOrder,
    };
    final result = await _apiClient.post(
      '/syllabuses/topic?school_id=$schoolId&academic_year_id=$academicYearId',
      data: payload,
      mapper: (json) {
        final res = json as Map<String, dynamic>;
        final data = res['data'] ?? res;
        return SyllabusItem.fromJson(Map<String, dynamic>.from(data as Map));
      },
    );
    return result.when(
      onSuccess: (item) {
        state = AcademicPlanningActionState(
          isLoading: false,
          successMessage: 'Topic "${item.topicName}" created successfully.',
          resultData: item,
        );
        return item;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(isLoading: false, errorMessage: failure.message);
        return null;
      },
    );
  }

  Future<SyllabusItem?> createChapter({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String subjectId,
    String? sectionId,
    required String unitName,
    required String chapterName,
    String? initialTopicName,
    int estimatedPeriods = 4,
    String? description,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);
    final payload = <String, dynamic>{
      'class_id': classId,
      'subject_id': subjectId,
      if (sectionId != null && sectionId.isNotEmpty) 'section_id': sectionId,
      'unit_name': unitName.trim(),
      'chapter_name': chapterName.trim(),
      if (initialTopicName != null && initialTopicName.isNotEmpty) 'initial_topic_name': initialTopicName.trim(),
      'estimated_periods': estimatedPeriods,
      if (description != null && description.isNotEmpty) 'description': description.trim(),
    };
    final result = await _apiClient.post(
      '/syllabuses/chapter?school_id=$schoolId&academic_year_id=$academicYearId',
      data: payload,
      mapper: (json) {
        final res = json as Map<String, dynamic>;
        final data = res['data'] ?? res;
        return SyllabusItem.fromJson(Map<String, dynamic>.from(data as Map));
      },
    );
    return result.when(
      onSuccess: (item) {
        state = AcademicPlanningActionState(
          isLoading: false,
          successMessage: 'Chapter "${item.chapterName}" created successfully.',
          resultData: item,
        );
        return item;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(isLoading: false, errorMessage: failure.message);
        return null;
      },
    );
  }

  Future<SyllabusItem?> createUnit({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String subjectId,
    String? sectionId,
    required String unitName,
    String? initialChapterName,
    String? initialTopicName,
    int estimatedPeriods = 4,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);
    final payload = <String, dynamic>{
      'class_id': classId,
      'subject_id': subjectId,
      if (sectionId != null && sectionId.isNotEmpty) 'section_id': sectionId,
      'unit_name': unitName.trim(),
      if (initialChapterName != null && initialChapterName.isNotEmpty) 'initial_chapter_name': initialChapterName.trim(),
      if (initialTopicName != null && initialTopicName.isNotEmpty) 'initial_topic_name': initialTopicName.trim(),
      'estimated_periods': estimatedPeriods,
    };
    final result = await _apiClient.post(
      '/syllabuses/unit?school_id=$schoolId&academic_year_id=$academicYearId',
      data: payload,
      mapper: (json) {
        final res = json as Map<String, dynamic>;
        final data = res['data'] ?? res;
        return SyllabusItem.fromJson(Map<String, dynamic>.from(data as Map));
      },
    );
    return result.when(
      onSuccess: (item) {
        state = AcademicPlanningActionState(
          isLoading: false,
          successMessage: 'Unit "${item.unitName}" created successfully.',
          resultData: item,
        );
        return item;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(isLoading: false, errorMessage: failure.message);
        return null;
      },
    );
  }

  Future<bool> deleteSyllabusEntry({
    required String schoolId,
    required String syllabusId,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);
    final result = await _apiClient.delete(
      '/syllabuses/$syllabusId?school_id=$schoolId',
      mapper: (json) => json,
    );
    return result.when(
      onSuccess: (_) {
        state = const AcademicPlanningActionState(isLoading: false, successMessage: 'Topic deleted successfully.');
        return true;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> deleteChapter({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String subjectId,
    required String chapterName,
    String? unitName,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);
    final result = await _apiClient.delete(
      '/syllabuses/chapter?school_id=$schoolId&academic_year_id=$academicYearId',
      data: {
        'class_id': classId,
        'subject_id': subjectId,
        'chapter_name': chapterName,
        if (unitName != null) 'unit_name': unitName,
      },
      mapper: (json) => json,
    );
    return result.when(
      onSuccess: (_) {
        state = const AcademicPlanningActionState(isLoading: false, successMessage: 'Chapter deleted successfully.');
        return true;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> deleteUnit({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String subjectId,
    required String unitName,
  }) async {
    state = const AcademicPlanningActionState(isLoading: true);
    final result = await _apiClient.delete(
      '/syllabuses/unit?school_id=$schoolId&academic_year_id=$academicYearId',
      data: {
        'class_id': classId,
        'subject_id': subjectId,
        'unit_name': unitName,
      },
      mapper: (json) => json,
    );
    return result.when(
      onSuccess: (_) {
        state = const AcademicPlanningActionState(isLoading: false, successMessage: 'Unit deleted successfully.');
        return true;
      },
      onFailure: (failure) {
        state = AcademicPlanningActionState(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }
}

typedef CrossTeacherCandidatesParams = ({
  String schoolId,
  String academicYearId,
  String classId,
  String sectionId,
  String subjectId,
});

final crossTeacherCandidatesProvider =
    FutureProvider.family<List<CandidateEvaluationModel>, CrossTeacherCandidatesParams>((ref, params) async {
  final apiClient = ref.watch(apiClientProvider);

  final url = '/syllabus-recovery/cross-teacher/candidates?school_id=${params.schoolId}&academic_year_id=${params.academicYearId}&class_id=${params.classId}&section_id=${params.sectionId}&subject_id=${params.subjectId}';

  final result = await apiClient.get(
    url,
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = (payload['data'] as List<dynamic>?) ?? [];
      return list
          .map((item) => CandidateEvaluationModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    },
  );

  return result.when(
    onSuccess: (items) => items,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

typedef RecoveryAnalyticsParams = ({
  String schoolId,
  String academicYearId,
});

final recoveryAnalyticsProvider =
    FutureProvider.family<RecoveryAnalyticsSummaryModel, RecoveryAnalyticsParams>((ref, params) async {
  final apiClient = ref.watch(apiClientProvider);

  final url = '/syllabus-recovery/analytics?school_id=${params.schoolId}&academic_year_id=${params.academicYearId}';

  final result = await apiClient.get(
    url,
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final data = payload['data'] ?? payload;
      return RecoveryAnalyticsSummaryModel.fromJson(Map<String, dynamic>.from(data as Map));
    },
  );

  return result.when(
    onSuccess: (summary) => summary,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

final academicPlanningControllerProvider =
    StateNotifierProvider<AcademicPlanningController, AcademicPlanningActionState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AcademicPlanningController(apiClient);
});

typedef AcademicHeatmapParams = ({
  String schoolId,
  String? academicYearId,
});

final academicHeatmapProvider =
    FutureProvider.family<AcademicHeatmapDataModel, AcademicHeatmapParams>((ref, params) async {
  final apiClient = ref.watch(apiClientProvider);

  var url = '/syllabus-recovery/academic-heatmap?school_id=${params.schoolId}';
  if (params.academicYearId != null && params.academicYearId!.isNotEmpty) {
    url += '&academic_year_id=${params.academicYearId}';
  }

  final result = await apiClient.get(
    url,
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final data = payload['data'] ?? payload;
      return AcademicHeatmapDataModel.fromJson(Map<String, dynamic>.from(data as Map));
    },
  );

  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

typedef AdminRecoveryPlansParams = ({
  String schoolId,
  String? academicYearId,
  String? status,
});

final adminRecoveryPlansProvider =
    FutureProvider.family<List<AdminSyllabusRecoveryPlanModel>, AdminRecoveryPlansParams>((ref, params) async {
  final apiClient = ref.watch(apiClientProvider);

  var url = '/syllabus-recovery/plans?school_id=${params.schoolId}';
  if (params.academicYearId != null && params.academicYearId!.isNotEmpty) {
    url += '&academic_year_id=${params.academicYearId}';
  }
  if (params.status != null && params.status!.isNotEmpty) {
    url += '&status=${params.status}';
  }

  final result = await apiClient.get(
    url,
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = (payload['data'] as List<dynamic>?) ?? [];
      return list
          .map((item) => AdminSyllabusRecoveryPlanModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    },
  );

  return result.when(
    onSuccess: (items) => items,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

