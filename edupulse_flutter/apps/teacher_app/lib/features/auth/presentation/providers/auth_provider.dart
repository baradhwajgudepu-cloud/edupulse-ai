import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../../../core/providers/school_context_provider.dart';

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

class Unauthorized extends AuthState {
  final String message;
  const Unauthorized(this.message);
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

  void setUnauthorized(String message) {
    state = Unauthorized(message);
  }

  void clearMustChangePassword() {
    if (state is Authenticated) {
      final cur = (state as Authenticated).user;
      state = Authenticated(
        UserEntity(
          id: cur.id,
          email: cur.email,
          firstName: cur.firstName,
          lastName: cur.lastName,
          tenantId: cur.tenantId,
          isSuperuser: cur.isSuperuser,
          roles: cur.roles,
          schools: cur.schools,
          schoolNames: cur.schoolNames,
          mustChangePassword: false,
        ),
      );
    }
  }

  Future<void> checkAuth() async {
    final sessionManager = ref.read(sessionManagerProvider);
    final hasSession = await sessionManager.hasSession();

    if (!hasSession) {
      state = const Unauthenticated();
      return;
    }

    state = const AuthLoading();

    // Restore cached tenant context first to prevent default fallback during validation
    final cachedTenantId = await sessionManager.getTenantId();
    if (cachedTenantId != null && cachedTenantId.isNotEmpty) {
      ref.read(selectedTenantIdProvider.notifier).state = cachedTenantId;
    }

    final validateSession = ref.read(validateSessionUseCaseProvider);
    final result = await validateSession();

    await result.when(
      onSuccess: (user) async {
        final isTeacher = user.isSuperuser || 
            user.roles.map((r) => r.toUpperCase()).contains('TEACHER');

        if (!isTeacher) {
          EduLogger.w('User is not authorized as a teacher. Roles: ${user.roles}');
          state = const Unauthorized('Access denied. Insufficient role permissions. You are not registered as a teacher.');
          return;
        }

        if (user.schools.isNotEmpty) {
          final cachedSchoolId = await sessionManager.getSchoolId();
          final targetSchoolId = (cachedSchoolId != null && user.schools.contains(cachedSchoolId))
              ? cachedSchoolId
              : user.schools.first;
          await sessionManager.saveSchoolId(targetSchoolId);
          final schoolName = user.schoolNames[targetSchoolId] ?? 'School: $targetSchoolId';
          await sessionManager.saveSchoolName(schoolName);
          ref.read(activeSchoolIdProvider.notifier).state = targetSchoolId;
        }
        if (user.tenantId != null) {
          await sessionManager.saveTenantId(user.tenantId!);
        }
        ref.read(selectedTenantIdProvider.notifier).state = user.tenantId;
        state = Authenticated(user);
      },
      onFailure: (failure) async {
        _logDiagnosticFailure(failure, 'async-onFailure');
        EduLogger.w('Saved session was invalid or expired: ${failure.message}');
        await sessionManager.clearSession();
        ref.read(selectedTenantIdProvider.notifier).state = null;
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
            final isTeacher = user.isSuperuser || 
                user.roles.map((r) => r.toUpperCase()).contains('TEACHER');

            if (!isTeacher) {
              EduLogger.w('User logged in but is not a teacher. Roles: ${user.roles}');
              final sessionManager = ref.read(sessionManagerProvider);
              await sessionManager.clearSession();
              ref.read(selectedTenantIdProvider.notifier).state = null;
              state = const Unauthorized('Access denied. Insufficient role permissions. You are not registered as a teacher.');
              return;
            }

            final sessionManager = ref.read(sessionManagerProvider);
            if (user.schools.isNotEmpty) {
              final cachedSchoolId = await sessionManager.getSchoolId();
              final targetSchoolId = (cachedSchoolId != null && user.schools.contains(cachedSchoolId))
                  ? cachedSchoolId
                  : user.schools.first;
              await sessionManager.saveSchoolId(targetSchoolId);
              final schoolName = user.schoolNames[targetSchoolId] ?? 'School: $targetSchoolId';
              await sessionManager.saveSchoolName(schoolName);
              ref.read(activeSchoolIdProvider.notifier).state = targetSchoolId;
            }
            if (user.tenantId != null) {
              await sessionManager.saveTenantId(user.tenantId!);
            }
            ref.read(selectedTenantIdProvider.notifier).state = user.tenantId;
            state = Authenticated(user);
          },
          onFailure: (failure) async {
        _logDiagnosticFailure(failure, 'async-onFailure');
            await sessionManager.clearSession();
            ref.read(selectedTenantIdProvider.notifier).state = null;
            state = AuthError('Failed to retrieve user details: ${failure.message}');
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
    if (ref.read(isTestingProvider)) {
      return true;
    }
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final normalizedBase = apiBaseUrl.endsWith('/')
          ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
          : apiBaseUrl;

      // 1. Try system health endpoint (/api/v1/system/health)
      try {
        final response = await dio.get('$normalizedBase/system/health');
        if (response.statusCode == 200) {
          return true;
        }
      } on DioException catch (e) {
        if (e.response != null) {
          // If we received any response, server is active and reachable
          return true;
        }
      }

      // 2. Try standard health endpoint (/api/v1/health)
      try {
        final response = await dio.get('$normalizedBase/health');
        if (response.statusCode == 200) {
          return true;
        }
      } on DioException catch (e) {
        if (e.response != null) {
          // If we received any response, server is active and reachable
          return true;
        }
      }

      // 3. Fallback to openapi.json connectivity verification
      try {
        final response = await dio.get('$normalizedBase/openapi.json');
        if (response.statusCode == 200) {
          return true;
        }
      } on DioException catch (e) {
        if (e.response != null) {
          // If we received any response, server is active and reachable
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
      ref.read(selectedTenantIdProvider.notifier).state = null;
      state = const Unauthenticated();
    }
  }

  Future<void> clearSessionLocally() async {
    final sessionManager = ref.read(sessionManagerProvider);
    await sessionManager.clearSession();
    state = const Unauthenticated();
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
      } else if (error is DioException && error.stackTrace != null) {
        buffer.writeln('Stack Trace:\n${error.stackTrace}');
      }
    } catch (_) {}
    
    buffer.writeln('==========================================');
    // ignore: avoid_print
    print(buffer.toString());
  }
}

final isTestingProvider = Provider<bool>((ref) => false);

final authStateProvider = NotifierProvider<AuthStateNotifier, AuthState>(
  AuthStateNotifier.new,
);
