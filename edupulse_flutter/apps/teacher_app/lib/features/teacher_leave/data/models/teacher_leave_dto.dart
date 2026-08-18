import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/teacher_leave_entity.dart';

part 'teacher_leave_dto.freezed.dart';
part 'teacher_leave_dto.g.dart';

@freezed
class TeacherLeaveDto with _$TeacherLeaveDto {
  const factory TeacherLeaveDto({
    required String id,
    @JsonKey(name: 'tenant_id') required String tenantId,
    @JsonKey(name: 'school_id') required String schoolId,
    @JsonKey(name: 'teacher_id') required String teacherId,
    @JsonKey(name: 'leave_type') required String leaveType,
    @JsonKey(name: 'start_date') required String startDate,
    @JsonKey(name: 'end_date') required String endDate,
    required String reason,
    String? remarks,
    required String status,
    @JsonKey(name: 'requested_at') required String requestedAt,
    @JsonKey(name: 'reviewed_at') String? reviewedAt,
    @JsonKey(name: 'reviewed_by') String? reviewedBy,
    @JsonKey(name: 'reviewer_remarks') String? reviewerRemarks,
    @JsonKey(name: 'cancelled_at') String? cancelledAt,
    @JsonKey(name: 'cancellation_reason') String? cancellationReason,
  }) = _TeacherLeaveDto;

  factory TeacherLeaveDto.fromJson(Map<String, dynamic> json) =>
      _$TeacherLeaveDtoFromJson(json);
}

extension TeacherLeaveDtoMapper on TeacherLeaveDto {
  TeacherLeaveEntity toEntity() {
    return TeacherLeaveEntity(
      id: id,
      tenantId: tenantId,
      schoolId: schoolId,
      teacherId: teacherId,
      leaveType: leaveType,
      startDate: startDate,
      endDate: endDate,
      reason: reason,
      remarks: remarks,
      status: status,
      requestedAt: requestedAt,
      reviewedAt: reviewedAt,
      reviewedBy: reviewedBy,
      reviewerRemarks: reviewerRemarks,
      cancelledAt: cancelledAt,
      cancellationReason: cancellationReason,
    );
  }
}
