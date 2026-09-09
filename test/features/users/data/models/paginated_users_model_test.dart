import 'package:elyx_digital_assignment/features/users/data/models/paginated_users_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fixtures/fixture_reader.dart';

void main() {
  final List<dynamic> body = fixtureList('users_list.json');

  group('fromResponse -- cursor derivation (constraint a)', () {
    test('takes the cursor from the Link header when present', () {
      const String link =
          '<https://api.github.com/users?per_page=10&since=9919>; rel="next", '
          '<https://api.github.com/users{?since}>; rel="first"';

      final PaginatedUsersModel page =
          PaginatedUsersModel.fromResponse(body, linkHeader: link);

      expect(page.users, hasLength(3));
      expect(page.nextSince, 9919);
      expect(page.hasReachedEnd, isFalse);
    });

    test('falls back to the last id when no Link header is sent at all', () {
      final PaginatedUsersModel page = PaginatedUsersModel.fromResponse(body);

      expect(page.nextSince, 9919, reason: 'id of the last item');
      expect(page.hasReachedEnd, isFalse);
    });

    test('a Link header without rel="next" means end of list', () {
      const String link = '<https://api.github.com/users{?since}>; rel="first"';

      final PaginatedUsersModel page =
          PaginatedUsersModel.fromResponse(body, linkHeader: link);

      expect(page.nextSince, isNull);
      expect(page.hasReachedEnd, isTrue,
          reason: 'a header with no next rel is authoritative');
    });

    test('an empty array is the end regardless of headers', () {
      const String link = '<https://api.github.com/users?since=99>; rel="next"';

      final PaginatedUsersModel page = PaginatedUsersModel.fromResponse(
        const <dynamic>[],
        linkHeader: link,
      );

      expect(page.users, isEmpty);
      expect(page.hasReachedEnd, isTrue);
    });

    test('skips malformed entries instead of throwing', () {
      final List<dynamic> mixed = <dynamic>[...body, 'not-an-object', 42];

      expect(PaginatedUsersModel.fromResponse(mixed).users, hasLength(3));
    });
  });

  group('cache round trip', () {
    test('toJson -> fromJson preserves users and cursor', () {
      final PaginatedUsersModel original =
          PaginatedUsersModel.fromResponse(body);

      final PaginatedUsersModel restored =
          PaginatedUsersModel.fromJson(original.toJson());

      expect(restored.nextSince, original.nextSince);
      expect(restored.users, original.users);
      expect(restored, original);
    });

    test('tolerates a corrupt envelope', () {
      final PaginatedUsersModel restored =
          PaginatedUsersModel.fromJson(<String, dynamic>{'users': 'garbage'});

      expect(restored.users, isEmpty);
      expect(restored.hasReachedEnd, isTrue);
    });
  });
}
