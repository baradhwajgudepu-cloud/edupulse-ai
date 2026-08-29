import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:admin_portal/core/providers/bootstrap_provider.dart';
import 'package:admin_portal/features/school_setup/presentation/pages/school_details_screen.dart';

// Mock Geolocator Platform implementation
class MockGeolocatorPlatform extends GeolocatorPlatform {
  Position? mockPosition;
  bool isServiceEnabled = true;
  LocationPermission mockPermission = LocationPermission.whileInUse;

  @override
  Future<bool> isLocationServiceEnabled() async => isServiceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => mockPermission;

  @override
  Future<LocationPermission> requestPermission() async => mockPermission;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    if (!isServiceEnabled) {
      throw const LocationServiceDisabledException();
    }
    if (mockPermission == LocationPermission.denied ||
        mockPermission == LocationPermission.deniedForever) {
      throw const PermissionDeniedException("Permission Denied");
    }
    return mockPosition ?? Position(
      longitude: 98.7654,
      latitude: 12.3456,
      timestamp: DateTime.now(),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
      isMocked: false,
    );
  }
}

class FakeGeofenceAuthRepository implements AuthRepository {
  @override
  Future<ApiResult<SessionToken>> login({required String email, required String password}) async {
    return const ApiResult.success(SessionToken(accessToken: 'mock_access', refreshToken: 'mock_refresh', tokenType: 'bearer'));
  }

  @override
  Future<ApiResult<void>> logout({required String refreshToken}) async => const ApiResult.success(null);

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
  Future<ApiResult<void>> requestPasswordReset({required String email}) async => const ApiResult.success(null);

  @override
  Future<ApiResult<void>> resetPassword({
    required String token,
    required String newPassword,
    String? confirmPassword,
  }) async => const ApiResult.success(null);
}

class FakeGeofenceSessionManager implements SessionManager {
  @override
  Future<String?> getTenantId() async => 'tenant_1';
  @override
  Future<void> saveTenantId(String tenantId) async {}
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

class FakeGeofenceApiClient extends BaseApiClient {
  final List<Map<String, dynamic>> putCalls = [];
  Map<String, dynamic> mockSchoolResponse = {
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
    'latitude': null,
    'longitude': null,
    'geofence_radius_meters': 100,
  };

  FakeGeofenceApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (path.startsWith('/schools/school_1')) {
      return ApiResult.success(mapper({'success': true, 'data': mockSchoolResponse}));
    }
    return ApiResult.failure(const ApiFailure(message: 'Not found', type: ApiFailureType.unknown));
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
    putCalls.add({'path': path, 'data': data});
    if (data is Map<String, dynamic>) {
      mockSchoolResponse.addAll(data);
    }
    return ApiResult.success(mapper({'success': true, 'data': mockSchoolResponse}));
  }
}

