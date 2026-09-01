import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import '../../data/datasources/planner_datasource.dart';
import '../../data/repositories/planner_repository.dart';
import '../../data/models/school_event_model.dart';
import '../../data/models/announcement_model.dart';

// Datasource Provider
final plannerDatasourceProvider = Provider<PlannerDatasource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PlannerDatasource(apiClient);
});

// Repository Provider
final plannerRepositoryProvider = Provider<PlannerRepository>((ref) {
  final datasource = ref.watch(plannerDatasourceProvider);
  return PlannerRepository(datasource);
});

// --- CALENDAR FEED PROVIDER ---
sealed class CalendarFeedState {
  const CalendarFeedState();
}

class CalendarFeedInitial extends CalendarFeedState {
  const CalendarFeedInitial();
}

class CalendarFeedLoading extends CalendarFeedState {
  const CalendarFeedLoading();
}

class CalendarFeedSuccess extends CalendarFeedState {
  final List<Map<String, dynamic>> feedItems;
  const CalendarFeedSuccess(this.feedItems);
}

class CalendarFeedError extends CalendarFeedState {
  final String message;
  const CalendarFeedError(this.message);
}

class CalendarFeedNotifier extends StateNotifier<CalendarFeedState> {
  final PlannerRepository _repository;
  final SessionManager _sessionManager;

  CalendarFeedNotifier(this._repository, this._sessionManager)
      : super(const CalendarFeedInitial());

  Future<void> fetchFeed({required String startDate, required String endDate}) async {
    state = const CalendarFeedLoading();
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) {
      state = const CalendarFeedError('No active school context found.');
      return;
    }

    final result = await _repository.getCalendarFeed(
      schoolId: schoolId,
      startDate: startDate,
      endDate: endDate,
    );

    result.when(
      onSuccess: (items) {
        state = CalendarFeedSuccess(items);
      },
      onFailure: (failure) {
        state = CalendarFeedError(failure.message);
      },
    );
  }
}

final calendarFeedProvider =
    StateNotifierProvider<CalendarFeedNotifier, CalendarFeedState>((ref) {
  final repo = ref.watch(plannerRepositoryProvider);
  final session = ref.watch(sessionManagerProvider);
  return CalendarFeedNotifier(repo, session);
});

// --- ACTION ITEMS PROVIDER ---
sealed class ActionItemsState {
  const ActionItemsState();
}

class ActionItemsInitial extends ActionItemsState {
  const ActionItemsInitial();
}

class ActionItemsLoading extends ActionItemsState {
  const ActionItemsLoading();
}

class ActionItemsSuccess extends ActionItemsState {
  final Map<String, dynamic> counts;
  const ActionItemsSuccess(this.counts);
}

class ActionItemsError extends ActionItemsState {
  final String message;
  const ActionItemsError(this.message);
}

class ActionItemsNotifier extends StateNotifier<ActionItemsState> {
  final PlannerRepository _repository;
  final SessionManager _sessionManager;

  ActionItemsNotifier(this._repository, this._sessionManager)
      : super(const ActionItemsInitial());

  Future<void> fetchActionItems() async {
    state = const ActionItemsLoading();
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) {
      state = const ActionItemsError('No active school context found.');
      return;
    }

    final result = await _repository.getActionItems(schoolId: schoolId);
    result.when(
      onSuccess: (counts) {
        state = ActionItemsSuccess(counts);
      },
      onFailure: (failure) {
        state = ActionItemsError(failure.message);
      },
    );
  }
}

final actionItemsProvider =
    StateNotifierProvider<ActionItemsNotifier, ActionItemsState>((ref) {
  final repo = ref.watch(plannerRepositoryProvider);
  final session = ref.watch(sessionManagerProvider);
  return ActionItemsNotifier(repo, session);
});

// --- EVENTS LIST PROVIDER ---
sealed class EventsListState {
  const EventsListState();
}

class EventsListInitial extends EventsListState {
  const EventsListInitial();
}

class EventsListLoading extends EventsListState {
  const EventsListLoading();
}

class EventsListSuccess extends EventsListState {
  final List<SchoolEvent> events;
  const EventsListSuccess(this.events);
}

class EventsListError extends EventsListState {
  final String message;
  const EventsListError(this.message);
}

