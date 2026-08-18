import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:intl/intl.dart';
import '../../../dashboard/presentation/providers/active_school_provider.dart';
import '../../data/datasources/leave_requests_datasource.dart';
import '../../data/repositories/leave_requests_repository.dart';
import '../../data/models/leave_request_model.dart';

// Datasource Provider
final leaveRequestsDatasourceProvider = Provider<LeaveRequestsDatasource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return LeaveRequestsDatasource(apiClient);
});

// Repository Provider
final leaveRequestsRepositoryProvider = Provider<LeaveRequestsRepository>((ref) {
  final datasource = ref.watch(leaveRequestsDatasourceProvider);
  return LeaveRequestsRepository(datasource);
});

class LeaveRequestsState {
  final List<LeaveRequest> requests;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;
  final bool isMutating;
  final String? status;
  final String? leaveType;
  final DateTime? startDate;
  final DateTime? endDate;
  final int skip;
  final int limit;
  final bool hasMore;

  LeaveRequestsState({
    required this.requests,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.isMutating = false,
    this.status = 'PENDING',
    this.leaveType = 'ALL',
    this.startDate,
    this.endDate,
    this.skip = 0,
    this.limit = 20,
    this.hasMore = true,
  });

  LeaveRequestsState copyWith({
    List<LeaveRequest>? requests,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool? isMutating,
    String? status,
    String? leaveType,
    DateTime? startDate,
    DateTime? endDate,
    int? skip,
    int? limit,
    bool? hasMore,
    bool clearError = false,
    bool clearDates = false,
  }) {
    return LeaveRequestsState(
      requests: requests ?? this.requests,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isMutating: isMutating ?? this.isMutating,
      status: status ?? this.status,
      leaveType: leaveType ?? this.leaveType,
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
      skip: skip ?? this.skip,
      limit: limit ?? this.limit,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class LeaveRequestsNotifier extends StateNotifier<LeaveRequestsState> {
  final LeaveRequestsRepository _repository;
  final String? _activeSchoolId;

  LeaveRequestsNotifier(this._repository, this._activeSchoolId)
      : super(LeaveRequestsState(requests: [])) {
    if (_activeSchoolId != null && _activeSchoolId.isNotEmpty) {
      fetchRequests();
    }
  }

  Future<void> setFilters({
    String? status,
    String? leaveType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    state = state.copyWith(
      status: status,
      leaveType: leaveType,
      startDate: startDate,
      endDate: endDate,
      skip: 0,
      requests: const [],
      hasMore: true,
      clearError: true,
    );
    await fetchRequests();
  }

  Future<void> fetchRequests({bool isRefresh = false, bool isLoadMore = false}) async {
    if (_activeSchoolId == null || _activeSchoolId.isEmpty) {
      state = state.copyWith(isLoading: false, errorMessage: 'No active school context found.');
      return;
    }

    if (isLoadMore) {
      if (state.isLoadingMore || !state.hasMore) return;
      state = state.copyWith(isLoadingMore: true, clearError: true);
    } else {
      if (state.isLoading && !isRefresh) return;
      if (!isRefresh) {
        state = state.copyWith(isLoading: true, clearError: true, skip: 0, requests: const [], hasMore: true);
      } else {
        state = state.copyWith(clearError: true, skip: 0, requests: const [], hasMore: true);
      }
    }

    final requestSchoolId = _activeSchoolId;
    final currentSkip = state.skip;
    final currentLimit = state.limit;
    final formattedStart = state.startDate != null ? DateFormat('yyyy-MM-dd').format(state.startDate!) : null;
    final formattedEnd = state.endDate != null ? DateFormat('yyyy-MM-dd').format(state.endDate!) : null;

    final result = await _repository.getLeaveRequests(
      schoolId: requestSchoolId,
      status: state.status,
      leaveType: state.leaveType,
      startDate: formattedStart,
      endDate: formattedEnd,
      skip: currentSkip,
      limit: currentLimit,
    );

    if (!mounted || _activeSchoolId != requestSchoolId) {
      return;
    }

    result.when(
      onSuccess: (list) {
        final newRequests = isLoadMore ? [...state.requests, ...list] : list;
        final hasMoreItems = list.length >= currentLimit;
        state = state.copyWith(
          requests: newRequests,
          isLoading: false,
          isLoadingMore: false,
          skip: currentSkip + list.length,
          hasMore: hasMoreItems,
        );
      },
      onFailure: (failure) {
        state = state.copyWith(
          isLoading: false,
          isLoadingMore: false,
          errorMessage: failure.message,
        );
      },
    );
  }

  Future<bool> approveLeave(String leaveId) async {
    return _reviewLeave(leaveId, 'APPROVE');
  }

  Future<bool> rejectLeave(String leaveId, String reason) async {
    return _reviewLeave(leaveId, 'REJECT', remarks: reason);
  }

  Future<bool> _reviewLeave(String leaveId, String decision, {String? remarks}) async {
    if (_activeSchoolId == null || _activeSchoolId.isEmpty) return false;

    state = state.copyWith(isMutating: true, clearError: true);

    final requestSchoolId = _activeSchoolId;
    final result = await _repository.reviewLeaveRequest(
      leaveId: leaveId,
      decision: decision,
      remarks: remarks,
    );

    if (!mounted || _activeSchoolId != requestSchoolId) {
      return false;
    }

    return result.when(
      onSuccess: (_) {
        state = state.copyWith(isMutating: false);
        fetchRequests(isRefresh: true);
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isMutating: false, errorMessage: failure.message);
        return false;
      },
    );
  }
}

final leaveRequestsStateProvider = StateNotifierProvider<LeaveRequestsNotifier, LeaveRequestsState>((ref) {
  final repo = ref.watch(leaveRequestsRepositoryProvider);
  final activeSchoolId = ref.watch(activeSchoolIdProvider);
  return LeaveRequestsNotifier(repo, activeSchoolId);
});

// Leave Detail State
class TeacherLeaveDetailState {
  final LeaveRequest? request;
  final bool isLoading;
  final String? errorMessage;
  final bool isReviewing;
  final String? reviewSuccessMessage;

  TeacherLeaveDetailState({
    this.request,
    this.isLoading = false,
    this.errorMessage,
    this.isReviewing = false,
    this.reviewSuccessMessage,
  });

  TeacherLeaveDetailState copyWith({
    LeaveRequest? request,
    bool? isLoading,
    String? errorMessage,
    bool? isReviewing,
    String? reviewSuccessMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return TeacherLeaveDetailState(
      request: request ?? this.request,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isReviewing: isReviewing ?? this.isReviewing,
      reviewSuccessMessage: clearSuccess ? null : (reviewSuccessMessage ?? this.reviewSuccessMessage),
    );
  }
}

class TeacherLeaveDetailNotifier extends StateNotifier<TeacherLeaveDetailState> {
  final LeaveRequestsRepository _repository;
  final String _leaveId;
  final Ref _ref;

  TeacherLeaveDetailNotifier(this._repository, this._leaveId, this._ref)
      : super(TeacherLeaveDetailState()) {
    fetchDetail();
  }

  Future<void> fetchDetail() async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    final result = await _repository.getTeacherLeave(_leaveId);
    if (!mounted) return;
    result.when(
      onSuccess: (data) {
        state = state.copyWith(request: data, isLoading: false);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
    );
  }

  Future<bool> reviewRequest(String decision, String? remarks) async {
    state = state.copyWith(isReviewing: true, clearError: true, clearSuccess: true);
    final result = await _repository.reviewLeaveRequest(
      leaveId: _leaveId,
      decision: decision,
      remarks: remarks,
    );
    if (!mounted) return false;
    return result.when(
      onSuccess: (data) async {
        state = state.copyWith(
          request: data,
          isReviewing: false,
          reviewSuccessMessage: 'Leave request reviewed successfully.',
        );
        _ref.read(leaveRequestsStateProvider.notifier).fetchRequests(isRefresh: true);
        return true;
      },
      onFailure: (failure) async {
        if (failure.statusCode == 403) {
          state = state.copyWith(
            isReviewing: false,
            errorMessage: 'You are not authorized to review this leave request.',
          );
          return false;
        } else {
          // Timeout reconciliation
          final detailResult = await _repository.getTeacherLeave(_leaveId);
          bool match = false;
          final expectedStatus = decision == 'APPROVE' ? 'APPROVED' : 'REJECTED';
          detailResult.when(
            onSuccess: (serverData) {
              if (serverData.status.toUpperCase() == expectedStatus) {
                match = true;
              }
            },
            onFailure: (_) {},
          );

          if (match) {
            state = state.copyWith(
              request: detailResult.dataOrNull,
              isReviewing: false,
              reviewSuccessMessage: 'Leave request reviewed successfully.',
            );
            _ref.read(leaveRequestsStateProvider.notifier).fetchRequests(isRefresh: true);
            return true;
          } else {
            state = state.copyWith(
              isReviewing: false,
              errorMessage: failure.message,
            );
            return false;
          }
        }
      },
    );
  }
}

final teacherLeaveDetailProvider = StateNotifierProvider.family<
    TeacherLeaveDetailNotifier, TeacherLeaveDetailState, String>((ref, leaveId) {
  final repo = ref.watch(leaveRequestsRepositoryProvider);
  return TeacherLeaveDetailNotifier(repo, leaveId, ref);
});

// Leave History State
class TeacherLeaveHistoryState {
  final String teacherId;
  final List<LeaveRequest> records;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;
  final String? status;
  final String? leaveType;
  final DateTime? startDate;
  final DateTime? endDate;
  final int skip;
  final int limit;
  final bool hasMore;

  TeacherLeaveHistoryState({
    required this.teacherId,
    this.records = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.status = 'ALL',
    this.leaveType = 'ALL',
    this.startDate,
    this.endDate,
    this.skip = 0,
    this.limit = 20,
    this.hasMore = true,
  });

  TeacherLeaveHistoryState copyWith({
    String? teacherId,
    List<LeaveRequest>? records,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    String? status,
    String? leaveType,
    DateTime? startDate,
    DateTime? endDate,
    int? skip,
    int? limit,
    bool? hasMore,
    bool clearError = false,
    bool clearDates = false,
  }) {
    return TeacherLeaveHistoryState(
      teacherId: teacherId ?? this.teacherId,
      records: records ?? this.records,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      status: status ?? this.status,
      leaveType: leaveType ?? this.leaveType,
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
      skip: skip ?? this.skip,
      limit: limit ?? this.limit,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class TeacherLeaveHistoryNotifier extends StateNotifier<TeacherLeaveHistoryState> {
  final LeaveRequestsRepository _repository;
  final String _teacherId;

  TeacherLeaveHistoryNotifier(this._repository, this._teacherId)
      : super(TeacherLeaveHistoryState(teacherId: _teacherId)) {
    fetchHistory();
  }

  Future<void> setFilters({
    String? status,
    String? leaveType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    state = state.copyWith(
      status: status,
      leaveType: leaveType,
      startDate: startDate,
      endDate: endDate,
      skip: 0,
      records: const [],
      hasMore: true,
      clearError: true,
    );
    await fetchHistory();
  }

  Future<void> fetchHistory({bool isLoadMore = false}) async {
    if (isLoadMore) {
      if (state.isLoadingMore || !state.hasMore) return;
      state = state.copyWith(isLoadingMore: true, clearError: true);
    } else {
      if (state.isLoading) return;
      state = state.copyWith(isLoading: true, clearError: true, skip: 0, records: const [], hasMore: true);
    }

    final currentSkip = state.skip;
    final currentLimit = state.limit;
    final formattedStart = state.startDate != null ? DateFormat('yyyy-MM-dd').format(state.startDate!) : null;
    final formattedEnd = state.endDate != null ? DateFormat('yyyy-MM-dd').format(state.endDate!) : null;

    final result = await _repository.getTeacherLeaveHistory(
      teacherId: _teacherId,
      status: state.status,
      leaveType: state.leaveType,
      startDate: formattedStart,
      endDate: formattedEnd,
      skip: currentSkip,
      limit: currentLimit,
    );

    if (!mounted) return;

    result.when(
      onSuccess: (items) {
        final newRecords = isLoadMore ? [...state.records, ...items] : items;
        final hasMoreItems = items.length >= currentLimit;
        state = state.copyWith(
          records: newRecords,
          isLoading: false,
          isLoadingMore: false,
          skip: currentSkip + items.length,
          hasMore: hasMoreItems,
        );
      },
      onFailure: (failure) {
        state = state.copyWith(
          isLoading: false,
          isLoadingMore: false,
          errorMessage: failure.message,
        );
      },
    );
  }
}

final teacherLeaveHistoryStateProvider = StateNotifierProvider.family<
    TeacherLeaveHistoryNotifier, TeacherLeaveHistoryState, String>((ref, teacherId) {
  final repo = ref.watch(leaveRequestsRepositoryProvider);
  return TeacherLeaveHistoryNotifier(repo, teacherId);
});
