// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AttendanceDtoImpl _$$AttendanceDtoImplFromJson(Map<String, dynamic> json) =>
    _$AttendanceDtoImpl(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      attendanceDate: json['attendance_date'] as String,
      attendanceStatus: json['attendance_status'] as String,
      remarks: json['remarks'] as String?,
    );

Map<String, dynamic> _$$AttendanceDtoImplToJson(_$AttendanceDtoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'student_id': instance.studentId,
      'attendance_date': instance.attendanceDate,
      'attendance_status': instance.attendanceStatus,
      'remarks': instance.remarks,
    };
