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
    Future.microtask(() => checkAuth());
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

    result.when(
      onSuccess: (user) async {
        final hasAdminAccess = user.isSuperuser || 
            user.roles.any((r) => 
                r.toUpperCase() == 'SUPER_ADMIN' || 
                r.toUpperCase() == 'ADMIN' || 
                r.toUpperCase() == 'PRINCIPAL' ||
                r.toUpperCase() == 'STAFF');
                
        if (!hasAdminAccess) {
          EduLogger.w('User authenticated but lacks admin access: ${user.email}');
          await sessionManager.clearSession();
          state = const AuthError('ACCESS_DENIED');
          return;
        }

        if (user.schools.isNotEmpty) {
          await sessionManager.saveSchoolId(user.schools.first);
        }
        state = Authenticated(user);
      },
      onFailure: (failure) async {
        _logDiagnosticFailure(failure, 'async-onFailure');
        EduLogger.w('Saved session was invalid or expired: ${failure.message}');
        await sessionManager.clearSession();
        state = const Unauthenticated();
      },
    );
  }

  Future<void> login(String email, String password) async {
    state = const AuthLoading();

    // 1. Connectivity verification check
    final buildConfig = ref.read(buildConfigProvider);
    final isHealthy = await _checkBackendHealth(buildConfig.apiBaseUrl);
    if (!isHealthy) {
      state = const AuthError('SERVER_UNREACHABLE');
      return;
    }

    final loginUseCase = ref.read(loginPlatformUseCaseProvider);
    final result = await loginUseCase(email: email, password: password);

    await result.when(
      onSuccess: (token) async {
        final sessionManager = ref.read(sessionManagerProvider);
        await sessionManager.saveSession(token);

        // Fetch user data after successful token caching
        final validateSession = ref.read(validateSessionUseCaseProvider);
        final userResult = await validateSession();

        userResult.when(
          onSuccess: (user) async {
            final hasAdminAccess = user.isSuperuser || 
                user.roles.any((r) => 
                    r.toUpperCase() == 'SUPER_ADMIN' || 
                    r.toUpperCase() == 'ADMIN' || 
                    r.toUpperCase() == 'PRINCIPAL' ||
                    r.toUpperCase() == 'STAFF');
                    
            if (!hasAdminAccess) {
              EduLogger.w('User logged in but lacks admin privileges: ${user.email}');
              await sessionManager.clearSession();
              state = const AuthError('ACCESS_DENIED');
              return;
            }

            if (user.schools.isNotEmpty) {
              await sessionManager.saveSchoolId(user.schools.first);
            }
            state = Authenticated(user);
          },
          onFailure: (failure) {
        _logDiagnosticFailure(failure, 'onFailure');
            state = AuthError(
                'Failed to retrieve user details: ${failure.message}');
          },
        );
      },
      onFailure: (failure) {
        _logDiagnosticFailure(failure, 'onFailure');
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

      final normalizedBase = apiBaseUrl.endsWith('/')
          ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
          : apiBaseUrl;

      // Try system health endpoint
      try {
        final response = await dio.get('$normalizedBase/system/health');
        if (response.statusCode == 200) {
          return true;
        }
      } on DioException catch (e) {
        if (e.response != null) {
          return true;
        }
      }

      // Fallback to openapi.json connectivity verification
      try {
        final rootUrl = normalizedBase.replaceAll('/api/v1', '');
        final response = await dio.get('$rootUrl/openapi.json');
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

  void _logDiagnosticFailure(ApiFailure failure, String context) {
    final error = failure.originalError;
    final buffer = StringBuffer();
    buffer.writeln('=== AUTH FAILURE DIAGNOSTIC ($context) ===');
    buffer.writeln('Failure Message: ${failure.message}');
    buffer.writeln('Failure Type: ${failure.type}');
    buffer.writeln('HTTP Status Code: ${failure.statusCode}');
    
    if (error != null) {
      buffer.writeln('Original Error Type: ${error.runtimeType}');
      buffer.writeln('Original Error Message: $error');
      if (error is DioException) {
        buffer.writeln('DioException Type: ${error.type}');
        buffer.writeln('Request Path: ${error.requestOptions.path}');
        buffer.writeln('Response Status: ${error.response?.statusCode}');
        var dataStr = error.response?.data?.toString() ?? 'N/A';
        if (dataStr.contains('access_token') || dataStr.contains('refresh_token')) {
          dataStr = '[REDACTED TOKENS]';
        }
        buffer.writeln('Response Data: $dataStr');
      }
    } else {
      buffer.writeln('No original exception object attached.');
    }
    
    try {
      if (error is Error && error.stackTrace != null) {
        buffer.writeln('Stack Trace:\n${error.stackTrace}');
      } else if (error is DioException) {
        buffer.writeln('Stack Trace:\n${error.stackTrace}');
      }
    } catch (_) {}
    
    buffer.writeln('==========================================');
    // ignore: avoid_print
    print(buffer.toString());
  }
}

final authStateProvider = NotifierProvider<AuthStateNotifier, AuthState>(
  AuthStateNotifier.new,
);