class EventsListNotifier extends StateNotifier<EventsListState> {
  final PlannerRepository _repository;
  final SessionManager _sessionManager;

  EventsListNotifier(this._repository, this._sessionManager)
      : super(const EventsListInitial());

  Future<void> fetchEvents({String? status, String? audience}) async {
    state = const EventsListLoading();
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) {
      state = const EventsListError('No active school context found.');
      return;
    }

    final result = await _repository.getEvents(
      schoolId: schoolId,
      status: status,
      audience: audience,
    );

    result.when(
      onSuccess: (list) {
        state = EventsListSuccess(list);
      },
      onFailure: (failure) {
        state = EventsListError(failure.message);
      },
    );
  }

  Future<bool> createEvent({
    required String eventName,
    String? description,
    required String eventDate,
    required String startTime,
    required String endTime,
    String? venue,
    required EventAudience targetAudience,
    required bool isHoliday,
  }) async {
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null) return false;

    final result = await _repository.createEvent(
      schoolId: schoolId,
      academicYearId: null,
      eventName: eventName,
      description: description,
      eventDate: eventDate,
      startTime: startTime,
      endTime: endTime,
      venue: venue,
      targetAudience: targetAudience,
      isHoliday: isHoliday,
    );

    return result.when(
      onSuccess: (e) {
        fetchEvents();
        return true;
      },
      onFailure: (f) => false,
    );
  }

  Future<bool> createAndPublishEvent({
    required String eventName,
    String? description,
    required String eventDate,
    required String startTime,
    required String endTime,
    String? venue,
    required EventAudience targetAudience,
    required bool isHoliday,
  }) async {
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null) return false;

    final result = await _repository.createEvent(
      schoolId: schoolId,
      academicYearId: null,
      eventName: eventName,
      description: description,
      eventDate: eventDate,
      startTime: startTime,
      endTime: endTime,
      venue: venue,
      targetAudience: targetAudience,
      isHoliday: isHoliday,
    );

    return result.when(
      onSuccess: (event) async {
        final publishResult = await publishEvent(event.id);
        fetchEvents();
        return publishResult;
      },
      onFailure: (f) => false,
    );
  }

  Future<bool> updateEvent({
    required String id,
    required String eventName,
    String? description,
    required String eventDate,
    required String startTime,
    required String endTime,
    String? venue,
    required EventAudience targetAudience,
    required bool isHoliday,
    required EventStatus status,
  }) async {
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null) return false;

    final result = await _repository.updateEvent(
      id: id,
      schoolId: schoolId,
      eventName: eventName,
      description: description,
      eventDate: eventDate,
      startTime: startTime,
      endTime: endTime,
      venue: venue,
      targetAudience: targetAudience,
      isHoliday: isHoliday,
      status: status,
    );

    return result.when(
      onSuccess: (e) {
        fetchEvents();
        return true;
      },
      onFailure: (f) => false,
    );
  }

  Future<bool> cancelEvent(SchoolEvent event) async {
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null) return false;

    final result = await _repository.updateEvent(
      id: event.id,
      schoolId: schoolId,
      eventName: event.eventName,
      description: event.description,
      eventDate: event.eventDate,
      startTime: event.startTime,
      endTime: event.endTime,
      venue: event.venue,
      targetAudience: event.targetAudience,
      isHoliday: event.isHoliday,
      status: EventStatus.cancelled,
    );

    return result.when(
      onSuccess: (_) {
        fetchEvents();
        return true;
      },
      onFailure: (_) => false,
    );
  }

  Future<bool> deleteEvent(String id) async {
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null) return false;

    final result = await _repository.deleteEvent(id: id, schoolId: schoolId);
    return result.when(
      onSuccess: (e) {
        fetchEvents();
        return true;
      },
      onFailure: (f) => false,
    );
  }

  Future<bool> publishEvent(String id) async {
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null) return false;

    final result = await _repository.publishEvent(id: id, schoolId: schoolId);
    return result.when(
      onSuccess: (e) {
        fetchEvents();
        return true;
      },
      onFailure: (f) => false,
    );
  }
}

final eventsListProvider =
    StateNotifierProvider<EventsListNotifier, EventsListState>((ref) {
  final repo = ref.watch(plannerRepositoryProvider);
  final session = ref.watch(sessionManagerProvider);
  return EventsListNotifier(repo, session);
});

