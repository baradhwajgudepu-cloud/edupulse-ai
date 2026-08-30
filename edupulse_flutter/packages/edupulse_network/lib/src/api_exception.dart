import 'package:dio/dio.dart';
import 'api_failure.dart';

class ApiException implements Exception {
  final ApiFailure failure;
  const ApiException(this.failure);

  @override
  String toString() => failure.message;
}

class ApiExceptionMapper {
  static ApiFailure mapToFailure(dynamic error) {
    if (error is DioException) {
      return _mapDioException(error);
    }

    if (error is FormatException) {
      return const ApiFailure(
        message: 'Parsing error occurred. Failed to serialize response.',
        type: ApiFailureType.validation,
      );
    }

    return ApiFailure(
      message: error?.toString() ?? 'An unexpected error occurred.',
      type: ApiFailureType.unknown,
      originalError: error,
    );
  }

  static ApiFailure _mapDioException(DioException exception) {
    final statusCode = exception.response?.statusCode;

    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiFailure(
          message:
              'Connection timed out. Please check your network and try again.',
          type: ApiFailureType.network,
          statusCode: statusCode,
          originalError: exception,
        );

      case DioExceptionType.badResponse:
        final responseData = exception.response?.data;
        String errorMessage = 'A server error occurred.';

        if (responseData is Map) {
          if (responseData['message'] is String && (responseData['message'] as String).trim().isNotEmpty) {
            errorMessage = (responseData['message'] as String).trim();
          } else if (responseData.containsKey('detail')) {
            final detail = responseData['detail'];
            if (detail is String && detail.trim().isNotEmpty) {
              errorMessage = detail.trim();
            } else if (detail is List) {
              errorMessage = detail.map((e) {
                if (e is Map) {
                  final loc = (e['loc'] as List?)?.join(' -> ') ?? '';
                  final msg = e['msg'] ?? e.toString();
                  return loc.isNotEmpty ? '[$loc]: $msg' : '$msg';
                }
                return e.toString();
              }).join('\n');
            }
          } else if (responseData['error'] != null) {
            errorMessage = responseData['error'].toString().trim();
          }
        }

        if (statusCode == 401) {
          return ApiFailure(
            message: 'Unauthorized access. Please login again.',
            type: ApiFailureType.unauthorized,
            statusCode: statusCode,
            originalError: exception,
          );
        }

        if (statusCode == 422) {
          return ApiFailure(
            message:
                errorMessage.isNotEmpty ? errorMessage : 'Validation failed.',
            type: ApiFailureType.validation,
            statusCode: statusCode,
            originalError: exception,
          );
        }

        if (statusCode != null && statusCode >= 500) {
          return ApiFailure(
            message: 'Internal server error occurred.',
            type: ApiFailureType.server,
            statusCode: statusCode,
            originalError: exception,
          );
        }

        return ApiFailure(
          message: errorMessage,
          type: ApiFailureType.unknown,
          statusCode: statusCode,
          originalError: exception,
        );

      case DioExceptionType.cancel:
        return ApiFailure(
          message: 'Request was cancelled.',
          type: ApiFailureType.unknown,
          statusCode: statusCode,
          originalError: exception,
        );

      case DioExceptionType.connectionError:
        return ApiFailure(
          message: 'No internet connection detected.',
          type: ApiFailureType.network,
          statusCode: statusCode,
          originalError: exception,
        );

      default:
        return ApiFailure(
          message: 'Unexpected network error occurred.',
          type: ApiFailureType.network,
          statusCode: statusCode,
          originalError: exception,
        );
    }
  }
}
