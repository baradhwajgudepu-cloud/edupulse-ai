// Strongly typed models for School Administration, Compliance, Recognition, Custom Fields, and Documents.

class SchoolProfileDto {
  final String id;
  final String tenantId;
  final String schoolId;
  final String schoolName;
  final String schoolCode;
  final String board;
  final String schoolType;
  final String email;
  final String? phone;
  final String? website;
  final String? principalName;
  final String? address;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? logoUrl;

  final String? schoolCategory;
  final String? managementType;
  final String? schoolLevel;
  final int? establishedYear;
  final String mediumOfInstruction;
  final String genderType;
  final String minorityStatus;
  final String areaType;
  final String? schoolPhotoUrl;
  final String? schoolMotto;

  final String? correspondentName;
  final String? headmasterName;
  final String? managementContact;
  final String? emergencyContact;
  final String? schoolWorkingHours;
  final String? officeWorkingHours;
  final String? morningAssemblyTime;
  final String? lunchTime;

  final int totalCapacity;
  final int currentCapacity;
  final int totalSectionsCount;
  final bool hasTransport;
  final bool hasHostel;
  final bool hasLibrary;
  final bool hasLaboratory;
  final bool hasSportsFacilities;
  final bool hasSmartClassrooms;
  final bool hasComputerLab;
  final bool hasMedicalRoom;
  final bool hasCctv;
  final bool hasFireSafety;
  final bool hasWaterSanitation;
  final bool hasElectricityBackup;
  final bool hasAccessibilityRamps;

  final String? udiseCode;
  final String udiseStatus;
  final String udiseVerificationStatus;
  final DateTime? udiseVerifiedAt;
  final String? udiseVerifiedByName;
  final String? udiseNotes;
  final Map<String, dynamic> customValues;

  const SchoolProfileDto({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.schoolName,
    required this.schoolCode,
    required this.board,
    required this.schoolType,
    required this.email,
    this.phone,
    this.website,
    this.principalName,
    this.address,
    this.city,
    this.state,
    this.postalCode,
    this.logoUrl,
    this.schoolCategory,
    this.managementType,
    this.schoolLevel,
    this.establishedYear,
    required this.mediumOfInstruction,
    required this.genderType,
    required this.minorityStatus,
    required this.areaType,
    this.schoolPhotoUrl,
    this.schoolMotto,
    this.correspondentName,
    this.headmasterName,
    this.managementContact,
    this.emergencyContact,
    this.schoolWorkingHours,
    this.officeWorkingHours,
    this.morningAssemblyTime,
    this.lunchTime,
    required this.totalCapacity,
    required this.currentCapacity,
    required this.totalSectionsCount,
    required this.hasTransport,
    required this.hasHostel,
    required this.hasLibrary,
    required this.hasLaboratory,
    required this.hasSportsFacilities,
    required this.hasSmartClassrooms,
    required this.hasComputerLab,
    required this.hasMedicalRoom,
    required this.hasCctv,
    required this.hasFireSafety,
    required this.hasWaterSanitation,
    required this.hasElectricityBackup,
    required this.hasAccessibilityRamps,
    this.udiseCode,
    required this.udiseStatus,
    required this.udiseVerificationStatus,
    this.udiseVerifiedAt,
    this.udiseVerifiedByName,
    this.udiseNotes,
    required this.customValues,
  });

