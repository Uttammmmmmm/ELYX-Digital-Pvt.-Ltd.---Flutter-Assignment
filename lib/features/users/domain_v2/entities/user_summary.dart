/// The user as the LIST endpoint returns it.
library;

import 'package:equatable/equatable.dart';

/// A GitHub user as returned by `GET /users?since=...`.
///
/// CONSTRAINT (b): this type deliberately has NO `name` and NO `email`,
/// because the list endpoint does not return them. It returns exactly six
/// fields, and those are the six below.
///
/// The tempting alternative -- one entity with `String? name` and
/// `String? email` shared by both endpoints -- is wrong, and the reason is
/// worth being able to say out loud: with a single nullable type the detail
/// screen cannot distinguish "not fetched yet" from "GitHub returned null",
/// and those two need different UI (a spinner versus a fallback label). Two
/// types make the impossible state unrepresentable instead of relying on a
/// convention nobody remembers six months later.
///
/// Fetching the missing fields is not an option either: names live behind
/// `GET /users/{login}`, one request per user, against a 60 requests/hour
/// unauthenticated budget. See [UserDetail].
class UserSummary extends Equatable {
  const UserSummary({
    required this.id,
    required this.login,
    required this.avatarUrl,
    required this.htmlUrl,
    required this.type,
    required this.siteAdmin,
  });

  /// Numeric account id. Also serves as the pagination cursor -- the `since`
  /// value for the next page is the id of the last user in this batch.
  final int id;

  /// Unique handle. This, not [id], keys the detail endpoint.
  final String login;

  /// Avatar image URL.
  final String avatarUrl;

  /// Public profile URL on github.com.
  final String htmlUrl;

  /// `User`, `Organization` or `Bot`.
  final String type;

  /// Whether the account is GitHub staff.
  final bool siteAdmin;

  @override
  List<Object?> get props =>
      <Object?>[id, login, avatarUrl, htmlUrl, type, siteAdmin];
}
