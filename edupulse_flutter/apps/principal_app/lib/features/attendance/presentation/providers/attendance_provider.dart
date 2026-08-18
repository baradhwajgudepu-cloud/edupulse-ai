import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:intl/intl.dart';
import '../../data/datasources/attendance_datasource.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/models/attendance_model.dart';

// Datasource Provider
final attendanceDatasourceProvider = Provider<AttendanceDatasource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AttendanceDatasource(apiClient);
});

// Repository Provider
final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final datasource = ref.watch(attendanceDatasourceProvider);
  return AttendanceRepository(datasource);
});

class AttendanceState {
  final DateTime selectedDate;
  final List<AttendanceRecord> records;
  final bool isLoading;
  final String? errorMessage;

  AttendanceState({
    required this.selectedDate,
    required this.records,
    this.isLoading = false,
    this.errorMessage,
  });

  int get totalCount => records.length;
  int get presentCount => records.where((r) => r.status == 'PRESENT').length;
  int get absentCount => records.where((r) => r.status == 'ABSENT').length;
  int get lateCount => records.where((r) => r.status == 'LATE').length;
  int get halfDayCount => records.where((r) => r.status == 'HALFDAY').length;

  /// Attendance Percentage Formula:
  /// (Present + Late + Half-day) / Total * 100
  /// LATE and HALFDAY status counts are included in this present-equivalent percentage rate 
  /// but represented as distinct numerical categories in counts dashboards.
  double get attendancePercentage {
    if (totalCount == 0) return 0.0;
    final presentEquivalent = presentCount + lateCount + halfDayCount;
    return (presentEquivalent / totalCount) * 100.0;
  }

  AttendanceState copyWith({
    DateTime? selectedDate,
    List<AttendanceRecord>? records,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AttendanceState(
      selectedDate: selectedDate ?? this.selectedDate,
      records: records ?? this.records,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AttendanceNotifier extends StateNotifier<AttendanceState> {
  final AttendanceRepository _repository;
  final SessionManager _sessionManager;

  AttendanceNotifier(this._repository, this._sessionManager)
      : super(AttendanceState(selectedDate: DateTime.now(), records: []));

  Future<void> setDate(DateTime date) async {
    state = state.copyWith(selectedDate: date);
    await fetchAttendance();
  }

  Future<void> fetchAttendance({bool isRefresh = false}) async {
    if (!isRefresh) {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) {
      state = state.copyWith(isLoading: false, errorMessage: 'No active school context found.');
      return;
    }

    final formattedDate = DateFormat('yyyy-MM-dd').format(state.selectedDate);
    final result = await _repository.getDailyAttendance(schoolId: schoolId, date: formattedDate);

    result.when(
      onSuccess: (list) {
        state = state.copyWith(records: list, isLoading: false);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
    );
  }
}

final attendanceStateProvider = StateNotifierProvider<AttendanceNotifier, AttendanceState>((ref) {
  final repo = ref.watch(attendanceRepositoryProvider);
  final session = ref.watch(sessionManagerProvider);
  return AttendanceNotifier(repo, session);
});
