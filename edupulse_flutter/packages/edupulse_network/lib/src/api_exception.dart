import 'package:dio/dio.dart';
import 'package:edupulse_core/edupulse_core.dart';
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
      EduLogger.e('Serialization/parsing error: ${error.message}', error);
      return ApiFailure(
        message: 'Parsing error occurred. Failed to serialize response: ${error.message}',
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
        String errorMessage = '';

        if (responseData is Map) {
          if (responseData.containsKey('message')) {
            final msg = responseData['message'];
            if (msg is String && msg.isNotEmpty) {
              errorMessage = msg;
            }
          }
          if (errorMessage.isEmpty && responseData.containsKey('detail')) {
            final detail = responseData['detail'];
            if (detail is String) {
              errorMessage = detail;
            } else if (detail is List) {
              errorMessage = detail.map((e) {
                if (e is Map) {
                  final loc = e['loc'];
                  final msg = e['msg'] ?? e.toString();
                  if (loc is List && loc.isNotEmpty) {
                    final field = loc.last;
                    return '$field: $msg';
                  }
                  return msg.toString();
                }
                return e.toString();
              }).join('\n');
            }
          }
        }

        if (errorMessage.isEmpty) {
          errorMessage = 'A server error occurred.';
        }

        final formattedMessage = statusCode != null
            ? 'HTTP $statusCode\n"$errorMessage"'
            : errorMessage;

        if (statusCode == 401) {
          return ApiFailure(
            message: formattedMessage,
            type: ApiFailureType.unauthorized,
            statusCode: statusCode,
            originalError: exception,
          );
        }

        if (statusCode == 422) {
          return ApiFailure(
            message: formattedMessage,
            type: ApiFailureType.validation,
            statusCode: statusCode,
            originalError: exception,
          );
        }

        if (statusCode != null && statusCode >= 500) {
          return ApiFailure(
            message: formattedMessage,
            type: ApiFailureType.server,
            statusCode: statusCode,
            originalError: exception,
          );
        }

        return ApiFailure(
          message: formattedMessage,
          type: ApiFailureType.unknown,
          statusCode: statusCode,
          originalError: exception,
        );

      case DioExceptionType.cancel:
        final errorMsg = exception.error?.toString();
        return ApiFailure(
          message: errorMsg != null && errorMsg.isNotEmpty ? errorMsg : 'Request was cancelled.',
          type: ApiFailureType.unknown,
          statusCode: statusCode,
          originalError: exception,
        );

      case DioExceptionType.connectionError:
        final messageDetail = 'Browser network/CORS connection failure. Details: ${exception.message} | Error: ${exception.error}';
        // ignore: avoid_print
        print('[JWT_INTERCEPTOR _mapDioException connectionError] $messageDetail');
        return ApiFailure(
          message: messageDetail,
          type: ApiFailureType.network,
          statusCode: statusCode,
          originalError: exception,
        );

      default:
        final messageDetail = 'Unexpected network error occurred. Type: ${exception.type} | Details: ${exception.message} | Error: ${exception.error}';
        // ignore: avoid_print
        print('[JWT_INTERCEPTOR _mapDioException default] $messageDetail');
        return ApiFailure(
          message: messageDetail,
          type: ApiFailureType.network,
          statusCode: statusCode,
          originalError: exception,
        );
    }
  }
}
