import 'package:flutter/foundation.dart';

enum TeacherStatus {
  ACTIVE,
  INACTIVE,
  ON_LEAVE,
  RETIRED,
}

enum EmploymentType {
  FULL_TIME,
  PART_TIME,
  CONTRACT,
  VISITING,
}

enum AssignmentStatus {
  ACTIVE,
  INACTIVE,
  TRANSFERRED,
  ARCHIVED,
}

enum AssignmentType {
  PRIMARY,
  SECONDARY,
  SUBSTITUTE,
}

@immutable
class TeacherDto {
  final String id;
  final String tenantId;
  final String schoolId;
  final String employeeCode;
  final String staffCode;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String gender;
  final String dateOfBirth; // YYYY-MM-DD
  final String? bloodGroup;
  final String? aadhaarNumber;
  final String? panNumber;
  final String mobile;
  final String? alternateMobile;
  final String officialEmail;
  final String? personalEmail;
  
  final String? emergencyContactName;
  final String? emergencyContactMobile;
  final String? emergencyContactRelation;
  final String? photoUrl;
  final Map<String, dynamic> address;
  
  final String? qualification;
  final String? specialization;
  final int? experienceYears;
  
  final String joiningDate; // YYYY-MM-DD
  final String? dateOfConfirmation; // YYYY-MM-DD
  final String? dateOfResignation; // YYYY-MM-DD
  final String? dateOfRetirement; // YYYY-MM-DD
  
  final String employmentType; // Enum string
  final String? designation;
  final String? department;
  final double? salary;
  
  final String status; // Enum string
  final bool isActive;
  final String? userId;
  final Map<String, dynamic> settings;
  final Map<String, dynamic> aiMetrics;
  final int version;

  const TeacherDto({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.employeeCode,
    required this.staffCode,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.gender,
    required this.dateOfBirth,
    this.bloodGroup,
    this.aadhaarNumber,
    this.panNumber,
    required this.mobile,
    this.alternateMobile,
    required this.officialEmail,
    this.personalEmail,
    this.emergencyContactName,
    this.emergencyContactMobile,
    this.emergencyContactRelation,
    this.photoUrl,
    required this.address,
    this.qualification,
    this.specialization,
    this.experienceYears,
    required this.joiningDate,
    this.dateOfConfirmation,
    this.dateOfResignation,
    this.dateOfRetirement,
    required this.employmentType,
    this.designation,
    this.department,
    this.salary,
    required this.status,
    required this.isActive,
    this.userId,
    required this.settings,
    required this.aiMetrics,
    required this.version,
  });

  String get fullName {
    if (middleName != null && middleName!.isNotEmpty) {
      return '$firstName $middleName $lastName';
    }
    return '$firstName $lastName';
  }

  factory TeacherDto.fromJson(Map<String, dynamic> json) {
    return TeacherDto(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      employeeCode: json['employee_code'] as String,
      staffCode: json['staff_code'] as String,
      firstName: json['first_name'] as String,
      middleName: json['middle_name'] as String?,
      lastName: json['last_name'] as String,
      gender: json['gender'] as String,
      dateOfBirth: json['date_of_birth'] as String,
      bloodGroup: json['blood_group'] as String?,
      aadhaarNumber: json['aadhaar_number'] as String?,
      panNumber: json['pan_number'] as String?,
      mobile: json['mobile'] as String,
      alternateMobile: json['alternate_mobile'] as String?,
      officialEmail: json['official_email'] as String,
      personalEmail: json['personal_email'] as String?,
      emergencyContactName: json['emergency_contact_name'] as String?,
      emergencyContactMobile: json['emergency_contact_mobile'] as String?,
      emergencyContactRelation: json['emergency_contact_relation'] as String?,
      photoUrl: json['photo_url'] as String?,
      address: json['address'] != null ? Map<String, dynamic>.from(json['address'] as Map) : const <String, dynamic>{},
      qualification: json['qualification'] as String?,
      specialization: json['specialization'] as String?,
      experienceYears: json['experience_years'] as int?,
      joiningDate: json['joining_date'] as String,
      dateOfConfirmation: json['date_of_confirmation'] as String?,
      dateOfResignation: json['date_of_resignation'] as String?,
      dateOfRetirement: json['date_of_retirement'] as String?,
      employmentType: json['employment_type'] as String,
      designation: json['designation'] as String?,
      department: json['department'] as String?,
      salary: json['salary'] != null ? (json['salary'] as num).toDouble() : null,
      status: json['status'] as String? ?? 'ACTIVE',
      isActive: json['is_active'] as bool? ?? true,
      userId: json['user_id'] as String?,
      settings: json['settings'] != null ? Map<String, dynamic>.from(json['settings'] as Map) : const <String, dynamic>{},
      aiMetrics: json['ai_metrics'] != null ? Map<String, dynamic>.from(json['ai_metrics'] as Map) : const <String, dynamic>{},
      version: json['version'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employee_code': employeeCode,
      'staff_code': staffCode,
      'first_name': firstName,
      'middle_name': middleName,
      'last_name': lastName,
      'gender': gender,
      'date_of_birth': dateOfBirth,
      'blood_group': bloodGroup,
      'aadhaar_number': aadhaarNumber,
      'pan_number': panNumber,
      'mobile': mobile,
      'alternate_mobile': alternateMobile,
      'official_email': officialEmail,
      'personal_email': personalEmail,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_mobile': emergencyContactMobile,
      'emergency_contact_relation': emergencyContactRelation,
      'photo_url': photoUrl,
      'address': address,
      'qualification': qualification,
      'specialization': specialization,
      'experience_years': experienceYears,
      'joining_date': joiningDate,
      'date_of_confirmation': dateOfConfirmation,
      'date_of_resignation': dateOfResignation,
      'date_of_retirement': dateOfRetirement,
      'employment_type': employmentType,
      'designation': designation,
      'department': department,
      'salary': salary,
      'status': status,
      'is_active': isActive,
      'settings': settings,
    };
  }
}

@immutable
class TeacherSubjectAssignmentDto {
  final String id;
  final String tenantId;
  final String schoolId;
  final String academicYearId;
  final String teacherId;
  final String subjectId;
  final String classId;
  final String sectionId;
  
