import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:admin_portal/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/school_setup/data/models/school_setup_models.dart';

class MockBulkApiClient extends BaseApiClient {
  MockBulkApiClient() : super(Dio());

  bool simulateParse404 = false;
  bool simulateTimetableFailure = false;
  bool simulateMarkFailureForSession2 = false;

  List<Map<String, dynamic>> studentsData = [];
  List<Map<String, dynamic>> existingSessionsData = [];
  List<Map<String, dynamic>> timetablesData = [];

  final List<Map<String, dynamic>> postedSessions = [];
  final List<Map<String, dynamic>> postedMarkings = [];
  final List<Map<String, dynamic>> postedChunks = [];
  final List<String> requestedEndpoints = [];
  bool simulateChunkFailure = false;
  int failOnBatchIndex = -1;

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    requestedEndpoints.add('GET $path');

    if (path.contains('/students')) {
      final uri = Uri.parse('http://dummy$path');
      final limit = int.tryParse(uri.queryParameters['limit'] ?? '100') ?? 100;
      final skip = int.tryParse(uri.queryParameters['skip'] ?? '0') ?? 0;
      if (limit > 100) {
        return ApiResult.failure(const ApiFailure(
          message: 'Input should be less than or equal to 100',
          type: ApiFailureType.validation,
          statusCode: 422,
        ));
      }
      final paged = studentsData.skip(skip).take(limit).toList();
      return ApiResult.success(mapper({
        'data': paged,
      }));
    }

    if (path.contains('/attendances/sessions')) {
      final uri = Uri.parse('http://dummy$path');
      final classId = uri.queryParameters['class_id'];
      final sectionId = uri.queryParameters['section_id'];
      final date = uri.queryParameters['attendance_date'];

      var filtered = existingSessionsData;
      if (classId != null) {
        filtered = filtered.where((s) => s['class_id'] == classId).toList();
      }
      if (sectionId != null) {
        filtered = filtered.where((s) => s['section_id'] == sectionId).toList();
      }
      if (date != null) {
        filtered = filtered.where((s) => s['attendance_date'] == date).toList();
      }

      return ApiResult.success(mapper({
        'data': filtered,
      }));
    }

    if (path.contains('/timetables')) {
      if (simulateTimetableFailure) {
        return ApiResult.failure(const ApiFailure(
          message: 'No timetable found',
          type: ApiFailureType.server,
          statusCode: 404,
        ));
      }
      return ApiResult.success(mapper({
        'data': timetablesData,
      }));
    }

    if (path.contains('/attendances/daily')) {
      return ApiResult.success(mapper({
        'data': {'total_students': 100, 'present': 90, 'absent': 10}
      }));
    }

    if (path.contains('/classes')) {
      return ApiResult.success(mapper({'data': []}));
    }

