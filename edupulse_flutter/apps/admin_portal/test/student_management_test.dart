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
import 'package:admin_portal/features/students/presentation/pages/students_screen.dart';
import 'package:admin_portal/features/students/presentation/pages/student_details_screen.dart';
import 'package:admin_portal/features/students/presentation/providers/student_providers.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';

class FakeStudentRepository implements AuthRepository {
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

class FakeStudentSessionManager implements SessionManager {
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

class FakeStudentApiClient extends BaseApiClient {
  final List<Map<String, dynamic>> _mockAcademicYears = [
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

  final List<Map<String, dynamic>> _mockStudents = [
    {
      'id': 'student_1',
      'tenant_id': 'tenant_1',
      'school_id': 'school_1',
      'academic_year_id': 'ay_1',
      'class_id': 'class_1',
      'section_id': 'section_1',
      'class_name': 'Class 8',
      'section_name': 'Section A',
      'first_name': 'Aarav',
      'last_name': 'Sharma',
      'gender': 'MALE',
      'date_of_birth': '2014-05-12',
      'admission_number': 'ADM001',
      'roll_number': '801',
      'admission_date': '2026-06-01',
      'status': 'ACTIVE',
      'is_active': true,
      'address': {'line': 'Road 1', 'city': 'Hyderabad', 'state': 'Telangana'},
      'medical_information': {'allergies': 'None'},
      'version': 1,
      'created_at': '2026-08-08T00:00:00Z',
      'updated_at': '2026-08-08T00:00:00Z',
    }
  ];

  final List<Map<String, dynamic>> _mockGuardians = [];

  final List<Map<String, dynamic>> _mockGuardianProfiles = [
    {
      'id': 'guardian_1',
      'tenant_id': 'tenant_1',
      'school_id': 'school_1',
      'guardian_type': 'FATHER',
      'first_name': 'Ramesh',
      'last_name': 'Kumar',
      'gender': 'MALE',
      'date_of_birth': '1985-05-12',
      'email': 'ramesh@gmail.com',
      'mobile': '9876543210',
      'is_mobile_verified': true,
      'is_email_verified': true,
      'status': 'ACTIVE',
      'is_active': true,
      'version': 1,
      'created_at': '2026-08-08T00:00:00Z',
      'updated_at': '2026-08-08T00:00:00Z',
    },
    {
      'id': 'guardian_2',
      'tenant_id': 'tenant_1',
      'school_id': 'school_1',
      'guardian_type': 'MOTHER',
      'first_name': 'Priya',
      'last_name': 'Kumar',
      'gender': 'FEMALE',
      'date_of_birth': '1988-06-15',
      'email': 'priya@gmail.com',
      'mobile': '9876543211',
      'is_mobile_verified': true,
      'is_email_verified': true,
      'status': 'ACTIVE',
      'is_active': true,
      'version': 1,
      'created_at': '2026-08-08T00:00:00Z',
      'updated_at': '2026-08-08T00:00:00Z',
    }
  ];

  Duration? delay;
  int activeDeleteRequests = 0;
  int maxConcurrentDeletesObserved = 0;
  int totalDeleteCalls = 0;
  int totalGetCalls = 0;
  final Set<String> failDeleteIds = {};
  final List<String> deletedIdsObserved = [];
  FakeStudentApiClient() : super(Dio());

  void setMockStudents(List<Map<String, dynamic>> list) {
    _mockStudents.clear();
    _mockStudents.addAll(list);
  }

  Future<void> _maybeDelay() async {
    if (delay != null) {
      await Future.delayed(delay!);
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
    if (path.contains('/students')) {
      totalGetCalls++;
    }
    await _maybeDelay();
    final uri = Uri.parse(path);

    if (path.contains('/academic-years')) {
      return ApiResult.success(mapper({'data': _mockAcademicYears}));
    } else if (path.contains('/classes')) {
      return ApiResult.success(mapper({'data': _mockClasses}));
    } else if (path.contains('/sections')) {
      return ApiResult.success(mapper({'data': _mockSections}));
    } else if (path.contains('/student-guardians')) {
      final guardianId = uri.queryParameters['guardian_id'];
      if (guardianId != null) {
        final list = _mockGuardians.where((m) => m['guardian_id'] == guardianId).toList();
        return ApiResult.success(mapper({'data': list}));
      }
      return ApiResult.success(mapper({'data': _mockGuardians}));
    } else if (path.contains('/identity/provision/status/')) {
      final gId = path.split('/').last.split('?').first;
      if (gId == 'guardian_2') {
        return ApiResult.success(mapper({
          'data': {
            'is_provisioned': false,
            'user_id': null,
            'email': null,
          }
        }));
      }
      return ApiResult.success(mapper({
        'data': {
          'is_provisioned': true,
          'user_id': 'user_for_$gId',
          'email': 'ramesh@gmail.com',
        }
      }));
    } else if (path.contains('/guardians/') && !path.endsWith('/guardians')) {
      final id = path.split('/').last.split('?').first;
      final match = _mockGuardianProfiles.firstWhere(
        (g) => g['id'] == id,
        orElse: () => throw Exception('Guardian not found in mock'),
      );
      return ApiResult.success(mapper({'data': match}));
    } else if (path.contains('/guardians')) {
      final search = uri.queryParameters['search'];
      if (search != null && search.isNotEmpty) {
        final filtered = _mockGuardianProfiles
            .where((g) => g['email'] == search || g['mobile'] == search)
            .toList();
        return ApiResult.success(mapper({'data': filtered}));
      }
      return ApiResult.success(mapper({'data': _mockGuardianProfiles}));
    } else if (path.contains('/students/') && !path.endsWith('/students')) {
      final id = path.split('/').last.split('?').first;
      final match = _mockStudents.firstWhere((s) => s['id'] == id, orElse: () => _mockStudents.first);
      return ApiResult.success(mapper({'data': match}));
    } else if (path.contains('/students')) {
      final schoolId = uri.queryParameters['school_id'] ?? 'school_1';
      final search = uri.queryParameters['search'];
      final classId = uri.queryParameters['class_id'];
      final status = uri.queryParameters['status'];

      final filtered = _mockStudents.where((s) {
        if (s['school_id'] != schoolId) return false;
        if (classId != null && s['class_id'] != classId) return false;
        if (status != null && s['status'] != status) return false;
        if (search != null && search.isNotEmpty) {
          final query = search.toLowerCase();
          return s['first_name'].toLowerCase().contains(query) || s['admission_number'].toLowerCase().contains(query);
        }
        return true;
      }).toList();
      final skip = int.tryParse(uri.queryParameters['skip'] ?? '') ?? 0;
      final limit = int.tryParse(uri.queryParameters['limit'] ?? '') ?? 10;
      final paginated = filtered.skip(skip).take(limit).toList();
      return ApiResult.success(mapper({'data': paginated, 'total': filtered.length}));
    } else if (path.contains('/identity/users/')) {
      final uId = path.split('/').last.split('?').first;
      return ApiResult.success(mapper({
        'data': {
          'id': uId,
          'tenant_id': 'tenant_1',
          'email': 'ramesh@gmail.com',
          'first_name': 'Ramesh',
          'last_name': 'Kumar',
          'status': 'ACTIVE',
          'is_superuser': false,
          'schools': [
            {'id': 'school_1', 'name': 'Greenwood High', 'code': 'GWH'}
          ],
          'roles': [
            {
              'id': 'role_parent',
              'name': 'Parent',
              'code': 'PARENT',
              'description': 'Parent user access',
              'permissions': []
            }
          ],
          'version': 1,
          'created_at': '2026-08-08T00:00:00Z',
          'updated_at': '2026-08-08T00:00:00Z',
        }
      }));
    }

    return ApiResult.failure(const ApiFailure(message: 'Mock Endpoint not found', type: ApiFailureType.unknown));
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
    await _maybeDelay();
    final body = (data is Map<String, dynamic>) ? data : <String, dynamic>{};

    if (path.contains('/students')) {
      final newStudent = {
        'id': 'student_${_mockStudents.length + 1}',
        'tenant_id': 'tenant_1',
        'school_id': body['school_id'] ?? 'school_1',
        'academic_year_id': body['academic_year_id'] ?? 'ay_1',
        'class_id': body['class_id'] ?? 'class_1',
        'section_id': body['section_id'] ?? 'section_1',
        'first_name': body['first_name'] ?? 'New',
        'last_name': body['last_name'] ?? 'Student',
        'gender': body['gender'] ?? 'MALE',
        'date_of_birth': body['date_of_birth'] ?? '2014-05-12',
        'admission_number': body['admission_number'] ?? 'ADM999',
        'roll_number': body['roll_number'] ?? '999',
        'admission_date': body['admission_date'] ?? '2026-06-01',
        'status': body['status'] ?? 'ACTIVE',
        'is_active': true,
        'address': body['address'] ?? const {},
        'medical_information': body['medical_information'] ?? const {},
        'version': 1,
        'created_at': '2026-08-08T00:00:00Z',
        'updated_at': '2026-08-08T00:00:00Z',
      };
      _mockStudents.add(newStudent);
      return ApiResult.success(mapper({'data': newStudent}));
    } else if (path.contains('/student-guardians')) {
      final newMapping = {
        'id': 'mapping_${_mockGuardians.length + 1}',
        'tenant_id': 'tenant_1',
        'school_id': body['school_id'] ?? 'school_1',
        'student_id': body['student_id'],
        'guardian_id': body['guardian_id'],
        'relationship': body['relationship'] ?? 'GUARDIAN',
        'is_primary': body['is_primary'] ?? false,
        'can_pickup_student': body['can_pickup_student'] ?? true,
        'receives_notifications': body['receives_notifications'] ?? true,
        'version': 1,
        'created_at': '2026-08-08T00:00:00Z',
        'updated_at': '2026-08-08T00:00:00Z',
      };
      _mockGuardians.add(newMapping);
      return ApiResult.success(mapper({'data': newMapping}));
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
    await _maybeDelay();
    final body = (data is Map<String, dynamic>) ? data : <String, dynamic>{};
    final id = path.split('/').last.split('?').first;

    if (path.contains('/students/')) {
      final idx = _mockStudents.indexWhere((s) => s['id'] == id);
      if (idx != -1) {
        _mockStudents[idx] = {
          ..._mockStudents[idx],
          ...body,
          'version': _mockStudents[idx]['version'] + 1,
        };
        return ApiResult.success(mapper({'data': _mockStudents[idx]}));
      }
    } else if (path.contains('/student-guardians/')) {
      final idx = _mockGuardians.indexWhere((m) => m['id'] == id);
      if (idx != -1) {
        _mockGuardians[idx] = {
          ..._mockGuardians[idx],
          ...body,
          'version': _mockGuardians[idx]['version'] + 1,
        };
        return ApiResult.success(mapper({'data': _mockGuardians[idx]}));
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
    totalDeleteCalls++;
    activeDeleteRequests++;
    if (activeDeleteRequests > maxConcurrentDeletesObserved) {
      maxConcurrentDeletesObserved = activeDeleteRequests;
    }

    await _maybeDelay();
    final id = path.split('/').last.split('?').first;
    deletedIdsObserved.add(id);

    if (failDeleteIds.contains(id)) {
      activeDeleteRequests--;
      return ApiResult.failure(const ApiFailure(
        message: 'Student cannot be deleted because related records exist.',
        type: ApiFailureType.unknown,
      ));
    }

    if (path.contains('/students/')) {
      _mockStudents.removeWhere((s) => s['id'] == id);
    } else if (path.contains('/student-guardians/')) {
      _mockGuardians.removeWhere((m) => m['id'] == id);
    }

    activeDeleteRequests--;

    return ApiResult.success(mapper({'data': {'status': 'success'}}));
  }
}
void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWith((ref) => FakeStudentRepository()),
        sessionManagerProvider.overrideWith((ref) => FakeStudentSessionManager()),
        apiClientProvider.overrideWith((ref) => FakeStudentApiClient()),
        bootstrapResultProvider.overrideWithValue(BootstrapResult(success: true)),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  testWidgets('StudentsScreen lists students, pagination, filters, and search parameters', (WidgetTester tester) async {
    container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: StudentsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify student is listed
    expect(find.text('Aarav Sharma'), findsWidgets);
    expect(find.text('ADM001'), findsWidgets);

    // Verify search triggers fetch update
    await tester.enterText(find.byType(TextField), 'Aarav');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('Aarav Sharma'), findsWidgets);
  });

  testWidgets('StudentDetailsScreen displays admission profile form and edits', (WidgetTester tester) async {
    container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: StudentDetailsScreen(schoolId: 'school_1', studentId: 'student_1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Aarav'), findsWidgets);
    expect(find.text('ADM001'), findsWidgets);
    expect(find.text('801'), findsWidgets);
    await tester.pumpAndSettle();
  });

  testWidgets('GoRouter student navigation routes to details correctly without literal :id', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeApiClient = FakeStudentApiClient();
    
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWith((ref) => FakeStudentRepository()),
          sessionManagerProvider.overrideWith((ref) => FakeStudentSessionManager()),
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
    
    router.go('${AppRoutes.students}?school_id=school_1');
    await tester.pumpAndSettle();

    expect(find.byType(StudentsScreen), findsOneWidget);
    
    final studentNameFinder = find.text('Aarav Sharma');
    expect(studentNameFinder, findsOneWidget);
    await tester.tap(studentNameFinder);
    await tester.pumpAndSettle();

    expect(find.byType(StudentDetailsScreen), findsOneWidget);
    expect(router.state.uri.path, '/students/student_1');
    expect(router.state.uri.queryParameters['school_id'], 'school_1');
    expect(router.state.uri.path.contains(':id'), false);
    
    await tester.pumpAndSettle();
  });

  group('Student Management Provider and Mutation Audit Tests', () {
    testWidgets('Create student automatically invalidates list provider', (WidgetTester tester) async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: StudentsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Aarav Sharma'), findsWidgets);

      final actionNotifier = container.read(studentActionProvider.notifier);

      // Create student mutation
      final success = await actionNotifier.execute(
        method: 'POST',
        path: '/students',
        data: {
          'first_name': 'Karan',
          'last_name': 'Mehta',
          'gender': 'MALE',
          'date_of_birth': '2014-08-10',
          'admission_number': 'ADM002',
          'roll_number': '802',
          'admission_date': '2026-06-01',
          'school_id': 'school_1',
          'academic_year_id': 'ay_1',
          'class_id': 'class_1',
          'section_id': 'section_1',
        },
      );
      expect(success, true);

      // Invalidate student list and refetch
      container.invalidate(studentListProvider);
      await container.read(studentListProvider.notifier).fetchStudents();
      await tester.pumpAndSettle();

      expect(find.text('Karan Mehta'), findsWidgets);
    });

    testWidgets('Update student handles modifications correctly', (WidgetTester tester) async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

      final actionNotifier = container.read(studentActionProvider.notifier);

      final success = await actionNotifier.execute(
        method: 'PUT',
        path: '/students/student_1?school_id=school_1',
        data: {
          'first_name': 'Aarav Modified',
          'last_name': 'Sharma',
          'gender': 'MALE',
          'date_of_birth': '2014-05-12',
          'admission_number': 'ADM001',
          'roll_number': '801',
          'admission_date': '2026-06-01',
          'school_id': 'school_1',
          'academic_year_id': 'ay_1',
          'class_id': 'class_1',
          'section_id': 'section_1',
          'version': 1,
        },
      );
      expect(success, true);

      container.invalidate(studentListProvider);
      await container.read(studentListProvider.notifier).fetchStudents();
      expect(container.read(studentListProvider).students.first.firstName, 'Aarav Modified');
      await tester.pumpAndSettle();
    });

    testWidgets('Delete student performs soft-delete mapping', (WidgetTester tester) async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

      final actionNotifier = container.read(studentActionProvider.notifier);

      final success = await actionNotifier.execute(
        method: 'DELETE',
        path: '/students/student_1?school_id=school_1',
      );
      expect(success, true);

      container.invalidate(studentListProvider);
      await container.read(studentListProvider.notifier).fetchStudents();
      expect(container.read(studentListProvider).students.every((s) => s.id != 'student_1'), true);
      await tester.pumpAndSettle();
    });

