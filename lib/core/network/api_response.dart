library;

class ApiResponse<T> {
  const ApiResponse({
    required this.data,
    required this.statusCode,
    required Map<String, List<String>> headers,
  }) : _headers = headers;

  final T? data;

  final int statusCode;

  final Map<String, List<String>> _headers;

  String? header(String name) {
    final String key = name.toLowerCase();
    final List<String>? values = _headers[key];
    if (values == null || values.isEmpty) return null;
    final String v = values.first.trim();
    return v.isEmpty ? null : v;
  }
}
