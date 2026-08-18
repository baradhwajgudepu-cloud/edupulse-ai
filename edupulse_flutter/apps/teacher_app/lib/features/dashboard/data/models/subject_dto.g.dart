// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subject_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SubjectDtoImpl _$$SubjectDtoImplFromJson(Map<String, dynamic> json) =>
    _$SubjectDtoImpl(
      id: json['id'] as String,
      subjectName: json['subject_name'] as String,
      subjectCode: json['subject_code'] as String,
      shortName: json['short_name'] as String?,
      displayColor: json['display_color'] as String?,
    );

Map<String, dynamic> _$$SubjectDtoImplToJson(_$SubjectDtoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'subject_name': instance.subjectName,
      'subject_code': instance.subjectCode,
      'short_name': instance.shortName,
      'display_color': instance.displayColor,
    };
