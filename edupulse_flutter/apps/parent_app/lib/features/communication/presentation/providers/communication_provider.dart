import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_api/edupulse_api.dart';
import 'package:edupulse_models/edupulse_models.dart';

// 1. Queries List State and Notifier
class QueriesListState {
  final bool isLoading;
  final List<CommunicationRequest> requests;
  final String? errorMessage;

  const QueriesListState({
    this.isLoading = false,
    this.requests = const [],
    this.errorMessage,
  });

  QueriesListState copyWith({
    bool? isLoading,
    List<CommunicationRequest>? requests,
    String? errorMessage,
  }) {
    return QueriesListState(
      isLoading: isLoading ?? this.isLoading,
      requests: requests ?? this.requests,
      errorMessage: errorMessage,
    );
  }
}

class QueriesListNotifier extends StateNotifier<QueriesListState> {
  final CommunicationApiClient _client;

  QueriesListNotifier(this._client) : super(const QueriesListState());

  Future<void> fetchRequests({String? studentId}) async {
    state = state.copyWith(isLoading: true);
    final result = await _client.getRequests(studentId: studentId);
    result.when(
      onSuccess: (list) {
        state = QueriesListState(requests: list);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
    );
  }
}

final queriesListProvider = StateNotifierProvider<QueriesListNotifier, QueriesListState>((ref) {
  final client = ref.watch(communicationApiClientProvider);
  return QueriesListNotifier(client);
});

// 2. Request Details State and Notifier
class RequestDetailsState {
  final bool isLoading;
  final CommunicationRequestDetail? detail;
  final String? errorMessage;
  final Map<String, dynamic>? aiInsights;
  final bool isAiLoading;

  const RequestDetailsState({
    this.isLoading = false,
    this.detail,
    this.errorMessage,
    this.aiInsights,
    this.isAiLoading = false,
  });

  RequestDetailsState copyWith({
    bool? isLoading,
    CommunicationRequestDetail? detail,
    String? errorMessage,
    Map<String, dynamic>? aiInsights,
    bool? isAiLoading,
  }) {
    return RequestDetailsState(
      isLoading: isLoading ?? this.isLoading,
      detail: detail ?? this.detail,
      errorMessage: errorMessage,
      aiInsights: aiInsights ?? this.aiInsights,
      isAiLoading: isAiLoading ?? this.isAiLoading,
    );
  }
}

class RequestDetailsNotifier extends StateNotifier<RequestDetailsState> {
  final CommunicationApiClient _client;
  final String requestId;

  RequestDetailsNotifier(this._client, this.requestId) : super(const RequestDetailsState());

  Future<void> fetchDetails() async {
    state = state.copyWith(isLoading: true);
    final result = await _client.getRequestDetails(requestId);
    result.when(
      onSuccess: (detail) {
        state = RequestDetailsState(detail: detail);
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

  Future<void> uploadFile({
    required String messageId,
    required String fileName,
    required List<int> fileBytes,
    required String mimeType,
  }) async {
    final result = await _client.uploadAttachment(
      messageId: messageId,
      fileName: fileName,
      fileBytes: fileBytes,
      mimeType: mimeType,
    );
    result.when(
      onSuccess: (_) {
        fetchDetails();
      },
      onFailure: (failure) {
        state = state.copyWith(errorMessage: failure.message);
      },
    );
  }
}

final requestDetailsProvider = StateNotifierProvider.family<RequestDetailsNotifier, RequestDetailsState, String>((ref, requestId) {
  final client = ref.watch(communicationApiClientProvider);
  return RequestDetailsNotifier(client, requestId);
});

// 3. Unread Count Provider
final communicationUnreadCountProvider = FutureProvider<int>((ref) async {
  final client = ref.watch(communicationApiClientProvider);
  final result = await client.getUnreadCount();
  return result.when(
    onSuccess: (count) => count,
    onFailure: (_) => 0,
  );
});
