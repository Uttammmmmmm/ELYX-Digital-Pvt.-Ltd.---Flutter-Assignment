import 'dart:io';

import 'package:elyx_digital_assignment/core/constants/cache_constants.dart';
import 'package:elyx_digital_assignment/core/storage/cache_entry.dart';
import 'package:elyx_digital_assignment/core/storage/json_box.dart';
import 'package:elyx_digital_assignment/features/users/data/datasources/user_local_data_source.dart';
import 'package:elyx_digital_assignment/features/users/data/models/paginated_users_model.dart';
import 'package:elyx_digital_assignment/features/users/data/models/user_detail_model.dart';
import 'package:elyx_digital_assignment/features/users/data/models/user_summary_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../../../../fixtures/fixture_reader.dart';

/// Exercised against a real Hive box in a temp directory rather than a mock:
/// the thing worth testing here IS the JSON round trip through disk.
void main() {
  late Directory tempDir;
  late Box<String> pagesBox;
  late Box<String> detailBox;
  late UserLocalDataSourceImpl dataSource;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test');
    Hive.init(tempDir.path);
    pagesBox = await Hive.openBox<String>(CacheConstants.usersPageBox);
    detailBox = await Hive.openBox<String>(CacheConstants.userDetailBox);
    dataSource = UserLocalDataSourceImpl(
      pagesBox: JsonBox(pagesBox),
      detailBox: JsonBox(detailBox),
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  const PaginatedUsersModel page = PaginatedUsersModel(
    users: <UserSummaryModel>[
      UserSummaryModel(
        id: 1,
        login: 'mojombo',
        avatarUrl: 'https://avatars.githubusercontent.com/u/1?v=4',
        htmlUrl: 'https://github.com/mojombo',
        type: 'User',
        siteAdmin: false,
      ),
    ],
    nextSince: 1,
    hasReachedEnd: false,
  );

  group('users batches', () {
    test('round trips through disk and stamps a cache time', () async {
      await dataSource.cacheUsersPage(null, page);

      final CacheEntry<PaginatedUsersModel>? entry =
          dataSource.readUsersPage(null);

      expect(entry, isNotNull);
      expect(entry!.value, page);
      expect(entry.isStale(CacheConstants.usersPageTtl), isFalse);
    });

    test('keys batches by cursor, so they do not overwrite each other',
        () async {
      await dataSource.cacheUsersPage(null, page);
      await dataSource.cacheUsersPage(
        46,
        const PaginatedUsersModel(
          users: <UserSummaryModel>[],
          nextSince: 99,
          hasReachedEnd: false,
        ),
      );

      expect(dataSource.readUsersPage(null)!.value.nextSince, 1);
      expect(dataSource.readUsersPage(46)!.value.nextSince, 99);
    });

    test('returns null on a miss', () {
      expect(dataSource.readUsersPage(12345), isNull);
    });

    test('reports stale once past the TTL, but stays readable', () async {
      await JsonBox(pagesBox).write(
        CacheConstants.usersPageKey(null),
        page.toJson(),
        now: DateTime.now().subtract(const Duration(hours: 2)),
      );

      final CacheEntry<PaginatedUsersModel> entry =
          dataSource.readUsersPage(null)!;

      expect(entry.isStale(CacheConstants.usersPageTtl), isTrue);
      expect(entry.value, page, reason: 'stale is still usable');
    });

    test('a corrupt entry reads as a miss instead of throwing', () async {
      await pagesBox.put(CacheConstants.usersPageKey(null), 'not json{{{');

      expect(dataSource.readUsersPage(null), isNull);
    });
  });

  group('user details', () {
    test('round trips and is retrievable case-insensitively', () async {
      final UserDetailModel detail =
          UserDetailModel.fromJson(fixtureMap('user_detail.json'));

      await dataSource.cacheUserDetail(detail);

      expect(dataSource.readUserDetail('MoJoMbO')!.value, detail);
    });

    test('preserves nulls across the round trip (constraint c)', () async {
      final UserDetailModel detail =
          UserDetailModel.fromJson(fixtureMap('user_detail.json'));

      await dataSource.cacheUserDetail(detail);
      final UserDetailModel restored =
          dataSource.readUserDetail('mojombo')!.value;

      expect(restored.email, isNull);
      expect(restored.bio, isNull);
      expect(restored.name, 'Tom Preston-Werner');
    });
  });

  group('clearUsersPages', () {
    test('empties batches but preserves expensive detail documents', () async {
      await dataSource.cacheUsersPage(null, page);
      await dataSource.cacheUserDetail(
        UserDetailModel.fromJson(fixtureMap('user_detail.json')),
      );

      await dataSource.clearUsersPages();

      expect(dataSource.readUsersPage(null), isNull);
      expect(dataSource.readUserDetail('mojombo'), isNotNull);
    });
  });
}
