import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:teacher_app/app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teacher_app/core/providers/bootstrap_provider.dart';
import 'package:teacher_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:teacher_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:teacher_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:teacher_app/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:teacher_app/features/dashboard/domain/entities/teacher_profile.dart';
import 'package:teacher_app/features/dashboard/domain/entities/academic_year.dart';
import 'package:teacher_app/features/dashboard/domain/entities/timetable_entry.dart';

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
  String? cachedSchoolId;

  @override
  Future<String?> getAccessToken() async => 'access';

  @override
  Future<String?> getRefreshToken() async => 'refresh';

  @override
  Future<void> saveSession(SessionToken token) async {}

  @override
  Future<void> clearSession() async {}

  @override
  Future<bool> hasSession() async => true;

  @override
  Future<String?> getSchoolId() async => '16730f87-bf8d-44e0-acf9-4b055a778b58';

  @override
  Future<void> saveSchoolId(String schoolId) async {
    cachedSchoolId = schoolId;
  }
}

class FakeDashboardRepository implements DashboardRepository {
  final bool shouldFail;
  final String? failureMessage;
  final DashboardDataEntity? customData;
  int callCount = 0;

  FakeDashboardRepository({
    this.shouldFail = false,
    this.failureMessage,
    this.customData,
  });

  @override
  Future<ApiResult<DashboardDataEntity>> getDashboardData({
    required String schoolId,
    required String email,
  }) async {
    callCount++;
    if (shouldFail) {
      return ApiResult.failure(
        ApiFailure(
          message: failureMessage ?? 'Failed to load dashboard data',
          type: ApiFailureType.unknown,
          statusCode: 500,
        ),
      );
    }

    final today = DateTime.now();
    final todayDay = const ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'][today.weekday - 1];

    return ApiResult.success(
      customData ??
          DashboardDataEntity(
            teacherProfile: const TeacherProfileEntity(
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
            academicYear: const AcademicYearEntity(
              id: 'ay_123',
              name: 'Academic Year 2026-27',
              code: 'AY-2026-27',
              status: 'ACTIVE',
            ),
            schedule: [
              TimetableEntryEntity(
                id: 't_slot_1',
                dayOfWeek: todayDay,
                periodNumber: 1,
                startTime: '08:30:00',
                endTime: '09:15:00',
                periodType: 'REGULAR',
                roomId: 'room_101_id',
                isAvailable: true,
                classId: 'class_8',
                className: 'Grade 8',
                sectionId: 'sec_a',
                sectionName: 'Section A',
                subjectId: 'sub_math',
                subjectName: 'Mathematics',
                subjectCode: 'MATH-101',
                displayColor: '#FF5733',
              ),
              TimetableEntryEntity(
                id: 't_slot_2',
                dayOfWeek: todayDay,
                periodNumber: 2,
                startTime: '09:15:00',
                endTime: '10:00:00',
                periodType: 'REGULAR',
                roomId: 'room_102_id',
                isAvailable: true,
                classId: 'class_8',
                className: 'Grade 8',
                sectionId: 'sec_a',
                sectionName: 'Section A',
                subjectId: 'sub_sci',
                subjectName: 'Science',
                subjectCode: 'SCI-101',
                displayColor: '#33FF57',
              ),
            ],
          ),
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Dashboard loads successfully with teacher identity and schedule',
      (WidgetTester tester) async {
    final fakeRepo = FakeDashboardRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isTestingProvider.overrideWithValue(true),
          bootstrapResultProvider.overrideWithValue(BootstrapResult(success: true)),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          sessionManagerProvider.overrideWithValue(FakeSessionManager()),
          dashboardRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const EduPulseApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Verify teacher details display
    expect(find.text('Sarah Connor'), findsOneWidget);
    expect(find.text('Senior Lecturer • Science Department'), findsOneWidget);
    expect(find.text('Emp Code: EMP-9402'), findsOneWidget);
    expect(find.text('AY-2026-27'), findsOneWidget);

    // Verify schedule title and cards
    expect(find.text('Class Timetable'), findsOneWidget);
    expect(find.text('Mathematics'), findsOneWidget);
    expect(find.text('Science'), findsOneWidget);
    expect(find.text('Grade 8 - Section A'), findsNWidgets(2));
  });

  testWidgets('Selecting another weekday filters and displays new schedule',
      (WidgetTester tester) async {
    final customData = DashboardDataEntity(
      teacherProfile: const TeacherProfileEntity(
        id: 'teacher_123',
        employeeCode: 'EMP-9402',
        firstName: 'Sarah',
        lastName: 'Connor',
        designation: 'Lecturer',
        department: 'Science',
        officialEmail: 'teacher@edupulse.ai',
        mobile: '1234567890',
        status: 'ACTIVE',
      ),
      academicYear: const AcademicYearEntity(
        id: 'ay_123',
        name: 'AY 2026',
        code: 'AY-2026',
        status: 'ACTIVE',
      ),
      schedule: [
        const TimetableEntryEntity(
          id: 't_slot_mon',
          dayOfWeek: 'MONDAY',
          periodNumber: 1,
          startTime: '08:30:00',
          endTime: '09:15:00',
          periodType: 'REGULAR',
          isAvailable: true,
          classId: 'class_8',
          className: 'Grade 8',
          sectionId: 'sec_a',
          sectionName: 'A',
          subjectName: 'Math Monday',
          subjectCode: 'MATH',
        ),
        const TimetableEntryEntity(
          id: 't_slot_tue',
          dayOfWeek: 'TUESDAY',
          periodNumber: 1,
          startTime: '08:30:00',
          endTime: '09:15:00',
          periodType: 'REGULAR',
          isAvailable: true,
          classId: 'class_8',
          className: 'Grade 8',
          sectionId: 'sec_a',
          sectionName: 'A',
          subjectName: 'Science Tuesday',
          subjectCode: 'SCI',
        ),
      ],
    );

    final fakeRepo = FakeDashboardRepository(customData: customData);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isTestingProvider.overrideWithValue(true),
          bootstrapResultProvider.overrideWithValue(BootstrapResult(success: true)),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          sessionManagerProvider.overrideWithValue(FakeSessionManager()),
          dashboardRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const EduPulseApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Select Tuesday chip
    final tueChip = find.widgetWithText(ChoiceChip, 'TUE');
    expect(tueChip, findsOneWidget);
    await tester.ensureVisible(tueChip);
    await tester.tap(tueChip);
    await tester.pumpAndSettle();

    // Should display Science Tuesday and not Math Monday
    expect(find.text('Science Tuesday'), findsOneWidget);
    expect(find.text('Math Monday'), findsNothing);
  });

  testWidgets('Empty timetable schedule displays proper empty state card',
      (WidgetTester tester) async {
    final customData = DashboardDataEntity(
      teacherProfile: const TeacherProfileEntity(
        id: 'teacher_123',
        employeeCode: 'EMP-9402',
        firstName: 'Sarah',
        lastName: 'Connor',
        officialEmail: 'teacher@edupulse.ai',
        mobile: '1234567890',
        status: 'ACTIVE',
      ),
      academicYear: const AcademicYearEntity(
        id: 'ay_123',
        name: 'AY 2026',
        code: 'AY-2026',
        status: 'ACTIVE',
      ),
      schedule: const [], // Empty list of timetable assignments
    );

    final fakeRepo = FakeDashboardRepository(customData: customData);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isTestingProvider.overrideWithValue(true),
          bootstrapResultProvider.overrideWithValue(BootstrapResult(success: true)),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          sessionManagerProvider.overrideWithValue(FakeSessionManager()),
          dashboardRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const EduPulseApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Verify empty state is displayed
    expect(find.text('No timetable is currently assigned'), findsOneWidget);
  });

  testWidgets('No active academic year displays academic year error message',
      (WidgetTester tester) async {
    final fakeRepo = FakeDashboardRepository(
      shouldFail: true,
      failureMessage: 'No active academic year is configured for this school.',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isTestingProvider.overrideWithValue(true),
          bootstrapResultProvider.overrideWithValue(BootstrapResult(success: true)),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          sessionManagerProvider.overrideWithValue(FakeSessionManager()),
          dashboardRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const EduPulseApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Verify appropriate error screen is displayed
    expect(find.text('No active academic year is available'), findsOneWidget);
    expect(find.textContaining('An active academic year must be configured'), findsOneWidget);
  });

  testWidgets('API load failure shows generic error view and handles retry button click',
      (WidgetTester tester) async {
    final fakeRepo = FakeDashboardRepository(
      shouldFail: true,
      failureMessage: 'Network timeout connection issue.',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isTestingProvider.overrideWithValue(true),
          bootstrapResultProvider.overrideWithValue(BootstrapResult(success: true)),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          sessionManagerProvider.overrideWithValue(FakeSessionManager()),
          dashboardRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const EduPulseApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Verify error title and generic message
    expect(find.text('Dashboard Loading Failed'), findsOneWidget);
    expect(find.text('Network timeout connection issue.'), findsOneWidget);

    // Tap retry button
    final retryButton = find.text('Retry');
    expect(retryButton, findsOneWidget);
    await tester.tap(retryButton);
    await tester.pump();

    // Verify it called getDashboardData again
    expect(fakeRepo.callCount, equals(2));
  });

  testWidgets('Tapping Attendance quick action card displays period selector bottom sheet',
      (WidgetTester tester) async {
    final fakeRepo = FakeDashboardRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isTestingProvider.overrideWithValue(true),
          bootstrapResultProvider.overrideWithValue(BootstrapResult(success: true)),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          sessionManagerProvider.overrideWithValue(FakeSessionManager()),
          dashboardRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const EduPulseApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Verify Attendance quick action card exists
    final attendanceCard = find.text('Attendance');
    expect(attendanceCard, findsOneWidget);

    // Tap it
    await tester.tap(attendanceCard);
    await tester.pumpAndSettle();

    // Verify that the period selector bottom sheet appears with the title and available periods
    expect(find.text('Select Period for Attendance'), findsOneWidget);
    expect(find.text('Mathematics'), findsOneWidget);
    expect(find.text('Science'), findsOneWidget);

    // Tap a period to select it and confirm it navigates (dismisses bottom sheet)
    await tester.tap(find.widgetWithText(ListTile, 'Mathematics (Grade 8-Section A)'));
    await tester.pumpAndSettle();
    expect(find.text('Select Period for Attendance'), findsNothing);
  });
}
