import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import '../../data/datasources/academic_datasource.dart';
import '../../data/repositories/academic_repository.dart';
import '../../data/models/academic_models.dart';

// Datasource Provider
final academicDatasourceProvider = Provider<AcademicDatasource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AcademicDatasource(apiClient);
});

// Repository Provider
final academicRepositoryProvider = Provider<AcademicRepository>((ref) {
  final datasource = ref.watch(academicDatasourceProvider);
  return AcademicRepository(datasource);
});

class AcademicState {
  final List<Examination> examinations;
  final Map<String, MarksSummary> scheduleSummaries;
  final List<Map<String, dynamic>> classes;
  final List<Map<String, dynamic>> sections;
  final List<Map<String, dynamic>> academicYears;
  final Map<String, dynamic>? planningSummary;
  final AcademicHeatmapData? academicHeatmap;
  final List<SyllabusRecoveryPlan> recoveryPlans;
  final TeacherAbsenceImpact? absenceImpact;
  final bool isRecoveryLoading;
  final String? recoveryMessage;
  final String selectedHeatmapFilter;
  final bool isLoading;
  final String? errorMessage;

  AcademicState({
    required this.examinations,
    required this.scheduleSummaries,
    this.classes = const [],
    this.sections = const [],
    this.academicYears = const [],
    this.planningSummary,
    this.academicHeatmap,
    this.recoveryPlans = const [],
    this.absenceImpact,
    this.isRecoveryLoading = false,
    this.recoveryMessage,
    this.selectedHeatmapFilter = 'ALL',
    this.isLoading = false,
    this.errorMessage,
  });

  AcademicState copyWith({
    List<Examination>? examinations,
    Map<String, MarksSummary>? scheduleSummaries,
    List<Map<String, dynamic>>? classes,
    List<Map<String, dynamic>>? sections,
    List<Map<String, dynamic>>? academicYears,
    Map<String, dynamic>? planningSummary,
    AcademicHeatmapData? academicHeatmap,
    List<SyllabusRecoveryPlan>? recoveryPlans,
    TeacherAbsenceImpact? absenceImpact,
    bool? isRecoveryLoading,
    String? recoveryMessage,
    String? selectedHeatmapFilter,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool clearRecoveryMessage = false,
  }) {
    return AcademicState(
      examinations: examinations ?? this.examinations,
      scheduleSummaries: scheduleSummaries ?? this.scheduleSummaries,
      classes: classes ?? this.classes,
      sections: sections ?? this.sections,
      academicYears: academicYears ?? this.academicYears,
      planningSummary: planningSummary ?? this.planningSummary,
      academicHeatmap: academicHeatmap ?? this.academicHeatmap,
      recoveryPlans: recoveryPlans ?? this.recoveryPlans,
      absenceImpact: absenceImpact ?? this.absenceImpact,
      isRecoveryLoading: isRecoveryLoading ?? this.isRecoveryLoading,
      recoveryMessage: clearRecoveryMessage ? null : (recoveryMessage ?? this.recoveryMessage),
      selectedHeatmapFilter: selectedHeatmapFilter ?? this.selectedHeatmapFilter,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AcademicNotifier extends StateNotifier<AcademicState> {
  final AcademicRepository _repository;
  final SessionManager _sessionManager;

  AcademicNotifier(this._repository, this._sessionManager)
      : super(AcademicState(examinations: [], scheduleSummaries: {}, classes: [], sections: [], academicYears: []));

  Future<void> fetchExaminations({bool isRefresh = false}) async {
    if (!isRefresh) {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) {
      state = state.copyWith(isLoading: false, errorMessage: 'No active school context found.');
      return;
    }

    final result = await _repository.getExaminations(schoolId: schoolId);

    result.when(
      onSuccess: (list) {
        state = state.copyWith(examinations: list, isLoading: false);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
    );

    // Concurrently fetch planning and syllabus metrics
    await fetchPlanningSummary();
  }

  Future<void> fetchPlanningSummary() async {
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) return;

    final result = await _repository.getAcademicPlanningSummary(
      schoolId: schoolId,
      academicYearId: '',
    );

    result.when(
      onSuccess: (data) {
        state = state.copyWith(planningSummary: data);
      },
      onFailure: (_) {},
    );
  }

  Future<void> fetchClassesAndSections() async {
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) return;

    final classResult = await _repository.getClasses(schoolId: schoolId);
    final sectionResult = await _repository.getSections(schoolId: schoolId);
    final ayResult = await _repository.getAcademicYears(schoolId: schoolId);

    List<Map<String, dynamic>> loadedClasses = [];
    List<Map<String, dynamic>> loadedSections = [];
    List<Map<String, dynamic>> loadedAYs = [];

    classResult.when(
      onSuccess: (list) => loadedClasses = list,
      onFailure: (failure) {},
    );

    sectionResult.when(
      onSuccess: (list) => loadedSections = list,
      onFailure: (failure) {},
    );

    ayResult.when(
      onSuccess: (list) => loadedAYs = list,
      onFailure: (failure) {},
    );

    state = state.copyWith(
      classes: loadedClasses,
      sections: loadedSections,
      academicYears: loadedAYs,
    );
  }

  Future<List<Map<String, dynamic>>> getSuggestedSchedules({
    required List<String> classIds,
    required String startDate,
    required String endDate,
  }) async {
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) return [];

    final result = await _repository.getSuggestedSchedules(
      schoolId: schoolId,
      classIds: classIds,
      startDate: startDate,
      endDate: endDate,
    );

    return result.when(
      onSuccess: (list) => list,
      onFailure: (failure) => [],
    );
  }

  Future<void> fetchSummaryForSchedule(String scheduleId) async {
    if (state.scheduleSummaries.containsKey(scheduleId)) return; // Already cached

    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) return;

    final result = await _repository.getMarksSummary(schoolId: schoolId, examScheduleId: scheduleId);

    result.when(
      onSuccess: (summary) {
        final newMap = Map<String, MarksSummary>.from(state.scheduleSummaries);
        newMap[scheduleId] = summary;
        state = state.copyWith(scheduleSummaries: newMap);
      },
      onFailure: (failure) {
        // Safe fallback: insert empty summary
        final newMap = Map<String, MarksSummary>.from(state.scheduleSummaries);
        newMap[scheduleId] = MarksSummary.empty();
        state = state.copyWith(scheduleSummaries: newMap);
      },
    );
  }

