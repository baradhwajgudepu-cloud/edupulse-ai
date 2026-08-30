import '../../domain/entities/user_entity.dart';
import '../../domain/entities/session_token.dart';
import '../models/user_response_dto.dart';
import '../models/token_response_dto.dart';

extension UserResponseDtoMapper on UserResponseDto {
  UserEntity toEntity() {
    return UserEntity(
      id: id,
      email: email,
      firstName: firstName,
      lastName: lastName,
      tenantId: tenantId,
      isSuperuser: isSuperuser,
      roles: roles.map((e) {
        if (e is Map) {
          return (e['code'] ?? e['name'] ?? e.toString()).toString();
        }
        return e.toString();
      }).toList(),
      schools: schools.map((e) {
        if (e is Map) {
          return (e['id'] ?? e.toString()).toString();
        }
        return e.toString();
      }).toList(),
      schoolNames: {
        for (final e in schools)
          if (e is Map && e['id'] != null)
            e['id'].toString(): (e['name'] ?? e['code'] ?? '').toString()
      },
    );
  }
}

extension TokenResponseDtoMapper on TokenResponseDto {
  SessionToken toEntity() {
    return SessionToken(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: tokenType,
    );
  }
}
