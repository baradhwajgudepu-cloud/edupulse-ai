// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'staff_attendance_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$StaffAttendanceDtoImpl _$$StaffAttendanceDtoImplFromJson(
        Map<String, dynamic> json) =>
    _$StaffAttendanceDtoImpl(
      id: json['id'] as String?,
      tenantId: json['tenant_id'] as String,
      teacherId: json['teacher_id'] as String,
      schoolId: json['school_id'] as String,
      attendanceDate: json['attendance_date'] as String,
      checkInTime: json['check_in_time'] as String?,
      checkInLatitude: (json['check_in_latitude'] as num?)?.toDouble(),
      checkInLongitude: (json['check_in_longitude'] as num?)?.toDouble(),
      checkInDistanceMeters:
          (json['check_in_distance_meters'] as num?)?.toDouble(),
      checkOutTime: json['check_out_time'] as String?,
      checkOutLatitude: (json['check_out_latitude'] as num?)?.toDouble(),
      checkOutLongitude: (json['check_out_longitude'] as num?)?.toDouble(),
      checkOutDistanceMeters:
          (json['check_out_distance_meters'] as num?)?.toDouble(),
      isMockedLocation: json['is_mocked_location'] as bool? ?? false,
      remarks: json['remarks'] as String?,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      status: json['status'] as String,
    );

Map<String, dynamic> _$$StaffAttendanceDtoImplToJson(
        _$StaffAttendanceDtoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenant_id': instance.tenantId,
      'teacher_id': instance.teacherId,
      'school_id': instance.schoolId,
      'attendance_date': instance.attendanceDate,
      'check_in_time': instance.checkInTime,
      'check_in_latitude': instance.checkInLatitude,
      'check_in_longitude': instance.checkInLongitude,
      'check_in_distance_meters': instance.checkInDistanceMeters,
      'check_out_time': instance.checkOutTime,
      'check_out_latitude': instance.checkOutLatitude,
      'check_out_longitude': instance.checkOutLongitude,
      'check_out_distance_meters': instance.checkOutDistanceMeters,
      'is_mocked_location': instance.isMockedLocation,
      'remarks': instance.remarks,
      'duration_seconds': instance.durationSeconds,
      'status': instance.status,
    };
