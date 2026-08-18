// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'section_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SectionDtoImpl _$$SectionDtoImplFromJson(Map<String, dynamic> json) =>
    _$SectionDtoImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      classId: json['class_id'] as String,
    );

Map<String, dynamic> _$$SectionDtoImplToJson(_$SectionDtoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'code': instance.code,
      'class_id': instance.classId,
    };
