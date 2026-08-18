import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:teacher_app/features/teacher_leave/domain/entities/teacher_leave_entity.dart';
import 'package:teacher_app/features/teacher_leave/domain/repositories/teacher_leave_repository.dart';
import 'package:teacher_app/features/teacher_leave/presentation/providers/teacher_leave_provider.dart';
import 'package:teacher_app/features/teacher_leave/presentation/pages/teacher_leave_screen.dart';
import 'package:teacher_app/features/teacher_leave/presentation/pages/teacher_leave_detail_screen.dart';
import 'package:teacher_app/features/teacher_leave/presentation/widgets/leave_request_card.dart';

// Fake Teacher Leave Repository
class FakeTeacherLeaveRepository implements TeacherLeaveRepository {
  bool shouldFailGetLeaves = false;
  bool shouldFailCreate = false;
  bool shouldFailGetLeave = false;
  bool shouldFailCancel = false;

  int getLeavesCallCount = 0;
  int createCallCount = 0;
  int getLeaveCallCount = 0;
  int cancelCallCount = 0;

  List<TeacherLeaveEntity> myLeaves = [];
  TeacherLeaveEntity? singleLeave;
  ApiFailure? customFailure;

  @override
  Future<ApiResult<List<TeacherLeaveEntity>>> getMyLeaves() async {
    getLeavesCallCount++;
    if (shouldFailGetLeaves) {
      return ApiResult.failure(customFailure ?? const ApiFailure(
        message: "Server Error",
        type: ApiFailureType.server,
        statusCode: 500,
      ));
    }
    return ApiResult.success(myLeaves);
  }

  @override
  Future<ApiResult<TeacherLeaveEntity>> createLeave({
    required String leaveType,
    required String startDate,
    required String endDate,
    required String reason,
    String? remarks,
  }) async {
    createCallCount++;
    if (shouldFailCreate) {
      return ApiResult.failure(customFailure ?? const ApiFailure(
        message: "Conflict Overlap",
        type: ApiFailureType.validation,
        statusCode: 409,
      ));
    }
    
    final created = TeacherLeaveEntity(
      id: "leave_123",
      tenantId: "tenant_123",
      schoolId: "school_123",
      teacherId: "teacher_123",
      leaveType: leaveType,
      startDate: startDate,
      endDate: endDate,
      reason: reason,
      remarks: remarks,
      status: "PENDING",
      requestedAt: DateTime.now().toIso8601String(),
    );
    myLeaves.add(created);
    return ApiResult.success(created);
  }

  @override
  Future<ApiResult<TeacherLeaveEntity>> getLeave(String leaveId) async {
    getLeaveCallCount++;
    if (shouldFailGetLeave) {
      return ApiResult.failure(customFailure ?? const ApiFailure(
        message: "Not Found",
        type: ApiFailureType.unknown,
        statusCode: 404,
      ));
    }
    if (singleLeave != null) {
      return ApiResult.success(singleLeave!);
    }
    final match = myLeaves.firstWhere((l) => l.id == leaveId, orElse: () => TeacherLeaveEntity(
      id: leaveId,
      tenantId: "tenant_123",
      schoolId: "school_123",
      teacherId: "teacher_123",
      leaveType: "CASUAL",
      startDate: "2026-08-19",
      endDate: "2026-08-20",
      reason: "Mock details",
      status: "PENDING",
      requestedAt: DateTime.now().toIso8601String(),
    ));
    return ApiResult.success(match);
  }

  @override
  Future<ApiResult<TeacherLeaveEntity>> cancelLeave({
    required String leaveId,
    required String cancellationReason,
  }) async {
    cancelCallCount++;
    if (shouldFailCancel) {
      return ApiResult.failure(customFailure ?? const ApiFailure(
        message: "Cancel Error",
        type: ApiFailureType.server,
        statusCode: 500,
      ));
    }

    final original = myLeaves.firstWhere((l) => l.id == leaveId, orElse: () => TeacherLeaveEntity(
      id: leaveId,
      tenantId: "tenant_123",
      schoolId: "school_123",
      teacherId: "teacher_123",
      leaveType: "CASUAL",
      startDate: "2026-08-19",
      endDate: "2026-08-20",
      reason: "Mock details",
      status: "PENDING",
      requestedAt: DateTime.now().toIso8601String(),
    ));

    final updated = TeacherLeaveEntity(
      id: original.id,
      tenantId: original.tenantId,
      schoolId: original.schoolId,
      teacherId: original.teacherId,
      leaveType: original.leaveType,
      startDate: original.startDate,
      endDate: original.endDate,
      reason: original.reason,
      remarks: original.remarks,
      status: "CANCELLED",
      requestedAt: original.requestedAt,
      cancelledAt: DateTime.now().toIso8601String(),
      cancellationReason: cancellationReason,
    );

    // Update inside myLeaves list
    final idx = myLeaves.indexWhere((l) => l.id == leaveId);
    if (idx != -1) {
      myLeaves[idx] = updated;
    }
    singleLeave = updated;
    return ApiResult.success(updated);
  }
}

