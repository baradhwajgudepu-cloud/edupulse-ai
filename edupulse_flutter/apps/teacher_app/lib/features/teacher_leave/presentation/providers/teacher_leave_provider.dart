import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';

import '../../domain/entities/teacher_leave_entity.dart';
import '../../domain/repositories/teacher_leave_repository.dart';
import '../../data/datasource/teacher_leave_remote_datasource.dart';
import '../../data/repositories/teacher_leave_repository_impl.dart';

// States
sealed class TeacherLeaveListState {
  const TeacherLeaveListState();
}
class TeacherLeaveListInitial extends TeacherLeaveListState {
  const TeacherLeaveListInitial();
}
class TeacherLeaveListLoading extends TeacherLeaveListState {
  const TeacherLeaveListLoading();
}
class TeacherLeaveListLoaded extends TeacherLeaveListState {
  final List<TeacherLeaveEntity> leaves;
  const TeacherLeaveListLoaded(this.leaves);
}
class TeacherLeaveListError extends TeacherLeaveListState {
  final String message;
  const TeacherLeaveListError(this.message);
}

sealed class TeacherLeaveDetailState {
  const TeacherLeaveDetailState();
}
class TeacherLeaveDetailInitial extends TeacherLeaveDetailState {
  const TeacherLeaveDetailInitial();
}
class TeacherLeaveDetailLoading extends TeacherLeaveDetailState {
  const TeacherLeaveDetailLoading();
}
class TeacherLeaveDetailLoaded extends TeacherLeaveDetailState {
  final TeacherLeaveEntity leave;
  const TeacherLeaveDetailLoaded(this.leave);
}
class TeacherLeaveDetailError extends TeacherLeaveDetailState {
  final String message;
  const TeacherLeaveDetailError(this.message);
}

sealed class TeacherLeaveFormState {
  const TeacherLeaveFormState();
}
class TeacherLeaveFormInitial extends TeacherLeaveFormState {
  const TeacherLeaveFormInitial();
}
class TeacherLeaveFormLoading extends TeacherLeaveFormState {
  const TeacherLeaveFormLoading();
}
class TeacherLeaveFormSuccess extends TeacherLeaveFormState {
  final TeacherLeaveEntity leave;
  const TeacherLeaveFormSuccess(this.leave);
}
class TeacherLeaveFormError extends TeacherLeaveFormState {
  final String message;
  const TeacherLeaveFormError(this.message);
}

sealed class TeacherLeaveCancelState {
  const TeacherLeaveCancelState();
}
class TeacherLeaveCancelInitial extends TeacherLeaveCancelState {
  const TeacherLeaveCancelInitial();
}
class TeacherLeaveCancelLoading extends TeacherLeaveCancelState {
  const TeacherLeaveCancelLoading();
}
class TeacherLeaveCancelSuccess extends TeacherLeaveCancelState {
  final TeacherLeaveEntity leave;
  const TeacherLeaveCancelSuccess(this.leave);
}
class TeacherLeaveCancelError extends TeacherLeaveCancelState {
  final String message;
  const TeacherLeaveCancelError(this.message);
}

// Repository & Datasource Providers
final teacherLeaveRemoteDatasourceProvider = Provider<TeacherLeaveRemoteDatasource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TeacherLeaveRemoteDatasource(apiClient);
});

final teacherLeaveRepositoryProvider = Provider<TeacherLeaveRepository>((ref) {
  final remote = ref.watch(teacherLeaveRemoteDatasourceProvider);
  return TeacherLeaveRepositoryImpl(remote);
});

// List Provider
final teacherLeaveListProvider = StateNotifierProvider<TeacherLeaveListNotifier, TeacherLeaveListState>((ref) {
  return TeacherLeaveListNotifier(ref.watch(teacherLeaveRepositoryProvider));
});

class TeacherLeaveListNotifier extends StateNotifier<TeacherLeaveListState> {
  final TeacherLeaveRepository _repository;

