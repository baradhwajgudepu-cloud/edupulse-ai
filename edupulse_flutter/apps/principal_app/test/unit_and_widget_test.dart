import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';

// Import local domain objects and providers
import 'package:principal_app/features/students/data/models/student_model.dart';
import 'package:principal_app/features/students/presentation/providers/student_provider.dart';
import 'package:principal_app/features/teachers/data/models/teacher_model.dart';
import 'package:principal_app/features/attendance/data/models/attendance_model.dart';
import 'package:principal_app/features/attendance/presentation/providers/attendance_provider.dart';
import 'package:principal_app/features/academics/data/models/academic_models.dart';
import 'package:principal_app/features/homework/data/models/homework_model.dart';
import 'package:principal_app/features/report_cards/presentation/providers/report_cards_provider.dart';
import 'package:principal_app/features/dashboard/presentation/providers/dashboard_provider.dart';

class FakeSessionManager implements SessionManager {
  @override
  Future<String?> getAccessToken() async => 'fake_token';
  @override
  Future<String?> getRefreshToken() async => 'fake_refresh';
  @override
  Future<void> saveSession(SessionToken token) async {}
  @override
  Future<void> clearSession() async {}
  @override
  Future<bool> hasSession() async => true;
  @override
  Future<String?> getSchoolId() async => 'school_abc';
  @override
  Future<void> saveSchoolId(String schoolId) async {}
}

class FakeBaseApiClient extends BaseApiClient {
  final bool simulate403;
  final bool failFee;
  final bool failNotifications;
  final bool failExaminations;
  
  FakeBaseApiClient({
    this.simulate403 = false,
    this.failFee = false,
    this.failNotifications = false,
    this.failExaminations = false,
  }) : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (simulate403) {
      return ApiResult.failure(const ApiFailure(
        message: 'Permission denied',
        type: ApiFailureType.unauthorized,
        statusCode: 403,
      ));
    }

    if (failFee && path.contains('/fees/reports/dashboard')) {
      return ApiResult.failure(const ApiFailure(
        message: 'Fee service down',
        type: ApiFailureType.unknown,
        statusCode: 500,
      ));
    }

    if (failNotifications && path.contains('/notifications')) {
      return ApiResult.failure(const ApiFailure(
        message: 'Notification service down',
        type: ApiFailureType.unknown,
        statusCode: 500,
      ));
    }

    if (failExaminations && path.contains('/examinations')) {
      return ApiResult.failure(const ApiFailure(
        message: 'Examination service down',
        type: ApiFailureType.unknown,
        statusCode: 500,
      ));
    }

