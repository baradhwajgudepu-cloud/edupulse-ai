import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_api/edupulse_api.dart';
import 'package:edupulse_models/edupulse_models.dart';

class CommunicationAnalyticsState {
  final bool isLoading;
  final CommunicationAnalytics? analytics;
  final String? errorMessage;

  const CommunicationAnalyticsState({
    this.isLoading = false,
    this.analytics,
    this.errorMessage,
  });

  CommunicationAnalyticsState copyWith({
    bool? isLoading,
    CommunicationAnalytics? analytics,
    String? errorMessage,
  }) {
    return CommunicationAnalyticsState(
      isLoading: isLoading ?? this.isLoading,
      analytics: analytics ?? this.analytics,
      errorMessage: errorMessage,
    );
  }
}

class CommunicationAnalyticsNotifier extends StateNotifier<CommunicationAnalyticsState> {
  final CommunicationApiClient _client;

  CommunicationAnalyticsNotifier(this._client) : super(const CommunicationAnalyticsState());

  Future<void> fetchAnalytics() async {
    state = state.copyWith(isLoading: true);
    final result = await _client.getAnalytics();
    result.when(
      onSuccess: (data) {
        state = CommunicationAnalyticsState(analytics: data);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
    );
  }
}

final communicationAnalyticsProvider = StateNotifierProvider<CommunicationAnalyticsNotifier, CommunicationAnalyticsState>((ref) {
  final client = ref.watch(communicationApiClientProvider);
  return CommunicationAnalyticsNotifier(client);
});
