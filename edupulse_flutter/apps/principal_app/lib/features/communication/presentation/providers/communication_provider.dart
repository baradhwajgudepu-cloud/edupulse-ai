import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_api/edupulse_api.dart';
import 'package:edupulse_models/edupulse_models.dart';

// 1. Queries List State and Notifier
class PrincipalQueriesState {
  final bool isLoading;
  final List<CommunicationRequest> requests;
  final String? errorMessage;

  const PrincipalQueriesState({
    this.isLoading = false,
    this.requests = const [],
    this.errorMessage,
  });

  PrincipalQueriesState copyWith({
    bool? isLoading,
    List<CommunicationRequest>? requests,
    String? errorMessage,
  }) {
    return PrincipalQueriesState(
      isLoading: isLoading ?? this.isLoading,
      requests: requests ?? this.requests,
      errorMessage: errorMessage,
    );
  }
}

class PrincipalQueriesNotifier extends StateNotifier<PrincipalQueriesState> {
  final CommunicationApiClient _client;

  PrincipalQueriesNotifier(this._client) : super(const PrincipalQueriesState());

  Future<void> fetchRequests({
    String? status,
    String? category,
    String? priority,
    String? search,
    String? studentId,
  }) async {
    state = state.copyWith(isLoading: true);
    final result = await _client.getRequests(
      status: status,
      category: category,
      priority: priority,
      search: search,
      studentId: studentId,
    );
    result.when(
      onSuccess: (list) {
        state = PrincipalQueriesState(requests: list);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
    );
  }
}

final principalQueriesProvider = StateNotifierProvider<PrincipalQueriesNotifier, PrincipalQueriesState>((ref) {
  final client = ref.watch(communicationApiClientProvider);
  return PrincipalQueriesNotifier(client);
});

// 2. Request Details State and Notifier
class PrincipalDetailsState {
  final bool isLoading;
  final CommunicationRequestDetail? detail;
  final String? errorMessage;
  final List<Map<String, dynamic>> schoolTeachers;
  final bool isTeachersLoading;

  const PrincipalDetailsState({
    this.isLoading = false,
    this.detail,
    this.errorMessage,
    this.schoolTeachers = const [],
    this.isTeachersLoading = false,
  });

  PrincipalDetailsState copyWith({
    bool? isLoading,
    CommunicationRequestDetail? detail,
    String? errorMessage,
    List<Map<String, dynamic>>? schoolTeachers,
    bool? isTeachersLoading,
  }) {
    return PrincipalDetailsState(
      isLoading: isLoading ?? this.isLoading,
      detail: detail ?? this.detail,
      errorMessage: errorMessage,
      schoolTeachers: schoolTeachers ?? this.schoolTeachers,
      isTeachersLoading: isTeachersLoading ?? this.isTeachersLoading,
    );
  }
}

class PrincipalDetailsNotifier extends StateNotifier<PrincipalDetailsState> {
  final CommunicationApiClient _client;
  final Ref _ref;
  final String requestId;

  PrincipalDetailsNotifier(this._client, this._ref, this.requestId)
      : super(const PrincipalDetailsState());

  Future<void> fetchDetails() async {
    state = state.copyWith(isLoading: true);
    final result = await _client.getRequestDetails(requestId);
    result.when(
      onSuccess: (detail) {
        state = state.copyWith(isLoading: false, detail: detail);
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

  Future<void> assignTeacher(String teacherId) async {
    final result = await _client.assignRequest(requestId: requestId, assigneeId: teacherId);
    result.when(
      onSuccess: (_) {
        fetchDetails();
      },
      onFailure: (failure) {
        state = state.copyWith(errorMessage: failure.message);
      },
    );
  }

  Future<void> fetchSchoolTeachers(String schoolId) async {
    state = state.copyWith(isTeachersLoading: true);
    final apiClient = _ref.read(apiClientProvider);
    final result = await apiClient.get(
      '/teachers',
      queryParameters: {'school_id': schoolId},
      mapper: (json) => json,
    );
    result.when(
      onSuccess: (res) {
        final list = (res['data'] as List? ?? []);
        final List<Map<String, dynamic>> teachers = [];
        for (final item in list) {
          teachers.add({
            'id': item['user_id'] ?? item['id'],
            'fullName': '${item['first_name']} ${item['last_name']}',
          });
        }
        state = state.copyWith(isTeachersLoading: false, schoolTeachers: teachers);
      },
      onFailure: (failure) {
        state = state.copyWith(isTeachersLoading: false, errorMessage: failure.message);
      },
    );
  }
}

final principalDetailsProvider = StateNotifierProvider.family<PrincipalDetailsNotifier, PrincipalDetailsState, String>((ref, requestId) {
  final client = ref.watch(communicationApiClientProvider);
  return PrincipalDetailsNotifier(client, ref, requestId);
});
