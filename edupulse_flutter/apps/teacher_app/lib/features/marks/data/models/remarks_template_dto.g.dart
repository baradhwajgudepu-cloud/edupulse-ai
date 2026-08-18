// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'remarks_template_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RemarksTemplateDtoImpl _$$RemarksTemplateDtoImplFromJson(
        Map<String, dynamic> json) =>
    _$RemarksTemplateDtoImpl(
      templates:
          (json['templates'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$$RemarksTemplateDtoImplToJson(
        _$RemarksTemplateDtoImpl instance) =>
    <String, dynamic>{
      'templates': instance.templates,
    };
