enum ApiFailureType {
  network,
  unauthorized,
  validation,
  server,
  unknown,
}

class ApiFailure {
  final String message;
  final int? statusCode;
  final ApiFailureType type;
  final dynamic originalError;

  const ApiFailure({
    required this.message,
    required this.type,
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() {
    return 'ApiFailure(message: $message, type: $type, statusCode: $statusCode)';
  }
}