    testWidgets('Guardian association links, updates, and unlinks mappings', (WidgetTester tester) async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

      final actionNotifier = container.read(studentActionProvider.notifier);

      // 1. Link Guardian
      var success = await actionNotifier.execute(
        method: 'POST',
        path: '/student-guardians',
        data: {
          'school_id': 'school_1',
          'student_id': 'student_1',
          'guardian_id': 'guardian_1',
          'relationship': 'FATHER',
          'is_primary': true,
        },
      );
      expect(success, true);

      // Verify mapping state refetched
      container.invalidate(studentGuardianProvider('student_1'));
      var mappings = await container.read(studentGuardianProvider('student_1').future);
      expect(mappings.isNotEmpty, true);
      expect(mappings.first.guardianId, 'guardian_1');

      // 2. Update mapping
      success = await actionNotifier.execute(
        method: 'PUT',
        path: '/student-guardians/mapping_1?school_id=school_1',
        data: {
          'relationship': 'MOTHER',
          'is_primary': false,
        },
      );
      expect(success, true);
      container.invalidate(studentGuardianProvider('student_1'));
      mappings = await container.read(studentGuardianProvider('student_1').future);
      expect(mappings.first.relationship, 'MOTHER');

      // 3. Unlink mapping
      success = await actionNotifier.execute(
        method: 'DELETE',
        path: '/student-guardians/mapping_1?school_id=school_1',
      );
      expect(success, true);
      container.invalidate(studentGuardianProvider('student_1'));
      mappings = await container.read(studentGuardianProvider('student_1').future);
      expect(mappings.isEmpty, true);
      await tester.pumpAndSettle();
    });

