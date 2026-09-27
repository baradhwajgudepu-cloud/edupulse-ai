// ignore_for_file: deprecated_member_use
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:admin_portal/features/settings/presentation/providers/settings_provider.dart';
import 'package:admin_portal/features/settings/presentation/widgets/school_geofence_card.dart';
import 'package:admin_portal/features/settings/presentation/widgets/location_preview_dialog.dart';
import 'package:admin_portal/features/school_setup/data/models/school_setup_models.dart';

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
    return mockPosition ??
        Position(
          longitude: 78.4867,
          latitude: 17.3850,
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

class FakeSettingsApiClient extends BaseApiClient {
  final List<Map<String, dynamic>> patchCalls = [];
  final List<Map<String, dynamic>> putCalls = [];
  Map<String, dynamic> mockSchoolResponse = {};
  bool simulatePatch404 = false;
  bool simulatePatch500 = false;

  FakeSettingsApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    patchCalls.add({'path': path, 'data': data});
    if (simulatePatch404) {
      return ApiResult.failure(const ApiFailure(
        message: 'HTTP 404 "Not Found"',
        statusCode: 404,
        type: ApiFailureType.network,
      ));
    }
    if (simulatePatch500) {
      return ApiResult.failure(const ApiFailure(
        message: 'HTTP 500 "Internal Server Error"',
        statusCode: 500,
        type: ApiFailureType.server,
      ));
    }
    if (data is Map<String, dynamic>) {
      mockSchoolResponse.addAll(data);
    }
    return ApiResult.success(mapper({'success': true, 'data': mockSchoolResponse}));
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

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (path == '/schools' || path.startsWith('/schools?')) {
      return ApiResult.success(mapper({'success': true, 'data': [mockSchoolResponse]}));
    }
    return ApiResult.success(mapper({'success': true, 'data': mockSchoolResponse}));
  }
}

