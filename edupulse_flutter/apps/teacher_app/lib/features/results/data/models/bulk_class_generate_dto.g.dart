// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bulk_class_generate_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$StudentFailureDetailDtoImpl _$$StudentFailureDetailDtoImplFromJson(
        Map<String, dynamic> json) =>
    _$StudentFailureDetailDtoImpl(
      studentId: json['student_id'] as String,
      studentName: json['student_name'] as String,
      reasons:
          (json['reasons'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$$StudentFailureDetailDtoImplToJson(
        _$StudentFailureDetailDtoImpl instance) =>
    <String, dynamic>{
      'student_id': instance.studentId,
      'student_name': instance.studentName,
      'reasons': instance.reasons,
    };

_$BulkClassGenerateDtoImpl _$$BulkClassGenerateDtoImplFromJson(
        Map<String, dynamic> json) =>
    _$BulkClassGenerateDtoImpl(
      totalStudents: (json['total_students'] as num).toInt(),
      generatedCount: (json['generated_count'] as num).toInt(),
      failedCount: (json['failed_count'] as num).toInt(),
      failures: (json['failures'] as List<dynamic>)
          .map((e) =>
              StudentFailureDetailDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$BulkClassGenerateDtoImplToJson(
        _$BulkClassGenerateDtoImpl instance) =>
    <String, dynamic>{
      'total_students': instance.totalStudents,
      'generated_count': instance.generatedCount,
      'failed_count': instance.failedCount,
      'failures': instance.failures,
    };