    return ApiResult.failure(const ApiFailure(
      message: 'Endpoint not mocked',
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
    requestedEndpoints.add('POST $path');

    if (path.contains('/import-jobs/parse')) {
      if (simulateParse404) {
        return ApiResult.failure(const ApiFailure(
          message: 'Not Found',
          type: ApiFailureType.server,
          statusCode: 404,
        ));
      }

      return ApiResult.success(mapper({
        'data': {
          'headers': [
            'admission_number',
            'student_name',
            'class_code',
            'section_code',
            'attendance_date',
            'session_type',
            'attendance_status',
            'attendance_reason',
            'remarks'
          ],
          'rows': [
            ['ADM001', 'Aarav Sharma', 'C5', 'C5-A', '2026-09-12', 'MORNING', 'PRESENT', '', 'On time'],
            ['ADM002', 'Diya Patel', 'C5', 'C5-A', '2026-09-12', 'MORNING', 'ABSENT', 'SICK', 'Fever'],
          ],
          'total_rows': 2,
        }
      }));
    }

    if (path.contains('/attendances/session') && !path.contains('/mark')) {
      final payload = Map<String, dynamic>.from(data as Map);
      postedSessions.add(payload);
      final newId = 'session_gen_${postedSessions.length}';
      return ApiResult.success(mapper({
        'data': {
          'id': newId,
          'status': 'DRAFT',
          'session_type': payload['session_type'] ?? 'FULL_DAY',
        }
      }));
    }

    if (path.contains('/attendances/bulk/chunk')) {
      final payload = Map<String, dynamic>.from(data as Map);
      postedChunks.add(payload);
      final records = payload['records'] as List;
      final batchIndex = payload['batch_index'] as int? ?? 1;
      final totalBatches = payload['total_batches'] as int? ?? 1;

      if (simulateChunkFailure || (failOnBatchIndex == batchIndex)) {
        return ApiResult.failure(ApiFailure(
          message: 'Simulated network or database timeout on batch $batchIndex',
          type: ApiFailureType.server,
          statusCode: 500,
        ));
      }

      return ApiResult.success(mapper({
        'data': {
          'import_id': payload['import_id'],
          'batch_index': batchIndex,
          'total_batches': totalBatches,
          'total_rows': payload['total_rows'] ?? records.length,
          'imported_rows': records.length,
          'skipped_rows': 0,
          'failed_rows': 0,
          'status': 'COMMITTED',
          'timing': {
            'session_resolution_ms': 5.0,
            'attendance_lookup_ms': 2.0,
            'insert_update_ms': 10.0,
            'audit_ms': 3.0,
            'commit_ms': 4.0,
            'total_batch_ms': 24.0,
          }
        }
      }));
    }

    if (path.contains('/imports/record')) {
      return ApiResult.success(mapper({
        'data': {'id': 'job_recorded_123', 'status': 'COMPLETED'}
      }));
    }

    if (path.contains('/mark')) {
      final payload = Map<String, dynamic>.from(data as Map);
      postedMarkings.add({'path': path, 'data': payload});

      if (simulateMarkFailureForSession2 && path.contains('session_gen_2')) {
        return ApiResult.failure(const ApiFailure(
          message: 'Failed to record session marking',
          type: ApiFailureType.server,
          statusCode: 500,
        ));
      }

      return ApiResult.success(mapper({
        'data': {'status': 'SUBMITTED'}
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

  late MockBulkApiClient mockApi;
  late ProviderContainer container;

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
    ),
    const ClassDto(
      id: 'class_6',
      tenantId: 'tenant_1',
      schoolId: 'school_1',
      academicYearId: 'ay_1',
      name: 'Class 6',
      code: 'C6',
      level: 6,
      category: 'MIDDLE',
      capacity: 40,
      status: 'ACTIVE',
      isActive: true,
      version: 1,
    ),
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
    ),
    const SectionDto(
      id: 'sec_b',
      tenantId: 'tenant_1',
      schoolId: 'school_1',
      academicYearId: 'ay_1',
      classId: 'class_5',
      name: 'Section B',
      code: 'C5-B',
      capacity: 40,
      sortOrder: 2,
      status: 'ACTIVE',
      isActive: true,
      version: 1,
    ),
    const SectionDto(
      id: 'sec_6a',
      tenantId: 'tenant_1',
      schoolId: 'school_1',
      academicYearId: 'ay_1',
      classId: 'class_6',
      name: 'Section A',
      code: 'C6-A',
      capacity: 40,
      sortOrder: 1,
      status: 'ACTIVE',
      isActive: true,
      version: 1,
    ),
  ];

  setUp(() {
    mockApi = MockBulkApiClient();

    mockApi.studentsData = [
      {
        'id': 'stud_1',
        'tenant_id': 'tenant_1',
        'school_id': 'school_1',
        'academic_year_id': 'ay_1',
        'class_id': 'class_5',
        'section_id': 'sec_a',
        'admission_number': 'ADM001',
        'roll_number': '1',
        'first_name': 'Aarav',
        'last_name': 'Sharma',
        'gender': 'MALE',
        'status': 'ACTIVE',
        'is_active': true,
      },
      {
        'id': 'stud_2',
        'tenant_id': 'tenant_1',
        'school_id': 'school_1',
        'academic_year_id': 'ay_1',
        'class_id': 'class_5',
        'section_id': 'sec_a',
        'admission_number': 'ADM002',
        'roll_number': '2',
        'first_name': 'Diya',
        'last_name': 'Patel',
        'gender': 'FEMALE',
        'status': 'ACTIVE',
        'is_active': true,
      },
      {
        'id': 'stud_3',
        'tenant_id': 'tenant_1',
        'school_id': 'school_1',
        'academic_year_id': 'ay_1',
        'class_id': 'class_6',
        'section_id': 'sec_6a',
        'admission_number': 'ADM003',
        'roll_number': '3',
        'first_name': 'Rohan',
        'last_name': 'Gupta',
        'gender': 'MALE',
        'status': 'ACTIVE',
        'is_active': true,
      },
    ];

    mockApi.timetablesData = [
      {'id': 'tt_c5_a', 'class_id': 'class_5', 'section_id': 'sec_a'},
      {'id': 'tt_c6_a', 'class_id': 'class_6', 'section_id': 'sec_6a'},
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

  group('Bulk Attendance Upload Canonical Frontend Tests', () {
    test('1. CSV files are parsed locally in-memory with zero network requests to /import-jobs/parse', () async {
      mockApi.simulateParse404 = false;
      final notifier = container.read(bulkAttendanceUploadProvider.notifier);

      const csvContent = '''admission_number,student_name,class_code,section_code,attendance_date,session_type,attendance_status,attendance_reason,remarks
ADM001,Aarav Sharma,C5,C5-A,2026-09-12,MORNING,PRESENT,,On time
ADM002,Diya Patel,C5,C5-A,2026-09-12,MORNING,ABSENT,SICK,Fever
''';
      notifier.selectFile(utf8.encode(csvContent), 'attendance.csv');

      await notifier.validateFile('ay_1');

      final state = container.read(bulkAttendanceUploadProvider);
      expect(state.currentStep, 2);
      expect(state.validateResult, isNotNull);
      expect(state.validateResult!.totalRows, 2);
      expect(state.validateResult!.validRows, 2);
      expect(state.validateResult!.invalidRows, 0);
      expect(state.parsedRows.length, 2);

      // Verify ZERO network requests were made to /import-jobs/parse
      expect(
        mockApi.requestedEndpoints.any((e) => e.contains('/import-jobs/parse')),
        isFalse,
        reason: 'CSV validation must not call /import-jobs/parse',
      );

      // Check student identity resolution
      expect(state.parsedRows[0].studentId, 'stud_1');
      expect(state.parsedRows[0].studentName, 'Aarav Sharma');
      expect(state.parsedRows[0].sessionType, 'MORNING');
      expect(state.parsedRows[1].studentId, 'stud_2');
      expect(state.parsedRows[1].studentName, 'Diya Patel');
      expect(state.parsedRows[1].attendanceReason, 'SICK');
    });

    test('2. Excel files (.xlsx) attempt remote parsing, and surface friendly guidance on 404 without propagating raw error', () async {
      mockApi.simulateParse404 = true;
      final notifier = container.read(bulkAttendanceUploadProvider.notifier);

      notifier.selectFile(utf8.encode('excel_binary_content'), 'attendance.xlsx');

      await notifier.validateFile('ay_1');

      final state = container.read(bulkAttendanceUploadProvider);
      // Verify /import-jobs/parse was attempted for Excel file
      expect(
        mockApi.requestedEndpoints.any((e) => e.contains('/import-jobs/parse')),
        isTrue,
        reason: 'Non-CSV files should attempt remote spreadsheet parser',
      );
      // Verify raw 404 / Not Found did NOT leak to user
      expect(state.errorMessage, isNotNull);
      expect(state.errorMessage, contains('Excel parsing service is unavailable'));
      expect(state.errorMessage, contains('CSV format'));
      expect(state.errorMessage, isNot(contains('404')));
      expect(state.errorMessage, isNot(contains('Not Found')));
    });

    test('3. Student identity resolution: handles missing student_name by looking up student from admission_number', () async {
      mockApi.simulateParse404 = true;
      final notifier = container.read(bulkAttendanceUploadProvider.notifier);

      const csvContent = '''admission_number,student_name,class_code,section_code,attendance_date,session_type,attendance_status,attendance_reason,remarks
ADM001,,C5,C5-A,2026-09-12,AFTERNOON,PRESENT,,
''';
      notifier.selectFile(utf8.encode(csvContent), 'attendance.csv');

      await notifier.validateFile('ay_1');

      final state = container.read(bulkAttendanceUploadProvider);
      expect(state.parsedRows.length, 1);
      final row = state.parsedRows[0];
      expect(row.isValid, isTrue);
      expect(row.studentId, 'stud_1');
      expect(row.studentName, 'Aarav Sharma');
      expect(row.sessionType, 'AFTERNOON');
    });

    test('4. Unknown admission number produces INVALID row with descriptive error', () async {
      mockApi.simulateParse404 = true;
      final notifier = container.read(bulkAttendanceUploadProvider.notifier);

      const csvContent = '''admission_number,student_name,class_code,section_code,attendance_date,session_type,attendance_status,attendance_reason,remarks
UNKNOWN_999,Ghost Student,C5,C5-A,2026-09-12,FULL_DAY,PRESENT,,
''';
      notifier.selectFile(utf8.encode(csvContent), 'attendance.csv');

      await notifier.validateFile('ay_1');

      final state = container.read(bulkAttendanceUploadProvider);
      expect(state.validateResult!.invalidRows, 1);
      expect(state.validateResult!.validRows, 0);
      expect(state.parsedRows[0].isValid, isFalse);
      expect(state.parsedRows[0].errorMessage, contains("Student with admission number 'UNKNOWN_999' not found"));
    });

    test('5. Class or Section mismatch against student enrollment produces INVALID row', () async {
      mockApi.simulateParse404 = true;
      final notifier = container.read(bulkAttendanceUploadProvider.notifier);

      const csvContent = '''admission_number,student_name,class_code,section_code,attendance_date,session_type,attendance_status,attendance_reason,remarks
ADM001,Aarav Sharma,C6,C6-A,2026-09-12,FULL_DAY,PRESENT,,
''';
      notifier.selectFile(utf8.encode(csvContent), 'attendance.csv');

      await notifier.validateFile('ay_1');

      final state = container.read(bulkAttendanceUploadProvider);
      expect(state.validateResult!.invalidRows, 1);
      expect(state.parsedRows[0].isValid, isFalse);
      expect(state.parsedRows[0].errorMessage, contains("Student belongs to class 'class_5'"));
    });

    test('6. Session types MORNING, AFTERNOON, FULL_DAY are strictly preserved and unknown rejected', () async {
      mockApi.simulateParse404 = true;
      final notifier = container.read(bulkAttendanceUploadProvider.notifier);

      const csvContent = '''admission_number,student_name,class_code,section_code,attendance_date,session_type,attendance_status,attendance_reason,remarks
ADM001,Aarav Sharma,C5,C5-A,2026-09-12,MORNING,PRESENT,,
ADM002,Diya Patel,C5,C5-A,2026-09-12,EVENING,PRESENT,,
ADM003,Rohan Gupta,C6,C6-A,2026-09-12,FULL_DAY,PRESENT,,
''';
      notifier.selectFile(utf8.encode(csvContent), 'attendance.csv');

      await notifier.validateFile('ay_1');

      final state = container.read(bulkAttendanceUploadProvider);
      expect(state.parsedRows[0].sessionType, 'MORNING');
      expect(state.parsedRows[0].isValid, isTrue);

      expect(state.parsedRows[1].isValid, isFalse);
      expect(state.parsedRows[1].errorMessage, contains("Invalid session 'EVENING'"));

      expect(state.parsedRows[2].sessionType, 'FULL_DAY');
      expect(state.parsedRows[2].isValid, isTrue);
    });

    test('7. In-file duplicate detection flags duplicate entry for same student, date, and session', () async {
      mockApi.simulateParse404 = true;
      final notifier = container.read(bulkAttendanceUploadProvider.notifier);

      const csvContent = '''admission_number,student_name,class_code,section_code,attendance_date,session_type,attendance_status,attendance_reason,remarks
ADM001,Aarav Sharma,C5,C5-A,2026-09-12,MORNING,PRESENT,,First mark
ADM001,Aarav Sharma,C5,C5-A,2026-09-12,MORNING,ABSENT,SICK,Second mark
''';
      notifier.selectFile(utf8.encode(csvContent), 'attendance.csv');

      await notifier.validateFile('ay_1');

      final state = container.read(bulkAttendanceUploadProvider);
      expect(state.validateResult!.validRows, 1);
      expect(state.validateResult!.duplicateRows, 1);
      expect(state.parsedRows[0].isValid, isTrue);
      expect(state.parsedRows[1].isValid, isFalse);
      expect(state.parsedRows[1].isDuplicate, isTrue);
      expect(state.parsedRows[1].errorMessage, contains('Duplicate record'));
    });

    test('8. Existing session conflict detection: marks CONFLICT if session exists, INVALID if locked', () async {
      mockApi.simulateParse404 = true;
      mockApi.existingSessionsData = [
        {
          'id': 'sess_unlocked',
          'tenant_id': 'tenant_1',
          'school_id': 'school_1',
          'academic_year_id': 'ay_1',
          'class_id': 'class_5',
          'section_id': 'sec_a',
          'attendance_date': '2026-09-12',
          'session_type': 'MORNING',
          'status': 'SUBMITTED',
          'settings': {'session_type': 'MORNING'},
          'attendances': [],
        },
        {
          'id': 'sess_locked',
          'tenant_id': 'tenant_1',
          'school_id': 'school_1',
          'academic_year_id': 'ay_1',
          'class_id': 'class_6',
          'section_id': 'sec_6a',
          'attendance_date': '2026-09-12',
          'session_type': 'FULL_DAY',
          'status': 'LOCKED',
          'settings': {'session_type': 'FULL_DAY'},
          'attendances': [],
        }
      ];

      final notifier = container.read(bulkAttendanceUploadProvider.notifier);

      const csvContent = '''admission_number,student_name,class_code,section_code,attendance_date,session_type,attendance_status,attendance_reason,remarks
ADM001,Aarav Sharma,C5,C5-A,2026-09-12,MORNING,PRESENT,,Conflict row
ADM003,Rohan Gupta,C6,C6-A,2026-09-12,FULL_DAY,PRESENT,,Locked session row
''';
      notifier.selectFile(utf8.encode(csvContent), 'attendance.csv');

      await notifier.validateFile('ay_1');

      final state = container.read(bulkAttendanceUploadProvider);
      expect(state.validateResult!.conflictRows, 1);
      expect(state.validateResult!.invalidRows, 1);

      expect(state.parsedRows[0].isConflict, isTrue);
      expect(state.parsedRows[1].isValid, isFalse);
      expect(state.parsedRows[1].errorMessage, contains('is locked'));
    });

    test('9. Conflict strategy SKIP_EXISTING excludes conflict rows from execution', () async {
      mockApi.simulateParse404 = true;
      final notifier = container.read(bulkAttendanceUploadProvider.notifier);

      const csvContent = '''admission_number,student_name,class_code,section_code,attendance_date,session_type,attendance_status,attendance_reason,remarks
ADM001,Aarav Sharma,C5,C5-A,2026-09-12,MORNING,PRESENT,,Conflict row
ADM003,Rohan Gupta,C6,C6-A,2026-09-12,FULL_DAY,PRESENT,,Clean row
''';
      notifier.selectFile(utf8.encode(csvContent), 'attendance.csv');

      await notifier.validateFile('ay_1');

      notifier.setConflictStrategy('SKIP_EXISTING');
      await notifier.executeImport();

      final state = container.read(bulkAttendanceUploadProvider);
      expect(state.currentStep, 4);
      expect(state.importResult!.status, 'COMPLETED');

      // Exactly 1 chunk sent
      expect(mockApi.postedChunks.length, 1);
      final chunk = mockApi.postedChunks[0];
      expect(chunk['conflict_strategy'], 'SKIP_EXISTING');
    });

    test('10. End-to-end chunked import: dispatches single chunk request to /attendances/bulk/chunk with MORNING session_type strictly preserved', () async {
      mockApi.simulateParse404 = true;
      final notifier = container.read(bulkAttendanceUploadProvider.notifier);

      const csvContent = '''admission_number,student_name,class_code,section_code,attendance_date,session_type,attendance_status,attendance_reason,remarks
ADM001,Aarav Sharma,C5,C5-A,2026-09-12,MORNING,PRESENT,,Good
ADM002,Diya Patel,C5,C5-A,2026-09-12,MORNING,ABSENT,SICK,Fever
ADM003,Rohan Gupta,C6,C6-A,2026-09-12,FULL_DAY,PRESENT,,Present in Class 6
''';
      notifier.selectFile(utf8.encode(csvContent), 'attendance.csv');

      await notifier.validateFile('ay_1');
      await notifier.executeImport();

      final state = container.read(bulkAttendanceUploadProvider);
      expect(state.currentStep, 4);
      expect(state.importResult, isNotNull);
      expect(state.importResult!.status, 'COMPLETED');
      expect(state.importResult!.importedRows, 3);
      expect(state.importResult!.failedRows, 0);

      // Verify exactly ONE chunk was sent rather than thousands of session/mark requests
      expect(mockApi.postedChunks.length, 1);
      final chunk = mockApi.postedChunks[0];
      expect(chunk['batch_index'], 1);
      expect(chunk['total_batches'], 1);
      expect(chunk['idempotency_key'], contains('_batch_1'));

      final chunkRecords = chunk['records'] as List;
      expect(chunkRecords.length, 3);
      // Strictly preserve MORNING
      expect(chunkRecords[0]['session_type'], 'MORNING');
      expect(chunkRecords[1]['session_type'], 'MORNING');
      expect(chunkRecords[2]['session_type'], 'FULL_DAY');
    });

    test('11. Timeout & Retry Mechanism: saves failed batch index and allows safe retry resuming from failed batch', () async {
      mockApi.simulateParse404 = true;
      mockApi.failOnBatchIndex = 2; // Simulate failure on Batch 2

      final notifier = container.read(bulkAttendanceUploadProvider.notifier);

      const csvContent = '''admission_number,student_name,class_code,section_code,attendance_date,session_type,attendance_status,attendance_reason,remarks
ADM001,Aarav Sharma,C5,C5-A,2026-09-12,MORNING,PRESENT,,Row 1
ADM002,Diya Patel,C5,C5-A,2026-09-12,MORNING,ABSENT,SICK,Row 2
ADM003,Rohan Gupta,C6,C6-A,2026-09-12,FULL_DAY,PRESENT,,Row 3
''';
      notifier.selectFile(utf8.encode(csvContent), 'attendance.csv');

      await notifier.validateFile('ay_1');
      // Execute with chunkSize=1 to generate 3 batches
      await notifier.executeImport(chunkSize: 1);

      var state = container.read(bulkAttendanceUploadProvider);
      expect(state.isImporting, isFalse);
      expect(state.errorMessage, contains('Batch 2 of 3 failed'));
      expect(state.lastFailedBatchIndex, 1); // 0-indexed: batch 2 is index 1
      expect(state.importSuccessCount, 1);

      // Now clear failure condition and retry
      mockApi.failOnBatchIndex = -1;
      await notifier.executeImport(chunkSize: 1, retryFromFailed: true);

      state = container.read(bulkAttendanceUploadProvider);
      expect(state.currentStep, 4);
      expect(state.importResult!.status, 'COMPLETED');
      expect(state.importResult!.importedRows, 3);
      expect(state.lastFailedBatchIndex, isNull);
    });

    test('12. Date validation: invalid date format and future dates are rejected as INVALID', () async {
      mockApi.simulateParse404 = true;
      final notifier = container.read(bulkAttendanceUploadProvider.notifier);

      final futureDate = DateTime.now().add(const Duration(days: 10));
      final futureDateStr = '${futureDate.year}-${futureDate.month.toString().padLeft(2, '0')}-${futureDate.day.toString().padLeft(2, '0')}';

      final csvContent = '''admission_number,student_name,class_code,section_code,attendance_date,session_type,attendance_status,attendance_reason,remarks
ADM001,Aarav Sharma,C5,C5-A,NOT-A-DATE,MORNING,PRESENT,,Bad date
ADM002,Diya Patel,C5,C5-A,$futureDateStr,MORNING,PRESENT,,Future date
''';
      notifier.selectFile(utf8.encode(csvContent), 'attendance.csv');

      await notifier.validateFile('ay_1');

      final state = container.read(bulkAttendanceUploadProvider);
      expect(state.validateResult!.invalidRows, 2);
      expect(state.parsedRows[0].isValid, isFalse);
      expect(state.parsedRows[0].errorMessage, contains('Invalid date format'));
      expect(state.parsedRows[1].isValid, isFalse);
      expect(state.parsedRows[1].errorMessage, contains('in the future'));
    });

    test('13. Preview pagination: manages page navigation and clamps page size without DOM overload', () async {
      final notifier = container.read(bulkAttendanceUploadProvider.notifier);

      expect(container.read(bulkAttendanceUploadProvider).previewCurrentPage, 1);
      expect(container.read(bulkAttendanceUploadProvider).previewPageSize, 25);

      notifier.setPreviewPage(2);
      expect(container.read(bulkAttendanceUploadProvider).previewCurrentPage, 2);

      notifier.setPreviewPageSize(50);
      expect(container.read(bulkAttendanceUploadProvider).previewPageSize, 50);
      expect(container.read(bulkAttendanceUploadProvider).previewCurrentPage, 1);
    });

    test('14. Student resolution & pagination: fetches students across multiple pages with limit <= 100 without hitting 422, and resolves ADM2025001-ADM2025010 as valid', () async {
      // Setup 150 students across multiple pages (limit <= 100 constraint enforced by MockBulkApiClient)
      final List<Map<String, dynamic>> largeStudentRoster = [];
      for (int i = 1; i <= 100; i++) {
        largeStudentRoster.add({
          'id': 'stud_p1_$i',
          'tenant_id': 'tenant_1',
          'school_id': 'school_1',
          'academic_year_id': 'ay_1',
          'class_id': 'class_5',
          'section_id': 'sec_a',
          'class_name': 'Class 5',
          'section_name': 'Section A',
          'admission_number': 'PAGE1_${i.toString().padLeft(3, '0')}',
          'roll_number': '$i',
          'first_name': 'First$i',
          'last_name': 'Last$i',
          'status': 'ACTIVE',
          'is_active': true,
        });
      }

      // Add actual Telangana School test students on page 2 (skip=100)
      final telanganaStudents = [
        ('ADM2025001', 'Tarun', 'Rao', '1'),
        ('ADM2025002', 'Aakanksha', 'Reddy', '2'),
        ('ADM2025003', 'Koushik', 'Sharma', '3'),
        ('ADM2025004', 'Harshini', 'Goud', '4'),
        ('ADM2025005', 'Vikram', 'Chowdary', '5'),
        ('ADM2025006', 'Shravani', 'Varma', '6'),
        ('ADM2025007', 'Satish', 'Naidu', '7'),
        ('ADM2025008', 'Ruchitha', 'Gupta', '8'),
        ('ADM2025009', 'Aditya', 'Murthy', '9'),
        ('ADM2025010', 'Anusha', 'Sastry', '10'),
      ];

      for (final s in telanganaStudents) {
        largeStudentRoster.add({
          'id': 'stud_ts_${s.$1}',
          'tenant_id': 'tenant_1',
          'school_id': 'school_1',
          'academic_year_id': 'ay_1',
          'class_id': 'class_5',
          'section_id': 'sec_a',
          'class_name': 'Class 5',
          'section_name': 'Section A',
          'admission_number': s.$1,
          'roll_number': s.$4,
          'first_name': s.$2,
          'last_name': s.$3,
          'status': 'ACTIVE',
          'is_active': true,
        });
      }

      mockApi.studentsData = largeStudentRoster;
      mockApi.requestedEndpoints.clear();

      final notifier = container.read(bulkAttendanceUploadProvider.notifier);

      final csvLines = [
        'admission_number,student_name,class_code,section_code,attendance_date,session_type,attendance_status,attendance_reason,remarks',
        ...telanganaStudents.map((s) => '${s.$1},${s.$2} ${s.$3},C5,C5-A,2026-09-12,MORNING,PRESENT,UNKNOWN,Regular attendance'),
      ];
      final csvContent = '${csvLines.join('\n')}\n';

      notifier.selectFile(utf8.encode(csvContent), 'edupulse_attendance_bulk_test_data.csv');
      await notifier.validateFile('ay_1');

      final state = container.read(bulkAttendanceUploadProvider);

      // Verify requests obeyed FastAPI limit <= 100 contract and paginated across pages
      final studentCalls = mockApi.requestedEndpoints.where((e) => e.contains('/students')).toList();
      expect(studentCalls.length, 2);
      expect(studentCalls[0], contains('skip=0&limit=100'));
      expect(studentCalls[1], contains('skip=100&limit=100'));
      expect(mockApi.requestedEndpoints.any((e) => e.contains('limit=1000')), isFalse);

      // Verify validation result: all 10 students resolved canonically
      expect(state.validateResult, isNotNull);
      expect(state.validateResult!.totalRows, 10);
      expect(state.validateResult!.validRows, 10);
      expect(state.validateResult!.invalidRows, 0);
      expect(state.validateResult!.duplicateRows, 0);

      // Verify each row in preview and parsed rows is valid and resolved
      for (int i = 0; i < 10; i++) {
        final parsed = state.parsedRows[i];
        final expected = telanganaStudents[i];
        expect(parsed.isValid, isTrue, reason: 'Row $i (${expected.$1}) must be valid');
        expect(parsed.admissionNumber, expected.$1);
        expect(parsed.studentName, '${expected.$2} ${expected.$3}');
        expect(parsed.studentId, 'stud_ts_${expected.$1}');
        expect(parsed.errorMessage, isNull);

        final preview = state.validateResult!.previewRows[i];
        expect(preview.validationStatus, 'VALID');
        expect(preview.admissionNumber, expected.$1);
        expect(preview.errorMessage, isNull);
      }
    });

    test('15. Strict validation preserved: unknown admission numbers and inactive students remain INVALID with descriptive reason', () async {
      mockApi.studentsData = [
        {
          'id': 'stud_active',
          'school_id': 'school_1',
          'class_id': 'class_5',
          'section_id': 'sec_a',
          'admission_number': 'ADM2025001',
          'first_name': 'Tarun',
          'last_name': 'Rao',
          'status': 'ACTIVE',
          'is_active': true,
        },
        {
          'id': 'stud_inactive',
          'school_id': 'school_1',
          'class_id': 'class_5',
          'section_id': 'sec_a',
          'admission_number': 'ADM_INACTIVE',
          'first_name': 'Inactive',
          'last_name': 'Student',
          'status': 'INACTIVE',
          'is_active': false,
        },
      ];

      final notifier = container.read(bulkAttendanceUploadProvider.notifier);

      const csvContent = '''admission_number,student_name,class_code,section_code,attendance_date,session_type,attendance_status,attendance_reason,remarks
ADM2025001,Tarun Rao,C5,C5-A,2026-09-12,MORNING,PRESENT,UNKNOWN,Regular
UNKNOWN999,Ghost Student,C5,C5-A,2026-09-12,MORNING,PRESENT,UNKNOWN,Unknown student
ADM_INACTIVE,Inactive Student,C5,C5-A,2026-09-12,MORNING,PRESENT,UNKNOWN,Inactive student
''';
      notifier.selectFile(utf8.encode(csvContent), 'test_validation.csv');
      await notifier.validateFile('ay_1');

      final state = container.read(bulkAttendanceUploadProvider);
      expect(state.validateResult!.totalRows, 3);
      expect(state.validateResult!.validRows, 1);
      expect(state.validateResult!.invalidRows, 2);

      // ADM2025001 is valid
      expect(state.parsedRows[0].isValid, isTrue);

      // UNKNOWN999 is invalid with campus mismatch error
      expect(state.parsedRows[1].isValid, isFalse);
      expect(state.parsedRows[1].errorMessage, contains("Student with admission number 'UNKNOWN999' not found in this school campus"));

      // ADM_INACTIVE is invalid with inactive error
      expect(state.parsedRows[2].isValid, isFalse);
      expect(state.parsedRows[2].errorMessage, contains("Student 'ADM_INACTIVE' is marked inactive"));
    });
  });
}
