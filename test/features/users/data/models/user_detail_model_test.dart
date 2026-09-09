import 'package:elyx_digital_assignment/features/users/data/models/user_detail_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fixtures/fixture_reader.dart';

void main() {
  group('UserDetailModel.fromJson', () {
    test('parses a full profile', () {
      final UserDetailModel detail =
          UserDetailModel.fromJson(fixtureMap('user_detail.json'));

      expect(detail.login, 'mojombo');
      expect(detail.id, 1);
      expect(detail.name, 'Tom Preston-Werner');
      expect(detail.location, 'San Francisco');
      expect(detail.publicRepos, 66);
      expect(detail.followers, 23000);
      expect(detail.createdAt, DateTime.utc(2007, 10, 20, 5, 24, 19));
    });

    test('keeps genuinely-absent fields null -- no invented fallbacks '
        '(constraint c)', () {
      final UserDetailModel detail =
          UserDetailModel.fromJson(fixtureMap('user_detail.json'));

      expect(detail.email, isNull, reason: 'email is null for most users');
      expect(detail.bio, isNull);
      expect(detail.company, isNull);
    });

    test('collapses empty and whitespace strings to null', () {
      final UserDetailModel detail =
          UserDetailModel.fromJson(fixtureMap('user_detail_sparse.json'));

      expect(detail.name, isNull);
      expect(detail.company, isNull, reason: '"" means not provided');
      expect(detail.blog, isNull);
      expect(detail.location, isNull, reason: 'whitespace-only means absent');
      // createdAt is non-nullable on the entity, so a missing timestamp
      // falls back to an obviously-wrong epoch sentinel rather than
      // DateTime.now(), which would read as a real brand-new account.
      expect(detail.createdAt, DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
    });

    test('survives a response missing every optional key', () {
      final UserDetailModel detail = UserDetailModel.fromJson(
        <String, dynamic>{'login': 'octocat', 'id': 583231},
      );

      expect(detail.login, 'octocat');
      expect(detail.publicRepos, 0);
      expect(detail.followers, 0);
      expect(detail.name, isNull);
    });

    test('cache round trip is lossless', () {
      final UserDetailModel original =
          UserDetailModel.fromJson(fixtureMap('user_detail.json'));

      final UserDetailModel restored =
          UserDetailModel.fromJson(original.toJson());

      expect(restored, original);
    });
  });
}
