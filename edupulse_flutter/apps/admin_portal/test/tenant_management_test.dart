import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:admin_portal/features/tenant_setup/data/models/tenant_models.dart';
import 'package:admin_portal/features/tenant_setup/presentation/providers/tenant_providers.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';

void main() {
  group('Tenant Management Tests', () {
    late Map<String, dynamic> mockResponses;
    late Dio dio;
    late BaseApiClient apiClient;

    setUp(() {
      mockResponses = {};
      dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          final cleanPath = options.path.startsWith('/') ? options.path : '/${options.path}';
          final key = '${options.method} $cleanPath';
          if (mockResponses.containsKey(key)) {
            final mockVal = mockResponses[key];
            if (mockVal is DioException) {
              handler.reject(mockVal);
            } else {
              handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: mockVal,
              ));
            }
          } else {
            handler.resolve(Response(
              requestOptions: options,
              statusCode: 404,
              data: {'success': false, 'message': 'Not Found: $key'},
            ));
          }
        },
      ));
      apiClient = BaseApiClient(dio);
    });

    test('1. Tenant list loading', () async {
      mockResponses['GET /tenants'] = {
        'success': true,
        'message': 'Tenants fetched successfully.',
        'data': [
          {
            'id': 'tenant-uuid-1',
            'name': 'Tenant One',
            'code': 'tenant-one',
            'subdomain': 'tenantone',
            'email': 't1@edu.in',
            'is_active': true,
            'status': 'ACTIVE',
            'timezone': 'Asia/Kolkata',
            'currency': 'INR',
            'country': 'India',
          }
        ],
      };

      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(apiClient),
      ]);

      // Initially empty
      expect(container.read(tenantsListProvider).tenants, isEmpty);

      // Fetch
      await container.read(tenantsListProvider.notifier).fetchTenants();

      final state = container.read(tenantsListProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.tenants, hasLength(1));
      expect(state.tenants[0].id, 'tenant-uuid-1');
      expect(state.tenants[0].name, 'Tenant One');
    });

    test('2. Create tenant successfully and becomes active', () async {
      mockResponses['POST /tenants'] = {
        'success': true,
        'message': 'Tenant created successfully.',
        'data': {
          'id': 'tenant-uuid-2',
          'name': 'Tenant Two',
          'code': 'tenant-two',
          'subdomain': 'tenanttwo',
          'email': 't2@edu.in',
          'is_active': true,
          'status': 'ACTIVE',
          'timezone': 'Asia/Kolkata',
          'currency': 'INR',
          'country': 'India',
        },
      };

      // Mock the list call as well since createTenant calls fetchTenants internally
      mockResponses['GET /tenants'] = {
        'success': true,
        'message': 'Tenants fetched successfully.',
        'data': [
          {
            'id': 'tenant-uuid-2',
            'name': 'Tenant Two',
            'code': 'tenant-two',
            'subdomain': 'tenanttwo',
            'email': 't2@edu.in',
            'is_active': true,
            'status': 'ACTIVE',
            'timezone': 'Asia/Kolkata',
            'currency': 'INR',
            'country': 'India',
          }
        ],
      };

      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(apiClient),
      ]);

      // Register watchers
      container.read(tenantSetupWatcherProvider);

      expect(container.read(selectedTenantIdProvider), isNull);

      final result = await container.read(tenantsListProvider.notifier).createTenant(
            TenantCreateRequest(
              name: 'Tenant Two',
              code: 'tenant-two',
              subdomain: 'tenanttwo',
              email: 't2@edu.in',
            ),
          );

      expect(result.isSuccess, isTrue);
      // Verify active tenant updated automatically
      expect(container.read(selectedTenantIdProvider), 'tenant-uuid-2');
    });

    test('3. Active school is cleared after tenant switch', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(apiClient),
      ]);

      // Set initial contexts
      container.read(selectedTenantIdProvider.notifier).state = 'tenant-uuid-1';
      container.read(selectedSchoolIdProvider.notifier).state = 'school-uuid-1';

      // Register watcher
      container.read(tenantSetupWatcherProvider);

      // Verify school is set
      expect(container.read(selectedSchoolIdProvider), 'school-uuid-1');

      // Switch Tenant
      container.read(selectedTenantIdProvider.notifier).state = 'tenant-uuid-2';

      // Verify school is cleared
      expect(container.read(selectedSchoolIdProvider), isNull);
    });

    test('4. Tenant creation validation rules', () {
      // Regex formats: lowercase, numbers, dashes only for code and subdomain
      final validCode = RegExp(r'^[a-z0-9\-]+$');
      expect(validCode.hasMatch('valid-code-123'), isTrue);
      expect(validCode.hasMatch('Invalid-Code'), isFalse);
      expect(validCode.hasMatch('invalid_code'), isFalse);
      expect(validCode.hasMatch('invalid.code'), isFalse);

      // Phone
      final validPhone = RegExp(r'^(?:\+91|0)?[6-9]\d{9}$');
      expect(validPhone.hasMatch('9876543210'), isTrue);
      expect(validPhone.hasMatch('+919876543210'), isTrue);
      expect(validPhone.hasMatch('09876543210'), isTrue);
      expect(validPhone.hasMatch('1234567890'), isFalse);

      // Indian PIN Code
      final validPin = RegExp(r'^[1-9][0-9]{5}$');
      expect(validPin.hasMatch('500081'), isTrue);
      expect(validPin.hasMatch('012345'), isFalse);
      expect(validPin.hasMatch('5000812'), isFalse);

      // PAN
      final validPan = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
      expect(validPan.hasMatch('ABCDE1234F'), isTrue);
      expect(validPan.hasMatch('abcde1234f'), isFalse);
      expect(validPan.hasMatch('ABCD12345F'), isFalse);

      // GSTIN
      final validGstin = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
      expect(validGstin.hasMatch('36ABCDE1234F1Z5'), isTrue);
      expect(validGstin.hasMatch('36abcde1234f1z5'), isFalse);
    });

    test('5. Duplicate tenant/code handling (HTTP 409 conflict)', () async {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/tenants'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/tenants'),
          statusCode: 409,
          data: {'success': false, 'message': 'Tenant code already registered.'},
        ),
      );

      mockResponses['POST /tenants'] = dioException;

      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(apiClient),
      ]);

      final result = await container.read(tenantsListProvider.notifier).createTenant(
            TenantCreateRequest(
              name: 'Tenant Two',
              code: 'tenant-two',
              subdomain: 'tenanttwo',
              email: 't2@edu.in',
            ),
          );

      expect(result.isFailure, isTrue);
      final state = container.read(tenantsListProvider);
      expect(state.error, contains('Tenant code already registered.'));
    });

    test('6. Clean-state Integration Flow', () async {
      // 1. Initial State: No active tenant, no active school
      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(apiClient),
      ]);
      
      container.read(tenantSetupWatcherProvider);

      expect(container.read(selectedTenantIdProvider), isNull);
      expect(container.read(selectedSchoolIdProvider), isNull);

      // 2. Create Tenant
      mockResponses['POST /tenants'] = {
        'success': true,
        'message': 'Tenant created.',
        'data': {
          'id': 'new-tenant-uuid',
          'name': 'New Tenant',
          'code': 'new-tenant',
          'subdomain': 'newtenant',
          'email': 'new@tenant.com',
          'is_active': true,
          'status': 'ACTIVE',
          'timezone': 'Asia/Kolkata',
          'currency': 'INR',
          'country': 'India',
        },
      };
      mockResponses['GET /tenants'] = {
        'success': true,
        'message': 'Tenants fetched successfully.',
        'data': [],
      };

      final createResult = await container.read(tenantsListProvider.notifier).createTenant(
            TenantCreateRequest(
              name: 'New Tenant',
              code: 'new-tenant',
              subdomain: 'newtenant',
              email: 'new@tenant.com',
            ),
          );
      
      expect(createResult.isSuccess, isTrue);
      // 3. Tenant is selected automatically
      expect(container.read(selectedTenantIdProvider), 'new-tenant-uuid');

      // 4. No active school initially
      expect(container.read(selectedSchoolIdProvider), isNull);

      // 5. Create school under selected tenant
      mockResponses['POST /schools'] = {
        'success': true,
        'message': 'School created.',
        'data': {
          'id': 'new-school-uuid',
          'name': 'New School Campus',
          'code': 'SCH001',
          'board': 'CBSE',
          'email': 'sch@tenant.com',
          'is_active': true,
          'status': 'ACTIVE',
        },
      };

      // Mock fetch schools
      mockResponses['GET /schools'] = {
        'success': true,
        'message': 'Schools fetched.',
        'data': [
          {
            'id': 'new-school-uuid',
            'name': 'New School Campus',
            'code': 'SCH001',
            'board': 'CBSE',
            'email': 'sch@tenant.com',
            'is_active': true,
            'status': 'ACTIVE',
          }
        ],
      };

      final schoolResult = await apiClient.post(
        '/schools',
        data: {
          'name': 'New School Campus',
          'code': 'SCH001',
          'board': 'CBSE',
        },
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          return payload['data'] as Map<String, dynamic>;
        },
      );

      expect(schoolResult.isSuccess, isTrue);
      final schoolUuid = (schoolResult as Success<Map<String, dynamic>>).data['id'] as String;
      
      // 6. School is set active
      container.read(selectedSchoolIdProvider.notifier).state = schoolUuid;
      expect(container.read(selectedSchoolIdProvider), 'new-school-uuid');
    });
  });
}
