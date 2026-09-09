import 'package:dartz/dartz.dart';
import 'package:elyx_digital_assignment/core/error/exceptions.dart';
import 'package:elyx_digital_assignment/core/error/failures.dart';
import 'package:elyx_digital_assignment/features/users/data/models/cached_page_model.dart';
import 'package:elyx_digital_assignment/features/users/data/models/user_detail_model.dart';
import 'package:elyx_digital_assignment/features/users/data/models/user_summary_model.dart';
import 'package:elyx_digital_assignment/features/users/data/repositories/user_repository_impl.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/paginated_users.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_detail.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_summary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../../helpers/mocks.mocks.dart';

const UserSummaryModel _remoteUser = UserSummaryModel(
  id: 48,
  login: 'defunkt',
  avatarUrl: 'a',
  htmlUrl: 'h',
  type: 'User',
  siteAdmin: false,
);

const UserSummaryModel _cachedUser = UserSummaryModel(
  id: 1,
  login: 'mojombo',
  avatarUrl: 'a',
  htmlUrl: 'h',
  type: 'User',
  siteAdmin: false,
);

final PaginatedUsers _remotePage = PaginatedUsers.fromBatch(
  users: const <UserSummary>[_remoteUser],
  nextSince: 48,
);

/// Distinguishable from the remote batch, so branches are unambiguous.
CachedPageModel _cachedPage(Duration age) => CachedPageModel(
      users: const <UserSummaryModel>[_cachedUser],
      nextSince: 1,
      requestedSince: null,
      cachedAt: DateTime.now().subtract(age),
    );

