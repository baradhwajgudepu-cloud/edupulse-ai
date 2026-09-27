import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';

import '../../domain/entities/attendance_enums.dart';
import '../../domain/entities/attendance_session_entity.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../../data/datasource/attendance_remote_datasource.dart';
import '../../data/repositories/attendance_repository_impl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../dashboard/domain/entities/dashboard_data.dart';
import '../../../my_classes/domain/repositories/my_classes_repository.dart';
import '../../../my_classes/presentation/providers/my_classes_provider.dart';
import '../../../my_classes/domain/entities/student.dart';
import '../../../../core/providers/school_context_provider.dart';

// --- ADMIN IMPORTED SCENARIO ENUM ---
enum AdminAttendanceScenario {
  none,
  scenarioA, // Admin recorded FULL_DAY attendance (warning banner + block duplicate full-day submission)
  scenarioB, // Admin recorded FULL_DAY attendance, but this is Period Attendance (informational banner: allow period-specific attendance)
  scenarioC, // Attendance already submitted / locked
}

// --- ATTENDANCE STATE REPRESENTATION ---
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
  final AttendanceSessionEntity? session; // null if session has not been initiated on backend
  final AttendanceSessionEntity? dailySession; // any full-day session found for this class & date
  final List<StudentEntity> students;
  final Map<String, AttendanceStatus> studentStatuses;
  final Map<String, String> studentRemarks;
  final bool isSaving;
  final String query;
  final bool isDailyMode;
  final String? className;
  final String? sectionName;
  final AdminAttendanceScenario scenario;
  final String? scenarioBannerMessage;
  final bool canSubmit;

  const AttendanceSuccess({
    this.session,
    this.dailySession,
    required this.students,
    required this.studentStatuses,
    required this.studentRemarks,
    this.isSaving = false,
    this.query = '',
    this.isDailyMode = false,
    this.className,
    this.sectionName,
    this.scenario = AdminAttendanceScenario.none,
    this.scenarioBannerMessage,
    this.canSubmit = true,
  });

  List<StudentEntity> get filteredStudents {
    if (query.trim().isEmpty) return students;
    final lower = query.toLowerCase().trim();
    return students.where((s) {
      final nameMatches = s.fullName.toLowerCase().contains(lower);
      final rollMatches = s.rollNumber.toLowerCase().contains(lower);
      return nameMatches || rollMatches;
    }).toList();
  }

  int get totalCount => students.length;
  int get presentCount => studentStatuses.values.where((status) => status == AttendanceStatus.PRESENT).length;
  int get absentCount => studentStatuses.values.where((status) => status == AttendanceStatus.ABSENT).length;
  int get lateCount => studentStatuses.values.where((status) => status == AttendanceStatus.LATE).length;
  int get otherCount => studentStatuses.values.where((status) => 
      status != AttendanceStatus.PRESENT && 
      status != AttendanceStatus.ABSENT && 
      status != AttendanceStatus.LATE).length;

  AttendanceSuccess copyWith({
    AttendanceSessionEntity? Function()? session,
    AttendanceSessionEntity? Function()? dailySession,
    List<StudentEntity>? students,
    Map<String, AttendanceStatus>? studentStatuses,
    Map<String, String>? studentRemarks,
    bool? isSaving,
    String? query,
    bool? isDailyMode,
    String? className,
    String? sectionName,
    AdminAttendanceScenario? scenario,
    String? Function()? scenarioBannerMessage,
    bool? canSubmit,
  }) {
    return AttendanceSuccess(
      session: session != null ? session() : this.session,
      dailySession: dailySession != null ? dailySession() : this.dailySession,
      students: students ?? this.students,
      studentStatuses: studentStatuses ?? this.studentStatuses,
      studentRemarks: studentRemarks ?? this.studentRemarks,
      isSaving: isSaving ?? this.isSaving,
      query: query ?? this.query,
      isDailyMode: isDailyMode ?? this.isDailyMode,
      className: className ?? this.className,
      sectionName: sectionName ?? this.sectionName,
      scenario: scenario ?? this.scenario,
      scenarioBannerMessage: scenarioBannerMessage != null ? scenarioBannerMessage() : this.scenarioBannerMessage,
      canSubmit: canSubmit ?? this.canSubmit,
    );
  }
}

