import 'package:freezed_annotation/freezed_annotation.dart';

part 'attendance_dto.freezed.dart';
part 'attendance_dto.g.dart';

@freezed
class AttendanceDto with _$AttendanceDto {
  const factory AttendanceDto({
    required String id,
    @JsonKey(name: 'student_id') required String studentId,
    @JsonKey(name: 'attendance_date') required String attendanceDate,
    @JsonKey(name: 'attendance_status') required String attendanceStatus,
    @JsonKey(name: 'remarks') String? remarks,
  }) = _AttendanceDto;

  factory AttendanceDto.fromJson(Map<String, dynamic> json) =>
      _$AttendanceDtoFromJson(json);
}
