import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../../school_setup/presentation/providers/school_setup_providers.dart';

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
  final String? message;
  const Unauthenticated([this.message]);
}

class AccountLocked extends Unauthenticated {
  static const defaultLockedMessage =
      'Your account is locked. Please contact your school administrator to unlock your account.';

  const AccountLocked([
    super.message = defaultLockedMessage,
  ]);
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}

final authLockMessageProvider = StateProvider<String?>((ref) => null);

bool isAccountLockedError({
  int? statusCode,
  String? message,
  dynamic originalError,
}) {
  final msg = message?.toLowerCase() ?? '';
  if (msg.contains('userstatus.locked') ||
      msg.contains('account status is currently') ||
      msg.contains('account is locked') ||
      msg.contains('account_locked')) {
    return true;
  }

  if (originalError is DioException) {
    final dataStr = originalError.response?.data?.toString().toLowerCase() ?? '';
    if (dataStr.contains('userstatus.locked') ||
        dataStr.contains('account status is currently') ||
        dataStr.contains('account is locked')) {
      return true;
    }
  }

  if (statusCode == 403 && (msg.contains('locked') || msg.contains('userstatus'))) {
    return true;
  }

  return false;
}

class AuthStateNotifier extends Notifier<AuthState> {
  static int _providerBuildCount = 0;
  bool _isCheckingAuth = false;

  @override
  AuthState build() {
    _providerBuildCount++;
    if (_providerBuildCount == 1) {
      AuthIncidentLogger.log('[AUTH PROVIDER] CREATED');
    } else {
      AuthIncidentLogger.log('[AUTH PROVIDER] RECREATED', {'buildCount': _providerBuildCount});
    }
    ref.onDispose(() {
      AuthIncidentLogger.log('[AUTH PROVIDER] DISPOSED');
    });

    AuthIncidentLogger.log('AUTH_STATE_INITIAL');
    Future.microtask(() => checkAuth());
    return const AuthInitial();
  }

  void setAuthenticated(UserEntity user) {
    _setAuthenticated(user);
  }

  void _setAuthenticated(UserEntity user) {
    AuthIncidentLogger.log('AUTH_STATE_AUTHENTICATED', {
      'userId': user.id,
      'email': user.email,
      'roles': user.roles,
    });
    state = Authenticated(user);
  }

  Future<void> _setUnauthenticated({
    required String reason,
    required String source,
    int? httpStatus,
    String? requestPath,
  }) async {
    final sessionManager = ref.read(sessionManagerProvider);
    final hasAccess = (await sessionManager.getAccessToken())?.isNotEmpty ?? false;
    final hasRefresh = (await sessionManager.getRefreshToken())?.isNotEmpty ?? false;

    AuthIncidentLogger.logUnauthenticated(
      previousState: state.runtimeType.toString(),
      sourceClass: 'AuthStateNotifier',
      sourceMethod: source,
      reason: reason,
      hasAccessToken: hasAccess,
      hasRefreshToken: hasRefresh,
      hasTenantContext: ref.read(selectedTenantIdProvider) != null,
      hasSchoolContext: ref.read(selectedSchoolIdProvider) != null,
      httpStatus: httpStatus,
      requestPath: requestPath,
    );
    ref.read(selectedTenantIdProvider.notifier).state = null;
    ref.read(selectedSchoolIdProvider.notifier).state = null;
    ref.read(selectedAcademicYearIdProvider.notifier).state = null;
    state = const Unauthenticated();
  }

  Future<void> _setAccountLocked({
    required String reason,
    required String source,
    int? httpStatus,
    String? requestPath,
  }) async {
    final sessionManager = ref.read(sessionManagerProvider);
    final hasAccess = (await sessionManager.getAccessToken())?.isNotEmpty ?? false;
    final hasRefresh = (await sessionManager.getRefreshToken())?.isNotEmpty ?? false;

    AuthIncidentLogger.logUnauthenticated(
      previousState: state.runtimeType.toString(),
      sourceClass: 'AuthStateNotifier',
      sourceMethod: source,
      reason: reason,
      hasAccessToken: hasAccess,
      hasRefreshToken: hasRefresh,
      hasTenantContext: ref.read(selectedTenantIdProvider) != null,
      hasSchoolContext: ref.read(selectedSchoolIdProvider) != null,
      httpStatus: httpStatus,
      requestPath: requestPath,
    );
    ref.read(selectedTenantIdProvider.notifier).state = null;
    ref.read(selectedSchoolIdProvider.notifier).state = null;
    ref.read(selectedAcademicYearIdProvider.notifier).state = null;
    state = const AccountLocked();
  }

  void setStateForTesting(AuthState newState) {
    state = newState;
  }

  Future<void> checkAuth() async {
    if (_isCheckingAuth) return;
    _isCheckingAuth = true;

    AuthIncidentLogger.log('CHECK_AUTH_STARTED');

    try {
      final sessionManager = ref.read(sessionManagerProvider);
      final hasSession = await sessionManager.hasSession();
      final hasAccess = (await sessionManager.getAccessToken())?.isNotEmpty ?? false;
      final hasRefresh = (await sessionManager.getRefreshToken())?.isNotEmpty ?? false;

      debugPrint('[AUTH DIAGNOSTIC] checkAuth started');
      debugPrint('[AUTH DIAGNOSTIC] hasSession: $hasSession | hasAccessToken: $hasAccess | hasRefreshToken: $hasRefresh');

      if (!hasSession) {
        AuthIncidentLogger.log('CHECK_AUTH_FAILURE', {'reason': 'No session tokens found in storage'});
        await _setUnauthenticated(
          reason: 'No session tokens found in storage',
          source: 'AuthStateNotifier.checkAuth',
        );
        return;
      }

      // Restore saved tenant context prior to session validation
      final savedTenantId = await sessionManager.getTenantId();
      if (savedTenantId != null && savedTenantId.isNotEmpty) {
        if (ref.read(selectedTenantIdProvider) != savedTenantId) {
          ref.read(selectedTenantIdProvider.notifier).state = savedTenantId;
        }
      }

      state = const AuthLoading();
      final validateSession = ref.read(validateSessionUseCaseProvider);
      final result = await validateSession().timeout(
        const Duration(seconds: 15),
        onTimeout: () => const ApiResult.failure(
          ApiFailure(
            message: 'Connection timed out while verifying your session. Please check your network.',
            type: ApiFailureType.network,
          ),
        ),
      );

      await result.when(
        onSuccess: (user) async {
          final hasAdminAccess = user.isSuperuser || 
              user.roles.any((r) {
                final role = r.toUpperCase();
                return role == 'SUPER_ADMIN' || 
                    role == 'SYSTEM_ADMIN' ||
                    role == 'ADMIN' || 
                    role == 'TENANT_ADMIN' ||
                    role == 'CHAIRMAN' ||
                    role == 'PRINCIPAL' ||
                    role == 'SCHOOL_ADMIN' ||
                    role == 'TEACHER' ||
                    role == 'STAFF';
              });
                  
          if (!hasAdminAccess) {
            EduLogger.w('User authenticated but lacks admin access: ${user.email}');
            await sessionManager.clearSession('AuthStateNotifier.checkAuth.noAdminAccess');
            await _setUnauthenticated(
              reason: 'User lacks administrative privileges: ${user.email}',
              source: 'AuthStateNotifier.checkAuth.noAdminAccess',
              httpStatus: 403,
              requestPath: '/auth/me',
            );
            return;
          }

          await _setupUserContext(user, sessionManager);
          AuthIncidentLogger.log('CHECK_AUTH_SUCCESS', {'user': user.email});
          _setAuthenticated(user);
        },
        onFailure: (failure) async {
          AuthIncidentLogger.log('CHECK_AUTH_FAILURE', {
            'statusCode': failure.statusCode,
            'message': failure.message,
          });
          _logDiagnosticFailure(failure, 'async-onFailure');

          final isLocked = isAccountLockedError(
            statusCode: failure.statusCode,
            message: failure.message,
            originalError: failure.originalError,
          );

          if (isLocked) {
            EduLogger.w('Saved session was rejected: Account is locked (HTTP ${failure.statusCode}): ${failure.message}. Clearing tokens and transitioning to AccountLocked.');
            await sessionManager.clearSession('AuthStateNotifier.checkAuth.account_locked');
            ref.read(authLockMessageProvider.notifier).state =
                AccountLocked.defaultLockedMessage;
            await _setAccountLocked(
              reason: 'Account is locked (HTTP ${failure.statusCode}): ${failure.message}',
              source: 'AuthStateNotifier.checkAuth.accountLocked',
              httpStatus: failure.statusCode,
              requestPath: '/auth/me',
            );
            return;
          }

          final isCredentialRejection = failure.statusCode == 401 ||
              failure.statusCode == 403 ||
              failure.type == ApiFailureType.unauthorized ||
              (failure.message.toLowerCase().contains('unauthorized') ||
                  failure.message.toLowerCase().contains('invalid authentication token') ||
                  failure.message.toLowerCase().contains('token signature has expired') ||
                  failure.message.toLowerCase().contains('access denied') ||
                  failure.message.contains('401') ||
                  failure.message.contains('403'));

          final errorCategory = isCredentialRejection
              ? 'CREDENTIAL_REJECTION'
              : (failure.type == ApiFailureType.network
                  ? 'NETWORK_TIMEOUT'
                  : 'SERVER_OPERATIONAL');

          debugPrint('[AUTH DIAGNOSTIC] Session validation failed');
          debugPrint('[AUTH DIAGNOSTIC] Endpoint: /auth/me | Method: GET');
          debugPrint('[AUTH DIAGNOSTIC] Status Code: ${failure.statusCode ?? "NONE"}');
          debugPrint('[AUTH DIAGNOSTIC] Failure Type: ${failure.type}');
          debugPrint('[AUTH DIAGNOSTIC] Error Category: $errorCategory');

          if (isCredentialRejection) {
            EduLogger.w('Saved session was rejected with invalid credentials (HTTP ${failure.statusCode}): ${failure.message}. Clearing invalid auth state and routing to login.');
            await sessionManager.clearSession('AuthStateNotifier.checkAuth.invalid_credentials');
            await _setUnauthenticated(
              reason: 'Saved session was invalid or expired (HTTP ${failure.statusCode}): ${failure.message}',
              source: 'AuthStateNotifier.checkAuth',
              httpStatus: failure.statusCode,
              requestPath: '/auth/me',
            );
          } else {
            EduLogger.w('Network, timeout, or operational session validation error (HTTP ${failure.statusCode}): ${failure.message}. Preserving saved tokens for retry.');
            if (failure.statusCode == 404) {
              state = const AuthError('The EduPulse authentication service endpoint was not found (HTTP 404). Please ensure the EduPulse backend is running at http://127.0.0.1:8000.');
            } else {
              state = AuthError(failure.message);
            }
          }
        },
      );
    } catch (e, st) {
      EduLogger.e('Unexpected error in checkAuth: $e', e, st);
      AuthIncidentLogger.log('CHECK_AUTH_EXCEPTION', {'error': e.toString()});
      state = AuthError(e.toString());
    } finally {
      _isCheckingAuth = false;
    }
  }

