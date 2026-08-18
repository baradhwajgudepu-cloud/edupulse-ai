class Teacher {
  final String id;
  final String firstName;
  final String lastName;
  final String employeeCode;
  final String staffCode;
  final String designation;
  final String department;
  final String qualification;
  final String joiningDate;
  final String status;
  final String employmentType;
  final String mobile;
  final String officialEmail;
  final String? emergencyContactName;
  final String? emergencyContactMobile;

  Teacher({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.employeeCode,
    required this.staffCode,
    required this.designation,
    required this.department,
    required this.qualification,
    required this.joiningDate,
    required this.status,
    required this.employmentType,
    required this.mobile,
    required this.officialEmail,
    this.emergencyContactName,
    this.emergencyContactMobile,
  });

  String get fullName => '$firstName $lastName';

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: json['id'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      employeeCode: json['employee_code'] as String? ?? '',
      staffCode: json['staff_code'] as String? ?? '',
      designation: json['designation'] as String? ?? '',
      department: json['department'] as String? ?? '',
      qualification: json['qualification'] as String? ?? '',
      joiningDate: json['joining_date'] as String? ?? '',
      status: json['status'] as String? ?? '',
      employmentType: json['employment_type'] as String? ?? '',
      mobile: json['mobile'] as String? ?? '',
      officialEmail: json['official_email'] as String? ?? '',
      emergencyContactName: json['emergency_contact_name'] as String?,
      emergencyContactMobile: json['emergency_contact_mobile'] as String?,
    );
  }
}
