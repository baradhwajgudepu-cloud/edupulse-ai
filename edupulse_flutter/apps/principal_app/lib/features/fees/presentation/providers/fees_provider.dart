import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_auth/edupulse_auth.dart';

class FeesAnalyticsData {
  final double todayCollection;
  final double monthCollection;
  final double pendingDues;
  final double collectionPercentage;
  final int defaultersCount;
  final List<dynamic> topOutstandingClasses;
  final double predictedCollectionNext30Days;
  final Map<String, double> historicalTrend;

  FeesAnalyticsData({
    required this.todayCollection,
    required this.monthCollection,
    required this.pendingDues,
    required this.collectionPercentage,
    required this.defaultersCount,
    required this.topOutstandingClasses,
    required this.predictedCollectionNext30Days,
    required this.historicalTrend,
  });

  factory FeesAnalyticsData.empty() {
    return FeesAnalyticsData(
      todayCollection: 0.0,
      monthCollection: 0.0,
      pendingDues: 0.0,
      collectionPercentage: 0.0,
      defaultersCount: 0,
      topOutstandingClasses: [],
      predictedCollectionNext30Days: 0.0,
      historicalTrend: {},
    );
  }
}

sealed class FeesState {
  const FeesState();
}

class FeesInitial extends FeesState {
  const FeesInitial();
}

class FeesLoading extends FeesState {
  const FeesLoading();
}

class FeesSuccess extends FeesState {
  final FeesAnalyticsData data;
  const FeesSuccess(this.data);
}

class FeesError extends FeesState {
  final String message;
  const FeesError(this.message);
}

class FeesNotifier extends StateNotifier<FeesState> {
  final BaseApiClient _apiClient;

  FeesNotifier(this._apiClient) : super(const FeesInitial());

  Future<void> fetchAnalytics({bool isRefresh = false}) async {
    if (!isRefresh) {
      state = const FeesLoading();
    }

    try {
      // 1. Fetch standard fee dashboard report with explicit mapper
      final dashboardResult = await _apiClient.get<Map<String, dynamic>>(
        '/fees/reports/dashboard',
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          return payload['data'] as Map<String, dynamic>? ?? {};
        },
      );

      // 2. Fetch AI collection predictions report with explicit mapper
      final aiResult = await _apiClient.get<Map<String, dynamic>>(
        '/fees/ai/analytics',
        mapper: (json) {
          final payload = json as Map<String, dynamic>;
          return payload['data'] as Map<String, dynamic>? ?? {};
        },
      );

      double todayColl = 0.0;
      double monthColl = 0.0;
      double pendingDues = 0.0;
      double colPct = 0.0;
      int defCount = 0;
      List<dynamic> outstandingClasses = [];
      double predictedNext30Days = 0.0;
      Map<String, double> trend = {};

      dashboardResult.when(
        onSuccess: (dataMap) {
          todayColl = (dataMap['today_collection'] as num?)?.toDouble() ?? 0.0;
          monthColl = (dataMap['month_collection'] as num?)?.toDouble() ?? 0.0;
          pendingDues = (dataMap['pending_dues'] as num?)?.toDouble() ?? 0.0;
          colPct = (dataMap['collection_percentage'] as num?)?.toDouble() ?? 0.0;
          defCount = (dataMap['defaulters_count'] as num?)?.toInt() ?? 0;
          outstandingClasses = dataMap['top_outstanding_classes'] as List<dynamic>? ?? [];
        },
        onFailure: (failure) {
          EduLogger.e('Failed to fetch fees dashboard data: ${failure.message}');
        },
      );

      aiResult.when(
        onSuccess: (dataMap) {
          predictedNext30Days = (dataMap['predicted_collection_next_30_days'] as num?)?.toDouble() ?? 0.0;
          
          final trendPayload = dataMap['historical_trend'] as Map<String, dynamic>? ?? {};
          trend = trendPayload.map((key, val) => MapEntry(key, (val as num).toDouble()));
        },
        onFailure: (failure) {
          EduLogger.e('Failed to fetch fees AI prediction analytics: ${failure.message}');
        },
      );

      state = FeesSuccess(FeesAnalyticsData(
        todayCollection: todayColl,
        monthCollection: monthColl,
        pendingDues: pendingDues,
        collectionPercentage: colPct,
        defaultersCount: defCount,
        topOutstandingClasses: outstandingClasses,
        predictedCollectionNext30Days: predictedNext30Days,
        historicalTrend: trend,
      ));
    } catch (e) {
      state = FeesError('An unexpected error occurred: ${e.toString()}');
    }
  }
}

final feesStateProvider = StateNotifierProvider<FeesNotifier, FeesState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return FeesNotifier(apiClient);
});

class OutstandingFeesState {
  final bool isLoading;
  final List<dynamic> records;
  final String? errorMessage;

  OutstandingFeesState({
    this.isLoading = false,
    this.records = const [],
    this.errorMessage,
  });

  OutstandingFeesState copyWith({
    bool? isLoading,
    List<dynamic>? records,
    String? errorMessage,
  }) {
    return OutstandingFeesState(
      isLoading: isLoading ?? this.isLoading,
      records: records ?? this.records,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class OutstandingFeesNotifier extends StateNotifier<OutstandingFeesState> {
  final BaseApiClient _apiClient;
  final SessionManager _sessionManager;

  OutstandingFeesNotifier(this._apiClient, this._sessionManager) : super(OutstandingFeesState());

  Future<void> fetchReport({String? classId}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) {
      state = state.copyWith(isLoading: false, errorMessage: 'No active school context found.');
      return;
    }

    final queryParams = <String, dynamic>{
      'school_id': schoolId,
    };
    if (classId != null && classId.isNotEmpty) {
      queryParams['class_id'] = classId;
    }

    final result = await _apiClient.get<List<dynamic>>(
      '/fees/reports/outstanding',
      queryParameters: queryParams,
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return payload['data'] as List<dynamic>? ?? [];
      },
    );

    result.when(
      onSuccess: (data) {
        state = state.copyWith(isLoading: false, records: data);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
    );
  }
}

final outstandingFeesProvider = StateNotifierProvider.family<OutstandingFeesNotifier, OutstandingFeesState, String?>((ref, classId) {
  final apiClient = ref.watch(apiClientProvider);
  final sessionManager = ref.watch(sessionManagerProvider);
  final notifier = OutstandingFeesNotifier(apiClient, sessionManager);
  notifier.fetchReport(classId: classId);
  return notifier;
});