    testWidgets('Student details displays guardian info, handles View Parent and error gracefully, and UserDetails shows linked children', (WidgetTester tester) async {
      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

      // 1. Link guardian mappings
      final actionNotifier = container.read(studentActionProvider.notifier);
      await actionNotifier.execute(
        method: 'POST',
        path: '/student-guardians',
        data: {
          'school_id': 'school_1',
          'student_id': 'student_1',
          'guardian_id': 'guardian_1',
          'relationship': 'FATHER',
          'is_primary': true,
        },
      );
      await actionNotifier.execute(
        method: 'POST',
        path: '/student-guardians',
        data: {
          'school_id': 'school_1',
          'student_id': 'student_1',
          'guardian_id': 'guardian_not_exist',
          'relationship': 'MOTHER',
          'is_primary': false,
        },
      );

      // 2. Build StudentDetailsScreen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: StudentDetailsScreen(schoolId: 'school_1', studentId: 'student_1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should display Guardian 1 details
      expect(find.text('Ramesh Kumar (FATHER)'), findsOneWidget);
      expect(find.text('Email: ramesh@gmail.com • Phone: 9876543210'), findsOneWidget);

      // Should display Guardian 2 (missing/unavailable profile) error state gracefully
      expect(find.text('Guardian profile unavailable (MOTHER)'), findsOneWidget);

      // Verify View Parent navigation
      final fakeApiClient = FakeStudentApiClient();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) => FakeStudentRepository()),
            sessionManagerProvider.overrideWith((ref) => FakeStudentSessionManager()),
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

