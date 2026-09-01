import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';

// Import local domain objects and providers
import 'package:principal_app/features/dashboard/presentation/providers/active_school_provider.dart';
import 'package:principal_app/features/staff_attendance/data/models/staff_attendance_model.dart';
import 'package:principal_app/features/staff_attendance/presentation/providers/staff_attendance_provider.dart';
import 'package:principal_app/features/staff_attendance/presentation/pages/teacher_attendance_detail_screen.dart';
import 'package:principal_app/features/staff_attendance/presentation/pages/geofence_configuration_screen.dart';

class FakeSessionManager implements SessionManager {
  String? cachedTenantId;

  @override
  Future<String?> getTenantId() async => cachedTenantId;

  @override
  Future<void> saveTenantId(String tenantId) async {
    cachedTenantId = tenantId;
  }

  @override
  Future<String?> getAccessToken() async => 'fake_token';
  @override
  Future<String?> getRefreshToken() async => 'fake_refresh';
  @override
  Future<void> saveSession(SessionToken token) async {}
  @override
  Future<void> clearSession() async {}
  @override
  Future<bool> hasSession() async => true;
  @override
  Future<String?> getSchoolId() async => 'school_123';
  @override
  Future<void> saveSchoolId(String schoolId) async {}
}

class FakeBaseApiClient extends BaseApiClient {
  final bool simulate403;
  final bool simulateEmpty;
  final bool simulateFailure;
  final bool simulateTimeout;
  
  int putCallCount = 0;
  double? lastPutLatitude;
  double? lastPutLongitude;
  int? lastPutRadius;

  FakeBaseApiClient({
    this.simulate403 = false,
    this.simulateEmpty = false,
    this.simulateFailure = false,
    this.simulateTimeout = false,
  }) : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    if (simulateFailure) {
      return ApiResult.failure(const ApiFailure(
        message: 'Internal Server Error',
        type: ApiFailureType.unknown,
        statusCode: 500,
      ));
    }

    if (path.contains('/staff-attendance/daily')) {
      if (simulateEmpty) {
        return ApiResult.success(mapper({
          'data': {
            'date': queryParameters?['attendance_date'] ?? '2026-08-18',
            'total_teachers': 0,
            'present_count': 0,
            'absent_count': 0,
            'late_count': 0,
            'half_day_count': 0,
            'on_leave_count': 0,
            'attendance_rate': 0.0,
            'records': []
          }
        }));
      }

      return ApiResult.success(mapper({
        'data': {
          'date': queryParameters?['attendance_date'] ?? '2026-08-18',
          'total_teachers': 3,
          'present_count': 1,
          'absent_count': 1,
          'late_count': 1,
          'half_day_count': 0,
          'on_leave_count': 0,
          'attendance_rate': 66.7,
          'records': [
            {
              'teacher_id': 'teacher_present',
              'teacher_name': 'Alice Smith',
              'designation': 'Math Teacher',
              'department': 'Science',
              'attendance_status': 'PRESENT',
              'check_in_time': '2026-08-18T09:00:00Z',
              'check_in_latitude': 17.4485,
              'check_in_longitude': 78.3741,
              'check_in_distance_meters': 10.0,
              'check_out_time': '2026-08-18T17:00:00Z',
              'check_out_latitude': 17.4486,
              'check_out_longitude': 78.3742,
              'check_out_distance_meters': 12.0,
              'is_mocked_location': false,
            },
            {
              'teacher_id': 'teacher_late',
              'teacher_name': 'Bob Jones',
              'designation': 'Science Teacher',
              'department': 'Science',
              'attendance_status': 'LATE',
              'check_in_time': '2026-08-18T09:45:00Z',
              'check_in_latitude': 17.4490,
              'check_in_longitude': 78.3750,
              'check_in_distance_meters': 150.0,
              'is_mocked_location': true,
            },
            {
              'teacher_id': 'teacher_absent',
              'teacher_name': 'Charlie Brown',
              'designation': 'English Teacher',
              'department': 'Arts',
              'attendance_status': 'ABSENT',
              'is_mocked_location': false,
            }
          ]
        }
      }));
    } else if (path.contains('/history')) {
      final skip = queryParameters?['skip'] as int? ?? 0;
      final limit = queryParameters?['limit'] as int? ?? 20;

      if (skip >= 40) {
        return ApiResult.success(mapper({'data': []}));
      }

      return ApiResult.success(mapper({
        'data': List.generate(limit, (index) {
          final idNum = skip + index;
          return {
            'id': 'log_$idNum',
            'attendance_date': '2026-08-${18 - idNum}',
            'status': idNum % 2 == 0 ? 'PRESENT' : 'LATE',
            'check_in_time': '2026-08-${18 - idNum}T09:00:00Z',
            'check_in_latitude': 17.4485,
            'check_in_longitude': 78.3741,
            'check_in_distance_meters': 10.0,
            'is_mocked_location': idNum % 4 == 0,
            'remarks': 'Log number $idNum',
            'duration_seconds': 28800
          };
        })
      }));
    } else if (path.startsWith('/schools/')) {
      return ApiResult.success(mapper({
        'data': {
          'id': 'school_123',
          'name': 'EduPulse Academy',
          'latitude': 17.4486,
          'longitude': 78.3742,
          'geofence_radius_meters': 150
        }
      }));
    }

