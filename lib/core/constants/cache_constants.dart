/// Hive box names, cache keys and staleness policy.
library;

/// Cache configuration: where things are stored and how long they stay fresh.
abstract final class CacheConstants {
  /// Cursor-keyed batches of the users list.
  static const String usersPageBox = 'users_pages_box';

  /// Login-keyed profile documents.
  static const String userDetailBox = 'user_detail_box';

  /// Batches go stale quickly: they are a moving window over a dataset that
  /// grows constantly, and refreshing one costs a single request.
  static const Duration pagesTtl = Duration(minutes: 15);

  /// Profiles change rarely -- bio, location, repo counts -- and each refetch
  /// costs one of 60 hourly requests. Constraint (d).
  static const Duration detailsTtl = Duration(hours: 6);

  /// Cache key for a batch, derived from the CURSOR that requested it.
  ///
  /// WHY NOT A PAGE INDEX: `GET /users` is cursor-paginated via `since`, and
  /// `page` is silently ignored (constraint a). "Page 3" is not a stable
  /// identity -- it means "whatever the third hop happened to land on", which
  /// changes the moment a new user is created or an account is deleted
  /// upstream. Keying by index would therefore let a cached batch be returned
  /// for a request that would now yield entirely different users, and two
  /// different cursors could collide on one key. The cursor IS the identity
  /// of the request, so it is the only correct key. It also makes the cache
  /// self-describing: `page_47` says exactly which request produced it.
  static String usersPageKey(int? since) =>
      since == null ? 'page_first' : 'page_$since';

  /// Cache key for a profile. Lower-cased because GitHub logins are
  /// case-insensitive, so `/users/MojomBo` and `/users/mojombo` are one
  /// resource and must not occupy two cache entries.
  static String userDetailKey(String login) => login.toLowerCase();
}
