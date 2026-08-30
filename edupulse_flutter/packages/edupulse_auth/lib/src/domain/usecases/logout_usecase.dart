import 'package:edupulse_network/edupulse_network.dart';
import '../repositories/auth_repository.dart';

class LogoutUseCase {
  final AuthRepository _repository;

  const LogoutUseCase(this._repository);

  Future<ApiResult<void>> call({required String refreshToken}) {
    return _repository.logout(refreshToken: refreshToken);
  }
}
