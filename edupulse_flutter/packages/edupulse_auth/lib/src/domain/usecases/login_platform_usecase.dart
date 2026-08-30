import 'package:edupulse_network/edupulse_network.dart';
import '../entities/session_token.dart';
import '../repositories/auth_repository.dart';

class LoginPlatformUseCase {
  final PlatformAuthRepository _repository;

  LoginPlatformUseCase(this._repository);

  Future<ApiResult<SessionToken>> call({
    required String email,
    required String password,
  }) {
    return _repository.platformLogin(email: email, password: password);
  }
}
