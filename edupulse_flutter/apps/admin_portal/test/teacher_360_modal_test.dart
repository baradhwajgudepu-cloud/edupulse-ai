import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:admin_portal/features/teachers/data/models/teachers_models.dart';
import 'package:admin_portal/features/teachers/presentation/widgets/teacher_360_modal.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';

class FakeTeacher360ApiClient extends BaseApiClient {
  FakeTeacher360ApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    final uri = Uri.parse(path);
    if (uri.path.endsWith('/360')) {
      return ApiResult.success(mapper({
        'success': true,
        'message': 'OK',
        'data': {
          'teacher': {
            'id': 'fa73cb76-f5d9-491b-9d17-4fc55b66563e',
            'school_id': '89c6f113-8495-4f0d-ab76-fb77c1423771',
            'employee_code': 'EMP101',
            'staff_code': 'EMP101',
            'first_name': 'Dr. Sreenivas',
            'last_name': 'Sharma',
            'department': 'General Academics',
            'designation': 'PRINCIPAL',
            'employment_type': 'FULL_TIME',
            'status': 'ACTIVE',
            'official_email': 'sreenivas.sharma@telanganamodelschool.edu.in',
            'mobile': '+91 98765 43210',
            'joining_date': '2024-06-01',
            'aadhaar_number': '123456789012',
            'pan_number': 'ABCDE1234F',
            'created_at': '2024-06-01T00:00:00Z',
            'updated_at': '2024-06-01T00:00:00Z',
          },
          'overview': {
            'total_classes': 3,
            'total_sections': 3,
            'weekly_periods': 15,
            'primary_subjects': ['Hindi Second Language'],
            'class_teacher_of': [],
            'syllabus_completion_rate': 0.0,
            'expected_syllabus_rate': 35.1,
            'syllabus_pace_variance': -35.1,
            'syllabus_pace_status': 'BEHIND',
            'marks_submission_rate': 100.0,
            'attendance_rate': null,
            'active_students_taught': 90,
          },
          'assignments': [
            {
              'assignment_id': '11111111-1111-1111-1111-111111111111',
              'class_id': '22222222-2222-2222-2222-222222222222',
              'class_name': 'Class 5',
              'section_id': '33333333-3333-3333-3333-333333333333',
              'section_name': 'Section A',
              'subject_id': '44444444-4444-4444-4444-444444444444',
              'subject_name': 'Hindi Second Language',
              'assignment_type': 'PRIMARY',
              'weekly_periods': 5,
              'workload_percentage': 16.7,
              'student_count': 30,
              'is_class_teacher': false,
            },
            {
              'assignment_id': '11111111-1111-1111-1111-111111111112',
              'class_id': '22222222-2222-2222-2222-222222222223',
              'class_name': 'Class 7',
              'section_id': '33333333-3333-3333-3333-333333333334',
              'section_name': 'Section A',
              'subject_id': '44444444-4444-4444-4444-444444444444',
              'subject_name': 'Hindi Second Language',
              'assignment_type': 'PRIMARY',
              'weekly_periods': 5,
              'workload_percentage': 16.7,
              'student_count': 30,
              'is_class_teacher': false,
            },
          ],
          'syllabus_progress': [
            {
              'class_id': '22222222-2222-2222-2222-222222222222',
              'class_name': 'Class 5',
              'section_id': '33333333-3333-3333-3333-333333333333',
              'section_name': 'Section A',
              'subject_id': '44444444-4444-4444-4444-444444444444',
              'subject_name': 'Hindi Second Language',
              'total_topics': 5,
              'completed_topics': 0,
              'expected_topics_by_now': 2,
              'actual_completion_percentage': 0.0,
              'expected_completion_percentage': 35.1,
              'pace_variance': -35.1,
              'pace_status': 'BEHIND',
              'topics': [
                {
                  'id': '55555555-5555-5555-5555-555555555551',
                  'syllabus_code': 'SYLL_HIN_1',
                  'unit_name': 'Unit 1',
                  'chapter_name': 'Varnamala',
                  'topic_name': 'Swar aur Vyanjan',
                  'sequence_order': 1,
                  'estimated_periods': 4,
                  'coverage_status': 'PENDING',
                  'completed_at': null,
                  'is_expected_by_now': true,
                }
              ]
            }
          ],
          'timetable': [
            {
              'id': '66666666-6666-6666-6666-666666666661',
              'day_of_week': 'MONDAY',
              'period_number': 2,
              'start_time': '09:45',
              'end_time': '10:30',
              'period_type': 'REGULAR',
              'subject_name': 'Hindi Second Language',
              'class_name': 'Class 5',
              'section_name': 'Section A',
              'is_active': true,
            }
          ],
          'attendance': {
            'has_data': false,
            'attendance_rate': null,
            'present_days': 0,
            'absent_days': 0,
            'leave_days': 0,
            'total_recorded_days': 0,
            'monthly_trend': [],
            'recent_logs': [],
          },
          'homework': [],
          'exam_compliance': [
            {
              'exam_id': '77777777-7777-7777-7777-777777777771',
              'exam_name': 'Quarterly Examination 2026',
              'exam_type': 'QUARTERLY',
              'exam_date': '2026-09-23',
              'class_name': 'Class 5',
              'section_name': 'Section A',
              'subject_name': 'Hindi Second Language',
              'total_students': 30,
              'marks_entered_count': 30,
              'marks_pending_count': 0,
              'compliance_percentage': 100.0,
              'status': 'COMPLETED',
            }
          ],
          'workload': {
            'weekly_period_capacity': 30,
            'assigned_weekly_periods': 15,
            'utilization_rate': 50.0,
            'subject_distribution': [
              {
                'subject_name': 'Hindi Second Language',
                'weekly_periods': 15,
                'percentage': 100.0,
              }
            ],
            'class_distribution': [
              {
                'class_name': 'Class 5',
                'weekly_periods': 5,
                'percentage': 33.3,
              }
            ],
          }
        }
      }));
    }
    return ApiResult.failure(const ApiFailure(message: 'Not found', type: ApiFailureType.unknown));
  }
}

