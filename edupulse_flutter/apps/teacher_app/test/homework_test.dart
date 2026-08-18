import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

import 'package:teacher_app/features/homework/domain/entities/homework_entity.dart';
import 'package:teacher_app/features/homework/domain/repositories/homework_repository.dart';
import 'package:teacher_app/features/homework/presentation/providers/homework_provider.dart';

// --- AUTH REPO FAKE ---
class FakeAuthRepository implements AuthRepository {
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
    return const ApiResult.success(
      UserEntity(
        id: 'teacher_123',
        email: 'teacher@edupulse.ai',
        firstName: 'Sarah',
        lastName: 'Connor',
        tenantId: 'd09b9362-3dc8-422d-a441-160735fcea96',
        isSuperuser: false,
        roles: ['TEACHER'],
        schools: ['16730f87-bf8d-44e0-acf9-4b055a778b58'],
      ),
    );
  }

  @override
  Future<ApiResult<void>> requestPasswordReset({required String email}) async {
    return const ApiResult.success(null);
  }
}

class FakeSessionManager implements SessionManager {
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
  Future<void> saveSchoolId(String schoolId) async {}
}

// --- DASHBOARD REPO FAKE ---
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
          employeeCode: 'EMP123',
          firstName: 'Sarah',
          lastName: 'Connor',
          officialEmail: 'teacher@edupulse.ai',
          mobile: '9876543210',
          status: 'ACTIVE',
        ),
        academicYear: AcademicYearEntity(
          id: '113282c1-9831-4e54-a00e-1746d3c2829d',
          name: '2026-2027',
          code: 'AY2627',
          status: 'ACTIVE',
        ),
        schedule: [
          TimetableEntryEntity(
            id: 'timetable_1',
            dayOfWeek: 'MONDAY',
            periodNumber: 1,
            startTime: '09:00',
            endTime: '09:45',
            periodType: 'CLASS',
            isAvailable: true,
            classId: 'class_9a',
            className: 'Class 9',
            sectionId: 'section_a',
            sectionName: 'A',
            subjectId: 'subject_math',
            subjectName: 'Mathematics',
            subjectCode: 'MATH09',
            displayColor: '#FF5733',
          )
        ],
      ),
    );
  }
}

