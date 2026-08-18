import 'package:equatable/equatable.dart';

class StaffAttendanceEntity extends Equatable {
  final String? id;
  final String tenantId;
  final String teacherId;
  final String schoolId;
  final String attendanceDate;
  final String? checkInTime;
  final double? checkInLatitude;
  final double? checkInLongitude;
  final double? checkInDistanceMeters;
  final String? checkOutTime;
  final double? checkOutLatitude;
  final double? checkOutLongitude;
  final double? checkOutDistanceMeters;
  final bool isMockedLocation;
  final String? remarks;
  final int? durationSeconds;
  final String status; // NOT_CHECKED_IN, CHECKED_IN, CHECKED_OUT

  const StaffAttendanceEntity({
    this.id,
    required this.tenantId,
    required this.teacherId,
    required this.schoolId,
    required this.attendanceDate,
    this.checkInTime,
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkInDistanceMeters,
    this.checkOutTime,
    this.checkOutLatitude,
    this.checkOutLongitude,
    this.checkOutDistanceMeters,
    required this.isMockedLocation,
    this.remarks,
    this.durationSeconds,
    required this.status,
  });

  @override
  List<Object?> get props => [
        id,
        tenantId,
        teacherId,
        schoolId,
        attendanceDate,
        checkInTime,
        checkInLatitude,
        checkInLongitude,
        checkInDistanceMeters,
        checkOutTime,
        checkOutLatitude,
        checkOutLongitude,
        checkOutDistanceMeters,
        isMockedLocation,
        remarks,
        durationSeconds,
        status,
      ];
}
