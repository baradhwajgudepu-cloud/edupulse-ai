import 'package:flutter/foundation.dart';

@immutable
class SchoolDto {
  final String id;
  final String tenantId;
  final String name;
  final String? displayName;
  final String code;
  final String board;
  final String schoolType;
  final String email;
  final String? phone;
  final String? website;
  final String? principalName;
  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final String? logoUrl;
  final String? logoUpdatedAt;
  final bool isActive;
  final String status;
  final Map<String, dynamic>? settings;
  final String? udiseCode;
  final int version;
  final double? latitude;
  final double? longitude;
  final int? geofenceRadiusMeters;

  bool get hasLogo => logoUrl != null && logoUrl!.trim().isNotEmpty;
  bool get isGeofenceConfigured => latitude != null && longitude != null;
  bool get isGeofencingEnabled {
    if (settings != null && settings!['geofence'] != null) {
      final gf = settings!['geofence'];
      if (gf is Map && gf['enabled'] != null) {
        return gf['enabled'] as bool;
      }
    }
    return isGeofenceConfigured;
  }

  const SchoolDto({
    required this.id,
    required this.tenantId,
    required this.name,
    this.displayName,
    required this.code,
    required this.board,
    required this.schoolType,
    required this.email,
    this.phone,
    this.website,
    this.principalName,
    this.address,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    this.logoUrl,
    this.logoUpdatedAt,
    required this.isActive,
    required this.status,
    this.settings,
    this.udiseCode,
    required this.version,
    this.latitude,
    this.longitude,
    this.geofenceRadiusMeters,
  });

