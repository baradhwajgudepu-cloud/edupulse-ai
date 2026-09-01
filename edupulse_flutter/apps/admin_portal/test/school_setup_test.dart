import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/core/providers/bootstrap_provider.dart';
import 'package:admin_portal/features/school_setup/presentation/pages/schools_screen.dart';
import 'package:admin_portal/features/school_setup/presentation/pages/school_details_screen.dart';
import 'package:admin_portal/features/school_setup/presentation/pages/academic_years_screen.dart';
import 'package:admin_portal/features/school_setup/presentation/pages/academic_year_details_screen.dart';
import 'package:admin_portal/features/school_setup/presentation/pages/classes_screen.dart';
import 'package:admin_portal/features/school_setup/presentation/pages/class_details_screen.dart';
import 'package:admin_portal/features/school_setup/presentation/pages/sections_screen.dart';
import 'package:admin_portal/features/school_setup/presentation/pages/section_details_screen.dart';
import 'package:admin_portal/features/school_setup/presentation/pages/subjects_screen.dart';
import 'package:admin_portal/features/school_setup/presentation/pages/subject_details_screen.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';

class FakeSchoolRepository implements AuthRepository {
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
    return const ApiResult.success(UserEntity(
      id: 'admin_id_123',
      email: 'admin@edupulse.ai',
      firstName: 'Main',
      lastName: 'Admin',
      tenantId: 'tenant_1',
      isSuperuser: true,
      roles: ['SUPER_ADMIN'],
      schools: ['school_1'],
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

class FakeSchoolSessionManager implements SessionManager {
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

class FakeSchoolApiClient extends BaseApiClient {
  final List<Map<String, dynamic>> _mockSchools = [
    {
      'id': 'school_1',
      'tenant_id': 'tenant_1',
      'name': 'Delhi Public School',
      'code': 'DPS001',
      'board': 'CBSE',
      'school_type': 'HIGH_SCHOOL',
      'email': 'dps@school.edu',
      'is_active': true,
      'status': 'ACTIVE',
      'version': 1,
    }
  ];

  final List<Map<String, dynamic>> _mockAcademicYears = [
    {
      'id': 'ay_1',
      'tenant_id': 'tenant_1',
      'school_id': 'school_1',
      'name': '2026-2027',
      'code': 'AY2026',
      'description': 'Academic Year 2026-2027',
      'start_date': '2026-06-01',
      'end_date': '2027-03-31',
      'status': 'ACTIVE',
      'is_current': true,
      'settings': {
        'grading_scale': 'GPA_4',
        'passing_percentage': 40,
        'auto_promote_students': false
      },
      'version': 1,
    }
  ];

  final List<Map<String, dynamic>> _mockClasses = [
    {
      'id': 'class_1',
      'tenant_id': 'tenant_1',
      'school_id': 'school_1',
      'academic_year_id': 'ay_1',
      'name': 'Class 8',
      'code': 'CLASS_8',
      'level': 8,
      'category': 'HIGH',
      'capacity': 40,
      'status': 'ACTIVE',
      'is_active': true,
      'version': 1,
    }
  ];

  final List<Map<String, dynamic>> _mockSections = [
    {
      'id': 'section_1',
      'tenant_id': 'tenant_1',
      'school_id': 'school_1',
      'academic_year_id': 'ay_1',
      'class_id': 'class_1',
      'name': 'Section A',
      'code': 'SEC_A',
      'capacity': 40,
      'room_number': '101',
      'sort_order': 1,
      'status': 'ACTIVE',
      'is_active': true,
      'version': 1,
    }
  ];

  final List<Map<String, dynamic>> _mockSubjects = [
    {
      'id': 'subject_1',
      'tenant_id': 'tenant_1',
      'school_id': 'school_1',
      'academic_year_id': 'ay_1',
      'subject_code': 'MATH101',
      'subject_name': 'Mathematics',
      'category': 'CORE',
      'subject_type': 'THEORY',
      'theory_marks': 80,
      'practical_marks': 0,
      'pass_marks': 35,
      'status': 'ACTIVE',
      'is_active': true,
      'version': 1,
    }
  ];

  FakeSchoolApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    final uri = Uri.parse(path);

    if (path.contains('/academic-years/') && !path.endsWith('/academic-years')) {
      final id = path.split('/').last.split('?').first;
      final match = _mockAcademicYears.firstWhere((y) => y['id'] == id, orElse: () => _mockAcademicYears.first);
      return ApiResult.success(mapper({'data': match}));
    } else if (path.contains('/academic-years')) {
      final schoolId = path.split('/schools/')[1].split('/academic-years')[0];
      final filtered = _mockAcademicYears.where((y) => y['school_id'] == schoolId).toList();
      return ApiResult.success(mapper({'data': filtered}));
    } else if (path.contains('/schools/') && !path.endsWith('/schools')) {
      final id = path.split('/').last.split('?').first;
      final match = _mockSchools.firstWhere((s) => s['id'] == id, orElse: () => _mockSchools.first);
      return ApiResult.success(mapper({'data': match}));
    } else if (path.contains('/schools')) {
      return ApiResult.success(mapper({'data': _mockSchools}));
    } else if (path.contains('/classes/') && !path.endsWith('/classes')) {
      final id = path.split('/').last.split('?').first;
      final match = _mockClasses.firstWhere((c) => c['id'] == id, orElse: () => _mockClasses.first);
      return ApiResult.success(mapper({'data': match}));
    } else if (path.contains('/classes')) {
      final schoolId = uri.queryParameters['school_id'] ?? 'school_1';
      final ayId = uri.queryParameters['academic_year_id'];
      final filtered = _mockClasses.where((c) {
        if (c['school_id'] != schoolId) return false;
        if (ayId != null && c['academic_year_id'] != ayId) return false;
        return true;
      }).toList();
      return ApiResult.success(mapper({'data': filtered}));
    } else if (path.contains('/sections/') && !path.endsWith('/sections')) {
      final id = path.split('/').last.split('?').first;
      final match = _mockSections.firstWhere((s) => s['id'] == id, orElse: () => _mockSections.first);
      return ApiResult.success(mapper({'data': match}));
    } else if (path.contains('/sections')) {
      final schoolId = uri.queryParameters['school_id'] ?? 'school_1';
      final classId = uri.queryParameters['class_id'];
      final filtered = _mockSections.where((s) {
        if (s['school_id'] != schoolId) return false;
        if (classId != null && s['class_id'] != classId) return false;
        return true;
      }).toList();
      return ApiResult.success(mapper({'data': filtered}));
    } else if (path.contains('/subjects/') && !path.endsWith('/subjects')) {
      final id = path.split('/').last.split('?').first;
      final match = _mockSubjects.firstWhere((s) => s['id'] == id, orElse: () => _mockSubjects.first);
      return ApiResult.success(mapper({'data': match}));
    } else if (path.contains('/subjects')) {
      final schoolId = uri.queryParameters['school_id'] ?? 'school_1';
      final ayId = uri.queryParameters['academic_year_id'];
      final filtered = _mockSubjects.where((s) {
        if (s['school_id'] != schoolId) return false;
        if (ayId != null && s['academic_year_id'] != ayId) return false;
        return true;
      }).toList();
      return ApiResult.success(mapper({'data': filtered}));
    }

    return ApiResult.failure(const ApiFailure(message: 'Endpoint not found mock client', type: ApiFailureType.unknown));
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
    final body = (data is Map<String, dynamic>) ? data : <String, dynamic>{};

    if (path.contains('/schools') && !path.contains('/academic-years')) {
      final newSchool = {
        'id': 'school_${_mockSchools.length + 1}',
        'tenant_id': 'tenant_1',
        'name': body['name'] ?? '',
        'code': body['code'] ?? '',
        'board': body['board'] ?? 'CBSE',
        'school_type': body['school_type'] ?? 'HIGH_SCHOOL',
        'email': body['email'] ?? '',
        'status': body['status'] ?? 'ACTIVE',
        'is_active': true,
        'version': 1,
      };
      _mockSchools.add(newSchool);
      return ApiResult.success(mapper({'data': newSchool}));
    } else if (path.contains('/academic-years')) {
      final schoolId = path.split('/schools/')[1].split('/academic-years')[0];
      final newAy = {
        'id': 'ay_${_mockAcademicYears.length + 1}',
        'tenant_id': 'tenant_1',
        'school_id': schoolId,
        'name': body['name'] ?? '',
        'code': body['code'] ?? '',
        'start_date': body['start_date'] ?? '2026-06-01',
        'end_date': body['end_date'] ?? '2027-03-31',
        'status': body['status'] ?? 'ACTIVE',
        'is_current': body['is_current'] ?? false,
        'version': 1,
      };
      if (newAy['is_current'] == true) {
        for (var y in _mockAcademicYears) {
          if (y['school_id'] == schoolId) {
            y['is_current'] = false;
          }
        }
      }
      _mockAcademicYears.add(newAy);
      return ApiResult.success(mapper({'data': newAy}));
    } else if (path.contains('/classes')) {
      final newClass = {
        'id': 'class_${_mockClasses.length + 1}',
        'tenant_id': 'tenant_1',
        'school_id': body['school_id'] ?? 'school_1',
        'academic_year_id': body['academic_year_id'] ?? 'ay_1',
        'name': body['name'] ?? '',
        'code': body['code'] ?? '',
        'level': body['level'] ?? 1,
        'category': body['category'] ?? 'PRIMARY',
        'capacity': body['capacity'] ?? 40,
        'status': body['status'] ?? 'ACTIVE',
        'is_active': true,
        'version': 1,
      };
      _mockClasses.add(newClass);
      return ApiResult.success(mapper({'data': newClass}));
    } else if (path.contains('/sections')) {
      final newSec = {
        'id': 'section_${_mockSections.length + 1}',
        'tenant_id': 'tenant_1',
        'school_id': body['school_id'] ?? 'school_1',
        'academic_year_id': body['academic_year_id'] ?? 'ay_1',
        'class_id': body['class_id'] ?? 'class_1',
        'name': body['name'] ?? '',
        'code': body['code'] ?? '',
        'capacity': body['capacity'] ?? 40,
        'room_number': body['room_number'] ?? '',
        'sort_order': body['sort_order'] ?? 1,
        'status': body['status'] ?? 'ACTIVE',
        'is_active': true,
        'version': 1,
      };
      _mockSections.add(newSec);
      return ApiResult.success(mapper({'data': newSec}));
    } else if (path.contains('/subjects')) {
      final newSub = {
        'id': 'subject_${_mockSubjects.length + 1}',
        'tenant_id': 'tenant_1',
        'school_id': body['school_id'] ?? 'school_1',
        'academic_year_id': body['academic_year_id'] ?? 'ay_1',
        'subject_code': body['subject_code'] ?? '',
        'subject_name': body['subject_name'] ?? '',
        'category': body['category'] ?? 'CORE',
        'subject_type': body['subject_type'] ?? 'THEORY',
        'theory_marks': body['theory_marks'] ?? 80,
        'practical_marks': body['practical_marks'] ?? 0,
        'pass_marks': body['pass_marks'] ?? 35,
        'status': body['status'] ?? 'ACTIVE',
        'is_active': true,
        'version': 1,
      };
      _mockSubjects.add(newSub);
      return ApiResult.success(mapper({'data': newSub}));
    }
    return ApiResult.success(mapper({'data': {'status': 'success'}}));
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
    final body = (data is Map<String, dynamic>) ? data : <String, dynamic>{};
    final id = path.split('/').last.split('?').first;

    if (path.contains('/academic-years/')) {
      final idx = _mockAcademicYears.indexWhere((y) => y['id'] == id);
      if (idx != -1) {
        _mockAcademicYears[idx] = {
          ..._mockAcademicYears[idx],
          ...body,
          'version': _mockAcademicYears[idx]['version'] + 1,
        };
        if (_mockAcademicYears[idx]['is_current'] == true) {
          final schoolId = _mockAcademicYears[idx]['school_id'];
          for (var i = 0; i < _mockAcademicYears.length; i++) {
            if (i != idx && _mockAcademicYears[i]['school_id'] == schoolId) {
              _mockAcademicYears[i]['is_current'] = false;
            }
          }
        }
        return ApiResult.success(mapper({'data': _mockAcademicYears[idx]}));
      }
    } else if (path.contains('/schools/')) {
      final idx = _mockSchools.indexWhere((s) => s['id'] == id);
      if (idx != -1) {
        _mockSchools[idx] = {
          ..._mockSchools[idx],
          ...body,
          'version': _mockSchools[idx]['version'] + 1,
        };
        return ApiResult.success(mapper({'data': _mockSchools[idx]}));
      }
    } else if (path.contains('/classes/')) {
      final idx = _mockClasses.indexWhere((c) => c['id'] == id);
      if (idx != -1) {
        _mockClasses[idx] = {
          ..._mockClasses[idx],
          ...body,
          'version': _mockClasses[idx]['version'] + 1,
        };
        return ApiResult.success(mapper({'data': _mockClasses[idx]}));
      }
    } else if (path.contains('/sections/')) {
      final idx = _mockSections.indexWhere((s) => s['id'] == id);
      if (idx != -1) {
        _mockSections[idx] = {
          ..._mockSections[idx],
          ...body,
          'version': _mockSections[idx]['version'] + 1,
        };
        return ApiResult.success(mapper({'data': _mockSections[idx]}));
      }
    } else if (path.contains('/subjects/')) {
      final idx = _mockSubjects.indexWhere((s) => s['id'] == id);
      if (idx != -1) {
        _mockSubjects[idx] = {
          ..._mockSubjects[idx],
          ...body,
          'version': _mockSubjects[idx]['version'] + 1,
        };
        return ApiResult.success(mapper({'data': _mockSubjects[idx]}));
      }
    }
    return ApiResult.success(mapper({'data': {'status': 'success'}}));
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
    final id = path.split('/').last.split('?').first;

    if (path.contains('/academic-years/')) {
      _mockAcademicYears.removeWhere((y) => y['id'] == id);
    } else if (path.contains('/schools/')) {
      _mockSchools.removeWhere((s) => s['id'] == id);
    } else if (path.contains('/classes/')) {
      _mockClasses.removeWhere((c) => c['id'] == id);
    } else if (path.contains('/sections/')) {
      _mockSections.removeWhere((s) => s['id'] == id);
    } else if (path.contains('/subjects/')) {
      _mockSubjects.removeWhere((s) => s['id'] == id);
    }

    return ApiResult.success(mapper({'data': {'status': 'success'}}));
  }
}

class FakeSchoolApiClientWithFailures extends FakeSchoolApiClient {
  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    return ApiResult.failure(const ApiFailure(message: 'Simulated create failure', type: ApiFailureType.unknown));
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
    return ApiResult.failure(const ApiFailure(message: 'Simulated update failure', type: ApiFailureType.unknown));
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
    return ApiResult.failure(const ApiFailure(message: 'Simulated delete failure', type: ApiFailureType.unknown));
  }
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWith((ref) => FakeSchoolRepository()),
        sessionManagerProvider.overrideWith((ref) => FakeSchoolSessionManager()),
        apiClientProvider.overrideWith((ref) => FakeSchoolApiClient()),
        bootstrapResultProvider.overrideWithValue(
          BootstrapResult(
            success: true,
          ),
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  testWidgets('SchoolsScreen lists and allows selecting school context', (WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SchoolsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify school item rendered
    expect(find.text('Delhi Public School'), findsWidgets);
    expect(find.text('CBSE'), findsWidgets);
    expect(find.text('HIGH_SCHOOL'), findsWidgets);
  });

  testWidgets('SchoolDetailsScreen form inputs show existing values', (WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SchoolDetailsScreen(schoolId: 'school_1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify fields populated
    expect(find.text('Delhi Public School'), findsWidgets);
    expect(find.text('DPS001'), findsWidgets);
    expect(find.text('dps@school.edu'), findsWidgets);
  });

  testWidgets('AcademicYearsScreen lists academic years', (WidgetTester tester) async {
    container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AcademicYearsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('2026-2027'), findsWidgets);
    expect(find.text('AY2026'), findsWidgets);
  });

  testWidgets('AcademicYearDetailsScreen date formatter constraints', (WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AcademicYearDetailsScreen(schoolId: 'school_1', ayId: 'ay_1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('2026-06-01'), findsOneWidget);
    expect(find.text('2027-03-31'), findsOneWidget);
  });

  testWidgets('ClassesScreen lists classes and categories', (WidgetTester tester) async {
    container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ClassesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Class 8'), findsWidgets);
    expect(find.text('CLASS_8'), findsWidgets);
  });

  testWidgets('ClassDetailsScreen renders level and promotion fields', (WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ClassDetailsScreen(schoolId: 'school_1', classId: 'class_1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Class 8'), findsWidgets);
    expect(find.text('CLASS_8'), findsWidgets);
    expect(find.text('8'), findsWidgets);
  });

  testWidgets('SectionsScreen lists classroom details', (WidgetTester tester) async {
    container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SectionsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Section A'), findsWidgets);
    expect(find.text('SEC_A'), findsWidgets);
  });

  testWidgets('SectionDetailsScreen renders sort order and room', (WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SectionDetailsScreen(schoolId: 'school_1', sectionId: 'section_1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Section A'), findsWidgets);
    expect(find.text('SEC_A'), findsWidgets);
    expect(find.text('101'), findsWidgets);
  });

  testWidgets('SubjectsScreen lists credit and marks limits', (WidgetTester tester) async {
    container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SubjectsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Mathematics'), findsWidgets);
    expect(find.text('MATH101'), findsWidgets);
  });

  testWidgets('SubjectDetailsScreen renders theory and pass validation ranges', (WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SubjectDetailsScreen(schoolId: 'school_1', subjectId: 'subject_1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Mathematics'), findsWidgets);
    expect(find.text('MATH101'), findsWidgets);
    expect(find.text('80'), findsWidgets);
    expect(find.text('35'), findsWidgets);
  });

  group('Complete CRUD State Refetch & Scoping Audit Tests', () {
    testWidgets('Schools CRUD automatically updates the school directory', (WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SchoolsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Delhi Public School'), findsWidgets);

      final actionNotifier = container.read(setupActionProvider.notifier);

      // Create school
      var success = await actionNotifier.execute(
        method: 'POST',
        path: '/schools',
        data: {'name': 'DPS Gachibowli', 'code': 'DPS002'},
      );
      expect(success, true);
      container.invalidate(schoolsListProvider);
      await container.read(schoolsListProvider.notifier).fetchSchools();
      await tester.pumpAndSettle();
      expect(find.text('DPS Gachibowli'), findsWidgets);

      // Update school
      success = await actionNotifier.execute(
        method: 'PUT',
        path: '/schools/school_1',
        data: {'name': 'DPS Secunderabad'},
      );
      expect(success, true);
      container.invalidate(schoolsListProvider);
      await container.read(schoolsListProvider.notifier).fetchSchools();
      await tester.pumpAndSettle();
      expect(find.text('DPS Secunderabad'), findsWidgets);

      // Delete school
      success = await actionNotifier.execute(
        method: 'DELETE',
        path: '/schools/school_2',
      );
      expect(success, true);
      container.invalidate(schoolsListProvider);
      await container.read(schoolsListProvider.notifier).fetchSchools();
      await tester.pumpAndSettle();
      expect(find.text('DPS Gachibowli'), findsNothing);
    });

    testWidgets('Academic Years CRUD automatically refreshes listing', (WidgetTester tester) async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AcademicYearsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('2026-2027'), findsWidgets);

      final actionNotifier = container.read(setupActionProvider.notifier);

      // Create academic year
      var success = await actionNotifier.execute(
        method: 'POST',
        path: '/schools/school_1/academic-years',
        data: {'name': '2027-2028', 'code': 'AY2027'},
      );
      expect(success, true);
      container.invalidate(academicYearsProvider('school_1'));
      await container.read(academicYearsProvider('school_1').notifier).fetchYears();
      await tester.pumpAndSettle();
      expect(find.text('2027-2028'), findsWidgets);

      // Current Year Change
      success = await actionNotifier.execute(
        method: 'PUT',
        path: '/schools/school_1/academic-years/ay_2',
        data: {'is_current': true},
      );
      expect(success, true);
      container.invalidate(academicYearsProvider('school_1'));
      await container.read(academicYearsProvider('school_1').notifier).fetchYears();
      await tester.pumpAndSettle();
      final list = container.read(academicYearsProvider('school_1')).years;
      expect(list.firstWhere((y) => y.id == 'ay_2').isCurrent, true);
      expect(list.firstWhere((y) => y.id == 'ay_1').isCurrent, false);
    });

    testWidgets('Sections CRUD automatically refreshes classroom listing', (WidgetTester tester) async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SectionsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Section A'), findsWidgets);

      final actionNotifier = container.read(setupActionProvider.notifier);

      // Create Section
      var success = await actionNotifier.execute(
        method: 'POST',
        path: '/sections',
        data: {
          'school_id': 'school_1',
          'class_id': 'class_1',
          'name': 'Section B',
          'code': 'SEC_B',
          'capacity': 45,
        },
      );
      expect(success, true);
      container.invalidate(sectionsProvider('school_1'));
      await container.read(sectionsProvider('school_1').notifier).fetchSections(classId: 'class_1');
      await tester.pumpAndSettle();
      expect(find.text('Section B'), findsWidgets);

      // Update Section
      success = await actionNotifier.execute(
        method: 'PUT',
        path: '/sections/section_1',
        data: {
          'name': 'Section A Modified',
          'capacity': 50,
        },
      );
      expect(success, true);
      container.invalidate(sectionsProvider('school_1'));
      await container.read(sectionsProvider('school_1').notifier).fetchSections(classId: 'class_1');
      await tester.pumpAndSettle();
      expect(find.text('Section A Modified'), findsWidgets);

      // Delete Section
      success = await actionNotifier.execute(
        method: 'DELETE',
        path: '/sections/section_2?school_id=school_1',
      );
      expect(success, true);
      container.invalidate(sectionsProvider('school_1'));
      await container.read(sectionsProvider('school_1').notifier).fetchSections(classId: 'class_1');
      await tester.pumpAndSettle();
      expect(find.text('Section B'), findsNothing);
    });

