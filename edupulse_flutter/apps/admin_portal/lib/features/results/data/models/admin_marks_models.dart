import 'package:flutter/foundation.dart';

enum AdminMarkResultStatus {
  present,
  absent,
  exempted,
  malpractice;

  String toBackendValue() {
    switch (this) {
      case AdminMarkResultStatus.present:
        return 'PRESENT';
      case AdminMarkResultStatus.absent:
        return 'ABSENT';
      case AdminMarkResultStatus.exempted:
        return 'EXEMPTED';
      case AdminMarkResultStatus.malpractice:
        return 'MALPRACTICE';
    }
  }

  static AdminMarkResultStatus fromBackendValue(String? val) {
    switch ((val ?? '').toUpperCase()) {
      case 'ABSENT':
        return AdminMarkResultStatus.absent;
      case 'EXEMPTED':
        return AdminMarkResultStatus.exempted;
      case 'MALPRACTICE':
        return AdminMarkResultStatus.malpractice;
      case 'PRESENT':
      default:
        return AdminMarkResultStatus.present;
    }
  }
}

enum AdminMarkStatus {
  draft,
  submitted,
  approved,
  published,
  locked;

  String toBackendValue() {
    switch (this) {
      case AdminMarkStatus.draft:
        return 'DRAFT';
      case AdminMarkStatus.submitted:
        return 'SUBMITTED';
      case AdminMarkStatus.approved:
        return 'APPROVED';
      case AdminMarkStatus.published:
        return 'PUBLISHED';
      case AdminMarkStatus.locked:
        return 'LOCKED';
    }
  }

  static AdminMarkStatus fromBackendValue(String? val) {
    switch ((val ?? '').toUpperCase()) {
      case 'SUBMITTED':
        return AdminMarkStatus.submitted;
      case 'APPROVED':
        return AdminMarkStatus.approved;
      case 'PUBLISHED':
        return AdminMarkStatus.published;
      case 'LOCKED':
        return AdminMarkStatus.locked;
      case 'DRAFT':
      default:
        return AdminMarkStatus.draft;
    }
  }
}

@immutable
class MarksAuditEntry {
  final double? oldMarks;
  final double? newMarks;
  final String? reason;
  final String? action;
  final String updatedBy;
  final DateTime? updatedAt;

  const MarksAuditEntry({
    this.oldMarks,
    this.newMarks,
    this.reason,
    this.action,
    required this.updatedBy,
    this.updatedAt,
  });