  factory SchoolProfileDto.fromJson(Map<String, dynamic> json) {
    return SchoolProfileDto(
      id: json['id']?.toString() ?? '',
      tenantId: json['tenant_id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      schoolName: json['school_name']?.toString() ?? '',
      schoolCode: json['school_code']?.toString() ?? '',
      board: json['board']?.toString() ?? '',
      schoolType: json['school_type']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      website: json['website']?.toString(),
      principalName: json['principal_name']?.toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      postalCode: json['postal_code']?.toString(),
      logoUrl: json['logo_url']?.toString(),
      schoolCategory: json['school_category']?.toString(),
      managementType: json['management_type']?.toString(),
      schoolLevel: json['school_level']?.toString(),
      establishedYear: (json['established_year'] as num?)?.toInt(),
      mediumOfInstruction: json['medium_of_instruction']?.toString() ?? 'English',
      genderType: json['gender_type']?.toString() ?? 'Co-Education',
      minorityStatus: json['minority_status']?.toString() ?? 'Non-Minority',
      areaType: json['area_type']?.toString() ?? 'Urban',
      schoolPhotoUrl: json['school_photo_url']?.toString(),
      schoolMotto: json['school_motto']?.toString(),
      correspondentName: json['correspondent_name']?.toString(),
      headmasterName: json['headmaster_name']?.toString(),
      managementContact: json['management_contact']?.toString(),
      emergencyContact: json['emergency_contact']?.toString(),
      schoolWorkingHours: json['school_working_hours']?.toString(),
      officeWorkingHours: json['office_working_hours']?.toString(),
      morningAssemblyTime: json['morning_assembly_time']?.toString(),
      lunchTime: json['lunch_time']?.toString(),
      totalCapacity: (json['total_capacity'] as num?)?.toInt() ?? 1000,
      currentCapacity: (json['current_capacity'] as num?)?.toInt() ?? 0,
      totalSectionsCount: (json['total_sections_count'] as num?)?.toInt() ?? 0,
      hasTransport: json['has_transport'] == true,
      hasHostel: json['has_hostel'] == true,
      hasLibrary: json['has_library'] ?? true,
      hasLaboratory: json['has_laboratory'] ?? true,
      hasSportsFacilities: json['has_sports_facilities'] ?? true,
      hasSmartClassrooms: json['has_smart_classrooms'] == true,
      hasComputerLab: json['has_computer_lab'] ?? true,
      hasMedicalRoom: json['has_medical_room'] == true,
      hasCctv: json['has_cctv'] == true,
      hasFireSafety: json['has_fire_safety'] == true,
      hasWaterSanitation: json['has_water_sanitation'] ?? true,
      hasElectricityBackup: json['has_electricity_backup'] == true,
      hasAccessibilityRamps: json['has_accessibility_ramps'] == true,
      udiseCode: json['udise_code']?.toString(),
      udiseStatus: json['udise_status']?.toString() ?? 'CONFIGURED',
      udiseVerificationStatus: json['udise_verification_status']?.toString() ?? 'UNVERIFIED',
      udiseVerifiedAt: json['udise_verified_at'] != null ? DateTime.tryParse(json['udise_verified_at'].toString()) : null,
      udiseVerifiedByName: json['udise_verified_by_name']?.toString(),
      udiseNotes: json['udise_notes']?.toString(),
      customValues: json['custom_values'] is Map ? Map<String, dynamic>.from(json['custom_values']) : {},
    );
  }
}

class SchoolRecognitionDto {
  final String id;
  final String tenantId;
  final String schoolId;
  final String authorityLevel; // CENTRAL, STATE, OTHER
  final String authorityName;
  final String recognitionType; // AFFILIATION, RECOGNITION, NOC, REGISTRATION
  final String recognitionNumber;
  final String? certificateNumber;
  final String? proceedingsOrderNumber;
  final String? issueDate;
  final String? validFrom;
  final String? validUntil;
  final String status; // ACTIVE, EXPIRED, PENDING, RENEWAL_IN_PROGRESS
  final String? documentId;
  final String? documentTitle;
  final String? remarks;

  const SchoolRecognitionDto({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.authorityLevel,
    required this.authorityName,
    required this.recognitionType,
    required this.recognitionNumber,
    this.certificateNumber,
    this.proceedingsOrderNumber,
    this.issueDate,
    this.validFrom,
    this.validUntil,
    required this.status,
    this.documentId,
    this.documentTitle,
    this.remarks,
  });

