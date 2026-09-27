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

// --- TEACHER LEAVES ---
class LeaveRequest {
  final String id;
  final String tenantId;
  final String schoolId;
  final String teacherId;
  final String teacherName;
  final String? teacherDesignation;
  final String? teacherEmployeeId;
  final String leaveType;
  final String startDate;
  final String endDate;
  final String reason;
  final String? remarks;
  final String status; // PENDING, APPROVED, REJECTED, CANCELLED
  final String requestedAt;
  final String? reviewedAt;
  final String? reviewedBy;
  final String? reviewerRemarks;

  LeaveRequest({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.teacherId,
    required this.teacherName,
    this.teacherDesignation,
    this.teacherEmployeeId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.remarks,
    required this.status,
    required this.requestedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.reviewerRemarks,
  });

  int get daysCount {
    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);
      return end.difference(start).inDays + 1;
    } catch (_) {
      return 1;
    }
  }

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    String teacherName = 'Staff Member';
    String? designation;
    String? employeeId;

    if (json['teacher'] != null && json['teacher'] is Map) {
      final t = json['teacher'] as Map<String, dynamic>;
      final fn = t['first_name'] as String? ?? '';
      final ln = t['last_name'] as String? ?? '';
      teacherName = '$fn $ln'.trim();
      if (teacherName.isEmpty) teacherName = 'Staff Member';
      designation = t['designation'] as String?;
      employeeId = t['employee_id'] as String?;
    }

    return LeaveRequest(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      schoolId: json['school_id'] as String? ?? '',
      teacherId: json['teacher_id'] as String? ?? '',
      teacherName: teacherName,
      teacherDesignation: designation,
      teacherEmployeeId: employeeId,
      leaveType: json['leave_type'] as String? ?? 'CASUAL',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      remarks: json['remarks'] as String?,
      status: (json['status'] as String? ?? 'PENDING').toUpperCase(),
      requestedAt: json['requested_at'] as String? ?? '',
      reviewedAt: json['reviewed_at'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      reviewerRemarks: json['reviewer_remarks'] as String?,
    );
  }
}

// --- NOTIFICATIONS ---
class PlannerNotification {
  final String id;
  final String title;
  final String message;
  final String targetAudience;
  final String priority;
  final String status; // DRAFT, SCHEDULED, PUBLISHED
  final String createdAt;
  final String? scheduledFor;

  PlannerNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.targetAudience,
    required this.priority,
    required this.status,
    required this.createdAt,
    this.scheduledFor,
  });

  factory PlannerNotification.fromJson(Map<String, dynamic> json) {
    final publishedAt = json['published_at'] as String?;
    final scheduledAt = json['scheduled_at'] as String? ?? json['scheduled_for'] as String?;

    String computedStatus;
    if (publishedAt != null && publishedAt.isNotEmpty) {
      computedStatus = 'PUBLISHED';
    } else if (scheduledAt != null && scheduledAt.isNotEmpty) {
      computedStatus = 'SCHEDULED';
    } else {
      final rawStatus = (json['status'] as String? ?? '').toUpperCase();
      if (rawStatus == 'PUBLISHED' || rawStatus == 'SCHEDULED' || rawStatus == 'DRAFT') {
        computedStatus = rawStatus;
      } else {
        computedStatus = 'PUBLISHED';
      }
    }

    return PlannerNotification(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? (json['body'] as String? ?? ''),
      targetAudience: json['target_role'] as String? ?? (json['target_audience'] as String? ?? 'ALL'),
      priority: (json['priority'] as String? ?? 'NORMAL').toUpperCase(),
      status: computedStatus,
      createdAt: json['created_at'] as String? ?? '',
      scheduledFor: scheduledAt,
    );
  }
}

// --- OPERATIONAL TIMELINE ITEM ---
enum PlannerTimelineType {
  leave,
  exam,
  circular,
  notification,
  event;
}

class PlannerTimelineItem {
  final String id;
  final String title;
  final String description;
  final String timestamp;
  final String status;
  final PlannerTimelineType type;
  final String? actionRoute;

  PlannerTimelineItem({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.status,
    required this.type,
    this.actionRoute,
  });
}

