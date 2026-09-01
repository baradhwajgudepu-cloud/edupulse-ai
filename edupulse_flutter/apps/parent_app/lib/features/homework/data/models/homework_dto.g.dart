// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'homework_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$HomeworkDtoImpl _$$HomeworkDtoImplFromJson(Map<String, dynamic> json) =>
    _$HomeworkDtoImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      dueDate: json['due_date'] as String,
      priority: json['priority'] as String,
      status: json['status'] as String,
      attachmentUrl: json['attachment_url'] as String?,
      subjectId: json['subject_id'] as String,
      classId: json['class_id'] as String,
      sectionId: json['section_id'] as String,
    );

Map<String, dynamic> _$$HomeworkDtoImplToJson(_$HomeworkDtoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'due_date': instance.dueDate,
      'priority': instance.priority,
      'status': instance.status,
      'attachment_url': instance.attachmentUrl,
      'subject_id': instance.subjectId,
      'class_id': instance.classId,
      'section_id': instance.sectionId,
    };
