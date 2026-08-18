import 'package:equatable/equatable.dart';

class TeacherProfileEntity extends Equatable {
  final String id;
  final String employeeCode;
  final String firstName;
  final String lastName;
  final String? designation;
  final String? department;
  final String officialEmail;
  final String mobile;
  final String status;

  String get fullName => '$firstName $lastName';

  const TeacherProfileEntity({
    required this.id,
    required this.employeeCode,
    required this.firstName,
    required this.lastName,
    this.designation,
    this.department,
    required this.officialEmail,
    required this.mobile,
    required this.status,
  });

  @override
  List<Object?> get props => [
        id,
        employeeCode,
        firstName,
        lastName,
        designation,
        department,
        officialEmail,
        mobile,
        status,
      ];
}
