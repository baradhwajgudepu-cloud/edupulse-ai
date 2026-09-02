import 'package:flutter/foundation.dart';

@immutable
class ExaminationDto {
  final String id;
  final String tenantId;
  final String schoolId;
  final String academicYearId;
  final String examName;
  final String examType;
  final String status;
  final String startDate;
  final String endDate;
  final String? description;

  const ExaminationDto({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.academicYearId,
    required this.examName,
    required this.examType,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.description,
  });

  factory ExaminationDto.fromJson(Map<String, dynamic> json) {
    return ExaminationDto(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      academicYearId: json['academic_year_id'] as String,
      examName: json['exam_name'] as String,
      examType: json['exam_type'] as String,
      status: json['status'] as String,
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
      description: json['description'] as String?,
    );
  }
}

@immutable
class ReportCardDto {
  final String id;
  final String verificationUuid;
  final String status;
  final String? pdfUrl;
  final List<dynamic> pdfHistory;
  final String? generatedAt;
  final String? publishedAt;
  final String? approvedAt;
  final String tenantId;
  final String schoolId;
  final String academicYearId;
  final String studentId;
  final Map<String, dynamic> aiMetrics;

  const ReportCardDto({
    required this.id,
    required this.verificationUuid,
    required this.status,
    this.pdfUrl,
    required this.pdfHistory,
    this.generatedAt,
    this.publishedAt,
    this.approvedAt,
    required this.tenantId,
    required this.schoolId,
    required this.academicYearId,
    required this.studentId,
    required this.aiMetrics,
  });

  factory ReportCardDto.fromJson(Map<String, dynamic> json) {
    return ReportCardDto(
      id: json['id'] as String,
      verificationUuid: json['verification_uuid'] as String,
      status: json['status'] as String,
      pdfUrl: json['pdf_url'] as String?,
      pdfHistory: json['pdf_history'] as List<dynamic>? ?? const [],
      generatedAt: json['generated_at'] as String?,
      publishedAt: json['published_at'] as String?,
      approvedAt: json['approved_at'] as String?,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      academicYearId: json['academic_year_id'] as String,
      studentId: json['student_id'] as String,
      aiMetrics: json['ai_metrics'] as Map<String, dynamic>? ?? const {},
    );
  }
}

@immutable
class ReportCardSubjectMarkRowDto {
  final String subjectName;
  final int maximumMarks;
  final double? marksObtained;
  final String resultStatus;
  final String grade;
  final String? remarks;

  const ReportCardSubjectMarkRowDto({
    required this.subjectName,
    required this.maximumMarks,
    this.marksObtained,
    required this.resultStatus,
    required this.grade,
    this.remarks,
  });

  factory ReportCardSubjectMarkRowDto.fromJson(Map<String, dynamic> json) {
    return ReportCardSubjectMarkRowDto(
      subjectName: json['subject_name'] as String,
      maximumMarks: json['maximum_marks'] as int,
      marksObtained: (json['marks_obtained'] as num?)?.toDouble(),
      resultStatus: json['result_status'] as String,
      grade: json['grade'] as String,
      remarks: json['remarks'] as String?,
    );
  }
}

@immutable
class ReportCardPreviewDto {
  final String studentId;
  final String studentName;
  final String admissionNumber;
  final String rollNumber;
  final String className;
  final String sectionName;
  final int attendanceTotal;
  final int attendancePresent;
  final double attendancePercentage;
  final double overallPercentage;
  final String overallGrade;
  final String promotionStatus;
  final List<ReportCardSubjectMarkRowDto> subjectMarks;
  final String? teacherRemarks;
  final String? principalRemarks;
  final String aiNarrative;
  final bool isValid;
  final List<String> missingReasons;

  const ReportCardPreviewDto({
    required this.studentId,
    required this.studentName,
    required this.admissionNumber,
    required this.rollNumber,
    required this.className,
    required this.sectionName,
    required this.attendanceTotal,
    required this.attendancePresent,
    required this.attendancePercentage,
    required this.overallPercentage,
    required this.overallGrade,
    required this.promotionStatus,
    required this.subjectMarks,
    this.teacherRemarks,
    this.principalRemarks,
    required this.aiNarrative,
    required this.isValid,
    required this.missingReasons,
  });

