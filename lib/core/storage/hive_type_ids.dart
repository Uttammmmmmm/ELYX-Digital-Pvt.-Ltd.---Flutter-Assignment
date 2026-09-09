/// THE single registry of Hive typeIds.
///
/// Every `@HiveType` in this app must take its id from here, and no id may
/// ever be reused or renumbered. A typeId is written into every persisted
/// record; changing one silently reinterprets old bytes as the wrong class,
/// which surfaces as corrupt data on a user's device long after the change.
/// Retiring a type means burning its id, not recycling it.
library;

/// Hive typeIds. Append only.
abstract final class HiveTypeIds {
  /// [UserSummaryModel] -- the list-endpoint user.
  static const int userSummary = 0;

  /// [UserDetailModel] -- the full profile.
  static const int userDetail = 1;

  /// [CachedPageModel] -- one cached batch plus its cursors.
  static const int cachedPage = 2;

  /// Next free id. Bump when adding a type; never reuse a retired one.
  static const int nextFree = 3;
}