  TeacherLeaveListNotifier(this._repository) : super(const TeacherLeaveListInitial());

  Future<void> fetchLeaves({bool isSilent = false}) async {
    if (!isSilent) {
      state = const TeacherLeaveListLoading();
    }
    final result = await _repository.getMyLeaves();
    result.when(
      onSuccess: (list) {
        state = TeacherLeaveListLoaded(list);
      },
      onFailure: (failure) {
        state = TeacherLeaveListError(_mapFailureToMessage(failure));
      },
    );
  }
}

// Detail Provider
final teacherLeaveDetailProvider = StateNotifierProvider.family<TeacherLeaveDetailNotifier, TeacherLeaveDetailState, String>((ref, leaveId) {
  return TeacherLeaveDetailNotifier(ref.watch(teacherLeaveRepositoryProvider), leaveId);
});

class TeacherLeaveDetailNotifier extends StateNotifier<TeacherLeaveDetailState> {
  final TeacherLeaveRepository _repository;
  final String _leaveId;

  TeacherLeaveDetailNotifier(this._repository, this._leaveId) : super(const TeacherLeaveDetailInitial());

  Future<void> fetchDetail({bool isSilent = false}) async {
    if (!isSilent) {
      state = const TeacherLeaveDetailLoading();
    }
    final result = await _repository.getLeave(_leaveId);
    result.when(
      onSuccess: (entity) {
        state = TeacherLeaveDetailLoaded(entity);
      },
      onFailure: (failure) {
        state = TeacherLeaveDetailError(_mapFailureToMessage(failure));
      },
    );
  }

  void updateEntity(TeacherLeaveEntity entity) {
    state = TeacherLeaveDetailLoaded(entity);
  }
}

// Form Provider
final teacherLeaveFormNotifierProvider = StateNotifierProvider<TeacherLeaveFormNotifier, TeacherLeaveFormState>((ref) {
  return TeacherLeaveFormNotifier(ref.watch(teacherLeaveRepositoryProvider), ref);
});

class TeacherLeaveFormNotifier extends StateNotifier<TeacherLeaveFormState> {
  final TeacherLeaveRepository _repository;
  final Ref _ref;

  TeacherLeaveFormNotifier(this._repository, this._ref) : super(const TeacherLeaveFormInitial());

  Future<void> submitLeave({
    required String leaveType,
    required String startDate,
    required String endDate,
    required String reason,
    String? remarks,
  }) async {
    if (state is TeacherLeaveFormLoading) return; // Prevent duplicate submission
    state = const TeacherLeaveFormLoading();

    final result = await _repository.createLeave(
      leaveType: leaveType,
      startDate: startDate,
      endDate: endDate,
      reason: reason,
      remarks: remarks,
    );

    await result.when(
      onSuccess: (entity) async {
        state = TeacherLeaveFormSuccess(entity);
        // Refresh list
        _ref.read(teacherLeaveListProvider.notifier).fetchLeaves(isSilent: true);
      },
      onFailure: (failure) async {
        if (failure.type == ApiFailureType.network || failure.message.toLowerCase().contains('timeout')) {
          // Timeout reconciliation
          await _reconcileCreate(
            leaveType: leaveType,
            startDate: startDate,
            endDate: endDate,
            fallbackError: _mapFailureToMessage(failure),
          );
        } else {
          state = TeacherLeaveFormError(_mapFailureToMessage(failure));
        }
      },
    );
  }

  Future<void> _reconcileCreate({
    required String leaveType,
    required String startDate,
    required String endDate,
    required String fallbackError,
  }) async {
    final result = await _repository.getMyLeaves();
    await result.when(
      onSuccess: (list) async {
        final matches = list.where((leave) =>
            leave.leaveType == leaveType &&
            leave.startDate == startDate &&
            leave.endDate == endDate);
        if (matches.isNotEmpty) {
          // Find the most recently requested one
          final matchedLeave = matches.first;
          state = TeacherLeaveFormSuccess(matchedLeave);
          _ref.read(teacherLeaveListProvider.notifier).fetchLeaves(isSilent: true);
        } else {
          state = TeacherLeaveFormError(
            'Request timed out. We verified with the server, and the request was not received. Please try submitting again.',
          );
        }
      },
      onFailure: (failure) async {
        state = TeacherLeaveFormError(
          'Submission timed out. Verification failed: ${failure.message}. Original error: $fallbackError',
        );
      },
    );
  }