  final String assignmentType; // Enum string
  final int priority;
  final int weeklyPeriods;
  final double workloadPercentage;
  
  final String effectiveFrom; // YYYY-MM-DD
  final String? effectiveTo; // YYYY-MM-DD
  
  final bool isClassTeacher;
  final String? roomId;
  final int? maximumStudents;
  final String? remarks;
  
  final String status; // Enum string
  final bool isActive;
  final int version;
  final String? assignedBy;
  final String? assignedAt;

  const TeacherSubjectAssignmentDto({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.academicYearId,
    required this.teacherId,
    required this.subjectId,
    required this.classId,
    required this.sectionId,
    required this.assignmentType,
    required this.priority,
    required this.weeklyPeriods,
    required this.workloadPercentage,
    required this.effectiveFrom,
    this.effectiveTo,
    required this.isClassTeacher,
    this.roomId,
    this.maximumStudents,
    this.remarks,
    required this.status,
    required this.isActive,
    required this.version,
    this.assignedBy,
    this.assignedAt,
  });

  factory TeacherSubjectAssignmentDto.fromJson(Map<String, dynamic> json) {
    return TeacherSubjectAssignmentDto(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      academicYearId: json['academic_year_id'] as String,
      teacherId: json['teacher_id'] as String,
      subjectId: json['subject_id'] as String,
      classId: json['class_id'] as String,
      sectionId: json['section_id'] as String,
      assignmentType: json['assignment_type'] as String,
      priority: json['priority'] as int? ?? 1,
      weeklyPeriods: json['weekly_periods'] as int,
      workloadPercentage: json['workload_percentage'] != null ? (json['workload_percentage'] as num).toDouble() : 0.0,
      effectiveFrom: json['effective_from'] as String,
      effectiveTo: json['effective_to'] as String?,
      isClassTeacher: json['is_class_teacher'] as bool? ?? false,
      roomId: json['room_id'] as String?,
      maximumStudents: json['maximum_students'] as int?,
      remarks: json['remarks'] as String?,
      status: json['status'] as String? ?? 'ACTIVE',
      isActive: json['is_active'] as bool? ?? true,
      version: json['version'] as int? ?? 1,
      assignedBy: json['assigned_by'] as String?,
      assignedAt: json['assigned_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'school_id': schoolId,
      'academic_year_id': academicYearId,
      'teacher_id': teacherId,
      'subject_id': subjectId,
      'class_id': classId,
      'section_id': sectionId,
      'assignment_type': assignmentType,
      'priority': priority,
      'weekly_periods': weeklyPeriods,
      'workload_percentage': workloadPercentage,
      'effective_from': effectiveFrom,
      'effective_to': effectiveTo,
      'is_class_teacher': isClassTeacher,
      'room_id': roomId,
      'maximum_students': maximumStudents,
      'remarks': remarks,
      'status': status,
    };
  }
}
