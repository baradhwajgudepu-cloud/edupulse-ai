import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_api/edupulse_api.dart';
import 'package:edupulse_models/edupulse_models.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// 1. Queries List State and Notifier
class TeacherQueriesState {
  final bool isLoading;
  final List<CommunicationRequest> requests;
  final String? errorMessage;

  const TeacherQueriesState({
    this.isLoading = false,
    this.requests = const [],
    this.errorMessage,
  });

  TeacherQueriesState copyWith({
    bool? isLoading,
    List<CommunicationRequest>? requests,
    String? errorMessage,
  }) {
    return TeacherQueriesState(
      isLoading: isLoading ?? this.isLoading,
      requests: requests ?? this.requests,
      errorMessage: errorMessage,
    );
  }
}

class TeacherQueriesNotifier extends StateNotifier<TeacherQueriesState> {
  final CommunicationApiClient _client;
  final Ref _ref;

  TeacherQueriesNotifier(this._client, this._ref) : super(const TeacherQueriesState());

  Future<void> fetchRequests() async {
    state = state.copyWith(isLoading: true);
    final authState = _ref.read(authStateProvider);
    String? userId;
    if (authState is Authenticated) {
      userId = authState.user.id;
    }

    final result = await _client.getRequests(assignedToId: userId);
    result.when(
      onSuccess: (list) {
        state = TeacherQueriesState(requests: list);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
    );
  }
}

final teacherQueriesProvider = StateNotifierProvider<TeacherQueriesNotifier, TeacherQueriesState>((ref) {
  final client = ref.watch(communicationApiClientProvider);
  return TeacherQueriesNotifier(client, ref);
});

// 2. Request Details State and Notifier
class TeacherDetailsState {
  final bool isLoading;
  final CommunicationRequestDetail? detail;
  final String? errorMessage;
  final Map<String, dynamic>? aiInsights;
  final bool isAiLoading;

  const TeacherDetailsState({
    this.isLoading = false,
    this.detail,
    this.errorMessage,
    this.aiInsights,
    this.isAiLoading = false,
  });

  TeacherDetailsState copyWith({
    bool? isLoading,
    CommunicationRequestDetail? detail,
    String? errorMessage,
    Map<String, dynamic>? aiInsights,
    bool? isAiLoading,
  }) {
    return TeacherDetailsState(
      isLoading: isLoading ?? this.isLoading,
      detail: detail ?? this.detail,
      errorMessage: errorMessage,
      aiInsights: aiInsights ?? this.aiInsights,
      isAiLoading: isAiLoading ?? this.isAiLoading,
    );
  }
}

class TeacherDetailsNotifier extends StateNotifier<TeacherDetailsState> {
  final CommunicationApiClient _client;
  final String requestId;

  TeacherDetailsNotifier(this._client, this.requestId) : super(const TeacherDetailsState());

  Future<void> fetchDetails() async {
    state = state.copyWith(isLoading: true);
    final result = await _client.getRequestDetails(requestId);
    result.when(
      onSuccess: (detail) {
        state = TeacherDetailsState(detail: detail);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
    );
  }

  Future<void> reply(String message) async {
    final result = await _client.replyToRequest(requestId: requestId, message: message);
    result.when(
      onSuccess: (msg) {
        fetchDetails(); // Reload details
      },
      onFailure: (failure) {
        state = state.copyWith(errorMessage: failure.message);
      },
    );
  }

  Future<void> updateStatus(String status) async {
    final result = await _client.updateStatus(requestId: requestId, status: status);
    result.when(
      onSuccess: (_) {
        fetchDetails();
      },
      onFailure: (failure) {
        state = state.copyWith(errorMessage: failure.message);
      },
    );
  }

  Future<void> escalate() async {
    final result = await _client.escalateRequest(requestId);
    result.when(
      onSuccess: (_) {
        fetchDetails();
      },
      onFailure: (failure) {
        state = state.copyWith(errorMessage: failure.message);
      },
    );
  }

  Future<void> fetchAiInsights() async {
    state = state.copyWith(isAiLoading: true);
    final result = await _client.getAiInsights(requestId);
    result.when(
      onSuccess: (insights) {
        state = state.copyWith(isAiLoading: false, aiInsights: insights);
      },
      onFailure: (failure) {
        state = state.copyWith(isAiLoading: false, errorMessage: failure.message);
      },
    );
  }
}

final teacherDetailsProvider = StateNotifierProvider.family<TeacherDetailsNotifier, TeacherDetailsState, String>((ref, requestId) {
  final client = ref.watch(communicationApiClientProvider);
  return TeacherDetailsNotifier(client, requestId);
});