  factory SchoolDto.fromJson(Map<String, dynamic> json) {
    return SchoolDto(
      id: (json['id'] ?? '') as String,
      tenantId: (json['tenant_id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      displayName: json['display_name'] as String?,
      code: (json['code'] ?? '') as String,
      board: (json['board'] ?? '') as String,
      schoolType: (json['school_type'] ?? 'HIGH_SCHOOL') as String,
      email: (json['email'] ?? '') as String,
      phone: json['phone'] as String?,
      website: json['website'] as String?,
      principalName: json['principal_name'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String?,
      postalCode: json['postal_code'] as String?,
      logoUrl: json['logo_url'] as String?,
      logoUpdatedAt: json['logo_updated_at'] as String? ??
          (json['settings'] != null && json['settings'] is Map && (json['settings'] as Map)['branding'] != null
              ? ((json['settings'] as Map)['branding'] as Map)['logo_updated_at'] as String?
              : null),
      isActive: json['is_active'] as bool? ?? true,
      status: json['status'] as String? ?? 'ACTIVE',
      settings: json['settings'] as Map<String, dynamic>?,
      udiseCode: json['udise_code'] as String?,
      version: json['version'] as int? ?? 1,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      geofenceRadiusMeters: json['geofence_radius_meters'] as int? ?? json['geofence_radius'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'display_name': displayName,
      'code': code,
      'board': board,
      'school_type': schoolType,
      'email': email,
      'phone': phone,
      'website': website,
      'principal_name': principalName,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'postal_code': postalCode,
      'logo_url': logoUrl,
      'is_active': isActive,
      'status': status,
      'settings': settings,
      'udise_code': udiseCode,
      'latitude': latitude,
      'longitude': longitude,
      'geofence_radius_meters': geofenceRadiusMeters,
    };
  }
}

@immutable
class AcademicYearDto {
  final String id;
  final String tenantId;
  final String schoolId;
  final String name;
  final String code;
  final String? description;
  final String startDate; // YYYY-MM-DD
  final String endDate; // YYYY-MM-DD
  final String status;
  final bool isCurrent;
  final Map<String, dynamic>? settings;
  final int version;

  const AcademicYearDto({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.name,
    required this.code,
    this.description,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.isCurrent,
    this.settings,
    required this.version,
  });

  factory AcademicYearDto.fromJson(Map<String, dynamic> json) {
    return AcademicYearDto(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      description: json['description'] as String?,
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
      status: json['status'] as String? ?? 'UPCOMING',
      isCurrent: json['is_current'] as bool? ?? false,
      settings: json['settings'] as Map<String, dynamic>?,
      version: json['version'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'description': description,
      'start_date': startDate,
      'end_date': endDate,
      'status': status,
      'is_current': isCurrent,
      'settings': settings,
    };
  }
}

@immutable
class ClassDto {
  final String id;
  final String tenantId;
  final String schoolId;
  final String academicYearId;
  final String name;
  final String? displayName;
  final String code;
  final int level;
  final String category;
  final String? stream;
  final String? description;
  final int capacity;
  final int? promotionOrder;
  final String? nextClassId;
  final String status;
  final bool isActive;
  final Map<String, dynamic>? settings;
  final int version;

  const ClassDto({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.academicYearId,
    required this.name,
    this.displayName,
    required this.code,
    required this.level,
    required this.category,
    this.stream,
    this.description,
    required this.capacity,
    this.promotionOrder,
    this.nextClassId,
    required this.status,
    required this.isActive,
    this.settings,
    required this.version,
  });

  factory ClassDto.fromJson(Map<String, dynamic> json) {
    return ClassDto(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      academicYearId: json['academic_year_id'] as String,
      name: json['name'] as String,
      displayName: json['display_name'] as String?,
      code: json['code'] as String,
      level: json['level'] as int? ?? 1,
      category: json['category'] as String? ?? 'PRIMARY',
      stream: json['stream'] as String?,
      description: json['description'] as String?,
      capacity: json['capacity'] as int? ?? 40,
      promotionOrder: json['promotion_order'] as int?,
      nextClassId: json['next_class_id'] as String?,
      status: json['status'] as String? ?? 'ACTIVE',
      isActive: json['is_active'] as bool? ?? true,
      settings: json['settings'] as Map<String, dynamic>?,
      version: json['version'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'school_id': schoolId,
      'academic_year_id': academicYearId,
      'name': name,
      'display_name': displayName,
      'code': code,
      'level': level,
      'category': category,
      'stream': stream,
      'description': description,
      'capacity': capacity,
      'promotion_order': promotionOrder,
      'next_class_id': nextClassId,
      'status': status,
      'is_active': isActive,
      'settings': settings,
    };
  }
}

@immutable
class SectionDto {
  final String id;
  final String tenantId;
  final String schoolId;
  final String academicYearId;
  final String classId;
  final String name;
  final String code;
  final int capacity;
  final String? roomNumber;
  final int sortOrder;
  final String? description;
  final String status;
  final bool isActive;
  final Map<String, dynamic>? settings;
  final int version;

  const SectionDto({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.academicYearId,
    required this.classId,
    required this.name,
    required this.code,
    required this.capacity,
    this.roomNumber,
    required this.sortOrder,
    this.description,
    required this.status,
    required this.isActive,
    this.settings,
    required this.version,
  });

  factory SectionDto.fromJson(Map<String, dynamic> json) {
    return SectionDto(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      academicYearId: json['academic_year_id'] as String,
      classId: json['class_id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      capacity: json['capacity'] as int? ?? 40,
      roomNumber: json['room_number'] as String?,
      sortOrder: json['sort_order'] as int? ?? 1,
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'ACTIVE',
      isActive: json['is_active'] as bool? ?? true,
      settings: json['settings'] as Map<String, dynamic>?,
      version: json['version'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'school_id': schoolId,
      'academic_year_id': academicYearId,
      'class_id': classId,
      'name': name,
      'code': code,
      'capacity': capacity,
      'room_number': roomNumber,
      'sort_order': sortOrder,
      'description': description,
      'status': status,
      'is_active': isActive,
      'settings': settings,
    };
  }
}

@immutable
class SubjectDto {
  final String id;
  final String tenantId;
  final String schoolId;
  final String academicYearId;
  final String subjectCode;
  final String subjectName;
  final String? shortName;
  final String category;
  final String subjectType;
  final String? description;
  final int? creditHours;
  final int? weeklyPeriods;
  final int theoryMarks;
  final int practicalMarks;
  final int passMarks;
  final String? displayColor;
  final int? displayOrder;
  final String status;
  final bool isActive;
  final Map<String, dynamic>? settings;
  final int version;
  final String sourceType;
  final bool isExaminationApplicable;
  final bool isMarksApplicable;
  final int maxMarks;
  final bool appearsInReportCard;
  final bool includedInConsolidatedResult;
  final bool includedInRankCalculation;

  bool get isSchoolAdded => sourceType == 'SCHOOL_ADDED';
  bool get isBoardOfficial => sourceType == 'BOARD_OFFICIAL';

  const SubjectDto({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.academicYearId,
    required this.subjectCode,
    required this.subjectName,
    this.shortName,
    required this.category,
    required this.subjectType,
    this.description,
    this.creditHours,
    this.weeklyPeriods,
    required this.theoryMarks,
    required this.practicalMarks,
    required this.passMarks,
    this.displayColor,
    this.displayOrder,
    required this.status,
    required this.isActive,
    this.settings,
    required this.version,
    this.sourceType = 'BOARD_OFFICIAL',
    this.isExaminationApplicable = true,
    this.isMarksApplicable = true,
    this.maxMarks = 100,
    this.appearsInReportCard = true,
    this.includedInConsolidatedResult = true,
    this.includedInRankCalculation = true,
  });

  factory SubjectDto.fromJson(Map<String, dynamic> json) {
    return SubjectDto(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      academicYearId: json['academic_year_id'] as String,
      subjectCode: json['subject_code'] as String,
      subjectName: json['subject_name'] as String,
      shortName: json['short_name'] as String?,
      category: json['category'] as String? ?? 'CORE',
      subjectType: json['subject_type'] as String? ?? 'THEORY',
      description: json['description'] as String?,
      creditHours: json['credit_hours'] as int?,
      weeklyPeriods: json['weekly_periods'] as int?,
      theoryMarks: json['theory_marks'] as int? ?? 0,
      practicalMarks: json['practical_marks'] as int? ?? 0,
      passMarks: json['pass_marks'] as int? ?? 0,
      displayColor: json['display_color'] as String?,
      displayOrder: json['display_order'] as int?,
      status: json['status'] as String? ?? 'ACTIVE',
      isActive: json['is_active'] as bool? ?? true,
      settings: json['settings'] as Map<String, dynamic>?,
      version: json['version'] as int? ?? 1,
      sourceType: json['source_type'] as String? ?? 'BOARD_OFFICIAL',
      isExaminationApplicable: json['is_examination_applicable'] as bool? ?? true,
      isMarksApplicable: json['is_marks_applicable'] as bool? ?? true,
      maxMarks: json['max_marks'] as int? ?? 100,
      appearsInReportCard: json['appears_in_report_card'] as bool? ?? true,
      includedInConsolidatedResult: json['included_in_consolidated_result'] as bool? ?? true,
      includedInRankCalculation: json['included_in_rank_calculation'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'school_id': schoolId,
      'academic_year_id': academicYearId,
      'subject_code': subjectCode,
      'subject_name': subjectName,
      'short_name': shortName,
      'category': category,
      'subject_type': subjectType,
      'description': description,
      'credit_hours': creditHours,
      'weekly_periods': weeklyPeriods,
      'theory_marks': theoryMarks,
      'practical_marks': practicalMarks,
      'pass_marks': passMarks,
      'display_color': displayColor,
      'display_order': displayOrder,
      'status': status,
      'is_active': isActive,
      'settings': settings,
      'source_type': sourceType,
      'is_examination_applicable': isExaminationApplicable,
      'is_marks_applicable': isMarksApplicable,
      'max_marks': maxMarks,
      'appears_in_report_card': appearsInReportCard,
      'included_in_consolidated_result': includedInConsolidatedResult,
      'included_in_rank_calculation': includedInRankCalculation,
    };
  }
}

@immutable
class QuickSchoolOnboardingPayload {
  final String schoolName;
  final String principalName;
  final String principalEmail;
  final String principalPassword;
  final String? logoBase64;
  final String? board;
  final String? schoolType;
  final String? schoolCode;
  final String? phone;
  final String? address;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? website;

  const QuickSchoolOnboardingPayload({
    required this.schoolName,
    required this.principalName,
    required this.principalEmail,
    required this.principalPassword,
    this.logoBase64,
    this.board,
    this.schoolType,
    this.schoolCode,
    this.phone,
    this.address,
    this.city,
    this.state,
    this.postalCode,
    this.website,
  });

  Map<String, dynamic> toJson() {
    return {
      'school_name': schoolName,
      'principal_name': principalName,
      'principal_email': principalEmail,
      'principal_password': principalPassword,
      if (logoBase64 != null) 'logo_base64': logoBase64,
      if (board != null) 'board': board,
      if (schoolType != null) 'school_type': schoolType,
      if (schoolCode != null) 'school_code': schoolCode,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (postalCode != null) 'postal_code': postalCode,
      if (website != null) 'website': website,
    };
  }
}

@immutable
class QuickSchoolOnboardingResult {
  final String tenantId;
  final String tenantName;
  final String tenantCode;
  final String subdomain;
  final String schoolId;
  final String schoolName;
  final String schoolCode;
  final String board;
  final String schoolType;
  final String? logoUrl;
  final String principalId;
  final String principalName;
  final String principalEmail;
  final String accessToken;
  final String tokenType;
  final String status;
  final String message;

  const QuickSchoolOnboardingResult({
    required this.tenantId,
    required this.tenantName,
    required this.tenantCode,
    required this.subdomain,
    required this.schoolId,
    required this.schoolName,
    required this.schoolCode,
    required this.board,
    required this.schoolType,
    this.logoUrl,
    required this.principalId,
    required this.principalName,
    required this.principalEmail,
    required this.accessToken,
    required this.tokenType,
    required this.status,
    required this.message,
  });

  factory QuickSchoolOnboardingResult.fromJson(Map<String, dynamic> json) {
    return QuickSchoolOnboardingResult(
      tenantId: json['tenant_id'] as String? ?? '',
      tenantName: json['tenant_name'] as String? ?? '',
      tenantCode: json['tenant_code'] as String? ?? '',
      subdomain: json['subdomain'] as String? ?? '',
      schoolId: json['school_id'] as String? ?? '',
      schoolName: json['school_name'] as String? ?? '',
      schoolCode: json['school_code'] as String? ?? '',
      board: json['board'] as String? ?? 'CBSE',
      schoolType: json['school_type'] as String? ?? 'HIGH_SCHOOL',
      logoUrl: json['logo_url'] as String?,
      principalId: json['principal_id'] as String? ?? '',
      principalName: json['principal_name'] as String? ?? '',
      principalEmail: json['principal_email'] as String? ?? '',
      accessToken: json['access_token'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? 'bearer',
      status: json['status'] as String? ?? 'ACTIVE',
      message: json['message'] as String? ?? 'School created successfully.',
    );
  }
}

@immutable
class SetupStepItemDto {
  final String stepKey;
  final String title;
  final String description;
  final bool isCompleted;
  final String route;
  final String actionLabel;

  const SetupStepItemDto({
    required this.stepKey,
    required this.title,
    required this.description,
    required this.isCompleted,
    required this.route,
    required this.actionLabel,
  });

  factory SetupStepItemDto.fromJson(Map<String, dynamic> json) {
    return SetupStepItemDto(
      stepKey: json['step_key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isCompleted: json['is_completed'] as bool? ?? false,
      route: json['route'] as String? ?? '',
      actionLabel: json['action_label'] as String? ?? 'Configure',
    );
  }
}

@immutable
class SchoolSetupProgressDto {
  final String schoolId;
  final String schoolName;
  final int completedCount;
  final int totalSteps;
  final int progressPercentage;
  final List<SetupStepItemDto> steps;

  const SchoolSetupProgressDto({
    required this.schoolId,
    required this.schoolName,
    required this.completedCount,
    required this.totalSteps,
    required this.progressPercentage,
    required this.steps,
  });

  factory SchoolSetupProgressDto.fromJson(Map<String, dynamic> json) {
    final list = (json['steps'] as List<dynamic>?) ?? [];
    return SchoolSetupProgressDto(
      schoolId: json['school_id'] as String? ?? '',
      schoolName: json['school_name'] as String? ?? '',
      completedCount: json['completed_count'] as int? ?? 0,
      totalSteps: json['total_steps'] as int? ?? 8,
      progressPercentage: json['progress_percentage'] as int? ?? 0,
      steps: list
          .map((e) => SetupStepItemDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
