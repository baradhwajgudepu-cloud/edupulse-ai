import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/attendance_enums.dart';
import '../../domain/entities/attendance_response_entity.dart';

part 'attendance_response_dto.freezed.dart';
part 'attendance_response_dto.g.dart';

@freezed
class AttendanceResponseDto with _$AttendanceResponseDto {
  const factory AttendanceResponseDto({
    required String id,
    @JsonKey(name: 'tenant_id') required String tenantId,
    @JsonKey(name: 'school_id') required String schoolId,
    @JsonKey(name: 'academic_year_id') required String academicYearId,
    @JsonKey(name: 'attendance_session_id') required String attendanceSessionId,
    @JsonKey(name: 'student_id') required String studentId,
    @JsonKey(name: 'timetable_id') required String timetableId,
    @JsonKey(name: 'class_id') required String classId,
    @JsonKey(name: 'section_id') required String sectionId,
    @JsonKey(name: 'teacher_id') String? teacherId,
    @JsonKey(name: 'subject_id') String? subjectId,
    @JsonKey(name: 'attendance_date') required String attendanceDate,
    @JsonKey(name: 'attendance_status') required AttendanceStatus attendanceStatus,
    @JsonKey(name: 'attendance_source') required AttendanceSource attendanceSource,
    @JsonKey(name: 'attendance_reason') required AttendanceReason attendanceReason,
    String? remarks,
  }) = _AttendanceResponseDto;

  factory AttendanceResponseDto.fromJson(Map<String, dynamic> json) =>
      _$AttendanceResponseDtoFromJson(json);
}

extension AttendanceResponseDtoMapper on AttendanceResponseDto {
  AttendanceResponseEntity toEntity() {
    return AttendanceResponseEntity(
      id: id,
      tenantId: tenantId,
      schoolId: schoolId,
      academicYearId: academicYearId,
      attendanceSessionId: attendanceSessionId,
      studentId: studentId,
      timetableId: timetableId,
      classId: classId,
      sectionId: sectionId,
      teacherId: teacherId,
      subjectId: subjectId,
      attendanceDate: attendanceDate,
      attendanceStatus: attendanceStatus,
      attendanceSource: attendanceSource,
      attendanceReason: attendanceReason,
      remarks: remarks,
    );
  }
}
