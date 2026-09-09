library;

import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../error/exceptions.dart';
import 'header_reader.dart';
import 'rate_limit_tracker.dart';

class RateLimitInterceptor extends Interceptor {
  RateLimitInterceptor(this._tracker, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final RateLimitTracker _tracker;

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
