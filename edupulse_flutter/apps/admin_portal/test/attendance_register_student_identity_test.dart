import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:admin_portal/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/school_setup/data/models/school_setup_models.dart';

class MockRegisterApiClient extends BaseApiClient {
  MockRegisterApiClient() : super(Dio());

  bool simulateRegister404 = true;
  List<Map<String, dynamic>> customAttendanceData = [];
  List<Map<String, dynamic>> studentsData = [];
  List<Map<String, dynamic>> sessionsData = [];
  Map<String, dynamic>? lastSessionPostPayload;

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (path.contains('/attendances/register')) {
      if (simulateRegister404) {
        return ApiResult.failure(const ApiFailure(
          message: 'Not Found',
          type: ApiFailureType.server,
          statusCode: 404,
        ));
      }
      return ApiResult.success(mapper({
        'data': customAttendanceData,
        'meta': {'total': customAttendanceData.length}
      }));
    }

    if (path.contains('/attendances/sessions')) {
      return ApiResult.success(mapper({
        'data': sessionsData,
      }));
    }

    if (path.startsWith('/attendances') && !path.contains('/sessions')) {
      return ApiResult.success(mapper({
        'data': customAttendanceData,
      }));
    }

    if (path.contains('/students/')) {
      final uri = Uri.parse(path);
      final id = uri.pathSegments.last;
      final match = studentsData.firstWhere(
        (s) => s['id'] == id,
        orElse: () => <String, dynamic>{},
      );
      if (match.isNotEmpty) {
        return ApiResult.success(mapper({'data': match}));
      }
      return ApiResult.failure(const ApiFailure(
        message: 'Not Found',
        type: ApiFailureType.server,
        statusCode: 404,
      ));
    }

    if (path.startsWith('/students') || path.contains('/students?')) {
      return ApiResult.success(mapper({
        'data': studentsData,
      }));
    }

    if (path.contains('/timetables')) {
      return ApiResult.success(mapper({
        'data': [
          {'id': 'tt_slot_1', 'subject_id': 'sub_1'}
        ]
      }));
    }

