import 'exam_schedule_entity.dart';

enum ExamType {
  UNIT_TEST,
  MONTHLY,
  QUARTERLY,
  HALF_YEARLY,
  PRE_FINAL,
  ANNUAL,
  SUPPLEMENTARY,
}

enum ExamStatus {
  DRAFT,
  PUBLISHED,
  LOCKED,
  COMPLETED,
  ARCHIVED,
}

class ExaminationEntity {
  final String id;
  final String tenantId;
  final String schoolId;
  final String academicYearId;
  final String examName;
  final ExamType examType;
  final DateTime startDate;
  final DateTime endDate;
  final ExamStatus status;
  final String? description;
  final Map<String, dynamic> settings;
  final Map<String, dynamic> aiMetrics;
  final bool isActive;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ExamScheduleEntity> schedules;

  const ExaminationEntity({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.academicYearId,
    required this.examName,
    required this.examType,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.description,
    required this.settings,
    required this.aiMetrics,
    required this.isActive,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.schedules,
  });
}
