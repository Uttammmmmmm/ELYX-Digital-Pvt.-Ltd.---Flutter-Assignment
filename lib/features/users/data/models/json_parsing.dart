library;

String? asOptionalString(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is! String) return null;
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String asString(
  Map<String, dynamic> json,
  String key, {
  String fallback = '',
}) => asOptionalString(json, key) ?? fallback;

int asInt(Map<String, dynamic> json, String key, {int fallback = 0}) {
  final Object? value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

DateTime? asOptionalDate(Map<String, dynamic> json, String key) {
  final String? raw = asOptionalString(json, key);
  return raw == null ? null : DateTime.tryParse(raw);
}
