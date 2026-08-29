import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'domain/entities/session_token.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/usecases/login_usecase.dart';
import 'domain/usecases/login_platform_usecase.dart';
import 'domain/usecases/logout_usecase.dart';
import 'domain/usecases/refresh_token_usecase.dart';
import 'domain/usecases/validate_session_usecase.dart';
import 'domain/usecases/forgot_password_usecase.dart';
import 'domain/usecases/reset_password_usecase.dart';
import 'data/datasource/auth_remote_datasource.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'session_manager.dart';
import 'token_storage.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return TokenStorage(secureStorage);
});

final authRemoteDatasourceProvider = Provider<AuthRemoteDatasource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthRemoteDatasource(apiClient);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remote = ref.watch(authRemoteDatasourceProvider);
  return AuthRepositoryImpl(remote);
});

final sessionManagerProvider = Provider<SessionManager>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  return SessionManager(
    tokenStorage: tokenStorage,
  );
});

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return LoginUseCase(repo);
});

final loginPlatformUseCaseProvider = Provider<LoginPlatformUseCase>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  if (repo is PlatformAuthRepository) {
    return LoginPlatformUseCase(repo as PlatformAuthRepository);
  }
  return LoginPlatformUseCase(_FakePlatformAuthRepository(repo));
});

class _FakePlatformAuthRepository implements PlatformAuthRepository {
  final AuthRepository _repo;
  _FakePlatformAuthRepository(this._repo);

  @override
  Future<ApiResult<SessionToken>> platformLogin({
    required String email,
    required String password,
  }) {
    return _repo.login(email: email, password: password);
  }
}

final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return LogoutUseCase(repo);
});

final refreshTokenUseCaseProvider = Provider<RefreshTokenUseCase>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return RefreshTokenUseCase(repo);
});

final validateSessionUseCaseProvider = Provider<ValidateSessionUseCase>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return ValidateSessionUseCase(repo);
});

final forgotPasswordUseCaseProvider = Provider<ForgotPasswordUseCase>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return ForgotPasswordUseCase(repo);
});

final resetPasswordUseCaseProvider = Provider<ResetPasswordUseCase>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return ResetPasswordUseCase(repo);
});
