import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:principal_app/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:principal_app/features/academics/data/models/academic_models.dart';

class DashboardSummaryData {
  final double todayCollection;
  final double monthCollection;
  final double pendingDues;
  final double collectionPercentage;
  final int defaultersCount;
  final List<dynamic> topOutstandingClasses;
  final String? feeError;

  final int unreadNotificationsCount;
  final List<NotificationDto> urgentNotifications;
  final List<NotificationDto> highPriorityNotifications;
  final String? notificationsError;

  final List<Examination> upcomingExaminations;
  final String? academicsError;

  DashboardSummaryData({
    required this.todayCollection,
    required this.monthCollection,
    required this.pendingDues,
    required this.collectionPercentage,
    required this.defaultersCount,
    required this.topOutstandingClasses,
    this.feeError,
    required this.unreadNotificationsCount,
    required this.urgentNotifications,
    required this.highPriorityNotifications,
    this.notificationsError,
    required this.upcomingExaminations,
    this.academicsError,
  });

  factory DashboardSummaryData.empty() {
    return DashboardSummaryData(
      todayCollection: 0.0,
      monthCollection: 0.0,
      pendingDues: 0.0,
      collectionPercentage: 0.0,
      defaultersCount: 0,
      topOutstandingClasses: [],
      unreadNotificationsCount: 0,
      urgentNotifications: [],
      highPriorityNotifications: [],
      upcomingExaminations: [],
    );
  }
}

sealed class DashboardState {
  const DashboardState();
}

class DashboardInitial extends DashboardState {
  const DashboardInitial();
}

class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

class DashboardSuccess extends DashboardState {
  final DashboardSummaryData data;
  const DashboardSuccess(this.data);
}

class DashboardError extends DashboardState {
  final String message;
  const DashboardError(this.message);
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  final BaseApiClient _apiClient;
  final SessionManager _sessionManager;
  String? _activeSchoolId;
  String? _lastLoadedSchoolId;

  DashboardNotifier(this._apiClient, this._sessionManager) : super(const DashboardInitial());

  Future<void> fetchSummary({bool isRefresh = false}) async {
    final schoolId = await _sessionManager.getSchoolId() ?? '';
    _activeSchoolId = schoolId;
    final requestSchoolId = schoolId;

    if (schoolId != _lastLoadedSchoolId) {
      state = const DashboardLoading();
      _lastLoadedSchoolId = schoolId;
    } else if (!isRefresh) {
      state = const DashboardLoading();
    }

    try {
      // 1. Fee dashboard request
      final feeFuture = _apiClient.get<Map<String, dynamic>>(
        '/fees/reports/dashboard',
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          return payload['data'] as Map<String, dynamic>? ?? {};
        },
      );

      // 2. Unread notification count request
      final unreadCountFuture = _apiClient.get<int>(
        '/notifications/unread-count',
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          final data = payload['data'] as Map<String, dynamic>? ?? {};
          return (data['unread_count'] as num?)?.toInt() ?? 0;
        },
      );

