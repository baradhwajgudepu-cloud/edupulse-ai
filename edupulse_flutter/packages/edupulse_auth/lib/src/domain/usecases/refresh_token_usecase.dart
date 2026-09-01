import 'package:edupulse_network/edupulse_network.dart';
import '../entities/session_token.dart';
import '../repositories/auth_repository.dart';

class RefreshTokenUseCase {
  final AuthRepository _repository;

  const RefreshTokenUseCase(this._repository);

  Future<ApiResult<SessionToken>> call({required String refreshToken}) {
    return _repository.refreshToken(refreshToken: refreshToken);
  }
}
