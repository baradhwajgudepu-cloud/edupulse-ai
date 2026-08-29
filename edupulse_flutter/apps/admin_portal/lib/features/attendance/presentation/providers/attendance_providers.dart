import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../data/models/attendance_models.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

class AttendanceFiltersState {
  final String? academicYearId;
  final String? classId;
  final String? sectionId;
  final DateTime? attendanceDate;
  final String? status;

  const AttendanceFiltersState({
    this.academicYearId,
    this.classId,
    this.sectionId,
    this.attendanceDate,
    this.status,
  });

  AttendanceFiltersState copyWith({
    String? academicYearId,
    String? classId,
    String? sectionId,
    DateTime? attendanceDate,
    String? status,
    bool clearAcademicYear = false,
    bool clearClass = false,
    bool clearSection = false,
    bool clearDate = false,
    bool clearStatus = false,
  }) {
    return AttendanceFiltersState(
      academicYearId: clearAcademicYear ? null : (academicYearId ?? this.academicYearId),
      classId: clearClass ? null : (classId ?? this.classId),
      sectionId: clearSection ? null : (sectionId ?? this.sectionId),
      attendanceDate: clearDate ? null : (attendanceDate ?? this.attendanceDate),
      status: clearStatus ? null : (status ?? this.status),
    );
  }
}

class AttendanceFiltersNotifier extends StateNotifier<AttendanceFiltersState> {
  AttendanceFiltersNotifier() : super(const AttendanceFiltersState());

  void setAcademicYear(String? id) => state = state.copyWith(academicYearId: id, clearAcademicYear: id == null);
  void setClass(String? id) => state = state.copyWith(classId: id, clearClass: id == null, clearSection: true);
  void setSection(String? id) => state = state.copyWith(sectionId: id, clearSection: id == null);
  void setDate(DateTime? date) => state = state.copyWith(attendanceDate: date, clearDate: date == null);
  void setStatus(String? status) => state = state.copyWith(status: status, clearStatus: status == null);
  
  void clearAll() => state = const AttendanceFiltersState();
}

final attendanceFiltersProvider =
    StateNotifierProvider<AttendanceFiltersNotifier, AttendanceFiltersState>((ref) {
  return AttendanceFiltersNotifier();
});

class AttendanceSessionListState {
  final List<AttendanceSessionDto> sessions;
  final bool isLoading;
  final String? error;

  const AttendanceSessionListState({
    required this.sessions,
    required this.isLoading,
    this.error,
  });
}

class AttendanceSessionListNotifier extends StateNotifier<AttendanceSessionListState> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  AttendanceSessionListNotifier(this._apiClient, this._ref)
      : super(const AttendanceSessionListState(sessions: [], isLoading: false)) {
    _ref.listen<AttendanceFiltersState>(attendanceFiltersProvider, (previous, next) {
      fetchSessions();
    });
    _ref.listen<String?>(selectedSchoolIdProvider, (previous, next) {
      if (next != null) {
        fetchSessions();
      } else {
        state = const AttendanceSessionListState(sessions: [], isLoading: false);
      }
    });
  }

  Future<void> fetchSessions() async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    state = AttendanceSessionListState(sessions: state.sessions, isLoading: true);
    final filters = _ref.read(attendanceFiltersProvider);

    final Map<String, String> query = {
      'school_id': schoolId,
    };
    if (filters.academicYearId != null) query['academic_year_id'] = filters.academicYearId!;
    if (filters.classId != null) query['class_id'] = filters.classId!;
    if (filters.sectionId != null) query['section_id'] = filters.sectionId!;
    if (filters.status != null) query['status'] = filters.status!;
    if (filters.attendanceDate != null) {
      query['attendance_date'] = filters.attendanceDate!.toIso8601String().substring(0, 10);
    }

    final uri = Uri(path: '/attendances/sessions', queryParameters: query);

    final result = await _apiClient.get(
      uri.toString(),
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List? ?? [];
        return list.map((e) => AttendanceSessionDto.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      },
    );

    if (!mounted) return;

    result.when(
      onSuccess: (data) {
        state = AttendanceSessionListState(sessions: data, isLoading: false);
      },
      onFailure: (failure) {
        state = AttendanceSessionListState(sessions: [], isLoading: false, error: failure.message);
      },
    );
  }
}

final attendanceSessionsProvider =
    StateNotifierProvider<AttendanceSessionListNotifier, AttendanceSessionListState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AttendanceSessionListNotifier(apiClient, ref);
});

class AttendanceLogListState {
  final List<AttendanceLogDto> logs;
  final bool isLoading;
  final String? error;

  const AttendanceLogListState({
    required this.logs,
    required this.isLoading,
    this.error,
  });
}

class AttendanceLogListNotifier extends StateNotifier<AttendanceLogListState> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  AttendanceLogListNotifier(this._apiClient, this._ref)
      : super(const AttendanceLogListState(logs: [], isLoading: false)) {
    _ref.listen<AttendanceFiltersState>(attendanceFiltersProvider, (previous, next) {
      fetchLogs();
    });
    _ref.listen<String?>(selectedSchoolIdProvider, (previous, next) {
      if (next != null) {
        fetchLogs();
      } else {
        state = const AttendanceLogListState(logs: [], isLoading: false);
      }
    });
  }

  Future<void> fetchLogs() async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    state = AttendanceLogListState(logs: state.logs, isLoading: true);
    final filters = _ref.read(attendanceFiltersProvider);

    final Map<String, String> query = {
      'school_id': schoolId,
    };
    if (filters.academicYearId != null) query['academic_year_id'] = filters.academicYearId!;
    if (filters.classId != null) query['class_id'] = filters.classId!;
    if (filters.sectionId != null) query['section_id'] = filters.sectionId!;
    if (filters.status != null) query['status'] = filters.status!;
    if (filters.attendanceDate != null) {
      query['attendance_date'] = filters.attendanceDate!.toIso8601String().substring(0, 10);
    }

    final uri = Uri(path: '/attendances', queryParameters: query);

    final result = await _apiClient.get(
      uri.toString(),
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List? ?? [];
        return list.map((e) => AttendanceLogDto.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      },
    );

    if (!mounted) return;

    result.when(
      onSuccess: (data) {
        state = AttendanceLogListState(logs: data, isLoading: false);
      },
      onFailure: (failure) {
        state = AttendanceLogListState(logs: [], isLoading: false, error: failure.message);
      },
    );
  }
}