  Future<void> _setupUserContext(UserEntity user, SessionManager sessionManager) async {
    final isSuper = user.isSuperuser || user.roles.any((r) {
      final role = r.toUpperCase();
      return role == 'SUPER_ADMIN' || role == 'SYSTEM_ADMIN';
    });
    final isTenant = !isSuper && user.roles.any((r) {
      final role = r.toUpperCase();
      return role == 'TENANT_ADMIN' || role == 'CHAIRMAN' || role == 'ADMIN' || role == 'ADMINISTRATOR';
    });

    if (!user.isSuperuser && user.tenantId != null && user.tenantId!.isNotEmpty) {
      ref.read(selectedTenantIdProvider.notifier).state = user.tenantId;
      await sessionManager.saveTenantId(user.tenantId!);
    }

    if (!isSuper && !isTenant) {
      // School-scoped user (Principal, Teacher, etc.)
      if (user.schools.length == 1) {
        final singleSchoolId = user.schools.first;
        ref.read(selectedSchoolIdProvider.notifier).state = singleSchoolId;
        await sessionManager.saveSchoolId(singleSchoolId);
        final name = user.schoolNames[singleSchoolId];
        if (name != null && name.isNotEmpty) {
          await sessionManager.saveSchoolName(name);
        }
      } else if (user.schools.length > 1) {
        final savedId = await sessionManager.getSchoolId();
        if (savedId != null && user.schools.contains(savedId)) {
          ref.read(selectedSchoolIdProvider.notifier).state = savedId;
        } else {
          final firstSchoolId = user.schools.first;
          ref.read(selectedSchoolIdProvider.notifier).state = firstSchoolId;
          await sessionManager.saveSchoolId(firstSchoolId);
          final name = user.schoolNames[firstSchoolId];
          if (name != null && name.isNotEmpty) {
            await sessionManager.saveSchoolName(name);
          }
        }
      } else {
        EduLogger.w('User ${user.email} is not assigned to any school.');
      }
    } else {
      // Platform / Tenant Admin: restore saved school if available
      final savedId = await sessionManager.getSchoolId();
      if (savedId != null && savedId.isNotEmpty) {
        ref.read(selectedSchoolIdProvider.notifier).state = savedId;
      }
    }
  }

