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

final sessionExpiredProvider = StateProvider<bool>((ref) => false);

final buildConfigProvider = Provider<BuildConfig>((ref) {
  return BuildConfig.fromEnvironment();
});

final selectedTenantIdProvider = StateProvider<String?>((ref) => null);

final activeTenantIdProvider = Provider<String?>((ref) {
  final selected = ref.watch(selectedTenantIdProvider);
  if (selected != null && selected.isNotEmpty) {
    return selected;
  }

  final config = ref.watch(buildConfigProvider);
  return config.tenantId;
});

final refreshDioProvider = Provider<Dio>((ref) {
  final config = ref.watch(buildConfigProvider);

  return Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
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
      tenantIdGetter: () => ref.read(activeTenantIdProvider),
    ),
    RefreshTokenInterceptor(
      tokenProvider: tokenProv,
      dio: dio,
      ref: ref,
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
