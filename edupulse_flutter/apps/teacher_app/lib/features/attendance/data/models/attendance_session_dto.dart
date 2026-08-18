import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/attendance_enums.dart';
import '../../domain/entities/attendance_session_entity.dart';
import 'attendance_response_dto.dart';

part 'attendance_session_dto.freezed.dart';
part 'attendance_session_dto.g.dart';

@freezed
class AttendanceSessionDto with _$AttendanceSessionDto {
  const factory AttendanceSessionDto({
    required String id,
    @JsonKey(name: 'tenant_id') required String tenantId,
    @JsonKey(name: 'school_id') required String schoolId,
    @JsonKey(name: 'academic_year_id') required String academicYearId,
    @JsonKey(name: 'timetable_id') required String timetableId,
    @JsonKey(name: 'class_id') required String classId,
    @JsonKey(name: 'section_id') required String sectionId,
    @JsonKey(name: 'teacher_id') String? teacherId,
    @JsonKey(name: 'subject_id') String? subjectId,
    @JsonKey(name: 'attendance_date') required String attendanceDate,
    required AttendanceSessionStatus status,
    @JsonKey(name: 'marked_by') String? markedBy,
    @JsonKey(name: 'marked_at') String? markedAt,
    @Default([]) List<AttendanceResponseDto> attendances,
  }) = _AttendanceSessionDto;

  factory AttendanceSessionDto.fromJson(Map<String, dynamic> json) =>
      _$AttendanceSessionDtoFromJson(json);
}

extension AttendanceSessionDtoMapper on AttendanceSessionDto {
  AttendanceSessionEntity toEntity() {
    return AttendanceSessionEntity(
      id: id,
      tenantId: tenantId,
      schoolId: schoolId,
      academicYearId: academicYearId,
      timetableId: timetableId,
      classId: classId,
      sectionId: sectionId,
      teacherId: teacherId,
      subjectId: subjectId,
      attendanceDate: attendanceDate,
      status: status,
      markedBy: markedBy,
      markedAt: markedAt,
      attendances: attendances.map((d) => d.toEntity()).toList(),
    );
  }
}
