import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/report_card_entity.dart';

part 'report_card_dto.freezed.dart';
part 'report_card_dto.g.dart';

@freezed
class ReportCardDto with _$ReportCardDto {
  const factory ReportCardDto({
    required String id,
    @JsonKey(name: 'verification_uuid') required String verificationUuid,
    required String status,
    @JsonKey(name: 'pdf_url') String? pdfUrl,
    @JsonKey(name: 'pdf_history') required List<Map<String, dynamic>> pdfHistory,
    @JsonKey(name: 'generated_at') String? generatedAt,
    @JsonKey(name: 'published_at') String? publishedAt,
    @JsonKey(name: 'approved_at') String? approvedAt,
    @JsonKey(name: 'generated_by') String? generatedBy,
    @JsonKey(name: 'published_by') String? publishedBy,
    @JsonKey(name: 'approved_by') String? approvedBy,
    required Map<String, dynamic> settings,
    @JsonKey(name: 'ai_metrics') required Map<String, dynamic> aiMetrics,
    @JsonKey(name: 'is_active') required bool isActive,
    required int version,
    @JsonKey(name: 'tenant_id') required String tenantId,
    @JsonKey(name: 'school_id') required String schoolId,
    @JsonKey(name: 'academic_year_id') required String academicYearId,
    @JsonKey(name: 'student_id') required String studentId,
    @JsonKey(name: 'created_at') required String createdAt,
    @JsonKey(name: 'updated_at') required String updatedAt,
  }) = _ReportCardDto;

  const ReportCardDto._();

  factory ReportCardDto.fromJson(Map<String, dynamic> json) =>
      _$ReportCardDtoFromJson(json);

  ReportCardEntity toEntity() {
    final statusEnum = ReportCardStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => ReportCardStatus.DRAFT,
    );

    return ReportCardEntity(
      id: id,
      verificationUuid: verificationUuid,
      status: statusEnum,
      pdfUrl: pdfUrl,
      pdfHistory: pdfHistory,
      generatedAt: generatedAt != null ? DateTime.parse(generatedAt!) : null,
      publishedAt: publishedAt != null ? DateTime.parse(publishedAt!) : null,
      approvedAt: approvedAt != null ? DateTime.parse(approvedAt!) : null,
      generatedBy: generatedBy,
      publishedBy: publishedBy,
      approvedBy: approvedBy,
      settings: settings,
      aiMetrics: aiMetrics,
      isActive: isActive,
      version: version,
      tenantId: tenantId,
      schoolId: schoolId,
      academicYearId: academicYearId,
      studentId: studentId,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }
}
