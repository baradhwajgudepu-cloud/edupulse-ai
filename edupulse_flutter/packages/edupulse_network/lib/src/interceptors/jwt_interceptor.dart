import 'package:dio/dio.dart';
import '../token_provider.dart';

class JwtInterceptor extends Interceptor {
  final AuthTokenProvider? _tokenProvider;
  final String _tenantId;

  JwtInterceptor({
    AuthTokenProvider? tokenProvider,
    required String tenantId,
  })  : _tokenProvider = tokenProvider,
        _tenantId = tenantId;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers['X-Tenant-ID'] = _tenantId;

    if (_tokenProvider != null) {
      final token = await _tokenProvider.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    super.onRequest(options, handler);
  }
}
