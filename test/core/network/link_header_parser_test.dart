import 'package:elyx_digital_assignment/core/network/link_header_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const LinkHeaderParser parser = LinkHeaderParser();

  group('LinkHeaderParser.nextSince', () {
    test('extracts the since cursor from a real GitHub header', () {
      const String header =
          '<https://api.github.com/users?per_page=10&since=46>; rel="next", '
          '<https://api.github.com/users{?since}>; rel="first"';
      expect(parser.nextSince(header), 46);
    });

    test('returns null when the header is absent or blank', () {
      expect(parser.nextSince(null), isNull);
      expect(parser.nextSince('   '), isNull);
    });

    test('returns null on the last page (only rel="first"/"prev")', () {
      const String header =
          '<https://api.github.com/users{?since}>; rel="first", '
          '<https://api.github.com/users?since=30>; rel="prev"';
      expect(parser.nextSince(header), isNull);
    });

    test('handles unquoted rel and extra params', () {
      const String header =
          '<https://api.github.com/users?since=99>; type=text/html; rel=next';
      expect(parser.nextSince(header), 99);
    });

    test('percent-decodes the cursor value', () {
      const String header =
          '<https://api.github.com/users?since=%31%32%33>; rel="next"';
      expect(parser.nextSince(header), 123);
    });

    test('is not confused by commas inside the URL', () {
      const String header =
          '<https://api.github.com/users?q=a,b&since=7>; rel="next", '
          '<https://api.github.com/users>; rel="first"';
      expect(parser.nextSince(header), 7);
    });

    test('degrades to null on a malformed header instead of throwing', () {
      expect(() => parser.nextSince('garbage;;;'), returnsNormally);
      expect(parser.nextSince('garbage;;;'), isNull);
    });

    test('templated next url without a real cursor yields null', () {
      const String header = '<https://api.github.com/users{?since}>; rel="next"';
      expect(parser.nextSince(header), isNull);
    });
  });
}
