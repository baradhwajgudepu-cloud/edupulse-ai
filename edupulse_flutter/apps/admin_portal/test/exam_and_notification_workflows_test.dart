import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/planner/presentation/providers/planner_providers.dart';
import 'package:admin_portal/features/planner/data/models/planner_models.dart';

class MockWorkflowApiClient extends BaseApiClient {
  final List<Map<String, dynamic>> calls = [];

  MockWorkflowApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    calls.add({'method': 'GET', 'path': path, 'query': queryParameters});
    if (path == '/examinations') {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'exam-uuid-1',
            'exam_name': 'Unit Test 1',
            'exam_type': 'UNIT_TEST',
            'start_date': '2026-10-01',
            'end_date': '2026-10-10',
            'status': 'DRAFT',
            'schedules': [],
          }
        ]
      }));
    }
    if (path == '/notifications') {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'notif-uuid-1',
            'title': 'School Assembly',
            'message': 'Annual assembly tomorrow morning',
            'target_role': 'PARENT',
            'priority': 'NORMAL',
            'status': 'UNREAD',
            'scheduled_at': '2026-10-02T09:00:00Z',
            'published_at': null,
            'created_at': '2026-10-01T08:00:00Z',
          }
        ]
      }));
    }
    return ApiResult.success(mapper({'data': []}));
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
    calls.add({'method': 'POST', 'path': path, 'data': data, 'query': queryParameters});

    if (path == '/examinations/wizard') {
      final reqData = data as Map<String, dynamic>;
      return ApiResult.success(mapper({
        'data': {
          'id': 'exam-new-uuid',
          'exam_name': reqData['exam_name'],
          'exam_type': reqData['exam_type'],
          'start_date': reqData['start_date'],
          'end_date': reqData['end_date'],
          'status': 'DRAFT',
          'schedules': [],
        }
      }));
    }

    if (path.contains('/examinations/') && path.endsWith('/publish')) {
      return ApiResult.success(mapper({
        'data': {
          'id': 'exam-uuid-1',
          'exam_name': 'Unit Test 1',
          'exam_type': 'UNIT_TEST',
          'start_date': '2026-10-01',
          'end_date': '2026-10-10',
          'status': 'PUBLISHED',
          'schedules': [],
        }
      }));
    }

    if (path == '/notifications') {
      final reqData = data as Map<String, dynamic>;
      return ApiResult.success(mapper({
        'data': {
          'id': 'notif-new-uuid',
          'title': reqData['title'],
          'message': reqData['message'],
          'target_role': reqData['target_role'],
          'priority': reqData['priority'],
          'status': 'UNREAD',
          'scheduled_at': reqData['scheduled_at'],
          'published_at': reqData['scheduled_at'] != null ? null : '2026-10-01T10:00:00Z',
          'created_at': '2026-10-01T10:00:00Z',
        }
      }));
    }

    if (path.contains('/notifications/') && path.endsWith('/publish')) {
      return ApiResult.success(mapper({
        'data': {
          'id': 'notif-uuid-1',
          'title': 'School Assembly',
          'message': 'Annual assembly tomorrow morning',
          'target_role': 'PARENT',
          'priority': 'NORMAL',
          'status': 'UNREAD',
          'scheduled_at': '2026-10-02T09:00:00Z',
          'published_at': '2026-10-01T10:30:00Z',
          'created_at': '2026-10-01T08:00:00Z',
        }
      }));
    }

    return ApiResult.success(mapper({'data': {}}));
  }
}

