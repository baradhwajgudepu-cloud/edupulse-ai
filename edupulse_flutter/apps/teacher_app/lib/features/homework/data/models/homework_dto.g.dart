// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'homework_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$HomeworkDtoImpl _$$HomeworkDtoImplFromJson(Map<String, dynamic> json) =>
    _$HomeworkDtoImpl(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      academicYearId: json['academic_year_id'] as String,
      teacherId: json['teacher_id'] as String,
      teacherSubjectAssignmentId:
          json['teacher_subject_assignment_id'] as String,
      subjectId: json['subject_id'] as String,
      classId: json['class_id'] as String,
      sectionId: json['section_id'] as String,
      timetableId: json['timetable_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String,
      dueDate: json['due_date'] as String,
      priority: json['priority'] as String,
      status: json['status'] as String,
      attachmentUrl: json['attachment_url'] as String?,
      estimatedMinutes: (json['estimated_minutes'] as num?)?.toInt(),
      isActive: json['is_active'] as bool,
      settings: json['settings'] as Map<String, dynamic>,
      aiMetrics: json['ai_metrics'] as Map<String, dynamic>,
      version: (json['version'] as num).toInt(),
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );

Map<String, dynamic> _$$HomeworkDtoImplToJson(_$HomeworkDtoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenant_id': instance.tenantId,
      'school_id': instance.schoolId,
      'academic_year_id': instance.academicYearId,
      'teacher_id': instance.teacherId,
      'teacher_subject_assignment_id': instance.teacherSubjectAssignmentId,
      'subject_id': instance.subjectId,
      'class_id': instance.classId,
      'section_id': instance.sectionId,
      'timetable_id': instance.timetableId,
      'title': instance.title,
      'description': instance.description,
      'due_date': instance.dueDate,
      'priority': instance.priority,
      'status': instance.status,
      'attachment_url': instance.attachmentUrl,
      'estimated_minutes': instance.estimatedMinutes,
      'is_active': instance.isActive,
      'settings': instance.settings,
      'ai_metrics': instance.aiMetrics,
      'version': instance.version,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };
