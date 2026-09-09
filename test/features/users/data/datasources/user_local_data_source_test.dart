import 'dart:io';

import 'package:elyx_digital_assignment/core/constants/cache_constants.dart';
import 'package:elyx_digital_assignment/core/storage/cache_entry.dart';
import 'package:elyx_digital_assignment/core/storage/json_box.dart';
import 'package:elyx_digital_assignment/features/users/data/datasources/user_local_data_source.dart';
import 'package:elyx_digital_assignment/features/users/data/models/github_user_detail_model.dart';
import 'package:elyx_digital_assignment/features/users/data/models/github_user_model.dart';
import 'package:elyx_digital_assignment/features/users/data/models/users_page_model.dart';
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

  const UsersPageModel page = UsersPageModel(
    users: <GithubUserModel>[
      GithubUserModel(
        id: 1,
        login: 'mojombo',
        avatarUrl: 'https://avatars.githubusercontent.com/u/1?v=4',
        htmlUrl: 'https://github.com/mojombo',
        type: 'User',
        isSiteAdmin: false,
      ),
    ],
    nextCursor: 1,
  );

  group('users pages', () {
    test('round trips through disk and stamps a cache time', () async {
      await dataSource.cacheUsersPage(null, page);

      final CacheEntry<UsersPageModel>? entry = dataSource.readUsersPage(null);

      expect(entry, isNotNull);
      expect(entry!.value, page);
      expect(entry.isStale(CacheConstants.usersPageTtl), isFalse);
    });

    test('keys pages by cursor, so pages do not overwrite each other', () async {
      await dataSource.cacheUsersPage(null, page);
      await dataSource.cacheUsersPage(
        46,
        const UsersPageModel(users: <GithubUserModel>[], nextCursor: 99),
      );

      expect(dataSource.readUsersPage(null)!.value.nextCursor, 1);
      expect(dataSource.readUsersPage(46)!.value.nextCursor, 99);
    });

    test('returns null on a miss', () {
      expect(dataSource.readUsersPage(12345), isNull);
    });

    test('reports stale once past the TTL', () async {
      await JsonBox(pagesBox).write(
        CacheConstants.usersPageKey(null),
        page.toJson(),
        now: DateTime.now().subtract(const Duration(hours: 2)),
      );

      final CacheEntry<UsersPageModel> entry = dataSource.readUsersPage(null)!;

      expect(entry.isStale(CacheConstants.usersPageTtl), isTrue);
      expect(entry.value, page, reason: 'stale is still readable');
    });

    test('a corrupt entry reads as a miss instead of throwing', () async {
      await pagesBox.put(CacheConstants.usersPageKey(null), 'not json{{{');

      expect(dataSource.readUsersPage(null), isNull);
    });
  });

  group('user details', () {
    test('round trips and is retrievable case-insensitively', () async {
      final GithubUserDetailModel detail =
          GithubUserDetailModel.fromJson(fixtureMap('user_detail.json'));

      await dataSource.cacheUserDetail(detail);

      expect(dataSource.readUserDetail('MoJoMbO')!.value, detail);
    });

    test('displayNames builds the sparse login -> name index (constraint e)',
        () async {
      await dataSource.cacheUserDetail(
        GithubUserDetailModel.fromJson(fixtureMap('user_detail.json')),
      );
      await dataSource.cacheUserDetail(
        GithubUserDetailModel.fromJson(fixtureMap('user_detail_sparse.json')),
      );

      final Map<String, String> names = dataSource.displayNames();

      expect(names, <String, String>{'mojombo': 'Tom Preston-Werner'});
      expect(names.containsKey('ghost'), isFalse,
          reason: 'a null name contributes nothing to search');
    });
  });

  group('clearUsersPages', () {
    test('empties pages but preserves expensive detail documents', () async {
      await dataSource.cacheUsersPage(null, page);
      await dataSource.cacheUserDetail(
        GithubUserDetailModel.fromJson(fixtureMap('user_detail.json')),
      );

      await dataSource.clearUsersPages();

      expect(dataSource.readUsersPage(null), isNull);
      expect(dataSource.readUserDetail('mojombo'), isNotNull);
    });
  });
}
