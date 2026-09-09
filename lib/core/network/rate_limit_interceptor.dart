/// Dio interceptor that observes and enforces GitHub's rate limit.
library;

import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../error/exceptions.dart';
import 'header_reader.dart';
import 'rate_limit_tracker.dart';

/// Records `x-ratelimit-*` on every response and converts an exhausted
/// 403/429 into a [RateLimitException].
///
/// Two responsibilities, deliberately together because they read the same
/// headers:
///  1. Observation -- update [RateLimitTracker] on success *and* failure, so
///     the UI can warn at "3 requests left" instead of only at zero.
///  2. Classification -- reject with a [RateLimitException] carrying `resetAt`
///     so the repository can produce a distinct failure. Constraint (d).
class RateLimitInterceptor extends Interceptor {
  RateLimitInterceptor(this._tracker, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final RateLimitTracker _tracker;

  /// Injectable clock; keeps reset-time assertions deterministic in tests.
  final DateTime Function() _now;

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _record(response.headers);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final Headers? headers = err.response?.headers;
    _record(headers);

    final int? status = err.response?.statusCode;
    final bool isRateLimitStatus = status == 403 || status == 429;

    // A 403 is only a rate limit when `x-ratelimit-remaining` is 0; otherwise
    // it is an ordinary "forbidden" and must not be mislabelled.
    if (isRateLimitStatus && isRateLimitExhausted(headers)) {
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          response: err.response,
          type: DioExceptionType.badResponse,
          // Carried in `error` so `mapDioException` passes it through intact.
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

  /// Stores the latest budget, ignoring responses that carry no rate headers.
  void _record(Headers? headers) {
    final int? remaining = readIntHeader(
      headers,
      ApiConstants.headerRateLimitRemaining,
    );
    if (remaining == null) return;

    _tracker.update(
      RateLimitSnapshot(
        remaining: remaining,
        limit:
            readIntHeader(headers, ApiConstants.headerRateLimitLimit) ??
            (ApiConstants.hasToken ? 5000 : 60),
        resetAt: rateLimitResetAt(headers, now: _now()),
        observedAt: _now(),
      ),
    );
  }
}
