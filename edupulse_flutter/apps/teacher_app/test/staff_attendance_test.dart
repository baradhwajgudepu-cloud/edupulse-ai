import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:teacher_app/features/staff_attendance/domain/entities/staff_attendance_entity.dart';
import 'package:teacher_app/features/staff_attendance/domain/entities/school_geofence_entity.dart';
import 'package:teacher_app/features/staff_attendance/domain/repositories/staff_attendance_repository.dart';
import 'package:teacher_app/features/staff_attendance/presentation/providers/staff_attendance_provider.dart';
import 'package:teacher_app/features/staff_attendance/presentation/pages/staff_attendance_screen.dart';
import 'package:teacher_app/features/staff_attendance/presentation/widgets/staff_attendance_status_card.dart';
import 'package:teacher_app/features/staff_attendance/presentation/widgets/geofence_status_banner.dart';
import 'package:teacher_app/core/providers/school_context_provider.dart';

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
    if (mockPosition == null) {
      return Position(
        longitude: 77.5946,
        latitude: 12.9716,
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
    return mockPosition!;
  }
}

// Fake Staff Attendance Repository
class FakeStaffAttendanceRepository implements StaffAttendanceRepository {
  bool shouldFailGetStatus = false;
  bool shouldFailCheckIn = false;
  bool shouldFailCheckOut = false;
  int getStatusCallCount = 0;
  int checkInCallCount = 0;
  int checkOutCallCount = 0;

  StaffAttendanceEntity? todayStatus;
  ApiFailure? customFailure;

  SchoolGeofenceEntity? mockGeofence = const SchoolGeofenceEntity(
    schoolId: 'school_123',
    enabled: true,
    latitude: 12.9716,
    longitude: 77.5946,
    radiusMeters: 100,
    isConfigured: true,
  );

  @override
  Future<ApiResult<SchoolGeofenceEntity>> getSchoolGeofence(String schoolId) async {
    if (mockGeofence != null) {
      return ApiResult.success(mockGeofence!);
    }
    return const ApiResult.failure(ApiFailure(
      message: "Geofence not configured",
      type: ApiFailureType.validation,
      statusCode: 400,
    ));
  }

  @override
  Future<ApiResult<StaffAttendanceEntity?>> getTodayStatus() async {
    getStatusCallCount++;
    if (shouldFailGetStatus) {
      return ApiResult.failure(customFailure ?? const ApiFailure(
        message: "Server Error",
        type: ApiFailureType.server,
        statusCode: 500,
      ));
    }
    return ApiResult.success(todayStatus);
  }

  @override
  Future<ApiResult<StaffAttendanceEntity>> checkIn({
    required double latitude,
    required double longitude,
    double? accuracy,
    required bool isMocked,
    String? remarks,
  }) async {
    checkInCallCount++;
    if (shouldFailCheckIn) {
      return ApiResult.failure(customFailure ?? const ApiFailure(
        message: "Outside Boundary",
        type: ApiFailureType.validation,
        statusCode: 422,
      ));
    }
    
    todayStatus = StaffAttendanceEntity(
      id: "att_123",
      tenantId: "tenant_abc",
      teacherId: "teacher_xyz",
      schoolId: "school_123",
      attendanceDate: DateTime.now().toIsoformat(),
      checkInTime: DateTime.now().toIsoformat(),
      checkInLatitude: latitude,
      checkInLongitude: longitude,
      checkInDistanceMeters: 5.0,
      isMockedLocation: isMocked,
      status: "CHECKED_IN",
    );
    return ApiResult.success(todayStatus!);
  }

  @override
  Future<ApiResult<StaffAttendanceEntity>> checkOut({
    required double latitude,
    required double longitude,
    double? accuracy,
    required bool isMocked,
    String? remarks,
  }) async {
    checkOutCallCount++;
    if (shouldFailCheckOut) {
      return ApiResult.failure(customFailure ?? const ApiFailure(
        message: "Check-out Failed",
        type: ApiFailureType.server,
        statusCode: 500,
      ));
    }

    todayStatus = StaffAttendanceEntity(
      id: "att_123",
      tenantId: "tenant_abc",
      teacherId: "teacher_xyz",
      schoolId: "school_123",
      attendanceDate: DateTime.now().toIsoformat(),
      checkInTime: todayStatus?.checkInTime ?? DateTime.now().toIsoformat(),
      checkInLatitude: todayStatus?.checkInLatitude,
      checkInLongitude: todayStatus?.checkInLongitude,
      checkInDistanceMeters: todayStatus?.checkInDistanceMeters,
      checkOutTime: DateTime.now().toIsoformat(),
      checkOutLatitude: latitude,
      checkOutLongitude: longitude,
      checkOutDistanceMeters: 8.0,
      durationSeconds: 28800,
      isMockedLocation: isMocked,
      status: "CHECKED_OUT",
    );
    return ApiResult.success(todayStatus!);
  }
}

extension DateTimeIso on DateTime {
  String toIsoformat() => toIso8601String();
}

void main() {
  late MockGeolocatorPlatform mockGeolocator;
  late FakeStaffAttendanceRepository fakeRepository;

  setUp(() {
    mockGeolocator = MockGeolocatorPlatform();
    GeolocatorPlatform.instance = mockGeolocator;
    fakeRepository = FakeStaffAttendanceRepository();
  });

  ProviderContainer createContainer({String? schoolId = 'school_123'}) {
    return ProviderContainer(
      overrides: [
        staffAttendanceRepositoryProvider.overrideWithValue(fakeRepository),
        if (schoolId != null)
          activeSchoolIdProvider.overrideWith((ref) => schoolId),
      ],
    );
  }

  Widget createTestWidget({String? schoolId = 'school_123'}) {
    return ProviderScope(
      overrides: [
        staffAttendanceRepositoryProvider.overrideWithValue(fakeRepository),
        if (schoolId != null)
          activeSchoolIdProvider.overrideWith((ref) => schoolId),
      ],
      child: const MaterialApp(
        home: StaffAttendanceScreen(),
      ),
    );
  }

  test('Initial state is correct', () {
    final container = createContainer();
    addTearDown(container.dispose);

    expect(container.read(staffAttendanceStateProvider), const StaffAttendanceInitial());
  });

  test('fetchTodayStatus success NOT_CHECKED_IN sets state to NotCheckedIn', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    fakeRepository.todayStatus = null;

    final notifier = container.read(staffAttendanceStateProvider.notifier);
    final future = notifier.fetchTodayStatus();

    expect(container.read(staffAttendanceStateProvider), const StaffAttendanceLoading());
    await future;
    expect(container.read(staffAttendanceStateProvider), const StaffAttendanceNotCheckedIn());
  });

  test('fetchTodayStatus success CHECKED_IN sets state to CheckedIn', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    final checkInEntity = StaffAttendanceEntity(
      id: "att_123",
      tenantId: "tenant_abc",
      teacherId: "teacher_xyz",
      schoolId: "school_123",
      attendanceDate: "2026-08-18",
      checkInTime: "2026-08-18T09:00:00Z",
      checkInDistanceMeters: 10.0,
      isMockedLocation: false,
      status: "CHECKED_IN",
    );
    fakeRepository.todayStatus = checkInEntity;

    final notifier = container.read(staffAttendanceStateProvider.notifier);
    await notifier.fetchTodayStatus();

    final state = container.read(staffAttendanceStateProvider);
    expect(state, isA<StaffAttendanceCheckedIn>());
    expect((state as StaffAttendanceCheckedIn).data, checkInEntity);
  });

  test('fetchTodayStatus success CHECKED_OUT sets state to CheckedOut', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    final checkOutEntity = StaffAttendanceEntity(
      id: "att_123",
      tenantId: "tenant_abc",
      teacherId: "teacher_xyz",
      schoolId: "school_123",
      attendanceDate: "2026-08-18",
      checkInTime: "2026-08-18T09:00:00Z",
      checkOutTime: "2026-08-18T17:00:00Z",
      isMockedLocation: false,
      status: "CHECKED_OUT",
    );
    fakeRepository.todayStatus = checkOutEntity;

    final notifier = container.read(staffAttendanceStateProvider.notifier);
    await notifier.fetchTodayStatus();

    final state = container.read(staffAttendanceStateProvider);
    expect(state, isA<StaffAttendanceCheckedOut>());
    expect((state as StaffAttendanceCheckedOut).data, checkOutEntity);
  });

  test('checkIn success transitions to CheckedIn state', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    fakeRepository.todayStatus = null;
    container.read(staffAttendanceStateProvider.notifier).state = const StaffAttendanceNotCheckedIn();

    final notifier = container.read(staffAttendanceStateProvider.notifier);
    final checkInFuture = notifier.checkIn();

    expect(container.read(staffAttendanceStateProvider), isA<StaffAttendanceCheckingIn>());
    await checkInFuture;

    expect(container.read(staffAttendanceStateProvider), isA<StaffAttendanceCheckedIn>());
    expect(fakeRepository.checkInCallCount, 1);
  });

  test('checkIn geofence boundary rejection returns validation error', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    container.read(staffAttendanceStateProvider.notifier).state = const StaffAttendanceNotCheckedIn();
    fakeRepository.shouldFailCheckIn = true;
    fakeRepository.customFailure = const ApiFailure(
      message: "Outside Boundary Limit",
      type: ApiFailureType.validation,
      statusCode: 422,
    );

    final notifier = container.read(staffAttendanceStateProvider.notifier);
    await notifier.checkIn();

    final state = container.read(staffAttendanceStateProvider);
    expect(state, isA<StaffAttendanceError>());
    expect((state as StaffAttendanceError).message, "Outside Boundary Limit");
  });

  test('checkIn with mocked GPS location is rejected when geofence enabled', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    container.read(staffAttendanceStateProvider.notifier).state = const StaffAttendanceNotCheckedIn();
    mockGeolocator.mockPosition = Position(
      longitude: 77.5946,
      latitude: 12.9716,
      timestamp: DateTime.now(),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
      isMocked: true,
    );

    final notifier = container.read(staffAttendanceStateProvider.notifier);
    await notifier.checkIn();

    final state = container.read(staffAttendanceStateProvider);
    expect(state, isA<StaffAttendanceError>());
    expect((state as StaffAttendanceError).message, contains("Mocked GPS location detected"));
    expect(fakeRepository.checkInCallCount, 0);
  });

  test('checkOut with mocked GPS location is rejected when geofence enabled', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    final checkInEntity = StaffAttendanceEntity(
      id: "att_123",
      tenantId: "tenant_abc",
      teacherId: "teacher_xyz",
      schoolId: "school_123",
      attendanceDate: "2026-08-18",
      checkInTime: "2026-08-18T09:00:00Z",
      isMockedLocation: false,
      status: "CHECKED_IN",
    );
    container.read(staffAttendanceStateProvider.notifier).state = StaffAttendanceCheckedIn(checkInEntity);

    mockGeolocator.mockPosition = Position(
      longitude: 77.5946,
      latitude: 12.9716,
      timestamp: DateTime.now(),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
      isMocked: true,
    );

    final notifier = container.read(staffAttendanceStateProvider.notifier);
    await notifier.checkOut();

    final state = container.read(staffAttendanceStateProvider);
    expect(state, isA<StaffAttendanceError>());
    expect((state as StaffAttendanceError).message, contains("Mocked GPS location detected"));
    expect(fakeRepository.checkOutCallCount, 0);
  });

  test('checkIn location service disabled error returns correct error', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    container.read(staffAttendanceStateProvider.notifier).state = const StaffAttendanceNotCheckedIn();
    mockGeolocator.isServiceEnabled = false;

    final notifier = container.read(staffAttendanceStateProvider.notifier);
    await notifier.checkIn();

    final state = container.read(staffAttendanceStateProvider);
    expect(state, isA<StaffAttendanceError>());
    expect((state as StaffAttendanceError).message, contains("Location services are turned off"));
  });

  test('checkIn permission denied error returns correct error', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    container.read(staffAttendanceStateProvider.notifier).state = const StaffAttendanceNotCheckedIn();
    mockGeolocator.mockPermission = LocationPermission.denied;

    final notifier = container.read(staffAttendanceStateProvider.notifier);
    await notifier.checkIn();

    final state = container.read(staffAttendanceStateProvider);
    expect(state, isA<StaffAttendanceError>());
    expect((state as StaffAttendanceError).message, contains("Location permission is required"));
  });

  test('checkIn permanently denied permission returns correct error', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    container.read(staffAttendanceStateProvider.notifier).state = const StaffAttendanceNotCheckedIn();
    mockGeolocator.mockPermission = LocationPermission.deniedForever;

    final notifier = container.read(staffAttendanceStateProvider.notifier);
    await notifier.checkIn();

    final state = container.read(staffAttendanceStateProvider);
    expect(state, isA<StaffAttendanceError>());
    expect((state as StaffAttendanceError).message, contains("Location permission has been permanently denied"));
  });

  test('Timeout reconciliation after check-in', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    container.read(staffAttendanceStateProvider.notifier).state = const StaffAttendanceNotCheckedIn();
    
    // Simulate checkIn timeout
    fakeRepository.shouldFailCheckIn = true;
    fakeRepository.customFailure = const ApiFailure(
      message: "Connection Timeout",
      type: ApiFailureType.network,
      statusCode: 408,
    );

    // Prepare GET status mock to return successful check-in
    fakeRepository.todayStatus = StaffAttendanceEntity(
      id: "att_123",
      tenantId: "tenant_abc",
      teacherId: "teacher_xyz",
      schoolId: "school_123",
      attendanceDate: "2026-08-18",
      checkInTime: "2026-08-18T09:00:00Z",
      status: "CHECKED_IN",
      isMockedLocation: false,
    );

    final notifier = container.read(staffAttendanceStateProvider.notifier);
    await notifier.checkIn();

    // Verification: status has been reconciled and matches CHECKED_IN
    expect(container.read(staffAttendanceStateProvider), isA<StaffAttendanceCheckedIn>());
    expect(fakeRepository.getStatusCallCount, 1);
  });

  testWidgets('Screen renders correctly for NOT_CHECKED_IN state', (tester) async {
    fakeRepository.todayStatus = null;
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text("Not Checked In"), findsOneWidget);
    expect(find.text("Check In"), findsOneWidget);
    expect(find.textContaining(" verified against the school boundary"), findsOneWidget);
  });

  testWidgets('Screen renders correctly for CHECKED_IN state', (tester) async {
    fakeRepository.todayStatus = StaffAttendanceEntity(
      id: "att_123",
      tenantId: "tenant_abc",
      teacherId: "teacher_xyz",
      schoolId: "school_123",
      attendanceDate: "2026-08-18",
      checkInTime: "2026-08-18T09:30:00Z",
      checkInDistanceMeters: 12.5,
      isMockedLocation: false,
      status: "CHECKED_IN",
    );

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.byType(StaffAttendanceStatusCard), findsOneWidget);
    expect(find.text("Checked In"), findsOneWidget);
    expect(find.text("Check Out"), findsOneWidget);
  });

  testWidgets('Screen renders correctly for CHECKED_OUT state', (tester) async {
    fakeRepository.todayStatus = StaffAttendanceEntity(
      id: "att_123",
      tenantId: "tenant_abc",
      teacherId: "teacher_xyz",
      schoolId: "school_123",
      attendanceDate: "2026-08-18",
      checkInTime: "2026-08-18T09:30:00Z",
      checkOutTime: "2026-08-18T17:30:00Z",
      checkInDistanceMeters: 12.5,
      checkOutDistanceMeters: 5.0,
      durationSeconds: 28800,
      isMockedLocation: false,
      status: "CHECKED_OUT",
    );

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.byType(StaffAttendanceStatusCard), findsOneWidget);
    expect(find.text("Attendance Completed"), findsOneWidget);
    expect(find.text("Check In"), findsNothing);
    expect(find.text("Check Out"), findsNothing);
  });

  test('Geofencing enabled: check-in outside radius is blocked on client', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    // User is ~2.2 km away from school
    mockGeolocator.mockPosition = Position(
      latitude: 12.9916,
      longitude: 77.5946,
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

    final notifier = container.read(staffAttendanceStateProvider.notifier);
    await notifier.fetchTodayStatus();
    await notifier.checkIn();

    // CheckIn call was blocked: repository.checkIn was never called
    expect(fakeRepository.checkInCallCount, 0);
    final currentState = container.read(staffAttendanceStateProvider);
    expect(currentState, isA<StaffAttendanceError>());
    final errorState = currentState as StaffAttendanceError;
    expect(errorState.message, contains('outside the school attendance location'));
    expect(errorState.message, contains('Allowed: 100m'));
  });

  test('Geofencing enabled: check-in inside radius succeeds', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    // User is at school (0 meters away)
    mockGeolocator.mockPosition = Position(
      latitude: 12.9716,
      longitude: 77.5946,
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

    final notifier = container.read(staffAttendanceStateProvider.notifier);
    await notifier.fetchTodayStatus();
    await notifier.checkIn();

    expect(fakeRepository.checkInCallCount, 1);
    expect(container.read(staffAttendanceStateProvider), isA<StaffAttendanceCheckedIn>());
  });

  test('Geofencing disabled: check-in outside radius is allowed', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    // School geofencing is disabled
    fakeRepository.mockGeofence = const SchoolGeofenceEntity(
      schoolId: 'school_123',
      enabled: false,
      latitude: 12.9716,
      longitude: 77.5946,
      radiusMeters: 100,
      isConfigured: true,
    );

    // User is ~2.2 km away
    mockGeolocator.mockPosition = Position(
      latitude: 12.9916,
      longitude: 77.5946,
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

    final notifier = container.read(staffAttendanceStateProvider.notifier);
    await notifier.fetchTodayStatus();
    await notifier.checkIn();

    // Should succeed and call checkIn
    expect(fakeRepository.checkInCallCount, 1);
    expect(container.read(staffAttendanceStateProvider), isA<StaffAttendanceCheckedIn>());
  });

  test('Geofencing enabled: check-out outside radius is blocked, preserves checked-in data', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    fakeRepository.todayStatus = StaffAttendanceEntity(
      id: "att_123",
      tenantId: "tenant_abc",
      teacherId: "teacher_xyz",
      schoolId: "school_123",
      attendanceDate: "2026-08-18",
      checkInTime: "2026-08-18T09:30:00Z",
      checkInDistanceMeters: 5.0,
      isMockedLocation: false,
      status: "CHECKED_IN",
    );

    final notifier = container.read(staffAttendanceStateProvider.notifier);
    await notifier.fetchTodayStatus();
    expect(container.read(staffAttendanceStateProvider), isA<StaffAttendanceCheckedIn>());

    // Move outside radius (~2.2 km away)
    mockGeolocator.mockPosition = Position(
      latitude: 12.9916,
      longitude: 77.5946,
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

    await notifier.checkOut();

    // Check-out blocked: repository.checkOut was never called
    expect(fakeRepository.checkOutCallCount, 0);
    final state = container.read(staffAttendanceStateProvider);
    expect(state, isA<StaffAttendanceError>());
    final err = state as StaffAttendanceError;
    expect(err.message, contains('outside the school attendance location'));
    expect(err.existingData, isNotNull);
    expect(err.existingData!.status, equals('CHECKED_IN'));
  });

  test('GPS accuracy > 100m is rejected', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    mockGeolocator.mockPosition = Position(
      latitude: 12.9716,
      longitude: 77.5946,
      timestamp: DateTime.now(),
      accuracy: 250, // inaccurate fix
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
      isMocked: false,
    );

    final notifier = container.read(staffAttendanceStateProvider.notifier);
    await notifier.fetchTodayStatus();
    await notifier.checkIn();

    expect(fakeRepository.checkInCallCount, 0);
    final state = container.read(staffAttendanceStateProvider);
    expect(state, isA<StaffAttendanceError>());
    expect((state as StaffAttendanceError).message, contains('GPS accuracy is too low'));
  });

  testWidgets('Geofence disabled displays informational banner', (tester) async {
    fakeRepository.todayStatus = null;
    fakeRepository.mockGeofence = const SchoolGeofenceEntity(
      schoolId: 'school_123',
      enabled: false,
      latitude: 12.9716,
      longitude: 77.5946,
      radiusMeters: 100,
      isConfigured: true,
    );

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Attendance is not location restricted (Geofence Disabled).'), findsOneWidget);
    expect(find.textContaining('Location restriction is disabled'), findsOneWidget);
  });

  testWidgets('Geofence unconfigured displays error banner and disables check-in', (tester) async {
    fakeRepository.todayStatus = null;
    fakeRepository.mockGeofence = const SchoolGeofenceEntity(
      schoolId: 'school_123',
      enabled: true,
      latitude: null,
      longitude: null,
      radiusMeters: 100,
      isConfigured: false,
    );

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('School attendance location is not configured. Sign-in cannot be verified.'), findsOneWidget);
    expect(find.textContaining('School attendance geofence coordinates are not configured'), findsOneWidget);

    // Tapping Check In should not trigger checkInCallCount because button is disabled
    await tester.tap(find.text('Check In'));
    await tester.pumpAndSettle();
    expect(fakeRepository.checkInCallCount, 0);
  });
}