const Duration _fresh = Duration(minutes: 1);
const Duration _stale = Duration(hours: 5);

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
    when(local.cacheUserDetail(any)).thenAnswer((_) async {});
  });

  void stubRemote([PaginatedUsers? page]) => when(
        remote.getUsers(since: anyNamed('since'), perPage: anyNamed('perPage')),
      ).thenAnswer((_) async => page ?? _remotePage);

  void throwRemote(Object e) => when(
        remote.getUsers(since: anyNamed('since'), perPage: anyNamed('perPage')),
      ).thenThrow(e);

  List<String> loginsOf(Either<Failure, PaginatedUsers> r) => r.fold(
        (Failure f) => fail('expected Right, got $f'),
        (PaginatedUsers p) => p.users.map((UserSummary u) => u.login).toList(),
      );

  group('branch 1 -- forceRefresh', () {
    test('goes remote even when the cache is fresh, and overwrites it',
        () async {
      when(local.getCachedUsersPage(null)).thenReturn(_cachedPage(_fresh));
      when(network.isConnected).thenAnswer((_) async => true);
      stubRemote();

      final Either<Failure, PaginatedUsers> result =
          await repository.getUsers(forceRefresh: true);

      expect(loginsOf(result), <String>['defunkt']);
      verify(local.cacheUsersPage(null, _remotePage)).called(1);
    });

    test('falls back to the stale cache when the forced fetch fails',
        () async {
      when(local.getCachedUsersPage(null)).thenReturn(_cachedPage(_stale));
      when(network.isConnected).thenAnswer((_) async => true);
      throwRemote(const ServerException('boom', statusCode: 500));

      expect(
        loginsOf(await repository.getUsers(forceRefresh: true)),
        <String>['mojombo'],
        reason: 'a pull-to-refresh must not be punished with an error screen',
      );
    });
  });

  group('branch 2 -- fresh cache hit', () {
    test('returns the cache and makes NO network call at all', () async {
      when(local.getCachedUsersPage(null)).thenReturn(_cachedPage(_fresh));

      expect(loginsOf(await repository.getUsers()), <String>['mojombo']);
      verifyZeroInteractions(remote);
      verifyNever(network.isConnected);
    });
  });

  group('branch 3 -- offline', () {
    setUp(() => when(network.isConnected).thenAnswer((_) async => false));

    test('serves cached data at ANY age rather than failing', () async {
      when(local.getCachedUsersPage(null))
          .thenReturn(_cachedPage(const Duration(days: 30)));

      expect(loginsOf(await repository.getUsers()), <String>['mojombo']);
      verifyZeroInteractions(remote);
    });

    test('only fails when there is nothing usable on disk', () async {
      when(local.getCachedUsersPage(null)).thenReturn(null);

      expect(
        await repository.getUsers(),
        const Left<Failure, PaginatedUsers>(NetworkFailure()),
      );
    });
  });

  group('branch 4 -- stale cache + online', () {
    test('refreshes from the network', () async {
      when(local.getCachedUsersPage(null)).thenReturn(_cachedPage(_stale));
      when(network.isConnected).thenAnswer((_) async => true);
      stubRemote();

      expect(loginsOf(await repository.getUsers()), <String>['defunkt']);
    });
  });

  group('branch 5 -- remote failed', () {
    setUp(() => when(network.isConnected).thenAnswer((_) async => true));

    test('a spent rate limit degrades to stale cache (constraint d)', () async {
      when(local.getCachedUsersPage(null)).thenReturn(_cachedPage(_stale));
      throwRemote(RateLimitException(resetAt: DateTime.now(), statusCode: 403));

      expect(loginsOf(await repository.getUsers()), <String>['mojombo']);
    });

    test('surfaces RateLimitFailure with resetAt when nothing is cached',
        () async {
      final DateTime resetAt = DateTime.now().add(const Duration(minutes: 42));
      when(local.getCachedUsersPage(null)).thenReturn(null);
      throwRemote(RateLimitException(resetAt: resetAt, statusCode: 403));

      final Failure failure = (await repository.getUsers())
          .fold((Failure f) => f, (_) => fail('expected Left'));

      expect(failure, isA<RateLimitFailure>());
      expect((failure as RateLimitFailure).resetAt, resetAt);
    });

    test('maps a server error to ServerFailure with no cache', () async {
      when(local.getCachedUsersPage(null)).thenReturn(null);
      throwRemote(const ServerException('boom', statusCode: 500));

      expect(
        (await repository.getUsers()).fold((Failure f) => f, (_) => null),
        isA<ServerFailure>(),
      );
    });

    test('an unexpected non-AppException never escapes the data layer',
        () async {
      when(local.getCachedUsersPage(null)).thenReturn(null);
      throwRemote(StateError('unmapped'));

      expect(
        (await repository.getUsers()).fold((Failure f) => f, (_) => null),
        isA<ServerFailure>(),
      );
    });
  });

  group('branch 6 -- remote success', () {
    test('caches before returning, keyed by the requesting cursor', () async {
      when(local.getCachedUsersPage(47)).thenReturn(null);
      when(network.isConnected).thenAnswer((_) async => true);
      stubRemote();

      await repository.getUsers(since: 47, perPage: 25);

      verify(remote.getUsers(since: 47, perPage: 25)).called(1);
      verify(local.cacheUsersPage(47, _remotePage)).called(1);
    });
  });

  group('branch 7 -- empty batch', () {
    test('is a successful end-of-list, NOT a failure', () async {
      when(local.getCachedUsersPage(999)).thenReturn(null);
      when(network.isConnected).thenAnswer((_) async => true);
      stubRemote(
        PaginatedUsers.fromBatch(users: const <UserSummary>[], nextSince: null),
      );

      final Either<Failure, PaginatedUsers> result =
          await repository.getUsers(since: 999);

      expect(result.isRight(), isTrue,
          reason: 'reaching the end of GitHub is not an outage');
      result.fold((_) => fail('expected Right'), (PaginatedUsers p) {
        expect(p.users, isEmpty);
        expect(p.hasReachedEnd, isTrue);
      });
    });

    test('the empty batch is still cached, so the end is not rediscovered',
        () async {
      final PaginatedUsers empty =
          PaginatedUsers.fromBatch(users: const <UserSummary>[], nextSince: null);
      when(local.getCachedUsersPage(999)).thenReturn(null);
      when(network.isConnected).thenAnswer((_) async => true);
      stubRemote(empty);

      await repository.getUsers(since: 999);

      verify(local.cacheUsersPage(999, empty)).called(1);
    });
  });

  group('getUserDetail', () {
    final UserDetailModel detail = UserDetailModel(
      id: 1,
      login: 'mojombo',
      avatarUrl: 'a',
      htmlUrl: 'h',
      publicRepos: 66,
      followers: 23000,
      following: 11,
      createdAt: DateTime.utc(2007, 10, 20),
      name: 'Tom Preston-Werner',
      cachedAt: DateTime.now(),
    );

    test('a fresh cached profile skips the network', () async {
      when(local.getCachedUserDetail('mojombo')).thenReturn(detail);

      final Either<Failure, UserDetail> result =
          await repository.getUserDetail('mojombo');

      expect(result.isRight(), isTrue);
      verifyZeroInteractions(remote);
    });

    test('offline with a cached profile serves it at any age', () async {
      when(local.getCachedUserDetail('mojombo')).thenReturn(
        UserDetailModel(
          id: 1,
          login: 'mojombo',
          avatarUrl: 'a',
          htmlUrl: 'h',
          publicRepos: 66,
          followers: 23000,
          following: 11,
          createdAt: DateTime.utc(2007, 10, 20),
          cachedAt: DateTime.now().subtract(const Duration(days: 30)),
        ),
      );
      when(network.isConnected).thenAnswer((_) async => false);

      expect((await repository.getUserDetail('mojombo')).isRight(), isTrue);
    });

    test('a 404 is authoritative and must NOT serve a cached copy', () async {
      // Must be STALE, otherwise the fresh-cache branch short-circuits and
      // the request that would 404 is never made.
      when(local.getCachedUserDetail('ghost')).thenReturn(
        UserDetailModel(
          id: 1,
          login: 'ghost',
          avatarUrl: 'a',
          htmlUrl: 'h',
          publicRepos: 0,
          followers: 0,
          following: 0,
          createdAt: DateTime.utc(2010),
          cachedAt: DateTime.now().subtract(const Duration(days: 30)),
        ),
      );
      when(network.isConnected).thenAnswer((_) async => true);
      when(remote.getUserDetail('ghost')).thenThrow(const NotFoundException());

      expect(
        (await repository.getUserDetail('ghost'))
            .fold((Failure f) => f, (_) => null),
        isA<NotFoundFailure>(),
        reason: 'the account is gone, so the cached copy is now wrong',
      );
    });

    test('other failures fall back to the cached profile', () async {
      when(local.getCachedUserDetail('mojombo')).thenReturn(
        UserDetailModel(
          id: 1,
          login: 'mojombo',
          avatarUrl: 'a',
          htmlUrl: 'h',
          publicRepos: 66,
          followers: 23000,
          following: 11,
          createdAt: DateTime.utc(2007, 10, 20),
          cachedAt: DateTime.now().subtract(const Duration(days: 30)),
        ),
      );
      when(network.isConnected).thenAnswer((_) async => true);
      when(remote.getUserDetail('mojombo'))
          .thenThrow(const ServerException('boom', statusCode: 500));

      expect((await repository.getUserDetail('mojombo')).isRight(), isTrue);
    });
  });
}
