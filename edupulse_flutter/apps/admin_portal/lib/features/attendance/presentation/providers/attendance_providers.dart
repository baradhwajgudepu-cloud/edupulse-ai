import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/models/attendance_models.dart';
import '../../../../core/presentation/utils/dropdown_safety.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../students/data/models/student_models.dart';
import '../../../teachers/data/models/teachers_models.dart';
import '../../../bulk_import/presentation/providers/web_download_helper.dart';

// ==================================================
// 1. Existing Filter State & Notifier (Preserved)
// ==================================================
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

// ==================================================
// 2. Existing Session List & Notifier (Preserved)
// ==================================================
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

// ==================================================
// 3. Existing Logs List & Notifier (Preserved)
// ==================================================
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

// ==================================================
// 4. KPI & Detail Providers (Preserved)
// ==================================================
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

  Future<bool> lockSession({required String sessionId}) async {
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

  Future<bool> deleteSession({required String sessionId}) async {
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

// ==================================================
// 5. Attendance Dashboard State & Notifier
// ==================================================
class AttendanceDashboardState {
  final AttendanceDashboardStatsDto? stats;
  final List<AttendanceAlertDto> alerts;
  final DateTime selectedDate;
  final bool isLoading;
  final String? error;

  AttendanceDashboardState({
    this.stats,
    this.alerts = const [],
    DateTime? selectedDate,
    this.isLoading = false,
    this.error,
  }) : selectedDate = selectedDate ?? DateTime.now();

  AttendanceDashboardState copyWith({
    AttendanceDashboardStatsDto? stats,
    List<AttendanceAlertDto>? alerts,
    DateTime? selectedDate,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AttendanceDashboardState(
      stats: stats ?? this.stats,
      alerts: alerts ?? this.alerts,
      selectedDate: selectedDate ?? this.selectedDate,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AttendanceDashboardNotifier extends StateNotifier<AttendanceDashboardState> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  AttendanceDashboardNotifier(this._apiClient, this._ref)
      : super(AttendanceDashboardState());

  Future<void> fetchDashboard({DateTime? date}) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    final targetDate = date ?? state.selectedDate;
    final dateStr = targetDate.toIso8601String().substring(0, 10);

    state = state.copyWith(isLoading: true, selectedDate: targetDate, clearError: true);

    try {
      // 1. Fetch recent attendance sessions via canonical endpoint /attendances/sessions
      final sessionsRes = await _apiClient.get(
        '/attendances/sessions?school_id=$schoolId&limit=100',
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          final list = payload['data'] as List? ?? [];
          return list.map((e) => AttendanceSessionDto.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        },
      );

      // 2. Fetch daily attendance records via canonical endpoint /attendances/daily
      final dailyRes = await _apiClient.get(
        '/attendances/daily?school_id=$schoolId&attendance_date=$dateStr',
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          final list = payload['data'] as List? ?? [];
          return list.map((e) => AttendanceLogDto.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        },
      );

      // 3. Fetch school classes via canonical endpoint /classes
      final classesRes = await _apiClient.get(
        '/classes?school_id=$schoolId',
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          final list = payload['data'] as List? ?? [];
          return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        },
      );

      if (!mounted) return;

      List<AttendanceSessionDto> sessions = [];
      String? errorMsg;
      sessionsRes.when(
        onSuccess: (s) => sessions = s,
        onFailure: (f) => errorMsg = f.message,
      );

      List<AttendanceLogDto> dailyLogs = [];
      dailyRes.when(
        onSuccess: (d) => dailyLogs = d,
        onFailure: (_) {},
      );

      List<Map<String, dynamic>> classes = [];
      classesRes.when(
        onSuccess: (c) => classes = c,
        onFailure: (_) {},
      );

      if (sessions.isEmpty && dailyLogs.isEmpty && errorMsg != null) {
        state = state.copyWith(isLoading: false, error: errorMsg);
        return;
      }

      // Compute Dashboard Stats deterministically from canonical responses
      final stats = _computeDashboardStats(
        targetDate: targetDate,
        dateStr: dateStr,
        sessions: sessions,
        dailyLogs: dailyLogs,
        classes: classes,
      );

      // Evaluate Attendance Alerts (unmarked classes, consecutive absence streaks)
      final alerts = _evaluateAlerts(
        dateStr: dateStr,
        stats: stats,
        sessions: sessions,
        dailyLogs: dailyLogs,
      );

      state = state.copyWith(
        stats: stats,
        alerts: alerts,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  AttendanceDashboardStatsDto _computeDashboardStats({
    required DateTime targetDate,
    required String dateStr,
    required List<AttendanceSessionDto> sessions,
    required List<AttendanceLogDto> dailyLogs,
    required List<Map<String, dynamic>> classes,
  }) {
    // 1. Gather all attendance logs for targetDate
    final todaySessions = sessions.where((s) => s.attendanceDate.startsWith(dateStr)).toList();

    // Map unique student logs on targetDate
    final Map<String, AttendanceLogDto> targetDateLogsMap = {};
    for (final log in dailyLogs) {
      targetDateLogsMap[log.studentId] = log;
    }
    for (final s in todaySessions) {
      for (final a in s.attendances) {
        targetDateLogsMap.putIfAbsent(a.studentId, () => a);
      }
    }
    final todayLogs = targetDateLogsMap.values.toList();

    int presentCount = 0;
    int absentCount = 0;
    int lateCount = 0;
    int excusedCount = 0;
    int halfDayCount = 0;

    for (final log in todayLogs) {
      final status = log.attendanceStatus.toUpperCase();
      if (status == 'PRESENT' || status == 'ONLINE') {
        presentCount++;
      } else if (status == 'ABSENT') {
        absentCount++;
      } else if (status == 'LATE') {
        lateCount++;
      } else if (status == 'EXCUSED' || status == 'MEDICAL_LEAVE') {
        excusedCount++;
      } else if (status == 'HALF_DAY') {
        halfDayCount++;
      }
    }

    final markedTotal = presentCount + absentCount + lateCount + excusedCount + halfDayCount;
    final attendancePercentage = markedTotal > 0
        ? double.parse((presentCount / markedTotal * 100.0).toStringAsFixed(1))
        : 0.0;

    // Derive class list if /classes was empty
    List<Map<String, dynamic>> effectiveClasses = classes;
    if (effectiveClasses.isEmpty) {
      final Map<String, Map<String, dynamic>> derivedClasses = {};
      for (final s in sessions) {
        if (!derivedClasses.containsKey(s.classId)) {
          derivedClasses[s.classId] = {
            'id': s.classId,
            'name': s.className ?? 'Class',
            'capacity': 30,
          };
        }
      }
      effectiveClasses = derivedClasses.values.toList();
    }

    // Total enrolled students: sum of class capacities or unique students seen or marked total
    int capacitySum = 0;
    for (final c in effectiveClasses) {
      final cap = c['capacity'] as int? ?? 0;
      capacitySum += cap > 0 ? cap : 30;
    }
    final Set<String> uniqueStudentIds = {};
    for (final s in sessions) {
      for (final a in s.attendances) {
        uniqueStudentIds.add(a.studentId);
      }
    }
    for (final l in dailyLogs) {
      uniqueStudentIds.add(l.studentId);
    }
    final int totalStudents = markedTotal > 0
        ? markedTotal
        : (capacitySum > 0 ? capacitySum : uniqueStudentIds.length);

    // Classes marked & pending
    final markedClassIds = todaySessions
        .where((s) => s.status.toUpperCase() == 'SUBMITTED' || s.status.toUpperCase() == 'LOCKED')
        .map((s) => s.classId)
        .toSet();
    final classesMarked = effectiveClasses.where((c) => markedClassIds.contains(c['id'])).length;
    final classesPending = effectiveClasses.isNotEmpty
        ? (effectiveClasses.length - classesMarked).clamp(0, effectiveClasses.length)
        : 0;

    // 7-Day Trend
    final List<Map<String, dynamic>> dailyTrend = [];
    double trendSum = 0.0;
    int trendDaysWithData = 0;

    for (int i = 6; i >= 0; i--) {
      final pastDate = targetDate.subtract(Duration(days: i));
      final pastDateStr = pastDate.toIso8601String().substring(0, 10);

      final daySessions = sessions.where((s) => s.attendanceDate.startsWith(pastDateStr)).toList();
      int dayTotal = 0;
      int dayPresent = 0;
      int dayAbsent = 0;

      for (final s in daySessions) {
        for (final a in s.attendances) {
          dayTotal++;
          final st = a.attendanceStatus.toUpperCase();
          if (st == 'PRESENT' || st == 'ONLINE') {
            dayPresent++;
          } else if (st == 'ABSENT') {
            dayAbsent++;
          }
        }
      }

      if (pastDateStr == dateStr && dayTotal == 0 && markedTotal > 0) {
        dayTotal = markedTotal;
        dayPresent = presentCount;
        dayAbsent = absentCount;
      }

      final dayPct = dayTotal > 0
          ? double.parse((dayPresent / dayTotal * 100.0).toStringAsFixed(1))
          : 0.0;

      if (dayTotal > 0) {
        trendSum += dayPct;
        trendDaysWithData++;
      }

      dailyTrend.add({
        'date': pastDateStr,
        'percentage': dayPct,
        'present': dayPresent,
        'absent': dayAbsent,
        'total': dayTotal,
      });
    }

    final monthlyPercentage = trendDaysWithData > 0
        ? double.parse((trendSum / trendDaysWithData).toStringAsFixed(1))
        : attendancePercentage;

    // Class-wise breakdown
    final List<Map<String, dynamic>> classWiseStats = [];
    for (final cls in effectiveClasses) {
      final clsId = cls['id'] as String? ?? '';
      final clsName = cls['name'] as String? ?? 'Class';
      final clsSessions = todaySessions.where((s) => s.classId == clsId).toList();

      int clsTotal = 0;
      int clsPresent = 0;
      int clsAbsent = 0;
      String sectionName = '';

      for (final s in clsSessions) {
        if (s.sectionName != null && s.sectionName!.isNotEmpty) {
          sectionName = s.sectionName!;
        }
        for (final a in s.attendances) {
          clsTotal++;
          final st = a.attendanceStatus.toUpperCase();
          if (st == 'PRESENT' || st == 'ONLINE') {
            clsPresent++;
          } else if (st == 'ABSENT') {
            clsAbsent++;
          }
        }
      }

      if (clsTotal == 0) {
        final matchingLogs = todayLogs.where((l) => l.classId == clsId).toList();
        for (final l in matchingLogs) {
          clsTotal++;
          if (l.sectionName != null && l.sectionName!.isNotEmpty) {
            sectionName = l.sectionName!;
          }
          final st = l.attendanceStatus.toUpperCase();
          if (st == 'PRESENT' || st == 'ONLINE') {
            clsPresent++;
          } else if (st == 'ABSENT') {
            clsAbsent++;
          }
        }
      }

      final isMarked = markedClassIds.contains(clsId);
      final clsPct = clsTotal > 0
          ? double.parse((clsPresent / clsTotal * 100.0).toStringAsFixed(1))
          : 0.0;

      classWiseStats.add({
        'class_id': clsId,
        'class_name': clsName,
        'section_name': sectionName,
        'percentage': clsPct,
        'is_marked': isMarked,
        'total': clsTotal,
        'present': clsPresent,
        'absent': clsAbsent,
        'total_marked': clsTotal,
      });
    }

    // Low attendance students (< 75% across recent history)
    final Map<String, List<AttendanceLogDto>> studentHistory = {};
    for (final s in sessions) {
      for (final a in s.attendances) {
        studentHistory.putIfAbsent(a.studentId, () => []).add(a);
      }
    }
    for (final l in dailyLogs) {
      studentHistory.putIfAbsent(l.studentId, () => []).add(l);
    }

    final List<Map<String, dynamic>> lowAttendanceStudents = [];
    studentHistory.forEach((studentId, logs) {
      if (logs.isNotEmpty) {
        int attended = 0;
        for (final l in logs) {
          final st = l.attendanceStatus.toUpperCase();
          if (st == 'PRESENT' || st == 'ONLINE' || st == 'LATE') {
            attended++;
          }
        }
        final rate = (attended / logs.length) * 100.0;
        if (rate < 75.0) {
          final latest = logs.first;
          lowAttendanceStudents.add({
            'student_id': studentId,
            'student_name': latest.studentName ?? 'Student',
            'admission_number': latest.admissionNumber ?? '',
            'class_name': latest.className ?? '',
            'section_name': latest.sectionName ?? '',
            'attendance_percentage': double.parse(rate.toStringAsFixed(1)),
            'attended_sessions': attended,
            'total_sessions': logs.length,
          });
        }
      }
    });

    return AttendanceDashboardStatsDto(
      attendanceDate: dateStr,
      attendancePercentage: attendancePercentage,
      totalStudents: totalStudents,
      presentCount: presentCount,
      absentCount: absentCount,
      lateCount: lateCount,
      excusedCount: excusedCount,
      halfDayCount: halfDayCount,
      classesMarked: classesMarked,
      classesPending: classesPending,
      dailyTrend: dailyTrend,
      classWiseStats: classWiseStats,
      monthlyPercentage: monthlyPercentage,
      lowAttendanceStudents: lowAttendanceStudents,
    );
  }

  List<AttendanceAlertDto> _evaluateAlerts({
    required String dateStr,
    required AttendanceDashboardStatsDto stats,
    required List<AttendanceSessionDto> sessions,
    required List<AttendanceLogDto> dailyLogs,
  }) {
    final List<AttendanceAlertDto> alerts = [];

    // Alert 1: Unmarked classes today
    if (stats.classesPending > 0) {
      alerts.add(
        AttendanceAlertDto(
          alertType: 'UNMARKED_CLASSES',
          severity: 'MEDIUM',
          title: 'Unmarked Classes: ${stats.classesPending} Class${stats.classesPending > 1 ? "es" : ""} Pending Today',
          message: 'Attendance has not been recorded yet for ${stats.classesPending} class(es) on $dateStr.',
          entityId: null,
          details: {'pending_count': stats.classesPending},
        ),
      );
    }

    // Alert 2: Consecutive absences across recent logs
    final Map<String, List<AttendanceLogDto>> studentHistory = {};
    for (final s in sessions) {
      for (final a in s.attendances) {
        studentHistory.putIfAbsent(a.studentId, () => []).add(a);
      }
    }
    for (final l in dailyLogs) {
      studentHistory.putIfAbsent(l.studentId, () => []).add(l);
    }

    studentHistory.forEach((studentId, logs) {
      logs.sort((a, b) => b.attendanceDate.compareTo(a.attendanceDate));
      int consecutive = 0;
      for (final l in logs) {
        if (l.attendanceStatus.toUpperCase() == 'ABSENT') {
          consecutive++;
        } else {
          break;
        }
      }
      if (consecutive >= 3) {
        final latest = logs.first;
        alerts.add(
          AttendanceAlertDto(
            alertType: 'CONSECUTIVE_ABSENCE',
            severity: 'HIGH',
            title: 'Consecutive Absence Warning: ${latest.studentName ?? "Student"}',
            message: 'Student ${latest.studentName ?? "Student"} has been absent for $consecutive consecutive days.',
            entityId: studentId,
            details: {'consecutive_absent_days': consecutive},
          ),
        );
      }
    });

    return alerts;
  }
}

final attendanceDashboardProvider =
    StateNotifierProvider<AttendanceDashboardNotifier, AttendanceDashboardState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AttendanceDashboardNotifier(apiClient, ref);
});

// ==================================================
// 6. Daily Attendance Marking State & Notifier
// ==================================================
class DailyAttendanceMarkState {
  final String? academicYearId;
  final String? classId;
  final String? sectionId;
  final DateTime attendanceDate;
  final String sessionType;
  final List<StudentRosterItem> roster;
  final bool isLoading;
  final bool isSaving;
  final bool isLocked;
  final String? sessionId;
  final String? errorMessage;
  final String? successMessage;

  DailyAttendanceMarkState({
    this.academicYearId,
    this.classId,
    this.sectionId,
    DateTime? attendanceDate,
    this.sessionType = 'FULL_DAY',
    this.roster = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.isLocked = false,
    this.sessionId,
    this.errorMessage,
    this.successMessage,
  }) : attendanceDate = attendanceDate ?? DateTime.now();

  DailyAttendanceMarkState copyWith({
    String? academicYearId,
    String? classId,
    String? sectionId,
    DateTime? attendanceDate,
    String? sessionType,
    List<StudentRosterItem>? roster,
    bool? isLoading,
    bool? isSaving,
    bool? isLocked,
    String? sessionId,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearSession = false,
  }) {
    return DailyAttendanceMarkState(
      academicYearId: academicYearId ?? this.academicYearId,
      classId: classId ?? this.classId,
      sectionId: sectionId ?? this.sectionId,
      attendanceDate: attendanceDate ?? this.attendanceDate,
      sessionType: sessionType ?? this.sessionType,
      roster: roster ?? this.roster,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isLocked: isLocked ?? this.isLocked,
      sessionId: clearSession ? null : (sessionId ?? this.sessionId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class DailyAttendanceMarkNotifier extends StateNotifier<DailyAttendanceMarkState> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  DailyAttendanceMarkNotifier(this._apiClient, this._ref)
      : super(DailyAttendanceMarkState());

  void setSelection({
    String? academicYearId,
    String? classId,
    String? sectionId,
    DateTime? attendanceDate,
    String? sessionType,
  }) {
    state = state.copyWith(
      academicYearId: academicYearId ?? state.academicYearId,
      classId: classId ?? state.classId,
      sectionId: sectionId ?? state.sectionId,
      attendanceDate: attendanceDate ?? state.attendanceDate,
      sessionType: sessionType ?? state.sessionType,
      clearError: true,
      clearSuccess: true,
    );
    if (state.classId != null && state.sectionId != null) {
      loadRoster();
    }
  }

  Future<void> loadRoster() async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null || state.classId == null || state.sectionId == null) return;

    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    try {
      // 1. Fetch Students via chunked pagination loop (safe limit <= 50)
      List<StudentDto> students = [];
      int currentSkip = 0;
      const int pageSize = 50;
      bool hasMore = true;

      while (hasMore) {
        final queryParams = <String>[
          'school_id=$schoolId',
          'class_id=${state.classId}',
          'section_id=${state.sectionId}',
          if (state.academicYearId != null) 'academic_year_id=${state.academicYearId}',
          'status=ACTIVE',
          'skip=$currentSkip',
          'limit=$pageSize',
        ];

        final studentsRes = await _apiClient.get(
          '/students?${queryParams.join('&')}',
          mapper: (json) {
            final payload = json as Map<String, dynamic>;
            final list = payload['data'] as List? ?? [];
            return list.map((e) => StudentDto.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          },
        );

        List<StudentDto> chunk = [];
        String? chunkError;
        studentsRes.when(
          onSuccess: (data) => chunk = data,
          onFailure: (failure) => chunkError = failure.message,
        );

        if (chunkError != null) {
          if (mounted) {
            state = state.copyWith(isLoading: false, errorMessage: chunkError);
          }
          return;
        }

        students.addAll(chunk);
        if (chunk.length < pageSize) {
          hasMore = false;
        } else {
          currentSkip += pageSize;
        }
      }

      final dateStr = state.attendanceDate.toIso8601String().substring(0, 10);

      // 2. Check if existing session
      AttendanceSessionDto? existingSession;
      final sessionRes = await _apiClient.get(
        '/attendances/daily/session?school_id=$schoolId&class_id=${state.classId}&section_id=${state.sectionId}&attendance_date=$dateStr&session_type=${state.sessionType}',
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          if (payload['data'] == null) return null;
          return AttendanceSessionDto.fromJson(Map<String, dynamic>.from(payload['data'] as Map));
        },
      );

      if (!mounted) return;

      sessionRes.when(
        onSuccess: (s) => existingSession = s,
        onFailure: (_) {},
      );

      // Canonical fallback to /attendances/sessions
      if (existingSession == null) {
        final fallbackRes = await _apiClient.get(
          '/attendances/sessions?school_id=$schoolId&class_id=${state.classId}&section_id=${state.sectionId}&attendance_date=$dateStr&limit=1',
          mapper: (json) {
            final payload = json as Map<String, dynamic>;
            final list = payload['data'] as List? ?? [];
            return list.map((e) => AttendanceSessionDto.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          },
        );
        if (!mounted) return;
        fallbackRes.when(
          onSuccess: (sessions) {
            if (sessions.isNotEmpty) {
              existingSession = sessions.first;
            }
          },
          onFailure: (_) {},
        );
      }

      final Map<String, AttendanceLogDto> markedMap = {};
      if (existingSession != null) {
        for (final att in existingSession!.attendances) {
          markedMap[att.studentId] = att;
        }
      }

      final rosterItems = students.map((s) {
        final marked = markedMap[s.id];
        return StudentRosterItem(
          studentId: s.id,
          studentName: '${s.firstName} ${s.lastName}'.trim(),
          admissionNumber: s.admissionNumber,
          rollNumber: s.rollNumber,
          status: marked?.attendanceStatus ?? 'PRESENT',
          reason: DropdownSafety.normalizeAttendanceReason(marked?.attendanceReason ?? 'UNKNOWN'),
          remarks: marked?.remarks ?? '',
          isSelected: false,
        );
      }).toList();

      state = state.copyWith(
        roster: rosterItems,
        isLoading: false,
        sessionId: existingSession?.id,
        isLocked: existingSession?.status == 'LOCKED',
      );
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
      }
    }
  }

  void markAllPresent() {
    if (state.isLocked) return;
    final updated = state.roster.map((s) => s.copyWith(
      status: 'PRESENT',
      reason: DropdownSafety.reasonUnknown,
    )).toList();
    state = state.copyWith(roster: updated);
  }

  void markSelectedStatus(String status) {
    if (state.isLocked) return;
    final updated = state.roster.map((s) {
      if (s.isSelected) {
        final currentCanonical = DropdownSafety.normalizeAttendanceReason(s.reason);
        final validReasons = DropdownSafety.getReasonsForStatus(status);
        final newReason = status == 'PRESENT'
            ? DropdownSafety.reasonUnknown
            : (validReasons.contains(currentCanonical) ? currentCanonical : DropdownSafety.reasonUnknown);
        return s.copyWith(
          status: status,
          reason: newReason,
        );
      }
      return s;
    }).toList();
    state = state.copyWith(roster: updated);
  }

  void toggleSelectAll(bool select) {
    final updated = state.roster.map((s) => s.copyWith(isSelected: select)).toList();
    state = state.copyWith(roster: updated);
  }

  void toggleSelectStudent(String studentId) {
    final updated = state.roster.map((s) {
      if (s.studentId == studentId) {
        return s.copyWith(isSelected: !s.isSelected);
      }
      return s;
    }).toList();
    state = state.copyWith(roster: updated);
  }

  void updateStudentStatus(String studentId, String status, {String? reason, String? remarks}) {
    if (state.isLocked) return;
    final updated = state.roster.map((s) {
      if (s.studentId == studentId) {
        String finalReason;
        if (status == 'PRESENT') {
          finalReason = DropdownSafety.reasonUnknown;
        } else if (reason != null) {
          finalReason = DropdownSafety.normalizeAttendanceReason(reason);
        } else {
          final currentCanonical = DropdownSafety.normalizeAttendanceReason(s.reason);
          final validReasons = DropdownSafety.getReasonsForStatus(status);
          finalReason = validReasons.contains(currentCanonical) ? currentCanonical : DropdownSafety.reasonUnknown;
        }
        return s.copyWith(
          status: status,
          reason: finalReason,
          remarks: remarks ?? s.remarks,
        );
      }
      return s;
    }).toList();
    state = state.copyWith(roster: updated);
  }

  Future<bool> submitAttendance({String? reason}) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return false;
    if (state.academicYearId == null || state.classId == null || state.sectionId == null) {
      state = state.copyWith(errorMessage: 'Please select an Academic Year, Class, and Section.');
      return false;
    }
    if (state.roster.isEmpty) {
      state = state.copyWith(errorMessage: 'Student roster is empty.');
      return false;
    }

    state = state.copyWith(isSaving: true, clearError: true, clearSuccess: true);

    final payload = {
      'school_id': schoolId,
      'academic_year_id': state.academicYearId,
      'class_id': state.classId,
      'section_id': state.sectionId,
      'attendance_date': state.attendanceDate.toIso8601String().substring(0, 10),
      'session_type': state.sessionType,
      'attendance_source': 'MANUAL',
      'records': state.roster.map((r) => {
        'student_id': r.studentId,
        'attendance_status': r.status,
        'attendance_reason': r.status == 'PRESENT' ? DropdownSafety.reasonUnknown : DropdownSafety.normalizeAttendanceReason(r.reason),
        'remarks': r.remarks,
      }).toList(),
    };

    final result = await _apiClient.post(
      '/attendances/daily/mark?school_id=$schoolId',
      data: payload,
      mapper: (json) => json,
    );

    if (!mounted) return false;

    return result.when(
      onSuccess: (_) {
        state = state.copyWith(
          isSaving: false,
          successMessage: 'Attendance marked successfully for ${state.roster.length} students.',
        );
        _ref.read(attendanceDashboardProvider.notifier).fetchDashboard();
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isSaving: false, errorMessage: failure.message);
        return false;
      },
    );
  }
}

final dailyAttendanceMarkProvider =
    StateNotifierProvider<DailyAttendanceMarkNotifier, DailyAttendanceMarkState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DailyAttendanceMarkNotifier(apiClient, ref);
});

// ==================================================
// 7. Attendance Register State & Notifier
// ==================================================
class AttendanceRegisterState {
  final List<AttendanceLogDto> records;
  final int total;
  final int skip;
  final int limit;
  final String search;
  final String? classId;
  final String? sectionId;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? status;
  final bool isLoading;
  final String? error;

  const AttendanceRegisterState({
    this.records = const [],
    this.total = 0,
    this.skip = 0,
    this.limit = 50,
    this.search = '',
    this.classId,
    this.sectionId,
    this.startDate,
    this.endDate,
    this.status,
    this.isLoading = false,
    this.error,
  });

  AttendanceRegisterState copyWith({
    List<AttendanceLogDto>? records,
    int? total,
    int? skip,
    int? limit,
    String? search,
    String? classId,
    String? sectionId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearClass = false,
    bool clearSection = false,
    bool clearStatus = false,
    bool clearDates = false,
  }) {
    return AttendanceRegisterState(
      records: records ?? this.records,
      total: total ?? this.total,
      skip: skip ?? this.skip,
      limit: limit ?? this.limit,
      search: search ?? this.search,
      classId: clearClass ? null : (classId ?? this.classId),
      sectionId: clearSection ? null : (sectionId ?? this.sectionId),
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
      status: clearStatus ? null : (status ?? this.status),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AttendanceRegisterNotifier extends StateNotifier<AttendanceRegisterState> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  AttendanceRegisterNotifier(this._apiClient, this._ref)
      : super(const AttendanceRegisterState());

  void setSearch(String query) {
    state = state.copyWith(search: query, skip: 0);
    fetchRegister();
  }

  void setFilters({
    String? classId,
    String? sectionId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) {
    state = state.copyWith(
      classId: classId,
      sectionId: sectionId,
      startDate: startDate,
      endDate: endDate,
      status: status,
      skip: 0,
      clearClass: classId == null,
      clearSection: sectionId == null,
      clearStatus: status == null,
      clearDates: startDate == null && endDate == null,
    );
    fetchRegister();
  }

  Future<void> fetchRegister({int? skip, int? limit}) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    final currentSkip = skip ?? state.skip;
    final currentLimit = limit ?? state.limit;

    state = state.copyWith(isLoading: true, skip: currentSkip, limit: currentLimit, clearError: true);

    final Map<String, String> query = {
      'school_id': schoolId,
      'skip': currentSkip.toString(),
      'limit': currentLimit.clamp(1, 100).toString(),
    };
    if (state.classId != null) query['class_id'] = state.classId!;
    if (state.sectionId != null) query['section_id'] = state.sectionId!;
    if (state.status != null) query['status'] = state.status!;
    if (state.search.isNotEmpty) query['search'] = state.search;
    if (state.startDate != null) query['start_date'] = state.startDate!.toIso8601String().substring(0, 10);
    if (state.endDate != null) query['end_date'] = state.endDate!.toIso8601String().substring(0, 10);

    final uri = Uri(path: '/attendances/register', queryParameters: query);

    var result = await _apiClient.get(
      uri.toString(),
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List? ?? [];
        final total = (payload['meta'] as Map?)?['total'] as int? ?? list.length;
        return {
          'records': list.map((e) => AttendanceLogDto.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
          'total': total,
        };
      },
    );

    if (!mounted) return;

    bool needsFallback = false;
    result.when(
      onSuccess: (_) {},
      onFailure: (f) {
        if (f.statusCode == 404 || f.message.contains('404')) {
          needsFallback = true;
        }
      },
    );

    if (needsFallback) {
      final fallbackQuery = Map<String, String>.from(query);
      if (state.startDate != null) {
        fallbackQuery['attendance_date'] = state.startDate!.toIso8601String().substring(0, 10);
      }
      fallbackQuery.remove('start_date');
      fallbackQuery.remove('end_date');
      fallbackQuery.remove('search');

      final fallbackUri = Uri(path: '/attendances', queryParameters: fallbackQuery);
      result = await _apiClient.get(
        fallbackUri.toString(),
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          final list = payload['data'] as List? ?? [];
          return {
            'records': list.map((e) => AttendanceLogDto.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
            'total': list.length,
          };
        },
      );
      if (!mounted) return;
    }

    result.when(
      onSuccess: (data) {
        state = state.copyWith(
          records: data['records'] as List<AttendanceLogDto>,
          total: data['total'] as int,
          isLoading: false,
        );
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }

  void exportCsv() {
    if (state.records.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln('Date,Admission Number,Student Name,Class,Section,Session,Status,Reason,Remarks');
    for (final r in state.records) {
      buffer.writeln(
        '"${r.attendanceDate}","${r.admissionNumber ?? ""}","${r.studentName ?? ""}","${r.className ?? ""}","${r.sectionName ?? ""}","${r.sessionType}","${r.attendanceStatus}","${r.attendanceReason}","${r.remarks ?? ""}"',
      );
    }

    final dateStr = DateTime.now().toIso8601String().substring(0, 10);
    downloadCsvFile('attendance_register_$dateStr.csv', buffer.toString());
  }
}

final attendanceRegisterProvider =
    StateNotifierProvider<AttendanceRegisterNotifier, AttendanceRegisterState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AttendanceRegisterNotifier(apiClient, ref);
});

// ==================================================
// 8. Bulk Attendance Upload Wizard State & Notifier
// ==================================================
class BulkAttendanceUploadState {
  final int currentStep;
  final List<int>? selectedFileBytes;
  final String? selectedFileName;
  final BulkAttendanceValidateDto? validateResult;
  final String conflictStrategy;
  final BulkAttendanceImportResponseDto? importResult;
  final bool isValidating;
  final bool isImporting;
  final String? errorMessage;

  const BulkAttendanceUploadState({
    this.currentStep = 0,
    this.selectedFileBytes,
    this.selectedFileName,
    this.validateResult,
    this.conflictStrategy = 'SKIP_EXISTING',
    this.importResult,
    this.isValidating = false,
    this.isImporting = false,
    this.errorMessage,
  });

  BulkAttendanceUploadState copyWith({
    int? currentStep,
    List<int>? selectedFileBytes,
    String? selectedFileName,
    BulkAttendanceValidateDto? validateResult,
    String? conflictStrategy,
    BulkAttendanceImportResponseDto? importResult,
    bool? isValidating,
    bool? isImporting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BulkAttendanceUploadState(
      currentStep: currentStep ?? this.currentStep,
      selectedFileBytes: selectedFileBytes ?? this.selectedFileBytes,
      selectedFileName: selectedFileName ?? this.selectedFileName,
      validateResult: validateResult ?? this.validateResult,
      conflictStrategy: conflictStrategy ?? this.conflictStrategy,
      importResult: importResult ?? this.importResult,
      isValidating: isValidating ?? this.isValidating,
      isImporting: isImporting ?? this.isImporting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class BulkAttendanceUploadNotifier extends StateNotifier<BulkAttendanceUploadState> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  BulkAttendanceUploadNotifier(this._apiClient, this._ref)
      : super(const BulkAttendanceUploadState());

  void setStep(int step) => state = state.copyWith(currentStep: step, clearError: true);

  void setConflictStrategy(String strategy) => state = state.copyWith(conflictStrategy: strategy);

  void reset() => state = const BulkAttendanceUploadState();

  Future<void> downloadTemplate() async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    try {
      const templateHeaders = "Admission Number,Student Name,Class,Section,Attendance Date,Session,Status,Remarks\n";
      final sampleRow = "ADM2025001,John Doe,Grade 10,Section A,${DateTime.now().toIso8601String().substring(0, 10)},FULL_DAY,PRESENT,Regular attendance\n";
      downloadCsvFile('attendance_import_template.csv', templateHeaders + sampleRow);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to download template: $e');
    }
  }

  Future<void> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          state = state.copyWith(
            selectedFileBytes: file.bytes,
            selectedFileName: file.name,
            currentStep: 1,
            clearError: true,
          );
        }
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to pick file: $e');
    }
  }

  Future<void> validateFile(String academicYearId) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null || state.selectedFileBytes == null || state.selectedFileName == null) return;

    state = state.copyWith(isValidating: true, clearError: true);

    try {
      final formData = FormData.fromMap({
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'file': MultipartFile.fromBytes(
          state.selectedFileBytes!,
          filename: state.selectedFileName!,
        ),
      });

      final result = await _apiClient.post(
        '/attendances/bulk/validate',
        data: formData,
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          return BulkAttendanceValidateDto.fromJson(Map<String, dynamic>.from(payload['data'] as Map));
        },
      );

      if (!mounted) return;

      result.when(
        onSuccess: (valResult) {
          state = state.copyWith(
            isValidating: false,
            validateResult: valResult,
            currentStep: 2,
          );
        },
        onFailure: (failure) {
          state = state.copyWith(isValidating: false, errorMessage: failure.message);
        },
      );
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isValidating: false, errorMessage: e.toString());
      }
    }
  }

  Future<void> executeImport() async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null || state.validateResult == null) return;

    state = state.copyWith(isImporting: true, clearError: true);

    try {
      final result = await _apiClient.post(
        '/attendances/bulk/import?school_id=$schoolId',
        data: {
          'job_id': state.validateResult!.jobId,
          'conflict_strategy': state.conflictStrategy,
        },
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          return BulkAttendanceImportResponseDto.fromJson(Map<String, dynamic>.from(payload['data'] as Map));
        },
      );

      if (!mounted) return;

      result.when(
        onSuccess: (impResult) {
          state = state.copyWith(
            isImporting: false,
            importResult: impResult,
            currentStep: 4,
          );
          _ref.read(attendanceDashboardProvider.notifier).fetchDashboard();
          _ref.read(attendanceImportsHistoryProvider.notifier).fetchHistory();
        },
        onFailure: (failure) {
          state = state.copyWith(isImporting: false, errorMessage: failure.message);
        },
      );
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isImporting: false, errorMessage: e.toString());
      }
    }
  }
}

