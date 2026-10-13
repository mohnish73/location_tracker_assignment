/// Every MethodChannel call resolves to exactly one of these, never an uncaught exception.
sealed class ChannelResult<T> {
  const ChannelResult();
}

final class ChannelSuccess<T> extends ChannelResult<T> {
  const ChannelSuccess(this.data);
  final T data;
}

final class ChannelFailure<T> extends ChannelResult<T> {
  const ChannelFailure(this.error);
  final NativeError error;
}

/// Structured error built from Kotlin's `result.error(code, message, details)`.
class NativeError {
  const NativeError({required this.code, required this.message, this.details});

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => 'NativeError($code): $message';
}

/// Error codes produced by the Kotlin side (see ChannelContract.Errors) plus Dart-side ones.
abstract final class NativeErrorCode {
  static const permissionDenied = 'PERMISSION_DENIED';
  static const locationDisabled = 'LOCATION_DISABLED';
  static const invalidArgument = 'INVALID_ARGUMENT';
  static const databaseError = 'DATABASE_ERROR';
  static const serviceError = 'SERVICE_ERROR';
  static const exportFailed = 'EXPORT_FAILED';
  static const requestInProgress = 'REQUEST_IN_PROGRESS';
  static const settingsUnavailable = 'SETTINGS_UNAVAILABLE';
  static const unexpected = 'UNEXPECTED';

  /// Dart side: the method is not registered on the platform.
  static const notImplemented = 'NOT_IMPLEMENTED';

  /// Dart side: the platform replied with data in an unexpected shape.
  static const invalidResponse = 'INVALID_RESPONSE';
}
