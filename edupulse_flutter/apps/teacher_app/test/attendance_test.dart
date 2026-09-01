import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:teacher_app/app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_app/features/shell/presentation/pages/home_screen.dart';

import 'package:teacher_app/core/providers/bootstrap_provider.dart';
import 'package:teacher_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:teacher_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:teacher_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:teacher_app/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:teacher_app/features/dashboard/domain/entities/teacher_profile.dart';
import 'package:teacher_app/features/dashboard/domain/entities/academic_year.dart';
import 'package:teacher_app/features/dashboard/domain/entities/timetable_entry.dart';
import 'package:teacher_app/features/my_classes/domain/repositories/my_classes_repository.dart';
import 'package:teacher_app/features/my_classes/presentation/providers/my_classes_provider.dart';
import 'package:teacher_app/features/my_classes/domain/entities/teacher_class_group.dart';
import 'package:teacher_app/features/my_classes/domain/entities/student.dart';

import 'package:teacher_app/features/attendance/domain/entities/attendance_enums.dart';
import 'package:teacher_app/features/attendance/domain/entities/attendance_response_entity.dart';
import 'package:teacher_app/features/attendance/domain/entities/attendance_session_entity.dart';
import 'package:teacher_app/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:teacher_app/features/attendance/presentation/providers/attendance_provider.dart';
import 'package:teacher_app/features/attendance/presentation/pages/attendance_marking_screen.dart';

// --- AUTH REPO FAKE ---
class FakeAuthRepository implements AuthRepository {
  final List<String> userRoles;

  FakeAuthRepository({this.userRoles = const ['TEACHER']});

  @override
  Future<ApiResult<SessionToken>> login({required String email, required String password}) async {
    return const ApiResult.success(SessionToken(accessToken: 'access', refreshToken: 'refresh', tokenType: 'bearer'));
  }

  @override
  Future<ApiResult<void>> logout({required String refreshToken}) async {
    return const ApiResult.success(null);
  }

  @override
  Future<ApiResult<SessionToken>> refreshToken({required String refreshToken}) async {
    return const ApiResult.success(SessionToken(accessToken: 'access_new', refreshToken: 'refresh_new', tokenType: 'bearer'));
  }

  @override
  Future<ApiResult<UserEntity>> getCurrentUser() async {
    return ApiResult.success(
      UserEntity(
        id: 'teacher_123',
        email: 'teacher@edupulse.ai',
        firstName: 'Sarah',
        lastName: 'Connor',
        tenantId: 'd09b9362-3dc8-422d-a441-160735fcea96',
        isSuperuser: false,
        roles: userRoles,
        schools: const ['16730f87-bf8d-44e0-acf9-4b055a778b58'],
      ),
    );
  }

  @override
  Future<ApiResult<void>> requestPasswordReset({required String email}) async {
    return const ApiResult.success(null);
  }
}

class FakeSessionManager implements SessionManager {
  String? cachedTenantId;

  @override
  Future<String?> getTenantId() async => cachedTenantId;

  @override
  Future<void> saveTenantId(String tenantId) async {
    cachedTenantId = tenantId;
  }

  final bool hasSessionValue;
  String? cachedSchoolId;

  FakeSessionManager({required bool hasSession}) : hasSessionValue = hasSession;

  @override
  Future<String?> getAccessToken() async => hasSessionValue ? 'access' : null;

  @override
  Future<String?> getRefreshToken() async => hasSessionValue ? 'refresh' : null;

  @override
  Future<void> saveSession(SessionToken token) async {}

  @override
  Future<void> clearSession() async {}

  @override
  Future<bool> hasSession() async => hasSessionValue;

  @override
  Future<String?> getSchoolId() async => '16730f87-bf8d-44e0-acf9-4b055a778b58';

  @override
  Future<void> saveSchoolId(String schoolId) async {
    cachedSchoolId = schoolId;
  }
}

