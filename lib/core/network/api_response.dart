/// Transport-agnostic response envelope.
library;

/// A response body plus the headers callers still need, with no Dio types.
///
/// The data layer must read the `Link` header to derive the pagination cursor,
/// which is why a bare `T` is not enough. Returning our own envelope instead of
/// Dio's `Response<T>` is what keeps `package:dio` from leaking past
/// `core/network` -- see the boundary note in `DioClient`.
class ApiResponse<T> {
  const ApiResponse({
    required this.data,
    required this.statusCode,
    required Map<String, List<String>> headers,
  }) : _headers = headers;

  /// Decoded body. Null for empty responses.
  final T? data;

  /// HTTP status of the response.
  final int statusCode;

  final Map<String, List<String>> _headers;

  /// First value of [name], case-insensitively; null when absent.
  String? header(String name) {
    final String key = name.toLowerCase();
    final List<String>? values = _headers[key];
    if (values == null || values.isEmpty) return null;
    final String v = values.first.trim();
    return v.isEmpty ? null : v;
  }
}