  factory SchoolRecognitionDto.fromJson(Map<String, dynamic> json) {
    return SchoolRecognitionDto(
      id: json['id']?.toString() ?? '',
      tenantId: json['tenant_id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      authorityLevel: json['authority_level']?.toString() ?? 'STATE',
      authorityName: json['authority_name']?.toString() ?? '',
      recognitionType: json['recognition_type']?.toString() ?? 'RECOGNITION',
      recognitionNumber: json['recognition_number']?.toString() ?? '',
      certificateNumber: json['certificate_number']?.toString(),
      proceedingsOrderNumber: json['proceedings_order_number']?.toString(),
      issueDate: json['issue_date']?.toString(),
      validFrom: json['valid_from']?.toString(),
      validUntil: json['valid_until']?.toString(),
      status: json['status']?.toString() ?? 'ACTIVE',
      documentId: json['document_id']?.toString(),
      documentTitle: json['document_title']?.toString(),
      remarks: json['remarks']?.toString(),
    );
  }
}

class SchoolCustomFieldDto {
  final String id;
  final String schoolId;
  final String fieldName;
  final String fieldKey;
  final String fieldType;
  final List<String> fieldOptions;
  final bool isRequired;
  final bool visibleToPrincipal;
  final bool visibleToTeachers;
  final bool visibleToParents;

  const SchoolCustomFieldDto({
    required this.id,
    required this.schoolId,
    required this.fieldName,
    required this.fieldKey,
    required this.fieldType,
    required this.fieldOptions,
    required this.isRequired,
    required this.visibleToPrincipal,
    required this.visibleToTeachers,
    required this.visibleToParents,
  });

