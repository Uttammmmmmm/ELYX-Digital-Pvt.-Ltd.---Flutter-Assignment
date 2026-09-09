/// Safe helpers for reading Dio response headers.
///
/// Exists because `Headers.value(name)` *throws* when a header appears more
/// than once, which would turn a diagnostic header into a crash. Everything
/// here degrades to null instead.
library;

import 'package:dio/dio.dart';

import '../constants/api_constants.dart';

/// Returns the first value of [name], or null. Lookup is case-insensitive.
String? readHeader(Headers? headers, String name) {
  final List<String>? values = headers?[name];
  if (values == null || values.isEmpty) return null;
  final String v = values.first.trim();
  return v.isEmpty ? null : v;
}

/// Returns [name] parsed as an int, or null when absent or unparseable.
int? readIntHeader(Headers? headers, String name) =>
    int.tryParse(readHeader(headers, name) ?? '');

/// True when GitHub reports zero requests left in the current window.
///
/// Returns false when the header is absent -- we never *assume* exhaustion,
/// since a plain 403 (e.g. a blocked user) is a different problem.
bool isRateLimitExhausted(Headers? headers) =>
    readIntHeader(headers, ApiConstants.headerRateLimitRemaining) == 0;

/// Resolves when the rate-limit window reopens.
///
/// Prefers `x-ratelimit-reset` (absolute unix *seconds*), falls back to
/// `retry-after` (relative seconds, used by secondary/abuse limits), and
/// finally assumes a full hour -- the primary window length.
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

/// True when the response carries `retry-after`, which marks a secondary
/// (abuse) rate limit rather than the primary hourly quota.
bool isSecondaryRateLimit(Headers? headers) =>
    readHeader(headers, ApiConstants.headerRetryAfter) != null;
