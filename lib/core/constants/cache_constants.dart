/// Hive box names and staleness policy.
library;

/// Cache configuration: where things are stored and how long they stay fresh.
abstract final class CacheConstants {
  /// Cursor-keyed list pages. Churns as GitHub gains users.
  static const String usersPageBox = 'users_pages_box';

  /// Login-keyed user detail documents. Near-static.
  static const String userDetailBox = 'user_detail_box';

  /// List pages go stale quickly -- they are a moving window over a growing
  /// dataset, and a refresh is one cheap request.
  static const Duration usersPageTtl = Duration(minutes: 15);

  /// Detail documents change rarely (bio, location, repo counts), and each
  /// refetch costs a request from a 60/hour budget. Constraint (d).
  static const Duration userDetailTtl = Duration(hours: 24);

  /// Cache key for a list page. The first page has no cursor.
  static String usersPageKey(int? cursor) =>
      cursor == null ? 'page:first' : 'page:$cursor';

  /// Cache key for a user detail document.
  static String userDetailKey(String login) => 'user:${login.toLowerCase()}';
}
