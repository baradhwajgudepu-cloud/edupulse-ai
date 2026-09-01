import '../../domain/entities/attendance_record.dart';
import '../models/attendance_dto.dart';

extension AttendanceDtoMapper on AttendanceDto {
  AttendanceRecordEntity toEntity() {
    final date = DateTime.tryParse(attendanceDate) ?? DateTime.now();

    final status = switch (attendanceStatus.toUpperCase()) {
      'PRESENT' => AttendanceStatus.present,
      'ABSENT' => AttendanceStatus.absent,
      'LATE' => AttendanceStatus.late,
      'HALF_DAY' => AttendanceStatus.halfDay,
      'MEDICAL_LEAVE' || 'EXCUSED' => AttendanceStatus.leave,
      'HOLIDAY' => AttendanceStatus.holiday,
      'ONLINE' => AttendanceStatus.online,
      _ => AttendanceStatus.present,
    };

    return AttendanceRecordEntity(
      id: id,
      studentId: studentId,
      date: date,
      status: status,
      remarks: remarks ?? '',
    );
  }
}