  Future<bool> createExamination({
    required String examName,
    required String examType,
    required String startDate,
    required String endDate,
    String? description,
  }) async {
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) return false;

    final result = await _repository.createExamination(
      schoolId: schoolId,
      examName: examName,
      examType: examType,
      startDate: startDate,
      endDate: endDate,
      description: description,
    );

    return result.when(
      onSuccess: (exam) {
        fetchExaminations(isRefresh: true);
        return true;
      },
      onFailure: (failure) => false,
    );
  }

  Future<bool> createExaminationWizard({
    required Map<String, dynamic> payload,
  }) async {
    final result = await _repository.createExaminationWizard(payload: payload);
    return result.when(
      onSuccess: (exam) {
        fetchExaminations(isRefresh: true);
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> publishExamination(String id) async {
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) return false;

    final result = await _repository.publishExamination(id: id, schoolId: schoolId);

    return result.when(
      onSuccess: (exam) {
        fetchExaminations(isRefresh: true);
        return true;
      },
      onFailure: (failure) => false,
    );
  }

  Future<void> fetchAcademicHeatmap({bool isRefresh = false, String? academicYearId}) async {
    if (!isRefresh) {
      state = state.copyWith(isRecoveryLoading: true);
    }
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) {
      state = state.copyWith(isRecoveryLoading: false, errorMessage: 'No active school context found.');
      return;
    }
    final result = await _repository.getAcademicHeatmap(schoolId: schoolId, academicYearId: academicYearId);
    result.when(
      onSuccess: (data) {
        state = state.copyWith(academicHeatmap: data, isRecoveryLoading: false);
      },
      onFailure: (failure) {
        state = state.copyWith(isRecoveryLoading: false, errorMessage: failure.message);
      },
    );
  }

  Future<void> fetchRecoveryPlans({String? status, bool isRefresh = false}) async {
    if (!isRefresh) {
      state = state.copyWith(isRecoveryLoading: true);
    }
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) {
      state = state.copyWith(isRecoveryLoading: false);
      return;
    }
    final result = await _repository.getRecoveryPlans(schoolId: schoolId, status: status);
    result.when(
      onSuccess: (plans) {
        state = state.copyWith(recoveryPlans: plans, isRecoveryLoading: false);
      },
      onFailure: (failure) {
        state = state.copyWith(isRecoveryLoading: false, errorMessage: failure.message);
      },
    );
  }

  Future<void> fetchAbsenceImpact({required String teacherId, required String absenceDate}) async {
    state = state.copyWith(isRecoveryLoading: true);
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) {
      state = state.copyWith(isRecoveryLoading: false);
      return;
    }
    final result = await _repository.getTeacherAbsenceImpact(
      schoolId: schoolId,
      teacherId: teacherId,
      absenceDate: absenceDate,
    );
    result.when(
      onSuccess: (impact) {
        state = state.copyWith(absenceImpact: impact, isRecoveryLoading: false);
      },
      onFailure: (failure) {
        state = state.copyWith(isRecoveryLoading: false, errorMessage: failure.message);
      },
    );
  }

  Future<bool> updateRecoveryPlanItem({
    required String planId,
    required String itemId,
    required Map<String, dynamic> data,
  }) async {
    state = state.copyWith(isRecoveryLoading: true);
    final result = await _repository.updateRecoveryPlanItem(
      planId: planId,
      itemId: itemId,
      data: data,
    );
    return result.when(
      onSuccess: (updatedPlan) {
        final updatedList = state.recoveryPlans.map((p) => p.id == planId ? updatedPlan : p).toList();
        state = state.copyWith(
          recoveryPlans: updatedList,
          isRecoveryLoading: false,
          recoveryMessage: 'Slot updated and validated successfully.',
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isRecoveryLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> regenerateRecoveryPlan({required String planId, String? reason}) async {
    state = state.copyWith(isRecoveryLoading: true);
    final result = await _repository.regenerateRecoveryPlan(planId: planId, reason: reason);
    return result.when(
      onSuccess: (updatedPlan) {
        final updatedList = state.recoveryPlans.map((p) => p.id == planId ? updatedPlan : p).toList();
        state = state.copyWith(
          recoveryPlans: updatedList,
          isRecoveryLoading: false,
          recoveryMessage: 'Recovery plan recomputed successfully.',
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isRecoveryLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> approveRecoveryPlan(String planId, {String? remarks}) async {
    state = state.copyWith(isRecoveryLoading: true);
    final result = await _repository.approveRecoveryPlan(planId: planId, remarks: remarks);
    return result.when(
      onSuccess: (updatedPlan) {
        final updatedList = state.recoveryPlans.map((p) => p.id == planId ? updatedPlan : p).toList();
        state = state.copyWith(
          recoveryPlans: updatedList,
          isRecoveryLoading: false,
          recoveryMessage: 'Recovery plan approved and applied to timetable.',
        );
        fetchAcademicHeatmap(isRefresh: true);
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isRecoveryLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> rejectRecoveryPlan(String planId, {required String remarks}) async {
    state = state.copyWith(isRecoveryLoading: true);
    final result = await _repository.rejectRecoveryPlan(planId: planId, remarks: remarks);
    return result.when(
      onSuccess: (updatedPlan) {
        final updatedList = state.recoveryPlans.map((p) => p.id == planId ? updatedPlan : p).toList();
        state = state.copyWith(
          recoveryPlans: updatedList,
          isRecoveryLoading: false,
          recoveryMessage: 'Recovery plan rejected.',
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isRecoveryLoading: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  void setHeatmapFilter(String filter) {
    state = state.copyWith(selectedHeatmapFilter: filter);
  }
}

final academicStateProvider = StateNotifierProvider<AcademicNotifier, AcademicState>((ref) {
  final repo = ref.watch(academicRepositoryProvider);
  final session = ref.watch(sessionManagerProvider);
  return AcademicNotifier(repo, session);
});
