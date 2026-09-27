import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:teacher_app/core/providers/school_context_provider.dart';
import 'package:teacher_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:teacher_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:teacher_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:teacher_app/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:teacher_app/features/dashboard/domain/entities/teacher_profile.dart';
import 'package:teacher_app/features/dashboard/domain/entities/academic_year.dart';
import 'package:teacher_app/features/my_classes/domain/repositories/my_classes_repository.dart';
import 'package:teacher_app/features/my_classes/presentation/providers/my_classes_provider.dart';
import 'package:teacher_app/features/my_classes/domain/entities/teacher_class_group.dart';
import 'package:teacher_app/features/my_classes/domain/entities/student.dart';
import 'package:teacher_app/features/student_directory/presentation/providers/student_directory_provider.dart';
import 'package:teacher_app/features/homework/presentation/providers/homework_provider.dart';

class FakeSessionManager implements SessionManager {
  String? cachedSchoolId;
  String? cachedSchoolName;
  String? cachedTenantId;

  @override
  Future<String?> getSchoolId() async => cachedSchoolId;

  @override
  Future<void> saveSchoolId(String schoolId) async {
    cachedSchoolId = schoolId;
  }

  @override
  Future<String?> getSchoolName() async => cachedSchoolName;

  @override
  Future<void> saveSchoolName(String schoolName) async {
    cachedSchoolName = schoolName;
  }

  @override
  Future<String?> getTenantId() async => cachedTenantId;

  @override
  Future<void> saveTenantId(String tenantId) async {
    cachedTenantId = tenantId;
  }

  @override
  Future<String?> getAccessToken() async => 'access_token';

  @override
  Future<String?> getRefreshToken() async => 'refresh_token';

  @override
  Future<void> saveSession(SessionToken token) async {}

  @override
  Future<void> clearSession([String source = 'SessionManager.clearSession']) async {}

  @override
  Future<bool> hasSession() async => true;

  @override
  Future<String?> getTenantName() async => 'Test Tenant';

  @override
  Future<void> saveTenantName(String tenantName) async {}
}

class ControllableDashboardRepository implements DashboardRepository {
  Completer<ApiResult<DashboardDataEntity>> completerA = Completer<ApiResult<DashboardDataEntity>>();
  Completer<ApiResult<DashboardDataEntity>> completerB = Completer<ApiResult<DashboardDataEntity>>();
  int callCount = 0;
  String? lastRequestedSchoolId;

  void reset() {
    completerA = Completer<ApiResult<DashboardDataEntity>>();
    completerB = Completer<ApiResult<DashboardDataEntity>>();
    callCount = 0;
    lastRequestedSchoolId = null;
  }

  @override
  Future<ApiResult<DashboardDataEntity>> getDashboardData({
    required String schoolId,
    required String email,
  }) {
    callCount++;
    lastRequestedSchoolId = schoolId;
    if (schoolId == 'school_A') {
      return completerA.future;
    } else {
      return completerB.future;
    }
  }
}

class FakeMyClassesRepository implements MyClassesRepository {
  int classCallCount = 0;
  String? lastRequestedSchoolId;

  @override
  Future<ApiResult<List<TeacherClassGroupEntity>>> getTeacherClasses({
    required String schoolId,
    required String academicYearId,
    required String teacherId,
  }) async {
    classCallCount++;
    lastRequestedSchoolId = schoolId;
    return ApiResult.success([
      TeacherClassGroupEntity(
        classId: 'class_1',
        className: 'Class 10 ($schoolId)',
        sectionId: 'sec_A',
        sectionName: 'A',
        assignments: const [],
      ),
    ]);
  }

  @override
  Future<ApiResult<List<StudentEntity>>> getClassStudents({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String sectionId,
  }) async {
    return const ApiResult.success([]);
  }

  @override
  Future<ApiResult<List<StudentEntity>>> getTeacherStudents({
    required String schoolId,
    required String academicYearId,
  }) async {
    return const ApiResult.success([]);
  }
}

DashboardDataEntity createMockDashboardData(String schoolId) {
  return DashboardDataEntity(
    teacherProfile: const TeacherProfileEntity(
      id: 'teacher_123',
      employeeCode: 'EMP-001',
      firstName: 'Sarah',
      lastName: 'Connor',
      designation: 'Senior Lecturer',
      department: 'Science',
      officialEmail: 'teacher@edupulse.ai',
      mobile: '1234567890',
      status: 'ACTIVE',
    ),
    academicYear: AcademicYearEntity(
      id: 'ay_$schoolId',
      name: '2025-2026',
      code: 'AY-2025-26',
      status: 'ACTIVE',
    ),
    schedule: const [],
  );
}