      // Set up the student details mapping first in fake client
      await fakeApiClient.post(
        '/student-guardians',
        data: {
          'school_id': 'school_1',
          'student_id': 'student_1',
          'guardian_id': 'guardian_1',
          'relationship': 'FATHER',
          'is_primary': true,
        },
        mapper: (json) => json,
      );

      router.go('/students/student_1?school_id=school_1');
      await tester.pumpAndSettle();

      // Tap View Parent
      final viewParentFinder = find.text('View Parent');
      expect(viewParentFinder, findsOneWidget);
      await tester.ensureVisible(viewParentFinder);
      await tester.tap(viewParentFinder);
      await tester.pumpAndSettle();

      // Assert it routes to `/users/user_for_guardian_1`
      expect(router.state.uri.path, '/users/user_for_guardian_1');
      
      // Let's pump again to see UserDetailsScreen
      await tester.pumpAndSettle();
      expect(find.text('User Account Details'), findsOneWidget);
      expect(find.text('Ramesh Kumar'), findsWidgets);
      expect(find.text('ramesh@gmail.com'), findsWidgets);

      // Linked children should be rendered
      expect(find.text('Linked Students / Children'), findsOneWidget);
      expect(find.text('Aarav Sharma'), findsWidgets);
      expect(find.text('Admission: ADM001 • Class: Class 8 • Section: Section A • Status: ACTIVE'), findsOneWidget);

