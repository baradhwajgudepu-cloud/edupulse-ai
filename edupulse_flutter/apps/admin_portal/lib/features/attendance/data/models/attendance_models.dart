class AttendanceSessionDto {
  final String id;
  final String tenantId;
  final String schoolId;
  final String academicYearId;
  final String timetableId;
  final String classId;
  final String sectionId;
  final String? teacherId;
  final String? subjectId;
  final String attendanceDate;
  final String status;
  final String? markedBy;
  final String? markedAt;
  final bool isActive;
  final Map<String, dynamic> settings;
  final int version;
  final List<AttendanceLogDto> attendances;

  const AttendanceSessionDto({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.academicYearId,
    required this.timetableId,
    required this.classId,
    required this.sectionId,
    this.teacherId,
    this.subjectId,
    required this.attendanceDate,
    required this.status,
    this.markedBy,
    this.markedAt,
    required this.isActive,
    required this.settings,
    required this.version,
    required this.attendances,
  });

  factory AttendanceSessionDto.fromJson(Map<String, dynamic> json) {
    return AttendanceSessionDto(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      academicYearId: json['academic_year_id'] as String,
      timetableId: json['timetable_id'] as String,
      classId: json['class_id'] as String,
      sectionId: json['section_id'] as String,
      teacherId: json['teacher_id'] as String?,
      subjectId: json['subject_id'] as String?,
      attendanceDate: json['attendance_date'] as String,
      status: json['status'] as String,
      markedBy: json['marked_by'] as String?,
      markedAt: json['marked_at'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      settings: Map<String, dynamic>.from(json['settings'] as Map? ?? {}),
      version: json['version'] as int? ?? 1,
      attendances: (json['attendances'] as List? ?? [])
          .map((e) => AttendanceLogDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class AttendanceLogDto {
  final String id;
  final String tenantId;
  final String schoolId;
  final String academicYearId;
  final String attendanceSessionId;
  final String studentId;
  final String timetableId;
  final String classId;
  final String sectionId;
  final String? teacherId;
  final String? subjectId;
  final String attendanceDate;
  final String attendanceStatus;
  final String attendanceSource;
  final String attendanceReason;
  final String? remarks;
  final bool parentViewed;
  final String? parentViewedAt;
  final bool isActive;
  final Map<String, dynamic> settings;
  final Map<String, dynamic> aiMetrics;
  final int version;
  final String? studentRollNumber;
  final String? studentName;

  const AttendanceLogDto({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.academicYearId,
    required this.attendanceSessionId,
    required this.studentId,
    required this.timetableId,
    required this.classId,
    required this.sectionId,
    this.teacherId,
    this.subjectId,
    required this.attendanceDate,
    required this.attendanceStatus,
    required this.attendanceSource,
    required this.attendanceReason,
    this.remarks,
    required this.parentViewed,
    this.parentViewedAt,
    required this.isActive,
    required this.settings,
    required this.aiMetrics,
    required this.version,
    this.studentRollNumber,
    this.studentName,
  });

  factory AttendanceLogDto.fromJson(Map<String, dynamic> json) {
    String? roll;
    String? name;
    if (json['student'] != null) {
      final student = json['student'] as Map;
      roll = student['roll_number'] as String?;
      name = '${student['first_name'] ?? ""} ${student['last_name'] ?? ""}'.trim();
    }
    return AttendanceLogDto(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      academicYearId: json['academic_year_id'] as String,
      attendanceSessionId: json['attendance_session_id'] as String,
      studentId: json['student_id'] as String,
      timetableId: json['timetable_id'] as String,
      classId: json['class_id'] as String,
      sectionId: json['section_id'] as String,
      teacherId: json['teacher_id'] as String?,
      subjectId: json['subject_id'] as String?,
      attendanceDate: json['attendance_date'] as String,
      attendanceStatus: json['attendance_status'] as String,
      attendanceSource: json['attendance_source'] as String? ?? 'MANUAL',
      attendanceReason: json['attendance_reason'] as String? ?? 'UNKNOWN',
      remarks: json['remarks'] as String?,
      parentViewed: json['parent_viewed'] as bool? ?? false,
      parentViewedAt: json['parent_viewed_at'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      settings: Map<String, dynamic>.from(json['settings'] as Map? ?? {}),
      aiMetrics: Map<String, dynamic>.from(json['ai_metrics'] as Map? ?? {}),
      version: json['version'] as int? ?? 1,
      studentRollNumber: roll,
      studentName: name,
    );
  }

  List<AttendanceAuditEntryDto> get auditLogs {
    final list = settings['audit_logs'] as List? ?? [];
    return list.map((e) => AttendanceAuditEntryDto.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }
}

class AttendanceAuditEntryDto {
  final String previousStatus;
  final String newStatus;
  final String updatedBy;
  final String updatedAt;
  final String reasonForChange;

  const AttendanceAuditEntryDto({
    required this.previousStatus,
    required this.newStatus,
    required this.updatedBy,
    required this.updatedAt,
    required this.reasonForChange,
  });

  factory AttendanceAuditEntryDto.fromJson(Map<String, dynamic> json) {
    return AttendanceAuditEntryDto(
      previousStatus: json['previous_status'] as String? ?? '',
      newStatus: json['new_status'] as String? ?? '',
      updatedBy: json['updated_by'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      reasonForChange: json['reason_for_change'] as String? ?? '',
    );
  }
}
