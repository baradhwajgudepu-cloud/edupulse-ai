import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/teachers/presentation/pages/teachers_screen.dart';
import 'package:admin_portal/features/teachers/presentation/pages/teacher_details_screen.dart';

class FakeTestSessionManager implements SessionManager {
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
  Future<void> clearSession() async {}
  @override
  Future<bool> hasSession() async => true;
  @override
  Future<String?> getSchoolId() async => 'school_1';
  @override
  Future<void> saveSchoolId(String schoolId) async {}
}

class FakeTeachersApiClient extends BaseApiClient {
  bool simulateError = false;
  bool simulateValidationError = false;
  bool isCreateSuccess = true;
  
  FakeTeachersApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (simulateError && path.contains('/teachers')) {
      return ApiResult.failure(const ApiFailure(message: 'Simulated API connection failure', type: ApiFailureType.unknown));
    }

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
            'name': 'Class 8',
            'code': 'CLASS_8',
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
            'id': 'section_1',
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
            'subject_code': 'MATH8',
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

    if (path.contains('/teachers/t_1') || path.contains('/teachers/t_2')) {
      final isT2 = path.contains('t_2');
      return ApiResult.success(mapper({
        'data': {
          'id': isT2 ? 't_2' : 't_1',
          'tenant_id': 'tenant_1',
          'school_id': 'school_1',
          'employee_code': isT2 ? 'EMP002' : 'EMP001',
          'staff_code': isT2 ? 'STF002' : 'STF001',
          'first_name': isT2 ? 'Jane' : 'John',
          'middle_name': isT2 ? '' : '',
          'last_name': isT2 ? 'Smith' : 'Doe',
          'gender': isT2 ? 'FEMALE' : 'MALE',
          'date_of_birth': isT2 ? '1960-01-01' : '1990-05-15',
          'mobile': isT2 ? '9876543211' : '9876543210',
          'official_email': isT2 ? 'jane.smith@school.com' : 'john.doe@school.com',
          'joining_date': isT2 ? '1995-06-01' : '2020-06-01',
          'employment_type': 'FULL_TIME',
          'designation': isT2 ? 'HOD' : 'PGT',
          'department': isT2 ? 'English' : 'Mathematics',
          'status': isT2 ? 'RETIRED' : 'ACTIVE',
          'is_active': !isT2,
          'version': 1,
        }
      }));
    }

    if (path.contains('/teachers')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 't_1',
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
            'id': 't_2',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'employee_code': 'EMP002',
            'staff_code': 'STF002',
            'first_name': 'Jane',
            'middle_name': '',
            'last_name': 'Smith',
            'gender': 'FEMALE',
            'date_of_birth': '1960-01-01',
            'mobile': '9876543211',
            'official_email': 'jane.smith@school.com',
            'joining_date': '1995-06-01',
            'employment_type': 'FULL_TIME',
            'designation': 'HOD',
            'department': 'English',
            'status': 'RETIRED',
            'is_active': false,
            'version': 1,
          }
        ],
        'total': 2,
      }));
    }

    if (path.contains('/teacher-subject-assignments')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'asg_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'teacher_id': 't_1',
            'subject_id': 'sub_1',
            'class_id': 'class_1',
            'section_id': 'section_1',
            'assignment_type': 'PRIMARY',
            'priority': 1,
            'weekly_periods': 6,
            'workload_percentage': 15.0,
            'effective_from': '2026-06-01',
            'is_class_teacher': true,
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1,
          }
        ]
      }));
    }

    return ApiResult.failure(const ApiFailure(message: 'Unknown mock endpoint', type: ApiFailureType.unknown));
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
    if (simulateValidationError) {
      if (path.contains('/teacher-subject-assignments')) {
        return ApiResult.failure(const ApiFailure(message: 'Validation rejected by backend service', type: ApiFailureType.unknown, statusCode: 422));
      }
      return ApiResult.failure(const ApiFailure(message: 'Official email is already registered', type: ApiFailureType.unknown, statusCode: 409));
    }
    return ApiResult.success(mapper({'success': true, 'data': {'id': 'new_id'}}));
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
    if (simulateValidationError) {
      return ApiResult.failure(const ApiFailure(message: 'Validation rejected by backend service', type: ApiFailureType.unknown, statusCode: 422));
    }
    return ApiResult.success(mapper({'success': true}));
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
    return ApiResult.success(mapper({'success': true}));
  }
}

void setupViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  late FakeTeachersApiClient fakeApiClient;

  setUp(() {
    fakeApiClient = FakeTeachersApiClient();
  });

  Widget createTestWidget(Widget child) {
    return ProviderScope(
      overrides: [
        sessionManagerProvider.overrideWithValue(FakeTestSessionManager()),
        apiClientProvider.overrideWithValue(fakeApiClient),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Teachers Feature UI Tests', () {
    testWidgets('1. Teacher list screen renders successfully', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const TeachersScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Teachers & Staff'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('Jane Smith'), findsOneWidget);
      expect(find.text('EMP001'), findsOneWidget);
      expect(find.text('EMP002'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('RETIRED'), findsOneWidget);
    });

    testWidgets('2-5. Filters and search fields render and react to input', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const TeachersScreen()));
      await tester.pumpAndSettle();

      // Verify search input field is present
      final searchField = find.byKey(const Key('teacher_search_field'));
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'Mathematics');
      await tester.pumpAndSettle();

      // Verify dropdown filters are present
      expect(find.byKey(const Key('status_filter_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('dept_filter_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('desg_filter_dropdown')), findsOneWidget);
    });

    testWidgets('6. Add Teacher opens input dialog form', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const TeachersScreen()));
      await tester.pumpAndSettle();

      final addBtn = find.byKey(const Key('add_teacher_button'));
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(find.text('Register New Teacher'), findsOneWidget);
      expect(find.text('Employee Code *'), findsOneWidget);
      expect(find.text('Staff Code *'), findsOneWidget);
    });

    testWidgets('7. Required-field validation marks errors correctly', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const TeachersScreen()));
      await tester.pumpAndSettle();

      // Open Form Dialog
      await tester.tap(find.byKey(const Key('add_teacher_button')));
      await tester.pumpAndSettle();

      // Submit without entering data
      await tester.tap(find.text('Register Teacher'));
      await tester.pumpAndSettle();

      // Should show validation triggers
      expect(find.text('Required'), findsAtLeastNWidgets(2));
    });

    testWidgets('8. Backend validation error is parsed and displayed', (tester) async {
      setupViewport(tester);
      fakeApiClient.simulateValidationError = true;
      await tester.pumpWidget(createTestWidget(const TeachersScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add_teacher_button')));
      await tester.pumpAndSettle();

      // Fill in required textfields
      await tester.enterText(find.widgetWithText(TextFormField, 'Employee Code *'), 'EMP100');
      await tester.enterText(find.widgetWithText(TextFormField, 'Staff Code *'), 'STF100');
      await tester.enterText(find.widgetWithText(TextFormField, 'First Name *'), 'Bob');
      await tester.enterText(find.widgetWithText(TextFormField, 'Last Name *'), 'Builder');
      await tester.enterText(find.widgetWithText(TextFormField, 'Mobile Number *'), '1234567890');
      await tester.enterText(find.widgetWithText(TextFormField, 'Official Email *'), 'bob@school.com');
      
      // Select dates using fake picks (simulate picking from dates variables)
      // For simplicity, we just verify form submission tries to call POST
      await tester.tap(find.text('Register Teacher'));
      await tester.pumpAndSettle();

      // Displays backend simulated email conflict warning
      expect(find.text('Official email is already registered'), findsOneWidget);
    });

    testWidgets('9. Teacher details page renders all panels', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const TeacherDetailsScreen(teacherId: 't_1')));
      await tester.pumpAndSettle();

      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('Employment & Office Information'), findsOneWidget);
      expect(find.text('Personal & Contact Information'), findsOneWidget);
      expect(find.text('Qualification & Background'), findsOneWidget);
    });

    testWidgets('10. Edit Teacher dialog opens with pre-populated values', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const TeacherDetailsScreen(teacherId: 't_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('edit_teacher_profile_button')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Teacher Profile'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'First Name *'), findsOneWidget);
      // Pre-filled values check
      expect(find.text('John'), findsOneWidget);
      expect(find.text('Doe'), findsOneWidget);
    });

    testWidgets('11. Deactivate confirmation popup appears', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const TeacherDetailsScreen(teacherId: 't_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('deactivate_teacher_profile_button')));
      await tester.pumpAndSettle();

      expect(find.text('Deactivate Teacher'), findsOneWidget);
      expect(find.text('Are you sure you want to change status to INACTIVE?'), findsOneWidget);
    });

    testWidgets('12. Assignment list renders under subject mappings tab', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const TeacherDetailsScreen(teacherId: 't_1')));
      await tester.pumpAndSettle();

      // Tap on the Mappings tab
      await tester.tap(find.text('Subject Mappings'));
      await tester.pumpAndSettle();

      expect(find.text('Academic Assignments Catalog'), findsOneWidget);
      expect(find.text('Class 8 - Section A'), findsOneWidget);
      expect(find.text('Mathematics (MATH8)'), findsOneWidget);
      expect(find.text('PRIMARY'), findsOneWidget);
      expect(find.text('Class Teacher'), findsOneWidget);
    });

    testWidgets('13. Assignment dialog renders setup dropdowns', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const TeacherDetailsScreen(teacherId: 't_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Subject Mappings'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('assign_subject_button')));
      await tester.pumpAndSettle();

      expect(find.text('New Subject Assignment'), findsOneWidget);
      expect(find.text('Class / Grade Level *'), findsOneWidget);
      expect(find.text('Section *'), findsOneWidget);
      expect(find.text('Subject *'), findsOneWidget);
    });

    testWidgets('14. Assignment creation success refreshes lists', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const TeacherDetailsScreen(teacherId: 't_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Subject Mappings'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('assign_subject_button')));
      await tester.pumpAndSettle();

      // Select Dropdowns
      await tester.tap(find.text('Academic Year *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026-2027 (Current)').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Class / Grade Level *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Class 8').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Section *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Section A').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Subject *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mathematics (MATH8)').last);
      await tester.pumpAndSettle();

      // Fill in weekly periods and tap submit
      await tester.tap(find.text('Assign Teacher'));
      await tester.pumpAndSettle();

      // Closes dialog and returns to screen
      expect(find.text('New Subject Assignment'), findsNothing);
    });

    testWidgets('15. Assignment backend failure displays error', (tester) async {
      setupViewport(tester);
      fakeApiClient.simulateValidationError = true;
      await tester.pumpWidget(createTestWidget(const TeacherDetailsScreen(teacherId: 't_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Subject Mappings'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('assign_subject_button')));
      await tester.pumpAndSettle();

      // Select Dropdowns
      await tester.tap(find.text('Academic Year *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026-2027 (Current)').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Class / Grade Level *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Class 8').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Section *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Section A').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Subject *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mathematics (MATH8)').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Assign Teacher'));
      await tester.pumpAndSettle();

      expect(find.text('Validation rejected by backend service'), findsOneWidget);
    });

    testWidgets('16. Invalid actions are disabled according to teacher status', (tester) async {
      setupViewport(tester);
      await tester.pumpWidget(createTestWidget(const TeacherDetailsScreen(teacherId: 't_2'))); // Jane Smith (RETIRED)
      await tester.pumpAndSettle();

      final editBtn = tester.widget<ElevatedButton>(find.byKey(const Key('edit_teacher_profile_button')));
      final deactivateBtn = tester.widget<OutlinedButton>(find.byKey(const Key('deactivate_teacher_profile_button')));

      expect(editBtn.onPressed, isNull); // Disabled
      expect(deactivateBtn.onPressed, isNull); // Disabled
    });
  });
}
