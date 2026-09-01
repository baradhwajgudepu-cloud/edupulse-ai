import 'package:edupulse_network/edupulse_network.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class ValidateSessionUseCase {
  final AuthRepository _repository;

  const ValidateSessionUseCase(this._repository);

  Future<ApiResult<UserEntity>> call() {
    return _repository.getCurrentUser();
  }
}
