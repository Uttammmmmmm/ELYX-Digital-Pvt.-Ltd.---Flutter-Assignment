library;

import 'package:hive_ce/hive.dart';

import '../../../../core/constants/cache_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/paginated_users.dart';
import '../../domain/entities/user_detail.dart';
import '../../domain/entities/user_summary.dart';
import '../models/cached_page_model.dart';
import '../models/user_detail_model.dart';

abstract interface class UserLocalDataSource {
  Future<void> cacheUsersPage(Object? cursor, PaginatedUsers page);

  CachedPageModel? getCachedUsersPage(Object? cursor);

  Future<void> cacheUserDetail(UserDetail detail);

  UserDetailModel? getCachedUserDetail(String detailId);

  List<UserSummary> getAllCachedUsers();

  Future<void> clearUsersPages();
}

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
    final List<CachedPageModel> pages = _pages.values.toList()
      ..sort(
        (CachedPageModel a, CachedPageModel b) =>
            _sortKey(a.requestedCursor).compareTo(_sortKey(b.requestedCursor)),
      );

    final Set<int> seen = <int>{};
    return <UserSummary>[
      for (final CachedPageModel page in pages)
        for (final UserSummary user in page.users)
          if (seen.add(user.id)) user,
    ];
  }

  @override
  Future<void> clearUsersPages() => _pages.clear();

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

        if (x == null) return -1;
        if (y == null) return 1;
        return x.compareTo(y);
      });

    await _details.deleteAll(byAge.take(overflow));
  }

  static Comparable<Object> _sortKey(Object? cursor) => switch (cursor) {
    null => -1,
    final int i => i,
    final Object o => o.toString(),
  };
}
