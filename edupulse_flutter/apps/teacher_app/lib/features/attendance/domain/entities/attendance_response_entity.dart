import 'package:equatable/equatable.dart';
import 'attendance_enums.dart';

class AttendanceResponseEntity extends Equatable {
  final String id;
  final String tenantId;
  final String schoolId;
  final String academicYearId;
  final String attendanceSessionId;
  final String studentId;
  final String timetableId;
  final String classId;
  final String sectionId;
  final String? teacherId;
  final String? subjectId;
  final String attendanceDate;
  final AttendanceStatus attendanceStatus;
  final AttendanceSource attendanceSource;
  final AttendanceReason attendanceReason;
  final String? remarks;

  const AttendanceResponseEntity({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.academicYearId,
    required this.attendanceSessionId,
    required this.studentId,
    required this.timetableId,
    required this.classId,
    required this.sectionId,
    this.teacherId,
    this.subjectId,
    required this.attendanceDate,
    required this.attendanceStatus,
    required this.attendanceSource,
    required this.attendanceReason,
    this.remarks,
  });

  @override
  List<Object?> get props => [
        id,
        tenantId,
        schoolId,
        academicYearId,
        attendanceSessionId,
        studentId,
        timetableId,
        classId,
        sectionId,
        teacherId,
        subjectId,
        attendanceDate,
        attendanceStatus,
        attendanceSource,
        attendanceReason,
        remarks,
      ];
}
