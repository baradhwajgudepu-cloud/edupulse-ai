import 'package:edupulse_network/edupulse_network.dart';
import '../repositories/auth_repository.dart';

class ResetPasswordUseCase {
  final AuthRepository _repository;

  const ResetPasswordUseCase(this._repository);

  Future<ApiResult<void>> call({
    required String token,
    required String newPassword,
    String? confirmPassword,
  }) {
    return _repository.resetPassword(
      token: token,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
  }
}
