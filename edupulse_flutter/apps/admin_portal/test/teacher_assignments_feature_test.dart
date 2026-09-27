import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/teachers/presentation/providers/teachers_providers.dart';
import 'package:admin_portal/features/teachers/presentation/pages/teacher_assignments_screen.dart';

class FakeAssignmentsSessionManager implements SessionManager {
  String? cachedTenantId;

  @override
  Future<String?> getTenantId() async => cachedTenantId;

  @override
  Future<void> saveTenantId(String tenantId) async {
    cachedTenantId = tenantId;
  }

  @override
  Future<String?> getAccessToken() async => 'mock_access';
  @override
  Future<String?> getRefreshToken() async => 'mock_refresh';
  @override
  Future<void> saveSession(SessionToken token) async {}
  @override
  Future<void> clearSession([String source = 'SessionManager.clearSession']) async {}
  @override
  Future<bool> hasSession() async => true;
  @override
  Future<String?> getSchoolId() async => 'school_1';
  @override
  Future<void> saveSchoolId(String schoolId) async {}
  @override
  Future<String?> getSchoolName() async => 'Test School';
  @override
  Future<void> saveSchoolName(String schoolName) async {}
  @override
  Future<String?> getTenantName() async => 'Test Tenant';
  @override
  Future<void> saveTenantName(String tenantName) async {}
}

class FakeAssignmentsApiClient extends BaseApiClient {
  bool simulateDeleteSuccess = true;
  int deleteCallCount = 0;

  FakeAssignmentsApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (path.contains('/academic-years')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'ay_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'name': '2026-2027',
            'code': 'AY2026',
            'start_date': '2026-06-01',
            'end_date': '2027-03-31',
            'status': 'ACTIVE',
            'is_current': true,
            'version': 1,
          }
        ]
      }));
    }

    if (path.contains('/classes')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'class_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'name': 'Class 10',
            'code': 'CLASS_10',
            'capacity': 40,
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1,
          }
        ]
      }));
    }

    if (path.contains('/sections')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'sec_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'class_id': 'class_1',
            'name': 'Section A',
            'code': 'SEC_A',
            'capacity': 40,
            'sort_order': 1,
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1,
          }
        ]
      }));
    }

    if (path.contains('/subjects')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'sub_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'subject_code': 'MATH101',
            'subject_name': 'Mathematics',
            'category': 'CORE',
            'subject_type': 'THEORY',
            'theory_marks': 100,
            'practical_marks': 0,
            'pass_marks': 40,
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1,
          }
        ]
      }));
    }

    if (path.contains('/teachers')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'teacher_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'employee_code': 'EMP001',
            'staff_code': 'STF001',
            'first_name': 'John',
            'middle_name': '',
            'last_name': 'Doe',
            'gender': 'MALE',
            'date_of_birth': '1990-05-15',
            'mobile': '9876543210',
            'official_email': 'john.doe@school.com',
            'joining_date': '2020-06-01',
            'employment_type': 'FULL_TIME',
            'designation': 'PGT',
            'department': 'Mathematics',
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1,
          },
          {
            'id': 'teacher_2',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'employee_code': 'EMP002',
            'staff_code': 'STF002',
            'first_name': 'Jane',
            'middle_name': '',
            'last_name': 'Smith',
            'gender': 'FEMALE',
            'date_of_birth': '1992-08-20',
            'mobile': '9876543211',
            'official_email': 'jane.smith@school.com',
            'joining_date': '2021-07-01',
            'employment_type': 'FULL_TIME',
            'designation': 'TGT',
            'department': 'Science',
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1,
          },
        ],
        'total': 2,
        'skip': 0,
        'limit': 50,
      }));
    }

    if (path.contains('/teacher-subject-assignments')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'asgn_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'teacher_id': 'teacher_1',
            'subject_id': 'sub_1',
            'class_id': 'class_1',
            'section_id': 'sec_1',
            'academic_year_id': 'ay_1',
            'assignment_type': 'PRIMARY',
            'is_class_teacher': true,
            'weekly_periods': 6,
            'status': 'ACTIVE',
            'remarks': 'Primary Math and Class Teacher',
            'version': 1,
          },
          {
            'id': 'asgn_2',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'teacher_id': 'teacher_2',
            'subject_id': 'sub_1',
            'class_id': 'class_1',
            'section_id': 'sec_1',
            'academic_year_id': 'ay_1',
            'assignment_type': 'SECONDARY',
            'is_class_teacher': false,
            'weekly_periods': 4,
            'status': 'ACTIVE',
            'remarks': 'Assistant teacher',
            'version': 1,
          },
        ]
      }));
    }

    return ApiResult.failure(const ApiFailure(message: 'Not found', type: ApiFailureType.unknown));
  }

  @override
  Future<ApiResult<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    deleteCallCount++;
    if (simulateDeleteSuccess) {
      return ApiResult.success(mapper({'status': 'success'}));
    }
    return ApiResult.failure(const ApiFailure(message: 'Delete failed', type: ApiFailureType.unknown));
  }
}

Widget createTestWidget({FakeAssignmentsApiClient? apiClient}) {
  final client = apiClient ?? FakeAssignmentsApiClient();
  final session = FakeAssignmentsSessionManager();

  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(client),
      sessionManagerProvider.overrideWithValue(session),
      selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
    ],
    child: const MaterialApp(
      home: TeacherAssignmentsScreen(),
    ),
  );
}

void main() {
  testWidgets('TeacherAssignmentsScreen renders title and statistics correctly', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Teacher Assignments'), findsOneWidget);
    expect(find.text('Assign and manage academic workload across classes and subjects'), findsOneWidget);

    // Verify stat cards
    expect(find.text('Total Mappings'), findsOneWidget);
    expect(find.text('Class Teachers'), findsOneWidget);
    expect(find.text('Active Teachers'), findsOneWidget);
    expect(find.text('Weekly Periods'), findsOneWidget);
  });

  testWidgets('TeacherAssignmentsScreen displays assignment table rows and details', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Verify table headers
    expect(find.text('Class & Section'), findsOneWidget);
    expect(find.text('Subject'), findsOneWidget);
    expect(find.text('Teacher'), findsOneWidget);
    expect(find.text('Role / Type'), findsOneWidget);
    expect(find.text('Periods'), findsOneWidget);

    // Verify data rows
    expect(find.text('Class 10 - Section A'), findsNWidgets(2));
    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('Jane Smith'), findsOneWidget);
    expect(find.text('6 / wk'), findsOneWidget);
    expect(find.text('4 / wk'), findsOneWidget);
  });

  testWidgets('Clicking + New Assignment opens AssignmentFormDialog', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    final newAssignmentBtn = find.text('New Assignment');
    expect(newAssignmentBtn, findsOneWidget);
    await tester.tap(newAssignmentBtn);
    await tester.pumpAndSettle();

    expect(find.text('Assign Academic Subject'), findsOneWidget);
  });

  testWidgets('Clicking delete on assignment shows confirmation dialog', (tester) async {
    final client = FakeAssignmentsApiClient();
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await tester.pumpWidget(createTestWidget(apiClient: client));
    await tester.pumpAndSettle();

    final deleteBtn = find.byKey(const Key('delete_assignment_asgn_1'));
    expect(deleteBtn, findsOneWidget);
    await tester.ensureVisible(deleteBtn);
    await tester.tap(deleteBtn);
    await tester.pumpAndSettle();

    expect(find.text('Remove Assignment?'), findsOneWidget);
    expect(find.text('Are you sure you want to remove this academic assignment?'), findsOneWidget);

    // Confirm delete
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(client.deleteCallCount, 1);
  });
}
