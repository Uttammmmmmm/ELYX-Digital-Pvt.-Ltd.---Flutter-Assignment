import 'package:dartz/dartz.dart';
import 'package:elyx_digital_assignment/core/error/exceptions.dart';
import 'package:elyx_digital_assignment/core/error/failures.dart';
import 'package:elyx_digital_assignment/features/users/data/models/cached_page_model.dart';
import 'package:elyx_digital_assignment/features/users/data/models/user_detail_model.dart';
import 'package:elyx_digital_assignment/features/users/data/models/user_summary_model.dart';
import 'package:elyx_digital_assignment/features/users/data/repositories/user_repository_impl.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/paginated_users.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_summary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../../helpers/entity_fixtures.dart';
import '../../../../helpers/mocks.mocks.dart';

void main() {
  late MockUsersApi api;
  late MockUserLocalDataSource local;
  late MockNetworkInfo network;
  late UserRepositoryImpl repository;

  final PaginatedUsers remotePage = PaginatedUsers.fromBatch(
    users: <UserSummary>[reqresUser(9, first: 'Remote', last: 'User')],
    nextCursor: 2,
  );

  CachedPageModel cachedPage(Duration age) => CachedPageModel(
    users: <UserSummaryModel>[
      UserSummaryModel.fromEntity(reqresUser(1, first: 'Cached')),
    ],
    nextCursor: 5,
    requestedCursor: null,
    cachedAt: DateTime.now().subtract(age),
  );

  const Duration fresh = Duration(minutes: 1);
  const Duration stale = Duration(hours: 5);

  setUp(() {
    api = MockUsersApi();
    local = MockUserLocalDataSource();
    network = MockNetworkInfo();
    repository = UserRepositoryImpl(
      api: api,
      local: local,
      networkInfo: network,
    );
    when(local.cacheUsersPage(any, any)).thenAnswer((_) async {});
    when(local.cacheUserDetail(any)).thenAnswer((_) async {});
    when(local.clearUsersPages()).thenAnswer((_) async {});
  });

  void stubRemote([PaginatedUsers? page]) => when(
    api.fetchUsers(cursor: anyNamed('cursor'), perPage: anyNamed('perPage')),
  ).thenAnswer((_) async => page ?? remotePage);

  List<String> namesOf(Either<Failure, PaginatedUsers> r) => r.fold(
    (Failure f) => fail('expected Right, got $f'),
    (PaginatedUsers p) =>
        p.users.map((UserSummary u) => u.displayName).toList(),
  );

  group('branch 1 -- forceRefresh', () {
    test('goes remote even when the cache is fresh', () async {
      when(local.getCachedUsersPage(null)).thenReturn(cachedPage(fresh));
      when(network.isConnected).thenAnswer((_) async => true);
      stubRemote();

      expect(namesOf(await repository.getUsers(forceRefresh: true)), <String>[
        'Remote User',
      ]);
    });

    test(
      'INVALIDATES cached batches once the replacement has arrived',
      () async {
        when(local.getCachedUsersPage(any)).thenReturn(null);
        when(network.isConnected).thenAnswer((_) async => true);
        stubRemote();

        await repository.getUsers(forceRefresh: true);

        verify(local.clearUsersPages()).called(1);
      },
    );

    test('does NOT clear on a normal read', () async {
      when(local.getCachedUsersPage(null)).thenReturn(null);
      when(network.isConnected).thenAnswer((_) async => true);
      stubRemote();

      await repository.getUsers();

      verifyNever(local.clearUsersPages());
    });

    test(
      'a later page after a refresh goes REMOTE, not to a pre-refresh entry',
      () async {
        bool cleared = false;
        when(local.clearUsersPages()).thenAnswer((_) async => cleared = true);
        when(
          local.getCachedUsersPage(2),
        ).thenAnswer((_) => cleared ? null : cachedPage(fresh));
        when(local.getCachedUsersPage(null)).thenReturn(null);
        when(network.isConnected).thenAnswer((_) async => true);
        stubRemote();

        await repository.getUsers(forceRefresh: true);
        final Either<Failure, PaginatedUsers> second = await repository
            .getUsers(cursor: 2);

        expect(namesOf(second), <String>['Remote User']);
        verify(
          api.fetchUsers(cursor: 2, perPage: anyNamed('perPage')),
        ).called(1);
      },
    );

    // Regression: the invalidation used to run before the connectivity
    // check, so pulling to refresh in airplane mode destroyed the only copy
    // of the data the user could still be shown.
    test('offline: does NOT clear the cache it cannot replace', () async {
      when(local.getCachedUsersPage(null)).thenReturn(cachedPage(stale));
      when(network.isConnected).thenAnswer((_) async => false);

      final Either<Failure, PaginatedUsers> result = await repository.getUsers(
        forceRefresh: true,
      );

      verifyNever(local.clearUsersPages());
      verifyZeroInteractions(api);
      expect(namesOf(result), <String>[
        'Cached Last1',
      ], reason: 'the cache survives and is still served');
    });

    test('offline with an empty cache still fails cleanly', () async {
      when(local.getCachedUsersPage(null)).thenReturn(null);
      when(network.isConnected).thenAnswer((_) async => false);

      expect(
        await repository.getUsers(forceRefresh: true),
        const Left<Failure, PaginatedUsers>(NetworkFailure()),
      );
      verifyNever(local.clearUsersPages());
    });

    test('a failed refresh leaves the cached batches intact', () async {
      when(local.getCachedUsersPage(null)).thenReturn(cachedPage(stale));
      when(network.isConnected).thenAnswer((_) async => true);
      when(
        api.fetchUsers(
          cursor: anyNamed('cursor'),
          perPage: anyNamed('perPage'),
        ),
      ).thenThrow(const ServerException('boom', statusCode: 500));

      await repository.getUsers(forceRefresh: true);

      verifyNever(local.clearUsersPages());
    });

    test('reports the failure instead of re-serving what the user '
        'just asked to replace', () async {
      when(local.clearUsersPages()).thenAnswer((_) async {});
      when(local.getCachedUsersPage(null)).thenReturn(cachedPage(stale));
      when(network.isConnected).thenAnswer((_) async => true);
      when(
        api.fetchUsers(
          cursor: anyNamed('cursor'),
          perPage: anyNamed('perPage'),
        ),
      ).thenThrow(const ServerException('boom', statusCode: 500));

      expect((await repository.getUsers(forceRefresh: true)).isLeft(), isTrue);
    });
  });

  group('branch 2 -- fresh cache hit', () {
    test('returns the cache and makes NO network call at all', () async {
      when(local.getCachedUsersPage(null)).thenReturn(cachedPage(fresh));

      expect(namesOf(await repository.getUsers()), <String>['Cached Last1']);
      verifyZeroInteractions(api);
      verifyNever(network.isConnected);
    });
  });

  group('branch 3 -- offline', () {
    setUp(() => when(network.isConnected).thenAnswer((_) async => false));

    test('serves cached data at ANY age rather than failing', () async {
      when(
        local.getCachedUsersPage(null),
      ).thenReturn(cachedPage(const Duration(days: 30)));

      expect(namesOf(await repository.getUsers()), <String>['Cached Last1']);
      verifyZeroInteractions(api);
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
      when(local.getCachedUsersPage(null)).thenReturn(cachedPage(stale));
      when(network.isConnected).thenAnswer((_) async => true);
      stubRemote();

      expect(namesOf(await repository.getUsers()), <String>['Remote User']);
    });
  });

  group('branch 5 -- remote failed', () {
    setUp(() => when(network.isConnected).thenAnswer((_) async => true));

    test('a spent rate limit degrades to stale cache', () async {
      when(local.getCachedUsersPage(null)).thenReturn(cachedPage(stale));
      when(
        api.fetchUsers(
          cursor: anyNamed('cursor'),
          perPage: anyNamed('perPage'),
        ),
      ).thenThrow(RateLimitException(resetAt: DateTime.now(), statusCode: 429));

      expect(namesOf(await repository.getUsers()), <String>['Cached Last1']);
    });

    test(
      'surfaces RateLimitFailure with resetAt when nothing is cached',
      () async {
        final DateTime resetAt = DateTime.now().add(
          const Duration(minutes: 42),
        );
        when(local.getCachedUsersPage(null)).thenReturn(null);
        when(
          api.fetchUsers(
            cursor: anyNamed('cursor'),
            perPage: anyNamed('perPage'),
          ),
        ).thenThrow(RateLimitException(resetAt: resetAt, statusCode: 429));

        final Failure failure = (await repository.getUsers()).fold(
          (Failure f) => f,
          (_) => fail('expected Left'),
        );

        expect(failure, isA<RateLimitFailure>());
        expect((failure as RateLimitFailure).resetAt, resetAt);
      },
    );

    test(
      'an unexpected non-AppException never escapes the data layer',
      () async {
        when(local.getCachedUsersPage(null)).thenReturn(null);
        when(
          api.fetchUsers(
            cursor: anyNamed('cursor'),
            perPage: anyNamed('perPage'),
          ),
        ).thenThrow(StateError('unmapped'));

        expect(
          (await repository.getUsers()).fold((Failure f) => f, (_) => null),
          isA<ServerFailure>(),
        );
      },
    );
  });

  group('branch 6 -- remote success', () {
    test('caches under the requesting cursor, whatever its shape', () async {
      when(local.getCachedUsersPage(2)).thenReturn(null);
      when(network.isConnected).thenAnswer((_) async => true);
      stubRemote();

      await repository.getUsers(cursor: 2, perPage: 25);

      verify(api.fetchUsers(cursor: 2, perPage: 25)).called(1);
      verify(local.cacheUsersPage(2, remotePage)).called(1);
    });
  });

  group('branch 7 -- empty batch', () {
    test('is a successful end-of-list, NOT a failure', () async {
      when(local.getCachedUsersPage(3)).thenReturn(null);
      when(network.isConnected).thenAnswer((_) async => true);
      stubRemote(
        PaginatedUsers.fromBatch(
          users: const <UserSummary>[],
          nextCursor: null,
        ),
      );

      final Either<Failure, PaginatedUsers> result = await repository.getUsers(
        cursor: 3,
      );

      expect(result.isRight(), isTrue);
      result.fold((_) => fail('expected Right'), (PaginatedUsers p) {
        expect(p.users, isEmpty);
        expect(p.hasReachedEnd, isTrue);
      });
    });
  });

  group('getUserDetail', () {
    test('a fresh cached profile skips the network', () async {
      when(local.getCachedUserDetail('1')).thenReturn(
        UserDetailModel.fromEntity(reqresDetail(1), cachedAt: DateTime.now()),
      );

      expect((await repository.getUserDetail('1')).isRight(), isTrue);
      verifyZeroInteractions(api);
    });

    test('a 404 is authoritative and must NOT serve a cached copy', () async {
      when(local.getCachedUserDetail('ghost')).thenReturn(
        UserDetailModel.fromEntity(
          reqresDetail(1),
          cachedAt: DateTime.now().subtract(const Duration(days: 30)),
        ),
      );
      when(network.isConnected).thenAnswer((_) async => true);
      when(api.fetchUserDetail('ghost')).thenThrow(const NotFoundException());

      expect(
        (await repository.getUserDetail(
          'ghost',
        )).fold((Failure f) => f, (_) => null),
        isA<NotFoundFailure>(),
      );
    });

    test('other failures fall back to the cached profile', () async {
      when(local.getCachedUserDetail('1')).thenReturn(
        UserDetailModel.fromEntity(
          reqresDetail(1),
          cachedAt: DateTime.now().subtract(const Duration(days: 30)),
        ),
      );
      when(network.isConnected).thenAnswer((_) async => true);
      when(
        api.fetchUserDetail('1'),
      ).thenThrow(const ServerException('boom', statusCode: 500));

      expect((await repository.getUserDetail('1')).isRight(), isTrue);
    });
  });

  group('getCachedUsers', () {
    test('exposes the whole cached corpus for the cold-start seed', () async {
      when(
        local.getAllCachedUsers(),
      ).thenReturn(<UserSummary>[reqresUser(1), reqresUser(2)]);

      expect(await repository.getCachedUsers(), hasLength(2));
    });

    test(
      'degrades to empty rather than throwing out of a cold start',
      () async {
        when(local.getAllCachedUsers()).thenThrow(const CacheException());

        expect(await repository.getCachedUsers(), isEmpty);
      },
    );
  });
}