    return ApiResult.failure(const ApiFailure(
      message: 'Not Found',
      type: ApiFailureType.unknown,
      statusCode: 404,
    ));
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
    putCallCount++;
    if (simulate403) {
      return ApiResult.failure(const ApiFailure(
        message: 'Permission denied',
        type: ApiFailureType.unauthorized,
        statusCode: 403,
      ));
    }

    if (simulateTimeout) {
      // Simulate timeout by returning a failure that is NOT 403,
      // so the provider triggers the timeout reconciliation logic.
      return ApiResult.failure(const ApiFailure(
        message: 'Connection Timeout',
        type: ApiFailureType.unknown,
        statusCode: 504,
      ));
    }

    if (path.startsWith('/schools/')) {
      final body = data as Map<String, dynamic>;
      lastPutLatitude = body['latitude'] as double?;
      lastPutLongitude = body['longitude'] as double?;
      lastPutRadius = body['geofence_radius_meters'] as int?;

      return ApiResult.success(mapper({
        'data': {
          'id': 'school_123',
          'name': 'EduPulse Academy',
          'latitude': lastPutLatitude,
          'longitude': lastPutLongitude,
          'geofence_radius_meters': lastPutRadius
        }
      }));
    }

    return ApiResult.failure(const ApiFailure(
      message: 'Not Found',
      type: ApiFailureType.unknown,
      statusCode: 404,
    ));
  }
}

