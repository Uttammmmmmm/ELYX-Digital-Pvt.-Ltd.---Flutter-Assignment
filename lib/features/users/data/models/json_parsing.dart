/// Defensive JSON coercion helpers shared by the models.
library;

/// Reads [key] as a String, mapping missing/blank/non-string to null.
///
/// GitHub uses `""` and `null` interchangeably for "not provided" (an unset
/// `blog` comes back as an empty string, an unset `bio` as null). Collapsing
/// both to null here means the presentation layer has exactly one "absent"
/// case to render. Constraint (c).
String? asOptionalString(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is! String) return null;
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Reads [key] as a String, falling back to [fallback] when absent.
String asString(
  Map<String, dynamic> json,
  String key, {
  String fallback = '',
}) =>
    asOptionalString(json, key) ?? fallback;

/// Reads [key] as an int, tolerating a numeric string.
int asInt(Map<String, dynamic> json, String key, {int fallback = 0}) {
  final Object? value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

/// Reads [key] as a bool, tolerating `"true"` / `"false"`.
bool asBool(Map<String, dynamic> json, String key, {bool fallback = false}) {
  final Object? value = json[key];
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return fallback;
}

/// Reads [key] as an ISO-8601 timestamp, or null.
DateTime? asOptionalDate(Map<String, dynamic> json, String key) {
  final String? raw = asOptionalString(json, key);
  return raw == null ? null : DateTime.tryParse(raw);
}