    return ApiResult.failure(const ApiFailure(
      message: 'Not Found',
      type: ApiFailureType.server,
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
    if (path.contains('/attendances/session') && !path.contains('/mark')) {
      lastSessionPostPayload = Map<String, dynamic>.from(data as Map);
      return ApiResult.success(mapper({
        'data': {
          'id': 'session_uuid',
          'status': 'DRAFT',
          'session_type': lastSessionPostPayload?['session_type'] ?? 'FULL_DAY',
        }
      }));
    }

    if (path.contains('/mark')) {
      return ApiResult.success(mapper({
        'data': {'id': 'session_uuid', 'status': 'SUBMITTED'}
      }));
    }

    return ApiResult.failure(const ApiFailure(
      message: 'Endpoint not mocked',
      type: ApiFailureType.server,
      statusCode: 404,
    ));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockRegisterApiClient mockApi;
  late ProviderContainer container;

  setUp(() {
    mockApi = MockRegisterApiClient();

    // Standard school setup classes and sections
    final mockClasses = [
      const ClassDto(
        id: 'class_5',
        tenantId: 'tenant_1',
        schoolId: 'school_1',
        academicYearId: 'ay_1',
        name: 'Class 5',
        code: 'C5',
        level: 5,
        category: 'PRIMARY',
        capacity: 40,
        status: 'ACTIVE',
        isActive: true,
        version: 1,
      )
    ];

    final mockSections = [
      const SectionDto(
        id: 'sec_a',
        tenantId: 'tenant_1',
        schoolId: 'school_1',
        academicYearId: 'ay_1',
        classId: 'class_5',
        name: 'Section A',
        code: 'C5-A',
        capacity: 40,
        sortOrder: 1,
        status: 'ACTIVE',
        isActive: true,
        version: 1,
      )
    ];

    // Standard students
    mockApi.studentsData = [
      {
        'id': 'stud_uuid',
        'tenant_id': 'tenant_1',
        'school_id': 'school_1',
        'academic_year_id': 'ay_1',
        'class_id': 'class_5',
        'section_id': 'sec_a',
        'admission_number': 'ADM005',
        'roll_number': '5',
        'first_name': 'Bhavani',
        'last_name': 'Patel',
        'gender': 'FEMALE',
        'date_of_birth': '2015-05-15',
        'admission_date': '2020-06-01',
        'created_at': '2020-06-01T00:00:00Z',
        'updated_at': '2020-06-01T00:00:00Z',
        'status': 'ACTIVE',
        'is_active': true,
      },
      {
        'id': 'stud_other',
        'tenant_id': 'tenant_1',
        'school_id': 'school_1',
        'academic_year_id': 'ay_1',
        'class_id': 'class_5',
        'section_id': 'sec_a',
        'admission_number': 'ADM006',
        'roll_number': '6',
        'first_name': 'Suresh',
        'last_name': 'Kumar',
        'gender': 'MALE',
        'date_of_birth': '2015-08-20',
        'admission_date': '2020-06-01',
        'created_at': '2020-06-01T00:00:00Z',
        'updated_at': '2020-06-01T00:00:00Z',
        'status': 'ACTIVE',
        'is_active': true,
      },
    ];

    // Sessions data
    mockApi.sessionsData = [
      {
        'id': 'session_uuid',
        'tenant_id': 'tenant_1',
        'school_id': 'school_1',
        'academic_year_id': 'ay_1',
        'class_id': 'class_5',
        'section_id': 'sec_a',
        'attendance_date': '2026-09-11',
        'session_type': 'MORNING',
        'status': 'SUBMITTED',
        'settings': {'session_type': 'MORNING'},
        'attendances': [],
      }
    ];

    container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(mockApi),
        selectedSchoolIdProvider.overrideWith((ref) => 'school_1'),
        classesProvider('school_1').overrideWith((ref) {
          final notifier = ClassesNotifier(mockApi, 'school_1');
          notifier.state = ClassesState(classes: mockClasses, isLoading: false);
          return notifier;
        }),
        sectionsProvider('school_1').overrideWith((ref) {
          final notifier = SectionsNotifier(mockApi, 'school_1');
          notifier.state = SectionsState(sections: mockSections, isLoading: false);
          return notifier;
        }),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('Attendance Register Student Identity & Session Regression Tests', () {
    test('1. Exact Production-Shaped Payload: ID-only attendance is enriched into a displayable row rather than allowing "-"', () async {
      mockApi.simulateRegister404 = true;
      // Exact production-shaped payload with no student metadata and no session_type
      mockApi.customAttendanceData = [
        {
          'id': 'att_exact_prod_1',
          'tenant_id': 'tenant_1',
          'school_id': 'school_1',
          'academic_year_id': 'ay_1',
          'attendance_session_id': 'session_uuid',
          'student_id': 'stud_uuid',
          'class_id': 'class_5',
          'section_id': 'sec_a',
          'attendance_date': '2026-09-11',
          'attendance_status': 'PRESENT',
          'attendance_source': 'MANUAL',
          'attendance_reason': 'UNKNOWN',
          'remarks': null,
          'parent_viewed': false,
          'is_active': true,
          'settings': {},
          'ai_metrics': {},
          'version': 1,
        }
      ];

      final registerNotifier = container.read(attendanceRegisterProvider.notifier);
      await registerNotifier.fetchRegister();

      final state = container.read(attendanceRegisterProvider);
      expect(state.isLoading, isFalse);
      expect(state.records.length, equals(1));

      final row = state.records.first;
      // Must NOT leak "-" into the register
      expect(row.studentName, equals('Bhavani Patel'));
      expect(row.admissionNumber, equals('ADM005'));
      expect(row.studentRollNumber, equals('5'));
      expect(row.className, equals('Class 5'));
      expect(row.sectionName, equals('Section A'));
      expect(row.sessionType, equals('MORNING'));
      expect(row.attendanceStatus, equals('PRESENT'));
    });

    test('2. Direct API Identity: respects student identity when API directly provides it', () async {
      mockApi.simulateRegister404 = false;
      mockApi.customAttendanceData = [
        {
          'id': 'att_direct_1',
          'tenant_id': 'tenant_1',
          'school_id': 'school_1',
          'academic_year_id': 'ay_1',
          'attendance_session_id': 'session_uuid',
          'student_id': 'stud_direct',
          'student_name': 'Direct Student',
          'admission_number': 'ADM999',
          'roll_number': '99',
          'class_id': 'class_5',
          'section_id': 'sec_a',
          'class_name': 'Class 5',
          'section_name': 'Section A',
          'attendance_date': '2026-09-11',
          'session_type': 'AFTERNOON',
          'attendance_status': 'PRESENT',
          'attendance_source': 'MANUAL',
          'attendance_reason': 'UNKNOWN',
        }
      ];

      final registerNotifier = container.read(attendanceRegisterProvider.notifier);
      await registerNotifier.fetchRegister();

      final state = container.read(attendanceRegisterProvider);
      expect(state.records.length, equals(1));
      final row = state.records.first;
      expect(row.studentName, equals('Direct Student'));
      expect(row.admissionNumber, equals('ADM999'));
      expect(row.sessionType, equals('AFTERNOON'));
    });

    test('3. Session Creation Fix: verifies both session_type and settings.session_type are passed for backend compatibility', () async {
      mockApi.sessionsData = []; // No session exists yet, forces timetable lookup and session creation
      final markNotifier = container.read(dailyAttendanceMarkProvider.notifier);
      markNotifier.setSelection(
        academicYearId: 'ay_1',
        classId: 'class_5',
        sectionId: 'sec_a',
        sessionType: 'MORNING',
        attendanceDate: DateTime(2026, 9, 11),
      );

      await markNotifier.loadRoster();
      final success = await markNotifier.submitAttendance();

      expect(success, isTrue);
      expect(mockApi.lastSessionPostPayload, isNotNull);
      // Both session_type and settings.session_type must be present
      expect(mockApi.lastSessionPostPayload!['session_type'], equals('MORNING'));
      expect(mockApi.lastSessionPostPayload!['settings'], isA<Map>());
      expect((mockApi.lastSessionPostPayload!['settings'] as Map)['session_type'], equals('MORNING'));
    });

    test('4. Name and Admission Number Search: searching for "bhavani" filters correctly in fallback mode', () async {
      mockApi.simulateRegister404 = true;
      mockApi.customAttendanceData = [
        {
          'id': 'att_1',
          'attendance_session_id': 'session_uuid',
          'student_id': 'stud_uuid',
          'class_id': 'class_5',
          'section_id': 'sec_a',
          'attendance_date': '2026-09-11',
          'attendance_status': 'PRESENT',
        },
        {
          'id': 'att_2',
          'attendance_session_id': 'session_uuid',
          'student_id': 'stud_other',
          'class_id': 'class_5',
          'section_id': 'sec_a',
          'attendance_date': '2026-09-11',
          'attendance_status': 'PRESENT',
        }
      ];

      final registerNotifier = container.read(attendanceRegisterProvider.notifier);

      // Search by student name
      registerNotifier.setSearch('bhavani');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(attendanceRegisterProvider);
      expect(state.records.length, equals(1));
      expect(state.records.first.studentName, equals('Bhavani Patel'));
      expect(state.records.first.admissionNumber, equals('ADM005'));

      // Search by admission number
      registerNotifier.setSearch('ADM006');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state2 = container.read(attendanceRegisterProvider);
      expect(state2.records.length, equals(1));
      expect(state2.records.first.studentName, equals('Suresh Kumar'));
      expect(state2.records.first.admissionNumber, equals('ADM006'));
    });

    test('5. Filters (Status, Date-Range) and Pagination: work seamlessly with enriched records', () async {
      mockApi.simulateRegister404 = true;
      mockApi.customAttendanceData = [
        {
          'id': 'att_1',
          'attendance_session_id': 'session_uuid',
          'student_id': 'stud_uuid',
          'class_id': 'class_5',
          'section_id': 'sec_a',
          'attendance_date': '2026-09-11',
          'attendance_status': 'PRESENT',
        },
        {
          'id': 'att_2',
          'attendance_session_id': 'session_uuid',
          'student_id': 'stud_other',
          'class_id': 'class_5',
          'section_id': 'sec_a',
          'attendance_date': '2026-09-11',
          'attendance_status': 'ABSENT',
        }
      ];

      final registerNotifier = container.read(attendanceRegisterProvider.notifier);

      // Filter by status = ABSENT
      registerNotifier.setFilters(status: 'ABSENT');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(attendanceRegisterProvider);
      expect(state.records.length, equals(1));
      expect(state.records.first.attendanceStatus, equals('ABSENT'));
      expect(state.records.first.studentName, equals('Suresh Kumar'));
    });
  });
}
