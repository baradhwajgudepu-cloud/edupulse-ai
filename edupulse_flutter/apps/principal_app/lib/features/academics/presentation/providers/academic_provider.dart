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
  final bool isLoading;
  final String? errorMessage;

  AcademicState({
    required this.examinations,
    required this.scheduleSummaries,
    this.classes = const [],
    this.sections = const [],
    this.academicYears = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  AcademicState copyWith({
    List<Examination>? examinations,
    Map<String, MarksSummary>? scheduleSummaries,
    List<Map<String, dynamic>>? classes,
    List<Map<String, dynamic>>? sections,
    List<Map<String, dynamic>>? academicYears,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AcademicState(
      examinations: examinations ?? this.examinations,
      scheduleSummaries: scheduleSummaries ?? this.scheduleSummaries,
      classes: classes ?? this.classes,
      sections: sections ?? this.sections,
      academicYears: academicYears ?? this.academicYears,
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
}

final academicStateProvider = StateNotifierProvider<AcademicNotifier, AcademicState>((ref) {
  final repo = ref.watch(academicRepositoryProvider);
  final session = ref.watch(sessionManagerProvider);
  return AcademicNotifier(repo, session);
});
