enum ReportCardStatus {
  DRAFT,
  UNDER_REVIEW,
  APPROVED,
  PUBLISHED,
  LOCKED,
  ARCHIVED,
}

class ReportCardEntity {
  final String id;
  final String verificationUuid;
  final ReportCardStatus status;
  final String? pdfUrl;
  final List<Map<String, dynamic>> pdfHistory;
  final DateTime? generatedAt;
  final DateTime? publishedAt;
  final DateTime? approvedAt;
  final String? generatedBy;
  final String? publishedBy;
  final String? approvedBy;
  final Map<String, dynamic> settings;
  final Map<String, dynamic> aiMetrics;
  final bool isActive;
  final int version;
  final String tenantId;
  final String schoolId;
  final String academicYearId;
  final String studentId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReportCardEntity({
    required this.id,
    required this.verificationUuid,
    required this.status,
    this.pdfUrl,
    required this.pdfHistory,
    this.generatedAt,
    this.publishedAt,
    this.approvedAt,
    this.generatedBy,
    this.publishedBy,
    this.approvedBy,
    required this.settings,
    required this.aiMetrics,
    required this.isActive,
    required this.version,
    required this.tenantId,
    required this.schoolId,
    required this.academicYearId,
    required this.studentId,
    required this.createdAt,
    required this.updatedAt,
  });
}
