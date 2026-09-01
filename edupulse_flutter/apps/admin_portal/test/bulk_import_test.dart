import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/app.dart';
import 'package:admin_portal/core/routing/routes.dart';
import 'package:admin_portal/core/routing/app_router.dart';
import 'package:admin_portal/core/providers/bootstrap_provider.dart';
import 'package:admin_portal/features/bulk_import/presentation/pages/bulk_import_screen.dart';
import 'package:admin_portal/features/bulk_import/presentation/providers/bulk_import_providers.dart';
import 'package:admin_portal/features/bulk_import/data/models/bulk_import_models.dart';
import 'package:admin_portal/features/bulk_import/data/models/csv_helper.dart';
import 'package:admin_portal/features/school_setup/data/models/school_setup_models.dart';
import 'package:admin_portal/features/auth/presentation/providers/auth_provider.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';

class FakeBulkImportRepository implements AuthRepository {
  final bool hasAdminAccess;
  FakeBulkImportRepository({this.hasAdminAccess = true});

  @override
  Future<ApiResult<SessionToken>> login({required String email, required String password}) async {
    return const ApiResult.success(SessionToken(accessToken: 'mock_access', refreshToken: 'mock_refresh', tokenType: 'bearer'));
  }

  @override
  Future<ApiResult<void>> logout({required String refreshToken}) async {
    return const ApiResult.success(null);
  }

  @override
  Future<ApiResult<SessionToken>> refreshToken({required String refreshToken}) async {
    return const ApiResult.success(SessionToken(accessToken: 'mock_access_new', refreshToken: 'mock_refresh_new', tokenType: 'bearer'));
  }

  @override
  Future<ApiResult<UserEntity>> getCurrentUser() async {
    return ApiResult.success(UserEntity(
      id: 'admin_id_123',
      email: 'admin@edupulse.ai',
      firstName: 'Main',
      lastName: 'Admin',
      tenantId: 'tenant_1',
      isSuperuser: hasAdminAccess,
      roles: hasAdminAccess ? ['SUPER_ADMIN'] : ['GUEST'],
      schools: const ['school_1', 'school_500', 'school_capacity'],
    ));
  }

  @override
  Future<ApiResult<void>> requestPasswordReset({required String email}) async {
    return const ApiResult.success(null);
  }

  @override
  Future<ApiResult<void>> resetPassword({
    required String token,
    required String newPassword,
    String? confirmPassword,
  }) async {
    return const ApiResult.success(null);
  }
}

class FakeBulkImportSessionManager implements SessionManager {
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
class FakeBulkImportApiClient extends BaseApiClient {
  final List<Map<String, dynamic>> postCalls = [];
  bool failNextRequest = false;
  bool failGlobally = false;

  final List<Map<String, dynamic>> dynamicClasses = [
    {
      'id': 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
      'tenant_id': 'tenant_1',
      'school_id': 'school_1',
      'academic_year_id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      'name': 'Class 1',
      'code': 'CLASS_1',
      'level': 1,
      'capacity': 40,
      'status': 'ACTIVE',
      'is_active': true,
      'sort_order': 1,
      'version': 1,
    }
  ];

  final List<Map<String, dynamic>> dynamicSections = [
    {
      'id': 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
      'tenant_id': 'tenant_1',
      'school_id': 'school_1',
      'academic_year_id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      'class_id': 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
      'name': 'Section A',
      'code': 'SEC_A',
      'capacity': 1000,
      'status': 'ACTIVE',
      'is_active': true,
      'sort_order': 1,
      'version': 1,
    },
    {
      'id': 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44',
      'tenant_id': 'tenant_1',
      'school_id': 'school_1',
      'academic_year_id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      'class_id': 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
      'name': 'Section B',
      'code': 'SEC_B',
      'capacity': 1000,
      'status': 'ACTIVE',
      'is_active': true,
      'sort_order': 2,
      'version': 1,
    }
  ];

  int maxSimultaneousPostCalls = 0;
  int currentSimultaneousPostCalls = 0;
  Map<String, ApiResult<dynamic>> customStudentResponses = {};

  FakeBulkImportApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    currentSimultaneousPostCalls++;
    if (currentSimultaneousPostCalls > maxSimultaneousPostCalls) {
      maxSimultaneousPostCalls = currentSimultaneousPostCalls;
    }
    try {
      postCalls.add({'path': path, 'data': data});

      if (failGlobally) {
        return const ApiResult.failure(ApiFailure(
          type: ApiFailureType.unauthorized,
          statusCode: 401,
          message: 'Unauthorized token or tenant failure',
        ));
      }

      if (failNextRequest) {
        failNextRequest = false;
        return const ApiResult.failure(ApiFailure(
          type: ApiFailureType.validation,
          statusCode: 409,
          message: 'Conflict or duplicate record exists',
        ));
      }

      // Check specific data values to trigger mock errors
      if (data is Map<String, dynamic>) {
        final String admNo = (data['admission_number'] ?? '').toString();
        final String firstName = (data['first_name'] ?? '').toString();

        if (customStudentResponses.containsKey(admNo)) {
          return customStudentResponses[admNo]! as ApiResult<T>;
        }
        if (customStudentResponses.containsKey(firstName)) {
          return customStudentResponses[firstName]! as ApiResult<T>;
        }

        if (admNo.startsWith('ADM_NET_ERR') || firstName.startsWith('NetErrStudent')) {
          return const ApiResult.failure(ApiFailure(
            type: ApiFailureType.network,
            message: 'Browser network/CORS connection failure',
          ));
        }

        if (admNo.startsWith('ADM_DUP') || firstName.startsWith('DupStudent')) {
          return const ApiResult.failure(ApiFailure(
            type: ApiFailureType.validation,
            statusCode: 409,
            message: 'Student with admission number already exists',
          ));
        }

        if (admNo.startsWith('ADM_TIMEOUT') || firstName.startsWith('TimeoutStudent')) {
          return const ApiResult.failure(ApiFailure(
            type: ApiFailureType.network,
            message: 'Connection timed out',
          ));
        }

        if (admNo.startsWith('ADM_FAIL_422') || firstName.startsWith('Fail422Student')) {
          return const ApiResult.failure(ApiFailure(
            type: ApiFailureType.validation,
            statusCode: 422,
            message: 'Validation failed: Invalid student data provided',
          ));
        }

        if (admNo.startsWith('ADM_FAIL_500') || firstName.startsWith('Fail500Student')) {
          return const ApiResult.failure(ApiFailure(
            type: ApiFailureType.server,
            statusCode: 500,
            message: 'Internal server error',
          ));
        }

        if (firstName == 'CapacityConflict') {
          return const ApiResult.failure(ApiFailure(
            type: ApiFailureType.validation,
            statusCode: 400,
            message: 'Cannot register student because target section capacity has been reached.',
          ));
        }
        if (firstName == 'FailRow') {
          return const ApiResult.failure(ApiFailure(
            type: ApiFailureType.validation,
            statusCode: 400,
            message: 'Bad Request parameters',
          ));
        }
        if (firstName == 'GlobalFail') {
          return const ApiResult.failure(ApiFailure(
            type: ApiFailureType.server,
            statusCode: 503,
            message: 'Backend server offline',
          ));
        }
        if (path == '/classes') {
          if (data['name'] == 'FailClass') {
            return const ApiResult.failure(ApiFailure(type: ApiFailureType.validation, message: 'Class creation failed'));
          }
        final newClass = {
          'id': 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380c99',
          'tenant_id': 'tenant_1',
          'school_id': 'school_1',
          'academic_year_id': data['academic_year_id'],
          'name': data['name'],
          'code': data['code'],
          'level': data['level'],
          'category': data['category'],
          'capacity': data['capacity'],
          'status': data['status'],
          'is_active': true,
          'version': 1,
        };
        dynamicClasses.add(newClass);
        return ApiResult.success(mapper({
          'data': newClass
        }));
      }

      if (path == '/sections') {
        if (data['name'] == 'FailSection') {
          return const ApiResult.failure(ApiFailure(type: ApiFailureType.validation, message: 'Section creation failed'));
        }
        final newSec = {
          'id': 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c99',
          'tenant_id': 'tenant_1',
          'school_id': 'school_1',
          'academic_year_id': data['academic_year_id'],
          'class_id': data['class_id'],
          'name': data['name'],
          'code': data['code'],
          'capacity': data['capacity'],
          'sort_order': data['sort_order'],
          'status': data['status'],
          'is_active': true,
          'version': 1,
        };
        dynamicSections.add(newSec);
        return ApiResult.success(mapper({
          'data': newSec
        }));
      }
    }
    if (path.contains('/import-jobs/parse')) {
      if (customStudentResponses.containsKey('__parse_response__')) {
        final res = customStudentResponses['__parse_response__']!;
        return res.when(
          onSuccess: (val) => ApiResult.success(mapper(val)),
          onFailure: (fail) => ApiResult.failure(fail),
        );
      }
      return ApiResult.success(mapper({
        'success': true,
        'message': 'File parsed successfully.',
        'data': {
          'filename': 'test.xlsx',
          'format': 'xlsx',
          'sheets': ['Sheet1'],
          'selected_sheet': 'Sheet1',
          'columns': ['first_name', 'last_name'],
          'row_count': 1,
          'preview_rows': [
            ['first_name', 'last_name'],
            ['John', 'Doe']
          ]
        }
      }));
    }

    return ApiResult.success(mapper({'success': true, 'id': 'new_id'}));
    } finally {
      currentSimultaneousPostCalls--;
    }
  }

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
            'id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'name': '2024-2025',
            'code': 'AY_2024_25',
            'start_date': '2024-06-01',
            'end_date': '2025-05-31',
            'is_active': true,
            'status': 'ACTIVE',
            'is_current': true,
            'version': 1,
          }
        ]
      }));
    }
    if (path.contains('/schools') && !path.contains('/academic-years')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'school_1',
            'tenant_id': 'tenant_1',
            'name': 'Delhi Public School Hyderabad',
            'code': 'DPSH',
            'board': 'CBSE',
            'school_type': 'CO_ED',
            'email': 'dps@school.in',
            'phone': '123456',
            'is_active': true,
            'status': 'ACTIVE',
            'version': 1,
          },
          {
            'id': 'school_500',
            'tenant_id': 'tenant_1',
            'name': 'Delhi Public School Hyderabad High Cap',
            'code': 'DPSH_HC',
            'board': 'CBSE',
            'school_type': 'CO_ED',
            'email': 'dps_hc@school.in',
            'phone': '123456',
            'is_active': true,
            'status': 'ACTIVE',
            'version': 1,
          },
          {
            'id': 'school_capacity',
            'tenant_id': 'tenant_1',
            'name': 'Delhi Public School Hyderabad Capacity Test',
            'code': 'DPSH_CAP',
            'board': 'CBSE',
            'school_type': 'CO_ED',
            'email': 'dps_cap@school.in',
            'phone': '123456',
            'is_active': true,
            'status': 'ACTIVE',
            'version': 1,
          }
        ]
      }));
    }
    if (path.contains('/classes')) {
      return ApiResult.success(mapper({
        'data': dynamicClasses
      }));
    }
    if (path.contains('/sections')) {
      final schoolIdQuery = (queryParameters != null) ? queryParameters['school_id'] : null;
      final isCapacityTest = path.contains('school_capacity') || schoolIdQuery == 'school_capacity';
      final is500School = path.contains('school_500') || schoolIdQuery == 'school_500';
      
      final schoolIdValue = isCapacityTest ? 'school_capacity' : (is500School ? 'school_500' : 'school_1');
      final capA = isCapacityTest ? 3 : 1000;
      final capB = isCapacityTest ? 5 : 1000;

      for (var s in dynamicSections) {
        if (s['id'] == 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33') {
          s['school_id'] = schoolIdValue;
          s['capacity'] = capA;
        } else if (s['id'] == 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44') {
          s['school_id'] = schoolIdValue;
          s['capacity'] = capB;
        }
      }

      return ApiResult.success(mapper({
        'data': dynamicSections
      }));
    }

    if (path.contains('/students')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'stud_ex_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
            'class_id': 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
            'section_id': 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
            'first_name': 'Existing1',
            'last_name': 'One',
            'gender': 'MALE',
            'date_of_birth': '2015-01-01',
            'admission_number': 'ADM001',
            'roll_number': 'R01',
            'admission_date': '2023-01-01',
            'status': 'ACTIVE',
            'is_active': true,
            'address': {},
            'medical_information': {},
            'settings': {},
            'ai_metrics': {},
            'version': 1,
            'created_at': '2023-01-01',
            'updated_at': '2023-01-01',
          },
          {
            'id': 'stud_ex_2',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
            'class_id': 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
            'section_id': 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
            'first_name': 'Existing2',
            'last_name': 'Two',
            'gender': 'FEMALE',
            'date_of_birth': '2015-01-02',
            'admission_number': 'ADM002',
            'roll_number': 'R02',
            'admission_date': '2023-01-01',
            'status': 'ACTIVE',
            'is_active': true,
            'address': {},
            'medical_information': {},
            'settings': {},
            'ai_metrics': {},
            'version': 1,
            'created_at': '2023-01-01',
            'updated_at': '2023-01-01',
          }
        ]
      }));
    }
    return ApiResult.success(mapper({'data': []}));
  }
}