final attendanceLogsProvider =
    StateNotifierProvider<AttendanceLogListNotifier, AttendanceLogListState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AttendanceLogListNotifier(apiClient, ref);
});

class AttendanceKpiState {
  final int totalSessions;
  final int present;
  final int absent;
  final int late;
  final int leave;
  final double attendancePercentage;

  const AttendanceKpiState({
    required this.totalSessions,
    required this.present,
    required this.absent,
    required this.late,
    required this.leave,
    required this.attendancePercentage,
  });
}

final attendanceKpiProvider = Provider<AttendanceKpiState>((ref) {
  final sessionState = ref.watch(attendanceSessionsProvider);
  final logState = ref.watch(attendanceLogsProvider);

  final totalSessions = sessionState.sessions.length;
  int present = 0;
  int absent = 0;
  int lateCount = 0;
  int leave = 0;

  for (final log in logState.logs) {
    final status = log.attendanceStatus.toUpperCase();
    if (status == 'PRESENT' || status == 'ONLINE') {
      present++;
    } else if (status == 'ABSENT') {
      absent++;
    } else if (status == 'LATE') {
      lateCount++;
    } else if (status == 'MEDICAL_LEAVE' || status == 'EXCUSED' || status == 'HALF_DAY') {
      leave++;
    }
  }

  final totalLogs = present + absent + lateCount + leave;
  final pct = totalLogs == 0 ? 0.0 : (present / totalLogs) * 100.0;

  return AttendanceKpiState(
    totalSessions: totalSessions,
    present: present,
    absent: absent,
    late: lateCount,
    leave: leave,
    attendancePercentage: pct,
  );
});

final attendanceSessionDetailProvider =
    FutureProvider.family<AttendanceSessionDto, String>((ref, sessionId) async {
  final apiClient = ref.watch(apiClientProvider);
  final schoolId = ref.watch(selectedSchoolIdProvider);
  if (schoolId == null) {
    throw Exception('No school campus selected.');
  }

  final result = await apiClient.get(
    '/attendances/session/$sessionId?school_id=$schoolId',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      return AttendanceSessionDto.fromJson(Map<String, dynamic>.from(payload['data'] as Map));
    },
  );

  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

class AttendanceOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  AttendanceOperationsNotifier(this._apiClient, this._ref) : super(const AsyncValue.data(null));

  Future<bool> correctAttendance({
    required String sessionId,
    required String studentId,
    required String status,
    required String correctionReason,
    String? remarks,
  }) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return false;

    state = const AsyncValue.loading();

    final result = await _apiClient.put(
      '/attendances/session/$sessionId/student/$studentId?school_id=$schoolId',
      data: {
        'attendance_status': status,
        'attendance_source': 'MANUAL',
        'attendance_reason': 'UNKNOWN',
        'remarks': remarks ?? '',
        'correction_reason': correctionReason,
      },
      mapper: (json) => json,
    );

    if (!mounted) return false;

    return result.when(
      onSuccess: (_) {
        state = const AsyncValue.data(null);
        _ref.invalidate(attendanceSessionDetailProvider(sessionId));
        _ref.read(attendanceSessionsProvider.notifier).fetchSessions();
        _ref.read(attendanceLogsProvider.notifier).fetchLogs();
        return true;
      },
      onFailure: (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
    );
  }

  Future<bool> lockSession({
    required String sessionId,
  }) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return false;

    state = const AsyncValue.loading();

    final result = await _apiClient.post(
      '/attendances/session/$sessionId/lock?school_id=$schoolId',
      data: {},
      mapper: (json) => json,
    );

    if (!mounted) return false;

    return result.when(
      onSuccess: (_) {
        state = const AsyncValue.data(null);
        _ref.invalidate(attendanceSessionDetailProvider(sessionId));
        _ref.read(attendanceSessionsProvider.notifier).fetchSessions();
        _ref.read(attendanceLogsProvider.notifier).fetchLogs();
        return true;
      },
      onFailure: (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
    );
  }

  Future<bool> deleteSession({
    required String sessionId,
  }) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return false;

    state = const AsyncValue.loading();

    final result = await _apiClient.delete(
      '/attendances/session/$sessionId?school_id=$schoolId',
      mapper: (json) => json,
    );

    if (!mounted) return false;

    return result.when(
      onSuccess: (_) {
        state = const AsyncValue.data(null);
        _ref.read(attendanceSessionsProvider.notifier).fetchSessions();
        _ref.read(attendanceLogsProvider.notifier).fetchLogs();
        return true;
      },
      onFailure: (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
    );
  }
}

final attendanceOperationsProvider =
    StateNotifierProvider<AttendanceOperationsNotifier, AsyncValue<void>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AttendanceOperationsNotifier(apiClient, ref);
});