class AttendanceError extends AttendanceState {
  final String message;
  const AttendanceError(this.message);
}

// --- PROVIDER DEFINITIONS ---

final attendanceRemoteDatasourceProvider = Provider<AttendanceRemoteDatasource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AttendanceRemoteDatasource(apiClient);
});

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final remote = ref.watch(attendanceRemoteDatasourceProvider);
  return AttendanceRepositoryImpl(remote);
});

class AttendanceNotifier extends StateNotifier<AttendanceState> {
  final AttendanceRepository _repository;
  final MyClassesRepository _myClassesRepository;
  final Ref _ref;
  final String? _timetableId;
  final String? _classId;
  final String? _sectionId;
  final String _dateStr;
  final bool _isDailyMode;
  final String? _fallbackClassName;
  final String? _fallbackSectionName;

  AttendanceNotifier(
    this._repository,
    this._myClassesRepository,
    this._ref, {
    String? timetableId,
    String? classId,
    String? sectionId,
    required String dateStr,
    bool isDailyMode = false,
    String? fallbackClassName,
    String? fallbackSectionName,
  })  : _timetableId = timetableId,
        _classId = classId,
        _sectionId = sectionId,
        _dateStr = dateStr,
        _isDailyMode = isDailyMode,
        _fallbackClassName = fallbackClassName,
        _fallbackSectionName = fallbackSectionName,
        super(const AttendanceInitial());

