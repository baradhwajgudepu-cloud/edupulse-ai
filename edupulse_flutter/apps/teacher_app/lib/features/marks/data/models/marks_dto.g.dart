// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'marks_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MarksDtoImpl _$$MarksDtoImplFromJson(Map<String, dynamic> json) =>
    _$MarksDtoImpl(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      academicYearId: json['academic_year_id'] as String,
      examinationId: json['examination_id'] as String,
      examScheduleId: json['exam_schedule_id'] as String,
      studentId: json['student_id'] as String,
      teacherSubjectAssignmentId:
          json['teacher_subject_assignment_id'] as String,
      teacherId: json['teacher_id'] as String,
      subjectId: json['subject_id'] as String,
      classId: json['class_id'] as String,
      sectionId: json['section_id'] as String,
      maximumMarks: (json['maximum_marks'] as num).toInt(),
      marksObtained: (json['marks_obtained'] as num?)?.toDouble(),
      resultStatus: json['result_status'] as String,
      status: json['status'] as String,
      grade: json['grade'] as String?,
      remarks: json['remarks'] as String?,
      settings: json['settings'] as Map<String, dynamic>,
      aiMetrics: json['ai_metrics'] as Map<String, dynamic>,
      auditHistory: json['audit_history'] as List<dynamic>,
      isActive: json['is_active'] as bool,
      version: (json['version'] as num).toInt(),
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );

Map<String, dynamic> _$$MarksDtoImplToJson(_$MarksDtoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenant_id': instance.tenantId,
      'school_id': instance.schoolId,
      'academic_year_id': instance.academicYearId,
      'examination_id': instance.examinationId,
      'exam_schedule_id': instance.examScheduleId,
      'student_id': instance.studentId,
      'teacher_subject_assignment_id': instance.teacherSubjectAssignmentId,
      'teacher_id': instance.teacherId,
      'subject_id': instance.subjectId,
      'class_id': instance.classId,
      'section_id': instance.sectionId,
      'maximum_marks': instance.maximumMarks,
      'marks_obtained': instance.marksObtained,
      'result_status': instance.resultStatus,
      'status': instance.status,
      'grade': instance.grade,
      'remarks': instance.remarks,
      'settings': instance.settings,
      'ai_metrics': instance.aiMetrics,
      'audit_history': instance.auditHistory,
      'is_active': instance.isActive,
      'version': instance.version,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };
