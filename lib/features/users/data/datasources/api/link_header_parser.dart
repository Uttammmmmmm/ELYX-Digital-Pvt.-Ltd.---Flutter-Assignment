library;

class LinkHeaderParser {
  const LinkHeaderParser();

  static final RegExp _entry = RegExp(r'<([^>]*)>\s*;\s*([^,]*)');

  static final RegExp _rel = RegExp(
    r'''rel\s*=\s*(?:"([^"]*)"|'([^']*)'|([^;,\s]+))''',
    caseSensitive: false,
  );

  Map<String, String> parse(String? header) {
    if (header == null || header.trim().isEmpty) {
      return const <String, String>{};
    }

    final Map<String, String> links = <String, String>{};
    for (final RegExpMatch m in _entry.allMatches(header)) {
      final String url = (m.group(1) ?? '').trim();
      final String params = m.group(2) ?? '';
      if (url.isEmpty) continue;

      final RegExpMatch? rel = _rel.firstMatch(params);
      if (rel == null) continue;

      final String? name = (rel.group(1) ?? rel.group(2) ?? rel.group(3))
          ?.trim()
          .toLowerCase();

      if (name == null || name.isEmpty) continue;
      for (final String part in name.split(RegExp(r'\s+'))) {
        links.putIfAbsent(part, () => url);
      }
    }
    return links;
  }

  String? nextUrl(String? header) => parse(header)['next'];

  int? nextSince(String? header) {
    final String? url = nextUrl(header);
    if (url == null) return null;

    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return null;

    final String? raw = uri.queryParameters['since'];
    if (raw == null) return null;

    return int.tryParse(raw.trim());
  }
}
