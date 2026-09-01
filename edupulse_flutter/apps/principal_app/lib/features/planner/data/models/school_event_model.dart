enum EventAudience {
  all,
  students,
  parents,
  teachers;

  String toJson() => name.toUpperCase();

  static EventAudience fromJson(String value) {
    switch (value.toUpperCase()) {
      case 'STUDENTS':
        return EventAudience.students;
      case 'PARENTS':
        return EventAudience.parents;
      case 'TEACHERS':
        return EventAudience.teachers;
      case 'ALL':
      default:
        return EventAudience.all;
    }
  }
}

enum EventStatus {
  draft,
  published,
  cancelled,
  completed;

  String toJson() => name.toUpperCase();

  static EventStatus fromJson(String value) {
    switch (value.toUpperCase()) {
      case 'PUBLISHED':
        return EventStatus.published;
      case 'CANCELLED':
        return EventStatus.cancelled;
      case 'COMPLETED':
        return EventStatus.completed;
      case 'DRAFT':
      default:
        return EventStatus.draft;
    }
  }
}

class SchoolEvent {
  final String id;
  final String eventName;
  final String? description;
  final String eventDate;
  final String startTime;
  final String endTime;
  final String? venue;
  final EventAudience targetAudience;
  final EventStatus status;
  final bool isHoliday;

  SchoolEvent({
    required this.id,
    required this.eventName,
    this.description,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    this.venue,
    required this.targetAudience,
    required this.status,
    required this.isHoliday,
  });

  factory SchoolEvent.fromJson(Map<String, dynamic> json) {
    return SchoolEvent(
      id: json['id'] as String? ?? '',
      eventName: json['event_name'] as String? ?? '',
      description: json['description'] as String?,
      eventDate: json['event_date'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      venue: json['venue'] as String?,
      targetAudience: EventAudience.fromJson(json['target_audience'] as String? ?? 'ALL'),
      status: EventStatus.fromJson(json['status'] as String? ?? 'DRAFT'),
      isHoliday: json['is_holiday'] as bool? ?? false,
    );
  }
}
