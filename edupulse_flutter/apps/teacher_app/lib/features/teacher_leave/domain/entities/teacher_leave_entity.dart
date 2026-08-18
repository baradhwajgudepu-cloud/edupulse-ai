import 'package:equatable/equatable.dart';

class TeacherLeaveEntity extends Equatable {
  final String id;
  final String tenantId;
  final String schoolId;
  final String teacherId;
  final String leaveType; // CASUAL, SICK, EARNED, EMERGENCY, OTHER
  final String startDate; // yyyy-MM-dd
  final String endDate; // yyyy-MM-dd
  final String reason;
  final String? remarks;
  final String status; // PENDING, APPROVED, REJECTED, CANCELLED
  final String requestedAt;
  final String? reviewedAt;
  final String? reviewedBy;
  final String? reviewerRemarks;
  final String? cancelledAt;
  final String? cancellationReason;

  const TeacherLeaveEntity({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.teacherId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.remarks,
    required this.status,
    required this.requestedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.reviewerRemarks,
    this.cancelledAt,
    this.cancellationReason,
  });

  int get durationDays {
    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);
      return end.difference(start).inDays + 1;
    } catch (_) {
      return 1;
    }
  }

  @override
  List<Object?> get props => [
        id,
        tenantId,
        schoolId,
        teacherId,
        leaveType,
        startDate,
        endDate,
        reason,
        remarks,
        status,
        requestedAt,
        reviewedAt,
        reviewedBy,
        reviewerRemarks,
        cancelledAt,
        cancellationReason,
      ];
}
