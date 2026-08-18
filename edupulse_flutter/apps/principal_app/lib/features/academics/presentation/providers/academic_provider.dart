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
  final bool isLoading;
  final String? errorMessage;

  AcademicState({
    required this.examinations,
    required this.scheduleSummaries,
    this.isLoading = false,
    this.errorMessage,
  });

  AcademicState copyWith({
    List<Examination>? examinations,
    Map<String, MarksSummary>? scheduleSummaries,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AcademicState(
      examinations: examinations ?? this.examinations,
      scheduleSummaries: scheduleSummaries ?? this.scheduleSummaries,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AcademicNotifier extends StateNotifier<AcademicState> {
  final AcademicRepository _repository;
  final SessionManager _sessionManager;

  AcademicNotifier(this._repository, this._sessionManager)
      : super(AcademicState(examinations: [], scheduleSummaries: {}));

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
}

final academicStateProvider = StateNotifierProvider<AcademicNotifier, AcademicState>((ref) {
  final repo = ref.watch(academicRepositoryProvider);
  final session = ref.watch(sessionManagerProvider);
  return AcademicNotifier(repo, session);
});
