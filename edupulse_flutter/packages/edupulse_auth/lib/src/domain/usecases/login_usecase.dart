import 'package:edupulse_network/edupulse_network.dart';
import '../entities/session_token.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository _repository;

  const LoginUseCase(this._repository);

  Future<ApiResult<SessionToken>> call({
    required String email,
    required String password,
  }) {
    return _repository.login(email: email, password: password);
  }
}