  Future<void> fetchAttendance() async {
    state = const AttendanceLoading();

    final authState = _ref.read(authStateProvider);
    if (authState is! Authenticated) {
      state = const AttendanceError('User is not authenticated.');
      return;
    }

    final schoolId = _ref.read(activeSchoolIdProvider) ??
        (authState.user.schools.isNotEmpty ? authState.user.schools.first : null);
    if (schoolId == null) {
      state = const AttendanceError('No school associated with this account.');
      return;
    }

    final dashboardState = _ref.read(dashboardStateProvider);
    if (dashboardState is! DashboardSuccess && dashboardState is! DashboardRefreshing) {
      state = const AttendanceError('Dashboard must load first.');
      return;
    }

    final DashboardDataEntity dashboardData = dashboardState is DashboardSuccess
        ? dashboardState.data
        : (dashboardState as DashboardRefreshing).data;
    final academicYearId = dashboardData.academicYear.id;

    String classId;
    String sectionId;
    String className = _fallbackClassName ?? '';
    String sectionName = _fallbackSectionName ?? '';

    if (_isDailyMode) {
      classId = _classId ?? '';
      sectionId = _sectionId ?? '';

      // Try resolving class and section names from myClassesStateProvider
      final myClassesState = _ref.read(myClassesStateProvider);
      if (myClassesState is MyClassesSuccess) {
        for (final group in myClassesState.classes) {
          if (group.classId == classId && (sectionId.isEmpty || group.sectionId == sectionId)) {
            if (className.isEmpty) className = group.className;
            if (sectionName.isEmpty) sectionName = group.sectionName;
            break;
          }
        }
      }
    } else {
      final timetable = dashboardData.schedule.firstWhere(
        (entry) => entry.id == _timetableId,
        orElse: () => throw Exception('Timetable entry not found for ID: $_timetableId'),
      );
      classId = timetable.classId;
      sectionId = timetable.sectionId;
      className = timetable.className;
      sectionName = timetable.sectionName;
    }

    // 1. Load Student Roster
    final studentsResult = await _myClassesRepository.getClassStudents(
      schoolId: schoolId,
      academicYearId: academicYearId,
      classId: classId,
      sectionId: sectionId,
    );

    // Guard against race condition: discard response if active school changed in-flight
    final currentSchoolId = _ref.read(activeSchoolIdProvider) ??
        (authState.user.schools.isNotEmpty ? authState.user.schools.first : null);
    if (currentSchoolId != schoolId) {
      return;
    }

    List<StudentEntity> roster = [];
    String? rosterError;
    studentsResult.when(
      onSuccess: (data) => roster = data,
      onFailure: (err) => rosterError = err.message,
    );

    if (rosterError != null) {
      state = AttendanceError(rosterError!);
      return;
    }

    // 2. Fetch any existing FULL_DAY session (for daily mode or period mode info)
    final dailySessionResult = await _repository.getDailySession(
      schoolId: schoolId,
      classId: classId,
      sectionId: sectionId,
      attendanceDate: _dateStr,
      sessionType: 'FULL_DAY',
    );

    if ((_ref.read(activeSchoolIdProvider) ?? (authState.user.schools.isNotEmpty ? authState.user.schools.first : null)) != schoolId) {
      return;
    }

    AttendanceSessionEntity? existingDailySession;
    dailySessionResult.when(
      onSuccess: (s) => existingDailySession = s,
      onFailure: (_) => null,
    );

    if (_isDailyMode) {
      // MODE B: Daily Class Attendance
      if (existingDailySession != null) {
        final Map<String, AttendanceStatus> studentStatuses = {};
        final Map<String, String> studentRemarks = {};

        for (final s in roster) {
          studentStatuses[s.id] = AttendanceStatus.PRESENT;
        }
        for (final log in existingDailySession!.attendances) {
          studentStatuses[log.studentId] = log.attendanceStatus;
          if (log.remarks != null) {
            studentRemarks[log.studentId] = log.remarks!;
          }
        }

        final isSubmittedOrLocked = existingDailySession!.status == AttendanceSessionStatus.SUBMITTED ||
            existingDailySession!.status == AttendanceSessionStatus.LOCKED;

        final isMarkedByOther = existingDailySession!.markedBy != null &&
            existingDailySession!.markedBy != authState.user.id;

        AdminAttendanceScenario scenario;
        String? scenarioMsg;
        bool canSubmit;

        if (isSubmittedOrLocked) {
          if (isMarkedByOther || existingDailySession!.status == AttendanceSessionStatus.LOCKED) {
            // Scenario A: Admin recorded full-day attendance - block duplicate submission
            scenario = AdminAttendanceScenario.scenarioA;
            scenarioMsg = 'Full-day attendance has already been recorded by school administration for this date. Further submissions are disabled.';
            canSubmit = false;
          } else {
            // Scenario C: Already submitted by this teacher
            scenario = AdminAttendanceScenario.scenarioC;
            scenarioMsg = 'Attendance already submitted for this date.';
            canSubmit = false;
          }
        } else {
          scenario = AdminAttendanceScenario.none;
          canSubmit = true;
        }

        state = AttendanceSuccess(
          session: existingDailySession,
          dailySession: existingDailySession,
          students: roster,
          studentStatuses: studentStatuses,
          studentRemarks: studentRemarks,
          isDailyMode: true,
          className: className,
          sectionName: sectionName,
          scenario: scenario,
          scenarioBannerMessage: scenarioMsg,
          canSubmit: canSubmit,
        );
      } else {
        // Daily session does not exist yet: Default all students to PRESENT
        final Map<String, AttendanceStatus> studentStatuses = {};
        final Map<String, String> studentRemarks = {};
        for (final s in roster) {
          studentStatuses[s.id] = AttendanceStatus.PRESENT;
        }

        state = AttendanceSuccess(
          session: null,
          dailySession: null,
          students: roster,
          studentStatuses: studentStatuses,
          studentRemarks: studentRemarks,
          isDailyMode: true,
          className: className,
          sectionName: sectionName,
          scenario: AdminAttendanceScenario.none,
          canSubmit: true,
        );
      }
    } else {
      // MODE A: Period Attendance
      final sessionsResult = await _repository.getSessions(
        schoolId: schoolId,
        academicYearId: academicYearId,
        classId: classId,
        sectionId: sectionId,
        attendanceDate: _dateStr,
      );

      if ((_ref.read(activeSchoolIdProvider) ?? (authState.user.schools.isNotEmpty ? authState.user.schools.first : null)) != schoolId) {
        return;
      }

      sessionsResult.when(
        onSuccess: (sessions) async {
          final matching = sessions.firstWhere(
            (s) => s.timetableId == _timetableId,
            orElse: () => const AttendanceSessionEntity(
              id: '',
              tenantId: '',
              schoolId: '',
              academicYearId: '',
              timetableId: '',
              classId: '',
              sectionId: '',
              attendanceDate: '',
              status: AttendanceSessionStatus.DRAFT,
              attendances: [],
            ),
          );

          if (matching.id.isNotEmpty) {
            final detailsResult = await _repository.getSessionDetails(
              schoolId: schoolId,
              sessionId: matching.id,
            );

            detailsResult.when(
              onSuccess: (fullSession) {
                final Map<String, AttendanceStatus> studentStatuses = {};
                final Map<String, String> studentRemarks = {};

                for (final s in roster) {
                  studentStatuses[s.id] = AttendanceStatus.PRESENT;
                }
                for (final log in fullSession.attendances) {
                  studentStatuses[log.studentId] = log.attendanceStatus;
                  if (log.remarks != null) {
                    studentRemarks[log.studentId] = log.remarks!;
                  }
                }

                final isSubmittedOrLocked = fullSession.status == AttendanceSessionStatus.SUBMITTED ||
                    fullSession.status == AttendanceSessionStatus.LOCKED;

                AdminAttendanceScenario scenario;
                String? scenarioMsg;
                bool canSubmit;

                if (isSubmittedOrLocked) {
                  scenario = AdminAttendanceScenario.scenarioC;
                  scenarioMsg = 'Attendance already submitted for this period.';
                  canSubmit = false;
                } else if (existingDailySession != null) {
                  // Scenario B: Admin full day exists, but teacher takes period attendance
                  scenario = AdminAttendanceScenario.scenarioB;
                  scenarioMsg = 'Daily attendance recorded by administration. You may still record period-specific attendance for this timetable slot.';
                  canSubmit = true;
                } else {
                  scenario = AdminAttendanceScenario.none;
                  canSubmit = true;
                }

                state = AttendanceSuccess(
                  session: fullSession,
                  dailySession: existingDailySession,
                  students: roster,
                  studentStatuses: studentStatuses,
                  studentRemarks: studentRemarks,
                  isDailyMode: false,
                  className: className,
                  sectionName: sectionName,
                  scenario: scenario,
                  scenarioBannerMessage: scenarioMsg,
                  canSubmit: canSubmit,
                );
              },
              onFailure: (err) {
                state = AttendanceError(err.message);
              },
            );
          } else {
            // Period session does not exist yet
            final Map<String, AttendanceStatus> studentStatuses = {};
            final Map<String, String> studentRemarks = {};
            for (final s in roster) {
              studentStatuses[s.id] = AttendanceStatus.PRESENT;
            }

            AdminAttendanceScenario scenario = AdminAttendanceScenario.none;
            String? scenarioMsg;

            if (existingDailySession != null) {
              // Scenario B: Admin full day exists, but teacher takes period attendance
              scenario = AdminAttendanceScenario.scenarioB;
              scenarioMsg = 'Daily attendance recorded by administration. You may still record period-specific attendance for this timetable slot.';
            }

            state = AttendanceSuccess(
              session: null,
              dailySession: existingDailySession,
              students: roster,
              studentStatuses: studentStatuses,
              studentRemarks: studentRemarks,
              isDailyMode: false,
              className: className,
              sectionName: sectionName,
              scenario: scenario,
              scenarioBannerMessage: scenarioMsg,
              canSubmit: true,
            );
          }
        },
        onFailure: (err) {
          state = AttendanceError(err.message);
        },
      );
    }
  }

