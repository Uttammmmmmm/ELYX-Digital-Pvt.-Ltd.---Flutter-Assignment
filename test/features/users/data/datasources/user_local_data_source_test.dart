import 'dart:io';

import 'package:elyx_digital_assignment/core/constants/cache_constants.dart';
import 'package:elyx_digital_assignment/core/storage/hive_initializer.dart';
import 'package:elyx_digital_assignment/features/users/data/datasources/user_local_data_source.dart';
import 'package:elyx_digital_assignment/features/users/data/models/cached_page_model.dart';
import 'package:elyx_digital_assignment/features/users/data/models/user_detail_model.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/paginated_users.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_summary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import '../../../../helpers/entity_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<CachedPageModel> pagesBox;
  late Box<UserDetailModel> detailsBox;
  late UserLocalDataSourceImpl dataSource;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test');
    Hive.init(tempDir.path);
    HiveInitializer.registerAdaptersOnce();
    pagesBox = await Hive.openBox<CachedPageModel>(CacheConstants.usersPageBox);
    detailsBox = await Hive.openBox<UserDetailModel>(
      CacheConstants.userDetailBox,
    );
    dataSource = UserLocalDataSourceImpl(
      pagesBox: pagesBox,
      detailsBox: detailsBox,
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  PaginatedUsers page(List<UserSummary> users, {Object? nextCursor}) =>
      PaginatedUsers.fromBatch(users: users, nextCursor: nextCursor);

  group('cache keys derive from the CURSOR', () {
    test('the first batch uses page_first', () {
      expect(CacheConstants.usersPageKey(null), 'page_first');
    });

    test('a cursor batch embeds the cursor, whatever its shape', () {
      expect(CacheConstants.usersPageKey(2), 'page_2');
      expect(CacheConstants.usersPageKey(2868), 'page_2868');
    });

    test('different cursors never collide', () async {
      await dataSource.cacheUsersPage(
        null,
        page(<UserSummary>[reqresUser(1)], nextCursor: 2),
      );
      await dataSource.cacheUsersPage(
        2,
        page(<UserSummary>[reqresUser(7)], nextCursor: null),
      );

      expect(dataSource.getCachedUsersPage(null)!.users.single.id, 1);
      expect(dataSource.getCachedUsersPage(2)!.users.single.id, 7);
    });
  });

  group('batches', () {
    test('round trip through the generated adapter', () async {
      await dataSource.cacheUsersPage(
        1,
        page(<UserSummary>[reqresUser(2, first: 'Janet')], nextCursor: 2),
      );

      final CachedPageModel? cached = dataSource.getCachedUsersPage(1);

      expect(cached, isNotNull);
      expect(cached!.users.single.displayName, startsWith('Janet'));
      expect(cached.users.single.email, isNotNull);
      expect(cached.nextCursor, 2);
      expect(cached.requestedCursor, 1);
      expect(cached.isStale(CacheConstants.pagesTtl), isFalse);
    });

    test('returns null on a miss', () {
      expect(dataSource.getCachedUsersPage(9999), isNull);
    });

    test('an empty batch is cached as a normal record, not skipped', () async {
      await dataSource.cacheUsersPage(3, page(const <UserSummary>[]));

      final CachedPageModel? cached = dataSource.getCachedUsersPage(3);
      expect(cached, isNotNull);
      expect(cached!.toEntity().hasReachedEnd, isTrue);
    });
  });

  group('profiles', () {
    test('round trip, stamped with a cache time', () async {
      await dataSource.cacheUserDetail(reqresDetail(2, first: 'Janet'));

      final UserDetailModel? cached = dataSource.getCachedUserDetail('2');

      expect(cached, isNotNull);
      expect(cached!.cachedAt, isNotNull);
      expect(cached.displayName, startsWith('Janet'));
      expect(cached.hasEmail, isTrue);
      expect(cached.isStale(CacheConstants.detailsTtl), isFalse);
    });

    test('a GitHub-shaped profile keeps its extras', () async {
      await dataSource.cacheUserDetail(
        githubDetail(1, 'mojombo', bio: 'Cofounder', location: 'SF'),
      );

      final UserDetailModel cached = dataSource.getCachedUserDetail('mojombo')!;

      expect(cached.bio, 'Cofounder');
      expect(cached.hasStats, isTrue);
      expect(cached.followers, 23000);
    });

    test('lookup is case-insensitive -- one user, one cache entry', () async {
      await dataSource.cacheUserDetail(githubDetail(1, 'mojombo'));

      expect(dataSource.getCachedUserDetail('MoJoMbO'), isNotNull);
    });
  });

  group('detail cache is bounded', () {
    test('entries past the TTL are evicted on the next write', () async {
      await detailsBox.put(
        'stale-one',
        UserDetailModel.fromEntity(
          reqresDetail(99),
          cachedAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      );
      expect(detailsBox.length, 1);

      await dataSource.cacheUserDetail(reqresDetail(1));

      expect(
        detailsBox.containsKey('stale-one'),
        isFalse,
        reason: 'expired entries would be refetched anyway -- dead weight',
      );
      expect(dataSource.getCachedUserDetail('1'), isNotNull);
    });

    test('oldest-by-write are evicted above the ceiling', () async {
      final DateTime base = DateTime.now();
      for (int i = 0; i < CacheConstants.maxCachedDetails + 10; i++) {
        await detailsBox.put(
          'user-$i',
          UserDetailModel.fromEntity(
            reqresDetail(i),
            cachedAt: base.subtract(Duration(minutes: 300 - i)),
          ),
        );
      }

      await dataSource.cacheUserDetail(reqresDetail(9999));

      expect(
        detailsBox.length,
        lessThanOrEqualTo(CacheConstants.maxCachedDetails),
      );
      expect(dataSource.getCachedUserDetail('9999'), isNotNull);
      expect(detailsBox.containsKey('user-0'), isFalse);
    });

    test('a cache under the ceiling is left alone', () async {
      await dataSource.cacheUserDetail(reqresDetail(1));
      await dataSource.cacheUserDetail(reqresDetail(2));

      expect(detailsBox.length, 2);
    });
  });

  group('getAllCachedUsers', () {
    test(
      'concatenates every batch in CURSOR order, not insertion order',
      () async {
        await dataSource.cacheUsersPage(
          2,
          page(<UserSummary>[reqresUser(7), reqresUser(8)], nextCursor: 3),
        );
        await dataSource.cacheUsersPage(
          null,
          page(<UserSummary>[reqresUser(1), reqresUser(2)], nextCursor: 2),
        );

        expect(
          dataSource.getAllCachedUsers().map((UserSummary u) => u.id),
          <int>[1, 2, 7, 8],
        );
      },
    );

    test('deduplicates by id across overlapping batches', () async {
      await dataSource.cacheUsersPage(
        null,
        page(<UserSummary>[reqresUser(1), reqresUser(2)], nextCursor: 2),
      );
      await dataSource.cacheUsersPage(
        2,
        page(<UserSummary>[reqresUser(2), reqresUser(3)], nextCursor: null),
      );

      expect(dataSource.getAllCachedUsers().map((UserSummary u) => u.id), <int>[
        1,
        2,
        3,
      ]);
    });

    test('is empty when nothing is cached', () {
      expect(dataSource.getAllCachedUsers(), isEmpty);
    });

    test('serves the offline search corpus regardless of staleness', () async {
      await pagesBox.put(
        CacheConstants.usersPageKey(null),
        CachedPageModel.fromEntity(
          page(<UserSummary>[reqresUser(1)], nextCursor: 2),
          requestedCursor: null,
          now: DateTime.now().subtract(const Duration(days: 30)),
        ),
      );

      expect(dataSource.getAllCachedUsers(), hasLength(1));
    });
  });

  group('clearing', () {
    test('clearUsersPages empties batches but preserves profiles', () async {
      await dataSource.cacheUsersPage(
        null,
        page(<UserSummary>[reqresUser(1)], nextCursor: 2),
      );
      await dataSource.cacheUserDetail(reqresDetail(1));

      await dataSource.clearUsersPages();

      expect(dataSource.getCachedUsersPage(null), isNull);
      expect(dataSource.getCachedUserDetail('1'), isNotNull);
    });

    test('clearAll empties both', () async {
      await dataSource.cacheUsersPage(
        null,
        page(<UserSummary>[reqresUser(1)], nextCursor: 2),
      );
      await dataSource.cacheUserDetail(reqresDetail(1));

      await dataSource.clearAll();

      expect(dataSource.getAllCachedUsers(), isEmpty);
      expect(dataSource.getCachedUserDetail('1'), isNull);
    });
  });
}
