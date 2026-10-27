import 'failure.dart';

sealed class AppException implements Exception {
  const AppException(this.message, {this.details});

  final String message;
  final Object? details;

  String get code;

  Failure toFailure() =>
      Failure(code: code, message: message, details: details);

  /// Surfaces the message instead of the default `Instance of 'X'`, which is
  /// what any `error.toString()` in the UI would otherwise print.
  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.details});
  @override
  String get code => 'network';
}

class RequestTimeoutException extends AppException {
  const RequestTimeoutException(super.message, {super.details});
  @override
  String get code => 'timeout';
}

class ProviderUnavailableException extends AppException {
  const ProviderUnavailableException(super.message, {super.details});
  @override
  String get code => 'provider_unavailable';
}

class BadResponseException extends AppException {
  const BadResponseException(super.message, {super.details});
  @override
  String get code => 'bad_response';
}

class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.details});
  @override
  String get code => 'database';
}
