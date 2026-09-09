import 'dart:io';

import 'package:elyx_digital_assignment/core/constants/cache_constants.dart';
import 'package:elyx_digital_assignment/features/users/data/datasources/user_local_data_source.dart';
import 'package:elyx_digital_assignment/features/users/data/models/cached_page_model.dart';
import 'package:elyx_digital_assignment/features/users/data/models/user_detail_model.dart';
import 'package:elyx_digital_assignment/features/users/data/models/user_summary_model.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/paginated_users.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_summary.dart';
import 'package:elyx_digital_assignment/core/storage/hive_initializer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import '../../../../fixtures/fixture_reader.dart';

UserSummaryModel _u(int id, String login) => UserSummaryModel(
      id: id,
      login: login,
      avatarUrl: 'https://avatars.githubusercontent.com/u/$id?v=4',
      htmlUrl: 'https://github.com/$login',
      type: 'User',
      siteAdmin: false,
    );

/// Run against real Hive boxes in a temp directory rather than mocks: the
/// thing worth testing here IS the adapter round trip through disk.
void main() {
  late Directory tempDir;
  late Box<CachedPageModel> pagesBox;
  late Box<UserDetailModel> detailsBox;
  late UserLocalDataSourceImpl dataSource;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test');
    Hive.init(tempDir.path);
    HiveInitializer.registerAdaptersOnce();
    pagesBox = await Hive.openBox<CachedPageModel>(CacheConstants.usersPageBox);
    detailsBox =
        await Hive.openBox<UserDetailModel>(CacheConstants.userDetailBox);
    dataSource = UserLocalDataSourceImpl(
      pagesBox: pagesBox,
      detailsBox: detailsBox,
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  PaginatedUsers page(List<UserSummary> users, {int? nextSince}) =>
      PaginatedUsers.fromBatch(users: users, nextSince: nextSince);

  group('cache keys are derived from the CURSOR (constraint a)', () {
    test('the first batch uses page_first', () {
      expect(CacheConstants.usersPageKey(null), 'page_first');
    });

    test('a cursor batch uses page_<since>', () {
      expect(CacheConstants.usersPageKey(47), 'page_47');
    });

    test('different cursors never collide', () async {
      await dataSource.cacheUsersPage(
          null, page(<UserSummary>[_u(1, 'a')], nextSince: 1));
      await dataSource.cacheUsersPage(
          47, page(<UserSummary>[_u(48, 'b')], nextSince: 48));

      expect(dataSource.getCachedUsersPage(null)!.users.single.id, 1);
      expect(dataSource.getCachedUsersPage(47)!.users.single.id, 48);
    });
  });

  group('batches', () {
    test('round trip through the generated adapter', () async {
      await dataSource.cacheUsersPage(
        47,
        page(<UserSummary>[_u(48, 'defunkt')], nextSince: 48),
      );

      final CachedPageModel? cached = dataSource.getCachedUsersPage(47);

      expect(cached, isNotNull);
      expect(cached!.users.single.login, 'defunkt');
      expect(cached.nextSince, 48);
      expect(cached.requestedSince, 47);
      expect(cached.isStale(CacheConstants.pagesTtl), isFalse);
    });

    test('returns null on a miss', () {
      expect(dataSource.getCachedUsersPage(9999), isNull);
    });

    test('an empty batch is cached as a normal record, not skipped', () async {
      await dataSource.cacheUsersPage(999, page(const <UserSummary>[]));

      final CachedPageModel? cached = dataSource.getCachedUsersPage(999);

      expect(cached, isNotNull);
      expect(cached!.users, isEmpty);
      expect(cached.toEntity().hasReachedEnd, isTrue,
          reason: 'remembering the end avoids spending a request to rediscover it');
    });
  });

  group('profiles', () {
    test('round trip, stamped with a cache time', () async {
      final UserDetailModel detail =
          UserDetailModel.fromJson(fixtureMap('user_detail.json'));
      expect(detail.cachedAt, isNull, reason: 'unstamped before caching');

      await dataSource.cacheUserDetail(detail);
      final UserDetailModel? cached = dataSource.getCachedUserDetail('mojombo');

      expect(cached, isNotNull);
      expect(cached!.cachedAt, isNotNull);
      expect(cached.name, 'Tom Preston-Werner');
      expect(cached.email, isNull, reason: 'nulls survive the round trip');
      expect(cached.isStale(CacheConstants.detailsTtl), isFalse);
    });

    test('lookup is case-insensitive -- one GitHub user, one cache entry',
        () async {
      await dataSource.cacheUserDetail(
        UserDetailModel.fromJson(fixtureMap('user_detail.json')),
      );

      expect(dataSource.getCachedUserDetail('MoJoMbO'), isNotNull);
    });

    test('an unstamped record reads as stale rather than trusted forever', () {
      final UserDetailModel detail =
          UserDetailModel.fromJson(fixtureMap('user_detail.json'));

      expect(detail.isStale(CacheConstants.detailsTtl), isTrue);
    });
  });

  group('getAllCachedUsers', () {
    test('concatenates every batch in CURSOR order, not insertion order',
        () async {
      // Written deliberately out of order.
      await dataSource.cacheUsersPage(
          47, page(<UserSummary>[_u(48, 'c'), _u(49, 'd')], nextSince: 49));
      await dataSource.cacheUsersPage(
          null, page(<UserSummary>[_u(1, 'a'), _u(2, 'b')], nextSince: 2));
      await dataSource.cacheUsersPage(
          2, page(<UserSummary>[_u(3, 'e')], nextSince: 47));

      expect(
        dataSource.getAllCachedUsers().map((UserSummary u) => u.login),
        <String>['a', 'b', 'e', 'c', 'd'],
      );
    });

    test('deduplicates by id across overlapping batches', () async {
      await dataSource.cacheUsersPage(
          null, page(<UserSummary>[_u(1, 'a'), _u(2, 'b')], nextSince: 2));
      await dataSource.cacheUsersPage(
          2, page(<UserSummary>[_u(2, 'b'), _u(3, 'c')], nextSince: 3));

      expect(
        dataSource.getAllCachedUsers().map((UserSummary u) => u.id),
        <int>[1, 2, 3],
      );
    });

    test('is empty when nothing is cached', () {
      expect(dataSource.getAllCachedUsers(), isEmpty);
    });

    test('serves the offline search corpus regardless of staleness', () async {
      await pagesBox.put(
        CacheConstants.usersPageKey(null),
        CachedPageModel(
          users: <UserSummaryModel>[_u(1, 'ancient')],
          nextSince: 1,
          requestedSince: null,
          cachedAt: DateTime.now().subtract(const Duration(days: 30)),
        ),
      );

      expect(dataSource.getAllCachedUsers(), hasLength(1));
    });
  });

  group('clearAll', () {
    test('empties both boxes', () async {
      await dataSource.cacheUsersPage(
          null, page(<UserSummary>[_u(1, 'a')], nextSince: 1));
      await dataSource.cacheUserDetail(
        UserDetailModel.fromJson(fixtureMap('user_detail.json')),
      );

      await dataSource.clearAll();

      expect(dataSource.getCachedUsersPage(null), isNull);
      expect(dataSource.getCachedUserDetail('mojombo'), isNull);
      expect(dataSource.getAllCachedUsers(), isEmpty);
    });
  });
}
