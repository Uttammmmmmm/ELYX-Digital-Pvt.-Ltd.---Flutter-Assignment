import 'package:dartz/dartz.dart';
import 'package:elyx_digital_assignment/core/error/exceptions.dart';
import 'package:elyx_digital_assignment/core/error/failures.dart';
import 'package:elyx_digital_assignment/core/models/sourced.dart';
import 'package:elyx_digital_assignment/core/storage/cache_entry.dart';
import 'package:elyx_digital_assignment/features/users/data/models/github_user_model.dart';
import 'package:elyx_digital_assignment/features/users/data/models/users_page_model.dart';
import 'package:elyx_digital_assignment/features/users/data/repositories/user_repository_impl.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/users_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../../helpers/mocks.mocks.dart';

const GithubUserModel _mojombo = GithubUserModel(
  id: 1,
  login: 'mojombo',
  avatarUrl: 'https://avatars.githubusercontent.com/u/1?v=4',
  htmlUrl: 'https://github.com/mojombo',
  type: 'User',
  isSiteAdmin: false,
);

const UsersPageModel _networkPage =
    UsersPageModel(users: <GithubUserModel>[_mojombo], nextCursor: 1);

const UsersPageModel _cachedPage =
    UsersPageModel(users: <GithubUserModel>[], nextCursor: 99);

