class Student {
  final String id;
  final String firstName;
  final String lastName;
  final String admissionNumber;
  final String rollNumber;
  final String className;
  final String sectionName;
  final String gender;
  final String dateOfBirth;
  final String? mobile;
  final String? email;
  final String admissionDate;
  final String status;
  final String? photoUrl;

  Student({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.admissionNumber,
    required this.rollNumber,
    required this.className,
    required this.sectionName,
    required this.gender,
    required this.dateOfBirth,
    this.mobile,
    this.email,
    required this.admissionDate,
    required this.status,
    this.photoUrl,
  });

  String get fullName => '$firstName $lastName';

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      admissionNumber: json['admission_number'] as String? ?? '',
      rollNumber: json['roll_number'] as String? ?? '',
      className: json['class_name'] as String? ?? '',
      sectionName: json['section_name'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      dateOfBirth: json['date_of_birth'] as String? ?? '',
      mobile: json['mobile'] as String?,
      email: json['email'] as String?,
      admissionDate: json['admission_date'] as String? ?? '',
      status: json['status'] as String? ?? '',
      photoUrl: json['photo_url'] as String?,
    );
  }
}
