// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_card_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ReportCardDtoImpl _$$ReportCardDtoImplFromJson(Map<String, dynamic> json) =>
    _$ReportCardDtoImpl(
      id: json['id'] as String,
      verificationUuid: json['verification_uuid'] as String,
      status: json['status'] as String,
      pdfUrl: json['pdf_url'] as String?,
      pdfHistory: (json['pdf_history'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      generatedAt: json['generated_at'] as String?,
      publishedAt: json['published_at'] as String?,
      approvedAt: json['approved_at'] as String?,
      generatedBy: json['generated_by'] as String?,
      publishedBy: json['published_by'] as String?,
      approvedBy: json['approved_by'] as String?,
      settings: json['settings'] as Map<String, dynamic>,
      aiMetrics: json['ai_metrics'] as Map<String, dynamic>,
      isActive: json['is_active'] as bool,
      version: (json['version'] as num).toInt(),
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      academicYearId: json['academic_year_id'] as String,
      studentId: json['student_id'] as String,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );

Map<String, dynamic> _$$ReportCardDtoImplToJson(_$ReportCardDtoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'verification_uuid': instance.verificationUuid,
      'status': instance.status,
      'pdf_url': instance.pdfUrl,
      'pdf_history': instance.pdfHistory,
      'generated_at': instance.generatedAt,
      'published_at': instance.publishedAt,
      'approved_at': instance.approvedAt,
      'generated_by': instance.generatedBy,
      'published_by': instance.publishedBy,
      'approved_by': instance.approvedBy,
      'settings': instance.settings,
      'ai_metrics': instance.aiMetrics,
      'is_active': instance.isActive,
      'version': instance.version,
      'tenant_id': instance.tenantId,
      'school_id': instance.schoolId,
      'academic_year_id': instance.academicYearId,
      'student_id': instance.studentId,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };
