import 'package:equatable/equatable.dart';

enum AttendanceStatus {
  present,
  absent,
  late,
  halfDay,
  leave,
  holiday,
  online,
}

class AttendanceRecordEntity extends Equatable {
  final String id;
  final String studentId;
  final DateTime date;
  final AttendanceStatus status;
  final String remarks;

  const AttendanceRecordEntity({
    required this.id,
    required this.studentId,
    required this.date,
    required this.status,
    required this.remarks,
  });

  @override
  List<Object?> get props => [id, studentId, date, status, remarks];
}