  factory ReportCardPreviewDto.fromJson(Map<String, dynamic> json) {
    final list = json['subject_marks'] as List<dynamic>? ?? const [];
    final marks = list.map((e) => ReportCardSubjectMarkRowDto.fromJson(e as Map<String, dynamic>)).toList();

    return ReportCardPreviewDto(
      studentId: json['student_id'] as String,
      studentName: json['student_name'] as String,
      admissionNumber: json['admission_number'] as String,
      rollNumber: json['roll_number'] as String,
      className: json['class_name'] as String,
      sectionName: json['section_name'] as String,
      attendanceTotal: json['attendance_total'] as int? ?? 0,
      attendancePresent: json['attendance_present'] as int? ?? 0,
      attendancePercentage: (json['attendance_percentage'] as num? ?? 0.0).toDouble(),
      overallPercentage: (json['overall_percentage'] as num? ?? 0.0).toDouble(),
      overallGrade: json['overall_grade'] as String? ?? 'F',
      promotionStatus: json['promotion_status'] as String? ?? 'DETAINED',
      subjectMarks: marks,
      teacherRemarks: json['teacher_remarks'] as String?,
      principalRemarks: json['principal_remarks'] as String?,
      aiNarrative: json['ai_narrative'] as String? ?? '',
      isValid: json['is_valid'] as bool? ?? false,
      missingReasons: (json['missing_reasons'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
    );
  }
}

@immutable
class StudentFailureDetailDto {
  final String studentId;
  final String studentName;
  final List<String> reasons;

  const StudentFailureDetailDto({
    required this.studentId,
    required this.studentName,
    required this.reasons,
  });

  factory StudentFailureDetailDto.fromJson(Map<String, dynamic> json) {
    return StudentFailureDetailDto(
      studentId: json['student_id'] as String,
      studentName: json['student_name'] as String,
      reasons: (json['reasons'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
    );
  }
}

@immutable
class BulkClassGenerateResponseDto {
  final int totalStudents;
  final int generatedCount;
  final int failedCount;
  final List<StudentFailureDetailDto> failures;

  const BulkClassGenerateResponseDto({
    required this.totalStudents,
    required this.generatedCount,
    required this.failedCount,
    required this.failures,
  });

  factory BulkClassGenerateResponseDto.fromJson(Map<String, dynamic> json) {
    final list = json['failures'] as List<dynamic>? ?? const [];
    final failedList = list.map((e) => StudentFailureDetailDto.fromJson(e as Map<String, dynamic>)).toList();
    return BulkClassGenerateResponseDto(
      totalStudents: json['total_students'] as int? ?? 0,
      generatedCount: json['generated_count'] as int? ?? 0,
      failedCount: json['failed_count'] as int? ?? 0,
      failures: failedList,
    );
  }
}

@immutable
class BulkReportCardActionResponseDto {
  final int totalRequested;
  final int successCount;
  final int failedCount;
  final List<StudentFailureDetailDto> failures;

  const BulkReportCardActionResponseDto({
    required this.totalRequested,
    required this.successCount,
    required this.failedCount,
    required this.failures,
  });

  factory BulkReportCardActionResponseDto.fromJson(Map<String, dynamic> json) {
    final list = json['failures'] as List<dynamic>? ?? const [];
    final failedList = list.map((e) => StudentFailureDetailDto.fromJson(e as Map<String, dynamic>)).toList();
    return BulkReportCardActionResponseDto(
      totalRequested: json['total_requested'] as int? ?? 0,
      successCount: json['success_count'] as int? ?? 0,
      failedCount: json['failed_count'] as int? ?? 0,
      failures: failedList,
    );
  }
}

@immutable
class VerificationResponseDto {
  final String studentName;
  final String rollNumber;
  final String className;
  final String sectionName;
  final String academicYear;
  final String status;
  final String verificationDate;
  final String? generatedAt;
  final String? publishedAt;
  final String? pdfUrl;

  const VerificationResponseDto({
    required this.studentName,
    required this.rollNumber,
    required this.className,
    required this.sectionName,
    required this.academicYear,
    required this.status,
    required this.verificationDate,
    this.generatedAt,
    this.publishedAt,
    this.pdfUrl,
  });

  factory VerificationResponseDto.fromJson(Map<String, dynamic> json) {
    return VerificationResponseDto(
      studentName: json['student_name'] as String? ?? '',
      rollNumber: json['roll_number'] as String? ?? '',
      className: json['class_name'] as String? ?? '',
      sectionName: json['section_name'] as String? ?? '',
      academicYear: json['academic_year'] as String? ?? '',
      status: json['status'] as String? ?? 'DRAFT',
      verificationDate: json['verification_date'] as String? ?? '',
      generatedAt: json['generated_at'] as String?,
      publishedAt: json['published_at'] as String?,
      pdfUrl: json['pdf_url'] as String?,
    );
  }
}

@immutable
class ExamSubjectMarkDto {
  final String subjectName;
  final int maxMarks;
  final double? marksObtained;
  final String grade;
  final String status;
  final String? remarks;

  const ExamSubjectMarkDto({
    required this.subjectName,
    required this.maxMarks,
    this.marksObtained,
    required this.grade,
    required this.status,
    this.remarks,
  });

  factory ExamSubjectMarkDto.fromJson(Map<String, dynamic> json) {
    return ExamSubjectMarkDto(
      subjectName: json['subject_name'] as String? ?? '',
      maxMarks: json['max_marks'] as int? ?? 100,
      marksObtained: (json['marks_obtained'] as num?)?.toDouble(),
      grade: json['grade'] as String? ?? 'F',
      status: json['status'] as String? ?? 'ABSENT',
      remarks: json['remarks'] as String?,
    );
  }
}

@immutable
class ExamHistorySummaryDto {
  final String examinationId;
  final String examinationName;
  final List<ExamSubjectMarkDto> subjectMarks;
  final int totalMaxMarks;
  final double totalObtainedMarks;
  final double percentage;
  final String grade;

  const ExamHistorySummaryDto({
    required this.examinationId,
    required this.examinationName,
    required this.subjectMarks,
    required this.totalMaxMarks,
    required this.totalObtainedMarks,
    required this.percentage,
    required this.grade,
  });

  factory ExamHistorySummaryDto.fromJson(Map<String, dynamic> json) {
    final list = json['subject_marks'] as List<dynamic>? ?? const [];
    final marks = list.map((e) => ExamSubjectMarkDto.fromJson(e as Map<String, dynamic>)).toList();

    return ExamHistorySummaryDto(
      examinationId: json['examination_id'] as String? ?? '',
      examinationName: json['examination_name'] as String? ?? '',
      subjectMarks: marks,
      totalMaxMarks: json['total_max_marks'] as int? ?? 0,
      totalObtainedMarks: (json['total_obtained_marks'] as num? ?? 0.0).toDouble(),
      percentage: (json['percentage'] as num? ?? 0.0).toDouble(),
      grade: json['grade'] as String? ?? 'F',
    );
  }
}

@immutable
class StudentAcademicHistoryDto {
  final String studentId;
  final String studentName;
  final String className;
  final String sectionName;
  final List<ExamHistorySummaryDto> examinations;

  const StudentAcademicHistoryDto({
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.sectionName,
    required this.examinations,
  });

  factory StudentAcademicHistoryDto.fromJson(Map<String, dynamic> json) {
    final list = json['examinations'] as List<dynamic>? ?? const [];
    final exams = list.map((e) => ExamHistorySummaryDto.fromJson(e as Map<String, dynamic>)).toList();

    return StudentAcademicHistoryDto(
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      className: json['class_name'] as String? ?? '',
      sectionName: json['section_name'] as String? ?? '',
      examinations: exams,
    );
  }
}

