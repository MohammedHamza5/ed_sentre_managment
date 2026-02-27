/// Result type for error handling
/// استخدام نمط Result بدلاً من الاستثناءات
sealed class Result<T> {
  const Result();
}

/// Success result with data
class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

/// Failure result with error
class Failure<T> extends Result<T> {
  final String message;
  final Exception? exception;
  final StackTrace? stackTrace;
  
  const Failure(
    this.message, {
    this.exception,
    this.stackTrace,
  });
}

/// Extension methods for Result
extension ResultExtension<T> on Result<T> {
  /// Check if result is success
  bool get isSuccess => this is Success<T>;
  
  /// Check if result is failure
  bool get isFailure => this is Failure<T>;
  
  /// Get data if success, otherwise return null
  T? get dataOrNull {
    if (this is Success<T>) {
      return (this as Success<T>).data;
    }
    return null;
  }
  
  /// Get error message if failure, otherwise return null
  String? get errorOrNull {
    if (this is Failure<T>) {
      return (this as Failure<T>).message;
    }
    return null;
  }
  
  /// Map the data if success
  Result<R> map<R>(R Function(T data) mapper) {
    if (this is Success<T>) {
      try {
        return Success(mapper((this as Success<T>).data));
      } catch (e, stack) {
        return Failure(
          'Mapping failed: $e',
          exception: e is Exception ? e : Exception(e.toString()),
          stackTrace: stack,
        );
      }
    }
    return Failure(
      (this as Failure<T>).message,
      exception: (this as Failure<T>).exception,
      stackTrace: (this as Failure<T>).stackTrace,
    );
  }
  
  /// Execute an action based on result type
  R when<R>({
    required R Function(T data) success,
    required R Function(String message) failure,
  }) {
    if (this is Success<T>) {
      return success((this as Success<T>).data);
    }
    return failure((this as Failure<T>).message);
  }
  
  /// Execute an action only if success
  void ifSuccess(void Function(T data) action) {
    if (this is Success<T>) {
      action((this as Success<T>).data);
    }
  }
  
  /// Execute an action only if failure
  void ifFailure(void Function(String message) action) {
    if (this is Failure<T>) {
      action((this as Failure<T>).message);
    }
  }
}


