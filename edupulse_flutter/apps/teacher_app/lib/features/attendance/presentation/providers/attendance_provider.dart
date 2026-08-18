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
  final List<StudentEntity> students;
  final Map<String, AttendanceStatus> studentStatuses;
  final Map<String, String> studentRemarks;
  final bool isSaving;
  final String query;

  const AttendanceSuccess({
    this.session,
    required this.students,
    required this.studentStatuses,
    required this.studentRemarks,
    this.isSaving = false,
    this.query = '',
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
    List<StudentEntity>? students,
    Map<String, AttendanceStatus>? studentStatuses,
    Map<String, String>? studentRemarks,
    bool? isSaving,
    String? query,
  }) {
    return AttendanceSuccess(
      session: session != null ? session() : this.session,
      students: students ?? this.students,
      studentStatuses: studentStatuses ?? this.studentStatuses,
      studentRemarks: studentRemarks ?? this.studentRemarks,
      isSaving: isSaving ?? this.isSaving,
      query: query ?? this.query,
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
  final String _timetableId;
  final String _dateStr;

  AttendanceNotifier(
    this._repository,
    this._myClassesRepository,
    this._ref,
    this._timetableId,
    this._dateStr,
  ) : super(const AttendanceInitial());

  Future<void> fetchAttendance() async {
    state = const AttendanceLoading();

    final authState = _ref.read(authStateProvider);
    if (authState is! Authenticated) {
      state = const AttendanceError('User is not authenticated.');
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

    final schoolId = authState.user.schools.isNotEmpty ? authState.user.schools.first : null;
    if (schoolId == null) {
      state = const AttendanceError('No school associated with this account.');
      return;
    }

    // Determine timetable details
    final timetable = dashboardData.schedule.firstWhere(
      (entry) => entry.id == _timetableId,
      orElse: () => throw Exception('Timetable entry not found'),
    );

    final classId = timetable.classId;
    final sectionId = timetable.sectionId;
    final academicYearId = dashboardData.academicYear.id;

    // Load Student Roster
    final studentsResult = await _myClassesRepository.getClassStudents(
      schoolId: schoolId,
      academicYearId: academicYearId,
      classId: classId,
      sectionId: sectionId,
    );

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

    // Query active attendance sessions
    final sessionsResult = await _repository.getSessions(
      schoolId: schoolId,
      academicYearId: academicYearId,
      classId: classId,
      sectionId: sectionId,
      attendanceDate: _dateStr,
    );

    sessionsResult.when(
      onSuccess: (sessions) async {
        // Filter session matching the specific timetable ID
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
          // Fetch full details of the existing session
          final detailsResult = await _repository.getSessionDetails(
            schoolId: schoolId,
            sessionId: matching.id,
          );

          detailsResult.when(
            onSuccess: (fullSession) {
              final Map<String, AttendanceStatus> studentStatuses = {};
              final Map<String, String> studentRemarks = {};

              // Initialize roster to PRESENT first
              for (final s in roster) {
                studentStatuses[s.id] = AttendanceStatus.PRESENT;
              }

              // Overwrite with existing backend logs
              for (final log in fullSession.attendances) {
                studentStatuses[log.studentId] = log.attendanceStatus;
                if (log.remarks != null) {
                  studentRemarks[log.studentId] = log.remarks!;
                }
              }

              state = AttendanceSuccess(
                session: fullSession,
                students: roster,
                studentStatuses: studentStatuses,
                studentRemarks: studentRemarks,
              );
            },
            onFailure: (err) {
              state = AttendanceError(err.message);
            },
          );
        } else {
          // Session does not exist yet: Default all students to PRESENT
          final Map<String, AttendanceStatus> studentStatuses = {};
          final Map<String, String> studentRemarks = {};

          for (final s in roster) {
            studentStatuses[s.id] = AttendanceStatus.PRESENT;
          }

          state = AttendanceSuccess(
            session: null,
            students: roster,
            studentStatuses: studentStatuses,
            studentRemarks: studentRemarks,
          );
        }
      },
      onFailure: (err) {
        state = AttendanceError(err.message);
      },
    );
  }

  void toggleStatus(String studentId) {
    final current = state;
    if (current is! AttendanceSuccess) return;

    // Direct toggle Presentation -> Absence exception
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

    state = current.copyWith(isSaving: true);

    final authState = _ref.read(authStateProvider);
    final schoolId = authState is Authenticated && authState.user.schools.isNotEmpty 
        ? authState.user.schools.first 
        : null;

    if (schoolId == null) {
      state = const AttendanceError('Authentication mismatch.');
      return;
    }

    final dashboardState = _ref.read(dashboardStateProvider);
    final academicYearId = dashboardState is DashboardSuccess 
        ? dashboardState.data.academicYear.id 
        : (dashboardState as DashboardRefreshing).data.academicYear.id;

    // Step 1: Ensure Session exists on backend
    String sessionId = current.session?.id ?? '';

    if (sessionId.isEmpty) {
      final createResult = await _repository.createSession(
        schoolId: schoolId,
        academicYearId: academicYearId,
        timetableId: _timetableId,
        attendanceDate: _dateStr,
      );

      bool createFailed = false;
      createResult.when(
        onSuccess: (sessionEntity) => sessionId = sessionEntity.id,
        onFailure: (err) {
          createFailed = true;
          // Reconciliation: Check if session actually created despite error
          _reconcileAndFetch(schoolId, academicYearId, err.message);
        },
      );

      if (createFailed || sessionId.isEmpty) return;
    }

    // Step 2: Formulate records and send bulk update
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
        // Refresh details
        await fetchAttendance();
      },
      onFailure: (err) async {
        // Reconciliation check: do not auto resubmit
        await _reconcileAndFetch(schoolId, academicYearId, err.message);
      },
    );
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
    final schoolId = authState is Authenticated && authState.user.schools.isNotEmpty 
        ? authState.user.schools.first 
        : null;

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

  // Help reconcile state after network interruption or database errors
  Future<void> _reconcileAndFetch(String schoolId, String academicYearId, String baseErrorMsg) async {
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
          // Reconciled successfully - fetch state from matching session
          await fetchAttendance();
        } else {
          // Reconcile failed to find any session, propagate original error
          state = AttendanceError(baseErrorMsg);
        }
      },
      onFailure: (_) {
        // Propagation
        state = AttendanceError(baseErrorMsg);
      },
    );
  }
}

final attendanceStateProvider = StateNotifierProvider.family<AttendanceNotifier, AttendanceState, String>((ref, arg) {
  final parts = arg.split(':');
  final timetableId = parts[0];
  final dateStr = parts[1];
  
  final repo = ref.watch(attendanceRepositoryProvider);
  final myClassesRepo = ref.watch(myClassesRepositoryProvider);
  return AttendanceNotifier(repo, myClassesRepo, ref, timetableId, dateStr);
});
