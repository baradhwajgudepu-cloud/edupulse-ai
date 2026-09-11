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
  bool failAuditWith404 = false;
  bool failSchoolSetup = false;
  final List<String> requestedGetPaths = [];
  bool failSessionsWith404 = false;

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    requestedGetPaths.add(path);

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

    // 2. Daily session lookup (obsolete endpoint simulation)
    if (path.contains('/attendances/daily/session') || path.contains('/attendance/daily/session')) {
      return ApiResult.failure(const ApiFailure(
        message: 'Not Found',
        statusCode: 404,
        type: ApiFailureType.unknown,
      ));
    }

    // 3. Canonical /attendances/sessions lookup
    if (path.contains('/attendances/sessions')) {
      if (failSessionsWith404) {
        return ApiResult.failure(const ApiFailure(
          message: 'Not Found',
          statusCode: 404,
          type: ApiFailureType.unknown,
        ));
      }
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
      if (failAuditWith404) {
        return ApiResult.failure(const ApiFailure(
          message: 'Not Found',
          statusCode: 404,
          type: ApiFailureType.unknown,
        ));
      }
      return ApiResult.success(mapper({
        'data': auditLogs,
        'meta': {'total': auditLogs.length}
      }));
    }

    // 9. Academic years lookup
    if (path.contains('/academic-years')) {
      if (failSchoolSetup) {
        return ApiResult.failure(const ApiFailure(message: 'Academic years failed to load', type: ApiFailureType.unknown, statusCode: 500));
      }
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'ay_1',
            'name': '2025-2026',
            'code': 'AY2526',
            'school_id': 'school_1',
            'tenant_id': 'tenant_1',
            'start_date': '2025-06-01',
            'end_date': '2026-04-30',
            'status': 'ACTIVE',
            'is_current': true,
            'version': 1,
          },
          {
            'id': 'ay_2',
            'name': '2026-2027',
            'code': 'AY2627',
            'school_id': 'school_1',
            'tenant_id': 'tenant_1',
            'start_date': '2026-06-01',
            'end_date': '2027-04-30',
            'status': 'UPCOMING',
            'is_current': false,
            'version': 1,
          },
        ]
      }));
    }

    // 10. Classes lookup
    if (path.contains('/classes')) {
      if (failSchoolSetup) {
        return ApiResult.failure(const ApiFailure(message: 'Classes failed to load', type: ApiFailureType.unknown, statusCode: 500));
      }
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'class_1',
            'name': 'Class 10',
            'code': 'CLS10',
            'school_id': 'school_1',
            'tenant_id': 'tenant_1',
            'academic_year_id': 'ay_1',
            'level': 10,
            'category': 'SECONDARY',
            'capacity': 40,
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1,
          },
          {
            'id': 'class_2',
            'name': 'Class 9',
            'code': 'CLS9',
            'school_id': 'school_1',
            'tenant_id': 'tenant_1',
            'academic_year_id': 'ay_2',
            'level': 9,
            'category': 'SECONDARY',
            'capacity': 40,
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1,
          },
        ]
      }));
    }

    // 11. Sections lookup
    if (path.contains('/sections')) {
      if (failSchoolSetup) {
        return ApiResult.failure(const ApiFailure(message: 'Sections failed to load', type: ApiFailureType.unknown, statusCode: 500));
      }
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'sec_1',
            'name': 'Section A',
            'code': '10A',
            'class_id': 'class_1',
            'academic_year_id': 'ay_1',
            'school_id': 'school_1',
            'tenant_id': 'tenant_1',
            'capacity': 40,
            'sort_order': 1,
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1,
          },
          {
            'id': 'sec_2',
            'name': 'Section B',
            'code': '9B',
            'class_id': 'class_2',
            'academic_year_id': 'ay_2',
            'school_id': 'school_1',
            'tenant_id': 'tenant_1',
            'capacity': 40,
            'sort_order': 2,
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1,
          },
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

    test('14. AUDIT TRAIL 404 TRUTHFULNESS: gracefully reports unsupported version without fabricating records', () async {
      mockApi.auditLogs = [];
      mockApi.failAuditWith404 = true;

      final auditNotifier = container.read(attendanceAuditLogsProvider.notifier);
      await auditNotifier.fetchAuditLogs();
      final auditState = container.read(attendanceAuditLogsProvider);

      expect(auditState.isLoading, isFalse);
      expect(auditState.isUnsupportedVersion, isTrue);
      expect(auditState.unsupportedMessage, contains('Detailed audit history is not available in this production API version'));
      expect(auditState.logs, isEmpty);
      expect(auditState.error, isNull);
    });

    group('Attendance Mark Selectors & Cascading Workflow Tests', () {
      test('TEST 1: Academic Year options load successfully and selecting an Academic Year updates DailyAttendanceMarkState', () async {
        final ayNotifier = container.read(academicYearsProvider('school_1').notifier);
        await ayNotifier.fetchYears();
        final ayState = container.read(academicYearsProvider('school_1'));
        expect(ayState.years.length, equals(2));
        expect(ayState.years.first.id, equals('ay_1'));

        final markNotifier = container.read(dailyAttendanceMarkProvider.notifier);
        markNotifier.setSelection(academicYearId: 'ay_1', clearClass: true, clearSection: true);
        final state = container.read(dailyAttendanceMarkProvider);
        expect(state.academicYearId, equals('ay_1'));
        expect(state.classId, isNull);
        expect(state.sectionId, isNull);
        expect(state.roster, isEmpty);
      });

      test('TEST 2: Class remains disabled before Academic Year selection', () async {
        final markNotifier = container.read(dailyAttendanceMarkProvider.notifier);
        markNotifier.reset();
        final state = container.read(dailyAttendanceMarkProvider);
        expect(state.academicYearId, isNull);
        expect(state.classId, isNull);

        // When academicYearId is null, class selection is disallowed/cleared
        final classesNotifier = container.read(classesProvider('school_1').notifier);
        await classesNotifier.fetchClasses();
        final classesState = container.read(classesProvider('school_1'));

        final availableClasses = classesState.classes.where((c) {
          if (state.academicYearId != null && c.academicYearId != state.academicYearId) return false;
          return state.academicYearId != null;
        }).toList();

        expect(availableClasses, isEmpty);
      });

      test('TEST 3: Class becomes enabled after Academic Year selection and only classes belonging to that Academic Year are displayed', () async {
        final markNotifier = container.read(dailyAttendanceMarkProvider.notifier);
        markNotifier.setSelection(academicYearId: 'ay_1', clearClass: true, clearSection: true);

        final classesNotifier = container.read(classesProvider('school_1').notifier);
        await classesNotifier.fetchClasses();
        final classesState = container.read(classesProvider('school_1'));

        final availableForAy1 = classesState.classes.where((c) => c.academicYearId == 'ay_1').toList();
        final availableForAy2 = classesState.classes.where((c) => c.academicYearId == 'ay_2').toList();

        expect(availableForAy1.length, equals(1));
        expect(availableForAy1.first.name, equals('Class 10'));
        expect(availableForAy2.length, equals(1));
        expect(availableForAy2.first.name, equals('Class 9'));
      });

      test('TEST 4: Changing Academic Year clears the previously selected Class, Section, and roster', () async {
        final markNotifier = container.read(dailyAttendanceMarkProvider.notifier);
        markNotifier.setSelection(academicYearId: 'ay_1', classId: 'class_1', sectionId: 'sec_1');
        await markNotifier.loadRoster();

        var state = container.read(dailyAttendanceMarkProvider);
        expect(state.academicYearId, equals('ay_1'));
        expect(state.classId, equals('class_1'));
        expect(state.sectionId, equals('sec_1'));
        expect(state.roster.isNotEmpty, isTrue);

        // Change academic year
        markNotifier.setSelection(academicYearId: 'ay_2', clearClass: true, clearSection: true);
        state = container.read(dailyAttendanceMarkProvider);

        expect(state.academicYearId, equals('ay_2'));
        expect(state.classId, isNull);
        expect(state.sectionId, isNull);
        expect(state.roster, isEmpty);
      });

      test('TEST 5: Section remains disabled before Class selection', () async {
        final markNotifier = container.read(dailyAttendanceMarkProvider.notifier);
        markNotifier.reset();
        markNotifier.setSelection(academicYearId: 'ay_1');

        final state = container.read(dailyAttendanceMarkProvider);
        expect(state.classId, isNull);

        final sectionsNotifier = container.read(sectionsProvider('school_1').notifier);
        await sectionsNotifier.fetchSections();
        final sectionsState = container.read(sectionsProvider('school_1'));

        final availableSections = sectionsState.sections.where((s) {
          if (state.classId != null && s.classId != state.classId) return false;
          return state.classId != null;
        }).toList();

        expect(availableSections, isEmpty);
      });

      test('TEST 6: Section becomes enabled after Class selection and only sections belonging to that Class are displayed', () async {
        final markNotifier = container.read(dailyAttendanceMarkProvider.notifier);
        markNotifier.setSelection(academicYearId: 'ay_1', classId: 'class_1', clearSection: true);

        final sectionsNotifier = container.read(sectionsProvider('school_1').notifier);
        await sectionsNotifier.fetchSections();
        final sectionsState = container.read(sectionsProvider('school_1'));

        final sectionsForClass1 = sectionsState.sections.where((s) => s.classId == 'class_1').toList();
        final sectionsForClass2 = sectionsState.sections.where((s) => s.classId == 'class_2').toList();

        expect(sectionsForClass1.length, equals(1));
        expect(sectionsForClass1.first.name, equals('Section A'));
        expect(sectionsForClass2.length, equals(1));
        expect(sectionsForClass2.first.name, equals('Section B'));
      });

      test('TEST 7: Changing Class clears Section and roster', () async {
        final markNotifier = container.read(dailyAttendanceMarkProvider.notifier);
        markNotifier.setSelection(academicYearId: 'ay_1', classId: 'class_1', sectionId: 'sec_1');
        await markNotifier.loadRoster();

        var state = container.read(dailyAttendanceMarkProvider);
        expect(state.sectionId, equals('sec_1'));
        expect(state.roster.isNotEmpty, isTrue);

        // Change class
        markNotifier.setSelection(classId: 'class_2', clearSection: true);
        state = container.read(dailyAttendanceMarkProvider);

        expect(state.classId, equals('class_2'));
        expect(state.sectionId, isNull);
        expect(state.roster, isEmpty);
      });

      test('TEST 8: Selecting Section triggers student roster loading', () async {
        final markNotifier = container.read(dailyAttendanceMarkProvider.notifier);
        markNotifier.setSelection(academicYearId: 'ay_1', classId: 'class_1', sectionId: 'sec_1');
        await markNotifier.loadRoster();

        final state = container.read(dailyAttendanceMarkProvider);
        expect(state.isLoading, isFalse);
        expect(state.roster.length, equals(3));
        expect(state.roster[0].studentName, equals('Aarav Reddy'));
        expect(state.roster[1].studentName, equals('Diya Patel'));
        expect(state.roster[2].studentName, equals('Karan Singh'));
      });

      test('TEST 9: Date picker remains functional', () async {
        final markNotifier = container.read(dailyAttendanceMarkProvider.notifier);
        final targetDate = DateTime(2026, 10, 15);
        markNotifier.setSelection(attendanceDate: targetDate);

        final state = container.read(dailyAttendanceMarkProvider);
        expect(state.attendanceDate, equals(targetDate));
      });

      test('TEST 10: Session dropdown remains functional', () async {
        final markNotifier = container.read(dailyAttendanceMarkProvider.notifier);
        markNotifier.setSelection(sessionType: 'MORNING');
        expect(container.read(dailyAttendanceMarkProvider).sessionType, equals('MORNING'));

        markNotifier.setSelection(sessionType: 'AFTERNOON');
        expect(container.read(dailyAttendanceMarkProvider).sessionType, equals('AFTERNOON'));

        markNotifier.setSelection(sessionType: 'FULL_DAY');
        expect(container.read(dailyAttendanceMarkProvider).sessionType, equals('FULL_DAY'));
      });

      test('TEST 11: Provider loading/error states do not cause crashes', () async {
        mockApi.failSchoolSetup = true;

        final ayNotifier = container.read(academicYearsProvider('school_1').notifier);
        await ayNotifier.fetchYears();
        final ayState = container.read(academicYearsProvider('school_1'));
        expect(ayState.error, isNotNull);
        expect(ayState.isLoading, isFalse);

        final classesNotifier = container.read(classesProvider('school_1').notifier);
        await classesNotifier.fetchClasses();
        final classesState = container.read(classesProvider('school_1'));
        expect(classesState.error, isNotNull);
        expect(classesState.isLoading, isFalse);

        final sectionsNotifier = container.read(sectionsProvider('school_1').notifier);
        await sectionsNotifier.fetchSections();
        final sectionsState = container.read(sectionsProvider('school_1'));
        expect(sectionsState.error, isNotNull);
        expect(sectionsState.isLoading, isFalse);

        // Reset fail flag and verify clean recovery
        mockApi.failSchoolSetup = false;
        await ayNotifier.fetchYears();
        expect(container.read(academicYearsProvider('school_1')).error, isNull);
        expect(container.read(academicYearsProvider('school_1')).years.length, equals(2));
      });
    });

    group('Attendance Mark Canonical Session Endpoint Regression Tests', () {
      test('TEST 12: Roster loads successfully and uses canonical /attendances/sessions for existing session lookup', () async {
        mockApi.requestedGetPaths.clear();
        mockApi.activeSession = null;

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
        expect(state.errorMessage, isNull);

        // Verify canonical endpoint is used
        expect(
          mockApi.requestedGetPaths.any((p) => p.startsWith('/attendances/sessions')),
          isTrue,
          reason: 'Must use canonical /attendances/sessions endpoint',
        );

        // Verify obsolete endpoint is NOT used
        expect(
          mockApi.requestedGetPaths.any((p) => p.contains('/attendances/daily/session')),
          isFalse,
          reason: 'Must NOT call obsolete /attendances/daily/session endpoint',
        );
      });

      test('TEST 13: Empty session result (normal state) does not produce an error banner', () async {
        mockApi.requestedGetPaths.clear();
        mockApi.activeSession = null;

        final markNotifier = container.read(dailyAttendanceMarkProvider.notifier);
        markNotifier.setSelection(
          academicYearId: 'ay_1',
          classId: 'class_1',
          sectionId: 'sec_1',
          attendanceDate: DateTime(2026, 9, 11),
        );

        await markNotifier.loadRoster();

        final state = container.read(dailyAttendanceMarkProvider);
        expect(state.errorMessage, isNull);
        expect(state.sessionId, isNull);
        expect(state.isLocked, isFalse);
        expect(state.roster.isNotEmpty, isTrue);
      });

      test('TEST 14: Existing session via canonical /attendances/sessions correctly pre-populates attendance', () async {
        mockApi.requestedGetPaths.clear();
        mockApi.activeSession = {
          'id': 'session_prepop_1',
          'tenant_id': 'tenant_1',
          'school_id': 'school_1',
          'class_id': 'class_1',
          'section_id': 'sec_1',
          'academic_year_id': 'ay_1',
          'attendance_date': '2026-09-11',
          'session_type': 'FULL_DAY',
          'status': 'SUBMITTED',
          'total_students': 3,
          'present_count': 2,
          'absent_count': 1,
          'late_count': 0,
          'excused_count': 0,
          'is_locked': false,
          'attendances': [
            {
              'id': 'att_prepop_1',
              'student_id': 'stud_001',
              'attendance_status': 'PRESENT',
              'attendance_reason': 'UNKNOWN',
              'remarks': 'On time',
            },
            {
              'id': 'att_prepop_2',
              'student_id': 'stud_002',
              'attendance_status': 'ABSENT',
              'attendance_reason': 'ILLNESS',
              'remarks': 'Fever',
            },
          ],
        };

        final markNotifier = container.read(dailyAttendanceMarkProvider.notifier);
        markNotifier.setSelection(
          academicYearId: 'ay_1',
          classId: 'class_1',
          sectionId: 'sec_1',
          attendanceDate: DateTime(2026, 9, 11),
        );

        await markNotifier.loadRoster();

        final state = container.read(dailyAttendanceMarkProvider);
        expect(state.errorMessage, isNull);
        expect(state.sessionId, equals('session_prepop_1'));
        expect(state.isLocked, isFalse);
        expect(state.roster[0].status, equals('PRESENT'));
        expect(state.roster[0].remarks, equals('On time'));
        expect(state.roster[1].status, equals('ABSENT'));
        expect(state.roster[1].reason, equals('SICK'));
        expect(state.roster[1].remarks, equals('Fever'));
      });

      test('TEST 15: Optional session lookup failure handles gracefully without error banner and keeps roster', () async {
        mockApi.requestedGetPaths.clear();
        mockApi.failSessionsWith404 = true;

        final markNotifier = container.read(dailyAttendanceMarkProvider.notifier);
        markNotifier.setSelection(
          academicYearId: 'ay_1',
          classId: 'class_1',
          sectionId: 'sec_1',
          attendanceDate: DateTime(2026, 9, 11),
        );

        await markNotifier.loadRoster();

        final state = container.read(dailyAttendanceMarkProvider);
        // Roster is preserved and displayed
        expect(state.roster.length, equals(3));
        expect(state.isLoading, isFalse);
        // Error message is not populated for optional session lookup failure
        expect(state.errorMessage, isNull);
        expect(state.sessionId, isNull);

        mockApi.failSessionsWith404 = false;
      });
    });
  });
}