  factory SchoolCustomFieldDto.fromJson(Map<String, dynamic> json) {
    return SchoolCustomFieldDto(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      fieldName: json['field_name']?.toString() ?? '',
      fieldKey: json['field_key']?.toString() ?? '',
      fieldType: json['field_type']?.toString() ?? 'TEXT',
      fieldOptions: (json['field_options'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      isRequired: json['is_required'] == true,
      visibleToPrincipal: json['visible_to_principal'] ?? true,
      visibleToTeachers: json['visible_to_teachers'] == true,
      visibleToParents: json['visible_to_parents'] == true,
    );
  }
}

class SchoolDocumentDto {
  final String id;
  final String schoolId;
  final String category;
  final String title;
  final String? issuingAuthority;
  final String? documentNumber;
  final String fileName;
  final String filePath;
  final int fileSizeBytes;
  final String contentType;
  final String? issueDate;
  final String? expiryDate;
  final String confidentialityLevel;
  final bool isPasswordProtected;
  final bool isArchived;
  final String? remarks;
  final String? uploadedByName;
  final bool isExpiringSoon;
  final bool isExpired;
  final int? daysUntilExpiry;

  const SchoolDocumentDto({
    required this.id,
    required this.schoolId,
    required this.category,
    required this.title,
    this.issuingAuthority,
    this.documentNumber,
    required this.fileName,
    required this.filePath,
    required this.fileSizeBytes,
    required this.contentType,
    this.issueDate,
    this.expiryDate,
    required this.confidentialityLevel,
    required this.isPasswordProtected,
    required this.isArchived,
    this.remarks,
    this.uploadedByName,
    required this.isExpiringSoon,
    required this.isExpired,
    this.daysUntilExpiry,
  });

  bool get isPdf =>
      contentType.toLowerCase().contains('pdf') ||
      fileName.toLowerCase().endsWith('.pdf');

  bool get isImage =>
      contentType.toLowerCase().contains('image') ||
      fileName.toLowerCase().endsWith('.png') ||
      fileName.toLowerCase().endsWith('.jpg') ||
      fileName.toLowerCase().endsWith('.jpeg') ||
      fileName.toLowerCase().endsWith('.webp');

  bool get hasFile => fileSizeBytes > 0 && filePath.isNotEmpty;

  String get formattedFileSize {
    if (fileSizeBytes <= 0) return '0 B';
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  factory SchoolDocumentDto.fromJson(Map<String, dynamic> json) {
    return SchoolDocumentDto(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      category: json['category']?.toString() ?? 'OTHER',
      title: json['title']?.toString() ?? '',
      issuingAuthority: json['issuing_authority']?.toString(),
      documentNumber: json['document_number']?.toString(),
      fileName: json['file_name']?.toString() ?? '',
      filePath: json['file_path']?.toString() ?? '',
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? 0,
      contentType: json['content_type']?.toString() ?? 'application/pdf',
      issueDate: json['issue_date']?.toString(),
      expiryDate: json['expiry_date']?.toString(),
      confidentialityLevel: json['confidentiality_level']?.toString() ?? 'STANDARD',
      isPasswordProtected: json['is_password_protected'] == true,
      isArchived: json['is_archived'] == true,
      remarks: json['remarks']?.toString(),
      uploadedByName: json['uploaded_by_name']?.toString(),
      isExpiringSoon: json['is_expiring_soon'] == true,
      isExpired: json['is_expired'] == true,
      daysUntilExpiry: (json['days_until_expiry'] as num?)?.toInt(),
    );
  }
}

class ComplianceDashboardDto {
  final String schoolId;
  final String schoolName;
  final String? udiseCode;
  final bool udiseConfigured;
  final String udiseVerificationStatus;
  final DateTime? udiseVerifiedAt;

  final int totalRecognitions;
  final int activeRecognitions;
  final int centralRecognitionsCount;
  final int stateRecognitionsCount;

  final int totalDocuments;
  final int confidentialDocumentsCount;
  final int expiringDocumentsCount;
  final int expiredDocumentsCount;

  final bool payrollPolicyConfigured;
  final bool payrollReady;
  final int teachersCount;
  final int pendingPayrollCount;
  final int approvedPayrollCount;

  const ComplianceDashboardDto({
    required this.schoolId,
    required this.schoolName,
    this.udiseCode,
    required this.udiseConfigured,
    required this.udiseVerificationStatus,
    this.udiseVerifiedAt,
    required this.totalRecognitions,
    required this.activeRecognitions,
    required this.centralRecognitionsCount,
    required this.stateRecognitionsCount,
    required this.totalDocuments,
    required this.confidentialDocumentsCount,
    required this.expiringDocumentsCount,
    required this.expiredDocumentsCount,
    required this.payrollPolicyConfigured,
    required this.payrollReady,
    required this.teachersCount,
    required this.pendingPayrollCount,
    required this.approvedPayrollCount,
  });

  factory ComplianceDashboardDto.fromJson(Map<String, dynamic> json) {
    return ComplianceDashboardDto(
      schoolId: json['school_id']?.toString() ?? '',
      schoolName: json['school_name']?.toString() ?? '',
      udiseCode: json['udise_code']?.toString(),
      udiseConfigured: json['udise_configured'] == true,
      udiseVerificationStatus: json['udise_verification_status']?.toString() ?? 'UNVERIFIED',
      udiseVerifiedAt: json['udise_verified_at'] != null ? DateTime.tryParse(json['udise_verified_at'].toString()) : null,
      totalRecognitions: (json['total_recognitions'] as num?)?.toInt() ?? 0,
      activeRecognitions: (json['active_recognitions'] as num?)?.toInt() ?? 0,
      centralRecognitionsCount: (json['central_recognitions_count'] as num?)?.toInt() ?? 0,
      stateRecognitionsCount: (json['state_recognitions_count'] as num?)?.toInt() ?? 0,
      totalDocuments: (json['total_documents'] as num?)?.toInt() ?? 0,
      confidentialDocumentsCount: (json['confidential_documents_count'] as num?)?.toInt() ?? 0,
      expiringDocumentsCount: (json['expiring_documents_count'] as num?)?.toInt() ?? 0,
      expiredDocumentsCount: (json['expired_documents_count'] as num?)?.toInt() ?? 0,
      payrollPolicyConfigured: json['payroll_policy_configured'] == true,
      payrollReady: json['payroll_ready'] == true,
      teachersCount: (json['teachers_count'] as num?)?.toInt() ?? 0,
      pendingPayrollCount: (json['pending_payroll_count'] as num?)?.toInt() ?? 0,
      approvedPayrollCount: (json['approved_payroll_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class DocumentExpiryAlertDto {
  final String documentId;
  final String title;
  final String category;
  final String? documentNumber;
  final String expiryDate;
  final int daysRemaining;
  final bool isExpired;
  final String recommendedAction;

  const DocumentExpiryAlertDto({
    required this.documentId,
    required this.title,
    required this.category,
    this.documentNumber,
    required this.expiryDate,
    required this.daysRemaining,
    required this.isExpired,
    required this.recommendedAction,
  });

  factory DocumentExpiryAlertDto.fromJson(Map<String, dynamic> json) {
    return DocumentExpiryAlertDto(
      documentId: json['document_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      documentNumber: json['document_number']?.toString(),
      expiryDate: json['expiry_date']?.toString() ?? '',
      daysRemaining: (json['days_remaining'] as num?)?.toInt() ?? 0,
      isExpired: json['is_expired'] == true,
      recommendedAction: json['recommended_action']?.toString() ?? '',
    );
  }
}

class DocumentExpiryMonitorDto {
  final int totalMonitored;
  final int expiringSoonCount;
  final int expiredCount;
  final List<DocumentExpiryAlertDto> alerts;
  final List<String> missingMandatoryCategories;

  const DocumentExpiryMonitorDto({
    required this.totalMonitored,
    required this.expiringSoonCount,
    required this.expiredCount,
    required this.alerts,
    required this.missingMandatoryCategories,
  });

  factory DocumentExpiryMonitorDto.fromJson(Map<String, dynamic> json) {
    return DocumentExpiryMonitorDto(
      totalMonitored: (json['total_monitored'] as num?)?.toInt() ?? 0,
      expiringSoonCount: (json['expiring_soon_count'] as num?)?.toInt() ?? 0,
      expiredCount: (json['expired_count'] as num?)?.toInt() ?? 0,
      alerts: (json['alerts'] as List<dynamic>?)
              ?.map((e) => DocumentExpiryAlertDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      missingMandatoryCategories: (json['missing_mandatory_categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class DocumentAccessLogDto {
  final String id;
  final String documentId;
  final String documentTitle;
  final String? userName;
  final String action;
  final String? ipAddress;
  final DateTime createdAt;

  const DocumentAccessLogDto({
    required this.id,
    required this.documentId,
    required this.documentTitle,
    this.userName,
    required this.action,
    this.ipAddress,
    required this.createdAt,
  });

  factory DocumentAccessLogDto.fromJson(Map<String, dynamic> json) {
    return DocumentAccessLogDto(
      id: json['id']?.toString() ?? '',
      documentId: json['document_id']?.toString() ?? '',
      documentTitle: json['document_title']?.toString() ?? 'Document',
      userName: json['user_name']?.toString(),
      action: json['action']?.toString() ?? 'VIEW',
      ipAddress: json['ip_address']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class ComplianceRequirementDto {
  final String id;
  final String code;
  final String title;
  final String category;
  final String applicableAuthority;
  final String statutoryReference;
  final String requirementDescription;
  final String whatSchoolMustMaintain;
  final List<String> requiredDocuments;
  final Map<String, dynamic> fieldSchema;
  final int? defaultValidityMonths;
  final int renewalReminderDays;
  final bool mandatory;
  final int sortOrder;
  final bool isActive;

  const ComplianceRequirementDto({
    required this.id,
    required this.code,
    required this.title,
    required this.category,
    required this.applicableAuthority,
    required this.statutoryReference,
    required this.requirementDescription,
    required this.whatSchoolMustMaintain,
    required this.requiredDocuments,
    required this.fieldSchema,
    this.defaultValidityMonths,
    required this.renewalReminderDays,
    required this.mandatory,
    required this.sortOrder,
    required this.isActive,
  });

  factory ComplianceRequirementDto.fromJson(Map<String, dynamic> json) {
    return ComplianceRequirementDto(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      applicableAuthority: json['applicable_authority']?.toString() ?? '',
      statutoryReference: json['statutory_reference']?.toString() ?? '',
      requirementDescription: json['requirement_description']?.toString() ?? '',
      whatSchoolMustMaintain: json['what_school_must_maintain']?.toString() ?? '',
      requiredDocuments: (json['required_documents'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      fieldSchema: json['field_schema'] is Map<String, dynamic>
          ? json['field_schema'] as Map<String, dynamic>
          : {},
      defaultValidityMonths: (json['default_validity_months'] as num?)?.toInt(),
      renewalReminderDays: (json['renewal_reminder_days'] as num?)?.toInt() ?? 60,
      mandatory: json['mandatory'] != false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] != false,
    );
  }
}

class ComplianceDocumentSummaryDto {
  final String id;
  final String title;
  final String fileName;
  final String filePath;
  final String contentType;
  final int fileSizeBytes;
  final String? issueDate;
  final String? expiryDate;
  final String? issuingAuthority;
  final String? documentNumber;

  const ComplianceDocumentSummaryDto({
    required this.id,
    required this.title,
    required this.fileName,
    required this.filePath,
    required this.contentType,
    required this.fileSizeBytes,
    this.issueDate,
    this.expiryDate,
    this.issuingAuthority,
    this.documentNumber,
  });

  factory ComplianceDocumentSummaryDto.fromJson(Map<String, dynamic> json) {
    return ComplianceDocumentSummaryDto(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      fileName: json['file_name']?.toString() ?? '',
      filePath: json['file_path']?.toString() ?? '',
      contentType: json['content_type']?.toString() ?? 'application/pdf',
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? 0,
      issueDate: json['issue_date']?.toString(),
      expiryDate: json['expiry_date']?.toString(),
      issuingAuthority: json['issuing_authority']?.toString(),
      documentNumber: json['document_number']?.toString(),
    );
  }
}

class ComplianceAuditLogDto {
  final String id;
  final String recordId;
  final String action;
  final String? actorId;
  final String? actorName;
  final String? actorRole;
  final Map<String, dynamic> changes;
  final String? notes;
  final DateTime createdAt;

  const ComplianceAuditLogDto({
    required this.id,
    required this.recordId,
    required this.action,
    this.actorId,
    this.actorName,
    this.actorRole,
    required this.changes,
    this.notes,
    required this.createdAt,
  });

  factory ComplianceAuditLogDto.fromJson(Map<String, dynamic> json) {
    return ComplianceAuditLogDto(
      id: json['id']?.toString() ?? '',
      recordId: json['record_id']?.toString() ?? '',
      action: json['action']?.toString() ?? 'UPDATED',
      actorId: json['actor_id']?.toString(),
      actorName: json['actor_name']?.toString(),
      actorRole: json['actor_role']?.toString(),
      changes: json['changes'] is Map<String, dynamic>
          ? json['changes'] as Map<String, dynamic>
          : {},
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class ComplianceRecordDto {
  final String id;
  final String tenantId;
  final String schoolId;
  final String requirementId;
  final ComplianceRequirementDto requirement;
  final String status;
  final String? certificateNumber;
  final String? issuingAuthority;
  final String? issueDate;
  final String? expiryDate;
  final String? lastInspectionDate;
  final String? nextRenewalDate;
  final String? primaryDocumentId;
  final ComplianceDocumentSummaryDto? primaryDocument;
  final List<String> supportingDocumentIds;
  final List<ComplianceDocumentSummaryDto> supportingDocuments;
  final List<String> photoEvidenceUrls;
  final Map<String, dynamic> specificData;
  final List<String> missingItems;
  final String verificationStatus;
  final DateTime? verifiedAt;
  final String? verifiedBy;
  final String? verifiedByName;
  final String? verificationNotes;
  final String? remarks;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? daysUntilExpiry;
  final bool isExpired;
  final bool isExpiringSoon;

  const ComplianceRecordDto({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.requirementId,
    required this.requirement,
    required this.status,
    this.certificateNumber,
    this.issuingAuthority,
    this.issueDate,
    this.expiryDate,
    this.lastInspectionDate,
    this.nextRenewalDate,
    this.primaryDocumentId,
    this.primaryDocument,
    required this.supportingDocumentIds,
    required this.supportingDocuments,
    required this.photoEvidenceUrls,
    required this.specificData,
    required this.missingItems,
    required this.verificationStatus,
    this.verifiedAt,
    this.verifiedBy,
    this.verifiedByName,
    this.verificationNotes,
    this.remarks,
    required this.createdAt,
    required this.updatedAt,
    this.daysUntilExpiry,
    required this.isExpired,
    required this.isExpiringSoon,
  });

  String get statusDisplayLabel {
    switch (status.toUpperCase()) {
      case 'VERIFIED':
        return 'Verified / Compliant';
      case 'PENDING_VERIFICATION':
        return 'Pending Verification';
      case 'MISSING_EVIDENCE':
        return 'Missing Evidence';
      case 'EXPIRING_SOON':
        return 'Expiring Soon';
      case 'EXPIRED':
        return 'Expired';
      case 'NON_COMPLIANT':
        return 'Non-Compliant';
      case 'NOT_APPLICABLE':
        return 'Not Applicable';
      default:
        return status;
    }
  }

  bool get hasValidEvidence => primaryDocument != null && (certificateNumber?.isNotEmpty ?? false);

  factory ComplianceRecordDto.fromJson(Map<String, dynamic> json) {
    return ComplianceRecordDto(
      id: json['id']?.toString() ?? '',
      tenantId: json['tenant_id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      requirementId: json['requirement_id']?.toString() ?? '',
      requirement: ComplianceRequirementDto.fromJson(
        json['requirement'] is Map<String, dynamic>
            ? json['requirement'] as Map<String, dynamic>
            : {},
      ),
      status: json['status']?.toString() ?? 'MISSING_EVIDENCE',
      certificateNumber: json['certificate_number']?.toString(),
      issuingAuthority: json['issuing_authority']?.toString(),
      issueDate: json['issue_date']?.toString(),
      expiryDate: json['expiry_date']?.toString(),
      lastInspectionDate: json['last_inspection_date']?.toString(),
      nextRenewalDate: json['next_renewal_date']?.toString(),
      primaryDocumentId: json['primary_document_id']?.toString(),
      primaryDocument: json['primary_document'] is Map<String, dynamic>
          ? ComplianceDocumentSummaryDto.fromJson(json['primary_document'] as Map<String, dynamic>)
          : null,
      supportingDocumentIds: (json['supporting_document_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      supportingDocuments: (json['supporting_documents'] as List<dynamic>?)
              ?.map((e) => ComplianceDocumentSummaryDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      photoEvidenceUrls: (json['photo_evidence_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      specificData: json['specific_data'] is Map<String, dynamic>
          ? json['specific_data'] as Map<String, dynamic>
          : {},
      missingItems: (json['missing_items'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      verificationStatus: json['verification_status']?.toString() ?? 'UNVERIFIED',
      verifiedAt: json['verified_at'] != null ? DateTime.tryParse(json['verified_at'].toString()) : null,
      verifiedBy: json['verified_by']?.toString(),
      verifiedByName: json['verified_by_name']?.toString(),
      verificationNotes: json['verification_notes']?.toString(),
      remarks: json['remarks']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      daysUntilExpiry: (json['days_until_expiry'] as num?)?.toInt(),
      isExpired: json['is_expired'] == true,
      isExpiringSoon: json['is_expiring_soon'] == true,
    );
  }
}

class ComplianceDashboardSummaryDto {
  final String schoolId;
  final int totalRequirements;
  final int verifiedCount;
  final int pendingVerificationCount;
  final int missingEvidenceCount;
  final int expiringSoonCount;
  final int expiredCount;
  final int nonCompliantCount;
  final int notApplicableCount;
  final double compliancePercentage;
  final List<ComplianceRecordDto> items;

  const ComplianceDashboardSummaryDto({
    required this.schoolId,
    required this.totalRequirements,
    required this.verifiedCount,
    required this.pendingVerificationCount,
    required this.missingEvidenceCount,
    required this.expiringSoonCount,
    required this.expiredCount,
    required this.nonCompliantCount,
    required this.notApplicableCount,
    required this.compliancePercentage,
    required this.items,
  });

  factory ComplianceDashboardSummaryDto.fromJson(Map<String, dynamic> json) {
    return ComplianceDashboardSummaryDto(
      schoolId: json['school_id']?.toString() ?? '',
      totalRequirements: (json['total_requirements'] as num?)?.toInt() ?? 0,
      verifiedCount: (json['verified_count'] as num?)?.toInt() ?? 0,
      pendingVerificationCount: (json['pending_verification_count'] as num?)?.toInt() ?? 0,
      missingEvidenceCount: (json['missing_evidence_count'] as num?)?.toInt() ?? 0,
      expiringSoonCount: (json['expiring_soon_count'] as num?)?.toInt() ?? 0,
      expiredCount: (json['expired_count'] as num?)?.toInt() ?? 0,
      nonCompliantCount: (json['non_compliant_count'] as num?)?.toInt() ?? 0,
      notApplicableCount: (json['not_applicable_count'] as num?)?.toInt() ?? 0,
      compliancePercentage: (json['compliance_percentage'] as num?)?.toDouble() ?? 0.0,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ComplianceRecordDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

