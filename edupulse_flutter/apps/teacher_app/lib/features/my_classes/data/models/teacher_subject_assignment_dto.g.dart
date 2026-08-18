// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'teacher_subject_assignment_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TeacherSubjectAssignmentDtoImpl _$$TeacherSubjectAssignmentDtoImplFromJson(
        Map<String, dynamic> json) =>
    _$TeacherSubjectAssignmentDtoImpl(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      academicYearId: json['academic_year_id'] as String,
      teacherId: json['teacher_id'] as String,
      subjectId: json['subject_id'] as String,
      classId: json['class_id'] as String,
      sectionId: json['section_id'] as String,
      assignmentType: json['assignment_type'] as String,
      priority: (json['priority'] as num).toInt(),
      weeklyPeriods: (json['weekly_periods'] as num).toInt(),
      isClassTeacher: json['is_class_teacher'] as bool,
      isActive: json['is_active'] as bool,
      status: json['status'] as String,
    );

Map<String, dynamic> _$$TeacherSubjectAssignmentDtoImplToJson(
        _$TeacherSubjectAssignmentDtoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenant_id': instance.tenantId,
      'school_id': instance.schoolId,
      'academic_year_id': instance.academicYearId,
      'teacher_id': instance.teacherId,
      'subject_id': instance.subjectId,
      'class_id': instance.classId,
      'section_id': instance.sectionId,
      'assignment_type': instance.assignmentType,
      'priority': instance.priority,
      'weekly_periods': instance.weeklyPeriods,
      'is_class_teacher': instance.isClassTeacher,
      'is_active': instance.isActive,
      'status': instance.status,
    };
