import 'api_failure.dart';

sealed class ApiResult<T> {
  const ApiResult();

  const factory ApiResult.success(T data) = Success<T>;
  const factory ApiResult.failure(ApiFailure failure) = Failure<T>;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  R when<R>({
    required R Function(T data) onSuccess,
    required R Function(ApiFailure failure) onFailure,
  }) {
    switch (this) {
      case Success<T>(:final data):
        return onSuccess(data);
      case Failure<T>(:final failure):
        return onFailure(failure);
    }
  }

  T? get dataOrNull => this is Success<T> ? (this as Success<T>).data : null;
  ApiFailure? get failureOrNull =>
      this is Failure<T> ? (this as Failure<T>).failure : null;
}

class Success<T> extends ApiResult<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends ApiResult<T> {
  final ApiFailure failure;
  const Failure(this.failure);
}
