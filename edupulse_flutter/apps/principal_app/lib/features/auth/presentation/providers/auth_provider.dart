import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_network/edupulse_network.dart';

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class Authenticated extends AuthState {
  final UserEntity user;
  const Authenticated(this.user);
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}

class AuthStateNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    return const AuthInitial();
  }

  void setAuthenticated(UserEntity user) {
    state = Authenticated(user);
  }

  Future<void> checkAuth() async {
    final sessionManager = ref.read(sessionManagerProvider);
    final hasSession = await sessionManager.hasSession();

    if (!hasSession) {
      state = const Unauthenticated();
      return;
    }

    state = const AuthLoading();
    final validateSession = ref.read(validateSessionUseCaseProvider);
    final result = await validateSession();

    await result.when(
      onSuccess: (user) async {
        if (user.schools.isNotEmpty) {
          // If no school selected yet, default to the first one assigned to the user
          final currentSchoolId = await sessionManager.getSchoolId();
          if (currentSchoolId == null || currentSchoolId.isEmpty) {
            await sessionManager.saveSchoolId(user.schools.first);
          }
        }
        state = Authenticated(user);
      },
      onFailure: (failure) async {
        EduLogger.w('Saved session was invalid or expired: ${failure.message}');
        await sessionManager.clearSession();
        state = const Unauthenticated();
      },
    );
  }

  Future<void> login(String email, String password) async {
    state = const AuthLoading();

    // Verify connectivity first
    final buildConfig = ref.read(buildConfigProvider);
    final isHealthy = await _checkBackendHealth(buildConfig.apiBaseUrl);
    if (!isHealthy) {
      state = const AuthError('SERVER_UNREACHABLE');
      return;
    }

    final loginUseCase = ref.read(loginUseCaseProvider);
    final result = await loginUseCase(email: email, password: password);

    await result.when(
      onSuccess: (token) async {
        final sessionManager = ref.read(sessionManagerProvider);
        await sessionManager.saveSession(token);

        // Fetch user data after successful token caching
        final validateSession = ref.read(validateSessionUseCaseProvider);
        final userResult = await validateSession();

        await userResult.when(
          onSuccess: (user) async {
            if (user.schools.isNotEmpty) {
              await sessionManager.saveSchoolId(user.schools.first);
            }
            state = Authenticated(user);
          },
          onFailure: (failure) {
            state = AuthError(
                'Failed to retrieve user details: ${failure.message}');
          },
        );
      },
      onFailure: (failure) {
        state = AuthError(failure.message);
      },
    );
  }

  Future<bool> _checkBackendHealth(String apiBaseUrl) async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );

      // Try API health check endpoint first
      try {
        final response = await dio.get<dynamic>('$apiBaseUrl/system/health');
        if (response.statusCode == 200) {
          return true;
        }
      } on DioException catch (e) {
        if (e.response != null) {
          return true;
        }
      }

      // Try OpenAPI JSON endpoint as fallback
      try {
        final response = await dio.get<dynamic>('$apiBaseUrl/openapi.json');
        if (response.statusCode == 200) {
          return true;
        }
      } on DioException catch (e) {
        if (e.response != null) {
          return true;
        }
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    state = const AuthLoading();
    final sessionManager = ref.read(sessionManagerProvider);
    final logoutUseCase = ref.read(logoutUseCaseProvider);

    try {
      final refreshToken = await sessionManager.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await logoutUseCase(refreshToken: refreshToken);
      }
    } catch (e) {
      EduLogger.e('Error calling remote logout endpoint: $e');
    } finally {
      await sessionManager.clearSession();
      state = const Unauthenticated();
    }
  }
}

final authStateProvider = NotifierProvider<AuthStateNotifier, AuthState>(
  AuthStateNotifier.new,
);