  void toggleStatus(String studentId) {
    final current = state;
    if (current is! AttendanceSuccess) return;

    final statuses = Map<String, AttendanceStatus>.from(current.studentStatuses);
    final prev = statuses[studentId] ?? AttendanceStatus.PRESENT;
    statuses[studentId] = prev == AttendanceStatus.PRESENT 
        ? AttendanceStatus.ABSENT 
        : AttendanceStatus.PRESENT;

    state = current.copyWith(studentStatuses: statuses);
  }

  void setStatus(String studentId, AttendanceStatus status, {String? remarks}) {
    final current = state;
    if (current is! AttendanceSuccess) return;

    final statuses = Map<String, AttendanceStatus>.from(current.studentStatuses);
    statuses[studentId] = status;

    final remarksMap = Map<String, String>.from(current.studentRemarks);
    if (remarks != null && remarks.isNotEmpty) {
      remarksMap[studentId] = remarks;
    } else {
      remarksMap.remove(studentId);
    }

    state = current.copyWith(
      studentStatuses: statuses,
      studentRemarks: remarksMap,
    );
  }

  void markAllPresent() {
    final current = state;
    if (current is! AttendanceSuccess) return;

    final Map<String, AttendanceStatus> statuses = {};
    for (final s in current.students) {
      statuses[s.id] = AttendanceStatus.PRESENT;
    }

    state = current.copyWith(
      studentStatuses: statuses,
      studentRemarks: {},
    );
  }

