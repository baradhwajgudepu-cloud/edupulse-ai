import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/features/auth/presentation/providers/auth_provider.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/planner/presentation/pages/timetable_management_screen.dart';

class FakeTimetableApiClient extends BaseApiClient {
  bool copyDayCalled = false;
  bool publishCalled = false;

  FakeTimetableApiClient() : super(Dio());

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
            'first_name': 'Alan',
            'middle_name': '',
            'last_name': 'Turing',
            'gender': 'MALE',
            'date_of_birth': '1990-01-01',
            'mobile': '9876543210',
            'official_email': 'alan.turing@school.com',
            'joining_date': '2020-01-01',
            'employment_type': 'FULL_TIME',
            'designation': 'PGT',
            'department': 'Computer Science',
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1,
          }
        ],
        'total': 1,
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
            'weekly_periods': 5,
            'status': 'ACTIVE',
            'version': 1,
          }
        ]
      }));
    }

    if (path.contains('/timetables')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'slot_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'class_id': 'class_1',
            'section_id': 'sec_1',
            'day_of_week': 'MONDAY',
            'period_number': 1,
            'start_time': '09:00:00',
            'end_time': '09:45:00',
            'period_type': 'REGULAR',
            'teacher_subject_assignment_id': 'asgn_1',
            'teacher_id': 'teacher_1',
            'subject_id': 'sub_1',
            'room_number': 'Room 101',
            'status': 'ACTIVE',
            'version': 1,
          },
          {
            'id': 'slot_2',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'class_id': 'class_1',
            'section_id': 'sec_1',
            'day_of_week': 'MONDAY',
            'period_number': 2,
            'start_time': '09:45:00',
            'end_time': '10:30:00',
            'period_type': 'LAB',
            'teacher_subject_assignment_id': 'asgn_1',
            'teacher_id': 'teacher_1',
            'subject_id': 'sub_1',
            'room_number': 'Lab 1',
            'status': 'ACTIVE',
            'version': 1,
          }
        ]
      }));
    }

    return ApiResult.failure(const ApiFailure(message: 'Not found', type: ApiFailureType.unknown));
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
    if (path.contains('/copy-day')) {
      copyDayCalled = true;
      return ApiResult.success(mapper({'count': 2, 'message': 'Day schedule copied successfully'}));
    }
    if (path.contains('/bulk-status')) {
      publishCalled = true;
      return ApiResult.success(mapper({'count': 2, 'message': 'Timetable status updated successfully'}));
    }
    return ApiResult.success(mapper({'id': 'new_slot', 'status': 'ACTIVE'}));
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
    return ApiResult.success(mapper({'status': 'deleted'}));
  }
}

Widget createTimetableTestWidget({FakeTimetableApiClient? apiClient}) {
  final client = apiClient ?? FakeTimetableApiClient();

  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(client),
      selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
    ],
    child: const MaterialApp(
      home: TimetableManagementScreen(
        initialClassId: 'class_1',
        initialSectionId: 'sec_1',
      ),
    ),
  );
}

void main() {
  testWidgets('TimetableManagementScreen renders title, action buttons, and layout toggles', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 850));
    await tester.pumpWidget(createTimetableTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Timetable Management'), findsOneWidget);
    expect(find.text('Schedule and conflict detection for classes, teachers, and rooms'), findsOneWidget);

    // Verify mode switches
    expect(find.text('Class & Section'), findsOneWidget);
    expect(find.text('Teacher Schedule'), findsOneWidget);
    expect(find.text('Room Schedule'), findsOneWidget);

    // Action buttons
    expect(find.text('Add Slot'), findsOneWidget);
    expect(find.text('Copy Day'), findsOneWidget);
    expect(find.text('Copy Section'), findsOneWidget);
    expect(find.text('Print / Export'), findsOneWidget);
  });

  testWidgets('TimetableManagementScreen displays weekly schedule slots', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 850));
    await tester.pumpWidget(createTimetableTestWidget());
    await tester.pumpAndSettle();

    // Verify day headers
    expect(find.text('Monday'), findsWidgets);
    expect(find.text('Tuesday'), findsWidgets);

    // Verify loaded slots
    expect(find.text('Room 101'), findsOneWidget);
    expect(find.text('Lab 1'), findsOneWidget);
  });

  testWidgets('Clicking Add Slot opens TimetableSlotDialog', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 850));
    await tester.pumpWidget(createTimetableTestWidget());
    await tester.pumpAndSettle();

    final addSlotBtn = find.text('Add Slot');
    expect(addSlotBtn, findsOneWidget);
    await tester.tap(addSlotBtn);
    await tester.pumpAndSettle();

    expect(find.text('Schedule Timetable Slot'), findsOneWidget);
    expect(find.text('Day of Week*'), findsOneWidget);
    expect(find.text('Period Number*'), findsOneWidget);
  });

  testWidgets('Clicking Copy Day opens CopyDayDialog', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 850));
    await tester.pumpWidget(createTimetableTestWidget());
    await tester.pumpAndSettle();

    final copyDayBtn = find.text('Copy Day');
    expect(copyDayBtn, findsOneWidget);
    await tester.tap(copyDayBtn);
    await tester.pumpAndSettle();

    expect(find.text('Copy Day Schedule'), findsOneWidget);
    expect(find.text('Source Day*'), findsOneWidget);
    expect(find.text('Target Day*'), findsOneWidget);
  });
}
