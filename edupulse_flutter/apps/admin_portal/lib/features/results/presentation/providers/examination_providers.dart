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

  Future<void> loadSchedules() async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null || schoolId.isEmpty) {
      state = state.copyWith(schedules: [], isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    final apiClient = _ref.read(apiClientProvider);

    final queryParams = <String, dynamic>{
      'school_id': schoolId,
    };
    if (state.selectedExamId != null && state.selectedExamId!.isNotEmpty) {
      queryParams['exam_id'] = state.selectedExamId;
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
    required String startDate,
    int gapDays = 1,
    String startTime = '09:00:00',
    int durationMinutes = 180,
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
      'start_date': startDate,
      'gap_days': gapDays,
      'start_time': startTime,
      'duration_minutes': durationMinutes,
      'exclude_weekends': excludeWeekends,
      'max_marks': maxMarks,
      'pass_marks': passMarks,
    };

    final result = await apiClient.post(
      '/examinations/schedules/bulk-preview',
      data: payload,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return BulkTimetablePreviewResponseModel.fromJson(payload['data'] as Map<String, dynamic>);
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