  void searchLocal(String query) {
    final current = state;
    if (current is! AttendanceSuccess) return;
    state = current.copyWith(query: query);
  }

  Future<void> submitAttendance() async {
    final current = state;
    if (current is! AttendanceSuccess) return;
    if (!current.canSubmit) return;

    state = current.copyWith(isSaving: true);

    final authState = _ref.read(authStateProvider);
    final schoolId = _ref.read(activeSchoolIdProvider) ??
        (authState is Authenticated && authState.user.schools.isNotEmpty 
            ? authState.user.schools.first 
            : null);

    if (schoolId == null) {
      state = const AttendanceError('Authentication mismatch.');
      return;
    }

    final dashboardState = _ref.read(dashboardStateProvider);
    final academicYearId = dashboardState is DashboardSuccess 
        ? dashboardState.data.academicYear.id 
        : (dashboardState as DashboardRefreshing).data.academicYear.id;

    if (_isDailyMode) {
      final records = current.students.map((student) {
        final status = current.studentStatuses[student.id] ?? AttendanceStatus.PRESENT;
        final remarks = current.studentRemarks[student.id];
        return AttendanceRecordPayload(
          studentId: student.id,
          attendanceStatus: status,
          remarks: remarks,
        );
      }).toList();

      final dailyResult = await _repository.markDailyAttendance(
        schoolId: schoolId,
        academicYearId: academicYearId,
        classId: _classId!,
        sectionId: _sectionId!,
        attendanceDate: _dateStr,
        sessionType: 'FULL_DAY',
        records: records,
      );

      await dailyResult.when(
        onSuccess: (sessionEntity) async {
          state = current.copyWith(
            session: () => sessionEntity,
            isSaving: false,
          );
          await fetchAttendance();
        },
        onFailure: (err) async {
          state = AttendanceError(err.message);
        },
      );
    } else {
      // Period Mode
      String sessionId = current.session?.id ?? '';

      if (sessionId.isEmpty) {
        final createResult = await _repository.createSession(
          schoolId: schoolId,
          academicYearId: academicYearId,
          timetableId: _timetableId!,
          attendanceDate: _dateStr,
        );

        bool createFailed = false;
        createResult.when(
          onSuccess: (sessionEntity) => sessionId = sessionEntity.id,
          onFailure: (err) {
            createFailed = true;
            _reconcileAndFetch(schoolId, academicYearId, err.message);
          },
        );

        if (createFailed || sessionId.isEmpty) return;
      }

      final List<AttendanceRecordPayload> records = [];
      for (final student in current.students) {
        final status = current.studentStatuses[student.id] ?? AttendanceStatus.PRESENT;
        final remarks = current.studentRemarks[student.id];
        records.add(
          AttendanceRecordPayload(
            studentId: student.id,
            attendanceStatus: status,
            remarks: remarks,
          ),
        );
      }

      final bulkResult = await _repository.bulkMarkAttendance(
        schoolId: schoolId,
        sessionId: sessionId,
        sessionStatus: AttendanceSessionStatus.SUBMITTED,
        records: records,
      );

      await bulkResult.when(
        onSuccess: (sessionEntity) async {
          state = current.copyWith(
            session: () => sessionEntity,
            isSaving: false,
          );
          await fetchAttendance();
        },
        onFailure: (err) async {
          await _reconcileAndFetch(schoolId, academicYearId, err.message);
        },
      );
    }
  }

