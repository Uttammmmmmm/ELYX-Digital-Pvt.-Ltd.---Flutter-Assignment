/// Hive box names, cache keys and staleness policy.
library;

/// Cache configuration: where things are stored and how long they stay fresh.
abstract final class CacheConstants {
  /// Bumped whenever a persisted model's field layout changes.
  ///
  /// Hive stores raw field indices, so reading a v1 record with a v2 adapter
  /// silently reinterprets bytes as the wrong fields. Rather than crash on
  /// read -- or worse, render garbage -- the boxes are dropped and refetched
  /// when this does not match what is on disk. The cache is by definition
  /// reconstructible, so discarding it is always cheaper than a corrupt read.
  static const int schemaVersion = 4;

  /// Box holding the schema version and other small metadata.
  static const String metaBox = 'meta_box';

  /// Key of [schemaVersion] inside [metaBox].
  static const String schemaVersionKey = 'schema_version';

  /// Cursor-keyed batches of the users list.
  static const String usersPageBox = 'users_pages_box';

  /// Detail-id-keyed profile documents.
  static const String userDetailBox = 'user_detail_box';

  /// Batches go stale quickly: a moving window over a dataset that changes,
  /// and refreshing one costs a single request.
  static const Duration pagesTtl = Duration(minutes: 15);

  /// Profiles change rarely, and each refetch costs a request.
  static const Duration detailsTtl = Duration(hours: 6);

  /// Hard ceiling on cached profiles.
  ///
  /// The detail cache gains an entry per profile viewed and nothing ever
  /// removed one, so it grew without bound. A TTL controls freshness, not
  /// size. Oldest-by-write are evicted past this.
  static const int maxCachedDetails = 200;

  /// Cache key for a batch, derived from the CURSOR that requested it.
  ///
  /// WHY NOT A PAGE INDEX: for the GitHub source the cursor is a user id, and
  /// "page 3" is not a stable identity -- it means "whatever the third hop
  /// landed on", which changes when a user is created or deleted upstream.
  /// Keying by the cursor makes the entry self-describing and collision-free
  /// for both sources.
  static String usersPageKey(Object? cursor) =>
      cursor == null ? 'page_first' : 'page_$cursor';

  /// Cache key for a profile. Lower-cased because GitHub logins are
  /// case-insensitive, so `/users/MojomBo` and `/users/mojombo` are one
  /// resource and must not occupy two entries.
  static String userDetailKey(String detailId) => detailId.toLowerCase();
}
