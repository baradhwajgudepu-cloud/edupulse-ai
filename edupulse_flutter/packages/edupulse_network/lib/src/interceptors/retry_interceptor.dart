import 'dart:io';
import 'package:dio/dio.dart';
import 'package:edupulse_core/edupulse_core.dart';

class RetryInterceptor extends Interceptor {
  final Dio _dio;
  final int maxRetries;
  final int initialDelayMs;

  RetryInterceptor({
    required Dio dio,
    this.maxRetries = 3,
    this.initialDelayMs = 1000,
  }) : _dio = dio;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final requestOptions = err.requestOptions;
    final extra = requestOptions.extra;
    final int retryCount = (extra['retry_count'] as int?) ?? 0;

    final shouldRetry = _isNetworkError(err) && retryCount < maxRetries;

    if (shouldRetry) {
      final nextRetry = retryCount + 1;
      extra['retry_count'] = nextRetry;

      final delay = initialDelayMs * (1 << (nextRetry - 1));

      EduLogger.w(
        'Network error detected. Retrying request (${requestOptions.path}) '
        'attempt $nextRetry/$maxRetries in ${delay}ms...',
      );

      await Future.delayed(Duration(milliseconds: delay));

      try {
        final response = await _dio.fetch(requestOptions);
        return handler.resolve(response);
      } catch (e) {
        return super.onError(err, handler);
      }
    }

    super.onError(err, handler);
  }

  bool _isNetworkError(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        err.error is SocketException;
  }
}
