import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../data/models/examination_models.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

// ==================================================
// Exam Types Provider & Notifier
// ==================================================
class ExamTypesState {
  final bool isLoading;
  final String? errorMessage;
  final List<ExamTypeMasterModel> types;

  const ExamTypesState({
    this.isLoading = false,
    this.errorMessage,
    this.types = const [],
  });

  ExamTypesState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    List<ExamTypeMasterModel>? types,
  }) {
    return ExamTypesState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      types: types ?? this.types,
    );
  }
}

class ExamTypesNotifier extends StateNotifier<ExamTypesState> {
  final Ref _ref;

  ExamTypesNotifier(this._ref) : super(const ExamTypesState()) {
    loadTypes();
  }

  Future<void> loadTypes() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final apiClient = _ref.read(apiClientProvider);

    final queryParams = <String, dynamic>{};
    if (schoolId != null && schoolId.isNotEmpty) {
      queryParams['school_id'] = schoolId;
    }

    final result = await apiClient.get(
      '/examinations/types',
      queryParameters: queryParams,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((item) => ExamTypeMasterModel.fromJson(item as Map<String, dynamic>)).toList();
      },
    );

    result.when(
      onSuccess: (types) {
        state = state.copyWith(isLoading: false, types: types);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
    );
  }

  Future<bool> createType({
    required String name,
    required String code,
    String? description,
    required ExamTypeCategoryEnum category,
    required double defaultWeightage,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final apiClient = _ref.read(apiClientProvider);

    final payload = {
      'name': name,
      'code': code.toUpperCase().trim(),
      'description': description,
      'category': category.code,
      'default_weightage': defaultWeightage,
      'school_id': schoolId,
      'is_active': true,
    };

    final result = await apiClient.post(
      '/examinations/types',
      data: payload,
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        loadTypes();
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> updateType({
    required String id,
    String? name,
    String? description,
    ExamTypeCategoryEnum? category,
    double? defaultWeightage,
    bool? isActive,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final apiClient = _ref.read(apiClientProvider);

    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (description != null) payload['description'] = description;
    if (category != null) payload['category'] = category.code;
    if (defaultWeightage != null) payload['default_weightage'] = defaultWeightage;
    if (isActive != null) payload['is_active'] = isActive;

    final queryParams = <String, dynamic>{};
    if (schoolId != null && schoolId.isNotEmpty) {
      queryParams['school_id'] = schoolId;
    }

    final result = await apiClient.put(
      '/examinations/types/$id',
      queryParameters: queryParams,
      data: payload,
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        loadTypes();
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> deleteType(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final apiClient = _ref.read(apiClientProvider);

    final queryParams = <String, dynamic>{};
    if (schoolId != null && schoolId.isNotEmpty) {
      queryParams['school_id'] = schoolId;
    }

    final result = await apiClient.delete(
      '/examinations/types/$id',
      queryParameters: queryParams,
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        loadTypes();
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }
}

final examTypesProvider = StateNotifierProvider<ExamTypesNotifier, ExamTypesState>((ref) {
  return ExamTypesNotifier(ref);
});


// ==================================================
// Examinations Provider & Notifier
// ==================================================
class ExaminationsState {
  final bool isLoading;
  final String? errorMessage;
  final List<ExaminationModel> examinations;
  final String? selectedAcademicYearId;
  final String? selectedStatus;
  final String? selectedClassId;
  final String searchQuery;

  const ExaminationsState({
    this.isLoading = false,
    this.errorMessage,
    this.examinations = const [],
    this.selectedAcademicYearId,
    this.selectedStatus,
    this.selectedClassId,
    this.searchQuery = '',
  });

  ExaminationsState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    List<ExaminationModel>? examinations,
    String? selectedAcademicYearId,
    bool clearAcademicYear = false,
    String? selectedStatus,
    bool clearStatus = false,
    String? selectedClassId,
    bool clearClass = false,
    String? searchQuery,
  }) {
    return ExaminationsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      examinations: examinations ?? this.examinations,
      selectedAcademicYearId: clearAcademicYear ? null : (selectedAcademicYearId ?? this.selectedAcademicYearId),
      selectedStatus: clearStatus ? null : (selectedStatus ?? this.selectedStatus),
      selectedClassId: clearClass ? null : (selectedClassId ?? this.selectedClassId),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class ExaminationsNotifier extends StateNotifier<ExaminationsState> {
  final Ref _ref;

  ExaminationsNotifier(this._ref) : super(const ExaminationsState()) {
    loadExaminations();
  }

  void setAcademicYearFilter(String? ayId) {
    state = state.copyWith(selectedAcademicYearId: ayId, clearAcademicYear: ayId == null);
    loadExaminations();
  }

  void setStatusFilter(String? status) {
    state = state.copyWith(selectedStatus: status, clearStatus: status == null);
    loadExaminations();
  }

  void setClassFilter(String? classId) {
    state = state.copyWith(selectedClassId: classId, clearClass: classId == null);
    loadExaminations();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    loadExaminations();
  }

  Future<void> loadExaminations() async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null || schoolId.isEmpty) {
      state = state.copyWith(examinations: [], isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    final apiClient = _ref.read(apiClientProvider);

    final queryParams = <String, dynamic>{
      'school_id': schoolId,
    };
    if (state.selectedAcademicYearId != null && state.selectedAcademicYearId!.isNotEmpty) {
      queryParams['academic_year_id'] = state.selectedAcademicYearId;
    }
    if (state.selectedClassId != null && state.selectedClassId!.isNotEmpty) {
      queryParams['class_id'] = state.selectedClassId;
    }
    if (state.searchQuery.isNotEmpty) {
      queryParams['search'] = state.searchQuery;
    }

    final result = await apiClient.get(
      '/examinations',
      queryParameters: queryParams,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((item) => ExaminationModel.fromJson(item as Map<String, dynamic>)).toList();
      },
    );

    result.when(
      onSuccess: (exams) {
        var filtered = exams;
        if (state.selectedStatus != null && state.selectedStatus!.isNotEmpty) {
          filtered = exams.where((e) => e.status.code == state.selectedStatus).toList();
        }
        state = state.copyWith(isLoading: false, examinations: filtered);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
    );
  }

  Future<ExaminationModel?> getExaminationDetail(String examId) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final apiClient = _ref.read(apiClientProvider);

    final result = await apiClient.get(
      '/examinations/$examId/detail',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return ExaminationModel.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    return result.when(
      onSuccess: (exam) => exam,
      onFailure: (failure) {
        state = state.copyWith(errorMessage: failure.message);
        return null;
      },
    );
  }

  Future<bool> createExaminationCycle({
    required String examName,
    required String examType,
    required String startDate,
    required String endDate,
    String? description,
    required List<String> participatingClassIds,
    Map<String, dynamic> settings = const {},
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final apiClient = _ref.read(apiClientProvider);

    final payload = {
      'school_id': schoolId,
      'exam_name': examName,
      'exam_type': examType,
      'start_date': startDate,
      'end_date': endDate,
      'description': description,
      'participating_class_ids': participatingClassIds,
      'settings': settings,
    };

    final result = await apiClient.post(
      '/examinations',
      data: payload,
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        loadExaminations();
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> updateExaminationClasses({
    required String examId,
    required List<String> classIds,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final apiClient = _ref.read(apiClientProvider);

    final result = await apiClient.post(
      '/examinations/$examId/classes',
      queryParameters: {'school_id': schoolId},
      data: {'class_ids': classIds},
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        loadExaminations();
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> createExaminationWizard({
    required String examName,
    required String examType,
    required String startDate,
    required String endDate,
    String? description,
    required String targetScope,
    List<String>? classIds,
    List<String>? sectionIds,
    List<Map<String, dynamic>> schedules = const [],
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final apiClient = _ref.read(apiClientProvider);

    final payload = {
      'school_id': schoolId,
      'exam_name': examName,
      'exam_type': examType,
      'start_date': startDate,
      'end_date': endDate,
      'description': description,
      'target_scope': targetScope,
      'class_ids': classIds,
      'section_ids': sectionIds,
      'participating_class_ids': classIds,
      'schedules': schedules,
    };

    final result = await apiClient.post(
      '/examinations/wizard',
      data: payload,
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        loadExaminations();
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> transitionStatus({
    required String examId,
    required ExamStatusEnum newStatus,
    String? reason,
    bool isAdministrativeOverride = false,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final apiClient = _ref.read(apiClientProvider);

    final payload = {
      'new_status': newStatus.code,
      'reason': reason,
      'is_administrative_override': isAdministrativeOverride,
    };

    final result = await apiClient.put(
      '/examinations/$examId/status',
      queryParameters: {'school_id': schoolId},
      data: payload,
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        loadExaminations();
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> copyExamination({
    required String sourceExamId,
    required String newExamName,
    required String newStartDate,
    required String newEndDate,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final apiClient = _ref.read(apiClientProvider);

    final payload = {
      'source_exam_id': sourceExamId,
      'new_exam_name': newExamName,
      'new_start_date': newStartDate,
      'new_end_date': newEndDate,
    };

    final result = await apiClient.post(
      '/examinations/copy',
      queryParameters: {'school_id': schoolId},
      data: payload,
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        loadExaminations();
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> deleteExamination(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final apiClient = _ref.read(apiClientProvider);

    final result = await apiClient.delete(
      '/examinations/$id',
      queryParameters: {'school_id': schoolId},
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        loadExaminations();
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<ExamDeletionImpactModel?> getDeletionImpact(String examId) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final apiClient = _ref.read(apiClientProvider);

    final result = await apiClient.get(
      '/examinations/$examId/delete-impact',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return ExamDeletionImpactModel.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    return result.when(
      onSuccess: (impact) => impact,
      onFailure: (failure) {
        state = state.copyWith(errorMessage: failure.message);
        return null;
      },
    );
  }

  Future<bool> archiveExamination(String examId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final apiClient = _ref.read(apiClientProvider);

    final result = await apiClient.post(
      '/examinations/$examId/archive',
      queryParameters: {'school_id': schoolId},
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        loadExaminations();
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> deleteExaminationPermanent(String examId, String confirmationName) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final apiClient = _ref.read(apiClientProvider);

    final result = await apiClient.delete(
      '/examinations/$examId',
      queryParameters: {
        'school_id': schoolId,
        'mode': 'permanent',
        'confirmation_name': confirmationName,
      },
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        loadExaminations();
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }
}

final examinationsProvider = StateNotifierProvider<ExaminationsNotifier, ExaminationsState>((ref) {
  final notifier = ExaminationsNotifier(ref);
  ref.listen<String?>(selectedSchoolIdProvider, (prev, next) {
    if (prev != next) {
      notifier.loadExaminations();
    }
  });
  return notifier;
});


// ==================================================
// Timetable Schedules Provider & Notifier
// ==================================================
class ExamSchedulesState {
  final bool isLoading;
  final String? errorMessage;
  final List<ExamScheduleModel> schedules;
  final String? selectedExamId;
  final String? selectedClassId;
  final String? selectedSectionId;

  const ExamSchedulesState({
    this.isLoading = false,
    this.errorMessage,
    this.schedules = const [],
    this.selectedExamId,
    this.selectedClassId,
    this.selectedSectionId,
  });

  ExamSchedulesState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    List<ExamScheduleModel>? schedules,
    String? selectedExamId,
    bool clearExam = false,
    String? selectedClassId,
    bool clearClass = false,
    String? selectedSectionId,
    bool clearSection = false,
  }) {
    return ExamSchedulesState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      schedules: schedules ?? this.schedules,
      selectedExamId: clearExam ? null : (selectedExamId ?? this.selectedExamId),
      selectedClassId: clearClass ? null : (selectedClassId ?? this.selectedClassId),
      selectedSectionId: clearSection ? null : (selectedSectionId ?? this.selectedSectionId),
    );
  }
}

class ExamSchedulesNotifier extends StateNotifier<ExamSchedulesState> {
  final Ref _ref;

  ExamSchedulesNotifier(this._ref) : super(const ExamSchedulesState());

  void setExamFilter(String? examId) {
    state = state.copyWith(selectedExamId: examId, clearExam: examId == null);
    loadSchedules();
  }

  void setClassFilter(String? classId) {
    state = state.copyWith(selectedClassId: classId, clearClass: classId == null, clearSection: true);
    loadSchedules();
  }

  void setSectionFilter(String? sectionId) {
    state = state.copyWith(selectedSectionId: sectionId, clearSection: sectionId == null);
    loadSchedules();
  }

  Future<void> loadSchedules({String? examId}) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null || schoolId.isEmpty) {
      state = state.copyWith(schedules: [], isLoading: false);
      return;
    }

    if (examId != null) {
      state = state.copyWith(selectedExamId: examId);
    }

    state = state.copyWith(isLoading: true, clearError: true);
    final apiClient = _ref.read(apiClientProvider);

    final queryParams = <String, dynamic>{
      'school_id': schoolId,
    };
    final effectiveExamId = examId ?? state.selectedExamId;
    if (effectiveExamId != null && effectiveExamId.isNotEmpty) {
      queryParams['exam_id'] = effectiveExamId;
    }
    if (state.selectedClassId != null && state.selectedClassId!.isNotEmpty) {
      queryParams['class_id'] = state.selectedClassId;
    }
    if (state.selectedSectionId != null && state.selectedSectionId!.isNotEmpty) {
      queryParams['section_id'] = state.selectedSectionId;
    }

    final result = await apiClient.get(
      '/examinations/schedules',
      queryParameters: queryParams,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((item) => ExamScheduleModel.fromJson(item as Map<String, dynamic>)).toList();
      },
    );

    result.when(
      onSuccess: (schedules) {
        state = state.copyWith(isLoading: false, schedules: schedules);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
    );
  }

  Future<bool> createSchedule({
    required String examId,
    required String classId,
    required String sectionId,
    required String subjectId,
    String? teacherSubjectAssignmentId,
    required String examDate,
    required String startTime,
    required String endTime,
    int maxMarks = 100,
    int passMarks = 35,
    String? roomNumber,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final apiClient = _ref.read(apiClientProvider);

    final payload = {
      'class_id': classId,
      'section_id': sectionId,
      'subject_id': subjectId,
      'teacher_subject_assignment_id': teacherSubjectAssignmentId,
      'exam_date': examDate,
      'start_time': startTime,
      'end_time': endTime,
      'max_marks': maxMarks,
      'pass_marks': passMarks,
      'room_number': roomNumber,
    };

    final result = await apiClient.post(
      '/examinations/schedules',
      queryParameters: {
        'school_id': schoolId,
        'exam_id': examId,
      },
      data: payload,
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        loadSchedules();
        _ref.read(examinationsProvider.notifier).loadExaminations();
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> updateSchedule({
    required String scheduleId,
    String? examDate,
    String? startTime,
    String? endTime,
    int? maxMarks,
    int? passMarks,
    String? roomNumber,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final apiClient = _ref.read(apiClientProvider);

    final payload = <String, dynamic>{};
    if (examDate != null) payload['exam_date'] = examDate;
    if (startTime != null) payload['start_time'] = startTime;
    if (endTime != null) payload['end_time'] = endTime;
    if (maxMarks != null) payload['max_marks'] = maxMarks;
    if (passMarks != null) payload['pass_marks'] = passMarks;
    if (roomNumber != null) payload['room_number'] = roomNumber;

    final result = await apiClient.put(
      '/examinations/schedules/$scheduleId',
      queryParameters: {'school_id': schoolId},
      data: payload,
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        loadSchedules();
        _ref.read(examinationsProvider.notifier).loadExaminations();
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> deleteSchedule(String scheduleId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final apiClient = _ref.read(apiClientProvider);

    final result = await apiClient.delete(
      '/examinations/schedules/$scheduleId',
      queryParameters: {'school_id': schoolId},
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        loadSchedules();
        _ref.read(examinationsProvider.notifier).loadExaminations();
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }
}

final examSchedulesProvider = StateNotifierProvider<ExamSchedulesNotifier, ExamSchedulesState>((ref) {
  final notifier = ExamSchedulesNotifier(ref);
  ref.listen<String?>(selectedSchoolIdProvider, (prev, next) {
    if (prev != next) {
      notifier.loadSchedules();
    }
  });
  return notifier;
});


// ==================================================
// Bulk Timetable Generator Provider
// ==================================================
class BulkTimetableGeneratorState {
  final bool isLoading;
  final String? errorMessage;
  final BulkTimetablePreviewResponseModel? preview;

  const BulkTimetableGeneratorState({
    this.isLoading = false,
    this.errorMessage,
    this.preview,
  });

  BulkTimetableGeneratorState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    BulkTimetablePreviewResponseModel? preview,
    bool clearPreview = false,
  }) {
    return BulkTimetableGeneratorState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      preview: clearPreview ? null : (preview ?? this.preview),
    );
  }
}

class BulkTimetableGeneratorNotifier extends StateNotifier<BulkTimetableGeneratorState> {
  final Ref _ref;

  BulkTimetableGeneratorNotifier(this._ref) : super(const BulkTimetableGeneratorState());

  void clear() {
    state = const BulkTimetableGeneratorState();
  }

  Future<bool> generatePreview({
    required String examinationId,
    required List<String> classIds,
    List<String>? sectionIds,
    List<String>? subjectIds,
    List<String>? paperIds,
    required String startDate,
    String? endDate,
    int gapDays = 1,
    String startTime = '09:00:00',
    int durationMinutes = 180,
    List<Map<String, dynamic>>? sessions,
    String schedulingStrategy = 'ONE_PAPER_PER_DAY',
    bool excludeWeekends = true,
    int maxMarks = 100,
    int passMarks = 35,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearPreview: true);
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final apiClient = _ref.read(apiClientProvider);

    final payload = {
      'school_id': schoolId,
      'examination_id': examinationId,
      'class_ids': classIds,
      'section_ids': sectionIds,
      'subject_ids': subjectIds,
      'paper_ids': paperIds,
      'start_date': startDate,
      'end_date': endDate,
      'gap_days': gapDays,
      'start_time': startTime,
      'duration_minutes': durationMinutes,
      'sessions': sessions,
      'scheduling_strategy': schedulingStrategy,
      'exclude_weekends': excludeWeekends,
      'max_marks': maxMarks,
      'pass_marks': passMarks,
    };

    final result = await apiClient.post(
      '/examinations/schedules/bulk-preview',
      data: payload,
      mapper: (json) {
        final payload = Map<String, dynamic>.from(json as Map);
        final data = payload['data'] != null ? Map<String, dynamic>.from(payload['data'] as Map) : <String, dynamic>{};
        return BulkTimetablePreviewResponseModel.fromJson(data);
      },
    );

    return result.when(
      onSuccess: (preview) {
        state = state.copyWith(isLoading: false, preview: preview);
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> confirmSchedules({
    required String examinationId,
    required List<Map<String, dynamic>> schedules,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final apiClient = _ref.read(apiClientProvider);

    final payload = {
      'school_id': schoolId,
      'examination_id': examinationId,
      'schedules': schedules,
    };

    final result = await apiClient.post(
      '/examinations/schedules/bulk-confirm',
      data: payload,
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        state = state.copyWith(isLoading: false, clearPreview: true);
        _ref.read(examSchedulesProvider.notifier).loadSchedules();
        _ref.read(examinationsProvider.notifier).loadExaminations();
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }
}

final bulkTimetableGeneratorProvider = StateNotifierProvider<BulkTimetableGeneratorNotifier, BulkTimetableGeneratorState>((ref) {
  return BulkTimetableGeneratorNotifier(ref);
});


// ==================================================
// Exam Papers Management Provider
// ==================================================
class ExamPapersState {
  final bool isLoading;
  final String? errorMessage;
  final List<ExamPaperModel> papers;
  final String? selectedPaperId;

  const ExamPapersState({
    this.isLoading = false,
    this.errorMessage,
    this.papers = const [],
    this.selectedPaperId,
  });

  ExamPapersState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    List<ExamPaperModel>? papers,
    String? selectedPaperId,
    bool clearSelected = false,
  }) {
    return ExamPapersState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      papers: papers ?? this.papers,
      selectedPaperId: clearSelected ? null : (selectedPaperId ?? this.selectedPaperId),
    );
  }

  ExamPaperModel? get selectedPaper {
    if (selectedPaperId == null) return null;
    try {
      return papers.firstWhere((p) => p.id == selectedPaperId);
    } catch (_) {
      return null;
    }
  }
}

class ExamPapersNotifier extends StateNotifier<ExamPapersState> {
  final Ref _ref;

  ExamPapersNotifier(this._ref) : super(const ExamPapersState());

  void selectPaper(String? paperId) {
    state = state.copyWith(selectedPaperId: paperId, clearSelected: paperId == null);
  }

  Future<void> loadPapers(String examId) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null || schoolId.isEmpty) return;

    state = state.copyWith(isLoading: true, clearError: true);
    final apiClient = _ref.read(apiClientProvider);

    final result = await apiClient.get(
      '/examinations/$examId/papers',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((item) => ExamPaperModel.fromJson(item as Map<String, dynamic>)).toList();
      },
    );

    result.when(
      onSuccess: (papers) {
        final currentSelected = state.selectedPaperId;
        final stillExists = papers.any((p) => p.id == currentSelected);
        state = state.copyWith(
          isLoading: false,
          papers: papers,
          selectedPaperId: stillExists ? currentSelected : (papers.isNotEmpty ? papers.first.id : null),
        );
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
    );
  }

  Future<bool> createPaper(String examId, Map<String, dynamic> payload) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final apiClient = _ref.read(apiClientProvider);

    final result = await apiClient.post(
      '/examinations/$examId/papers',
      queryParameters: {'school_id': schoolId},
      data: payload,
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        loadPapers(examId);
        _ref.read(examinationsProvider.notifier).loadExaminations();
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> updatePaper(String examId, String paperId, Map<String, dynamic> payload) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final apiClient = _ref.read(apiClientProvider);

    final result = await apiClient.put(
      '/examinations/papers/$paperId',
      queryParameters: {'school_id': schoolId},
      data: payload,
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        loadPapers(examId);
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> deletePaper(String examId, String paperId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final apiClient = _ref.read(apiClientProvider);

    final result = await apiClient.delete(
      '/examinations/papers/$paperId',
      queryParameters: {'school_id': schoolId},
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        loadPapers(examId);
        _ref.read(examinationsProvider.notifier).loadExaminations();
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> configurePaperClasses(String examId, String paperId, List<Map<String, dynamic>> configs) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final apiClient = _ref.read(apiClientProvider);

    final result = await apiClient.post(
      '/examinations/papers/$paperId/classes',
      queryParameters: {'school_id': schoolId},
      data: {'configs': configs},
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        loadPapers(examId);
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }
}

final examPapersProvider = StateNotifierProvider<ExamPapersNotifier, ExamPapersState>((ref) {
  return ExamPapersNotifier(ref);
});


// ==================================================
// Question Paper Intelligence Provider
// ==================================================
class QuestionPaperIntelligenceState {
  final bool isLoading;
  final bool isExtracting;
  final String? errorMessage;
  final QuestionPaperModel? questionPaper;
  final QuestionPaperExtractionResponseModel? lastExtraction;
  final List<SyllabusTopicOptionModel> syllabusTopics;

  const QuestionPaperIntelligenceState({
    this.isLoading = false,
    this.isExtracting = false,
    this.errorMessage,
    this.questionPaper,
    this.lastExtraction,
    this.syllabusTopics = const [],
  });

  QuestionPaperIntelligenceState copyWith({
    bool? isLoading,
    bool? isExtracting,
    String? errorMessage,
    bool clearError = false,
    QuestionPaperModel? questionPaper,
    bool clearQuestionPaper = false,
    QuestionPaperExtractionResponseModel? lastExtraction,
    bool clearExtraction = false,
    List<SyllabusTopicOptionModel>? syllabusTopics,
  }) {
    return QuestionPaperIntelligenceState(
      isLoading: isLoading ?? this.isLoading,
      isExtracting: isExtracting ?? this.isExtracting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      questionPaper: clearQuestionPaper ? null : (questionPaper ?? this.questionPaper),
      lastExtraction: clearExtraction ? null : (lastExtraction ?? this.lastExtraction),
      syllabusTopics: syllabusTopics ?? this.syllabusTopics,
    );
  }
}

class QuestionPaperIntelligenceNotifier extends StateNotifier<QuestionPaperIntelligenceState> {
  final Ref _ref;

  QuestionPaperIntelligenceNotifier(this._ref) : super(const QuestionPaperIntelligenceState());

  void clear() {
    state = const QuestionPaperIntelligenceState();
  }

  Future<void> loadQuestionPaper({required String examId, required String paperId}) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    final apiClient = _ref.read(apiClientProvider);

    final result = await apiClient.get(
      '/examinations/$examId/papers/$paperId/question-paper',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return QuestionPaperModel.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    result.when(
      onSuccess: (qp) {
        state = state.copyWith(isLoading: false, questionPaper: qp);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, clearQuestionPaper: true);
      },
    );
  }

  Future<void> loadSyllabusTopics({required String examId, required String paperId}) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    final apiClient = _ref.read(apiClientProvider);
    final result = await apiClient.get(
      '/examinations/$examId/papers/$paperId/syllabus-topics',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((item) => SyllabusTopicOptionModel.fromJson(item as Map<String, dynamic>)).toList();
      },
    );

    result.when(
      onSuccess: (topics) {
        state = state.copyWith(syllabusTopics: topics);
      },
      onFailure: (failure) {
        // Keep existing topics if error
      },
    );
  }

  Future<QuestionPaperExtractionResponseModel?> uploadAndExtract({
    required String examId,
    required String paperId,
    List<int>? fileBytes,
    String? fileName,
    String? rawText,
  }) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return null;

    state = state.copyWith(isExtracting: true, clearError: true);
    final apiClient = _ref.read(apiClientProvider);

    dynamic bodyData;
    if (fileBytes != null && fileName != null) {
      bodyData = FormData.fromMap({
        'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
        if (rawText != null && rawText.isNotEmpty) 'raw_text': rawText,
      });
    } else {
      bodyData = FormData.fromMap({
        'raw_text': rawText ?? '',
      });
    }

    final result = await apiClient.post(
      '/examinations/$examId/papers/$paperId/question-paper/upload',
      queryParameters: {'school_id': schoolId},
      data: bodyData,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return QuestionPaperExtractionResponseModel.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    return result.when(
      onSuccess: (extraction) {
        state = state.copyWith(isExtracting: false, lastExtraction: extraction);
        loadQuestionPaper(examId: examId, paperId: paperId);
        return extraction;
      },
      onFailure: (failure) {
        state = state.copyWith(isExtracting: false, errorMessage: failure.message);
        return null;
      },
    );
  }

  Future<bool> verifyQuestionPaper({
    required String examId,
    required String paperId,
    required Map<String, dynamic> payload,
  }) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return false;

    state = state.copyWith(isLoading: true, clearError: true);
    final apiClient = _ref.read(apiClientProvider);

    final result = await apiClient.put(
      '/examinations/$examId/papers/$paperId/question-paper/verify',
      queryParameters: {'school_id': schoolId},
      data: payload,
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        state = state.copyWith(isLoading: false);
        loadQuestionPaper(examId: examId, paperId: paperId);
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }
}

final questionPaperIntelligenceProvider = StateNotifierProvider<QuestionPaperIntelligenceNotifier, QuestionPaperIntelligenceState>((ref) {
  return QuestionPaperIntelligenceNotifier(ref);
});


// ==================================================
// Question-Wise Marks Spreadsheet Provider
// ==================================================
class QuestionWiseMarksState {
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final QuestionWiseMarksMatrixModel? matrix;

  const QuestionWiseMarksState({
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.matrix,
  });

  QuestionWiseMarksState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
    QuestionWiseMarksMatrixModel? matrix,
    bool clearMatrix = false,
  }) {
    return QuestionWiseMarksState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      matrix: clearMatrix ? null : (matrix ?? this.matrix),
    );
  }
}

class QuestionWiseMarksNotifier extends StateNotifier<QuestionWiseMarksState> {
  final Ref _ref;

  QuestionWiseMarksNotifier(this._ref) : super(const QuestionWiseMarksState());

  void clear() {
    state = const QuestionWiseMarksState();
  }

  Future<void> loadMarksMatrix({required String examId, required String paperId}) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    final apiClient = _ref.read(apiClientProvider);

    final result = await apiClient.get(
      '/examinations/$examId/papers/$paperId/marks/question-wise',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return QuestionWiseMarksMatrixModel.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    result.when(
      onSuccess: (matrix) {
        state = state.copyWith(isLoading: false, matrix: matrix);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
    );
  }

  Future<bool> saveMarks({
    required String examId,
    required String paperId,
    required List<Map<String, dynamic>> rows,
    bool isDraft = false,
  }) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return false;

    state = state.copyWith(isSaving: true, clearError: true);
    final apiClient = _ref.read(apiClientProvider);

    final payload = {
      'is_draft': isDraft,
      'rows': rows,
    };

    final result = await apiClient.post(
      '/examinations/$examId/papers/$paperId/marks/question-wise',
      queryParameters: {'school_id': schoolId},
      data: payload,
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        state = state.copyWith(isSaving: false);
        loadMarksMatrix(examId: examId, paperId: paperId);
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isSaving: false, errorMessage: failure.message);
        return false;
      },
    );
  }
}

final questionWiseMarksProvider = StateNotifierProvider<QuestionWiseMarksNotifier, QuestionWiseMarksState>((ref) {
  return QuestionWiseMarksNotifier(ref);
});


// ==================================================
// Question-Wise Assessment Analytics Provider
// ==================================================
class QuestionWiseAnalyticsState {
  final bool isLoading;
  final String? errorMessage;
  final QuestionWiseAnalyticsModel? analytics;

  const QuestionWiseAnalyticsState({
    this.isLoading = false,
    this.errorMessage,
    this.analytics,
  });

  QuestionWiseAnalyticsState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    QuestionWiseAnalyticsModel? analytics,
    bool clearAnalytics = false,
  }) {
    return QuestionWiseAnalyticsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      analytics: clearAnalytics ? null : (analytics ?? this.analytics),
    );
  }
}

class QuestionWiseAnalyticsNotifier extends StateNotifier<QuestionWiseAnalyticsState> {
  final Ref _ref;

  QuestionWiseAnalyticsNotifier(this._ref) : super(const QuestionWiseAnalyticsState());

  void clear() {
    state = const QuestionWiseAnalyticsState();
  }

  Future<void> loadAnalytics({required String examId, required String paperId}) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    final apiClient = _ref.read(apiClientProvider);

    final result = await apiClient.get(
      '/examinations/$examId/papers/$paperId/analytics',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return QuestionWiseAnalyticsModel.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    result.when(
      onSuccess: (analytics) {
        state = state.copyWith(isLoading: false, analytics: analytics);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
    );
  }
}

final questionWiseAnalyticsProvider = StateNotifierProvider<QuestionWiseAnalyticsNotifier, QuestionWiseAnalyticsState>((ref) {
  return QuestionWiseAnalyticsNotifier(ref);
});