  void reset() {
    state = const TeacherLeaveFormInitial();
  }
}

// Cancel Provider
final teacherLeaveCancelNotifierProvider = StateNotifierProvider<TeacherLeaveCancelNotifier, TeacherLeaveCancelState>((ref) {
  return TeacherLeaveCancelNotifier(ref.watch(teacherLeaveRepositoryProvider), ref);
});

class TeacherLeaveCancelNotifier extends StateNotifier<TeacherLeaveCancelState> {
  final TeacherLeaveRepository _repository;
  final Ref _ref;

  TeacherLeaveCancelNotifier(this._repository, this._ref) : super(const TeacherLeaveCancelInitial());

  Future<void> cancelLeave({
    required String leaveId,
    required String cancellationReason,
  }) async {
    if (state is TeacherLeaveCancelLoading) return; // Prevent duplicate cancellation
    state = const TeacherLeaveCancelLoading();

    final result = await _repository.cancelLeave(
      leaveId: leaveId,
      cancellationReason: cancellationReason,
    );

    await result.when(
      onSuccess: (entity) async {
        state = TeacherLeaveCancelSuccess(entity);
        // Update detail state and list state
        _ref.read(teacherLeaveDetailProvider(leaveId).notifier).updateEntity(entity);
        _ref.read(teacherLeaveListProvider.notifier).fetchLeaves(isSilent: true);
      },
      onFailure: (failure) async {
        if (failure.type == ApiFailureType.network || failure.message.toLowerCase().contains('timeout')) {
          // Timeout reconciliation
          await _reconcileCancel(
            leaveId: leaveId,
            fallbackError: _mapFailureToMessage(failure),
          );
        } else {
          state = TeacherLeaveCancelError(_mapFailureToMessage(failure));
        }
      },
    );
  }

  Future<void> _reconcileCancel({
    required String leaveId,
    required String fallbackError,
  }) async {
    final result = await _repository.getLeave(leaveId);
    await result.when(
      onSuccess: (entity) async {
        if (entity.status == 'CANCELLED') {
          state = TeacherLeaveCancelSuccess(entity);
          _ref.read(teacherLeaveDetailProvider(leaveId).notifier).updateEntity(entity);
          _ref.read(teacherLeaveListProvider.notifier).fetchLeaves(isSilent: true);
        } else {
          state = TeacherLeaveCancelError(
            'Cancellation timed out. Verification on server shows status is still "${entity.status}". Please try again.',
          );
        }
      },
      onFailure: (failure) async {
        state = TeacherLeaveCancelError(
          'Cancellation timed out. Verification failed: ${failure.message}. Original error: $fallbackError',
        );
      },
    );
  }

  void reset() {
    state = const TeacherLeaveCancelInitial();
  }
}

String _mapFailureToMessage(ApiFailure failure) {
  if (failure.statusCode == 401) {
    return 'Session expired. Please log in again.';
  }
  if (failure.statusCode == 403) {
    return 'You are not authorized to submit or manage leave requests.';
  }
  if (failure.statusCode == 404) {
    return 'Leave request not found.';
  }
  if (failure.statusCode == 409) {
    return failure.message;
  }
  if (failure.statusCode == 422) {
    return failure.message;
  }
  if (failure.statusCode == 500) {
    return 'Something went wrong on the server. Please try again.';
  }
  if (failure.type == ApiFailureType.network) {
    return 'Unable to confirm request right now.';
  }
  return failure.message;
}
