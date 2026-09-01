import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';

// Import local domain objects, providers and pages
import 'package:principal_app/features/dashboard/presentation/providers/active_school_provider.dart';
import 'package:principal_app/features/leave_requests/presentation/providers/leave_requests_provider.dart';
import 'package:principal_app/features/leave_requests/presentation/pages/teacher_leave_detail_screen.dart';

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

class FakeLeaveApiClient extends BaseApiClient {
  final bool simulate403;
  final bool simulate404;
  final bool simulateEmpty;
  final bool simulateFailure;
  final bool simulateTimeout;

  int postCallCount = 0;
  String? lastDecision;
  String? lastRemarks;

  FakeLeaveApiClient({
    this.simulate403 = false,
    this.simulate404 = false,
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

    if (simulate404) {
      return ApiResult.failure(const ApiFailure(
        message: 'Leave request could not be found.',
        type: ApiFailureType.unknown,
        statusCode: 404,
      ));
    }

    if (path.contains('/history')) {
      if (simulateEmpty) {
        return ApiResult.success(mapper({'data': []}));
      }
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'history_1',
            'tenant_id': 'tenant_abc',
            'school_id': 'school_123',
            'teacher_id': 'teacher_xyz',
            'leave_type': 'CASUAL',
            'start_date': '2026-08-10',
            'end_date': '2026-08-12',
            'reason': 'Family emergency',
            'status': 'APPROVED',
            'requested_at': '2026-08-09T10:00:00Z',
            'reviewed_at': '2026-08-09T12:00:00Z',
            'reviewer_remarks': 'Approved',
            'teacher': {
              'first_name': 'Alice',
              'last_name': 'Smith',
              'designation': 'Math Teacher',
              'department': 'Science'
            }
          }
        ]
      }));
    }

    if (path.startsWith('/teacher-leaves/')) {
      // Single request detail lookup
      final id = path.split('/').last;
      return ApiResult.success(mapper({
        'data': {
          'id': id,
          'tenant_id': 'tenant_abc',
          'school_id': 'school_123',
          'teacher_id': 'teacher_xyz',
          'leave_type': 'SICK',
          'start_date': '2026-08-15',
          'end_date': '2026-08-16',
          'reason': 'Fever',
          'status': id == 'leave_approved'
              ? 'APPROVED'
              : id == 'leave_rejected'
                  ? 'REJECTED'
                  : id == 'leave_cancelled'
                      ? 'CANCELLED'
                      : 'PENDING',
          'requested_at': '2026-08-14T09:00:00Z',
          'reviewer_remarks': id == 'leave_rejected' ? 'Too many leaves' : null,
          'teacher': {
            'first_name': 'Alice',
            'last_name': 'Smith',
            'designation': 'Math Teacher',
            'department': 'Science'
          }
        }
      }));
    }

    if (path.contains('/teacher-leaves')) {
      if (simulateEmpty) {
        return ApiResult.success(mapper({'data': []}));
      }

      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'leave_pending_1',
            'tenant_id': 'tenant_abc',
            'school_id': 'school_123',
            'teacher_id': 'teacher_xyz',
            'leave_type': 'SICK',
            'start_date': '2026-08-15',
            'end_date': '2026-08-16',
            'reason': 'Fever',
            'status': 'PENDING',
            'requested_at': '2026-08-14T09:00:00Z',
            'teacher': {
              'first_name': 'Alice',
              'last_name': 'Smith',
              'designation': 'Math Teacher',
              'department': 'Science'
            }
          },
          {
            'id': 'leave_approved_1',
            'tenant_id': 'tenant_abc',
            'school_id': 'school_123',
            'teacher_id': 'teacher_abc',
            'leave_type': 'CASUAL',
            'start_date': '2026-08-18',
            'end_date': '2026-08-20',
            'reason': 'Personal work',
            'status': 'APPROVED',
            'requested_at': '2026-08-17T09:00:00Z',
            'teacher': {
              'first_name': 'Bob',
              'last_name': 'Jones',
              'designation': 'Science Teacher',
              'department': 'Science'
            }
          }
        ]
      }));
    }

    return ApiResult.failure(const ApiFailure(
      message: 'Not Found',
      type: ApiFailureType.unknown,
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
    postCallCount++;
    if (simulate403) {
      return ApiResult.failure(const ApiFailure(
        message: 'Permission denied',
        type: ApiFailureType.unauthorized,
        statusCode: 403,
      ));
    }

    if (simulateTimeout) {
      return ApiResult.failure(const ApiFailure(
        message: 'Connection Timeout',
        type: ApiFailureType.unknown,
        statusCode: 504,
      ));
    }

    if (path.contains('/review')) {
      final body = data as Map<String, dynamic>;
      lastDecision = body['decision'] as String?;
      lastRemarks = body['reviewer_remarks'] as String?;

      return ApiResult.success(mapper({
        'data': {
          'id': 'leave_pending_1',
          'tenant_id': 'tenant_abc',
          'school_id': 'school_123',
          'teacher_id': 'teacher_xyz',
          'leave_type': 'SICK',
          'start_date': '2026-08-15',
          'end_date': '2026-08-16',
          'reason': 'Fever',
          'status': lastDecision == 'APPROVE' ? 'APPROVED' : 'REJECTED',
          'requested_at': '2026-08-14T09:00:00Z',
          'reviewer_remarks': lastRemarks,
          'teacher': {
            'first_name': 'Alice',
            'last_name': 'Smith',
            'designation': 'Math Teacher',
            'department': 'Science'
          }
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
  group('Teacher Leave Principal UI - Unit & Widget Tests', () {

    test('1. List loading state', () {
      final client = FakeLeaveApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          activeSchoolIdProvider.overrideWith((ref) => 'school_123'),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(leaveRequestsStateProvider);
      expect(state.isLoading, isTrue);
    });

    test('2. Successful leave list loading', () async {
      final client = FakeLeaveApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          activeSchoolIdProvider.overrideWith((ref) => 'school_123'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(leaveRequestsStateProvider.notifier).fetchRequests();

      final state = container.read(leaveRequestsStateProvider);
      expect(state.isLoading, isFalse);
      expect(state.requests.length, equals(2));
      expect(state.requests[0].id, equals('leave_pending_1'));
      expect(state.requests[1].status, equals('APPROVED'));
    });

    test('3. Empty state handling', () async {
      final client = FakeLeaveApiClient(simulateEmpty: true);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          activeSchoolIdProvider.overrideWith((ref) => 'school_123'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(leaveRequestsStateProvider.notifier).fetchRequests();

      final state = container.read(leaveRequestsStateProvider);
      expect(state.requests, isEmpty);
    });

    test('4. API failure mapping', () async {
      final client = FakeLeaveApiClient(simulateFailure: true);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          activeSchoolIdProvider.overrideWith((ref) => 'school_123'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(leaveRequestsStateProvider.notifier).fetchRequests();

      final state = container.read(leaveRequestsStateProvider);
      expect(state.errorMessage, contains('Internal Server Error'));
    });

    test('5, 6, 7 & 8. Status, leave-type, and date filtering', () async {
      final client = FakeLeaveApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          activeSchoolIdProvider.overrideWith((ref) => 'school_123'),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(leaveRequestsStateProvider.notifier);
      await notifier.setFilters(
        status: 'PENDING',
        leaveType: 'SICK',
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 30),
      );

      final state = container.read(leaveRequestsStateProvider);
      expect(state.status, equals('PENDING'));
      expect(state.leaveType, equals('SICK'));
      expect(state.startDate, equals(DateTime(2026, 8, 1)));
    });

    test('9. Detail loading states and success mapping', () async {
      final client = FakeLeaveApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);

      final detailStateProvider = teacherLeaveDetailProvider('leave_pending_1');
      expect(container.read(detailStateProvider).isLoading, isTrue);

      await container.read(detailStateProvider.notifier).fetchDetail();

      final state = container.read(detailStateProvider);
      expect(state.isLoading, isFalse);
      expect(state.request, isNotNull);
      expect(state.request!.reason, equals('Fever'));
      expect(state.request!.teacherName, equals('Alice Smith'));
    });

    testWidgets('10 & 11. Detail UI rendering - Pending shows buttons, Reviewed hides them', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = FakeLeaveApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);

      // Render PENDING request
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: TeacherLeaveDetailScreen(leaveId: 'leave_pending_1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Approve Leave'), findsOneWidget);
      expect(find.text('Reject Leave'), findsOneWidget);

      // Render APPROVED request
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: TeacherLeaveDetailScreen(leaveId: 'leave_approved'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Approve Leave'), findsNothing);
      expect(find.text('Reject Leave'), findsNothing);
    });

    test('12. Successful approval dispatch', () async {
      final client = FakeLeaveApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          activeSchoolIdProvider.overrideWith((ref) => 'school_123'),
        ],
      );
      addTearDown(container.dispose);

      final detailNotifier = container.read(teacherLeaveDetailProvider('leave_pending_1').notifier);
      final success = await detailNotifier.reviewRequest('APPROVE', 'Looks good');

      expect(success, isTrue);
      expect(client.lastDecision, equals('APPROVE'));
      expect(client.lastRemarks, equals('Looks good'));
    });

    testWidgets('13. Rejection reasons validation', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = FakeLeaveApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: TeacherLeaveDetailScreen(leaveId: 'leave_pending_1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Reject Leave button to open confirmation dialog
      await tester.tap(find.text('Reject Leave'));
      await tester.pumpAndSettle();

      // Tap Reject button without filling a reason
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reject'));
      await tester.pump();

      // Toast error should be visible
      expect(find.text('Reason for rejection is required.'), findsOneWidget);
    });

    test('14. 403 authorization mapping', () async {
      final client = FakeLeaveApiClient(simulate403: true);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);

      final detailNotifier = container.read(teacherLeaveDetailProvider('leave_pending_1').notifier);
      final success = await detailNotifier.reviewRequest('APPROVE', null);

      expect(success, isFalse);
      expect(
        container.read(teacherLeaveDetailProvider('leave_pending_1')).errorMessage,
        contains('not authorized'),
      );
    });

    test('15. Timeout reconciliation matches state transition', () async {
      final client = FakeLeaveApiClient(simulateTimeout: true);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);

      final detailNotifier = container.read(teacherLeaveDetailProvider('leave_approved').notifier);
      
      // Simulate that the request was processed on the server before timeout, so state is already APPROVED
      final success = await detailNotifier.reviewRequest('APPROVE', null);
      expect(success, isTrue);
    });

    test('16. Active school switching resets data', () async {
      final client = FakeLeaveApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          activeSchoolIdProvider.overrideWith((ref) => 'school_123'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(leaveRequestsStateProvider.notifier).fetchRequests();
      expect(container.read(leaveRequestsStateProvider).requests.length, equals(2));

      // Switch school
      container.read(activeSchoolIdProvider.notifier).state = 'school_456';
      
      // Verification
      expect(container.read(leaveRequestsStateProvider).requests, isEmpty);
    });
  });
}
