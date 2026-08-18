import 'dart:io';
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
import 'package:teacher_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:teacher_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:teacher_app/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:teacher_app/features/dashboard/domain/entities/teacher_profile.dart';
import 'package:teacher_app/features/dashboard/domain/entities/academic_year.dart';
import 'package:teacher_app/features/dashboard/domain/entities/timetable_entry.dart';


class FakeAuthRepository implements AuthRepository {
  final List<String> userRoles;
  final bool shouldFailLogin;
  final bool shouldFailLogout;
  final bool shouldFailValidateSession;

  FakeAuthRepository({
    this.userRoles = const ['TEACHER'],
    this.shouldFailLogin = false,
    this.shouldFailLogout = false,
    this.shouldFailValidateSession = false,
  });

  @override
  Future<ApiResult<SessionToken>> login({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    if (shouldFailLogin) {
      return const ApiResult.failure(
        ApiFailure(
          message: 'Invalid credentials',
          type: ApiFailureType.unauthorized,
          statusCode: 401,
        ),
      );
    }
    return const ApiResult.success(
      SessionToken(
        accessToken: 'access',
        refreshToken: 'refresh',
        tokenType: 'bearer',
      ),
    );
  }

  @override
  Future<ApiResult<void>> logout({required String refreshToken}) async {
    if (shouldFailLogout) {
      return const ApiResult.failure(
        ApiFailure(
          message: 'Logout failed on server',
          type: ApiFailureType.unknown,
          statusCode: 500,
        ),
      );
    }
    return const ApiResult.success(null);
  }

  @override
  Future<ApiResult<SessionToken>> refreshToken({
    required String refreshToken,
  }) async {
    return const ApiResult.success(
      SessionToken(
        accessToken: 'access_new',
        refreshToken: 'refresh_new',
        tokenType: 'bearer',
      ),
    );
  }

  @override
  Future<ApiResult<UserEntity>> getCurrentUser() async {
    if (shouldFailValidateSession) {
      return const ApiResult.failure(
        ApiFailure(
          message: 'Session expired',
          type: ApiFailureType.unauthorized,
          statusCode: 401,
        ),
      );
    }
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
  final bool _shouldHaveSession;
  String? cachedSchoolId;

  FakeSessionManager({bool hasSession = true})
      : _shouldHaveSession = hasSession;

  @override
  Future<String?> getAccessToken() async => 'access';

  @override
  Future<String?> getRefreshToken() async => 'refresh';

  @override
  Future<void> saveSession(SessionToken token) async {}

  @override
  Future<void> clearSession() async {}

  @override
  Future<bool> hasSession() async => _shouldHaveSession;

  @override
  Future<String?> getSchoolId() async => cachedSchoolId;

  @override
  Future<void> saveSchoolId(String schoolId) async {
    cachedSchoolId = schoolId;
  }
}

class FakeBaseApiClient extends BaseApiClient {
  final bool simulateUnreachable;

  FakeBaseApiClient({this.simulateUnreachable = false}) : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (simulateUnreachable) {
      throw const SocketException('Connection refused');
    }
    return ApiResult.failure(const ApiFailure(
      message: 'Not mocked',
      type: ApiFailureType.unknown,
      statusCode: 404,
    ));
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
    if (simulateUnreachable) {
      throw const SocketException('Connection refused');
    }
    return ApiResult.failure(const ApiFailure(
      message: 'Not mocked',
      type: ApiFailureType.unknown,
      statusCode: 404,
    ));
  }
}

class FakeDashboardRepository implements DashboardRepository {
  @override
  Future<ApiResult<DashboardDataEntity>> getDashboardData({
    required String schoolId,
    required String email,
  }) async {
    return const ApiResult.success(
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
            id: 't_slot_1',
            dayOfWeek: 'MONDAY',
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
        ],
      ),
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App with active session for Teacher routes to Home',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isTestingProvider.overrideWithValue(true),
          bootstrapResultProvider.overrideWithValue(
            BootstrapResult(success: true),
          ),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(userRoles: const ['TEACHER']),
          ),
          sessionManagerProvider.overrideWithValue(
            FakeSessionManager(hasSession: true),
          ),
          dashboardRepositoryProvider.overrideWithValue(
            FakeDashboardRepository(),
          ),
        ],
        child: const EduPulseApp(),
      ),
    );

    // Allow splash loader & animation delay
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Class Timetable'), findsOneWidget);
    expect(find.text('Sarah Connor'), findsOneWidget);
    expect(find.text('Senior Lecturer • Science Department'), findsOneWidget);
  });

  testWidgets('App with active session for Non-Teacher routes to Access Denied',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isTestingProvider.overrideWithValue(true),
          bootstrapResultProvider.overrideWithValue(
            BootstrapResult(success: true),
          ),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(userRoles: const ['PARENT']),
          ),
          sessionManagerProvider.overrideWithValue(
            FakeSessionManager(hasSession: true),
          ),
        ],
        child: const EduPulseApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Access Denied'), findsOneWidget);
    expect(find.textContaining('Insufficient role permissions'), findsOneWidget);
  });

  testWidgets('Empty fields show form validation errors on login screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isTestingProvider.overrideWithValue(true),
          bootstrapResultProvider.overrideWithValue(
            BootstrapResult(success: true),
          ),
          sessionManagerProvider.overrideWithValue(
            FakeSessionManager(hasSession: false),
          ),
        ],
        child: const EduPulseApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Tap Login button without inputs
    final loginButton = find.widgetWithText(ElevatedButton, 'Login');
    expect(loginButton, findsOneWidget);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('Invalid email format displays validation error',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isTestingProvider.overrideWithValue(true),
          bootstrapResultProvider.overrideWithValue(
            BootstrapResult(success: true),
          ),
          sessionManagerProvider.overrideWithValue(
            FakeSessionManager(hasSession: false),
          ),
        ],
        child: const EduPulseApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Fill invalid email
    final emailField = find.widgetWithText(TextFormField, 'Email');
    await tester.enterText(emailField, 'invalid-email');

    // Tap Login button
    final loginButton = find.widgetWithText(ElevatedButton, 'Login');
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email address'), findsOneWidget);
  });

  testWidgets('Invalid credentials displays error snackbar',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isTestingProvider.overrideWithValue(true),
          bootstrapResultProvider.overrideWithValue(
            BootstrapResult(success: true),
          ),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(shouldFailLogin: true),
          ),
          sessionManagerProvider.overrideWithValue(
            FakeSessionManager(hasSession: false),
          ),
        ],
        child: const EduPulseApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Enter valid email and password format
    final emailField = find.widgetWithText(TextFormField, 'Email');
    await tester.enterText(emailField, 'wrong@edupulse.ai');
    final passwordField = find.widgetWithText(TextFormField, 'Password');
    await tester.enterText(passwordField, 'wrongpassword');

    // Tap Login
    final loginButton = find.widgetWithText(ElevatedButton, 'Login');
    await tester.tap(loginButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await tester.pumpAndSettle();

    // Snackbar should report the failure message
    expect(find.text('Invalid credentials'), findsOneWidget);
  });

  testWidgets('Logout trigger clears session and routes back to login',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isTestingProvider.overrideWithValue(true),
          bootstrapResultProvider.overrideWithValue(
            BootstrapResult(success: true),
          ),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(userRoles: const ['TEACHER']),
          ),
          sessionManagerProvider.overrideWithValue(
            FakeSessionManager(hasSession: true),
          ),
          dashboardRepositoryProvider.overrideWithValue(
            FakeDashboardRepository(),
          ),
        ],
        child: const EduPulseApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Verify Home screen is loaded
    expect(find.text('Class Timetable'), findsOneWidget);

    // Tap Logout button
    final logoutIcon = find.byIcon(Icons.logout_rounded);
    await tester.tap(logoutIcon);
    await tester.pumpAndSettle();

    // Confirmation dialog should appear
    expect(find.text('Confirm Logout'), findsOneWidget);
    expect(find.text('Are you sure you want to log out of the Teacher Portal?'), findsOneWidget);

    // Tap Confirm Logout in dialog
    final confirmLogoutButton = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(ElevatedButton, 'Logout'),
    );
    await tester.tap(confirmLogoutButton);
    await tester.pumpAndSettle();

    // Routes back to Login screen
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('App with invalid/expired saved session redirects to Login',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isTestingProvider.overrideWithValue(true),
          bootstrapResultProvider.overrideWithValue(
            BootstrapResult(success: true),
          ),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(shouldFailValidateSession: true),
          ),
          sessionManagerProvider.overrideWithValue(
            FakeSessionManager(hasSession: true),
          ),
        ],
        child: const EduPulseApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('Logout server failure still clears session locally and routes to Login',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isTestingProvider.overrideWithValue(true),
          bootstrapResultProvider.overrideWithValue(
            BootstrapResult(success: true),
          ),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(userRoles: const ['TEACHER'], shouldFailLogout: true),
          ),
          sessionManagerProvider.overrideWithValue(
            FakeSessionManager(hasSession: true),
          ),
          dashboardRepositoryProvider.overrideWithValue(
            FakeDashboardRepository(),
          ),
        ],
        child: const EduPulseApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Verify Home screen is loaded
    expect(find.text('Class Timetable'), findsOneWidget);

    // Tap Logout button
    final logoutIcon = find.byIcon(Icons.logout_rounded);
    await tester.tap(logoutIcon);
    await tester.pumpAndSettle();

    // Confirmation dialog should appear
    expect(find.text('Confirm Logout'), findsOneWidget);
    expect(find.text('Are you sure you want to log out of the Teacher Portal?'), findsOneWidget);

    // Tap Confirm Logout in dialog
    final confirmLogoutButton = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(ElevatedButton, 'Logout'),
    );
    await tester.tap(confirmLogoutButton);
    await tester.pumpAndSettle();

    // Routes back to Login screen
    expect(find.text('Login'), findsOneWidget);
  });
}
