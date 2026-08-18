// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'marks_wizard_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$StudentShortInfoDtoImpl _$$StudentShortInfoDtoImplFromJson(
        Map<String, dynamic> json) =>
    _$StudentShortInfoDtoImpl(
      id: json['id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      rollNumber: json['roll_number'] as String,
    );

Map<String, dynamic> _$$StudentShortInfoDtoImplToJson(
        _$StudentShortInfoDtoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'first_name': instance.firstName,
      'last_name': instance.lastName,
      'roll_number': instance.rollNumber,
    };

_$MarkWizardItemDtoImpl _$$MarkWizardItemDtoImplFromJson(
        Map<String, dynamic> json) =>
    _$MarkWizardItemDtoImpl(
      student:
          StudentShortInfoDto.fromJson(json['student'] as Map<String, dynamic>),
      markRecord: json['mark_record'] == null
          ? null
          : MarksDto.fromJson(json['mark_record'] as Map<String, dynamic>),
      isMissing: json['is_missing'] as bool,
    );

Map<String, dynamic> _$$MarkWizardItemDtoImplToJson(
        _$MarkWizardItemDtoImpl instance) =>
    <String, dynamic>{
      'student': instance.student,
      'mark_record': instance.markRecord,
      'is_missing': instance.isMissing,
    };

_$MarksWizardDtoImpl _$$MarksWizardDtoImplFromJson(Map<String, dynamic> json) =>
    _$MarksWizardDtoImpl(
      totalStudents: (json['total_students'] as num).toInt(),
      enteredCount: (json['entered_count'] as num).toInt(),
      missingCount: (json['missing_count'] as num).toInt(),
      averageScore: (json['average_score'] as num?)?.toDouble(),
      highestScore: (json['highest_score'] as num?)?.toDouble(),
      lowestScore: (json['lowest_score'] as num?)?.toDouble(),
      missingStudents: (json['missing_students'] as List<dynamic>)
          .map((e) => StudentShortInfoDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      entries: (json['entries'] as List<dynamic>)
          .map((e) => MarkWizardItemDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$MarksWizardDtoImplToJson(
        _$MarksWizardDtoImpl instance) =>
    <String, dynamic>{
      'total_students': instance.totalStudents,
      'entered_count': instance.enteredCount,
      'missing_count': instance.missingCount,
      'average_score': instance.averageScore,
      'highest_score': instance.highestScore,
      'lowest_score': instance.lowestScore,
      'missing_students': instance.missingStudents,
      'entries': instance.entries,
    };