// --- DASHBOARD REPO FAKE ---
class FakeDashboardRepository implements DashboardRepository {
  @override
  Future<ApiResult<DashboardDataEntity>> getDashboardData({
    required String schoolId,
    required String email,
  }) async {
    return ApiResult.success(
      DashboardDataEntity(
        teacherProfile: TeacherProfileEntity(
          id: 'teacher_123',
          employeeCode: 'EMP-9402',
          firstName: 'Sarah',
          lastName: 'Connor',
          designation: 'Senior Lecturer',
          department: 'Science Department',
          officialEmail: 'teacher@edupulse.ai',
          mobile: '1234567890',
          status: 'ACTIVE',
        ),
        academicYear: AcademicYearEntity(
          id: 'ay_123',
          name: 'Academic Year 2026-27',
          code: 'AY-2026-27',
          status: 'ACTIVE',
        ),
        schedule: [
          TimetableEntryEntity(
            id: 'timetable_1',
            dayOfWeek: 'MONDAY',
            periodNumber: 2,
            startTime: '09:40:00',
            endTime: '10:20:00',
            periodType: 'REGULAR',
            isAvailable: true,
            classId: 'class_9',
            className: 'Grade 9',
            sectionId: 'sec_a',
            sectionName: 'A',
            subjectId: 'sub_math',
            subjectName: 'Mathematics',
            subjectCode: 'MATH-101',
            displayColor: '#FF5733',
          ),
        ],
      ),
    );
  }
}

// --- MY CLASSES REPO FAKE ---
class FakeMyClassesRepository implements MyClassesRepository {
  List<StudentEntity> studentsMock = [
    const StudentEntity(
      id: 'student_1',
      firstName: 'John',
      lastName: 'Doe',
      gender: 'MALE',
      dateOfBirth: '2012-05-14',
      admissionNumber: 'ADM-1001',
      rollNumber: '01',
      status: 'ACTIVE',
      className: 'Grade 9',
      sectionName: 'A',
    ),
    const StudentEntity(
      id: 'student_2',
      firstName: 'Jane',
      lastName: 'Smith',
      gender: 'FEMALE',
      dateOfBirth: '2012-09-20',
      admissionNumber: 'ADM-1002',
      rollNumber: '02',
      status: 'ACTIVE',
      className: 'Grade 9',
      sectionName: 'A',
    ),
  ];

  @override
  Future<ApiResult<List<TeacherClassGroupEntity>>> getTeacherClasses({
    required String schoolId,
    required String academicYearId,
    required String teacherId,
  }) async {
    return const ApiResult.success([]);
  }

  @override
  Future<ApiResult<List<StudentEntity>>> getClassStudents({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String sectionId,
  }) async {
    return ApiResult.success(studentsMock);
  }

  @override
  Future<ApiResult<List<StudentEntity>>> getTeacherStudents({
    required String schoolId,
    required String academicYearId,
  }) async {
    return ApiResult.success(studentsMock);
  }
}

// --- ATTENDANCE REPO FAKE ---
class FakeAttendanceRepository implements AttendanceRepository {
  bool shouldFail = false;
  String? failureMessage;
  int bulkMarkCount = 0;
  int createSessionCount = 0;

  AttendanceSessionEntity? currentSession;
  List<AttendanceSessionEntity> getSessionsMock = [];

  @override
  Future<ApiResult<AttendanceSessionEntity>> createSession({
    required String schoolId,
    required String academicYearId,
    required String timetableId,
    required String attendanceDate,
  }) async {
    createSessionCount++;
    if (shouldFail) {
      return ApiResult.failure(
        ApiFailure(
          message: failureMessage ?? 'Failed to create session',
          type: ApiFailureType.unknown,
          statusCode: 500,
        ),
      );
    }

    currentSession = AttendanceSessionEntity(
      id: 'session_123',
      tenantId: 'd09b9362-3dc8-422d-a441-160735fcea96',
      schoolId: schoolId,
      academicYearId: academicYearId,
      timetableId: timetableId,
      classId: 'class_9',
      sectionId: 'sec_a',
      teacherId: 'teacher_123',
      subjectId: 'sub_math',
      attendanceDate: attendanceDate,
      status: AttendanceSessionStatus.DRAFT,
      attendances: const [],
    );
    getSessionsMock = [currentSession!];
    return ApiResult.success(currentSession!);
  }

