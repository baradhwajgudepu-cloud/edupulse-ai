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
  final bool isActive;
  final String status;
  final Map<String, dynamic>? settings;
  final String? udiseCode;
  final int version;
  final double? latitude;
  final double? longitude;
  final int? geofenceRadiusMeters;

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
    };
  }
}
