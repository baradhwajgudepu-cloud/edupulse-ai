class UserResponseDto {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? tenantId;
  final String status;
  final bool isSuperuser;
  final List<dynamic> schools;
  final List<dynamic> roles;
  final int version;
  final String createdAt;
  final String updatedAt;

  const UserResponseDto({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.tenantId,
    required this.status,
    required this.isSuperuser,
    required this.schools,
    required this.roles,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserResponseDto.fromJson(Map<String, dynamic> json) {
    return UserResponseDto(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      firstName: (json['first_name'] ?? json['firstName'] ?? '').toString(),
      lastName: (json['last_name'] ?? json['lastName'] ?? '').toString(),
      tenantId: json['tenant_id']?.toString() ?? json['tenantId']?.toString(),
      status: (json['status'] ?? 'ACTIVE').toString(),
      isSuperuser: json['is_superuser'] == true || json['isSuperuser'] == true,
      schools: (json['schools'] as List<dynamic>?) ?? const [],
      roles: (json['roles'] as List<dynamic>?) ?? const [],
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdAt: (json['created_at'] ?? json['createdAt'] ?? '').toString(),
      updatedAt: (json['updated_at'] ?? json['updatedAt'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'tenant_id': tenantId,
      'status': status,
      'is_superuser': isSuperuser,
      'schools': schools,
      'roles': roles,
      'version': version,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
