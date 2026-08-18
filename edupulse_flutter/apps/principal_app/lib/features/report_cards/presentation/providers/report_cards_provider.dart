import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import '../../data/datasources/report_cards_datasource.dart';
import '../../data/repositories/report_cards_repository.dart';
import '../../data/models/report_card_model.dart';

// Datasource Provider
final reportCardsDatasourceProvider = Provider<ReportCardsDatasource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ReportCardsDatasource(apiClient);
});

// Repository Provider
final reportCardsRepositoryProvider = Provider<ReportCardsRepository>((ref) {
  final datasource = ref.watch(reportCardsDatasourceProvider);
  return ReportCardsRepository(datasource);
});

class ReportCardsState {
  final List<ReportCard> reportCards;
  final bool isLoading;
  final bool actionInProgress;
  final String? selectedStatus;
  final String? errorMessage;

  ReportCardsState({
    required this.reportCards,
    this.isLoading = false,
    this.actionInProgress = false,
    this.selectedStatus,
    this.errorMessage,
  });

  ReportCardsState copyWith({
    List<ReportCard>? reportCards,
    bool? isLoading,
    bool? actionInProgress,
    String? selectedStatus,
    String? errorMessage,
    bool clearError = false,
    bool clearStatus = false,
  }) {
    return ReportCardsState(
      reportCards: reportCards ?? this.reportCards,
      isLoading: isLoading ?? this.isLoading,
      actionInProgress: actionInProgress ?? this.actionInProgress,
      selectedStatus: clearStatus ? null : (selectedStatus ?? this.selectedStatus),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ReportCardsNotifier extends StateNotifier<ReportCardsState> {
  final ReportCardsRepository _repository;
  final SessionManager _sessionManager;

  ReportCardsNotifier(this._repository, this._sessionManager)
      : super(ReportCardsState(reportCards: [], selectedStatus: 'UNDER_REVIEW'));

  Future<void> fetchReportCards({bool isRefresh = false, String? status}) async {
    final targetStatus = status ?? state.selectedStatus;
    if (!isRefresh) {
      state = state.copyWith(isLoading: true, clearError: true, selectedStatus: targetStatus);
    }

    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) {
      state = state.copyWith(isLoading: false, errorMessage: 'No active school context found.');
      return;
    }

    final result = await _repository.getReportCards(
      schoolId: schoolId,
      status: (targetStatus != null && targetStatus != 'ALL') ? targetStatus : null,
    );

    result.when(
      onSuccess: (list) {
        state = state.copyWith(reportCards: list, isLoading: false);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
    );
  }

  Future<bool> approveCard(String id) async {
    state = state.copyWith(actionInProgress: true, clearError: true);
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) {
      state = state.copyWith(actionInProgress: false, errorMessage: 'No active school context.');
      return false;
    }

    final result = await _repository.approveReportCard(id: id, schoolId: schoolId);
    return result.when(
      onSuccess: (_) async {
        await fetchReportCards(isRefresh: true);
        state = state.copyWith(actionInProgress: false);
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(actionInProgress: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> lockCard(String id) async {
    state = state.copyWith(actionInProgress: true, clearError: true);
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) {
      state = state.copyWith(actionInProgress: false, errorMessage: 'No active school context.');
      return false;
    }

    final result = await _repository.lockReportCard(id: id, schoolId: schoolId);
    return result.when(
      onSuccess: (_) async {
        await fetchReportCards(isRefresh: true);
        state = state.copyWith(actionInProgress: false);
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(actionInProgress: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> unlockCard(String id) async {
    state = state.copyWith(actionInProgress: true, clearError: true);
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) {
      state = state.copyWith(actionInProgress: false, errorMessage: 'No active school context.');
      return false;
    }

    final result = await _repository.unlockReportCard(id: id, schoolId: schoolId);
    return result.when(
      onSuccess: (_) async {
        await fetchReportCards(isRefresh: true);
        state = state.copyWith(actionInProgress: false);
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(actionInProgress: false, errorMessage: failure.message);
        return false;
      },
    );
  }

  Future<bool> bulkPublish(String classId, String sectionId) async {
    state = state.copyWith(actionInProgress: true, clearError: true);
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) {
      state = state.copyWith(actionInProgress: false, errorMessage: 'No active school context.');
      return false;
    }

    final result = await _repository.publishReportCards(
      schoolId: schoolId,
      classId: classId,
      sectionId: sectionId,
    );
    return result.when(
      onSuccess: (_) async {
        await fetchReportCards(isRefresh: true);
        state = state.copyWith(actionInProgress: false);
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(actionInProgress: false, errorMessage: failure.message);
        return false;
      },
    );
  }
}

final reportCardsStateProvider = StateNotifierProvider<ReportCardsNotifier, ReportCardsState>((ref) {
  final repo = ref.watch(reportCardsRepositoryProvider);
  final session = ref.watch(sessionManagerProvider);
  return ReportCardsNotifier(repo, session);
});
