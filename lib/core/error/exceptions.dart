/// Data-layer exceptions.
///
/// These are *thrown* by data sources and the networking stack. They are
/// deliberately transport-flavoured (status codes, reset timestamps) and never
/// escape the data layer -- repositories catch them and return [Failure]s.
library;

/// Base type for every exception raised inside the data layer.
///
/// `sealed` so repository mapping can switch exhaustively: adding a new
/// exception becomes a compile error at every mapping site rather than a
/// silently-unhandled case at runtime.
sealed class AppException implements Exception {
  const AppException(this.message, {this.statusCode});

  /// Technical description, for logs. Not shown to users verbatim.
  final String message;

  /// HTTP status when the failure originated from a response.
  final int? statusCode;

  @override
  String toString() => '$runtimeType($statusCode): $message';
}

/// A non-2xx response that is not covered by a more specific exception
/// (typically 5xx, or an unexpected 4xx).
final class ServerException extends AppException {
  const ServerException(super.message, {super.statusCode});
}

/// The request never reached the server: DNS failure, no route, socket error.
final class NetworkException extends AppException {
  const NetworkException([super.message = 'No network connection']);
}

/// A connect, send or receive timeout elapsed.
///
/// NOTE: this shadows `dart:async`'s [TimeoutException]. Any library importing
/// both must prefix one of them; nothing in this project imports `dart:async`
/// alongside this file.
final class TimeoutException extends AppException {
  const TimeoutException([super.message = 'The request timed out']);
}

/// The GitHub rate limit is exhausted. Carries when access returns.
///
/// Constraint (d): must reach the UI as its own state, not a generic error.
final class RateLimitException extends AppException {
  const RateLimitException({
    required this.resetAt,
    this.isSecondary = false,
    int? statusCode,
    String message = 'GitHub API rate limit exceeded',
  }) : super(message, statusCode: statusCode);

  /// Wall-clock time at which the quota is restored.
  final DateTime resetAt;

  /// True for secondary (abuse) rate limits, which use `retry-after` and are
  /// usually much shorter than the primary hourly window.
  final bool isSecondary;

  /// Time left until the window resets; never negative.
  Duration remainingFrom(DateTime now) {
    final Duration d = resetAt.difference(now);
    return d.isNegative ? Duration.zero : d;
  }
}

/// 404 -- the requested resource does not exist (e.g. a deleted user login).
final class NotFoundException extends AppException {
  // A super formal parameter cannot be combined with the explicit `super(...)`
  // call needed to pin statusCode to 404.
  // ignore: use_super_parameters
  const NotFoundException([String message = 'Resource not found'])
      : super(message, statusCode: 404);
}

/// Local persistence failed, or the cache was empty when it was required.
final class CacheException extends AppException {
  const CacheException([super.message = 'Cache read/write failed']);
}
