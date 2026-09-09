import 'package:dio/dio.dart';
import 'package:elyx_digital_assignment/core/error/exceptions.dart';
import 'package:elyx_digital_assignment/core/network/dio_client.dart';
import 'package:elyx_digital_assignment/core/network/rate_limit_tracker.dart';
import 'package:elyx_digital_assignment/features/users/data/datasources/api/reqres_users_api.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/paginated_users.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_detail.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../fixtures/fixture_reader.dart';
import '../../../../../helpers/fake_http_adapter.dart';

void main() {
  late RateLimitTracker tracker;

  setUp(() => tracker = RateLimitTracker());

  ({ReqresUsersApi api, FakeHttpAdapter adapter}) build(
    FakeReply Function(RequestOptions options) reply,
  ) {
    final FakeHttpAdapter adapter = FakeHttpAdapter(reply);
    final Dio dio = Dio()..httpClientAdapter = adapter;
    final ReqresUsersApi api = ReqresUsersApi(
      client: DioClient(
        rateLimitTracker: tracker,
        baseUrl: 'https://reqres.in/api',
        headers: const <String, String>{
          'Accept': 'application/json',
          'x-api-key': ReqresUsersApi.defaultApiKey,
        },
        dio: dio,
      ),
      apiKey: ReqresUsersApi.defaultApiKey,
    );
    return (api: api, adapter: adapter);
  }

  FakeReply page1(RequestOptions _) =>
      FakeReply(statusCode: 200, body: fixture('reqres_users_page1.json'));

  group('the required API key header', () {
    test('x-api-key is sent on every request', () async {
      final harness = build(page1);

      await harness.api.fetchUsers();

      expect(
        harness.adapter.requests.single.headers['x-api-key'],
        'reqres-free-v1',
        reason: 'reqres returns 401 missing_api_key without it',
      );
    });

    test('the header is declared on the api itself, for DioClient to use', () {
      final harness = build(page1);
      expect(harness.api.headers['x-api-key'], 'reqres-free-v1');
      expect(harness.api.baseUrl, 'https://reqres.in/api');
    });
  });

  group('page-number pagination (the scheme the brief specifies)', () {
    test('the first request sends page=1 and per_page', () async {
      final harness = build(page1);

      await harness.api.fetchUsers(perPage: 10);

      final RequestOptions request = harness.adapter.requests.single;
      expect(request.path, '/users');
      expect(request.queryParameters['page'], 1);
      expect(request.queryParameters['per_page'], 10);
      expect(
        request.queryParameters.containsKey('since'),
        isFalse,
        reason: 'since belongs to the other source',
      );
    });

    test('the cursor IS the page number, and advances by one', () async {
      final harness = build(page1);

      final PaginatedUsers page = await harness.api.fetchUsers();

      expect(page.nextCursor, 2, reason: 'page 1 of 2');
      expect(page.hasReachedEnd, isFalse);
    });

    test('a supplied cursor becomes the page parameter', () async {
      final harness = build(
        (_) => FakeReply(
          statusCode: 200,
          body: fixture('reqres_users_page2.json'),
        ),
      );

      await harness.api.fetchUsers(cursor: 2);

      expect(harness.adapter.requests.single.queryParameters['page'], 2);
    });

    test(
      'the last page ends pagination, read from total_pages in the BODY',
      () async {
        final harness = build(
          (_) => FakeReply(
            statusCode: 200,
            body: fixture('reqres_users_page2.json'),
          ),
        );

        final PaginatedUsers page = await harness.api.fetchUsers(cursor: 2);

        expect(page.nextCursor, isNull, reason: 'page 2 of 2');
        expect(page.hasReachedEnd, isTrue);
      },
    );

    test('an empty data array is the end', () async {
      final harness = build(
        (_) => const FakeReply(
          statusCode: 200,
          body: '{"page":3,"total_pages":3,"data":[]}',
        ),
      );

      final PaginatedUsers page = await harness.api.fetchUsers(cursor: 3);

      expect(page.users, isEmpty);
      expect(page.hasReachedEnd, isTrue);
    });
  });

  group('list parsing', () {
    test(
      'maps first_name/last_name/email/avatar onto the neutral entity',
      () async {
        final harness = build(page1);

        final PaginatedUsers page = await harness.api.fetchUsers();

        expect(page.users, hasLength(2));
        final UserSummary first = page.users.first;
        expect(first.id, 1);
        expect(first.firstName, 'George');
        expect(first.lastName, 'Bluth');
        expect(first.displayName, 'George Bluth');
        expect(first.email, 'george.bluth@reqres.in');
        expect(first.avatarUrl, contains('reqres.in/img/faces'));
      },
    );

    test(
      'detailId is the numeric id -- reqres keys detail by id, not handle',
      () async {
        final harness = build(page1);

        final PaginatedUsers page = await harness.api.fetchUsers();

        expect(page.users.first.detailId, '1');
      },
    );

    test('leaves GitHub-only fields null rather than inventing them', () async {
      final harness = build(page1);

      final UserSummary user = (await harness.api.fetchUsers()).users.first;

      expect(user.handle, isNull);
      expect(user.profileUrl, isNull);
      expect(user.accountType, isNull);
    });

    test('one malformed record does not discard the batch', () async {
      final harness = build(
        (_) => const FakeReply(
          statusCode: 200,
          body:
              '{"page":1,"total_pages":1,'
              '"data":[{"id":1,"first_name":"A"},"junk",42,{"id":2}]}',
        ),
      );

      final PaginatedUsers page = await harness.api.fetchUsers();

      expect(page.users, hasLength(2));
      expect(page.users.first.displayName, 'A');

      expect(page.users.last.displayName, 'User 2');
    });
  });

  group('detail parsing', () {
    test('unwraps the {"data": …} envelope', () async {
      final harness = build(
        (_) => FakeReply(
          statusCode: 200,
          body: fixture('reqres_user_detail.json'),
        ),
      );

      final UserDetail detail = await harness.api.fetchUserDetail('2');

      expect(harness.adapter.requests.single.path, '/users/2');
      expect(detail.displayName, 'Janet Weaver');
      expect(detail.email, 'janet.weaver@reqres.in');
      expect(detail.hasEmail, isTrue);
    });

    test(
      'reports no stats, so the UI hides the row rather than showing zeros',
      () async {
        final harness = build(
          (_) => FakeReply(
            statusCode: 200,
            body: fixture('reqres_user_detail.json'),
          ),
        );

        final UserDetail detail = await harness.api.fetchUserDetail('2');

        expect(detail.hasStats, isFalse);
        expect(detail.publicRepos, isNull);
        expect(detail.createdAt, isNull);
        expect(detail.bio, isNull);
      },
    );

    test('a missing data envelope is a ServerException, not a crash', () async {
      final harness = build(
        (_) => const FakeReply(statusCode: 200, body: '{"support":{}}'),
      );

      await expectLater(
        harness.api.fetchUserDetail('2'),
        throwsA(isA<ServerException>()),
      );
    });

    test('404 becomes NotFoundException', () async {
      final harness = build(
        (_) => const FakeReply(statusCode: 404, body: '{}'),
      );

      await expectLater(
        harness.api.fetchUserDetail('999'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test(
      'a missing key 401 surfaces as a typed failure, not a parse error',
      () async {
        final harness = build(
          (_) => const FakeReply(
            statusCode: 401,
            body: '{"error":"missing_api_key"}',
          ),
        );

        await expectLater(
          harness.api.fetchUsers(),
          throwsA(isA<AppException>()),
        );
      },
    );
  });
}
