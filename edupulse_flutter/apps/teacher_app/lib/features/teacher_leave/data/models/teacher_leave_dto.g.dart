// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'teacher_leave_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TeacherLeaveDtoImpl _$$TeacherLeaveDtoImplFromJson(
        Map<String, dynamic> json) =>
    _$TeacherLeaveDtoImpl(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      teacherId: json['teacher_id'] as String,
      leaveType: json['leave_type'] as String,
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
      reason: json['reason'] as String,
      remarks: json['remarks'] as String?,
      status: json['status'] as String,
      requestedAt: json['requested_at'] as String,
      reviewedAt: json['reviewed_at'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      reviewerRemarks: json['reviewer_remarks'] as String?,
      cancelledAt: json['cancelled_at'] as String?,
      cancellationReason: json['cancellation_reason'] as String?,
    );

Map<String, dynamic> _$$TeacherLeaveDtoImplToJson(
        _$TeacherLeaveDtoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenant_id': instance.tenantId,
      'school_id': instance.schoolId,
      'teacher_id': instance.teacherId,
      'leave_type': instance.leaveType,
      'start_date': instance.startDate,
      'end_date': instance.endDate,
      'reason': instance.reason,
      'remarks': instance.remarks,
      'status': instance.status,
      'requested_at': instance.requestedAt,
      'reviewed_at': instance.reviewedAt,
      'reviewed_by': instance.reviewedBy,
      'reviewer_remarks': instance.reviewerRemarks,
      'cancelled_at': instance.cancelledAt,
      'cancellation_reason': instance.cancellationReason,
    };
