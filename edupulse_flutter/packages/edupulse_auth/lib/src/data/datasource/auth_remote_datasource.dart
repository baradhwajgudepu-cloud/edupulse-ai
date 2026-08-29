import 'package:edupulse_network/edupulse_network.dart';
import '../models/token_response_dto.dart';
import '../models/user_response_dto.dart';

class AuthRemoteDatasource {
  final BaseApiClient _apiClient;

  const AuthRemoteDatasource(this._apiClient);

  Future<ApiResult<TokenResponseDto>> login({
    required String email,
    required String password,
  }) {
    return _apiClient.post(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return TokenResponseDto.fromJson(
            payload['data'] as Map<String, dynamic>);
      },
    );
  }

  Future<ApiResult<TokenResponseDto>> platformLogin({
    required String email,
    required String password,
  }) {
    return _apiClient.post(
      '/auth/platform-login',
      data: {
        'email': email,
        'password': password,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return TokenResponseDto.fromJson(
            payload['data'] as Map<String, dynamic>);
      },
    );
  }

  Future<ApiResult<void>> logout({required String refreshToken}) {
    return _apiClient.post(
      '/auth/logout',
      data: {
        'refresh_token': refreshToken,
      },
      mapper: (_) {},
    );
  }

  Future<ApiResult<TokenResponseDto>> refreshToken(
      {required String refreshToken}) {
    return _apiClient.post(
      '/auth/refresh',
      data: {
        'refresh_token': refreshToken,
      },
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return TokenResponseDto.fromJson(
            payload['data'] as Map<String, dynamic>);
      },
    );
  }

  Future<ApiResult<UserResponseDto>> getCurrentUser() {
    return _apiClient.get(
      '/auth/me',
      mapper: (json) {
        final payload = json as Map<String, dynamic>;
        return UserResponseDto.fromJson(
            payload['data'] as Map<String, dynamic>);
      },
    );
  }

  Future<ApiResult<void>> requestPasswordReset({required String email}) {
    return _apiClient.post(
      '/auth/forgot-password',
      data: {
        'email': email,
      },
      mapper: (_) {},
    );
  }

  Future<ApiResult<void>> resetPassword({
    required String token,
    required String newPassword,
    String? confirmPassword,
  }) {
    return _apiClient.post(
      '/auth/reset-password',
      data: {
        'token': token,
        'new_password': newPassword,
        if (confirmPassword != null) 'confirm_password': confirmPassword,
      },
      mapper: (_) {},
    );
  }
}
