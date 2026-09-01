import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:parent_app/app.dart';
import 'package:parent_app/core/providers/bootstrap_provider.dart';
import 'package:parent_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:parent_app/features/dashboard/domain/entities/outstanding_class.dart';
import 'package:parent_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:parent_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:parent_app/features/attendance/domain/entities/attendance_record.dart';
import 'package:parent_app/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:parent_app/features/attendance/presentation/providers/attendance_provider.dart';
import 'package:parent_app/features/homework/domain/entities/homework.dart';
import 'package:parent_app/features/homework/domain/repositories/homework_repository.dart';
import 'package:parent_app/features/homework/presentation/providers/homework_provider.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Future<ApiResult<SessionToken>> login({
    required String email,
    required String password,
  }) async {
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
    return const ApiResult.success(
      UserEntity(
        id: '123',
        email: 'parent@edupulse.ai',
        firstName: 'John',
        lastName: 'Doe',
        tenantId: '00000000-0000-0000-0000-000000000000',
        isSuperuser: false,
        roles: ['parent'],
        schools: ['school_1'],
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

  final bool _shouldHaveSession;

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
  Future<String?> getSchoolId() async => 'school_1';

  @override
  Future<void> saveSchoolId(String schoolId) async {}
}

class FakeDashboardRepository implements DashboardRepository {
  @override
  Future<ApiResult<DashboardSummaryEntity>> getDashboardSummary({
    required String schoolId,
  }) async {
    return const ApiResult.success(
      DashboardSummaryEntity(
        todayCollection: 1200,
        monthCollection: 45000,
        pendingDues: 8500,
        collectionPercentage: 84.1,
        defaultersCount: 3,
        topOutstandingClasses: [
          OutstandingClassEntity(
              className: 'Class 10-A', outstandingAmount: 5000),
          OutstandingClassEntity(
              className: 'Class 9-B', outstandingAmount: 3500),
        ],
      ),
    );
  }
}

class FakeAttendanceRepository implements AttendanceRepository {
  @override
  Future<ApiResult<List<AttendanceRecordEntity>>> getAttendanceRecords({
    required String studentId,
    required String academicYearId,
    required String schoolId,
  }) async {
    return ApiResult.success([
      AttendanceRecordEntity(
        id: '1',
        studentId: studentId,
        date: DateTime.now(),
        status: AttendanceStatus.present,
        remarks: 'On time',
      ),
      AttendanceRecordEntity(
        id: '2',
        studentId: studentId,
        date: DateTime.now().subtract(const Duration(days: 1)),
        status: AttendanceStatus.absent,
        remarks: 'Sick leave',
      ),
    ]);
  }
}

class FakeHomeworkRepository implements HomeworkRepository {
  @override
  Future<ApiResult<List<HomeworkEntity>>> getHomeworkRecords({
    required String schoolId,
    bool forceRefresh = false,
  }) async {
    return ApiResult.success([
      HomeworkEntity(
        id: 'h1',
        title: 'Math Algebra Assignment',
        description: 'Complete questions 1 to 10 on page 42.',
        dueDate: DateTime.now().add(const Duration(days: 2)),
        priority: HomeworkPriority.high,
        status: HomeworkStatus.published,
        attachmentUrl: 'https://example.com/algebra.pdf',
        subjectId: 'Math',
        classId: 'Class 10',
        sectionId: 'Section A',
      ),
    ]);
  }
}

class FakeBaseApiClient extends BaseApiClient {
  FakeBaseApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (path == '/guardians') {
      return ApiResult.success(mapper({
        'data': [
          {'id': 'guardian_1'}
        ]
      }));
    }
    if (path == '/student-guardians') {
      return ApiResult.success(mapper({
        'data': [
          {'student_id': 'student_1'}
        ]
      }));
    }
    if (path.startsWith('/students/')) {
      return ApiResult.success(mapper({
        'data': {
          'first_name': 'Aarav',
          'last_name': 'Kumar',
          'admission_number': 'ADM2026089',
          'class_id': 'Class 8',
          'section_id': 'A',
          'academic_year_id': 'academic_2026',
          'class_name': 'Class 8',
          'section_name': 'Section A',
        }
      }));
    }
    if (path == '/attendances/student') {
      return ApiResult.success(mapper({
        'data': [
          {'attendance_status': 'PRESENT'},
          {'attendance_status': 'PRESENT'},
          {'attendance_status': 'ABSENT'},
        ]
      }));
    }
    if (path == '/homeworks/parent') {
      return ApiResult.success(mapper({
        'data': [
          {'class_id': 'Class 8', 'section_id': 'A'},
          {'class_id': 'Class 8', 'section_id': 'A'},
        ]
      }));
    }
    if (path == '/examinations/parent') {
      return ApiResult.success(mapper({
        'data': [
          {'exam_date': '2026-10-02', 'room_number': '101', 'class_id': 'Class 8', 'section_id': 'A'},
        ]
      }));
    }
    if (path == '/notifications') {
      return ApiResult.success(mapper({
        'data': [
          {'notification_type': 'ANNOUNCEMENT', 'title': 'Notice', 'message': 'Announcements details'}
        ]
      }));
    }
    if (path.contains('/fees/ledgers/')) {
      return ApiResult.success(mapper({
        'data': {
          'student_id': 'student_1',
          'opening_balance': 0.0,
          'assignments': [],
          'payments': [],
          'closing_balance': 0.0,
        }
      }));
    }
    if (path.contains('/report-cards/student/')) {
      return ApiResult.success(mapper({
        'data': {
          'id': 'rc_1',
          'status': 'PUBLISHED',
          'pdf_url': '/static/report_cards/report.pdf',
          'published_at': '2026-08-02',
          'ai_metrics': {
            'risk_level': 'LOW',
            'ai_narrative': 'Test narrative'
          }
        }
      }));
    }
    return ApiResult.failure(const ApiFailure(message: 'Unknown endpoint in mock', type: ApiFailureType.unknown, statusCode: 400));
  }
}

void main() {
  testWidgets('App with active session routes to Dashboard',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapResultProvider.overrideWithValue(
            BootstrapResult(success: true),
          ),
          apiClientProvider.overrideWithValue(FakeBaseApiClient()),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          sessionManagerProvider.overrideWithValue(
            FakeSessionManager(hasSession: true),
          ),
          dashboardRepositoryProvider
              .overrideWithValue(FakeDashboardRepository()),
          attendanceRepositoryProvider
              .overrideWithValue(FakeAttendanceRepository()),
          homeworkRepositoryProvider
              .overrideWithValue(FakeHomeworkRepository()),
        ],
        child: const EduPulseApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Aarav Kumar'), findsOneWidget);
    expect(find.text('₹8,500'), findsOneWidget);
  });

  testWidgets('App without active session routes to Login Screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapResultProvider.overrideWithValue(
            BootstrapResult(success: true),
          ),
          apiClientProvider.overrideWithValue(FakeBaseApiClient()),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          sessionManagerProvider.overrideWithValue(
            FakeSessionManager(hasSession: false),
          ),
          dashboardRepositoryProvider
              .overrideWithValue(FakeDashboardRepository()),
          attendanceRepositoryProvider
              .overrideWithValue(FakeAttendanceRepository()),
          homeworkRepositoryProvider
              .overrideWithValue(FakeHomeworkRepository()),
        ],
        child: const EduPulseApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('App can navigate to Attendance Screen and render stats',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapResultProvider.overrideWithValue(
            BootstrapResult(success: true),
          ),
          apiClientProvider.overrideWithValue(FakeBaseApiClient()),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          sessionManagerProvider.overrideWithValue(
            FakeSessionManager(hasSession: true),
          ),
          dashboardRepositoryProvider
              .overrideWithValue(FakeDashboardRepository()),
          attendanceRepositoryProvider
              .overrideWithValue(FakeAttendanceRepository()),
          homeworkRepositoryProvider
              .overrideWithValue(FakeHomeworkRepository()),
        ],
        child: const EduPulseApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);

    final attendanceButton = find.text('Attendance');
    expect(attendanceButton, findsOneWidget);
    await tester.tap(attendanceButton);
    await tester.pumpAndSettle();

    expect(find.text('Attendance Percentage'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('App can navigate to Homework Screen and render details',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapResultProvider.overrideWithValue(
            BootstrapResult(success: true),
          ),
          apiClientProvider.overrideWithValue(FakeBaseApiClient()),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          sessionManagerProvider.overrideWithValue(
            FakeSessionManager(hasSession: true),
          ),
          dashboardRepositoryProvider
              .overrideWithValue(FakeDashboardRepository()),
          attendanceRepositoryProvider
              .overrideWithValue(FakeAttendanceRepository()),
          homeworkRepositoryProvider
              .overrideWithValue(FakeHomeworkRepository()),
        ],
        child: const EduPulseApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);

    final homeworkButton = find.text('Homework');
    expect(homeworkButton, findsOneWidget);
    await tester.tap(homeworkButton);
    await tester.pumpAndSettle();

    expect(find.text('Math Algebra Assignment'), findsOneWidget);
    expect(find.text('Complete questions 1 to 10 on page 42.'), findsOneWidget);
  });
}