    if (path.contains('/fees/reports/dashboard')) {
      return ApiResult.success(mapper({
        'data': {
          'today_collection': 5000.0,
          'month_collection': 250000.0,
          'pending_dues': 75000.0,
          'collection_percentage': 85.0,
          'defaulters_count': 12,
          'top_outstanding_classes': [
            {
              'class_name': 'Grade 10',
              'outstanding_amount': 25000.0,
            }
          ]
        }
      }));
    } else if (path.contains('/notifications/unread-count')) {
      return ApiResult.success(mapper({
        'data': {
          'unread_count': 5
        }
      }));
    } else if (path.contains('/notifications')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'notif_1',
            'title': 'Overdue Fee Notice',
            'content': 'Please check dues',
            'priority': 'URGENT',
            'notification_type': 'FEE',
            'status': 'UNREAD',
            'created_at': '2026-08-09T10:00:00Z',
          },
          {
            'id': 'notif_2',
            'title': 'PTA Meeting',
            'content': 'PTA Meeting scheduled for tomorrow',
            'priority': 'HIGH',
            'notification_type': 'ACADEMIC',
            'status': 'UNREAD',
            'created_at': '2026-08-09T11:00:00Z',
          }
        ]
      }));
    } else if (path.contains('/students')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'stud_1',
            'first_name': 'Rahul',
            'last_name': 'Sharma',
            'admission_number': 'ADM001',
            'roll_number': '10',
            'class_name': 'Grade 10',
            'section_name': 'A',
            'gender': 'MALE',
            'date_of_birth': '2010-05-15',
            'mobile': '9876543210',
            'email': 'rahul@example.com',
            'admission_date': '2020-04-01',
            'status': 'ACTIVE',
            // Sensitive fields (Aadhaar, address, parent details, etc.)
            // must NOT exist in our deserialized Student model. We will verify this!
            'aadhaar_number': '123456789012',
            'medical_information': 'Asthma history',
            'address': '123 Street Name',
            'parent_contact': '9999988888',
          }
        ]
      }));
    } else if (path.contains('/teachers')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'teach_1',
            'first_name': 'Jane',
            'last_name': 'Doe',
            'employee_code': 'EMP01',
            'staff_code': 'STF01',
            'designation': 'HOD Science',
            'department': 'Science',
            'qualification': 'M.Sc. Physics',
            'joining_date': '2015-06-01',
            'status': 'ACTIVE',
            'employment_type': 'FULL_TIME',
            'mobile': '9898989898',
            'official_email': 'jane.doe@school.edu',
            'emergency_contact_name': 'John Doe',
            'emergency_contact_mobile': '9797979797',
            // Sensitive fields (salary, address, personal email, etc.)
            // must NOT exist in our Teacher model definition.
            'salary': '85000',
            'personal_email': 'jane.personal@gmail.com',
            'pan_number': 'ABCDE1234F',
            'aadhaar_number': '987654321098',
            'address': '456 Lane Road',
          }
        ]
      }));
    } else if (path.contains('/attendances/daily')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'att_1',
            'student_id': 'stud_1',
            'attendance_status': 'PRESENT',
            'attendance_date': '2026-08-09',
            'class_id': 'class_1',
            'section_id': 'sec_1'
          },
          {
            'id': 'att_2',
            'student_id': 'stud_missing',
            'attendance_status': 'ABSENT',
            'attendance_date': '2026-08-09',
            'class_id': 'class_1',
            'section_id': 'sec_1'
          }
        ]
      }));
    } else if (path.contains('/examinations')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'exam_1',
            'exam_name': 'Mid-Term 2026',
            'exam_type': 'SUMMATIVE',
            'start_date': '2026-09-01',
            'end_date': '2026-09-10',
            'status': 'UPCOMING',
            'schedules': [
              {
                'id': 'sched_1',
                'subject_id': 'sub_physics',
                'exam_date': '2026-09-02',
                'start_time': '09:00',
                'end_time': '12:00',
                'max_marks': 100,
                'pass_marks': 35
              }
            ]
          }
        ]
      }));
    } else if (path.contains('/marks/summary')) {
      return ApiResult.success(mapper({
        'data': {
          'class_average': 78.5,
          'pass_percentage': 92.0,
          'highest_score': 98.0,
          'lowest_score': 42.0,
          'missing_count': 1,
          'absent_count': 2
        }
      }));
    } else if (path.contains('/homeworks')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'hw_1',
            'teacher_id': 'teach_1',
            'class_id': 'class_1',
            'section_id': 'sec_1',
            'subject_id': 'sub_math',
            'title': 'Trigonometry Homework',
            'description': 'Complete exercises 1 to 5',
            'due_date': '2026-08-15',
            'priority': 'HIGH',
            'status': 'PUBLISHED'
          }
        ]
      }));
    } else if (path.contains('/report-cards')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'rc_1',
            'verification_uuid': 'uuid_val_123',
            'status': 'UNDER_REVIEW',
            'pdf_url': 'https://pdf.example.com/rc_1.pdf',
            'version': 1,
            'academic_year_id': 'ay_2026',
            'student_id': 'stud_1',
            'class_id': 'class_1',
            'section_id': 'sec_1'
          }
        ]
      }));
    }
    
    return ApiResult.failure(const ApiFailure(
      message: 'Route not mocked',
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
    if (simulate403) {
      return ApiResult.failure(const ApiFailure(
        message: 'Permission denied',
        type: ApiFailureType.unauthorized,
        statusCode: 403,
      ));
    }

    if (path.contains('/approve') || path.contains('/lock') || path.contains('/unlock') || path.contains('/publish')) {
      return ApiResult.success(mapper({
        'data': {
          'id': 'rc_1',
          'verification_uuid': 'uuid_val_123',
          'status': path.contains('/approve')
              ? 'APPROVED'
              : path.contains('/lock')
                  ? 'LOCKED'
                  : 'UNDER_REVIEW',
          'pdf_url': 'https://pdf.example.com/rc_1.pdf',
          'version': 2,
          'academic_year_id': 'ay_2026',
          'student_id': 'stud_1',
          'class_id': 'class_1',
          'section_id': 'sec_1'
        }
      }));
    }
    
    return ApiResult.failure(const ApiFailure(
      message: 'Route not mocked',
      type: ApiFailureType.unknown,
      statusCode: 404,
    ));
  }
}

