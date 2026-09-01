class CommunicationRequest {
  final String id;
  final String tenantId;
  final String schoolId;
  final String studentId;
  final String creatorId;
  final String? assignedToId;
  final String recipientType;
  final String category;
  final String module;
  final String? referenceType;
  final String? referenceId;
  final String subject;
  final String priority;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final bool isActive;
  final int version;
  final int unreadMessagesCount;

  CommunicationRequest({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.studentId,
    required this.creatorId,
    this.assignedToId,
    required this.recipientType,
    required this.category,
    required this.module,
    this.referenceType,
    this.referenceId,
    required this.subject,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    required this.isActive,
    required this.version,
    this.unreadMessagesCount = 0,
  });

  factory CommunicationRequest.fromJson(Map<String, dynamic> json) {
    return CommunicationRequest(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      studentId: json['student_id'] as String,
      creatorId: json['creator_id'] as String,
      assignedToId: json['assigned_to_id'] as String?,
      recipientType: json['recipient_type'] as String,
      category: json['category'] as String,
      module: json['module'] as String,
      referenceType: json['reference_type'] as String?,
      referenceId: json['reference_id'] as String?,
      subject: json['subject'] as String,
      priority: json['priority'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      resolvedAt: json['resolved_at'] != null 
          ? DateTime.parse(json['resolved_at'] as String).toLocal() 
          : null,
      isActive: json['is_active'] as bool? ?? true,
      version: json['version'] as int? ?? 1,
      unreadMessagesCount: json['unread_messages_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'school_id': schoolId,
      'student_id': studentId,
      'creator_id': creatorId,
      'assigned_to_id': assignedToId,
      'recipient_type': recipientType,
      'category': category,
      'module': module,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'subject': subject,
      'priority': priority,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'is_active': isActive,
      'version': version,
      'unread_messages_count': unreadMessagesCount,
    };
  }
}

class CommunicationAttachment {
  final String id;
  final String tenantId;
  final String schoolId;
  final String messageId;
  final String fileName;
  final String fileType;
  final int fileSize;
  final String fileUrl;
  final String uploadedById;
  final DateTime uploadedAt;

  CommunicationAttachment({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.messageId,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.fileUrl,
    required this.uploadedById,
    required this.uploadedAt,
  });

  factory CommunicationAttachment.fromJson(Map<String, dynamic> json) {
    return CommunicationAttachment(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      messageId: json['message_id'] as String,
      fileName: json['file_name'] as String,
      fileType: json['file_type'] as String,
      fileSize: json['file_size'] as int,
      fileUrl: json['file_url'] as String,
      uploadedById: json['uploaded_by_id'] as String,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'school_id': schoolId,
      'message_id': messageId,
      'file_name': fileName,
      'file_type': fileType,
      'file_size': fileSize,
      'file_url': fileUrl,
      'uploaded_by_id': uploadedById,
      'uploaded_at': uploadedAt.toIso8601String(),
    };
  }
}

class CommunicationMessage {
  final String id;
  final String requestId;
  final String senderId;
  final String senderRole;
  final String message;
  final DateTime createdAt;
  final List<CommunicationAttachment> attachments;

  CommunicationMessage({
    required this.id,
    required this.requestId,
    required this.senderId,
    required this.senderRole,
    required this.message,
    required this.createdAt,
    required this.attachments,
  });

  factory CommunicationMessage.fromJson(Map<String, dynamic> json) {
    final rawAttachments = json['attachments'] as List? ?? [];
    return CommunicationMessage(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      senderId: json['sender_id'] as String,
      senderRole: json['sender_role'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      attachments: rawAttachments
          .map((e) => CommunicationAttachment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'sender_id': senderId,
      'sender_role': senderRole,
      'message': message,
      'created_at': createdAt.toIso8601String(),
      'attachments': attachments.map((e) => e.toJson()).toList(),
    };
  }
}

class CommunicationParticipant {
  final String id;
  final String tenantId;
  final String schoolId;
  final String requestId;
  final String userId;
  final String role;
  final DateTime? lastReadAt;

  CommunicationParticipant({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.requestId,
    required this.userId,
    required this.role,
    this.lastReadAt,
  });

  factory CommunicationParticipant.fromJson(Map<String, dynamic> json) {
    return CommunicationParticipant(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      requestId: json['request_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String,
      lastReadAt: json['last_read_at'] != null 
          ? DateTime.parse(json['last_read_at'] as String).toLocal() 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'school_id': schoolId,
      'request_id': requestId,
      'user_id': userId,
      'role': role,
      'last_read_at': lastReadAt?.toIso8601String(),
    };
  }
}

class CommunicationAuditLog {
  final String id;
  final String tenantId;
  final String schoolId;
  final String requestId;
  final String userId;
  final String action;
  final String details;
  final DateTime timestamp;

  CommunicationAuditLog({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.requestId,
    required this.userId,
    required this.action,
    required this.details,
    required this.timestamp,
  });

  factory CommunicationAuditLog.fromJson(Map<String, dynamic> json) {
    return CommunicationAuditLog(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      requestId: json['request_id'] as String,
      userId: json['user_id'] as String,
      action: json['action'] as String,
      details: json['details'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'school_id': schoolId,
      'request_id': requestId,
      'user_id': userId,
      'action': action,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class CommunicationRequestDetail {
  final CommunicationRequest request;
  final List<CommunicationMessage> messages;
  final List<CommunicationParticipant> participants;
  final List<CommunicationAuditLog> auditLogs;

  CommunicationRequestDetail({
    required this.request,
    required this.messages,
    required this.participants,
    required this.auditLogs,
  });

  factory CommunicationRequestDetail.fromJson(Map<String, dynamic> json) {
    final rawRequest = json['request'] as Map<String, dynamic>;
    final rawMessages = json['messages'] as List? ?? [];
    final rawParticipants = json['participants'] as List? ?? [];
    final rawAuditLogs = json['audit_logs'] as List? ?? [];

    return CommunicationRequestDetail(
      request: CommunicationRequest.fromJson(rawRequest),
      messages: rawMessages
          .map((e) => CommunicationMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
      participants: rawParticipants
          .map((e) => CommunicationParticipant.fromJson(e as Map<String, dynamic>))
          .toList(),
      auditLogs: rawAuditLogs
          .map((e) => CommunicationAuditLog.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'request': request.toJson(),
      'messages': messages.map((e) => e.toJson()).toList(),
      'participants': participants.map((e) => e.toJson()).toList(),
      'audit_logs': auditLogs.map((e) => e.toJson()).toList(),
    };
  }
}

class CommunicationAnalytics {
  final int totalRequests;
  final int openCount;
  final int acknowledgedCount;
  final int inProgressCount;
  final int resolvedCount;
  final int escalatedCount;
  final int reopenCount;
  final int slaBreachCount;
  final double averageResolutionTimeHours;
  final List<CommunicationRequest> urgentRequests;

  CommunicationAnalytics({
    required this.totalRequests,
    required this.openCount,
    required this.acknowledgedCount,
    required this.inProgressCount,
    required this.resolvedCount,
    required this.escalatedCount,
    required this.reopenCount,
    required this.slaBreachCount,
    required this.averageResolutionTimeHours,
    required this.urgentRequests,
  });

  factory CommunicationAnalytics.fromJson(Map<String, dynamic> json) {
    final rawUrgent = json['urgent_requests'] as List? ?? [];
    return CommunicationAnalytics(
      totalRequests: json['total_requests'] as int? ?? 0,
      openCount: json['open_count'] as int? ?? 0,
      acknowledgedCount: json['acknowledged_count'] as int? ?? 0,
      inProgressCount: json['in_progress_count'] as int? ?? 0,
      resolvedCount: json['resolved_count'] as int? ?? 0,
      escalatedCount: json['escalated_count'] as int? ?? 0,
      reopenCount: json['reopen_count'] as int? ?? 0,
      slaBreachCount: json['sla_breach_count'] as int? ?? 0,
      averageResolutionTimeHours: (json['average_resolution_time_hours'] as num?)?.toDouble() ?? 0.0,
      urgentRequests: rawUrgent
          .map((e) => CommunicationRequest.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
