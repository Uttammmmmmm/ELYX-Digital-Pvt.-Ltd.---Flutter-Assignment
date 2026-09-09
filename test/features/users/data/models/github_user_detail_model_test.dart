import 'package:elyx_digital_assignment/features/users/data/models/github_user_detail_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fixtures/fixture_reader.dart';

void main() {
  group('GithubUserDetailModel.fromJson', () {
    test('parses a full profile', () {
      final GithubUserDetailModel detail =
          GithubUserDetailModel.fromJson(fixtureMap('user_detail.json'));

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
      final GithubUserDetailModel detail =
          GithubUserDetailModel.fromJson(fixtureMap('user_detail.json'));

      expect(detail.email, isNull, reason: 'email is null for most users');
      expect(detail.bio, isNull);
      expect(detail.company, isNull);
    });

    test('collapses empty and whitespace strings to null', () {
      final GithubUserDetailModel detail =
          GithubUserDetailModel.fromJson(fixtureMap('user_detail_sparse.json'));

      expect(detail.name, isNull);
      expect(detail.company, isNull, reason: '"" means not provided');
      expect(detail.blog, isNull);
      expect(detail.location, isNull, reason: 'whitespace-only means absent');
      expect(detail.createdAt, isNull);
    });

    test('survives a response missing every optional key', () {
      final GithubUserDetailModel detail = GithubUserDetailModel.fromJson(
        <String, dynamic>{'login': 'octocat', 'id': 583231},
      );

      expect(detail.login, 'octocat');
      expect(detail.publicRepos, 0);
      expect(detail.followers, 0);
      expect(detail.name, isNull);
    });

    test('cache round trip is lossless', () {
      final GithubUserDetailModel original =
          GithubUserDetailModel.fromJson(fixtureMap('user_detail.json'));

      final GithubUserDetailModel restored =
          GithubUserDetailModel.fromJson(original.toJson());

      expect(restored, original);
    });
  });
}
