class ReportCard {
  final String id;
  final String verificationUuid;
  final String status; // DRAFT, UNDER_REVIEW, APPROVED, PUBLISHED, LOCKED, ARCHIVED
  final String? pdfUrl;
  final int version;
  final String academicYearId;
  final String studentId;
  final String classId;
  final String sectionId;

  ReportCard({
    required this.id,
    required this.verificationUuid,
    required this.status,
    this.pdfUrl,
    required this.version,
    required this.academicYearId,
    required this.studentId,
    required this.classId,
    required this.sectionId,
  });

  factory ReportCard.fromJson(Map<String, dynamic> json) {
    return ReportCard(
      id: json['id'] as String? ?? '',
      verificationUuid: json['verification_uuid'] as String? ?? '',
      status: json['status'] as String? ?? 'DRAFT',
      pdfUrl: json['pdf_url'] as String?,
      version: json['version'] as int? ?? 1,
      academicYearId: json['academic_year_id'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      classId: json['class_id'] as String? ?? '',
      sectionId: json['section_id'] as String? ?? '',
    );
  }
}