  factory MarksAuditEntry.fromJson(Map<String, dynamic> json) {
    return MarksAuditEntry(
      oldMarks: (json['old_marks'] is num) ? (json['old_marks'] as num).toDouble() : null,
      newMarks: (json['new_marks'] is num) ? (json['new_marks'] as num).toDouble() : null,
      reason: json['reason'] as String?,
      action: json['action'] as String?,
      updatedBy: (json['updated_by'] ?? 'System Admin').toString(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }
}

@immutable
class AdminExamScheduleOption {
  final String id;
  final String examId;
  final String examName;
  final String classId;
  final String className;
  final String? sectionId;
  final String? sectionName;
  final String subjectId;
  final String subjectName;
  final String subjectCode;
  final int maxMarks;
  final int passMarks;
  final String? paperDate;
  final String? startTime;
  final String? endTime;

  const AdminExamScheduleOption({
    required this.id,
    required this.examId,
    required this.examName,
    required this.classId,
    required this.className,
    this.sectionId,
    this.sectionName,
    required this.subjectId,
    required this.subjectName,
    required this.subjectCode,
    required this.maxMarks,
    required this.passMarks,
    this.paperDate,
    this.startTime,
    this.endTime,
  });

  factory AdminExamScheduleOption.fromJson(Map<String, dynamic> json) {
    final sub = json['subject'] as Map<String, dynamic>?;
    final cls = json['class_entity'] as Map<String, dynamic>? ?? json['class'] as Map<String, dynamic>? ?? json['class_obj'] as Map<String, dynamic>?;
    final sec = json['section'] as Map<String, dynamic>?;
    final ex = json['examination'] as Map<String, dynamic>?;

    final rawSubjectName = sub?['subject_name'] ?? sub?['name'] ?? json['subject_name'];
    final rawSubjectCode = sub?['subject_code'] ?? sub?['code'] ?? json['subject_code'];
    final rawClassName = cls?['name'] ?? json['class_name'];
    final rawSectionName = sec?['name'] ?? json['section_name'];
    final rawExamName = ex?['exam_name'] ?? ex?['name'] ?? json['exam_name'];

    return AdminExamScheduleOption(
      id: (json['id'] ?? '').toString(),
      examId: (json['examination_id'] ?? json['exam_id'] ?? '').toString(),
      examName: (rawExamName ?? 'Exam').toString(),
      classId: (json['class_id'] ?? '').toString(),
      className: (rawClassName ?? 'Class').toString(),
      sectionId: json['section_id']?.toString(),
      sectionName: rawSectionName?.toString(),
      subjectId: (json['subject_id'] ?? '').toString(),
      subjectName: (rawSubjectName ?? 'Unknown Subject').toString(),
      subjectCode: (rawSubjectCode ?? '').toString(),
      maxMarks: (json['max_marks'] is num) ? (json['max_marks'] as num).toInt() : 100,
      passMarks: (json['pass_marks'] is num) ? (json['pass_marks'] as num).toInt() : 35,
      paperDate: json['paper_date']?.toString() ?? json['exam_date']?.toString(),
      startTime: json['start_time']?.toString(),
      endTime: json['end_time']?.toString(),
    );
  }
}

@immutable
class AdminStudentMarkRow {
  final String studentId;
  final String firstName;
  final String lastName;
  final String rollNumber;
  final int maxMarks;
  final double? marksObtained;
  final AdminMarkResultStatus resultStatus;
  final AdminMarkStatus status;
  final String? remarks;
  final String? overrideReason;
  final List<MarksAuditEntry> auditHistory;
  final bool isModified;
  final String? validationError;

  const AdminStudentMarkRow({
    required this.studentId,
    required this.firstName,
    required this.lastName,
    required this.rollNumber,
    required this.maxMarks,
    this.marksObtained,
    this.resultStatus = AdminMarkResultStatus.present,
    this.status = AdminMarkStatus.draft,
    this.remarks,
    this.overrideReason,
    this.auditHistory = const [],
    this.isModified = false,
    this.validationError,
  });

  String get fullName => '$firstName $lastName'.trim();

  AdminStudentMarkRow copyWith({
    double? marksObtained,
    bool clearMarks = false,
    AdminMarkResultStatus? resultStatus,
    AdminMarkStatus? status,
    String? remarks,
    String? overrideReason,
    List<MarksAuditEntry>? auditHistory,
    bool? isModified,
    String? validationError,
    bool clearError = false,
  }) {
    return AdminStudentMarkRow(
      studentId: studentId,
      firstName: firstName,
      lastName: lastName,
      rollNumber: rollNumber,
      maxMarks: maxMarks,
      marksObtained: clearMarks ? null : (marksObtained ?? this.marksObtained),
      resultStatus: resultStatus ?? this.resultStatus,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      overrideReason: overrideReason ?? this.overrideReason,
      auditHistory: auditHistory ?? this.auditHistory,
      isModified: isModified ?? this.isModified,
      validationError: clearError ? null : (validationError ?? this.validationError),
    );
  }
}

@immutable
class AdminMarksBoardState {
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final String? successMessage;
  final String? activeScheduleId;
  final AdminExamScheduleOption? activeSchedule;
  final List<AdminStudentMarkRow> rows;
  final bool hasUnsavedChanges;

  const AdminMarksBoardState({
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.successMessage,
    this.activeScheduleId,
    this.activeSchedule,
    this.rows = const [],
    this.hasUnsavedChanges = false,
  });

  int get totalStudents => rows.length;

  int get enteredCount => rows.where((r) =>
      (r.resultStatus == AdminMarkResultStatus.present && r.marksObtained != null) ||
      r.resultStatus == AdminMarkResultStatus.absent ||
      r.resultStatus == AdminMarkResultStatus.exempted ||
      r.resultStatus == AdminMarkResultStatus.malpractice
  ).length;

  int get missingCount => totalStudents - enteredCount;

  double get classAverage {
    final validScores = rows
        .where((r) => r.resultStatus == AdminMarkResultStatus.present && r.marksObtained != null)
        .map((r) => r.marksObtained!)
        .toList();
    if (validScores.isEmpty) return 0.0;
    final sum = validScores.reduce((a, b) => a + b);
    return double.parse((sum / validScores.length).toStringAsFixed(1));
  }

  double get highestMarks {
    final validScores = rows
        .where((r) => r.resultStatus == AdminMarkResultStatus.present && r.marksObtained != null)
        .map((r) => r.marksObtained!)
        .toList();
    if (validScores.isEmpty) return 0.0;
    return validScores.reduce((a, b) => a > b ? a : b);
  }

  double get lowestMarks {
    final validScores = rows
        .where((r) => r.resultStatus == AdminMarkResultStatus.present && r.marksObtained != null)
        .map((r) => r.marksObtained!)
        .toList();
    if (validScores.isEmpty) return 0.0;
    return validScores.reduce((a, b) => a < b ? a : b);
  }

  AdminMarksBoardState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
    String? activeScheduleId,
    AdminExamScheduleOption? activeSchedule,
    List<AdminStudentMarkRow>? rows,
    bool? hasUnsavedChanges,
  }) {
    return AdminMarksBoardState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      activeScheduleId: activeScheduleId ?? this.activeScheduleId,
      activeSchedule: activeSchedule ?? this.activeSchedule,
      rows: rows ?? this.rows,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
    );
  }
}

