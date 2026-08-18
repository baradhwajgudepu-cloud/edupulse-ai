enum ExamResult {
  PRESENT,
  ABSENT,
  MALPRACTICE,
  EXEMPTED,
}

enum MarksStatus {
  DRAFT,
  PUBLISHED,
  LOCKED,
}

class StudentMarkEntity {
  final String id;
  final String tenantId;
  final String schoolId;
  final String academicYearId;
  final String examinationId;
  final String examScheduleId;
  final String studentId;
  final String teacherSubjectAssignmentId;
  final String teacherId;
  final String subjectId;
  final String classId;
  final String sectionId;
  final int maximumMarks;
  final double? marksObtained;
  final ExamResult resultStatus;
  final MarksStatus status;
  final String? grade;
  final String? remarks;
  final Map<String, dynamic> settings;
  final Map<String, dynamic> aiMetrics;
  final List<dynamic> auditHistory;
  final bool isActive;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudentMarkEntity({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.academicYearId,
    required this.examinationId,
    required this.examScheduleId,
    required this.studentId,
    required this.teacherSubjectAssignmentId,
    required this.teacherId,
    required this.subjectId,
    required this.classId,
    required this.sectionId,
    required this.maximumMarks,
    this.marksObtained,
    required this.resultStatus,
    required this.status,
    this.grade,
    this.remarks,
    required this.settings,
    required this.aiMetrics,
    required this.auditHistory,
    required this.isActive,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });
}
