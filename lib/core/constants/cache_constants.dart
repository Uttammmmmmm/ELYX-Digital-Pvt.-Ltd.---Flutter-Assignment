library;

abstract final class CacheConstants {
  static const int schemaVersion = 4;

  static const String metaBox = 'meta_box';

  static const String schemaVersionKey = 'schema_version';

  static const String usersPageBox = 'users_pages_box';

  static const String userDetailBox = 'user_detail_box';

  static const Duration pagesTtl = Duration(minutes: 15);

  static const Duration detailsTtl = Duration(hours: 6);

  static const int maxCachedDetails = 200;

  static String usersPageKey(Object? cursor) =>
      cursor == null ? 'page_first' : 'page_$cursor';

  static String userDetailKey(String detailId) => detailId.toLowerCase();
}