void main() {
  group('Examination Workflows', () {
    test('createExaminationWizard dispatches valid payload and updates exam state', () async {
      final mockApi = MockWorkflowApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          selectedSchoolIdProvider.overrideWith((ref) => 'test-school-123'),
          selectedAcademicYearIdProvider.overrideWith((ref) => 'ay-uuid-456'),
        ],
      );

      final notifier = container.read(examsListProvider.notifier);
      final ok = await notifier.createExaminationWizard(
        examName: 'Mid-Term Exam',
        examType: 'HALF_YEARLY',
        startDate: '2026-10-15',
        endDate: '2026-10-25',
        schedules: [],
      );

      expect(ok, isTrue);

      // Verify POST call was executed
      final postCalls = mockApi.calls.where((c) => c['path'] == '/examinations/wizard').toList();
      expect(postCalls.length, 1);
      final payload = postCalls.first['data'] as Map<String, dynamic>;
      expect(payload['school_id'], 'test-school-123');
      expect(payload['academic_year_id'], 'ay-uuid-456');
      expect(payload['exam_name'], 'Mid-Term Exam');
      expect(payload['exam_type'], 'HALF_YEARLY');
      expect(payload['start_date'], '2026-10-15');
      expect(payload['end_date'], '2026-10-25');

      // Verify exam added to state
      final state = container.read(examsListProvider);
      expect(state.examinations.any((e) => e.examName == 'Mid-Term Exam'), isTrue);
    });

    test('publishExam transitions examination from DRAFT to PUBLISHED', () async {
      final mockApi = MockWorkflowApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          selectedSchoolIdProvider.overrideWith((ref) => 'test-school-123'),
        ],
      );

      final notifier = container.read(examsListProvider.notifier);
      await notifier.fetchExams();
      expect(container.read(examsListProvider).examinations.first.status, 'DRAFT');

      final ok = await notifier.publishExam('exam-uuid-1');
      expect(ok, isTrue);

      final publishCalls = mockApi.calls.where((c) => c['path'] == '/examinations/exam-uuid-1/publish').toList();
      expect(publishCalls.length, 1);
      expect(publishCalls.first['query']?['school_id'], 'test-school-123');

      // State is updated with PUBLISHED
      expect(container.read(examsListProvider).examinations.first.status, 'PUBLISHED');
    });
  });

  group('Notification Workflows', () {
    test('PlannerNotification.fromJson correctly parses SCHEDULED and PUBLISHED lifecycle', () {
      final scheduledJson = {
        'id': 'n1',
        'title': 'Parent Meeting',
        'message': 'Meeting at 3 PM',
        'target_role': 'PARENT',
        'priority': 'HIGH',
        'status': 'UNREAD',
        'scheduled_at': '2026-10-05T15:00:00Z',
        'published_at': null,
        'created_at': '2026-10-01T12:00:00Z',
      };
      final scheduled = PlannerNotification.fromJson(scheduledJson);
      expect(scheduled.status, 'SCHEDULED');
      expect(scheduled.targetAudience, 'PARENT');
      expect(scheduled.priority, 'HIGH');

      final publishedJson = {
        'id': 'n2',
        'title': 'Emergency Alert',
        'message': 'Weather alert',
        'target_role': 'STAFF',
        'priority': 'URGENT',
        'status': 'UNREAD',
        'scheduled_at': null,
        'published_at': '2026-10-01T12:00:00Z',
        'created_at': '2026-10-01T12:00:00Z',
      };
      final published = PlannerNotification.fromJson(publishedJson);
      expect(published.status, 'PUBLISHED');
      expect(published.targetAudience, 'STAFF');
      expect(published.priority, 'URGENT');
    });

    test('createNotification normalizes roles and dispatches genuine backend call', () async {
      final mockApi = MockWorkflowApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          selectedSchoolIdProvider.overrideWith((ref) => 'test-school-123'),
        ],
      );

      final notifier = container.read(plannerNotificationsProvider.notifier);
      final ok = await notifier.createNotification(
        title: 'Sports Day Notice',
        message: 'All parents please note the timing.',
        targetAudience: 'PARENT',
        priority: 'NORMAL',
      );

      expect(ok, isTrue);

      final postCalls = mockApi.calls.where((c) => c['method'] == 'POST' && c['path'] == '/notifications').toList();
      expect(postCalls.length, 1);
      final payload = postCalls.first['data'] as Map<String, dynamic>;
      expect(payload['school_id'], 'test-school-123');
      expect(payload['title'], 'Sports Day Notice');
      expect(payload['target_role'], 'PARENT');
      expect(payload['notification_type'], 'GENERAL');
      expect(payload['priority'], 'NORMAL');
    });

    test('publishNotification publishes scheduled alert and updates state', () async {
      final mockApi = MockWorkflowApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          selectedSchoolIdProvider.overrideWith((ref) => 'test-school-123'),
        ],
      );

      final notifier = container.read(plannerNotificationsProvider.notifier);
      await notifier.fetchNotifications();
      expect(container.read(plannerNotificationsProvider).notifications.first.status, 'SCHEDULED');

      final ok = await notifier.publishNotification('notif-uuid-1');
      expect(ok, isTrue);

      final publishCalls = mockApi.calls.where((c) => c['path'] == '/notifications/notif-uuid-1/publish').toList();
      expect(publishCalls.length, 1);
      expect(publishCalls.first['query']?['school_id'], 'test-school-123');

      expect(container.read(plannerNotificationsProvider).notifications.first.status, 'PUBLISHED');
    });
  });
}