void main() {
  final sampleTeacher = TeacherDto(
    id: 'fa73cb76-f5d9-491b-9d17-4fc55b66563e',
    schoolId: '89c6f113-8495-4f0d-ab76-fb77c1423771',
    employeeCode: 'EMP101',
    staffCode: 'EMP101',
    firstName: 'Dr. Sreenivas',
    lastName: 'Sharma',
    department: 'General Academics',
    designation: 'PRINCIPAL',
    employmentType: 'FULL_TIME',
    status: 'ACTIVE',
    officialEmail: 'sreenivas.sharma@telanganamodelschool.edu.in',
    mobile: '+91 98765 43210',
    joiningDate: '2024-06-01',
    aadhaarNumber: '123456789012',
    panNumber: 'ABCDE1234F',
  );

  Widget createSubject() {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(FakeTeacher360ApiClient()),
        selectedSchoolIdProvider.overrideWith((ref) => '89c6f113-8495-4f0d-ab76-fb77c1423771'),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Teacher360Modal(
            teacher: sampleTeacher,
            schoolId: '89c6f113-8495-4f0d-ab76-fb77c1423771',
          ),
        ),
      ),
    );
  }

  testWidgets('Teacher 360 Modal renders identity banner and tab headers', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    // Verify identity info
    expect(find.text('Dr. Sreenivas Sharma'), findsOneWidget);
    expect(find.text('EMP101'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);

    // Verify tabs
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Classes & Subjects'), findsOneWidget);
    expect(find.text('Syllabus Progress'), findsOneWidget);
    expect(find.text('Timetable'), findsOneWidget);
    expect(find.text('Attendance'), findsOneWidget);
    expect(find.text('Homework'), findsOneWidget);
    expect(find.text('Examinations'), findsOneWidget);
    expect(find.text('Workload & Profile'), findsOneWidget);

    // Verify Overview stats
    expect(find.text('Assigned Classes'), findsOneWidget);
    expect(find.text('Weekly Teaching Load'), findsOneWidget);
    expect(find.text('Syllabus Pace'), findsOneWidget);
    expect(find.text('Exam Marks Compliance'), findsOneWidget);
    expect(find.text('Primary Subjects Taught'), findsOneWidget);
  });

  testWidgets('Teacher 360 Modal switches tabs seamlessly', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    // Switch to Classes & Subjects tab
    await tester.tap(find.text('Classes & Subjects'));
    await tester.pumpAndSettle();
    expect(find.text('Class 5 • Section A'), findsOneWidget);
    expect(find.text('Class 7 • Section A'), findsOneWidget);

    // Switch to Syllabus Progress tab
    await tester.tap(find.text('Syllabus Progress'));
    await tester.pumpAndSettle();
    expect(find.text('Class 5 • Section A — Hindi Second Language'), findsOneWidget);
    expect(find.text('BEHIND (-35.1%)'), findsOneWidget);

    // Switch to Timetable tab
    await tester.tap(find.text('Timetable'));
    await tester.pumpAndSettle();
    expect(find.text('P2'), findsOneWidget);
    expect(find.text('09:45 – 10:30'), findsOneWidget);

    // Switch to Attendance tab (empty state)
    await tester.tap(find.text('Attendance'));
    await tester.pumpAndSettle();
    expect(find.text('No Staff Attendance Logged'), findsOneWidget);

    // Switch to Examinations tab
    await tester.tap(find.text('Examinations'));
    await tester.pumpAndSettle();
    expect(find.text('Quarterly Examination 2026 — Hindi Second Language'), findsOneWidget);
    expect(find.text('COMPLETED'), findsWidgets);

    // Switch to Workload & Profile tab
    await tester.tap(find.text('Workload & Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Weekly Teaching Capacity Utilization'), findsOneWidget);
    expect(find.text('Subject Load Breakdown'), findsOneWidget);
  });
}
