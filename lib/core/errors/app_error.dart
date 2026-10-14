/// Result type for safe functional error handling in Tahrir.
sealed class Result<T> {
  const Result();

  const factory Result.success(T data) = Success<T>;
  const factory Result.failure(AppError error) = Failure<T>;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get dataOrNull => switch (this) {
        Success<T>(data: final data) => data,
        Failure<T>() => null,
      };

  AppError? get errorOrNull => switch (this) {
        Success<T>() => null,
        Failure<T>(error: final error) => error,
      };

  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(AppError error) onFailure,
  }) {
    return switch (this) {
      Success<T>(data: final data) => onSuccess(data),
      Failure<T>(error: final error) => onFailure(error),
    };
  }
}

final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

final class Failure<T> extends Result<T> {
  final AppError error;
  const Failure(this.error);
}

/// Standard AppError hierarchy
sealed class AppError {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const AppError(this.message, {this.cause, this.stackTrace});

  @override
  String toString() => '$runtimeType: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

final class StorageError extends AppError {
  const StorageError(super.message, {super.cause, super.stackTrace});
}

final class ParsingError extends AppError {
  const ParsingError(super.message, {super.cause, super.stackTrace});
}

final class MediaError extends AppError {
  const MediaError(super.message, {super.cause, super.stackTrace});
}

final class NotFoundError extends AppError {
  const NotFoundError(super.message, {super.cause, super.stackTrace});
}

final class GeneralError extends AppError {
  const GeneralError(super.message, {super.cause, super.stackTrace});
}
