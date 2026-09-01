import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../data/models/planner_models.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';
import '../../../teachers/data/models/teachers_models.dart';

// ==========================================
// 1. CALENDAR FEED PROVIDER
// ==========================================
class CalendarFeedState {
  final List<Map<String, dynamic>> feedItems;
  final bool isLoading;
  final String? error;

  const CalendarFeedState({
    required this.feedItems,
    required this.isLoading,
    this.error,
  });

  CalendarFeedState copyWith({
    List<Map<String, dynamic>>? feedItems,
    bool? isLoading,
    String? error,
  }) {
    return CalendarFeedState(
      feedItems: feedItems ?? this.feedItems,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class CalendarFeedNotifier extends StateNotifier<CalendarFeedState> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  CalendarFeedNotifier(this._apiClient, this._ref)
      : super(const CalendarFeedState(feedItems: [], isLoading: false)) {
    _ref.listen<String?>(selectedSchoolIdProvider, (previous, next) {
      state = const CalendarFeedState(feedItems: [], isLoading: false);
    });
  }

  Future<void> fetchFeed({required String startDate, required String endDate}) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.get(
      '/calendar/feed',
      queryParameters: {
        'school_id': schoolId,
        'start_date': startDate,
        'end_date': endDate,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      },
    );

    result.when(
      onSuccess: (data) {
        state = CalendarFeedState(feedItems: data, isLoading: false);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }
}

final calendarFeedProvider =
    StateNotifierProvider<CalendarFeedNotifier, CalendarFeedState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CalendarFeedNotifier(apiClient, ref);
});


// ==========================================
// 2. EVENTS LIST PROVIDER
// ==========================================
class EventsListState {
  final List<SchoolEvent> events;
  final bool isLoading;
  final String? error;

  const EventsListState({
    required this.events,
    required this.isLoading,
    this.error,
  });

