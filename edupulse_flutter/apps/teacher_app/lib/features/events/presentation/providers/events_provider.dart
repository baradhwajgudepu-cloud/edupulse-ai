import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import '../../data/models/school_event_model.dart';

// States
sealed class EventsState {
  const EventsState();
}

class EventsInitial extends EventsState {
  const EventsInitial();
}

class EventsLoading extends EventsState {
  const EventsLoading();
}

class EventsSuccess extends EventsState {
  final List<SchoolEvent> events;
  const EventsSuccess(this.events);
}

class EventsError extends EventsState {
  final String message;
  const EventsError(this.message);
}

class EventsNotifier extends StateNotifier<EventsState> {
  final BaseApiClient _apiClient;
  final SessionManager _sessionManager;

  EventsNotifier(this._apiClient, this._sessionManager) : super(const EventsInitial());

  Future<void> fetchEvents() async {
    state = const EventsLoading();
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) {
      state = const EventsError('No active school context found.');
      return;
    }

    final result = await _apiClient.get<List<SchoolEvent>>(
      '/events',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((e) => SchoolEvent.fromJson(e as Map<String, dynamic>)).toList();
      },
    );

    result.when(
      onSuccess: (list) {
        state = EventsSuccess(list);
      },
      onFailure: (failure) {
        state = EventsError(failure.message);
      },
    );
  }
}

final eventsProvider = StateNotifierProvider<EventsNotifier, EventsState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final session = ref.watch(sessionManagerProvider);
  return EventsNotifier(apiClient, session);
});

// Single Event Detail Provider
sealed class EventDetailState {
  const EventDetailState();
}

class EventDetailInitial extends EventDetailState {
  const EventDetailInitial();
}

class EventDetailLoading extends EventDetailState {
  const EventDetailLoading();
}

class EventDetailSuccess extends EventDetailState {
  final SchoolEvent event;
  const EventDetailSuccess(this.event);
}

class EventDetailError extends EventDetailState {
  final String message;
  const EventDetailError(this.message);
}

class EventDetailNotifier extends StateNotifier<EventDetailState> {
  final BaseApiClient _apiClient;
  final SessionManager _sessionManager;
  final String _eventId;

  EventDetailNotifier(this._apiClient, this._sessionManager, this._eventId)
      : super(const EventDetailInitial());

  Future<void> fetchDetail() async {
    state = const EventDetailLoading();
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) {
      state = const EventDetailError('No active school context found.');
      return;
    }

    final result = await _apiClient.get<SchoolEvent>(
      '/events/$_eventId',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return SchoolEvent.fromJson(payload['data'] as Map<String, dynamic>);
      },
    );

    result.when(
      onSuccess: (event) {
        state = EventDetailSuccess(event);
      },
      onFailure: (failure) {
        state = EventDetailError(failure.message);
      },
    );
  }
}

final eventDetailProvider = StateNotifierProvider.family<EventDetailNotifier, EventDetailState, String>((ref, eventId) {
  final apiClient = ref.watch(apiClientProvider);
  final session = ref.watch(sessionManagerProvider);
  return EventDetailNotifier(apiClient, session, eventId);
});
