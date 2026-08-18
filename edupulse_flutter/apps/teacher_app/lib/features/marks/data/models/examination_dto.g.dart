// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'examination_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ExaminationDtoImpl _$$ExaminationDtoImplFromJson(Map<String, dynamic> json) =>
    _$ExaminationDtoImpl(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      academicYearId: json['academic_year_id'] as String,
      examName: json['exam_name'] as String,
      examType: json['exam_type'] as String,
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
      status: json['status'] as String,
      description: json['description'] as String?,
      settings: json['settings'] as Map<String, dynamic>,
      aiMetrics: json['ai_metrics'] as Map<String, dynamic>,
      isActive: json['is_active'] as bool,
      version: (json['version'] as num).toInt(),
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      schedules: (json['schedules'] as List<dynamic>?)
              ?.map((e) => ExamScheduleDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$ExaminationDtoImplToJson(
        _$ExaminationDtoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenant_id': instance.tenantId,
      'school_id': instance.schoolId,
      'academic_year_id': instance.academicYearId,
      'exam_name': instance.examName,
      'exam_type': instance.examType,
      'start_date': instance.startDate,
      'end_date': instance.endDate,
      'status': instance.status,
      'description': instance.description,
      'settings': instance.settings,
      'ai_metrics': instance.aiMetrics,
      'is_active': instance.isActive,
      'version': instance.version,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'schedules': instance.schedules,
    };