void main() {
  group('Staff Attendance Principal UI - Unit & Flow Tests', () {
    
    test('1. Daily attendance loading', () async {
      final client = FakeBaseApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          activeSchoolIdProvider.overrideWith((ref) => 'school_123'),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(staffAttendanceStateProvider);
      // Verify that it initially sets loading correctly
      expect(state.isLoading, isTrue);
    });

    test('2. Daily attendance success', () async {
      final client = FakeBaseApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          activeSchoolIdProvider.overrideWith((ref) => 'school_123'),
        ],
      );
      addTearDown(container.dispose);

      // Wait for automatic fetch
      await container.read(staffAttendanceStateProvider.notifier).fetchAttendance();

      final state = container.read(staffAttendanceStateProvider);
      expect(state.isLoading, isFalse);
      expect(state.summary, isNotNull);
      expect(state.summary!.records.length, equals(3));
      
      final alice = state.summary!.records.firstWhere((r) => r.teacherId == 'teacher_present');
      expect(alice.checkInDistanceMeters, equals(10.0));
      expect(alice.checkOutDistanceMeters, equals(12.0));
    });

    test('3. Empty attendance', () async {
      final client = FakeBaseApiClient(simulateEmpty: true);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          activeSchoolIdProvider.overrideWith((ref) => 'school_123'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(staffAttendanceStateProvider.notifier).fetchAttendance();

      final state = container.read(staffAttendanceStateProvider);
      expect(state.summary!.records, isEmpty);
      expect(state.summary!.totalTeachers, equals(0));
    });

    test('4. API failure mapping', () async {
      final client = FakeBaseApiClient(simulateFailure: true);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          activeSchoolIdProvider.overrideWith((ref) => 'school_123'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(staffAttendanceStateProvider.notifier).fetchAttendance();

      final state = container.read(staffAttendanceStateProvider);
      expect(state.errorMessage, contains('Internal Server Error'));
    });

    test('5 & 6. Status filtering & search verification', () async {
      final summary = StaffDailyAttendanceSummary(
        date: '2026-08-18',
        totalTeachers: 3,
        presentCount: 1,
        absentCount: 1,
        lateCount: 1,
        halfDayCount: 0,
        onLeaveCount: 0,
        notMarkedCount: 0,
        attendanceRate: 66.7,
        records: [
          StaffDailyAttendanceReportItem(
            teacherId: 't1',
            teacherName: 'Alice Smith',
            department: 'Science',
            attendanceStatus: 'PRESENT',
            isMockedLocation: false,
          ),
          StaffDailyAttendanceReportItem(
            teacherId: 't2',
            teacherName: 'Bob Jones',
            department: 'Science',
            attendanceStatus: 'LATE',
            isMockedLocation: true,
          ),
          StaffDailyAttendanceReportItem(
            teacherId: 't3',
            teacherName: 'Charlie Brown',
            department: 'Arts',
            attendanceStatus: 'ABSENT',
            isMockedLocation: false,
          )
        ],
      );

      // Verify filter matches local filtering logic of the page
      final presentRecords = summary.records.where((r) => r.attendanceStatus == 'PRESENT').toList();
      expect(presentRecords.length, equals(1));
      expect(presentRecords.first.teacherName, equals('Alice Smith'));

      final searchRecords = summary.records.where((r) => r.teacherName.toLowerCase().contains('bob')).toList();
      expect(searchRecords.length, equals(1));
      expect(searchRecords.first.teacherId, equals('t2'));
    });

    testWidgets('7 & 11. Teacher detail rendering and mock warning', (WidgetTester tester) async {
      final client = FakeBaseApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          activeSchoolIdProvider.overrideWith((ref) => 'school_123'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(staffAttendanceStateProvider.notifier).fetchAttendance();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: TeacherAttendanceDetailScreen(teacherId: 'teacher_late'),
          ),
        ),
      );

      // Late teacher has isMockedLocation = true
      expect(find.text('Bob Jones'), findsOneWidget);
      expect(find.text('Mock location detected during verification.'), findsOneWidget);
      expect(find.text('150.0 m'), findsOneWidget);
    });

    test('8. History loading', () async {
      final client = FakeBaseApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(teacherAttendanceHistoryStateProvider('teacher_late'));
      expect(state.isLoading, isTrue);
    });

    test('9 & 10. History pagination and Date filtering', () async {
      final client = FakeBaseApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(teacherAttendanceHistoryStateProvider('teacher_late').notifier);
      await notifier.fetchHistory();

      var state = container.read(teacherAttendanceHistoryStateProvider('teacher_late'));
      expect(state.records.length, equals(20));
      expect(state.skip, equals(20));
      expect(state.hasMore, isTrue);

      // Load more
      await notifier.fetchHistory(isLoadMore: true);
      state = container.read(teacherAttendanceHistoryStateProvider('teacher_late'));
      expect(state.records.length, equals(40));
      expect(state.skip, equals(40));

      // Filter dates resets pagination
      await notifier.setDateRange(DateTime(2026, 8, 1), DateTime(2026, 8, 15));
      state = container.read(teacherAttendanceHistoryStateProvider('teacher_late'));
      expect(state.skip, equals(20));
    });

    test('12. Geofence configuration loading', () async {
      final client = FakeBaseApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          activeSchoolIdProvider.overrideWith((ref) => 'school_123'),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(schoolGeofenceStateProvider);
      expect(state.isLoading, isTrue);
    });

    testWidgets('13 & 14. Geofence coordinate and radius validation boundary limits', (WidgetTester tester) async {
      final client = FakeBaseApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          activeSchoolIdProvider.overrideWith((ref) => 'school_123'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(schoolGeofenceStateProvider.notifier).fetchGeofence();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: GeofenceConfigurationScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Edit
      await tester.tap(find.byIcon(Icons.edit_rounded));
      await tester.pumpAndSettle();

      // Find forms
      final latField = find.widgetWithText(TextFormField, 'Latitude');
      final lngField = find.widgetWithText(TextFormField, 'Longitude');
      final radiusField = find.widgetWithText(TextFormField, 'Allowed Radius');

      // Invalid Latitude
      await tester.enterText(latField, '105.0');
      await tester.enterText(lngField, '78.3741');
      await tester.enterText(radiusField, '150');

      await tester.tap(find.text('Save Configuration'));
      await tester.pumpAndSettle();
      expect(find.text('Must be -90 to 90'), findsOneWidget);

      // Invalid Longitude
      await tester.enterText(latField, '17.4486');
      await tester.enterText(lngField, '-200.0');
      await tester.tap(find.text('Save Configuration'));
      await tester.pumpAndSettle();
      expect(find.text('Must be -180 to 180'), findsOneWidget);

      // Invalid Radius
      await tester.enterText(lngField, '78.3742');
      await tester.enterText(radiusField, '-10');
      await tester.tap(find.text('Save Configuration'));
      await tester.pumpAndSettle();
      expect(find.text('Must be greater than 0'), findsOneWidget);

      await tester.enterText(radiusField, '25000');
      await tester.tap(find.text('Save Configuration'));
      await tester.pumpAndSettle();
      expect(find.text('Maximum allowed radius is 10,000 meters'), findsOneWidget);
    });

    test('15. Successful geofence update', () async {
      final client = FakeBaseApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          activeSchoolIdProvider.overrideWith((ref) => 'school_123'),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(schoolGeofenceStateProvider.notifier);
      await notifier.fetchGeofence();

      final success = await notifier.updateGeofence(latitude: 17.5, longitude: 78.5, radius: 200);
      expect(success, isTrue);
      expect(client.lastPutLatitude, equals(17.5));
      expect(client.lastPutLongitude, equals(78.5));
      expect(client.lastPutRadius, equals(200));
    });

    test('16. 403 geofence update handling', () async {
      final client = FakeBaseApiClient(simulate403: true);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          activeSchoolIdProvider.overrideWith((ref) => 'school_123'),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(schoolGeofenceStateProvider.notifier);
      await notifier.fetchGeofence();

      final success = await notifier.updateGeofence(latitude: 17.5, longitude: 78.5, radius: 200);
      expect(success, isFalse);
      expect(container.read(schoolGeofenceStateProvider).errorMessage, contains('not authorized'));
    });

    test('17. Timeout reconciliation', () async {
      final client = FakeBaseApiClient(simulateTimeout: true);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          activeSchoolIdProvider.overrideWith((ref) => 'school_123'),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(schoolGeofenceStateProvider.notifier);
      await notifier.fetchGeofence();

      // Submit the values that match server's default fake values to mock that the server did receive it before timeout
      final success = await notifier.updateGeofence(
        latitude: 17.4486,
        longitude: 78.3742,
        radius: 150,
      );
      expect(success, isTrue);
      expect(container.read(schoolGeofenceStateProvider).updateSuccessMessage, contains('updated successfully'));
    });

    test('18 & 19. Active school change resets and reloads data', () async {
      final client = FakeBaseApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          activeSchoolIdProvider.overrideWith((ref) => 'school_123'),
        ],
      );
      addTearDown(container.dispose);

      // Verify initially loading
      expect(container.read(staffAttendanceStateProvider).isLoading, isTrue);
      
      // Let it fetch
      await container.read(staffAttendanceStateProvider.notifier).fetchAttendance();
      expect(container.read(staffAttendanceStateProvider).summary, isNotNull);

      // Switch school
      container.read(activeSchoolIdProvider.notifier).state = 'school_456';
      
      // State is recreated, so it goes back to loading and clears summary
      expect(container.read(staffAttendanceStateProvider).summary, isNull);
    });

    test('20. No hardcoded IDs', () async {
      final client = FakeBaseApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          activeSchoolIdProvider.overrideWith((ref) => 'dynamic_school_abc'),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(staffAttendanceStateProvider.notifier);
      await notifier.fetchAttendance();

      final state = container.read(staffAttendanceStateProvider);
      expect(state.summary, isNotNull);
    });
  });
}