void main() {
  late FakeTeacherLeaveRepository fakeRepository;

  setUp(() {
    fakeRepository = FakeTeacherLeaveRepository();
  });

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        teacherLeaveRepositoryProvider.overrideWithValue(fakeRepository),
      ],
    );
  }

  Widget createTestWidget(Widget child) {
    return ProviderScope(
      overrides: [
        teacherLeaveRepositoryProvider.overrideWithValue(fakeRepository),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  test('Initial states are correct', () {
    final container = createContainer();
    addTearDown(container.dispose);

    expect(container.read(teacherLeaveListProvider), const TeacherLeaveListInitial());
    expect(container.read(teacherLeaveFormNotifierProvider), const TeacherLeaveFormInitial());
    expect(container.read(teacherLeaveCancelNotifierProvider), const TeacherLeaveCancelInitial());
  });

  test('getMyLeaves success empty list sets state correctly', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    fakeRepository.myLeaves = [];
    final notifier = container.read(teacherLeaveListProvider.notifier);
    final future = notifier.fetchLeaves();

    expect(container.read(teacherLeaveListProvider), const TeacherLeaveListLoading());
    await future;

    final state = container.read(teacherLeaveListProvider);
    expect(state, isA<TeacherLeaveListLoaded>());
    expect((state as TeacherLeaveListLoaded).leaves, isEmpty);
  });

  test('createLeave success updates state and refreshes list', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    final formNotifier = container.read(teacherLeaveFormNotifierProvider.notifier);
    final future = formNotifier.submitLeave(
      leaveType: "CASUAL",
      startDate: "2026-08-19",
      endDate: "2026-08-20",
      reason: "Family event",
    );

    expect(container.read(teacherLeaveFormNotifierProvider), const TeacherLeaveFormLoading());
    await future;

    final formState = container.read(teacherLeaveFormNotifierProvider);
    expect(formState, isA<TeacherLeaveFormSuccess>());
    expect((formState as TeacherLeaveFormSuccess).leave.leaveType, "CASUAL");
    expect(fakeRepository.createCallCount, 1);
    expect(fakeRepository.getLeavesCallCount, 1); // Triggers silent reload
  });

  test('createLeave overlap error reports validation error', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    fakeRepository.shouldFailCreate = true;
    fakeRepository.customFailure = const ApiFailure(
      message: "Overlap detected",
      type: ApiFailureType.validation,
      statusCode: 409,
    );

    final formNotifier = container.read(teacherLeaveFormNotifierProvider.notifier);
    await formNotifier.submitLeave(
      leaveType: "CASUAL",
      startDate: "2026-08-19",
      endDate: "2026-08-20",
      reason: "Family event",
    );

    final formState = container.read(teacherLeaveFormNotifierProvider);
    expect(formState, isA<TeacherLeaveFormError>());
    expect((formState as TeacherLeaveFormError).message, "Overlap detected");
  });

  test('createLeave timeout reconciliation resolves correctly', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    fakeRepository.shouldFailCreate = true;
    fakeRepository.customFailure = const ApiFailure(
      message: "Gateway Timeout",
      type: ApiFailureType.network,
      statusCode: 504,
    );

    // Mock that the leave WAS actually created on the server
    final createdServerSide = TeacherLeaveEntity(
      id: "leave_123",
      tenantId: "tenant_123",
      schoolId: "school_123",
      teacherId: "teacher_123",
      leaveType: "SICK",
      startDate: "2026-08-22",
      endDate: "2026-08-23",
      reason: "High fever",
      status: "PENDING",
      requestedAt: DateTime.now().toIso8601String(),
    );
    fakeRepository.myLeaves = [createdServerSide];

    final formNotifier = container.read(teacherLeaveFormNotifierProvider.notifier);
    await formNotifier.submitLeave(
      leaveType: "SICK",
      startDate: "2026-08-22",
      endDate: "2026-08-23",
      reason: "High fever",
    );

    // Form state reconciled to success
    final formState = container.read(teacherLeaveFormNotifierProvider);
    expect(formState, isA<TeacherLeaveFormSuccess>());
    expect((formState as TeacherLeaveFormSuccess).leave.id, "leave_123");
    expect(fakeRepository.getLeavesCallCount, 2); // Checked server list & refreshed
  });

  test('cancelLeave success updates detail and list states', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    final initialLeave = TeacherLeaveEntity(
      id: "leave_123",
      tenantId: "tenant_123",
      schoolId: "school_123",
      teacherId: "teacher_123",
      leaveType: "CASUAL",
      startDate: "2026-08-19",
      endDate: "2026-08-20",
      reason: "Mock details",
      status: "PENDING",
      requestedAt: DateTime.now().toIso8601String(),
    );
    fakeRepository.myLeaves = [initialLeave];

    final cancelNotifier = container.read(teacherLeaveCancelNotifierProvider.notifier);
    await cancelNotifier.cancelLeave(
      leaveId: "leave_123",
      cancellationReason: "Change of plans",
    );

    expect(container.read(teacherLeaveCancelNotifierProvider), isA<TeacherLeaveCancelSuccess>());
    expect(fakeRepository.cancelCallCount, 1);
    expect(fakeRepository.getLeavesCallCount, 1); // Refreshed lists
  });

  test('cancelLeave timeout reconciliation resolves status', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    // Cancel fails due to network
    fakeRepository.shouldFailCancel = true;
    fakeRepository.customFailure = const ApiFailure(
      message: "Timeout",
      type: ApiFailureType.network,
      statusCode: 408,
    );

    // Server-side status is already CANCELLED
    final cancelledServerSide = TeacherLeaveEntity(
      id: "leave_123",
      tenantId: "tenant_123",
      schoolId: "school_123",
      teacherId: "teacher_123",
      leaveType: "CASUAL",
      startDate: "2026-08-19",
      endDate: "2026-08-20",
      reason: "Mock details",
      status: "CANCELLED",
      requestedAt: DateTime.now().toIso8601String(),
      cancellationReason: "Change of plans",
    );
    fakeRepository.singleLeave = cancelledServerSide;

    final cancelNotifier = container.read(teacherLeaveCancelNotifierProvider.notifier);
    await cancelNotifier.cancelLeave(
      leaveId: "leave_123",
      cancellationReason: "Change of plans",
    );

    expect(container.read(teacherLeaveCancelNotifierProvider), isA<TeacherLeaveCancelSuccess>());
    expect(fakeRepository.getLeaveCallCount, 1); // Query individual details
  });

  testWidgets('List screen renders empty list correctly', (tester) async {
    fakeRepository.myLeaves = [];
    await tester.pumpWidget(createTestWidget(const TeacherLeaveScreen()));
    await tester.pumpAndSettle();

    expect(find.text("No leave requests found."), findsWidgets);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('List screen renders leave cards correctly', (tester) async {
    fakeRepository.myLeaves = [
      TeacherLeaveEntity(
        id: "leave_123",
        tenantId: "tenant_123",
        schoolId: "school_123",
        teacherId: "teacher_123",
        leaveType: "CASUAL",
        startDate: "2026-08-19",
        endDate: "2026-08-21",
        reason: "Trip to home",
        status: "PENDING",
        requestedAt: DateTime.now().toIso8601String(),
      )
    ];

    await tester.pumpWidget(createTestWidget(const TeacherLeaveScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(LeaveRequestCard), findsOneWidget);
    expect(find.text("Casual Leave"), findsOneWidget);
    expect(find.text("PENDING"), findsOneWidget);
    expect(find.text("Trip to home"), findsOneWidget);
  });

  testWidgets('Detail screen renders cancel action when PENDING', (tester) async {
    final pendingLeave = TeacherLeaveEntity(
      id: "leave_123",
      tenantId: "tenant_123",
      schoolId: "school_123",
      teacherId: "teacher_123",
      leaveType: "CASUAL",
      startDate: "2026-08-19",
      endDate: "2026-08-21",
      reason: "Trip to home",
      status: "PENDING",
      requestedAt: DateTime.now().toIso8601String(),
    );
    fakeRepository.singleLeave = pendingLeave;

    await tester.pumpWidget(createTestWidget(const TeacherLeaveDetailScreen(leaveId: "leave_123")));
    await tester.pumpAndSettle();

    expect(find.text("Cancel Request"), findsOneWidget);
  });

  testWidgets('Detail screen hides cancel action when APPROVED', (tester) async {
    final approvedLeave = TeacherLeaveEntity(
      id: "leave_123",
      tenantId: "tenant_123",
      schoolId: "school_123",
      teacherId: "teacher_123",
      leaveType: "CASUAL",
      startDate: "2026-08-19",
      endDate: "2026-08-21",
      reason: "Trip to home",
      status: "APPROVED",
      requestedAt: DateTime.now().toIso8601String(),
    );
    fakeRepository.singleLeave = approvedLeave;

    await tester.pumpWidget(createTestWidget(const TeacherLeaveDetailScreen(leaveId: "leave_123")));
    await tester.pumpAndSettle();

    expect(find.text("Cancel Request"), findsNothing);
  });
}
