import 'package:dio/dio.dart';
import 'package:edupulse_core/edupulse_core.dart';

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    options.extra['start_time'] = DateTime.now().millisecondsSinceEpoch;

    final fullUrl = options.uri.toString();

    final headersBuffer = StringBuffer();
    options.headers.forEach((key, value) {
      if (key.toLowerCase() == 'authorization') {
        headersBuffer.writeln('$key: Bearer ***REDACTED***');
      } else {
        headersBuffer.writeln('$key: $value');
      }
    });

    EduLogger.d(
      '🌐 REQUEST[${options.method}] => FULL URL: $fullUrl\n'
      '================================\n'
      'REQUEST HEADERS\n'
      '${headersBuffer.toString()}'
      '================================\n'
      'QueryParameters: ${options.queryParameters}\n'
      'Body: ${options.data}',
    );
    super.onRequest(options, handler);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final startTime = response.requestOptions.extra['start_time'] as int?;
    final elapsedStr = startTime != null
        ? '${DateTime.now().millisecondsSinceEpoch - startTime}ms'
        : 'unknown';

    final fullUrl = response.requestOptions.uri.toString();

    EduLogger.d(
      '✅ RESPONSE[${response.statusCode}] => FULL URL: $fullUrl\n'
      'Elapsed Time: $elapsedStr\n'
      'Data: ${response.data}',
    );
    super.onResponse(response, handler);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    final startTime = err.requestOptions.extra['start_time'] as int?;
    final elapsedStr = startTime != null
        ? '${DateTime.now().millisecondsSinceEpoch - startTime}ms'
        : 'unknown';

    final fullUrl = err.requestOptions.uri.toString();

    final errorMsg = err.error?.toString() ?? '';
    final isConnectionIssue = errorMsg.contains('SocketException') ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.connectionError;

    if (isConnectionIssue) {
      EduLogger.e(
        '❌ ERROR => FULL URL: $fullUrl\n'
        'Cannot reach backend.\n'
        'Elapsed Time: $elapsedStr',
        err.error,
        err.stackTrace,
      );
    } else {
      EduLogger.e(
        '❌ ERROR[${err.response?.statusCode}] => FULL URL: $fullUrl\n'
        'Elapsed Time: $elapsedStr\n'
        'Message: ${err.message}\n'
        'Response: ${err.response?.data}',
        err.error,
        err.stackTrace,
      );
    }
    super.onError(err, handler);
  }
}
