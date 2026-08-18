// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance_response_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AttendanceResponseDtoImpl _$$AttendanceResponseDtoImplFromJson(
        Map<String, dynamic> json) =>
    _$AttendanceResponseDtoImpl(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      academicYearId: json['academic_year_id'] as String,
      attendanceSessionId: json['attendance_session_id'] as String,
      studentId: json['student_id'] as String,
      timetableId: json['timetable_id'] as String,
      classId: json['class_id'] as String,
      sectionId: json['section_id'] as String,
      teacherId: json['teacher_id'] as String?,
      subjectId: json['subject_id'] as String?,
      attendanceDate: json['attendance_date'] as String,
      attendanceStatus:
          $enumDecode(_$AttendanceStatusEnumMap, json['attendance_status']),
      attendanceSource:
          $enumDecode(_$AttendanceSourceEnumMap, json['attendance_source']),
      attendanceReason:
          $enumDecode(_$AttendanceReasonEnumMap, json['attendance_reason']),
      remarks: json['remarks'] as String?,
    );

Map<String, dynamic> _$$AttendanceResponseDtoImplToJson(
        _$AttendanceResponseDtoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenant_id': instance.tenantId,
      'school_id': instance.schoolId,
      'academic_year_id': instance.academicYearId,
      'attendance_session_id': instance.attendanceSessionId,
      'student_id': instance.studentId,
      'timetable_id': instance.timetableId,
      'class_id': instance.classId,
      'section_id': instance.sectionId,
      'teacher_id': instance.teacherId,
      'subject_id': instance.subjectId,
      'attendance_date': instance.attendanceDate,
      'attendance_status':
          _$AttendanceStatusEnumMap[instance.attendanceStatus]!,
      'attendance_source':
          _$AttendanceSourceEnumMap[instance.attendanceSource]!,
      'attendance_reason':
          _$AttendanceReasonEnumMap[instance.attendanceReason]!,
      'remarks': instance.remarks,
    };

const _$AttendanceStatusEnumMap = {
  AttendanceStatus.PRESENT: 'PRESENT',
  AttendanceStatus.ABSENT: 'ABSENT',
  AttendanceStatus.LATE: 'LATE',
  AttendanceStatus.HALF_DAY: 'HALF_DAY',
  AttendanceStatus.MEDICAL_LEAVE: 'MEDICAL_LEAVE',
  AttendanceStatus.EXCUSED: 'EXCUSED',
  AttendanceStatus.HOLIDAY: 'HOLIDAY',
  AttendanceStatus.ONLINE: 'ONLINE',
};

const _$AttendanceSourceEnumMap = {
  AttendanceSource.MANUAL: 'MANUAL',
  AttendanceSource.BIOMETRIC: 'BIOMETRIC',
  AttendanceSource.RFID: 'RFID',
  AttendanceSource.FACE_RECOGNITION: 'FACE_RECOGNITION',
  AttendanceSource.IMPORT: 'IMPORT',
};

const _$AttendanceReasonEnumMap = {
  AttendanceReason.SICK: 'SICK',
  AttendanceReason.PERSONAL: 'PERSONAL',
  AttendanceReason.SPORTS: 'SPORTS',
  AttendanceReason.OFFICIAL: 'OFFICIAL',
  AttendanceReason.UNKNOWN: 'UNKNOWN',
};