void main() {
  late ProviderContainer container;
  late FakeSessionManager sessionManager;
  late ControllableDashboardRepository dashboardRepo;
  late FakeMyClassesRepository myClassesRepo;

  const multiSchoolUser = UserEntity(
    id: 'teacher_123',
    email: 'teacher@edupulse.ai',
    firstName: 'Sarah',
    lastName: 'Connor',
    tenantId: 'tenant_1',
    isSuperuser: false,
    roles: ['TEACHER'],
    schools: const ['school_A', 'school_B'],
    schoolNames: const {
      'school_A': 'Primary Campus A',
      'school_B': 'Secondary Campus B',
    },
  );

  setUp(() {
    sessionManager = FakeSessionManager();
    dashboardRepo = ControllableDashboardRepository();
    myClassesRepo = FakeMyClassesRepository();

    container = ProviderContainer(
      overrides: [
        sessionManagerProvider.overrideWithValue(sessionManager),
        dashboardRepositoryProvider.overrideWithValue(dashboardRepo),
        myClassesRepositoryProvider.overrideWithValue(myClassesRepo),
      ],
    );

    // Seed authenticated state with multi-school teacher
    container.read(authStateProvider.notifier).setAuthenticated(multiSchoolUser);
  });

  tearDown(() {
    container.dispose();
  });

  group('Multi-School Context & Cache Isolation Audit', () {
    test('Default active school derives from authState.user.schools.first', () {
      final activeSchool = container.read(activeSchoolIdProvider);
      final activeName = container.read(activeSchoolNameProvider);

      expect(activeSchool, equals('school_A'));
      expect(activeName, equals('Primary Campus A'));
    });

    test('switchSchool updates activeSchoolId, activeSchoolName, and persists to sessionManager', () async {
      final controller = container.read(schoolContextControllerProvider);

      // Trigger initial dashboard load for school_A
      final futureA = container.read(dashboardStateProvider.notifier).fetchDashboard();
      dashboardRepo.completerA.complete(ApiResult.success(createMockDashboardData('school_A')));
      await futureA;

      expect(container.read(activeSchoolIdProvider), equals('school_A'));
      expect(container.read(dashboardStateProvider), isA<DashboardSuccess>());

      // Switch context to school_B
      final switchFuture = controller.switchSchool('school_B');
      // Complete newly triggered dashboard request for school_B
      dashboardRepo.completerB.complete(ApiResult.success(createMockDashboardData('school_B')));
      await switchFuture;

      expect(container.read(activeSchoolIdProvider), equals('school_B'));
      expect(container.read(activeSchoolNameProvider), equals('Secondary Campus B'));
      expect(sessionManager.cachedSchoolId, equals('school_B'));
      expect(sessionManager.cachedSchoolName, equals('Secondary Campus B'));

      // Verify dashboard was reloaded for school_B
      final dashState = container.read(dashboardStateProvider);
      expect(dashState, isA<DashboardSuccess>());
      expect((dashState as DashboardSuccess).data.academicYear.id, equals('ay_school_B'));
    });

    test('switchSchool invalidates stale school-scoped providers', () async {
      final controller = container.read(schoolContextControllerProvider);

      // Simulate student directory having state
      expect(container.read(studentDirectoryStateProvider), isA<StudentDirectoryInitial>());
      expect(container.read(homeworkListProvider), isA<HomeworkListInitial>());

      // Perform switch
      final switchFuture = controller.switchSchool('school_B');
      dashboardRepo.completerB.complete(ApiResult.success(createMockDashboardData('school_B')));
      await switchFuture;

      // Ensure providers are fresh and reset
      expect(container.read(studentDirectoryStateProvider), isA<StudentDirectoryInitial>());
      expect(container.read(homeworkListProvider), isA<HomeworkListInitial>());
    });

    test('In-flight response for school_A is safely rejected if school switches to school_B before response arrives', () async {
      // 1. Initiate fetch for school_A (slow response)
      final fetchFutureSchoolA = container.read(dashboardStateProvider.notifier).fetchDashboard();
      expect(dashboardRepo.lastRequestedSchoolId, equals('school_A'));

      // 2. User immediately switches active school to school_B while school_A is still in-flight
      container.read(activeSchoolIdProvider.notifier).state = 'school_B';

      // 3. Late response arrives for school_A
      dashboardRepo.completerA.complete(ApiResult.success(createMockDashboardData('school_A')));
      await fetchFutureSchoolA;

      // 4. Verification: The stale school_A response MUST be discarded!
      final currentState = container.read(dashboardStateProvider);
      // It should NOT be DashboardSuccess with school_A data
      if (currentState is DashboardSuccess) {
        expect(currentState.data.academicYear.id, isNot('ay_school_A'));
      } else {
        expect(currentState, isA<DashboardLoading>());
      }
    });
  });
}
