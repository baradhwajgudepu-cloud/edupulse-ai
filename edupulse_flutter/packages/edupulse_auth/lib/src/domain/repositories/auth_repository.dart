import 'package:edupulse_network/edupulse_network.dart';
import '../entities/user_entity.dart';
import '../entities/session_token.dart';

abstract class AuthRepository {
  Future<ApiResult<SessionToken>> login({
    required String email,
    required String password,
  });

  Future<ApiResult<void>> logout({required String refreshToken});

  Future<ApiResult<SessionToken>> refreshToken({required String refreshToken});

  Future<ApiResult<UserEntity>> getCurrentUser();

  Future<ApiResult<void>> requestPasswordReset({required String email});

  Future<ApiResult<void>> resetPassword({
    required String token,
    required String newPassword,
    String? confirmPassword,
  });
}

abstract class PlatformAuthRepository {
  Future<ApiResult<SessionToken>> platformLogin({
    required String email,
    required String password,
  });
}
