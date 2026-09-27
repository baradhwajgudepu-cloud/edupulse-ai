import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:admin_portal/core/auth/portal_permissions.dart';
import 'package:admin_portal/features/users/presentation/providers/user_provider.dart';

class MockApiClient extends BaseApiClient {
  final List<String> recordedUrls = [];
  Map<String, dynamic> mockResponseData = {
    'data': [
      {
        'id': 'u1',
        'email': 'sunitha.chowdary@telanganaschool.edu',
        'first_name': 'Sunitha',
        'last_name': 'Chowdary',
        'status': 'ACTIVE',
        'is_superuser': false,
        'schools': [{'id': 's1', 'name': 'Telangana School'}],
        'roles': [{'code': 'TEACHER', 'name': 'Teacher'}],
      }
    ],
    'meta': {
      'total': 147,
      'skip': 0,
      'limit': 20,
      'page': 1,
      'page_size': 20,
      'total_pages': 8
    }
  };

  MockApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    recordedUrls.add(path);
    return ApiResult.success(mapper(mockResponseData));
  }
}

void main() {
  group('PortalPermissions Role Scoping Tests', () {
    test('Teacher role allows academic modules but strictly denies administrative modules', () {
      const teacherUser = UserEntity(
        id: 'teacher-123',
        email: 'sunitha.chowdary@telanganaschool.edu',
        firstName: 'Sunitha',
        lastName: 'Chowdary',
        tenantId: 'tenant-1',
        isSuperuser: false,
        roles: ['TEACHER'],
        schools: ['school-1'],
      );

      final perms = PortalPermissions.fromUser(teacherUser);

      // Role flags
      expect(perms.isTeacher, isTrue);
      expect(perms.isPrincipal, isFalse);
      expect(perms.isTenantAdmin, isFalse);
      expect(perms.isSuperAdmin, isFalse);

      // Classroom / Academic capabilities allowed
      expect(perms.canAccessClasses, isTrue);
      expect(perms.canAccessStudents, isTrue);
      expect(perms.canAccessAttendance, isTrue);
      expect(perms.canAccessMarks, isTrue);
      expect(perms.canAccessPlanner, isTrue);

      // Administration capabilities strictly denied
      expect(perms.canManageUsers, isFalse);
      expect(perms.canManageTenants, isFalse);
      expect(perms.canManageSchools, isFalse);
      expect(perms.canManageFees, isFalse);
      expect(perms.canManageSettings, isFalse);
      expect(perms.canConfigureExams, isFalse);
      expect(perms.canManagePromotions, isFalse);
      expect(perms.canManageBulkImport, isFalse);

      // Route access validation
      expect(perms.canAccessRoute('/dashboard'), isTrue);
      expect(perms.canAccessRoute('/classes'), isTrue);
      expect(perms.canAccessRoute('/attendance'), isTrue);
      expect(perms.canAccessRoute('/marks'), isTrue);
      expect(perms.canAccessRoute('/planner'), isTrue);

      // Denied routes
      expect(perms.canAccessRoute('/users'), isFalse);
      expect(perms.canAccessRoute('/schools'), isFalse);
      expect(perms.canAccessRoute('/tenants'), isFalse);
      expect(perms.canAccessRoute('/settings'), isFalse);
      expect(perms.canAccessRoute('/fees'), isFalse);
      expect(perms.canAccessRoute('/bulk-import'), isFalse);
      expect(perms.canAccessRoute('/results/exam-types'), isFalse);
    });

    test('Principal role allows school-scoped user management and settings but denies tenant admin', () {
      const principalUser = UserEntity(
        id: 'principal-123',
        email: 'principal@school.edu',
        firstName: 'Ramesh',
        lastName: 'Chandra',
        tenantId: 'tenant-1',
        isSuperuser: false,
        roles: ['PRINCIPAL'],
        schools: ['school-1'],
      );

      final perms = PortalPermissions.fromUser(principalUser);

      expect(perms.isPrincipal, isTrue);
      expect(perms.isTeacher, isFalse);
      expect(perms.canManageUsers, isTrue);
      expect(perms.canManageSettings, isTrue);
      expect(perms.canManageTenants, isFalse);
      expect(perms.canAccessRoute('/users'), isTrue);
      expect(perms.canAccessRoute('/tenants'), isFalse);
    });

    test('Platform Super Admin has full unrestricted portal access', () {
      const adminUser = UserEntity(
        id: 'admin-123',
        email: 'admin@edupulse.ai',
        firstName: 'Super',
        lastName: 'Admin',
        tenantId: 'tenant-1',
        isSuperuser: true,
        roles: ['SUPER_ADMIN'],
        schools: ['school-1'],
      );

      final perms = PortalPermissions.fromUser(adminUser);

      expect(perms.isSuperAdmin, isTrue);
      expect(perms.canManageTenants, isTrue);
      expect(perms.canManageUsers, isTrue);
      expect(perms.canAccessRoute('/tenants'), isTrue);
      expect(perms.canAccessRoute('/users'), isTrue);
      expect(perms.canAccessRoute('/settings'), isTrue);
    });
  });

  group('UsersListNotifier Server-Side Search & Filter Tests', () {
    late MockApiClient mockApi;
    late UsersListNotifier notifier;

    setUp(() {
      mockApi = MockApiClient();
      notifier = UsersListNotifier(mockApi);
    });

    test('fetchUsers calls /identity/users with pagination skip & limit', () async {
      await notifier.fetchUsers(reset: true);

      expect(mockApi.recordedUrls, contains('/identity/users?skip=0&limit=20'));
      expect(notifier.state.users.length, equals(1));
      expect(notifier.state.totalCount, equals(147));
      expect(notifier.state.users.first.firstName, equals('Sunitha'));
    });

    test('search triggers query parameter search in API request', () async {
      notifier.search('Sunitha');

      expect(notifier.state.searchQuery, equals('Sunitha'));
      expect(
        mockApi.recordedUrls.last,
        equals('/identity/users?skip=0&limit=20&search=Sunitha'),
      );
    });

    test('setRoleFilter triggers query parameter role in API request', () async {
      notifier.setRoleFilter('TEACHER');

      expect(notifier.state.selectedRole, equals('TEACHER'));
      expect(
        mockApi.recordedUrls.last,
        equals('/identity/users?skip=0&limit=20&role=TEACHER'),
      );
    });

    test('setStatusFilter triggers query parameter status in API request', () async {
      notifier.setStatusFilter('ACTIVE');

      expect(notifier.state.selectedStatus, equals('ACTIVE'));
      expect(
        mockApi.recordedUrls.last,
        equals('/identity/users?skip=0&limit=20&status=ACTIVE'),
      );
    });

    test('clearFilters resets all filter parameters and triggers reset request', () async {
      notifier.setRoleFilter('ADMIN');
      await Future<void>.delayed(Duration.zero);
      notifier.clearFilters();
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.searchQuery, isEmpty);
      expect(notifier.state.selectedRole, isNull);
      expect(notifier.state.selectedStatus, isNull);
      expect(notifier.state.selectedSchoolId, isNull);
      expect(mockApi.recordedUrls.last, equals('/identity/users?skip=0&limit=20'));
    });
  });
}
