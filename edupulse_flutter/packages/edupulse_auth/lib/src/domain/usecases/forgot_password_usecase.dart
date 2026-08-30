import 'package:edupulse_network/edupulse_network.dart';
import '../repositories/auth_repository.dart';

class ForgotPasswordUseCase {
  final AuthRepository _repository;

  const ForgotPasswordUseCase(this._repository);

  Future<ApiResult<void>> call({required String email}) {
    return _repository.requestPasswordReset(email: email);
  }
}