    testWidgets('Subjects CRUD automatically refreshes subject catalog', (WidgetTester tester) async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SubjectsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Mathematics'), findsWidgets);

      final actionNotifier = container.read(setupActionProvider.notifier);

      // Create Subject
      var success = await actionNotifier.execute(
        method: 'POST',
        path: '/subjects',
        data: {
          'school_id': 'school_1',
          'academic_year_id': 'ay_1',
          'subject_name': 'Science',
          'subject_code': 'SCI101',
        },
      );
      expect(success, true);
      container.invalidate(subjectsProvider('school_1'));
      await container.read(subjectsProvider('school_1').notifier).fetchSubjects(academicYearId: 'ay_1');
      await tester.pumpAndSettle();
      expect(find.text('Science'), findsWidgets);

      // Delete Subject
      success = await actionNotifier.execute(
        method: 'DELETE',
        path: '/subjects/subject_2?school_id=school_1',
      );
      expect(success, true);
      container.invalidate(subjectsProvider('school_1'));
      await container.read(subjectsProvider('school_1').notifier).fetchSubjects(academicYearId: 'ay_1');
      await tester.pumpAndSettle();
      expect(find.text('Science'), findsNothing);
    });

    testWidgets('Context isolation and scopes are preserved correctly', (WidgetTester tester) async {
      final freshContainer = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWith((ref) => FakeSchoolRepository()),
          sessionManagerProvider.overrideWith((ref) => FakeSchoolSessionManager()),
          apiClientProvider.overrideWith((ref) => FakeSchoolApiClient()),
          bootstrapResultProvider.overrideWithValue(BootstrapResult(success: true)),
        ],
      );
      addTearDown(freshContainer.dispose);

      // Set school context
      freshContainer.read(selectedSchoolIdProvider.notifier).state = 'school_1';

      // 1. School isolation: Verify classes belong strictly to active school
      final classesNotifier = freshContainer.read(classesProvider('school_1').notifier);
      await classesNotifier.fetchClasses(academicYearId: 'ay_1');
      expect(freshContainer.read(classesProvider('school_1')).classes.every((c) => c.schoolId == 'school_1'), true);

      // 2. Class isolation: Verify sections belong strictly to active class
      final sectionsNotifier = freshContainer.read(sectionsProvider('school_1').notifier);
      await sectionsNotifier.fetchSections(classId: 'class_1');
      expect(freshContainer.read(sectionsProvider('school_1')).sections.every((s) => s.classId == 'class_1'), true);
    });
  });
}
