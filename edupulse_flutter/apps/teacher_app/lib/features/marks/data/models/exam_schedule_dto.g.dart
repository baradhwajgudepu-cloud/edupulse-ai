// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam_schedule_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ExamScheduleDtoImpl _$$ExamScheduleDtoImplFromJson(
        Map<String, dynamic> json) =>
    _$ExamScheduleDtoImpl(
      id: json['id'] as String,
      examId: json['exam_id'] as String,
      classId: json['class_id'] as String,
      sectionId: json['section_id'] as String,
      subjectId: json['subject_id'] as String,
      teacherSubjectAssignmentId:
          json['teacher_subject_assignment_id'] as String,
      examDate: json['exam_date'] as String,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      maxMarks: (json['max_marks'] as num).toInt(),
      passMarks: (json['pass_marks'] as num).toInt(),
      roomNumber: json['room_number'] as String?,
      isActive: json['is_active'] as bool,
      version: (json['version'] as num).toInt(),
    );

Map<String, dynamic> _$$ExamScheduleDtoImplToJson(
        _$ExamScheduleDtoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'exam_id': instance.examId,
      'class_id': instance.classId,
      'section_id': instance.sectionId,
      'subject_id': instance.subjectId,
      'teacher_subject_assignment_id': instance.teacherSubjectAssignmentId,
      'exam_date': instance.examDate,
      'start_time': instance.startTime,
      'end_time': instance.endTime,
      'max_marks': instance.maxMarks,
      'pass_marks': instance.passMarks,
      'room_number': instance.roomNumber,
      'is_active': instance.isActive,
      'version': instance.version,
    };
