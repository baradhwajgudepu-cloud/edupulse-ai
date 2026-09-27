import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_core/edupulse_core.dart';
import '../token_provider.dart';
import '../network_providers.dart';

class RefreshTokenInterceptor extends Interceptor {
  final AuthTokenProvider? _tokenProvider;
  final Dio _dio;
  final Ref? _ref;
  final void Function()? _onSessionExpired;

  Completer<void>? _refreshCompleter;

  RefreshTokenInterceptor({
    AuthTokenProvider? tokenProvider,
    required Dio dio,
    Ref? ref,
    void Function()? onSessionExpired,
  })  : _tokenProvider = tokenProvider,
        _dio = dio,
        _ref = ref,
        _onSessionExpired = onSessionExpired;

  void _notifySessionExpired() {
    AuthIncidentLogger.log('SESSION_EXPIRED', {
      'source': 'RefreshTokenInterceptor._notifySessionExpired',
    });
    debugPrintStack(
      label: '[AUTH INCIDENT] CALL STACK FOR SESSION_EXPIRED',
    );
    if (_ref != null) {
      _ref.read(sessionExpiredProvider.notifier).state = true;
    }
    if (_onSessionExpired != null) {
      _onSessionExpired();
    }
  }

  bool _isAuthEndpoint(String path) {
    return path.contains('/auth/login') ||
        path.contains('/auth/platform-login') ||
        path.contains('/auth/refresh') ||
        path.contains('/auth/forgot-password') ||
        path.contains('/auth/reset-password');
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final requestOptions = err.requestOptions;
    final isAuth = _isAuthEndpoint(requestOptions.path);
    final retryAttempt = requestOptions.extra['isRetry'] == true ? 1 : 0;

    debugPrint('[AUTH HTTP]');
    debugPrint('METHOD: ${requestOptions.method}');
    debugPrint('PATH: ${requestOptions.path}');
    debugPrint('STATUS: ${response?.statusCode ?? 'ERROR_${err.type.name}'}');
    debugPrint('AUTH ENDPOINT: ${isAuth ? 'YES' : 'NO'}');
    debugPrint('RETRY ATTEMPT: $retryAttempt');

    // Do not attempt to refresh if the request was an auth endpoint (login, refresh, reset)
    if (isAuth) {
      return super.onError(err, handler);
    }

    final isRetry = requestOptions.extra['isRetry'] == true;

    // Check if the failed request carried an Authorization header OR if there is an active session in storage.
    // If the request had no Bearer token and there is no active token in storage, it was an unauthenticated request
    // (e.g. pre-login, probe, or public endpoint before authentication).
    // It must NEVER trigger refresh or session expiration!
    final authHeader = requestOptions.headers['Authorization'] as String?;
    final hasAuthHeader = authHeader != null && authHeader.startsWith('Bearer ') && authHeader.length > 10;
    final currentAccessToken = _tokenProvider != null ? await _tokenProvider.getAccessToken() : null;
    if (!hasAuthHeader && (currentAccessToken == null || currentAccessToken.isEmpty)) {
      return super.onError(err, handler);
    }

    // HTTP 401 is the ONLY status code that should attempt token refresh
    if (response?.statusCode == 401 && _tokenProvider != null) {
      if (isRetry) {
        // Refresh token already tried for this request and failed again
        _notifySessionExpired();
        return super.onError(err, handler);
      }

      // Check if a refresh token is actually present in storage.
      final currentRefreshToken = await _tokenProvider.getRefreshToken();
      if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
        // No refresh token available. Do NOT expire session or logout.
        return super.onError(err, handler);
      }

      try {
        // Single-flight refresh mutex: if another request is already refreshing, wait for it
        if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
          await _refreshCompleter!.future;
        } else {
          _refreshCompleter = Completer<void>();
          try {
            AuthIncidentLogger.log('REFRESH_STARTED');
            await _tokenProvider.refreshSession();
            AuthIncidentLogger.log('REFRESH_SUCCESS');
            _refreshCompleter!.complete();
          } catch (refreshErr) {
            AuthIncidentLogger.log('REFRESH_FAILURE', {'error': '$refreshErr'});
            if (!_refreshCompleter!.isCompleted) {
              _refreshCompleter!.complete();
            }
            // Strict Phase 7 Invariant: ONLY notify session expired if refresh definitively failed
            // with an HTTP authentication rejection (401 / unauthorized / invalid refresh token).
            bool isAuthRejection = false;
            if (refreshErr is DioException && refreshErr.response?.statusCode == 401) {
              isAuthRejection = true;
            } else if (refreshErr.toString().contains('401') ||
                refreshErr.toString().toLowerCase().contains('invalid refresh token') ||
                refreshErr.toString().toLowerCase().contains('unauthorized')) {
              isAuthRejection = true;
            }
            if (isAuthRejection) {
              _notifySessionExpired();
            }
            return super.onError(err, handler);
          } finally {
            _refreshCompleter = null;
          }
        }

        final newToken = await _tokenProvider.getAccessToken();
        if (newToken != null && newToken.isNotEmpty) {
          requestOptions.extra['isRetry'] = true;
          requestOptions.headers['Authorization'] = 'Bearer $newToken';

          final retryResponse = await _dio.fetch(requestOptions);
          return handler.resolve(retryResponse);
        } else {
          return super.onError(err, handler);
        }
      } catch (e) {
        return super.onError(err, handler);
      }
    }

    // For any other status code (403, 400, 404, 422, 500, etc.) NEVER refresh and NEVER notify session expired
    super.onError(err, handler);
  }
}
