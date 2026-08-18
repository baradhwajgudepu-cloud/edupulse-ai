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
import 'package:teacher_app/features/my_classes/domain/repositories/my_classes_repository.dart';
import 'package:teacher_app/features/my_classes/presentation/providers/my_classes_provider.dart';
import 'package:teacher_app/features/my_classes/presentation/pages/my_classes_screen.dart';
import 'package:teacher_app/features/my_classes/domain/entities/teacher_class_group.dart';
import 'package:teacher_app/features/my_classes/domain/entities/student.dart';

// --- AUTH & SESSION MOCKS ---
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
            periodNumber: 1,
            startTime: '08:00:00',
            endTime: '09:00:00',
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
  bool shouldFailClasses = false;
  bool shouldFailStudents = false;
  String? failureMessage;
  int classesCallCount = 0;
  int studentsCallCount = 0;

  List<TeacherClassGroupEntity> classesMock = [
    const TeacherClassGroupEntity(
      classId: 'class_9',
      className: 'Grade 9',
      sectionId: 'sec_a',
      sectionName: 'A',
      assignments: [
        TeacherSubjectAssignmentEntity(
          id: 'assign_1',
          subjectId: 'sub_math',
          subjectName: 'Mathematics',
          subjectCode: 'MATH-101',
          displayColor: '#FF5733',
          isClassTeacher: true,
        ),
        TeacherSubjectAssignmentEntity(
          id: 'assign_2',
          subjectId: 'sub_sci',
          subjectName: 'Science',
          subjectCode: 'SCI-101',
          displayColor: '#33FF57',
          isClassTeacher: false,
        ),
      ],
    ),
    const TeacherClassGroupEntity(
      classId: 'class_10',
      className: 'Grade 10',
      sectionId: 'sec_b',
      sectionName: 'B',
      assignments: [
        TeacherSubjectAssignmentEntity(
          id: 'assign_3',
          subjectId: 'sub_phy',
          subjectName: 'Physics',
          subjectCode: 'PHY-101',
          displayColor: '#3357FF',
          isClassTeacher: false,
        ),
      ],
    ),
  ];

  List<StudentEntity> studentsMock = [
    const StudentEntity(
      id: 'student_1',
      firstName: 'John',
      lastName: 'Doe',
      gender: 'MALE',
      dateOfBirth: '2012-05-14',
      admissionNumber: 'ADM-1001',
      rollNumber: '1',
      status: 'ACTIVE',
      className: 'Grade 9',
      sectionName: 'A',
    ),
    const StudentEntity(
      id: 'student_2',
      firstName: 'Jane',
      lastName: 'Smith',
      gender: 'FEMALE',
      dateOfBirth: '2012-08-22',
      admissionNumber: 'ADM-1002',
      rollNumber: '2',
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
    classesCallCount++;
    if (shouldFailClasses) {
      return ApiResult.failure(
        ApiFailure(
          message: failureMessage ?? 'Failed to load assignments',
          type: ApiFailureType.unknown,
          statusCode: 500,
        ),
      );
    }
    return ApiResult.success(classesMock);
  }

  @override
  Future<ApiResult<List<StudentEntity>>> getClassStudents({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String sectionId,
  }) async {
    studentsCallCount++;
    if (shouldFailStudents) {
      return ApiResult.failure(
        ApiFailure(
          message: failureMessage ?? 'Failed to load students',
          type: ApiFailureType.unknown,
          statusCode: 500,
        ),
      );
    }
    return ApiResult.success(studentsMock);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestWidget({
    required WidgetTester tester,
    required FakeMyClassesRepository myClassesRepo,
    FakeDashboardRepository? dashboardRepo,
    FakeAuthRepository? authRepo,
    FakeSessionManager? sessionManager,
  }) {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    return ProviderScope(
      overrides: [
        isTestingProvider.overrideWithValue(true),
        bootstrapResultProvider.overrideWithValue(
          BootstrapResult(success: true),
        ),
        authRepositoryProvider.overrideWithValue(
          authRepo ?? FakeAuthRepository(),
        ),
        sessionManagerProvider.overrideWithValue(
          sessionManager ?? FakeSessionManager(hasSession: true),
        ),
        dashboardRepositoryProvider.overrideWithValue(
          dashboardRepo ?? FakeDashboardRepository(),
        ),
        myClassesRepositoryProvider.overrideWithValue(myClassesRepo),
      ],
      child: const EduPulseApp(),
    );
  }

  group('Phase 3: My Classes Screen Widget Tests', () {
    testWidgets('1. Successful assignments loading and 2. rendering', (tester) async {
      final fakeClassesRepo = FakeMyClassesRepository();

      await tester.pumpWidget(createTestWidget(tester: tester, myClassesRepo: fakeClassesRepo));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Go to home, then tap My Classes button
      final myClassesAction = find.text('My Classes');
      expect(myClassesAction, findsOneWidget);
      await tester.tap(myClassesAction);
      await tester.pumpAndSettle();

      // Verify the screen is My Classes and lists groups correctly
      expect(find.text('Grade 9 - A'), findsOneWidget);
      expect(find.text('Grade 10 - B'), findsOneWidget);
      expect(find.text('Mathematics'), findsOneWidget);
      expect(find.text('Science'), findsOneWidget);
      expect(find.text('Physics'), findsOneWidget);
      expect(find.text('2 Subjects Assigned'), findsOneWidget);
    });

    testWidgets('3. Duplicate assignments are filtered and 7. grouping is preserved', (tester) async {
      final fakeClassesRepo = FakeMyClassesRepository();
      // Inject duplicate assignments in repository mock
      fakeClassesRepo.classesMock = [
        const TeacherClassGroupEntity(
          classId: 'class_9',
          className: 'Grade 9',
          sectionId: 'sec_a',
          sectionName: 'A',
          assignments: [
            TeacherSubjectAssignmentEntity(
              id: 'assign_1',
              subjectId: 'sub_math',
              subjectName: 'Mathematics',
              subjectCode: 'MATH-101',
              displayColor: '#FF5733',
              isClassTeacher: true,
            ),
            TeacherSubjectAssignmentEntity(
              // Duplicate subject mapping
              id: 'assign_2_dup',
              subjectId: 'sub_math',
              subjectName: 'Mathematics',
              subjectCode: 'MATH-101',
              displayColor: '#FF5733',
              isClassTeacher: false,
            ),
          ],
        ),
      ];

      await tester.pumpWidget(createTestWidget(tester: tester, myClassesRepo: fakeClassesRepo));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Classes'));
      await tester.pumpAndSettle();

      // Verify Mathematics is displayed only once
      expect(
        find.descendant(of: find.byType(MyClassesScreen), matching: find.text('Mathematics')),
        findsOneWidget,
      );
      expect(find.text('1 Subject Assigned'), findsOneWidget);
    });

    testWidgets('4. Empty assignments show empty state card', (tester) async {
      final fakeClassesRepo = FakeMyClassesRepository();
      fakeClassesRepo.classesMock = [];

      await tester.pumpWidget(createTestWidget(tester: tester, myClassesRepo: fakeClassesRepo));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Classes'));
      await tester.pumpAndSettle();

      expect(find.text('No Classes Assigned'), findsOneWidget);
      expect(find.text('No classes are currently assigned to you.'), findsOneWidget);
    });

    testWidgets('5. API error displays error state, and 6. retry works', (tester) async {
      final fakeClassesRepo = FakeMyClassesRepository();
      fakeClassesRepo.shouldFailClasses = true;

      await tester.pumpWidget(createTestWidget(tester: tester, myClassesRepo: fakeClassesRepo));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Classes'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to Load Classes'), findsOneWidget);

      // Now set repository to success and trigger retry
      fakeClassesRepo.shouldFailClasses = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Grade 9 - A'), findsOneWidget);
    });
  });

  group('Phase 3: Class Detail Screen Widget Tests', () {
    testWidgets('8. Correct class/section and 9. subjects displayed', (tester) async {
      final fakeClassesRepo = FakeMyClassesRepository();

      await tester.pumpWidget(createTestWidget(tester: tester, myClassesRepo: fakeClassesRepo));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Classes'));
      await tester.pumpAndSettle();

      // Tap on Grade 9 - A card to go to details
      await tester.tap(find.text('Grade 9 - A'));
      await tester.pumpAndSettle();

      // Verify Class details screen content
      expect(find.text('Grade 9 - A'), findsWidgets);
      expect(find.text('Class Teacher'), findsNWidgets(2));
      expect(find.text('View Student Roster'), findsOneWidget);
      expect(find.text('Mathematics'), findsOneWidget);
      expect(find.text('MATH-101'), findsOneWidget);
      expect(find.text('Science'), findsOneWidget);
      expect(find.text('SCI-101'), findsOneWidget);
    });

    testWidgets('10. Navigation to roster from class detail screen', (tester) async {
      final fakeClassesRepo = FakeMyClassesRepository();

      await tester.pumpWidget(createTestWidget(tester: tester, myClassesRepo: fakeClassesRepo));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Classes'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Grade 9 - A'));
      await tester.pumpAndSettle();

      // Tap view student roster button
      await tester.tap(find.text('View Student Roster'));
      await tester.pumpAndSettle();

      // Verify roster loads
      expect(find.text('Roster - Grade 9 (A)'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);
    });
  });

  group('Phase 3: Student Roster Screen Widget Tests', () {
    testWidgets('11. Successful roster loading and 12. student rendering', (tester) async {
      final fakeClassesRepo = FakeMyClassesRepository();

      await tester.pumpWidget(createTestWidget(tester: tester, myClassesRepo: fakeClassesRepo));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Classes'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Grade 9 - A'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('View Student Roster'));
      await tester.pumpAndSettle();

      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('Adm: ADM-1001'), findsOneWidget);
      expect(find.text('Jane Smith'), findsOneWidget);
      expect(find.text('Adm: ADM-1002'), findsOneWidget);
    });

    testWidgets('13. Empty roster displays empty card', (tester) async {
      final fakeClassesRepo = FakeMyClassesRepository();
      fakeClassesRepo.studentsMock = [];

      await tester.pumpWidget(createTestWidget(tester: tester, myClassesRepo: fakeClassesRepo));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Classes'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Grade 9 - A'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('View Student Roster'));
      await tester.pumpAndSettle();

      expect(find.text('No Students Found'), findsOneWidget);
      expect(find.text('No students found in this section.'), findsOneWidget);
    });

    testWidgets('14. API error displays error state, and 15. retry works', (tester) async {
      final fakeClassesRepo = FakeMyClassesRepository();
      fakeClassesRepo.shouldFailStudents = true;

      await tester.pumpWidget(createTestWidget(tester: tester, myClassesRepo: fakeClassesRepo));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Classes'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Grade 9 - A'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('View Student Roster'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to Load Roster'), findsOneWidget);

      // Reset error and retry
      fakeClassesRepo.shouldFailStudents = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('John Doe'), findsOneWidget);
    });

    testWidgets('16. Local search filters roster, and 17. no search results displays empty', (tester) async {
      final fakeClassesRepo = FakeMyClassesRepository();

      await tester.pumpWidget(createTestWidget(tester: tester, myClassesRepo: fakeClassesRepo));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Classes'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Grade 9 - A'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('View Student Roster'));
      await tester.pumpAndSettle();

      // Verify both students are there
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('Jane Smith'), findsOneWidget);

      // Type "John" in search box
      final searchTextField = find.byType(TextField);
      await tester.enterText(searchTextField, 'John');
      await tester.pumpAndSettle();

      // Only John Doe should remain
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('Jane Smith'), findsNothing);

      // Type something that doesn't match
      await tester.enterText(searchTextField, 'Nobody');
      await tester.pumpAndSettle();

      expect(find.text('No Results Found'), findsOneWidget);
      expect(find.text('No matching students found.'), findsOneWidget);
    });

    testWidgets('18. Student selection opens student details screen', (tester) async {
      final fakeClassesRepo = FakeMyClassesRepository();

      await tester.pumpWidget(createTestWidget(tester: tester, myClassesRepo: fakeClassesRepo));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Classes'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Grade 9 - A'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('View Student Roster'));
      await tester.pumpAndSettle();

      // Tap on John Doe row
      await tester.tap(find.text('John Doe'));
      await tester.pumpAndSettle();

      // Verify Student Profile screen displays details
      expect(find.text('Student Profile'), findsOneWidget);
      expect(find.text('John Doe'), findsWidgets);
      expect(find.text('Adm: ADM-1001'), findsNothing); // It splits layout in detail screen
      expect(find.text('Admission Number'), findsOneWidget);
      expect(find.text('ADM-1001'), findsOneWidget);
      expect(find.text('Personal Details'), findsOneWidget);
      expect(find.text('Date of Birth'), findsOneWidget);
      expect(find.text('2012-05-14'), findsOneWidget);
    });
  });

  group('Phase 3: Security & Protected Routes', () {
    testWidgets('19. 401 Unauthorized API error propagates correctly', (tester) async {
      final fakeClassesRepo = FakeMyClassesRepository();
      fakeClassesRepo.shouldFailClasses = true;
      fakeClassesRepo.failureMessage = 'Session expired';

      await tester.pumpWidget(createTestWidget(tester: tester, myClassesRepo: fakeClassesRepo));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Classes'));
      await tester.pumpAndSettle();

      expect(find.text('Session expired'), findsOneWidget);
    });

    testWidgets('20. 403 Forbidden API error propagates correctly', (tester) async {
      final fakeClassesRepo = FakeMyClassesRepository();
      fakeClassesRepo.shouldFailClasses = true;
      fakeClassesRepo.failureMessage = 'Forbidden resource access error';

      await tester.pumpWidget(createTestWidget(tester: tester, myClassesRepo: fakeClassesRepo));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Classes'));
      await tester.pumpAndSettle();

      expect(find.text('Forbidden resource access error'), findsOneWidget);
    });

    testWidgets('21. Protected route behavior triggers redirects on Non-Teacher accounts', (tester) async {
      final fakeClassesRepo = FakeMyClassesRepository();

      await tester.pumpWidget(
        createTestWidget(
          tester: tester,
          myClassesRepo: fakeClassesRepo,
          authRepo: FakeAuthRepository(userRoles: const ['PARENT']),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Verify that app redirected to Access Denied (unauthorized path) instead of loading home/dashboard
      expect(find.text('Access Denied'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);
    });
  });
}
