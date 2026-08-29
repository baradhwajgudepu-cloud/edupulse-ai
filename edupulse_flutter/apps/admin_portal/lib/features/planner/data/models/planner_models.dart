import 'package:flutter/foundation.dart';

// --- EVENTS ---
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

// --- ANNOUNCEMENTS ---
enum AnnouncementAudienceType {
  role,
  className,
  section;

  String toJson() {
    if (this == AnnouncementAudienceType.className) return 'CLASS';
    return name.toUpperCase();
  }

  static AnnouncementAudienceType fromJson(String value) {
    switch (value.toUpperCase()) {
      case 'CLASS':
        return AnnouncementAudienceType.className;
      case 'SECTION':
        return AnnouncementAudienceType.section;
      case 'ROLE':
      default:
        return AnnouncementAudienceType.role;
    }
  }
}

enum AnnouncementStatus {
  draft,
  published,
  cancelled;

  String toJson() => name.toUpperCase();

  static AnnouncementStatus fromJson(String value) {
    switch (value.toUpperCase()) {
      case 'PUBLISHED':
        return AnnouncementStatus.published;
      case 'CANCELLED':
        return AnnouncementStatus.cancelled;
      case 'DRAFT':
      default:
        return AnnouncementStatus.draft;
    }
  }
}

class Announcement {
  final String id;
  final String title;
  final String message;
  final AnnouncementAudienceType audienceType;
  final String? targetRole;
  final String? targetClassId;
  final String? targetSectionId;
  final String? publishAt;
  final String? expiresAt;
  final String priority;
  final String? attachmentUrl;
  final AnnouncementStatus status;
  final String createdAt;

  Announcement({
    required this.id,
    required this.title,
    required this.message,
    required this.audienceType,
    this.targetRole,
    this.targetClassId,
    this.targetSectionId,
    this.publishAt,
    this.expiresAt,
    required this.priority,
    this.attachmentUrl,
    required this.status,
    required this.createdAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      audienceType: AnnouncementAudienceType.fromJson(json['audience_type'] as String? ?? 'ROLE'),
      targetRole: json['target_role'] as String?,
      targetClassId: json['target_class_id'] as String?,
      targetSectionId: json['target_section_id'] as String?,
      publishAt: json['publish_at'] as String?,
      expiresAt: json['expires_at'] as String?,
      priority: json['priority'] as String? ?? 'NORMAL',
      attachmentUrl: json['attachment_url'] as String?,
      status: AnnouncementStatus.fromJson(json['status'] as String? ?? 'DRAFT'),
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

// --- EXAMINATIONS ---
class ExamSchedule {
  final String id;
  final String examId;
  final String classId;
  final String sectionId;
  final String subjectId;
  final String teacherSubjectAssignmentId;
  final String examDate;
  final String startTime;
  final String endTime;
  final int maxMarks;
  final int passMarks;
  final String? roomNumber;

  ExamSchedule({
    required this.id,
    required this.examId,
    required this.classId,
    required this.sectionId,
    required this.subjectId,
    required this.teacherSubjectAssignmentId,
    required this.examDate,
    required this.startTime,
    required this.endTime,
    required this.maxMarks,
    required this.passMarks,
    this.roomNumber,
  });

  factory ExamSchedule.fromJson(Map<String, dynamic> json) {
    return ExamSchedule(
      id: json['id'] as String? ?? '',
      examId: json['exam_id'] as String? ?? '',
      classId: json['class_id'] as String? ?? '',
      sectionId: json['section_id'] as String? ?? '',
      subjectId: json['subject_id'] as String? ?? '',
      teacherSubjectAssignmentId: json['teacher_subject_assignment_id'] as String? ?? '',
      examDate: json['exam_date'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      maxMarks: (json['max_marks'] as num?)?.toInt() ?? 100,
      passMarks: (json['pass_marks'] as num?)?.toInt() ?? 35,
      roomNumber: json['room_number'] as String?,
    );
  }
}

class Examination {
  final String id;
  final String examName;
  final String examType;
  final String startDate;
  final String endDate;
  final String status;
  final String? description;
  final List<ExamSchedule> schedules;

  Examination({
    required this.id,
    required this.examName,
    required this.examType,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.description,
    required this.schedules,
  });

  factory Examination.fromJson(Map<String, dynamic> json) {
    final schedList = json['schedules'] as List<dynamic>? ?? [];
    return Examination(
      id: json['id'] as String? ?? '',
      examName: json['exam_name'] as String? ?? '',
      examType: json['exam_type'] as String? ?? '',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      status: json['status'] as String? ?? '',
      description: json['description'] as String?,
      schedules: schedList.map((e) => ExamSchedule.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
