// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'marks_publish_summary_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MarksPublishSummaryDtoImpl _$$MarksPublishSummaryDtoImplFromJson(
        Map<String, dynamic> json) =>
    _$MarksPublishSummaryDtoImpl(
      examName: json['exam_name'] as String,
      subjectName: json['subject_name'] as String,
      className: json['class_name'] as String,
      totalStudents: (json['total_students'] as num).toInt(),
      enteredCount: (json['entered_count'] as num).toInt(),
      missingCount: (json['missing_count'] as num).toInt(),
      passPercentage: (json['pass_percentage'] as num).toDouble(),
    );

Map<String, dynamic> _$$MarksPublishSummaryDtoImplToJson(
        _$MarksPublishSummaryDtoImpl instance) =>
    <String, dynamic>{
      'exam_name': instance.examName,
      'subject_name': instance.subjectName,
      'class_name': instance.className,
      'total_students': instance.totalStudents,
      'entered_count': instance.enteredCount,
      'missing_count': instance.missingCount,
      'pass_percentage': instance.passPercentage,
    };
