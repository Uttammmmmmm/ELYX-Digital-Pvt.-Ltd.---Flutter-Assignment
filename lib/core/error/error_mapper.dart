library;

import 'package:dio/dio.dart';

import '../network/header_reader.dart';
import 'exceptions.dart';

AppException mapDioException(DioException error) {
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

AppException _mapBadResponse(DioException error) {
  final Response<dynamic>? response = error.response;
  final int? status = response?.statusCode;
  final Headers? headers = response?.headers;

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

  return ServerException('Unexpected response from GitHub', statusCode: status);
}
