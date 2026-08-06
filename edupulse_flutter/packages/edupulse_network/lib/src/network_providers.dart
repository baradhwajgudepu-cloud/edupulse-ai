import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:edupulse_config/edupulse_config.dart';
import 'token_provider.dart';
import 'interceptors/jwt_interceptor.dart';
import 'interceptors/refresh_token_interceptor.dart';
import 'interceptors/retry_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'base_api_client.dart';

final authTokenProvider = Provider<AuthTokenProvider?>((ref) => null);

final buildConfigProvider = Provider<BuildConfig>((ref) {
  return BuildConfig.fromEnvironment();
});

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(buildConfigProvider);
  final tokenProv = ref.watch(authTokenProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: config.timeout,
      receiveTimeout: config.timeout,
      sendTimeout: config.timeout,
      contentType: 'application/json',
    ),
  );

  dio.interceptors.addAll([
    JwtInterceptor(
      tokenProvider: tokenProv,
      tenantId: config.tenantId,
    ),
    RefreshTokenInterceptor(
      tokenProvider: tokenProv,
      dio: dio,
    ),
    RetryInterceptor(
      dio: dio,
    ),
    LoggingInterceptor(),
  ]);

  return dio;
});

final apiClientProvider = Provider<BaseApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return BaseApiClient(dio);
});
