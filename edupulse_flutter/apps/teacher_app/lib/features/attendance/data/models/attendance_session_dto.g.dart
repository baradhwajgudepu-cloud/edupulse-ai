// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance_session_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AttendanceSessionDtoImpl _$$AttendanceSessionDtoImplFromJson(
        Map<String, dynamic> json) =>
    _$AttendanceSessionDtoImpl(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      academicYearId: json['academic_year_id'] as String,
      timetableId: json['timetable_id'] as String,
      classId: json['class_id'] as String,
      sectionId: json['section_id'] as String,
      teacherId: json['teacher_id'] as String?,
      subjectId: json['subject_id'] as String?,
      attendanceDate: json['attendance_date'] as String,
      status: $enumDecode(_$AttendanceSessionStatusEnumMap, json['status']),
      markedBy: json['marked_by'] as String?,
      markedAt: json['marked_at'] as String?,
      attendances: (json['attendances'] as List<dynamic>?)
              ?.map((e) =>
                  AttendanceResponseDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$AttendanceSessionDtoImplToJson(
        _$AttendanceSessionDtoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenant_id': instance.tenantId,
      'school_id': instance.schoolId,
      'academic_year_id': instance.academicYearId,
      'timetable_id': instance.timetableId,
      'class_id': instance.classId,
      'section_id': instance.sectionId,
      'teacher_id': instance.teacherId,
      'subject_id': instance.subjectId,
      'attendance_date': instance.attendanceDate,
      'status': _$AttendanceSessionStatusEnumMap[instance.status]!,
      'marked_by': instance.markedBy,
      'marked_at': instance.markedAt,
      'attendances': instance.attendances,
    };

const _$AttendanceSessionStatusEnumMap = {
  AttendanceSessionStatus.DRAFT: 'DRAFT',
  AttendanceSessionStatus.SUBMITTED: 'SUBMITTED',
  AttendanceSessionStatus.LOCKED: 'LOCKED',
};