  Future<void> login(String email, String password) async {
    ref.read(authLockMessageProvider.notifier).state = null;
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

        // Immediately resolve and synchronize tenant context from JWT before validating session
        final tokenTenantId = _extractTenantIdFromJwt(token.accessToken);
        if (tokenTenantId != null && tokenTenantId.isNotEmpty) {
          ref.read(selectedTenantIdProvider.notifier).state = tokenTenantId;
          await sessionManager.saveTenantId(tokenTenantId);
        }

        // Fetch user data after successful token caching
        final validateSession = ref.read(validateSessionUseCaseProvider);
        final userResult = await validateSession();

        await userResult.when(
          onSuccess: (user) async {
            final hasAdminAccess = user.isSuperuser || 
                user.roles.any((r) {
                  final role = r.toUpperCase();
                  return role == 'SUPER_ADMIN' || 
                      role == 'SYSTEM_ADMIN' ||
                      role == 'ADMIN' || 
                      role == 'TENANT_ADMIN' ||
                      role == 'CHAIRMAN' ||
                      role == 'PRINCIPAL' ||
                      role == 'SCHOOL_ADMIN' ||
                      role == 'TEACHER' ||
                      role == 'STAFF';
                });
                    
            if (!hasAdminAccess) {
              EduLogger.w('User logged in but lacks admin privileges: ${user.email}');
              await sessionManager.clearSession('AuthStateNotifier.login.noAdminAccess');
              state = const AuthError('ACCESS_DENIED');
              return;
            }

            await _setupUserContext(user, sessionManager);
            AuthIncidentLogger.log('LOGIN_SUCCESS', {'email': email, 'roles': user.roles});
            _setAuthenticated(user);
          },
          onFailure: (failure) async {
            _logDiagnosticFailure(failure, 'onFailure');
            debugPrint('[AUTH DIAGNOSTIC] Login session validation failed: ${failure.statusCode}');
            final isLocked = isAccountLockedError(
              statusCode: failure.statusCode,
              message: failure.message,
              originalError: failure.originalError,
            );
            if (isLocked) {
              await sessionManager.clearSession('AuthStateNotifier.login.validateFailed.account_locked');
              ref.read(selectedTenantIdProvider.notifier).state = null;
              ref.read(selectedSchoolIdProvider.notifier).state = null;
              ref.read(selectedAcademicYearIdProvider.notifier).state = null;
              ref.read(authLockMessageProvider.notifier).state =
                  AccountLocked.defaultLockedMessage;
              state = const AccountLocked();
              return;
            }
            final isAuthRejection = failure.statusCode == 401 ||
                failure.statusCode == 403 ||
                failure.type == ApiFailureType.unauthorized;
            if (isAuthRejection) {
              await sessionManager.clearSession('AuthStateNotifier.login.validateFailed');
            }
            state = AuthError(
                'Failed to retrieve user details: ${failure.message}');
          },
        );
      },
      onFailure: (failure) async {
        _logDiagnosticFailure(failure, 'onFailure');
        final isLocked = isAccountLockedError(
          statusCode: failure.statusCode,
          message: failure.message,
          originalError: failure.originalError,
        );
        if (isLocked) {
          final sessionManager = ref.read(sessionManagerProvider);
          await sessionManager.clearSession('AuthStateNotifier.login.account_locked');
          ref.read(selectedTenantIdProvider.notifier).state = null;
          ref.read(selectedSchoolIdProvider.notifier).state = null;
          ref.read(selectedAcademicYearIdProvider.notifier).state = null;
          ref.read(authLockMessageProvider.notifier).state =
              AccountLocked.defaultLockedMessage;
          state = const AccountLocked();
          return;
        }
        state = AuthError(failure.message);
      },
    );
  }

  String? _extractTenantIdFromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payloadString = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(payloadString) as Map<String, dynamic>;
      final tid = payload['tenant_id'];
      if (tid is String && tid.isNotEmpty && tid != 'None') {
        return tid;
      }
    } catch (_) {}
    return null;
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

      // Try primary /health or /system/health endpoints
      try {
        final response = await dio.get('$normalizedBase/health');
        if (response.statusCode == 200) {
          return true;
        }
      } on DioException catch (e) {
        if (e.response != null) {
          return true;
        }
      }

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
    AuthIncidentLogger.log('LOGOUT_CALLED', {'source': 'AuthStateNotifier.logout'});
    debugPrintStack(label: '[AUTH INCIDENT] CALL STACK FOR LOGOUT_CALLED');
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
      await sessionManager.clearSession('AuthStateNotifier.logout');
      ref.read(selectedTenantIdProvider.notifier).state = null;
      ref.read(selectedSchoolIdProvider.notifier).state = null;
      ref.read(selectedAcademicYearIdProvider.notifier).state = null;
      await _setUnauthenticated(
        reason: 'User or system invoked logout()',
        source: 'AuthStateNotifier.logout',
      );
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