@immutable
class ExamWideUploadRowModel {
  final int rowNumber;
  final String className;
  final String sectionName;
  final String rollNumber;
  final String? studentName;
  final String subjectName;
  final int maxMarks;
  final double? marksObtained;
  final String status;
  final String? remarks;
  final bool isValid;
  final String? errorMessage;
  final String? studentId;
  final String? examScheduleId;
  final String? classId;
  final String? sectionId;
  final String? subjectId;

  const ExamWideUploadRowModel({
    required this.rowNumber,
    required this.className,
    required this.sectionName,
    required this.rollNumber,
    this.studentName,
    required this.subjectName,
    required this.maxMarks,
    this.marksObtained,
    required this.status,
    this.remarks,
    required this.isValid,
    this.errorMessage,
    this.studentId,
    this.examScheduleId,
    this.classId,
    this.sectionId,
    this.subjectId,
  });

  factory ExamWideUploadRowModel.fromJson(Map<String, dynamic> json) {
    return ExamWideUploadRowModel(
      rowNumber: (json['row_number'] is num) ? (json['row_number'] as num).toInt() : 0,
      className: (json['class_name'] ?? '').toString(),
      sectionName: (json['section_name'] ?? '').toString(),
      rollNumber: (json['roll_number'] ?? '').toString(),
      studentName: json['student_name']?.toString(),
      subjectName: (json['subject_name'] ?? '').toString(),
      maxMarks: (json['max_marks'] is num) ? (json['max_marks'] as num).toInt() : 100,
      marksObtained: (json['marks_obtained'] is num) ? (json['marks_obtained'] as num).toDouble() : null,
      status: (json['status'] ?? 'PRESENT').toString(),
      remarks: json['remarks']?.toString(),
      isValid: json['is_valid'] == true,
      errorMessage: json['error_message']?.toString(),
      studentId: json['student_id']?.toString(),
      examScheduleId: json['exam_schedule_id']?.toString(),
      classId: json['class_id']?.toString(),
      sectionId: json['section_id']?.toString(),
      subjectId: json['subject_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'row_number': rowNumber,
      'class_name': className,
      'section_name': sectionName,
      'roll_number': rollNumber,
      if (studentName != null) 'student_name': studentName,
      'subject_name': subjectName,
      'max_marks': maxMarks,
      if (marksObtained != null) 'marks_obtained': marksObtained,
      'status': status,
      if (remarks != null) 'remarks': remarks,
      'is_valid': isValid,
      if (errorMessage != null) 'error_message': errorMessage,
      if (studentId != null) 'student_id': studentId,
      if (examScheduleId != null) 'exam_schedule_id': examScheduleId,
      if (classId != null) 'class_id': classId,
      if (sectionId != null) 'section_id': sectionId,
      if (subjectId != null) 'subject_id': subjectId,
    };
  }
}

@immutable
class ExamWideUploadPreviewModel {
  final int totalRows;
  final int validRowsCount;
  final int invalidRowsCount;
  final List<String> classesDetected;
  final List<String> sectionsDetected;
  final List<String> subjectsDetected;
  final int studentsCount;
  final List<String> errors;
  final List<ExamWideUploadRowModel> previewRows;

  const ExamWideUploadPreviewModel({
    required this.totalRows,
    required this.validRowsCount,
    required this.invalidRowsCount,
    required this.classesDetected,
    required this.sectionsDetected,
    required this.subjectsDetected,
    required this.studentsCount,
    required this.errors,
    required this.previewRows,
  });

