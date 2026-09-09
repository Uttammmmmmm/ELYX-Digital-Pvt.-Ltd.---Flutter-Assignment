/// Display rules for user data.
library;

import '../../domain/entities/user_detail.dart';

/// Turns nullable domain values into strings fit for the screen.
///
/// WHY THIS IS NOT IN THE DOMAIN: the entity keeps `name` and `email` nullable
/// because that is the truth GitHub returns. Deciding that a missing name
/// should read as the login, or that a missing email should say "not public",
/// is a *presentation* choice -- a different client might render a dash, or
/// hide the row entirely. Keeping it here means the fallbacks are declared
/// once, are unit-testable as pure functions, and never leak back into
/// entities as fake data. Constraint (c).
abstract final class UserDisplay {
  /// Copy for the phone row.
  ///
  /// Constraint (c): GitHub has NO phone concept at all -- this is not a null
  /// value, it is a field that does not exist. There is deliberately no
  /// `phone` property on any entity or model to read this from; the detail
  /// screen renders it as a static, visibly-unavailable row. Fabricating a
  /// plausible-looking number here would be inventing data.
  static const String phoneUnavailable = 'Not provided by GitHub API';

  /// Copy for a hidden email.
  static const String emailUnavailable = 'Not public on GitHub';

  /// Copy for any other absent optional field.
  static const String fieldUnavailable = 'Not provided';

  /// True when the display name is falling back to the login, so the UI can
  /// skip rendering the handle twice.
  ///
  /// The name itself now comes from [UserDetail.displayName] -- that rule is
  /// about the domain, not about this screen. What stays here is the purely
  /// visual consequence of the fallback.
  static bool namesAreSame(UserDetail detail) => detail.name == null;

  /// The handle, prefixed.
  static String handle(String login) => '@$login';

  /// Email, or the "not public" fallback.
  static String email(UserDetail detail) => detail.email ?? emailUnavailable;

  /// Any optional free-text field, or the generic fallback.
  static String orUnavailable(String? value) => value ?? fieldUnavailable;

  /// Compact counts: `1.2k`, `23k`, `1.1m`.
  ///
  /// Follower counts run to six digits and would otherwise wrap the stat row.
  static String count(int value) {
    if (value < 1000) return '$value';
    if (value < 10000) return '${(value / 1000).toStringAsFixed(1)}k';
    if (value < 1000000) return '${(value / 1000).round()}k';
    return '${(value / 1000000).toStringAsFixed(1)}m';
  }
}
