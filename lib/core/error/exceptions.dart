library;

sealed class AppException implements Exception {
  const AppException(this.message, {this.statusCode});

  final String message;

  final int? statusCode;

  @override
  String toString() => '$runtimeType($statusCode): $message';
}

final class ServerException extends AppException {
  const ServerException(super.message, {super.statusCode});
}

final class NetworkException extends AppException {
  const NetworkException([super.message = 'No network connection']);
}

final class TimeoutException extends AppException {
  const TimeoutException([super.message = 'The request timed out']);
}

final class RateLimitException extends AppException {
  const RateLimitException({
    required this.resetAt,
    this.isSecondary = false,
    int? statusCode,
    String message = 'API rate limit exceeded',
  }) : super(message, statusCode: statusCode);

  final DateTime resetAt;

  final bool isSecondary;

  Duration remainingFrom(DateTime now) {
    final Duration d = resetAt.difference(now);
    return d.isNegative ? Duration.zero : d;
  }
}

final class NotFoundException extends AppException {
  // ignore: use_super_parameters
  const NotFoundException([String message = 'Resource not found'])
    : super(message, statusCode: 404);
}

final class CacheException extends AppException {
  const CacheException([super.message = 'Cache read/write failed']);
}
