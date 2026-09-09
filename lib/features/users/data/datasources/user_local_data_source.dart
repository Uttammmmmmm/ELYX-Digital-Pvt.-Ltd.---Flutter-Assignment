/// Hive-backed cache for users batches and profile documents.
library;

import 'package:hive_ce/hive.dart';

import '../../../../core/constants/cache_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/paginated_users.dart';
import '../../domain/entities/user_detail.dart';
import '../../domain/entities/user_summary.dart';
import '../models/cached_page_model.dart';
import '../models/user_detail_model.dart';

/// Reads and writes cached users data.
///
/// Stores and retrieves. It applies no policy: it does not decide when to
/// prefer the cache or when to refresh -- it only reports age and lets the
/// repository decide. Eviction is the one exception, because a size ceiling
/// is a property of the store itself.
abstract interface class UserLocalDataSource {
  /// Stores [page], recording which cursor requested it.
  Future<void> cacheUsersPage(Object? cursor, PaginatedUsers page);

  /// The cached batch for [cursor], or null on a miss. May be stale.
  CachedPageModel? getCachedUsersPage(Object? cursor);

  /// Stores [detail], stamped with the current time, then evicts.
  Future<void> cacheUserDetail(UserDetail detail);

  /// The cached profile for [detailId], or null on a miss. May be stale.
  UserDetailModel? getCachedUserDetail(String detailId);

  /// Every cached user across all batches, in cursor order, deduplicated.
  List<UserSummary> getAllCachedUsers();

  /// Drops cached batches, leaving profile documents intact.
  Future<void> clearUsersPages();

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
  }) : _pages = pagesBox,
       _details = detailsBox;

  final Box<CachedPageModel> _pages;
  final Box<UserDetailModel> _details;

  @override
  Future<void> cacheUsersPage(Object? cursor, PaginatedUsers page) async {
    try {
      await _pages.put(
        CacheConstants.usersPageKey(cursor),
        CachedPageModel.fromEntity(page, requestedCursor: cursor),
      );
    } catch (e) {
      // A failed WRITE is worth surfacing: it means offline support is
      // silently broken. A failed read is not -- that is just a miss.
      throw CacheException('Failed to cache batch cursor=$cursor: $e');
    }
  }

  @override
  CachedPageModel? getCachedUsersPage(Object? cursor) =>
      _pages.get(CacheConstants.usersPageKey(cursor));

  @override
  Future<void> cacheUserDetail(UserDetail detail) async {
    try {
      await _details.put(
        CacheConstants.userDetailKey(detail.user.detailId),
        UserDetailModel.fromEntity(detail, cachedAt: DateTime.now()),
      );
      await _evictDetails();
    } catch (e) {
      throw CacheException(
        'Failed to cache profile ${detail.user.detailId}: $e',
      );
    }
  }

  @override
  UserDetailModel? getCachedUserDetail(String detailId) =>
      _details.get(CacheConstants.userDetailKey(detailId));

  @override
  List<UserSummary> getAllCachedUsers() {
    // Cursor order, not Hive key order. Hive returns keys in insertion order,
    // which after a refresh or an out-of-order retry no longer matches the
    // sequence the API paginates in. Sorting by the cursor that REQUESTED
    // each batch reconstructs the true order; the first batch (null cursor)
    // sorts first because -1 precedes every real cursor value.
    final List<CachedPageModel> pages = _pages.values.toList()
      ..sort(
        (CachedPageModel a, CachedPageModel b) =>
            _sortKey(a.requestedCursor).compareTo(_sortKey(b.requestedCursor)),
      );

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
  Future<void> clearUsersPages() => _pages.clear();

  @override
  Future<void> clearAll() async {
    await _pages.clear();
    await _details.clear();
  }

  /// Keeps the profile cache bounded.
  ///
  /// Two passes, in this order: drop anything past its TTL (it would be
  /// refetched anyway, so it is pure dead weight), then, if still over the
  /// ceiling, drop oldest-by-write until under it. Without this the box gains
  /// an entry per profile viewed and never loses one.
  Future<void> _evictDetails({DateTime? now}) async {
    final DateTime at = now ?? DateTime.now();

    final List<dynamic> expired = <dynamic>[
      for (final dynamic key in _details.keys)
        if (_details.get(key)?.isStale(CacheConstants.detailsTtl, now: at) ??
            false)
          key,
    ];
    if (expired.isNotEmpty) await _details.deleteAll(expired);

    final int overflow = _details.length - CacheConstants.maxCachedDetails;
    if (overflow <= 0) return;

    final List<dynamic> byAge = _details.keys.toList()
      ..sort((dynamic a, dynamic b) {
        final DateTime? x = _details.get(a)?.cachedAt;
        final DateTime? y = _details.get(b)?.cachedAt;
        // Unstamped entries are the oldest thing we can know about.
        if (x == null) return -1;
        if (y == null) return 1;
        return x.compareTo(y);
      });

    await _details.deleteAll(byAge.take(overflow));
  }

  /// Orders cursors of either shape. Ints sort naturally; anything else falls
  /// back to its string form, which at least keeps the order stable.
  static Comparable<Object> _sortKey(Object? cursor) => switch (cursor) {
    null => -1,
    final int i => i,
    final Object o => o.toString(),
  };
}
