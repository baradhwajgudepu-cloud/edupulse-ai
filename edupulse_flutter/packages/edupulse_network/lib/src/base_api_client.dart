import 'package:dio/dio.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'api_result.dart';
import 'api_exception.dart';

class BaseApiClient {
  final Dio _dio;

  const BaseApiClient(this._dio);

  String _normalizePath(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return path.startsWith('/') ? path.substring(1) : path;
  }

  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    final normalizedPath = _normalizePath(path);
    if (path.contains('/fees/reports/dashboard')) {
      final safeDioHeaders = Map<String, dynamic>.from(_dio.options.headers)
        ..removeWhere((k, v) => k.toLowerCase().contains('auth') || k.toLowerCase().contains('token'));
      final safeOptHeaders = options?.headers != null
          ? (Map<String, dynamic>.from(options!.headers!)
            ..removeWhere((k, v) => k.toLowerCase().contains('auth') || k.toLowerCase().contains('token')))
          : null;
      // ignore: avoid_print
      print('dio.options.headers: $safeDioHeaders');
      // ignore: avoid_print
      print('options.headers: $safeOptHeaders');
    }
    return _safeRequest(
      () => _dio.get(
        normalizedPath,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
      mapper,
    );
  }

  Future<ApiResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    final normalizedPath = _normalizePath(path);
    final isLogin = path.contains('/auth/login') || path.contains('/auth/platform-login');
    final isStudent = path.contains('students');
    try {
      if (isStudent) {
        final fullUrl = '${_dio.options.baseUrl}$normalizedPath';
        final reqHeaders = <String, dynamic>{
          ..._dio.options.headers,
          ...?options?.headers,
        };
        final safeHeaders = Map<String, dynamic>.from(reqHeaders)
          ..removeWhere((key, value) =>
              key.toLowerCase().contains('auth') ||
              key.toLowerCase().contains('token') ||
              key.toLowerCase().contains('password'));
        // ignore: avoid_print
        print('[BASE_API_CLIENT POST START] URL: $fullUrl | Headers: $safeHeaders | Method: POST');
        // ignore: avoid_print
        print('[BASE_API_CLIENT STUDENT OPTIONS] '
            'baseUrl: ${_dio.options.baseUrl} | '
            'connectTimeout: ${_dio.options.connectTimeout} / ${options?.connectTimeout} | '
            'sendTimeout: ${_dio.options.sendTimeout} / ${options?.sendTimeout} | '
            'receiveTimeout: ${_dio.options.receiveTimeout} / ${options?.receiveTimeout} | '
            'extra: ${_dio.options.extra} / ${options?.extra} | '
            'contentType: ${_dio.options.contentType} / ${options?.contentType} | '
            'responseType: ${_dio.options.responseType} / ${options?.responseType} | '
            'validateStatus: ${_dio.options.validateStatus} / ${options?.validateStatus} | '
            'followRedirects: ${_dio.options.followRedirects} / ${options?.followRedirects} | '
            'persistentConnection: ${_dio.options.persistentConnection} / ${options?.persistentConnection}');
      }

      final response = await _dio.post(
        normalizedPath,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      if (isLogin) {
        _logPostSuccess(normalizedPath, data, options, response);
      }
      if (isStudent) {
        // ignore: avoid_print
        print('[BASE_API_CLIENT POST SUCCESS] URL: ${_dio.options.baseUrl}$normalizedPath | Status: ${response.statusCode}');
      }
      final responseData = response.data;
      try {
        final parsed = mapper(responseData);
        return ApiResult.success(parsed);
      } catch (e) {
        throw FormatException('Serialization failed: $e');
      }
    } catch (e) {
      if (isLogin) {
        _logPostFailure(normalizedPath, data, options, e);
      }
      if (isStudent) {
        int? statusCode;
        String? responseMsg;
        String? dioExceptionType;
        if (e is DioException) {
          statusCode = e.response?.statusCode;
          responseMsg = e.response?.data?.toString();
          dioExceptionType = e.type.toString();
        }
        // ignore: avoid_print
        print('[BASE_API_CLIENT POST FAILURE] URL: ${_dio.options.baseUrl}$normalizedPath | DioType: $dioExceptionType | Status: $statusCode | Response: $responseMsg | Error: $e');
      }
      final failure = ApiExceptionMapper.mapToFailure(e);
      return ApiResult.failure(failure);
    }
  }

  Future<ApiResult<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    return _safeRequest(
      () => _dio.put(
        _normalizePath(path),
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
      mapper,
    );
  }

