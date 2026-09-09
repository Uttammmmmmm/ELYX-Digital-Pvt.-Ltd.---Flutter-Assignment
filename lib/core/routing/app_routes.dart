/// Route names, in one place.
library;

/// Every named route the app can push.
///
/// Constants rather than string literals at call sites: a typo becomes a
/// compile error instead of a 404 discovered by a user.
abstract final class AppRoutes {
  /// The users list. The initial route.
  static const String usersList = '/';

  /// A user's profile. Expects a `UserSummary` as its argument.
  static const String userDetail = '/user';
}
