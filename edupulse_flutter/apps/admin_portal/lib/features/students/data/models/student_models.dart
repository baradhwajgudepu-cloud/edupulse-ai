import 'package:flutter/foundation.dart';

@immutable
class StudentDto {
  final String id;
  final String tenantId;
  final String schoolId;
  final String academicYearId;
  final String classId;
  final String sectionId;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String gender;
  final String dateOfBirth; // YYYY-MM-DD
  final String? bloodGroup;
  final String? aadhaarNumber;
  final String? emisNumber;
  final String? mobile;
  final String? email;
  final String? photoUrl;
  final Map<String, dynamic> address;
  final Map<String, dynamic> medicalInformation;
  final String admissionNumber;
  final String rollNumber;
  final String admissionDate; // YYYY-MM-DD
  final String status;
  final bool isActive;
  final Map<String, dynamic> settings;
  final Map<String, dynamic> aiMetrics;
  final int version;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final String? className;
  final String? sectionName;
  final String? admittedAt;
  final String? promotedAt;
  final String? transferredAt;
  final String? withdrawnAt;
  final String? graduatedAt;

  const StudentDto({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.academicYearId,
    required this.classId,
    required this.sectionId,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.gender,
    required this.dateOfBirth,
    this.bloodGroup,
    this.aadhaarNumber,
    this.emisNumber,
    this.mobile,
    this.email,
    this.photoUrl,
    required this.address,
    required this.medicalInformation,
    required this.admissionNumber,
    required this.rollNumber,
    required this.admissionDate,
    required this.status,
    required this.isActive,
    required this.settings,
    required this.aiMetrics,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.className,
    this.sectionName,
    this.admittedAt,
    this.promotedAt,
    this.transferredAt,
    this.withdrawnAt,
    this.graduatedAt,
  });

  factory StudentDto.fromJson(Map<String, dynamic> json) {
    return StudentDto(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      academicYearId: json['academic_year_id'] as String,
      classId: json['class_id'] as String,
      sectionId: json['section_id'] as String,
      firstName: json['first_name'] as String,
      middleName: json['middle_name'] as String?,
      lastName: json['last_name'] as String,
      gender: json['gender'] as String,
      dateOfBirth: json['date_of_birth'] as String,
      bloodGroup: json['blood_group'] as String?,
      aadhaarNumber: json['aadhaar_number'] as String?,
      emisNumber: json['emis_number'] as String?,
      mobile: json['mobile'] as String?,
      email: json['email'] as String?,
      photoUrl: json['photo_url'] as String?,
      address: json['address'] != null ? Map<String, dynamic>.from(json['address'] as Map) : const <String, dynamic>{},
      medicalInformation: json['medical_information'] != null ? Map<String, dynamic>.from(json['medical_information'] as Map) : const <String, dynamic>{},
      admissionNumber: json['admission_number'] as String,
      rollNumber: json['roll_number'] as String,
      admissionDate: json['admission_date'] as String,
      status: json['status'] as String? ?? 'ACTIVE',
      isActive: json['is_active'] as bool? ?? true,
      settings: json['settings'] != null ? Map<String, dynamic>.from(json['settings'] as Map) : const <String, dynamic>{},
      aiMetrics: json['ai_metrics'] != null ? Map<String, dynamic>.from(json['ai_metrics'] as Map) : const <String, dynamic>{},
      version: json['version'] as int? ?? 1,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      deletedAt: json['deleted_at'] as String?,
      className: json['class_name'] as String?,
      sectionName: json['section_name'] as String?,
      admittedAt: json['admitted_at'] as String?,
      promotedAt: json['promoted_at'] as String?,
      transferredAt: json['transferred_at'] as String?,
      withdrawnAt: json['withdrawn_at'] as String?,
      graduatedAt: json['graduated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'first_name': firstName,
      'middle_name': middleName,
      'last_name': lastName,
      'gender': gender,
      'date_of_birth': dateOfBirth,
      'blood_group': bloodGroup,
      'aadhaar_number': aadhaarNumber,
      'emis_number': emisNumber,
      'mobile': mobile,
      'email': email,
      'photo_url': photoUrl,
      'address': address,
      'medical_information': medicalInformation,
      'admission_number': admissionNumber,
      'roll_number': rollNumber,
      'admission_date': admissionDate,
      'school_id': schoolId,
      'academic_year_id': academicYearId,
      'class_id': classId,
      'section_id': sectionId,
      'status': status,
      'settings': settings,
    };
  }

  factory StudentDto.forLedger({
    required String id,
    required String firstName,
    required String lastName,
    required String admissionNumber,
    String rollNumber = '',
  }) {
    return StudentDto(
      id: id,
      tenantId: '',
      schoolId: '',
      academicYearId: '',
      classId: '',
      sectionId: '',
      firstName: firstName,
      lastName: lastName,
      gender: '',
      dateOfBirth: '',
      address: const {},
      medicalInformation: const {},
      admissionNumber: admissionNumber,
      rollNumber: rollNumber,
      admissionDate: '',
      status: '',
      isActive: true,
      settings: const {},
      aiMetrics: const {},
      version: 1,
      createdAt: '',
      updatedAt: '',
    );
  }
}

@immutable
class GuardianDto {
  final String id;
  final String tenantId;
  final String schoolId;
  final String guardianType;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String gender;
  final String dateOfBirth; // YYYY-MM-DD
  final String? aadhaarNumber;
  final String? panNumber;
  final String? occupation;
  final String? qualification;
  final String? organization;
  final double? annualIncome;
  final String mobile;
  final String? alternateMobile;
  final String? email;
  final String? emergencyContactName;
  final String? emergencyContactMobile;
  final String? photoUrl;
  final Map<String, dynamic> address;
  final Map<String, dynamic> communicationPreferences;
  final Map<String, dynamic> settings;
  final Map<String, dynamic> aiMetrics;
  final bool isMobileVerified;
  final bool isEmailVerified;
  final String status;
  final bool isActive;
  final int version;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final String? loginId;