  @override
  Future<ApiResult<AttendanceSessionEntity>> bulkMarkAttendance({
    required String schoolId,
    required String sessionId,
    required AttendanceSessionStatus sessionStatus,
    required List<AttendanceRecordPayload> records,
  }) async {
    bulkMarkCount++;
    if (shouldFail) {
      return ApiResult.failure(
        ApiFailure(
          message: failureMessage ?? 'Failed to mark attendance',
          type: ApiFailureType.unknown,
          statusCode: 500,
        ),
      );
    }

    final logs = records.map((r) => AttendanceResponseEntity(
      id: 'log_${r.studentId}',
      tenantId: 'd09b9362-3dc8-422d-a441-160735fcea96',
      schoolId: schoolId,
      academicYearId: 'ay_123',
      attendanceSessionId: sessionId,
      studentId: r.studentId,
      timetableId: 'timetable_1',
      classId: 'class_9',
      sectionId: 'sec_a',
      attendanceDate: '2026-08-13',
      attendanceStatus: r.attendanceStatus,
      attendanceSource: r.attendanceSource,
      attendanceReason: r.attendanceReason,
      remarks: r.remarks,
    )).toList();

    currentSession = AttendanceSessionEntity(
      id: sessionId,
      tenantId: 'd09b9362-3dc8-422d-a441-160735fcea96',
      schoolId: schoolId,
      academicYearId: 'ay_123',
      timetableId: 'timetable_1',
      classId: 'class_9',
      sectionId: 'sec_a',
      teacherId: 'teacher_123',
      subjectId: 'sub_math',
      attendanceDate: '2026-08-13',
      status: sessionStatus,
      attendances: logs,
    );
    getSessionsMock = [currentSession!];
    return ApiResult.success(currentSession!);
  }

  @override
  Future<ApiResult<List<AttendanceSessionEntity>>> getSessions({
    required String schoolId,
    String? academicYearId,
    String? classId,
    String? sectionId,
    String? attendanceDate,
    AttendanceSessionStatus? status,
  }) async {
    if (shouldFail) {
      return ApiResult.failure(
        ApiFailure(
          message: failureMessage ?? 'Failed to list sessions',
          type: ApiFailureType.unknown,
          statusCode: 500,
        ),
      );
    }
    return ApiResult.success(getSessionsMock);
  }

  @override
  Future<ApiResult<AttendanceSessionEntity>> getSessionDetails({
    required String schoolId,
    required String sessionId,
  }) async {
    if (shouldFail) {
      return ApiResult.failure(
        ApiFailure(
          message: failureMessage ?? 'Failed to get details',
          type: ApiFailureType.unknown,
          statusCode: 500,
        ),
      );
    }
    return ApiResult.success(currentSession!);
  }

