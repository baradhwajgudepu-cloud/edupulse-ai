class AttendanceSessionDto {
  final String id;
  final String tenantId;
  final String schoolId;
  final String academicYearId;
  final String? timetableId;
  final String sessionType;
  final String classId;
  final String sectionId;
  final String? teacherId;
  final String? subjectId;
  final String attendanceDate;
  final String status;
  final String? markedBy;
  final String? markedByName;
  final String? markedAt;
  final bool isActive;
  final Map<String, dynamic> settings;
  final int version;
  final String? className;
  final String? sectionName;
  final List<AttendanceLogDto> attendances;

  const AttendanceSessionDto({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.academicYearId,
    this.timetableId,
    this.sessionType = 'FULL_DAY',
    required this.classId,
    required this.sectionId,
    this.teacherId,
    this.subjectId,
    required this.attendanceDate,
    required this.status,
    this.markedBy,
    this.markedByName,
    this.markedAt,
    required this.isActive,
    required this.settings,
    required this.version,
    this.className,
    this.sectionName,
    required this.attendances,
  });

  factory AttendanceSessionDto.fromJson(Map<String, dynamic> json) {
    return AttendanceSessionDto(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      schoolId: json['school_id'] as String? ?? '',
      academicYearId: json['academic_year_id'] as String? ?? '',
      timetableId: json['timetable_id'] as String?,
      sessionType: json['session_type'] as String? ?? 'FULL_DAY',
      classId: json['class_id'] as String? ?? '',
      sectionId: json['section_id'] as String? ?? '',
      teacherId: json['teacher_id'] as String?,
      subjectId: json['subject_id'] as String?,
      attendanceDate: json['attendance_date'] as String? ?? '',
      status: json['status'] as String? ?? 'DRAFT',
      markedBy: json['marked_by'] as String?,
      markedByName: json['marked_by_name'] as String?,
      markedAt: json['marked_at'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      settings: Map<String, dynamic>.from(json['settings'] as Map? ?? {}),
      version: json['version'] as int? ?? 1,
      className: json['class_name'] as String?,
      sectionName: json['section_name'] as String?,
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
  final String? timetableId;
  final String sessionType;
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
  final String? admissionNumber;
  final String? className;
  final String? sectionName;
  final String? markedByName;

  const AttendanceLogDto({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.academicYearId,
    required this.attendanceSessionId,
    required this.studentId,
    this.timetableId,
    this.sessionType = 'FULL_DAY',
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
    this.admissionNumber,
    this.className,
    this.sectionName,
    this.markedByName,
  });

  factory AttendanceLogDto.fromJson(Map<String, dynamic> json) {
    String? roll = json['roll_number'] as String?;
    String? name = json['student_name'] as String?;
    String? adm = json['admission_number'] as String?;
    if (json['student'] != null) {
      final student = json['student'] as Map;
      roll ??= student['roll_number'] as String?;
      adm ??= student['admission_number'] as String?;
      name ??= '${student['first_name'] ?? ""} ${student['last_name'] ?? ""}'.trim();
    }
    return AttendanceLogDto(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      schoolId: json['school_id'] as String? ?? '',
      academicYearId: json['academic_year_id'] as String? ?? '',
      attendanceSessionId: json['attendance_session_id'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      timetableId: json['timetable_id'] as String?,
      sessionType: json['session_type'] as String? ?? 'FULL_DAY',
      classId: json['class_id'] as String? ?? '',
      sectionId: json['section_id'] as String? ?? '',
      teacherId: json['teacher_id'] as String?,
      subjectId: json['subject_id'] as String?,
      attendanceDate: json['attendance_date'] as String? ?? '',
      attendanceStatus: json['attendance_status'] as String? ?? 'ABSENT',
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
      admissionNumber: adm,
      className: json['class_name'] as String?,
      sectionName: json['section_name'] as String?,
      markedByName: json['marked_by_name'] as String?,
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

class AttendanceAuditLogDto {
  final String id;
  final String tenantId;
  final String schoolId;
  final String? attendanceId;
  final String studentId;
  final String? studentName;
  final String? admissionNumber;
  final String? className;
  final String? sectionName;
  final String attendanceDate;
  final String sessionType;
  final String? oldStatus;
  final String newStatus;
  final String action;
  final String? changedBy;
  final String? changedByName;
  final String? changedByRole;
  final String timestamp;
  final String source;
  final String? reason;

  const AttendanceAuditLogDto({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    this.attendanceId,
    required this.studentId,
    this.studentName,
    this.admissionNumber,
    this.className,
    this.sectionName,
    required this.attendanceDate,
    required this.sessionType,
    this.oldStatus,
    required this.newStatus,
    required this.action,
    this.changedBy,
    this.changedByName,
    this.changedByRole,
    required this.timestamp,
    required this.source,
    this.reason,
  });

  factory AttendanceAuditLogDto.fromJson(Map<String, dynamic> json) {
    return AttendanceAuditLogDto(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      attendanceId: json['attendance_id'] as String?,
      studentId: json['student_id'] as String,
      studentName: json['student_name'] as String?,
      admissionNumber: json['admission_number'] as String?,
      className: json['class_name'] as String?,
      sectionName: json['section_name'] as String?,
      attendanceDate: json['attendance_date'] as String,
      sessionType: json['session_type'] as String? ?? 'FULL_DAY',
      oldStatus: json['old_status'] as String?,
      newStatus: json['new_status'] as String,
      action: json['action'] as String,
      changedBy: json['changed_by'] as String?,
      changedByName: json['changed_by_name'] as String?,
      changedByRole: json['changed_by_role'] as String?,
      timestamp: json['timestamp'] as String,
      source: json['source'] as String? ?? 'MANUAL',
      reason: json['reason'] as String?,
    );
  }
}

class AttendanceDashboardStatsDto {
  final String attendanceDate;
  final double attendancePercentage;
  final int totalStudents;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int excusedCount;
  final int halfDayCount;
  final int classesMarked;
  final int classesPending;
  final List<Map<String, dynamic>> dailyTrend;
  final List<Map<String, dynamic>> classWiseStats;
  final double monthlyPercentage;
  final List<Map<String, dynamic>> lowAttendanceStudents;

  const AttendanceDashboardStatsDto({
    required this.attendanceDate,
    required this.attendancePercentage,
    required this.totalStudents,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.excusedCount,
    required this.halfDayCount,
    required this.classesMarked,
    required this.classesPending,
    required this.dailyTrend,
    required this.classWiseStats,
    required this.monthlyPercentage,
    required this.lowAttendanceStudents,
  });

  factory AttendanceDashboardStatsDto.fromJson(Map<String, dynamic> json) {
    return AttendanceDashboardStatsDto(
      attendanceDate: json['attendance_date'] as String? ?? '',
      attendancePercentage: (json['attendance_percentage'] as num?)?.toDouble() ?? 0.0,
      totalStudents: json['total_students'] as int? ?? 0,
      presentCount: json['present_count'] as int? ?? 0,
      absentCount: json['absent_count'] as int? ?? 0,
      lateCount: json['late_count'] as int? ?? 0,
      excusedCount: json['excused_count'] as int? ?? 0,
      halfDayCount: json['half_day_count'] as int? ?? 0,
      classesMarked: json['classes_marked'] as int? ?? 0,
      classesPending: json['classes_pending'] as int? ?? 0,
      dailyTrend: (json['daily_trend'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      classWiseStats: (json['class_wise_stats'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      monthlyPercentage: (json['monthly_percentage'] as num?)?.toDouble() ?? 0.0,
      lowAttendanceStudents: (json['low_attendance_students'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }
}

class AttendanceAlertDto {
  final String alertType;
  final String severity;
  final String title;
  final String message;
  final String? entityId;
  final Map<String, dynamic> details;

  const AttendanceAlertDto({
    required this.alertType,
    required this.severity,
    required this.title,
    required this.message,
    this.entityId,
    required this.details,
  });

  factory AttendanceAlertDto.fromJson(Map<String, dynamic> json) {
    return AttendanceAlertDto(
      alertType: json['alert_type'] as String? ?? 'INFO',
      severity: json['severity'] as String? ?? 'MEDIUM',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      entityId: json['entity_id'] as String?,
      details: Map<String, dynamic>.from(json['details'] as Map? ?? {}),
    );
  }
}

class BulkValidateRowPreviewDto {
  final int rowNumber;
  final String? admissionNumber;
  final String? studentName;
  final String? className;
  final String? sectionName;
  final String? attendanceDate;
  final String? session;
  final String? status;
  final String validationStatus;
  final String? errorMessage;
  final String? conflictExistingStatus;

  const BulkValidateRowPreviewDto({
    required this.rowNumber,
    this.admissionNumber,
    this.studentName,
    this.className,
    this.sectionName,
    this.attendanceDate,
    this.session,
    this.status,
    required this.validationStatus,
    this.errorMessage,
    this.conflictExistingStatus,
  });

  factory BulkValidateRowPreviewDto.fromJson(Map<String, dynamic> json) {
    return BulkValidateRowPreviewDto(
      rowNumber: json['row_number'] as int? ?? 0,
      admissionNumber: json['admission_number'] as String?,
      studentName: json['student_name'] as String?,
      className: json['class_name'] as String?,
      sectionName: json['section_name'] as String?,
      attendanceDate: json['attendance_date'] as String?,
      session: json['session'] as String?,
      status: json['status'] as String?,
      validationStatus: json['validation_status'] as String? ?? 'VALID',
      errorMessage: json['error_message'] as String?,
      conflictExistingStatus: json['conflict_existing_status'] as String?,
    );
  }
}

class BulkAttendanceValidateDto {
  final String jobId;
  final String filename;
  final int totalRows;
  final int validRows;
  final int invalidRows;
  final int duplicateRows;
  final int conflictRows;
  final List<BulkValidateRowPreviewDto> previewRows;
  final List<String> errors;

  const BulkAttendanceValidateDto({
    required this.jobId,
    required this.filename,
    required this.totalRows,
    required this.validRows,
    required this.invalidRows,
    required this.duplicateRows,
    required this.conflictRows,
    required this.previewRows,
    required this.errors,
  });

  factory BulkAttendanceValidateDto.fromJson(Map<String, dynamic> json) {
    return BulkAttendanceValidateDto(
      jobId: json['job_id'] as String,
      filename: json['filename'] as String? ?? 'attendance.csv',
      totalRows: json['total_rows'] as int? ?? 0,
      validRows: json['valid_rows'] as int? ?? 0,
      invalidRows: json['invalid_rows'] as int? ?? 0,
      duplicateRows: json['duplicate_rows'] as int? ?? 0,
      conflictRows: json['conflict_rows'] as int? ?? 0,
      previewRows: (json['preview_rows'] as List? ?? [])
          .map((e) => BulkValidateRowPreviewDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      errors: (json['errors'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }
}

class BulkAttendanceImportResponseDto {
  final String jobId;
  final String status;
  final int totalRows;
  final int importedRows;
  final int skippedRows;
  final int failedRows;
  final int conflictRows;
  final String message;

  const BulkAttendanceImportResponseDto({
    required this.jobId,
    required this.status,
    required this.totalRows,
    required this.importedRows,
    required this.skippedRows,
    required this.failedRows,
    required this.conflictRows,
    required this.message,
  });

  factory BulkAttendanceImportResponseDto.fromJson(Map<String, dynamic> json) {
    return BulkAttendanceImportResponseDto(
      jobId: json['job_id'] as String,
      status: json['status'] as String? ?? 'COMPLETED',
      totalRows: json['total_rows'] as int? ?? 0,
      importedRows: json['imported_rows'] as int? ?? 0,
      skippedRows: json['skipped_rows'] as int? ?? 0,
      failedRows: json['failed_rows'] as int? ?? 0,
      conflictRows: json['conflict_rows'] as int? ?? 0,
      message: json['message'] as String? ?? '',
    );
  }
}

class AttendanceImportJobDto {
  final String id;
  final String tenantId;
  final String schoolId;
  final String filename;
  final String status;
  final int totalRows;
  final int successfulRows;
  final int failedRows;
  final int skippedRows;
  final String? dateRange;
  final String? uploadedBy;
  final String? uploadedByName;
  final String? uploadedByRole;
  final String createdAt;
  final String? completedAt;
  final String? errorSummary;

  const AttendanceImportJobDto({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.filename,
    required this.status,
    required this.totalRows,
    required this.successfulRows,
    required this.failedRows,
    required this.skippedRows,
    this.dateRange,
    this.uploadedBy,
    this.uploadedByName,
    this.uploadedByRole,
    required this.createdAt,
    this.completedAt,
    this.errorSummary,
  });

  factory AttendanceImportJobDto.fromJson(Map<String, dynamic> json) {
    return AttendanceImportJobDto(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      filename: json['filename'] as String? ?? 'attendance_upload.csv',
      status: json['status'] as String? ?? 'COMPLETED',
      totalRows: json['total_rows'] as int? ?? 0,
      successfulRows: json['successful_rows'] as int? ?? 0,
      failedRows: json['failed_rows'] as int? ?? 0,
      skippedRows: json['skipped_rows'] as int? ?? 0,
      dateRange: json['date_range'] as String?,
      uploadedBy: json['uploaded_by'] as String?,
      uploadedByName: json['uploaded_by_name'] as String?,
      uploadedByRole: json['uploaded_by_role'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      completedAt: json['completed_at'] as String?,
      errorSummary: json['error_summary']?.toString(),
    );
  }
}

class StudentRosterItem {
  final String studentId;
  final String studentName;
  final String admissionNumber;
  final String rollNumber;
  String status; // PRESENT, ABSENT, LATE, HALF_DAY, EXCUSED
  String reason; // SICK, PERSONAL, SPORTS, OFFICIAL, UNKNOWN
  String remarks;
  bool isSelected;

  StudentRosterItem({
    required this.studentId,
    required this.studentName,
    required this.admissionNumber,
    required this.rollNumber,
    this.status = 'PRESENT',
    this.reason = 'UNKNOWN',
    this.remarks = '',
    this.isSelected = false,
  });

  StudentRosterItem copyWith({
    String? status,
    String? reason,
    String? remarks,
    bool? isSelected,
  }) {
    return StudentRosterItem(
      studentId: studentId,
      studentName: studentName,
      admissionNumber: admissionNumber,
      rollNumber: rollNumber,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      remarks: remarks ?? this.remarks,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
