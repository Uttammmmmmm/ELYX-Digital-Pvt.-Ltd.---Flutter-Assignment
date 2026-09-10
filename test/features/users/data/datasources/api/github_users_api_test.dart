import 'package:dio/dio.dart';
import 'package:elyx_digital_assignment/core/error/exceptions.dart';
import 'package:elyx_digital_assignment/core/network/dio_client.dart';
import 'package:elyx_digital_assignment/features/users/data/datasources/api/github_users_api.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/paginated_users.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_detail.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../fixtures/fixture_reader.dart';
import '../../../../../helpers/fake_http_adapter.dart';

void main() {
  ({GitHubUsersApi api, FakeHttpAdapter adapter}) build(
    FakeReply Function(RequestOptions options) reply,
  ) {
    final FakeHttpAdapter adapter = FakeHttpAdapter(reply);
    final Dio dio = Dio()..httpClientAdapter = adapter;
    return (
      api: GitHubUsersApi(
        client: DioClient(
          baseUrl: 'https://api.github.com',
          headers: const <String, String>{'User-Agent': 'test'},
          dio: dio,
        ),
      ),
      adapter: adapter,
    );
  }

  FakeReply users(RequestOptions _) =>
      FakeReply(statusCode: 200, body: fixture('users_list.json'));

  group('cursor pagination', () {
    test('omits since ENTIRELY on the first request', () async {
      final harness = build(users);

      await harness.api.fetchUsers(perPage: 10);

      final RequestOptions r = harness.adapter.requests.single;
      expect(r.queryParameters['per_page'], 10);
      expect(
        r.queryParameters.containsKey('since'),
        isFalse,
        reason: 'since=0 is a real cursor, not "from the beginning"',
      );
      expect(
        r.queryParameters.containsKey('page'),
        isFalse,
        reason: 'page is silently ignored by this endpoint',
      );
    });

    test('sends the cursor as since', () async {
      final harness = build(users);

      await harness.api.fetchUsers(cursor: 46);

      expect(harness.adapter.requests.single.queryParameters['since'], 46);
    });

    test('derives the next cursor from the Link header', () async {
      final harness = build(
        (_) => FakeReply(
          statusCode: 200,
          body: fixture('users_list.json'),
          headers: <String, List<String>>{
            'link': <String>[
              '<https://api.github.com/users?per_page=10&since=9919>; '
                  'rel="next"',
            ],
          },
        ),
      );

      final PaginatedUsers page = await harness.api.fetchUsers();

      expect(page.users, hasLength(3));
      expect(page.nextCursor, 9919);
    });

    test('an empty array ends pagination', () async {
      final harness = build(
        (_) => const FakeReply(statusCode: 200, body: '[]'),
      );

      final PaginatedUsers page = await harness.api.fetchUsers(cursor: 999999);

      expect(page.users, isEmpty);
      expect(page.hasReachedEnd, isTrue);
    });
  });

  group('list parsing -- constraint (b)', () {
    test('maps login onto displayName and leaves name fields null', () async {
      final harness = build(users);

      final UserSummary user = (await harness.api.fetchUsers()).users.first;

      expect(user.handle, 'mojombo');
      expect(user.displayName, 'mojombo', reason: 'no name in a list response');
      expect(user.lastName, isNull);
      expect(user.email, isNull);
      expect(user.detailId, 'mojombo', reason: 'GitHub keys detail by login');
      expect(user.accountType, 'User');
    });

    test('skips malformed entries instead of discarding the batch', () async {
      final harness = build(
        (_) => const FakeReply(
          statusCode: 200,
          body: '[{"id":1,"login":"a"},"junk",42,{"id":2,"login":"b"}]',
        ),
      );

      expect((await harness.api.fetchUsers()).users, hasLength(2));
    });
  });

  group('detail', () {
    test('requests /users/{login} and parses the extras', () async {
      final harness = build(
        (_) => FakeReply(statusCode: 200, body: fixture('user_detail.json')),
      );

      final UserDetail detail = await harness.api.fetchUserDetail('mojombo');

      expect(harness.adapter.requests.single.path, '/users/mojombo');
      expect(detail.displayName, 'Tom Preston-Werner');
      expect(detail.hasStats, isTrue);
      expect(detail.followers, 23000);
      expect(detail.location, 'San Francisco');
      expect(detail.email, isNull, reason: 'null for most GitHub accounts');
    });

    test('percent-encodes the path segment', () async {
      final harness = build(
        (_) => FakeReply(statusCode: 200, body: fixture('user_detail.json')),
      );

      await harness.api.fetchUserDetail('a/b');

      expect(
        harness.adapter.requests.single.path,
        '/users/a%2Fb',
        reason: 'an unencoded slash would retarget the request',
      );
    });

    test('404 becomes NotFoundException', () async {
      final harness = build(
        (_) =>
            const FakeReply(statusCode: 404, body: '{"message":"Not Found"}'),
      );

      await expectLater(
        harness.api.fetchUserDetail('nope'),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('rate limiting', () {
    test(
      '403 with remaining=0 becomes RateLimitException with the reset time',
      () async {
        final DateTime resetAt = DateTime.now().add(
          const Duration(minutes: 30),
        );
        final int epoch = resetAt.millisecondsSinceEpoch ~/ 1000;

        final harness = build(
          (_) => FakeReply(
            statusCode: 403,
            body: '{"message":"API rate limit exceeded"}',
            headers: <String, List<String>>{
              'x-ratelimit-limit': const <String>['60'],
              'x-ratelimit-remaining': const <String>['0'],
              'x-ratelimit-reset': <String>['$epoch'],
            },
          ),
        );

        await expectLater(
          harness.api.fetchUsers(),
          throwsA(
            isA<RateLimitException>().having(
              (RateLimitException e) =>
                  e.resetAt.millisecondsSinceEpoch ~/ 1000,
              'resetAt',
              epoch,
            ),
          ),
        );
      },
    );

    test('a plain 403 with quota left is NOT a rate limit', () async {
      final harness = build(
        (_) => const FakeReply(
          statusCode: 403,
          body: '{"message":"Forbidden"}',
          headers: <String, List<String>>{
            'x-ratelimit-remaining': <String>['57'],
          },
        ),
      );

      await expectLater(
        harness.api.fetchUsers(),
        throwsA(isA<ServerException>()),
      );
    });

    test('a connection failure becomes NetworkException', () async {
      final FakeHttpAdapter adapter = FakeHttpAdapter(
        (RequestOptions o) => throw DioException.connectionError(
          requestOptions: o,
          reason: 'Failed host lookup',
        ),
      );
      final GitHubUsersApi api = GitHubUsersApi(
        client: DioClient(
          baseUrl: 'https://api.github.com',
          headers: const <String, String>{},
          dio: Dio()..httpClientAdapter = adapter,
        ),
      );

      await expectLater(api.fetchUsers(), throwsA(isA<NetworkException>()));
    });
  });
}
