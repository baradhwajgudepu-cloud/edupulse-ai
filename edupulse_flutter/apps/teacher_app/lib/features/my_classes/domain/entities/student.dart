import 'package:equatable/equatable.dart';

class StudentEntity extends Equatable {
  final String id;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String gender;
  final String dateOfBirth;
  final String? bloodGroup;
  final String? mobile;
  final String? email;
  final String? photoUrl;
  final String admissionNumber;
  final String rollNumber;
  final String status;
  final String className;
  final String sectionName;

  const StudentEntity({
    required this.id,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.gender,
    required this.dateOfBirth,
    this.bloodGroup,
    this.mobile,
    this.email,
    this.photoUrl,
    required this.admissionNumber,
    required this.rollNumber,
    required this.status,
    required this.className,
    required this.sectionName,
  });

  String get fullName => middleName != null && middleName!.isNotEmpty
      ? '$firstName $middleName $lastName'
      : '$firstName $lastName';

  @override
  List<Object?> get props => [
        id,
        firstName,
        middleName,
        lastName,
        gender,
        dateOfBirth,
        bloodGroup,
        mobile,
        email,
        photoUrl,
        admissionNumber,
        rollNumber,
        status,
        className,
        sectionName,
      ];
}