  const GuardianDto({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.guardianType,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.gender,
    required this.dateOfBirth,
    this.aadhaarNumber,
    this.panNumber,
    this.occupation,
    this.qualification,
    this.organization,
    this.annualIncome,
    required this.mobile,
    this.alternateMobile,
    this.email,
    this.emergencyContactName,
    this.emergencyContactMobile,
    this.photoUrl,
    required this.address,
    required this.communicationPreferences,
    required this.settings,
    required this.aiMetrics,
    required this.isMobileVerified,
    required this.isEmailVerified,
    required this.status,
    required this.isActive,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.loginId,
  });

  factory GuardianDto.fromJson(Map<String, dynamic> json) {
    return GuardianDto(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      guardianType: json['guardian_type'] as String,
      firstName: json['first_name'] as String,
      middleName: json['middle_name'] as String?,
      lastName: json['last_name'] as String,
      gender: json['gender'] as String,
      dateOfBirth: json['date_of_birth'] as String,
      aadhaarNumber: json['aadhaar_number'] as String?,
      panNumber: json['pan_number'] as String?,
      occupation: json['occupation'] as String?,
      qualification: json['qualification'] as String?,
      organization: json['organization'] as String?,
      annualIncome: (json['annual_income'] as num?)?.toDouble(),
      mobile: json['mobile'] as String,
      alternateMobile: json['alternate_mobile'] as String?,
      email: json['email'] as String?,
      emergencyContactName: json['emergency_contact_name'] as String?,
      emergencyContactMobile: json['emergency_contact_mobile'] as String?,
      photoUrl: json['photo_url'] as String?,
      address: json['address'] != null ? Map<String, dynamic>.from(json['address'] as Map) : const <String, dynamic>{},
      communicationPreferences: json['communication_preferences'] != null ? Map<String, dynamic>.from(json['communication_preferences'] as Map) : const <String, dynamic>{},
      settings: json['settings'] != null ? Map<String, dynamic>.from(json['settings'] as Map) : const <String, dynamic>{},
      aiMetrics: json['ai_metrics'] != null ? Map<String, dynamic>.from(json['ai_metrics'] as Map) : const <String, dynamic>{},
      isMobileVerified: json['is_mobile_verified'] as bool? ?? false,
      isEmailVerified: json['is_email_verified'] as bool? ?? false,
      status: json['status'] as String? ?? 'ACTIVE',
      isActive: json['is_active'] as bool? ?? true,
      version: json['version'] as int? ?? 1,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      deletedAt: json['deleted_at'] as String?,
      loginId: json['login_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'guardian_type': guardianType,
      'first_name': firstName,
      'middle_name': middleName,
      'last_name': lastName,
      'gender': gender,
      'date_of_birth': dateOfBirth,
      'aadhaar_number': aadhaarNumber,
      'pan_number': panNumber,
      'occupation': occupation,
      'qualification': qualification,
      'organization': organization,
      'annual_income': annualIncome,
      'mobile': mobile,
      'alternate_mobile': alternateMobile,
      'email': email,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_mobile': emergencyContactMobile,
      'photo_url': photoUrl,
      'address': address,
      'communication_preferences': communicationPreferences,
      'school_id': schoolId,
    };
  }
}

@immutable
class StudentGuardianDto {
  final String id;
  final String tenantId;
  final String schoolId;
  final String studentId;
  final String guardianId;
  final String relationship;
  final bool isPrimary;
  final bool canPickupStudent;
  final bool receivesNotifications;
  final int version;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final GuardianDto? guardian; // Optionally resolved locally/nested

  const StudentGuardianDto({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.studentId,
    required this.guardianId,
    required this.relationship,
    required this.isPrimary,
    required this.canPickupStudent,
    required this.receivesNotifications,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.guardian,
  });

  factory StudentGuardianDto.fromJson(Map<String, dynamic> json) {
    return StudentGuardianDto(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      studentId: json['student_id'] as String,
      guardianId: json['guardian_id'] as String,
      relationship: json['relationship'] as String,
      isPrimary: json['is_primary'] as bool? ?? false,
      canPickupStudent: json['can_pickup_student'] as bool? ?? true,
      receivesNotifications: json['receives_notifications'] as bool? ?? true,
      version: json['version'] as int? ?? 1,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      deletedAt: json['deleted_at'] as String?,
      guardian: json['guardian'] != null ? GuardianDto.fromJson(Map<String, dynamic>.from(json['guardian'] as Map)) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'school_id': schoolId,
      'student_id': studentId,
      'guardian_id': guardianId,
      'relationship': relationship,
      'is_primary': isPrimary,
      'can_pickup_student': canPickupStudent,
      'receives_notifications': receivesNotifications,
    };
  }

  StudentGuardianDto copyWith({
    String? relationship,
    bool? isPrimary,
    bool? canPickupStudent,
    bool? receivesNotifications,
    GuardianDto? guardian,
  }) {
    return StudentGuardianDto(
      id: id,
      tenantId: tenantId,
      schoolId: schoolId,
      studentId: studentId,
      guardianId: guardianId,
      relationship: relationship ?? this.relationship,
      isPrimary: isPrimary ?? this.isPrimary,
      canPickupStudent: canPickupStudent ?? this.canPickupStudent,
      receivesNotifications: receivesNotifications ?? this.receivesNotifications,
      version: version,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      guardian: guardian ?? this.guardian,
    );
  }
}
