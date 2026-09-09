import 'package:elyx_digital_assignment/features/users/data/models/user_summary_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fixtures/fixture_reader.dart';

/// One malformed record must never discard the whole batch, so every field is
/// coerced rather than cast. These tests pin that behaviour against the shapes
/// GitHub actually emits, plus the ones a proxy or an older cache might.
void main() {
  group('fromJson - well-formed', () {
    test('parses a real list element', () {
      final Map<String, dynamic> json =
          (fixtureList('users_list.json').first as Map<String, dynamic>);

      final UserSummaryModel user = UserSummaryModel.fromJson(json);

      expect(user.id, 1);
      expect(user.login, 'mojombo');
      expect(user.type, 'User');
      expect(user.siteAdmin, isFalse);
      expect(user.avatarUrl, contains('avatars.githubusercontent.com'));
    });
  });

  group('fromJson - defensive coercion', () {
    test('an id arriving as a String is still parsed', () {
      final UserSummaryModel user = UserSummaryModel.fromJson(
        <String, dynamic>{'id': '42', 'login': 'mojombo'},
      );
      expect(user.id, 42);
    });

    test('an id arriving as a double is truncated, not thrown', () {
      final UserSummaryModel user = UserSummaryModel.fromJson(
        <String, dynamic>{'id': 42.0, 'login': 'mojombo'},
      );
      expect(user.id, 42);
    });

    test('a null login degrades to empty rather than throwing', () {
      final UserSummaryModel user = UserSummaryModel.fromJson(
        <String, dynamic>{'id': 1, 'login': null},
      );
      expect(user.login, '');
    });

    test('missing string fields degrade to empty', () {
      final UserSummaryModel user =
          UserSummaryModel.fromJson(<String, dynamic>{'id': 1});

      expect(user.login, '');
      expect(user.avatarUrl, '');
      expect(user.htmlUrl, '');
    });

    test('a missing type defaults to User, not empty', () {
      final UserSummaryModel user =
          UserSummaryModel.fromJson(<String, dynamic>{'id': 1});
      expect(user.type, 'User');
    });

    test('site_admin arriving as a String is coerced', () {
      expect(
        UserSummaryModel.fromJson(
          <String, dynamic>{'id': 1, 'site_admin': 'true'},
        ).siteAdmin,
        isTrue,
      );
      expect(
        UserSummaryModel.fromJson(
          <String, dynamic>{'id': 1, 'site_admin': 'false'},
        ).siteAdmin,
        isFalse,
      );
    });

    test('a completely empty object parses without throwing', () {
      expect(
        () => UserSummaryModel.fromJson(const <String, dynamic>{}),
        returnsNormally,
      );
      expect(UserSummaryModel.fromJson(const <String, dynamic>{}).id, 0);
    });

    test('an unparseable id falls back to 0 rather than throwing', () {
      expect(
        UserSummaryModel.fromJson(
          <String, dynamic>{'id': 'not-a-number', 'login': 'x'},
        ).id,
        0,
      );
    });
  });

  group('round trip', () {
    test('toJson -> fromJson is lossless and uses GitHub field names', () {
      final Map<String, dynamic> json =
          (fixtureList('users_list.json').first as Map<String, dynamic>);
      final UserSummaryModel original = UserSummaryModel.fromJson(json);

      final Map<String, dynamic> encoded = original.toJson();
      expect(encoded.keys, contains('avatar_url'));
      expect(encoded.keys, contains('site_admin'));

      expect(UserSummaryModel.fromJson(encoded), original);
    });

    test('fromEntity narrows without losing anything', () {
      final UserSummaryModel original = UserSummaryModel.fromJson(
        (fixtureList('users_list.json').first as Map<String, dynamic>),
      );
      expect(UserSummaryModel.fromEntity(original), original);
    });
  });
}