  @override
  Future<ApiResult<AttendanceResponseEntity>> correctAttendance({
    required String schoolId,
    required String sessionId,
    required String studentId,
    required AttendanceStatus attendanceStatus,
    required String correctionReason,
    AttendanceSource? attendanceSource,
    AttendanceReason? attendanceReason,
    String? remarks,
  }) async {
    if (shouldFail) {
      return ApiResult.failure(
        ApiFailure(
          message: failureMessage ?? 'Failed to correct attendance',
          type: ApiFailureType.unknown,
          statusCode: 500,
        ),
      );
    }

    final entity = AttendanceResponseEntity(
      id: 'log_$studentId',
      tenantId: 'd09b9362-3dc8-422d-a441-160735fcea96',
      schoolId: schoolId,
      academicYearId: 'ay_123',
      attendanceSessionId: sessionId,
      studentId: studentId,
      timetableId: 'timetable_1',
      classId: 'class_9',
      sectionId: 'sec_a',
      attendanceDate: '2026-08-13',
      attendanceStatus: attendanceStatus,
      attendanceSource: attendanceSource ?? AttendanceSource.MANUAL,
      attendanceReason: attendanceReason ?? AttendanceReason.UNKNOWN,
      remarks: remarks,
    );

    if (currentSession != null) {
      final updatedList = currentSession!.attendances.map((a) {
        if (a.studentId == studentId) return entity;
        return a;
      }).toList();

      currentSession = AttendanceSessionEntity(
        id: currentSession!.id,
        tenantId: currentSession!.tenantId,
        schoolId: currentSession!.schoolId,
        academicYearId: currentSession!.academicYearId,
        timetableId: currentSession!.timetableId,
        classId: currentSession!.classId,
        sectionId: currentSession!.sectionId,
        teacherId: currentSession!.teacherId,
        subjectId: currentSession!.subjectId,
        attendanceDate: currentSession!.attendanceDate,
        status: currentSession!.status,
        attendances: updatedList,
      );
    }

    return ApiResult.success(entity);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestWidget({
    required WidgetTester tester,
    required FakeAttendanceRepository attendanceRepo,
    FakeDashboardRepository? dashboardRepo,
    FakeAuthRepository? authRepo,
    FakeSessionManager? sessionManager,
    FakeMyClassesRepository? myClassesRepo,
  }) {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    return ProviderScope(
      overrides: [
        isTestingProvider.overrideWithValue(true),
        bootstrapResultProvider.overrideWithValue(BootstrapResult(success: true)),
        sessionManagerProvider.overrideWithValue(sessionManager ?? FakeSessionManager(hasSession: true)),
        authRepositoryProvider.overrideWithValue(authRepo ?? FakeAuthRepository()),
        dashboardRepositoryProvider.overrideWithValue(dashboardRepo ?? FakeDashboardRepository()),
        myClassesRepositoryProvider.overrideWithValue(myClassesRepo ?? FakeMyClassesRepository()),
        attendanceRepositoryProvider.overrideWithValue(attendanceRepo),
      ],
      child: const EduPulseApp(),
    );
  }

  group('Phase 4: Attendance Screen Widget Tests', () {
    testWidgets('1. Session Initialization and default students PRESENT', (tester) async {
      final fakeAttendanceRepo = FakeAttendanceRepository();

      await tester.pumpWidget(createTestWidget(tester: tester, attendanceRepo: fakeAttendanceRepo));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Navigate to Attendance Screen directly by pumping or simulating GoRouter push
      // We can directly navigate to Route /attendance?timetableId=timetable_1&date=2026-08-13
      final context = tester.element(find.byType(HomeScreen));
      context.push('/attendance?timetableId=timetable_1&date=2026-08-13');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Verify Header details
      expect(find.text('Grade 9 - A'), findsWidgets);
      expect(find.text('Mathematics'), findsWidgets);
      expect(find.text('Period 2 (09:40:00 - 10:20:00)'), findsOneWidget);

      // Verify default state matches PRESENT for all students
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('Jane Smith'), findsOneWidget);
      expect(find.text('PRESENT'), findsNWidgets(2));

      // Verify Live counters
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('2'), findsNWidgets(2)); // Total and Present counts
      expect(find.text('Absent'), findsOneWidget);
      expect(find.text('0'), findsNWidgets(2)); // Absent and Late counts
    });

    testWidgets('2. Roster item toggles between PRESENT and ABSENT and counter updates', (tester) async {
      final fakeAttendanceRepo = FakeAttendanceRepository();

      await tester.pumpWidget(createTestWidget(tester: tester, attendanceRepo: fakeAttendanceRepo));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(HomeScreen));
      context.push('/attendance?timetableId=timetable_1&date=2026-08-13');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Verify both are present initially
      expect(find.text('2'), findsNWidgets(2)); // Total & Present

      // Tap on John Doe row to toggle ABSENT
      await tester.tap(find.text('John Doe'));
      await tester.pumpAndSettle();

      // Verify John Doe is now ABSENT
      expect(find.text('ABSENT'), findsOneWidget);
      expect(find.text('1'), findsNWidgets(2)); // Present counter = 1, Absent counter = 1
      expect(find.text('2'), findsOneWidget); // Total = 2

      // Tap again to toggle back to PRESENT
      await tester.tap(find.text('John Doe'));
      await tester.pumpAndSettle();

      expect(find.text('PRESENT'), findsNWidgets(2));
      expect(find.text('2'), findsNWidgets(2)); // Present count = 2
    });

