import 'package:elyx_digital_assignment/features/users/data/models/users_page_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fixtures/fixture_reader.dart';

void main() {
  final List<dynamic> body = fixtureList('users_list.json');

  group('UsersPageModel.fromResponse -- cursor derivation (constraint a)', () {
    test('takes the cursor from the Link header when present', () {
      const String link =
          '<https://api.github.com/users?per_page=10&since=9919>; rel="next", '
          '<https://api.github.com/users{?since}>; rel="first"';

      final UsersPageModel page =
          UsersPageModel.fromResponse(body, linkHeader: link);

      expect(page.users, hasLength(3));
      expect(page.nextCursor, 9919);
      expect(page.hasReachedEnd, isFalse);
    });

    test('falls back to the last id when no Link header is sent at all', () {
      final UsersPageModel page = UsersPageModel.fromResponse(body);

      expect(page.nextCursor, 9919, reason: 'id of the last item');
      expect(page.hasReachedEnd, isFalse);
    });

    test('a Link header without rel="next" means end of list', () {
      const String link = '<https://api.github.com/users{?since}>; rel="first"';

      final UsersPageModel page =
          UsersPageModel.fromResponse(body, linkHeader: link);

      expect(page.nextCursor, isNull);
      expect(page.hasReachedEnd, isTrue,
          reason: 'header present but no next rel is authoritative');
    });

    test('an empty array is the end regardless of headers', () {
      const String link =
          '<https://api.github.com/users?since=99>; rel="next"';

      final UsersPageModel page =
          UsersPageModel.fromResponse(const <dynamic>[], linkHeader: link);

      expect(page.users, isEmpty);
      expect(page.hasReachedEnd, isTrue);
    });

    test('skips malformed entries instead of throwing', () {
      final List<dynamic> mixed = <dynamic>[...body, 'not-an-object', 42];

      final UsersPageModel page = UsersPageModel.fromResponse(mixed);

      expect(page.users, hasLength(3));
    });
  });

  group('UsersPageModel cache round trip', () {
    test('toJson -> fromJson preserves users and cursor', () {
      final UsersPageModel original =
          UsersPageModel.fromResponse(body, linkHeader: null);

      final UsersPageModel restored =
          UsersPageModel.fromJson(original.toJson());

      expect(restored.nextCursor, original.nextCursor);
      expect(restored.users, original.users);
      expect(restored, original);
    });

    test('tolerates a corrupt envelope', () {
      final UsersPageModel restored =
          UsersPageModel.fromJson(<String, dynamic>{'users': 'garbage'});

      expect(restored.users, isEmpty);
      expect(restored.hasReachedEnd, isTrue);
    });
  });
}