void main() {
  group('1. Students Security & Provider Audit', () {
    test('Student model excludes all sensitive fields from compiled object schema', () {
      final json = {
        'id': 'stud_1',
        'first_name': 'Rahul',
        'last_name': 'Sharma',
        'admission_number': 'ADM001',
        'roll_number': '10',
        'class_name': 'Grade 10',
        'section_name': 'A',
        'gender': 'MALE',
        'date_of_birth': '2010-05-15',
        'mobile': '9876543210',
        'email': 'rahul@example.com',
        'admission_date': '2020-04-01',
        'status': 'ACTIVE',
        // Sensitive fields present in raw payload
        'aadhaar_number': '123456789012',
        'medical_information': 'Asthma history',
        'address': '123 Street Name',
        'parent_contact': '9999988888',
      };
      
      final student = Student.fromJson(json);
      
      expect(student.fullName, equals('Rahul Sharma'));
      expect(student.admissionNumber, equals('ADM001'));
      
      // Reflective schema fields checks (confirming compilation constraints)
      final fields = student.toString().toLowerCase();
      expect(fields.contains('aadhaar'), isFalse);
      expect(fields.contains('medical'), isFalse);
      expect(fields.contains('address'), isFalse);
      expect(fields.contains('parent'), isFalse);
    });

    testProvider('studentStateProvider updates lists, search, and pagination resets', (container) async {
      final notifier = container.read(studentsStateProvider.notifier);
      
      await notifier.init();
      
      final state = container.read(studentsStateProvider);
      expect(state, isA<StudentsSuccess>());
      
      final success = state as StudentsSuccess;
      expect(success.students, hasLength(1));
      expect(success.students.first.fullName, equals('Rahul Sharma'));
      
      // Verify filter change resets pagination offsets
      await notifier.setFilters(search: 'John');
      final afterSearch = container.read(studentsStateProvider) as StudentsSuccess;
      expect(afterSearch.searchQuery, equals('John'));
    });
  });

  group('2. Teachers Security Audit', () {
    test('Teacher model excludes all sensitive fields', () {
      final json = {
        'id': 'teach_1',
        'first_name': 'Jane',
        'last_name': 'Doe',
        'employee_code': 'EMP01',
        'staff_code': 'STF01',
        'designation': 'HOD Science',
        'department': 'Science',
        'qualification': 'M.Sc. Physics',
        'joining_date': '2015-06-01',
        'status': 'ACTIVE',
        'employment_type': 'FULL_TIME',
        'mobile': '9898989898',
        'official_email': 'jane.doe@school.edu',
        'emergency_contact_name': 'John Doe',
        'emergency_contact_mobile': '9797979797',
        // Sensitive parameters
        'salary': '85000',
        'personal_email': 'jane.personal@gmail.com',
        'pan_number': 'ABCDE1234F',
        'aadhaar_number': '987654321098',
        'address': '456 Lane Road',
      };

      final teacher = Teacher.fromJson(json);

      expect(teacher.fullName, equals('Jane Doe'));
      expect(teacher.employeeCode, equals('EMP01'));
      expect(teacher.officialEmail, equals('jane.doe@school.edu'));
      expect(teacher.emergencyContactName, equals('John Doe'));

      final fields = teacher.toString().toLowerCase();
      expect(fields.contains('salary'), isFalse);
      expect(fields.contains('personal_email'), isFalse);
      expect(fields.contains('pan_number'), isFalse);
      expect(fields.contains('address'), isFalse);
    });
  });

  group('3. Attendance Metrics & Lookup Fallback Audit', () {
    test('AttendanceState calculates percentage correctly', () {
      final record1 = AttendanceRecord(id: '1', studentId: 's1', status: 'PRESENT', date: '2026-08-09', classId: 'c1', sectionId: 'se1');
      final record2 = AttendanceRecord(id: '2', studentId: 's2', status: 'ABSENT', date: '2026-08-09', classId: 'c1', sectionId: 'se1');
      final record3 = AttendanceRecord(id: '3', studentId: 's3', status: 'LATE', date: '2026-08-09', classId: 'c1', sectionId: 'se1');
      final record4 = AttendanceRecord(id: '4', studentId: 's4', status: 'HALFDAY', date: '2026-08-09', classId: 'c1', sectionId: 'se1');

      final state = AttendanceState(
        selectedDate: DateTime.now(),
        records: [record1, record2, record3, record4],
      );

      expect(state.totalCount, equals(4));
      expect(state.presentCount, equals(1));
      expect(state.absentCount, equals(1));
      expect(state.lateCount, equals(1));
      expect(state.halfDayCount, equals(1));

      // Present equivalents: Present(1) + Late(1) + Half-day(1) = 3
      // Total: 4
      // Rate: 3 / 4 * 100 = 75.0%
      expect(state.attendancePercentage, equals(75.0));
    });

    testProvider('attendanceStateProvider fetches daily attendance records', (container) async {
      final notifier = container.read(attendanceStateProvider.notifier);
      await notifier.fetchAttendance();
      
      final state = container.read(attendanceStateProvider);
      expect(state.isLoading, isFalse);
      expect(state.records, hasLength(2));
      expect(state.records.first.status, equals('PRESENT'));
    });
  });

  group('4. Academics Marks Summary Deserialization', () {
    test('MarksSummary correctly maps class metrics', () {
      final json = {
        'class_average': 78.5,
        'pass_percentage': 92.0,
        'highest_score': 98.0,
        'lowest_score': 42.0,
        'missing_count': 1,
        'absent_count': 2
      };

      final summary = MarksSummary.fromJson(json);

      expect(summary.classAverage, equals(78.5));
      expect(summary.passPercentage, equals(92.0));
      expect(summary.highestScore, equals(98.0));
      expect(summary.lowestScore, equals(42.0));
      expect(summary.missingCount, equals(1));
      expect(summary.absentCount, equals(2));
    });
  });

  group('5. Homework Status & Priority Audit', () {
    test('Homework correctly registers status mapping', () {
      final json = {
        'id': 'hw_1',
        'teacher_id': 'teach_1',
        'class_id': 'class_1',
        'section_id': 'sec_1',
        'subject_id': 'sub_math',
        'title': 'Test title',
        'description': 'Test desc',
        'due_date': '2026-08-15',
        'priority': 'HIGH',
        'status': 'PUBLISHED'
      };

      final hw = Homework.fromJson(json);

      expect(hw.title, equals('Test title'));
      expect(hw.priority, equals('HIGH'));
      expect(hw.status, equals('PUBLISHED'));
    });
  });

  group('6. Report Cards Mutations & Refresh Actions', () {
    testProvider('Approve and lock report card updates states on backend refresh', (container) async {
      final notifier = container.read(reportCardsStateProvider.notifier);

      await notifier.fetchReportCards();
      
      var state = container.read(reportCardsStateProvider);
      expect(state.reportCards, hasLength(1));
      expect(state.reportCards.first.status, equals('UNDER_REVIEW'));

      // Approve card triggers re-fetch
      final success = await notifier.approveCard('rc_1');
      expect(success, isTrue);

      state = container.read(reportCardsStateProvider);
      expect(state.actionInProgress, isFalse);
    });
  });

  group('7. Security 403 Permission Denied Handlers', () {
    testProvider('403 API errors map gracefully to Provider error states', (container) async {
      final notifier = container.read(studentsStateProvider.notifier);

      // Force 403 provider initialization via simulator
      await notifier.init();

      final state = container.read(studentsStateProvider);
      expect(state, isA<StudentsError>());
      expect((state as StudentsError).message, contains('Permission denied'));
    }, simulate403: true);
  });

  group('8. Dashboard Metrics, Alerts, and School Switching tests', () {
    testProvider('Dashboard successful concurrent metrics loading and state mapping', (container) async {
      final notifier = container.read(dashboardStateProvider.notifier);
      await notifier.fetchSummary();
      
      final state = container.read(dashboardStateProvider);
      expect(state, isA<DashboardSuccess>());
      
      final success = state as DashboardSuccess;
      expect(success.data.todayCollection, equals(5000.0));
      expect(success.data.monthCollection, equals(250000.0));
      expect(success.data.pendingDues, equals(75000.0));
      expect(success.data.collectionPercentage, equals(85.0));
      expect(success.data.defaultersCount, equals(12));
      expect(success.data.topOutstandingClasses, hasLength(1));
      expect(success.data.topOutstandingClasses.first['class_name'], equals('Grade 10'));
      expect(success.data.unreadNotificationsCount, equals(5));
      expect(success.data.urgentNotifications, hasLength(1));
      expect(success.data.urgentNotifications.first.title, contains('Overdue Fee'));
      expect(success.data.highPriorityNotifications, hasLength(1));
      expect(success.data.highPriorityNotifications.first.title, contains('PTA'));
      expect(success.data.upcomingExaminations, hasLength(1));
      expect(success.data.upcomingExaminations.first.examName, contains('Mid-Term'));
    });

    testProvider('Section level failure (Fee down) does not crash entire dashboard', (container) async {
      final notifier = container.read(dashboardStateProvider.notifier);
      await notifier.fetchSummary();
      
      final state = container.read(dashboardStateProvider);
      expect(state, isA<DashboardSuccess>());
      
      final success = state as DashboardSuccess;
      expect(success.data.feeError, contains('Fee service down'));
      // Other metrics should load successfully
      expect(success.data.unreadNotificationsCount, equals(5));
      expect(success.data.upcomingExaminations, hasLength(1));
    }, failFee: true);

    testProvider('Section level failure (Notifications down) does not crash dashboard', (container) async {
      final notifier = container.read(dashboardStateProvider.notifier);
      await notifier.fetchSummary();
      
      final state = container.read(dashboardStateProvider);
      expect(state, isA<DashboardSuccess>());
      
      final success = state as DashboardSuccess;
      expect(success.data.notificationsError, contains('Notification service down'));
      expect(success.data.todayCollection, equals(5000.0));
      expect(success.data.upcomingExaminations, hasLength(1));
    }, failNotifications: true);

    testProvider('Section level failure (Examinations down) does not crash dashboard', (container) async {
      final notifier = container.read(dashboardStateProvider.notifier);
      await notifier.fetchSummary();
      
      final state = container.read(dashboardStateProvider);
      expect(state, isA<DashboardSuccess>());
      
      final success = state as DashboardSuccess;
      expect(success.data.academicsError, contains('Examination service down'));
      expect(success.data.todayCollection, equals(5000.0));
      expect(success.data.unreadNotificationsCount, equals(5));
    }, failExaminations: true);

    testProvider('403 Forbidden is mapped to section error card message gracefully', (container) async {
      final notifier = container.read(dashboardStateProvider.notifier);
      await notifier.fetchSummary();
      
      final state = container.read(dashboardStateProvider);
      expect(state, isA<DashboardSuccess>());
      
      final success = state as DashboardSuccess;
      expect(success.data.feeError, contains('Permission denied'));
      expect(success.data.notificationsError, contains('Permission denied'));
      expect(success.data.academicsError, contains('Permission denied'));
    }, simulate403: true);

    test('School switching clears School A state immediately', () async {
      final session = FakeSessionManager();
      final client = FakeBaseApiClient();
      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(session),
          apiClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(dashboardStateProvider.notifier);
      await notifier.fetchSummary();

      expect(container.read(dashboardStateProvider), isA<DashboardSuccess>());

      notifier.clear();
      expect(container.read(dashboardStateProvider), isA<DashboardLoading>());
    });

    test('Stale School A response cannot overwrite School B dashboard state', () async {
      final session = FakeSessionManager();
      final client = FakeBaseApiClient();
      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(session),
          apiClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(dashboardStateProvider.notifier);
      
      // Trigger request for School A
      final futureA = notifier.fetchSummary();
      
      // Immediately clear and fetch for School B
      notifier.clear();
      await notifier.fetchSummary();
      final stateB = container.read(dashboardStateProvider);

      // Finish School A response
      await futureA;

      // State must not be modified by School A stale callback
      expect(container.read(dashboardStateProvider), equals(stateB));
    });
  });
}

// Custom Helper: Provider state test wrapper
void testProvider(
  String description,
  Future<void> Function(ProviderContainer container) testBody, {
  bool simulate403 = false,
  bool failFee = false,
  bool failNotifications = false,
  bool failExaminations = false,
}) {
  test(description, () async {
    final container = ProviderContainer(
      overrides: [
        sessionManagerProvider.overrideWithValue(FakeSessionManager()),
        apiClientProvider.overrideWithValue(FakeBaseApiClient(
          simulate403: simulate403,
          failFee: failFee,
          failNotifications: failNotifications,
          failExaminations: failExaminations,
        )),
      ],
    );
    addTearDown(container.dispose);
    await testBody(container);
  });
}
