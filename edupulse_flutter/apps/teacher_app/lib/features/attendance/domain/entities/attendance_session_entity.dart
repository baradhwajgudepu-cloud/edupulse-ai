import 'package:equatable/equatable.dart';
import 'attendance_enums.dart';
import 'attendance_response_entity.dart';

class AttendanceSessionEntity extends Equatable {
  final String id;
  final String tenantId;
  final String schoolId;
  final String academicYearId;
  final String timetableId;
  final String classId;
  final String sectionId;
  final String? teacherId;
  final String? subjectId;
  final String attendanceDate;
  final AttendanceSessionStatus status;
  final String? markedBy;
  final String? markedAt;
  final List<AttendanceResponseEntity> attendances;

  const AttendanceSessionEntity({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.academicYearId,
    required this.timetableId,
    required this.classId,
    required this.sectionId,
    this.teacherId,
    this.subjectId,
    required this.attendanceDate,
    required this.status,
    this.markedBy,
    this.markedAt,
    required this.attendances,
  });

  @override
  List<Object?> get props => [
        id,
        tenantId,
        schoolId,
        academicYearId,
        timetableId,
        classId,
        sectionId,
        teacherId,
        subjectId,
        attendanceDate,
        status,
        markedBy,
        markedAt,
        attendances,
      ];
}
