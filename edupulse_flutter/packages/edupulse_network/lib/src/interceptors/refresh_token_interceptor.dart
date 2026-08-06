import 'package:dio/dio.dart';
import '../token_provider.dart';

class RefreshTokenInterceptor extends Interceptor {
  final AuthTokenProvider? _tokenProvider;
  final Dio _dio;

  RefreshTokenInterceptor({
    AuthTokenProvider? tokenProvider,
    required Dio dio,
  })  : _tokenProvider = tokenProvider,
        _dio = dio;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    
    if (response?.statusCode == 401 && _tokenProvider != null) {
      try {
        await _tokenProvider.refreshSession();

        final newToken = await _tokenProvider.getAccessToken();
        if (newToken != null && newToken.isNotEmpty) {
          final requestOptions = err.requestOptions;
          requestOptions.headers['Authorization'] = 'Bearer $newToken';

          final retryResponse = await _dio.fetch(requestOptions);
          return handler.resolve(retryResponse);
        }
      } catch (e) {
        return super.onError(err, handler);
      }
    }

    super.onError(err, handler);
  }
}
