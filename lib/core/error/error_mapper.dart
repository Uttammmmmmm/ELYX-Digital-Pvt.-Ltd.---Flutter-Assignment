/// The single translation point from Dio's transport errors to [AppException].
///
/// BOUNDARY NOTE: this is one of only two places outside `core/network` that
/// may import `package:dio` (see the architecture test). It sits in `core/error`
/// because it *produces* the error vocabulary; if you want a stricter rule,
/// move this file to `core/network/` and the allowlist shrinks to one entry.
library;

import 'package:dio/dio.dart';

import '../network/header_reader.dart';
import 'exceptions.dart';

/// Converts a [DioException] into the appropriate [AppException].
///
/// Ordering matters: an exception already classified by an interceptor (the
/// rate-limit interceptor rejects with `error: RateLimitException`) is passed
/// straight through, so the richer diagnosis is never downgraded here.
AppException mapDioException(DioException error) {
  // Already classified upstream -- do not re-derive.
  final Object? inner = error.error;
  if (inner is AppException) return inner;

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
      return const TimeoutException('Connection timed out');
    case DioExceptionType.sendTimeout:
      return const TimeoutException('Sending the request timed out');
    case DioExceptionType.receiveTimeout:
      return const TimeoutException('Waiting for the response timed out');
    case DioExceptionType.transformTimeout:
      return const TimeoutException('Decoding the response timed out');

    case DioExceptionType.connectionError:
      return const NetworkException('Could not reach api.github.com');

    case DioExceptionType.badCertificate:
      return const ServerException('The server certificate was rejected');

    case DioExceptionType.cancel:
      // A cancellation is our own doing (widget disposed, query superseded).
      // It is surfaced as an exception so callers can drop it silently rather
      // than render it.
      return const ServerException('Request cancelled');

    case DioExceptionType.badResponse:
      return _mapBadResponse(error);

    case DioExceptionType.unknown:
      return ServerException(
        error.message ?? 'Unexpected error',
        statusCode: error.response?.statusCode,
      );
  }
}

/// Splits a non-2xx response by status code.
AppException _mapBadResponse(DioException error) {
  final Response<dynamic>? response = error.response;
  final int? status = response?.statusCode;
  final Headers? headers = response?.headers;

  // 403 and 429 are both used for rate limiting. The status alone is NOT
  // enough: a plain 403 also means "forbidden". `x-ratelimit-remaining: 0`
  // is the discriminator. Constraint (d).
  if (status == 403 || status == 429) {
    if (isRateLimitExhausted(headers)) {
      return RateLimitException(
        resetAt: rateLimitResetAt(headers),
        isSecondary: isSecondaryRateLimit(headers),
        statusCode: status,
      );
    }
    return ServerException(
      'Forbidden by GitHub (not a rate limit)',
      statusCode: status,
    );
  }

  if (status == 404) return const NotFoundException();

  if (status == 401) {
    return const ServerException(
      'GitHub rejected the access token',
      statusCode: 401,
    );
  }

  if (status != null && status >= 500) {
    return ServerException('GitHub server error', statusCode: status);
  }

  return ServerException(
    'Unexpected response from GitHub',
    statusCode: status,
  );
}
