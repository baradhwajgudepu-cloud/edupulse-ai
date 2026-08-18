import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/staff_attendance_entity.dart';

part 'staff_attendance_dto.freezed.dart';
part 'staff_attendance_dto.g.dart';

@freezed
class StaffAttendanceDto with _$StaffAttendanceDto {
  const factory StaffAttendanceDto({
    String? id,
    @JsonKey(name: 'tenant_id') required String tenantId,
    @JsonKey(name: 'teacher_id') required String teacherId,
    @JsonKey(name: 'school_id') required String schoolId,
    @JsonKey(name: 'attendance_date') required String attendanceDate,
    @JsonKey(name: 'check_in_time') String? checkInTime,
    @JsonKey(name: 'check_in_latitude') double? checkInLatitude,
    @JsonKey(name: 'check_in_longitude') double? checkInLongitude,
    @JsonKey(name: 'check_in_distance_meters') double? checkInDistanceMeters,
    @JsonKey(name: 'check_out_time') String? checkOutTime,
    @JsonKey(name: 'check_out_latitude') double? checkOutLatitude,
    @JsonKey(name: 'check_out_longitude') double? checkOutLongitude,
    @JsonKey(name: 'check_out_distance_meters') double? checkOutDistanceMeters,
    @JsonKey(name: 'is_mocked_location') @Default(false) bool isMockedLocation,
    String? remarks,
    @JsonKey(name: 'duration_seconds') int? durationSeconds,
    required String status,
  }) = _StaffAttendanceDto;

  factory StaffAttendanceDto.fromJson(Map<String, dynamic> json) =>
      _$StaffAttendanceDtoFromJson(json);
}

extension StaffAttendanceDtoMapper on StaffAttendanceDto {
  StaffAttendanceEntity toEntity() {
    return StaffAttendanceEntity(
      id: id,
      tenantId: tenantId,
      teacherId: teacherId,
      schoolId: schoolId,
      attendanceDate: attendanceDate,
      checkInTime: checkInTime,
      checkInLatitude: checkInLatitude,
      checkInLongitude: checkInLongitude,
      checkInDistanceMeters: checkInDistanceMeters,
      checkOutTime: checkOutTime,
      checkOutLatitude: checkOutLatitude,
      checkOutLongitude: checkOutLongitude,
      checkOutDistanceMeters: checkOutDistanceMeters,
      isMockedLocation: isMockedLocation,
      remarks: remarks,
      durationSeconds: durationSeconds,
      status: status,
    );
  }
}
