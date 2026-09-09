/// The user as it appears in a list response.
library;

import 'package:equatable/equatable.dart';

/// A GitHub user, containing exactly the fields `GET /users` returns.
///
/// Constraint (b): the list endpoint returns NO name and NO email. Modelling
/// them here as nullable would make it impossible to tell "not fetched yet"
/// from "GitHub returned null" -- two situations that need different UI. So the
/// richer shape is a separate type, [GithubUserDetail], and this one stays
/// honest about what the list actually gives you.
class GithubUser extends Equatable {
  const GithubUser({
    required this.id,
    required this.login,
    required this.avatarUrl,
    required this.htmlUrl,
    required this.type,
    required this.isSiteAdmin,
  });

  /// Numeric id. Doubles as the pagination cursor -- see `UsersPage`.
  final int id;

  /// Unique handle. This, not [id], keys the detail endpoint.
  final String login;

  /// Avatar image URL.
  final String avatarUrl;

  /// Public profile URL on github.com.
  final String htmlUrl;

  /// `User`, `Organization` or `Bot`.
  final String type;

  /// Whether the account is a GitHub staff admin.
  final bool isSiteAdmin;

  @override
  List<Object?> get props =>
      <Object?>[id, login, avatarUrl, htmlUrl, type, isSiteAdmin];
}