  Future<ApiResult<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    return _safeRequest(
      () => _dio.patch(
        _normalizePath(path),
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
      mapper,
    );
  }

  Future<ApiResult<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    return _safeRequest(
      () => _dio.delete(
        _normalizePath(path),
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
      mapper,
    );
  }

  Future<ApiResult<T>> _safeRequest<T>(
    Future<Response<dynamic>> Function() request,
    T Function(dynamic json) mapper,
  ) async {
    try {
      final response = await request();
      final data = response.data;

      try {
        final parsed = mapper(data);
        return ApiResult.success(parsed);
      } catch (e) {
        throw FormatException('Serialization failed: $e');
      }
    } catch (e) {
      final failure = ApiExceptionMapper.mapToFailure(e);
      return ApiResult.failure(failure);
    }
  }

  void _logPostSuccess(String path, dynamic data, Options? options, Response response) {
    final baseUrl = _dio.options.baseUrl;
    final fullUrl = baseUrl.endsWith('/') ? '$baseUrl${path.startsWith('/') ? path.substring(1) : path}' : '$baseUrl/${path.startsWith('/') ? path.substring(1) : path}';
    final reqHeaders = <String, dynamic>{
      ..._dio.options.headers,
      ...?options?.headers,
    };
    final safeHeaders = Map<String, dynamic>.from(reqHeaders)
      ..removeWhere((key, value) =>
          key.toLowerCase().contains('auth') ||
          key.toLowerCase().contains('token') ||
          key.toLowerCase().contains('password'));

    final email = (data is Map) ? data['email'] : null;
    final tenantId = reqHeaders['X-Tenant-ID'] ?? reqHeaders['x-tenant-id'];

    EduLogger.i(
      '--- DIAGNOSTIC LOGIN SUCCESS ---\n'
      '1. Resolved API Base URL: $baseUrl\n'
      '2. Actual Login URL: $fullUrl\n'
      '3. HTTP Method: POST\n'
      '4. HTTP Status Code: ${response.statusCode}\n'
      '5. Request Headers (Safe): $safeHeaders\n'
      '6. Request Email: $email\n'
      '7. X-Tenant-ID: $tenantId\n'
      '8. Response Status Message: ${response.statusMessage ?? response.statusCode}\n'
      '9. Response Body: SUCCESS (Tokens Redacted)\n'
      '10. DioException Type: N/A\n'
      '11. DioException Message: N/A\n'
      '--------------------------------'
    );
  }

  void _logPostFailure(String path, dynamic data, Options? options, dynamic e) {
    final baseUrl = _dio.options.baseUrl;
    final fullUrl = baseUrl.endsWith('/') ? '$baseUrl${path.startsWith('/') ? path.substring(1) : path}' : '$baseUrl/${path.startsWith('/') ? path.substring(1) : path}';
    final reqHeaders = <String, dynamic>{
      ..._dio.options.headers,
      ...?options?.headers,
    };
    final safeHeaders = Map<String, dynamic>.from(reqHeaders)
      ..removeWhere((key, value) =>
          key.toLowerCase().contains('auth') ||
          key.toLowerCase().contains('token') ||
          key.toLowerCase().contains('password'));

    final email = (data is Map) ? data['email'] : null;
    final tenantId = reqHeaders['X-Tenant-ID'] ?? reqHeaders['x-tenant-id'];

    int? statusCode;
    String? responseMsg;
    String? dioExceptionType;
    String? dioExceptionMessage;

    if (e is DioException) {
      statusCode = e.response?.statusCode;
      responseMsg = e.response?.data?.toString();
      dioExceptionType = e.type.toString();
      dioExceptionMessage = e.message;
    }

    final failure = ApiExceptionMapper.mapToFailure(e);

    EduLogger.e(
      '--- DIAGNOSTIC LOGIN FAILURE ---\n'
      '1. Resolved API Base URL: $baseUrl\n'
      '2. Actual Login URL: $fullUrl\n'
      '3. HTTP Method: POST\n'
      '4. HTTP Status Code: $statusCode\n'
      '5. Request Headers (Safe): $safeHeaders\n'
      '6. Request Email: $email\n'
      '7. X-Tenant-ID: $tenantId\n'
      '8. Response Status Message: $statusCode\n'
      '9. Response Body: ${responseMsg ?? "N/A"}\n'
      '10. DioException Type: ${dioExceptionType ?? "N/A"}\n'
      '11. DioException Message: ${dioExceptionMessage ?? "N/A"}\n'
      '12. Final AuthError Message: ${failure.message}\n'
      '--------------------------------'
    );
  }
}