void main() {
  late MockUserRemoteDataSource remote;
  late MockUserLocalDataSource local;
  late MockNetworkInfo network;
  late UserRepositoryImpl repository;

  setUp(() {
    remote = MockUserRemoteDataSource();
    local = MockUserLocalDataSource();
    network = MockNetworkInfo();
    repository = UserRepositoryImpl(
      remote: remote,
      local: local,
      networkInfo: network,
    );
    when(local.cacheUsersPage(any, any)).thenAnswer((_) async {});
  });

  CacheEntry<UsersPageModel> entryAged(Duration age) => CacheEntry<UsersPageModel>(
        value: _cachedPage,
        cachedAt: DateTime.now().subtract(age),
      );

  group('getUsers -- policy 1: fresh cache wins', () {
    test('serves cache and never touches the network', () async {
      when(local.readUsersPage(null))
          .thenReturn(entryAged(const Duration(minutes: 1)));

      final Either<Failure, Sourced<UsersPage>> result =
          await repository.getUsers();

      expect(result.isRight(), isTrue);
      result.fold((_) => fail('expected Right'), (Sourced<UsersPage> s) {
        expect(s.value, _cachedPage);
        expect(s.isFromCache, isTrue);
      });
      verifyZeroInteractions(remote);
      verifyNever(network.isConnected);
    });

    test('forceRefresh bypasses a fresh cache', () async {
      when(local.readUsersPage(null))
          .thenReturn(entryAged(const Duration(minutes: 1)));
      when(network.isConnected).thenAnswer((_) async => true);
      when(remote.getUsers(since: anyNamed('since')))
          .thenAnswer((_) async => _networkPage);

      final Either<Failure, Sourced<UsersPage>> result =
          await repository.getUsers(forceRefresh: true);

      result.fold((_) => fail('expected Right'), (Sourced<UsersPage> s) {
        expect(s.value, _networkPage);
        expect(s.isFromCache, isFalse);
      });
      verify(remote.getUsers(since: null)).called(1);
    });
  });

  group('getUsers -- policy 2: offline', () {
    test('serves stale cache at any age', () async {
      when(local.readUsersPage(null))
          .thenReturn(entryAged(const Duration(days: 30)));
      when(network.isConnected).thenAnswer((_) async => false);

      final Either<Failure, Sourced<UsersPage>> result =
          await repository.getUsers();

      result.fold((_) => fail('expected Right'), (Sourced<UsersPage> s) {
        expect(s.value, _cachedPage);
        expect(s.isFromCache, isTrue, reason: 'UI must be able to say so');
        expect(s.cachedAt, isNotNull);
      });
      verifyZeroInteractions(remote);
    });

    test('fails with NetworkFailure when the cache is empty', () async {
      when(local.readUsersPage(null)).thenReturn(null);
      when(network.isConnected).thenAnswer((_) async => false);

      final Either<Failure, Sourced<UsersPage>> result =
          await repository.getUsers();

      expect(result, const Left<Failure, Sourced<UsersPage>>(NetworkFailure()));
    });
  });

  group('getUsers -- policy 3: online fetch', () {
    setUp(() {
      when(network.isConnected).thenAnswer((_) async => true);
      when(local.readUsersPage(any)).thenReturn(null);
    });

    test('fetches, caches, and returns a network-tagged result', () async {
      when(remote.getUsers(since: anyNamed('since')))
          .thenAnswer((_) async => _networkPage);

      final Either<Failure, Sourced<UsersPage>> result =
          await repository.getUsers(cursor: 46);

      result.fold((_) => fail('expected Right'), (Sourced<UsersPage> s) {
        expect(s.origin, DataOrigin.network);
        expect(s.cachedAt, isNull);
      });
      verify(remote.getUsers(since: 46)).called(1);
      verify(local.cacheUsersPage(46, _networkPage)).called(1);
    });
  });

  group('getUsers -- policy 4: request failed', () {
    setUp(() => when(network.isConnected).thenAnswer((_) async => true));

    test('a spent rate limit falls back to stale cache (constraint d)', () async {
      final DateTime resetAt = DateTime.now().add(const Duration(minutes: 42));
      when(local.readUsersPage(null))
          .thenReturn(entryAged(const Duration(hours: 5)));
      when(remote.getUsers(since: anyNamed('since')))
          .thenThrow(RateLimitException(resetAt: resetAt, statusCode: 403));

      final Either<Failure, Sourced<UsersPage>> result =
          await repository.getUsers();

      result.fold((_) => fail('stale data beats an error screen'),
          (Sourced<UsersPage> s) {
        expect(s.value, _cachedPage);
        expect(s.isFromCache, isTrue);
      });
    });

    test('surfaces RateLimitFailure with resetAt when nothing is cached',
        () async {
      final DateTime resetAt = DateTime.now().add(const Duration(minutes: 42));
      when(local.readUsersPage(null)).thenReturn(null);
      when(remote.getUsers(since: anyNamed('since')))
          .thenThrow(RateLimitException(resetAt: resetAt, statusCode: 403));

      final Either<Failure, Sourced<UsersPage>> result =
          await repository.getUsers();

      final Failure failure =
          result.fold((Failure f) => f, (_) => fail('expected Left'));
      expect(failure, isA<RateLimitFailure>());
      expect((failure as RateLimitFailure).resetAt, resetAt);
    });

    test('maps a server error to ServerFailure', () async {
      when(local.readUsersPage(null)).thenReturn(null);
      when(remote.getUsers(since: anyNamed('since')))
          .thenThrow(const ServerException('boom', statusCode: 500));

      final Either<Failure, Sourced<UsersPage>> result =
          await repository.getUsers();

      expect(result.isLeft(), isTrue);
      expect(
        result.fold((Failure f) => f, (_) => null),
        isA<ServerFailure>(),
      );
    });
  });

  group('getUserDetail', () {
    test('a 404 is authoritative and must NOT serve a cached copy', () async {
      when(network.isConnected).thenAnswer((_) async => true);
      when(local.readUserDetail('ghost')).thenReturn(null);
      when(remote.getUserDetail('ghost')).thenThrow(const NotFoundException());

      final Either<Failure, dynamic> result =
          await repository.getUserDetail('ghost');

      expect(
        result.fold((Failure f) => f, (_) => null),
        isA<NotFoundFailure>(),
      );
    });
  });

  group('cachedDisplayNames (constraint e)', () {
    test('returns the sparse login -> name index', () async {
      when(local.displayNames())
          .thenReturn(const <String, String>{'mojombo': 'Tom Preston-Werner'});

      expect(
        await repository.cachedDisplayNames(),
        const <String, String>{'mojombo': 'Tom Preston-Werner'},
      );
    });

    test('degrades to an empty map rather than failing search', () async {
      when(local.displayNames()).thenThrow(const CacheException());

      expect(await repository.cachedDisplayNames(), isEmpty);
    });
  });

  group('clearUsersCache', () {
    test('drops list pages but leaves detail documents alone', () async {
      when(local.clearUsersPages()).thenAnswer((_) async {});

      await repository.clearUsersCache();

      verify(local.clearUsersPages()).called(1);
      verifyNever(local.cacheUserDetail(any));
    });
  });
}