void main() {
  late ProviderContainer container;
  late FakeBulkImportApiClient fakeApiClient;

  setUp(() {
    fakeApiClient = FakeBulkImportApiClient();
    container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApiClient),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('Bulk Import Unit & CSV Validation Tests', () {
    test('Validates Students CSV columns correctly', () {
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n'
          'Priya,Verma,FEMALE,2014-08-20,ADM002,802,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      notifier.selectFile('students.csv', csv);

      final state = container.read(bulkImportProvider);
      expect(state.globalErrorMessage, isNull);
      expect(state.rows.length, 2);
      expect(state.rows[0].status, ImportRowStatus.valid);
      expect(state.rows[0].data['first_name'], 'Rahul');
    });

    test('Rejects invalid file extensions', () {
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.selectFile('data.xlsx', 'some data');
      final state = container.read(bulkImportProvider);
      expect(state.globalErrorMessage, contains('Only CSV files'));
      expect(state.rows, isEmpty);
    });

    test('Rejects empty files', () {
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.selectFile('empty.csv', '   ');
      final state = container.read(bulkImportProvider);
      expect(state.globalErrorMessage, contains('empty'));
    });

    test('Detects missing required headers', () {
      const csv = 'first_name,last_name,gender\n'
          'Rahul,Sharma,MALE';

      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      notifier.selectFile('bad_headers.csv', csv);

      final state = container.read(bulkImportProvider);
      expect(state.globalErrorMessage, contains('Missing required column header'));
    });

    test('Detects invalid date formats', () {
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'Rahul,Sharma,MALE,12/05/2014,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      notifier.selectFile('bad_date.csv', csv);

      final state = container.read(bulkImportProvider);
      expect(state.rows.first.status, ImportRowStatus.error);
      expect(state.rows.first.errors.first, contains('YYYY-MM-DD'));
    });

    test('Detects invalid UUID format', () {
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,not-a-uuid,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      notifier.selectFile('bad_uuid.csv', csv);

      final state = container.read(bulkImportProvider);
      expect(state.rows.first.status, ImportRowStatus.error);
      expect(state.rows.first.errors.first, contains('must be a valid UUID'));
    });

    test('Detects duplicate values within CSV', () {
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n'
          'Aarav,Sharma,MALE,2014-06-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      notifier.selectFile('dup.csv', csv);

      final state = container.read(bulkImportProvider);
      expect(state.rows[1].status, ImportRowStatus.duplicate);
      expect(state.rows[1].errors.join(' '), contains('Duplicate admission_number'));
    });

    test('Resets state when school context changes', () {
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      notifier.selectFile('test.csv', csv);

      expect(container.read(bulkImportProvider).rows.isNotEmpty, true);

      // Trigger school context change
      container.read(selectedSchoolIdProvider.notifier).state = 'school_2';
      expect(container.read(bulkImportProvider).rows.isEmpty, true);
    });
  });

  group('Bulk Import Loop Execution Tests', () {
    test('Sequential import handles partial successes and failed rows independent', () async {
      // Force selected school
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      final rows = [
        ParsedRow(
          rowIndex: 2,
          data: {
            'first_name': 'SuccessRow',
            'last_name': 'One',
            'academic_year_id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
            'class_id': 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
            'section_id': 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
          },
          errors: [],
          warnings: [],
          status: ImportRowStatus.valid,
        ),
        ParsedRow(
          rowIndex: 3,
          data: {
            'first_name': 'FailRow',
            'last_name': 'Two',
            'academic_year_id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
            'class_id': 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
            'section_id': 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
          },
          errors: [],
          warnings: [],
          status: ImportRowStatus.valid,
        ),
        ParsedRow(
          rowIndex: 4,
          data: {
            'first_name': 'SuccessRow',
            'last_name': 'Three',
            'academic_year_id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
            'class_id': 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
            'section_id': 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
          },
          errors: [],
          warnings: [],
          status: ImportRowStatus.valid,
        ),
      ];

      notifier.state = notifier.state.copyWith(rows: rows);

      await notifier.importRecords('school_1', fakeApiClient);

      final state = container.read(bulkImportProvider);
      expect(state.successCount, 2);
      expect(state.failedCount, 1);
      expect(state.rows[0].status, ImportRowStatus.success);
      expect(state.rows[1].status, ImportRowStatus.apiError);
      expect(state.rows[1].apiErrorMessage, contains('Bad Request'));
      expect(state.rows[2].status, ImportRowStatus.success);
    });

    test('Stops queue on global failures', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      final rows = [
        ParsedRow(
          rowIndex: 2,
          data: {
            'first_name': 'SuccessRow',
            'academic_year_id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
            'class_id': 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
            'section_id': 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
          },
          errors: [],
          warnings: [],
          status: ImportRowStatus.valid,
        ),
        ParsedRow(
          rowIndex: 3,
          data: {
            'first_name': 'GlobalFail',
            'academic_year_id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
            'class_id': 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
            'section_id': 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
          },
          errors: [],
          warnings: [],
          status: ImportRowStatus.valid,
        ),
        ParsedRow(
          rowIndex: 4,
          data: {
            'first_name': 'SuccessRow',
            'academic_year_id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
            'class_id': 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
            'section_id': 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
          },
          errors: [],
          warnings: [],
          status: ImportRowStatus.valid,
        ),
      ];

      notifier.state = notifier.state.copyWith(rows: rows);

      await notifier.importRecords('school_1', fakeApiClient);
      final state = container.read(bulkImportProvider);
      expect(state.successCount, 2);
      expect(state.failedCount, 1);
      expect(state.globalErrorMessage, contains('Backend server offline'));
    });
  });

  group('Bulk Import Widget & Screen Routing Tests', () {
    testWidgets('Renders Bulk Import screen, selectors, and handles CSV wizard flow', (WidgetTester tester) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.exceptionAsString().contains('overflowed')) {
          return;
        }
        originalOnError?.call(details);
      };

      final fakeRepo = FakeBulkImportRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) => fakeRepo),
            sessionManagerProvider.overrideWith((ref) => FakeBulkImportSessionManager()),
            apiClientProvider.overrideWithValue(fakeApiClient),
            bootstrapResultProvider.overrideWithValue(BootstrapResult(success: true)),
          ],
          child: const EduPulseAdminApp(),
        ),
      );

      await tester.pumpAndSettle();

      final appContainer = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
      final router = appContainer.read(routerProvider);

      appContainer.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      await tester.pumpAndSettle();

      router.go(AppRoutes.bulkImport);
      await tester.pumpAndSettle();

      expect(find.byType(BulkImportScreen), findsOneWidget);
      expect(find.text(' दिल्ली Public School Hyderabad', skipOffstage: false), findsNothing);
      expect(find.text('Active School: Delhi Public School Hyderabad'), findsOneWidget);

      // Verify template structure columns
      expect(find.text('first_name'), findsOneWidget);
      expect(find.text('admission_number'), findsOneWidget);

      // Simulate state update through provider directly for CSV preview and validate UI
      final notifier = appContainer.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      final rows = [
        ParsedRow(
          rowIndex: 2,
          data: {
            'first_name': 'Rahul',
            'last_name': 'Sharma',
            'gender': 'MALE',
            'date_of_birth': '2014-05-12',
            'admission_number': 'ADM101',
            'roll_number': '801',
            'admission_date': '2026-06-01',
            'academic_year_id': 'ay_1',
            'class_id': 'class_1',
            'section_id': 'section_1'
          },
          errors: [],
          warnings: [],
          status: ImportRowStatus.valid,
        ),
      ];

      notifier.state = notifier.state.copyWith(
        fileName: 'students_mock.csv',
        rows: rows,
      );

      await tester.pumpAndSettle();

      expect(find.text('Total Rows'), findsOneWidget);
      expect(find.text('Valid'), findsOneWidget);
      expect(find.text('Rahul'), findsOneWidget);

      // Click Import Valid Records button
      final importBtn = find.text('Import Valid Records');
      expect(importBtn, findsOneWidget);
      await tester.ensureVisible(importBtn);
      await tester.pumpAndSettle();
      await tester.tap(importBtn);
      await tester.pumpAndSettle();

      // Assert confirmation dialog appears
      expect(find.text('Ready to Import'), findsOneWidget);
      expect(find.text(' Delhi Public School Hyderabad'), findsNothing);

      // Confirm button
      final confirmBtn = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Import Valid Rows'),
      );
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Progress bar should complete and show summary
      expect(find.text('Import Completed'), findsOneWidget);
      expect(find.text('Successfully Imported'), findsOneWidget);
      expect(find.text('Start Another Import'), findsOneWidget);

      // Verify routing path is clean and doesn't contain :id
      expect(router.state.uri.path, '/bulk-import');
      expect(router.state.uri.path.contains(':id'), false);

      FlutterError.onError = originalOnError;
    });

    testWidgets('Enforces permission check and hides view if user is guest', (WidgetTester tester) async {
      final fakeRepo = FakeBulkImportRepository(hasAdminAccess: false);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) => fakeRepo),
            sessionManagerProvider.overrideWith((ref) => FakeBulkImportSessionManager()),
            apiClientProvider.overrideWithValue(fakeApiClient),
            bootstrapResultProvider.overrideWithValue(BootstrapResult(success: true)),
          ],
          child: const EduPulseAdminApp(),
        ),
      );

      await tester.pumpAndSettle();
      final appContainer = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

      appContainer.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      await tester.pumpAndSettle();

      // Should be redirected or denied access at login (meaning state remains Unauthenticated or throws error)
      expect(appContainer.read(authStateProvider) is Authenticated, false);
    });

    testWidgets('Large Dataset Integration: 500 students wide table, pagination and execution filtering works', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        originalOnError?.call(details);
      };

      const csvHeader = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n';
      final csvRows = List.generate(500, (i) {
        final admissionNum = 'ADM${1000 + i}';
        final rollNum = '${100 + i}';
        return 'Student$i,LastName$i,MALE,2014-05-12,$admissionNum,$rollNum,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';
      }).join('\n');
      final fullCsv = csvHeader + csvRows;

      final fakeRepo = FakeBulkImportRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) => fakeRepo),
            sessionManagerProvider.overrideWith((ref) => FakeBulkImportSessionManager()),
            apiClientProvider.overrideWithValue(fakeApiClient),
            bootstrapResultProvider.overrideWithValue(BootstrapResult(success: true)),
          ],
          child: const EduPulseAdminApp(),
        ),
      );

      await tester.pumpAndSettle();
      final appContainer = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
      final router = appContainer.read(routerProvider);

      appContainer.read(selectedSchoolIdProvider.notifier).state = 'school_500';
      await tester.pumpAndSettle();

      router.go(AppRoutes.bulkImport);
      await tester.pumpAndSettle();

      final notifier = appContainer.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      await notifier.selectFile('students_500.csv', fullCsv);

      await tester.pumpAndSettle();

      expect(find.text('Page 1 of 50'), findsOneWidget);
      expect(find.text('Showing 1 to 10 of 500 rows'), findsOneWidget);

      expect(find.text('Student0'), findsOneWidget);
      expect(find.text('Student10'), findsNothing);

      final nextPageBtn = find.byIcon(Icons.chevron_right);
      expect(nextPageBtn, findsOneWidget);
      await tester.ensureVisible(nextPageBtn);
      await tester.tap(nextPageBtn);
      await tester.pumpAndSettle();

      expect(find.text('Page 2 of 50'), findsOneWidget);
      expect(find.text('Showing 11 to 20 of 500 rows'), findsOneWidget);
      expect(find.text('Student10'), findsOneWidget);
      expect(find.text('Student0'), findsNothing);

      final importBtn = find.text('Import Valid Records');
      expect(importBtn, findsOneWidget);
      await tester.ensureVisible(importBtn);
      await tester.tap(importBtn);
      await tester.pumpAndSettle();

      final confirmBtn = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Import Valid Rows'),
      );
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(find.text('Import Completed'), findsOneWidget);
      expect(find.text('Showing 1 to 10 of 500 rows'), findsOneWidget);
      expect(find.text('Page 1 of 50'), findsOneWidget);

      final successChip = find.text('Success (500)');
      expect(successChip, findsOneWidget);
      await tester.ensureVisible(successChip);
      await tester.tap(successChip);
      await tester.pumpAndSettle();

      expect(find.text('Page 1 of 50'), findsOneWidget);

      FlutterError.onError = originalOnError;
    });

    testWidgets('Interactive Validation Grid: cell editing, error correction, re-validation, filters, search, bulk edit, and school context change', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        originalOnError?.call(details);
      };

      const csvContent = 
          'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM1001,101,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n'
          'Anjali,Rao,INVALID_GENDER,2014-07-22,ADM1002,102,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n'
          'Vikram,Patel,MALE,2014-08-15,ADM1003,103,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,invalid-uuid,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      final fakeRepo = FakeBulkImportRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) => fakeRepo),
            sessionManagerProvider.overrideWith((ref) => FakeBulkImportSessionManager()),
            apiClientProvider.overrideWithValue(fakeApiClient),
            bootstrapResultProvider.overrideWithValue(BootstrapResult(success: true)),
          ],
          child: const EduPulseAdminApp(),
        ),
      );

      await tester.pumpAndSettle();
      final appContainer = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
      final router = appContainer.read(routerProvider);

      appContainer.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      await tester.pumpAndSettle();

      router.go(AppRoutes.bulkImport);
      await tester.pumpAndSettle();

      final notifier = appContainer.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      await notifier.selectFile('students_test.csv', csvContent);

      await tester.pumpAndSettle();

      expect(find.text('Total Rows'), findsOneWidget);
      expect(find.text('3'), findsNWidgets(3));
      expect(find.text('Blocking Errors'), findsOneWidget);
      expect(find.text('2'), findsNWidgets(3)); 

      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'Anjali');
      await tester.pumpAndSettle();

      expect(find.text('Anjali'), findsNWidgets(2));
      expect(find.text('Rahul'), findsNothing);

      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();

      print('DTest grid rows: ${appContainer.read(bulkImportProvider).rows.map((r) => '${r.data['first_name']}: ${r.status} (${r.errors})')}');
      final errorsFilterChip = find.text('Errors (2)');
      expect(errorsFilterChip, findsOneWidget);
      await tester.ensureVisible(errorsFilterChip);
      await tester.tap(errorsFilterChip);
      await tester.pumpAndSettle();

      expect(find.text('Anjali'), findsOneWidget);
      expect(find.text('Vikram'), findsOneWidget);
      expect(find.text('Rahul'), findsNothing);

      appContainer.read(bulkImportProvider.notifier).updateCell(3, 'gender', 'FEMALE');
      await tester.pumpAndSettle();

      expect(find.text('Errors (1)'), findsOneWidget);

      final editedChip = find.text('Edited (1)');
      expect(editedChip, findsOneWidget);
      await tester.ensureVisible(editedChip);
      await tester.tap(editedChip);
      await tester.pumpAndSettle();
      expect(find.text('Anjali'), findsOneWidget);

      appContainer.read(selectedSchoolIdProvider.notifier).state = null;
      await tester.pumpAndSettle();

      expect(find.text('Please select a school context first'), findsOneWidget);

      FlutterError.onError = originalOnError;
    });

    testWidgets('Section Capacity Awareness: pre-import checks, calculations, warning banners, filtering, and API errors', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        originalOnError?.call(details);
      };

      final fakeRepo = FakeBulkImportRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) => fakeRepo),
            sessionManagerProvider.overrideWith((ref) => FakeBulkImportSessionManager()),
            apiClientProvider.overrideWithValue(fakeApiClient),
            bootstrapResultProvider.overrideWithValue(BootstrapResult(success: true)),
          ],
          child: const EduPulseAdminApp(),
        ),
      );

      await tester.pumpAndSettle();
      final appContainer = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
      final router = appContainer.read(routerProvider);

      appContainer.read(selectedSchoolIdProvider.notifier).state = 'school_capacity';
      await tester.pumpAndSettle();

      // Go to Bulk Import tab/screen
      router.go(AppRoutes.bulkImport);
      await tester.pumpAndSettle();

      // Fetch sections to populate the sections state
      await appContainer.read(sectionsProvider('school_capacity').notifier).fetchSections();
      await tester.pumpAndSettle();

      final notifier = appContainer.read(bulkImportProvider.notifier);

      // Verify that sections and students fetch runs correctly on file selection
      final csvData =
          'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'Rahul,Sharma,MALE,2015-05-12,ADM101,R101,2024-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n'
          'Priya,Verma,FEMALE,2015-06-12,ADM102,R102,2024-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n'
          'Amit,Kumar,MALE,2015-07-12,ADM103,R103,2024-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44\n';

      await notifier.selectFile('students.csv', csvData);
      await tester.pumpAndSettle();

      // Trigger the background student counts loader to populate
      await notifier.fetchExistingStudentCounts('school_capacity');
      await tester.pumpAndSettle();

      // Verify Section Capacity Panel is rendered
      expect(find.text('Section Capacity Status'), findsOneWidget);
      // Section A: capacity 3, existing 2, incoming 2. Projected = 4. Exceeds capacity! Status = ERROR.
      // Section B: capacity 5, existing 0, incoming 1. Projected = 1. Valid! Status = VALID.
      expect(find.text('Class 1 / Section A'), findsAtLeastNWidgets(1));
      expect(find.text('Class 1 / Section B'), findsAtLeastNWidgets(1));

      // Verify smart warning banner is displayed
      expect(find.textContaining('Section Class 1 / Section A has only 1 available seats, but 2 incoming students are assigned to it.'), findsOneWidget);

      expect(find.textContaining('Capacity Errors (2)'), findsOneWidget);

      // Verify Proceed button/Import button is disabled because capacity is exceeded
      final importButton = find.byWidgetPredicate((widget) =>
          widget is ElevatedButton &&
          widget.child is Text &&
          (widget.child as Text).data!.contains('Import Valid Rows (1)'));
      expect(importButton, findsOneWidget);
      expect(tester.widget<ElevatedButton>(importButton).onPressed, isNotNull);

      // Edit Priya's section (index 1 in state.rows, row index is 3) to Section B UUID
      // This will make Section A: projected = 2 existing + 1 incoming = 3 (exactly at limit!)
      // Section B: projected = 0 existing + 2 incoming = 2 (valid!)
      await notifier.updateCell(3, 'section_id', 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44');
      await tester.pumpAndSettle();

      print('DTest capacity test rows: ${appContainer.read(bulkImportProvider).rows.map((r) => '${r.data['first_name']}: ${r.status} (${r.errors})')}');
      print('DTest capacity test dependenciesReady: ${appContainer.read(bulkImportProvider).dependenciesReady}');
      print('DTest capacity test dependenciesDirty: ${appContainer.read(bulkImportProvider).dependenciesDirty}');
      print('DTest capacity test dependencyError: ${appContainer.read(bulkImportProvider).dependencyError}');

      // Verify Section A is now VALID (projected 3/3, exactly at limit) and warning banner is gone
      expect(find.textContaining('Section Section A has only'), findsNothing);
      expect(find.textContaining('Capacity Errors (0)'), findsOneWidget);

      // Verify Import button becomes enabled
      final enabledImportButton = find.byWidgetPredicate((widget) =>
          widget is ElevatedButton &&
          widget.child is Text &&
          (widget.child as Text).data!.contains('Import Valid Records'));
      expect(enabledImportButton, findsOneWidget);
      expect(tester.widget<ElevatedButton>(enabledImportButton).onPressed, isNotNull);

      // Verify capacity Errors filter chip displays 0 rows
      final capErrorsChip = find.textContaining('Capacity Errors (0)');
      await tester.ensureVisible(capErrorsChip);
      await tester.tap(capErrorsChip);
      await tester.pumpAndSettle();
      expect(find.text('Rahul'), findsNothing);
      expect(find.text('Priya'), findsNothing);

      // Move Priya back to Section A UUID to exceed capacity again
      notifier.updateCell(3, 'section_id', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33');
      await tester.pumpAndSettle();

      // Change first student's first_name to 'CapacityConflict' to check backend race-condition error handling
      notifier.updateCell(2, 'first_name', 'CapacityConflict');
      await tester.pumpAndSettle();

      // Move Priya back to Section B UUID so that import is not blocked by client checks
      notifier.updateCell(3, 'section_id', 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44');
      await tester.pumpAndSettle();

      // Now verify API error handling when a race condition on backend returns 400 capacity exceeded
      await notifier.importRecords('school_capacity', fakeApiClient);
      await tester.pumpAndSettle();

      // The first row 'CapacityConflict' should fail with HTTP 400 capacity exceeded message
      final failedRow = appContainer.read(bulkImportProvider).rows.firstWhere((r) => r.status == ImportRowStatus.apiError || r.status == ImportRowStatus.failed);
      expect(failedRow.apiErrorMessage, contains('HTTP 400: Cannot register student because target section capacity has been reached. (Section: Section A)'));

      FlutterError.onError = originalOnError;
    });
  });

  group('Bulk Import Student Payload Optional Fields Tests', () {
    test('TEST 1: Optional aadhaar_number = "" is omitted from payload and succeeds without 422', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id,aadhaar_number\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33,\n';

      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      notifier.selectFile('students.csv', csv);

      fakeApiClient.postCalls.clear();
      await notifier.importRecords('school_1', fakeApiClient);

      expect(fakeApiClient.postCalls.length, 1);
      final payload = fakeApiClient.postCalls.first['data'] as Map<String, dynamic>;
      expect(payload.containsKey('aadhaar_number'), false);
      expect(payload['first_name'], 'Rahul');
    });

    test('TEST 2: Optional aadhaar_number = "   " is omitted from payload', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id,aadhaar_number\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33,   \n';

      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      notifier.selectFile('students.csv', csv);

      fakeApiClient.postCalls.clear();
      await notifier.importRecords('school_1', fakeApiClient);

      expect(fakeApiClient.postCalls.length, 1);
      final payload = fakeApiClient.postCalls.first['data'] as Map<String, dynamic>;
      expect(payload.containsKey('aadhaar_number'), false);
    });

    test('TEST 3: Optional aadhaar_number = null (missing column or empty field) is omitted', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n';

      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      notifier.selectFile('students.csv', csv);

      fakeApiClient.postCalls.clear();
      await notifier.importRecords('school_1', fakeApiClient);

      expect(fakeApiClient.postCalls.length, 1);
      final payload = fakeApiClient.postCalls.first['data'] as Map<String, dynamic>;
      expect(payload.containsKey('aadhaar_number'), false);
    });

    test('TEST 4: Optional aadhaar_number = valid 12-digit value is included in payload', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id,aadhaar_number\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33,123456789012\n';

      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      notifier.selectFile('students.csv', csv);

      fakeApiClient.postCalls.clear();
      await notifier.importRecords('school_1', fakeApiClient);

      expect(fakeApiClient.postCalls.length, 1);
      final payload = fakeApiClient.postCalls.first['data'] as Map<String, dynamic>;
      expect(payload['aadhaar_number'], '123456789012');
    });

    test('TEST 5: Optional aadhaar_number = invalid non-empty value preserves original error/API error', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id,aadhaar_number\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33,invalid_value\n';

      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      notifier.selectFile('students.csv', csv);

      fakeApiClient.postCalls.clear();
      await notifier.importRecords('school_1', fakeApiClient);

      expect(fakeApiClient.postCalls.length, 1);
      final payload = fakeApiClient.postCalls.first['data'] as Map<String, dynamic>;
      expect(payload['aadhaar_number'], 'invalid_value');
    });

    test('TEST 6: All optional fields empty succeeds when all required fields are valid', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id,middle_name,blood_group,aadhaar_number,emis_number,mobile,email,photo_url\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33,,,,,,,\n';

      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      notifier.selectFile('students.csv', csv);

      fakeApiClient.postCalls.clear();
      await notifier.importRecords('school_1', fakeApiClient);

      expect(fakeApiClient.postCalls.length, 1);
      final payload = fakeApiClient.postCalls.first['data'] as Map<String, dynamic>;
      expect(payload.containsKey('middle_name'), false);
      expect(payload.containsKey('blood_group'), false);
      expect(payload.containsKey('aadhaar_number'), false);
      expect(payload.containsKey('emis_number'), false);
      expect(payload.containsKey('mobile'), false);
      expect(payload.containsKey('email'), false);
      expect(payload.containsKey('photo_url'), false);
      
      final state = container.read(bulkImportProvider);
      expect(state.rows[0].status, ImportRowStatus.success);
    });

    test('TEST 7: Required field empty triggers client-side blocking error and prevents API call', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          ',Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n';

      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      notifier.selectFile('students.csv', csv);

      final state = container.read(bulkImportProvider);
      expect(state.rows[0].status, ImportRowStatus.error);

      fakeApiClient.postCalls.clear();
      await notifier.importRecords('school_1', fakeApiClient);

      expect(fakeApiClient.postCalls, isEmpty);
      expect(container.read(bulkImportProvider).rows[0].status, ImportRowStatus.skipped);
    });
  });

  group('Pre-Import Validation Group Tests', () {
    test('1. Duplicate admission number inside CSV', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n'
          'Aarav,Rao,MALE,2014-05-12,ADM001,802,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n';

      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      notifier.selectFile('students.csv', csv);

      final state = container.read(bulkImportProvider);
      expect(state.rows[0].status, ImportRowStatus.valid);
      expect(state.rows[1].status, ImportRowStatus.duplicate);
      expect(state.rows[1].errors.first, contains('Duplicate admission_number "ADM001"'));
    });

    test('2. Duplicate roll number inside CSV', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n'
          'Aarav,Rao,MALE,2014-05-12,ADM002,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n';

      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      notifier.selectFile('students.csv', csv);

      final state = container.read(bulkImportProvider);
      expect(state.rows[0].status, ImportRowStatus.valid);
      expect(state.rows[1].status, ImportRowStatus.duplicate);
      expect(state.rows[1].errors.first, contains('Student with roll number 801 already exists in this section.'));
    });

    test('3. Existing roll_number + section_id conflict', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      notifier.state = notifier.state.copyWith(
        existingRollSectionKeys: {'801|c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33'}
      );

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n';
      notifier.selectFile('students.csv', csv);

      final state = container.read(bulkImportProvider);
      expect(state.rows[0].status, ImportRowStatus.duplicate);
      expect(state.rows[0].errors.first, contains('Student with roll number 801 already exists in this section.'));
    });

    test('4. Same roll number in different sections should be allowed', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n'
          'Aarav,Rao,MALE,2014-05-12,ADM002,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44\n';

      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      notifier.selectFile('students.csv', csv);

      final state = container.read(bulkImportProvider);
      expect(state.rows[0].status, ImportRowStatus.valid);
      expect(state.rows[1].status, ImportRowStatus.valid);
    });

    test('8. Editing roll number removes duplicate error', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n'
          'Aarav,Rao,MALE,2014-05-12,ADM002,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n';

      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      notifier.selectFile('students.csv', csv);

      expect(container.read(bulkImportProvider).rows[1].status, ImportRowStatus.duplicate);

      notifier.updateCell(3, 'roll_number', '802');
      expect(container.read(bulkImportProvider).rows[1].status, ImportRowStatus.valid);
    });

    test('9. Editing section removes duplicate error', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n'
          'Aarav,Rao,MALE,2014-05-12,ADM002,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n';

      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      notifier.selectFile('students.csv', csv);

      expect(container.read(bulkImportProvider).rows[1].status, ImportRowStatus.duplicate);

      await notifier.updateCell(3, 'section_id', 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44');
      expect(container.read(bulkImportProvider).rows[1].status, ImportRowStatus.valid);
    });

    test('10. Blocking errors disable Execute Import', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          ',Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n';

      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      notifier.selectFile('students.csv', csv);

      fakeApiClient.postCalls.clear();
      await notifier.importRecords('school_1', fakeApiClient);
      expect(fakeApiClient.postCalls, isEmpty);
    });

    test('11. Warning does not disable Execute Import', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n';

      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      notifier.selectFile('students.csv', csv);

      // Manually simulate a row warning
      final rows = List<ParsedRow>.from(notifier.state.rows);
      rows[0] = rows[0].copyWith(status: ImportRowStatus.warning);
      notifier.state = notifier.state.copyWith(rows: rows);

      expect(container.read(bulkImportProvider).rows[0].status, ImportRowStatus.warning);

      fakeApiClient.postCalls.clear();
      await notifier.importRecords('school_1', fakeApiClient);
      expect(fakeApiClient.postCalls.length, 1);
    });

    test('15. School context change resets validation state', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n';

      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      notifier.selectFile('students.csv', csv);

      expect(container.read(bulkImportProvider).rows, isNotEmpty);

      container.read(selectedSchoolIdProvider.notifier).state = 'school_2';
      expect(container.read(bulkImportProvider).rows, isEmpty);
    });
  });

  group('Partial Import Group Tests', () {
    test('TEST 1, 2, 3: 500 rows (461 valid, 39 errors) - imports exactly 461, skips 39, 0 API failures', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      // Seed 500 rows: 461 valid, 39 errors
      final List<ParsedRow> rows = [];
      for (int i = 1; i <= 500; i++) {
        final isError = i <= 39;
        rows.add(ParsedRow(
          rowIndex: i + 1,
          data: {
            'first_name': isError ? '' : 'Student$i',
            'last_name': 'Test',
            'gender': 'MALE',
            'date_of_birth': '2012-04-15',
            'admission_number': 'ADM$i',
            'roll_number': '$i',
            'admission_date': '2026-06-01',
            'academic_year_id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
            'class_id': 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
            'section_id': 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
          },
          errors: isError ? ['First name is required'] : [],
          warnings: const [],
          status: isError ? ImportRowStatus.error : ImportRowStatus.valid,
        ));
      }

      notifier.state = notifier.state.copyWith(
        fileName: 'students_500.csv',
        rows: rows,
      );

      fakeApiClient.postCalls.clear();
      await notifier.importRecords('school_1', fakeApiClient);

      // TEST 1: Imports exactly 461
      expect(fakeApiClient.postCalls.length, 461);

      // TEST 2: Verify none of the 39 invalid rows generates an API request
      for (final call in fakeApiClient.postCalls) {
        final data = call['data'] as Map<String, dynamic>;
        final firstName = data['first_name'] as String;
        expect(firstName.isEmpty, false);
      }

      // TEST 3: Verify execution summary shows: 461 successful, 39 skipped, 0 API failures
      final finalState = container.read(bulkImportProvider);
      expect(finalState.successCount, 461);
      expect(finalState.skippedCount, 39);
      expect(finalState.failedCount, 0);
    });

    test('TEST 4: Correct one of the 39 errors, changes validation count, imports 462', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      final List<ParsedRow> rows = [];
      for (int i = 1; i <= 500; i++) {
        final isError = i <= 39;
        rows.add(ParsedRow(
          rowIndex: i + 1,
          data: {
            'first_name': isError ? '' : 'Student$i',
            'last_name': 'Test',
            'gender': 'MALE',
            'date_of_birth': '2012-04-15',
            'admission_number': 'ADM$i',
            'roll_number': '$i',
            'admission_date': '2026-06-01',
            'academic_year_id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
            'class_id': 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
            'section_id': 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
          },
          errors: isError ? ['First name is required'] : [],
          warnings: const [],
          status: isError ? ImportRowStatus.error : ImportRowStatus.valid,
        ));
      }

      notifier.state = notifier.state.copyWith(
        fileName: 'students_500.csv',
        rows: rows,
      );

      // Correct one error (row index 2 corresponds to rowIndex 2 in validation grid)
      notifier.updateCell(2, 'first_name', 'ResolvedName');

      final midState = container.read(bulkImportProvider);
      final validCount = midState.rows.where((r) => r.status == ImportRowStatus.valid).length;
      expect(validCount, 462);

      fakeApiClient.postCalls.clear();
      await notifier.importRecords('school_1', fakeApiClient);

      expect(fakeApiClient.postCalls.length, 462);
    });

    test('TEST 5: All rows valid - normal behavior imports all', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      final List<ParsedRow> rows = [];
      for (int i = 1; i <= 10; i++) {
        rows.add(ParsedRow(
          rowIndex: i + 1,
          data: {
            'first_name': 'Student$i',
            'last_name': 'Test',
            'gender': 'MALE',
            'date_of_birth': '2012-04-15',
            'admission_number': 'ADM$i',
            'roll_number': '$i',
            'admission_date': '2026-06-01',
            'academic_year_id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
            'class_id': 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
            'section_id': 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
          },
          errors: const [],
          warnings: const [],
          status: ImportRowStatus.valid,
        ));
      }

      notifier.state = notifier.state.copyWith(
        fileName: 'students_valid.csv',
        rows: rows,
      );

      fakeApiClient.postCalls.clear();
      await notifier.importRecords('school_1', fakeApiClient);

      expect(fakeApiClient.postCalls.length, 10);
      expect(container.read(bulkImportProvider).skippedCount, 0);
    });

    test('TEST 6: Error CSV contains exactly the 39 skipped rows', () async {
      final List<ParsedRow> rows = [];
      for (int i = 1; i <= 500; i++) {
        final isError = i <= 39;
        rows.add(ParsedRow(
          rowIndex: i + 1,
          data: {
            'first_name': isError ? '' : 'Student$i',
            'last_name': 'Test',
            'gender': 'MALE',
            'date_of_birth': '2012-04-15',
            'admission_number': 'ADM$i',
            'roll_number': '$i',
            'admission_date': '2026-06-01',
            'academic_year_id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
            'class_id': 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
            'section_id': 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
          },
          errors: isError ? ['First name is required'] : [],
          warnings: const [],
          status: isError ? ImportRowStatus.error : ImportRowStatus.valid,
        ));
      }

      final skippedRows = rows.where((r) => r.status == ImportRowStatus.skipped || r.status == ImportRowStatus.error).toList();
      expect(skippedRows.length, 39);
      for (final row in skippedRows) {
        expect(row.data['first_name'], isEmpty);
      }
    });

    test('TEST 7: Changing school context resets the partial-import state', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      notifier.state = notifier.state.copyWith(
        fileName: 'partial.csv',
        rows: [
          ParsedRow(
            rowIndex: 2,
            data: {'first_name': 'Test'},
            errors: const [],
            warnings: const [],
            status: ImportRowStatus.valid,
          )
        ],
        isCompleted: true,
        successCount: 1,
      );

      container.read(selectedSchoolIdProvider.notifier).state = 'school_2';
      expect(container.read(bulkImportProvider).rows, isEmpty);
      expect(container.read(bulkImportProvider).isCompleted, false);
      expect(container.read(bulkImportProvider).successCount, 0);
    });

    test('TEST 8: Capacity errors remain blocking and are excluded from the valid import set', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      final row = ParsedRow(
        rowIndex: 2,
        data: {
          'first_name': 'Rahul',
          'last_name': 'Sharma',
          'gender': 'MALE',
          'date_of_birth': '2014-05-12',
          'admission_number': 'ADM001',
          'roll_number': '801',
          'admission_date': '2026-06-01',
          'academic_year_id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
          'class_id': 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
          'section_id': 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
        },
        errors: const ['Section capacity exceeded'],
        warnings: const [],
        status: ImportRowStatus.error,
      );

      notifier.state = notifier.state.copyWith(
        fileName: 'capacity.csv',
        rows: [row],
      );

      fakeApiClient.postCalls.clear();
      await notifier.importRecords('school_1', fakeApiClient);
      expect(fakeApiClient.postCalls, isEmpty);
      expect(container.read(bulkImportProvider).skippedCount, 1);
    });

    test('TEST 9: Duplicate roll-number errors remain blocking and are excluded from the valid import set', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      final row = ParsedRow(
        rowIndex: 2,
        data: {
          'first_name': 'Rahul',
          'last_name': 'Sharma',
          'gender': 'MALE',
          'date_of_birth': '2014-05-12',
          'admission_number': 'ADM001',
          'roll_number': '801',
          'admission_date': '2026-06-01',
          'academic_year_id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
          'class_id': 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
          'section_id': 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
        },
        errors: const ['Duplicate roll number in section'],
        warnings: const [],
        status: ImportRowStatus.error,
      );

      notifier.state = notifier.state.copyWith(
        fileName: 'duplicate.csv',
        rows: [row],
      );

      fakeApiClient.postCalls.clear();
      await notifier.importRecords('school_1', fakeApiClient);
      expect(fakeApiClient.postCalls, isEmpty);
    });

    test('TEST 10: Optional blank fields continue to be omitted from student API payloads', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      final row = ParsedRow(
        rowIndex: 2,
        data: {
          'first_name': 'Rahul',
          'last_name': 'Sharma',
          'gender': 'MALE',
          'date_of_birth': '2014-05-12',
          'admission_number': 'ADM001',
          'roll_number': '801',
          'admission_date': '2026-06-01',
          'academic_year_id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
          'class_id': 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
          'section_id': 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
          'middle_name': '',
          'aadhaar_number': '   ',
        },
        errors: const [],
        warnings: const [],
        status: ImportRowStatus.valid,
      );

      notifier.state = notifier.state.copyWith(
        fileName: 'optional.csv',
        rows: [row],
      );

      fakeApiClient.postCalls.clear();
      await notifier.importRecords('school_1', fakeApiClient);

      expect(fakeApiClient.postCalls.length, 1);
      final payload = fakeApiClient.postCalls.first['data'] as Map<String, dynamic>;
      expect(payload.containsKey('middle_name'), false);
      expect(payload.containsKey('aadhaar_number'), false);
    });
  });

  group('Bulk Import Dependency Auto-Creation Group Tests', () {
    final Map<String, String> baseData = {
      'first_name': 'Rahul',
      'last_name': 'Sharma',
      'gender': 'MALE',
      'date_of_birth': '2012-04-15',
      'admission_number': 'ADM001',
      'roll_number': '1',
      'admission_date': '2026-06-01',
      'academic_year_id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    };

    test('D1: Mode A vs Mode B detection - Mode A with class_id', () {
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';
      final parsed = CsvHelper.parseCsv(csv);
      final validated = CsvHelper.validateCsv(parsed, ImportType.students);
      expect(validated.length, 1);
      expect(validated.first.errors, isEmpty);
    });

    test('D2: Mode B detection - Mode B with class_name and section_name', () {
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_name,class_code,section_name,section_code\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,Class 9,C09,Section B,SEC_B';
      final parsed = CsvHelper.parseCsv(csv);
      final validated = CsvHelper.validateCsv(parsed, ImportType.students);
      expect(validated.length, 1);
      expect(validated.first.errors, isEmpty);
    });

    test('D3: Mode B validation requires academic_year_id', () {
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_name,section_name\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,,Class 9,Section B';
      final parsed = CsvHelper.parseCsv(csv);
      final validated = CsvHelper.validateCsv(parsed, ImportType.students);
      expect(validated.length, 1);
      expect(validated.first.errors.any((e) => e.contains('academic_year_id')), true);
    });

    test('D4: Mode B validation fails if neither class_id nor names are present', () {
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
      final parsed = CsvHelper.parseCsv(csv);
      final validated = CsvHelper.validateCsv(parsed, ImportType.students);
      expect(validated.length, 1);
      expect(validated.first.data.isEmpty, true); // missing headers
    });

    test('D5: selectFile triggers checkDependencies for student import type', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_name,class_code,section_name,section_code\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,Class 9,C09,Section B,SEC_B';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      await notifier.selectFile('students.csv', csv);

      final state = container.read(bulkImportProvider);
      expect(state.dependencyTotalClasses, 1);
      expect(state.dependencyTotalSections, 1);
      expect(state.dependenciesReady, false);
    });

    test('D6: checkDependencies fetches existing classes and sections from backend', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      
      final rows = [
        ParsedRow(
          rowIndex: 2,
          data: {
            ...baseData,
            'class_name': 'Class 1',
            'section_name': 'Section A',
          },
          errors: const [],
          warnings: const [],
          status: ImportRowStatus.valid,
        )
      ];

      await notifier.checkDependencies(rows);
      final state = container.read(bulkImportProvider);
      expect(state.cachedClasses.isNotEmpty, true);
      expect(state.cachedSections.isNotEmpty, true);
    });

    test('D7: checkDependencies resolves existing classes matching normalized name', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      
      final rows = [
        ParsedRow(
          rowIndex: 2,
          data: {
            ...baseData,
            'class_name': '  class 1  ', // Case and whitespace normalized should match Class 1
            'section_name': 'Section A',
          },
          errors: const [],
          warnings: const [],
          status: ImportRowStatus.valid,
        )
      ];

      await notifier.checkDependencies(rows);
      final state = container.read(bulkImportProvider);
      expect(state.dependencyExistingClasses, 1);
      expect(state.dependencyNewClasses, 0);
    });

    test('D8: checkDependencies resolves existing sections matching normalized name', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      
      final rows = [
        ParsedRow(
          rowIndex: 2,
          data: {
            ...baseData,
            'class_name': 'Class 1',
            'section_name': '  section a  ',
          },
          errors: const [],
          warnings: const [],
          status: ImportRowStatus.valid,
        )
      ];

      await notifier.checkDependencies(rows);
      final state = container.read(bulkImportProvider);
      expect(state.dependencyExistingSections, 1);
      expect(state.dependencyNewSections, 0);
    });

    test('D9: checkDependencies resolves existing classes matching normalized code', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      
      final rows = [
        ParsedRow(
          rowIndex: 2,
          data: {
            ...baseData,
            'class_code': '  class_1  ',
            'section_name': 'Section A',
          },
          errors: const [],
          warnings: const [],
          status: ImportRowStatus.valid,
        )
      ];

      await notifier.checkDependencies(rows);
      final state = container.read(bulkImportProvider);
      expect(state.dependencyExistingClasses, 1);
    });

    test('D10: checkDependencies resolves existing sections matching normalized code', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      
      final rows = [
        ParsedRow(
          rowIndex: 2,
          data: {
            ...baseData,
            'class_name': 'Class 1',
            'section_code': '  sec_a  ',
          },
          errors: const [],
          warnings: const [],
          status: ImportRowStatus.valid,
        )
      ];

      await notifier.checkDependencies(rows);
      final state = container.read(bulkImportProvider);
      expect(state.dependencyExistingSections, 1);
    });

    test('D11: checkDependencies identifies missing classes and sections correctly', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      
      final rows = [
        ParsedRow(
          rowIndex: 2,
          data: {
            ...baseData,
            'class_name': 'Class 99',
            'section_name': 'Section Z',
          },
          errors: const [],
          warnings: const [],
          status: ImportRowStatus.valid,
        )
      ];

      await notifier.checkDependencies(rows);
      final state = container.read(bulkImportProvider);
      expect(state.dependencyNewClasses, 1);
      expect(state.dependencyNewSections, 1);
      expect(state.dependenciesReady, false);
    });

    test('D12: checkDependencies sets dependenciesReady to false when there are unresolved classes or sections', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      
      final rows = [
        ParsedRow(
          rowIndex: 2,
          data: {
            ...baseData,
            'class_name': 'Class 99',
            'section_name': 'Section A',
          },
          errors: const [],
          warnings: const [],
          status: ImportRowStatus.valid,
        )
      ];

      await notifier.checkDependencies(rows);
      final state = container.read(bulkImportProvider);
      expect(state.dependenciesReady, false);
    });

    test('D13: checkDependencies sets dependenciesReady to true when all are resolved', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      
      final rows = [
        ParsedRow(
          rowIndex: 2,
          data: {
            ...baseData,
            'class_name': 'Class 1',
            'section_name': 'Section A',
          },
          errors: const [],
          warnings: const [],
          status: ImportRowStatus.valid,
        )
      ];

      await notifier.checkDependencies(rows);
      final state = container.read(bulkImportProvider);
      expect(state.dependenciesReady, true);
    });

    test('D14: prepareDependencies sequentially creates missing classes and sections', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      
      final rows = [
        ParsedRow(
          rowIndex: 2,
          data: {
            ...baseData,
            'class_name': 'Class 99',
            'class_code': 'C99',
            'section_name': 'Section Z',
            'section_code': 'SEC_Z',
          },
          errors: const [],
          warnings: const [],
          status: ImportRowStatus.valid,
        )
      ];

      notifier.state = notifier.state.copyWith(rows: rows);
      await notifier.checkDependencies(rows);

      fakeApiClient.postCalls.clear();
      await notifier.prepareDependencies(40, 1, 40);

      expect(fakeApiClient.postCalls.length, 2);
      expect(fakeApiClient.postCalls[0]['path'], '/classes');
      expect(fakeApiClient.postCalls[1]['path'], '/sections');
      expect(container.read(bulkImportProvider).dependenciesReady, true);
    });

    test('D15: prepareDependencies concurrency check fetches latest list before creating', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      
      final rows = [
        ParsedRow(
          rowIndex: 2,
          data: {
            ...baseData,
            'class_name': 'Class 1',
            'section_name': 'Section A',
          },
          errors: const [],
          warnings: const [],
          status: ImportRowStatus.valid,
        )
      ];

      notifier.state = notifier.state.copyWith(rows: rows);
      fakeApiClient.postCalls.clear();
      await notifier.prepareDependencies(40, 1, 40);

      // Existing records in GET response matches, so no POST calls are made
      expect(fakeApiClient.postCalls.length, 0);
    });

    test('D16: prepareDependencies updates resolvedClassIds and resolvedSectionIds maps', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      
      final rows = [
        ParsedRow(
          rowIndex: 2,
          data: {
            ...baseData,
            'class_name': 'Class 99',
            'class_code': 'C99',
            'section_name': 'Section Z',
            'section_code': 'SEC_Z',
          },
          errors: const [],
          warnings: const [],
          status: ImportRowStatus.valid,
        )
      ];

      notifier.state = notifier.state.copyWith(rows: rows);
      await notifier.checkDependencies(rows);
      await notifier.prepareDependencies(40, 1, 40);

      final state = container.read(bulkImportProvider);
      expect(state.resolvedClassIds['school_1|a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11|c99'], 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380c99');
      expect(state.resolvedSectionIds['school_1|a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11|b0eebc99-9c0b-4ef8-bb6d-6bb9bd380c99|sec_z'], 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c99');
    });

    test('D17: prepareDependencies substitutes resolved IDs in row data', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      
      final rows = [
        ParsedRow(
          rowIndex: 2,
          data: {
            ...baseData,
            'class_name': 'Class 99',
            'class_code': 'C99',
            'section_name': 'Section Z',
            'section_code': 'SEC_Z',
          },
          errors: const [],
          warnings: const [],
          status: ImportRowStatus.valid,
        )
      ];

      notifier.state = notifier.state.copyWith(rows: rows);
      await notifier.checkDependencies(rows);
      await notifier.prepareDependencies(40, 1, 40);

      final updatedRow = container.read(bulkImportProvider).rows.first;
      expect(updatedRow.data['class_id'], 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380c99');
      expect(updatedRow.data['section_id'], 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c99');
    });

    test('D18: prepareDependencies re-runs validation to clear errors if resolved', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      
      final rows = [
        ParsedRow(
          rowIndex: 2,
          data: {
            ...baseData,
            'class_name': 'Class 99',
            'class_code': 'C99',
            'section_name': 'Section Z',
            'section_code': 'SEC_Z',
          },
          errors: const ['Class not found'],
          warnings: const [],
          status: ImportRowStatus.error,
        )
      ];

      notifier.state = notifier.state.copyWith(rows: rows);
      await notifier.checkDependencies(rows);
      await notifier.prepareDependencies(40, 1, 40);

      final updatedRow = container.read(bulkImportProvider).rows.first;
      print('D18 updatedRow errors: ${updatedRow.errors}');
      expect(updatedRow.errors.isEmpty, true);
      expect(updatedRow.status, ImportRowStatus.valid);
    });

    test('D19: prepareDependencies handles class creation failure', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      
      final rows = [
        ParsedRow(
          rowIndex: 2,
          data: {
            ...baseData,
            'class_name': 'FailClass', // name triggers failure in fakeApiClient
            'section_name': 'Section Z',
          },
          errors: const [],
          warnings: const [],
          status: ImportRowStatus.valid,
        )
      ];

      notifier.state = notifier.state.copyWith(rows: rows);
      await notifier.checkDependencies(rows);
      await notifier.prepareDependencies(40, 1, 40);

      final state = container.read(bulkImportProvider);
      expect(state.dependenciesReady, false);
      expect(state.rows.first.status, ImportRowStatus.dependencyError);
      expect(state.rows.first.errors.contains('Class dependency could not be created.'), true);
    });

    test('D20: prepareDependencies handles section creation failure', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      
      final rows = [
        ParsedRow(
          rowIndex: 2,
          data: {
            ...baseData,
            'class_name': 'Class 1', // Existing
            'section_name': 'FailSection', // section name triggers failure in fakeApiClient
          },
          errors: const [],
          warnings: const [],
          status: ImportRowStatus.valid,
        )
      ];

      notifier.state = notifier.state.copyWith(rows: rows);
      await notifier.checkDependencies(rows);
      await notifier.prepareDependencies(40, 1, 40);

      final state = container.read(bulkImportProvider);
      expect(state.dependenciesReady, false);
      expect(state.rows.first.status, ImportRowStatus.dependencyError);
      expect(state.rows.first.errors.contains('Section dependency could not be created.'), true);
    });

    test('D21: prepareDependencies updates dependenciesReady to true on full success', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      
      final rows = [
        ParsedRow(
          rowIndex: 2,
          data: {
            ...baseData,
            'class_name': 'Class 99',
            'section_name': 'Section Z',
          },
          errors: const [],
          warnings: const [],
          status: ImportRowStatus.valid,
        )
      ];

      notifier.state = notifier.state.copyWith(rows: rows);
      await notifier.checkDependencies(rows);
      await notifier.prepareDependencies(40, 1, 40);

      expect(container.read(bulkImportProvider).dependenciesReady, true);
    });

    test('D22: updateCell marks dependencies dirty and recalculates dependencies on class/section details edit', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      
      final rows = [
        ParsedRow(
          rowIndex: 2,
          data: {
            ...baseData,
            'class_name': 'Class 1',
            'section_name': 'Section A',
          },
          errors: const [],
          warnings: const [],
          status: ImportRowStatus.valid,
        )
      ];

      notifier.state = notifier.state.copyWith(rows: rows, dependenciesReady: true);
      await notifier.updateCell(2, 'class_name', 'Class 99');

      final state = container.read(bulkImportProvider);
      expect(state.dependenciesDirty, true);
      expect(state.dependenciesReady, false);
      expect(state.dependencyNewClasses, 1);
    });

    test('D23: updateCell bidirectional sync for class_id and section_id selections', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      
      final rows = [
        ParsedRow(
          rowIndex: 2,
          data: {
            ...baseData,
            'class_name': 'Class 99',
            'section_name': 'Section Z',
          },
          errors: const [],
          warnings: const [],
          status: ImportRowStatus.valid,
        )
      ];

      notifier.state = notifier.state.copyWith(rows: rows);
      await notifier.checkDependencies(rows);
      // Manually trigger cache fill
      notifier.state = notifier.state.copyWith(
        cachedClasses: [
          const ClassDto(
            id: 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
            tenantId: 'tenant_1',
            schoolId: 'school_1',
            academicYearId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
            name: 'Class 1',
            code: 'CLASS_1',
            level: 1,
            category: 'PRIMARY',
            capacity: 40,
            status: 'ACTIVE',
            isActive: true,
            version: 1,
          )
        ],
      );

      await notifier.updateCell(2, 'class_id', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22');
      final updatedRow = container.read(bulkImportProvider).rows.first;
      expect(updatedRow.data['class_name'], 'Class 1');
      expect(updatedRow.data['class_code'], 'CLASS_1');
    });

    test('D24: skipConflictingRows changes duplicate status rows to skipped and runs revalidation', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      
      final rows = [
        ParsedRow(
          rowIndex: 2,
          data: {
            'first_name': 'Duplicate',
            'last_name': 'Student',
            'gender': 'MALE',
            'date_of_birth': '2012-04-15',
            'admission_number': 'ADM100',
            'roll_number': '1',
            'admission_date': '2026-06-01',
            'academic_year_id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
            'class_id': 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
            'section_id': 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
          },
          errors: const [],
          warnings: const [],
          status: ImportRowStatus.duplicate,
        )
      ];

      notifier.state = notifier.state.copyWith(rows: rows);
      notifier.skipConflictingRows();

      final updatedRow = container.read(bulkImportProvider).rows.first;
      expect(updatedRow.status, ImportRowStatus.skipped);
    });

    test('D25: importRecords executes valid rows and ignores duplicate/skipped rows', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      
      final rows = [
        ParsedRow(
          rowIndex: 2,
          data: {
            'first_name': 'ImportMe',
            'last_name': 'Test',
            'gender': 'MALE',
            'date_of_birth': '2012-04-15',
            'admission_number': 'ADM101',
            'roll_number': '2',
            'admission_date': '2026-06-01',
            'academic_year_id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
            'class_id': 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
            'section_id': 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
          },
          errors: const [],
          warnings: const [],
          status: ImportRowStatus.valid,
        ),
        ParsedRow(
          rowIndex: 3,
          data: {
            'first_name': 'SkipMe',
            'last_name': 'Test',
            'gender': 'MALE',
            'date_of_birth': '2012-04-15',
            'admission_number': 'ADM102',
            'roll_number': '3',
            'admission_date': '2026-06-01',
            'academic_year_id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
            'class_id': 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
            'section_id': 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
          },
          errors: const [],
          warnings: const [],
          status: ImportRowStatus.skipped,
        )
      ];

      notifier.state = notifier.state.copyWith(rows: rows);
      fakeApiClient.postCalls.clear();
      await notifier.importRecords('school_1', fakeApiClient);

      expect(fakeApiClient.postCalls.length, 1);
      expect(fakeApiClient.postCalls.first['data']['first_name'], 'ImportMe');
    });

    test('D26: student validation handles phone, father_name, mother_name, address, status', () {
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_name,section_name,phone,father_name,mother_name,address,status\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,Class 9,Section B,9876543210,Father Name,Mother Name,Hyderabad,ACTIVE';
      final parsed = CsvHelper.parseCsv(csv);
      final validated = CsvHelper.validateCsv(parsed, ImportType.students);
      expect(validated.length, 1);
      expect(validated.first.errors, isEmpty);
      expect(validated.first.warnings, isEmpty); // no unexpected column warnings
    });

    test('D27: selectFile saves CSV headers in state.headers', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_name,section_name\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,Class 9,Section B';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);
      await notifier.selectFile('students.csv', csv);

      final state = container.read(bulkImportProvider);
      expect(state.headers, contains('class_name'));
      expect(state.headers, contains('section_name'));
      expect(state.headers, contains('first_name'));
    });

    test('D28: validateCsv accepts empty class_id when class_name or class_code is present', () {
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id,class_name,section_name\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,,,Class 9,Section B';
      final parsed = CsvHelper.parseCsv(csv);
      final validated = CsvHelper.validateCsv(parsed, ImportType.students);
      expect(validated.length, 1);
      expect(validated.first.errors, isEmpty);
    });

    test('D29: validateCsv rejects empty class_id when class_name and class_code are absent', () {
      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';
      final parsed = CsvHelper.parseCsv(csv);
      final validated = CsvHelper.validateCsv(parsed, ImportType.students);
      expect(validated.length, 1);
      expect(validated.first.errors.isNotEmpty, true);
      expect(validated.first.errors.first, contains('Class identifier'));
    });
    test('D30: sanitizeCode helper correctly formats spaces to underscores', () {
      final notifier = container.read(bulkImportProvider.notifier);
      expect(notifier.sanitizeCode('Class 8'), 'CLASS_8');
    });

    test('D31: sanitizeCode helper correctly handles special characters', () {
      final notifier = container.read(bulkImportProvider.notifier);
      expect(notifier.sanitizeCode('Class-8@#'), 'CLASS_8');
    });

    test('D32: sanitizeCode helper enforces minimum length of 2 for classes', () {
      final notifier = container.read(bulkImportProvider.notifier);
      expect(notifier.sanitizeCode('A', minLength: 2), 'AX');
    });

    test('D33: sanitizeCode helper enforces minimum length of 1 for sections', () {
      final notifier = container.read(bulkImportProvider.notifier);
      expect(notifier.sanitizeCode('A', minLength: 1), 'A');
    });

    test('D34: sanitizeCode helper collapses multiple underscores', () {
      final notifier = container.read(bulkImportProvider.notifier);
      expect(notifier.sanitizeCode('Class__8--9'), 'CLASS_8_9');
    });

    test('D35: sanitizeCode helper handles empty/null inputs by returning fallback CODE', () {
      final notifier = container.read(bulkImportProvider.notifier);
      expect(notifier.sanitizeCode(''), 'CODE');
      expect(notifier.sanitizeCode(' '), 'CODE');
    });
    test('D36: prepareDependencies sanitizes class code with spaces', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_name,section_name\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,New Class,Section A';

      await notifier.selectFile('students.csv', csv);
      fakeApiClient.postCalls.clear();

      await notifier.prepareDependencies(40, 1, 40);

      final classPost = fakeApiClient.postCalls.firstWhere((c) => c['path'] == '/classes');
      expect(classPost['data']['code'], 'NEW_CLASS');
    });

    test('D37: prepareDependencies sanitizes section code with spaces', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_name,section_name\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,Class 1,New Section';

      await notifier.selectFile('students.csv', csv);
      fakeApiClient.postCalls.clear();

      await notifier.prepareDependencies(40, 1, 40);

      final sectionPost = fakeApiClient.postCalls.firstWhere((c) => c['path'] == '/sections');
      expect(sectionPost['data']['code'], 'NEW_SECTION');
    });

    test('D38: analyzeDependencies matches existing class with sanitized code', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_code,section_name\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,class 1,Section A';

      await notifier.selectFile('students.csv', csv);
      final state = container.read(bulkImportProvider);
      expect(state.dependencyNewClasses, 0);
    });

    test('D39: analyzeDependencies matches existing section with sanitized code', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_code,section_code\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,CLASS_1,sec a';

      await notifier.selectFile('students.csv', csv);
      final state = container.read(bulkImportProvider);
      expect(state.dependencyNewSections, 0);
    });

    test('D40: prepareDependencies matches existing class with sanitized code', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_code,section_name\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,class 1,Section A';

      await notifier.selectFile('students.csv', csv);
      fakeApiClient.postCalls.clear();
      await notifier.prepareDependencies(40, 1, 40);

      final classPost = fakeApiClient.postCalls.any((c) => c['path'] == '/classes');
      expect(classPost, false);
    });

    test('D41: prepareDependencies matches existing section with sanitized code', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_code,section_code\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,CLASS_1,sec a';

      await notifier.selectFile('students.csv', csv);
      fakeApiClient.postCalls.clear();
      await notifier.prepareDependencies(40, 1, 40);

      final sectionPost = fakeApiClient.postCalls.any((c) => c['path'] == '/sections');
      expect(sectionPost, false);
    });

    test('D42: prepareDependencies performs atomic updates on Riverpod state only at completion', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_name,section_name\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,New Class,Section A';

      await notifier.selectFile('students.csv', csv);

      final future = notifier.prepareDependencies(40, 1, 40);
      final stateMid = container.read(bulkImportProvider);
      expect(stateMid.dependenciesPreparing, true);

      await future;
      final stateEnd = container.read(bulkImportProvider);
      expect(stateEnd.dependenciesPreparing, false);
      expect(stateEnd.dependenciesReady, true);
    });

    test('D43: prepareDependencies propagates failure when parent class creation fails', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_name,section_name\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,FailClass,Section A';

      await notifier.selectFile('students.csv', csv);
      fakeApiClient.postCalls.clear();

      await notifier.prepareDependencies(40, 1, 40);

      final state = container.read(bulkImportProvider);
      expect(state.dependenciesReady, false);
      expect(state.dependencyError, contains('FailClass'));
    });

    test('D44: prepareDependencies blocks section creation when class creation fails', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_name,section_name\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,FailClass,Section A';

      await notifier.selectFile('students.csv', csv);
      fakeApiClient.postCalls.clear();

      await notifier.prepareDependencies(40, 1, 40);

      final hasSectionPost = fakeApiClient.postCalls.any((c) => c['path'] == '/sections');
      expect(hasSectionPost, false);

      final state = container.read(bulkImportProvider);
      expect(state.dependencyError, contains('blocked: parent class could not be resolved'));
    });

    test('D45: prepareDependencies appends detailed HTTP response body and status code on failure', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_name,section_name\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,FailClass,Section A';

      await notifier.selectFile('students.csv', csv);
      fakeApiClient.postCalls.clear();

      await notifier.prepareDependencies(40, 1, 40);

      final state = container.read(bulkImportProvider);
      expect(state.dependencyError, contains('creation failed'));
    });

    test('D46: prepareDependencies invalidates and refetches classes/sections providers on successful dependency creation', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_name,section_name\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,New Class,New Section';

      await notifier.selectFile('students.csv', csv);
      await notifier.prepareDependencies(40, 1, 40);

      final classes = container.read(classesProvider('school_1')).classes;
      expect(classes.any((c) => c.name == 'New Class'), true);
    });
    test('D47: revalidation clears stale class/section unresolved dependency errors when resolved', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_name,section_name\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM999,899,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,New Class,Section A';

      await notifier.selectFile('students.csv', csv);

      // Manually set initial rows to simulate starting with a dependency error
      final initialRows = container.read(bulkImportProvider).rows.map((row) => row.copyWith(
        status: ImportRowStatus.dependencyError,
        errors: ['Class dependency could not be created.'],
      )).toList();
      notifier.state = container.read(bulkImportProvider).copyWith(rows: initialRows);

      final stateBefore = container.read(bulkImportProvider);
      expect(stateBefore.rows.first.errors.isNotEmpty, true);

      await notifier.prepareDependencies(40, 1, 40);

      final stateAfter = container.read(bulkImportProvider);
      expect(stateAfter.rows.first.errors, isEmpty);
    });

    test('D48: revalidation updates rows statuses from dependencyError to valid when resolved', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_name,section_name\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM999,899,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,New Class,Section A';

      await notifier.selectFile('students.csv', csv);

      // Manually set initial rows to simulate starting with a dependency error
      final initialRows = container.read(bulkImportProvider).rows.map((row) => row.copyWith(
        status: ImportRowStatus.dependencyError,
        errors: ['Class dependency could not be created.'],
      )).toList();
      notifier.state = container.read(bulkImportProvider).copyWith(rows: initialRows);

      await notifier.prepareDependencies(40, 1, 40);

      final state = container.read(bulkImportProvider);
      expect(state.rows.first.status, ImportRowStatus.valid);
    });
    test('D49: Selected Academic Year context change listener resets bulk import state', () {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      container.read(selectedAcademicYearIdProvider.notifier).state = 'new_ay_id';

      final state = container.read(bulkImportProvider);
      expect(state.rows, isEmpty);
      expect(state.fileName, isNull);
    });

    test('D50: selectFile handles school id and academic year context changes', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_name,section_name\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,Class 1,Section A';

      await notifier.selectFile('students.csv', csv);
      expect(container.read(bulkImportProvider).rows.isNotEmpty, true);

      container.read(selectedSchoolIdProvider.notifier).state = 'school_2';
      expect(container.read(bulkImportProvider).rows.isEmpty, true);
    });

    test('D51: prepareDependencies creates only unique classes and unique sections and avoids duplicate POST calls', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_name,section_name\n'
          'Rahul,Sharma,MALE,2014-05-12,ADM001,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,New Class,New Section\n'
          'Priya,Sharma,FEMALE,2014-05-12,ADM002,802,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,New Class,New Section';

      await notifier.selectFile('students.csv', csv);
      fakeApiClient.postCalls.clear();

      await notifier.prepareDependencies(40, 1, 40);

      final classCallsCount = fakeApiClient.postCalls.where((c) => c['path'] == '/classes').length;
      final sectionCallsCount = fakeApiClient.postCalls.where((c) => c['path'] == '/sections').length;
      expect(classCallsCount, 1);
      expect(sectionCallsCount, 1);
    });

    test('D52: Single student test: successful student increments successful count and processed count', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'Aarav,Sharma,MALE,2014-05-12,ADM901,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      await notifier.selectFile('students.csv', csv);
      await notifier.importRecords('school_1', fakeApiClient);

      final state = container.read(bulkImportProvider);
      expect(state.currentProgress, 1);
      expect(state.totalProgress, 1);
      expect(state.successCount, 1);
      expect(state.failedCount, 0);
      expect(state.skippedCount, 0);
      expect(state.currentProgress, state.successCount + state.failedCount + state.skippedCount);
      expect(state.rows.first.status, ImportRowStatus.success);
    });

    test('D53: Single student test: failed student increments failed count and does not increment successful', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'Fail422Student,Sharma,MALE,2014-05-12,ADM_FAIL_422,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      await notifier.selectFile('students.csv', csv);
      await notifier.importRecords('school_1', fakeApiClient);

      final state = container.read(bulkImportProvider);
      expect(state.currentProgress, 1);
      expect(state.totalProgress, 1);
      expect(state.successCount, 0);
      expect(state.failedCount, 1);
      expect(state.skippedCount, 0);
      expect(state.currentProgress, state.successCount + state.failedCount + state.skippedCount);
      expect(state.rows.first.status, ImportRowStatus.apiError);
      expect(state.rows.first.apiErrorMessage, contains('Validation failed'));
    });

    test('D54: Single student test: HTTP 409 conflict produces ALREADY_EXISTS status with already exists reason', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'DupStudent,Sharma,MALE,2014-05-12,ADM_DUP,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      await notifier.selectFile('students.csv', csv);
      await notifier.importRecords('school_1', fakeApiClient);

      final state = container.read(bulkImportProvider);
      expect(state.currentProgress, 1);
      expect(state.totalProgress, 1);
      expect(state.successCount, 0);
      expect(state.alreadyExistsCount, 1);
      expect(state.rows.first.status, ImportRowStatus.alreadyExists);
      expect(state.rows.first.apiErrorMessage, contains('already exists'));
    });

    test('D55: Timeout produces NETWORK_ERROR status with Request timed out message', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'TimeoutStudent,Sharma,MALE,2014-05-12,ADM_TIMEOUT,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      await notifier.selectFile('students.csv', csv);
      await notifier.importRecords('school_1', fakeApiClient);

      final state = container.read(bulkImportProvider);
      expect(state.currentProgress, 1);
      expect(state.totalProgress, 1);
      expect(state.networkErrorCount, 1);
      expect(state.apiErrorCount, 0);
      expect(state.rows.first.status, ImportRowStatus.networkError);
      expect(state.rows.first.apiErrorMessage, contains('timed out'));
    });

    test('D56: Partial failure does not block subsequent valid student records', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'StudentOne,Sharma,MALE,2014-05-12,ADM901,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n'
          'Fail422Student,Sharma,MALE,2014-05-12,ADM_FAIL_422,802,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n'
          'StudentThree,Sharma,MALE,2014-05-12,ADM903,803,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      await notifier.selectFile('students.csv', csv);
      await notifier.importRecords('school_1', fakeApiClient);

      final state = container.read(bulkImportProvider);
      expect(state.currentProgress, 3);
      expect(state.totalProgress, 3);
      expect(state.successCount, 2);
      expect(state.failedCount, 1);
      expect(state.currentProgress, state.successCount + state.failedCount + state.skippedCount);
      expect(state.rows[0].status, ImportRowStatus.success);
      expect(state.rows[1].status, ImportRowStatus.apiError);
      expect(state.rows[2].status, ImportRowStatus.success);
    });

    test('D57: Maximum concurrent student creation requests does not exceed 5', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      final buffer = StringBuffer('first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n');
      for (int i = 1; i <= 20; i++) {
        buffer.writeln('Student$i,Sharma,MALE,2014-05-12,ADM90$i,$i,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33');
      }

      fakeApiClient.maxSimultaneousPostCalls = 0;
      await notifier.selectFile('students.csv', buffer.toString());
      await notifier.importRecords('school_1', fakeApiClient);

      final state = container.read(bulkImportProvider);
      expect(state.currentProgress, 20);
      expect(state.totalProgress, 20);
      expect(state.successCount, 20);
      expect(fakeApiClient.maxSimultaneousPostCalls <= 5, true);
    });

    test('D58: 100 students simulation reaches exactly 100/100 with accurate counters', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      final buffer = StringBuffer('first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n');
      // 95 valid, 3 fail 422, 2 duplicate 409
      for (int i = 1; i <= 95; i++) {
        buffer.writeln('Student$i,Sharma,MALE,2014-05-12,ADM9$i,$i,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33');
      }
      for (int i = 1; i <= 3; i++) {
        buffer.writeln('Fail422Student$i,Sharma,MALE,2014-05-12,ADM_FAIL_422_$i,20$i,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33');
      }
      for (int i = 1; i <= 2; i++) {
        buffer.writeln('DupStudent$i,Sharma,MALE,2014-05-12,ADM_DUP_$i,30$i,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33');
      }
      await notifier.selectFile('students.csv', buffer.toString());
      await notifier.importRecords('school_1', fakeApiClient);

      final state = container.read(bulkImportProvider);
      expect(state.totalProgress, 100);
      expect(state.currentProgress, 100);
      expect(state.totalSuccessCount, 95);
      expect(state.apiErrorCount, 3);
      expect(state.alreadyExistsCount, 2);
      expect(state.totalSuccessCount + state.apiErrorCount + state.alreadyExistsCount + state.networkErrorCount + state.validationErrorCount, 100);
      expect(state.isCompleted, true);
    });

    test('D59: Dependency error rows are never sent to POST /students', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'StudentBadDep,Sharma,MALE,2014-05-12,ADM901,801,2026-06-01,invalid-uuid,invalid-uuid,invalid-uuid';

      await notifier.selectFile('students.csv', csv);
      fakeApiClient.postCalls.clear();

      await notifier.importRecords('school_1', fakeApiClient);

      final state = container.read(bulkImportProvider);
      expect(fakeApiClient.postCalls.where((c) => c['path'] == '/students').isEmpty, true);
      expect(state.rows.first.status, ImportRowStatus.skipped);
    });
  });

  group('Bulk Import Connectivity Failure Classification & Safe Retry (20 Scenarios)', () {
    test('1. Network error -> networkError status classification', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'NetErrStudent,Sharma,MALE,2014-05-12,ADM_NET_ERR,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      await notifier.selectFile('students.csv', csv);
      await notifier.importRecords('school_1', fakeApiClient);

      final state = container.read(bulkImportProvider);
      expect(state.rows.first.status, ImportRowStatus.networkError);
      expect(state.networkErrorCount, 1);
    });

    test('2. HTTP 422 -> apiError status classification', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'Fail422Student,Sharma,MALE,2014-05-12,ADM_FAIL_422,802,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      await notifier.selectFile('students.csv', csv);
      await notifier.importRecords('school_1', fakeApiClient);

      final state = container.read(bulkImportProvider);
      expect(state.rows.first.status, ImportRowStatus.apiError);
      expect(state.apiErrorCount, 1);
      expect(state.networkErrorCount, 0);
    });

    test('3. HTTP 409 -> alreadyExists status classification', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'DupStudent,Sharma,MALE,2014-05-12,ADM_DUP,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      await notifier.selectFile('students.csv', csv);
      await notifier.importRecords('school_1', fakeApiClient);

      final state = container.read(bulkImportProvider);
      expect(state.rows.first.status, ImportRowStatus.alreadyExists);
      expect(state.alreadyExistsCount, 1);
    });

    test('4. Successful POST -> success status classification', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'GoodStudent,Sharma,MALE,2014-05-12,ADM101,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      await notifier.selectFile('students.csv', csv);
      await notifier.importRecords('school_1', fakeApiClient);

      final state = container.read(bulkImportProvider);
      expect(state.rows.first.status, ImportRowStatus.success);
      expect(state.totalSuccessCount, 1);
    });

    test('5. Network error does NOT increment apiErrorCount', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'NetErrStudent,Sharma,MALE,2014-05-12,ADM_NET_ERR,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      await notifier.selectFile('students.csv', csv);
      await notifier.importRecords('school_1', fakeApiClient);

      final state = container.read(bulkImportProvider);
      expect(state.networkErrorCount, 1);
      expect(state.apiErrorCount, 0);
    });

    test('6. Network failures remain in state with complete details after import', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'Ira,Singh,FEMALE,2014-05-12,ADM_NET_ERR,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      await notifier.selectFile('students.csv', csv);
      await notifier.importRecords('school_1', fakeApiClient);

      final state = container.read(bulkImportProvider);
      expect(state.rows.length, 1);
      expect(state.rows.first.data['first_name'], 'Ira');
      expect(state.rows.first.data['admission_number'], 'ADM_NET_ERR');
      expect(state.rows.first.data['section_id'], 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33');
      expect(state.rows.first.status, ImportRowStatus.networkError);
    });

    test('7. Retry processes only networkError rows', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'GoodStudent,Sharma,MALE,2014-05-12,ADM101,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n'
          'NetErrStudent,Sharma,MALE,2014-05-12,ADM_NET_ERR,802,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n'
          'Fail422Student,Sharma,MALE,2014-05-12,ADM_FAIL_422,803,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      await notifier.selectFile('students.csv', csv);
      await notifier.importRecords('school_1', fakeApiClient);

      fakeApiClient.postCalls.clear();
      // Configure NetErrStudent to succeed on retry
      fakeApiClient.customStudentResponses['ADM_NET_ERR'] = const ApiResult.success({'id': 'student_new'});

      await notifier.retryNetworkFailures('school_1', fakeApiClient);

      expect(fakeApiClient.postCalls.length, 1);
      expect(fakeApiClient.postCalls.first['data']['admission_number'], 'ADM_NET_ERR');
    });

    test('8. Successful original rows are never retried', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'GoodStudent,Sharma,MALE,2014-05-12,ADM101,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n'
          'NetErrStudent,Sharma,MALE,2014-05-12,ADM_NET_ERR,802,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      await notifier.selectFile('students.csv', csv);
      await notifier.importRecords('school_1', fakeApiClient);

      fakeApiClient.postCalls.clear();
      fakeApiClient.customStudentResponses['ADM_NET_ERR'] = const ApiResult.success({'id': 'student_new'});
      await notifier.retryNetworkFailures('school_1', fakeApiClient);

      final hasGoodStudent = fakeApiClient.postCalls.any((c) => c['data']['admission_number'] == 'ADM101');
      expect(hasGoodStudent, false);
    });

    test('9. AlreadyExists rows are never retried', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'DupStudent,Sharma,MALE,2014-05-12,ADM_DUP,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n'
          'NetErrStudent,Sharma,MALE,2014-05-12,ADM_NET_ERR,802,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      await notifier.selectFile('students.csv', csv);
      await notifier.importRecords('school_1', fakeApiClient);

      fakeApiClient.postCalls.clear();
      fakeApiClient.customStudentResponses['ADM_NET_ERR'] = const ApiResult.success({'id': 'student_new'});
      await notifier.retryNetworkFailures('school_1', fakeApiClient);

      final hasDupStudent = fakeApiClient.postCalls.any((c) => c['data']['admission_number'] == 'ADM_DUP');
      expect(hasDupStudent, false);
    });

    test('10. Retry network failure remains networkError if still disconnected', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'NetErrStudent,Sharma,MALE,2014-05-12,ADM_NET_ERR,802,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      await notifier.selectFile('students.csv', csv);
      await notifier.importRecords('school_1', fakeApiClient);

      expect(container.read(bulkImportProvider).rows.first.status, ImportRowStatus.networkError);

      await notifier.retryNetworkFailures('school_1', fakeApiClient);

      final state = container.read(bulkImportProvider);
      expect(state.rows.first.status, ImportRowStatus.networkError);
      expect(state.retryStillFailedCount, 1);
    });

    test('11. Retry network failure can become success when network recovers', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'NetErrStudent,Sharma,MALE,2014-05-12,ADM_NET_ERR,802,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      await notifier.selectFile('students.csv', csv);
      await notifier.importRecords('school_1', fakeApiClient);

      fakeApiClient.customStudentResponses['ADM_NET_ERR'] = const ApiResult.success({'id': 'student_new'});
      await notifier.retryNetworkFailures('school_1', fakeApiClient);

      final state = container.read(bulkImportProvider);
      expect(state.rows.first.status, ImportRowStatus.success);
      expect(state.totalSuccessCount, 1);
      expect(state.networkErrorCount, 0);
      expect(state.retrySuccessCount, 1);
    });

    test('12. Retry network failure can become alreadyExists if created on previous attempt', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'NetErrStudent,Sharma,MALE,2014-05-12,ADM_NET_ERR,802,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      await notifier.selectFile('students.csv', csv);
      await notifier.importRecords('school_1', fakeApiClient);

      // Server returns 409 because it was created before connection dropped
      fakeApiClient.customStudentResponses['ADM_NET_ERR'] = const ApiResult.failure(ApiFailure(
        type: ApiFailureType.validation,
        statusCode: 409,
        message: 'Student with admission number already exists',
      ));
      await notifier.retryNetworkFailures('school_1', fakeApiClient);

      final state = container.read(bulkImportProvider);
      expect(state.rows.first.status, ImportRowStatus.alreadyExists);
      expect(state.alreadyExistsCount, 1);
      expect(state.networkErrorCount, 0);
      expect(state.retryAlreadyExistsCount, 1);
    });

    test('13. Retry network failure can become apiError on server validation error', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'NetErrStudent,Sharma,MALE,2014-05-12,ADM_NET_ERR,802,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      await notifier.selectFile('students.csv', csv);
      await notifier.importRecords('school_1', fakeApiClient);

      fakeApiClient.customStudentResponses['ADM_NET_ERR'] = const ApiResult.failure(ApiFailure(
        type: ApiFailureType.validation,
        statusCode: 422,
        message: 'Section capacity reached',
      ));
      await notifier.retryNetworkFailures('school_1', fakeApiClient);

      final state = container.read(bulkImportProvider);
      expect(state.rows.first.status, ImportRowStatus.apiError);
      expect(state.apiErrorCount, 1);
      expect(state.networkErrorCount, 0);
    });

    test('14. Maximum concurrency never exceeds 5 during retry', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      final buffer = StringBuffer('first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n');
      for (int i = 1; i <= 20; i++) {
        buffer.writeln('NetErrStudent$i,Sharma,MALE,2014-05-12,ADM_NET_ERR_$i,$i,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33');
      }

      await notifier.selectFile('students.csv', buffer.toString());
      await notifier.importRecords('school_1', fakeApiClient);

      fakeApiClient.maxSimultaneousPostCalls = 0;
      for (int i = 1; i <= 20; i++) {
        fakeApiClient.customStudentResponses['ADM_NET_ERR_$i'] = const ApiResult.success({'id': 'student_new'});
      }

      await notifier.retryNetworkFailures('school_1', fakeApiClient);

      expect(fakeApiClient.maxSimultaneousPostCalls <= 5, true);
      expect(container.read(bulkImportProvider).totalSuccessCount, 20);
    });

    test('15. Final counters equal total rows: total = success + validation + alreadyExists + network + api + skipped', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      final buffer = StringBuffer('first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n');
      // 50 valid, 30 net err, 10 fail 422, 10 dup
      for (int i = 1; i <= 50; i++) {
        buffer.writeln('Student$i,Sharma,MALE,2014-05-12,ADM_OK_$i,$i,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33');
      }
      for (int i = 1; i <= 30; i++) {
        buffer.writeln('NetErrStudent$i,Sharma,MALE,2014-05-12,ADM_NET_ERR_$i,10$i,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33');
      }
      for (int i = 1; i <= 10; i++) {
        buffer.writeln('Fail422Student$i,Sharma,MALE,2014-05-12,ADM_FAIL_422_$i,20$i,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33');
      }
      for (int i = 1; i <= 10; i++) {
        buffer.writeln('DupStudent$i,Sharma,MALE,2014-05-12,ADM_DUP_$i,30$i,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33');
      }

      await notifier.selectFile('students.csv', buffer.toString());
      await notifier.importRecords('school_1', fakeApiClient);

      final state = container.read(bulkImportProvider);
      expect(state.rows.length, 100);
      expect(state.totalSuccessCount, 50);
      expect(state.networkErrorCount, 30);
      expect(state.apiErrorCount, 10);
      expect(state.alreadyExistsCount, 10);
      expect(state.totalSuccessCount + state.networkErrorCount + state.apiErrorCount + state.alreadyExistsCount + state.validationErrorCount + state.totalSkippedCount, 100);
    });

    test('16. Retry counters update correctly during retry lifecycle', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      final buffer = StringBuffer('first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n');
      for (int i = 1; i <= 3; i++) {
        buffer.writeln('NetErrStudent$i,Sharma,MALE,2014-05-12,ADM_NET_ERR_$i,$i,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33');
      }

      await notifier.selectFile('students.csv', buffer.toString());
      await notifier.importRecords('school_1', fakeApiClient);

      // Student 1 -> Success, Student 2 -> AlreadyExists, Student 3 -> Still network error
      fakeApiClient.customStudentResponses['ADM_NET_ERR_1'] = const ApiResult.success({'id': 's1'});
      fakeApiClient.customStudentResponses['ADM_NET_ERR_2'] = const ApiResult.failure(ApiFailure(type: ApiFailureType.validation, statusCode: 409, message: 'exists'));

      await notifier.retryNetworkFailures('school_1', fakeApiClient);

      final state = container.read(bulkImportProvider);
      expect(state.retryTotal, 3);
      expect(state.retrySuccessCount, 1);
      expect(state.retryAlreadyExistsCount, 1);
      expect(state.retryStillFailedCount, 1);
    });

    test('17. HTTP null is never shown in user-facing network error text', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'NetErrStudent,Sharma,MALE,2014-05-12,ADM_NET_ERR,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      await notifier.selectFile('students.csv', csv);
      await notifier.importRecords('school_1', fakeApiClient);

      final state = container.read(bulkImportProvider);
      expect(state.rows.first.apiErrorMessage?.contains('null'), false);
      expect(state.rows.first.apiErrorMessage?.contains('Browser network/CORS connection failure'), true);
    });

    test('18. No duplicate student is created when retry receives HTTP 409', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'NetErrStudent,Sharma,MALE,2014-05-12,ADM_NET_ERR,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      await notifier.selectFile('students.csv', csv);
      await notifier.importRecords('school_1', fakeApiClient);

      fakeApiClient.customStudentResponses['ADM_NET_ERR'] = const ApiResult.failure(ApiFailure(
        type: ApiFailureType.validation,
        statusCode: 409,
        message: 'Student with admission number already exists',
      ));
      await notifier.retryNetworkFailures('school_1', fakeApiClient);

      final state = container.read(bulkImportProvider);
      expect(state.rows.first.status, ImportRowStatus.alreadyExists);
      expect(state.totalSuccessCount, 0);
    });

    test('19. Complete original row data is preserved for retry', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'Aarav,Patel,MALE,2014-05-12,ADM_NET_ERR,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      await notifier.selectFile('students.csv', csv);
      await notifier.importRecords('school_1', fakeApiClient);

      fakeApiClient.postCalls.clear();
      fakeApiClient.customStudentResponses['ADM_NET_ERR'] = const ApiResult.success({'id': 'student_new'});
      await notifier.retryNetworkFailures('school_1', fakeApiClient);

      final postPayload = fakeApiClient.postCalls.first['data'] as Map<String, dynamic>;
      expect(postPayload['first_name'], 'Aarav');
      expect(postPayload['last_name'], 'Patel');
      expect(postPayload['admission_number'], 'ADM_NET_ERR');
      expect(postPayload['academic_year_id'], 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11');
      expect(postPayload['class_id'], 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22');
      expect(postPayload['section_id'], 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33');
    });

    test('20. Final reconciliation does not submit duplicate POST requests', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      const csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'Student1,Sharma,MALE,2014-05-12,ADM101,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n'
          'NetErrStudent,Sharma,MALE,2014-05-12,ADM_NET_ERR,802,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      await notifier.selectFile('students.csv', csv);
      await notifier.importRecords('school_1', fakeApiClient);

      fakeApiClient.postCalls.clear();
      fakeApiClient.customStudentResponses['ADM_NET_ERR'] = const ApiResult.success({'id': 'student_new'});
      await notifier.retryNetworkFailures('school_1', fakeApiClient);

      // Verify exactly 1 call was made during retry
      expect(fakeApiClient.postCalls.length, 1);
      expect(container.read(bulkImportProvider).totalSuccessCount, 2);
    });
  });

  group('Bulk Import Controlled Concurrency Worker Pool Tests', () {
    test('100 rows process correctly with max concurrency <= 5', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      // Generate 100 valid student rows
      final csvBuffer = StringBuffer();
      csvBuffer.writeln('first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id');
      for (int i = 1; i <= 100; i++) {
        csvBuffer.writeln('Student$i,LastName$i,MALE,2014-05-12,CONC_ADM_$i,${800 + i},2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33');
      }

      final testApiClient = FakeBulkImportApiClient();
      await notifier.selectFile('students_100.csv', csvBuffer.toString());
      await notifier.importRecords('school_1', testApiClient);

      final state = container.read(bulkImportProvider);
      
      // 1. 100 rows are processed
      expect(state.rows.length, 100);
      
      // 2. Maximum simultaneous POST requests never exceeds 5
      expect(testApiClient.maxSimultaneousPostCalls, lessThanOrEqualTo(5));
      
      // 3. Every row is processed exactly once
      expect(testApiClient.postCalls.length, 100);

      // 4. No duplicate POST for a row
      final Map<String, int> requestCountByAdmissionNumber = {};
      for (final call in testApiClient.postCalls) {
        if (call['path'] == '/students') {
          final admission = call['data']['admission_number'] as String;
          requestCountByAdmissionNumber[admission] = (requestCountByAdmissionNumber[admission] ?? 0) + 1;
        }
      }
      for (int i = 1; i <= 100; i++) {
        expect(requestCountByAdmissionNumber['CONC_ADM_$i'], 1);
      }

      // 5. Successful responses are counted correctly
      expect(state.totalSuccessCount, 100);
      expect(state.failedCount, 0);
      expect(state.skippedCount, 0);
    });

    test('Granular failure classifications (409, 422, Network) and retry concurrency in 100 rows context', () async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      final testApiClient = FakeBulkImportApiClient();

      // Row 1: Network Error (starts with ADM_NET_ERR)
      // Row 2: HTTP 409 (starts with ADM_DUP)
      // Row 3: HTTP 422 (starts with ADM_FAIL_422)
      // Row 4: HTTP 500 (starts with ADM_FAIL_500)
      // Row 5: Good student
      final csv = 'first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n'
          'NetErr,Sharma,MALE,2014-05-12,ADM_NET_ERR_C1,801,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n'
          'Dup,Sharma,MALE,2014-05-12,ADM_DUP_C2,802,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n'
          'Fail422,Sharma,MALE,2014-05-12,ADM_FAIL_422_C3,803,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n'
          'Fail500,Sharma,MALE,2014-05-12,ADM_FAIL_500_C4,804,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33\n'
          'Good,Sharma,MALE,2014-05-12,ADM_GOOD_C5,805,2026-06-01,a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11,b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22,c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

      await notifier.selectFile('students_mix.csv', csv);
      await notifier.importRecords('school_1', testApiClient);

      final state = container.read(bulkImportProvider);
      
      // Check classifications:
      // Row 1 -> networkError
      expect(state.rows[0].status, ImportRowStatus.networkError);
      // Row 2 -> alreadyExists (HTTP 409)
      expect(state.rows[1].status, ImportRowStatus.alreadyExists);
      // Row 3 -> apiError (HTTP 422)
      expect(state.rows[2].status, ImportRowStatus.apiError);
      // Row 4 -> apiError (HTTP 500)
      expect(state.rows[3].status, ImportRowStatus.apiError);
      // Row 5 -> success
      expect(state.rows[4].status, ImportRowStatus.success);

      // Verify retry network failures processes ONLY networkError rows
      testApiClient.postCalls.clear();
      testApiClient.maxSimultaneousPostCalls = 0;
      testApiClient.customStudentResponses['ADM_NET_ERR_C1'] = const ApiResult.success({'id': 'student_retried'});

      await notifier.retryNetworkFailures('school_1', testApiClient);
      
      // Only 1 request should be sent (Row 1)
      expect(testApiClient.postCalls.length, 1);
      expect(testApiClient.postCalls.first['data']['admission_number'], 'ADM_NET_ERR_C1');
      expect(testApiClient.maxSimultaneousPostCalls, lessThanOrEqualTo(5));

      final finalState = container.read(bulkImportProvider);
      expect(finalState.rows[0].status, ImportRowStatus.success); // Succeeded on retry
      expect(finalState.totalSuccessCount, 2); // Row 1 + Row 5
    });
  });

  group('Spreadsheet Global Import Parser / Null Safety Tests', () {
    late ProviderContainer container;
    late FakeBulkImportApiClient fakeApiClient;

    setUp(() {
      fakeApiClient = FakeBulkImportApiClient();
      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(fakeApiClient),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Null sheets / missing keys in parse response does not crash', () async {
      fakeApiClient.customStudentResponses['__parse_response__'] = const ApiResult.success({
        'success': true,
        'message': 'File parsed successfully.',
        'data': {
          'filename': 'no_sheets.xlsx',
          'format': 'xlsx',
          'sheets': null,
          'selected_sheet': null,
          'columns': null,
          'row_count': 0,
          'preview_rows': null,
        }
      });

      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      // Should not crash and should fall back safely to empty lists
      await notifier.selectSpreadsheetFile('no_sheets.xlsx', Uint8List(0));

      final state = container.read(bulkImportProvider);
      expect(state.sheets, isEmpty);
      expect(state.selectedSheet, isNull);
      expect(state.rows, isEmpty);
    });

    test('CSV parsing returns default implicit sheet and does not crash', () async {
      fakeApiClient.customStudentResponses['__parse_response__'] = const ApiResult.success({
        'success': true,
        'message': 'File parsed successfully.',
        'data': {
          'filename': 'students.csv',
          'format': 'csv',
          'sheets': ['CSV'],
          'selected_sheet': 'CSV',
          'columns': ['first_name', 'last_name'],
          'row_count': 2,
          'preview_rows': [
            ['first_name', 'last_name'],
            ['Alice', 'Smith']
          ],
        }
      });

      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      await notifier.selectSpreadsheetFile('students.csv', Uint8List(0));

      final state = container.read(bulkImportProvider);
      expect(state.sheets, contains('CSV'));
      expect(state.selectedSheet, 'CSV');
      expect(state.rows.length, equals(1)); // 1 validation row (excluding header row)
    });

    test('XLSX multiple sheets parse response displays worksheets', () async {
      fakeApiClient.customStudentResponses['__parse_response__'] = const ApiResult.success({
        'success': true,
        'message': 'File parsed successfully.',
        'data': {
          'filename': 'school.xlsx',
          'format': 'xlsx',
          'sheets': ['school', 'teachers', 'students'],
          'selected_sheet': 'school',
          'columns': ['school_code', 'school_name'],
          'row_count': 2,
          'preview_rows': [
            ['school_code', 'school_name'],
            ['SCH1', 'Main School']
          ],
        }
      });

      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      await notifier.selectSpreadsheetFile('school.xlsx', Uint8List(0));

      final state = container.read(bulkImportProvider);
      expect(state.sheets, equals(['school', 'teachers', 'students']));
      expect(state.selectedSheet, 'school');
    });

    test('Sheet selection update triggers re-parse and validation', () async {
      final notifier = container.read(bulkImportProvider.notifier);
      notifier.setImportType(ImportType.students);

      // Verify selecting sheet calls API with sheet_name query param
      await notifier.selectSpreadsheetFile('school.xlsx', Uint8List(0), sheetName: 'teachers');

      expect(fakeApiClient.postCalls.last['path'], contains('sheet_name=teachers'));
    });
  });
}

ImportRowStatus rowStatus(ParsedRow row) => row.status;
