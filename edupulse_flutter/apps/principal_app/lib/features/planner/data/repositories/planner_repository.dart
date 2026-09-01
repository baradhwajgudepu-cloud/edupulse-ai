import 'package:edupulse_network/edupulse_network.dart';
import '../datasources/planner_datasource.dart';
import '../models/school_event_model.dart';
import '../models/announcement_model.dart';

class PlannerRepository {
  final PlannerDatasource _datasource;

  PlannerRepository(this._datasource);

  // --- CALENDAR CONSOLIDATED FEED ---
  Future<ApiResult<List<Map<String, dynamic>>>> getCalendarFeed({
    required String schoolId,
    required String startDate,
    required String endDate,
  }) async {
    return _datasource.getCalendarFeed(
      schoolId: schoolId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  // --- CLASSES & SECTIONS ---
  Future<ApiResult<List<Map<String, dynamic>>>> getClasses({required String schoolId}) async {
    return _datasource.getClasses(schoolId: schoolId);
  }

  Future<ApiResult<List<Map<String, dynamic>>>> getSections({required String schoolId}) async {
    return _datasource.getSections(schoolId: schoolId);
  }

  Future<ApiResult<List<Map<String, dynamic>>>> getAcademicYears({required String schoolId}) async {
    return _datasource.getAcademicYears(schoolId: schoolId);
  }

  // --- ACTION ITEMS ---
  Future<ApiResult<Map<String, dynamic>>> getActionItems({
    required String schoolId,
  }) async {
    return _datasource.getActionItems(schoolId: schoolId);
  }

  // --- EVENTS ---
  Future<ApiResult<List<SchoolEvent>>> getEvents({
    required String schoolId,
    String? status,
    String? audience,
  }) async {
    final result = await _datasource.getEvents(
      schoolId: schoolId,
      status: status,
      audience: audience,
    );
    return result.when(
      onSuccess: (list) {
        final events = list.map((e) => SchoolEvent.fromJson(e)).toList();
        return ApiResult.success(events);
      },
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  Future<ApiResult<SchoolEvent>> createEvent({
    required String schoolId,
    String? academicYearId,
    required String eventName,
    String? description,
    required String eventDate,
    required String startTime,
    required String endTime,
    String? venue,
    required EventAudience targetAudience,
    required bool isHoliday,
  }) async {
    final payload = {
      'event_name': eventName,
      'description': description,
      'event_date': eventDate,
      'start_time': startTime,
      'end_time': endTime,
      'venue': venue,
      'target_audience': targetAudience.toJson(),
      'is_holiday': isHoliday,
    };
    final result = await _datasource.createEvent(
      schoolId: schoolId,
      academicYearId: academicYearId,
      data: payload,
    );
    return result.when(
      onSuccess: (data) => ApiResult.success(SchoolEvent.fromJson(data)),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  Future<ApiResult<SchoolEvent>> updateEvent({
    required String id,
    required String schoolId,
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
    final payload = {
      'event_name': eventName,
      'description': description,
      'event_date': eventDate,
      'start_time': startTime,
      'end_time': endTime,
      'venue': venue,
      'target_audience': targetAudience.toJson(),
      'is_holiday': isHoliday,
      'status': status.toJson(),
    };
    final result = await _datasource.updateEvent(
      id: id,
      schoolId: schoolId,
      data: payload,
    );
    return result.when(
      onSuccess: (data) => ApiResult.success(SchoolEvent.fromJson(data)),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  Future<ApiResult<SchoolEvent>> deleteEvent({
    required String id,
    required String schoolId,
  }) async {
    final result = await _datasource.deleteEvent(id: id, schoolId: schoolId);
    return result.when(
      onSuccess: (data) => ApiResult.success(SchoolEvent.fromJson(data)),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  Future<ApiResult<SchoolEvent>> publishEvent({
    required String id,
    required String schoolId,
  }) async {
    final result = await _datasource.publishEvent(id: id, schoolId: schoolId);
    return result.when(
      onSuccess: (data) => ApiResult.success(SchoolEvent.fromJson(data)),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  // --- ANNOUNCEMENTS ---
  Future<ApiResult<List<Announcement>>> getAnnouncements({
    required String schoolId,
    String? status,
  }) async {
    final result = await _datasource.getAnnouncements(
      schoolId: schoolId,
      status: status,
    );
    return result.when(
      onSuccess: (list) {
        final announcements = list.map((e) => Announcement.fromJson(e)).toList();
        return ApiResult.success(announcements);
      },
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  Future<ApiResult<Announcement>> createAnnouncement({
    required String schoolId,
    String? academicYearId,
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
    final payload = {
      'title': title,
      'message': message,
      'audience_type': audienceType.toJson(),
      'target_role': targetRole,
      'target_class_id': targetClassId,
      'target_section_id': targetSectionId,
      'publish_at': publishAt,
      'expires_at': expiresAt,
      'priority': priority,
      'attachment_url': attachmentUrl,
    };
    final result = await _datasource.createAnnouncement(
      schoolId: schoolId,
      academicYearId: academicYearId,
      data: payload,
    );
    return result.when(
      onSuccess: (data) => ApiResult.success(Announcement.fromJson(data)),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  Future<ApiResult<Announcement>> updateAnnouncement({
    required String id,
    required String schoolId,
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
    final payload = {
      'title': title,
      'message': message,
      'audience_type': audienceType.toJson(),
      'target_role': targetRole,
      'target_class_id': targetClassId,
      'target_section_id': targetSectionId,
      'publish_at': publishAt,
      'expires_at': expiresAt,
      'priority': priority,
      'attachment_url': attachmentUrl,
      'status': status.toJson(),
    };
    final result = await _datasource.updateAnnouncement(
      id: id,
      schoolId: schoolId,
      data: payload,
    );
    return result.when(
      onSuccess: (data) => ApiResult.success(Announcement.fromJson(data)),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  Future<ApiResult<Announcement>> deleteAnnouncement({
    required String id,
    required String schoolId,
  }) async {
    final result = await _datasource.deleteAnnouncement(id: id, schoolId: schoolId);
    return result.when(
      onSuccess: (data) => ApiResult.success(Announcement.fromJson(data)),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  Future<ApiResult<Announcement>> publishAnnouncement({
    required String id,
    required String schoolId,
  }) async {
    final result = await _datasource.publishAnnouncement(id: id, schoolId: schoolId);
    return result.when(
      onSuccess: (data) => ApiResult.success(Announcement.fromJson(data)),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }
}
