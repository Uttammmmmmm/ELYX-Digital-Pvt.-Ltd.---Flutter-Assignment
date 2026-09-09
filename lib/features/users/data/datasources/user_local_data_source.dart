/// Hive-backed cache for users batches and profile documents.
library;

import 'package:hive_ce/hive.dart';

import '../../../../core/constants/cache_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/paginated_users.dart';
import '../../domain/entities/user_summary.dart';
import '../models/cached_page_model.dart';
import '../models/user_detail_model.dart';

/// Reads and writes cached users data.
///
/// Stores and retrieves. It applies no policy: it does not decide when to
/// prefer the cache, when to refresh, or what a stale record means -- it only
/// reports age and lets the repository decide.
abstract interface class UserLocalDataSource {
  /// Stores [page], recording which cursor requested it.
  Future<void> cacheUsersPage(int? since, PaginatedUsers page);

  /// The cached batch for [since], or null on a miss. May be stale; the
  /// caller inspects [CachedPageModel.isStale].
  CachedPageModel? getCachedUsersPage(int? since);

  /// Stores [detail], stamped with the current time.
  Future<void> cacheUserDetail(UserDetailModel detail);

  /// The cached profile for [login], or null on a miss. May be stale.
  UserDetailModel? getCachedUserDetail(String login);

  /// Every cached user across all batches, in cursor order, deduplicated.
  List<UserSummary> getAllCachedUsers();

  /// Empties both boxes.
  Future<void> clearAll();
}

/// [UserLocalDataSource] over two typed Hive boxes.
///
/// Two boxes rather than one because the TTLs differ by more than an order of
/// magnitude -- batches 15 minutes, profiles 6 hours -- and because a refresh
/// must be able to drop batches without destroying profile documents, which
/// are far more expensive to rebuild.
class UserLocalDataSourceImpl implements UserLocalDataSource {
  const UserLocalDataSourceImpl({
    required Box<CachedPageModel> pagesBox,
    required Box<UserDetailModel> detailsBox,
  })  : _pages = pagesBox,
        _details = detailsBox;

  final Box<CachedPageModel> _pages;
  final Box<UserDetailModel> _details;

  @override
  Future<void> cacheUsersPage(int? since, PaginatedUsers page) async {
    try {
      await _pages.put(
        CacheConstants.usersPageKey(since),
        CachedPageModel.fromEntity(page, requestedSince: since),
      );
    } catch (e) {
      // A failed WRITE is worth surfacing: it means offline support is
      // silently broken. A failed read is not -- that is just a miss.
      throw CacheException('Failed to cache batch since=$since: $e');
    }
  }

  @override
  CachedPageModel? getCachedUsersPage(int? since) =>
      _pages.get(CacheConstants.usersPageKey(since));

  @override
  Future<void> cacheUserDetail(UserDetailModel detail) async {
    try {
      await _details.put(
        CacheConstants.userDetailKey(detail.login),
        detail.withCacheStamp(),
      );
    } catch (e) {
      throw CacheException('Failed to cache profile ${detail.login}: $e');
    }
  }

  @override
  UserDetailModel? getCachedUserDetail(String login) =>
      _details.get(CacheConstants.userDetailKey(login));

  @override
  List<UserSummary> getAllCachedUsers() {
    // Cursor order, not Hive key order. Hive returns keys in insertion order,
    // which after a refresh or an out-of-order retry no longer matches the
    // sequence GitHub paginates in. Sorting by the cursor that REQUESTED each
    // batch reconstructs the true order; the first batch (null cursor) sorts
    // first because -1 precedes every real user id.
    final List<CachedPageModel> pages = _pages.values.toList()
      ..sort((CachedPageModel a, CachedPageModel b) =>
          (a.requestedSince ?? -1).compareTo(b.requestedSince ?? -1));

    // Deduplicate by id: overlapping batches are normal after a refresh, and
    // a duplicate would break a keyed list and inflate the search corpus.
    final Set<int> seen = <int>{};
    return <UserSummary>[
      for (final CachedPageModel page in pages)
        for (final UserSummary user in page.users)
          if (seen.add(user.id)) user,
    ];
  }

  @override
  Future<void> clearAll() async {
    await _pages.clear();
    await _details.clear();
  }
}