SchoolDto createTestSchool({
  String id = 'sch_001',
  String name = 'Telangana Model School',
  double? latitude,
  double? longitude,
  int? geofenceRadiusMeters = 100,
  bool? geofenceEnabled,
}) {
  return SchoolDto(
    id: id,
    tenantId: 'tenant_ts',
    name: name,
    code: 'TS001',
    board: 'STATE',
    schoolType: 'HIGH_SCHOOL',
    email: 'principal@telanganaschool.edu',
    isActive: true,
    status: 'ACTIVE',
    version: 1,
    latitude: latitude,
    longitude: longitude,
    geofenceRadiusMeters: geofenceRadiusMeters,
    settings: geofenceEnabled != null
        ? {
            'geofence': {
              'enabled': geofenceEnabled,
              'latitude': latitude,
              'longitude': longitude,
              'radius_meters': geofenceRadiusMeters,
            }
          }
        : null,
  );
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late MockGeolocatorPlatform mockGeolocator;
  late FakeSettingsApiClient mockApiClient;

  setUp(() {
    mockGeolocator = MockGeolocatorPlatform();
    GeolocatorPlatform.instance = mockGeolocator;
    mockApiClient = FakeSettingsApiClient();

    container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWith((ref) => mockApiClient),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  Widget buildTestableWidget(Widget child, {Size size = const Size(1366, 768)}) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  group('SchoolGeofenceCard Widget Tests', () {
    testWidgets('renders unconfigured state when coordinates are null', (tester) async {
      final school = createTestSchool(latitude: null, longitude: null);

      await tester.pumpWidget(buildTestableWidget(SchoolGeofenceCard(school: school)));
      await tester.pumpAndSettle();

      // Header & Title
      expect(find.textContaining('School Geofence & Attendance Location'), findsOneWidget);

      // Toggle & Status
      expect(find.byKey(const Key('geofence_enable_switch')), findsOneWidget);
      expect(find.byKey(const Key('geofence_status_not_configured')), findsOneWidget);
      expect(find.textContaining('Location Not Configured'), findsOneWidget);

      // Fields
      expect(find.byKey(const Key('geofence_latitude_field')), findsOneWidget);
      expect(find.byKey(const Key('geofence_longitude_field')), findsOneWidget);
      expect(find.byKey(const Key('geofence_radius_field')), findsOneWidget);

      // Buttons
      expect(find.byKey(const Key('use_current_location_btn')), findsOneWidget);
      expect(find.byKey(const Key('preview_location_btn')), findsOneWidget);
      expect(find.byKey(const Key('save_geofence_settings_btn')), findsOneWidget);

      // Verify empty fields
      final latFinder = find.byKey(const Key('geofence_latitude_field'));
      final lonFinder = find.byKey(const Key('geofence_longitude_field'));
      final latWidget = tester.widget<TextFormField>(latFinder);
      final lonWidget = tester.widget<TextFormField>(lonFinder);

      expect(latWidget.controller?.text, isEmpty);
      expect(lonWidget.controller?.text, isEmpty);
    });

    testWidgets('displays configured coordinates and enabled state', (tester) async {
      final school = createTestSchool(
        latitude: 17.4485,
        longitude: 78.3741,
        geofenceRadiusMeters: 250,
        geofenceEnabled: true,
      );

      await tester.pumpWidget(buildTestableWidget(SchoolGeofenceCard(school: school)));
      await tester.pumpAndSettle();

      // Configured badge
      expect(find.byKey(const Key('geofence_status_configured')), findsOneWidget);
      expect(find.textContaining('Geofence Configured'), findsOneWidget);

      // Field values
      expect(find.text('17.4485'), findsOneWidget);
      expect(find.text('78.3741'), findsOneWidget);
      expect(find.text('250'), findsOneWidget);

      // Switch is on
      final switchFinder = find.byKey(const Key('geofence_enable_switch'));
      final switchWidget = tester.widget<SwitchListTile>(switchFinder);
      expect(switchWidget.value, isTrue);
    });

    testWidgets('allows toggling geofencing enabled switch', (tester) async {
      final school = createTestSchool(
        latitude: 17.4485,
        longitude: 78.3741,
        geofenceRadiusMeters: 200,
        geofenceEnabled: true,
      );

      await tester.pumpWidget(buildTestableWidget(SchoolGeofenceCard(school: school)));
      await tester.pumpAndSettle();

      final switchFinder = find.byKey(const Key('geofence_enable_switch'));
      expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);

      // Tap toggle to disable
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);

      // Tap toggle to re-enable
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
    });

    testWidgets('Use Current Location button fetches and populates coordinates', (tester) async {
      final school = createTestSchool(latitude: null, longitude: null);

      mockGeolocator.mockPosition = Position(
        latitude: 17.385044,
        longitude: 78.486671,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 500,
        altitudeAccuracy: 1.0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
        isMocked: false,
      );

      await tester.pumpWidget(buildTestableWidget(SchoolGeofenceCard(school: school)));
      await tester.pumpAndSettle();

      // Tap Use Current Location
      final useLocBtn = find.byKey(const Key('use_current_location_btn'));
      await tester.tap(useLocBtn);
      await tester.pumpAndSettle();

      // Coordinates should be filled with formatted strings
      expect(find.text('17.385044'), findsOneWidget);
      expect(find.text('78.486671'), findsOneWidget);

      // Status should switch to configured
      expect(find.byKey(const Key('geofence_status_configured')), findsOneWidget);
    });

    testWidgets('validates latitude, longitude, and radius bounds', (tester) async {
      final school = createTestSchool(latitude: null, longitude: null, geofenceEnabled: true);

      await tester.pumpWidget(buildTestableWidget(SchoolGeofenceCard(school: school)));
      await tester.pumpAndSettle();

      // Enter invalid latitude (> 90)
      final latFinder = find.byKey(const Key('geofence_latitude_field'));
      await tester.enterText(latFinder, '95.0');

      // Enter invalid longitude (> 180)
      final lonFinder = find.byKey(const Key('geofence_longitude_field'));
      await tester.enterText(lonFinder, '200.0');

      // Enter invalid radius (> 10,000)
      final radFinder = find.byKey(const Key('geofence_radius_field'));
      await tester.enterText(radFinder, '15000');

      // Tap Save button to trigger form validation
      final saveBtn = find.byKey(const Key('save_geofence_settings_btn'));
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify validation errors
      expect(find.text('Must be between -90 and +90'), findsOneWidget);
      expect(find.text('Must be between -180 and +180'), findsOneWidget);
      expect(find.text('Maximum allowed radius is 10,000 meters'), findsOneWidget);
      expect(mockApiClient.patchCalls, isEmpty);
    });

    testWidgets('validates negative or zero radius', (tester) async {
      final school = createTestSchool(latitude: 17.5, longitude: 78.5);

      await tester.pumpWidget(buildTestableWidget(SchoolGeofenceCard(school: school)));
      await tester.pumpAndSettle();

      final radFinder = find.byKey(const Key('geofence_radius_field'));
      await tester.enterText(radFinder, '0');

      final saveBtn = find.byKey(const Key('save_geofence_settings_btn'));
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text('Radius must be positive'), findsOneWidget);
      expect(mockApiClient.patchCalls, isEmpty);
    });

    testWidgets('Preview Location opens LocationPreviewDialog with radar visualization', (tester) async {
      final school = createTestSchool(
        name: 'Hyderabad Campus',
        latitude: 17.4485,
        longitude: 78.3741,
        geofenceRadiusMeters: 300,
        geofenceEnabled: true,
      );

      await tester.pumpWidget(buildTestableWidget(SchoolGeofenceCard(school: school)));
      await tester.pumpAndSettle();

      // Tap Preview Location
      final previewBtn = find.byKey(const Key('preview_location_btn'));
      await tester.tap(previewBtn);
      await tester.pumpAndSettle();

      // Verify dialog is opened
      expect(find.byType(LocationPreviewDialog), findsOneWidget);
      expect(find.textContaining('Geofence Preview'), findsOneWidget);
      expect(find.text('Hyderabad Campus'), findsOneWidget);
      expect(find.text('17.448500'), findsOneWidget);
      expect(find.text('78.374100'), findsOneWidget);
      expect(find.text('300 m'), findsOneWidget);

      // Close dialog
      final closeBtn = find.text('Close');
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      expect(find.byType(LocationPreviewDialog), findsNothing);
    });

    testWidgets('saves geofence configuration via PATCH /schools/{id}/geofence', (tester) async {
      final school = createTestSchool(
        id: 'sch_999',
        latitude: null,
        longitude: null,
        geofenceEnabled: false,
      );

      await tester.pumpWidget(buildTestableWidget(SchoolGeofenceCard(school: school)));
      await tester.pumpAndSettle();

      // Enable geofence
      final switchFinder = find.byKey(const Key('geofence_enable_switch'));
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Enter coordinates and radius
      final latFinder = find.byKey(const Key('geofence_latitude_field'));
      await tester.enterText(latFinder, '17.448293');

      final lonFinder = find.byKey(const Key('geofence_longitude_field'));
      await tester.enterText(lonFinder, '78.381204');

      final radFinder = find.byKey(const Key('geofence_radius_field'));
      await tester.enterText(radFinder, '350');
      await tester.pumpAndSettle();

      // Tap Save
      final saveBtn = find.byKey(const Key('save_geofence_settings_btn'));
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify API was called correctly
      expect(mockApiClient.patchCalls.length, 1);
      final call = mockApiClient.patchCalls.first;
      expect(call['path'], '/schools/sch_999/geofence');
      final data = call['data'] as Map<String, dynamic>;
      expect(data['enabled'], isTrue);
      expect(data['latitude'], 17.448293);
      expect(data['longitude'], 78.381204);
      expect(data['radius_meters'], 350);

      // Verify success snackbar
      expect(find.text('School geofence settings saved successfully.'), findsOneWidget);
    });

    testWidgets('saves geofence configuration via PUT fallback when PATCH returns HTTP 404', (tester) async {
      mockApiClient.simulatePatch404 = true;
      final school = createTestSchool(
        id: 'sch_404',
        latitude: null,
        longitude: null,
        geofenceEnabled: false,
      );

      await tester.pumpWidget(buildTestableWidget(SchoolGeofenceCard(school: school)));
      await tester.pumpAndSettle();

      // Enable geofence and enter coordinates
      final switchFinder = find.byKey(const Key('geofence_enable_switch'));
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('geofence_latitude_field')), '17.9689');
      await tester.enterText(find.byKey(const Key('geofence_longitude_field')), '79.5941');
      await tester.enterText(find.byKey(const Key('geofence_radius_field')), '200');
      await tester.pumpAndSettle();

      // Tap Save
      final saveBtn = find.byKey(const Key('save_geofence_settings_btn'));
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify PATCH was attempted first
      expect(mockApiClient.patchCalls.length, 1);
      expect(mockApiClient.patchCalls.first['path'], '/schools/sch_404/geofence');

      // Verify PUT fallback was executed
      expect(mockApiClient.putCalls.length, 1);
      final putCall = mockApiClient.putCalls.first;
      expect(putCall['path'], '/schools/sch_404');
      final putData = putCall['data'] as Map<String, dynamic>;
      expect(putData['latitude'], 17.9689);
      expect(putData['longitude'], 79.5941);
      expect(putData['geofence_radius_meters'], 200);
      expect(putData['settings']['geofence']['enabled'], isTrue);
      expect(putData['settings']['geofence']['latitude'], 17.9689);
      expect(putData['settings']['geofence']['longitude'], 79.5941);
      expect(putData['settings']['geofence']['radius_meters'], 200);

      // Verify success snackbar
      expect(find.text('School geofence settings saved successfully.'), findsOneWidget);
    });

    testWidgets('does not trigger PUT fallback on non-404 error (e.g. 500)', (tester) async {
      mockApiClient.simulatePatch500 = true;
      final school = createTestSchool(
        id: 'sch_500',
        latitude: null,
        longitude: null,
        geofenceEnabled: false,
      );

      await tester.pumpWidget(buildTestableWidget(SchoolGeofenceCard(school: school)));
      await tester.pumpAndSettle();

      // Enable and enter coords
      await tester.tap(find.byKey(const Key('geofence_enable_switch')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('geofence_latitude_field')), '17.9689');
      await tester.enterText(find.byKey(const Key('geofence_longitude_field')), '79.5941');
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.byKey(const Key('save_geofence_settings_btn')));
      await tester.pumpAndSettle();

      // Verify PATCH attempted, but PUT was NOT triggered
      expect(mockApiClient.patchCalls.length, 1);
      expect(mockApiClient.putCalls.length, 0);

      // Verify error snackbar surfaced
      expect(find.textContaining('Failed to save geofence settings'), findsOneWidget);
    });
  });

  group('Responsive Layout & Zero RenderFlex Overflow Verification', () {
    final viewports = <String, Size>{
      '1920x1080 (Desktop Ultra-Wide)': const Size(1920, 1080),
      '1440x900 (Desktop Standard)': const Size(1440, 900),
      '1366x768 (Laptop Common)': const Size(1366, 768),
      '1280x800 (Laptop Standard)': const Size(1280, 800),
      '1024x768 (Tablet Landscape)': const Size(1024, 768),
      '768x1024 (Tablet Portrait)': const Size(768, 1024),
      '412x915 (Mobile Web Width)': const Size(412, 915),
    };

    for (final entry in viewports.entries) {
      testWidgets('renders cleanly without RenderFlex overflow at ${entry.key}', (tester) async {
        await binding.setSurfaceSize(entry.value);
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() async {
          await binding.setSurfaceSize(null);
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final school = createTestSchool(
          latitude: 17.3850,
          longitude: 78.4867,
          geofenceRadiusMeters: 250,
          geofenceEnabled: true,
        );

        await tester.pumpWidget(buildTestableWidget(
          SchoolGeofenceCard(school: school),
          size: entry.value,
        ));
        await tester.pumpAndSettle();

        // 0 RenderFlex overflow exception
        final exc = tester.takeException();
        if (exc != null) {
          print('### EXCEPTION: ' + exc.toString());
          if (exc is FlutterError) {
            for (final d in exc.diagnostics) {
              print('DIAG: ' + d.toStringDeep());
            }
          }
        }
        expect(exc, isNull);

        // Core elements are visible
        expect(find.textContaining('School Geofence & Attendance Location'), findsOneWidget);
        expect(find.byKey(const Key('geofence_status_configured')), findsOneWidget);
        expect(find.byKey(const Key('save_geofence_settings_btn')), findsOneWidget);
      });
    }
  });
}