// --- ANNOUNCEMENTS LIST PROVIDER ---
sealed class AnnouncementsListState {
  const AnnouncementsListState();
}

class AnnouncementsListInitial extends AnnouncementsListState {
  const AnnouncementsListInitial();
}

class AnnouncementsListLoading extends AnnouncementsListState {
  const AnnouncementsListLoading();
}

class AnnouncementsListSuccess extends AnnouncementsListState {
  final List<Announcement> announcements;
  const AnnouncementsListSuccess(this.announcements);
}

class AnnouncementsListError extends AnnouncementsListState {
  final String message;
  const AnnouncementsListError(this.message);
}

class AnnouncementsListNotifier extends StateNotifier<AnnouncementsListState> {
  final PlannerRepository _repository;
  final SessionManager _sessionManager;

  AnnouncementsListNotifier(this._repository, this._sessionManager)
      : super(const AnnouncementsListInitial());

  Future<void> fetchAnnouncements({String? status}) async {
    state = const AnnouncementsListLoading();
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null || schoolId.isEmpty) {
      state = const AnnouncementsListError('No active school context found.');
      return;
    }

    final result = await _repository.getAnnouncements(
      schoolId: schoolId,
      status: status,
    );

    result.when(
      onSuccess: (list) {
        state = AnnouncementsListSuccess(list);
      },
      onFailure: (failure) {
        state = AnnouncementsListError(failure.message);
      },
    );
  }

  Future<bool> createAnnouncement({
    required String title,
    required String message,
    required AnnouncementAudienceType audienceType,
    String? targetRole,
    String? targetClassId,
    String? targetSectionId,
    String? publishAt,
    String? expiresAt,
    required String priority,
    String? attachmentUrl,
  }) async {
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null) return false;

    final result = await _repository.createAnnouncement(
      schoolId: schoolId,
      academicYearId: null,
      title: title,
      message: message,
      audienceType: audienceType,
      targetRole: targetRole,
      targetClassId: targetClassId,
      targetSectionId: targetSectionId,
      publishAt: publishAt,
      expiresAt: expiresAt,
      priority: priority,
      attachmentUrl: attachmentUrl,
    );

    return result.when(
      onSuccess: (a) {
        fetchAnnouncements();
        return true;
      },
      onFailure: (f) => false,
    );
  }

  Future<bool> updateAnnouncement({
    required String id,
    required String title,
    required String message,
    required AnnouncementAudienceType audienceType,
    String? targetRole,
    String? targetClassId,
    String? targetSectionId,
    String? publishAt,
    String? expiresAt,
    required String priority,
    String? attachmentUrl,
    required AnnouncementStatus status,
  }) async {
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null) return false;

    final result = await _repository.updateAnnouncement(
      id: id,
      schoolId: schoolId,
      title: title,
      message: message,
      audienceType: audienceType,
      targetRole: targetRole,
      targetClassId: targetClassId,
      targetSectionId: targetSectionId,
      publishAt: publishAt,
      expiresAt: expiresAt,
      priority: priority,
      attachmentUrl: attachmentUrl,
      status: status,
    );

    return result.when(
      onSuccess: (a) {
        fetchAnnouncements();
        return true;
      },
      onFailure: (f) => false,
    );
  }

  Future<bool> deleteAnnouncement(String id) async {
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null) return false;

    final result =
        await _repository.deleteAnnouncement(id: id, schoolId: schoolId);
    return result.when(
      onSuccess: (a) {
        fetchAnnouncements();
        return true;
      },
      onFailure: (f) => false,
    );
  }

  Future<bool> publishAnnouncement(String id) async {
    final schoolId = await _sessionManager.getSchoolId();
    if (schoolId == null) return false;

    final result =
        await _repository.publishAnnouncement(id: id, schoolId: schoolId);
    return result.when(
      onSuccess: (a) {
        fetchAnnouncements();
        return true;
      },
      onFailure: (f) => false,
    );
  }
}

final announcementsListProvider = StateNotifierProvider<
    AnnouncementsListNotifier, AnnouncementsListState>((ref) {
  final repo = ref.watch(plannerRepositoryProvider);
  final session = ref.watch(sessionManagerProvider);
  return AnnouncementsListNotifier(repo, session);
});