void main() {
  late ProviderContainer container;
  late MockGeolocatorPlatform mockGeolocator;
  late FakeGeofenceApiClient mockApiClient;

  setUp(() {
    mockGeolocator = MockGeolocatorPlatform();
    GeolocatorPlatform.instance = mockGeolocator;
    mockApiClient = FakeGeofenceApiClient();

    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWith((ref) => FakeGeofenceAuthRepository()),
        sessionManagerProvider.overrideWith((ref) => FakeGeofenceSessionManager()),
        apiClientProvider.overrideWith((ref) => mockApiClient),
        bootstrapResultProvider.overrideWithValue(BootstrapResult(success: true)),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  testWidgets('SchoolDetailsScreen renders geofence unconfigured status and config fields', (WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SchoolDetailsScreen(schoolId: 'school_1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & Fields are rendered
    expect(find.text('Staff Attendance Geofence'), findsOneWidget);
    expect(find.byKey(const Key('latitude_field')), findsOneWidget);
    expect(find.byKey(const Key('longitude_field')), findsOneWidget);
    expect(find.byKey(const Key('radius_field')), findsOneWidget);
    expect(find.byKey(const Key('use_current_location_button')), findsOneWidget);
    expect(find.byKey(const Key('save_geofence_button')), findsOneWidget);

    // Should initially show unconfigured warning
    expect(find.byKey(const Key('geofence_status_not_configured')), findsOneWidget);
    expect(find.text('Geofence not configured'), findsOneWidget);
  });

  testWidgets('SchoolDetailsScreen displays configured coordinates on load', (WidgetTester tester) async {
    mockApiClient.mockSchoolResponse['latitude'] = 17.5000;
    mockApiClient.mockSchoolResponse['longitude'] = 78.4000;
    mockApiClient.mockSchoolResponse['geofence_radius_meters'] = 200;

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
    expect(find.text('17.5'), findsOneWidget);
    expect(find.text('78.4'), findsOneWidget);
    expect(find.text('200'), findsOneWidget);

    // Verify status configured is shown
    expect(find.byKey(const Key('geofence_status_configured')), findsOneWidget);
    expect(find.text('Geofence configured'), findsOneWidget);
  });

  testWidgets('SchoolDetailsScreen Use Current Location button updates text fields without saving', (WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SchoolDetailsScreen(schoolId: 'school_1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Text fields are initially empty
    final latFinder = find.byKey(const Key('latitude_field'));
    final lonFinder = find.byKey(const Key('longitude_field'));
    expect(tester.widget<TextFormField>(latFinder).controller?.text, isEmpty);
    expect(tester.widget<TextFormField>(lonFinder).controller?.text, isEmpty);

    // Click use current location
    final useLocationBtn = find.byKey(const Key('use_current_location_button'));
    await tester.ensureVisible(useLocationBtn);
    await tester.tap(useLocationBtn);
    await tester.pumpAndSettle();

    // Verify fields are populated with mocked geolocator location
    expect(tester.widget<TextFormField>(latFinder).controller?.text, equals('12.3456'));
    expect(tester.widget<TextFormField>(lonFinder).controller?.text, equals('98.7654'));

    // Check that we haven't submitted any update API requests yet (do NOT automatically save)
    expect(mockApiClient.putCalls, isEmpty);
  });

  testWidgets('SchoolDetailsScreen Save Geofence button persists configuration', (WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SchoolDetailsScreen(schoolId: 'school_1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final latFinder = find.byKey(const Key('latitude_field'));
    final lonFinder = find.byKey(const Key('longitude_field'));
    final radFinder = find.byKey(const Key('radius_field'));
    final saveGeofenceBtn = find.byKey(const Key('save_geofence_button'));

    // Enter valid coordinates and radius
    await tester.ensureVisible(latFinder);
    await tester.enterText(latFinder, '13.0827');
    await tester.ensureVisible(lonFinder);
    await tester.enterText(lonFinder, '80.2707');
    await tester.ensureVisible(radFinder);
    await tester.enterText(radFinder, '300');
    await tester.pumpAndSettle();

    // Click Save Geofence
    await tester.ensureVisible(saveGeofenceBtn);
    await tester.tap(saveGeofenceBtn);
    await tester.pumpAndSettle();

    // Verify API update call
    expect(mockApiClient.putCalls, isNotEmpty);
    expect(mockApiClient.putCalls.last['path'], equals('/schools/school_1'));
    final payload = mockApiClient.putCalls.last['data'];
    expect(payload['latitude'], equals(13.0827));
    expect(payload['longitude'], equals(80.2707));
    expect(payload['geofence_radius_meters'], equals(300));
  });

  testWidgets('SchoolDetailsScreen displays validation errors for incorrect fields', (WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SchoolDetailsScreen(schoolId: 'school_1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final latFinder = find.byKey(const Key('latitude_field'));
    final lonFinder = find.byKey(const Key('longitude_field'));
    final radFinder = find.byKey(const Key('radius_field'));
    final saveGeofenceBtn = find.byKey(const Key('save_geofence_button'));

    // Enter out of bounds coordinates and negative radius
    await tester.ensureVisible(latFinder);
    await tester.enterText(latFinder, '95.0');
    await tester.ensureVisible(lonFinder);
    await tester.enterText(lonFinder, '-185.0');
    await tester.ensureVisible(radFinder);
    await tester.enterText(radFinder, '-10');
    await tester.pumpAndSettle();

    // Click Save Geofence to trigger validation
    await tester.ensureVisible(saveGeofenceBtn);
    await tester.tap(saveGeofenceBtn);
    await tester.pumpAndSettle();

    // Check for validation error messages on screen
    expect(find.text('Must be between -90 and 90'), findsOneWidget);
    expect(find.text('Must be between -180 and 180'), findsOneWidget);
    expect(find.text('Must be positive'), findsOneWidget);
  });
}
