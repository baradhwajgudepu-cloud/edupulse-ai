import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
        'attendance_source': AttendanceSource.MANUAL.wireValue,
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
        _ref.read(attendanceRegisterProvider.notifier).fetchRegister();
        _ref.read(attendanceDashboardProvider.notifier).fetchDashboard();
        _ref.read(attendanceAuditLogsProvider.notifier).fetchAuditLogs();
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
    bool clearAcademicYear = false,
    bool clearClass = false,
    bool clearSection = false,
    bool clearRoster = false,
  }) {
    return DailyAttendanceMarkState(
      academicYearId: clearAcademicYear ? null : (academicYearId ?? this.academicYearId),
      classId: clearClass ? null : (classId ?? this.classId),
      sectionId: clearSection ? null : (sectionId ?? this.sectionId),
      attendanceDate: attendanceDate ?? this.attendanceDate,
      sessionType: sessionType ?? this.sessionType,
      roster: clearRoster ? const [] : (roster ?? this.roster),
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
    bool clearAcademicYear = false,
    bool clearClass = false,
    bool clearSection = false,
  }) {
    final bool ayChanged = (academicYearId != null && academicYearId != state.academicYearId);
    final bool classChanged = (classId != null && classId != state.classId);

    // Determine new academicYearId
    final String? nextAyId = clearAcademicYear
        ? null
        : (academicYearId ?? state.academicYearId);

    // Determine new classId:
    // If AY is cleared or AY changed and no new classId was passed, classId is cleared.
    final bool shouldClearClass = clearAcademicYear || clearClass || (ayChanged && classId == null);
    final String? nextClassId = shouldClearClass
        ? null
        : (classId ?? state.classId);

    // Determine new sectionId:
    // If Class is cleared/changed, or Section is cleared, or AY changed and no new sectionId passed, clear sectionId.
    final bool shouldClearSection = shouldClearClass || clearSection || (classChanged && sectionId == null);
    final String? nextSectionId = shouldClearSection
        ? null
        : (sectionId ?? state.sectionId);

    final bool shouldClearRoster = nextClassId == null || nextSectionId == null;
    final bool dateChanged = (attendanceDate != null && attendanceDate != state.attendanceDate);
    final bool sessionTypeChanged = (sessionType != null && sessionType != state.sessionType);
    final bool shouldClearSession = shouldClearRoster || dateChanged || sessionTypeChanged;

    state = state.copyWith(
      academicYearId: nextAyId,
      classId: nextClassId,
      sectionId: nextSectionId,
      attendanceDate: attendanceDate ?? state.attendanceDate,
      sessionType: sessionType ?? state.sessionType,
      roster: shouldClearRoster ? const [] : state.roster,
      clearAcademicYear: nextAyId == null,
      clearClass: nextClassId == null,
      clearSection: nextSectionId == null,
      clearRoster: shouldClearRoster,
      clearSession: shouldClearSession,
      clearError: true,
      clearSuccess: true,
    );

    if (state.classId != null && state.sectionId != null) {
      loadRoster();
    }
  }

  void reset() {
    state = DailyAttendanceMarkState();
  }

  Future<void> loadRoster({bool preserveSuccess = false}) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null || state.classId == null || state.sectionId == null) return;

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: !preserveSuccess,
    );

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

      // 2. Check if existing session via canonical /attendances/sessions endpoint
      AttendanceSessionDto? existingSession;
      final sessionRes = await _apiClient.get(
        '/attendances/sessions?school_id=$schoolId&class_id=${state.classId}&section_id=${state.sectionId}&attendance_date=$dateStr&limit=10',
        mapper: (json) {
          if (json is! Map) return null;
          final dynamic rawData = json['data'];
          if (rawData == null || rawData is! List || rawData.isEmpty) {
            return null;
          }
          final sessions = rawData
              .whereType<Map>()
              .map((m) => AttendanceSessionDto.fromJson(Map<String, dynamic>.from(m)))
              .toList();
          if (sessions.isEmpty) return null;
          return sessions.firstWhere(
            (s) => s.sessionType.toUpperCase() == state.sessionType.toUpperCase(),
            orElse: () => sessions.first,
          );
        },
      );

      if (!mounted) return;

      sessionRes.when(
        onSuccess: (session) => existingSession = session,
        onFailure: (_) {
          // Normal state when no session exists or if optional lookup fails
          existingSession = null;
        },
      );

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
        clearError: true,
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
    if (state.isLocked) {
      state = state.copyWith(errorMessage: 'This attendance session is locked and cannot be edited.');
      return false;
    }

    state = state.copyWith(isSaving: true, clearError: true, clearSuccess: true);

    final dateStr = state.attendanceDate.toIso8601String().substring(0, 10);
    String? sessionId = state.sessionId;

    // 1. Resolve session if not already set in state
    if (sessionId == null || sessionId.isEmpty) {
      final sessionRes = await _apiClient.get(
        '/attendances/sessions?school_id=$schoolId&class_id=${state.classId}&section_id=${state.sectionId}&attendance_date=$dateStr&limit=10',
        mapper: (json) {
          if (json is! Map) return null;
          final dynamic rawData = json['data'];
          if (rawData == null || rawData is! List || rawData.isEmpty) return null;
          final sessions = rawData
              .whereType<Map>()
              .map((m) => AttendanceSessionDto.fromJson(Map<String, dynamic>.from(m)))
              .toList();
          if (sessions.isEmpty) return null;
          return sessions.firstWhere(
            (s) => s.sessionType.toUpperCase() == state.sessionType.toUpperCase(),
            orElse: () => sessions.first,
          );
        },
      );

      sessionRes.when(
        onSuccess: (session) => sessionId = session?.id,
        onFailure: (_) {},
      );
    }

    // 2. If session still does not exist, resolve timetable slot and create/start session
    if (sessionId == null || sessionId!.isEmpty) {
      final timetableRes = await _apiClient.get(
        '/timetables?school_id=$schoolId&class_id=${state.classId}&section_id=${state.sectionId}${state.academicYearId != null ? '&academic_year_id=${state.academicYearId}' : ''}&limit=1',
        mapper: (json) {
          if (json is! Map) return null;
          final dynamic rawData = json['data'];
          if (rawData == null || rawData is! List || rawData.isEmpty) return null;
          final first = rawData.first;
          if (first is! Map) return null;
          return first['id'] as String?;
        },
      );

      String? timetableId;
      timetableRes.when(
        onSuccess: (id) => timetableId = id,
        onFailure: (_) {},
      );

      if (timetableId == null || timetableId!.isEmpty) {
        if (mounted) {
          state = state.copyWith(
            isSaving: false,
            errorMessage: 'No active timetable slot found for this class and section.',
          );
        }
        return false;
      }

      final createRes = await _apiClient.post(
        '/attendances/session',
        data: {
          'school_id': schoolId,
          'academic_year_id': state.academicYearId,
          'timetable_id': timetableId,
          'attendance_date': dateStr,
          'session_type': state.sessionType,
          'settings': {
            'session_type': state.sessionType,
          },
        },
        mapper: (json) {
          if (json is! Map) return null;
          final dynamic data = json['data'];
          if (data is Map && data['id'] != null) {
            return data['id'] as String;
          }
          return null;
        },
      );

      String? createError;
      createRes.when(
        onSuccess: (id) => sessionId = id,
        onFailure: (failure) => createError = failure.message,
      );

      // If creation failed (e.g. session already exists), re-query /attendances/sessions
      if (sessionId == null || sessionId!.isEmpty) {
        final retryRes = await _apiClient.get(
          '/attendances/sessions?school_id=$schoolId&class_id=${state.classId}&section_id=${state.sectionId}&attendance_date=$dateStr&limit=10',
          mapper: (json) {
            if (json is! Map) return null;
            final dynamic rawData = json['data'];
            if (rawData == null || rawData is! List || rawData.isEmpty) return null;
            final sessions = rawData
                .whereType<Map>()
                .map((m) => AttendanceSessionDto.fromJson(Map<String, dynamic>.from(m)))
                .toList();
            if (sessions.isEmpty) return null;
            return sessions.firstWhere(
              (s) => s.sessionType.toUpperCase() == state.sessionType.toUpperCase(),
              orElse: () => sessions.first,
            );
          },
        );
        retryRes.when(
          onSuccess: (session) => sessionId = session?.id,
          onFailure: (_) {},
        );
      }

      if (sessionId == null || sessionId!.isEmpty) {
        if (mounted) {
          state = state.copyWith(
            isSaving: false,
            errorMessage: createError ?? 'Failed to initiate attendance session.',
          );
        }
        return false;
      }
    }

    final targetSessionId = sessionId!;

    // 3. Mark attendance using canonical session/{session_id}/mark endpoint
    final markPayload = {
      'attendance_session_status': 'SUBMITTED',
      'records': state.roster.map((r) => {
        'student_id': r.studentId,
        'attendance_status': r.status,
        'attendance_source': AttendanceSource.MANUAL.wireValue,
        'attendance_reason': r.status == 'PRESENT'
            ? DropdownSafety.reasonUnknown
            : DropdownSafety.normalizeAttendanceReason(r.reason),
        'remarks': r.remarks.trim().isEmpty ? null : r.remarks.trim(),
      }).toList(),
    };

    final result = await _apiClient.post(
      '/attendances/session/$targetSessionId/mark?school_id=$schoolId',
      data: markPayload,
      mapper: (json) => json,
    );

    if (!mounted) return false;

    return result.when(
      onSuccess: (_) {
        state = state.copyWith(
          isSaving: false,
          sessionId: sessionId,
          successMessage: 'Attendance marked successfully for ${state.roster.length} students.',
        );
        _ref.read(attendanceDashboardProvider.notifier).fetchDashboard();
        _ref.read(attendanceSessionsProvider.notifier).fetchSessions();
        _ref.read(attendanceRegisterProvider.notifier).fetchRegister();
        _ref.read(attendanceAuditLogsProvider.notifier).fetchAuditLogs();
        loadRoster(preserveSuccess: true);
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

class _AttendanceStudentIdentity {
  final String id;
  final String firstName;
  final String lastName;
  final String admissionNumber;
  final String? rollNumber;
  final String? className;
  final String? sectionName;

  const _AttendanceStudentIdentity({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.admissionNumber,
    this.rollNumber,
    this.className,
    this.sectionName,
  });

  factory _AttendanceStudentIdentity.fromJson(Map<String, dynamic> json) {
    final first = (json['first_name'] ?? json['firstName'] ?? '').toString();
    final last = (json['last_name'] ?? json['lastName'] ?? '').toString();
    final adm = (json['admission_number'] ?? json['admission_no'] ?? json['admissionNumber'] ?? '').toString();
    final roll = (json['roll_number'] ?? json['roll_no'] ?? json['rollNumber'])?.toString();
    final cls = (json['class_name'] ?? json['className'])?.toString();
    final sec = (json['section_name'] ?? json['sectionName'])?.toString();
    return _AttendanceStudentIdentity(
      id: (json['id'] ?? '').toString(),
      firstName: first,
      lastName: last,
      admissionNumber: adm,
      rollNumber: roll,
      className: cls,
      sectionName: sec,
    );
  }
}

class AttendanceRegisterNotifier extends StateNotifier<AttendanceRegisterState> {
  final BaseApiClient _apiClient;
  final Ref _ref;
  final Map<String, _AttendanceStudentIdentity> _studentCache = {};
  final Map<String, String> _sessionTypeCache = {};

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

    bool isFallback = false;
    result.when(
      onSuccess: (_) {},
      onFailure: (f) {
        if (f.statusCode == 404 || f.message.contains('404')) {
          isFallback = true;
        }
      },
    );

    if (isFallback) {
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
          final total = (payload['meta'] as Map?)?['total'] as int? ?? list.length;
          return {
            'records': list.map((e) => AttendanceLogDto.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
            'total': total,
          };
        },
      );
      if (!mounted) return;
    }

    await result.when(
      onSuccess: (data) async {
        final List<AttendanceLogDto> rawRecords = data['records'] as List<AttendanceLogDto>;
        int total = data['total'] as int;

        // Enrich records with student names, admission numbers, class/section names, and session types
        final enrichedRecords = await _enrichRecords(schoolId, rawRecords, isFallback: isFallback);

        if (!mounted) return;

        List<AttendanceLogDto> finalRecords = enrichedRecords;

        // Apply client-side search/filtering ONLY when fallback is used, avoiding duplicate filtering when register endpoint supports it
        if (isFallback) {
          if (state.search.trim().isNotEmpty) {
            final queryLower = state.search.trim().toLowerCase();
            finalRecords = finalRecords.where((r) {
              final nameMatch = r.studentName?.toLowerCase().contains(queryLower) ?? false;
              final admMatch = r.admissionNumber?.toLowerCase().contains(queryLower) ?? false;
              final rollMatch = r.studentRollNumber?.toLowerCase().contains(queryLower) ?? false;
              return nameMatch || admMatch || rollMatch;
            }).toList();
          }

          if (state.status != null && state.status!.isNotEmpty) {
            final statusUpper = state.status!.toUpperCase();
            finalRecords = finalRecords.where((r) => r.attendanceStatus.toUpperCase() == statusUpper).toList();
          }

          if (state.startDate != null) {
            final startStr = state.startDate!.toIso8601String().substring(0, 10);
            finalRecords = finalRecords.where((r) => r.attendanceDate.compareTo(startStr) >= 0).toList();
          }

          if (state.endDate != null) {
            final endStr = state.endDate!.toIso8601String().substring(0, 10);
            finalRecords = finalRecords.where((r) => r.attendanceDate.compareTo(endStr) <= 0).toList();
          }

          total = finalRecords.length;
        }

        state = state.copyWith(
          records: finalRecords,
          total: total,
          isLoading: false,
        );
      },
      onFailure: (failure) async {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }

  Future<List<AttendanceLogDto>> _enrichRecords(
    String schoolId,
    List<AttendanceLogDto> records, {
    required bool isFallback,
  }) async {
    if (records.isEmpty) return records;

    // 1. Resolve Class and Section names
    final classesState = _ref.read(classesProvider(schoolId));
    final sectionsState = _ref.read(sectionsProvider(schoolId));
    final classMap = {for (final c in classesState.classes) c.id: c.name};
    final sectionMap = {for (final s in sectionsState.sections) s.id: s.name};

    // 2. Resolve Session Types
    final existingSessions = _ref.read(attendanceSessionsProvider).sessions;
    for (final s in existingSessions) {
      if (s.id.isNotEmpty && s.sessionType.isNotEmpty) {
        _sessionTypeCache[s.id] = s.sessionType;
      }
    }

    final missingSessionIds = records
        .where((r) => r.attendanceSessionId.isNotEmpty && !_sessionTypeCache.containsKey(r.attendanceSessionId))
        .map((r) => r.attendanceSessionId)
        .toSet();

    if (missingSessionIds.isNotEmpty) {
      final sessionRes = await _apiClient.get(
        '/attendances/sessions?school_id=$schoolId&limit=50',
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          final list = payload['data'] as List? ?? [];
          return list.map((e) => AttendanceSessionDto.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        },
      );
      sessionRes.when(
        onSuccess: (sessions) {
          for (final s in sessions) {
            if (s.id.isNotEmpty && s.sessionType.isNotEmpty) {
              _sessionTypeCache[s.id] = s.sessionType;
            }
          }
        },
        onFailure: (_) {},
      );
    }

    // 3. Resolve Student Identity (name, adm no, roll no)
    final needsStudentResolution = records.where((r) {
      final nameMissing = r.studentName == null || r.studentName!.isEmpty || r.studentName == '-';
      final admMissing = r.admissionNumber == null || r.admissionNumber!.isEmpty || r.admissionNumber == '-';
      return (nameMissing || admMissing) && r.studentId.isNotEmpty;
    }).toList();

    final missingStudentIds = needsStudentResolution
        .map((r) => r.studentId)
        .where((id) => !_studentCache.containsKey(id))
        .toSet();

    if (missingStudentIds.isNotEmpty) {
      // Bulk fetch students for class/section or school
      final queryParams = <String>[
        'school_id=$schoolId',
        if (state.classId != null) 'class_id=${state.classId}',
        if (state.sectionId != null) 'section_id=${state.sectionId}',
        'limit=100',
      ];
      final studentsRes = await _apiClient.get(
        '/students?${queryParams.join('&')}',
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          final list = payload['data'] as List? ?? [];
          final result = <_AttendanceStudentIdentity>[];
          for (final e in list) {
            if (e is Map) {
              result.add(_AttendanceStudentIdentity.fromJson(Map<String, dynamic>.from(e)));
            }
          }
          return result;
        },
      );
      studentsRes.when(
        onSuccess: (students) {
          for (final s in students) {
            _studentCache[s.id] = s;
          }
        },
        onFailure: (_) {},
      );

      // If specific students still missing, fetch individually
      final stillMissing = missingStudentIds.where((id) => !_studentCache.containsKey(id)).take(15);
      for (final id in stillMissing) {
        final singleRes = await _apiClient.get(
          '/students/$id?school_id=$schoolId',
          mapper: (json) {
            final payload = json as Map<String, dynamic>;
            final dynamic data = payload['data'];
            if (data is Map) {
              return _AttendanceStudentIdentity.fromJson(Map<String, dynamic>.from(data));
            }
            return null;
          },
        );
        singleRes.when(
          onSuccess: (s) {
            if (s != null) {
              _studentCache[s.id] = s;
            }
          },
          onFailure: (_) {},
        );
      }
    }

    // 4. If search query is active during fallback, pre-load matching students if needed
    if (isFallback && state.search.trim().isNotEmpty) {
      final searchStudentsRes = await _apiClient.get(
        '/students?school_id=$schoolId&search=${Uri.encodeComponent(state.search.trim())}&limit=50',
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          final list = payload['data'] as List? ?? [];
          final result = <_AttendanceStudentIdentity>[];
          for (final e in list) {
            if (e is Map) {
              result.add(_AttendanceStudentIdentity.fromJson(Map<String, dynamic>.from(e)));
            }
          }
          return result;
        },
      );
      searchStudentsRes.when(
        onSuccess: (students) {
          for (final s in students) {
            _studentCache[s.id] = s;
          }
        },
        onFailure: (_) {},
      );
    }

    // 5. Enrich records without mutating original DTO
    return records.map((r) {
      final student = _studentCache[r.studentId];

      final resolvedName = (r.studentName != null && r.studentName!.isNotEmpty && r.studentName != '-')
          ? r.studentName
          : (student != null ? '${student.firstName} ${student.lastName}'.trim() : null);

      final resolvedAdm = (r.admissionNumber != null && r.admissionNumber!.isNotEmpty && r.admissionNumber != '-')
          ? r.admissionNumber
          : student?.admissionNumber;

      final resolvedRoll = (r.studentRollNumber != null && r.studentRollNumber!.isNotEmpty)
          ? r.studentRollNumber
          : student?.rollNumber;

      final resolvedClass = (r.className != null && r.className!.isNotEmpty)
          ? r.className
          : (classMap[r.classId] ?? student?.className);

      final resolvedSection = (r.sectionName != null && r.sectionName!.isNotEmpty)
          ? r.sectionName
          : (sectionMap[r.sectionId] ?? student?.sectionName);

      final resolvedSession = (r.sessionType.isNotEmpty && r.sessionType != 'FULL_DAY')
          ? r.sessionType
          : (_sessionTypeCache[r.attendanceSessionId] ?? r.sessionType);

      return r.copyWith(
        studentName: resolvedName,
        admissionNumber: resolvedAdm,
        studentRollNumber: resolvedRoll,
        className: resolvedClass,
        sectionName: resolvedSection,
        sessionType: resolvedSession,
      );
    }).toList();
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
class ParsedBulkAttendanceRow {
  final int rowNumber;
  final String? studentId;
  final String admissionNumber;
  final String? studentName;
  final String? rollNumber;
  final String? classId;
  final String? className;
  final String? sectionId;
  final String? sectionName;
  final String attendanceDate; // YYYY-MM-DD
  final String sessionType; // MORNING, AFTERNOON, FULL_DAY
  final String attendanceStatus; // PRESENT, ABSENT, LATE, HALF_DAY, EXCUSED
  final String attendanceReason;
  final String? remarks;
  final bool isValid;
  final bool isDuplicate;
  final bool isConflict;
  final String? conflictExistingStatus;
  final String? errorMessage;

  const ParsedBulkAttendanceRow({
    required this.rowNumber,
    this.studentId,
    required this.admissionNumber,
    this.studentName,
    this.rollNumber,
    this.classId,
    this.className,
    this.sectionId,
    this.sectionName,
    required this.attendanceDate,
    required this.sessionType,
    required this.attendanceStatus,
    required this.attendanceReason,
    this.remarks,
    required this.isValid,
    this.isDuplicate = false,
    this.isConflict = false,
    this.conflictExistingStatus,
    this.errorMessage,
  });
}

class _BulkStudentLookup {
  final String id;
  final String admissionNumber;
  final String firstName;
  final String lastName;
  final String? rollNumber;
  final String classId;
  final String sectionId;
  final String? className;
  final String? sectionName;
  final bool isActive;

  const _BulkStudentLookup({
    required this.id,
    required this.admissionNumber,
    required this.firstName,
    required this.lastName,
    this.rollNumber,
    required this.classId,
    required this.sectionId,
    this.className,
    this.sectionName,
    this.isActive = true,
  });

  factory _BulkStudentLookup.fromJson(Map<String, dynamic> json) {
    final first = (json['first_name'] ?? json['firstName'] ?? '').toString();
    final last = (json['last_name'] ?? json['lastName'] ?? '').toString();
    final adm = (json['admission_number'] ?? json['admission_no'] ?? json['admissionNumber'] ?? '').toString();
    final roll = (json['roll_number'] ?? json['roll_no'] ?? json['rollNumber'])?.toString();
    final cid = (json['class_id'] ?? json['classId'] ?? '').toString();
    final sid = (json['section_id'] ?? json['sectionId'] ?? '').toString();
    final cName = (json['class_name'] ?? json['className'])?.toString();
    final sName = (json['section_name'] ?? json['sectionName'])?.toString();
    final active = json['is_active'] != false && (json['status'] == null || json['status'] == 'ACTIVE');

    return _BulkStudentLookup(
      id: (json['id'] ?? '').toString(),
      admissionNumber: adm,
      firstName: first,
      lastName: last,
      rollNumber: roll,
      classId: cid,
      sectionId: sid,
      className: cName,
      sectionName: sName,
      isActive: active,
    );
  }
}

// ==================================================
// 8. Bulk Attendance Upload Wizard State & Notifier
// ==================================================
class BulkAttendanceUploadState {
  final int currentStep;
  final List<int>? selectedFileBytes;
  final String? selectedFileName;
  final String? selectedAcademicYearId;
  final BulkAttendanceValidateDto? validateResult;
  final List<ParsedBulkAttendanceRow> parsedRows;
  final String conflictStrategy;
  final BulkAttendanceImportResponseDto? importResult;
  final bool isValidating;
  final bool isImporting;
  final String? errorMessage;
  final String? importId;
  final int totalImportRows;
  final int processedImportRows;
  final int remainingImportRows;
  final int currentBatchIndex;
  final int totalBatches;
  final int importSuccessCount;
  final int importSkippedCount;
  final int importFailureCount;
  final int? lastFailedBatchIndex;
  final int previewCurrentPage;
  final int previewPageSize;

  const BulkAttendanceUploadState({
    this.currentStep = 0,
    this.selectedFileBytes,
    this.selectedFileName,
    this.selectedAcademicYearId,
    this.validateResult,
    this.parsedRows = const [],
    this.conflictStrategy = 'SKIP_EXISTING',
    this.importResult,
    this.isValidating = false,
    this.isImporting = false,
    this.errorMessage,
    this.importId,
    this.totalImportRows = 0,
    this.processedImportRows = 0,
    this.remainingImportRows = 0,
    this.currentBatchIndex = 0,
    this.totalBatches = 0,
    this.importSuccessCount = 0,
    this.importSkippedCount = 0,
    this.importFailureCount = 0,
    this.lastFailedBatchIndex,
    this.previewCurrentPage = 1,
    this.previewPageSize = 25,
  });

  BulkAttendanceUploadState copyWith({
    int? currentStep,
    List<int>? selectedFileBytes,
    String? selectedFileName,
    String? selectedAcademicYearId,
    BulkAttendanceValidateDto? validateResult,
    List<ParsedBulkAttendanceRow>? parsedRows,
    String? conflictStrategy,
    BulkAttendanceImportResponseDto? importResult,
    bool? isValidating,
    bool? isImporting,
    String? errorMessage,
    bool clearError = false,
    bool clearFailedBatch = false,
    String? importId,
    int? totalImportRows,
    int? processedImportRows,
    int? remainingImportRows,
    int? currentBatchIndex,
    int? totalBatches,
    int? importSuccessCount,
    int? importSkippedCount,
    int? importFailureCount,
    int? lastFailedBatchIndex,
    int? previewCurrentPage,
    int? previewPageSize,
  }) {
    return BulkAttendanceUploadState(
      currentStep: currentStep ?? this.currentStep,
      selectedFileBytes: selectedFileBytes ?? this.selectedFileBytes,
      selectedFileName: selectedFileName ?? this.selectedFileName,
      selectedAcademicYearId: selectedAcademicYearId ?? this.selectedAcademicYearId,
      validateResult: validateResult ?? this.validateResult,
      parsedRows: parsedRows ?? this.parsedRows,
      conflictStrategy: conflictStrategy ?? this.conflictStrategy,
      importResult: importResult ?? this.importResult,
      isValidating: isValidating ?? this.isValidating,
      isImporting: isImporting ?? this.isImporting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      importId: importId ?? this.importId,
      totalImportRows: totalImportRows ?? this.totalImportRows,
      processedImportRows: processedImportRows ?? this.processedImportRows,
      remainingImportRows: remainingImportRows ?? this.remainingImportRows,
      currentBatchIndex: currentBatchIndex ?? this.currentBatchIndex,
      totalBatches: totalBatches ?? this.totalBatches,
      importSuccessCount: importSuccessCount ?? this.importSuccessCount,
      importSkippedCount: importSkippedCount ?? this.importSkippedCount,
      importFailureCount: importFailureCount ?? this.importFailureCount,
      lastFailedBatchIndex: clearFailedBatch ? null : (lastFailedBatchIndex ?? this.lastFailedBatchIndex),
      previewCurrentPage: previewCurrentPage ?? this.previewCurrentPage,
      previewPageSize: previewPageSize ?? this.previewPageSize,
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

  void setPreviewPage(int page) => state = state.copyWith(previewCurrentPage: page);

  void setPreviewPageSize(int size) => state = state.copyWith(previewPageSize: size, previewCurrentPage: 1);

  void reset() => state = const BulkAttendanceUploadState();

  Future<void> downloadTemplate() async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    try {
      const templateHeaders = "admission_number,student_name,roll_number,class_code,section_code,attendance_date,session_type,attendance_status,attendance_reason,remarks\n";
      final sampleRow = "ADM001,Aarav Sharma,1,G10,G10-A,${DateTime.now().toIso8601String().substring(0, 10)},MORNING,PRESENT,UNKNOWN,Regular attendance\n";
      downloadCsvFile('attendance_import_template.csv', templateHeaders + sampleRow);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to download template: $e');
    }
  }

  void selectFile(List<int> bytes, String fileName) {
    state = state.copyWith(
      selectedFileBytes: bytes,
      selectedFileName: fileName,
      currentStep: 1,
      clearError: true,
    );
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

  static List<List<String>> _parseCsvBytes(List<int> bytes) {
    var content = utf8.decode(bytes, allowMalformed: true);
    if (content.startsWith('\uFEFF')) {
      content = content.substring(1);
    }
    return _parseCsvString(content);
  }

  static List<List<String>> _parseCsvString(String text) {
    final rows = <List<String>>[];
    final currentRow = <String>[];
    final currentField = StringBuffer();
    bool insideQuotes = false;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];

      if (char == '"') {
        if (insideQuotes && i + 1 < text.length && text[i + 1] == '"') {
          currentField.write('"');
          i++; // Skip escaped quote
        } else {
          insideQuotes = !insideQuotes;
        }
      } else if (char == ',' && !insideQuotes) {
        currentRow.add(currentField.toString().trim());
        currentField.clear();
      } else if ((char == '\n' || char == '\r') && !insideQuotes) {
        if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') {
          i++; // Skip \n in \r\n
        }
        currentRow.add(currentField.toString().trim());
        currentField.clear();
        if (currentRow.any((c) => c.isNotEmpty)) {
          rows.add(List<String>.from(currentRow));
        }
        currentRow.clear();
      } else {
        currentField.write(char);
      }
    }

    if (currentField.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentField.toString().trim());
      if (currentRow.any((c) => c.isNotEmpty)) {
        rows.add(List<String>.from(currentRow));
      }
    }

    return rows;
  }

  static String _normHeader(String h) {
    var cleaned = h.replaceAll('\uFEFF', '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_').replaceAll(RegExp(r'_+'), '_');
    while (cleaned.startsWith('_')) {
      cleaned = cleaned.substring(1);
    }
    while (cleaned.endsWith('_')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned;
  }

  Future<void> validateFile(String academicYearId) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null || state.selectedFileBytes == null || state.selectedFileName == null) return;

    state = state.copyWith(isValidating: true, clearError: true);

    try {
      final fileName = state.selectedFileName?.toLowerCase() ?? '';
      final isCsv = fileName.endsWith('.csv');

      List<List<String>> rawRows = [];
      String? parseError;

      if (isCsv) {
        // Zero network overhead: CSV files are parsed locally in memory using RFC-4180 parser.
        // Never calls /import-jobs/parse for CSV files.
        try {
          rawRows = _parseCsvBytes(state.selectedFileBytes!);
        } catch (e) {
          parseError = 'Failed to parse CSV file: $e';
        }
      } else {
        // For non-CSV spreadsheets (Excel .xlsx, .xls), attempt remote parsing endpoint
        try {
          final formData = FormData.fromMap({
            'file': MultipartFile.fromBytes(
              state.selectedFileBytes!,
              filename: state.selectedFileName!,
            ),
          });

          final parseRes = await _apiClient.post<Map<String, dynamic>>(
            '/import-jobs/parse',
            data: formData,
            mapper: (json) {
              if (json is! Map) return {};
              final data = json['data'];
              if (data is Map) return Map<String, dynamic>.from(data);
              return {};
            },
          );

          parseRes.when(
            onSuccess: (data) {
              final headersList = data['headers'] as List?;
              if (headersList != null && headersList.isNotEmpty) {
                rawRows.add(headersList.map((c) => c?.toString() ?? '').toList());
              }
              final rowsList = (data['rows'] as List?) ?? (data['preview_rows'] as List?);
              if (rowsList != null && rowsList.isNotEmpty) {
                for (final r in rowsList) {
                  if (r is List) {
                    rawRows.add(r.map((c) => c?.toString() ?? '').toList());
                  }
                }
              }
            },
            onFailure: (_) {
              // Clear, actionable ERP message instead of raw HTTP 404
              parseError = 'Excel parsing service is unavailable. Please save your file as CSV format (.csv) and re-upload for instant client-side processing.';
            },
          );
        } catch (_) {
          parseError = 'Excel parsing service is unavailable. Please save your file as CSV format (.csv) and re-upload for instant client-side processing.';
        }
      }

      if (rawRows.isEmpty) {
        if (!mounted) return;
        state = state.copyWith(
          isValidating: false,
          errorMessage: parseError ?? 'Unable to parse spreadsheet. Ensure valid CSV file format.',
        );
        return;
      }

      if (rawRows.length < 2) {
        if (!mounted) return;
        state = state.copyWith(
          isValidating: false,
          errorMessage: 'Spreadsheet contains no data rows (header row + at least 1 record required).',
        );
        return;
      }

      // 2. Identify columns from header row
      final headers = rawRows[0];
      int colAdm = -1;
      int colName = -1;
      int colRoll = -1;
      int colClass = -1;
      int colSec = -1;
      int colDate = -1;
      int colSess = -1;
      int colStatus = -1;
      int colReason = -1;
      int colRemarks = -1;

      for (int i = 0; i < headers.length; i++) {
        final h = _normHeader(headers[i]);
        if (h == 'admission_number' || h == 'adm_no' || h == 'admission_no' || h == 'admission' || h == 'student_id') {
          colAdm = i;
        } else if (h == 'student_name' || h == 'name' || h == 'student' || h == 'full_name') {
          colName = i;
        } else if (h == 'roll_number' || h == 'roll_no' || h == 'roll') {
          colRoll = i;
        } else if (h == 'class_code' || h == 'class_name' || h == 'class' || h == 'grade') {
          colClass = i;
        } else if (h == 'section_code' || h == 'section_name' || h == 'section' || h == 'sec') {
          colSec = i;
        } else if (h == 'attendance_date' || h == 'date') {
          colDate = i;
        } else if (h == 'session_type' || h == 'session') {
          colSess = i;
        } else if (h == 'attendance_status' || h == 'status') {
          colStatus = i;
        } else if (h == 'attendance_reason' || h == 'reason') {
          colReason = i;
        } else if (h == 'remarks' || h == 'remark' || h == 'notes' || h == 'comment' || h == 'comments') {
          colRemarks = i;
        }
      }

      if (colAdm == -1) {
        if (!mounted) return;
        state = state.copyWith(
          isValidating: false,
          errorMessage: "Mandatory column 'Admission Number' not found in spreadsheet header.",
        );
        return;
      }
      if (colDate == -1) {
        if (!mounted) return;
        state = state.copyWith(
          isValidating: false,
          errorMessage: "Mandatory column 'Date' not found in spreadsheet header.",
        );
        return;
      }
      if (colStatus == -1) {
        if (!mounted) return;
        state = state.copyWith(
          isValidating: false,
          errorMessage: "Mandatory column 'Status' not found in spreadsheet header.",
        );
        return;
      }

      // 3. Load students for school to validate admission numbers via safe chunked pagination (limit <= 100)
      final List<_BulkStudentLookup> schoolStudents = [];
      const int studentPageSize = 100;
      int currentSkip = 0;
      bool hasMoreStudents = true;
      String? studentsError;

      while (hasMoreStudents) {
        final studentsRes = await _apiClient.get(
          '/students?school_id=$schoolId&skip=$currentSkip&limit=$studentPageSize',
          mapper: (json) {
            final payload = json as Map<String, dynamic>;
            final list = payload['data'] as List? ?? [];
            return list
                .whereType<Map>()
                .map((m) => _BulkStudentLookup.fromJson(Map<String, dynamic>.from(m)))
                .toList();
          },
        );

        studentsRes.when(
          onSuccess: (chunk) {
            schoolStudents.addAll(chunk);
            if (chunk.length < studentPageSize || schoolStudents.length >= 2000) {
              hasMoreStudents = false;
            } else {
              currentSkip += studentPageSize;
            }
          },
          onFailure: (failure) {
            hasMoreStudents = false;
            studentsError = failure.message;
          },
        );
      }

      if (studentsError != null && schoolStudents.isEmpty) {
        if (!mounted) return;
        state = state.copyWith(
          isValidating: false,
          errorMessage: 'Failed to retrieve school students for validation: $studentsError',
        );
        return;
      }

      final studentsByAdm = <String, _BulkStudentLookup>{};
      final studentsById = <String, _BulkStudentLookup>{};
      for (final s in schoolStudents) {
        final cleanAdm = s.admissionNumber.replaceAll('\uFEFF', '').replaceAll('"', '').replaceAll("'", '').trim();
        if (cleanAdm.isNotEmpty) {
          studentsByAdm[cleanAdm.toLowerCase()] = s;
        }
        final cleanId = s.id.replaceAll('"', '').replaceAll("'", '').trim();
        if (cleanId.isNotEmpty) {
          studentsById[cleanId.toLowerCase()] = s;
        }
      }

      // 4. Load classes and sections (auto-fetch if not already populated)
      var classesState = _ref.read(classesProvider(schoolId));
      if (classesState.classes.isEmpty && !classesState.isLoading) {
        await _ref.read(classesProvider(schoolId).notifier).fetchClasses();
        classesState = _ref.read(classesProvider(schoolId));
      }

      var sectionsState = _ref.read(sectionsProvider(schoolId));
      if (sectionsState.sections.isEmpty && !sectionsState.isLoading) {
        await _ref.read(sectionsProvider(schoolId).notifier).fetchSections();
        sectionsState = _ref.read(sectionsProvider(schoolId));
      }

      final classesById = {for (final c in classesState.classes) c.id: c};
      final classesByNameOrCode = <String, dynamic>{};
      for (final c in classesState.classes) {
        classesByNameOrCode[c.name.trim().toLowerCase()] = c;
        if (c.code.trim().isNotEmpty) {
          classesByNameOrCode[c.code.trim().toLowerCase()] = c;
        }
      }

      final sectionsById = {for (final s in sectionsState.sections) s.id: s};
      final sectionsByNameOrCode = <String, dynamic>{};
      for (final s in sectionsState.sections) {
        sectionsByNameOrCode['${s.classId}|${s.name.trim().toLowerCase()}'] = s;
        if (s.code.trim().isNotEmpty) {
          sectionsByNameOrCode['${s.classId}|${s.code.trim().toLowerCase()}'] = s;
        }
      }

      // 5. Query existing sessions to detect conflicts
      final existingSessionsRes = await _apiClient.get(
        '/attendances/sessions?school_id=$schoolId&limit=100',
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          final list = payload['data'] as List? ?? [];
          return list
              .whereType<Map>()
              .map((m) => AttendanceSessionDto.fromJson(Map<String, dynamic>.from(m)))
              .toList();
        },
      );
      final List<AttendanceSessionDto> existingSessions = [];
      existingSessionsRes.when(
        onSuccess: (list) => existingSessions.addAll(list),
        onFailure: (_) {},
      );

      final existingSessionMap = <String, AttendanceSessionDto>{};
      for (final s in existingSessions) {
        final key = '${s.classId}|${s.sectionId}|${s.attendanceDate}|${s.sessionType.toUpperCase()}';
        existingSessionMap[key] = s;
      }

      // 6. Validate each row
      final parsedRows = <ParsedBulkAttendanceRow>[];
      final previewRows = <BulkValidateRowPreviewDto>[];
      final List<String> summaryErrors = [];
      final Set<String> seenInFile = {};

      int validRowsCount = 0;
      int invalidRowsCount = 0;
      int duplicateRowsCount = 0;
      int conflictRowsCount = 0;

      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      const allowedStatuses = {
        'PRESENT',
        'ABSENT',
        'LATE',
        'HALF_DAY',
        'EXCUSED',
        'MEDICAL_LEAVE',
        'ON_LEAVE',
        'LEAVE'
      };

      for (int rIdx = 1; rIdx < rawRows.length; rIdx++) {
        final row = rawRows[rIdx];
        if (row.isEmpty || row.every((c) => c.trim().isEmpty)) continue;

        final rawAdm = colAdm >= 0 && colAdm < row.length ? row[colAdm].trim() : '';
        final rawName = colName >= 0 && colName < row.length ? row[colName].trim() : '';
        final rawRoll = colRoll >= 0 && colRoll < row.length ? row[colRoll].trim() : '';
        final rawClass = colClass >= 0 && colClass < row.length ? row[colClass].trim() : '';
        final rawSec = colSec >= 0 && colSec < row.length ? row[colSec].trim() : '';
        final rawDate = colDate >= 0 && colDate < row.length ? row[colDate].trim() : '';
        final rawSess = colSess >= 0 && colSess < row.length ? row[colSess].trim() : 'FULL_DAY';
        final rawStatus = colStatus >= 0 && colStatus < row.length ? row[colStatus].trim() : '';
        final rawReason = colReason >= 0 && colReason < row.length ? row[colReason].trim() : '';
        final rawRemarks = colRemarks >= 0 && colRemarks < row.length ? row[colRemarks].trim() : '';

        final rowErrors = <String>[];

        // A. Resolve student
        _BulkStudentLookup? student;
        final cleanAdm = rawAdm.replaceAll('\uFEFF', '').replaceAll('"', '').replaceAll("'", '').trim();
        if (cleanAdm.isEmpty) {
          rowErrors.add('Admission number is missing');
        } else {
          student = studentsByAdm[cleanAdm.toLowerCase()] ?? studentsById[cleanAdm.toLowerCase()];
          if (student == null) {
            rowErrors.add("Student with admission number '$cleanAdm' not found in this school campus");
          } else if (!student.isActive) {
            rowErrors.add("Student '$cleanAdm' is marked inactive");
          }
        }

        // B. Resolve class & section
        String? resolvedClassId = student?.classId;
        String? resolvedClassName = student?.className;
        String? resolvedSectionId = student?.sectionId;
        String? resolvedSectionName = student?.sectionName;

        if (student != null && rawClass.isNotEmpty) {
          final matchedClass = classesByNameOrCode[rawClass.toLowerCase()];
          if (matchedClass != null && matchedClass.id != student.classId) {
            rowErrors.add("Student belongs to class '${student.className ?? student.classId}', not '$rawClass'");
          } else if (matchedClass == null && rawClass.toLowerCase() != (student.className ?? '').toLowerCase()) {
            rowErrors.add("Class '$rawClass' not found or mismatch with student roster");
          }
        }

        if (student != null && rawSec.isNotEmpty) {
          final matchedSec = sectionsByNameOrCode['${student.classId}|${rawSec.toLowerCase()}'];
          if (matchedSec != null && matchedSec.id != student.sectionId) {
            rowErrors.add("Student belongs to section '${student.sectionName ?? student.sectionId}', not '$rawSec'");
          } else if (matchedSec == null && rawSec.toLowerCase() != (student.sectionName ?? '').toLowerCase()) {
            rowErrors.add("Section '$rawSec' not found or mismatch with student roster");
          }
        }

        if (resolvedClassId != null && resolvedClassName == null) {
          resolvedClassName = classesById[resolvedClassId]?.name;
        }
        if (resolvedSectionId != null && resolvedSectionName == null) {
          resolvedSectionName = sectionsById[resolvedSectionId]?.name;
        }

        // C. Validate Date
        String isoDate = '';
        if (rawDate.isEmpty) {
          rowErrors.add('Attendance date is missing');
        } else {
          DateTime? parsedDate;
          final datePart = rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
          for (final fmt in ['yyyy-MM-dd', 'dd-MM-yyyy', 'dd/MM/yyyy', 'yyyy/MM/dd']) {
            try {
              parsedDate = DateFormat(fmt).parseStrict(datePart);
              break;
            } catch (_) {}
          }
          if (parsedDate == null) {
            rowErrors.add("Invalid date format '$rawDate'. Expected YYYY-MM-DD or DD/MM/YYYY");
          } else {
            isoDate = DateFormat('yyyy-MM-dd').format(parsedDate);
            final checkDate = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
            if (checkDate.isAfter(todayDate)) {
              rowErrors.add("Attendance date '$rawDate' is in the future. Future attendance is prohibited");
            }
          }
        }

        // D. Validate Session
        String normSession = 'FULL_DAY';
        if (rawSess.isNotEmpty) {
          final sUpper = rawSess.toUpperCase().replaceAll(' ', '_');
          if (sUpper == 'MORNING' || sUpper == 'AFTERNOON' || sUpper == 'FULL_DAY') {
            normSession = sUpper;
          } else {
            rowErrors.add("Invalid session '$rawSess'. Allowed: MORNING, AFTERNOON, FULL_DAY");
          }
        }

        // E. Validate Status
        String normStatus = rawStatus.toUpperCase().replaceAll(' ', '_');
        if (normStatus.isEmpty) {
          rowErrors.add('Attendance status is missing');
        } else if (!allowedStatuses.contains(normStatus)) {
          rowErrors.add("Invalid status '$rawStatus'. Allowed: PRESENT, ABSENT, LATE, HALF_DAY, EXCUSED");
        } else {
          if (normStatus == 'MEDICAL_LEAVE' || normStatus == 'ON_LEAVE' || normStatus == 'LEAVE') {
            normStatus = 'EXCUSED';
          }
        }

        // F. Validate Reason
        String normReason = 'UNKNOWN';
        if (normStatus == 'PRESENT') {
          normReason = DropdownSafety.reasonUnknown;
        } else if (rawReason.isNotEmpty) {
          normReason = DropdownSafety.normalizeAttendanceReason(rawReason);
        }

        // G. Duplicate & Conflict Detection
        bool isDuplicate = false;
        bool isConflict = false;
        String? conflictStatus;
        String validationStatus = 'VALID';

        if (rowErrors.isNotEmpty) {
          validationStatus = 'INVALID';
          invalidRowsCount++;
          if (summaryErrors.length < 50) {
            summaryErrors.add('Row $rIdx: ${rowErrors.join("; ")}');
          }
        } else if (student != null && isoDate.isNotEmpty) {
          final fileKey = '${student.id}|$isoDate|$normSession';
          if (seenInFile.contains(fileKey)) {
            isDuplicate = true;
            validationStatus = 'DUPLICATE';
            duplicateRowsCount++;
            rowErrors.add('Duplicate record in file for same student, date, and session');
            if (summaryErrors.length < 50) {
              summaryErrors.add('Row $rIdx: Duplicate entry for admission number $rawAdm on $isoDate');
            }
          } else {
            seenInFile.add(fileKey);

            // Check if existing session in database for that class/section/date/session
            final sessionKey = '$resolvedClassId|$resolvedSectionId|$isoDate|$normSession';
            final existingSession = existingSessionMap[sessionKey];
            if (existingSession != null) {
              if (existingSession.status.toUpperCase() == 'LOCKED') {
                validationStatus = 'INVALID';
                invalidRowsCount++;
                rowErrors.add('Attendance session on $isoDate ($normSession) is locked');
              } else {
                isConflict = true;
                validationStatus = 'CONFLICT';
                conflictRowsCount++;
                conflictStatus = 'SESSION_EXISTS';
              }
            } else {
              validRowsCount++;
            }
          }
        }

        final studentFullName = (rawName.isNotEmpty && rawName != '-')
            ? rawName
            : (student != null ? '${student.firstName} ${student.lastName}'.trim() : '-');

        final parsedRow = ParsedBulkAttendanceRow(
          rowNumber: rIdx,
          studentId: student?.id,
          admissionNumber: cleanAdm.isNotEmpty ? cleanAdm : rawAdm,
          studentName: studentFullName,
          rollNumber: rawRoll.isNotEmpty ? rawRoll : student?.rollNumber,
          classId: resolvedClassId,
          className: resolvedClassName ?? rawClass,
          sectionId: resolvedSectionId,
          sectionName: resolvedSectionName ?? rawSec,
          attendanceDate: isoDate.isNotEmpty ? isoDate : rawDate,
          sessionType: normSession,
          attendanceStatus: normStatus,
          attendanceReason: normReason,
          remarks: rawRemarks.isNotEmpty ? rawRemarks : null,
          isValid: rowErrors.isEmpty,
          isDuplicate: isDuplicate,
          isConflict: isConflict,
          conflictExistingStatus: conflictStatus,
          errorMessage: rowErrors.isNotEmpty ? rowErrors.join('; ') : null,
        );

        parsedRows.add(parsedRow);

        if (previewRows.length < 50) {
          previewRows.add(BulkValidateRowPreviewDto(
            rowNumber: rIdx,
            admissionNumber: cleanAdm.isNotEmpty ? cleanAdm : (rawAdm.isNotEmpty ? rawAdm : '-'),
            studentName: studentFullName,
            className: resolvedClassName ?? rawClass,
            sectionName: resolvedSectionName ?? rawSec,
            attendanceDate: isoDate.isNotEmpty ? isoDate : rawDate,
            session: normSession,
            status: normStatus.isNotEmpty ? normStatus : '-',
            validationStatus: validationStatus,
            errorMessage: rowErrors.isNotEmpty ? rowErrors.join('; ') : null,
            conflictExistingStatus: conflictStatus,
          ));
        }
      }

      final validateDto = BulkAttendanceValidateDto(
        jobId: 'bulk_${DateTime.now().millisecondsSinceEpoch}',
        filename: state.selectedFileName ?? 'attendance.csv',
        totalRows: parsedRows.length,
        validRows: validRowsCount,
        invalidRows: invalidRowsCount,
        duplicateRows: duplicateRowsCount,
        conflictRows: conflictRowsCount,
        previewRows: previewRows,
        errors: summaryErrors,
      );

      if (!mounted) return;

      state = state.copyWith(
        isValidating: false,
        validateResult: validateDto,
        parsedRows: parsedRows,
        selectedAcademicYearId: academicYearId,
        currentStep: 2,
      );
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isValidating: false, errorMessage: 'Validation error: $e');
      }
    }
  }

  Future<void> executeImport({int chunkSize = 1000, bool retryFromFailed = false}) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null || state.validateResult == null) return;

    // Filter rows to import according to conflict strategy
    final rowsToImport = state.parsedRows.where((r) {
      if (!r.isValid || r.isDuplicate) return false;
      if (state.conflictStrategy == 'SKIP_EXISTING' && r.isConflict) return false;
      return r.studentId != null && r.classId != null && r.sectionId != null;
    }).toList();

    if (rowsToImport.isEmpty) {
      if (!mounted) return;
      state = state.copyWith(
        isImporting: false,
        errorMessage: 'No valid rows available to import under the selected conflict strategy.',
      );
      return;
    }

    final totalRows = rowsToImport.length;
    final totalBatches = (totalRows / chunkSize).ceil();
    final importId = state.importId ?? 'imp_${DateTime.now().millisecondsSinceEpoch}';

    final startIndex = retryFromFailed ? (state.lastFailedBatchIndex ?? 0) : 0;

    state = state.copyWith(
      isImporting: true,
      importId: importId,
      totalImportRows: totalRows,
      processedImportRows: startIndex == 0 ? 0 : state.processedImportRows,
      remainingImportRows: startIndex == 0 ? totalRows : (totalRows - state.processedImportRows),
      currentBatchIndex: startIndex + 1,
      totalBatches: totalBatches,
      importSuccessCount: startIndex == 0 ? 0 : state.importSuccessCount,
      importSkippedCount: startIndex == 0 ? 0 : state.importSkippedCount,
      importFailureCount: startIndex == 0 ? 0 : state.importFailureCount,
      clearError: true,
    );

    int runningSuccess = state.importSuccessCount;
    int runningSkipped = state.importSkippedCount;
    int runningFailed = state.importFailureCount;
    int runningProcessed = state.processedImportRows;
    final List<String> batchErrors = [];

    for (int b = startIndex; b < totalBatches; b++) {
      final chunkStart = b * chunkSize;
      final chunkEnd = ((b + 1) * chunkSize).clamp(0, totalRows);
      final chunkRows = rowsToImport.sublist(chunkStart, chunkEnd);
      final batchNum = b + 1;
      final idempotencyKey = '${importId}_batch_$batchNum';

      if (!mounted) return;
      state = state.copyWith(
        currentBatchIndex: batchNum,
        remainingImportRows: totalRows - runningProcessed,
      );

      final chunkPayload = {
        'import_id': importId,
        'school_id': schoolId,
        'academic_year_id': state.selectedAcademicYearId,
        'conflict_strategy': state.conflictStrategy,
        'batch_index': batchNum,
        'total_batches': totalBatches,
        'total_rows': totalRows,
        'idempotency_key': idempotencyKey,
        'filename': state.selectedFileName ?? 'attendance.csv',
        'records': chunkRows.map((r) => {
          'row_number': r.rowNumber,
          'student_id': r.studentId,
          'class_id': r.classId,
          'section_id': r.sectionId,
          'attendance_date': r.attendanceDate,
          'session_type': r.sessionType, // STRICTLY PRESERVE MORNING
          'attendance_status': r.attendanceStatus,
          'attendance_reason': r.attendanceReason,
          'remarks': r.remarks,
        }).toList(),
      };

      try {
        final chunkRes = await _apiClient.post(
          '/attendances/bulk/chunk?school_id=$schoolId',
          data: chunkPayload,
          options: Options(
            sendTimeout: const Duration(seconds: 60),
            receiveTimeout: const Duration(seconds: 60),
          ),
          mapper: (json) {
            if (json is! Map) return null;
            final data = json['data'];
            return data is Map ? Map<String, dynamic>.from(data) : null;
          },
        );

        bool batchSucceeded = false;
        chunkRes.when(
          onSuccess: (data) {
            batchSucceeded = true;
            if (data != null) {
              final imp = (data['imported_rows'] as num?)?.toInt() ?? 0;
              final skp = (data['skipped_rows'] as num?)?.toInt() ?? 0;
              final fail = (data['failed_rows'] as num?)?.toInt() ?? 0;

              runningSuccess += imp;
              runningSkipped += skp;
              runningFailed += fail;
              runningProcessed += chunkRows.length;

              final errs = data['errors'] as List?;
              if (errs != null) {
                batchErrors.addAll(errs.map((e) => e.toString()));
              }
            } else {
              runningSuccess += chunkRows.length;
              runningProcessed += chunkRows.length;
            }
          },
          onFailure: (failure) {
            batchErrors.add('Batch $batchNum failed: ${failure.message}');
          },
        );

        if (!batchSucceeded) {
          if (!mounted) return;
          state = state.copyWith(
            isImporting: false,
            lastFailedBatchIndex: b,
            errorMessage: 'Batch $batchNum of $totalBatches failed: ${batchErrors.isNotEmpty ? batchErrors.last : "Network or server error"}. Click "Retry Remaining Records" to safely resume without duplicates.',
            importSuccessCount: runningSuccess,
            importSkippedCount: runningSkipped,
            importFailureCount: runningFailed,
            processedImportRows: runningProcessed,
            remainingImportRows: totalRows - runningProcessed,
          );
          return;
        }

        if (!mounted) return;
        state = state.copyWith(
          processedImportRows: runningProcessed,
          remainingImportRows: totalRows - runningProcessed,
          importSuccessCount: runningSuccess,
          importSkippedCount: runningSkipped,
          importFailureCount: runningFailed,
        );
      } catch (e) {
        if (!mounted) return;
        state = state.copyWith(
          isImporting: false,
          lastFailedBatchIndex: b,
          errorMessage: 'Batch $batchNum request timed out or encountered network failure: $e. Click "Retry Remaining Records" to resume.',
          importSuccessCount: runningSuccess,
          importSkippedCount: runningSkipped,
          importFailureCount: runningFailed,
          processedImportRows: runningProcessed,
          remainingImportRows: totalRows - runningProcessed,
        );
        return;
      }
    }

    if (!mounted) return;

    // Record persistent audit log in backend
    try {
      final dateList = state.parsedRows.map((r) => r.attendanceDate).where((d) => d.isNotEmpty).toSet().toList()..sort();
      final dateRange = dateList.isEmpty ? null : (dateList.length == 1 ? dateList.first : '${dateList.first} to ${dateList.last}');

      await _apiClient.post(
        '/attendances/imports/record',
        data: {
          'school_id': schoolId,
          'filename': state.selectedFileName ?? 'attendance.csv',
          'total_rows': totalRows,
          'successful_rows': runningSuccess,
          'failed_rows': runningFailed,
          'skipped_rows': runningSkipped,
          'status': runningFailed == 0 ? 'COMPLETED' : (runningSuccess > 0 ? 'COMPLETED_WITH_ERRORS' : 'FAILED'),
          'date_range': dateRange,
          'error_summary': batchErrors.isNotEmpty ? batchErrors.take(10).join('; ') : null,
          'errors': [],
        },
        mapper: (json) => json,
      );
    } catch (_) {}

    final importResponse = BulkAttendanceImportResponseDto(
      jobId: importId,
      status: runningFailed == 0 ? 'COMPLETED' : (runningSuccess > 0 ? 'PARTIALLY_COMPLETED' : 'FAILED'),
      totalRows: totalRows,
      importedRows: runningSuccess,
      skippedRows: runningSkipped,
      failedRows: runningFailed,
      conflictRows: state.validateResult!.conflictRows,
      message: runningFailed == 0
          ? 'Successfully imported $runningSuccess records across $totalBatches batch(es).'
          : 'Imported $runningSuccess records with $runningFailed failed records across $totalBatches batch(es).',
    );

    state = state.copyWith(
      isImporting: false,
      importResult: importResponse,
      currentStep: 4,
      clearFailedBatch: true,
      errorMessage: batchErrors.isNotEmpty && runningSuccess == 0
          ? batchErrors.join('\n')
          : null,
    );
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

    final jobsMap = <String, AttendanceImportJobDto>{};

    // 1. Query canonical /import-jobs?school_id=...&import_type=ATTENDANCE
    final canonicalResult = await _apiClient.get(
      '/import-jobs?school_id=$schoolId&import_type=ATTENDANCE&limit=50',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List? ?? [];
        return list.map((e) => AttendanceImportJobDto.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      },
    );

    canonicalResult.when(
      onSuccess: (list) {
        for (final job in list) {
          jobsMap[job.id] = job;
        }
      },
      onFailure: (_) {},
    );

    // 2. Query /attendances/imports?school_id=...
    final fallbackResult = await _apiClient.get(
      '/attendances/imports?school_id=$schoolId&limit=50',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List? ?? [];
        return list.map((e) => AttendanceImportJobDto.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      },
    );

    fallbackResult.when(
      onSuccess: (list) {
        for (final job in list) {
          jobsMap[job.id] = job;
        }
      },
      onFailure: (_) {},
    );

    if (!mounted) return;

    final allJobs = jobsMap.values.toList()
      ..sort((a, b) {
        try {
          return DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt));
        } catch (_) {
          return b.createdAt.compareTo(a.createdAt);
        }
      });

    state = state.copyWith(
      jobs: allJobs,
      total: allJobs.length,
      isLoading: false,
    );
  }

  Future<void> downloadErrorsCsv(String jobId) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    try {
      // 1. Try canonical /import-jobs/$jobId/rows?status_filter=ERROR
      final rowResult = await _apiClient.get(
        '/import-jobs/$jobId/rows?status_filter=ERROR&limit=100',
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          return payload['data'] as List? ?? [];
        },
      );

      bool handled = false;
      await rowResult.when(
        onSuccess: (rows) async {
          if (rows.isNotEmpty) {
            final buffer = StringBuffer('Row Number,Status,Error Code,Error Message,Source Identifier\n');
            for (final r in rows) {
              final map = Map<String, dynamic>.from(r as Map);
              buffer.writeln('${map['row_number'] ?? ""},${map['status'] ?? ""},"${map['error_code'] ?? ""}","${map['error_message'] ?? ""}","${map['source_identifier'] ?? ""}"');
            }
            downloadCsvFile('attendance_import_errors_$jobId.csv', buffer.toString());
            handled = true;
          }
        },
        onFailure: (_) async {},
      );

      if (handled) return;

      // 2. Fallback to /attendances/imports/$jobId/errors
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
  final bool isUnsupportedVersion;
  final String? unsupportedMessage;

  const AttendanceAuditLogsState({
    this.logs = const [],
    this.total = 0,
    this.skip = 0,
    this.limit = 50,
    this.isLoading = false,
    this.error,
    this.isUnsupportedVersion = false,
    this.unsupportedMessage,
  });

  AttendanceAuditLogsState copyWith({
    List<AttendanceAuditLogDto>? logs,
    int? total,
    int? skip,
    int? limit,
    bool? isLoading,
    String? error,
    bool? isUnsupportedVersion,
    String? unsupportedMessage,
    bool clearError = false,
  }) {
    return AttendanceAuditLogsState(
      logs: logs ?? this.logs,
      total: total ?? this.total,
      skip: skip ?? this.skip,
      limit: limit ?? this.limit,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isUnsupportedVersion: isUnsupportedVersion ?? this.isUnsupportedVersion,
      unsupportedMessage: isUnsupportedVersion == true
          ? (unsupportedMessage ?? this.unsupportedMessage)
          : (clearError ? null : (unsupportedMessage ?? this.unsupportedMessage)),
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

    state = state.copyWith(
      isLoading: true,
      skip: skip,
      limit: limit,
      clearError: true,
      isUnsupportedVersion: false,
    );

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
          isUnsupportedVersion: false,
          unsupportedMessage: null,
        );
      },
      onFailure: (failure) {
        final isNotFound = failure.statusCode == 404 ||
            failure.message.toLowerCase().contains('not found') ||
            failure.message.toLowerCase().contains('404');
        if (isNotFound) {
          state = state.copyWith(
            logs: const [],
            total: 0,
            isLoading: false,
            isUnsupportedVersion: true,
            unsupportedMessage: 'Detailed audit history is not available in this production API version.',
            error: null,
          );
        } else {
          state = state.copyWith(
            isLoading: false,
            error: failure.message,
            isUnsupportedVersion: false,
          );
        }
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