  factory ExamWideUploadPreviewModel.fromJson(Map<String, dynamic> json) {
    return ExamWideUploadPreviewModel(
      totalRows: (json['total_rows'] is num) ? (json['total_rows'] as num).toInt() : 0,
      validRowsCount: (json['valid_rows_count'] is num) ? (json['valid_rows_count'] as num).toInt() : 0,
      invalidRowsCount: (json['invalid_rows_count'] is num) ? (json['invalid_rows_count'] as num).toInt() : 0,
      classesDetected: (json['classes_detected'] as List?)?.map((e) => e.toString()).toList() ?? [],
      sectionsDetected: (json['sections_detected'] as List?)?.map((e) => e.toString()).toList() ?? [],
      subjectsDetected: (json['subjects_detected'] as List?)?.map((e) => e.toString()).toList() ?? [],
      studentsCount: (json['students_count'] is num) ? (json['students_count'] as num).toInt() : 0,
      errors: (json['errors'] as List?)?.map((e) => e.toString()).toList() ?? [],
      previewRows: (json['preview_rows'] as List?)
          ?.map((e) => ExamWideUploadRowModel.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}

@immutable
class ExamWideUploadResultModel {
  final String examinationId;
  final String examinationName;
  final int studentsProcessed;
  final int classesCount;
  final int sectionsCount;
  final int subjectsCount;
  final int totalRecords;
  final int savedCount;
  final int failedCount;

  const ExamWideUploadResultModel({
    required this.examinationId,
    required this.examinationName,
    required this.studentsProcessed,
    required this.classesCount,
    required this.sectionsCount,
    required this.subjectsCount,
    required this.totalRecords,
    required this.savedCount,
    required this.failedCount,
  });

  factory ExamWideUploadResultModel.fromJson(Map<String, dynamic> json) {
    return ExamWideUploadResultModel(
      examinationId: (json['examination_id'] ?? '').toString(),
      examinationName: (json['examination_name'] ?? 'Examination').toString(),
      studentsProcessed: (json['students_processed'] is num) ? (json['students_processed'] as num).toInt() : 0,
      classesCount: (json['classes_count'] is num) ? (json['classes_count'] as num).toInt() : 0,
      sectionsCount: (json['sections_count'] is num) ? (json['sections_count'] as num).toInt() : 0,
      subjectsCount: (json['subjects_count'] is num) ? (json['subjects_count'] as num).toInt() : 0,
      totalRecords: (json['total_records'] is num) ? (json['total_records'] as num).toInt() : 0,
      savedCount: (json['saved_count'] is num) ? (json['saved_count'] as num).toInt() : 0,
      failedCount: (json['failed_count'] is num) ? (json['failed_count'] as num).toInt() : 0,
    );
  }
}

@immutable
class ExaminationMissingBreakdownModel {
  final String className;
  final String sectionName;
  final String subjectName;
  final String classId;
  final String sectionId;
  final String scheduleId;
  final int missingCount;
  final int expectedCount;
  final int enteredCount;

  const ExaminationMissingBreakdownModel({
    required this.className,
    required this.sectionName,
    required this.subjectName,
    required this.classId,
    required this.sectionId,
    required this.scheduleId,
    required this.missingCount,
    required this.expectedCount,
    required this.enteredCount,
  });

  factory ExaminationMissingBreakdownModel.fromJson(Map<String, dynamic> json) {
    return ExaminationMissingBreakdownModel(
      className: (json['class_name'] ?? 'Class').toString(),
      sectionName: (json['section_name'] ?? 'Section').toString(),
      subjectName: (json['subject_name'] ?? 'Subject').toString(),
      classId: (json['class_id'] ?? '').toString(),
      sectionId: (json['section_id'] ?? '').toString(),
      scheduleId: (json['schedule_id'] ?? '').toString(),
      missingCount: (json['missing_count'] is num) ? (json['missing_count'] as num).toInt() : 0,
      expectedCount: (json['expected_count'] is num) ? (json['expected_count'] as num).toInt() : 0,
      enteredCount: (json['entered_count'] is num) ? (json['entered_count'] as num).toInt() : 0,
    );
  }
}

@immutable
class ExaminationPublishSummaryModel {
  final String examinationId;
  final String examinationName;
  final int totalExpectedRecords;
  final int marksEnteredCount;
  final int publishedCount;
  final int missingCount;
  final bool isFullyPublished;
  final List<ExaminationMissingBreakdownModel> missingBreakdown;

  const ExaminationPublishSummaryModel({
    required this.examinationId,
    required this.examinationName,
    required this.totalExpectedRecords,
    required this.marksEnteredCount,
    required this.publishedCount,
    required this.missingCount,
    required this.isFullyPublished,
    required this.missingBreakdown,
  });

  factory ExaminationPublishSummaryModel.fromJson(Map<String, dynamic> json) {
    return ExaminationPublishSummaryModel(
      examinationId: (json['examination_id'] ?? '').toString(),
      examinationName: (json['examination_name'] ?? 'Examination').toString(),
      totalExpectedRecords: (json['total_expected_records'] is num) ? (json['total_expected_records'] as num).toInt() : 0,
      marksEnteredCount: (json['marks_entered_count'] is num) ? (json['marks_entered_count'] as num).toInt() : 0,
      publishedCount: (json['published_count'] is num) ? (json['published_count'] as num).toInt() : 0,
      missingCount: (json['missing_count'] is num) ? (json['missing_count'] as num).toInt() : 0,
      isFullyPublished: json['is_fully_published'] == true,
      missingBreakdown: (json['missing_breakdown'] as List?)
          ?.map((e) => ExaminationMissingBreakdownModel.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}
