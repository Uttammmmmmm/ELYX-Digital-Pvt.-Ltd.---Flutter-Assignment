/// RFC 5988 `Link` header parsing for GitHub's cursor pagination.
library;

import '../constants/api_constants.dart';

/// Extracts pagination cursors from GitHub's `Link` response header.
///
/// The real header looks exactly like this (one line, comma-separated):
///
/// ```
/// Link: <https://api.github.com/users?per_page=10&since=46>; rel="next",
///       <https://api.github.com/users{?since}>; rel="first"
/// ```
///
/// This is authoritative for "is there a next page" -- preferring it over
/// "the array came back empty" saves one whole request per exhausted list,
/// which matters at 60 requests/hour. Constraint (a).
abstract final class LinkHeaderParser {
  /// Matches one `<url>; rel="name"` entry. `[^>]+` keeps commas inside the
  /// URL from splitting entries, which a naive `split(',')` gets wrong.
  static final RegExp _entry = RegExp(r'<([^>]*)>\s*;\s*([^,]*)');

  /// Matches `rel=next` or `rel="next"`, case-insensitively.
  static final RegExp _rel = RegExp(
    r'''rel\s*=\s*(?:"([^"]*)"|'([^']*)'|([^;,\s]+))''',
    caseSensitive: false,
  );

  /// Returns a `rel -> url` map. Empty when [header] is null, blank or
  /// unparseable -- a malformed header degrades to "no more pages", never
  /// to an exception.
  static Map<String, String> parse(String? header) {
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

      final String? name =
          (rel.group(1) ?? rel.group(2) ?? rel.group(3))?.trim().toLowerCase();
      // A rel may legally hold several space-separated names; index them all.
      if (name == null || name.isEmpty) continue;
      for (final String part in name.split(RegExp(r'\s+'))) {
        links.putIfAbsent(part, () => url);
      }
    }
    return links;
  }

  /// The absolute URL of the next page, or null at the end of the list.
  static String? nextUrl(String? header) => parse(header)['next'];

  /// The `since` cursor from the `rel="next"` URL, or null when there is no
  /// next page.
  ///
  /// [Uri.queryParameters] percent-decodes for us, so `since=46%32` and
  /// templated URLs (`{?since}`, which carry no real value) both behave.
  static int? nextSince(String? header) {
    final String? url = nextUrl(header);
    if (url == null) return null;

    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return null;

    final String? raw = uri.queryParameters[ApiConstants.paramSince];
    if (raw == null) return null;

    return int.tryParse(raw.trim());
  }
}
