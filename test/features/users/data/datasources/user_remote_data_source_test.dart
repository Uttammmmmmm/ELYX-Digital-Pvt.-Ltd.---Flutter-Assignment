import 'package:dio/dio.dart';
import 'package:elyx_digital_assignment/core/constants/api_constants.dart';
import 'package:elyx_digital_assignment/core/error/exceptions.dart';
import 'package:elyx_digital_assignment/core/network/dio_client.dart';
import 'package:elyx_digital_assignment/core/network/rate_limit_tracker.dart';
import 'package:elyx_digital_assignment/features/users/data/datasources/user_remote_data_source.dart';
import 'package:elyx_digital_assignment/features/users/data/models/paginated_users_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fixtures/fixture_reader.dart';
import '../../../../helpers/fake_http_adapter.dart';

/// End-to-end over the real Dio stack: interceptors, error mapper and Link
/// parser all run. Only the socket is faked.
void main() {
  late RateLimitTracker tracker;

  setUp(() => tracker = RateLimitTracker());

  ({UserRemoteDataSourceImpl source, FakeHttpAdapter adapter}) build(
    FakeReply Function(RequestOptions options) reply,
  ) {
    final FakeHttpAdapter adapter = FakeHttpAdapter(reply);
    final Dio dio = Dio()..httpClientAdapter = adapter;
    return (
      source: UserRemoteDataSourceImpl(
        DioClient(rateLimitTracker: tracker, dio: dio),
      ),
      adapter: adapter,
    );
  }

  group('getUsers', () {
    test('sends per_page and omits since on the first page (constraint a)',
        () async {
      final harness = build(
        (_) => FakeReply(statusCode: 200, body: fixture('users_list.json')),
      );

      await harness.source.getUsers();

      final RequestOptions request = harness.adapter.requests.single;
      expect(request.path, ApiConstants.usersPath);
      expect(request.queryParameters[ApiConstants.paramPerPage], 10);
      expect(
        request.queryParameters.containsKey(ApiConstants.paramSince),
        isFalse,
        reason: 'the first page must not send since',
      );
    });

    test('sends since as the cursor -- never page', () async {
      final harness = build(
        (_) => FakeReply(statusCode: 200, body: fixture('users_list.json')),
      );

      await harness.source.getUsers(since: 46);

      final RequestOptions request = harness.adapter.requests.single;
      expect(request.queryParameters[ApiConstants.paramSince], 46);
      expect(request.queryParameters.containsKey('page'), isFalse);
    });

    test('sends the headers GitHub requires', () async {
      final harness = build(
        (_) => FakeReply(statusCode: 200, body: fixture('users_list.json')),
      );

      await harness.source.getUsers();

      final Map<String, dynamic> headers = harness.adapter.requests.single.headers;
      expect(headers[ApiConstants.headerAccept], ApiConstants.acceptJson);
      expect(headers[ApiConstants.headerApiVersion], ApiConstants.apiVersion);
      expect(headers[ApiConstants.headerUserAgent], isNotNull,
          reason: 'GitHub rejects requests without a User-Agent');
    });

    test('derives the cursor from the Link header', () async {
      final harness = build(
        (_) => FakeReply(
          statusCode: 200,
          body: fixture('users_list.json'),
          headers: <String, List<String>>{
            'link': <String>[
              '<https://api.github.com/users?per_page=10&since=9919>; '
                  'rel="next", '
                  '<https://api.github.com/users{?since}>; rel="first"',
            ],
          },
        ),
      );

      final PaginatedUsersModel page = await harness.source.getUsers();

      expect(page.users, hasLength(3));
      expect(page.nextSince, 9919);
    });

    test('an empty array ends pagination', () async {
      final harness = build((_) => const FakeReply(statusCode: 200, body: '[]'));

      final PaginatedUsersModel page = await harness.source.getUsers(since: 999999);

      expect(page.users, isEmpty);
      expect(page.hasReachedEnd, isTrue);
    });

    test('403 with remaining=0 becomes RateLimitException with the reset time '
        '(constraint d)', () async {
      final DateTime resetAt =
          DateTime.now().add(const Duration(minutes: 30));
      final int epoch = resetAt.millisecondsSinceEpoch ~/ 1000;

      final harness = build(
        (_) => FakeReply(
          statusCode: 403,
          body: '{"message":"API rate limit exceeded"}',
          headers: <String, List<String>>{
            'x-ratelimit-limit': <String>['60'],
            'x-ratelimit-remaining': <String>['0'],
            'x-ratelimit-reset': <String>['$epoch'],
          },
        ),
      );

      await expectLater(
        harness.source.getUsers(),
        throwsA(
          isA<RateLimitException>().having(
            (RateLimitException e) => e.resetAt.millisecondsSinceEpoch ~/ 1000,
            'resetAt',
            epoch,
          ),
        ),
      );

      expect(tracker.isExhausted, isTrue);
      expect(tracker.snapshot!.limit, 60);
    });

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
        harness.source.getUsers(),
        throwsA(isA<ServerException>()),
      );
      expect(tracker.isExhausted, isFalse);
      expect(tracker.snapshot!.remaining, 57);
    });

    test('records the budget on a SUCCESSFUL response too', () async {
      final harness = build(
        (_) => FakeReply(
          statusCode: 200,
          body: fixture('users_list.json'),
          headers: <String, List<String>>{
            'x-ratelimit-limit': <String>['60'],
            'x-ratelimit-remaining': <String>['57'],
          },
        ),
      );

      await harness.source.getUsers();

      expect(tracker.snapshot!.remaining, 57,
          reason: 'lets the UI warn before the quota is gone');
    });
  });

  group('getUserDetail', () {
    test('requests /users/{login} and parses the profile', () async {
      final harness = build(
        (_) => FakeReply(statusCode: 200, body: fixture('user_detail.json')),
      );

      final detail = await harness.source.getUserDetail('mojombo');

      expect(harness.adapter.requests.single.path, '/users/mojombo');
      expect(detail.name, 'Tom Preston-Werner');
      expect(detail.email, isNull);
    });

    test('404 becomes NotFoundException', () async {
      final harness = build(
        (_) => const FakeReply(
          statusCode: 404,
          body: '{"message":"Not Found"}',
        ),
      );

      await expectLater(
        harness.source.getUserDetail('does-not-exist'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('a connection failure becomes NetworkException', () async {
      final FakeHttpAdapter adapter = FakeHttpAdapter(
        (RequestOptions options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'Failed host lookup: api.github.com',
        ),
      );
      final Dio dio = Dio()..httpClientAdapter = adapter;
      final UserRemoteDataSourceImpl source = UserRemoteDataSourceImpl(
        DioClient(rateLimitTracker: tracker, dio: dio),
      );

      await expectLater(
        source.getUsers(),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
