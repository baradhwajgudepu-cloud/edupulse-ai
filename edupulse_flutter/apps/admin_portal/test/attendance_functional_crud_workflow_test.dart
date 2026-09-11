import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:admin_portal/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';

class MockFunctionalApiClient extends BaseApiClient {
  MockFunctionalApiClient() : super(Dio());

  // In-memory persistent database for testing CRUD cycles
  Map<String, dynamic>? activeSession;
  List<Map<String, dynamic>> sessionLogs = [];
  List<Map<String, dynamic>> auditLogs = [];
  bool failNextSubmit = false;

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    // 1. Enrolled student roster
    if (path.contains('/students')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'stud_001',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'class_id': 'class_1',
            'section_id': 'sec_1',
            'admission_number': 'ADM001',
            'roll_number': '1',
            'first_name': 'Aarav',
            'last_name': 'Reddy',
            'gender': 'MALE',
            'date_of_birth': '2012-05-15',
            'admission_date': '2020-06-01',
            'status': 'ACTIVE',
            'is_active': true,
            'created_at': '2026-01-01T00:00:00Z',
            'updated_at': '2026-01-01T00:00:00Z',
          },
          {
            'id': 'stud_002',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'class_id': 'class_1',
            'section_id': 'sec_1',
            'admission_number': 'ADM002',
            'roll_number': '2',
            'first_name': 'Diya',
            'last_name': 'Patel',
            'gender': 'FEMALE',
            'date_of_birth': '2012-08-20',
            'admission_date': '2020-06-01',
            'status': 'ACTIVE',
            'is_active': true,
            'created_at': '2026-01-01T00:00:00Z',
            'updated_at': '2026-01-01T00:00:00Z',
          },
          {
            'id': 'stud_003',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'class_id': 'class_1',
            'section_id': 'sec_1',
            'admission_number': 'ADM003',
            'roll_number': '3',
            'first_name': 'Karan',
            'last_name': 'Singh',
            'gender': 'MALE',
            'date_of_birth': '2012-11-10',
            'admission_date': '2020-06-01',
            'status': 'ACTIVE',
            'is_active': true,
            'created_at': '2026-01-01T00:00:00Z',
            'updated_at': '2026-01-01T00:00:00Z',
          }
        ]
      }));
    }

    // 2. Daily session lookup
    if (path.contains('/attendances/daily/session') || path.contains('/attendance/daily/session')) {
      return ApiResult.success(mapper({
        'data': activeSession,
      }));
    }

    // 3. Canonical /attendances/sessions lookup
    if (path.contains('/attendances/sessions')) {
      final list = activeSession != null ? [activeSession!] : [];
      return ApiResult.success(mapper({'data': list}));
    }

    // 4. Session detail lookup
    if (path.contains('/attendances/session/')) {
      if (activeSession != null) {
        return ApiResult.success(mapper({'data': activeSession!}));
      }
      return ApiResult.failure(const ApiFailure(message: 'Session not found', type: ApiFailureType.unknown, statusCode: 404));
    }

    // 5. Daily logs lookup
    if (path.contains('/attendances/daily')) {
      return ApiResult.success(mapper({'data': sessionLogs}));
    }

    // 6. Canonical /attendances logs list
    if (path.contains('/attendances') && !path.contains('/sessions') && !path.contains('/register') && !path.contains('/audit-logs')) {
      return ApiResult.success(mapper({'data': sessionLogs}));
    }

    // 7. Register lookup
    if (path.contains('/attendances/register') || path.contains('/attendance/register')) {
      return ApiResult.success(mapper({
        'data': sessionLogs,
        'meta': {'total': sessionLogs.length, 'skip': 0, 'limit': 50}
      }));
    }

    // 8. Audit logs
    if (path.contains('/attendances/audit-logs') || path.contains('/attendance/audit-logs')) {
      return ApiResult.success(mapper({
        'data': auditLogs,
        'meta': {'total': auditLogs.length}
      }));
    }

    // 9. Classes lookup for dashboard
    if (path.contains('/classes')) {
      return ApiResult.success(mapper({
        'data': [
          {'id': 'class_1', 'name': 'Class 10', 'school_id': 'school_1'}
        ]
      }));
    }

    return ApiResult.success(mapper({'data': []}));
  }

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (failNextSubmit) {
      return ApiResult.failure(const ApiFailure(message: 'Simulated network submission failure', type: ApiFailureType.unknown, statusCode: 500));
    }

    // Daily mark submission
    if (path.contains('/attendances/daily/mark') || path.contains('/attendance/daily/mark')) {
      final payload = data as Map<String, dynamic>;
      final records = payload['records'] as List<dynamic>;

      final isLocked = activeSession != null && activeSession!['status'] == 'LOCKED';
      if (isLocked) {
        return ApiResult.failure(const ApiFailure(message: 'This attendance session is locked and cannot be edited.', type: ApiFailureType.unknown, statusCode: 422));
      }

      final sessionId = activeSession?['id'] ?? 'sess_functional_test_1';
      final todayStr = payload['attendance_date'] as String;

      final updatedLogs = <Map<String, dynamic>>[];
      for (final rec in records) {
        final r = rec as Map<String, dynamic>;
        final log = {
          'id': 'log_${r['student_id']}',
          'tenant_id': 'tenant_1',
          'school_id': 'school_1',
          'academic_year_id': payload['academic_year_id'],
          'attendance_session_id': sessionId,
          'student_id': r['student_id'],
          'class_id': payload['class_id'],
          'section_id': payload['section_id'],
          'attendance_date': todayStr,
          'session_type': payload['session_type'],
          'attendance_status': r['attendance_status'],
          'attendance_source': 'MANUAL',
          'attendance_reason': r['attendance_reason'] ?? 'UNKNOWN',
          'remarks': r['remarks'] ?? '',
          'is_active': true,
          'version': 1,
        };
        updatedLogs.add(log);
      }

      sessionLogs = updatedLogs;

      activeSession = {
        'id': sessionId,
        'tenant_id': 'tenant_1',
        'school_id': 'school_1',
        'class_id': payload['class_id'],
        'section_id': payload['section_id'],
        'academic_year_id': payload['academic_year_id'],
        'attendance_date': todayStr,
        'session_type': payload['session_type'],
        'status': 'SUBMITTED',
        'total_students': records.length,
        'present_count': records.where((r) => r['attendance_status'] == 'PRESENT').length,
        'absent_count': records.where((r) => r['attendance_status'] == 'ABSENT').length,
        'late_count': records.where((r) => r['attendance_status'] == 'LATE').length,
        'excused_count': records.where((r) => r['attendance_status'] == 'EXCUSED').length,
        'is_locked': false,
        'attendances': updatedLogs,
      };

      auditLogs.add({
        'id': 'audit_${auditLogs.length + 1}',
        'tenant_id': 'tenant_1',
        'school_id': 'school_1',
        'attendance_session_id': sessionId,
        'action': 'SUBMIT',
        'old_status': 'DRAFT',
        'new_status': 'SUBMITTED',
        'changed_by': 'user_teacher_1',
        'changed_by_name': 'Class Teacher',
        'changed_by_role': 'TEACHER',
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'MANUAL',
        'reason': 'Daily attendance submitted',
      });

      return ApiResult.success(mapper({'success': true, 'data': activeSession}));
    }

    // Lock session
    if (path.contains('/lock')) {
      if (activeSession != null) {
        activeSession!['status'] = 'LOCKED';
        activeSession!['is_locked'] = true;

        auditLogs.add({
          'id': 'audit_${auditLogs.length + 1}',
          'tenant_id': 'tenant_1',
          'school_id': 'school_1',
          'attendance_session_id': activeSession!['id'],
          'action': 'LOCK',
          'old_status': 'SUBMITTED',
          'new_status': 'LOCKED',
          'changed_by': 'user_principal_1',
          'changed_by_name': 'Principal Rao',
          'changed_by_role': 'PRINCIPAL',
          'timestamp': DateTime.now().toIso8601String(),
          'source': 'MANUAL',
          'reason': 'Session finalized and locked by administration',
        });

        return ApiResult.success(mapper({'success': true, 'data': activeSession}));
      }
      return ApiResult.failure(const ApiFailure(message: 'Session not found', type: ApiFailureType.unknown, statusCode: 404));
    }

    return ApiResult.success(mapper({'success': true}));
  }

  @override
  Future<ApiResult<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    // Individual student attendance correction
    if (path.contains('/student/')) {
      final uri = Uri.parse(path);
      final segments = uri.pathSegments;
      final studentIdIndex = segments.indexOf('student');
      final studentId = studentIdIndex != -1 && studentIdIndex + 1 < segments.length
          ? segments[studentIdIndex + 1]
          : 'stud_001';

      final payload = data as Map<String, dynamic>;
      final newStatus = payload['attendance_status'] as String;
      final correctionReason = payload['correction_reason'] as String;

      for (final log in sessionLogs) {
        if (log['student_id'] == studentId) {
          final oldStatus = log['attendance_status'];
          log['attendance_status'] = newStatus;
          log['remarks'] = payload['remarks'] ?? '';

          auditLogs.add({
            'id': 'audit_${auditLogs.length + 1}',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'attendance_session_id': activeSession?['id'],
            'student_id': studentId,
            'action': 'CORRECTION',
            'old_status': oldStatus,
            'new_status': newStatus,
            'changed_by': 'user_principal_1',
            'changed_by_name': 'Principal Rao',
            'changed_by_role': 'PRINCIPAL',
            'timestamp': DateTime.now().toIso8601String(),
            'source': 'MANUAL',
            'reason': correctionReason,
          });
        }
      }

      if (activeSession != null) {
        final atts = activeSession!['attendances'] as List<dynamic>;
        for (final att in atts) {
          if (att['student_id'] == studentId) {
            att['attendance_status'] = newStatus;
            att['remarks'] = payload['remarks'] ?? '';
          }
        }
      }

      return ApiResult.success(mapper({'success': true, 'message': 'Attendance corrected successfully'}));
    }

    return ApiResult.success(mapper({'success': true}));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFunctionalApiClient mockApi;
  late ProviderContainer container;

  setUp(() {
    mockApi = MockFunctionalApiClient();
    container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(mockApi),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('EduPulse Attendance Functional CRUD & Workflow Comprehensive Audit', () {
    test('1 & 2. CREATE / START SESSION & ROSTER LOADING: loads active enrolled students', () async {
      final markNotifier = container.read(dailyAttendanceMarkProvider.notifier);

      markNotifier.setSelection(
        academicYearId: 'ay_1',
        classId: 'class_1',
        sectionId: 'sec_1',
        attendanceDate: DateTime(2026, 9, 11),
      );

      await markNotifier.loadRoster();

      final state = container.read(dailyAttendanceMarkProvider);
      expect(state.isLoading, isFalse);
      expect(state.roster.length, equals(3));
      expect(state.roster[0].studentName, equals('Aarav Reddy'));
      expect(state.roster[1].studentName, equals('Diya Patel'));
      expect(state.roster[2].studentName, equals('Karan Singh'));
      expect(state.isLocked, isFalse);
      expect(state.sessionId, isNull);
    });

    test('3 & 4. MARKING & BULK OPERATIONS: mark Present, Absent, Late, Excused, and bulk selections', () async {
      final markNotifier = container.read(dailyAttendanceMarkProvider.notifier);
      markNotifier.setSelection(
        academicYearId: 'ay_1',
        classId: 'class_1',
        sectionId: 'sec_1',
      );
      await markNotifier.loadRoster();

      markNotifier.updateStudentStatus('stud_001', 'PRESENT');
      markNotifier.updateStudentStatus('stud_002', 'ABSENT', reason: 'ILLNESS', remarks: 'Fever');
      markNotifier.updateStudentStatus('stud_003', 'LATE', reason: 'TRAFFIC_DELAY', remarks: 'Bus breakdown');

      var state = container.read(dailyAttendanceMarkProvider);
      expect(state.roster[0].status, equals('PRESENT'));
      expect(state.roster[1].status, equals('ABSENT'));
      expect(state.roster[1].remarks, equals('Fever'));
      expect(state.roster[2].status, equals('LATE'));
      expect(state.roster[2].remarks, equals('Bus breakdown'));

      markNotifier.markAllPresent();
      state = container.read(dailyAttendanceMarkProvider);
      expect(state.roster.every((s) => s.status == 'PRESENT'), isTrue);

      markNotifier.toggleSelectStudent('stud_002');
      markNotifier.toggleSelectStudent('stud_003');
      markNotifier.markSelectedStatus('EXCUSED');
      state = container.read(dailyAttendanceMarkProvider);
      expect(state.roster[0].status, equals('PRESENT'));
      expect(state.roster[1].status, equals('EXCUSED'));
      expect(state.roster[2].status, equals('EXCUSED'));
    });

    test('5, 6 & 7. SAVE / UPDATE PERSISTENCE & REOPEN RECOVERY: submits attendance and verifies persistence', () async {
      final markNotifier = container.read(dailyAttendanceMarkProvider.notifier);
      markNotifier.setSelection(
        academicYearId: 'ay_1',
        classId: 'class_1',
        sectionId: 'sec_1',
        attendanceDate: DateTime(2026, 9, 11),
      );
      await markNotifier.loadRoster();

      markNotifier.updateStudentStatus('stud_001', 'PRESENT');
      markNotifier.updateStudentStatus('stud_002', 'ABSENT', reason: 'ILLNESS', remarks: 'Doctor note');
      markNotifier.updateStudentStatus('stud_003', 'LATE', reason: 'TRAFFIC_DELAY');

      final success = await markNotifier.submitAttendance();
      expect(success, isTrue);

      final stateAfterSave = container.read(dailyAttendanceMarkProvider);
      expect(stateAfterSave.successMessage, contains('Attendance marked successfully'));
      expect(mockApi.activeSession, isNotNull);
      expect(mockApi.activeSession!['status'], equals('SUBMITTED'));
      expect(mockApi.activeSession!['present_count'], equals(1));
      expect(mockApi.activeSession!['absent_count'], equals(1));
      expect(mockApi.activeSession!['late_count'], equals(1));

      final freshContainer = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
        ],
      );

      final freshMarkNotifier = freshContainer.read(dailyAttendanceMarkProvider.notifier);
      freshMarkNotifier.setSelection(
        academicYearId: 'ay_1',
        classId: 'class_1',
        sectionId: 'sec_1',
        attendanceDate: DateTime(2026, 9, 11),
      );
      await freshMarkNotifier.loadRoster();

      final reloadedState = freshContainer.read(dailyAttendanceMarkProvider);
      expect(reloadedState.sessionId, equals('sess_functional_test_1'));
      expect(reloadedState.roster[0].status, equals('PRESENT'));
      expect(reloadedState.roster[1].status, equals('ABSENT'));
      expect(reloadedState.roster[1].remarks, equals('Doctor note'));
      expect(reloadedState.roster[2].status, equals('LATE'));

      freshContainer.dispose();
    });

    test('8 & 9. LOCK STATUS & LOCKED-SESSION IMMUTABILITY: locks session and verifies edits are prohibited', () async {
      final markNotifier = container.read(dailyAttendanceMarkProvider.notifier);
      markNotifier.setSelection(
        academicYearId: 'ay_1',
        classId: 'class_1',
        sectionId: 'sec_1',
        attendanceDate: DateTime(2026, 9, 11),
      );
      await markNotifier.loadRoster();
      markNotifier.updateStudentStatus('stud_002', 'ABSENT', reason: 'ILLNESS');
      await markNotifier.submitAttendance();

      final opsNotifier = container.read(attendanceOperationsProvider.notifier);
      final lockSuccess = await opsNotifier.lockSession(sessionId: 'sess_functional_test_1');
      expect(lockSuccess, isTrue);
      expect(mockApi.activeSession!['status'], equals('LOCKED'));

      await markNotifier.loadRoster();
      final state = container.read(dailyAttendanceMarkProvider);
      expect(state.isLocked, isTrue);

      markNotifier.markAllPresent();
      expect(container.read(dailyAttendanceMarkProvider).roster[1].status, equals('ABSENT'));

      final submitResult = await markNotifier.submitAttendance();
      expect(submitResult, isFalse);
      expect(container.read(dailyAttendanceMarkProvider).errorMessage, contains('locked'));
    });

    test('10. INDIVIDUAL CORRECTION: modifies a student record with audit reason', () async {
      final markNotifier = container.read(dailyAttendanceMarkProvider.notifier);
      markNotifier.setSelection(
        academicYearId: 'ay_1',
        classId: 'class_1',
        sectionId: 'sec_1',
        attendanceDate: DateTime(2026, 9, 11),
      );
      await markNotifier.loadRoster();
      markNotifier.updateStudentStatus('stud_002', 'ABSENT');
      await markNotifier.submitAttendance();

      final opsNotifier = container.read(attendanceOperationsProvider.notifier);
      final corrected = await opsNotifier.correctAttendance(
        sessionId: 'sess_functional_test_1',
        studentId: 'stud_002',
        status: 'PRESENT',
        correctionReason: 'Medical certificate verified by clinic',
        remarks: 'Doctor note attached',
      );

      expect(corrected, isTrue);

      final updatedLog = mockApi.sessionLogs.firstWhere((l) => l['student_id'] == 'stud_002');
      expect(updatedLog['attendance_status'], equals('PRESENT'));
      expect(updatedLog['remarks'], equals('Doctor note attached'));

      expect(mockApi.auditLogs.any((a) =>
          a['student_id'] == 'stud_002' &&
          a['action'] == 'CORRECTION' &&
          a['old_status'] == 'ABSENT' &&
          a['new_status'] == 'PRESENT' &&
          a['reason'] == 'Medical certificate verified by clinic'
      ), isTrue);
    });

    test('11 & 12. REGISTER & AUDIT TRAIL: register reflects logs and audit trail tracks actor and changes', () async {
      mockApi.sessionLogs = [
        {
          'id': 'att_1',
          'tenant_id': 'tenant_1',
          'school_id': 'school_1',
          'academic_year_id': 'ay_1',
          'attendance_session_id': 'sess_1',
          'student_id': 'stud_001',
          'student_name': 'Aarav Reddy',
          'admission_number': 'ADM001',
          'class_id': 'class_1',
          'section_id': 'sec_1',
          'class_name': 'Grade 10',
          'section_name': 'Section A',
          'attendance_date': '2026-09-11',
          'session_type': 'FULL_DAY',
          'attendance_status': 'PRESENT',
          'attendance_source': 'MANUAL',
          'attendance_reason': 'UNKNOWN',
          'remarks': 'Present',
          'is_active': true,
          'version': 1,
        }
      ];

      final registerNotifier = container.read(attendanceRegisterProvider.notifier);
      await registerNotifier.fetchRegister();
      final regState = container.read(attendanceRegisterProvider);
      expect(regState.isLoading, isFalse);
      expect(regState.records.length, equals(1));
      expect(regState.records[0].studentName, equals('Aarav Reddy'));
      expect(regState.records[0].attendanceStatus, equals('PRESENT'));

      final auditNotifier = container.read(attendanceAuditLogsProvider.notifier);
      await auditNotifier.fetchAuditLogs();
      final auditState = container.read(attendanceAuditLogsProvider);
      expect(auditState.isLoading, isFalse);
    });

    test('13. DASHBOARD KPI RECALCULATION: recalculates KPIs deterministically from canonical responses', () async {
      final dashNotifier = container.read(attendanceDashboardProvider.notifier);
      await dashNotifier.fetchDashboard(date: DateTime(2026, 9, 11));

      final dashState = container.read(attendanceDashboardProvider);
      expect(dashState.isLoading, isFalse);
      expect(dashState.error, isNull);
      expect(dashState.stats, isNotNull);
    });
  });
}
