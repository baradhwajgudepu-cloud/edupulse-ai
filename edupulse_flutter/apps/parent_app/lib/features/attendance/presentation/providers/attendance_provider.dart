import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../../domain/usecases/get_attendance_usecase.dart';
import '../../data/datasource/attendance_remote_datasource.dart';
import '../../data/repositories/attendance_repository_impl.dart';
import 'package:edupulse_network/edupulse_network.dart';

sealed class AttendanceState {
  const AttendanceState();
}

class AttendanceInitial extends AttendanceState {
  const AttendanceInitial();
}

class AttendanceLoading extends AttendanceState {
  const AttendanceLoading();
}

class AttendanceSuccess extends AttendanceState {
  final List<AttendanceRecordEntity> records;
  final bool isFromCache;
  const AttendanceSuccess(this.records, {this.isFromCache = false});
}

class AttendanceError extends AttendanceState {
  final String message;
  const AttendanceError(this.message);
}

class AttendanceEmpty extends AttendanceState {
  const AttendanceEmpty();
}

// 1. Dependency Injection providers
final attendanceRemoteDatasourceProvider =
    Provider<AttendanceRemoteDatasource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AttendanceRemoteDatasource(apiClient);
});

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final remote = ref.watch(attendanceRemoteDatasourceProvider);
  return AttendanceRepositoryImpl(remote);
});

final getAttendanceUseCaseProvider = Provider<GetAttendanceUseCase>((ref) {
  final repo = ref.watch(attendanceRepositoryProvider);
  return GetAttendanceUseCase(repo);
});

// 2. Controller Notifier
class AttendanceNotifier extends Notifier<AttendanceState> {
  // In-memory cache key mapped by studentId
  final Map<String, List<AttendanceRecordEntity>> _cachedRecordsMap = {};

  @override
  AttendanceState build() {
    return const AttendanceInitial();
  }

  Future<void> fetchAttendance({
    required String studentId,
    required String academicYearId,
    required String schoolId,
    bool isRefresh = false,
  }) async {
    // Check local memory cache
    final cached = _cachedRecordsMap[studentId];
    if (cached != null && !isRefresh) {
      state = AttendanceSuccess(cached, isFromCache: true);
      return;
    }

    state = isRefresh ? const AttendanceLoading() : const AttendanceInitial();

    final getAttendance = ref.read(getAttendanceUseCaseProvider);
    final result = await getAttendance(
      studentId: studentId,
      academicYearId: academicYearId,
      schoolId: schoolId,
    );

    result.when(
      onSuccess: (records) {
        _cachedRecordsMap[studentId] = records;
        if (records.isEmpty) {
          state = const AttendanceEmpty();
        } else {
          state = AttendanceSuccess(records);
        }
      },
      onFailure: (failure) {
        // If query failed (e.g. connection timeout/offline) and we have cached data, fall back to cache
        if (cached != null) {
          state = AttendanceSuccess(cached, isFromCache: true);
        } else {
          state = AttendanceError(failure.message);
        }
      },
    );
  }
}

final attendanceStateProvider =
    NotifierProvider<AttendanceNotifier, AttendanceState>(
  AttendanceNotifier.new,
);
