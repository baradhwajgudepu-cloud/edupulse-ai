class LeaveRequest {
  final String id;
  final String tenantId;
  final String schoolId;
  final String teacherId;
  final String leaveType;
  final String startDate;
  final String endDate;
  final String reason;
  final String? remarks;
  final String status;
  final String requestedAt;
  final String? reviewedAt;
  final String? reviewedBy;
  final String? reviewerRemarks;
  final String? cancelledAt;
  final String? cancellationReason;
  final String teacherName;
  final String? teacherDesignation;
  final String? teacherDepartment;

  LeaveRequest({
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
    required this.teacherName,
    this.teacherDesignation,
    this.teacherDepartment,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    // Nested teacher data
    final teacherJson = json['teacher'] as Map<String, dynamic>?;
    final String resolvedTeacherName = teacherJson != null
        ? '${teacherJson['first_name'] as String? ?? ''} ${teacherJson['last_name'] as String? ?? ''}'.trim()
        : 'Unknown Teacher';
    final String? resolvedDesignation = teacherJson?['designation'] as String?;
    final String? resolvedDepartment = teacherJson?['department'] as String?;

    return LeaveRequest(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      schoolId: json['school_id'] as String? ?? '',
      teacherId: json['teacher_id'] as String? ?? '',
      leaveType: json['leave_type'] as String? ?? 'OTHER',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      remarks: json['remarks'] as String?,
      status: json['status'] as String? ?? 'PENDING',
      requestedAt: json['requested_at'] as String? ?? '',
      reviewedAt: json['reviewed_at'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      reviewerRemarks: json['reviewer_remarks'] as String?,
      cancelledAt: json['cancelled_at'] as String?,
      cancellationReason: json['cancellation_reason'] as String?,
      teacherName: resolvedTeacherName.isEmpty ? 'Unknown Teacher' : resolvedTeacherName,
      teacherDesignation: resolvedDesignation,
      teacherDepartment: resolvedDepartment,
    );
  }
}