  Future<void> correctStudentAttendance({
    required String studentId,
    required AttendanceStatus newStatus,
    required String correctionReason,
    String? remarks,
  }) async {
    final current = state;
    if (current is! AttendanceSuccess || current.session == null) return;

    state = current.copyWith(isSaving: true);

    final authState = _ref.read(authStateProvider);
    final schoolId = _ref.read(activeSchoolIdProvider) ??
        (authState is Authenticated && authState.user.schools.isNotEmpty 
            ? authState.user.schools.first 
            : null);

    if (schoolId == null) {
      state = const AttendanceError('Authentication mismatch.');
      return;
    }

    final result = await _repository.correctAttendance(
      schoolId: schoolId,
      sessionId: current.session!.id,
      studentId: studentId,
      attendanceStatus: newStatus,
      correctionReason: correctionReason,
      remarks: remarks,
    );

    await result.when(
      onSuccess: (_) async {
        await fetchAttendance();
      },
      onFailure: (err) {
        state = AttendanceError(err.message);
      },
    );
  }

  Future<void> _reconcileAndFetch(String schoolId, String academicYearId, String baseErrorMsg) async {
    if (_isDailyMode) {
      state = AttendanceError(baseErrorMsg);
      return;
    }

    final dashboardState = _ref.read(dashboardStateProvider);
    if (dashboardState is! DashboardSuccess && dashboardState is! DashboardRefreshing) {
      state = AttendanceError(baseErrorMsg);
      return;
    }
    final dashboardData = dashboardState is DashboardSuccess 
        ? dashboardState.data 
        : (dashboardState as DashboardRefreshing).data;
    final timetable = dashboardData.schedule.firstWhere(
      (entry) => entry.id == _timetableId,
      orElse: () => throw Exception('Timetable entry not found'),
    );

    final sessionsResult = await _repository.getSessions(
      schoolId: schoolId,
      academicYearId: academicYearId,
      classId: timetable.classId,
      sectionId: timetable.sectionId,
      attendanceDate: _dateStr,
    );

    sessionsResult.when(
      onSuccess: (sessions) async {
        final matching = sessions.firstWhere(
          (s) => s.timetableId == _timetableId,
          orElse: () => const AttendanceSessionEntity(
            id: '',
            tenantId: '',
            schoolId: '',
            academicYearId: '',
            timetableId: '',
            classId: '',
            sectionId: '',
            attendanceDate: '',
            status: AttendanceSessionStatus.DRAFT,
            attendances: [],
          ),
        );

        if (matching.id.isNotEmpty) {
          await fetchAttendance();
        } else {
          state = AttendanceError(baseErrorMsg);
        }
      },
      onFailure: (_) {
        state = AttendanceError(baseErrorMsg);
      },
    );
  }
}

final attendanceStateProvider = StateNotifierProvider.family<AttendanceNotifier, AttendanceState, String>((ref, arg) {
  final parts = arg.split(':');
  final repo = ref.watch(attendanceRepositoryProvider);
  final myClassesRepo = ref.watch(myClassesRepositoryProvider);

  if (parts.first == 'daily' && parts.length >= 4) {
    return AttendanceNotifier(
      repo,
      myClassesRepo,
      ref,
      classId: parts[1],
      sectionId: parts[2],
      dateStr: parts[3],
      isDailyMode: true,
    );
  } else if (parts.first == 'period' && parts.length >= 3) {
    return AttendanceNotifier(
      repo,
      myClassesRepo,
      ref,
      timetableId: parts[1],
      dateStr: parts[2],
      isDailyMode: false,
    );
  } else {
    final timetableId = parts[0];
    final dateStr = parts.length > 1 ? parts[1] : '';
    return AttendanceNotifier(
      repo,
      myClassesRepo,
      ref,
      timetableId: timetableId,
      dateStr: dateStr,
      isDailyMode: false,
    );
  }
});
