import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? tenantId;
  final bool isSuperuser;
  final List<String> roles;
  final List<String> schools;
  final Map<String, String> schoolNames;

  const UserEntity({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.tenantId,
    required this.isSuperuser,
    required this.roles,
    required this.schools,
    this.schoolNames = const {},
  });

  String get fullName => '$firstName $lastName';

  @override
  List<Object?> get props => [
        id,
        email,
        firstName,
        lastName,
        tenantId,
        isSuperuser,
        roles,
        schools,
        schoolNames,
      ];
}