  EventsListState copyWith({
    List<SchoolEvent>? events,
    bool? isLoading,
    String? error,
  }) {
    return EventsListState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class EventsListNotifier extends StateNotifier<EventsListState> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  EventsListNotifier(this._apiClient, this._ref)
      : super(const EventsListState(events: [], isLoading: false)) {
    _ref.listen<String?>(selectedSchoolIdProvider, (previous, next) {
      state = const EventsListState(events: [], isLoading: false);
      if (next != null) fetchEvents();
    });
  }

  Future<void> fetchEvents() async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.get(
      '/events',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((e) => SchoolEvent.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      },
    );

    result.when(
      onSuccess: (data) {
        state = EventsListState(events: data, isLoading: false);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
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
    required String targetAudience,
    required bool isHoliday,
  }) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return false;

    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.post(
      '/events',
      queryParameters: {'school_id': schoolId},
      data: {
        'event_name': eventName,
        'description': description,
        'event_date': eventDate,
        'start_time': startTime,
        'end_time': endTime,
        'venue': venue,
        'target_audience': targetAudience,
        'is_holiday': isHoliday,
      },
      mapper: (json) => SchoolEvent.fromJson((json as Map<String, dynamic>)['data'] as Map<String, dynamic>),
    );

    return result.when(
      onSuccess: (event) {
        state = state.copyWith(events: [...state.events, event], isLoading: false);
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }

  Future<bool> publishEvent(String id) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return false;

    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.post(
      '/events/$id/publish',
      queryParameters: {'school_id': schoolId},
      data: {},
      mapper: (json) => SchoolEvent.fromJson((json as Map<String, dynamic>)['data'] as Map<String, dynamic>),
    );

    return result.when(
      onSuccess: (updated) {
        state = state.copyWith(
          events: state.events.map((e) => e.id == id ? updated : e).toList(),
          isLoading: false,
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }

  Future<bool> deleteEvent(String id) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return false;

    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.delete(
      '/events/$id',
      queryParameters: {'school_id': schoolId},
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        state = state.copyWith(
          events: state.events.where((e) => e.id != id).toList(),
          isLoading: false,
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }
}

final eventsListProvider =
    StateNotifierProvider<EventsListNotifier, EventsListState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return EventsListNotifier(apiClient, ref);
});


// ==========================================
// 3. ANNOUNCEMENTS & CIRCULARS LIST PROVIDER
// ==========================================
class AnnouncementsListState {
  final List<Announcement> announcements;
  final bool isLoading;
  final String? error;

  const AnnouncementsListState({
    required this.announcements,
    required this.isLoading,
    this.error,
  });

  AnnouncementsListState copyWith({
    List<Announcement>? announcements,
    bool? isLoading,
    String? error,
  }) {
    return AnnouncementsListState(
      announcements: announcements ?? this.announcements,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AnnouncementsListNotifier extends StateNotifier<AnnouncementsListState> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  AnnouncementsListNotifier(this._apiClient, this._ref)
      : super(const AnnouncementsListState(announcements: [], isLoading: false)) {
    _ref.listen<String?>(selectedSchoolIdProvider, (previous, next) {
      state = const AnnouncementsListState(announcements: [], isLoading: false);
      if (next != null) fetchAnnouncements();
    });
  }

  Future<void> fetchAnnouncements() async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.get(
      '/announcements',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((e) => Announcement.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      },
    );

    result.when(
      onSuccess: (data) {
        state = AnnouncementsListState(announcements: data, isLoading: false);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }

  Future<bool> createAnnouncement({
    required String title,
    required String message,
    required String audienceType,
    String? targetRole,
    String? targetClassId,
    String? targetSectionId,
    String? publishAt,
    String? expiresAt,
    String priority = 'NORMAL',
    String? attachmentUrl,
  }) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return false;

    final academicYearId = _ref.read(selectedAcademicYearIdProvider);

    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.post(
      '/announcements',
      queryParameters: {
        'school_id': schoolId,
        if (academicYearId != null) 'academic_year_id': academicYearId,
      },
      data: {
        'title': title,
        'message': message,
        'audience_type': audienceType,
        if (targetRole != null) 'target_role': targetRole,
        if (targetClassId != null) 'target_class_id': targetClassId,
        if (targetSectionId != null) 'target_section_id': targetSectionId,
        if (publishAt != null) 'publish_at': publishAt,
        if (expiresAt != null) 'expires_at': expiresAt,
        'priority': priority,
        if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      },
      mapper: (json) => Announcement.fromJson((json as Map<String, dynamic>)['data'] as Map<String, dynamic>),
    );

    return result.when(
      onSuccess: (announcement) {
        state = state.copyWith(announcements: [...state.announcements, announcement], isLoading: false);
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }

  Future<bool> publishAnnouncement(String id) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return false;

    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.post(
      '/announcements/$id/publish',
      queryParameters: {'school_id': schoolId},
      data: {},
      mapper: (json) => Announcement.fromJson((json as Map<String, dynamic>)['data'] as Map<String, dynamic>),
    );

    return result.when(
      onSuccess: (updated) {
        state = state.copyWith(
          announcements: state.announcements.map((a) => a.id == id ? updated : a).toList(),
          isLoading: false,
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }

  Future<bool> deleteAnnouncement(String id) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return false;

    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.delete(
      '/announcements/$id',
      queryParameters: {'school_id': schoolId},
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        state = state.copyWith(
          announcements: state.announcements.where((a) => a.id != id).toList(),
          isLoading: false,
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }
}

final announcementsListProvider =
    StateNotifierProvider<AnnouncementsListNotifier, AnnouncementsListState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AnnouncementsListNotifier(apiClient, ref);
});


// ==========================================
// 4. EXAMS LIST PROVIDER & WIZARD
// ==========================================
class ExamsListState {
  final List<Examination> examinations;
  final bool isLoading;
  final String? error;

  const ExamsListState({
    required this.examinations,
    required this.isLoading,
    this.error,
  });

  ExamsListState copyWith({
    List<Examination>? examinations,
    bool? isLoading,
    String? error,
  }) {
    return ExamsListState(
      examinations: examinations ?? this.examinations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ExamsListNotifier extends StateNotifier<ExamsListState> {
  final BaseApiClient _apiClient;
  final Ref _ref;

  ExamsListNotifier(this._apiClient, this._ref)
      : super(const ExamsListState(examinations: [], isLoading: false)) {
    _ref.listen<String?>(selectedSchoolIdProvider, (previous, next) {
      state = const ExamsListState(examinations: [], isLoading: false);
      if (next != null) fetchExams();
    });
  }

  Future<void> fetchExams() async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return;

    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.get(
      '/examinations',
      queryParameters: {'school_id': schoolId},
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        final list = payload['data'] as List<dynamic>? ?? [];
        return list.map((e) => Examination.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      },
    );

    result.when(
      onSuccess: (data) {
        state = ExamsListState(examinations: data, isLoading: false);
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
    );
  }

  Future<bool> createExaminationWizard({
    required String examName,
    required String examType,
    required String startDate,
    required String endDate,
    String? description,
    required List<Map<String, dynamic>> schedules,
  }) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    final academicYearId = _ref.read(selectedAcademicYearIdProvider);
    if (schoolId == null || academicYearId == null) {
      state = state.copyWith(error: 'Missing active school or academic year context.');
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.post(
      '/examinations/wizard',
      data: {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'exam_name': examName,
        'exam_type': examType,
        'start_date': startDate,
        'end_date': endDate,
        if (description != null) 'description': description,
        'schedules': schedules,
      },
      mapper: (json) => Examination.fromJson((json as Map<String, dynamic>)['data'] as Map<String, dynamic>),
    );

    return result.when(
      onSuccess: (exam) {
        state = state.copyWith(examinations: [...state.examinations, exam], isLoading: false);
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }

  Future<bool> publishExam(String id) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return false;

    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.post(
      '/examinations/$id/publish',
      queryParameters: {'school_id': schoolId},
      mapper: (json) => Examination.fromJson((json as Map<String, dynamic>)['data'] as Map<String, dynamic>),
    );

    return result.when(
      onSuccess: (updated) {
        state = state.copyWith(
          examinations: state.examinations.map((e) => e.id == id ? updated : e).toList(),
          isLoading: false,
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }

  Future<bool> deleteExam(String id) async {
    final schoolId = _ref.read(selectedSchoolIdProvider);
    if (schoolId == null) return false;

    state = state.copyWith(isLoading: true, error: null);
    final result = await _apiClient.delete(
      '/examinations/$id',
      queryParameters: {'school_id': schoolId},
      mapper: (json) => json,
    );

    return result.when(
      onSuccess: (_) {
        state = state.copyWith(
          examinations: state.examinations.where((e) => e.id != id).toList(),
          isLoading: false,
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
    );
  }
}

final examsListProvider =
    StateNotifierProvider<ExamsListNotifier, ExamsListState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ExamsListNotifier(apiClient, ref);
});


// ==========================================
// 5. ALL TEACHER SUBJECT ASSIGNMENTS
// ==========================================
final plannerAssignmentsProvider =
    FutureProvider<List<TeacherSubjectAssignmentDto>>((ref) async {
  final schoolId = ref.watch(selectedSchoolIdProvider);
  if (schoolId == null) return [];

  final apiClient = ref.watch(apiClientProvider);
  final result = await apiClient.get(
    '/teacher-subject-assignments',
    queryParameters: {'school_id': schoolId},
    mapper: (json) {
      final payload = json as Map<String, dynamic>;
      final list = payload['data'] as List<dynamic>? ?? [];
      return list
          .map((item) => TeacherSubjectAssignmentDto.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    },
  );

  return result.when(
    onSuccess: (data) => data,
    onFailure: (failure) => throw Exception(failure.message),
  );
});
