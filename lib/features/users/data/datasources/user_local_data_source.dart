/// Hive-backed cache for users batches and detail documents.
library;

import '../../../../core/constants/cache_constants.dart';
import '../../../../core/storage/cache_entry.dart';
import '../../../../core/storage/json_box.dart';
import '../models/paginated_users_model.dart';
import '../models/user_detail_model.dart';

/// Reads and writes cached users data.
abstract interface class UserLocalDataSource {
  /// Cached batch for [since], or null on a miss.
  CacheEntry<PaginatedUsersModel>? readUsersPage(int? since);

  /// Stores [page] under [since].
  Future<void> cacheUsersPage(int? since, PaginatedUsersModel page);

  /// Cached profile for [login], or null on a miss.
  CacheEntry<UserDetailModel>? readUserDetail(String login);

  /// Stores [detail].
  Future<void> cacheUserDetail(UserDetailModel detail);

  /// Drops all cached batches, leaving detail documents intact.
  Future<void> clearUsersPages();
}

/// [UserLocalDataSource] over two [JsonBox] instances.
///
/// Two boxes, not one, because the TTLs differ by three orders of magnitude:
/// batches are a moving window (15 min) while profiles are near-static (24 h).
/// Sharing a box would force one policy on both and make a refresh wipe
/// expensive detail data it has no reason to touch.
class UserLocalDataSourceImpl implements UserLocalDataSource {
  const UserLocalDataSourceImpl({
    required JsonBox pagesBox,
    required JsonBox detailBox,
  })  : _pages = pagesBox,
        _details = detailBox;

  final JsonBox _pages;
  final JsonBox _details;

  @override
  CacheEntry<PaginatedUsersModel>? readUsersPage(int? since) {
    final CacheEntry<Object?>? entry =
        _pages.read(CacheConstants.usersPageKey(since));
    final Object? value = entry?.value;
    if (entry == null || value is! Map<String, dynamic>) return null;

    return entry.map((_) => PaginatedUsersModel.fromJson(value));
  }

  @override
  Future<void> cacheUsersPage(int? since, PaginatedUsersModel page) =>
      _pages.write(CacheConstants.usersPageKey(since), page.toJson());

  @override
  CacheEntry<UserDetailModel>? readUserDetail(String login) {
    final CacheEntry<Object?>? entry =
        _details.read(CacheConstants.userDetailKey(login));
    final Object? value = entry?.value;
    if (entry == null || value is! Map<String, dynamic>) return null;

    return entry.map((_) => UserDetailModel.fromJson(value));
  }

  @override
  Future<void> cacheUserDetail(UserDetailModel detail) => _details.write(
        CacheConstants.userDetailKey(detail.login),
        detail.toJson(),
      );

  @override
  Future<void> clearUsersPages() => _pages.clear();
}
