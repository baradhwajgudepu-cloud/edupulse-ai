import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../token_provider.dart';
import '../network_providers.dart';

class RefreshTokenInterceptor extends Interceptor {
  final AuthTokenProvider? _tokenProvider;
  final Dio _dio;
  final Ref? _ref;
  final void Function()? _onSessionExpired;

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
    if (_ref != null) {
      _ref.read(sessionExpiredProvider.notifier).state = true;
    }
    if (_onSessionExpired != null) {
      _onSessionExpired();
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final requestOptions = err.requestOptions;

    final isRetry = requestOptions.extra['isRetry'] == true;

    if (response?.statusCode == 401 && _tokenProvider != null) {
      if (isRetry) {
        _notifySessionExpired();
        return super.onError(err, handler);
      }

      try {
        await _tokenProvider.refreshSession();

        final newToken = await _tokenProvider.getAccessToken();
        if (newToken != null && newToken.isNotEmpty) {
          requestOptions.extra['isRetry'] = true;
          requestOptions.headers['Authorization'] = 'Bearer $newToken';

          final retryResponse = await _dio.fetch(requestOptions);
          return handler.resolve(retryResponse);
        }
      } catch (e) {
        _notifySessionExpired();
        return super.onError(err, handler);
      }
    }

    super.onError(err, handler);
  }
}