final bulkAttendanceUploadProvider =
    StateNotifierProvider<BulkAttendanceUploadNotifier, BulkAttendanceUploadState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return BulkAttendanceUploadNotifier(apiClient, ref);
});

// ==================================================
// 9. Attendance Import Jobs History State & Notifier
// ==================================================
class AttendanceImportsHistoryState {
  final List<AttendanceImportJobDto> jobs;
  final int total;
  final bool isLoading;
  final String? error;

  const AttendanceImportsHistoryState({
    this.jobs = const [],
    this.total = 0,
    this.isLoading = false,
    this.error,
  });

  AttendanceImportsHistoryState copyWith({
    List<AttendanceImportJobDto>? jobs,
    int? total,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AttendanceImportsHistoryState(
      jobs: jobs ?? this.jobs,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AttendanceImportsHistoryNotifier extends StateNotifier<AttendanceImportsHistoryState> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  AttendanceImportsHistoryNotifier(this._apiClient, this._ref)
      : super(const AttendanceImportsHistoryState());

  Future<void> fetchHistory() async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _apiClient.get(
      '/attendances/imports?school_id=$schoolId&limit=50',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List? ?? [];
        final total = (payload['meta'] as Map?)?['total'] as int? ?? list.length;
        return {
          'jobs': list.map((e) => AttendanceImportJobDto.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
          'total': total,
        };
      },
    );

    if (!mounted) return;

    result.when(
      onSuccess: (data) {
        state = state.copyWith(
          jobs: data['jobs'] as List<AttendanceImportJobDto>,
          total: data['total'] as int,
          isLoading: false,
        );
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }

  Future<void> downloadErrorsCsv(String jobId) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    try {
      final result = await _apiClient.get(
        '/attendances/imports/$jobId/errors?school_id=$schoolId',
        mapper: (json) => json.toString(),
      );

      result.when(
        onSuccess: (csvText) {
          downloadCsvFile('attendance_import_errors_$jobId.csv', csvText);
        },
        onFailure: (failure) {
          state = state.copyWith(error: 'Failed to download errors CSV: ${failure.message}');
        },
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final attendanceImportsHistoryProvider =
    StateNotifierProvider<AttendanceImportsHistoryNotifier, AttendanceImportsHistoryState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AttendanceImportsHistoryNotifier(apiClient, ref);
});

// ==================================================
// 10. Attendance Audit Logs State & Notifier
// ==================================================
class AttendanceAuditLogsState {
  final List<AttendanceAuditLogDto> logs;
  final int total;
  final int skip;
  final int limit;
  final bool isLoading;
  final String? error;

  const AttendanceAuditLogsState({
    this.logs = const [],
    this.total = 0,
    this.skip = 0,
    this.limit = 50,
    this.isLoading = false,
    this.error,
  });

  AttendanceAuditLogsState copyWith({
    List<AttendanceAuditLogDto>? logs,
    int? total,
    int? skip,
    int? limit,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AttendanceAuditLogsState(
      logs: logs ?? this.logs,
      total: total ?? this.total,
      skip: skip ?? this.skip,
      limit: limit ?? this.limit,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AttendanceAuditLogsNotifier extends StateNotifier<AttendanceAuditLogsState> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  AttendanceAuditLogsNotifier(this._apiClient, this._ref)
      : super(const AttendanceAuditLogsState());

  Future<void> fetchAuditLogs({
    String? studentId,
    DateTime? startDate,
    DateTime? endDate,
    String? action,
    int skip = 0,
    int limit = 50,
  }) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    state = state.copyWith(isLoading: true, skip: skip, limit: limit, clearError: true);

    final Map<String, String> query = {
      'school_id': schoolId,
      'skip': skip.toString(),
      'limit': limit.clamp(1, 100).toString(),
    };
    if (studentId != null) query['student_id'] = studentId;
    if (action != null) query['action'] = action;
    if (startDate != null) query['start_date'] = startDate.toIso8601String().substring(0, 10);
    if (endDate != null) query['end_date'] = endDate.toIso8601String().substring(0, 10);

    final uri = Uri(path: '/attendances/audit-logs', queryParameters: query);

    final result = await _apiClient.get(
      uri.toString(),
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List? ?? [];
        final total = (payload['meta'] as Map?)?['total'] as int? ?? list.length;
        return {
          'logs': list.map((e) => AttendanceAuditLogDto.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
          'total': total,
        };
      },
    );

    if (!mounted) return;

    result.when(
      onSuccess: (data) {
        state = state.copyWith(
          logs: data['logs'] as List<AttendanceAuditLogDto>,
          total: data['total'] as int,
          isLoading: false,
        );
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }
}

final attendanceAuditLogsProvider =
    StateNotifierProvider<AttendanceAuditLogsNotifier, AttendanceAuditLogsState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AttendanceAuditLogsNotifier(apiClient, ref);
});

// ==================================================
// 12. Teacher Assigned Classes & Sections Provider
// ==================================================
final teacherAttendanceAssignmentsProvider =
    FutureProvider.family<List<TeacherSubjectAssignmentDto>, String>((ref, schoolId) async {
  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/teacher-subject-assignments?school_id=$schoolId',
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = payload['data'] as List<dynamic>? ?? [];
      return list
          .map((item) => TeacherSubjectAssignmentDto.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    },
  );

  return result.when(
    onSuccess: (data) => data,
    onFailure: (_) => [],
  );
});
