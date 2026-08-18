// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'result_summary_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ResultSummaryDtoImpl _$$ResultSummaryDtoImplFromJson(
        Map<String, dynamic> json) =>
    _$ResultSummaryDtoImpl(
      classAverage: (json['class_average'] as num).toDouble(),
      passPercentage: (json['pass_percentage'] as num).toDouble(),
      highestScore: (json['highest_score'] as num).toDouble(),
      lowestScore: (json['lowest_score'] as num).toDouble(),
      missingCount: (json['missing_count'] as num).toInt(),
      absentCount: (json['absent_count'] as num).toInt(),
    );

Map<String, dynamic> _$$ResultSummaryDtoImplToJson(
        _$ResultSummaryDtoImpl instance) =>
    <String, dynamic>{
      'class_average': instance.classAverage,
      'pass_percentage': instance.passPercentage,
      'highest_score': instance.highestScore,
      'lowest_score': instance.lowestScore,
      'missing_count': instance.missingCount,
      'absent_count': instance.absentCount,
    };