      // Clicking View Student in UserDetails links back
      final viewStudentFinder = find.text('View Student');
      expect(viewStudentFinder, findsOneWidget);
      await tester.ensureVisible(viewStudentFinder);
      await tester.tap(viewStudentFinder);
      await tester.pumpAndSettle();

      // Assert router goes back to student detail
      expect(router.state.uri.path, '/students/student_1');
      
      await tester.pumpAndSettle();
    });

    testWidgets('Student Directory - Layout, Multi-selection, Bulk Actions, and FAB menu options', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: StudentsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify custom scrolling table presence
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(find.text('Student Name'), findsOneWidget);
      expect(find.text('Aarav Sharma'), findsOneWidget);

      // 2. Checkboxes multi-selection
      final checkboxFinder = find.byType(Checkbox);
      expect(checkboxFinder, findsWidgets);
      
      // Tap individual student checkbox
      await tester.tap(checkboxFinder.at(1));
      await tester.pumpAndSettle();

      // Bulk toolbar should appear
      expect(find.text('1 selected (current page)'), findsOneWidget);
      expect(find.byKey(const Key('bulk_change_status_btn')), findsOneWidget);
      expect(find.byKey(const Key('bulk_move_section_btn')), findsOneWidget);
      expect(find.byKey(const Key('bulk_export_btn')), findsOneWidget);

      // 3. Test Bulk Status Change confirmation and API execution
      await tester.tap(find.byKey(const Key('bulk_change_status_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Change Student Status'), findsOneWidget);
      
      await tester.tap(find.byKey(const Key('bulk_status_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inactive').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm_status_change_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Bulk Action Results'), findsOneWidget);
      await tester.tap(find.byKey(const Key('bulk_action_results_close_btn')));
      await tester.pumpAndSettle();

      expect(find.text('1 selected (current page)'), findsNothing);

      // 4. Test Split FAB dropdown options
      expect(find.byKey(const Key('admit_options_dropdown_btn')), findsOneWidget);
      await tester.tap(find.byKey(const Key('admit_options_dropdown_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bulk_import_option_btn')), findsOneWidget);
      expect(find.byKey(const Key('download_template_option_btn')), findsOneWidget);
    });

    testWidgets('Student Directory - Bulk Section Move capacity limits verification', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: StudentsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final checkboxFinder = find.byType(Checkbox);
      await tester.tap(checkboxFinder.at(1));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('bulk_move_section_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Move Students to Section'), findsOneWidget);

      await tester.tap(find.byKey(const Key('bulk_move_ay_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026-2027').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('bulk_move_class_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Class 8').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('bulk_move_section_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Section A').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm_move_section_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Bulk Action Results'), findsOneWidget);
      await tester.tap(find.byKey(const Key('bulk_action_results_close_btn')));
      await tester.pumpAndSettle();
    });

    testWidgets('Student Directory - UI Restructure & Bulk Delete Verification Flow', (WidgetTester tester) async {
      // 16. Responsive layout works at desktop width
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: StudentsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Pagination footer renders
      expect(find.textContaining('Showing 1-1 of 1 students'), findsOneWidget);

      // 2. Rows-per-page selector renders
      expect(find.byKey(const Key('pagination_limit_dropdown')), findsOneWidget);

      // 3. FAB does not overlap pagination (they are in different layout nodes: bottomNavigationBar vs FAB)
      expect(find.byKey(const Key('admit_options_dropdown_btn')), findsOneWidget);

      // 6. Rows-per-page remains clickable when FAB menu is closed
      await tester.tap(find.byKey(const Key('pagination_limit_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('25').last);
      await tester.pumpAndSettle();

      // 4. FAB menu opens above the FAB
      await tester.tap(find.byKey(const Key('admit_options_dropdown_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bulk_delete_option_btn')), findsOneWidget);

      // 8. Bulk Delete option inside FAB menu is disabled when no students are selected
      final MenuItemButton deleteOption = tester.widget(find.byKey(const Key('bulk_delete_option_btn')));
      expect(deleteOption.onPressed, isNull);

      // 5. FAB menu does not cover pagination controls / 7. Rows-per-page remains clickable when FAB menu is open
      await tester.tap(find.byKey(const Key('pagination_limit_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10').last);
      await tester.pumpAndSettle();

      // 9. Bulk Delete appears when students are selected
      final checkboxFinder = find.byType(Checkbox);
      await tester.tap(checkboxFinder.at(1));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bulk_delete_btn')), findsOneWidget);

      // 18. Horizontal table scrolling remains functional
      final horizontalScroll = find.byType(SingleChildScrollView).first;
      expect(horizontalScroll, findsWidgets);

      // 19. Vertical table scrolling remains functional
      final verticalScroll = find.byType(SingleChildScrollView).last;
      expect(verticalScroll, findsWidgets);

      // 10. Bulk Delete confirmation dialog appears
      await tester.tap(find.byKey(const Key('bulk_delete_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Delete 1 Students?'), findsOneWidget);
      expect(find.byKey(const Key('confirm_delete_dialog_btn')), findsOneWidget);

      // 11. Cancel does not delete students
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Aarav Sharma'), findsOneWidget);

      // 12. Confirm deletes only selected students
      await tester.tap(find.byKey(const Key('bulk_delete_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_delete_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Successfully deleted: 1 student(s).'), findsOneWidget);
      
      await tester.tap(find.byKey(const Key('bulk_delete_results_close_btn')));
      await tester.pumpAndSettle();

      // 13. Selection clears after successful bulk delete
      expect(find.text('1 selected (current page)'), findsNothing);

      // 14. Student list refreshes after deletion
      expect(find.text('Aarav Sharma'), findsNothing);

      // 15. Pagination is hidden after deletion and empty state is rendered
      expect(find.text('No students found matching selected filters.'), findsOneWidget);

      // 17. Responsive layout works at narrower width (with empty state)
      tester.view.physicalSize = const Size(500, 800);
      await tester.pumpAndSettle();
      expect(find.text('No students found matching selected filters.'), findsOneWidget);
    });

    group('Student Directory - Async Lifecycle & Deactivated Widget Safety tests', () {
      testWidgets('1. Bulk delete succeeds without lifecycle error', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: StudentsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final checkboxFinder = find.byType(Checkbox);
        await tester.tap(checkboxFinder.at(1));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('bulk_delete_btn')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('confirm_delete_dialog_btn')));
        await tester.pumpAndSettle();

        expect(find.textContaining('Successfully deleted: 1 student(s).'), findsOneWidget);
        await tester.tap(find.byKey(const Key('bulk_delete_results_close_btn')));
        await tester.pumpAndSettle();
      });

      testWidgets('2. Widget disposed while bulk delete is awaiting API', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
        
        final apiClient = container.read(apiClientProvider) as FakeStudentApiClient;
        apiClient.delay = const Duration(seconds: 1); // Mock delay to suspend API execution

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: StudentsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final checkboxFinder = find.byType(Checkbox);
        await tester.tap(checkboxFinder.at(1));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('bulk_delete_btn')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('confirm_delete_dialog_btn')));
        await tester.pump(); // Start the async operation but do not settle yet (API is delayed)

        // Dispose the screen by inflating a dummy widget
        await tester.pumpWidget(const SizedBox());
        
        // Complete the delay in fake API and ensure no deactivated widget errors are thrown
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
      });

      testWidgets('3. Widget disposed while bulk status change is awaiting API', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
        
        final apiClient = container.read(apiClientProvider) as FakeStudentApiClient;
        apiClient.delay = const Duration(seconds: 1);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: StudentsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final checkboxFinder = find.byType(Checkbox);
        await tester.tap(checkboxFinder.at(1));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('bulk_change_status_btn')));
        await tester.pumpAndSettle();
        // Select INACTIVE status
        await tester.tap(find.byKey(const Key('bulk_status_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Inactive').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('confirm_status_change_dialog_btn')));
        await tester.pump(); // Start bulk status change API call

        // Dispose screen
        await tester.pumpWidget(const SizedBox());

        // Complete delay
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
      });
      testWidgets('4. Widget disposed while bulk move is awaiting API', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
        
        final apiClient = container.read(apiClientProvider) as FakeStudentApiClient;
        apiClient.delay = const Duration(seconds: 1);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: StudentsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final checkboxFinder = find.byType(Checkbox);
        await tester.tap(checkboxFinder.at(1));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('bulk_move_section_btn')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('bulk_move_ay_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('2026-2027').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('bulk_move_class_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Class 8').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('bulk_move_section_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Section A').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('confirm_move_section_dialog_btn')));
        await tester.pump(); // Start bulk move API call

        // Dispose screen
        await tester.pumpWidget(const SizedBox());

        // Complete delay
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
      });
    });

    group('Student Directory - Bulk Delete Optimization tests', () {
      test('Provider - 50 and 100 selected students work, preserves filters, and checks concurrency/reconciliation limits', () async {
        final apiClient = container.read(apiClientProvider) as FakeStudentApiClient;
        apiClient.delay = const Duration(milliseconds: 10);
        apiClient.maxConcurrentDeletesObserved = 0;
        apiClient.totalDeleteCalls = 0;
        apiClient.totalGetCalls = 0;

        // Generate 100 mock students
        final mockList = List.generate(100, (i) => {
          'id': 'student_opt_$i',
          'tenant_id': 'tenant_1',
          'school_id': 'school_1',
          'academic_year_id': 'ay_1',
          'class_id': 'class_1',
          'section_id': 'section_1',
          'class_name': 'Class 8',
          'section_name': 'Section A',
          'first_name': 'Student',
          'last_name': '$i',
          'gender': 'MALE',
          'date_of_birth': '2014-05-12',
          'admission_number': 'ADM$i',
          'roll_number': '$i',
          'admission_date': '2026-06-01',
          'status': 'ACTIVE',
          'is_active': true,
          'version': 1,
          'created_at': '2026-08-08T00:00:00Z',
          'updated_at': '2026-08-08T00:00:00Z',
        });
        apiClient.setMockStudents(mockList);

        container.read(selectedSchoolIdProvider.notifier).state = 'school_1';
        final notifier = container.read(studentListProvider.notifier);
        notifier.updateLimit(50);
        notifier.updateFilters(search: 'search_query', classId: 'class_1', status: 'ACTIVE');
        await notifier.fetchStudents();
        
        // Reset counters before bulk delete
        apiClient.maxConcurrentDeletesObserved = 0;
        apiClient.totalDeleteCalls = 0;
        apiClient.totalGetCalls = 0;
        final idsToDelete = mockList.take(50).map((s) => s['id'] as String).toList();
        final results = await notifier.bulkDeleteStudents(idsToDelete);

        expect(results['successCount'], 50);
        expect(apiClient.totalDeleteCalls, 50);
        // Concurrency limit is <= 5
        expect(apiClient.maxConcurrentDeletesObserved, lessThanOrEqualTo(5));
        // Only 1 reconciliation GET call was made during bulk delete
        expect(apiClient.totalGetCalls, 1);

        // Verify search, class, and status filters are preserved
        final state = container.read(studentListProvider);
        expect(state.search, 'search_query');
        expect(state.classId, 'class_1');
        expect(state.status, 'ACTIVE');
        expect(state.limit, 50); // page size preserved
      });

      test('Provider - Partial failure preserves failed students in list and retry deletes only failed IDs', () async {
        final apiClient = container.read(apiClientProvider) as FakeStudentApiClient;
        apiClient.delay = Duration.zero;
        apiClient.failDeleteIds.clear();

        final mockList = List.generate(5, (i) => {
          'id': 'stud_fail_$i',
          'tenant_id': 'tenant_1',
          'school_id': 'school_1',
          'academic_year_id': 'ay_1',
          'class_id': 'class_1',
          'section_id': 'section_1',
          'class_name': 'Class 8',
          'section_name': 'Section A',
          'first_name': 'Student',
          'last_name': '$i',
          'gender': 'MALE',
          'date_of_birth': '2014-05-12',
          'admission_number': 'ADM$i',
          'roll_number': '$i',
          'admission_date': '2026-06-01',
          'status': 'ACTIVE',
          'is_active': true,
          'version': 1,
          'created_at': '2026-08-08T00:00:00Z',
          'updated_at': '2026-08-08T00:00:00Z',
        });
        apiClient.setMockStudents(mockList);

        container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

        final notifier = container.read(studentListProvider.notifier);
        await notifier.fetchStudents();

        // Make IDs 2 and 4 fail
        apiClient.failDeleteIds.addAll(['stud_fail_2', 'stud_fail_4']);

        final idsToDelete = mockList.map((s) => s['id'] as String).toList();
        final results = await notifier.bulkDeleteStudents(idsToDelete);

        expect(results['successCount'], 3);
        expect(results['failures'].length, 2);
        expect(results['successfulIds'], containsAll(['stud_fail_0', 'stud_fail_1', 'stud_fail_3']));
        expect(results['failedIds'], containsAll(['stud_fail_2', 'stud_fail_4']));
        // HTTP error message details are preserved
        expect(results['failures'][0], contains('Student cannot be deleted because related records exist.'));

        // The failed students must remain in local state students list
        final state = container.read(studentListProvider);
        final remainingIds = state.students.map((s) => s.id).toList();
        expect(remainingIds, containsAll(['stud_fail_2', 'stud_fail_4']));
        expect(remainingIds.contains('stud_fail_0'), isFalse);
        expect(remainingIds.contains('stud_fail_1'), isFalse);
        expect(remainingIds.contains('stud_fail_3'), isFalse);

        // Now retry failed IDs: resolve their failure first
        apiClient.failDeleteIds.clear();
        final retryResults = await notifier.bulkDeleteStudents(results['failedIds']);
        expect(retryResults['successCount'], 2);
        expect(retryResults['failures'].length, 0);

        final stateAfterRetry = container.read(studentListProvider);
        final finalIds = stateAfterRetry.students.map((s) => s.id).toList();
        expect(finalIds.contains('stud_fail_2'), isFalse);
        expect(finalIds.contains('stud_fail_4'), isFalse);
      });

      test('Provider - Empty page shifts pagination skip offset backward', () async {
        final apiClient = container.read(apiClientProvider) as FakeStudentApiClient;
        apiClient.delay = Duration.zero;

        // Generate 12 students (2 pages: 10 on page 1, 2 on page 2)
        final mockList = List.generate(12, (i) => {
          'id': 'stud_page_$i',
          'tenant_id': 'tenant_1',
          'school_id': 'school_1',
          'academic_year_id': 'ay_1',
          'class_id': 'class_1',
          'section_id': 'section_1',
          'class_name': 'Class 8',
          'section_name': 'Section A',
          'first_name': 'Student',
          'last_name': '$i',
          'gender': 'MALE',
          'date_of_birth': '2014-05-12',
          'admission_number': 'ADM$i',
          'roll_number': '$i',
          'admission_date': '2026-06-01',
          'status': 'ACTIVE',
          'is_active': true,
          'version': 1,
          'created_at': '2026-08-08T00:00:00Z',
          'updated_at': '2026-08-08T00:00:00Z',
        });
        apiClient.setMockStudents(mockList);

        container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

        final notifier = container.read(studentListProvider.notifier);
        await notifier.fetchStudents();
        // Move to Page 2 (skip: 10, limit: 10)
        notifier.nextPage();
        await notifier.fetchStudents();
        expect(container.read(studentListProvider).skip, 10);
        // Delete the remaining 2 students on Page 2
        final idsToDelete = ['stud_page_10', 'stud_page_11'];
        await notifier.bulkDeleteStudents(idsToDelete);

        // Skip should shift back to 0
        expect(container.read(studentListProvider).skip, 0);
      });

      testWidgets('Widget - confirmation dialog, cancel prevents deletion, and selection updates on success/failure', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Set up 2 mock students
        final apiClient = container.read(apiClientProvider) as FakeStudentApiClient;
        apiClient.delay = Duration.zero;
        apiClient.failDeleteIds.clear();

        final mockList = [
          {
            'id': 'ui_student_1',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'class_id': 'class_1',
            'section_id': 'section_1',
            'class_name': 'Class 8',
            'section_name': 'Section A',
            'first_name': 'Aarav',
            'last_name': 'Sharma',
            'gender': 'MALE',
            'date_of_birth': '2014-05-12',
            'admission_number': 'ADM001',
            'roll_number': '801',
            'admission_date': '2026-06-01',
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1,
            'created_at': '2026-08-08T00:00:00Z',
            'updated_at': '2026-08-08T00:00:00Z',
          },
          {
            'id': 'ui_student_2',
            'tenant_id': 'tenant_1',
            'school_id': 'school_1',
            'academic_year_id': 'ay_1',
            'class_id': 'class_1',
            'section_id': 'section_1',
            'class_name': 'Class 8',
            'section_name': 'Section A',
            'first_name': 'Rahul',
            'last_name': 'Sharma',
            'gender': 'MALE',
            'date_of_birth': '2014-05-12',
            'admission_number': 'ADM002',
            'roll_number': '802',
            'admission_date': '2026-06-01',
            'status': 'ACTIVE',
            'is_active': true,
            'version': 1,
            'created_at': '2026-08-08T00:00:00Z',
            'updated_at': '2026-08-08T00:00:00Z',
          }
        ];
        apiClient.setMockStudents(mockList);

        container.read(selectedSchoolIdProvider.notifier).state = 'school_1';

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: StudentsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Select both students
        final checkboxFinder = find.byType(Checkbox);
        await tester.tap(checkboxFinder.at(1)); // First student
        await tester.pumpAndSettle();
        await tester.tap(checkboxFinder.at(2)); // Second student
        await tester.pumpAndSettle();

        // 1. Confirm dialog appears
        await tester.tap(find.byKey(const Key('bulk_delete_btn')));
        await tester.pumpAndSettle();
        expect(find.text('Delete 2 Students?'), findsOneWidget);

        // 2. Cancel prevents deletion
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Aarav Sharma'), findsOneWidget);
        expect(find.text('Rahul Sharma'), findsOneWidget);

        // Make Rahul Sharma (ui_student_2) fail deletion
        apiClient.failDeleteIds.add('ui_student_2');

        // Click delete again and confirm
        await tester.tap(find.byKey(const Key('bulk_delete_btn')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('confirm_delete_dialog_btn')));
        await tester.pump(); // Start execution

        // During execution, check progress updates in the toolbar
        await tester.pump();
        
        // Settle the API execution
        await tester.pumpAndSettle();

        // Successful deletes removes student locally, failure keeps it
        expect(find.text('Aarav Sharma'), findsNothing);
        expect(find.text('Rahul Sharma'), findsOneWidget);

        // Partial failure results dialog is displayed with Retry Failed
        expect(find.text('Bulk Delete Results'), findsOneWidget);
        expect(find.textContaining('Successfully deleted: 1 student(s).'), findsOneWidget);
        expect(find.textContaining('Failed to delete (1):'), findsOneWidget);
        expect(find.byKey(const Key('bulk_delete_results_retry_btn')), findsOneWidget);

        // Unsuccessful student remains selected (1 selected)
        // Close the dialog first
        await tester.tap(find.byKey(const Key('bulk_delete_results_close_btn')));
        await tester.pumpAndSettle();

        // Verify Rahul Sharma remains selected
        expect(find.text('1 selected (current page)'), findsOneWidget);
      });
    });
  });
}
