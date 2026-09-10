library;

import 'package:dio/dio.dart';

import '../error/exceptions.dart';
import 'header_reader.dart';

/// Turns the API's "you are rate limited" responses into a typed
/// [RateLimitException] carrying the reset time.
///
/// A 403/429 is only a rate limit when the remaining-requests header says so;
/// otherwise it is an ordinary refusal and is left for the error mapper to
/// classify.
class RateLimitInterceptor extends Interceptor {
  RateLimitInterceptor({DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final DateTime Function() _now;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final Headers? headers = err.response?.headers;

    final int? status = err.response?.statusCode;
    final bool isRateLimitStatus = status == 403 || status == 429;

    if (isRateLimitStatus && isRateLimitExhausted(headers)) {
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          response: err.response,
          type: DioExceptionType.badResponse,

          error: RateLimitException(
            resetAt: rateLimitResetAt(headers, now: _now()),
            isSecondary: isSecondaryRateLimit(headers),
            statusCode: status,
          ),
        ),
      );
      return;
    }

    handler.next(err);
  }
}
