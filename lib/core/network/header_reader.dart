library;

import 'package:dio/dio.dart';

import '../constants/api_constants.dart';

String? readHeader(Headers? headers, String name) {
  final List<String>? values = headers?[name];
  if (values == null || values.isEmpty) return null;
  final String v = values.first.trim();
  return v.isEmpty ? null : v;
}

int? readIntHeader(Headers? headers, String name) =>
    int.tryParse(readHeader(headers, name) ?? '');

bool isRateLimitExhausted(Headers? headers) =>
    readIntHeader(headers, ApiConstants.headerRateLimitRemaining) == 0;

DateTime rateLimitResetAt(Headers? headers, {DateTime? now}) {
  final DateTime base = now ?? DateTime.now();

  final int? resetEpoch = readIntHeader(
    headers,
    ApiConstants.headerRateLimitReset,
  );
  if (resetEpoch != null) {
    return DateTime.fromMillisecondsSinceEpoch(resetEpoch * 1000);
  }

  final int? retryAfter = readIntHeader(headers, ApiConstants.headerRetryAfter);
  if (retryAfter != null) {
    return base.add(Duration(seconds: retryAfter));
  }

  return base.add(const Duration(hours: 1));
}

bool isSecondaryRateLimit(Headers? headers) =>
    readHeader(headers, ApiConstants.headerRetryAfter) != null;
