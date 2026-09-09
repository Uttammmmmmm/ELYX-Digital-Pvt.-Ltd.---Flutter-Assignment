import 'package:dartz/dartz.dart';
import 'package:elyx_digital_assignment/core/error/exceptions.dart';
import 'package:elyx_digital_assignment/core/error/failures.dart';
import 'package:elyx_digital_assignment/core/storage/cache_entry.dart';
import 'package:elyx_digital_assignment/features/users/data/models/paginated_users_model.dart';
import 'package:elyx_digital_assignment/features/users/data/models/user_summary_model.dart';
import 'package:elyx_digital_assignment/features/users/data/repositories/user_repository_impl.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/paginated_users.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../../helpers/mocks.mocks.dart';

const UserSummaryModel _mojombo = UserSummaryModel(
  id: 1,
  login: 'mojombo',
  avatarUrl: 'https://avatars.githubusercontent.com/u/1?v=4',
  htmlUrl: 'https://github.com/mojombo',
  type: 'User',
  siteAdmin: false,
);

const PaginatedUsersModel _networkPage = PaginatedUsersModel(
  users: <UserSummaryModel>[_mojombo],
  nextSince: 1,
  hasReachedEnd: false,
);

const PaginatedUsersModel _cachedPage = PaginatedUsersModel(
  users: <UserSummaryModel>[],
  nextSince: 99,
  hasReachedEnd: false,
);

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
    when(local.clearUsersPages()).thenAnswer((_) async {});
  });

  CacheEntry<PaginatedUsersModel> aged(Duration age) =>
      CacheEntry<PaginatedUsersModel>(
        value: _cachedPage,
        cachedAt: DateTime.now().subtract(age),
      );

  group('policy 1: fresh cache wins', () {
    test('serves cache and never touches the network', () async {
      when(local.readUsersPage(null))
          .thenReturn(aged(const Duration(minutes: 1)));

      final Either<Failure, PaginatedUsers> result =
          await repository.getUsers();

      expect(result, const Right<Failure, PaginatedUsers>(_cachedPage));
      verifyZeroInteractions(remote);
      verifyNever(network.isConnected);
    });
  });

  group('policy 2: forceRefresh (pull-to-refresh)', () {
    test('bypasses a fresh cache and goes to the network', () async {
      when(local.readUsersPage(null))
          .thenReturn(aged(const Duration(minutes: 1)));
      when(network.isConnected).thenAnswer((_) async => true);
      when(remote.getUsers(since: anyNamed('since'), perPage: anyNamed('perPage')))
          .thenAnswer((_) async => _networkPage);

      final Either<Failure, PaginatedUsers> result =
          await repository.getUsers(forceRefresh: true);

      expect(result, const Right<Failure, PaginatedUsers>(_networkPage));
    });

    test('clears stored batches first, so a refresh cannot be served the very '
        'data it is replacing', () async {
      when(local.readUsersPage(null)).thenReturn(null);
      when(network.isConnected).thenAnswer((_) async => true);
      when(remote.getUsers(since: anyNamed('since'), perPage: anyNamed('perPage')))
          .thenAnswer((_) async => _networkPage);

      await repository.getUsers(forceRefresh: true);

      verify(local.clearUsersPages()).called(1);
    });

    test('does NOT clear the cache on a normal read', () async {
      when(local.readUsersPage(null)).thenReturn(null);
      when(network.isConnected).thenAnswer((_) async => true);
      when(remote.getUsers(since: anyNamed('since'), perPage: anyNamed('perPage')))
          .thenAnswer((_) async => _networkPage);

      await repository.getUsers();

      verifyNever(local.clearUsersPages());
    });

    test('still writes to the cache after a forced fetch', () async {
      when(local.readUsersPage(null)).thenReturn(null);
      when(network.isConnected).thenAnswer((_) async => true);
      when(remote.getUsers(since: anyNamed('since'), perPage: anyNamed('perPage')))
          .thenAnswer((_) async => _networkPage);

      await repository.getUsers(forceRefresh: true);

      verify(local.cacheUsersPage(null, _networkPage)).called(1);
    });
  });

  group('policy 3: offline', () {
    test('serves stale cache at any age', () async {
      when(local.readUsersPage(null)).thenReturn(aged(const Duration(days: 30)));
      when(network.isConnected).thenAnswer((_) async => false);

      final Either<Failure, PaginatedUsers> result =
          await repository.getUsers();

      expect(result, const Right<Failure, PaginatedUsers>(_cachedPage));
      verifyZeroInteractions(remote);
    });

    test('fails with NetworkFailure when the cache is empty', () async {
      when(local.readUsersPage(null)).thenReturn(null);
      when(network.isConnected).thenAnswer((_) async => false);

      expect(
        await repository.getUsers(),
        const Left<Failure, PaginatedUsers>(NetworkFailure()),
      );
    });
  });

  group('policy 4: online fetch and failure fallback', () {
    setUp(() => when(network.isConnected).thenAnswer((_) async => true));

    test('passes the cursor and perPage straight through (constraint a)',
        () async {
      when(local.readUsersPage(any)).thenReturn(null);
      when(remote.getUsers(since: anyNamed('since'), perPage: anyNamed('perPage')))
          .thenAnswer((_) async => _networkPage);

      await repository.getUsers(since: 46, perPage: 25);

      verify(remote.getUsers(since: 46, perPage: 25)).called(1);
    });

    test('a spent rate limit falls back to stale cache (constraint d)',
        () async {
      when(local.readUsersPage(null)).thenReturn(aged(const Duration(hours: 5)));
      when(remote.getUsers(since: anyNamed('since'), perPage: anyNamed('perPage')))
          .thenThrow(RateLimitException(resetAt: DateTime.now(), statusCode: 403));

      expect(
        await repository.getUsers(),
        const Right<Failure, PaginatedUsers>(_cachedPage),
        reason: 'stale data beats an error screen',
      );
    });

    test('surfaces RateLimitFailure with resetAt when nothing is cached',
        () async {
      final DateTime resetAt = DateTime.now().add(const Duration(minutes: 42));
      when(local.readUsersPage(null)).thenReturn(null);
      when(remote.getUsers(since: anyNamed('since'), perPage: anyNamed('perPage')))
          .thenThrow(RateLimitException(resetAt: resetAt, statusCode: 403));

      final Failure failure = (await repository.getUsers())
          .fold((Failure f) => f, (_) => fail('expected Left'));

      expect(failure, isA<RateLimitFailure>());
      expect((failure as RateLimitFailure).resetAt, resetAt);
    });

    test('maps a server error to ServerFailure', () async {
      when(local.readUsersPage(null)).thenReturn(null);
      when(remote.getUsers(since: anyNamed('since'), perPage: anyNamed('perPage')))
          .thenThrow(const ServerException('boom', statusCode: 500));

      expect(
        (await repository.getUsers()).fold((Failure f) => f, (_) => null),
        isA<ServerFailure>(),
      );
    });
  });

  group('getUserDetail', () {
    test('a 404 is authoritative and must NOT serve a cached copy', () async {
      when(network.isConnected).thenAnswer((_) async => true);
      when(local.readUserDetail('ghost')).thenReturn(null);
      when(remote.getUserDetail('ghost')).thenThrow(const NotFoundException());

      expect(
        (await repository.getUserDetail('ghost'))
            .fold((Failure f) => f, (_) => null),
        isA<NotFoundFailure>(),
      );
    });
  });
}
