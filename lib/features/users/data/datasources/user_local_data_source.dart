/// Hive-backed cache for users list pages and detail documents.
library;

import '../../../../core/constants/cache_constants.dart';
import '../../../../core/storage/cache_entry.dart';
import '../../../../core/storage/json_box.dart';
import '../models/github_user_detail_model.dart';
import '../models/users_page_model.dart';

/// Reads and writes cached users data.
abstract interface class UserLocalDataSource {
  /// Cached page for [cursor], or null on a miss.
  CacheEntry<UsersPageModel>? readUsersPage(int? cursor);

  /// Stores [page] under [cursor].
  Future<void> cacheUsersPage(int? cursor, UsersPageModel page);

  /// Cached profile for [login], or null on a miss.
  CacheEntry<GithubUserDetailModel>? readUserDetail(String login);

  /// Stores [detail].
  Future<void> cacheUserDetail(GithubUserDetailModel detail);

  /// `login -> name` for every cached detail document that has a name.
  Map<String, String> displayNames();

  /// Drops all cached list pages, leaving detail documents intact.
  Future<void> clearUsersPages();
}

/// [UserLocalDataSource] over two [JsonBox] instances.
///
/// Two boxes, not one, because the TTLs differ by three orders of magnitude:
/// list pages are a moving window (15 min) while profiles are near-static
/// (24 h). Sharing a box would force a single policy on both and make
/// pull-to-refresh wipe expensive detail data it has no reason to touch.
class UserLocalDataSourceImpl implements UserLocalDataSource {
  const UserLocalDataSourceImpl({
    required JsonBox pagesBox,
    required JsonBox detailBox,
  })  : _pages = pagesBox,
        _details = detailBox;

  final JsonBox _pages;
  final JsonBox _details;

  @override
  CacheEntry<UsersPageModel>? readUsersPage(int? cursor) {
    final CacheEntry<Object?>? entry =
        _pages.read(CacheConstants.usersPageKey(cursor));
    final Object? value = entry?.value;
    if (entry == null || value is! Map<String, dynamic>) return null;

    return entry.map((_) => UsersPageModel.fromJson(value));
  }

  @override
  Future<void> cacheUsersPage(int? cursor, UsersPageModel page) =>
      _pages.write(CacheConstants.usersPageKey(cursor), page.toJson());

  @override
  CacheEntry<GithubUserDetailModel>? readUserDetail(String login) {
    final CacheEntry<Object?>? entry =
        _details.read(CacheConstants.userDetailKey(login));
    final Object? value = entry?.value;
    if (entry == null || value is! Map<String, dynamic>) return null;

    return entry.map((_) => GithubUserDetailModel.fromJson(value));
  }

  @override
  Future<void> cacheUserDetail(GithubUserDetailModel detail) => _details.write(
        CacheConstants.userDetailKey(detail.login),
        detail.toJson(),
      );

  @override
  Map<String, String> displayNames() {
    final Map<String, String> names = <String, String>{};

    for (final String key in _details.keys) {
      final CacheEntry<Object?>? entry = _details.read(key);
      final Object? value = entry?.value;
      if (value is! Map<String, dynamic>) continue;

      final Object? login = value['login'];
      final Object? name = value['name'];
      if (login is! String || name is! String || name.trim().isEmpty) continue;

      names[login.toLowerCase()] = name;
    }
    return names;
  }

  @override
  Future<void> clearUsersPages() => _pages.clear();
}
