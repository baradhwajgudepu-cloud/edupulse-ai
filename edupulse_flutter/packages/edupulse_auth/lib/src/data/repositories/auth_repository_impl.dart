import 'package:edupulse_network/edupulse_network.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/session_token.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasource/auth_remote_datasource.dart';
import '../mappers/auth_mappers.dart';

class AuthRepositoryImpl implements AuthRepository, PlatformAuthRepository {
  final AuthRemoteDatasource _remoteDatasource;

  const AuthRepositoryImpl(this._remoteDatasource);

  @override
  Future<ApiResult<SessionToken>> login({
    required String email,
    required String password,
  }) async {
    final result =
        await _remoteDatasource.login(email: email, password: password);
    return result.when(
      onSuccess: (dto) => ApiResult.success(dto.toEntity()),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  @override
  Future<ApiResult<SessionToken>> platformLogin({
    required String email,
    required String password,
  }) async {
    final result =
        await _remoteDatasource.platformLogin(email: email, password: password);
    return result.when(
      onSuccess: (dto) => ApiResult.success(dto.toEntity()),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  @override
  Future<ApiResult<void>> logout({required String refreshToken}) {
    return _remoteDatasource.logout(refreshToken: refreshToken);
  }

  @override
  Future<ApiResult<SessionToken>> refreshToken(
      {required String refreshToken}) async {
    final result =
        await _remoteDatasource.refreshToken(refreshToken: refreshToken);
    return result.when(
      onSuccess: (dto) => ApiResult.success(dto.toEntity()),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  @override
  Future<ApiResult<UserEntity>> getCurrentUser() async {
    final result = await _remoteDatasource.getCurrentUser();
    return result.when(
      onSuccess: (dto) => ApiResult.success(dto.toEntity()),
      onFailure: (failure) => ApiResult.failure(failure),
    );
  }

  @override
  Future<ApiResult<void>> requestPasswordReset({required String email}) {
    return _remoteDatasource.requestPasswordReset(email: email);
  }

  @override
  Future<ApiResult<void>> resetPassword({
    required String token,
    required String newPassword,
    String? confirmPassword,
  }) {
    return _remoteDatasource.resetPassword(
      token: token,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
  }
}