      // 3. Unread notifications list request
      final notificationsListFuture = _apiClient.get<List<NotificationDto>>(
        '/notifications',
        queryParameters: {'status': 'UNREAD'},
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          final dataList = payload['data'] as List<dynamic>? ?? [];
          return dataList.map((e) => NotificationDto.fromJson(e as Map<String, dynamic>)).toList();
        },
      );

      // 4. Upcoming examinations request
      final examsFuture = _apiClient.get<List<Examination>>(
        '/examinations',
        queryParameters: {
          'limit': 10,
          'school_id': schoolId,
        },
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          final dataList = payload['data'] as List<dynamic>? ?? [];
          return dataList.map((e) => Examination.fromJson(e as Map<String, dynamic>)).toList();
        },
      );

      final results = await Future.wait([
        feeFuture,
        unreadCountFuture,
        notificationsListFuture,
        examsFuture,
      ]);

      if (requestSchoolId != _activeSchoolId) {
        // Stale response from a previous school context. Ignore it.
        return;
      }

      final feeResult = results[0] as ApiResult<Map<String, dynamic>>;
      final unreadCountResult = results[1] as ApiResult<int>;
      final notificationsResult = results[2] as ApiResult<List<NotificationDto>>;
      final examsResult = results[3] as ApiResult<List<Examination>>;

      double todayColl = 0.0;
      double monthColl = 0.0;
      double pendingDues = 0.0;
      double colPct = 0.0;
      int defCount = 0;
      List<dynamic> outstandingClasses = [];
      String? feeError;

      feeResult.when(
        onSuccess: (dataMap) {
          todayColl = (dataMap['today_collection'] as num?)?.toDouble() ?? 0.0;
          monthColl = (dataMap['month_collection'] as num?)?.toDouble() ?? 0.0;
          pendingDues = (dataMap['pending_dues'] as num?)?.toDouble() ?? 0.0;
          colPct = (dataMap['collection_percentage'] as num?)?.toDouble() ?? 0.0;
          defCount = (dataMap['defaulters_count'] as num?)?.toInt() ?? 0;
          outstandingClasses = dataMap['top_outstanding_classes'] as List<dynamic>? ?? [];
        },
        onFailure: (failure) {
          feeError = failure.message;
          EduLogger.e('Dashboard fee metrics fetch failed: ${failure.message}');
        },
      );

      int unreadCount = 0;
      unreadCountResult.when(
        onSuccess: (count) {
          unreadCount = count;
        },
        onFailure: (failure) {
          EduLogger.e('Dashboard unread count fetch failed: ${failure.message}');
        },
      );

      List<NotificationDto> urgentNotifications = [];
      List<NotificationDto> highPriorityNotifications = [];
      String? notificationsError;

      notificationsResult.when(
        onSuccess: (list) {
          final Set<String> seenIds = {};
          urgentNotifications = list.where((n) {
            final isUrgentUnread = n.priority == 'URGENT' && !n.isRead;
            if (isUrgentUnread && !seenIds.contains(n.id)) {
              seenIds.add(n.id);
              return true;
            }
            return false;
          }).toList();

          highPriorityNotifications = list.where((n) {
            final isHighUnread = n.priority == 'HIGH' && !n.isRead;
            if (isHighUnread && !seenIds.contains(n.id)) {
              seenIds.add(n.id);
              return true;
            }
            return false;
          }).toList();
        },
        onFailure: (failure) {
          notificationsError = failure.message;
          EduLogger.e('Dashboard notifications list fetch failed: ${failure.message}');
        },
      );

      List<Examination> upcomingExams = [];
      String? academicsError;

      examsResult.when(
        onSuccess: (list) {
          final now = DateTime.now();
          upcomingExams = list.where((exam) {
            if (exam.startDate.isEmpty) return false;
            try {
              final start = DateTime.parse(exam.startDate);
              return start.isAfter(now.subtract(const Duration(days: 1)));
            } catch (_) {
              return false;
            }
          }).toList();

          upcomingExams.sort((Examination a, Examination b) => a.startDate.compareTo(b.startDate));
        },
        onFailure: (failure) {
          academicsError = failure.message;
          EduLogger.e('Dashboard examinations fetch failed: ${failure.message}');
        },
      );

      state = DashboardSuccess(DashboardSummaryData(
        todayCollection: todayColl,
        monthCollection: monthColl,
        pendingDues: pendingDues,
        collectionPercentage: colPct,
        defaultersCount: defCount,
        topOutstandingClasses: outstandingClasses,
        feeError: feeError,
        unreadNotificationsCount: unreadCount,
        urgentNotifications: urgentNotifications,
        highPriorityNotifications: highPriorityNotifications,
        notificationsError: notificationsError,
        upcomingExaminations: upcomingExams,
        academicsError: academicsError,
      ));
    } catch (e) {
      if (requestSchoolId == _activeSchoolId) {
        state = DashboardError('An unexpected error occurred: ${e.toString()}');
      }
    }
  }

  void clear() {
    _activeSchoolId = null;
    state = const DashboardLoading();
  }
}

final dashboardStateProvider = StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final sessionManager = ref.watch(sessionManagerProvider);
  return DashboardNotifier(apiClient, sessionManager);
});
