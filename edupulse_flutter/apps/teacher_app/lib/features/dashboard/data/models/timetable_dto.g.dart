// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timetable_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TimetableDtoImpl _$$TimetableDtoImplFromJson(Map<String, dynamic> json) =>
    _$TimetableDtoImpl(
      id: json['id'] as String,
      dayOfWeek: json['day_of_week'] as String,
      periodNumber: (json['period_number'] as num).toInt(),
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      periodType: json['period_type'] as String,
      roomId: json['room_id'] as String?,
      isAvailable: json['is_available'] as bool,
      classId: json['class_id'] as String,
      sectionId: json['section_id'] as String,
      subjectId: json['subject_id'] as String?,
      teacherId: json['teacher_id'] as String?,
    );

Map<String, dynamic> _$$TimetableDtoImplToJson(_$TimetableDtoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'day_of_week': instance.dayOfWeek,
      'period_number': instance.periodNumber,
      'start_time': instance.startTime,
      'end_time': instance.endTime,
      'period_type': instance.periodType,
      'room_id': instance.roomId,
      'is_available': instance.isAvailable,
      'class_id': instance.classId,
      'section_id': instance.sectionId,
      'subject_id': instance.subjectId,
      'teacher_id': instance.teacherId,
    };
