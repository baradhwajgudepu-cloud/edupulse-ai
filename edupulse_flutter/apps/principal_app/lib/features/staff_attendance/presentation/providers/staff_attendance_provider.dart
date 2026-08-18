import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:intl/intl.dart';
import '../../../dashboard/presentation/providers/active_school_provider.dart';
import '../../data/datasources/staff_attendance_datasource.dart';
import '../../data/repositories/staff_attendance_repository.dart';
import '../../data/models/staff_attendance_model.dart';

// Datasource Provider
final staffAttendanceDatasourceProvider = Provider<StaffAttendanceDatasource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return StaffAttendanceDatasource(apiClient);
});

// Repository Provider
final staffAttendanceRepositoryProvider = Provider<StaffAttendanceRepository>((ref) {
  final datasource = ref.watch(staffAttendanceDatasourceProvider);
  return StaffAttendanceRepository(datasource);
});

class StaffAttendanceState {
  final DateTime selectedDate;
  final StaffDailyAttendanceSummary? summary;
  final bool isLoading;
  final String? errorMessage;

  StaffAttendanceState({
    required this.selectedDate,
    this.summary,
    this.isLoading = false,
    this.errorMessage,
  });

  StaffAttendanceState copyWith({
    DateTime? selectedDate,
    StaffDailyAttendanceSummary? summary,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool clearSummary = false,
  }) {
    return StaffAttendanceState(
      selectedDate: selectedDate ?? this.selectedDate,
      summary: clearSummary ? null : (summary ?? this.summary),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class StaffAttendanceNotifier extends StateNotifier<StaffAttendanceState> {
  final StaffAttendanceRepository _repository;
  final String? _activeSchoolId;

  StaffAttendanceNotifier(this._repository, this._activeSchoolId)
      : super(StaffAttendanceState(selectedDate: DateTime.now())) {
    // Automatically load data when initialized with a school context
    if (_activeSchoolId != null && _activeSchoolId.isNotEmpty) {
      fetchAttendance();
    }
  }

  Future<void> setDate(DateTime date) async {
    state = state.copyWith(selectedDate: date, clearSummary: true);
    await fetchAttendance();
  }

  Future<void> fetchAttendance({bool isRefresh = false}) async {
    if (_activeSchoolId == null || _activeSchoolId.isEmpty) {
      state = state.copyWith(isLoading: false, errorMessage: 'No active school context found.');
      return;
    }

    if (!isRefresh) {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    final requestSchoolId = _activeSchoolId;
    final formattedDate = DateFormat('yyyy-MM-dd').format(state.selectedDate);
    
    final result = await _repository.getDailyStaffAttendance(
      schoolId: requestSchoolId,
      date: formattedDate,
    );

    // Stale response / disposed protection
    if (!mounted || _activeSchoolId != requestSchoolId) {
      return;
    }

    result.when(
      onSuccess: (summaryData) {
        state = state.copyWith(summary: summaryData, isLoading: false);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
    );
  }
}

final staffAttendanceStateProvider = StateNotifierProvider<StaffAttendanceNotifier, StaffAttendanceState>((ref) {
  final repo = ref.watch(staffAttendanceRepositoryProvider);
  final activeSchoolId = ref.watch(activeSchoolIdProvider);
  return StaffAttendanceNotifier(repo, activeSchoolId);
});

// Teacher Attendance History State
class TeacherAttendanceHistoryState {
  final String teacherId;
  final List<StaffAttendanceHistoryItem> records;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;
  final DateTime? startDate;
  final DateTime? endDate;
  final int skip;
  final int limit;
  final bool hasMore;

  TeacherAttendanceHistoryState({
    required this.teacherId,
    this.records = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.startDate,
    this.endDate,
    this.skip = 0,
    this.limit = 20,
    this.hasMore = true,
  });

  TeacherAttendanceHistoryState copyWith({
    String? teacherId,
    List<StaffAttendanceHistoryItem>? records,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    DateTime? startDate,
    DateTime? endDate,
    int? skip,
    int? limit,
    bool? hasMore,
    bool clearDates = false,
    bool clearError = false,
  }) {
    return TeacherAttendanceHistoryState(
      teacherId: teacherId ?? this.teacherId,
      records: records ?? this.records,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
      skip: skip ?? this.skip,
      limit: limit ?? this.limit,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class TeacherAttendanceHistoryNotifier extends StateNotifier<TeacherAttendanceHistoryState> {
  final StaffAttendanceRepository _repository;
  final String _teacherId;

  TeacherAttendanceHistoryNotifier(this._repository, this._teacherId)
      : super(TeacherAttendanceHistoryState(teacherId: _teacherId)) {
    fetchHistory();
  }

  Future<void> setDateRange(DateTime? start, DateTime? end) async {
    state = state.copyWith(
      startDate: start,
      endDate: end,
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

    final result = await _repository.getTeacherAttendanceHistory(
      teacherId: _teacherId,
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

final teacherAttendanceHistoryStateProvider = StateNotifierProvider.family<
    TeacherAttendanceHistoryNotifier, TeacherAttendanceHistoryState, String>((ref, teacherId) {
  final repo = ref.watch(staffAttendanceRepositoryProvider);
  return TeacherAttendanceHistoryNotifier(repo, teacherId);
});

// School Geofence State
class SchoolGeofenceState {
  final SchoolGeofenceModel? geofence;
  final bool isLoading;
  final String? errorMessage;
  final bool isUpdating;
  final String? updateSuccessMessage;

  SchoolGeofenceState({
    this.geofence,
    this.isLoading = false,
    this.errorMessage,
    this.isUpdating = false,
    this.updateSuccessMessage,
  });

  SchoolGeofenceState copyWith({
    SchoolGeofenceModel? geofence,
    bool? isLoading,
    String? errorMessage,
    bool? isUpdating,
    String? updateSuccessMessage,
    bool clearSuccessMessage = false,
    bool clearError = false,
  }) {
    return SchoolGeofenceState(
      geofence: geofence ?? this.geofence,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isUpdating: isUpdating ?? this.isUpdating,
      updateSuccessMessage: clearSuccessMessage ? null : (updateSuccessMessage ?? this.updateSuccessMessage),
    );
  }
}

class SchoolGeofenceNotifier extends StateNotifier<SchoolGeofenceState> {
  final StaffAttendanceRepository _repository;
  final String? _activeSchoolId;

  SchoolGeofenceNotifier(this._repository, this._activeSchoolId)
      : super(SchoolGeofenceState()) {
    if (_activeSchoolId != null && _activeSchoolId.isNotEmpty) {
      fetchGeofence();
    }
  }

  Future<void> fetchGeofence() async {
    if (_activeSchoolId == null || _activeSchoolId.isEmpty) {
      state = state.copyWith(errorMessage: 'No active school context found.');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true, clearSuccessMessage: true);

    final requestSchoolId = _activeSchoolId;
    final result = await _repository.getSchoolGeofence(schoolId: requestSchoolId);

    if (!mounted || _activeSchoolId != requestSchoolId) return;

    result.when(
      onSuccess: (geofenceData) {
        state = state.copyWith(geofence: geofenceData, isLoading: false);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
    );
  }

  Future<bool> updateGeofence({
    required double latitude,
    required double longitude,
    required int radius,
  }) async {
    if (_activeSchoolId == null || _activeSchoolId.isEmpty) {
      state = state.copyWith(errorMessage: 'No active school context found.');
      return false;
    }

    state = state.copyWith(isUpdating: true, clearError: true, clearSuccessMessage: true);

    final requestSchoolId = _activeSchoolId;
    final result = await _repository.updateSchoolGeofence(
      schoolId: requestSchoolId,
      latitude: latitude,
      longitude: longitude,
      radius: radius,
    );

    if (!mounted || _activeSchoolId != requestSchoolId) return false;

    bool success = false;
    await result.when(
      onSuccess: (geofenceData) async {
        state = state.copyWith(
          geofence: geofenceData,
          isUpdating: false,
          updateSuccessMessage: 'Geofence updated successfully.',
        );
        success = true;
      },
      onFailure: (failure) async {
        if (failure.statusCode == 403) {
          state = state.copyWith(
            isUpdating: false,
            errorMessage: 'You are not authorized to update geofence configurations.',
          );
        } else {
          // Timeout or general failure check: re-fetch and reconcile
          final fetchResult = await _repository.getSchoolGeofence(schoolId: requestSchoolId);
          bool match = false;
          fetchResult.when(
            onSuccess: (data) {
              if (data.latitude == latitude &&
                  data.longitude == longitude &&
                  data.geofenceRadiusMeters == radius) {
                match = true;
              }
            },
            onFailure: (_) {},
          );

          if (match) {
            state = state.copyWith(
              geofence: fetchResult.dataOrNull,
              isUpdating: false,
              updateSuccessMessage: 'Geofence updated successfully.',
            );
            success = true;
          } else {
            state = state.copyWith(
              isUpdating: false,
              errorMessage: failure.message,
            );
          }
        }
      },
    );
    return success;
  }
}

final schoolGeofenceStateProvider = StateNotifierProvider<SchoolGeofenceNotifier, SchoolGeofenceState>((ref) {
  final repo = ref.watch(staffAttendanceRepositoryProvider);
  final activeSchoolId = ref.watch(activeSchoolIdProvider);
  return SchoolGeofenceNotifier(repo, activeSchoolId);
});