    testWidgets('3. Mark All Present resets status list locally', (tester) async {
      final fakeAttendanceRepo = FakeAttendanceRepository();

      await tester.pumpWidget(createTestWidget(tester: tester, attendanceRepo: fakeAttendanceRepo));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(HomeScreen));
      context.push('/attendance?timetableId=timetable_1&date=2026-08-13');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Change both to ABSENT
      await tester.tap(find.text('John Doe'));
      await tester.tap(find.text('Jane Smith'));
      await tester.pumpAndSettle();

      expect(find.text('ABSENT'), findsNWidgets(2));

      // Tap "All Present"
      await tester.tap(find.text('All Present'));
      await tester.pumpAndSettle();

      expect(find.text('PRESENT'), findsNWidgets(2));
    });

    testWidgets('4. Local search filters roster view list', (tester) async {
      final fakeAttendanceRepo = FakeAttendanceRepository();

      await tester.pumpWidget(createTestWidget(tester: tester, attendanceRepo: fakeAttendanceRepo));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(HomeScreen));
      context.push('/attendance?timetableId=timetable_1&date=2026-08-13');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('Jane Smith'), findsOneWidget);

      // Search "Jane"
      final searchTextField = find.byType(TextField);
      await tester.enterText(searchTextField, 'Jane');
      await tester.pumpAndSettle();

      expect(find.text('John Doe'), findsNothing);
      expect(find.text('Jane Smith'), findsOneWidget);
    });

    testWidgets('5. Bulk Submission runs transaction and redirects', (tester) async {
      final fakeAttendanceRepo = FakeAttendanceRepository();

      await tester.pumpWidget(createTestWidget(tester: tester, attendanceRepo: fakeAttendanceRepo));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(HomeScreen));
      context.push('/attendance?timetableId=timetable_1&date=2026-08-13');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Toggle Jane ABSENT
      await tester.tap(find.text('Jane Smith'));
      await tester.pumpAndSettle();

      // Tap Approve and Submit
      await tester.tap(find.text('APPROVE & SUBMIT'));
      await tester.pumpAndSettle();

      // Verify dialog details
      expect(find.text('Approve Attendance?'), findsOneWidget);
      expect(find.text('2 Students'), findsOneWidget);
      expect(find.text('Approve & Submit'), findsOneWidget);

      // Tap dialog confirm
      await tester.tap(find.text('Approve & Submit'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2)); // wait for provider navigation/actions
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Check transaction run
      expect(fakeAttendanceRepo.createSessionCount, 1);
      expect(fakeAttendanceRepo.bulkMarkCount, 1);

      // Re-navigated back or pop completed
      expect(find.byType(AttendanceMarkingScreen), findsNothing);
    });

    testWidgets('6. Existing session loads logs in edit state', (tester) async {
      final fakeAttendanceRepo = FakeAttendanceRepository();
      // Setup existing session mock
      fakeAttendanceRepo.getSessionsMock = [
        AttendanceSessionEntity(
          id: 'session_123',
          tenantId: 'tenant_id',
          schoolId: 'school_id',
          academicYearId: 'ay_123',
          timetableId: 'timetable_1',
          classId: 'class_9',
          sectionId: 'sec_a',
          attendanceDate: '2026-08-13',
          status: AttendanceSessionStatus.SUBMITTED,
          attendances: const [
            AttendanceResponseEntity(
              id: 'log_student_1',
              tenantId: 'tenant_id',
              schoolId: 'school_id',
              academicYearId: 'ay_123',
              attendanceSessionId: 'session_123',
              studentId: 'student_1',
              timetableId: 'timetable_1',
              classId: 'class_9',
              sectionId: 'sec_a',
              attendanceDate: '2026-08-13',
              attendanceStatus: AttendanceStatus.ABSENT,
              attendanceSource: AttendanceSource.MANUAL,
              attendanceReason: AttendanceReason.UNKNOWN,
            ),
          ],
        ),
      ];
      fakeAttendanceRepo.currentSession = fakeAttendanceRepo.getSessionsMock.first;

      await tester.pumpWidget(createTestWidget(tester: tester, attendanceRepo: fakeAttendanceRepo));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(HomeScreen));
      context.push('/attendance?timetableId=timetable_1&date=2026-08-13');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Verify Loaded with SUBMITTED status and details
      expect(find.text('ABSENT'), findsOneWidget); // student_1 is ABSENT
      expect(find.text('PRESENT'), findsOneWidget); // student_2 defaults to PRESENT
      expect(find.text('Attendance is SUBMITTED. Modifying records requires a correction reason.'), findsOneWidget);
    });

    testWidgets('7. Modifying submitted log prompts for correction reason', (tester) async {
      final fakeAttendanceRepo = FakeAttendanceRepository();
      fakeAttendanceRepo.getSessionsMock = [
        AttendanceSessionEntity(
          id: 'session_123',
          tenantId: 'tenant_id',
          schoolId: 'school_id',
          academicYearId: 'ay_123',
          timetableId: 'timetable_1',
          classId: 'class_9',
          sectionId: 'sec_a',
          attendanceDate: '2026-08-13',
          status: AttendanceSessionStatus.SUBMITTED,
          attendances: const [
            AttendanceResponseEntity(
              id: 'log_student_1',
              tenantId: 'tenant_id',
              schoolId: 'school_id',
              academicYearId: 'ay_123',
              attendanceSessionId: 'session_123',
              studentId: 'student_1',
              timetableId: 'timetable_1',
              classId: 'class_9',
              sectionId: 'sec_a',
              attendanceDate: '2026-08-13',
              attendanceStatus: AttendanceStatus.PRESENT,
              attendanceSource: AttendanceSource.MANUAL,
              attendanceReason: AttendanceReason.UNKNOWN,
            ),
          ],
        ),
      ];
      fakeAttendanceRepo.currentSession = fakeAttendanceRepo.getSessionsMock.first;

      await tester.pumpWidget(createTestWidget(tester: tester, attendanceRepo: fakeAttendanceRepo));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(HomeScreen));
      context.push('/attendance?timetableId=timetable_1&date=2026-08-13');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Tap on John Doe to toggle
      await tester.tap(find.text('John Doe'));
      await tester.pumpAndSettle();

      // Verify correction dialog popped
      expect(find.text('Correct Attendance'), findsOneWidget);
      expect(find.text('Correction Reason*'), findsOneWidget);

      // Try typing reason and submitting
      final reasonField = find.byType(TextFormField);
      await tester.enterText(reasonField, 'Marked present incorrectly');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit Correction'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Check dialog closed
      expect(find.text('Correct Attendance'), findsNothing);
    });

    testWidgets('8. Locked session is read-only', (tester) async {
      final fakeAttendanceRepo = FakeAttendanceRepository();
      fakeAttendanceRepo.getSessionsMock = [
        AttendanceSessionEntity(
          id: 'session_123',
          tenantId: 'tenant_id',
          schoolId: 'school_id',
          academicYearId: 'ay_123',
          timetableId: 'timetable_1',
          classId: 'class_9',
          sectionId: 'sec_a',
          attendanceDate: '2026-08-13',
          status: AttendanceSessionStatus.LOCKED,
          attendances: const [
            AttendanceResponseEntity(
              id: 'log_student_1',
              tenantId: 'tenant_id',
              schoolId: 'school_id',
              academicYearId: 'ay_123',
              attendanceSessionId: 'session_123',
              studentId: 'student_1',
              timetableId: 'timetable_1',
              classId: 'class_9',
              sectionId: 'sec_a',
              attendanceDate: '2026-08-13',
              attendanceStatus: AttendanceStatus.PRESENT,
              attendanceSource: AttendanceSource.MANUAL,
              attendanceReason: AttendanceReason.UNKNOWN,
            ),
          ],
        ),
      ];
      fakeAttendanceRepo.currentSession = fakeAttendanceRepo.getSessionsMock.first;

      await tester.pumpWidget(createTestWidget(tester: tester, attendanceRepo: fakeAttendanceRepo));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(HomeScreen));
      context.push('/attendance?timetableId=timetable_1&date=2026-08-13');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('This session is LOCKED. Attendance cannot be modified.'), findsOneWidget);

      // Attempt to tap John Doe
      await tester.tap(find.text('John Doe'));
      await tester.pumpAndSettle();

      // Dialog should not show
      expect(find.text('Correct Attendance'), findsNothing);
    });
  });
}