// --- MY CLASSES REPO FAKE ---
class FakeMyClassesRepository implements MyClassesRepository {
  @override
  Future<ApiResult<List<TeacherClassGroupEntity>>> getTeacherClasses({
    required String schoolId,
    required String academicYearId,
    required String teacherId,
  }) async {
    return const ApiResult.success([
      TeacherClassGroupEntity(
        classId: 'class_9a',
        className: 'Class 9',
        sectionId: 'section_a',
        sectionName: 'A',
        assignments: [
          TeacherSubjectAssignmentEntity(
            id: 'tsa_1',
            subjectId: 'subject_math',
            subjectName: 'Mathematics',
            subjectCode: 'MATH09',
            displayColor: '#FF5733',
            isClassTeacher: true,
          )
        ],
      )
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
  Future<ApiResult<StudentEntity>> getStudentDetails({
    required String schoolId,
    required String studentId,
  }) async {
    return ApiResult.failure(ApiFailure(
      message: 'Not implemented',
      type: ApiFailureType.unknown,
      statusCode: 500,
    ));
  }
}

// --- HOMEWORK REPO FAKE ---
class FakeHomeworkRepository implements HomeworkRepository {
  final List<HomeworkEntity> mockHomeworks = [];

  FakeHomeworkRepository() {
    // Add seed data
    mockHomeworks.add(
      HomeworkEntity(
        id: 'hw_1',
        tenantId: 'tenant_1',
        schoolId: '16730f87-bf8d-44e0-acf9-4b055a778b58',
        academicYearId: '113282c1-9831-4e54-a00e-1746d3c2829d',
        teacherId: 'teacher_123',
        teacherSubjectAssignmentId: 'tsa_1',
        subjectId: 'subject_math',
        classId: 'class_9a',
        sectionId: 'section_a',
        title: 'Algebra homework',
        description: 'Complete page 12 of textbook',
        dueDate: DateTime.now().add(const Duration(days: 2)),
        priority: HomeworkPriority.NORMAL,
        status: HomeworkStatus.PUBLISHED,
        isActive: true,
        settings: const {},
        aiMetrics: const {},
        version: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<ApiResult<HomeworkEntity>> createHomework({
    required String schoolId,
    required String academicYearId,
    required String teacherId,
    required String teacherSubjectAssignmentId,
    required String subjectId,
    required String classId,
    required String sectionId,
    String? timetableId,
    required String title,
    required String description,
    required DateTime dueDate,
    required HomeworkPriority priority,
    required HomeworkStatus status,
    String? attachmentUrl,
    int? estimatedMinutes,
  }) async {
    final hw = HomeworkEntity(
      id: 'hw_new_${mockHomeworks.length}',
      tenantId: 'tenant_1',
      schoolId: schoolId,
      academicYearId: academicYearId,
      teacherId: teacherId,
      teacherSubjectAssignmentId: teacherSubjectAssignmentId,
      subjectId: subjectId,
      classId: classId,
      sectionId: sectionId,
      timetableId: timetableId,
      title: title,
      description: description,
      dueDate: dueDate,
      priority: priority,
      status: status,
      attachmentUrl: attachmentUrl,
      estimatedMinutes: estimatedMinutes,
      isActive: true,
      settings: const {},
      aiMetrics: const {},
      version: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    mockHomeworks.add(hw);
    return ApiResult.success(hw);
  }

  @override
  Future<ApiResult<HomeworkEntity>> createFromTimetable({
    required String schoolId,
    required String timetableId,
    required String title,
    required String description,
    required DateTime dueDate,
    required HomeworkPriority priority,
    required HomeworkStatus status,
    String? attachmentUrl,
    int? estimatedMinutes,
  }) async {
    return createHomework(
      schoolId: schoolId,
      academicYearId: '113282c1-9831-4e54-a00e-1746d3c2829d',
      teacherId: 'teacher_123',
      teacherSubjectAssignmentId: 'tsa_1',
      subjectId: 'subject_math',
      classId: 'class_9a',
      sectionId: 'section_a',
      timetableId: timetableId,
      title: title,
      description: description,
      dueDate: dueDate,
      priority: priority,
      status: status,
      attachmentUrl: attachmentUrl,
      estimatedMinutes: estimatedMinutes,
    );
  }

  @override
  Future<ApiResult<List<HomeworkEntity>>> copyHomework({
    required String schoolId,
    required String homeworkId,
    required List<String> targetSectionIds,
  }) async {
    final original = mockHomeworks.firstWhere((h) => h.id == homeworkId);
    final List<HomeworkEntity> copies = [];
    for (final secId in targetSectionIds) {
      final cp = original.copyWith(
        id: 'hw_copy_${mockHomeworks.length + copies.length}',
        sectionId: secId,
      );
      copies.add(cp);
    }
    mockHomeworks.addAll(copies);
    return ApiResult.success(copies);
  }

  @override
  Future<ApiResult<HomeworkEntity>> publishHomework({
    required String schoolId,
    required String id,
  }) async {
    final idx = mockHomeworks.indexWhere((h) => h.id == id);
    if (idx == -1) return ApiResult.failure(ApiFailure(message: 'Not found', type: ApiFailureType.unknown, statusCode: 500));
    final updated = mockHomeworks[idx].copyWith(status: HomeworkStatus.PUBLISHED);
    mockHomeworks[idx] = updated;
    return ApiResult.success(updated);
  }

  @override
  Future<ApiResult<List<HomeworkEntity>>> getRecentHomework({
    required String schoolId,
  }) async {
    return ApiResult.success(mockHomeworks);
  }

  @override
  Future<ApiResult<List<String>>> getTemplates({
    required String schoolId,
    String? subjectId,
  }) async {
    return const ApiResult.success(['Read Chapter', 'Solve Equations']);
  }

  @override
  Future<ApiResult<HomeworkEntity>> getHomeworkById({
    required String schoolId,
    required String id,
  }) async {
    final match = mockHomeworks.firstWhere((h) => h.id == id, orElse: () => throw Exception('Not found'));
    return ApiResult.success(match);
  }

  @override
  Future<ApiResult<List<HomeworkEntity>>> listHomeworks({
    required String schoolId,
    String? academicYearId,
    String? classId,
    String? sectionId,
    String? subjectId,
    String? teacherId,
    HomeworkStatus? status,
    String? search,
    int skip = 0,
    int limit = 100,
  }) async {
    var list = mockHomeworks.where((h) => h.schoolId == schoolId).toList();
    if (status != null) {
      list = list.where((h) => h.status == status).toList();
    }
    if (classId != null) {
      list = list.where((h) => h.classId == classId).toList();
    }
    if (sectionId != null) {
      list = list.where((h) => h.sectionId == sectionId).toList();
    }
    if (subjectId != null) {
      list = list.where((h) => h.subjectId == subjectId).toList();
    }
    if (search != null) {
      final term = search.toLowerCase();
      list = list.where((h) => h.title.toLowerCase().contains(term) || h.description.toLowerCase().contains(term)).toList();
    }
    return ApiResult.success(list);
  }

  @override
  Future<ApiResult<HomeworkEntity>> updateHomework({
    required String schoolId,
    required String id,
    String? title,
    String? description,
    DateTime? dueDate,
    HomeworkPriority? priority,
    HomeworkStatus? status,
    String? attachmentUrl,
    int? estimatedMinutes,
  }) async {
    final idx = mockHomeworks.indexWhere((h) => h.id == id);
    if (idx == -1) return ApiResult.failure(ApiFailure(message: 'Not found', type: ApiFailureType.unknown, statusCode: 500));
    final orig = mockHomeworks[idx];
    final updated = orig.copyWith(
      title: title ?? orig.title,
      description: description ?? orig.description,
      dueDate: dueDate ?? orig.dueDate,
      priority: priority ?? orig.priority,
      status: status ?? orig.status,
      attachmentUrl: attachmentUrl != null ? () => attachmentUrl : null,
      estimatedMinutes: estimatedMinutes != null ? () => estimatedMinutes : null,
    );
    mockHomeworks[idx] = updated;
    return ApiResult.success(updated);
  }

  @override
  Future<ApiResult<HomeworkEntity>> deleteHomework({
    required String schoolId,
    required String id,
  }) async {
    final match = mockHomeworks.firstWhere((h) => h.id == id);
    mockHomeworks.removeWhere((h) => h.id == id);
    return ApiResult.success(match);
  }
}

void main() {
  late ProviderContainer container;
  late FakeHomeworkRepository fakeHomeworkRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeHomeworkRepo = FakeHomeworkRepository();

    container = ProviderContainer(
      overrides: [
        isTestingProvider.overrideWithValue(true),
        bootstrapResultProvider.overrideWithValue(BootstrapResult(success: true)),
        sessionManagerProvider.overrideWithValue(FakeSessionManager()),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        dashboardRepositoryProvider.overrideWithValue(FakeDashboardRepository()),
        myClassesRepositoryProvider.overrideWithValue(FakeMyClassesRepository()),
        homeworkRepositoryProvider.overrideWithValue(fakeHomeworkRepo),
      ],
    );

    // Bootstrap app state
    await container.read(authStateProvider.notifier).checkAuth();
    await Future.delayed(Duration.zero); // Let async onSuccess callback complete and set Authenticated state
    await container.read(dashboardStateProvider.notifier).fetchDashboard();
  });

  tearDown(() {
    container.dispose();
  });

  group('Homework Provider Tests', () {
    test('fetchHomeworks returns success with correct status filtering', () async {
      final dbState = container.read(dashboardStateProvider);
      print('DEBUG: AuthState = ${container.read(authStateProvider)}');
      print('DEBUG: DashboardState = $dbState');
      if (dbState is DashboardError) {
        print('DEBUG: DashboardState Error Message = ${dbState.message}');
      }
      
      final state = container.read(homeworkListProvider);
      if (state is HomeworkListError) {
        print('DEBUG: HomeworkListError Message = ${state.message}');
      }

      final notifier = container.read(homeworkListProvider.notifier);
      await notifier.fetchHomeworks(status: HomeworkStatus.PUBLISHED);

      final endState = container.read(homeworkListProvider);
      if (endState is HomeworkListError) {
        print('DEBUG: End HomeworkListError Message = ${endState.message}');
      }
      expect(endState, isA<HomeworkListSuccess>());
      final success = endState as HomeworkListSuccess;
      expect(success.homeworks.length, 1);
      expect(success.homeworks.first.status, HomeworkStatus.PUBLISHED);
    });

    test('createHomework registers new homework entity', () async {
      final formNotifier = container.read(homeworkFormNotifierProvider.notifier);
      
      final success = await formNotifier.createHomework(
        title: 'New Algebra Sheet',
        description: 'Complete quadratics practice',
        dueDate: DateTime.now().add(const Duration(days: 3)),
        priority: HomeworkPriority.HIGH,
        status: HomeworkStatus.DRAFT,
        teacherSubjectAssignmentId: 'tsa_1',
        subjectId: 'subject_math',
        classId: 'class_9a',
        sectionId: 'section_a',
      );

      expect(success, true);
      expect(fakeHomeworkRepo.mockHomeworks.length, 2);
      expect(fakeHomeworkRepo.mockHomeworks.last.title, 'New Algebra Sheet');
      expect(fakeHomeworkRepo.mockHomeworks.last.status, HomeworkStatus.DRAFT);
    });

    test('createFromTimetable registers derived context homework', () async {
      final formNotifier = container.read(homeworkFormNotifierProvider.notifier);

      final success = await formNotifier.createFromTimetable(
        timetableId: 'timetable_1',
        title: 'Timetable Homework',
        description: 'Derived math assignment',
        dueDate: DateTime.now().add(const Duration(days: 4)),
        priority: HomeworkPriority.NORMAL,
        status: HomeworkStatus.PUBLISHED,
      );

      expect(success, true);
      expect(fakeHomeworkRepo.mockHomeworks.length, 2);
      expect(fakeHomeworkRepo.mockHomeworks.last.title, 'Timetable Homework');
      expect(fakeHomeworkRepo.mockHomeworks.last.timetableId, 'timetable_1');
    });

    test('copyToSections duplicates assignment across target sections', () async {
      final formNotifier = container.read(homeworkFormNotifierProvider.notifier);

      final success = await formNotifier.copyToSections(
        homeworkId: 'hw_1',
        targetSectionIds: ['section_b', 'section_c'],
      );

      expect(success, true);
      // Had 1, copied to 2 sections -> total should be 3
      expect(fakeHomeworkRepo.mockHomeworks.length, 3);
      expect(fakeHomeworkRepo.mockHomeworks[1].sectionId, 'section_b');
      expect(fakeHomeworkRepo.mockHomeworks[2].sectionId, 'section_c');
    });

    test('publishHomework transitions DRAFT assignment', () async {
      // Create a draft first
      final formNotifier = container.read(homeworkFormNotifierProvider.notifier);
      await formNotifier.createHomework(
        title: 'Draft Work',
        description: 'Some text',
        dueDate: DateTime.now().add(const Duration(days: 3)),
        priority: HomeworkPriority.LOW,
        status: HomeworkStatus.DRAFT,
        teacherSubjectAssignmentId: 'tsa_1',
        subjectId: 'subject_math',
        classId: 'class_9a',
        sectionId: 'section_a',
      );

      final draftId = fakeHomeworkRepo.mockHomeworks.last.id;
      final detailNotifier = container.read(homeworkDetailProvider(draftId).notifier);
      
      final success = await detailNotifier.publish();
      expect(success, true);

      final state = container.read(homeworkDetailProvider(draftId));
      expect(state, isA<HomeworkDetailSuccess>());
      expect((state as HomeworkDetailSuccess).homework.status, HomeworkStatus.PUBLISHED);
    });

    test('deleteHomework soft-deletes from repository', () async {
      final detailNotifier = container.read(homeworkDetailProvider('hw_1').notifier);
      final success = await detailNotifier.delete();
      
      expect(success, true);
      expect(fakeHomeworkRepo.mockHomeworks.any((h) => h.id == 'hw_1'), false);
    });
  });
}
